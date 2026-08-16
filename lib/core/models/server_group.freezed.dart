// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ServerGroup _$ServerGroupFromJson(Map<String, dynamic> json) {
  return _ServerGroup.fromJson(json);
}

/// @nodoc
mixin _$ServerGroup {
  String get countryCode => throw _privateConstructorUsedError;
  String get countryName => throw _privateConstructorUsedError;
  List<VpnNode> get nodes => throw _privateConstructorUsedError;
  VpnNode? get selectedNode => throw _privateConstructorUsedError;
  int get averagePing => throw _privateConstructorUsedError;
  int get averageHttpResponseTime => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ServerGroupCopyWith<ServerGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServerGroupCopyWith<$Res> {
  factory $ServerGroupCopyWith(
          ServerGroup value, $Res Function(ServerGroup) then) =
      _$ServerGroupCopyWithImpl<$Res, ServerGroup>;
  @useResult
  $Res call(
      {String countryCode,
      String countryName,
      List<VpnNode> nodes,
      VpnNode? selectedNode,
      int averagePing,
      int averageHttpResponseTime});

  $VpnNodeCopyWith<$Res>? get selectedNode;
}

/// @nodoc
class _$ServerGroupCopyWithImpl<$Res, $Val extends ServerGroup>
    implements $ServerGroupCopyWith<$Res> {
  _$ServerGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? countryCode = null,
    Object? countryName = null,
    Object? nodes = null,
    Object? selectedNode = freezed,
    Object? averagePing = null,
    Object? averageHttpResponseTime = null,
  }) {
    return _then(_value.copyWith(
      countryCode: null == countryCode
          ? _value.countryCode
          : countryCode // ignore: cast_nullable_to_non_nullable
              as String,
      countryName: null == countryName
          ? _value.countryName
          : countryName // ignore: cast_nullable_to_non_nullable
              as String,
      nodes: null == nodes
          ? _value.nodes
          : nodes // ignore: cast_nullable_to_non_nullable
              as List<VpnNode>,
      selectedNode: freezed == selectedNode
          ? _value.selectedNode
          : selectedNode // ignore: cast_nullable_to_non_nullable
              as VpnNode?,
      averagePing: null == averagePing
          ? _value.averagePing
          : averagePing // ignore: cast_nullable_to_non_nullable
              as int,
      averageHttpResponseTime: null == averageHttpResponseTime
          ? _value.averageHttpResponseTime
          : averageHttpResponseTime // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $VpnNodeCopyWith<$Res>? get selectedNode {
    if (_value.selectedNode == null) {
      return null;
    }

    return $VpnNodeCopyWith<$Res>(_value.selectedNode!, (value) {
      return _then(_value.copyWith(selectedNode: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ServerGroupImplCopyWith<$Res>
    implements $ServerGroupCopyWith<$Res> {
  factory _$$ServerGroupImplCopyWith(
          _$ServerGroupImpl value, $Res Function(_$ServerGroupImpl) then) =
      __$$ServerGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String countryCode,
      String countryName,
      List<VpnNode> nodes,
      VpnNode? selectedNode,
      int averagePing,
      int averageHttpResponseTime});

  @override
  $VpnNodeCopyWith<$Res>? get selectedNode;
}

/// @nodoc
class __$$ServerGroupImplCopyWithImpl<$Res>
    extends _$ServerGroupCopyWithImpl<$Res, _$ServerGroupImpl>
    implements _$$ServerGroupImplCopyWith<$Res> {
  __$$ServerGroupImplCopyWithImpl(
      _$ServerGroupImpl _value, $Res Function(_$ServerGroupImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? countryCode = null,
    Object? countryName = null,
    Object? nodes = null,
    Object? selectedNode = freezed,
    Object? averagePing = null,
    Object? averageHttpResponseTime = null,
  }) {
    return _then(_$ServerGroupImpl(
      countryCode: null == countryCode
          ? _value.countryCode
          : countryCode // ignore: cast_nullable_to_non_nullable
              as String,
      countryName: null == countryName
          ? _value.countryName
          : countryName // ignore: cast_nullable_to_non_nullable
              as String,
      nodes: null == nodes
          ? _value._nodes
          : nodes // ignore: cast_nullable_to_non_nullable
              as List<VpnNode>,
      selectedNode: freezed == selectedNode
          ? _value.selectedNode
          : selectedNode // ignore: cast_nullable_to_non_nullable
              as VpnNode?,
      averagePing: null == averagePing
          ? _value.averagePing
          : averagePing // ignore: cast_nullable_to_non_nullable
              as int,
      averageHttpResponseTime: null == averageHttpResponseTime
          ? _value.averageHttpResponseTime
          : averageHttpResponseTime // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ServerGroupImpl implements _ServerGroup {
  const _$ServerGroupImpl(
      {required this.countryCode,
      required this.countryName,
      required final List<VpnNode> nodes,
      this.selectedNode,
      this.averagePing = 0,
      this.averageHttpResponseTime = 0})
      : _nodes = nodes;

  factory _$ServerGroupImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServerGroupImplFromJson(json);

  @override
  final String countryCode;
  @override
  final String countryName;
  final List<VpnNode> _nodes;
  @override
  List<VpnNode> get nodes {
    if (_nodes is EqualUnmodifiableListView) return _nodes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_nodes);
  }

  @override
  final VpnNode? selectedNode;
  @override
  @JsonKey()
  final int averagePing;
  @override
  @JsonKey()
  final int averageHttpResponseTime;

  @override
  String toString() {
    return 'ServerGroup(countryCode: $countryCode, countryName: $countryName, nodes: $nodes, selectedNode: $selectedNode, averagePing: $averagePing, averageHttpResponseTime: $averageHttpResponseTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServerGroupImpl &&
            (identical(other.countryCode, countryCode) ||
                other.countryCode == countryCode) &&
            (identical(other.countryName, countryName) ||
                other.countryName == countryName) &&
            const DeepCollectionEquality().equals(other._nodes, _nodes) &&
            (identical(other.selectedNode, selectedNode) ||
                other.selectedNode == selectedNode) &&
            (identical(other.averagePing, averagePing) ||
                other.averagePing == averagePing) &&
            (identical(
                    other.averageHttpResponseTime, averageHttpResponseTime) ||
                other.averageHttpResponseTime == averageHttpResponseTime));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      countryCode,
      countryName,
      const DeepCollectionEquality().hash(_nodes),
      selectedNode,
      averagePing,
      averageHttpResponseTime);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ServerGroupImplCopyWith<_$ServerGroupImpl> get copyWith =>
      __$$ServerGroupImplCopyWithImpl<_$ServerGroupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ServerGroupImplToJson(
      this,
    );
  }
}

abstract class _ServerGroup implements ServerGroup {
  const factory _ServerGroup(
      {required final String countryCode,
      required final String countryName,
      required final List<VpnNode> nodes,
      final VpnNode? selectedNode,
      final int averagePing,
      final int averageHttpResponseTime}) = _$ServerGroupImpl;

  factory _ServerGroup.fromJson(Map<String, dynamic> json) =
      _$ServerGroupImpl.fromJson;

  @override
  String get countryCode;
  @override
  String get countryName;
  @override
  List<VpnNode> get nodes;
  @override
  VpnNode? get selectedNode;
  @override
  int get averagePing;
  @override
  int get averageHttpResponseTime;
  @override
  @JsonKey(ignore: true)
  _$$ServerGroupImplCopyWith<_$ServerGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
