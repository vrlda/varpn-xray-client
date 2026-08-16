import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/usage_stats.dart';
import '../services/macos_tunnel_bridge.dart';
import '../services/runtime_snapshot_store.dart';
import 'settings_provider.dart';

final usageStatsProvider =
    StateNotifierProvider<UsageStatsNotifier, UsageStats>(
  (ref) => UsageStatsNotifier(),
);

class UsageStatsNotifier extends StateNotifier<UsageStats> {
  UsageStatsNotifier() : super(_loadInitialState()) {
    unawaited(syncTrafficStats());
  }

  static const String _usageStatsKey = 'usage_stats';
  bool get _supportsNativeBridge => Platform.isMacOS || Platform.isIOS;

  void recordConnectionAttempt(String serverName) {
    state = state.copyWith(
      connectionAttempts: state.connectionAttempts + 1,
      lastServerName: serverName,
    );
    _persist();
  }

  void recordConnectionSuccess(String serverName, DateTime connectedAt) {
    state = state.copyWith(
      successfulConnections: state.successfulConnections + 1,
      lastServerName: serverName,
      lastConnectedAt: connectedAt,
      currentSessionStartedAt: connectedAt,
      currentSessionServerName: serverName,
    );
    _persist();
    unawaited(syncTrafficStats());
  }

  void recordConnectionFailure(String serverName) {
    state = state.copyWith(
      failedConnections: state.failedConnections + 1,
      lastServerName: serverName,
    );
    _persist();
  }

  void recordDisconnect(DateTime disconnectedAt) {
    final sessionStartedAt = state.currentSessionStartedAt;
    final connectedSeconds = sessionStartedAt == null
        ? 0
        : disconnectedAt
            .difference(sessionStartedAt)
            .inSeconds
            .clamp(0, 2147483647);

    state = state.copyWith(
      totalConnectedSeconds: state.totalConnectedSeconds + connectedSeconds,
      lastSessionSeconds: connectedSeconds,
      clearCurrentSessionStartedAt: true,
      clearCurrentSessionServerName: true,
    );
    _persist();
    unawaited(syncTrafficStats());
  }

  Future<void> syncTrafficStats() async {
    if (!_supportsNativeBridge) {
      return;
    }

    try {
      Map<String, dynamic> snapshot;
      if (Platform.isMacOS) {
        snapshot = await RuntimeSnapshotStore.readTrafficStats();
        if (snapshot.isEmpty) {
          snapshot = await MacosTunnelBridge.trafficStats();
        }
      } else {
        snapshot = await MacosTunnelBridge.trafficStats();
      }
      if (snapshot.isEmpty) {
        return;
      }

      final sessionStartedAt =
          _readDateTime(snapshot['currentSessionStartedAt']);
      state = state.copyWith(
        totalUplinkBytes: _readInt(snapshot['totalUplinkBytes']),
        totalDownlinkBytes: _readInt(snapshot['totalDownlinkBytes']),
        lastSessionUplinkBytes: _readInt(snapshot['lastSessionUplinkBytes']),
        lastSessionDownlinkBytes:
            _readInt(snapshot['lastSessionDownlinkBytes']),
        currentSessionUplinkBytes:
            _readInt(snapshot['currentSessionUplinkBytes']),
        currentSessionDownlinkBytes:
            _readInt(snapshot['currentSessionDownlinkBytes']),
        currentSessionStartedAt: sessionStartedAt,
        clearCurrentSessionStartedAt: sessionStartedAt == null,
        clearCurrentSessionServerName: sessionStartedAt == null,
      );
      _persist();
    } catch (_) {
      // Ignore transient bridge read failures.
    }
  }

  Future<void> reset() async {
    state = UsageStats.initial();
    _persist();

    if (Platform.isMacOS) {
      await RuntimeSnapshotStore.clearTrafficStats();
      await RuntimeSnapshotStore.clearTunnelHealth();
      await RuntimeSnapshotStore.clearProxyState();
    } else if (Platform.isIOS) {
      await MacosTunnelBridge.clearNativeLogs();
    }
  }

  static UsageStats _loadInitialState() {
    if (!Hive.isBoxOpen(Settings.boxName)) {
      return UsageStats.initial();
    }

    final rawValue = Hive.box(Settings.boxName).get(_usageStatsKey);
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return UsageStats.initial();
    }

    return UsageStats.fromRawJson(rawValue);
  }

  void _persist() {
    if (!Hive.isBoxOpen(Settings.boxName)) {
      return;
    }

    Hive.box(Settings.boxName).put(_usageStatsKey, state.toRawJson());
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }

    return DateTime.tryParse(normalized);
  }
}
