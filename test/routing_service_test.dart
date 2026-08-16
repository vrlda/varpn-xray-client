import 'package:easyxray/core/models/routing_settings.dart';
import 'package:easyxray/core/services/routing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseRuleList splits domain and ip rules correctly', () {
    final parsed = RoutingService.parseRuleList(
      'geosite:google\n'
      'example.com\n'
      'geoip:ru\n'
      '92.100.5.0/22\n'
      '1.1.1.1',
    );

    expect(
      parsed.domains,
      equals([
        'geosite:google',
        'example.com',
      ]),
    );
    expect(
      parsed.ips,
      equals([
        'geoip:ru',
        '92.100.5.0/22',
        '1.1.1.1',
      ]),
    );
  });

  test('buildRoutingConfig creates proxy direct and block rules', () {
    final settings =
        RoutingSettings.defaults().copyWith(enabled: true).updatePreset(
              RoutingSettings.defaults().selectedPreset.copyWith(
                    proxyRules: 'geosite:google',
                    directRules: 'geoip:ru',
                    blockRules: 'geosite:category-ads-all',
                  ),
            );

    final config = RoutingService.buildRoutingConfig(settings);

    expect(config, isNotNull);
    expect(config!['domainStrategy'], 'IPIfNonMatch');
    final rules = config['rules'] as List<dynamic>;
    expect(rules, hasLength(3));
    expect((rules[0] as Map<String, dynamic>)['outboundTag'], 'block');
    expect((rules[1] as Map<String, dynamic>)['outboundTag'], 'direct');
    expect((rules[2] as Map<String, dynamic>)['outboundTag'], 'proxy');
  });

  test('buildDnsConfig keeps fake dns and normalizes DoU addresses', () {
    final settings = RoutingSettings.defaults().updatePreset(
      RoutingSettings.defaults().selectedPreset.copyWith(
            fakeDnsEnabled: true,
            remoteDnsType: 'DoH',
            remoteDnsValue: 'https://cloudflare-dns.com/dns-query',
            remoteDnsIp: '',
            domesticDnsType: 'DoU',
            domesticDnsValue: '8.8.8.8',
          ),
    );

    final config = RoutingService.buildDnsConfig(settings);

    expect(config, isNotNull);
    final servers = config!['servers'] as List<dynamic>;
    expect(servers.first, 'fakedns');
    expect(
      (servers[2] as Map<String, dynamic>)['address'],
      'quic+local://8.8.8.8',
    );
  });
}
