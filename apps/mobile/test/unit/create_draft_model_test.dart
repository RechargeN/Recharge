import '../support/route_domain_fixtures.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/draft_publisher.dart';

void main() {
  test(
    'Rental reads recorded nested currency without inventing envelope defaults',
    () {
      final base = CreateDraftEntity.defaults(
        organizerId: 'u',
        organizerEmail: '',
        organizerName: '',
      ).copyWith(objectType: CreateObjectType.rental, clearEventData: true);
      final incomplete = CreateDraftModel.fromEntity(base).toEntity();
      expect(incomplete.currency, isEmpty);
      expect(incomplete.rentalData, isNull);
      final original = base.copyWith(
        rentalData: RentalDraftData.defaults(
          userId: 'u',
          currencyCode: 'EUR',
          timeZoneId: 'Europe/Riga',
        ),
      );
      final restored = CreateDraftModel.fromJson(
        CreateDraftModel.fromEntity(original).toJson(),
      ).toEntity();
      expect(restored.currency, isEmpty);
      expect(restored.rentalData!.pricing.currencyCode, 'EUR');
      expect(restored.rentalData!.pricing.deposit.amount.currency.value, 'EUR');
    },
  );
  test(
    'common Create money has canonical precedence and explicit legacy currency',
    () {
      final draft = CreateDraftEntity.defaults(
        organizerId: 'u',
        organizerEmail: '',
        organizerName: '',
        currency: 'EUR',
      );
      final json = CreateDraftModel.fromEntity(draft).toJson()
        ..remove('basePriceMinorUnits');
      json['basePrice'] = 12.34;
      final legacy = CreateDraftModel.fromJson(json);
      expect(legacy.basePrice?.minorUnits, 1234);
      expect(legacy.basePrice?.currency.value, 'EUR');
      expect(legacy.toJson()['basePriceMinorUnits'], 1234);
      expect(legacy.toJson().containsKey('basePrice'), isFalse);
      json['basePriceMinorUnits'] = 1;
      expect(CreateDraftModel.fromJson(json).basePrice?.minorUnits, 1);
      json['basePriceMinorUnits'] = 1.5;
      expect(
        () => CreateDraftModel.fromJson(json),
        throwsA(isA<MoneyReadException>()),
      );
      json.remove('basePriceMinorUnits');
      json.remove('currency');
      expect(
        () => CreateDraftModel.fromJson(json),
        throwsA(isA<MoneyReadException>()),
      );
      expect(
        () => CreateDraftModel.fromJson(json, activeCurrency: 'EUR'),
        throwsA(isA<MoneyReadException>()),
      );
      json['currency'] = 123;
      expect(
        () => CreateDraftModel.fromJson(json),
        throwsA(isA<MoneyReadException>()),
      );
      json.remove('currency');
      json['basePrice'] = 1.234;
      expect(
        () => CreateDraftModel.fromJson(json, activeCurrency: 'EUR'),
        throwsA(isA<MoneyReadException>()),
      );
    },
  );

  final base = CreateDraftEntity.defaults(
    organizerId: 'owner',
    organizerEmail: '',
    organizerName: '',
  );
  Map<String, dynamic> wire() => CreateDraftModel.fromEntity(base).toJson();
  CreateDraftEntity read(Map<String, dynamic> json) =>
      CreateDraftModel.fromJson(json).toEntity();

  test(
    'legacy Route keeps its explicit stored publisher and envelope conflicts fail closed',
    () {
      const stored = PublisherRef(
        type: PublisherType.page,
        id: 'stored-route-page',
      );
      final route = base.copyWith(
        objectType: CreateObjectType.route,
        clearEventData: true,
        clearPublisher: true,
        routeData: routeFixture().copyWith(publisherRef: stored),
      );
      final wire = CreateDraftModel.fromEntity(route).toJson()
        ..remove('publisherEnvelope');
      final restored = read(wire);
      expect(restored.effectivePublisher, stored);
      expect(
        read(CreateDraftModel.fromEntity(restored).toJson()).effectivePublisher,
        stored,
      );
      wire['publisherEnvelope'] = {
        'schemaVersion': 1,
        'publisherRef': {'type': 'page', 'id': 'forged-other-page'},
      };
      final conflict = read(wire);
      expect(conflict.routeData!.publisherRef, stored);
      expect(conflict.publisherSelectionRequired, isTrue);
    },
  );
  test('all ten legacy types without a stored publisher require selection', () {
    for (final type in CreateObjectType.values.where(
      (t) => t != CreateObjectType.quickPlan,
    )) {
      final value = wire()
        ..['objectType'] = type.taxonomyId
        ..remove('publisherEnvelope')
        ..['sectionData'] = <String, Object?>{};
      expect(read(value).publisherSelectionRequired, isTrue, reason: type.name);
    }
  });
  test(
    'all ten envelopes keep UTC microseconds zone and publisher on roundtrip',
    () {
      final instant = DateTime.utc(2026, 8, 3, 12, 0, 0, 123, 456);
      for (final type in CreateObjectType.values.where(
        (t) => t != CreateObjectType.quickPlan,
      )) {
        final source = base.copyWith(
          objectType: type,
          createdAtUtc: instant,
          updatedAtUtc: instant,
          publishedAtUtc: instant,
          startDateTimeUtc: instant,
          endDateTimeUtc: instant.add(const Duration(hours: 1)),
          registrationDeadlineUtc: instant,
          timezone: 'Pacific/Honolulu',
        );
        final restored = read(CreateDraftModel.fromEntity(source).toJson());
        expect(restored.createdAtUtc, instant, reason: type.name);
        expect(restored.updatedAtUtc, instant);
        expect(restored.publishedAtUtc, instant);
        expect(restored.startDateTimeUtc, instant);
        expect(restored.endDateTimeUtc, instant.add(const Duration(hours: 1)));
        expect(restored.registrationDeadlineUtc, instant);
        expect(restored.timezone, 'Pacific/Honolulu');
        expect(restored.effectivePublisher, source.effectivePublisher);
      }
    },
  );

  test(
    'envelope UTC rejects invalid values and missing required audit fields',
    () {
      for (final field in [
        'createdAtUtcIso',
        'updatedAtUtcIso',
        'publishedAtUtcIso',
        'startDateTimeUtcIso',
        'endDateTimeUtcIso',
        'registrationDeadlineUtcIso',
      ]) {
        for (final bad in <Object>[
          '2026-08-03T12:00:00',
          '2026-08-03T12:00:00+03:00',
          '2026-02-30T12:00:00Z',
          '2026-08-03T12:00:00.1234567Z',
          '',
          123,
        ]) {
          expect(
            () => read(wire()..[field] = bad),
            throwsFormatException,
            reason: '$field: $bad',
          );
        }
      }
      for (final field in ['createdAtUtcIso', 'updatedAtUtcIso']) {
        for (final version in [1, 9]) {
          final missing = wire()
            ..['schemaVersion'] = version
            ..remove(field);
          expect(() => read(missing), throwsFormatException);
          expect(() => read(wire()..[field] = null), throwsFormatException);
        }
      }
      final optional = wire()
        ..remove('startDateTimeUtcIso')
        ..remove('endDateTimeUtcIso')
        ..remove('registrationDeadlineUtcIso')
        ..remove('publishedAtUtcIso');
      final restored = read(optional);
      expect(restored.startDateTimeUtc, isNull);
      expect(restored.endDateTimeUtc, isNull);
      expect(restored.registrationDeadlineUtc, isNull);
      expect(restored.publishedAtUtc, isNull);
    },
  );

  test('envelope writers reject host-local DateTime values', () {
    final local = DateTime(2026, 8, 3, 12);
    for (final source in [
      base.copyWith(createdAtUtc: local),
      base.copyWith(updatedAtUtc: local),
      base.copyWith(publishedAtUtc: local),
      base.copyWith(startDateTimeUtc: local),
      base.copyWith(endDateTimeUtc: local),
      base.copyWith(registrationDeadlineUtc: local),
    ]) {
      expect(() => CreateDraftModel.fromEntity(source), throwsArgumentError);
    }
  });

  test('all ten local envelopes roundtrip independently of typed blocks', () {
    for (final type in CreateObjectType.values.where(
      (t) => t != CreateObjectType.quickPlan,
    )) {
      final draft = base.copyWith(
        objectType: type,
        publisherRef: const PublisherRef(
          type: PublisherType.page,
          id: 'page-A',
        ),
      );
      final json = CreateDraftModel.fromEntity(draft).toJson()
        ..['sectionData'] = <String, Object?>{};
      final restored = read(json);
      expect(
        restored.effectivePublisher,
        draft.publisherRef,
        reason: type.name,
      );
    }
  });

  for (final type in <String>[
    'event',
    'place',
    'activity',
    'find_people',
    'rental',
    'collection',
  ]) {
    test('$type legacy explicit Page survives compatibility read', () {
      final json = wire()..['objectType'] = type;
      final key = switch (type) {
        'find_people' => 'find_people_details',
        _ => '${type}_details',
      };
      final block = <String, Object?>{'schemaVersion': type == 'event' ? 2 : 1};
      if (type == 'activity' || type == 'collection') {
        block['publisher_ref'] = {'type': 'page', 'id': 'page-old'};
      } else if (type == 'find_people') {
        block.addAll({'publisherType': 'page', 'publisherId': 'page-old'});
      } else {
        block['publisherRef'] = {'type': 'page', 'id': 'page-old'};
      }
      json['sectionData'] = {key: block};
      final restored = read(json);
      expect(
        restored.effectivePublisher,
        const PublisherRef(type: PublisherType.page, id: 'page-old'),
      );
      expect(
        read(CreateDraftModel.fromEntity(restored).toJson()).effectivePublisher,
        restored.effectivePublisher,
      );
    });
  }

  test(
    'legacy Event numeric-string schema remains readable; v1 never invents a Page',
    () {
      for (final version in <Object>['2', 'invalid', 1]) {
        final json = wire()
          ..['sectionData'] = {
            'event_details': {
              'schemaVersion': version,
              'publisherRef': {'type': 'page', 'id': 'legacy-page'},
            },
          };
        final restored = read(json);
        expect(restored.publisherSelectionRequired, version != '2');
        if (version == '2') {
          expect(restored.effectivePublisher.id, 'legacy-page');
        }
      }
    },
  );

  test(
    'missing or invalid legacy publisher is selection-required, never inferred',
    () {
      for (final type in CreateObjectType.values.where(
        (t) => t != CreateObjectType.quickPlan,
      )) {
        final json = wire()
          ..['objectType'] = type.taxonomyId
          ..['sectionData'] = <String, Object?>{};
        final restored = read(json);
        expect(restored.publisherSelectionRequired, isTrue, reason: type.name);
        expect(
          read(
            CreateDraftModel.fromEntity(restored).toJson(),
          ).publisherSelectionRequired,
          isTrue,
        );
      }
      final invalid = wire()
        ..['publisherEnvelope'] = {
          'schemaVersion': 1,
          'publisherRef': {'type': 'page', 'id': ''},
        };
      expect(read(invalid).publisherSelectionRequired, isTrue);
    },
  );

  test(
    'explicit invalid envelope takes precedence over valid legacy identity',
    () {
      final json = wire()
        ..['publisherEnvelope'] = {
          'schemaVersion': 1,
          'publisherRef': {'type': 'admin', 'id': 'owner'},
        };
      expect(read(json).publisherSelectionRequired, isTrue);
    },
  );

  test(
    'conflicting typed publisher fails closed without rewriting either identity',
    () {
      final json = wire()
        ..['publisherEnvelope'] = {
          'schemaVersion': 1,
          'publisherRef': {'type': 'page', 'id': 'other-page'},
        };
      final restored = read(json);
      expect(restored.publisherSelectionRequired, isTrue);
      expect(restored.eventData!.publisherRef!.id, 'owner');
      expect(restored.publisherRef!.id, 'other-page');
    },
  );

  test(
    'unknown envelope fields and future versions roundtrip without granting rights',
    () {
      for (final raw in <Object>[
        {
          'schemaVersion': 1,
          'extra': {'opaque': true},
          'publisherRef': {'type': 'page', 'id': 'page-A', 'future': 4},
        },
        {
          'schemaVersion': 2,
          'future': true,
          'publisherRef': {'type': 'page', 'id': 'page-A'},
        },
        'unsupported-envelope',
      ]) {
        final json = wire()
          ..['publisherEnvelope'] = raw
          ..['sectionData'] = <String, Object?>{};
        final restored = read(json);
        final output = CreateDraftModel.fromEntity(restored).toJson();
        expect(output['publisherEnvelope'], raw);
        expect(
          restored.publisherSelectionRequired,
          raw is! Map || raw['schemaVersion'] != 1,
        );
      }
    },
  );
}
