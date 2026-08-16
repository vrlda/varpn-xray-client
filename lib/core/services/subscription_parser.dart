import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/server_group.dart';
import '../models/vpn_node.dart';

class SubscriptionParser {
  /// Parse subscription URL, raw config, or base64-encoded config bundle.
  static Future<List<VpnNode>> parseSubscription(String input) async {
    try {
      final payload = input.trim().replaceFirst('\uFEFF', '');
      if (payload.isEmpty) {
        return const [];
      }

      if (payload.startsWith('http://') || payload.startsWith('https://')) {
        final response = await http.get(
          Uri.parse(payload),
          headers: const {
            'Accept': 'text/plain',
            'User-Agent': 'VarPN/1.0',
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'The server took too long to respond.',
          ),
        );
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        return _parsePayload(response.body);
      }

      return _parsePayload(payload);
    } catch (e) {
      throw Exception('Failed to parse subscription: $e');
    }
  }

  static List<VpnNode> _parsePayload(String payload) {
    final cleaned = payload.trim().replaceFirst('\uFEFF', '');
    if (cleaned.isEmpty) {
      return const [];
    }

    final direct = _parseLineList(cleaned);
    if (direct.isNotEmpty) {
      return direct;
    }

    final decoded = _decodeBase64String(cleaned);
    if (decoded != null && decoded.trim().isNotEmpty) {
      final decodedNodes = _parseLineList(decoded);
      if (decodedNodes.isNotEmpty) {
        return decodedNodes;
      }
    }

    return const [];
  }

  static List<VpnNode> _parseLineList(String payload) {
    final normalized = payload.replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('#'))
        .toList();

    return lines.map(parseSingleConfig).whereType<VpnNode>().toList();
  }

  static String? _decodeBase64String(String value) {
    try {
      final sanitized = value.replaceAll(RegExp(r'\s+'), '');
      final normalized = sanitized.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = base64Decode(base64.normalize(normalized));
      return utf8.decode(decoded, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static VpnNode? parseSingleConfig(String configLine) {
    final config = configLine.trim();
    if (config.isEmpty) {
      return null;
    }

    try {
      if (config.startsWith('vless://')) {
        return _parseVless(config);
      }
      if (config.startsWith('vmess://')) {
        return _parseVmess(config);
      }
      if (config.startsWith('trojan://')) {
        return _parseTrojan(config);
      }
      if (config.startsWith('ss://')) {
        return _parseShadowsocks(config);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String suggestSourceName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return 'Connection';
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      final host = uri?.host.trim();
      if (host != null && host.isNotEmpty) {
        return host;
      }
    }

    final node = parseSingleConfig(trimmed);
    if (node != null) {
      return node.name;
    }

    final compact = trimmed.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 36) {
      return compact;
    }
    return '${compact.substring(0, 33)}...';
  }

  static VpnNode _parseVless(String config) {
    final uri = Uri.parse(config);
    final params = uri.queryParameters;

    return VpnNode(
      id: 'vless_${config.hashCode}',
      name: _displayName(uri.fragment, uri.host),
      server: uri.host,
      port: uri.port,
      protocol: 'vless',
      userId: uri.userInfo.split(':').first,
      flow: params['flow'],
      encryption: params['encryption'] ?? 'none',
      network: params['type'] ?? 'tcp',
      security: params['security'] ?? 'none',
      sni: params['sni'] ?? params['serverName'],
      realityPubKey: params['pbk'],
      realityShortId: params['sid'],
      path: params['path'] ?? params['serviceName'],
      host: params['host'] ?? params['authority'],
      rawConfig: <String, dynamic>{...params},
    );
  }

  static VpnNode _parseVmess(String config) {
    final encoded = config.substring('vmess://'.length).trim();
    final decoded = _decodeBase64String(encoded);
    if (decoded == null) {
      throw const FormatException('Invalid vmess payload');
    }

    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final tls = (json['tls']?.toString() ?? '').toLowerCase();

    return VpnNode(
      id: 'vmess_${config.hashCode}',
      name: _displayName(json['ps']?.toString(), json['add']?.toString() ?? ''),
      server: json['add']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 0,
      protocol: 'vmess',
      userId: json['id']?.toString(),
      encryption: json['scy']?.toString() ?? 'auto',
      network: json['net']?.toString() ?? 'tcp',
      security: tls == 'tls' || tls == 'reality' ? tls : 'none',
      sni: json['sni']?.toString(),
      path: json['path']?.toString(),
      host: json['host']?.toString(),
      rawConfig: json,
    );
  }

  static VpnNode _parseTrojan(String config) {
    final uri = Uri.parse(config);
    final params = uri.queryParameters;

    return VpnNode(
      id: 'trojan_${config.hashCode}',
      name: _displayName(uri.fragment, uri.host),
      server: uri.host,
      port: uri.port,
      protocol: 'trojan',
      userId: uri.userInfo,
      network: params['type'] ?? 'tcp',
      security: params['security'] ?? 'tls',
      sni: params['sni'] ?? params['peer'],
      path: params['path'] ?? params['serviceName'],
      host: params['host'] ?? params['authority'],
      rawConfig: <String, dynamic>{...params},
    );
  }

  static VpnNode _parseShadowsocks(String config) {
    final withoutScheme = config.substring('ss://'.length);
    final mainPart = withoutScheme.split('#').first;
    final namePart = withoutScheme.contains('#')
        ? withoutScheme.substring(withoutScheme.indexOf('#') + 1)
        : '';

    String method = 'aes-256-gcm';
    String password = '';
    String host = '';
    int port = 0;

    if (mainPart.contains('@')) {
      final lastAt = mainPart.lastIndexOf('@');
      final userInfoPart = mainPart.substring(0, lastAt);
      final hostPart = mainPart.substring(lastAt + 1);
      final decodedUserInfo = _decodeBase64String(userInfoPart) ?? userInfoPart;
      final credentials = decodedUserInfo.split(':');
      method = credentials.isNotEmpty ? credentials.first : method;
      password =
          credentials.length > 1 ? credentials.sublist(1).join(':') : password;
      final hostUri = Uri.parse('ss://$hostPart');
      host = hostUri.host;
      port = hostUri.port;
    } else {
      final decoded = _decodeBase64String(mainPart);
      if (decoded == null) {
        throw const FormatException('Invalid shadowsocks payload');
      }

      final atIndex = decoded.lastIndexOf('@');
      if (atIndex == -1) {
        throw const FormatException('Invalid shadowsocks endpoint');
      }

      final credentials = decoded.substring(0, atIndex).split(':');
      final endpoint = decoded.substring(atIndex + 1);
      final hostUri = Uri.parse('ss://$endpoint');
      method = credentials.isNotEmpty ? credentials.first : method;
      password =
          credentials.length > 1 ? credentials.sublist(1).join(':') : password;
      host = hostUri.host;
      port = hostUri.port;
    }

    return VpnNode(
      id: 'ss_${config.hashCode}',
      name: _displayName(namePart, host),
      server: host,
      port: port,
      protocol: 'ss',
      userId: password,
      encryption: method,
    );
  }

  static List<ServerGroup> groupByCountry(List<VpnNode> nodes) {
    final countryMap = <String, List<VpnNode>>{};

    for (final node in nodes) {
      final countryCode = _extractCountryCode(node);
      countryMap.putIfAbsent(countryCode, () => []).add(node);
    }

    return countryMap.entries.map((entry) {
      final groupedNodes = entry.value;
      final avgPing = groupedNodes.isEmpty
          ? 0
          : groupedNodes.map((n) => n.ping).reduce((a, b) => a + b) ~/
              groupedNodes.length;
      final avgHttp = groupedNodes.isEmpty
          ? 0
          : groupedNodes
                  .map((n) => n.httpResponseTime)
                  .reduce((a, b) => a + b) ~/
              groupedNodes.length;

      return ServerGroup(
        countryCode: entry.key,
        countryName: _getCountryName(entry.key),
        nodes: groupedNodes,
        averagePing: avgPing,
        averageHttpResponseTime: avgHttp,
      );
    }).toList()
      ..sort((a, b) => a.countryName.compareTo(b.countryName));
  }

  static String _displayName(String? encodedName, String fallback) {
    if (encodedName == null || encodedName.isEmpty) {
      return fallback;
    }

    if (!encodedName.contains('%')) {
      return encodedName;
    }

    try {
      return Uri.decodeComponent(encodedName);
    } catch (_) {
      return encodedName;
    }
  }

  static String _extractCountryCode(VpnNode node) {
    for (final value in [
      node.name,
      node.server,
      node.host ?? '',
      node.sni ?? '',
    ]) {
      final detectedCode = _extractCountryCodeFromText(value);
      if (detectedCode != null) {
        return detectedCode;
      }
    }

    return 'XX';
  }

  static String? _extractCountryCodeFromText(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      return null;
    }

    final flagMatch = RegExp(
      r'[\u{1F1E6}-\u{1F1FF}]{2}',
      unicode: true,
    ).firstMatch(name);

    if (flagMatch != null) {
      final runes = flagMatch.group(0)!.runes.toList();
      if (runes.length == 2) {
        return String.fromCharCodes(
          runes.map((rune) => rune - 0x1F1E6 + 0x41),
        );
      }
    }

    const shortCountryCodes = {
      'RU': 'RU',
      'RUS': 'RU',
      'DE': 'DE',
      'GER': 'DE',
      'US': 'US',
      'USA': 'US',
      'GB': 'GB',
      'UK': 'GB',
      'FR': 'FR',
      'FI': 'FI',
      'FIN': 'FI',
      'NL': 'NL',
      'NLD': 'NL',
      'SE': 'SE',
      'SWE': 'SE',
      'LV': 'LV',
      'LVA': 'LV',
      'AT': 'AT',
      'AUT': 'AT',
      'CH': 'CH',
      'CHE': 'CH',
      'SG': 'SG',
      'SGP': 'SG',
      'JP': 'JP',
      'JPN': 'JP',
    };

    final upperName = name.toUpperCase();
    final upperTokens = upperName
        .split(RegExp(r'[^A-Z]+'))
        .where((token) => token.isNotEmpty)
        .toList();

    for (final token in upperTokens) {
      if (shortCountryCodes.containsKey(token)) {
        return shortCountryCodes[token];
      }

      final firstThree = token.length >= 3 ? token.substring(0, 3) : token;
      if (shortCountryCodes.containsKey(firstThree)) {
        return shortCountryCodes[firstThree];
      }

      final firstTwo = token.length >= 2 ? token.substring(0, 2) : token;
      if (shortCountryCodes.containsKey(firstTwo)) {
        return shortCountryCodes[firstTwo];
      }
    }

    const countryPatterns = {
      'russia': 'RU',
      'россия': 'RU',
      'russian': 'RU',
      'germany': 'DE',
      'германия': 'DE',
      'german': 'DE',
      'usa': 'US',
      'united states': 'US',
      'сша': 'US',
      'uk': 'GB',
      'united kingdom': 'GB',
      'великобритания': 'GB',
      'britain': 'GB',
      'france': 'FR',
      'франция': 'FR',
      'finland': 'FI',
      'финляндия': 'FI',
      'netherlands': 'NL',
      'нидерланды': 'NL',
      'holland': 'NL',
      'sweden': 'SE',
      'швеция': 'SE',
      'latvia': 'LV',
      'латвия': 'LV',
      'austria': 'AT',
      'австрия': 'AT',
      'switzerland': 'CH',
      'швейцария': 'CH',
      'singapore': 'SG',
      'сингапур': 'SG',
      'japan': 'JP',
      'япония': 'JP',
    };

    final lowerName = name.toLowerCase();
    for (final entry in countryPatterns.entries) {
      if (lowerName.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  static String _getCountryName(String code) {
    const countryNames = {
      'RU': 'Россия',
      'DE': 'Германия',
      'US': 'США',
      'GB': 'Великобритания',
      'FR': 'Франция',
      'FI': 'Финляндия',
      'NL': 'Нидерланды',
      'SE': 'Швеция',
      'LV': 'Латвия',
      'AT': 'Австрия',
      'CH': 'Швейцария',
      'SG': 'Сингапур',
      'JP': 'Япония',
      'XX': 'Другие',
    };

    return countryNames[code] ?? 'Другие';
  }
}
