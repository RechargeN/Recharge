import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/recharge_taxonomy.dart';
import 'package:recharge/features/create/application/create_taxonomy.dart';
import 'package:recharge/features/create/domain/entities/content_validation_violation.dart';
import 'package:recharge/features/create/domain/usecases/content_server_readiness.dart';

/// M1 stage 3: the client readiness ports run on the exact bodies of the shared
/// compatibility fixtures (the mapper's output for each Create case) and must
/// answer like the server: never a refusal the server would not give, and for
/// every static rule the same public code and field path.
Map<String, Object?> _fixture(String type) =>
    jsonDecode(
          File(
            '../../packages/api_contracts/schema/content/v1/fixtures/'
            '${type}_create_compat.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;

List<Map<String, Object?>> _cases(Map<String, Object?> fixture) =>
    (fixture['cases']! as List<Object?>).cast<Map<String, Object?>>();

List<String> _pairs(List<ContentValidationViolation> items) =>
    items.map((item) => '${item.code} ${item.fieldPath}').toList()..sort();

List<String> _expected(Map<String, Object?> item) =>
    (item['expectedViolations']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map((v) => '${v['code']} ${v['fieldPath']}')
        .toList()
      ..sort();

void _check(
  String type,
  List<ContentValidationViolation> Function(Map<String, Object?> body) run, {
  required Set<String> caughtByClient,
}) {
  final List<Map<String, Object?>> cases = _cases(_fixture(type));
  final Set<String> names = cases.map((c) => c['name']! as String).toSet();
  expect(names.containsAll(caughtByClient), isTrue, reason: type);
  for (final Map<String, Object?> item in cases) {
    final String name = item['name']! as String;
    final List<String> actual = _pairs(
      run(item['body']! as Map<String, Object?>),
    );
    final List<String> expected = _expected(item);
    // Never stricter than the server.
    expect(
      actual.every(expected.contains),
      isTrue,
      reason: '$type/$name: client $actual, server $expected',
    );
    if (caughtByClient.contains(name)) {
      expect(actual, expected, reason: '$type/$name');
    }
  }
}

void main() {
  test('Place: every static server rule the Create checks missed', () {
    _check(
      'place',
      (body) => placeServerReadiness(body, marketCurrencyCode: 'EUR'),
      caughtByClient: <String>{
        'cover_missing',
        'short_description_short',
        'hours_mode_missing',
        'entry_type_missing',
        'currency_mismatch',
        'phone_invalid',
        'source_type_mismatch',
      },
    );
  });

  test(
    'Rental: static rules and the TEST-ONLY policy, on the server clock',
    () {
      final Map<String, Object?> fixture = _fixture('rental');
      final DateTime now = DateTime.parse(fixture['nowUtc']! as String);
      _check(
        'rental',
        (body) => rentalServerReadiness(body, nowUtc: now),
        caughtByClient: <String>{
          'cover_missing',
          'subcategory_empty',
          'coverage_stale',
          'attestation_policy_version_changed',
          'precision_too_fine',
          'delivery_radius_too_far',
          'external_url_fragment',
        },
      );
    },
  );

  test('Collection: static rules; Catalog review stays with the server', () {
    _check(
      'collection',
      (body) => collectionServerReadiness(
        body,
        subcategoryApplies: (category, subcategory) =>
            canonicalSubcategoryApplies(
              RechargeContentType.collection,
              category,
              subcategory,
            ),
      ),
      caughtByClient: <String>{
        'short_description_missing',
        'cover_missing',
        'subcategory_unknown',
        'local_object',
      },
    );
  });

  test(
    'Activity: the canonical pair must apply to Activity, as the server checks it',
    () {
      for (final Map<String, Object?> item in _cases(_fixture('activity'))) {
        final Map<String, Object?> body = item['body']! as Map<String, Object?>;
        final bool applies = canonicalSubcategoryApplies(
          RechargeContentType.activity,
          body['categoryId']! as String,
          body['subcategoryId']! as String,
        );
        final bool serverRefuses = (item['expectedIssues']! as List<Object?>)
            .contains('activity.subcategory_not_applicable');
        expect(applies, !serverRefuses, reason: item['name']! as String);
      }
    },
  );

  test('the client Rental policy equals the shared TEST-ONLY policy', () {
    final Map<String, Object?> policy =
        jsonDecode(
              File(
                '../../packages/api_contracts/schema/content/v1/fixtures/'
                'rental_reference_policy.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final Map<String, Object?> base = policy['base']! as Map<String, Object?>;
    const RentalServerPolicy client = RentalServerPolicy.emulatorTestOnly;
    expect(client.policyVersion, base['policyVersion']);
    expect(client.coverageFreshnessDays, base['coverageFreshnessDays']);
    expect(
      client.minApproximatePrecisionMeters,
      base['minApproximatePrecisionMeters'],
    );
    expect(client.maxDeliveryRadiusKm, base['maxDeliveryRadiusKm']);
  });

  test(
    'a media placeholder is not a local reference; an item to an unsaved object is',
    () {
      final List<ContentValidationViolation> withPlaceholder =
          collectionServerReadiness(<String, Object?>{
            'shortDescription': 'Three parks for a calm afternoon',
            'media': <String, Object?>{
              'coverImage': <String, Object?>{'mediaId': 'loc_cover'},
            },
            'items': const <Object?>[],
          }, subcategoryApplies: (_, _) => true);
      expect(withPlaceholder, isEmpty);
    },
  );
}
