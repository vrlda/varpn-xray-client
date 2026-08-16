import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../models/routing_settings.dart';
import '../models/tunnel_health.dart';
import '../models/tunnel_settings.dart';
import '../models/vpn_node.dart';
import '../models/xray_settings.dart';
import 'app_log_service.dart';
import 'geodata_service.dart';
import 'macos_tunnel_bridge.dart';
import 'vpn_service.dart';
import 'xray_config_builder.dart';

class IosVpnService implements IVpnService {
  static const int localPort = 10808;

  final RoutingSettings Function() _readRoutingSettings;
  final TunnelSettings Function() _readTunnelSettings;
  final XraySettings Function() _readXraySettings;
  final Future<VpnNode?> Function(VpnNode currentNode)? _resolveFailoverNode;

  final _statusController = StreamController<ConnectionStatus>.broadcast();

  VpnNode? _currentNode;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _watchdogTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _shouldAutoReconnect = false;
  bool _isReconnecting = false;
  bool _isDisposed = false;
  int _unexpectedReconnectFailures = 0;

  IosVpnService({
    RoutingSettings Function()? readRoutingSettings,
    TunnelSettings Function()? readTunnelSettings,
    XraySettings Function()? readXraySettings,
    Future<VpnNode?> Function(VpnNode currentNode)? resolveFailoverNode,
  })  : _readRoutingSettings = readRoutingSettings ?? RoutingSettings.defaults,
        _readTunnelSettings = readTunnelSettings ?? TunnelSettings.defaults,
        _readXraySettings = readXraySettings ?? XraySettings.defaults,
        _resolveFailoverNode = resolveFailoverNode {
    _lifecycleListener = AppLifecycleListener(
      onResume: _handleAppResume,
      onRestart: _handleAppResume,
      onShow: _handleAppResume,
    );
    _watchdogTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => unawaited(_reconcileTunnelState(reason: 'watchdog')),
    );
    unawaited(_reconcileTunnelState(reason: 'startup'));
  }

  @override
  Future<void> connect(VpnNode node) async {
    await _connectInternal(node, reconnectReason: null);
  }

  Future<bool> _connectInternal(
    VpnNode node, {
    required String? reconnectReason,
  }) async {
    try {
      AppLogService.instance.info(
        source: 'vpn',
        message: reconnectReason == null
            ? 'Connecting to ${node.name} (${node.server}:${node.port}) on iOS.'
            : 'Reconnecting to ${node.name} on iOS after $reconnectReason.',
      );

      await _disconnectInternal(userInitiated: false);
      _updateStatus(ConnectionStatus.connecting);

      final routingSettings = _readRoutingSettings();
      final tunnelSettings = _readTunnelSettings();
      final xraySettings = _readXraySettings();
      final assetDirectory = await GeodataService.ensureAssetDirectory(
        bundledAssetDirectory: 'xray-core',
      );
      final configJson = XrayConfigBuilder.buildRuntimeConfig(
        node: node,
        routingSettings: routingSettings,
        tunnelSettings: tunnelSettings,
        xraySettings: xraySettings,
        localPort: localPort,
      );

      final configFile = await _writeSharedConfig(configJson);
      await MacosTunnelBridge.startTunnel(
        configPath: configFile.path,
        assetDirectory: assetDirectory,
        dnsServers: XrayConfigBuilder.resolveDnsServers(
          routingSettings,
          tunnelSettings,
        ),
        mtu: tunnelSettings.mtu,
        enableIpv6: tunnelSettings.ipv6Enabled,
        bypassLocalNetworks: tunnelSettings.bypassLocalNetworks,
        strictRouting: tunnelSettings.strictRouting,
        reconnectReason: reconnectReason,
        activeTransport: _activeTransportForNode(node),
      );

      _currentNode = node;
      _shouldAutoReconnect = true;
      _isReconnecting = false;
      _unexpectedReconnectFailures = 0;
      _updateStatus(ConnectionStatus.connected);
      await AppLogService.instance.syncNativeLogs();
      AppLogService.instance.info(
        source: 'vpn',
        message: 'Connected to ${node.name} on iOS.',
      );
      return true;
    } catch (error) {
      AppLogService.instance.error(
        source: 'vpn',
        message: 'iOS connection error: $error',
      );
      _updateStatus(ConnectionStatus.error);
      await _disconnectInternal(userInitiated: false);
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _disconnectInternal(userInitiated: true);
  }

  Future<void> _disconnectInternal({required bool userInitiated}) async {
    if (userInitiated) {
      _shouldAutoReconnect = false;
      _isReconnecting = false;
    }

    if (_status == ConnectionStatus.disconnected) {
      if (userInitiated) {
        _currentNode = null;
      }
      return;
    }

    _updateStatus(ConnectionStatus.disconnecting);
    AppLogService.instance.info(
      source: 'vpn',
      message: 'Disconnecting active iOS session.',
    );

    try {
      await MacosTunnelBridge.stopTunnel();
      if (userInitiated) {
        _currentNode = null;
      }

      _updateStatus(ConnectionStatus.disconnected);
      await AppLogService.instance.syncNativeLogs();
      AppLogService.instance.info(
        source: 'vpn',
        message: 'Disconnected iOS tunnel.',
      );
    } catch (error) {
      AppLogService.instance.error(
        source: 'vpn',
        message: 'iOS disconnection error: $error',
      );
      _updateStatus(ConnectionStatus.error);
    }
  }

  Future<void> _handleAppResume() async {
    await _reconcileTunnelState(reason: 'resume');
  }

  Future<void> _reconcileTunnelState({required String reason}) async {
    if (_isDisposed || _status == ConnectionStatus.connecting) {
      return;
    }

    try {
      final tunnelStatus = await MacosTunnelBridge.tunnelStatus();
      await AppLogService.instance.syncNativeLogs();
      final actualStatus = _mapTunnelStatus(tunnelStatus);

      if (actualStatus == ConnectionStatus.connected) {
        if (_status != ConnectionStatus.connected) {
          AppLogService.instance.warning(
            source: 'vpn',
            message: 'Reconciled iOS tunnel status to connected after $reason.',
          );
          _updateStatus(ConnectionStatus.connected);
        }
        return;
      }

      if (actualStatus == ConnectionStatus.connecting ||
          actualStatus == ConnectionStatus.disconnecting) {
        if (_status != actualStatus) {
          AppLogService.instance.info(
            source: 'vpn',
            message:
                'Reconciled iOS tunnel status to ${actualStatus.name} after $reason.',
          );
          _updateStatus(actualStatus);
        }
        return;
      }

      final wasThoughtConnected = _status == ConnectionStatus.connected ||
          _status == ConnectionStatus.disconnecting;
      if (wasThoughtConnected) {
        AppLogService.instance.warning(
          source: 'vpn',
          message:
              'iOS tunnel is not running during $reason check. Native status: $tunnelStatus.',
        );
      }

      if (_status != ConnectionStatus.disconnected) {
        _updateStatus(ConnectionStatus.disconnected);
      }

      if (_shouldAutoReconnect &&
          _currentNode != null &&
          !_isReconnecting &&
          actualStatus == ConnectionStatus.disconnected) {
        _isReconnecting = true;
        AppLogService.instance.warning(
          source: 'vpn',
          message:
              'iOS tunnel dropped unexpectedly. Reconnecting to ${_currentNode!.name} after $reason.',
        );
        unawaited(_attemptReconnect());
      }
    } catch (error) {
      AppLogService.instance.warning(
        source: 'vpn',
        message: 'Failed to reconcile iOS tunnel state during $reason: $error',
      );
    }
  }

  Future<void> _attemptReconnect() async {
    final node = _currentNode;
    if (node == null || _isDisposed) {
      _isReconnecting = false;
      return;
    }

    try {
      final recovered = await _connectInternal(
        node,
        reconnectReason: 'unexpected disconnect',
      );
      if (recovered) {
        return;
      }

      _unexpectedReconnectFailures += 1;
      if (_unexpectedReconnectFailures < 2 || _resolveFailoverNode == null) {
        return;
      }

      final failoverNode = await _resolveFailoverNode!.call(node);
      if (failoverNode == null || failoverNode.id == node.id) {
        AppLogService.instance.error(
          source: 'vpn',
          message:
              'iOS same-country failover was unavailable after repeated reconnect failures for ${node.name}.',
        );
        return;
      }

      AppLogService.instance.warning(
        source: 'vpn',
        message:
            'Reconnecting through iOS fallback node ${failoverNode.name} after repeated failures for ${node.name}.',
      );
      await _connectInternal(
        failoverNode,
        reconnectReason: 'same-country failover',
      );
    } finally {
      _isReconnecting = false;
    }
  }

  Future<File> _writeSharedConfig(Map<String, dynamic> configJson) async {
    final sharedContainerPath = await MacosTunnelBridge.sharedContainerPath();
    if (sharedContainerPath == null || sharedContainerPath.isEmpty) {
      throw Exception('Shared container path is unavailable for iOS tunnel.');
    }

    final packetTunnelDirectory = Directory(
      '$sharedContainerPath/PacketTunnel',
    );
    await packetTunnelDirectory.create(recursive: true);

    final configFile = File('${packetTunnelDirectory.path}/runtime-config.json');
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(configJson),
      flush: true,
    );
    return configFile;
  }

  String _activeTransportForNode(VpnNode node) {
    final rawConfig = node.rawConfig ?? const <String, dynamic>{};
    return (node.network ?? rawConfig['type'] ?? rawConfig['net'] ?? 'tcp')
        .toString();
  }

  ConnectionStatus _mapTunnelStatus(String status) {
    switch (status) {
      case 'connected':
        return ConnectionStatus.connected;
      case 'connecting':
      case 'reasserting':
        return ConnectionStatus.connecting;
      case 'disconnecting':
        return ConnectionStatus.disconnecting;
      case 'disconnected':
      case 'invalid':
      case 'unsupported':
      case 'unknown':
      default:
        return ConnectionStatus.disconnected;
    }
  }

  @override
  Future<TunnelHealth?> readTunnelHealth() async {
    try {
      final snapshot = await MacosTunnelBridge.tunnelHealth();
      if (snapshot.isEmpty) {
        return null;
      }
      return TunnelHealth.fromJson(snapshot);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  VpnNode? get currentNode => _currentNode;

  @override
  bool get isConnected => _status == ConnectionStatus.connected;

  @override
  void dispose() {
    _isDisposed = true;
    _watchdogTimer?.cancel();
    _lifecycleListener?.dispose();
    _statusController.close();
  }

  void _updateStatus(ConnectionStatus next) {
    _status = next;
    _statusController.add(next);
  }
}
