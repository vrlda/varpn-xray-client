import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RuntimeSnapshotStore {
  static const String _runtimeDirectoryName = 'runtime';
  static const String _sharedMacosRootPath = '/Users/Shared/VarPN/state';
  static const String _trafficStatsFileName = 'traffic-stats.json';
  static const String _healthFileName = 'tunnel-health.json';
  static const String _proxyStateFileName = 'system-proxy.json';
  static const String _activeSessionFileName = 'active-session.json';

  static Future<Map<String, dynamic>> readTrafficStats() async {
    return _readJsonFile(_trafficStatsFileName);
  }

  static Future<void> writeTrafficStats(Map<String, dynamic> json) async {
    await _writeJsonFile(_trafficStatsFileName, json);
  }

  static Future<Map<String, dynamic>> readTunnelHealth() async {
    return _readJsonFile(_healthFileName);
  }

  static Future<void> writeTunnelHealth(Map<String, dynamic> json) async {
    await _writeJsonFile(_healthFileName, json);
  }

  static Future<Map<String, dynamic>> readProxyState() async {
    return _readJsonFile(_proxyStateFileName);
  }

  static Future<void> writeProxyState(Map<String, dynamic> json) async {
    await _writeJsonFile(_proxyStateFileName, json);
  }

  static Future<void> clearProxyState() async {
    await _deleteFile(_proxyStateFileName);
  }

  static Future<void> clearTrafficStats() async {
    await _deleteFile(_trafficStatsFileName);
  }

  static Future<void> clearTunnelHealth() async {
    await _deleteFile(_healthFileName);
  }

  static Future<Map<String, dynamic>> readActiveSession() async {
    return _readJsonFile(_activeSessionFileName);
  }

  static Future<void> writeActiveSession(Map<String, dynamic> json) async {
    await _writeJsonFile(_activeSessionFileName, json);
  }

  static Future<void> clearActiveSession() async {
    await _deleteFile(_activeSessionFileName);
  }

  static Future<Map<String, dynamic>> _readJsonFile(String fileName) async {
    try {
      final file = await _file(fileName);
      if (!await file.exists()) {
        return const <String, dynamic>{};
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const <String, dynamic>{};
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // Ignore malformed snapshots and fall back to an empty value.
    }

    return const <String, dynamic>{};
  }

  static Future<void> _writeJsonFile(
    String fileName,
    Map<String, dynamic> json,
  ) async {
    final file = await _file(fileName);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(json),
      flush: true,
    );
  }

  static Future<void> _deleteFile(String fileName) async {
    final file = await _file(fileName);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<File> _file(String fileName) async {
    if (Platform.isMacOS) {
      return File('$_sharedMacosRootPath/$fileName');
    }
    final supportDirectory = await getApplicationSupportDirectory();
    return File(
      '${supportDirectory.path}/$_runtimeDirectoryName/$fileName',
    );
  }
}
