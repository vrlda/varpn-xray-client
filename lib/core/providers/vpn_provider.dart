import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'server_provider.dart';
import 'settings_provider.dart';
import 'usage_stats_provider.dart';
import '../services/ios_vpn_service.dart';
import '../services/macos_utun_vpn_service.dart';
import '../services/vpn_service.dart';
import '../models/vpn_node.dart';

part 'vpn_provider.g.dart';

@riverpod
IVpnService vpnService(VpnServiceRef ref) {
  if (Platform.isMacOS) {
    final service = MacosUtunVpnService(
      readRoutingSettings: () => ref.read(settingsProvider).routingSettings,
      readTunnelSettings: () => ref.read(settingsProvider).tunnelSettings,
      readXraySettings: () => ref.read(settingsProvider).xraySettings,
      resolveFailoverCandidates: (currentNode) async {
        final settings = ref.read(settingsProvider);
        if (settings.devMode) {
          return const <VpnNode>[];
        }

        return ref
            .read(selectedServerProvider.notifier)
            .resolveFailoverCandidates(currentNode);
      },
    );
    ref.onDispose(service.dispose);
    return service;
  }
  if (Platform.isIOS) {
    final service = IosVpnService(
      readRoutingSettings: () => ref.read(settingsProvider).routingSettings,
      readTunnelSettings: () => ref.read(settingsProvider).tunnelSettings,
      readXraySettings: () => ref.read(settingsProvider).xraySettings,
      resolveFailoverNode: (currentNode) async {
        final settings = ref.read(settingsProvider);
        if (settings.devMode) {
          return null;
        }

        return ref
            .read(selectedServerProvider.notifier)
            .resolveFailoverNode(currentNode);
      },
    );
    ref.onDispose(service.dispose);
    return service;
  }
  final service = MockVpnService();
  ref.onDispose(service.dispose);
  return service;
}

@riverpod
class VpnConnection extends _$VpnConnection {
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  DateTime? _connectedAt;
  VpnNode? _pendingNode;

  @override
  ConnectionStatus build() {
    final service = ref.watch(vpnServiceProvider);

    // Listen to status changes
    _statusSubscription?.cancel();
    _statusSubscription = service.statusStream.listen((status) {
      final previous = state;
      state = status;
      _handleStatusTransition(
        previous: previous,
        next: status,
        service: service,
      );
    });

    ref.onDispose(() {
      _statusSubscription?.cancel();
    });

    return service.isConnected
        ? ConnectionStatus.connected
        : ConnectionStatus.disconnected;
  }

  Future<void> connect(VpnNode node) async {
    final service = ref.read(vpnServiceProvider);
    _pendingNode = node;
    ref.read(usageStatsProvider.notifier).recordConnectionAttempt(node.name);
    await service.connect(node);
  }

  Future<void> disconnect() async {
    final service = ref.read(vpnServiceProvider);
    await service.disconnect();
  }

  VpnNode? get currentNode {
    final service = ref.read(vpnServiceProvider);
    return service.currentNode;
  }

  void _handleStatusTransition({
    required ConnectionStatus previous,
    required ConnectionStatus next,
    required IVpnService service,
  }) {
    if (next == ConnectionStatus.connected &&
        previous != ConnectionStatus.connected) {
      final node = service.currentNode ?? _pendingNode;
      if (node != null) {
        final connectedAt = DateTime.now();
        _connectedAt = connectedAt;
        _pendingNode = null;
        ref
            .read(usageStatsProvider.notifier)
            .recordConnectionSuccess(node.name, connectedAt);
        unawaited(ref.read(usageStatsProvider.notifier).syncTrafficStats());
      }
      return;
    }

    if (next == ConnectionStatus.error &&
        previous == ConnectionStatus.connecting &&
        _pendingNode != null) {
      ref
          .read(usageStatsProvider.notifier)
          .recordConnectionFailure(_pendingNode!.name);
      _pendingNode = null;
      return;
    }

    if (next == ConnectionStatus.disconnected) {
      if (_connectedAt != null) {
        ref.read(usageStatsProvider.notifier).recordDisconnect(DateTime.now());
        unawaited(ref.read(usageStatsProvider.notifier).syncTrafficStats());
        _connectedAt = null;
      } else if (previous == ConnectionStatus.connecting &&
          _pendingNode != null) {
        ref
            .read(usageStatsProvider.notifier)
            .recordConnectionFailure(_pendingNode!.name);
      }
      _pendingNode = null;
    }
  }
}
