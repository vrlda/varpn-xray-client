import '../models/routing_settings.dart';
import '../models/tunnel_settings.dart';
import '../models/vpn_node.dart';
import '../models/xray_settings.dart';
import 'routing_service.dart';

class XrayConfigBuilder {
  static Map<String, dynamic> buildRuntimeConfig({
    required VpnNode node,
    required RoutingSettings routingSettings,
    required TunnelSettings tunnelSettings,
    required XraySettings xraySettings,
    required int localPort,
    int? apiPort,
    bool enableUdp = true,
  }) {
    final preset = routingSettings.selectedPreset;
    final dnsConfig = _buildDnsConfig(
      routingSettings,
      tunnelSettings,
    );
    final fakeDnsConfig = RoutingService.buildFakeDnsConfig(routingSettings);
    final routingConfig = apiPort == null
        ? RoutingService.buildRoutingConfig(routingSettings)
        : _withApiRoutingRule(
            RoutingService.buildRoutingConfig(routingSettings),
          );
    final defaultToProxy =
        !routingSettings.enabled || preset.globalProxyEnabled;

    final outbounds = <Map<String, dynamic>>[
      if (defaultToProxy)
        buildOutbound(
          node,
          xraySettings,
        )
      else
        _buildDirectOutbound(),
      if (defaultToProxy)
        _buildDirectOutbound()
      else
        buildOutbound(
          node,
          xraySettings,
        ),
      _buildBlockOutbound(),
    ];

    return {
      'log': {
        'loglevel': xraySettings.logLevel,
      },
      if (apiPort != null) 'stats': <String, dynamic>{},
      if (apiPort != null)
        'policy': {
          'system': {
            'statsOutboundUplink': true,
            'statsOutboundDownlink': true,
          },
        },
      if (apiPort != null)
        'api': {
          'tag': 'api',
          'listen': '127.0.0.1:$apiPort',
          'services': ['StatsService'],
        },
      if (dnsConfig != null) 'dns': dnsConfig,
      if (fakeDnsConfig.isNotEmpty) 'fakedns': fakeDnsConfig,
      if (routingConfig != null) 'routing': routingConfig,
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'port': localPort,
          'protocol': 'socks',
          'settings': {'udp': enableUdp},
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

  static Map<String, dynamic> buildProbeConfig({
    required VpnNode node,
    required int localPort,
    bool enableUdp = false,
    XraySettings? xraySettings,
  }) {
    final settings = xraySettings ?? XraySettings.defaults();
    return {
      'log': {'loglevel': settings.logLevel},
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'port': localPort,
          'protocol': 'socks',
          'settings': {'udp': enableUdp},
        },
      ],
      'outbounds': [
        buildOutbound(
          node,
          settings,
          allowInsecureDefault: true,
        ),
      ],
    };
  }

  static Map<String, dynamic> buildOutbound(
    VpnNode node,
    XraySettings xraySettings, {
    bool allowInsecureDefault = false,
  }) {
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
            (allowInsecureDefault || xraySettings.allowInsecure),
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

  static List<String> resolveDnsServers(
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

  static Map<String, dynamic>? _buildDnsConfig(
    RoutingSettings routingSettings,
    TunnelSettings tunnelSettings,
  ) {
    if (tunnelSettings.dnsMode == 'custom') {
      final servers = resolveDnsServers(
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

  static Map<String, dynamic> _withApiRoutingRule(
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

  static Map<String, dynamic> _buildDirectOutbound() {
    return {'protocol': 'freedom', 'tag': 'direct'};
  }

  static Map<String, dynamic> _buildBlockOutbound() {
    return {'protocol': 'blackhole', 'tag': 'block'};
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
}
