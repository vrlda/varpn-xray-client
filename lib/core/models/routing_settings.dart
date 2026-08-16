class RoutingSettings {
  static const String defaultGeositeUrl =
      'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat';
  static const String defaultGeoipUrl =
      'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat';

  final bool enabled;
  final String selectedPresetId;
  final List<RoutingPresetConfig> presets;
  final String geositeUrl;
  final String geoipUrl;
  final DateTime? geositeUpdatedAt;
  final DateTime? geoipUpdatedAt;
  final int? geositeBytes;
  final int? geoipBytes;

  const RoutingSettings({
    required this.enabled,
    required this.selectedPresetId,
    required this.presets,
    required this.geositeUrl,
    required this.geoipUrl,
    required this.geositeUpdatedAt,
    required this.geoipUpdatedAt,
    required this.geositeBytes,
    required this.geoipBytes,
  });

  factory RoutingSettings.defaults() {
    final preset = RoutingPresetConfig.defaultRu();
    return RoutingSettings(
      enabled: false,
      selectedPresetId: preset.id,
      presets: [preset],
      geositeUrl: defaultGeositeUrl,
      geoipUrl: defaultGeoipUrl,
      geositeUpdatedAt: null,
      geoipUpdatedAt: null,
      geositeBytes: null,
      geoipBytes: null,
    );
  }

  factory RoutingSettings.fromJson(Map<String, dynamic> json) {
    final defaults = RoutingSettings.defaults();
    final rawPresets = json['presets'];

    final presets = rawPresets is List
        ? rawPresets
            .whereType<Map>()
            .map(
              (preset) => RoutingPresetConfig.fromJson(
                preset.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              ),
            )
            .toList()
        : <RoutingPresetConfig>[];

    final effectivePresets =
        presets.isEmpty ? [_migrateLegacyPreset(json)] : presets;

    final selectedPresetId =
        json['selectedPresetId'] as String? ?? effectivePresets.first.id;
    final hasSelectedPreset =
        effectivePresets.any((preset) => preset.id == selectedPresetId);

    return RoutingSettings(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      selectedPresetId:
          hasSelectedPreset ? selectedPresetId : effectivePresets.first.id,
      presets: effectivePresets,
      geositeUrl: json['geositeUrl'] as String? ?? defaults.geositeUrl,
      geoipUrl: json['geoipUrl'] as String? ?? defaults.geoipUrl,
      geositeUpdatedAt: _readDateTime(json['geositeUpdatedAt']),
      geoipUpdatedAt: _readDateTime(json['geoipUpdatedAt']),
      geositeBytes: _readInt(json['geositeBytes']),
      geoipBytes: _readInt(json['geoipBytes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'selectedPresetId': selectedPresetId,
      'presets': presets.map((preset) => preset.toJson()).toList(),
      'geositeUrl': geositeUrl,
      'geoipUrl': geoipUrl,
      'geositeUpdatedAt': geositeUpdatedAt?.toIso8601String(),
      'geoipUpdatedAt': geoipUpdatedAt?.toIso8601String(),
      'geositeBytes': geositeBytes,
      'geoipBytes': geoipBytes,
    };
  }

  RoutingPresetConfig get selectedPreset =>
      findPreset(selectedPresetId) ?? presets.first;

  RoutingPresetConfig? findPreset(String presetId) {
    for (final preset in presets) {
      if (preset.id == presetId) {
        return preset;
      }
    }
    return null;
  }

  RoutingSettings copyWith({
    bool? enabled,
    String? selectedPresetId,
    List<RoutingPresetConfig>? presets,
    String? geositeUrl,
    String? geoipUrl,
    DateTime? geositeUpdatedAt,
    DateTime? geoipUpdatedAt,
    int? geositeBytes,
    int? geoipBytes,
  }) {
    final nextPresets = presets ?? this.presets;
    final nextSelectedPresetId = selectedPresetId ?? this.selectedPresetId;
    final hasSelectedPreset =
        nextPresets.any((preset) => preset.id == nextSelectedPresetId);

    return RoutingSettings(
      enabled: enabled ?? this.enabled,
      selectedPresetId:
          hasSelectedPreset ? nextSelectedPresetId : nextPresets.first.id,
      presets: nextPresets,
      geositeUrl: geositeUrl ?? this.geositeUrl,
      geoipUrl: geoipUrl ?? this.geoipUrl,
      geositeUpdatedAt: geositeUpdatedAt ?? this.geositeUpdatedAt,
      geoipUpdatedAt: geoipUpdatedAt ?? this.geoipUpdatedAt,
      geositeBytes: geositeBytes ?? this.geositeBytes,
      geoipBytes: geoipBytes ?? this.geoipBytes,
    );
  }

  RoutingSettings selectPreset(String presetId) {
    return copyWith(selectedPresetId: presetId);
  }

  RoutingSettings updatePreset(RoutingPresetConfig preset) {
    final nextPresets = [
      for (final current in presets)
        if (current.id == preset.id) preset else current,
    ];

    if (!nextPresets.any((current) => current.id == preset.id)) {
      nextPresets.add(preset);
    }

    return copyWith(
      presets: nextPresets,
      selectedPresetId:
          selectedPresetId == preset.id ? preset.id : selectedPresetId,
    );
  }

  RoutingSettings addPreset({
    required String name,
    RoutingPresetConfig? sourcePreset,
  }) {
    final seed = sourcePreset ?? selectedPreset;
    final preset = seed.copyWith(
      id: _createPresetId(),
      name: name,
    );

    return copyWith(
      presets: [...presets, preset],
      selectedPresetId: preset.id,
    );
  }

  RoutingSettings removePreset(String presetId) {
    final nextPresets = [
      for (final preset in presets)
        if (preset.id != presetId) preset,
    ];

    if (nextPresets.isEmpty) {
      final fallback = RoutingPresetConfig.defaultRu();
      return copyWith(
        presets: [fallback],
        selectedPresetId: fallback.id,
      );
    }

    return copyWith(
      presets: nextPresets,
      selectedPresetId: selectedPresetId == presetId
          ? nextPresets.first.id
          : selectedPresetId,
    );
  }

  static String _createPresetId() {
    return 'preset-${DateTime.now().microsecondsSinceEpoch}';
  }

  static RoutingPresetConfig _migrateLegacyPreset(Map<String, dynamic> json) {
    final defaultPreset = RoutingPresetConfig.defaultRu();
    final selectedPresetId =
        json['selectedPresetId'] as String? ?? defaultPreset.id;

    return RoutingPresetConfig(
      id: selectedPresetId,
      name: selectedPresetId == 'custom' ? 'Custom' : defaultPreset.name,
      globalProxyEnabled: json['globalProxyEnabled'] as bool? ?? true,
      proxyRules: json['proxyRules'] as String? ?? defaultPreset.proxyRules,
      directRules: json['directRules'] as String? ?? defaultPreset.directRules,
      blockRules: json['blockRules'] as String? ?? defaultPreset.blockRules,
      trimGeofiles: json['trimGeofiles'] as bool? ?? false,
      fakeDnsEnabled: json['fakeDnsEnabled'] as bool? ?? false,
      domainStrategy: json['domainStrategy'] as String? ?? 'IPIfNonMatch',
      remoteDnsType: json['remoteDnsType'] as String? ?? 'DoH',
      remoteDnsValue: json['remoteDnsValue'] as String? ??
          'https://cloudflare-dns.com/dns-query',
      remoteDnsIp: json['remoteDnsIp'] as String? ?? '1.1.1.1',
      domesticDnsType: json['domesticDnsType'] as String? ?? 'Plain',
      domesticDnsValue: json['domesticDnsValue'] as String? ?? '8.8.8.8',
    );
  }

  static DateTime? _readDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

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

class RoutingPresetConfig {
  final String id;
  final String name;
  final bool globalProxyEnabled;
  final String proxyRules;
  final String directRules;
  final String blockRules;
  final bool trimGeofiles;
  final bool fakeDnsEnabled;
  final String domainStrategy;
  final String remoteDnsType;
  final String remoteDnsValue;
  final String remoteDnsIp;
  final String domesticDnsType;
  final String domesticDnsValue;

  const RoutingPresetConfig({
    required this.id,
    required this.name,
    required this.globalProxyEnabled,
    required this.proxyRules,
    required this.directRules,
    required this.blockRules,
    required this.trimGeofiles,
    required this.fakeDnsEnabled,
    required this.domainStrategy,
    required this.remoteDnsType,
    required this.remoteDnsValue,
    required this.remoteDnsIp,
    required this.domesticDnsType,
    required this.domesticDnsValue,
  });

  factory RoutingPresetConfig.defaultRu() {
    return const RoutingPresetConfig(
      id: 'ru',
      name: 'Ru',
      globalProxyEnabled: true,
      proxyRules: 'geosite:google\ngeosite:tiktok\n92.100.5.0/22',
      directRules: 'geoip:ru\ngeosite:category-ru',
      blockRules: 'geosite:category-ads-all',
      trimGeofiles: false,
      fakeDnsEnabled: false,
      domainStrategy: 'IPIfNonMatch',
      remoteDnsType: 'DoH',
      remoteDnsValue: 'https://cloudflare-dns.com/dns-query',
      remoteDnsIp: '1.1.1.1',
      domesticDnsType: 'Plain',
      domesticDnsValue: '8.8.8.8',
    );
  }

  factory RoutingPresetConfig.fromJson(Map<String, dynamic> json) {
    final defaults = RoutingPresetConfig.defaultRu();

    return RoutingPresetConfig(
      id: json['id'] as String? ??
          'preset-${DateTime.now().microsecondsSinceEpoch}',
      name: json['name'] as String? ?? defaults.name,
      globalProxyEnabled:
          json['globalProxyEnabled'] as bool? ?? defaults.globalProxyEnabled,
      proxyRules: json['proxyRules'] as String? ?? defaults.proxyRules,
      directRules: json['directRules'] as String? ?? defaults.directRules,
      blockRules: json['blockRules'] as String? ?? defaults.blockRules,
      trimGeofiles: json['trimGeofiles'] as bool? ?? defaults.trimGeofiles,
      fakeDnsEnabled:
          json['fakeDnsEnabled'] as bool? ?? defaults.fakeDnsEnabled,
      domainStrategy:
          json['domainStrategy'] as String? ?? defaults.domainStrategy,
      remoteDnsType: json['remoteDnsType'] as String? ?? defaults.remoteDnsType,
      remoteDnsValue:
          json['remoteDnsValue'] as String? ?? defaults.remoteDnsValue,
      remoteDnsIp: json['remoteDnsIp'] as String? ?? defaults.remoteDnsIp,
      domesticDnsType:
          json['domesticDnsType'] as String? ?? defaults.domesticDnsType,
      domesticDnsValue:
          json['domesticDnsValue'] as String? ?? defaults.domesticDnsValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'globalProxyEnabled': globalProxyEnabled,
      'proxyRules': proxyRules,
      'directRules': directRules,
      'blockRules': blockRules,
      'trimGeofiles': trimGeofiles,
      'fakeDnsEnabled': fakeDnsEnabled,
      'domainStrategy': domainStrategy,
      'remoteDnsType': remoteDnsType,
      'remoteDnsValue': remoteDnsValue,
      'remoteDnsIp': remoteDnsIp,
      'domesticDnsType': domesticDnsType,
      'domesticDnsValue': domesticDnsValue,
    };
  }

  RoutingPresetConfig copyWith({
    String? id,
    String? name,
    bool? globalProxyEnabled,
    String? proxyRules,
    String? directRules,
    String? blockRules,
    bool? trimGeofiles,
    bool? fakeDnsEnabled,
    String? domainStrategy,
    String? remoteDnsType,
    String? remoteDnsValue,
    String? remoteDnsIp,
    String? domesticDnsType,
    String? domesticDnsValue,
  }) {
    return RoutingPresetConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      globalProxyEnabled: globalProxyEnabled ?? this.globalProxyEnabled,
      proxyRules: proxyRules ?? this.proxyRules,
      directRules: directRules ?? this.directRules,
      blockRules: blockRules ?? this.blockRules,
      trimGeofiles: trimGeofiles ?? this.trimGeofiles,
      fakeDnsEnabled: fakeDnsEnabled ?? this.fakeDnsEnabled,
      domainStrategy: domainStrategy ?? this.domainStrategy,
      remoteDnsType: remoteDnsType ?? this.remoteDnsType,
      remoteDnsValue: remoteDnsValue ?? this.remoteDnsValue,
      remoteDnsIp: remoteDnsIp ?? this.remoteDnsIp,
      domesticDnsType: domesticDnsType ?? this.domesticDnsType,
      domesticDnsValue: domesticDnsValue ?? this.domesticDnsValue,
    );
  }
}

class RoutingSuggestions {
  static const geositeTags = [
    'geosite:category-ads-all',
    'geosite:category-ru',
    'geosite:google',
    'geosite:tiktok',
    'geosite:youtube',
    'geosite:telegram',
    'geosite:openai',
    'geosite:github',
    'geosite:discord',
    'geosite:netflix',
    'geosite:apple',
    'geosite:microsoft',
    'geosite:geolocation-!ru',
  ];

  static const geoipTags = [
    'geoip:private',
    'geoip:ru',
    'geoip:cn',
    'geoip:ir',
    'geoip:us',
    'geoip:de',
    'geoip:gb',
    'geoip:fr',
    'geoip:fi',
    'geoip:nl',
    'geoip:lv',
  ];
}
