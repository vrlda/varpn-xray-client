import 'dart:convert';

import 'vpn_node.dart';

enum ConnectionSourceType {
  subscription,
  configLink,
  manual,
}

ConnectionSourceType connectionSourceTypeFromKey(String value) {
  switch (value) {
    case 'subscription':
      return ConnectionSourceType.subscription;
    case 'manual':
      return ConnectionSourceType.manual;
    case 'config_link':
    default:
      return ConnectionSourceType.configLink;
  }
}

String connectionSourceTypeKey(ConnectionSourceType type) {
  switch (type) {
    case ConnectionSourceType.subscription:
      return 'subscription';
    case ConnectionSourceType.manual:
      return 'manual';
    case ConnectionSourceType.configLink:
      return 'config_link';
  }
}

class ManualConnectionConfig {
  final String name;
  final String protocol;
  final String server;
  final int port;
  final String credential;
  final String encryption;
  final String network;
  final String security;
  final String flow;
  final String sni;
  final String path;
  final String host;
  final String realityPubKey;
  final String realityShortId;
  final String fingerprint;
  final String alpn;
  final String extraJson;
  final bool allowInsecure;

  const ManualConnectionConfig({
    required this.name,
    required this.protocol,
    required this.server,
    required this.port,
    required this.credential,
    this.encryption = 'none',
    this.network = 'tcp',
    this.security = 'none',
    this.flow = '',
    this.sni = '',
    this.path = '',
    this.host = '',
    this.realityPubKey = '',
    this.realityShortId = '',
    this.fingerprint = '',
    this.alpn = '',
    this.extraJson = '',
    this.allowInsecure = true,
  });

  ManualConnectionConfig copyWith({
    String? name,
    String? protocol,
    String? server,
    int? port,
    String? credential,
    String? encryption,
    String? network,
    String? security,
    String? flow,
    String? sni,
    String? path,
    String? host,
    String? realityPubKey,
    String? realityShortId,
    String? fingerprint,
    String? alpn,
    String? extraJson,
    bool? allowInsecure,
  }) {
    return ManualConnectionConfig(
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      server: server ?? this.server,
      port: port ?? this.port,
      credential: credential ?? this.credential,
      encryption: encryption ?? this.encryption,
      network: network ?? this.network,
      security: security ?? this.security,
      flow: flow ?? this.flow,
      sni: sni ?? this.sni,
      path: path ?? this.path,
      host: host ?? this.host,
      realityPubKey: realityPubKey ?? this.realityPubKey,
      realityShortId: realityShortId ?? this.realityShortId,
      fingerprint: fingerprint ?? this.fingerprint,
      alpn: alpn ?? this.alpn,
      extraJson: extraJson ?? this.extraJson,
      allowInsecure: allowInsecure ?? this.allowInsecure,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'protocol': protocol,
      'server': server,
      'port': port,
      'credential': credential,
      'encryption': encryption,
      'network': network,
      'security': security,
      'flow': flow,
      'sni': sni,
      'path': path,
      'host': host,
      'realityPubKey': realityPubKey,
      'realityShortId': realityShortId,
      'fingerprint': fingerprint,
      'alpn': alpn,
      'extraJson': extraJson,
      'allowInsecure': allowInsecure,
    };
  }

  factory ManualConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ManualConnectionConfig(
      name: json['name']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? 'vless',
      server: json['server']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 443,
      credential: json['credential']?.toString() ?? '',
      encryption: json['encryption']?.toString() ?? 'none',
      network: json['network']?.toString() ?? 'tcp',
      security: json['security']?.toString() ?? 'none',
      flow: json['flow']?.toString() ?? '',
      sni: json['sni']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      host: json['host']?.toString() ?? '',
      realityPubKey: json['realityPubKey']?.toString() ?? '',
      realityShortId: json['realityShortId']?.toString() ?? '',
      fingerprint: json['fingerprint']?.toString() ?? '',
      alpn: json['alpn']?.toString() ?? '',
      extraJson: json['extraJson']?.toString() ?? '',
      allowInsecure: json['allowInsecure'] == true,
    );
  }

  VpnNode toVpnNode(String id) {
    final normalizedProtocol = protocol.trim().toLowerCase();
    final normalizedNetwork = network.trim().toLowerCase();
    final normalizedSecurity = security.trim().toLowerCase();
    final rawConfig = <String, dynamic>{
      'type': normalizedNetwork,
      'security': normalizedSecurity,
      'allowInsecure': allowInsecure,
      if (flow.trim().isNotEmpty) 'flow': flow.trim(),
      if (sni.trim().isNotEmpty) 'sni': sni.trim(),
      if (host.trim().isNotEmpty) 'host': host.trim(),
      if (fingerprint.trim().isNotEmpty) 'fp': fingerprint.trim(),
      if (alpn.trim().isNotEmpty) 'alpn': alpn.trim(),
      if (realityPubKey.trim().isNotEmpty) 'pbk': realityPubKey.trim(),
      if (realityShortId.trim().isNotEmpty) 'sid': realityShortId.trim(),
    };

    if (path.trim().isNotEmpty) {
      if (normalizedNetwork == 'grpc') {
        rawConfig['serviceName'] = path.trim();
      } else {
        rawConfig['path'] = path.trim();
      }
    }

    final extra = _decodeExtraJson(extraJson);
    if (extra != null) {
      rawConfig.addAll(extra);
    }

    return VpnNode(
      id: id,
      name: name.trim().isEmpty ? server.trim() : name.trim(),
      server: server.trim(),
      port: port,
      protocol: normalizedProtocol,
      userId: credential.trim(),
      flow: flow.trim().isEmpty ? null : flow.trim(),
      encryption: encryption.trim().isEmpty ? null : encryption.trim(),
      network: normalizedNetwork,
      security: normalizedSecurity,
      sni: sni.trim().isEmpty ? null : sni.trim(),
      realityPubKey: realityPubKey.trim().isEmpty ? null : realityPubKey.trim(),
      realityShortId:
          realityShortId.trim().isEmpty ? null : realityShortId.trim(),
      path: path.trim().isEmpty ? null : path.trim(),
      host: host.trim().isEmpty ? null : host.trim(),
      rawConfig: rawConfig,
    );
  }
}

class ConnectionSource {
  final String id;
  final ConnectionSourceType type;
  final String name;
  final String input;
  final ManualConnectionConfig? manualConfig;
  final bool enabled;
  final DateTime? updatedAt;
  final String? lastRefreshError;

  const ConnectionSource({
    required this.id,
    required this.type,
    required this.name,
    this.input = '',
    this.manualConfig,
    this.enabled = true,
    this.updatedAt,
    this.lastRefreshError,
  });

  bool get isManual => type == ConnectionSourceType.manual;

  String get resolvedName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    if (manualConfig != null && manualConfig!.name.trim().isNotEmpty) {
      return manualConfig!.name.trim();
    }
    return input.trim();
  }

  ConnectionSource copyWith({
    String? id,
    ConnectionSourceType? type,
    String? name,
    String? input,
    ManualConnectionConfig? manualConfig,
    bool? enabled,
    Object? updatedAt = _sentinel,
    Object? lastRefreshError = _sentinel,
  }) {
    return ConnectionSource(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      input: input ?? this.input,
      manualConfig: manualConfig ?? this.manualConfig,
      enabled: enabled ?? this.enabled,
      updatedAt:
          identical(updatedAt, _sentinel) ? this.updatedAt : updatedAt as DateTime?,
      lastRefreshError: identical(lastRefreshError, _sentinel)
          ? this.lastRefreshError
          : lastRefreshError as String?,
    );
  }

  static const Object _sentinel = Object();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': connectionSourceTypeKey(type),
      'name': name,
      'input': input,
      'manualConfig': manualConfig?.toJson(),
      'enabled': enabled,
      'updatedAt': updatedAt?.toIso8601String(),
      'lastRefreshError': lastRefreshError,
    };
  }

  factory ConnectionSource.fromJson(Map<String, dynamic> json) {
    final manualJson = json['manualConfig'];
    return ConnectionSource(
      id: json['id']?.toString() ?? '',
      type: connectionSourceTypeFromKey(json['type']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      input: json['input']?.toString() ?? '',
      manualConfig: manualJson is Map<String, dynamic>
          ? ManualConnectionConfig.fromJson(manualJson)
          : manualJson is Map
              ? ManualConnectionConfig.fromJson(
                  manualJson.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
              : null,
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      lastRefreshError: json['lastRefreshError']?.toString(),
    );
  }
}

Map<String, dynamic>? _decodeExtraJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    return null;
  }

  return null;
}
