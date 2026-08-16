import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/connection_source.dart';
import '../models/ping_settings.dart';
import '../models/routing_settings.dart';
import '../models/tunnel_settings.dart';
import '../services/subscription_parser.dart';
import '../models/xray_settings.dart';

part 'settings_provider.g.dart';

@riverpod
class Settings extends _$Settings {
  static const String boxName = 'settings';
  static const String _devModeKey = 'dev_mode';
  static const String _languageKey = 'language';
  static const String _themeKey = 'theme';
  static const String _subscriptionLinkKey = 'subscription_link';
  static const String _connectionSourcesKey = 'connection_sources';
  static const String _activeConnectionSourceIdKey = 'active_connection_source';
  static const String _routingSettingsKey = 'routing_settings';
  static const String _pingSettingsKey = 'ping_settings';
  static const String _developerToolsUnlockedKey = 'developer_tools_unlocked';
  static const String _tunnelSettingsKey = 'tunnel_settings';
  static const String _xraySettingsKey = 'xray_settings';

  @override
  SettingsState build() {
    final box = Hive.box(boxName);
    final devMode = box.get(_devModeKey, defaultValue: false) as bool;
    final connectionSources = _loadConnectionSources(box);
    final activeConnectionSourceId = _resolveActiveConnectionSourceId(
      box,
      connectionSources,
    );

    return SettingsState(
      devMode: devMode,
      developerToolsUnlocked:
          (box.get(_developerToolsUnlockedKey, defaultValue: false) as bool) ||
              box.containsKey(_devModeKey),
      language: box.get(_languageKey, defaultValue: 'ru') as String,
      theme: box.get(_themeKey, defaultValue: 'system') as String,
      connectionSources: connectionSources,
      activeConnectionSourceId: activeConnectionSourceId,
      routingSettings: _loadRoutingSettings(box),
      pingSettings: _loadPingSettings(box),
      tunnelSettings: _loadTunnelSettings(box),
      xraySettings: _loadXraySettings(box),
    );
  }

  void toggleDevMode() {
    final box = Hive.box(boxName);
    final newValue = !state.devMode;
    box.put(_devModeKey, newValue);
    box.put(_developerToolsUnlockedKey, true);
    state = state.copyWith(
      devMode: newValue,
      developerToolsUnlocked: true,
    );
  }

  void setDevMode(bool value) {
    final box = Hive.box(boxName);
    box.put(_devModeKey, value);
    box.put(_developerToolsUnlockedKey, true);
    state = state.copyWith(
      devMode: value,
      developerToolsUnlocked: true,
    );
  }

  void unlockDeveloperTools() {
    final box = Hive.box(boxName);
    box.put(_developerToolsUnlockedKey, true);
    state = state.copyWith(developerToolsUnlocked: true);
  }

  void upsertConnectionSource(
    ConnectionSource source, {
    bool makeActive = false,
  }) {
    final box = Hive.box(boxName);
    final updated = [...state.connectionSources];
    final existingIndex = updated.indexWhere((item) => item.id == source.id);
    if (existingIndex == -1) {
      updated.add(source);
    } else {
      updated[existingIndex] = source;
    }

    final nextActiveId =
        makeActive ? source.id : state.activeConnectionSourceId ?? source.id;
    _persistConnectionSources(
      box,
      updated,
      activeConnectionSourceId: nextActiveId,
    );
    state = state.copyWith(
      connectionSources: updated,
      activeConnectionSourceId: nextActiveId,
    );
  }

  void removeConnectionSource(String sourceId) {
    final box = Hive.box(boxName);
    final updated = state.connectionSources
        .where((source) => source.id != sourceId)
        .toList(growable: false);
    final nextActiveId = state.activeConnectionSourceId == sourceId
        ? (updated.isNotEmpty ? updated.first.id : null)
        : state.activeConnectionSourceId;
    _persistConnectionSources(
      box,
      updated,
      activeConnectionSourceId: nextActiveId,
    );
    state = state.copyWith(
      connectionSources: updated,
      activeConnectionSourceId: nextActiveId,
    );
  }

  void setConnectionSourceEnabled(String sourceId, bool enabled) {
    final box = Hive.box(boxName);
    final updated = state.connectionSources
        .map(
          (source) => source.id == sourceId
              ? source.copyWith(enabled: enabled)
              : source,
        )
        .toList(growable: false);
    _persistConnectionSources(
      box,
      updated,
      activeConnectionSourceId: state.activeConnectionSourceId,
    );
    state = state.copyWith(connectionSources: updated);
  }

  void markConnectionSourceRefresh(
    String sourceId, {
    DateTime? updatedAt,
    String? lastRefreshError,
  }) {
    final box = Hive.box(boxName);
    final updated = state.connectionSources
        .map(
          (source) => source.id == sourceId
              ? source.copyWith(
                  updatedAt: updatedAt,
                  lastRefreshError: lastRefreshError,
                )
              : source,
        )
        .toList(growable: false);
    _persistConnectionSources(
      box,
      updated,
      activeConnectionSourceId: state.activeConnectionSourceId,
    );
    state = state.copyWith(connectionSources: updated);
  }

  void setActiveConnectionSource(String sourceId) {
    final box = Hive.box(boxName);
    box.put(_activeConnectionSourceIdKey, sourceId);
    state = state.copyWith(activeConnectionSourceId: sourceId);
  }

  void setLanguage(String language) {
    final box = Hive.box(boxName);
    box.put(_languageKey, language);
    state = state.copyWith(language: language);
  }

  void setTheme(String theme) {
    final box = Hive.box(boxName);
    box.put(_themeKey, theme);
    state = state.copyWith(theme: theme);
  }

  void setSubscriptionLink(String value) {
    final source = _buildLegacySource(value);
    upsertConnectionSource(source, makeActive: true);
  }

  void clearSubscriptionLink() {
    final activeId = state.activeConnectionSourceId;
    if (activeId == null) {
      return;
    }
    removeConnectionSource(activeId);
  }

  void saveRoutingSettings(RoutingSettings value) {
    final box = Hive.box(boxName);
    box.put(_routingSettingsKey, jsonEncode(value.toJson()));
    state = state.copyWith(routingSettings: value);
  }

  void savePingSettings(PingSettings value) {
    final box = Hive.box(boxName);
    box.put(_pingSettingsKey, jsonEncode(value.toJson()));
    state = state.copyWith(pingSettings: value);
  }

  void saveTunnelSettings(TunnelSettings value) {
    final box = Hive.box(boxName);
    box.put(_tunnelSettingsKey, jsonEncode(value.toJson()));
    state = state.copyWith(tunnelSettings: value);
  }

  void saveXraySettings(XraySettings value) {
    final box = Hive.box(boxName);
    box.put(_xraySettingsKey, jsonEncode(value.toJson()));
    state = state.copyWith(xraySettings: value);
  }

  void resetAll() {
    final box = Hive.box(boxName);
    for (final key in const [
      _devModeKey,
      _languageKey,
      _themeKey,
      _subscriptionLinkKey,
      _connectionSourcesKey,
      _activeConnectionSourceIdKey,
      _routingSettingsKey,
      _pingSettingsKey,
      _developerToolsUnlockedKey,
      _tunnelSettingsKey,
      _xraySettingsKey,
    ]) {
      box.delete(key);
    }

    state = SettingsState(
      devMode: false,
      developerToolsUnlocked: false,
      language: 'ru',
      theme: 'system',
      connectionSources: const [],
      activeConnectionSourceId: null,
      routingSettings: RoutingSettings.defaults(),
      pingSettings: PingSettings.defaults(),
      tunnelSettings: TunnelSettings.defaults(),
      xraySettings: XraySettings.defaults(),
    );
  }

  RoutingSettings _loadRoutingSettings(Box<dynamic> box) {
    final rawValue = box.get(_routingSettingsKey);
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return RoutingSettings.defaults();
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        return RoutingSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return RoutingSettings.fromJson(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    } catch (_) {
      // Fall through to defaults.
    }

    return RoutingSettings.defaults();
  }

  PingSettings _loadPingSettings(Box<dynamic> box) {
    final rawValue = box.get(_pingSettingsKey);
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return PingSettings.defaults();
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        return PingSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return PingSettings.fromJson(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    } catch (_) {
      // Fall through to defaults.
    }

    return PingSettings.defaults();
  }

  TunnelSettings _loadTunnelSettings(Box<dynamic> box) {
    final rawValue = box.get(_tunnelSettingsKey);
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return TunnelSettings.defaults();
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        return TunnelSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return TunnelSettings.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Fall through to defaults.
    }

    return TunnelSettings.defaults();
  }

  XraySettings _loadXraySettings(Box<dynamic> box) {
    final rawValue = box.get(_xraySettingsKey);
    if (rawValue is! String || rawValue.trim().isEmpty) {
      return XraySettings.defaults();
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        return XraySettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return XraySettings.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Fall through to defaults.
    }

    return XraySettings.defaults();
  }

  List<ConnectionSource> _loadConnectionSources(Box<dynamic> box) {
    final rawValue = box.get(_connectionSourcesKey);
    if (rawValue is String && rawValue.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is List) {
          return decoded
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return ConnectionSource.fromJson(item);
                }
                if (item is Map) {
                  return ConnectionSource.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  );
                }
                return null;
              })
              .whereType<ConnectionSource>()
              .toList(growable: false);
        }
      } catch (_) {
        // Fall through to legacy migration.
      }
    }

    final legacyInput =
        (box.get(_subscriptionLinkKey, defaultValue: '') as String).trim();
    if (legacyInput.isEmpty) {
      return const [];
    }

    final migrated = _buildLegacySource(legacyInput);
    final migratedSources = [migrated];
    _persistConnectionSources(
      box,
      migratedSources,
      activeConnectionSourceId: migrated.id,
    );
    return migratedSources;
  }

  String? _resolveActiveConnectionSourceId(
    Box<dynamic> box,
    List<ConnectionSource> sources,
  ) {
    if (sources.isEmpty) {
      return null;
    }

    final savedId = box.get(_activeConnectionSourceIdKey) as String?;
    if (savedId != null && sources.any((source) => source.id == savedId)) {
      return savedId;
    }

    final fallbackId = sources.first.id;
    box.put(_activeConnectionSourceIdKey, fallbackId);
    return fallbackId;
  }

  void _persistConnectionSources(
    Box<dynamic> box,
    List<ConnectionSource> sources, {
    required String? activeConnectionSourceId,
  }) {
    box.put(
      _connectionSourcesKey,
      jsonEncode(sources.map((source) => source.toJson()).toList()),
    );
    if (activeConnectionSourceId == null) {
      box.delete(_activeConnectionSourceIdKey);
    } else {
      box.put(_activeConnectionSourceIdKey, activeConnectionSourceId);
    }
  }

  ConnectionSource _buildLegacySource(String input) {
    final trimmed = input.trim();
    final suggestedName = SubscriptionParser.suggestSourceName(trimmed);
    final type = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? ConnectionSourceType.subscription
        : ConnectionSourceType.configLink;
    return ConnectionSource(
      id: 'source_${DateTime.now().microsecondsSinceEpoch}_${trimmed.hashCode.abs()}',
      type: type,
      name: suggestedName,
      input: trimmed,
    );
  }
}

class SettingsState {
  static const Object _sentinel = Object();

  final bool devMode;
  final bool developerToolsUnlocked;
  final String language;
  final String theme;
  final List<ConnectionSource> connectionSources;
  final String? activeConnectionSourceId;
  final RoutingSettings routingSettings;
  final PingSettings pingSettings;
  final TunnelSettings tunnelSettings;
  final XraySettings xraySettings;

  SettingsState({
    required this.devMode,
    required this.developerToolsUnlocked,
    required this.language,
    required this.theme,
    required this.connectionSources,
    required this.activeConnectionSourceId,
    required this.routingSettings,
    required this.pingSettings,
    required this.tunnelSettings,
    required this.xraySettings,
  });

  ConnectionSource? get activeConnectionSource {
    final activeId = activeConnectionSourceId;
    if (activeId == null) {
      return connectionSources.isEmpty ? null : connectionSources.first;
    }

    for (final source in connectionSources) {
      if (source.id == activeId) {
        return source;
      }
    }
    return connectionSources.isEmpty ? null : connectionSources.first;
  }

  List<ConnectionSource> get enabledConnectionSources {
    return connectionSources
        .where((source) => source.enabled)
        .toList(growable: false);
  }

  String get subscriptionLink {
    final activeSource = activeConnectionSource;
    if (activeSource == null ||
        activeSource.type == ConnectionSourceType.manual) {
      return '';
    }
    return activeSource.input;
  }

  SettingsState copyWith({
    bool? devMode,
    bool? developerToolsUnlocked,
    String? language,
    String? theme,
    List<ConnectionSource>? connectionSources,
    Object? activeConnectionSourceId = _sentinel,
    RoutingSettings? routingSettings,
    PingSettings? pingSettings,
    TunnelSettings? tunnelSettings,
    XraySettings? xraySettings,
  }) {
    return SettingsState(
      devMode: devMode ?? this.devMode,
      developerToolsUnlocked:
          developerToolsUnlocked ?? this.developerToolsUnlocked,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      connectionSources: connectionSources ?? this.connectionSources,
      activeConnectionSourceId: identical(
        activeConnectionSourceId,
        _sentinel,
      )
          ? this.activeConnectionSourceId
          : activeConnectionSourceId as String?,
      routingSettings: routingSettings ?? this.routingSettings,
      pingSettings: pingSettings ?? this.pingSettings,
      tunnelSettings: tunnelSettings ?? this.tunnelSettings,
      xraySettings: xraySettings ?? this.xraySettings,
    );
  }
}
