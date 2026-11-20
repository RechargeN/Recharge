import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/models/event_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';

void main() {
  test(
    'fresh Event defaults use zone calendar and stored fields remain unchanged',
    () {
      final clock = EventTimezoneRepositoryImpl();
      final instant = DateTime.utc(2026, 3, 28, 23, 30);
      EventDraftData defaults(String zone) => EventDraftData.defaults(
        marketCityId: 'riga',
        countryCode: 'LV',
        city: 'Riga',
        timezoneId: zone,
        currencyCode: 'EUR',
        localToday: clock.localDateAt(instantUtc: instant, timezoneId: zone),
      );
      expect(defaults('Europe/Riga').localStartDate, '2026-03-30');
      expect(defaults('Pacific/Honolulu').localStartDate, '2026-03-29');
      final source = defaults(
        'Europe/Riga',
      ).copyWith(localStartDate: '2026-10-25', startMinute: 210);
      final wire = EventDraftMapper.toJson(source);
      final restored = EventDraftMapper.fromJson(
        wire,
        defaults: defaults('Pacific/Honolulu'),
      );
      expect(restored.localStartDate, '2026-10-25');
      expect(restored.startMinute, 210);
      expect(EventDraftMapper.toJson(restored), wire);
    },
  );
  test(
    'legacy Event missing date uses explicit zone without changing original instant',
    () {
      final original = CreateDraftEntity.defaults(
        organizerId: 'u',
        organizerEmail: '',
        organizerName: '',
        timezone: 'Europe/Riga',
      ).copyWith(startDateTimeUtc: DateTime.utc(2026, 3, 28, 23, 30));
      final wire = CreateDraftModel.fromEntity(original).toJson();
      (wire['sectionData'] as Map).remove('event_details');
      final restored = CreateDraftModel.fromJson(wire).toEntity();
      expect(restored.eventData!.localStartDate, '2026-03-29');
      expect(restored.eventData!.startMinute, 90);
      expect(restored.startDateTimeUtc, original.startDateTimeUtc);
      expect(
        (wire['sectionData'] as Map).containsKey('event_details'),
        isFalse,
      );
    },
  );
  EventDraftData timedEvent() {
    final start = DateTime.utc(2026, 8, 3, 12, 0, 0, 123, 456);
    final end = start.add(const Duration(hours: 1));
    return EventDraftData.defaults(
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      timezoneId: 'Pacific/Honolulu',
      currencyCode: 'EUR',
    ).copyWith(
      schemaVersion: EventDraftData.currentSchemaVersion,
      occurrences: [
        EventOccurrenceDraft(
          id: 'o1',
          localDate: '2026-08-03',
          startAtUtc: start,
          endAtUtc: end,
        ),
      ],
      occurrenceOverrides: {
        'o1': EventOccurrenceOverrideDraft(
          occurrenceId: 'o1',
          startAtUtc: start,
          endAtUtc: end,
        ),
      },
      admission: EventAdmissionDraft(
        admissionMode: null,
        registrationMode: null,
        confirmationMode: null,
        registrationWindow: EventAccessWindow(
          kind: EventAccessWindowKind.absolute,
          opensAtUtc: start,
          closesAtUtc: end,
        ),
      ),
    );
  }

  test(
    'Event UTC fields roundtrip exact microseconds with their explicit zone',
    () {
      final source = timedEvent();
      final wire = EventDraftMapper.toJson(source);
      final restored = EventDraftMapper.fromJson(wire, defaults: source);
      expect(
        restored.occurrences.single.startAtUtc,
        source.occurrences.single.startAtUtc,
      );
      expect(
        restored.occurrenceOverrides['o1']!.endAtUtc,
        source.occurrenceOverrides['o1']!.endAtUtc,
      );
      expect(
        restored.admission!.registrationWindow!.opensAtUtc,
        source.admission!.registrationWindow!.opensAtUtc,
      );
      expect(restored.timezoneId, 'Pacific/Honolulu');
      expect(EventDraftMapper.toJson(restored), wire);
    },
  );

  test(
    'Event corrupt explicit UTC values fail instead of normalizing or dropping',
    () {
      final source = timedEvent();
      for (final location in ['occurrence', 'override', 'window']) {
        for (final edge in ['start', 'end']) {
          for (final invalid in <Object>[
            '2026-08-03T12:00:00',
            '2026-08-03T12:00:00+03:00',
            '2026-02-30T12:00:00Z',
            '2026-08-03T25:00:00Z',
            '2026-08-03T12:00:00.1234567Z',
            '',
            123,
          ]) {
            final wire = EventDraftMapper.toJson(source);
            final Map target = switch (location) {
              'occurrence' => (wire['occurrences'] as List).single as Map,
              'override' => (wire['occurrenceOverrides'] as Map)['o1'] as Map,
              _ => (wire['admission'] as Map)['registrationWindow'] as Map,
            };
            final key = location == 'window'
                ? (edge == 'start' ? 'opensAtUtc' : 'closesAtUtc')
                : (edge == 'start' ? 'startAtUtc' : 'endAtUtc');
            target[key] = invalid;
            expect(
              () => EventDraftMapper.fromJson(wire, defaults: source),
              throwsFormatException,
              reason: '$location/$key: $invalid',
            );
          }
        }
      }
    },
  );

  test(
    'Event required occurrence bounds fail while optional timestamps stay absent',
    () {
      final source = timedEvent();
      for (final field in ['startAtUtc', 'endAtUtc']) {
        final wire = EventDraftMapper.toJson(source);
        ((wire['occurrences'] as List).single as Map).remove(field);
        expect(
          () => EventDraftMapper.fromJson(wire, defaults: source),
          throwsFormatException,
        );
      }
      for (final malformed in <Object>[
        {},
        [null],
        [{}],
      ]) {
        final wire = EventDraftMapper.toJson(source)
          ..['occurrences'] = malformed;
        expect(
          () => EventDraftMapper.fromJson(wire, defaults: source),
          throwsFormatException,
        );
      }
      final wire = EventDraftMapper.toJson(source);
      ((wire['occurrenceOverrides'] as Map)['o1'] as Map)
        ..remove('startAtUtc')
        ..['endAtUtc'] = null;
      ((wire['admission'] as Map)['registrationWindow'] as Map)
        ..remove('opensAtUtc')
        ..['closesAtUtc'] = null;
      final restored = EventDraftMapper.fromJson(wire, defaults: source);
      expect(restored.occurrenceOverrides['o1']!.startAtUtc, isNull);
      expect(restored.occurrenceOverrides['o1']!.endAtUtc, isNull);
      expect(restored.admission!.registrationWindow!.opensAtUtc, isNull);
      expect(restored.admission!.registrationWindow!.closesAtUtc, isNull);
    },
  );

  test(
    'Event writers reject host-local instants and preserve opaque future schemas',
    () {
      final source = timedEvent();
      final local = DateTime(2026, 8, 3, 12);
      for (final invalid in [
        source.copyWith(
          occurrences: [source.occurrences.single.copyWith(startAtUtc: local)],
        ),
        source.copyWith(
          occurrenceOverrides: {
            'o1': EventOccurrenceOverrideDraft(
              occurrenceId: 'o1',
              endAtUtc: local,
            ),
          },
        ),
        source.copyWith(
          admission: source.admission!.copyWith(
            registrationWindow: source.admission!.registrationWindow!.copyWith(
              opensAtUtc: local,
            ),
          ),
        ),
      ]) {
        expect(() => EventDraftMapper.toJson(invalid), throwsArgumentError);
      }
      final future = <String, Object?>{
        'schemaVersion': 99,
        'occurrences': [
          {'startAtUtc': 'future-format'},
        ],
      };
      expect(
        EventDraftMapper.toJson(
          EventDraftMapper.fromJson(future, defaults: source),
        ),
        future,
      );
    },
  );
  test('Money canonical Event writer and legacy minor-unit reader agree', () {
    final defaults = EventDraftData.defaults(
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    final source = defaults.copyWith(
      price: Money(minorUnits: 1234, currency: CurrencyCode.parse('EUR')),
    );
    final json = EventDraftMapper.toJson(source);
    expect(json['price'], {'minorUnits': 1234, 'currencyCode': 'EUR'});
    expect(
      EventDraftMapper.fromJson(json, defaults: defaults).price,
      source.price,
    );
    json['price'] = {'amountMinor': '1234', 'currencyCode': 'EUR'};
    expect(
      EventDraftMapper.fromJson(json, defaults: defaults).price?.minorUnits,
      1234,
    );
    json['price'] = {
      'minorUnits': 17,
      'amountMinor': 1234,
      'currencyCode': 'EUR',
    };
    expect(
      EventDraftMapper.fromJson(json, defaults: defaults).price?.minorUnits,
      17,
    );
    json['price'] = {
      'minorUnits': 17.5,
      'amountMinor': 1234,
      'currencyCode': 'EUR',
    };
    expect(
      () => EventDraftMapper.fromJson(json, defaults: defaults),
      throwsA(isA<MoneyReadException>()),
    );
  });

  test('Event draft round-trips typed and unknown fields', () {
    final EventDraftData defaults = EventDraftData.defaults(
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    final EventDraftData source = defaults.copyWith(
      revision: 7,
      format: EventFormat.hybrid,
      onlineAccessMode: EventOnlineAccessMode.publicLink,
      publicOnlineUrl: 'https://events.example/live',
      scheduleMode: EventScheduleMode.recurring,
      localStartDate: '2026-08-03',
      recurrence: const EventRecurrenceRuleDraft(
        frequency: EventRecurrenceFrequency.weekly,
        interval: 2,
        weekdays: <int>{1, 3},
        endMode: EventRecurrenceEndMode.occurrenceCount,
        occurrenceCount: 6,
        exceptionLocalDates: <String>{'2026-08-17'},
      ),
      pricingMode: EventPricingMode.fixed,
      paymentCollectionMode: EventPaymentCollectionMode.external,
      price: Money(minorUnits: 1599, currency: CurrencyCode.parse('EUR')),
      unknownFields: const <String, Object?>{
        'futureCapability': <String, Object?>{'enabled': true},
      },
    );

    final Map<String, Object?> json = EventDraftMapper.toJson(source);
    final EventDraftData restored = EventDraftMapper.fromJson(
      json,
      defaults: defaults,
    );

    expect(restored.revision, 7);
    expect(restored.format, EventFormat.hybrid);
    expect(restored.recurrence!.weekdays, <int>{1, 3});
    expect(restored.recurrence!.exceptionLocalDates, <String>{'2026-08-17'});
    expect(restored.price!.minorUnits, 1599);
    expect(restored.unknownFields['futureCapability'], isA<Map>());
    expect(EventDraftMapper.toJson(restored)['futureCapability'], isA<Map>());
  });

  test('newer schema is preserved without interpreting unknown contract', () {
    final EventDraftData defaults = EventDraftData.defaults(
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );

    final EventDraftData restored = EventDraftMapper.fromJson(
      const <String, Object?>{
        'schemaVersion': 99,
        'futureSchedule': <String, Object?>{'kind': 'quantum'},
      },
      defaults: defaults,
    );

    expect(restored.timezoneId, 'Europe/Riga');
    expect(restored.unknownFields['futureSchedule'], isA<Map>());
  });

  test('Create draft persistence restores nested Event contract', () {
    final CreateDraftEntity base = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Host',
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    );
    final CreateDraftEntity source = base.copyWith(
      eventData: base.eventData!.copyWith(
        format: EventFormat.online,
        onlineAccessMode: EventOnlineAccessMode.publicLink,
        publicOnlineUrl: 'https://events.example/live',
        unknownFields: const <String, Object?>{'futureEventField': 42},
      ),
    );

    final Map<String, dynamic> json = CreateDraftModel.fromEntity(
      source,
    ).toJson();
    final CreateDraftEntity restored = CreateDraftModel.fromJson(
      json,
      activeMarketCityId: 'riga',
      activeTimezone: 'Europe/Riga',
      activeCountry: 'LV',
      activeCity: 'Riga',
    ).toEntity();

    expect(json['schemaVersion'], 9);
    expect(restored.eventData!.format, EventFormat.online);
    expect(restored.eventData!.publicOnlineUrl, 'https://events.example/live');
    expect(restored.eventData!.unknownFields['futureEventField'], 42);
  });
}
