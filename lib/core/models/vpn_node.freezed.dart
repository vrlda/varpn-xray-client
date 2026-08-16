// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vpn_node.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

VpnNode _$VpnNodeFromJson(Map<String, dynamic> json) {
  return _VpnNode.fromJson(json);
}

/// @nodoc
mixin _$VpnNode {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get server => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;
  String get protocol =>
      throw _privateConstructorUsedError; // vless, vmess, trojan, ss
  String? get userId => throw _privateConstructorUsedError;
  String? get flow => throw _privateConstructorUsedError;
  String? get encryption => throw _privateConstructorUsedError;
  String? get network =>
      throw _privateConstructorUsedError; // ws, grpc, tcp, http
  String? get security =>
      throw _privateConstructorUsedError; // none, tls, reality
  String? get sni => throw _privateConstructorUsedError;
  String? get realityPubKey => throw _privateConstructorUsedError;
  String? get realityShortId => throw _privateConstructorUsedError;
  String? get path => throw _privateConstructorUsedError;
  String? get host => throw _privateConstructorUsedError;
  Map<String, dynamic>? get rawConfig => throw _privateConstructorUsedError;
  int get ping => throw _privateConstructorUsedError;
  int get httpResponseTime => throw _privateConstructorUsedError;
  bool get isAvailable => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $VpnNodeCopyWith<VpnNode> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VpnNodeCopyWith<$Res> {
  factory $VpnNodeCopyWith(VpnNode value, $Res Function(VpnNode) then) =
      _$VpnNodeCopyWithImpl<$Res, VpnNode>;
  @useResult
  $Res call(
      {String id,
      String name,
      String server,
      int port,
      String protocol,
      String? userId,
      String? flow,
      String? encryption,
      String? network,
      String? security,
      String? sni,
      String? realityPubKey,
      String? realityShortId,
      String? path,
      String? host,
      Map<String, dynamic>? rawConfig,
      int ping,
      int httpResponseTime,
      bool isAvailable});
}

/// @nodoc
class _$VpnNodeCopyWithImpl<$Res, $Val extends VpnNode>
    implements $VpnNodeCopyWith<$Res> {
  _$VpnNodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? server = null,
    Object? port = null,
    Object? protocol = null,
    Object? userId = freezed,
    Object? flow = freezed,
    Object? encryption = freezed,
    Object? network = freezed,
    Object? security = freezed,
    Object? sni = freezed,
    Object? realityPubKey = freezed,
    Object? realityShortId = freezed,
    Object? path = freezed,
    Object? host = freezed,
    Object? rawConfig = freezed,
    Object? ping = null,
    Object? httpResponseTime = null,
    Object? isAvailable = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      server: null == server
          ? _value.server
          : server // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      protocol: null == protocol
          ? _value.protocol
          : protocol // ignore: cast_nullable_to_non_nullable
              as String,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String?,
      flow: freezed == flow
          ? _value.flow
          : flow // ignore: cast_nullable_to_non_nullable
              as String?,
      encryption: freezed == encryption
          ? _value.encryption
          : encryption // ignore: cast_nullable_to_non_nullable
              as String?,
      network: freezed == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String?,
      security: freezed == security
          ? _value.security
          : security // ignore: cast_nullable_to_non_nullable
              as String?,
      sni: freezed == sni
          ? _value.sni
          : sni // ignore: cast_nullable_to_non_nullable
              as String?,
      realityPubKey: freezed == realityPubKey
          ? _value.realityPubKey
          : realityPubKey // ignore: cast_nullable_to_non_nullable
              as String?,
      realityShortId: freezed == realityShortId
          ? _value.realityShortId
          : realityShortId // ignore: cast_nullable_to_non_nullable
              as String?,
      path: freezed == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String?,
      host: freezed == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String?,
      rawConfig: freezed == rawConfig
          ? _value.rawConfig
          : rawConfig // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      ping: null == ping
          ? _value.ping
          : ping // ignore: cast_nullable_to_non_nullable
              as int,
      httpResponseTime: null == httpResponseTime
          ? _value.httpResponseTime
          : httpResponseTime // ignore: cast_nullable_to_non_nullable
              as int,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VpnNodeImplCopyWith<$Res> implements $VpnNodeCopyWith<$Res> {
  factory _$$VpnNodeImplCopyWith(
          _$VpnNodeImpl value, $Res Function(_$VpnNodeImpl) then) =
      __$$VpnNodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String server,
      int port,
      String protocol,
      String? userId,
      String? flow,
      String? encryption,
      String? network,
      String? security,
      String? sni,
      String? realityPubKey,
      String? realityShortId,
      String? path,
      String? host,
      Map<String, dynamic>? rawConfig,
      int ping,
      int httpResponseTime,
      bool isAvailable});
}

/// @nodoc
class __$$VpnNodeImplCopyWithImpl<$Res>
    extends _$VpnNodeCopyWithImpl<$Res, _$VpnNodeImpl>
    implements _$$VpnNodeImplCopyWith<$Res> {
  __$$VpnNodeImplCopyWithImpl(
      _$VpnNodeImpl _value, $Res Function(_$VpnNodeImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? server = null,
    Object? port = null,
    Object? protocol = null,
    Object? userId = freezed,
    Object? flow = freezed,
    Object? encryption = freezed,
    Object? network = freezed,
    Object? security = freezed,
    Object? sni = freezed,
    Object? realityPubKey = freezed,
    Object? realityShortId = freezed,
    Object? path = freezed,
    Object? host = freezed,
    Object? rawConfig = freezed,
    Object? ping = null,
    Object? httpResponseTime = null,
    Object? isAvailable = null,
  }) {
    return _then(_$VpnNodeImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      server: null == server
          ? _value.server
          : server // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
      protocol: null == protocol
          ? _value.protocol
          : protocol // ignore: cast_nullable_to_non_nullable
              as String,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String?,
      flow: freezed == flow
          ? _value.flow
          : flow // ignore: cast_nullable_to_non_nullable
              as String?,
      encryption: freezed == encryption
          ? _value.encryption
          : encryption // ignore: cast_nullable_to_non_nullable
              as String?,
      network: freezed == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as String?,
      security: freezed == security
          ? _value.security
          : security // ignore: cast_nullable_to_non_nullable
              as String?,
      sni: freezed == sni
          ? _value.sni
          : sni // ignore: cast_nullable_to_non_nullable
              as String?,
      realityPubKey: freezed == realityPubKey
          ? _value.realityPubKey
          : realityPubKey // ignore: cast_nullable_to_non_nullable
              as String?,
      realityShortId: freezed == realityShortId
          ? _value.realityShortId
          : realityShortId // ignore: cast_nullable_to_non_nullable
              as String?,
      path: freezed == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String?,
      host: freezed == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String?,
      rawConfig: freezed == rawConfig
          ? _value._rawConfig
          : rawConfig // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      ping: null == ping
          ? _value.ping
          : ping // ignore: cast_nullable_to_non_nullable
              as int,
      httpResponseTime: null == httpResponseTime
          ? _value.httpResponseTime
          : httpResponseTime // ignore: cast_nullable_to_non_nullable
              as int,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VpnNodeImpl implements _VpnNode {
  const _$VpnNodeImpl(
      {required this.id,
      required this.name,
      required this.server,
      required this.port,
      required this.protocol,
      this.userId,
      this.flow,
      this.encryption,
      this.network,
      this.security,
      this.sni,
      this.realityPubKey,
      this.realityShortId,
      this.path,
      this.host,
      final Map<String, dynamic>? rawConfig,
      this.ping = 0,
      this.httpResponseTime = 0,
      this.isAvailable = false})
      : _rawConfig = rawConfig;

  factory _$VpnNodeImpl.fromJson(Map<String, dynamic> json) =>
      _$$VpnNodeImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String server;
  @override
  final int port;
  @override
  final String protocol;
// vless, vmess, trojan, ss
  @override
  final String? userId;
  @override
  final String? flow;
  @override
  final String? encryption;
  @override
  final String? network;
// ws, grpc, tcp, http
  @override
  final String? security;
// none, tls, reality
  @override
  final String? sni;
  @override
  final String? realityPubKey;
  @override
  final String? realityShortId;
  @override
  final String? path;
  @override
  final String? host;
  final Map<String, dynamic>? _rawConfig;
  @override
  Map<String, dynamic>? get rawConfig {
    final value = _rawConfig;
    if (value == null) return null;
    if (_rawConfig is EqualUnmodifiableMapView) return _rawConfig;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final int ping;
  @override
  @JsonKey()
  final int httpResponseTime;
  @override
  @JsonKey()
  final bool isAvailable;

  @override
  String toString() {
    return 'VpnNode(id: $id, name: $name, server: $server, port: $port, protocol: $protocol, userId: $userId, flow: $flow, encryption: $encryption, network: $network, security: $security, sni: $sni, realityPubKey: $realityPubKey, realityShortId: $realityShortId, path: $path, host: $host, rawConfig: $rawConfig, ping: $ping, httpResponseTime: $httpResponseTime, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VpnNodeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.server, server) || other.server == server) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.protocol, protocol) ||
                other.protocol == protocol) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.flow, flow) || other.flow == flow) &&
            (identical(other.encryption, encryption) ||
                other.encryption == encryption) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.security, security) ||
                other.security == security) &&
            (identical(other.sni, sni) || other.sni == sni) &&
            (identical(other.realityPubKey, realityPubKey) ||
                other.realityPubKey == realityPubKey) &&
            (identical(other.realityShortId, realityShortId) ||
                other.realityShortId == realityShortId) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.host, host) || other.host == host) &&
            const DeepCollectionEquality()
                .equals(other._rawConfig, _rawConfig) &&
            (identical(other.ping, ping) || other.ping == ping) &&
            (identical(other.httpResponseTime, httpResponseTime) ||
                other.httpResponseTime == httpResponseTime) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        server,
        port,
        protocol,
        userId,
        flow,
        encryption,
        network,
        security,
        sni,
        realityPubKey,
        realityShortId,
        path,
        host,
        const DeepCollectionEquality().hash(_rawConfig),
        ping,
        httpResponseTime,
        isAvailable
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VpnNodeImplCopyWith<_$VpnNodeImpl> get copyWith =>
      __$$VpnNodeImplCopyWithImpl<_$VpnNodeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VpnNodeImplToJson(
      this,
    );
  }
}

abstract class _VpnNode implements VpnNode {
  const factory _VpnNode(
      {required final String id,
      required final String name,
      required final String server,
      required final int port,
      required final String protocol,
      final String? userId,
      final String? flow,
      final String? encryption,
      final String? network,
      final String? security,
      final String? sni,
      final String? realityPubKey,
      final String? realityShortId,
      final String? path,
      final String? host,
      final Map<String, dynamic>? rawConfig,
      final int ping,
      final int httpResponseTime,
      final bool isAvailable}) = _$VpnNodeImpl;

  factory _VpnNode.fromJson(Map<String, dynamic> json) = _$VpnNodeImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get server;
  @override
  int get port;
  @override
  String get protocol;
  @override // vless, vmess, trojan, ss
  String? get userId;
  @override
  String? get flow;
  @override
  String? get encryption;
  @override
  String? get network;
  @override // ws, grpc, tcp, http
  String? get security;
  @override // none, tls, reality
  String? get sni;
  @override
  String? get realityPubKey;
  @override
  String? get realityShortId;
  @override
  String? get path;
  @override
  String? get host;
  @override
  Map<String, dynamic>? get rawConfig;
  @override
  int get ping;
  @override
  int get httpResponseTime;
  @override
  bool get isAvailable;
  @override
  @JsonKey(ignore: true)
  _$$VpnNodeImplCopyWith<_$VpnNodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
