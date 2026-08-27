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
    'propertyNames',
    'required',
    'dependentRequired',
    'oneOf',
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

  final Map<String, Map<String, Object?>> _documents = {};

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

  List<String> validateInstance(String schemaFile, Object? instance) {
    final failures = <String>[];
    final schema = _loadDocument(schemaFile);
    _validateValue(schema, instance, r'$', failures, schemaFile, 0);
    return failures;
  }

  void _validateSchemaNode(Object? node, String path, List<String> failures) {
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
      } else if (entry.key == 'oneOf') {
        final branches = entry.value;
        if (branches is! List || branches.isEmpty) {
          failures.add('$path.oneOf must be a non-empty array');
          continue;
        }
        for (var index = 0; index < branches.length; index++) {
          _validateSchemaNode(branches[index], '$path.oneOf[$index]', failures);
        }
      } else if (entry.key == 'items' ||
          entry.key == 'propertyNames' ||
          (entry.key == 'additionalProperties' && entry.value is Map)) {
        _validateSchemaNode(entry.value, '$path.${entry.key}', failures);
      } else if (entry.key == 'dependentRequired') {
        final dependencies = entry.value;
        if (dependencies is! Map ||
            dependencies.values.any(
              (value) => value is! List || value.any((item) => item is! String),
            )) {
          failures.add('$path.dependentRequired must map to string arrays');
        }
      }
    }
  }

  void _validateValue(
    Map<String, Object?> schema,
    Object? value,
    String path,
    List<String> failures,
    String currentFile,
    int depth,
  ) {
    if (depth > 256) {
      failures.add('$path exceeds validation depth');
      return;
    }

    final reference = schema[r'$ref'];
    if (reference is String) {
      final resolved = _resolveReference(reference, currentFile);
      _validateValue(
        resolved.schema,
        value,
        path,
        failures,
        resolved.file,
        depth + 1,
      );
      return;
    }

    final oneOf = schema['oneOf'];
    if (oneOf is List) {
      final branchFailures = <List<String>>[];
      for (final rawBranch in oneOf) {
        final candidateFailures = <String>[];
        _validateValue(
          (rawBranch as Map).cast<String, Object?>(),
          value,
          path,
          candidateFailures,
          currentFile,
          depth + 1,
        );
        branchFailures.add(candidateFailures);
      }
      final matches = branchFailures.where((entry) => entry.isEmpty).length;
      if (matches != 1) {
        failures.add(
          '$path must match exactly one oneOf branch; matched $matches',
        );
      }
      return;
    }

    final expectedType = schema['type'];
    if (expectedType is String && !_matchesType(value, expectedType)) {
      failures.add('$path must be $expectedType');
      return;
    }

    if (schema.containsKey('const') && value != schema['const']) {
      failures.add('$path must equal ${schema['const']}');
    }
    final allowed = schema['enum'];
    if (allowed is List && !allowed.contains(value)) {
      failures.add('$path is outside enum');
    }

    if (value is String) {
      final scalarCount = _unicodeScalarCount(value);
      if (scalarCount == null) {
        failures.add('$path contains an unpaired UTF-16 surrogate');
        return;
      }
      final minimum = schema['minLength'];
      if (minimum is int && scalarCount < minimum) {
        failures.add('$path is shorter than $minimum scalars');
      }
      final maximum = schema['maxLength'];
      if (maximum is int && scalarCount > maximum) {
        failures.add('$path is longer than $maximum scalars');
      }
      final pattern = schema['pattern'];
      if (pattern is String &&
          !RegExp(pattern, unicode: true).hasMatch(value)) {
        failures.add('$path does not match pattern');
      }
    }

    if (value is num) {
      if (!value.isFinite) failures.add('$path must be finite');
      final minimum = schema['minimum'];
      if (minimum is num && value < minimum) {
        failures.add('$path is below minimum $minimum');
      }
      final maximum = schema['maximum'];
      if (maximum is num && value > maximum) {
        failures.add('$path is above maximum $maximum');
      }
    }

    if (value is List) {
      final maximum = schema['maxItems'];
      if (maximum is int && value.length > maximum) {
        failures.add('$path has more than $maximum items');
      }
      final itemSchema = schema['items'];
      if (itemSchema is Map) {
        for (var index = 0; index < value.length; index++) {
          _validateValue(
            itemSchema.cast<String, Object?>(),
            value[index],
            '$path[$index]',
            failures,
            currentFile,
            depth + 1,
          );
        }
      }
    }

    if (value is Map) {
      final object = value.cast<String, Object?>();
      final required = schema['required'];
      if (required is List) {
        for (final field in required.cast<String>()) {
          if (!object.containsKey(field)) failures.add('$path misses $field');
        }
      }
      final rawProperties = schema['properties'];
      final properties = rawProperties is Map
          ? rawProperties.cast<String, Object?>()
          : const <String, Object?>{};
      for (final entry in properties.entries) {
        if (!object.containsKey(entry.key)) continue;
        _validateValue(
          (entry.value as Map).cast<String, Object?>(),
          object[entry.key],
          '$path.${entry.key}',
          failures,
          currentFile,
          depth + 1,
        );
      }
      final propertyNames = schema['propertyNames'];
      if (propertyNames is Map) {
        for (final key in object.keys) {
          _validateValue(
            propertyNames.cast<String, Object?>(),
            key,
            '$path.<propertyName>',
            failures,
            currentFile,
            depth + 1,
          );
        }
      }
      final dependentRequired = schema['dependentRequired'];
      if (dependentRequired is Map) {
        for (final entry in dependentRequired.entries) {
          if (!object.containsKey(entry.key)) continue;
          for (final dependent in (entry.value as List).cast<String>()) {
            if (!object.containsKey(dependent)) {
              failures.add('$path.${entry.key} requires $dependent');
            }
          }
        }
      }
      final additional = schema['additionalProperties'];
      for (final entry in object.entries) {
        if (properties.containsKey(entry.key)) continue;
        if (additional == false) {
          failures.add('$path contains unknown field ${entry.key}');
        } else if (additional is Map) {
          _validateValue(
            additional.cast<String, Object?>(),
            entry.value,
            '$path.${entry.key}',
            failures,
            currentFile,
            depth + 1,
          );
        }
      }
    }
  }

  bool _matchesType(Object? value, String type) => switch (type) {
    'null' => value == null,
    'boolean' => value is bool,
    'number' => value is num && value.isFinite,
    'integer' => value is int,
    'string' => value is String,
    'array' => value is List,
    'object' => value is Map,
    _ => false,
  };

  int? _unicodeScalarCount(String value) {
    var count = 0;
    final units = value.codeUnits;
    for (var index = 0; index < units.length; index++) {
      final unit = units[index];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (index + 1 >= units.length) return null;
        final low = units[++index];
        if (low < 0xDC00 || low > 0xDFFF) return null;
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        return null;
      }
      count++;
    }
    return count;
  }

  Map<String, Object?> _loadDocument(String file) => _documents.putIfAbsent(
    file,
    () => readJsonObject('$bookingSchemaRoot/$file'),
  );

  _ResolvedSchema _resolveReference(String reference, String currentFile) {
    final hash = reference.indexOf('#');
    final file = hash < 0
        ? reference
        : reference.substring(0, hash).isEmpty
        ? currentFile
        : reference.substring(0, hash);
    final fragment = hash < 0 ? '' : reference.substring(hash + 1);
    Object? node = _loadDocument(file);
    if (fragment.isNotEmpty) {
      if (!fragment.startsWith('/')) {
        throw FormatException('Unsupported JSON pointer in $reference');
      }
      for (final rawPart in fragment.substring(1).split('/')) {
        final part = rawPart.replaceAll('~1', '/').replaceAll('~0', '~');
        if (node is! Map || !node.containsKey(part)) {
          throw FormatException('Unresolved schema reference $reference');
        }
        node = node[part];
      }
    }
    if (node is! Map) {
      throw FormatException('Schema reference $reference is not an object');
    }
    return _ResolvedSchema(file, node.cast<String, Object?>());
  }
}

class _ResolvedSchema {
  const _ResolvedSchema(this.file, this.schema);

  final String file;
  final Map<String, Object?> schema;
}
