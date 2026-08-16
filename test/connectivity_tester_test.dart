import 'package:easyxray/core/models/vpn_node.dart';
import 'package:easyxray/core/services/connectivity_tester.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('findBestNode prefers available nodes with the lowest ping', () {
    final bestNode = ConnectivityTester.findBestNode([
      const VpnNode(
        id: 'de-slow',
        name: 'DE-1-X',
        server: 'de.example.com',
        port: 443,
        protocol: 'vless',
        network: 'xhttp',
        security: 'reality',
        ping: 420,
        httpResponseTime: 430,
        isAvailable: true,
      ),
      const VpnNode(
        id: 'de-fast',
        name: 'DE-2-X',
        server: 'de2.example.com',
        port: 443,
        protocol: 'vless',
        network: 'grpc',
        security: 'reality',
        ping: 180,
        httpResponseTime: 250,
        isAvailable: true,
      ),
      const VpnNode(
        id: 'de-down',
        name: 'DE-3-X',
        server: 'de3.example.com',
        port: 443,
        protocol: 'vless',
        network: 'grpc',
        security: 'reality',
        ping: 9999,
        httpResponseTime: 9999,
        isAvailable: false,
      ),
    ]);

    expect(bestNode?.id, 'de-fast');
  });

  test('findBestNode falls back to unknown nodes before measured failures', () {
    final bestNode = ConnectivityTester.findBestNode([
      const VpnNode(
        id: 'unknown',
        name: 'NL-X',
        server: 'nl.example.com',
        port: 443,
        protocol: 'vless',
      ),
      const VpnNode(
        id: 'failed',
        name: 'NL-G',
        server: 'nl2.example.com',
        port: 443,
        protocol: 'vless',
        ping: 9999,
        httpResponseTime: 9999,
        isAvailable: false,
      ),
    ]);

    expect(bestNode?.id, 'unknown');
  });
}
