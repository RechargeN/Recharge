import 'dart:async';
import 'package:recharge/features/create/data/repositories/catalog_activity_place_link_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/activity_place_link_controller.dart';
import 'package:recharge/features/create/domain/repositories/activity_place_link_repository.dart';

const place = ActivityPlaceCandidate(
  id: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
  title: 'Park',
  publishedRevisionId: '01ARZ3NDEKTSV4RRFFQ69G5FAW',
  pointerRevision: 1,
);

class Repository implements ActivityPlaceLinkRepository {
  ActivityPlaceResolution result = const ActivityPlaceResolution(
    'eligible',
    place,
  );
  Completer<ActivityPlaceResolution>? pending;
  bool offline = false;
  @override
  Future<ActivityPlaceResolution> resolve(String id) async =>
      pending == null ? result : pending!.future;
  @override
  Future<ActivityPlacePage> candidates(String text, {String? after}) async =>
      ActivityPlacePage(available: !offline, items: offline ? [] : [place]);
}

void main() {
  test(
    'Catalog wire adapter has no disabled/offline/unknown-version fallback',
    () async {
      int calls = 0;
      Map<String, Object?> response = {
        'schemaVersion': 1,
        'kind': 'succeeded',
        'placeLink': {
          'status': 'eligible',
          'place': {
            'contentId': place.id,
            'publishedRevisionId': place.publishedRevisionId,
            'pointerRevision': 1,
            'marketId': 'LV',
            'title': place.title,
          },
        },
      };
      Future<Map<String, Object?>> query(Map<String, Object?> envelope) async {
        calls++;
        expect(envelope['queryType'], 'placeLink');
        return response;
      }

      final disabled = CatalogActivityPlaceLinkRepository(
        query: query,
        marketId: 'LV',
      );
      expect((await disabled.resolve(place.id)).status, 'unavailable');
      expect(calls, 0);
      final enabled = CatalogActivityPlaceLinkRepository(
        query: query,
        marketId: 'LV',
        enabled: true,
      );
      expect((await enabled.resolve(place.id)).place!.id, place.id);
      response = {'schemaVersion': 2, 'kind': 'succeeded'};
      expect((await enabled.resolve(place.id)).status, 'unavailable');
      response = {
        'schemaVersion': 1,
        'kind': 'succeeded',
        'placeLink': {
          'status': 'eligible',
          'place': {'contentId': 'wrong'},
        },
      };
      expect((await enabled.resolve(place.id)).status, 'unavailable');
      final offline = CatalogActivityPlaceLinkRepository(
        query: (_) async => throw StateError('private'),
        marketId: 'LV',
        enabled: true,
      );
      expect((await offline.resolve(place.id)).status, 'unavailable');
    },
  );
  test(
    'picker resolves current eligibility and clears explicitly; outage is visible',
    () async {
      final repository = Repository();
      final controller = ActivityPlaceLinkController(repository);
      addTearDown(controller.dispose);
      await controller.search('Park');
      expect(controller.items.single.id, place.id);
      expect(await controller.resolve(place.id), place.id);
      controller.clear();
      expect(controller.selected, isNull);
      for (final status in ['unknown', 'forbidden', 'unavailable']) {
        repository.result = ActivityPlaceResolution(status);
        expect(await controller.resolve(place.id), isNull);
        expect(controller.status, status);
      }
      repository.offline = true;
      await controller.search('Park');
      expect(controller.status, 'unavailable');
      expect(controller.items, isEmpty);
    },
  );
  test(
    'late resolution cannot restore a cleared selection or notify disposed picker',
    () async {
      final repository = Repository()
        ..pending = Completer<ActivityPlaceResolution>();
      final controller = ActivityPlaceLinkController(repository);
      final request = controller.resolve(place.id);
      controller.clear();
      repository.pending!.complete(
        const ActivityPlaceResolution('eligible', place),
      );
      expect(await request, isNull);
      expect(controller.selected, isNull);
      controller.dispose();
      expect(await controller.resolve(place.id), isNull);
    },
  );
}
