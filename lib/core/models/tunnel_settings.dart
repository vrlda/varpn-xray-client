class TunnelSettings {
  final int mtu;
  final bool ipv6Enabled;
  final bool bypassLocalNetworks;
  final String dnsMode;
  final List<String> dnsServers;
  final bool strictRouting;

  const TunnelSettings({
    required this.mtu,
    required this.ipv6Enabled,
    required this.bypassLocalNetworks,
    required this.dnsMode,
    required this.dnsServers,
    required this.strictRouting,
  });

  factory TunnelSettings.defaults() {
    return const TunnelSettings(
      mtu: 1500,
      ipv6Enabled: true,
      bypassLocalNetworks: true,
      dnsMode: 'custom',
      dnsServers: ['1.1.1.1', '8.8.8.8'],
      strictRouting: true,
    );
  }

  factory TunnelSettings.fromJson(Map<String, dynamic> json) {
    final defaults = TunnelSettings.defaults();

    return TunnelSettings(
      mtu: _readInt(json['mtu']) ?? defaults.mtu,
      ipv6Enabled: _readBool(json['ipv6Enabled']) ?? defaults.ipv6Enabled,
      bypassLocalNetworks: _readBool(json['bypassLocalNetworks']) ??
          defaults.bypassLocalNetworks,
      dnsMode: json['dnsMode']?.toString() ?? defaults.dnsMode,
      dnsServers: _readStringList(json['dnsServers'], defaults.dnsServers),
      strictRouting: _readBool(json['strictRouting']) ?? defaults.strictRouting,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mtu': mtu,
      'ipv6Enabled': ipv6Enabled,
      'bypassLocalNetworks': bypassLocalNetworks,
      'dnsMode': dnsMode,
      'dnsServers': dnsServers,
      'strictRouting': strictRouting,
    };
  }

  TunnelSettings copyWith({
    int? mtu,
    bool? ipv6Enabled,
    bool? bypassLocalNetworks,
    String? dnsMode,
    List<String>? dnsServers,
    bool? strictRouting,
  }) {
    return TunnelSettings(
      mtu: mtu ?? this.mtu,
      ipv6Enabled: ipv6Enabled ?? this.ipv6Enabled,
      bypassLocalNetworks: bypassLocalNetworks ?? this.bypassLocalNetworks,
      dnsMode: dnsMode ?? this.dnsMode,
      dnsServers: dnsServers ?? this.dnsServers,
      strictRouting: strictRouting ?? this.strictRouting,
    );
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

  static List<String> _readStringList(
    Object? value,
    List<String> fallback,
  ) {
    if (value is List) {
      final normalized = value
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return fallback;
  }
}
