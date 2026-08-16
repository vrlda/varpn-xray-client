// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$serverListHash() => r'f1404a8cdec80b3243301676c871e42166234474';

/// See also [ServerList].
@ProviderFor(ServerList)
final serverListProvider =
    AutoDisposeNotifierProvider<ServerList, AsyncValue<List<VpnNode>>>.internal(
  ServerList.new,
  name: r'serverListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$serverListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ServerList = AutoDisposeNotifier<AsyncValue<List<VpnNode>>>;
String _$serverGroupsHash() => r'247ef431f315a81e19b2de5915d9d427e1e09854';

/// See also [ServerGroups].
@ProviderFor(ServerGroups)
final serverGroupsProvider =
    AutoDisposeNotifierProvider<ServerGroups, List<ServerGroup>>.internal(
  ServerGroups.new,
  name: r'serverGroupsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$serverGroupsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ServerGroups = AutoDisposeNotifier<List<ServerGroup>>;
String _$selectedServerHash() => r'272734918f8a4c1aae190a6e10a1175ade36ac04';

/// See also [SelectedServer].
@ProviderFor(SelectedServer)
final selectedServerProvider =
    AutoDisposeNotifierProvider<SelectedServer, ServerGroup?>.internal(
  SelectedServer.new,
  name: r'selectedServerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedServerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedServer = AutoDisposeNotifier<ServerGroup?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
