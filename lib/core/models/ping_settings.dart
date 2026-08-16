class PingSettings {
  static const String defaultUrl = 'https://www.gstatic.com/generate_204';
  static const int defaultIntervalSeconds = 45;

  final String protocol;
  final String url;
  final String displayMode;
  final int intervalSeconds;

  const PingSettings({
    required this.protocol,
    required this.url,
    required this.displayMode,
    required this.intervalSeconds,
  });

  factory PingSettings.defaults() {
    return const PingSettings(
      protocol: 'tcp',
      url: defaultUrl,
      displayMode: 'time',
      intervalSeconds: defaultIntervalSeconds,
    );
  }

  factory PingSettings.fromJson(Map<String, dynamic> json) {
    final defaults = PingSettings.defaults();
    return PingSettings(
      protocol: json['protocol'] as String? ?? defaults.protocol,
      url: json['url'] as String? ?? defaults.url,
      displayMode: json['displayMode'] as String? ?? defaults.displayMode,
      intervalSeconds:
          _readInt(json['intervalSeconds']) ?? defaults.intervalSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol,
      'url': url,
      'displayMode': displayMode,
      'intervalSeconds': intervalSeconds,
    };
  }

  PingSettings copyWith({
    String? protocol,
    String? url,
    String? displayMode,
    int? intervalSeconds,
  }) {
    return PingSettings(
      protocol: protocol ?? this.protocol,
      url: url ?? this.url,
      displayMode: displayMode ?? this.displayMode,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    );
  }

  bool get usesProxyTransport =>
      protocol == 'proxy_get' || protocol == 'proxy_head';

  static int? _readInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}
