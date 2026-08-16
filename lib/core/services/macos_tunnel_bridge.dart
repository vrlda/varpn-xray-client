import 'dart:io';

import 'package:flutter/services.dart';

class MacosTunnelBridge {
  static const MethodChannel _channel = MethodChannel('easyxray/tunnel');
  static bool get _supportsBridge => Platform.isMacOS || Platform.isIOS;

  static Future<String?> sharedContainerPath() async {
    if (!_supportsBridge) {
      return null;
    }
    return _channel.invokeMethod<String>('sharedContainerPath');
  }

  static Future<void> installHelper() async {
    if (!Platform.isMacOS) {
      return;
    }

    await _channel.invokeMethod<void>('installHelper');
  }

  static Future<Map<String, dynamic>> helperStatus() async {
    if (!Platform.isMacOS) {
      return const {};
    }

    final response = await _channel.invokeMethod<dynamic>('helperStatus');
    if (response is! Map) {
      return const {};
    }

    return response.map((key, value) => MapEntry(key.toString(), value));
  }

  static Future<void> startTunnel({
    required String configPath,
    required String assetDirectory,
    required List<String> dnsServers,
    int mtu = 1500,
    bool enableIpv6 = true,
    bool bypassLocalNetworks = true,
    bool strictRouting = true,
    String? reconnectReason,
    String? activeTransport,
    Map<String, dynamic>? activeSession,
  }) async {
    if (!_supportsBridge) {
      return;
    }

    await _channel.invokeMethod<void>('startTunnel', {
      'configPath': configPath,
      'assetDirectory': assetDirectory,
      'dnsServers': dnsServers,
      'mtu': mtu,
      'enableIpv6': enableIpv6,
      'bypassLocalNetworks': bypassLocalNetworks,
      'strictRouting': strictRouting,
      if (reconnectReason != null) 'reconnectReason': reconnectReason,
      if (activeTransport != null) 'activeTransport': activeTransport,
      if (activeSession != null) 'activeSession': activeSession,
    });
  }

  static Future<void> stopTunnel() async {
    if (!_supportsBridge) {
      return;
    }

    await _channel.invokeMethod<void>('stopTunnel');
  }

  static Future<String> tunnelStatus() async {
    if (!_supportsBridge) {
      return 'unsupported';
    }

    return (await _channel.invokeMethod<String>('tunnelStatus')) ??
        'disconnected';
  }

  static Future<List<Map<String, dynamic>>> fetchNativeLogs() async {
    if (!_supportsBridge) {
      return const [];
    }

    final response = await _channel.invokeMethod<List<dynamic>>(
      'nativeLogEntries',
    );
    if (response == null) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map(
          (entry) => entry.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();
  }

  static Future<Map<String, dynamic>> trafficStats() async {
    if (!_supportsBridge) {
      return const {};
    }

    final response = await _channel.invokeMethod<dynamic>('trafficStats');
    if (response is! Map) {
      return const {};
    }

    return response.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  static Future<Map<String, dynamic>> tunnelHealth() async {
    if (!_supportsBridge) {
      return const {};
    }

    final response = await _channel.invokeMethod<dynamic>('tunnelHealth');
    if (response is! Map) {
      return const {};
    }

    return response.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  static Future<void> clearNativeLogs() async {
    if (!_supportsBridge) {
      return;
    }

    await _channel.invokeMethod<void>('clearNativeLogs');
  }

  static Future<void> repairTunnel() async {
    if (!Platform.isMacOS) {
      return;
    }

    await _channel.invokeMethod<void>('repairTunnel');
  }

  static Future<int?> measureLatency({
    required String configPath,
    required String assetDirectory,
    required String url,
    required int localPort,
    int timeoutSeconds = 5,
  }) async {
    if (!Platform.isIOS) {
      return null;
    }

    return _channel.invokeMethod<int>('measureLatency', {
      'configPath': configPath,
      'assetDirectory': assetDirectory,
      'url': url,
      'localPort': localPort,
      'timeoutSeconds': timeoutSeconds,
    });
  }
}
