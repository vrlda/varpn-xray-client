import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'macos_tunnel_bridge.dart';
import '../providers/settings_provider.dart';

enum AppLogLevel {
  info,
  warning,
  error,
}

class AppLogEntry {
  final DateTime timestamp;
  final AppLogLevel level;
  final String source;
  final String message;

  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  factory AppLogEntry.fromJson(Map<String, dynamic> json) {
    return AppLogEntry(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      level: _levelFromName(json['level']?.toString()),
      source: json['source']?.toString() ?? 'app',
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'source': source,
      'message': message,
    };
  }

  static AppLogLevel _levelFromName(String? value) {
    return switch (value) {
      'warning' => AppLogLevel.warning,
      'error' => AppLogLevel.error,
      _ => AppLogLevel.info,
    };
  }
}

class AppLogService extends StateNotifier<List<AppLogEntry>> {
  static const String _logsKey = 'app_logs';
  static const int _maxEntries = 500;
  static final AppLogService instance = AppLogService._();

  AppLogService._() : super(const []) {
    _restore();
  }

  bool get _supportsNativeBridge => Platform.isMacOS || Platform.isIOS;

  void info({
    required String source,
    required String message,
  }) {
    _append(
      AppLogLevel.info,
      source: source,
      message: message,
    );
  }

  void warning({
    required String source,
    required String message,
  }) {
    _append(
      AppLogLevel.warning,
      source: source,
      message: message,
    );
  }

  void error({
    required String source,
    required String message,
  }) {
    _append(
      AppLogLevel.error,
      source: source,
      message: message,
    );
  }

  void clear() {
    state = const [];
    _persist();

    if (_supportsNativeBridge) {
      unawaited(MacosTunnelBridge.clearNativeLogs());
    }
  }

  Future<void> syncNativeLogs() async {
    if (!_supportsNativeBridge) {
      return;
    }

    final nativeEntries = await MacosTunnelBridge.fetchNativeLogs();
    if (nativeEntries.isEmpty) {
      return;
    }

    final knownEntries = state.map(_entryKey).toSet();
    final mergedEntries = [...state];
    var didChange = false;

    for (final entryJson in nativeEntries) {
      final entry = AppLogEntry.fromJson(entryJson);
      final key = _entryKey(entry);
      if (knownEntries.add(key)) {
        mergedEntries.add(entry);
        didChange = true;
      }
    }

    if (!didChange) {
      return;
    }

    mergedEntries.sort((left, right) {
      return left.timestamp.compareTo(right.timestamp);
    });

    state = mergedEntries.length > _maxEntries
        ? mergedEntries.sublist(mergedEntries.length - _maxEntries)
        : mergedEntries;
    _persist();
  }

  void _append(
    AppLogLevel level, {
    required String source,
    required String message,
  }) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }

    final next = [
      ...state,
      AppLogEntry(
        timestamp: DateTime.now(),
        level: level,
        source: source,
        message: normalized,
      ),
    ];

    state = next.length > _maxEntries
        ? next.sublist(next.length - _maxEntries)
        : next;

    _persist();
  }

  void _restore() {
    if (!Hive.isBoxOpen(Settings.boxName)) {
      return;
    }

    final rawValue = Hive.box(Settings.boxName).get(_logsKey);
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        return;
      }

      state = decoded
          .whereType<Map>()
          .map(
            (entry) => AppLogEntry.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  void _persist() {
    if (!Hive.isBoxOpen(Settings.boxName)) {
      return;
    }

    final serialized = jsonEncode(
      state.map((entry) => entry.toJson()).toList(),
    );
    Hive.box(Settings.boxName).put(_logsKey, serialized);
  }

  String _entryKey(AppLogEntry entry) {
    return [
      entry.timestamp.toIso8601String(),
      entry.level.name,
      entry.source,
      entry.message,
    ].join('|');
  }
}

final appLogsProvider = StateNotifierProvider<AppLogService, List<AppLogEntry>>(
  (ref) => AppLogService.instance,
);
