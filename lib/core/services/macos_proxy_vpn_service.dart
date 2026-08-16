import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../models/routing_settings.dart';
import '../models/ping_settings.dart';
import '../models/tunnel_health.dart';
import '../models/tunnel_settings.dart';
import '../models/vpn_node.dart';
import '../models/xray_settings.dart';
import 'app_log_service.dart';
import 'geodata_service.dart';
import 'routing_service.dart';
import 'runtime_snapshot_store.dart';
import 'vpn_service.dart';

class MacosProxyVpnService implements IVpnService {
  static const int localPort = 10808;
  static const int apiPort = 10085;
  static const Duration _watchdogInterval = Duration(seconds: 6);
  static const Duration _trafficPollInterval = Duration(seconds: 5);
  static const Duration _proxyStartupTimeout = Duration(seconds: 5);
  static const Duration _proxyHealthProbeInterval = Duration(seconds: 30);
  static const String _loopbackHost = '127.0.0.1';
  static const String _networksetupPath = '/usr/sbin/networksetup';
  static const String _osascriptPath = '/usr/bin/osascript';
  static const String _psPath = '/bin/ps';
  static const String _curlPath = '/usr/bin/curl';

  final RoutingSettings Function() _readRoutingSettings;
  final TunnelSettings Function() _readTunnelSettings;
  final PingSettings Function() _readPingSettings;
  final XraySettings Function() _readXraySettings;
  final Future<VpnNode?> Function(VpnNode currentNode)? _resolveFailoverNode;

  final _statusController = StreamController<ConnectionStatus>.broadcast();

  VpnNode? _currentNode;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  Process? _xrayProcess;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Timer? _watchdogTimer;
  Timer? _trafficTimer;
  AppLifecycleListener? _lifecycleListener;
  String? _lastXrayLogLine;
  bool _shouldAutoReconnect = false;
  bool _isReconnecting = false;
  bool _isDisposed = false;
  bool _isStoppingRuntime = false;
  bool _proxyConfigured = false;
  bool _proxyConfigurationHealthy = false;
  bool _proxyReachable = false;
  int _unexpectedReconnectFailures = 0;
  int _consecutiveProxyProbeFailures = 0;
  String? _lastReconnectReason;
  String? _lastCrashReason;
  int? _lastXrayExitCode;
  int _protectedServiceCount = 0;
  int _totalServiceCount = 0;
  String? _lastProxyError;
  DateTime? _lastProxyProbeAt;
  String? _lastAnnouncedProxyIssue;

  int _committedTotalUplinkBytes = 0;
  int _committedTotalDownlinkBytes = 0;
  int _sessionAccumulatedUplinkBytes = 0;
  int _sessionAccumulatedDownlinkBytes = 0;
  int _liveSessionUplinkBytes = 0;
  int _liveSessionDownlinkBytes = 0;
  int _lastSessionUplinkBytes = 0;
  int _lastSessionDownlinkBytes = 0;
  DateTime? _currentSessionStartedAt;

  MacosProxyVpnService({
    RoutingSettings Function()? readRoutingSettings,
    TunnelSettings Function()? readTunnelSettings,
    PingSettings Function()? readPingSettings,
    XraySettings Function()? readXraySettings,
    Future<VpnNode?> Function(VpnNode currentNode)? resolveFailoverNode,
  })  : _readRoutingSettings = readRoutingSettings ?? RoutingSettings.defaults,
        _readTunnelSettings = readTunnelSettings ?? TunnelSettings.defaults,
        _readPingSettings = readPingSettings ?? PingSettings.defaults,
        _readXraySettings = readXraySettings ?? XraySettings.defaults,
        _resolveFailoverNode = resolveFailoverNode {
    _lifecycleListener = AppLifecycleListener(
      onResume: _handleAppResume,
      onRestart: _handleAppResume,
      onShow: _handleAppResume,
    );
    _watchdogTimer = Timer.periodic(
      _watchdogInterval,
      (_) => unawaited(_reconcileRuntimeState(reason: 'watchdog')),
    );
    unawaited(_bootstrap());
  }

  @override
  Future<void> connect(VpnNode node) async {
    await _connectInternal(
      node,
      reconnectReason: null,
      preserveSession: false,
    );
  }

  Future<void> _bootstrap() async {
    await _restoreTrafficSnapshot();
    await _cleanupStaleProxyConfiguration();
    await _writeHealthSnapshot(
      nativeState: 'disconnected',
      xrayRunning: false,
    );
  }

  Future<void> _restoreTrafficSnapshot() async {
    final snapshot = await RuntimeSnapshotStore.readTrafficStats();
    _committedTotalUplinkBytes = _readInt(snapshot['totalUplinkBytes']);
    _committedTotalDownlinkBytes = _readInt(snapshot['totalDownlinkBytes']);
    _lastSessionUplinkBytes = _readInt(snapshot['lastSessionUplinkBytes']);
    _lastSessionDownlinkBytes = _readInt(snapshot['lastSessionDownlinkBytes']);
    _currentSessionStartedAt = null;
    _sessionAccumulatedUplinkBytes = 0;
    _sessionAccumulatedDownlinkBytes = 0;
    _liveSessionUplinkBytes = 0;
    _liveSessionDownlinkBytes = 0;

    await _writeTrafficSnapshot();
  }

  Future<bool> _connectInternal(
    VpnNode node, {
    required String? reconnectReason,
    required bool preserveSession,
  }) async {
    try {
      AppLogService.instance.info(
        source: 'vpn',
        message: reconnectReason == null
            ? 'Connecting to ${node.name} (${node.server}:${node.port}) through the system SOCKS proxy.'
            : 'Reconnecting to ${node.name} after $reconnectReason.',
      );

      if (!preserveSession) {
        await _disconnectInternal(
          userInitiated: false,
          finalizeSession: false,
        );
        _startFreshSession();
      } else {
        await _stopRuntimeOnly();
      }

      _updateStatus(ConnectionStatus.connecting);
      await _writeHealthSnapshot(
        nativeState: 'connecting',
        xrayRunning: false,
        lastReconnectReason: reconnectReason,
      );

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
        tunnelSettings,
        xraySettings,
      );

      final tempDir = await getTemporaryDirectory();
      final configFile = File(
        '${tempDir.path}/varpn_proxy_${node.id.hashCode}.json',
      );
      await configFile.writeAsString(jsonEncode(configJson));

      final process = await Process.start(
        xrayRuntime.executablePath,
        ['-c', configFile.path],
        workingDirectory: xrayRuntime.workingDirectory,
        environment: {
          'XRAY_LOCATION_ASSET': assetDirectory,
        },
        mode: ProcessStartMode.normal,
        includeParentEnvironment: true,
      );

      _xrayProcess = process;
      _attachProcessStreams(process);
      unawaited(_watchProcessExit(process));
      await _waitForLocalProxy(process);

      if (!_proxyConfigured) {
        await _applySystemProxy();
      }

      _currentNode = node;
      final proxyHealth = await _verifyProxyHealth(
        allowRepair: false,
        forceTrafficProbe: true,
      );
      await _applyProxyHealth(
        proxyHealth,
        reason: reconnectReason ?? 'connect',
      );

      _shouldAutoReconnect = true;
      _isReconnecting = false;
      _unexpectedReconnectFailures = 0;
      _lastReconnectReason = reconnectReason;
      _lastCrashReason = null;
      _lastXrayExitCode = null;

      _startTrafficPolling();
      await _refreshTrafficStats();
      await _writeHealthSnapshot(
        nativeState: proxyHealth.nativeState,
        xrayRunning: true,
        lastReconnectReason: reconnectReason,
      );
      _updateStatus(ConnectionStatus.connected);
      AppLogService.instance.info(
        source: 'vpn',
        message: 'Connected to ${node.name} through the system SOCKS proxy.',
      );
      return true;
    } catch (error) {
      AppLogService.instance.error(
        source: 'vpn',
        message: 'Proxy connection error: $error',
      );
      _updateStatus(ConnectionStatus.error);
      await _stopRuntimeOnly();
      if (_proxyConfigured) {
        try {
          await _restoreSystemProxy(allowPrompt: false);
        } catch (restoreError) {
          AppLogService.instance.warning(
            source: 'proxy',
            message:
                'Failed to restore the system proxy after a connection error: $restoreError',
          );
        }
      }
      _proxyConfigurationHealthy = false;
      _proxyReachable = false;
      _protectedServiceCount = 0;
      _totalServiceCount = 0;
      _lastProxyError = error.toString();
      await _writeHealthSnapshot(
        nativeState: 'error',
        xrayRunning: false,
        lastCrashReason: error.toString(),
      );
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _disconnectInternal(
      userInitiated: true,
      finalizeSession: true,
    );
  }

  Future<void> _disconnectInternal({
    required bool userInitiated,
    required bool finalizeSession,
  }) async {
    if (userInitiated) {
      _shouldAutoReconnect = false;
      _isReconnecting = false;
    }

    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnecting);
    }

    if (_proxyConfigured) {
      try {
        await _restoreSystemProxy(allowPrompt: userInitiated);
      } catch (error) {
        AppLogService.instance.warning(
          source: 'proxy',
          message: 'Failed to restore system proxy: $error',
        );
      }
    }

    if (finalizeSession) {
      await _refreshTrafficStats();
      await _finalizeCurrentSession();
    }

    await _stopRuntimeOnly();

    if (userInitiated) {
      _currentNode = null;
    }

    _proxyConfigurationHealthy = false;
    _proxyReachable = false;
    _protectedServiceCount = 0;
    _totalServiceCount = 0;
    _lastProxyError = null;
    _lastAnnouncedProxyIssue = null;
    _lastProxyProbeAt = null;
    _consecutiveProxyProbeFailures = 0;

    await _writeHealthSnapshot(
      nativeState: 'disconnected',
      xrayRunning: false,
    );
    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnected);
    }
  }

  Future<void> _stopRuntimeOnly() async {
    _trafficTimer?.cancel();
    _trafficTimer = null;

    final process = _xrayProcess;
    _xrayProcess = null;
    if (process == null) {
      await _cancelProcessStreams();
      return;
    }

    _isStoppingRuntime = true;
    try {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    } finally {
      _isStoppingRuntime = false;
      await _cancelProcessStreams();
    }
  }

  Future<void> _cancelProcessStreams() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
  }

  void _attachProcessStreams(Process process) {
    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleXrayLogLine);
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleXrayLogLine);
  }

  void _handleXrayLogLine(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty) {
      return;
    }

    _lastXrayLogLine = normalized;
    final lower = normalized.toLowerCase();
    if (lower.contains('error') || lower.contains('failed')) {
      AppLogService.instance.warning(
        source: 'xray',
        message: normalized,
      );
    }
  }

  Future<void> _watchProcessExit(Process process) async {
    final exitCode = await process.exitCode;
    if (_xrayProcess != null && !identical(_xrayProcess, process)) {
      return;
    }

    _lastXrayExitCode = exitCode;
    _xrayProcess = null;
    _trafficTimer?.cancel();
    _trafficTimer = null;

    if (_isStoppingRuntime || _isDisposed) {
      await _writeHealthSnapshot(
        nativeState: 'disconnected',
        xrayRunning: false,
        lastXrayExitCode: exitCode,
      );
      return;
    }

    final crashReason = _lastXrayLogLine ?? 'Xray exited with code $exitCode.';
    _lastCrashReason = crashReason;
    AppLogService.instance.warning(
      source: 'xray',
      message: crashReason,
    );

    await _preserveSessionProgressForReconnect();
    await _writeHealthSnapshot(
      nativeState: 'disconnected',
      xrayRunning: false,
      lastCrashReason: crashReason,
      lastXrayExitCode: exitCode,
    );

    if (_shouldAutoReconnect && _currentNode != null && !_isReconnecting) {
      _isReconnecting = true;
      _updateStatus(ConnectionStatus.connecting);
      AppLogService.instance.warning(
        source: 'vpn',
        message:
            'Proxy runtime stopped unexpectedly. Reconnecting to ${_currentNode!.name}.',
      );
      unawaited(
        _attemptReconnect(
          reconnectReason: 'unexpected disconnect',
        ),
      );
      return;
    }

    _updateStatus(ConnectionStatus.disconnected);
  }

  Future<void> _handleAppResume() async {
    await _reconcileRuntimeState(reason: 'resume');
  }

  Future<void> _reconcileRuntimeState({required String reason}) async {
    if (_isDisposed || _status == ConnectionStatus.connecting) {
      return;
    }

    try {
      final processAlive = await _isRuntimeAlive();
      await _refreshTrafficStats(logErrors: false);

      if (processAlive) {
        final proxyHealth = await _verifyProxyHealth(
          allowRepair: true,
          forceTrafficProbe: _shouldProbeTraffic(reason),
        );
        await _applyProxyHealth(
          proxyHealth,
          reason: reason,
        );

        if (_status != ConnectionStatus.connected) {
          _updateStatus(ConnectionStatus.connected);
          AppLogService.instance.info(
            source: 'vpn',
            message: 'Reconciled proxy runtime to connected after $reason.',
          );
        }
        await _writeHealthSnapshot(
          nativeState: proxyHealth.nativeState,
          xrayRunning: true,
        );

        if (_shouldAutoReconnect &&
            _currentNode != null &&
            !_isReconnecting &&
            proxyHealth.shouldReconnect &&
            (_consecutiveProxyProbeFailures >= 2 || reason != 'watchdog')) {
          _isReconnecting = true;
          await _preserveSessionProgressForReconnect();
          _updateStatus(ConnectionStatus.connecting);
          AppLogService.instance.warning(
            source: 'vpn',
            message:
                'Proxy traffic is unhealthy for ${_currentNode!.name}. Reconnecting after $reason.',
          );
          unawaited(
            _attemptReconnect(
              reconnectReason:
                  proxyHealth.issue ?? 'proxy traffic health check failed',
            ),
          );
        }
        return;
      }

      final wasThoughtConnected = _status == ConnectionStatus.connected ||
          _status == ConnectionStatus.disconnecting;
      if (wasThoughtConnected) {
        AppLogService.instance.warning(
          source: 'vpn',
          message: 'Proxy runtime is not running during $reason check.',
        );
      }

      if (_status != ConnectionStatus.disconnected) {
        _updateStatus(ConnectionStatus.disconnected);
      }

      await _writeHealthSnapshot(
        nativeState: 'disconnected',
        xrayRunning: false,
      );

      if (_shouldAutoReconnect &&
          _currentNode != null &&
          !_isReconnecting &&
          wasThoughtConnected) {
        _isReconnecting = true;
        await _preserveSessionProgressForReconnect();
        AppLogService.instance.warning(
          source: 'vpn',
          message:
              'Proxy runtime dropped unexpectedly. Reconnecting to ${_currentNode!.name} after $reason.',
        );
        unawaited(
          _attemptReconnect(
            reconnectReason: 'unexpected disconnect after $reason',
          ),
        );
      }
    } catch (error) {
      AppLogService.instance.warning(
        source: 'vpn',
        message: 'Failed to reconcile proxy runtime during $reason: $error',
      );
    }
  }

  Future<void> _attemptReconnect({
    required String reconnectReason,
  }) async {
    final node = _currentNode;
    if (node == null || _isDisposed) {
      _isReconnecting = false;
      return;
    }

    try {
      final recovered = await _connectInternal(
        node,
        reconnectReason: reconnectReason,
        preserveSession: true,
      );
      if (recovered) {
        return;
      }

      _unexpectedReconnectFailures += 1;
      if (_unexpectedReconnectFailures < 2 || _resolveFailoverNode == null) {
        await _finalizeCurrentSession();
        _updateStatus(ConnectionStatus.disconnected);
        return;
      }

      final failoverNode = await _resolveFailoverNode!.call(node);
      if (failoverNode == null || failoverNode.id == node.id) {
        AppLogService.instance.error(
          source: 'vpn',
          message:
              'Same-country failover was unavailable after repeated reconnect failures for ${node.name}.',
        );
        await _finalizeCurrentSession();
        _updateStatus(ConnectionStatus.disconnected);
        return;
      }

      AppLogService.instance.warning(
        source: 'vpn',
        message:
            'Reconnecting through fallback node ${failoverNode.name} after repeated failures for ${node.name}.',
      );
      final failoverRecovered = await _connectInternal(
        failoverNode,
        reconnectReason: 'same-country failover',
        preserveSession: true,
      );
      if (!failoverRecovered) {
        await _finalizeCurrentSession();
        _updateStatus(ConnectionStatus.disconnected);
      }
    } finally {
      _isReconnecting = false;
    }
  }

  void _startFreshSession() {
    _sessionAccumulatedUplinkBytes = 0;
    _sessionAccumulatedDownlinkBytes = 0;
    _liveSessionUplinkBytes = 0;
    _liveSessionDownlinkBytes = 0;
    _currentSessionStartedAt = DateTime.now();
  }

  Future<void> _preserveSessionProgressForReconnect() async {
    _sessionAccumulatedUplinkBytes += _liveSessionUplinkBytes;
    _sessionAccumulatedDownlinkBytes += _liveSessionDownlinkBytes;
    _liveSessionUplinkBytes = 0;
    _liveSessionDownlinkBytes = 0;
    await _writeTrafficSnapshot();
  }

  Future<void> _finalizeCurrentSession() async {
    final sessionUplink =
        _sessionAccumulatedUplinkBytes + _liveSessionUplinkBytes;
    final sessionDownlink =
        _sessionAccumulatedDownlinkBytes + _liveSessionDownlinkBytes;

    _committedTotalUplinkBytes += sessionUplink;
    _committedTotalDownlinkBytes += sessionDownlink;
    _lastSessionUplinkBytes = sessionUplink;
    _lastSessionDownlinkBytes = sessionDownlink;
    _sessionAccumulatedUplinkBytes = 0;
    _sessionAccumulatedDownlinkBytes = 0;
    _liveSessionUplinkBytes = 0;
    _liveSessionDownlinkBytes = 0;
    _currentSessionStartedAt = null;
    await _writeTrafficSnapshot();
  }

  Future<void> _startTrafficPolling() async {
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(
      _trafficPollInterval,
      (_) => unawaited(_refreshTrafficStats(logErrors: false)),
    );
  }

  Future<void> _refreshTrafficStats({bool logErrors = true}) async {
    final process = _xrayProcess;
    if (process == null) {
      return;
    }

    try {
      final counters = await _queryTrafficCounters();
      _liveSessionUplinkBytes = counters.uplinkBytes;
      _liveSessionDownlinkBytes = counters.downlinkBytes;
      await _writeTrafficSnapshot();
      await _writeHealthSnapshot(
        nativeState: _proxyConfigurationHealthy && _proxyReachable
            ? 'connected'
            : 'degraded',
        xrayRunning: true,
      );
    } catch (error) {
      if (logErrors) {
        AppLogService.instance.warning(
          source: 'stats',
          message: 'Traffic stats query failed: $error',
        );
      }
    }
  }

  Future<_TrafficCounters> _queryTrafficCounters() async {
    final runtime = _resolveXrayRuntime();
    final result = await Process.run(
      runtime.executablePath,
      [
        'api',
        'statsquery',
        '--server=127.0.0.1:$apiPort',
        '-timeout',
        '3',
        '-pattern',
        'outbound>>>proxy>>>traffic>>>',
      ],
      workingDirectory: runtime.workingDirectory,
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw Exception(stderr.isEmpty ? 'Unknown Xray API error' : stderr);
    }

    final decoded = jsonDecode(result.stdout.toString());
    if (decoded is! Map) {
      throw Exception('Traffic stats response was not valid JSON.');
    }

    final stats = decoded['stat'];
    if (stats is! List) {
      throw Exception('Traffic stats payload did not contain a stat array.');
    }

    var uplinkBytes = 0;
    var downlinkBytes = 0;
    for (final entry in stats.whereType<Map>()) {
      final name = entry['name']?.toString() ?? '';
      final value = _readInt(entry['value']);
      if (name.endsWith('>>>uplink')) {
        uplinkBytes = value;
      } else if (name.endsWith('>>>downlink')) {
        downlinkBytes = value;
      }
    }

    return _TrafficCounters(
      uplinkBytes: uplinkBytes.clamp(0, 1 << 62),
      downlinkBytes: downlinkBytes.clamp(0, 1 << 62),
    );
  }

  Future<void> _writeTrafficSnapshot() async {
    await RuntimeSnapshotStore.writeTrafficStats(
      {
        'totalUplinkBytes': _committedTotalUplinkBytes +
            _sessionAccumulatedUplinkBytes +
            _liveSessionUplinkBytes,
        'totalDownlinkBytes': _committedTotalDownlinkBytes +
            _sessionAccumulatedDownlinkBytes +
            _liveSessionDownlinkBytes,
        'lastSessionUplinkBytes': _lastSessionUplinkBytes,
        'lastSessionDownlinkBytes': _lastSessionDownlinkBytes,
        'currentSessionUplinkBytes':
            _sessionAccumulatedUplinkBytes + _liveSessionUplinkBytes,
        'currentSessionDownlinkBytes':
            _sessionAccumulatedDownlinkBytes + _liveSessionDownlinkBytes,
        'currentSessionStartedAt': _currentSessionStartedAt?.toIso8601String(),
      },
    );
  }

  Future<void> _writeHealthSnapshot({
    required String nativeState,
    required bool xrayRunning,
    String? lastReconnectReason,
    String? lastCrashReason,
    int? lastXrayExitCode,
  }) async {
    final residentMemoryBytes = await _readResidentMemoryBytes();
    await RuntimeSnapshotStore.writeTunnelHealth(
      {
        'updatedAt': DateTime.now().toIso8601String(),
        'nativeState': nativeState,
        'xrayRunning': xrayRunning,
        'residentMemoryBytes': residentMemoryBytes,
        'memoryPressure': _classifyMemoryPressure(residentMemoryBytes),
        'lastReconnectReason': lastReconnectReason ?? _lastReconnectReason,
        'lastCrashReason': lastCrashReason ?? _lastCrashReason,
        'lastXrayExitCode': lastXrayExitCode ?? _lastXrayExitCode,
        'proxyConfigured': _proxyConfigurationHealthy,
        'proxyReachable': _proxyReachable,
        'protectedServiceCount': _protectedServiceCount,
        'totalServiceCount': _totalServiceCount,
        'lastProxyError': _lastProxyError,
      },
    );
  }

  Future<int> _readResidentMemoryBytes() async {
    final process = _xrayProcess;
    if (process == null) {
      return 0;
    }

    try {
      final result = await Process.run(
        _psPath,
        ['-o', 'rss=', '-p', '${process.pid}'],
      );
      if (result.exitCode != 0) {
        return 0;
      }
      final kilobytes = int.tryParse(result.stdout.toString().trim()) ?? 0;
      return kilobytes * 1024;
    } catch (_) {
      return 0;
    }
  }

  String _classifyMemoryPressure(int residentMemoryBytes) {
    if (residentMemoryBytes >= 256 * 1024 * 1024) {
      return 'critical';
    }
    if (residentMemoryBytes >= 128 * 1024 * 1024) {
      return 'high';
    }
    if (residentMemoryBytes >= 64 * 1024 * 1024) {
      return 'moderate';
    }
    return residentMemoryBytes == 0 ? 'unknown' : 'normal';
  }

  Future<void> _waitForLocalProxy(Process process) async {
    final deadline = DateTime.now().add(_proxyStartupTimeout);

    while (DateTime.now().isBefore(deadline)) {
      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 50),
        onTimeout: () => -9999,
      );
      if (exitCode != -9999) {
        final details = _lastXrayLogLine;
        throw Exception(
          details == null
              ? 'Xray exited with code $exitCode'
              : 'Xray exited with code $exitCode: $details',
        );
      }

      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          localPort,
          timeout: const Duration(milliseconds: 250),
        );
        await socket.close();
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    final details = _lastXrayLogLine;
    throw Exception(
      details == null
          ? 'Timed out waiting for the local SOCKS proxy'
          : 'Timed out waiting for the local SOCKS proxy: $details',
    );
  }

  Future<void> _applySystemProxy() async {
    final services = await _listEnabledNetworkServices();
    if (services.isEmpty) {
      throw Exception('No enabled macOS network services were found.');
    }

    final states = await _captureProxyStates(services);
    await RuntimeSnapshotStore.writeProxyState(
      {
        'services': states.map((state) => state.toJson()).toList(),
      },
    );

    await _configureLocalProxyForServices(
      services,
      allowPrompt: true,
    );
    _proxyConfigured = true;
    AppLogService.instance.info(
      source: 'proxy',
      message:
          'Enabled the system SOCKS proxy for ${services.length} network service(s).',
    );
  }

  Future<void> _restoreSystemProxy({required bool allowPrompt}) async {
    final snapshot = await RuntimeSnapshotStore.readProxyState();
    final rawServices = snapshot['services'];
    final previousStates = rawServices is List
        ? rawServices
            .whereType<Map>()
            .map(
              (entry) => _NetworkServiceProxyState.fromJson(
                entry.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList()
        : <_NetworkServiceProxyState>[];

    final commands = <List<String>>[];
    if (previousStates.isEmpty) {
      final services = await _listEnabledNetworkServices();
      for (final service in services) {
        commands.add([
          _networksetupPath,
          '-setsocksfirewallproxystate',
          service,
          'off',
        ]);
      }
    } else {
      for (final state in previousStates) {
        if (state.enabled && state.server.isNotEmpty && state.port > 0) {
          commands.add([
            _networksetupPath,
            '-setsocksfirewallproxy',
            state.name,
            state.server,
            '${state.port}',
            'off',
          ]);
          commands.add([
            _networksetupPath,
            '-setsocksfirewallproxystate',
            state.name,
            'on',
          ]);
        } else {
          commands.add([
            _networksetupPath,
            '-setsocksfirewallproxystate',
            state.name,
            'off',
          ]);
        }
      }
    }

    if (commands.isNotEmpty) {
      await _runNetworksetupCommands(
        commands,
        allowPrompt: allowPrompt,
      );
    }

    _proxyConfigured = false;
    await RuntimeSnapshotStore.clearProxyState();
    AppLogService.instance.info(
      source: 'proxy',
      message: 'Restored the previous macOS SOCKS proxy configuration.',
    );
  }

  Future<void> _configureLocalProxyForServices(
    List<String> services, {
    required bool allowPrompt,
  }) async {
    final commands = <List<String>>[
      for (final service in services) ...[
        [
          _networksetupPath,
          '-setsocksfirewallproxy',
          service,
          _loopbackHost,
          '$localPort',
          'off',
        ],
        [
          _networksetupPath,
          '-setsocksfirewallproxystate',
          service,
          'on',
        ],
      ],
    ];

    await _runNetworksetupCommands(
      commands,
      allowPrompt: allowPrompt,
    );
  }

  Future<_ProxyHealthCheckResult> _verifyProxyHealth({
    required bool allowRepair,
    required bool forceTrafficProbe,
  }) async {
    final services = await _listEnabledNetworkServices();
    if (services.isEmpty) {
      return const _ProxyHealthCheckResult(
        configurationHealthy: false,
        trafficHealthy: false,
        protectedServiceCount: 0,
        totalServiceCount: 0,
        probePerformed: false,
        issue: 'No enabled macOS network services were found.',
      );
    }

    var protectedServiceCount = 0;
    var configurationHealthy = false;
    String? issue;

    Future<void> inspectCurrentState() async {
      final states = await _captureProxyStates(services);
      protectedServiceCount = states
          .where(
            (state) =>
                state.enabled &&
                state.server == _loopbackHost &&
                state.port == localPort,
          )
          .length;
      configurationHealthy = protectedServiceCount == services.length;
      issue = _describeProxyConfigurationIssue(
        protectedServiceCount: protectedServiceCount,
        totalServiceCount: services.length,
      );
    }

    await inspectCurrentState();

    if (!configurationHealthy && allowRepair) {
      try {
        await _configureLocalProxyForServices(
          services,
          allowPrompt: false,
        );
        await inspectCurrentState();
      } catch (error) {
        issue = 'Failed to re-apply the system SOCKS proxy: $error';
      }
    }

    var trafficHealthy = configurationHealthy ? _proxyReachable : false;
    var probePerformed = false;
    if (configurationHealthy &&
        _currentNode != null &&
        _xrayProcess != null &&
        forceTrafficProbe) {
      probePerformed = true;
      try {
        await _probeProxyTraffic();
        trafficHealthy = true;
      } catch (error) {
        trafficHealthy = false;
        issue ??=
            'Traffic stopped passing through the local SOCKS proxy: $error';
      } finally {
        _lastProxyProbeAt = DateTime.now();
      }
    }

    return _ProxyHealthCheckResult(
      configurationHealthy: configurationHealthy,
      trafficHealthy: trafficHealthy,
      protectedServiceCount: protectedServiceCount,
      totalServiceCount: services.length,
      probePerformed: probePerformed,
      issue: issue,
    );
  }

  Future<void> _probeProxyTraffic() async {
    final result = await Process.run(
      _curlPath,
      [
        '-sS',
        '-o',
        '/dev/null',
        '-w',
        '%{http_code}',
        '--socks5-hostname',
        '$_loopbackHost:$localPort',
        '--connect-timeout',
        '4',
        '--max-time',
        '8',
        _healthCheckUrl,
      ],
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw Exception(
          stderr.isEmpty ? 'curl exited with ${result.exitCode}' : stderr);
    }

    final statusCode = int.tryParse(result.stdout.toString().trim()) ?? 0;
    if (statusCode <= 0) {
      throw Exception('curl did not receive an HTTP response');
    }
  }

  bool _shouldProbeTraffic(String reason) {
    if (reason != 'watchdog') {
      return true;
    }

    final lastProbeAt = _lastProxyProbeAt;
    if (lastProbeAt == null) {
      return true;
    }

    return DateTime.now().difference(lastProbeAt) >= _proxyHealthProbeInterval;
  }

  String get _healthCheckUrl {
    final raw = _readPingSettings().url.trim();
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return raw;
    }
    return PingSettings.defaultUrl;
  }

  String? _describeProxyConfigurationIssue({
    required int protectedServiceCount,
    required int totalServiceCount,
  }) {
    if (totalServiceCount == 0) {
      return 'No enabled macOS network services were found.';
    }
    if (protectedServiceCount >= totalServiceCount) {
      return null;
    }
    if (protectedServiceCount == 0) {
      return 'The macOS system SOCKS proxy is disabled.';
    }
    return 'The macOS system SOCKS proxy is only active on $protectedServiceCount of $totalServiceCount network services.';
  }

  Future<void> _applyProxyHealth(
    _ProxyHealthCheckResult result, {
    required String reason,
  }) async {
    _proxyConfigurationHealthy = result.configurationHealthy;
    _proxyReachable = result.trafficHealthy;
    _protectedServiceCount = result.protectedServiceCount;
    _totalServiceCount = result.totalServiceCount;
    _lastProxyError = result.issue;

    if (result.probePerformed && result.trafficHealthy) {
      _consecutiveProxyProbeFailures = 0;
    } else if (result.probePerformed && !result.trafficHealthy) {
      _consecutiveProxyProbeFailures += 1;
    }

    if (result.issue != _lastAnnouncedProxyIssue) {
      if (result.issue == null) {
        AppLogService.instance.info(
          source: 'proxy',
          message: 'Proxy protection is healthy again after $reason.',
        );
      } else {
        AppLogService.instance.warning(
          source: 'proxy',
          message: result.issue!,
        );
      }
      _lastAnnouncedProxyIssue = result.issue;
    }
  }

  Future<void> _cleanupStaleProxyConfiguration() async {
    final services = await _listEnabledNetworkServices();
    if (services.isEmpty) {
      return;
    }

    final states = await _captureProxyStates(services);
    final staleStates = states
        .where(
          (state) =>
              state.enabled &&
              state.server == _loopbackHost &&
              state.port == localPort,
        )
        .toList();
    if (staleStates.isEmpty) {
      return;
    }

    AppLogService.instance.warning(
      source: 'proxy',
      message:
          'Detected a stale VarPN SOCKS proxy configuration from a previous session. Attempting cleanup.',
    );

    try {
      await _restoreSystemProxy(allowPrompt: false);
    } catch (error) {
      AppLogService.instance.warning(
        source: 'proxy',
        message: 'Failed to clean up stale SOCKS proxy settings: $error',
      );
    }
  }

  Future<List<String>> _listEnabledNetworkServices() async {
    final result = await Process.run(
      _networksetupPath,
      ['-listallnetworkservices'],
    );
    if (result.exitCode != 0) {
      throw Exception(
        result.stderr.toString().trim().isEmpty
            ? 'networksetup -listallnetworkservices failed'
            : result.stderr.toString().trim(),
      );
    }

    return LineSplitter.split(result.stdout.toString())
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('An asterisk'))
        .where((line) => !line.startsWith('*'))
        .toList();
  }

  Future<List<_NetworkServiceProxyState>> _captureProxyStates(
    List<String> services,
  ) async {
    final states = <_NetworkServiceProxyState>[];
    for (final service in services) {
      final result = await Process.run(
        _networksetupPath,
        ['-getsocksfirewallproxy', service],
      );
      if (result.exitCode != 0) {
        throw Exception(
          result.stderr.toString().trim().isEmpty
              ? 'Failed to query SOCKS proxy state for $service'
              : result.stderr.toString().trim(),
        );
      }

      final values = <String, String>{};
      for (final line in LineSplitter.split(result.stdout.toString())) {
        final parts = line.split(':');
        if (parts.length < 2) {
          continue;
        }
        values[parts.first.trim()] = parts.sublist(1).join(':').trim();
      }

      final enabled = (values['Enabled'] ?? '').toLowerCase() == 'yes';
      states.add(
        _NetworkServiceProxyState(
          name: service,
          enabled: enabled,
          server: values['Server'] ?? '',
          port: int.tryParse(values['Port'] ?? '') ?? 0,
        ),
      );
    }
    return states;
  }

  Future<void> _runNetworksetupCommands(
    List<List<String>> commands, {
    required bool allowPrompt,
  }) async {
    String? directFailure;
    for (final command in commands) {
      final executable = command.first;
      final args = command.sublist(1);
      final result = await Process.run(
        executable,
        args,
      );
      if (result.exitCode == 0) {
        continue;
      }

      directFailure = result.stderr.toString().trim();
      if (directFailure.isEmpty) {
        directFailure = result.stdout.toString().trim();
      }
      break;
    }

    if (directFailure == null) {
      return;
    }

    if (!allowPrompt) {
      throw Exception(directFailure);
    }

    final shellScript = commands
        .map((command) => command.map(_shellQuote).join(' '))
        .join(' && ');
    final script = 'do shell script "${_appleScriptQuote(shellScript)}" '
        'with administrator privileges';
    final result = await Process.run(
      _osascriptPath,
      ['-e', script],
    );
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw Exception(stderr.isEmpty ? directFailure : stderr);
    }
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  String _appleScriptQuote(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  Future<bool> _isRuntimeAlive() async {
    final process = _xrayProcess;
    if (process == null) {
      return false;
    }

    final exitCode = await process.exitCode.timeout(
      const Duration(milliseconds: 50),
      onTimeout: () => -9999,
    );
    return exitCode == -9999;
  }

  @override
  Future<TunnelHealth?> readTunnelHealth() async {
    final snapshot = await RuntimeSnapshotStore.readTunnelHealth();
    if (snapshot.isEmpty) {
      return null;
    }
    return TunnelHealth.fromJson(snapshot);
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
    TunnelSettings tunnelSettings,
    XraySettings xraySettings,
  ) {
    final preset = routingSettings.selectedPreset;
    final dnsConfig = _buildDnsConfig(
      routingSettings,
      tunnelSettings,
    );
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
      'log': {'loglevel': xraySettings.logLevel},
      'stats': <String, dynamic>{},
      'policy': {
        'system': {
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true,
        }
      },
      'api': {
        'tag': 'api',
        'listen': '127.0.0.1:$apiPort',
        'services': ['StatsService'],
      },
      if (dnsConfig != null) 'dns': dnsConfig,
      if (fakeDnsConfig.isNotEmpty) 'fakedns': fakeDnsConfig,
      'routing': routingConfig,
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'port': localPort,
          'protocol': 'socks',
          'settings': {'udp': true},
          'sniffing': {
            'enabled': xraySettings.sniffingEnabled,
            'destOverride': [
              'http',
              'tls',
              'quic',
              if (preset.fakeDnsEnabled) 'fakedns',
            ],
          },
        }
      ],
      'outbounds': outbounds,
    };
  }

  Map<String, dynamic> _withApiRoutingRule(
    Map<String, dynamic>? routingConfig,
  ) {
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

  Map<String, dynamic>? _buildDnsConfig(
    RoutingSettings routingSettings,
    TunnelSettings tunnelSettings,
  ) {
    if (tunnelSettings.dnsMode == 'custom') {
      final servers = _resolveDnsServers(
        routingSettings,
        tunnelSettings,
      );
      return {
        'servers': [
          for (final server in servers) {'address': server},
        ],
      };
    }

    return RoutingService.buildDnsConfig(routingSettings);
  }

  Map<String, dynamic> _buildDirectOutbound() {
    return {'protocol': 'freedom', 'tag': 'direct'};
  }

  Map<String, dynamic> _buildBlockOutbound() {
    return {'protocol': 'blackhole', 'tag': 'block'};
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

    final streamSettings = <String, dynamic>{
      'network': network,
      'security': security,
    };

    if (security == 'tls') {
      streamSettings['tlsSettings'] = <String, dynamic>{
        'serverName': node.sni ??
            rawConfig['sni'] ??
            rawConfig['serverName'] ??
            node.server,
        'allowInsecure': _parseBool(rawConfig['allowInsecure']) ??
            xraySettings.allowInsecure,
      };

      final fingerprint = rawConfig['fp']?.toString();
      final alpn = rawConfig['alpn']?.toString();
      if (fingerprint != null && fingerprint.isNotEmpty) {
        streamSettings['tlsSettings']['fingerprint'] = fingerprint;
      }
      if (alpn != null && alpn.isNotEmpty) {
        streamSettings['tlsSettings']['alpn'] = alpn
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
      }
    } else if (security == 'reality') {
      streamSettings['realitySettings'] = <String, dynamic>{
        'fingerprint': rawConfig['fp']?.toString() ??
            rawConfig['fingerprint']?.toString() ??
            'chrome',
        'serverName': node.sni ?? rawConfig['sni'] ?? node.server,
        'publicKey': node.realityPubKey ?? '',
        'shortId': node.realityShortId ?? '',
        'spiderX': rawConfig['spx']?.toString() ?? node.path ?? '',
      };
    }

    if (network == 'ws') {
      streamSettings['wsSettings'] = {
        'path': node.path ?? '/',
        'headers': {'Host': node.host ?? node.sni ?? ''},
      };
    } else if (network == 'xhttp') {
      streamSettings['xhttpSettings'] = {
        'path': node.path ?? '/',
        'host': node.host ?? node.sni ?? '',
        'mode': rawConfig['mode']?.toString() ?? 'auto',
      };
    } else if (network == 'grpc') {
      streamSettings['grpcSettings'] = {
        'serviceName': rawConfig['serviceName']?.toString() ?? node.path ?? '',
      };
    }

    final outbound = <String, dynamic>{
      'protocol': protocol,
      'streamSettings': streamSettings,
      'tag': 'proxy',
    };

    if (protocol == 'vless') {
      final user = <String, dynamic>{
        'id': node.userId ?? '',
        'encryption': node.encryption ?? 'none',
      };
      if (node.flow != null && node.flow!.isNotEmpty) {
        user['flow'] = node.flow;
      }

      outbound['settings'] = {
        'vnext': [
          {
            'address': node.server,
            'port': node.port,
            'users': [user],
          }
        ]
      };
    } else if (protocol == 'vmess') {
      outbound['settings'] = {
        'vnext': [
          {
            'address': node.server,
            'port': node.port,
            'users': [
              {
                'id': node.userId ?? '',
                'alterId':
                    int.tryParse(rawConfig['aid']?.toString() ?? '0') ?? 0,
                'security': node.encryption ?? rawConfig['scy'] ?? 'auto',
              }
            ],
          }
        ]
      };
    } else if (protocol == 'trojan') {
      outbound['settings'] = {
        'servers': [
          {
            'address': node.server,
            'port': node.port,
            'password': node.userId ?? '',
          }
        ]
      };
    } else if (protocol == 'ss') {
      outbound['settings'] = {
        'servers': [
          {
            'address': node.server,
            'port': node.port,
            'password': node.userId ?? '',
            'method': node.encryption ?? 'aes-256-gcm',
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

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
    _trafficTimer?.cancel();
    _lifecycleListener?.dispose();
    unawaited(_writeHealthSnapshot(
      nativeState: 'disposed',
      xrayRunning: false,
    ));
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

class _TrafficCounters {
  final int uplinkBytes;
  final int downlinkBytes;

  const _TrafficCounters({
    required this.uplinkBytes,
    required this.downlinkBytes,
  });
}

class _ProxyHealthCheckResult {
  final bool configurationHealthy;
  final bool trafficHealthy;
  final int protectedServiceCount;
  final int totalServiceCount;
  final bool probePerformed;
  final String? issue;

  const _ProxyHealthCheckResult({
    required this.configurationHealthy,
    required this.trafficHealthy,
    required this.protectedServiceCount,
    required this.totalServiceCount,
    required this.probePerformed,
    required this.issue,
  });

  bool get isHealthy => configurationHealthy && trafficHealthy;

  bool get shouldReconnect =>
      configurationHealthy && probePerformed && !trafficHealthy;

  String get nativeState => isHealthy ? 'connected' : 'degraded';
}

class _NetworkServiceProxyState {
  final String name;
  final bool enabled;
  final String server;
  final int port;

  const _NetworkServiceProxyState({
    required this.name,
    required this.enabled,
    required this.server,
    required this.port,
  });

  factory _NetworkServiceProxyState.fromJson(Map<String, dynamic> json) {
    return _NetworkServiceProxyState(
      name: json['name']?.toString() ?? '',
      enabled: json['enabled'] == true,
      server: json['server']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'enabled': enabled,
      'server': server,
      'port': port,
    };
  }
}
