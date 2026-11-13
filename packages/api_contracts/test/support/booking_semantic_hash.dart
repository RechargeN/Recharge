import 'dart:convert';

import 'package:api_contracts/api_contracts.dart';
import 'package:crypto/crypto.dart';

const _algorithmVersion = 'booking_semantic_hash_v1';
const _maxSafeInteger = 9007199254740991;

class BookingSemanticHashResult {
  const BookingSemanticHashResult({
    required this.projection,
    required this.canonicalBytes,
    required this.digest,
    required this.logicalIdentity,
  });

  final Map<String, Object?> projection;
  final List<int> canonicalBytes;
  final String digest;
  final String logicalIdentity;

  String get canonicalHex => canonicalBytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}

BookingSemanticHashResult computeBookingSemanticHash({
  required String rawCommandJson,
  required Map<String, Object?> resolvedActorScope,
}) {
  final decoded = StrictJsonReader(rawCommandJson).read();
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('command_root_not_object');
  }
  _validateActor(resolvedActorScope);
  final command = BookingCommandDto.fromJson(decoded);
  _validateSafeJson(decoded, 'command');

  final projection = <String, Object?>{
    'algorithmVersion': _algorithmVersion,
    'commandType': command.commandType.name,
    'commandSchemaVersion': command.schemaVersion,
    'resolvedActorScope': <String, Object?>{
      'kind': resolvedActorScope['kind'],
      'id': resolvedActorScope['id'],
    },
    if (command.expectedBookingRevision != null)
      'expectedBookingRevision': command.expectedBookingRevision,
    if (command.occurredAgainstEventRevision != null)
      'occurredAgainstEventRevision': command.occurredAgainstEventRevision,
    'payload': thawJsonMap(command.payload),
  };
  final canonical = _canonicalJson(projection);
  final bytes = utf8.encode(canonical);
  return BookingSemanticHashResult(
    projection: projection,
    canonicalBytes: bytes,
    digest: sha256.convert(bytes).toString(),
    logicalIdentity:
        '${resolvedActorScope['kind']}:${resolvedActorScope['id']}|'
        '${command.commandType.name}|${command.idempotencyKey}',
  );
}

void _validateActor(Map<String, Object?> actor) {
  if (actor.length != 2 ||
      actor['kind'] != 'user' ||
      actor['id'] is! String ||
      (actor['id']! as String).isEmpty) {
    throw const FormatException('invalid_actor_scope');
  }
  _validateUnicode(actor['id']! as String);
}

void _validateSafeJson(Object? value, String path, [int depth = 0]) {
  if (depth > 64) throw const FormatException('json_depth_exceeded');
  if (value == null || value is bool) return;
  if (value is int) {
    if (value < -_maxSafeInteger || value > _maxSafeInteger) {
      throw FormatException('unsafe_integer:$path');
    }
    return;
  }
  if (value is num) throw FormatException('fractional_number:$path');
  if (value is String) {
    _validateUnicode(value);
    return;
  }
  if (value is List) {
    for (var index = 0; index < value.length; index++) {
      _validateSafeJson(value[index], '$path[$index]', depth + 1);
    }
    return;
  }
  if (value is Map<String, Object?>) {
    for (final entry in value.entries) {
      _validateUnicode(entry.key);
      _validateSafeJson(entry.value, '$path.${entry.key}', depth + 1);
    }
    return;
  }
  throw FormatException('unsupported_json_type:$path');
}

void _validateUnicode(String value) {
  final units = value.codeUnits;
  for (var index = 0; index < units.length; index++) {
    final unit = units[index];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (index + 1 >= units.length) {
        throw const FormatException('unpaired_surrogate');
      }
      final low = units[++index];
      if (low < 0xDC00 || low > 0xDFFF) {
        throw const FormatException('unpaired_surrogate');
      }
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      throw const FormatException('unpaired_surrogate');
    }
  }
}

String _canonicalJson(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is int) return value.toString();
  if (value is String) return jsonEncode(value);
  if (value is List) return '[${value.map(_canonicalJson).join(',')}]';
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort(_compareUtf16);
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  throw const FormatException('unsupported_canonical_value');
}

int _compareUtf16(String left, String right) {
  final a = left.codeUnits;
  final b = right.codeUnits;
  final length = a.length < b.length ? a.length : b.length;
  for (var index = 0; index < length; index++) {
    final comparison = a[index].compareTo(b[index]);
    if (comparison != 0) return comparison;
  }
  return a.length.compareTo(b.length);
}

class StrictJsonReader {
  StrictJsonReader(this.source);

  final String source;
  int _offset = 0;

  Object? read() {
    _skipWhitespace();
    final value = _readValue(0);
    _skipWhitespace();
    if (_offset != source.length) throw const FormatException('trailing_json');
    return value;
  }

  Object? _readValue(int depth) {
    if (depth > 64) throw const FormatException('json_depth_exceeded');
    if (_offset >= source.length) throw const FormatException('unexpected_eof');
    return switch (source.codeUnitAt(_offset)) {
      0x7B => _readObject(depth + 1),
      0x5B => _readArray(depth + 1),
      0x22 => _readString(),
      0x74 => _readLiteral('true', true),
      0x66 => _readLiteral('false', false),
      0x6E => _readLiteral('null', null),
      _ => _readNumber(),
    };
  }

  Map<String, Object?> _readObject(int depth) {
    _offset++;
    final result = <String, Object?>{};
    _skipWhitespace();
    if (_consume(0x7D)) return result;
    while (true) {
      if (_peek() != 0x22) throw const FormatException('object_key_expected');
      final key = _readString();
      if (result.containsKey(key)) throw FormatException('duplicate_key:$key');
      _skipWhitespace();
      _expect(0x3A);
      _skipWhitespace();
      result[key] = _readValue(depth);
      _skipWhitespace();
      if (_consume(0x7D)) return result;
      _expect(0x2C);
      _skipWhitespace();
    }
  }

  List<Object?> _readArray(int depth) {
    _offset++;
    final result = <Object?>[];
    _skipWhitespace();
    if (_consume(0x5D)) return result;
    while (true) {
      result.add(_readValue(depth));
      _skipWhitespace();
      if (_consume(0x5D)) return result;
      _expect(0x2C);
      _skipWhitespace();
    }
  }

  String _readString() {
    final start = _offset;
    _offset++;
    while (_offset < source.length) {
      final unit = source.codeUnitAt(_offset++);
      if (unit == 0x22) {
        final value = jsonDecode(source.substring(start, _offset));
        if (value is! String) throw const FormatException('invalid_string');
        _validateUnicode(value);
        return value;
      }
      if (unit < 0x20) throw const FormatException('string_control');
      if (unit == 0x5C) {
        if (_offset >= source.length) throw const FormatException('bad_escape');
        final escaped = source.codeUnitAt(_offset++);
        if (escaped == 0x75) {
          _readHexEscape();
        } else if (!const <int>{
          0x22,
          0x5C,
          0x2F,
          0x62,
          0x66,
          0x6E,
          0x72,
          0x74,
        }.contains(escaped)) {
          throw const FormatException('bad_escape');
        }
      }
    }
    throw const FormatException('unterminated_string');
  }

  void _readHexEscape() {
    if (_offset + 4 > source.length) {
      throw const FormatException('bad_unicode_escape');
    }
    final hex = source.substring(_offset, _offset + 4);
    if (!RegExp(r'^[0-9A-Fa-f]{4}$').hasMatch(hex)) {
      throw const FormatException('bad_unicode_escape');
    }
    _offset += 4;
  }

  Object? _readLiteral(String literal, Object? value) {
    if (!source.startsWith(literal, _offset)) {
      throw const FormatException('invalid_literal');
    }
    _offset += literal.length;
    return value;
  }

  int _readNumber() {
    final match = RegExp(
      r'^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?',
    ).firstMatch(source.substring(_offset));
    if (match == null) throw const FormatException('value_expected');
    final token = match.group(0)!;
    _offset += token.length;
    final parsed = num.tryParse(token);
    if (parsed == null || !parsed.isFinite) {
      throw const FormatException('invalid_number');
    }
    if (parsed != parsed.truncateToDouble()) {
      throw const FormatException('fractional_number');
    }
    final integer = parsed.toInt();
    if (integer < -_maxSafeInteger || integer > _maxSafeInteger) {
      throw const FormatException('unsafe_integer');
    }
    return integer;
  }

  void _skipWhitespace() {
    while (_offset < source.length &&
        const <int>{
          0x20,
          0x09,
          0x0A,
          0x0D,
        }.contains(source.codeUnitAt(_offset))) {
      _offset++;
    }
  }

  int _peek() => _offset < source.length ? source.codeUnitAt(_offset) : -1;

  bool _consume(int unit) {
    if (_peek() != unit) return false;
    _offset++;
    return true;
  }

  void _expect(int unit) {
    if (!_consume(unit)) throw const FormatException('unexpected_token');
  }
}
