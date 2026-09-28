import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';

void main() {
  PublishedFindPeopleDiscoveryEntity entity({
    PublishedFindPeopleScheduleMode scheduleMode =
        PublishedFindPeopleScheduleMode.single,
    List<PublishedFindPeopleTimeOption>? timeOptions,
    PublishedFindPeopleCostType costType = PublishedFindPeopleCostType.free,
    double? amount,
    String currency = '',
  }) {
    return PublishedFindPeopleDiscoveryEntity(
      requestId: 'fp_1',
      occurrenceId: 'occ_1',
      publisherId: 'user_1',
      publisherType: 'user',
      publisherName: 'Anna',
      title: 'Morning run',
      category: 'sport_fitness',
      scheduleMode: scheduleMode,
      timeOptions:
          timeOptions ??
          <PublishedFindPeopleTimeOption>[
            PublishedFindPeopleTimeOption(
              id: 'slot_1',
              startAtUtc: DateTime.utc(2026, 9, 12, 5),
              endAtUtc: DateTime.utc(2026, 9, 12, 6),
              kind: PublishedFindPeopleTimeOptionKind.confirmed,
            ),
          ],
      timezoneId: 'Europe/Riga',
      targetGroupSize: 6,
      recruitmentStatus: PublishedFindPeopleRecruitmentStatus.open,
      costType: costType,
      expectedSpendAmount: amount,
      currencyCode: currency,
      publicLocation: PublishedFindPeoplePointLocation(
        meetingMode: PublishedFindPeopleMeetingMode.inPerson,
        areaLabel: 'Central Riga',
        latitude: 56.95,
        longitude: 24.1,
      ),
      publishedAtUtc: DateTime.utc(2026, 9, 1),
    );
  }

  test('accepts a valid occurrence-scoped public projection', () {
    expect(entity().requestId, 'fp_1');
  });

  test('single rejects a candidate time option', () {
    expect(
      () => entity(
        timeOptions: <PublishedFindPeopleTimeOption>[
          PublishedFindPeopleTimeOption(
            id: 'candidate',
            startAtUtc: DateTime.utc(2026, 9, 12, 5),
            endAtUtc: DateTime.utc(2026, 9, 12, 6),
            kind: PublishedFindPeopleTimeOptionKind.candidate,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('time poll requires at least two candidate options', () {
    expect(
      () => entity(
        scheduleMode: PublishedFindPeopleScheduleMode.timePoll,
        timeOptions: <PublishedFindPeopleTimeOption>[
          PublishedFindPeopleTimeOption(
            id: 'only',
            startAtUtc: DateTime.utc(2026, 9, 12, 5),
            endAtUtc: DateTime.utc(2026, 9, 12, 6),
            kind: PublishedFindPeopleTimeOptionKind.candidate,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('unknown cost cannot silently carry an amount', () {
    expect(
      () => entity(costType: PublishedFindPeopleCostType.unknown, amount: 10),
      throwsArgumentError,
    );
  });

  test('online and hidden variants cannot expose point geometry', () {
    const PublishedFindPeoplePublicLocation online =
        PublishedFindPeopleOnlineLocation(providerLabel: 'Meet');
    final PublishedFindPeoplePublicLocation hidden =
        PublishedFindPeopleHiddenLocation(
          meetingMode: PublishedFindPeopleMeetingMode.hybrid,
          safeAreaLabel: 'Riga',
        );
    expect(online, isNot(isA<PublishedFindPeoplePointLocation>()));
    expect(hidden, isNot(isA<PublishedFindPeoplePointLocation>()));
  });
}
