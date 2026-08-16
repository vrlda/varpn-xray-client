import 'dart:async';
import '../models/tunnel_health.dart';
import '../models/vpn_node.dart';

/// Interface for VPN service (assumes GoMobile binding exists)
abstract class IVpnService {
  /// Connect to a VPN node
  Future<void> connect(VpnNode node);

  /// Disconnect from VPN
  Future<void> disconnect();

  /// Get current connection status
  Stream<ConnectionStatus> get statusStream;

  /// Get current connected node
  VpnNode? get currentNode;

  /// Check if currently connected
  bool get isConnected;

  /// Read native tunnel health when available.
  Future<TunnelHealth?> readTunnelHealth();

  /// Dispose any background listeners/timers.
  void dispose();
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Mock implementation for development
class MockVpnService implements IVpnService {
  VpnNode? _currentNode;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  @override
  Future<void> connect(VpnNode node) async {
    _status = ConnectionStatus.connecting;
    _statusController.add(_status);

    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 2));

    _currentNode = node;
    _status = ConnectionStatus.connected;
    _statusController.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _status = ConnectionStatus.disconnecting;
    _statusController.add(_status);

    // Simulate disconnection delay
    await Future.delayed(const Duration(seconds: 1));

    _currentNode = null;
    _status = ConnectionStatus.disconnected;
    _statusController.add(_status);
  }

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  VpnNode? get currentNode => _currentNode;

  @override
  bool get isConnected => _status == ConnectionStatus.connected;

  @override
  Future<TunnelHealth?> readTunnelHealth() async => null;

  @override
  void dispose() {
    _statusController.close();
  }
}
