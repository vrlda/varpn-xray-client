import 'dart:convert';

import 'package:easyxray/core/services/subscription_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses mixed raw config lines', () {
    final vmessPayload = base64Encode(
      utf8.encode(
        jsonEncode({
          'v': '2',
          'ps': '🇫🇮 Finland vmess',
          'add': 'fi.example.com',
          'port': '443',
          'id': '11111111-1111-1111-1111-111111111111',
          'aid': '0',
          'net': 'ws',
          'type': 'none',
          'host': 'cdn.example.com',
          'path': '/ws',
          'tls': 'tls',
          'sni': 'fi.example.com',
        }),
      ),
    );

    final input = [
      'vless://11111111-1111-1111-1111-111111111111@de.example.com:443?type=ws&security=tls&host=cdn.example.com&path=%2Fsocket#%F0%9F%87%A9%F0%9F%87%AA%20Germany',
      'vmess://$vmessPayload',
      'trojan://secret@example.com:443?type=grpc&security=tls&serviceName=grpc#%F0%9F%87%AC%F0%9F%87%A7%20United%20Kingdom',
      'ss://${base64Encode(utf8.encode('aes-256-gcm:password@us.example.com:8388'))}#%F0%9F%87%BA%F0%9F%87%B8%20USA',
    ].join('\n');

    final nodes = SubscriptionParser.parseSubscription(input);

    expectLater(nodes, completion(hasLength(4)));
  });

  test('parses base64 subscription bundles', () async {
    final raw = [
      'vless://11111111-1111-1111-1111-111111111111@de.example.com:443?type=tcp&security=reality&pbk=pub&sni=de.example.com&sid=abcd#%F0%9F%87%A9%F0%9F%87%AA%20Germany',
      'trojan://secret@fi.example.com:443?type=ws&security=tls&host=fi.example.com&path=%2Ftrojan#%F0%9F%87%AB%F0%9F%87%AE%20Finland',
    ].join('\n');

    final encoded = base64Encode(utf8.encode(raw));
    final nodes = await SubscriptionParser.parseSubscription(encoded);

    expect(nodes, hasLength(2));
    expect(nodes.first.server, 'de.example.com');
    expect(nodes.last.protocol, 'trojan');
  });

  test('groups by emoji flag country', () async {
    final nodes = await SubscriptionParser.parseSubscription(
      'vless://11111111-1111-1111-1111-111111111111@de.example.com:443?type=tcp#%F0%9F%87%A9%F0%9F%87%AA%20Germany',
    );

    final groups = SubscriptionParser.groupByCountry(nodes);
    expect(groups.single.countryCode, 'DE');
    expect(groups.single.countryName, 'Германия');
  });

  test('groups by short country codes in node names', () async {
    final input = [
      'vless://11111111-1111-1111-1111-111111111111@de2.varpn.cc:443?type=xhttp&security=reality#DE-1-X',
      'vless://11111111-1111-1111-1111-111111111111@fin1.varpn.cc:8443?type=grpc&security=reality#FIN-G',
      'vless://11111111-1111-1111-1111-111111111111@lv1.varpn.cc:8443?type=grpc&security=reality#LV-G',
      'vless://11111111-1111-1111-1111-111111111111@144.31.122.126:8443?type=grpc&security=reality#NL-G',
    ].join('\n');

    final nodes = await SubscriptionParser.parseSubscription(input);
    final groups = SubscriptionParser.groupByCountry(nodes);
    final codes = groups.map((group) => group.countryCode).toSet();

    expect(codes, containsAll({'DE', 'FI', 'LV', 'NL'}));
  });
}
