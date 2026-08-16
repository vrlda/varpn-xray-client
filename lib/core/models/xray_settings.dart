class XraySettings {
  final String logLevel;
  final bool sniffingEnabled;
  final bool allowInsecure;
  final String transportOverride;

  const XraySettings({
    required this.logLevel,
    required this.sniffingEnabled,
    required this.allowInsecure,
    required this.transportOverride,
  });

  factory XraySettings.defaults() {
    return const XraySettings(
      logLevel: 'warning',
      sniffingEnabled: true,
      allowInsecure: false,
      transportOverride: 'auto',
    );
  }

  factory XraySettings.fromJson(Map<String, dynamic> json) {
    final defaults = XraySettings.defaults();

    return XraySettings(
      logLevel: json['logLevel']?.toString() ?? defaults.logLevel,
      sniffingEnabled:
          _readBool(json['sniffingEnabled']) ?? defaults.sniffingEnabled,
      allowInsecure: _readBool(json['allowInsecure']) ?? defaults.allowInsecure,
      transportOverride:
          json['transportOverride']?.toString() ?? defaults.transportOverride,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logLevel': logLevel,
      'sniffingEnabled': sniffingEnabled,
      'allowInsecure': allowInsecure,
      'transportOverride': transportOverride,
    };
  }

  XraySettings copyWith({
    String? logLevel,
    bool? sniffingEnabled,
    bool? allowInsecure,
    String? transportOverride,
  }) {
    return XraySettings(
      logLevel: logLevel ?? this.logLevel,
      sniffingEnabled: sniffingEnabled ?? this.sniffingEnabled,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      transportOverride: transportOverride ?? this.transportOverride,
    );
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
}
