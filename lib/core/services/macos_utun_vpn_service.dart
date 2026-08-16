import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../models/active_session_snapshot.dart';
import '../models/routing_settings.dart';
import '../models/tunnel_health.dart';
import '../models/tunnel_settings.dart';
import '../models/vpn_node.dart';
import '../models/xray_settings.dart';
import 'app_log_service.dart';
import 'geodata_service.dart';
import 'macos_tunnel_bridge.dart';
import 'runtime_snapshot_store.dart';
import 'subscription_parser.dart';
import 'vpn_service.dart';
import 'xray_config_builder.dart';

class MacosUtunVpnService implements IVpnService {
  static const Duration _watchdogInterval = Duration(seconds: 6);

  final RoutingSettings Function() _readRoutingSettings;
  final TunnelSettings Function() _readTunnelSettings;
  final XraySettings Function() _readXraySettings;
  final Future<List<VpnNode>> Function(VpnNode currentNode)?
      _resolveFailoverCandidates;

  final _statusController = StreamController<ConnectionStatus>.broadcast();

  VpnNode? _currentNode;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _watchdogTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _shouldAutoReconnect = false;
  bool _isRepairing = false;
  bool _isDisposed = false;

  MacosUtunVpnService({
    RoutingSettings Function()? readRoutingSettings,
    TunnelSettings Function()? readTunnelSettings,
    XraySettings Function()? readXraySettings,
    Future<List<VpnNode>> Function(VpnNode currentNode)?
        resolveFailoverCandidates,
  })  : _readRoutingSettings = readRoutingSettings ?? RoutingSettings.defaults,
        _readTunnelSettings = readTunnelSettings ?? TunnelSettings.defaults,
        _readXraySettings = readXraySettings ?? XraySettings.defaults,
        _resolveFailoverCandidates = resolveFailoverCandidates {
    _lifecycleListener = AppLifecycleListener(
      onResume: _handleAppResume,
      onRestart: _handleAppResume,
      onShow: _handleAppResume,
    );
    _watchdogTimer = Timer.periodic(
      _watchdogInterval,
      (_) => unawaited(_reconcileTunnelState(reason: 'watchdog')),
    );
    unawaited(_bootstrap());
  }

  @override
  Future<void> connect(VpnNode node) async {
    await _connectInternal(
      node,
      reconnectReason: null,
    );
  }

  @override
  Future<void> disconnect() async {
    await _disconnectInternal(userInitiated: true);
  }

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  VpnNode? get currentNode => _currentNode;

  @override
  bool get isConnected => _status == ConnectionStatus.connected;

  Future<void> _bootstrap() async {
    await _restoreCurrentNodeFromSnapshot();
    await _reconcileTunnelState(reason: 'startup');
  }

  Future<void> _handleAppResume() async {
    await _restoreCurrentNodeFromSnapshot();
    await _reconcileTunnelState(reason: 'resume');
  }

  Future<void> _restoreCurrentNodeFromSnapshot() async {
    try {
      final snapshotJson = await RuntimeSnapshotStore.readActiveSession();
      if (snapshotJson.isEmpty) {
        return;
      }

      final snapshot = ActiveSessionSnapshot.fromJson(snapshotJson);
      if (!snapshot.isActive || snapshot.candidates.isEmpty) {
        return;
      }

      final preferredNode = snapshot.candidates
          .where((candidate) => candidate.node.id == snapshot.lastWorkingNodeId)
          .map((candidate) => candidate.node)
          .firstOrNull;

      _currentNode = preferredNode ?? snapshot.candidates.first.node;
      _shouldAutoReconnect = true;
    } catch (_) {
      // Ignore malformed snapshots and let the helper truth win.
    }
  }

  Future<bool> _connectInternal(
    VpnNode node, {
    required String? reconnectReason,
  }) async {
    try {
      AppLogService.instance.info(
        source: 'vpn',
        message: reconnectReason == null
            ? 'Connecting to ${node.name} through the utun helper.'
            : 'Repairing utun connection to ${node.name} after $reconnectReason.',
      );

      await _ensureHelperReady();

      final routingSettings = _readRoutingSettings();
      final tunnelSettings = _readTunnelSettings();
      final xraySettings = _readXraySettings();
      final bundledXrayDirectory = _resolveBundledXrayDirectory();
      final assetDirectory = await GeodataService.ensureAssetDirectory(
        bundledAssetDirectory: bundledXrayDirectory,
      );

      final candidates = await _buildCandidates(
        primaryNode: node,
        routingSettings: routingSettings,
        tunnelSettings: tunnelSettings,
        xraySettings: xraySettings,
      );
      final selectedCountryCode =
          SubscriptionParser.groupByCountry([node]).firstOrNull?.countryCode;
      final activeSession = ActiveSessionSnapshot(
        // The helper should only treat a session as restorable after a
        // successful tunnel bring-up. Writing it as active here lets a freshly
        // started helper race into background restore before the first connect
        // attempt completes, which can block the control socket indefinitely.
        isActive: false,
        connectionMode: candidates.length > 1 ? 'country' : 'node',
        selectedCountryCode: selectedCountryCode,
        lastWorkingNodeId: node.id,
        tunnelSettings: tunnelSettings.copyWith(
          dnsServers:
              XrayConfigBuilder.resolveDnsServers(routingSettings, tunnelSettings),
        ),
        candidates: candidates,
      );

      await MacosTunnelBridge.startTunnel(
        configPath: candidates.first.configPath,
        assetDirectory: assetDirectory,
        dnsServers: activeSession.tunnelSettings.dnsServers,
        mtu: tunnelSettings.mtu,
        enableIpv6: tunnelSettings.ipv6Enabled,
        bypassLocalNetworks: tunnelSettings.bypassLocalNetworks,
        strictRouting: tunnelSettings.strictRouting,
        reconnectReason: reconnectReason,
        activeTransport: candidates.first.activeTransport,
        activeSession: activeSession.toJson(),
      );

      _currentNode = node;
      _shouldAutoReconnect = true;
      _isRepairing = false;
      _updateStatus(ConnectionStatus.connected);
      await AppLogService.instance.syncNativeLogs();
      AppLogService.instance.info(
        source: 'vpn',
        message: 'Connected to ${node.name} through utun.',
      );
      return true;
    } catch (error) {
      AppLogService.instance.error(
        source: 'vpn',
        message: 'utun connection error: $error',
      );
      _updateStatus(ConnectionStatus.error);
      return false;
    }
  }

  Future<void> _disconnectInternal({required bool userInitiated}) async {
    if (userInitiated) {
      _shouldAutoReconnect = false;
      _isRepairing = false;
    }

    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnecting);
    }

    try {
      await MacosTunnelBridge.stopTunnel();
      if (userInitiated) {
        _currentNode = null;
      }
      _updateStatus(ConnectionStatus.disconnected);
      await AppLogService.instance.syncNativeLogs();
      AppLogService.instance.info(
        source: 'vpn',
        message: 'Disconnected utun session.',
      );
    } catch (error) {
      AppLogService.instance.error(
        source: 'vpn',
        message: 'utun disconnection error: $error',
      );
      _updateStatus(ConnectionStatus.error);
    }
  }

  Future<void> _ensureHelperReady() async {
    final status = await MacosTunnelBridge.helperStatus();
    final installed = status['installed'] == true;
    final reachable = status['reachable'] == true;
    final needsRefresh = status['needsRefresh'] == true;
    if (!installed || !reachable || needsRefresh) {
      AppLogService.instance.info(
        source: 'helper',
        message: needsRefresh
            ? 'Updating the VarPN background helper to match the current app build.'
            : installed
                ? 'VarPN helper is installed but unreachable. Reinstalling it now.'
                : 'Installing the VarPN background helper.',
      );
      await MacosTunnelBridge.installHelper();
    }

    final refreshedStatus = await MacosTunnelBridge.helperStatus();
    if (refreshedStatus['installed'] != true ||
        refreshedStatus['reachable'] != true) {
      throw Exception('VarPN helper is not ready yet.');
    }
  }

  Future<List<ActiveSessionCandidate>> _buildCandidates({
    required VpnNode primaryNode,
    required RoutingSettings routingSettings,
    required TunnelSettings tunnelSettings,
    required XraySettings xraySettings,
  }) async {
    final runtimePorts = await _allocateRuntimePorts();
    final sourceCandidates = <VpnNode>[
      primaryNode,
      ...?await _resolveFailoverCandidates?.call(primaryNode),
    ];

    final deduped = <VpnNode>[];
    final seenIds = <String>{};
    for (final candidate in sourceCandidates) {
      if (seenIds.add(candidate.id)) {
        deduped.add(candidate);
      }
    }

    final sharedContainerPath =
        await MacosTunnelBridge.sharedContainerPath() ?? '/Users/Shared/VarPN';
    final configDirectory = Directory('$sharedContainerPath/configs');
    await configDirectory.create(recursive: true);

    final candidates = <ActiveSessionCandidate>[];
    for (var index = 0; index < deduped.length; index += 1) {
      final candidate = deduped[index];
      final configJson = XrayConfigBuilder.buildRuntimeConfig(
        node: candidate,
        routingSettings: routingSettings,
        tunnelSettings: tunnelSettings,
        xraySettings: xraySettings,
        localPort: runtimePorts.localPort,
        apiPort: runtimePorts.apiPort,
      );
      final configFile = File(
        '${configDirectory.path}/runtime_${candidate.id.hashCode}_$index.json',
      );
      await configFile.writeAsString(
        jsonEncode(configJson),
        flush: true,
      );

      candidates.add(
        ActiveSessionCandidate(
          node: candidate,
          countryCode:
              SubscriptionParser.groupByCountry([candidate]).firstOrNull?.countryCode,
          configPath: configFile.path,
          activeTransport: _activeTransport(candidate, xraySettings),
        ),
      );
    }

    return candidates;
  }

  Future<({int localPort, int apiPort})> _allocateRuntimePorts() async {
    final random = Random.secure();

    Future<int> bindEphemeralPort(Set<int> reserved) async {
      while (true) {
        final preferredPort = 20000 + random.nextInt(30000);
        if (reserved.contains(preferredPort)) {
          continue;
        }

        try {
          final socket = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            preferredPort,
          );
          final port = socket.port;
          await socket.close();
          if (!reserved.contains(port)) {
            reserved.add(port);
            return port;
          }
        } catch (_) {
          try {
            final socket = await ServerSocket.bind(
              InternetAddress.loopbackIPv4,
              0,
            );
            final port = socket.port;
            await socket.close();
            if (!reserved.contains(port)) {
              reserved.add(port);
              return port;
            }
          } catch (_) {
            // Keep retrying until the OS gives us a free port.
          }
        }
      }
    }

    final reserved = <int>{};
    final localPort = await bindEphemeralPort(reserved);
    final apiPort = await bindEphemeralPort(reserved);
    return (localPort: localPort, apiPort: apiPort);
  }

  String _activeTransport(VpnNode node, XraySettings xraySettings) {
    if (xraySettings.transportOverride != 'auto') {
      return xraySettings.transportOverride;
    }

    final rawConfig = node.rawConfig ?? const <String, dynamic>{};
    return (node.network ?? rawConfig['type'] ?? rawConfig['net'] ?? 'tcp')
        .toString();
  }

  String _resolveBundledXrayDirectory() {
    final searchRoots = <Directory>{
      Directory.current.absolute,
      Directory.current.parent.absolute,
    };

    var cursor = File(Platform.resolvedExecutable).absolute.parent;
    for (var index = 0; index < 8; index += 1) {
      searchRoots.add(cursor);
      final parent = cursor.parent;
      if (parent.path == cursor.path) {
        break;
      }
      cursor = parent;
    }

    final candidates = <Directory>[
      for (final root in searchRoots) Directory('${root.path}/Resources/xray-core'),
      for (final root in searchRoots)
        Directory('${root.path}/Contents/Resources/xray-core'),
      for (final root in searchRoots) Directory('${root.path}/xray-core'),
    ];

    for (final directory in candidates) {
      if (directory.existsSync()) {
        return directory.path;
      }
    }

    throw Exception('Bundled Xray runtime was not found in the app resources.');
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
          _updateStatus(ConnectionStatus.connected);
        }
        return;
      }

      if (actualStatus == ConnectionStatus.connecting ||
          actualStatus == ConnectionStatus.disconnecting) {
        if (_status != actualStatus) {
          _updateStatus(actualStatus);
        }
        return;
      }

      if (_status != ConnectionStatus.disconnected) {
        AppLogService.instance.warning(
          source: 'vpn',
          message:
              'utun helper reported $tunnelStatus during $reason reconciliation.',
        );
        _updateStatus(ConnectionStatus.disconnected);
      }

      if (_shouldAutoReconnect &&
          _currentNode != null &&
          !_isRepairing &&
          actualStatus == ConnectionStatus.disconnected) {
        _isRepairing = true;
        AppLogService.instance.warning(
          source: 'vpn',
          message:
              'Attempting utun helper repair for ${_currentNode!.name} after $reason.',
        );
        try {
          await MacosTunnelBridge.repairTunnel();
          await Future<void>.delayed(const Duration(milliseconds: 900));
          await AppLogService.instance.syncNativeLogs();
          final repairedStatus = _mapTunnelStatus(
            await MacosTunnelBridge.tunnelStatus(),
          );
          if (repairedStatus == ConnectionStatus.connected) {
            _updateStatus(ConnectionStatus.connected);
          }
        } finally {
          _isRepairing = false;
        }
      }
    } catch (error) {
      AppLogService.instance.warning(
        source: 'vpn',
        message: 'Failed to reconcile utun helper state during $reason: $error',
      );
    }
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
      case 'error':
      case 'disconnected':
      case 'invalid':
      case 'unsupported':
      case 'unknown':
      default:
        return ConnectionStatus.disconnected;
    }
  }

  void _updateStatus(ConnectionStatus next) {
    if (_status == next || _isDisposed) {
      return;
    }
    _status = next;
    _statusController.add(next);
  }

  @override
  Future<TunnelHealth?> readTunnelHealth() async {
    try {
      final snapshot = await MacosTunnelBridge.tunnelHealth();
      if (snapshot.isEmpty) {
        final fallback = await RuntimeSnapshotStore.readTunnelHealth();
        if (fallback.isEmpty) {
          return null;
        }
        return TunnelHealth.fromJson(fallback);
      }
      return TunnelHealth.fromJson(snapshot);
    } catch (_) {
      final fallback = await RuntimeSnapshotStore.readTunnelHealth();
      if (fallback.isEmpty) {
        return null;
      }
      return TunnelHealth.fromJson(fallback);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _watchdogTimer?.cancel();
    _lifecycleListener?.dispose();
    _statusController.close();
  }
}
