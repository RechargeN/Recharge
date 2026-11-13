import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/published_class_workshop_discovery_entity.dart';
import '../fixtures/class_workshop_details_fixture.dart';

void main() {
  test(
    'one coherent context supports single, fixed series, and unannounced dates',
    () {
      expect(
        classWorkshopFixture().schedule,
        isA<ClassWorkshopAnnouncedSchedule>(),
      );
      final series = ClassWorkshopAnnouncedSchedule([
        classOccurrence(),
        classOccurrence(
          id: 'occ-2',
          start: DateTime.utc(2026, 9, 13, 10),
          end: DateTime.utc(2026, 9, 13, 12),
        ),
      ]);
      expect(
        classWorkshopFixture(
          contextKind: ClassWorkshopContextKind.fixedSeries,
          schedule: series,
        ).displayContextId,
        'run-1',
      );
      expect(
        classWorkshopFixture(
          schedule: const ClassWorkshopDatesNotAnnounced(),
        ).schedule,
        isA<ClassWorkshopDatesNotAnnounced>(),
      );
      expect(
        () => classWorkshopFixture(
          contextKind: ClassWorkshopContextKind.fixedSeries,
        ),
        throwsArgumentError,
      );
      expect(() => classWorkshopFixture(schedule: series), throwsArgumentError);
    },
  );
  test('public identity and numeric facts reject malformed values', () {
    for (final build in <Object Function()>[
      () => classWorkshopFixture(id: ''),
      () => classWorkshopFixture(id: 'loc_1'),
      () => classWorkshopFixture(publisherId: 'loc_p'),
      () => classWorkshopFixture(contextId: ' '),
      () => classWorkshopFixture(revision: 0),
      () => classWorkshopFixture(title: ''),
      () => classWorkshopFixture(groupLimit: 0),
      () => classWorkshopFixture(durationMinutes: -1),
      () => classWorkshopFixture(publishedAtUtc: DateTime(2026)),
    ]) {
      expect(build, throwsArgumentError);
    }
  });
  test(
    'price unknown/free/fixed are distinct and full-series facts need a series',
    () {
      expect(
        classWorkshopFixture(
          price: const ClassWorkshopPriceNotProvided(),
        ).price,
        isA<ClassWorkshopPriceNotProvided>(),
      );
      expect(
        classWorkshopFixture(price: const ClassWorkshopPriceFree()).price,
        isA<ClassWorkshopPriceFree>(),
      );
      expect(
        () => ClassWorkshopPriceFixed(
          amountMinor: 0,
          currencyCode: 'EUR',
          minorUnitDigits: 2,
          scope: ClassWorkshopPriceScope.perPersonPerClass,
        ),
        throwsArgumentError,
      );
      expect(
        () => ClassWorkshopPriceFixed(
          amountMinor: 1,
          currencyCode: 'eur',
          minorUnitDigits: 2,
          scope: ClassWorkshopPriceScope.perPersonPerClass,
        ),
        throwsArgumentError,
      );
      expect(
        () => classWorkshopFixture(
          price: ClassWorkshopPriceFixed(
            amountMinor: 100,
            currencyCode: 'EUR',
            minorUnitDigits: 2,
            scope: ClassWorkshopPriceScope.perPersonFullSeries,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => classWorkshopFixture(
          durationScope: ClassWorkshopDurationScope.wholeSeries,
        ),
        throwsArgumentError,
      );
    },
  );
  test('only safe external HTTPS is accepted; info-only carries no URI', () {
    for (final uri in [
      'http://site.test',
      'javascript:alert(1)',
      '/relative',
      'https://user:pass@site.test',
      'https:///',
    ]) {
      expect(
        () => ClassWorkshopExternalEnrollment(Uri.parse(uri)),
        throwsArgumentError,
      );
    }
    for (final reason in ClassWorkshopInformationReason.values) {
      expect(
        classWorkshopFixture(
          enrollment: ClassWorkshopInformationOnly(reason),
        ).enrollment,
        isA<ClassWorkshopInformationOnly>(),
      );
    }
  });
  test(
    'occurrences reject non-UTC, invalid ordering, duplication, overlap and timezone mixing',
    () {
      expect(() => classOccurrence(start: DateTime(2026)), throwsArgumentError);
      expect(
        () => classOccurrence(end: DateTime.utc(2026, 9, 12, 9)),
        throwsArgumentError,
      );
      expect(() => ClassWorkshopAnnouncedSchedule([]), throwsArgumentError);
      expect(
        () => ClassWorkshopAnnouncedSchedule([
          classOccurrence(),
          classOccurrence(),
        ]),
        throwsArgumentError,
      );
      expect(
        () => ClassWorkshopAnnouncedSchedule([
          classOccurrence(),
          classOccurrence(id: 'two'),
        ]),
        throwsArgumentError,
      );
      expect(
        () => ClassWorkshopAnnouncedSchedule([
          classOccurrence(),
          classOccurrence(
            id: 'two',
            start: DateTime.utc(2026, 9, 13, 10),
            end: DateTime.utc(2026, 9, 13, 12),
            timezone: 'UTC',
          ),
        ]),
        throwsArgumentError,
      );
    },
  );
  test('location variants cannot expose online or hidden coordinates', () {
    expect(
      classWorkshopFixture(
        location: const ClassWorkshopOnlineLocation(),
      ).publicLocation.delivery,
      ClassWorkshopDelivery.onlineLive,
    );
    expect(
      classWorkshopFixture(
        location: ClassWorkshopHiddenLocation(
          delivery: ClassWorkshopDelivery.hybrid,
          safeAreaLabel: 'Рига',
        ),
      ).publicLocation,
      isA<ClassWorkshopHiddenLocation>(),
    );
    expect(
      () => ClassWorkshopHiddenLocation(
        delivery: ClassWorkshopDelivery.onlineLive,
        safeAreaLabel: 'Рига',
      ),
      throwsArgumentError,
    );
    for (final lat in [double.nan, double.infinity, 91.0]) {
      expect(
        () => ClassWorkshopPointLocation(
          delivery: ClassWorkshopDelivery.offline,
          venueName: 'Studio',
          areaLabel: 'Riga',
          latitude: lat,
          longitude: 24,
          precisionMeters: 50,
        ),
        throwsArgumentError,
      );
    }
  });
  test('publisher and instructor identities stay distinct', () {
    final value = classWorkshopFixture();
    expect(
      (value.instructor as ClassWorkshopGuestInstructor).profileRef,
      isNull,
    );
    expect(() => ClassWorkshopGuestInstructor(name: ' '), throwsArgumentError);
    expect(
      classWorkshopFixture(
        instructor: const ClassWorkshopInstructorSameAsPublisher(),
      ).instructor,
      isA<ClassWorkshopInstructorSameAsPublisher>(),
    );
  });
  test(
    'collections copy inputs, reject mutation and remove empty optional rows',
    () {
      final materials = ['Clay', ' '];
      final rows = [classOccurrence()];
      final value = classWorkshopFixture(
        materials: materials,
        schedule: ClassWorkshopAnnouncedSchedule(rows),
      );
      materials.clear();
      rows.clear();
      expect(value.includedMaterials, ['Clay']);
      expect(() => value.includedMaterials.add('x'), throwsUnsupportedError);
      expect(
        (value.schedule as ClassWorkshopAnnouncedSchedule).occurrences,
        hasLength(1),
      );
      expect(
        () => (value.schedule as ClassWorkshopAnnouncedSchedule).occurrences
            .clear(),
        throwsUnsupportedError,
      );
    },
  );
}
