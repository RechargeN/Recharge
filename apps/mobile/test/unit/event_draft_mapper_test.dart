import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/models/event_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';

void main() {
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
      price: const EventMoneyDraft(amountMinor: 1599, currencyCode: 'EUR'),
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
    expect(restored.price!.amountMinor, 1599);
    expect((json['price']! as Map<String, Object?>)['minorUnits'], 1599);
    expect(
      (json['price']! as Map<String, Object?>),
      isNot(contains('amountMinor')),
    );
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
      activeCurrency: 'EUR',
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

  test('fractional Event minor units fail closed', () {
    final EventDraftData defaults = EventDraftData.defaults(
      marketCityId: 'riga',
      countryCode: 'LV',
      city: 'Riga',
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );

    expect(
      () => EventDraftMapper.fromJson(const <String, Object?>{
        'price': <String, Object?>{'minorUnits': 12.5, 'currencyCode': 'EUR'},
      }, defaults: defaults),
      throwsFormatException,
    );
  });
}
