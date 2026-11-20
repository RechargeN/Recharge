import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/features/create/domain/usecases/build_event_content_body.dart';
import 'package:recharge/features/create/domain/usecases/validate_event_draft_usecase.dart';
import '../fixtures/create/user_event_draft.dart';

void main() {
  final base = userEventDraft(
    pageId: '5d1e0000-0000-4000-8000-00000000a001',
    coverPath: 'cover.png',
    localId: 'loc_1700000000000000',
  );
  const validate = ValidateEventDraftUseCase();
  Set<String> codes(CreateDraftEntity draft) => validate(
    draft,
    includeClassification: false,
    nowUtc: DateTime.utc(2026),
  ).map((i) => i.code).toSet();
  for (final entry in <String, bool>{
    '2026-02-03': true, '2026-02-30': false, '2026-2-3': false,
    ' 2026-02-03': false, '2026-02-03 ': false,
    // Intentional tightening: LocalDate supports Gregorian years 0001–9999.
    '0000-01-01': false,
  }.entries) {
    test('Event strict date ${entry.key} accepted=${entry.value}', () {
      final draft = base.copyWith(
        eventData: base.eventData!.copyWith(localStartDate: entry.key),
      );
      expect(codes(draft).contains('local_start_date_invalid'), !entry.value);
    });
  }
  for (final field in <(String, int, int, String)>[
    ('title', 3, 100, 'title_required'),
    ('shortDescription', 20, 240, 'short_description_required'),
    ('fullDescription', 50, 20000, 'full_description_required'),
  ]) {
    for (final length in [field.$2 - 1, field.$2, field.$3, field.$3 + 1]) {
      test('PR13 ${field.$1} length $length', () {
        final text = 'a' * length;
        final draft = switch (field.$1) {
          'title' => base.copyWith(title: text),
          'shortDescription' => base.copyWith(shortDescription: text),
          _ => base.copyWith(fullDescription: text),
        };
        expect(
          codes(draft).contains(field.$4),
          length < field.$2 || length > field.$3,
        );
      });
    }
  }
  test('paid Content price bytes and free omission preserve wire contract', () {
    const mapper = EventContentBodyMapper();
    final paid = base.copyWith(
      eventData: base.eventData!.copyWith(
        pricingMode: EventPricingMode.fixed,
        price: Money(minorUnits: 1500, currency: CurrencyCode.eur),
      ),
    );
    expect(
      utf8.encode(jsonEncode(mapper.map(paid).body)),
      File('test/fixtures/create/cp1_event_paid_body.json').readAsBytesSync(),
    );
    expect(
      utf8.encode(jsonEncode(mapper.map(base).body)),
      File('test/fixtures/create/cp1_event_free_body.json').readAsBytesSync(),
    );
    final pricing = mapper.map(paid).body['pricing'] as Map<String, Object?>;
    expect(
      utf8.encode(jsonEncode(pricing['price'])),
      utf8.encode('{"amountMinor":1500,"currencyCode":"EUR"}'),
    );
    final free = mapper.map(base).body['pricing'] as Map<String, Object?>;
    expect(free.containsKey('price'), isFalse);
    expect(free, {'mode': 'free', 'paymentCollectionMode': 'none'});
  });
  test('persisted EventMoneyDraft price restores into Money losslessly', () {
    final wire = CreateDraftModel.fromEntity(base).toJson();
    final sections = wire['sectionData'] as Map<String, Object?>;
    final event = sections['event_details'] as Map<String, Object?>;
    event['price'] = {'amountMinor': 1500, 'currencyCode': 'EUR'};
    event['pricingMode'] = 'fixed';
    final raw = jsonEncode(wire);
    final restored = CreateDraftModel.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    ).toEntity();
    expect(
      restored.eventData!.price,
      Money(minorUnits: 1500, currency: CurrencyCode.eur),
    );
    expect(
      jsonEncode(wire),
      raw,
      reason: 'read never mutates saved legacy input',
    );
  });
}
