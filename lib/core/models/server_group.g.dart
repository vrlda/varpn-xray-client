// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ServerGroupImpl _$$ServerGroupImplFromJson(Map<String, dynamic> json) =>
    _$ServerGroupImpl(
      countryCode: json['countryCode'] as String,
      countryName: json['countryName'] as String,
      nodes: (json['nodes'] as List<dynamic>)
          .map((e) => VpnNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedNode: json['selectedNode'] == null
          ? null
          : VpnNode.fromJson(json['selectedNode'] as Map<String, dynamic>),
      averagePing: (json['averagePing'] as num?)?.toInt() ?? 0,
      averageHttpResponseTime:
          (json['averageHttpResponseTime'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ServerGroupImplToJson(_$ServerGroupImpl instance) =>
    <String, dynamic>{
      'countryCode': instance.countryCode,
      'countryName': instance.countryName,
      'nodes': instance.nodes,
      'selectedNode': instance.selectedNode,
      'averagePing': instance.averagePing,
      'averageHttpResponseTime': instance.averageHttpResponseTime,
    };
