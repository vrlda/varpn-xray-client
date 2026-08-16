import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/routing_settings.dart';

class RoutingService {
  /// Restricted countries that commonly need split routing presets.
  static const restrictedCountries = ['RU', 'CN', 'IR'];

  /// Get user's current location based on IP.
  static Future<String?> getUserCountryCode() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://ipapi.co/json/'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = response.body;
        if (json.contains('"country_code":"RU"')) return 'RU';
        if (json.contains('"country_code":"CN"')) return 'CN';
        if (json.contains('"country_code":"IR"')) return 'IR';
      }
    } catch (_) {
      // Ignore geo lookup failures and continue with no recommendation.
    }
    return null;
  }

  static Future<bool> isInRestrictedCountry() async {
    final countryCode = await getUserCountryCode();
    return countryCode != null && restrictedCountries.contains(countryCode);
  }

  static String getRoutingMessage(String? countryCode) {
    if (countryCode == null) return '';

    const messages = {
      'RU':
          'Оптимизировано для России - локальные приложения работают напрямую',
      'CN': 'Оптимизировано для Китая - локальные приложения работают напрямую',
      'IR': 'Оптимизировано для Ирана - локальные приложения работают напрямую',
    };

    return messages[countryCode] ?? '';
  }

  static Map<String, dynamic>? buildRoutingConfig(RoutingSettings settings) {
    if (!settings.enabled) {
      return null;
    }

    final preset = settings.selectedPreset;
    final rules = <Map<String, dynamic>>[];

    void addRules({
      required String rawRules,
      required String outboundTag,
    }) {
      final parsed = parseRuleList(rawRules);
      if (parsed.domains.isNotEmpty) {
        rules.add({
          'type': 'field',
          'domain': parsed.domains,
          'outboundTag': outboundTag,
        });
      }
      if (parsed.ips.isNotEmpty) {
        rules.add({
          'type': 'field',
          'ip': parsed.ips,
          'outboundTag': outboundTag,
        });
      }
    }

    // Order matters: blocking should win before direct/proxy fallbacks.
    addRules(rawRules: preset.blockRules, outboundTag: 'block');
    addRules(rawRules: preset.directRules, outboundTag: 'direct');
    addRules(rawRules: preset.proxyRules, outboundTag: 'proxy');

    return {
      'domainStrategy': preset.domainStrategy,
      'rules': rules,
    };
  }

  static Map<String, dynamic>? buildDnsConfig(RoutingSettings settings) {
    final preset = settings.selectedPreset;
    final servers = <dynamic>[];

    if (preset.fakeDnsEnabled) {
      servers.add('fakedns');
    }

    final remoteServer = normalizeDnsAddress(
      type: preset.remoteDnsType,
      value: preset.remoteDnsValue,
      ipOverride: preset.remoteDnsIp,
    );
    if (remoteServer != null) {
      servers.add({'address': remoteServer});
    }

    final domesticServer = normalizeDnsAddress(
      type: preset.domesticDnsType,
      value: preset.domesticDnsValue,
    );
    if (domesticServer != null) {
      servers.add({'address': domesticServer});
    }

    if (servers.isEmpty) {
      return null;
    }

    return {
      'servers': servers,
    };
  }

  static List<Map<String, dynamic>> buildFakeDnsConfig(
    RoutingSettings settings,
  ) {
    if (!settings.selectedPreset.fakeDnsEnabled) {
      return const <Map<String, dynamic>>[];
    }

    return const [
      {
        'ipPool': '198.18.0.0/15',
        'poolSize': 65535,
      },
    ];
  }

  static ParsedRoutingRules parseRuleList(String rawRules) {
    final domains = <String>[];
    final ips = <String>[];
    final seenDomains = <String>{};
    final seenIps = <String>{};

    final normalized = rawRules.replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    for (final line in lines) {
      final items = line
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty);

      for (final item in items) {
        if (item.startsWith('#') || item.startsWith('//')) {
          continue;
        }

        if (_isIpRule(item)) {
          if (seenIps.add(item)) {
            ips.add(item);
          }
        } else {
          if (seenDomains.add(item)) {
            domains.add(item);
          }
        }
      }
    }

    return ParsedRoutingRules(
      domains: domains,
      ips: ips,
    );
  }

  static String? normalizeDnsAddress({
    required String type,
    required String value,
    String? ipOverride,
  }) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return null;
    }

    final normalizedType = type.trim().toLowerCase();
    final override = ipOverride?.trim() ?? '';

    switch (normalizedType) {
      case 'doh':
        final uri = Uri.tryParse(trimmedValue);
        if (override.isNotEmpty &&
            uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http')) {
          return uri.replace(host: override).toString();
        }
        return trimmedValue;
      case 'dou':
        if (trimmedValue.contains('://')) {
          return trimmedValue;
        }
        return 'quic+local://$trimmedValue';
      case 'plain':
      default:
        return trimmedValue;
    }
  }

  static bool _isIpRule(String value) {
    final lower = value.toLowerCase();
    if (lower.startsWith('geoip:')) {
      return true;
    }

    final cidrParts = value.split('/');
    if (cidrParts.length == 2 &&
        InternetAddress.tryParse(cidrParts.first.trim()) != null &&
        int.tryParse(cidrParts.last.trim()) != null) {
      return true;
    }

    return InternetAddress.tryParse(value) != null;
  }
}

class ParsedRoutingRules {
  final List<String> domains;
  final List<String> ips;

  const ParsedRoutingRules({
    required this.domains,
    required this.ips,
  });
}
