import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/published_bookable_session_discovery_local_datasource.dart';
import 'package:recharge/features/discover/domain/entities/published_bookable_session_discovery_entity.dart';

void main() {
  test(
    'reopening does not silently renew a stale snapshot or move slots',
    () async {
      DateTime now = DateTime.utc(2026, 9, 7, 10);
      final source = PublishedBookableSessionDiscoveryLocalDataSource(
        clock: () => now,
      );
      const id = PublishedBookableSessionDiscoveryLocalDataSource
          .personalTrainingSessionId;
      final first = await source.getActiveBookableSession(id);
      now = now.add(const Duration(hours: 1));
      final reopened = await source.getActiveBookableSession(id);
      expect(identical(first, reopened), isTrue);
      expect(reopened!.schedule.validUntilUtc.isBefore(now), isTrue);
    },
  );

  test('returns a coherent public fixture against an injected clock', () async {
    final DateTime now = DateTime.utc(2026, 9, 7, 10);
    final PublishedBookableSessionDiscoveryLocalDataSource source =
        PublishedBookableSessionDiscoveryLocalDataSource(clock: () => now);

    final PublishedBookableSessionDiscoveryEntity? value = await source
        .getActiveBookableSession(
          PublishedBookableSessionDiscoveryLocalDataSource
              .personalTrainingSessionId,
        );

    expect(value, isNotNull);
    expect(value!.schedule.generatedAtUtc, now);
    expect(value.schedule.validUntilUtc, now.add(const Duration(minutes: 5)));
    expect(value.schedule.offers, hasLength(2));
    expect(value.schedule.providerAvailabilityUnknown, isTrue);
  });

  test(
    'unknown and moderation-hidden ids share the same null result',
    () async {
      final PublishedBookableSessionDiscoveryLocalDataSource source =
          PublishedBookableSessionDiscoveryLocalDataSource(
            hiddenSessionIds: const <String>{'hidden'},
          );
      expect(await source.getActiveBookableSession('missing'), isNull);
      expect(await source.getActiveBookableSession('hidden'), isNull);
    },
  );

  test('malformed fixture fails closed before reaching presentation', () async {
    final PublishedBookableSessionDiscoveryLocalDataSource source =
        PublishedBookableSessionDiscoveryLocalDataSource(
          fixtureBuilders: <String, BookableSessionFixtureBuilder>{
            'malformed': () => throw ArgumentError('invalid public payload'),
            'future': () => throw const FormatException('future schema'),
          },
        );
    expect(await source.getActiveBookableSession('malformed'), isNull);
    expect(await source.getActiveBookableSession('future'), isNull);
  });
}
