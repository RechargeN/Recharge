import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/published_class_workshop_discovery_local_datasource.dart';
import 'package:recharge/features/discover/domain/entities/published_class_workshop_discovery_entity.dart';
import '../fixtures/class_workshop_details_fixture.dart';

void main() {
  test(
    'demo is explicitly informational and never invents a booking URL or fresh dates',
    () async {
      final source = PublishedClassWorkshopDiscoveryLocalDataSource();
      final value = (await source.getActiveClassWorkshop(
        PublishedClassWorkshopDiscoveryLocalDataSource.demoOfferingId,
      ))!;
      expect(value.title, contains('демо'));
      expect(value.enrollment, isA<ClassWorkshopInformationOnly>());
      expect(value.schedule, isA<ClassWorkshopDatesNotAnnounced>());
    },
  );
  test(
    'unknown, hidden, malformed, future-builder and mismatched id fail closed',
    () async {
      final source = PublishedClassWorkshopDiscoveryLocalDataSource(
        fixtureBuilders: {
          'class-1': () => classWorkshopFixture(),
          'malformed': () => throw ArgumentError('invalid'),
          'future': () => throw const FormatException('unsupported'),
          'wrong': () => classWorkshopFixture(),
        },
        hiddenIds: {'class-1'},
      );
      for (final id in [
        'unknown',
        'class-1',
        'malformed',
        'future',
        'wrong',
        '',
      ]) {
        expect(await source.getActiveClassWorkshop(id), isNull);
      }
    },
  );
  test('announced fixture dates remain stable on repeated reads', () async {
    final source = PublishedClassWorkshopDiscoveryLocalDataSource(
      fixtureBuilders: {'class-1': () => classWorkshopFixture()},
    );
    final a = (await source.getActiveClassWorkshop('class-1'))!;
    final b = (await source.getActiveClassWorkshop('class-1'))!;
    expect(
      (a.schedule as ClassWorkshopAnnouncedSchedule)
          .occurrences
          .first
          .startAtUtc,
      (b.schedule as ClassWorkshopAnnouncedSchedule)
          .occurrences
          .first
          .startAtUtc,
    );
  });
}
