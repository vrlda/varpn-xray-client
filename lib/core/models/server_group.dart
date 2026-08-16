import 'package:freezed_annotation/freezed_annotation.dart';
import 'vpn_node.dart';

part 'server_group.freezed.dart';
part 'server_group.g.dart';

@freezed
class ServerGroup with _$ServerGroup {
  const factory ServerGroup({
    required String countryCode,
    required String countryName,
    required List<VpnNode> nodes,
    VpnNode? selectedNode,
    @Default(0) int averagePing,
    @Default(0) int averageHttpResponseTime,
  }) = _ServerGroup;

  factory ServerGroup.fromJson(Map<String, dynamic> json) =>
      _$ServerGroupFromJson(json);
}
