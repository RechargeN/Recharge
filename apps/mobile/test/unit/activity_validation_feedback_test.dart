import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/content_validation_violation.dart';
import 'package:recharge/features/create/application/activity_validation_feedback.dart';

void main() {
  test('linked Place refusals point at the existing field', () {
    for (final code in [
      'activity.linked_place_unknown',
      'activity.linked_place_forbidden',
      'activity.linked_place_unresolved',
    ]) {
      expect(
        activityFieldFeedback(
          ContentValidationViolation.fromWire([
            {'code': code, 'fieldPath': '/body/location/linkedPlaceId'},
          ]),
        ).keys,
        contains('/body/location/linkedPlaceId'),
      );
    }
  });
  test('every shared Activity violation has a known client field message', () {
    final fixture =
        jsonDecode(
              File(
                '../../packages/api_contracts/schema/content/v1/fixtures/activity_create_compat.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final item in fixture['cases'] as List) {
      final details = ContentValidationViolation.fromWire(
        (item as Map)['expectedViolations'],
      );
      final messages = activityFieldFeedback(details);
      expect(messages.length, details.length, reason: item['name'] as String);
    }
  });

  test(
    'known code and exact path render client text; unknown and mismatched stay general',
    () {
      final violations = ContentValidationViolation.fromWire([
        {'code': 'activity.title_length', 'fieldPath': '/body/title'},
        {'code': 'future.unknown', 'fieldPath': '/body/title'},
        {'code': 'activity.access_notes_length', 'fieldPath': '/body/title'},
        {
          'code': 'activity.criterion_required',
          'fieldPath': '/body/criteria/difficulty',
        },
      ]);
      expect(activityFieldFeedback(violations), {
        '/body/title': 'Use 5–80 characters.',
        '/body/criteria/difficulty': 'Complete this category criterion.',
      });
      expect(
        activityFieldFeedback(
          ContentValidationViolation.fromWire([
            {'code': 'future.unknown', 'fieldPath': '/body/title'},
          ]),
        ),
        isEmpty,
      );
    },
  );
  test(
    'malformed, private and excessive details degrade to general answer',
    () {
      for (final input in [
        null,
        'raw data',
        [
          {
            'code': 'activity.title_length',
            'fieldPath': '/body/title',
            'value': 'private',
          },
        ],
        [
          {'code': 'activity.title_length', 'fieldPath': '/internal/secret'},
        ],
        List.filled(51, {
          'code': 'activity.title_length',
          'fieldPath': '/body/title',
        }),
      ]) {
        expect(ContentValidationViolation.fromWire(input), isEmpty);
      }
    },
  );
}
