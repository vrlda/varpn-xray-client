import 'package:freezed_annotation/freezed_annotation.dart';

part 'vpn_node.freezed.dart';
part 'vpn_node.g.dart';

@freezed
class VpnNode with _$VpnNode {
  const factory VpnNode({
    required String id,
    required String name,
    required String server,
    required int port,
    required String protocol, // vless, vmess, trojan, ss
    String? userId,
    String? flow,
    String? encryption,
    String? network, // ws, grpc, tcp, http
    String? security, // none, tls, reality
    String? sni,
    String? realityPubKey,
    String? realityShortId,
    String? path,
    String? host,
    Map<String, dynamic>? rawConfig,
    @Default(0) int ping,
    @Default(0) int httpResponseTime,
    @Default(false) bool isAvailable,
  }) = _VpnNode;

  factory VpnNode.fromJson(Map<String, dynamic> json) =>
      _$VpnNodeFromJson(json);
}
