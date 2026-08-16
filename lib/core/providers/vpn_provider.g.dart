// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vpn_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$vpnServiceHash() => r'cc0251c6bf24a44d70e350328e2d24606b7bbfdd';

/// See also [vpnService].
@ProviderFor(vpnService)
final vpnServiceProvider = AutoDisposeProvider<IVpnService>.internal(
  vpnService,
  name: r'vpnServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$vpnServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef VpnServiceRef = AutoDisposeProviderRef<IVpnService>;
String _$vpnConnectionHash() => r'2de1fd1e204b371f44af0679a681cf4748e0c251';

/// See also [VpnConnection].
@ProviderFor(VpnConnection)
final vpnConnectionProvider =
    AutoDisposeNotifierProvider<VpnConnection, ConnectionStatus>.internal(
  VpnConnection.new,
  name: r'vpnConnectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$vpnConnectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VpnConnection = AutoDisposeNotifier<ConnectionStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
