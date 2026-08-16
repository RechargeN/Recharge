import 'dart:convert';
import 'dart:io';

const bookingSchemaRoot = 'schema/booking/v1';

Map<String, Object?> readJsonObject(String relativePath) {
  final raw = jsonDecode(File(relativePath).readAsStringSync());
  if (raw is! Map) {
    throw FormatException('$relativePath must contain an object');
  }
  return raw.cast<String, Object?>();
}

List<Map<String, Object?>> readObjectList(
  Map<String, Object?> document,
  String field,
) {
  final raw = document[field];
  if (raw is! List) {
    throw FormatException('$field must contain a list');
  }
  return raw
      .map((value) => (value as Map).cast<String, Object?>())
      .toList(growable: false);
}

class BookingSchemaFixtureValidator {
  static const allowedKeywords = <String>{
    r'$schema',
    r'$id',
    r'$defs',
    r'$ref',
    'title',
    'type',
    'additionalProperties',
    'properties',
    'required',
    'enum',
    'const',
    'minimum',
    'maximum',
    'minLength',
    'maxLength',
    'maxItems',
    'items',
    'format',
    'pattern',
  };

  List<String> validateSchemaDocument(Map<String, Object?> schema) {
    final failures = <String>[];
    _validateSchemaNode(schema, r'$', failures);
    if (schema[r'$schema'] != 'https://json-schema.org/draft/2020-12/schema') {
      failures.add(r'$ must declare JSON Schema Draft 2020-12');
    }
    final id = schema[r'$id'];
    if (id is! String || !id.contains('/booking/v1/')) {
      failures.add(r'$ must have a stable Booking v1 $id');
    }
    return failures;
  }

  void _validateSchemaNode(
    Object? node,
    String path,
    List<String> failures,
  ) {
    if (node is! Map) return;
    final map = node.cast<String, Object?>();
    for (final entry in map.entries) {
      if (!allowedKeywords.contains(entry.key)) {
        failures.add('$path uses unapproved keyword ${entry.key}');
        continue;
      }
      if (entry.key == 'properties' || entry.key == r'$defs') {
        final namedSchemas = entry.value;
        if (namedSchemas is! Map) {
          failures.add('$path.${entry.key} must be an object');
          continue;
        }
        for (final named in namedSchemas.entries) {
          _validateSchemaNode(
            named.value,
            '$path.${entry.key}.${named.key}',
            failures,
          );
        }
      } else if (entry.key == 'items') {
        _validateSchemaNode(entry.value, '$path.items', failures);
      }
    }
  }
}
