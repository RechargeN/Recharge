import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'geo_point.dart';
import 'geometry_encoding.dart';

/// A deterministic fingerprint of ordered two-dimensional route geometry.
///
/// Elevation is intentionally excluded and can be versioned independently
/// from the route line.
class GeometryHash {
  const GeometryHash._({required this.value, required this.encodingPolicyId});

  static const String algorithm = 'sha256';
  static const String schemaVersion = 'recharge-geometry-hash-v1';

  final String value;
  final String encodingPolicyId;

  factory GeometryHash.fromPoints(
    Iterable<GeoPoint> points, {
    GeometryEncodingPolicy policy = GeometryEncodingPolicy.standard,
  }) {
    final materializedPoints = List<GeoPoint>.unmodifiable(points);
    final encoded = GeometryEncoding.encode(materializedPoints, policy: policy);
    final canonicalPayload = [
      schemaVersion,
      policy.id,
      materializedPoints.length,
      encoded,
    ].join('|');

    return GeometryHash._(
      value: sha256.convert(utf8.encode(canonicalPayload)).toString(),
      encodingPolicyId: policy.id,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeometryHash &&
          value == other.value &&
          encodingPolicyId == other.encodingPolicyId;

  @override
  int get hashCode => Object.hash(value, encodingPolicyId);

  @override
  String toString() => 'GeometryHash($algorithm, $encodingPolicyId, $value)';
}
