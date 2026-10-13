import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 of the canonical JSON of [value] (D4 §5.2): map keys sorted at
/// every level, list order kept, an integral double written as an integer (a
/// JSON round trip cannot tell `1.0` from `1`). Anything that is not JSON data
/// is refused rather than hashed loosely.
String localImportHash(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

Object? _canonical(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError('Non-finite number in import hash');
    }
    return value == value.truncateToDouble() ? value.toInt() : value;
  }
  if (value is Map) {
    if (value.keys.any((Object? key) => key is! String)) {
      throw ArgumentError('Import hash map keys must be strings');
    }
    final List<String> keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonical(value[key]),
    };
  }
  if (value is List) return value.map(_canonical).toList(growable: false);
  throw ArgumentError('Import hash value is not JSON data');
}
