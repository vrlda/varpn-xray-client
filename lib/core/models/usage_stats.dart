import 'dart:convert';

class UsageStats {
  final int connectionAttempts;
  final int successfulConnections;
  final int failedConnections;
  final int totalConnectedSeconds;
  final int lastSessionSeconds;
  final int totalUplinkBytes;
  final int totalDownlinkBytes;
  final int lastSessionUplinkBytes;
  final int lastSessionDownlinkBytes;
  final int currentSessionUplinkBytes;
  final int currentSessionDownlinkBytes;
  final String? lastServerName;
  final DateTime? lastConnectedAt;
  final DateTime? currentSessionStartedAt;
  final String? currentSessionServerName;

  const UsageStats({
    required this.connectionAttempts,
    required this.successfulConnections,
    required this.failedConnections,
    required this.totalConnectedSeconds,
    required this.lastSessionSeconds,
    required this.totalUplinkBytes,
    required this.totalDownlinkBytes,
    required this.lastSessionUplinkBytes,
    required this.lastSessionDownlinkBytes,
    required this.currentSessionUplinkBytes,
    required this.currentSessionDownlinkBytes,
    required this.lastServerName,
    required this.lastConnectedAt,
    required this.currentSessionStartedAt,
    required this.currentSessionServerName,
  });

  factory UsageStats.initial() {
    return const UsageStats(
      connectionAttempts: 0,
      successfulConnections: 0,
      failedConnections: 0,
      totalConnectedSeconds: 0,
      lastSessionSeconds: 0,
      totalUplinkBytes: 0,
      totalDownlinkBytes: 0,
      lastSessionUplinkBytes: 0,
      lastSessionDownlinkBytes: 0,
      currentSessionUplinkBytes: 0,
      currentSessionDownlinkBytes: 0,
      lastServerName: null,
      lastConnectedAt: null,
      currentSessionStartedAt: null,
      currentSessionServerName: null,
    );
  }

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      connectionAttempts: _readInt(json['connectionAttempts']),
      successfulConnections: _readInt(json['successfulConnections']),
      failedConnections: _readInt(json['failedConnections']),
      totalConnectedSeconds: _readInt(json['totalConnectedSeconds']),
      lastSessionSeconds: _readInt(json['lastSessionSeconds']),
      totalUplinkBytes: _readInt(json['totalUplinkBytes']),
      totalDownlinkBytes: _readInt(json['totalDownlinkBytes']),
      lastSessionUplinkBytes: _readInt(json['lastSessionUplinkBytes']),
      lastSessionDownlinkBytes: _readInt(json['lastSessionDownlinkBytes']),
      currentSessionUplinkBytes: _readInt(json['currentSessionUplinkBytes']),
      currentSessionDownlinkBytes:
          _readInt(json['currentSessionDownlinkBytes']),
      lastServerName: json['lastServerName']?.toString(),
      lastConnectedAt: _readDateTime(json['lastConnectedAt']),
      currentSessionStartedAt: _readDateTime(json['currentSessionStartedAt']),
      currentSessionServerName: json['currentSessionServerName']?.toString(),
    );
  }

  factory UsageStats.fromRawJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return UsageStats.fromJson(decoded);
      }
      if (decoded is Map) {
        return UsageStats.fromJson(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    } catch (_) {
      // Fall through to initial state.
    }

    return UsageStats.initial();
  }

  Map<String, dynamic> toJson() {
    return {
      'connectionAttempts': connectionAttempts,
      'successfulConnections': successfulConnections,
      'failedConnections': failedConnections,
      'totalConnectedSeconds': totalConnectedSeconds,
      'lastSessionSeconds': lastSessionSeconds,
      'totalUplinkBytes': totalUplinkBytes,
      'totalDownlinkBytes': totalDownlinkBytes,
      'lastSessionUplinkBytes': lastSessionUplinkBytes,
      'lastSessionDownlinkBytes': lastSessionDownlinkBytes,
      'currentSessionUplinkBytes': currentSessionUplinkBytes,
      'currentSessionDownlinkBytes': currentSessionDownlinkBytes,
      'lastServerName': lastServerName,
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      'currentSessionStartedAt': currentSessionStartedAt?.toIso8601String(),
      'currentSessionServerName': currentSessionServerName,
    };
  }

  String toRawJson() => jsonEncode(toJson());

  UsageStats copyWith({
    int? connectionAttempts,
    int? successfulConnections,
    int? failedConnections,
    int? totalConnectedSeconds,
    int? lastSessionSeconds,
    int? totalUplinkBytes,
    int? totalDownlinkBytes,
    int? lastSessionUplinkBytes,
    int? lastSessionDownlinkBytes,
    int? currentSessionUplinkBytes,
    int? currentSessionDownlinkBytes,
    String? lastServerName,
    DateTime? lastConnectedAt,
    DateTime? currentSessionStartedAt,
    String? currentSessionServerName,
    bool clearCurrentSessionStartedAt = false,
    bool clearCurrentSessionServerName = false,
  }) {
    return UsageStats(
      connectionAttempts: connectionAttempts ?? this.connectionAttempts,
      successfulConnections:
          successfulConnections ?? this.successfulConnections,
      failedConnections: failedConnections ?? this.failedConnections,
      totalConnectedSeconds:
          totalConnectedSeconds ?? this.totalConnectedSeconds,
      lastSessionSeconds: lastSessionSeconds ?? this.lastSessionSeconds,
      totalUplinkBytes: totalUplinkBytes ?? this.totalUplinkBytes,
      totalDownlinkBytes: totalDownlinkBytes ?? this.totalDownlinkBytes,
      lastSessionUplinkBytes:
          lastSessionUplinkBytes ?? this.lastSessionUplinkBytes,
      lastSessionDownlinkBytes:
          lastSessionDownlinkBytes ?? this.lastSessionDownlinkBytes,
      currentSessionUplinkBytes:
          currentSessionUplinkBytes ?? this.currentSessionUplinkBytes,
      currentSessionDownlinkBytes:
          currentSessionDownlinkBytes ?? this.currentSessionDownlinkBytes,
      lastServerName: lastServerName ?? this.lastServerName,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      currentSessionStartedAt: clearCurrentSessionStartedAt
          ? null
          : currentSessionStartedAt ?? this.currentSessionStartedAt,
      currentSessionServerName: clearCurrentSessionServerName
          ? null
          : currentSessionServerName ?? this.currentSessionServerName,
    );
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
    return DateTime.tryParse(value.toString());
  }
}
