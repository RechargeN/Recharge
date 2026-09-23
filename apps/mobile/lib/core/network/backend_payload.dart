import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

Map<String, Object?> freezeBackendPayload(Map<String, Object?> payload) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final MapEntry<String, Object?> entry in payload.entries)
        entry.key: _freezeValue(entry.value),
    });

String semanticPayloadHash(Map<String, Object?> payload) {
  final Object canonical = _canonicalize(payload);
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

Object? _freezeValue(Object? value) {
  if (value is Map) {
    if (value.keys.any((Object? key) => key is! String)) {
      throw ArgumentError('Backend payload map keys must be strings');
    }
    return UnmodifiableMapView<String, Object?>(<String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key! as String: _freezeValue(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  throw ArgumentError('Backend payload contains a non-canonical value');
}

Object _canonicalize(Map<String, Object?> payload) {
  final List<String> keys = payload.keys.toList()..sort();
  return <String, Object?>{
    for (final String key in keys) key: _canonicalizeValue(payload[key]),
  };
}

Object? _canonicalizeValue(Object? value) {
  if (value is Map) {
    if (value.keys.any((Object? key) => key is! String)) {
      throw ArgumentError('Semantic payload map keys must be strings');
    }
    final List<String> keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonicalizeValue(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalizeValue).toList(growable: false);
  }
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  throw ArgumentError('Semantic payload contains a non-canonical value');
}
