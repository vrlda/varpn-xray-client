// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vpn_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VpnNodeImpl _$$VpnNodeImplFromJson(Map<String, dynamic> json) =>
    _$VpnNodeImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      server: json['server'] as String,
      port: (json['port'] as num).toInt(),
      protocol: json['protocol'] as String,
      userId: json['userId'] as String?,
      flow: json['flow'] as String?,
      encryption: json['encryption'] as String?,
      network: json['network'] as String?,
      security: json['security'] as String?,
      sni: json['sni'] as String?,
      realityPubKey: json['realityPubKey'] as String?,
      realityShortId: json['realityShortId'] as String?,
      path: json['path'] as String?,
      host: json['host'] as String?,
      rawConfig: json['rawConfig'] as Map<String, dynamic>?,
      ping: (json['ping'] as num?)?.toInt() ?? 0,
      httpResponseTime: (json['httpResponseTime'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? false,
    );

Map<String, dynamic> _$$VpnNodeImplToJson(_$VpnNodeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'server': instance.server,
      'port': instance.port,
      'protocol': instance.protocol,
      'userId': instance.userId,
      'flow': instance.flow,
      'encryption': instance.encryption,
      'network': instance.network,
      'security': instance.security,
      'sni': instance.sni,
      'realityPubKey': instance.realityPubKey,
      'realityShortId': instance.realityShortId,
      'path': instance.path,
      'host': instance.host,
      'rawConfig': instance.rawConfig,
      'ping': instance.ping,
      'httpResponseTime': instance.httpResponseTime,
      'isAvailable': instance.isAvailable,
    };
