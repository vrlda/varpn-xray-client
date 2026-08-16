import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ping_settings.dart';
import '../models/vpn_node.dart';
import '../services/app_log_service.dart';
import 'server_provider.dart';
import 'settings_provider.dart';

final pingMonitorProvider = Provider<PingMonitorController>((ref) {
  final controller = PingMonitorController(ref);

  ref.listen<AsyncValue<List<VpnNode>>>(serverListProvider, (previous, next) {
    controller.handleServerListChange(previous, next);
  });

  ref.listen<PingSettings>(
    settingsProvider.select((settings) => settings.pingSettings),
    controller.handleSettingsChange,
  );

  Future.microtask(() {
    unawaited(controller.bootstrap());
  });

  ref.onDispose(controller.dispose);
  return controller;
});

class PingMonitorController {
  PingMonitorController(this._ref);

  static const Duration _sweepInterval = Duration(hours: 1);

  final Ref _ref;

  Timer? _timer;
  Future<List<VpnNode>>? _inFlightSweep;
  DateTime? _lastSweepAt;

  Future<void> bootstrap() async {
    if (_nodes.isEmpty) {
      return;
    }

    _restartTimer();
    await ensureFreshMetrics(
      reason: 'startup',
      force: true,
    );
  }

  void handleServerListChange(
    AsyncValue<List<VpnNode>>? previous,
    AsyncValue<List<VpnNode>> next,
  ) {
    final previousNodes = previous?.valueOrNull ?? const <VpnNode>[];
    final nextNodes = next.valueOrNull ?? const <VpnNode>[];
    final hadNodes = previousNodes.isNotEmpty;
    final hasNodes = nextNodes.isNotEmpty;

    if (!hasNodes) {
      _lastSweepAt = null;
      _timer?.cancel();
      return;
    }

    _restartTimer();

    final changedNodes = !_sameNodeIds(previousNodes, nextNodes);
    final hasUnmeasuredNodes = nextNodes.any((node) => !_hasMetrics(node));
    if (!hadNodes || changedNodes || hasUnmeasuredNodes) {
      unawaited(
        ensureFreshMetrics(
          reason: hadNodes ? 'nodes-updated' : 'startup',
          force: true,
        ),
      );
    }
  }

  void handleSettingsChange(PingSettings? previous, PingSettings next) {
    _restartTimer();

    if (previous == null) {
      return;
    }

    if (previous.protocol != next.protocol || previous.url != next.url) {
      _lastSweepAt = null;
    }
  }

  Future<List<VpnNode>> ensureFreshMetrics({
    required String reason,
    bool force = false,
  }) async {
    final nodes = _nodes;
    if (nodes.isEmpty) {
      return const <VpnNode>[];
    }

    final hasMeasuredNodes = nodes.any(_hasMetrics);
    final isStale = _lastSweepAt == null ||
        DateTime.now().difference(_lastSweepAt!) >= _sweepInterval;
    if (!force && hasMeasuredNodes && !isStale) {
      return nodes;
    }

    return runSweep(reason: reason);
  }

  Future<List<VpnNode>> runSweep({
    required String reason,
  }) async {
    final currentSweep = _inFlightSweep;
    if (currentSweep != null) {
      return currentSweep;
    }

    final nodes = _nodes;
    if (nodes.isEmpty) {
      return const <VpnNode>[];
    }

    final settings = _ref.read(settingsProvider).pingSettings;
    final future = _runSweep(
      settings,
      reason: reason,
    );
    _inFlightSweep = future;

    try {
      return await future;
    } finally {
      _inFlightSweep = null;
    }
  }

  void dispose() {
    _timer?.cancel();
  }

  List<VpnNode> get _nodes =>
      _ref.read(serverListProvider).valueOrNull ?? const <VpnNode>[];

  Future<List<VpnNode>> _runSweep(
    PingSettings settings, {
    required String reason,
  }) async {
    try {
      final measured =
          await _ref.read(serverListProvider.notifier).refreshMetrics(settings);
      _lastSweepAt = DateTime.now();
      final reachable = measured.where(_isReachable).length;
      AppLogService.instance.info(
        source: 'ping',
        message:
            'Ping sweep via ${_protocolLabel(settings.protocol)} completed for ${measured.length} nodes, reachable: $reachable ($reason).',
      );
      return measured;
    } catch (error) {
      AppLogService.instance.warning(
        source: 'ping',
        message: 'Ping sweep failed during $reason: $error',
      );
      rethrow;
    }
  }

  void _restartTimer() {
    _timer?.cancel();

    if (_nodes.isEmpty) {
      return;
    }

    _timer = Timer.periodic(
      _sweepInterval,
      (_) => unawaited(runSweep(reason: 'hourly')),
    );
  }
}

bool _isReachable(VpnNode node) {
  final ping = node.ping > 0 && node.ping < 9999;
  final http = node.httpResponseTime > 0 && node.httpResponseTime < 9999;
  return ping || http;
}

bool _hasMetrics(VpnNode node) {
  return node.ping > 0 || node.httpResponseTime > 0;
}

bool _sameNodeIds(List<VpnNode> previous, List<VpnNode> next) {
  if (identical(previous, next)) {
    return true;
  }

  if (previous.length != next.length) {
    return false;
  }

  final previousIds = previous.map((node) => node.id).toSet();
  final nextIds = next.map((node) => node.id).toSet();
  return previousIds.length == nextIds.length &&
      previousIds.containsAll(nextIds);
}

String _protocolLabel(String protocol) {
  return switch (protocol) {
    'proxy_get' => 'Proxy GET',
    'proxy_head' => 'Proxy HEAD',
    'icmp' => 'ICMP',
    _ => 'TCP',
  };
}
