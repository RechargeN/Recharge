import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/product_analytics/product_analytics_contract.dart';

/// L3 contract parity: the Dart registry equals the canonical JSON registry,
/// and the shared synthetic corpus (also used by the backend contract and
/// Emulator tests) passes or fails exactly as declared.
const String _root = '../../packages/api_contracts/schema/product_analytics/v1';

Map<String, Object?> _read(String file) =>
    jsonDecode(File('$_root/$file').readAsStringSync()) as Map<String, Object?>;

void main() {
  final Map<String, Object?> registry = _read(
    'product_analytics_event_registry.v1.json',
  );
  final Map<String, Object?> corpus = _read(
    'fixtures/product_analytics_corpus.v1.json',
  );
  final List<Map<String, Object?>> valid = (corpus['validEvents']! as List)
      .cast<Map<String, Object?>>();

  test('PA-T11 contract: the Dart registry equals the canonical JSON', () {
    expect(<String, Object?>{
      'schemaVersion': 1,
      'registryRevision': productAnalyticsRegistryRevision,
      'purposeId': productAnalyticsPurposeId,
      'legalBasisRef': productAnalyticsLegalBasisRef,
      'subjectMode': productAnalyticsSubjectMode,
      'dataClass': productAnalyticsDataClass,
      'limits': ProductAnalyticsLimits.asJson,
      'enums': productAnalyticsEnums,
      'events': <Map<String, Object?>>[
        for (final ProductAnalyticsDefinition definition
            in productAnalyticsEventRegistry)
          definition.toJson(),
      ],
    }, registry);
    expect(
      ProductAnalyticsObjectKind.values.map((kind) => kind.wire).toList(),
      productAnalyticsEnums['objectKind'],
    );
    expect(
      ProductAnalyticsEntrySurface.values.map((kind) => kind.wire).toList(),
      productAnalyticsEnums['entrySurface'],
    );
    expect(
      ProductAnalyticsPublishOutcome.values.map((kind) => kind.wire).toList(),
      productAnalyticsEnums['publishOutcome'],
    );
  });

  test('PA-T02 corpus: valid events pass and every invalid case fails', () {
    for (final Map<String, Object?> event in valid) {
      expect(isValidProductAnalyticsEnvelope(event), isTrue);
    }
    final List<Map<String, Object?>> invalid =
        (corpus['invalidEvents']! as List).cast<Map<String, Object?>>();
    expect(invalid.length, greaterThanOrEqualTo(25));
    for (final Map<String, Object?> item in invalid) {
      final Object? eventName = item['eventName'];
      final Map<String, Object?> event = Map<String, Object?>.of(
        eventName == null
            ? valid.first
            : valid.firstWhere(
                (Map<String, Object?> e) => e['eventName'] == eventName,
              ),
      );
      if (item['patch'] case final Map<String, Object?> patch) {
        event.addAll(patch);
      }
      if (item.containsKey('fields')) event['fields'] = item['fields'];
      if (item['rawFields'] case final String raw) {
        event['fields'] = jsonDecode(raw);
      }
      expect(
        isValidProductAnalyticsEnvelope(event),
        isFalse,
        reason: item['case'] as String?,
      );
    }
    for (final Map<String, Object?> item
        in (corpus['invalidBatches']! as List).cast<Map<String, Object?>>()) {
      final Map<String, Object?> batch;
      if (item['repeatValidEvents'] case final int count) {
        batch = <String, Object?>{
          'schemaVersion': 1,
          'events': List<Object?>.filled(count, valid.first),
        };
      } else {
        final Map<String, Object?> raw = Map<String, Object?>.of(
          item['batch']! as Map<String, Object?>,
        );
        if (item['case'] != 'batch_empty' && raw['events'] is List) {
          raw['events'] = <Object?>[valid.first];
        }
        batch = raw;
      }
      expect(
        isValidProductAnalyticsBatch(batch),
        isFalse,
        reason: item['case'] as String?,
      );
    }
  });

  test('typed events carry exactly the registered fields', () {
    const List<ProductAnalyticsEvent> events = <ProductAnalyticsEvent>[
      DetailsOpened(ProductAnalyticsObjectKind.classWorkshop),
      FavoriteAdded(
        ProductAnalyticsObjectKind.rental,
        ProductAnalyticsEntrySurface.other,
      ),
      CreatePublishFinished(
        ProductAnalyticsObjectKind.scenario,
        ProductAnalyticsPublishOutcome.submitted,
      ),
    ];
    for (final ProductAnalyticsEvent event in events) {
      final ProductAnalyticsDefinition definition = productAnalyticsDefinition(
        event.eventName,
        event.eventVersion,
      )!;
      expect(event.fields.keys.toSet(), definition.fields.keys.toSet());
    }
    expect(ProductAnalyticsObjectKind.fromObjectType('quick_plan'), isNull);
    expect(ProductAnalyticsObjectKind.fromObjectType('quickPlan'), isNull);
    expect(
      ProductAnalyticsObjectKind.fromObjectType('findPeople'),
      ProductAnalyticsObjectKind.findPeople,
    );
    expect(
      ProductAnalyticsObjectKind.fromObjectType('class_workshop'),
      ProductAnalyticsObjectKind.classWorkshop,
    );
  });
}
