import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/ping_settings.dart';
import '../models/vpn_node.dart';
import 'app_log_service.dart';
import 'geodata_service.dart';
import 'macos_tunnel_bridge.dart';
import 'xray_config_builder.dart';

class ConnectivityTester {
  static const int _failedLatency = 9999;
  static const Duration _socketTimeout = Duration(seconds: 4);
  static final RegExp _icmpTimePattern = RegExp(r'time[=<]([\d.]+)\s*ms');
  static const String _macCurlPath = '/usr/bin/curl';
  static const String _macPingPath = '/sbin/ping';

  static Future<VpnNode> measureNode(
    VpnNode node,
    PingSettings settings,
  ) async {
    final latency = switch (settings.protocol) {
      'icmp' => await _testIcmp(node, settings: settings),
      'tcp' => await _testTcpThroughProxy(node, settings: settings),
      'proxy_get' => await _testProxyRequest(
          node,
          settings: settings,
          method: 'GET',
        ),
      'proxy_head' => await _testProxyRequest(
          node,
          settings: settings,
          method: 'HEAD',
        ),
      _ => await _testTcpThroughProxy(node, settings: settings),
    };

    final isAvailable = latency > 0 && latency < _failedLatency;
    if (settings.usesProxyTransport) {
      return node.copyWith(
        ping: 0,
        httpResponseTime: latency,
        isAvailable: isAvailable,
      );
    }

    return node.copyWith(
      ping: latency,
      httpResponseTime: 0,
      isAvailable: isAvailable,
    );
  }

  static Future<List<VpnNode>> measureNodes(
    List<VpnNode> nodes,
    PingSettings settings,
  ) async {
    final measured = <VpnNode>[];
    for (final node in nodes) {
      measured.add(await measureNode(node, settings));
    }
    return measured;
  }

  static Future<int> testPing(VpnNode node) {
    return _testTcpThroughProxy(node, settings: PingSettings.defaults());
  }

  static Future<int> testHttpResponseTime(VpnNode node) {
    return _testProxyRequest(
      node,
      settings: PingSettings.defaults(),
      method: 'HEAD',
    );
  }

  static Future<void> testNodes(List<VpnNode> nodes) async {
    await measureNodes(nodes, PingSettings.defaults());
  }

  static VpnNode? findBestNode(List<VpnNode> nodes) {
    if (nodes.isEmpty) return null;

    final sortedNodes = List<VpnNode>.from(nodes);

    sortedNodes.sort((a, b) {
      final availabilityCompare =
          _availabilityRank(a).compareTo(_availabilityRank(b));
      if (availabilityCompare != 0) return availabilityCompare;

      final pingCompare = _scorePing(a).compareTo(_scorePing(b));
      if (pingCompare != 0) return pingCompare;

      final httpCompare = _scoreHttp(a).compareTo(_scoreHttp(b));
      if (httpCompare != 0) return httpCompare;

      return a.name.compareTo(b.name);
    });

    return sortedNodes.first;
  }

  static int _availabilityRank(VpnNode node) {
    if (_isAvailable(node)) {
      return 0;
    }

    if (node.ping > 0 || node.httpResponseTime > 0) {
      return 2;
    }

    return 1;
  }

  static bool _isAvailable(VpnNode node) {
    if (node.isAvailable) {
      return true;
    }

    final hasHealthyPing = node.ping > 0 && node.ping < _failedLatency;
    final hasHealthyHttp =
        node.httpResponseTime > 0 && node.httpResponseTime < _failedLatency;
    return hasHealthyPing || hasHealthyHttp;
  }

  static int _scorePing(VpnNode node) {
    if (node.ping > 0 && node.ping < _failedLatency) {
      return node.ping;
    }

    if (node.httpResponseTime > 0 && node.httpResponseTime < _failedLatency) {
      return node.httpResponseTime;
    }

    return _failedLatency;
  }

  static int _scoreHttp(VpnNode node) {
    if (node.httpResponseTime > 0) {
      return node.httpResponseTime;
    }

    return _failedLatency;
  }

  static Future<int> _testTcpConnect(VpnNode node) async {
    Socket? socket;
    final stopwatch = Stopwatch()..start();

    try {
      socket = await Socket.connect(
        node.server,
        node.port,
        timeout: _socketTimeout,
      );
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return _failedLatency;
    } finally {
      await socket?.close();
    }
  }

  static Future<int> _testIcmp(
    VpnNode node, {
    required PingSettings settings,
  }) async {
    if (Platform.isIOS) {
      AppLogService.instance.info(
        source: 'ping',
        message: 'ICMP is unavailable on iOS for ${node.name}, using libXray fallback.',
      );
      return _testIosProxyLatency(
        node,
        settings: settings,
      );
    }

    try {
      final args = Platform.isMacOS
          ? ['-c', '1', '-W', '1000', node.server]
          : ['-c', '1', '-W', '1', node.server];
      final result = await Process.run(_pingCommand, args).timeout(
        _socketTimeout,
      );
      if (result.exitCode != 0) {
        AppLogService.instance.info(
          source: 'ping',
          message: 'ICMP unavailable for ${node.name}, using TCP fallback.',
        );
        return _testTcpThroughProxy(
          node,
          settings: settings,
        );
      }

      final combined = '${result.stdout}\n${result.stderr}';
      final match = _icmpTimePattern.firstMatch(combined);
      if (match == null) {
        AppLogService.instance.info(
          source: 'ping',
          message:
              'ICMP returned no latency for ${node.name}, using TCP fallback.',
        );
        return _testTcpThroughProxy(
          node,
          settings: settings,
        );
      }

      final parsed = double.tryParse(match.group(1) ?? '');
      if (parsed == null) {
        AppLogService.instance.info(
          source: 'ping',
          message:
              'ICMP returned invalid latency for ${node.name}, using TCP fallback.',
        );
        return _testTcpThroughProxy(
          node,
          settings: settings,
        );
      }
      return parsed.round();
    } catch (error) {
      AppLogService.instance.info(
        source: 'ping',
        message: 'ICMP failed for ${node.name}, using TCP fallback.',
      );
      return _testTcpThroughProxy(
        node,
        settings: settings,
      );
    }
  }

  static Future<int> _testTcpThroughProxy(
    VpnNode node, {
    required PingSettings settings,
  }) async {
    if (Platform.isIOS) {
      return _testIosProxyLatency(
        node,
        settings: settings,
      );
    }

    if (!Platform.isMacOS) {
      return _testTcpConnect(node);
    }

    return _testProxyRequest(
      node,
      settings: settings,
      method: 'HEAD',
      metric: 'time_starttransfer',
    );
  }

  static Future<int> _testProxyRequest(
    VpnNode node, {
    required PingSettings settings,
    required String method,
    String metric = 'time_total',
  }) async {
    if (Platform.isIOS) {
      return _testIosProxyLatency(
        node,
        settings: settings,
      );
    }

    if (!Platform.isMacOS) {
      return _failedLatency;
    }

    return _withProbeProxy(
      node,
      (port) async {
        final result = await Process.run(
          _curlCommand,
          [
            '--silent',
            '--show-error',
            '--output',
            '/dev/null',
            '--write-out',
            '%{$metric}',
            '--max-time',
            '5',
            '--noproxy',
            '*',
            '--socks5-hostname',
            '127.0.0.1:$port',
            if (method == 'HEAD') '--head',
            settings.url,
          ],
        ).timeout(const Duration(seconds: 7));

        if (result.exitCode != 0) {
          AppLogService.instance.warning(
            source: 'ping',
            message:
                '$method probe failed for ${node.name}: ${result.stderr.toString().trim()}',
          );
          return _failedLatency;
        }

        final seconds = double.tryParse(result.stdout.toString().trim());
        if (seconds == null) {
          AppLogService.instance.warning(
            source: 'ping',
            message:
                '$method probe returned invalid $metric for ${node.name}: ${result.stdout.toString().trim()}',
          );
          return _failedLatency;
        }
        return (seconds * 1000).round();
      },
    );
  }

  static String get _curlCommand => Platform.isMacOS ? _macCurlPath : 'curl';

  static String get _pingCommand => Platform.isMacOS ? _macPingPath : 'ping';

  static Future<int> _withProbeProxy(
    VpnNode node,
    Future<int> Function(int port) runMeasurement,
  ) async {
    if (!Platform.isMacOS) {
      return _failedLatency;
    }

    final runtime = _resolveXrayRuntime();
    final port = await _reserveLocalPort();
    final tempDir = await getTemporaryDirectory();
    final configFile = File(
      '${tempDir.path}/xray_probe_${node.id.hashCode}_$port.json',
    );

    Process? process;
    StreamSubscription<String>? stdoutSubscription;
    StreamSubscription<String>? stderrSubscription;
    String? lastLogLine;

    try {
      await configFile.writeAsString(
        jsonEncode(_buildProbeConfig(node, port)),
      );

      process = await Process.start(
        runtime.executablePath,
        ['-c', configFile.path],
        workingDirectory: runtime.workingDirectory,
        mode: ProcessStartMode.normal,
        includeParentEnvironment: true,
      );

      stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => lastLogLine = line);
      stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => lastLogLine = line);

      await _waitForLocalSocks(
        process: process,
        port: port,
        readLastLogLine: () => lastLogLine,
      );

      return await runMeasurement(port);
    } catch (error) {
      AppLogService.instance.warning(
        source: 'ping',
        message: 'Probe failed for ${node.name}: $error',
      );
      return _failedLatency;
    } finally {
      await stdoutSubscription?.cancel();
      await stderrSubscription?.cancel();

      final probeProcess = process;
      if (probeProcess != null) {
        probeProcess.kill(ProcessSignal.sigterm);
        try {
          await probeProcess.exitCode.timeout(
            const Duration(seconds: 1),
            onTimeout: () {
              probeProcess.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
        } catch (_) {
          probeProcess.kill(ProcessSignal.sigkill);
        }
      }

      if (await configFile.exists()) {
        await configFile.delete();
      }
    }
  }

  static Future<int> _testIosProxyLatency(
    VpnNode node, {
    required PingSettings settings,
  }) async {
    final port = await _reserveLocalPort();
    final tempDir = await getTemporaryDirectory();
    final configFile = File(
      '${tempDir.path}/xray_probe_ios_${node.id.hashCode}_$port.json',
    );

    try {
      final assetDirectory = await GeodataService.ensureAssetDirectory(
        bundledAssetDirectory: 'xray-core',
      );
      final configJson = XrayConfigBuilder.buildProbeConfig(
        node: node,
        localPort: port,
      );
      await configFile.writeAsString(jsonEncode(configJson));

      final latency = await MacosTunnelBridge.measureLatency(
        configPath: configFile.path,
        assetDirectory: assetDirectory,
        url: settings.url,
        localPort: port,
        timeoutSeconds: 5,
      );
      if (latency == null || latency <= 0) {
        return _failedLatency;
      }
      return latency;
    } catch (error) {
      AppLogService.instance.warning(
        source: 'ping',
        message: 'iOS probe failed for ${node.name}: $error',
      );
      return _failedLatency;
    } finally {
      if (await configFile.exists()) {
        await configFile.delete();
      }
    }
  }

  static Future<void> _waitForLocalSocks({
    required Process process,
    required int port,
    required String? Function() readLastLogLine,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));

    while (DateTime.now().isBefore(deadline)) {
      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 50),
        onTimeout: () => -9999,
      );
      if (exitCode != -9999) {
        final details = readLastLogLine();
        throw Exception(
          details == null
              ? 'Xray probe exited with code $exitCode'
              : 'Xray probe exited with code $exitCode: $details',
        );
      }

      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        await socket.close();
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    final details = readLastLogLine();
    throw Exception(
      details == null
          ? 'Timed out waiting for probe proxy'
          : 'Timed out waiting for probe proxy: $details',
    );
  }

  static Future<int> _reserveLocalPort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  static Map<String, dynamic> _buildProbeConfig(VpnNode node, int port) {
    return {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'port': port,
          'protocol': 'socks',
          'settings': {'udp': false},
        },
      ],
      'outbounds': [
        _buildOutbound(node),
      ],
    };
  }

  static Map<String, dynamic> _buildOutbound(VpnNode node) {
    final protocol = node.protocol.toLowerCase();
    final rawConfig = node.rawConfig ?? const <String, dynamic>{};
    final network =
        (node.network ?? rawConfig['type'] ?? rawConfig['net'] ?? 'tcp')
            .toString();
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
        'allowInsecure': _parseBool(rawConfig['allowInsecure']) ?? true,
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
          },
        ],
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
              },
            ],
          },
        ],
      };
    } else if (protocol == 'trojan') {
      outbound['settings'] = {
        'servers': [
          {
            'address': node.server,
            'port': node.port,
            'password': node.userId ?? '',
          },
        ],
      };
    } else if (protocol == 'ss') {
      outbound['settings'] = {
        'servers': [
          {
            'address': node.server,
            'port': node.port,
            'password': node.userId ?? '',
            'method': node.encryption ?? 'aes-256-gcm',
          },
        ],
      };
    }

    return outbound;
  }

  static bool? _parseBool(Object? value) {
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

  static _ResolvedXrayRuntime _resolveXrayRuntime() {
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
}

class _ResolvedXrayRuntime {
  final String executablePath;
  final String workingDirectory;

  const _ResolvedXrayRuntime({
    required this.executablePath,
    required this.workingDirectory,
  });
}
