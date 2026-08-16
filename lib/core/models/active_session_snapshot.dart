import 'tunnel_settings.dart';
import 'vpn_node.dart';

class ActiveSessionSnapshot {
  final bool isActive;
  final String connectionMode;
  final String? selectedCountryCode;
  final String? lastWorkingNodeId;
  final TunnelSettings tunnelSettings;
  final List<ActiveSessionCandidate> candidates;

  const ActiveSessionSnapshot({
    required this.isActive,
    required this.connectionMode,
    required this.selectedCountryCode,
    required this.lastWorkingNodeId,
    required this.tunnelSettings,
    required this.candidates,
  });

  factory ActiveSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final rawCandidates = (json['candidates'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (entry) => entry.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList(growable: false);

    return ActiveSessionSnapshot(
      isActive: _readBool(json['isActive']) ?? false,
      connectionMode: _readString(json['connectionMode']) ?? 'node',
      selectedCountryCode: _readString(json['selectedCountryCode']),
      lastWorkingNodeId: _readString(json['lastWorkingNodeId']),
      tunnelSettings: TunnelSettings.fromJson(
        (json['tunnelSettings'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value),
            ) ??
            const <String, dynamic>{},
      ),
      candidates: rawCandidates
          .map(ActiveSessionCandidate.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'connectionMode': connectionMode,
      'selectedCountryCode': selectedCountryCode,
      'lastWorkingNodeId': lastWorkingNodeId,
      'tunnelSettings': tunnelSettings.toJson(),
      'candidates': candidates.map((entry) => entry.toJson()).toList(),
    };
  }

  ActiveSessionSnapshot copyWith({
    bool? isActive,
    String? connectionMode,
    String? selectedCountryCode,
    String? lastWorkingNodeId,
    TunnelSettings? tunnelSettings,
    List<ActiveSessionCandidate>? candidates,
  }) {
    return ActiveSessionSnapshot(
      isActive: isActive ?? this.isActive,
      connectionMode: connectionMode ?? this.connectionMode,
      selectedCountryCode: selectedCountryCode ?? this.selectedCountryCode,
      lastWorkingNodeId: lastWorkingNodeId ?? this.lastWorkingNodeId,
      tunnelSettings: tunnelSettings ?? this.tunnelSettings,
      candidates: candidates ?? this.candidates,
    );
  }

  static String? _readString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
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

class ActiveSessionCandidate {
  final VpnNode node;
  final String? countryCode;
  final String configPath;
  final String? activeTransport;

  const ActiveSessionCandidate({
    required this.node,
    required this.countryCode,
    required this.configPath,
    required this.activeTransport,
  });

  factory ActiveSessionCandidate.fromJson(Map<String, dynamic> json) {
    final rawNode = (json['node'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ) ??
        const <String, dynamic>{};
    return ActiveSessionCandidate(
      node: VpnNode.fromJson(rawNode),
      countryCode: _readString(json['countryCode']),
      configPath: _readString(json['configPath']) ?? '',
      activeTransport: _readString(json['activeTransport']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node': node.toJson(),
      'countryCode': countryCode,
      'configPath': configPath,
      'activeTransport': activeTransport,
    };
  }

  static String? _readString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty || normalized == 'null') {
      return null;
    }
    return normalized;
  }
}
