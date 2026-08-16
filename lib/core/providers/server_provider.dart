import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/connection_source.dart';
import '../models/ping_settings.dart';
import '../models/server_group.dart';
import '../models/vpn_node.dart';
import '../services/app_log_service.dart';
import '../services/connectivity_tester.dart';
import '../services/subscription_parser.dart';
import 'settings_provider.dart';

part 'server_provider.g.dart';

class ConnectionSourceLoadResult {
  final String sourceId;
  final int nodeCount;
  final Object? error;

  const ConnectionSourceLoadResult({
    required this.sourceId,
    required this.nodeCount,
    this.error,
  });

  bool get isSuccess => error == null;
}

@riverpod
class ServerList extends _$ServerList {
  final Map<String, List<VpnNode>> _sourceNodes = {};

  @override
  AsyncValue<List<VpnNode>> build() {
    return const AsyncValue.data([]);
  }

  Future<List<VpnNode>> loadFromSubscription(String link) async {
    final trimmed = link.trim();
    final inferredType =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? ConnectionSourceType.subscription
            : ConnectionSourceType.configLink;
    return loadFromConnectionSource(
      ConnectionSource(
        id: 'inline_${DateTime.now().microsecondsSinceEpoch}',
        type: inferredType,
        name: SubscriptionParser.suggestSourceName(trimmed),
        input: trimmed,
      ),
    );
  }

  Future<List<VpnNode>> loadFromConnectionSource(ConnectionSource source) async {
    final results = await loadEnabledSources([source], setLoading: true);
    final result = results.firstWhere(
      (entry) => entry.sourceId == source.id,
      orElse: () => ConnectionSourceLoadResult(
        sourceId: source.id,
        nodeCount: 0,
        error: Exception('Failed to load "${source.resolvedName}".'),
      ),
    );

    if (!result.isSuccess) {
      throw result.error!;
    }

    return _sourceNodes[source.id] ?? const <VpnNode>[];
  }

  Future<List<ConnectionSourceLoadResult>> loadEnabledSources(
    List<ConnectionSource> sources, {
    bool setLoading = false,
  }) async {
    final enabledSources = sources
        .where((source) => source.enabled)
        .toList(growable: false);

    if (enabledSources.isEmpty) {
      _sourceNodes.clear();
      state = const AsyncValue.data([]);
      return const <ConnectionSourceLoadResult>[];
    }

    if (setLoading) {
      state = const AsyncValue.loading();
    }

    final nextSourceNodes = <String, List<VpnNode>>{};
    final results = <ConnectionSourceLoadResult>[];

    for (final source in enabledSources) {
      try {
        final nodes = await _loadNodesForSource(source);
        nextSourceNodes[source.id] = nodes;
        ref.read(settingsProvider.notifier).markConnectionSourceRefresh(
              source.id,
              updatedAt: DateTime.now(),
              lastRefreshError: null,
            );
        AppLogService.instance.info(
          source: 'subscription',
          message:
              'Loaded ${nodes.length} connections from "${source.resolvedName}".',
        );
        results.add(
          ConnectionSourceLoadResult(
            sourceId: source.id,
            nodeCount: nodes.length,
          ),
        );
      } catch (error) {
        ref.read(settingsProvider.notifier).markConnectionSourceRefresh(
              source.id,
              lastRefreshError: error.toString(),
            );
        AppLogService.instance.error(
          source: 'subscription',
          message: 'Connection source "${source.resolvedName}" failed: $error',
        );
        results.add(
          ConnectionSourceLoadResult(
            sourceId: source.id,
            nodeCount: 0,
            error: error,
          ),
        );
      }
    }

    _sourceNodes
      ..clear()
      ..addAll(nextSourceNodes);

    final combined = _flattenSourceNodes();
    state = AsyncValue.data(combined);

    if (combined.isEmpty) {
      final failed = results.where((entry) => entry.error != null).toList();
      if (failed.isNotEmpty) {
        state = AsyncValue.error(failed.first.error!, StackTrace.current);
      }
    }

    return results;
  }

  Future<List<ConnectionSourceLoadResult>> refreshEnabledSources({
    bool subscriptionsOnly = false,
  }) async {
    final enabled = ref.read(settingsProvider).enabledConnectionSources.where((
      source,
    ) {
      if (!subscriptionsOnly) {
        return true;
      }
      return source.type == ConnectionSourceType.subscription;
    }).toList(growable: false);

    return loadEnabledSources(enabled, setLoading: false);
  }

  void addNode(VpnNode node) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, node]);
  }

  void replaceAll(List<VpnNode> nodes) {
    state = AsyncValue.data(nodes);
  }

  void clear() {
    _sourceNodes.clear();
    state = const AsyncValue.data([]);
  }

  Future<List<VpnNode>> refreshMetrics(PingSettings settings) async {
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) {
      return current;
    }

    final measured = await ConnectivityTester.measureNodes(current, settings);
    _applyMeasuredNodes(measured);
    state = AsyncValue.data(measured);
    return measured;
  }

  void removeNode(String nodeId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((n) => n.id != nodeId).toList());
  }

  Future<List<VpnNode>> _loadNodesForSource(ConnectionSource source) async {
    late final List<VpnNode> nodes;

    if (source.type == ConnectionSourceType.manual &&
        source.manualConfig != null) {
      nodes = [source.manualConfig!.toVpnNode('manual_${source.id}')];
    } else {
      nodes = await SubscriptionParser.parseSubscription(source.input).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException(
          'Timed out while loading "${source.resolvedName}".',
        ),
      );
    }

    if (nodes.isEmpty) {
      throw Exception('No connections found in "${source.resolvedName}".');
    }

    return nodes.map((node) => _stampNode(node, source)).toList(growable: false);
  }

  VpnNode _stampNode(VpnNode node, ConnectionSource source) {
    return node.copyWith(
      id: '${source.id}::${node.id}',
      rawConfig: {
        ...?node.rawConfig,
        '__sourceId': source.id,
        '__sourceName': source.resolvedName,
        '__sourceType': connectionSourceTypeKey(source.type),
      },
    );
  }

  List<VpnNode> _flattenSourceNodes() {
    return _sourceNodes.values.expand((nodes) => nodes).toList(growable: false);
  }

  void _applyMeasuredNodes(List<VpnNode> measured) {
    final rebuilt = <String, List<VpnNode>>{};
    for (final node in measured) {
      final sourceId = node.rawConfig?['__sourceId']?.toString();
      if (sourceId == null || sourceId.isEmpty) {
        continue;
      }
      rebuilt.putIfAbsent(sourceId, () => <VpnNode>[]).add(node);
    }

    if (rebuilt.isEmpty) {
      return;
    }

    _sourceNodes
      ..clear()
      ..addAll(rebuilt);
  }
}

@riverpod
class ServerGroups extends _$ServerGroups {
  @override
  List<ServerGroup> build() {
    final nodes = ref.watch(serverListProvider).valueOrNull ?? [];
    return SubscriptionParser.groupByCountry(nodes);
  }
}

@riverpod
class SelectedServer extends _$SelectedServer {
  @override
  ServerGroup? build() {
    return null;
  }

  void selectGroup(ServerGroup group) {
    state = group;
  }

  void clearSelection() {
    state = null;
  }

  void selectNode(VpnNode node) {
    final current = state;
    if (current != null) {
      state = current.copyWith(selectedNode: node);
    }
  }

  Future<ServerGroup?> resolveBestNodeForGroup(ServerGroup group) async {
    final latestGroup = _findGroupByCountry(group.countryCode) ?? group;
    if (latestGroup.nodes.isEmpty) {
      return null;
    }

    final bestNode =
            ConnectivityTester.findBestNode(latestGroup.nodes) ??
                latestGroup.nodes.first;
    final resolvedGroup = latestGroup.copyWith(
      selectedNode: bestNode,
      averagePing: bestNode.ping > 0 ? bestNode.ping : latestGroup.averagePing,
      averageHttpResponseTime: bestNode.httpResponseTime > 0
          ? bestNode.httpResponseTime
          : latestGroup.averageHttpResponseTime,
    );
    state = resolvedGroup;
    return resolvedGroup;
  }

  Future<void> autoSelect() async {
    final groups = ref.read(serverGroupsProvider);
    final currentNodes = ref.read(serverListProvider).valueOrNull ?? [];
    if (groups.isEmpty || currentNodes.isEmpty) {
      return;
    }

    final bestNode =
        ConnectivityTester.findBestNode(currentNodes) ?? currentNodes.first;
    final bestGroup = groups.firstWhere(
      (group) => group.nodes.any((node) => node.id == bestNode.id),
      orElse: () => groups.first,
    );

    state = bestGroup.copyWith(
      selectedNode: bestNode,
      averagePing: bestNode.ping > 0 ? bestNode.ping : bestGroup.averagePing,
      averageHttpResponseTime: bestNode.httpResponseTime > 0
          ? bestNode.httpResponseTime
          : bestGroup.averageHttpResponseTime,
    );
  }

  Future<VpnNode?> resolveFailoverNode(VpnNode currentNode) async {
    final alternatives = resolveFailoverCandidates(currentNode);
    if (alternatives.isEmpty) {
      return null;
    }

    final fallback =
        ConnectivityTester.findBestNode(alternatives) ?? alternatives.first;
    final groups = ref.read(serverGroupsProvider);
    for (final group in groups) {
      if (!group.nodes.any((node) => node.id == currentNode.id)) {
        continue;
      }

      state = group.copyWith(
        selectedNode: fallback,
        averagePing: fallback.ping > 0 ? fallback.ping : group.averagePing,
        averageHttpResponseTime: fallback.httpResponseTime > 0
            ? fallback.httpResponseTime
            : group.averageHttpResponseTime,
      );
      return fallback;
    }

    return fallback;
  }

  List<VpnNode> resolveFailoverCandidates(VpnNode currentNode) {
    final groups = ref.read(serverGroupsProvider);
    for (final group in groups) {
      final containsNode = group.nodes.any((node) => node.id == currentNode.id);
      if (!containsNode) {
        continue;
      }

      final alternatives = group.nodes
          .where((node) => node.id != currentNode.id)
          .toList(growable: true);
      if (alternatives.isEmpty) {
        return const <VpnNode>[];
      }

      alternatives.sort((left, right) {
        final leftScore = _scoreNode(left);
        final rightScore = _scoreNode(right);
        return leftScore.compareTo(rightScore);
      });
      return alternatives;
    }

    return const <VpnNode>[];
  }

  int _scoreNode(VpnNode node) {
    final ping = node.ping > 0 ? node.ping : 9999;
    final http = node.httpResponseTime > 0 ? node.httpResponseTime : 9999;
    final availabilityPenalty = node.isAvailable ? 0 : 5000;
    return ping + http + availabilityPenalty;
  }

  ServerGroup? _findGroupByCountry(String countryCode) {
    final groups = ref.read(serverGroupsProvider);
    for (final group in groups) {
      if (group.countryCode == countryCode) {
        return group;
      }
    }
    return null;
  }
}
