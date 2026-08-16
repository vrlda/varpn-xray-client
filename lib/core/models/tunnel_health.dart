class TunnelHealth {
  final DateTime? updatedAt;
  final String nativeState;
  final bool xrayRunning;
  final int residentMemoryBytes;
  final int peakResidentMemoryBytes;
  final String memoryPressure;
  final String? activeTransport;
  final String? lastWatchdogAction;
  final DateTime? lastReconnectAt;
  final String? lastReconnectReason;
  final String? lastCrashReason;
  final int? lastXrayExitCode;
  final String? connectionMode;
  final bool helperInstalled;
  final bool helperReachable;
  final String? utunInterfaceName;
  final bool routesConfigured;
  final bool dnsConfigured;
  final String? lastRepairAction;
  final bool proxyConfigured;
  final bool proxyReachable;
  final int protectedServiceCount;
  final int totalServiceCount;
  final String? lastProxyError;

  const TunnelHealth({
    required this.updatedAt,
    required this.nativeState,
    required this.xrayRunning,
    required this.residentMemoryBytes,
    required this.peakResidentMemoryBytes,
    required this.memoryPressure,
    required this.activeTransport,
    required this.lastWatchdogAction,
    required this.lastReconnectAt,
    required this.lastReconnectReason,
    required this.lastCrashReason,
    required this.lastXrayExitCode,
    required this.connectionMode,
    required this.helperInstalled,
    required this.helperReachable,
    required this.utunInterfaceName,
    required this.routesConfigured,
    required this.dnsConfigured,
    required this.lastRepairAction,
    required this.proxyConfigured,
    required this.proxyReachable,
    required this.protectedServiceCount,
    required this.totalServiceCount,
    required this.lastProxyError,
  });

  factory TunnelHealth.empty() {
    return const TunnelHealth(
      updatedAt: null,
      nativeState: 'unknown',
      xrayRunning: false,
      residentMemoryBytes: 0,
      peakResidentMemoryBytes: 0,
      memoryPressure: 'unknown',
      activeTransport: null,
      lastWatchdogAction: null,
      lastReconnectAt: null,
      lastReconnectReason: null,
      lastCrashReason: null,
      lastXrayExitCode: null,
      connectionMode: null,
      helperInstalled: false,
      helperReachable: false,
      utunInterfaceName: null,
      routesConfigured: false,
      dnsConfigured: false,
      lastRepairAction: null,
      proxyConfigured: false,
      proxyReachable: false,
      protectedServiceCount: 0,
      totalServiceCount: 0,
      lastProxyError: null,
    );
  }

  factory TunnelHealth.fromJson(Map<String, dynamic> json) {
    return TunnelHealth(
      updatedAt: _readDateTime(json['updatedAt']),
      nativeState: json['nativeState']?.toString() ?? 'unknown',
      xrayRunning: _readBool(json['xrayRunning']) ?? false,
      residentMemoryBytes: _readInt(json['residentMemoryBytes']) ?? 0,
      peakResidentMemoryBytes: _readInt(json['peakResidentMemoryBytes']) ?? 0,
      memoryPressure: json['memoryPressure']?.toString() ?? 'unknown',
      activeTransport: _readString(json['activeTransport']),
      lastWatchdogAction: _readString(json['lastWatchdogAction']),
      lastReconnectAt: _readDateTime(json['lastReconnectAt']),
      lastReconnectReason: _readString(json['lastReconnectReason']),
      lastCrashReason: _readString(json['lastCrashReason']),
      lastXrayExitCode: _readInt(json['lastXrayExitCode']),
      connectionMode: _readString(json['connectionMode']),
      helperInstalled: _readBool(json['helperInstalled']) ?? false,
      helperReachable: _readBool(json['helperReachable']) ?? false,
      utunInterfaceName: _readString(json['utunInterfaceName']),
      routesConfigured: _readBool(json['routesConfigured']) ?? false,
      dnsConfigured: _readBool(json['dnsConfigured']) ?? false,
      lastRepairAction: _readString(json['lastRepairAction']),
      proxyConfigured: _readBool(json['proxyConfigured']) ?? false,
      proxyReachable: _readBool(json['proxyReachable']) ?? false,
      protectedServiceCount: _readInt(json['protectedServiceCount']) ?? 0,
      totalServiceCount: _readInt(json['totalServiceCount']) ?? 0,
      lastProxyError: _readString(json['lastProxyError']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'updatedAt': updatedAt?.toIso8601String(),
      'nativeState': nativeState,
      'xrayRunning': xrayRunning,
      'residentMemoryBytes': residentMemoryBytes,
      'peakResidentMemoryBytes': peakResidentMemoryBytes,
      'memoryPressure': memoryPressure,
      'activeTransport': activeTransport,
      'lastWatchdogAction': lastWatchdogAction,
      'lastReconnectAt': lastReconnectAt?.toIso8601String(),
      'lastReconnectReason': lastReconnectReason,
      'lastCrashReason': lastCrashReason,
      'lastXrayExitCode': lastXrayExitCode,
      'connectionMode': connectionMode,
      'helperInstalled': helperInstalled,
      'helperReachable': helperReachable,
      'utunInterfaceName': utunInterfaceName,
      'routesConfigured': routesConfigured,
      'dnsConfigured': dnsConfigured,
      'lastRepairAction': lastRepairAction,
      'proxyConfigured': proxyConfigured,
      'proxyReachable': proxyReachable,
      'protectedServiceCount': protectedServiceCount,
      'totalServiceCount': totalServiceCount,
      'lastProxyError': lastProxyError,
    };
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

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static bool? _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().toLowerCase().trim();
    switch (normalized) {
      case 'true':
        return true;
      case 'false':
        return false;
      default:
        return null;
    }
  }

  static String? _readString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
  }
}
