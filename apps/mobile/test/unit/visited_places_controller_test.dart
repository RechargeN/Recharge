import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/visit_history_facade.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/visited/application/controllers/visited_places_controller.dart';
import 'package:recharge/features/visited/application/state/visited_places_state.dart';
import 'package:recharge/features/visited/domain/entities/visited_place_entity.dart';
import 'package:recharge/features/visited/domain/repositories/visited_places_repository.dart';
import 'package:recharge/features/visited/domain/usecases/get_visited_places_usecase.dart';

void main() {
  test('place calendar day follows IANA timezone across midnight and DST', () {
    final controller = VisitedPlacesController(
      getVisitedPlacesUseCase: GetVisitedPlacesUseCase(
        _FakeVisitedPlacesRepository(),
      ),
      analyticsService: _NoopAnalyticsService(),
    );
    final facade = VisitHistoryFacade(
      controller: controller,
      timezoneRepository: TimezoneRepositoryImpl.new,
    );
    DiscoverItemEntity place(String zone) => DiscoverItemEntity(
      id: 'place',
      title: '',
      subtitle: '',
      city: '',
      category: '',
      startsAtUtc: DateTime.utc(2026),
      latitude: 0,
      longitude: 0,
      priceAmount: null,
      distanceKm: 0,
      isFree: true,
      objectKind: DiscoverObjectKind.place,
      timezoneId: zone,
    );
    expect(
      facade.todayAtPlace(
        place('Europe/Riga'),
        nowUtc: DateTime.utc(2026, 7, 21, 22),
      ),
      DateTime(2026, 7, 22),
    );
    expect(
      facade.todayAtPlace(
        place('America/Los_Angeles'),
        nowUtc: DateTime.utc(2026, 7, 21, 2),
      ),
      DateTime(2026, 7, 20),
    );
    expect(
      facade.todayAtPlace(
        place('Europe/Riga'),
        nowUtc: DateTime.utc(2026, 10, 25, 1),
      ),
      DateTime(2026, 10, 25),
    );
    expect(() => facade.todayAtPlace(place('')), throwsArgumentError);
    controller.dispose();
  });
  test('loads visits for the requested creator', () async {
    final repository = _FakeVisitedPlacesRepository(
      items: <VisitedPlaceEntity>[_visit()],
    );
    final controller = VisitedPlacesController(
      getVisitedPlacesUseCase: GetVisitedPlacesUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    await controller.ensureLoaded(userId: 'creator-1');

    expect(controller.state.status, VisitedPlacesStatus.ready);
    expect(controller.state.items.single.title, 'Lake walk');
    expect(repository.requestedUserIds, <String>['creator-1']);

    await controller.ensureLoaded(userId: 'creator-1');
    expect(repository.requestedUserIds, <String>['creator-1']);
  });

  test('exposes an empty ready state', () async {
    final controller = VisitedPlacesController(
      getVisitedPlacesUseCase: GetVisitedPlacesUseCase(
        _FakeVisitedPlacesRepository(),
      ),
      analyticsService: _NoopAnalyticsService(),
    );

    await controller.loadVisitedPlaces(userId: 'creator-1');

    expect(controller.state.status, VisitedPlacesStatus.ready);
    expect(controller.state.items, isEmpty);
  });

  test('filters visits by month and day and clears the period', () async {
    final controller = VisitedPlacesController(
      getVisitedPlacesUseCase: GetVisitedPlacesUseCase(
        _FakeVisitedPlacesRepository(
          items: <VisitedPlaceEntity>[
            _visit(),
            _visit(
              id: 'd791dd13-7c8a-4132-bab6-b6a285bd8a22',
              title: 'Art space',
              visitedOn: DateTime(2026, 7, 21),
            ),
            _visit(
              id: 'a138b0b4-c8f8-46e4-990e-9dbe12c03877',
              title: 'June garden',
              visitedOn: DateTime(2026, 6, 8),
            ),
          ],
        ),
      ),
      analyticsService: _NoopAnalyticsService(),
    );
    await controller.loadVisitedPlaces(userId: 'creator-1');

    controller.selectMonth(DateTime(2026, 7));

    expect(controller.state.visibleItems, hasLength(2));
    expect(controller.state.selectedMonth, DateTime(2026, 7));
    expect(controller.state.selectedDay, isNull);

    controller.selectDay(DateTime(2026, 7, 20));

    expect(controller.state.visibleItems.single.title, 'Lake walk');
    expect(controller.state.selectedDay, DateTime(2026, 7, 20));

    controller.selectMonth(DateTime(2026, 6));

    expect(controller.state.visibleItems.single.title, 'June garden');
    expect(controller.state.selectedDay, isNull);

    controller.clearTimeFilter();

    expect(controller.state.visibleItems, hasLength(3));
    expect(controller.state.hasTimeFilter, isFalse);
  });
}

VisitedPlaceEntity _visit({
  String id = '4a3d27ad-8185-4b94-a991-9b36b6f62c16',
  String title = 'Lake walk',
  DateTime? visitedOn,
}) {
  return VisitedPlaceEntity(
    id: id,
    userId: 'creator-1',
    placeId: 'evt_rig_002',
    title: title,
    subtitle: 'Five calm kilometres',
    city: 'Riga',
    category: 'outdoor_nature_walking',
    visitedOn: visitedOn ?? DateTime(2026, 7, 20),
    timezoneId: 'Europe/Riga',
    evidence: VisitEvidence.selfReported,
    recordedAtUtc: DateTime.utc(2026, 7, 20, 12),
  );
}

class _FakeVisitedPlacesRepository implements VisitedPlacesRepository {
  _FakeVisitedPlacesRepository({this.items = const <VisitedPlaceEntity>[]});

  final List<VisitedPlaceEntity> items;
  final List<String> requestedUserIds = <String>[];

  @override
  Future<List<VisitedPlaceEntity>> getVisitedPlaces({
    required String userId,
  }) async {
    requestedUserIds.add(userId);
    return items;
  }

  @override
  Future<VisitedPlaceEntity> recordVisit(VisitedPlaceEntity visit) async {
    return visit;
  }

  @override
  Future<void> removeVisit({
    required String userId,
    required String visitId,
  }) async {}
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
