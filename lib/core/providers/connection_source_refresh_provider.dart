import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_source.dart';
import '../models/server_group.dart';
import '../services/app_log_service.dart';
import 'server_provider.dart';
import 'settings_provider.dart';

final connectionSourceRefreshProvider =
    Provider<ConnectionSourceRefreshController>((ref) {
  final controller = ConnectionSourceRefreshController(ref);

  ref.listen<List<ConnectionSource>>(
    settingsProvider.select((settings) => settings.connectionSources),
    controller.handleSourcesChanged,
  );

  Future.microtask(controller.bootstrap);
  ref.onDispose(controller.dispose);
  return controller;
});

class ConnectionSourceRefreshController {
  ConnectionSourceRefreshController(this._ref);

  static const Duration _refreshInterval = Duration(hours: 6);

  final Ref _ref;
  Timer? _timer;
  Future<void>? _inFlight;

  Future<void> bootstrap() async {
    _restartTimer();
    await syncSources(reason: 'startup');
  }

  void handleSourcesChanged(
    List<ConnectionSource>? previous,
    List<ConnectionSource> next,
  ) {
    _restartTimer();
    if (_sameSources(previous ?? const <ConnectionSource>[], next)) {
      return;
    }

    unawaited(syncSources(reason: 'sources-updated'));
  }

  Future<void> syncSources({
    required String reason,
  }) async {
    final current = _inFlight;
    if (current != null) {
      return current;
    }

    final future = _runSync(reason: reason);
    _inFlight = future;
    try {
      await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> refreshRemoteSources() async {
    final remoteSources = _ref
        .read(settingsProvider)
        .enabledConnectionSources
        .where((source) => source.type == ConnectionSourceType.subscription)
        .toList(growable: false);
    if (remoteSources.isEmpty) {
      await syncSources(reason: 'manual-refresh-no-subscriptions');
      return;
    }

    await syncSources(reason: 'manual-refresh');
  }

  void dispose() {
    _timer?.cancel();
  }

  Future<void> _runSync({
    required String reason,
  }) async {
    final sources = _ref.read(settingsProvider).connectionSources;
    await _ref.read(serverListProvider.notifier).loadEnabledSources(
          sources,
          setLoading: reason == 'startup',
        );
    _reconcileSelection();
    final enabledCount =
        _ref.read(settingsProvider).enabledConnectionSources.length;
    if (enabledCount == 0) {
      AppLogService.instance.info(
        source: 'subscription',
        message: 'No enabled connection sources to refresh ($reason).',
      );
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      _refreshInterval,
      (_) => unawaited(syncSources(reason: 'scheduled-refresh')),
    );
  }

  void _reconcileSelection() {
    final selected = _ref.read(selectedServerProvider);
    if (selected == null) {
      return;
    }

    ServerGroup? matchingGroup;
    for (final group in _ref.read(serverGroupsProvider)) {
      if (group.countryCode == selected.countryCode) {
        matchingGroup = group;
        break;
      }
    }

    if (matchingGroup == null) {
      _ref.read(selectedServerProvider.notifier).clearSelection();
      return;
    }

    final selectedNode = selected.selectedNode;
    if (selectedNode == null) {
      _ref.read(selectedServerProvider.notifier).selectGroup(matchingGroup);
      return;
    }

    final hasSelectedNode =
        matchingGroup.nodes.any((node) => node.id == selectedNode.id);
    _ref.read(selectedServerProvider.notifier).selectGroup(
          hasSelectedNode
              ? matchingGroup.copyWith(selectedNode: selectedNode)
              : matchingGroup.copyWith(selectedNode: null),
        );
  }
}

bool _sameSources(
    List<ConnectionSource> previous, List<ConnectionSource> next) {
  if (previous.length != next.length) {
    return false;
  }

  for (var i = 0; i < previous.length; i++) {
    final left = previous[i];
    final right = next[i];
    if (left.id != right.id ||
        left.name != right.name ||
        left.input != right.input ||
        left.enabled != right.enabled ||
        left.type != right.type ||
        left.manualConfig?.toJson().toString() !=
            right.manualConfig?.toJson().toString()) {
      return false;
    }
  }

  return true;
}
