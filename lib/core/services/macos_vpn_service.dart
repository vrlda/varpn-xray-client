import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import '../models/routing_settings.dart';
import '../models/tunnel_health.dart';
import '../models/tunnel_settings.dart';
import '../models/vpn_node.dart';
import '../models/xray_settings.dart';
import 'app_log_service.dart';
import 'geodata_service.dart';
import 'macos_tunnel_bridge.dart';
import 'routing_service.dart';
import 'vpn_service.dart';

class MacosVpnService implements IVpnService {
  final RoutingSettings Function() _readRoutingSettings;
  final TunnelSettings Function() _readTunnelSettings;
  final XraySettings Function() _readXraySettings;
  final Future<VpnNode?> Function(VpnNode currentNode)? _resolveFailoverNode;
  VpnNode? _currentNode;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Timer? _watchdogTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _shouldAutoReconnect = false;
  bool _isReconnecting = false;
  bool _isDisposed = false;
  int _unexpectedReconnectFailures = 0;

  // Local SOCKS proxy port
  static const int localPort = 10808;
  static const int apiPort = 10085;

  MacosVpnService({
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
    await _connectInternal(
      node,
      reconnectReason: null,
    );
  }

  Future<bool> _connectInternal(
    VpnNode node, {
    required String? reconnectReason,
  }) async {
    try {
      AppLogService.instance.info(
        source: 'vpn',
        message: reconnectReason == null
            ? 'Connecting to ${node.name} (${node.server}:${node.port})'
            : 'Reconnecting to ${node.name} after $reconnectReason.',
      );
      await _disconnectInternal(userInitiated: false);
      _updateStatus(ConnectionStatus.connecting);

      // 1. Resolve Xray runtime and the current routing preferences.
      final routingSettings = _readRoutingSettings();
      final tunnelSettings = _readTunnelSettings();
      final xraySettings = _readXraySettings();
      final xrayRuntime = _resolveXrayRuntime();
      final assetDirectory = await GeodataService.ensureAssetDirectory(
        bundledAssetDirectory: xrayRuntime.workingDirectory,
      );
      final configJson = _generateXrayConfig(
        node,
        routingSettings,
        xraySettings,
      );

      // 2. Write config to temp file.
      final tempDir = await getTemporaryDirectory();
      final configFile = File('${tempDir.path}/xray_config.json');
      await configFile.writeAsString(jsonEncode(configJson));

      await MacosTunnelBridge.startTunnel(
        configPath: configFile.path,
        assetDirectory: assetDirectory,
        dnsServers: _resolveDnsServers(routingSettings, tunnelSettings),
        mtu: tunnelSettings.mtu,
        enableIpv6: tunnelSettings.ipv6Enabled,
        bypassLocalNetworks: tunnelSettings.bypassLocalNetworks,
        strictRouting: tunnelSettings.strictRouting,
        reconnectReason: reconnectReason,
      );

      _currentNode = node;
      _shouldAutoReconnect = true;
      _isReconnecting = false;
      _unexpectedReconnectFailures = 0;
      _updateStatus(ConnectionStatus.connected);
      await AppLogService.instance.syncNativeLogs();
      AppLogService.instance.info(
        source: 'vpn',
        message: 'Connected to ${node.name}',
      );
      return true;
    } catch (e) {
      AppLogService.instance.error(
        source: 'vpn',
        message: 'Connection error: $e',
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
      _currentNode = userInitiated ? null : _currentNode;
      return;
    }

    _updateStatus(ConnectionStatus.disconnecting);
    AppLogService.instance.info(
      source: 'vpn',
      message: 'Disconnecting active session',
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
        message: 'Disconnected',
      );
    } catch (e) {
      AppLogService.instance.error(
        source: 'vpn',
        message: 'Disconnection error: $e',
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
            message:
                'Reconciled tunnel status to connected after $reason check.',
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
                'Reconciled tunnel status to ${actualStatus.name} after $reason check.',
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
              'Tunnel is not running during $reason check. Native status: $tunnelStatus.',
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
              'Tunnel dropped unexpectedly. Reconnecting to ${_currentNode!.name} after $reason.',
        );
        unawaited(_attemptReconnect());
      }
    } catch (error) {
      AppLogService.instance.warning(
        source: 'vpn',
        message: 'Failed to reconcile tunnel state during $reason: $error',
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
      final reconnectReason = 'unexpected disconnect';
      final recovered = await _connectInternal(
        node,
        reconnectReason: reconnectReason,
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
              'Same-country failover was unavailable after repeated reconnect failures for ${node.name}.',
        );
        return;
      }

      AppLogService.instance.warning(
        source: 'vpn',
        message:
            'Reconnecting through fallback node ${failoverNode.name} after repeated failures for ${node.name}.',
      );
      await _connectInternal(
        failoverNode,
        reconnectReason: 'same-country failover',
      );
    } finally {
      _isReconnecting = false;
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

  _ResolvedXrayRuntime _resolveXrayRuntime() {
    final searchRoots = <Directory>{
      Directory.current.absolute,
      Directory.current.parent.absolute,
    };

    var cursor = File(Platform.resolvedExecutable).absolute.parent;
    for (var i = 0; i < 8; i++) {
      searchRoots.add(cursor);
      final parent = cursor.parent;
      if (parent.path == cursor.path) {
        break;
      }
      cursor = parent;
    }

    final candidates = <File>[
      for (final root in searchRoots) File('${root.path}/xray-core/xray'),
      for (final root in searchRoots)
        File('${root.path}/Resources/xray-core/xray'),
      for (final root in searchRoots)
        File('${root.path}/Contents/Resources/xray-core/xray'),
    ];

    for (final file in candidates) {
      if (file.existsSync()) {
        return _ResolvedXrayRuntime(
          executablePath: file.path,
          workingDirectory: file.parent.path,
        );
      }
    }

    throw Exception('Xray executable not found in known locations');
  }

  Map<String, dynamic> _generateXrayConfig(
    VpnNode node,
    RoutingSettings routingSettings,
    XraySettings xraySettings,
  ) {
    final preset = routingSettings.selectedPreset;
    final dnsConfig = RoutingService.buildDnsConfig(routingSettings);
    final routingConfig = _withApiRoutingRule(
      RoutingService.buildRoutingConfig(routingSettings),
    );
    final fakeDnsConfig = RoutingService.buildFakeDnsConfig(routingSettings);
    final defaultToProxy =
        !routingSettings.enabled || preset.globalProxyEnabled;

    final outbounds = <Map<String, dynamic>>[
      if (defaultToProxy)
        _buildOutbound(node, xraySettings)
      else
        _buildDirectOutbound(),
      if (defaultToProxy)
        _buildDirectOutbound()
      else
        _buildOutbound(node, xraySettings),
      _buildBlockOutbound(),
    ];

    return {
      "log": {"loglevel": xraySettings.logLevel},
      "stats": <String, dynamic>{},
      "policy": {
        "system": {
          "statsOutboundUplink": true,
          "statsOutboundDownlink": true,
        }
      },
      "api": {
        "tag": "api",
        "listen": "127.0.0.1:$apiPort",
        "services": ["StatsService"],
      },
      if (dnsConfig != null) "dns": dnsConfig,
      if (fakeDnsConfig.isNotEmpty) "fakedns": fakeDnsConfig,
      'routing': routingConfig,
      "inbounds": [
        {
          "listen": "127.0.0.1",
          "port": localPort,
          "protocol": "socks",
          "settings": {"udp": true},
          "sniffing": {
            "enabled": xraySettings.sniffingEnabled,
            "destOverride": [
              "http",
              "tls",
              "quic",
              if (preset.fakeDnsEnabled) "fakedns",
            ],
          },
        }
      ],
      "outbounds": outbounds,
    };
  }

  Map<String, dynamic> _withApiRoutingRule(
      Map<String, dynamic>? routingConfig) {
    final config = routingConfig == null
        ? <String, dynamic>{'domainStrategy': 'AsIs', 'rules': <dynamic>[]}
        : Map<String, dynamic>.from(routingConfig);
    final existingRules = (config['rules'] as List?)?.toList() ?? <dynamic>[];

    config['rules'] = [
      {
        'type': 'field',
        'inboundTag': ['api'],
        'outboundTag': 'api',
      },
      ...existingRules,
    ];

    return config;
  }

  Map<String, dynamic> _buildDirectOutbound() {
    return {"protocol": "freedom", "tag": "direct"};
  }

  Map<String, dynamic> _buildBlockOutbound() {
    return {"protocol": "blackhole", "tag": "block"};
  }

  Map<String, dynamic> _buildOutbound(
    VpnNode node,
    XraySettings xraySettings,
  ) {
    final protocol = node.protocol.toLowerCase();
    final rawConfig = node.rawConfig ?? const <String, dynamic>{};
    final network = xraySettings.transportOverride == 'auto'
        ? (node.network ?? rawConfig['type'] ?? rawConfig['net'] ?? 'tcp')
            .toString()
        : xraySettings.transportOverride;
    final security =
        (node.security ?? rawConfig['security'] ?? rawConfig['tls'] ?? 'none')
            .toString();

    Map<String, dynamic> streamSettings = {
      "network": network,
      "security": security,
    };

    if (security == "tls") {
      streamSettings["tlsSettings"] = <String, dynamic>{
        "serverName": node.sni ??
            rawConfig['sni'] ??
            rawConfig['serverName'] ??
            node.server,
        "allowInsecure": _parseBool(rawConfig['allowInsecure']) ??
            xraySettings.allowInsecure,
      };

      final fingerprint = rawConfig['fp']?.toString();
      final alpn = rawConfig['alpn']?.toString();
      if (fingerprint != null && fingerprint.isNotEmpty) {
        streamSettings["tlsSettings"]["fingerprint"] = fingerprint;
      }
      if (alpn != null && alpn.isNotEmpty) {
        streamSettings["tlsSettings"]["alpn"] = alpn
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      }
    } else if (security == "reality") {
      streamSettings["realitySettings"] = <String, dynamic>{
        "fingerprint": rawConfig['fp']?.toString() ??
            rawConfig['fingerprint']?.toString() ??
            'chrome',
        "serverName": node.sni ?? rawConfig['sni'] ?? node.server,
        "publicKey": node.realityPubKey ?? "",
        "shortId": node.realityShortId ?? "",
        "spiderX": rawConfig['spx']?.toString() ?? node.path ?? "",
      };
    }

    if (network == "ws") {
      streamSettings["wsSettings"] = {
        "path": node.path ?? "/",
        "headers": {"Host": node.host ?? node.sni ?? ""}
      };
    } else if (network == "xhttp") {
      streamSettings["xhttpSettings"] = {
        "path": node.path ?? "/",
        "host": node.host ?? node.sni ?? "",
        "mode": rawConfig['mode']?.toString() ?? "auto",
      };
    } else if (network == "grpc") {
      streamSettings["grpcSettings"] = {
        "serviceName": rawConfig['serviceName']?.toString() ?? node.path ?? "",
      };
    }

    Map<String, dynamic> outbound = {
      "protocol": protocol,
      "streamSettings": streamSettings,
      "tag": "proxy"
    };

    if (protocol == 'vless') {
      final user = <String, dynamic>{
        "id": node.userId ?? "",
        "encryption": node.encryption ?? "none",
      };
      if (node.flow != null && node.flow!.isNotEmpty) {
        user["flow"] = node.flow;
      }

      outbound["settings"] = {
        "vnext": [
          {
            "address": node.server,
            "port": node.port,
            "users": [user]
          }
        ]
      };
    } else if (protocol == 'vmess') {
      outbound["settings"] = {
        "vnext": [
          {
            "address": node.server,
            "port": node.port,
            "users": [
              {
                "id": node.userId ?? "",
                "alterId":
                    int.tryParse(rawConfig['aid']?.toString() ?? '0') ?? 0,
                "security": node.encryption ?? rawConfig['scy'] ?? "auto"
              }
            ]
          }
        ]
      };
    } else if (protocol == 'trojan') {
      outbound["settings"] = {
        "servers": [
          {
            "address": node.server,
            "port": node.port,
            "password": node.userId ?? ""
          }
        ]
      };
    } else if (protocol == 'ss') {
      outbound["settings"] = {
        "servers": [
          {
            "address": node.server,
            "port": node.port,
            "password": node.userId ?? "",
            "method": node.encryption ?? "aes-256-gcm"
          }
        ]
      };
    }

    return outbound;
  }

  List<String> _resolveDnsServers(
    RoutingSettings routingSettings,
    TunnelSettings tunnelSettings,
  ) {
    if (tunnelSettings.dnsMode == 'system') {
      return const [];
    }

    if (tunnelSettings.dnsServers.isNotEmpty) {
      return [
        for (final server in tunnelSettings.dnsServers)
          if (server.trim().isNotEmpty) server.trim(),
      ];
    }

    final preset = routingSettings.selectedPreset;
    final candidates = <String>[
      preset.remoteDnsIp,
      preset.domesticDnsValue,
      '1.1.1.1',
      '8.8.8.8',
    ];

    final servers = <String>[];
    for (final candidate in candidates) {
      final normalized = candidate.trim();
      if (normalized.isEmpty) {
        continue;
      }

      if (Uri.tryParse(normalized)?.hasScheme ?? false) {
        continue;
      }

      if (!servers.contains(normalized)) {
        servers.add(normalized);
      }
    }

    return servers.isEmpty ? ['1.1.1.1', '8.8.8.8'] : servers;
  }

  bool? _parseBool(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim().toLowerCase();
    if (normalized == '1' || normalized == 'true') {
      return true;
    }
    if (normalized == '0' || normalized == 'false') {
      return false;
    }
    return null;
  }

  void _updateStatus(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
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
}

class _ResolvedXrayRuntime {
  final String executablePath;
  final String workingDirectory;

  const _ResolvedXrayRuntime({
    required this.executablePath,
    required this.workingDirectory,
  });
}
