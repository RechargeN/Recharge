import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/content_validation_feedback.dart';
import 'package:recharge/features/create/domain/entities/content_validation_violation.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

/// M1 stage 3 (3-A): every public detail the server sends for a Create case of
/// Place, Rental and Collection is accepted on the wire and has a field text;
/// an unknown code or a code on another path stays the general message.
void main() {
  const Map<String, CreateObjectType> types = <String, CreateObjectType>{
    'place': CreateObjectType.place,
    'rental': CreateObjectType.rental,
    'collection': CreateObjectType.collection,
  };

  for (final MapEntry<String, CreateObjectType> type in types.entries) {
    test('${type.key}: every shared violation parses and has a field text', () {
      final Map<String, Object?> fixture =
          jsonDecode(
                File(
                  '../../packages/api_contracts/schema/content/v1/fixtures/'
                  '${type.key}_create_compat.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      for (final Object? value in fixture['cases']! as List<Object?>) {
        final Map<String, Object?> item = value! as Map<String, Object?>;
        final List<Object?> wire = item['expectedViolations']! as List<Object?>;
        final List<ContentValidationViolation> parsed =
            ContentValidationViolation.fromWire(wire.isEmpty ? null : wire);
        expect(parsed, hasLength(wire.length), reason: '${item['name']}');
        final Map<String, String> feedback = contentFieldFeedback(
          type.value,
          parsed,
        );
        expect(
          feedback.keys.toSet(),
          parsed.map((v) => v.fieldPath).toSet(),
          reason: '${item['name']}',
        );
        // Every field has its own name; only the whole body is "Draft".
        for (final String path in feedback.keys.where((p) => p != '/body')) {
          expect(contentFieldLabel(path), isNot('Draft'), reason: path);
        }
      }
    });
  }

  test('unknown codes and mismatched paths stay general', () {
    final List<ContentValidationViolation> violations =
        ContentValidationViolation.fromWire(<Object?>[
          <String, Object?>{
            'code': 'place.media.cover_missing',
            'fieldPath': '/body/title',
          },
          <String, Object?>{
            'code': 'place.future_rule',
            'fieldPath': '/body/title',
          },
        ]);
    expect(violations, hasLength(2));
    expect(contentFieldFeedback(CreateObjectType.place, violations), isEmpty);
    expect(
      contentFieldFeedback(CreateObjectType.event, violations),
      isEmpty,
    );
  });
}
