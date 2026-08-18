import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/discover_remote_datasource.dart';
import 'package:recharge/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';

void main() {
  test('an activity mock item is free, evergreen and duration-filterable', () async {
    final DiscoverRepositoryImpl repository = DiscoverRepositoryImpl(
      remoteDataSource: MockDiscoverRemoteDataSource(),
    );
    final DiscoverQuery query = DiscoverQuery.defaults(
      marketCityId: 'riga',
      centerLat: 56.9496,
      centerLng: 24.1052,
      nowUtc: DateTime.utc(2026, 7, 25),
    ).copyWith(availableDurationMinutes: 60, freeOnly: true);

    final List<DiscoverItemEntity> results = await repository.getFeed(query);
    final DiscoverItemEntity activityItem = results.firstWhere(
      (DiscoverItemEntity item) => item.objectKind == DiscoverObjectKind.activity,
    );

    expect(activityItem.isFree, isTrue);
    expect(activityItem.priceAmount, 0);
    expect(activityItem.availabilityKind, AvailabilityKind.none);
    expect(activityItem.durationMinutes, isNotNull);
  });

  test('a long activity is excluded when availableDurationMinutes is too short', () async {
    final DiscoverRepositoryImpl repository = DiscoverRepositoryImpl(
      remoteDataSource: MockDiscoverRemoteDataSource(),
    );
    final DiscoverQuery query = DiscoverQuery.defaults(
      marketCityId: 'riga',
      centerLat: 56.9496,
      centerLng: 24.1052,
      nowUtc: DateTime.utc(2026, 7, 25),
    ).copyWith(availableDurationMinutes: 10);

    final List<DiscoverItemEntity> results = await repository.getFeed(query);

    // The mock activity fixture has duration_minutes: 45, which exceeds a
    // 10-minute availability window, so it must be filtered out — same
    // duration-filter code path event/place items already use.
    expect(
      results.any(
        (DiscoverItemEntity item) => item.id == 'mock-activity-coffee-walk',
      ),
      isFalse,
    );
  });
}
