import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/product_analytics/product_analytics_contract.dart';
import 'package:recharge/core/product_analytics/product_analytics_queue.dart';
import 'package:recharge/core/product_analytics/product_analytics_recorder.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/favorites/application/controllers/favorites_controller.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:recharge/features/favorites/domain/usecases/add_favorite_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:recharge/features/favorites/domain/usecases/remove_favorite_usecase.dart';

import 'product_analytics_test_support.dart';

/// L3 client path (ANALYTICS_L3_PRODUCT_ANALYTICS_AMENDMENT.md §12): producer →
/// validation → per-account bounded queue → local sink, with a synthetic
/// policy and an in-process sink. No network, SDK or persistent file is used.
void main() {
  late SyntheticPolicySource policy;
  late CaptureSink sink;
  late InMemoryProductAnalyticsQueueStore store;
  late DateTime now;

  ProductAnalyticsRecorder recorder({
    Duration sendTimeout = const Duration(seconds: 10),
    String Function()? ids,
    ProductAnalyticsQueueStore? withStore,
  }) => ProductAnalyticsRecorder(
    policy: policy,
    sink: sink,
    store: withStore ?? store,
    clock: () => now,
    newEventId: ids ?? sequentialEventIds(),
    sendTimeout: sendTimeout,
  );

  setUp(() {
    policy = SyntheticPolicySource();
    sink = CaptureSink();
    store = InMemoryProductAnalyticsQueueStore();
    now = DateTime.utc(2026, 10, 25, 9, 41, 17);
  });

  const DetailsOpened opened = DetailsOpened(ProductAnalyticsObjectKind.route);

  group('PA-T01 producer → validation → queue → sink', () {
    test('a Favorites add reaches the sink as one allowlisted event', () async {
      final ProductAnalyticsRecorder r = recorder()..bindAccount('user-a');
      final FavoritesController controller = _favorites(r);
      await controller.addFavorite(
        _favorite('evt_1', 'findPeople'),
        sourceScreen: 'discover_map',
      );
      await r.flush();
      expect(sink.batches, hasLength(1));
      final Map<String, Object?> batch = sink.batches.single;
      expect(isValidProductAnalyticsBatch(batch), isTrue);
      final Map<String, Object?> event = eventsOf(batch).single;
      expect(isValidProductAnalyticsEnvelope(event), isTrue);
      expect(event['eventName'], 'favorite_added');
      expect(event['fields'], <String, String>{
        'object_kind': 'find_people',
        'entry_surface': 'map',
      });
      // Rounded down to the hour; nothing about the account or the object.
      expect(event['occurredAtUtc'], '2026-10-25T09:00:00.000Z');
      final String text = jsonEncode(batch);
      for (final String forbidden in <String>['user-a', 'evt_1', 'Synthetic']) {
        expect(text.contains(forbidden), isFalse, reason: forbidden);
      }
      expect(allQueued(store), isEmpty);
    });

    test(
      'a legacy quick_plan or unknown object type is not reported',
      () async {
        final ProductAnalyticsRecorder r = recorder()..bindAccount('user-a');
        final FavoritesController controller = _favorites(r);
        await controller.addFavorite(
          _favorite('qp_1', 'quickPlan'),
          sourceScreen: 'quick_plan',
        );
        await controller.addFavorite(
          _favorite('x_1', null),
          sourceScreen: 'favorites',
        );
        expect(allQueued(store), isEmpty);
      },
    );
  });

  group('PA-T02 invalid input never reaches the queue', () {
    test(
      'a malformed event ID or policy revision is dropped before queueing',
      () {
        recorder(ids: () => 'L3SYNTH-not-a-uuid')
          ..bindAccount('user-a')
          ..record(opened);
        policy.policy = syntheticPolicy(revision: 'L3SYNTH Policy With Spaces');
        final ProductAnalyticsRecorder r = recorder()..bindAccount('user-a');
        r.record(opened);
        expect(allQueued(store), isEmpty);
        expect(r.drops[ProductAnalyticsDropReason.invalid], 1);
      },
    );

    test('the queue holds only allowlisted envelope keys', () {
      recorder()
        ..bindAccount('user-a')
        ..record(opened)
        ..record(
          const CreatePublishFinished(
            ProductAnalyticsObjectKind.event,
            ProductAnalyticsPublishOutcome.denied,
          ),
        );
      for (final ProductAnalyticsQueuedEvent item in allQueued(store)) {
        expect(item.envelope.keys.toSet(), <String>{
          'eventId',
          'eventName',
          'eventVersion',
          'occurredAtUtc',
          'policyRevision',
          'fields',
        });
        expect(isValidProductAnalyticsEnvelope(item.envelope), isTrue);
      }
    });
  });

  group('PA-T03 disable, opt-out, consent change, restart, expiry', () {
    test('the production composition collects nothing', () async {
      final ProductAnalyticsRecorder r = ProductAnalyticsRecorder.disabled()
        ..bindAccount('user-a')
        ..record(opened);
      await r.flush();
      expect(r.drops[ProductAnalyticsDropReason.noPolicy], 1);
    });

    test('opt-out deletes the buffered events and stops collection', () async {
      final ProductAnalyticsRecorder r = recorder()
        ..bindAccount('user-a')
        ..record(opened)
        ..record(opened);
      policy.policy = syntheticPolicy(allowed: false);
      r.record(opened);
      await r.flush();
      expect(allQueued(store), isEmpty);
      expect(sink.batches, isEmpty);
      expect(r.drops[ProductAnalyticsDropReason.consentWithdrawn], 3);
    });

    test(
      'consent withdrawn while a retry is in flight: nothing is kept',
      () async {
        final Completer<ProductAnalyticsSendResult> pending =
            Completer<ProductAnalyticsSendResult>();
        sink.answer = (_) => pending.future;
        final ProductAnalyticsRecorder r = recorder()
          ..bindAccount('user-a')
          ..record(opened);
        final Future<void> flushing = r.flush();
        policy.policy = syntheticPolicy(allowed: false);
        pending.completeError(TimeoutException('lost'));
        await flushing;
        expect(allQueued(store), isEmpty);
      },
    );

    test(
      'after a restart the same account resends the same event ID',
      () async {
        sink.answer = (_) => throw StateError('sink unavailable');
        recorder()
          ..bindAccount('user-a')
          ..record(opened);
        await recorder().flush(); // unbound instance: sends nothing
        final ProductAnalyticsRecorder first = recorder()
          ..bindAccount('user-a');
        await first.flush();
        final String sentId =
            eventsOf(sink.batches.single).single['eventId']! as String;
        // Restart: a new recorder over the same store, same account.
        sink.answer = null;
        final ProductAnalyticsRecorder restarted = recorder()
          ..bindAccount('user-a');
        await restarted.flush();
        expect(eventsOf(sink.batches.last).single['eventId'], sentId);
        expect(allQueued(store), isEmpty);
      },
    );

    test(
      'a changed policy revision or event list drops older events unsent',
      () async {
        final ProductAnalyticsRecorder r = recorder()
          ..bindAccount('user-a')
          ..record(opened)
          ..record(
            const FavoriteAdded(
              ProductAnalyticsObjectKind.place,
              ProductAnalyticsEntrySurface.details,
            ),
          );
        policy.policy = syntheticPolicy(revision: 'synthetic-l3-policy-2');
        await r.flush();
        expect(sink.batches, isEmpty);
        expect(allQueued(store), isEmpty);
        expect(r.drops[ProductAnalyticsDropReason.notAllowed], 2);
      },
    );

    test('events older than the queue age leave the queue unsent', () async {
      final ProductAnalyticsRecorder r = recorder()
        ..bindAccount('user-a')
        ..record(opened);
      now = now.add(const Duration(hours: 24));
      await r.flush();
      expect(sink.batches, isEmpty);
      expect(r.drops[ProductAnalyticsDropReason.expired], 1);
    });
  });

  group('PA-T04 logout and another account', () {
    test(
      'binding another account deletes the previous queue before any send',
      () async {
        final ProductAnalyticsRecorder r = recorder()
          ..bindAccount('user-a')
          ..record(opened)
          ..record(opened)
          ..bindAccount('user-b')
          ..record(
            const FavoriteAdded(
              ProductAnalyticsObjectKind.event,
              ProductAnalyticsEntrySurface.planner,
            ),
          );
        await r.flush();
        expect(
          eventsOf(sink.batches.single).single['eventName'],
          'favorite_added',
        );
        expect(r.drops[ProductAnalyticsDropReason.accountChanged], 2);
        r
          ..record(opened)
          ..bindAccount(null);
        expect(allQueued(store), isEmpty);
        r
          ..record(opened)
          ..bindAccount('user-a');
        await r.flush();
        expect(sink.batches, hasLength(1));
        expect(r.drops[ProductAnalyticsDropReason.noAccount], 1);
      },
    );

    test(
      'an account switch during an in-flight send never restores the old queue',
      () async {
        final Completer<ProductAnalyticsSendResult> pending =
            Completer<ProductAnalyticsSendResult>();
        sink.answer = (_) => pending.future;
        final ProductAnalyticsRecorder r = recorder()
          ..bindAccount('user-a')
          ..record(opened);
        final Future<void> flushing = r.flush();
        r
          ..bindAccount('user-b')
          ..record(const DetailsOpened(ProductAnalyticsObjectKind.collection));
        pending.completeError(StateError('outcome unknown'));
        await flushing;
        final List<ProductAnalyticsQueuedEvent> left = allQueued(store);
        expect(left, hasLength(1));
        expect(left.single.envelope['fields'], <String, String>{
          'object_kind': 'collection',
        });
        expect(left.single.attempts, 0);
      },
    );

    test(
      'a restart with another account deletes the first account queue',
      () async {
        recorder()
          ..bindAccount('user-a')
          ..record(opened);
        final ProductAnalyticsRecorder restarted = recorder()
          ..bindAccount('user-b');
        await restarted.flush();
        expect(sink.batches, isEmpty);
        expect(allQueued(store), isEmpty);
      },
    );
  });

  group('PA-T05 lost responses, duplicates and retries', () {
    test(
      'an unknown outcome keeps the event; a retry sends the same ID once more',
      () async {
        int calls = 0;
        sink.answer = (Map<String, Object?> batch) {
          calls += 1;
          if (calls == 1) throw TimeoutException('response lost');
          return ProductAnalyticsDelivered(
            <String, ProductAnalyticsDisposition>{
              for (final Map<String, Object?> e in eventsOf(batch))
                e['eventId']! as String: ProductAnalyticsDisposition.duplicate,
            },
          );
        };
        final ProductAnalyticsRecorder r = recorder()
          ..bindAccount('user-a')
          ..record(opened);
        await r.flush();
        expect(allQueued(store).single.attempts, 1);
        await r.flush();
        expect(
          sink.batches.map((b) => eventsOf(b).single['eventId']).toSet(),
          hasLength(1),
        );
        expect(allQueued(store), isEmpty);
      },
    );

    test(
      'a missing disposition is unknown, a rejection is final, attempts are bounded',
      () async {
        sink.answer = (Map<String, Object?> batch) =>
            ProductAnalyticsDelivered(<String, ProductAnalyticsDisposition>{
              eventsOf(batch).first['eventId']! as String:
                  ProductAnalyticsDisposition.rejectedSchema,
            });
        final ProductAnalyticsRecorder r = recorder()
          ..bindAccount('user-a')
          ..record(opened)
          ..record(opened);
        await r.flush();
        expect(r.drops[ProductAnalyticsDropReason.rejected], 1);
        expect(allQueued(store).single.attempts, 1);
        sink.answer = (_) => throw StateError('down');
        for (int i = 0; i < ProductAnalyticsLimits.maxAttempts; i += 1) {
          await r.flush();
        }
        expect(allQueued(store), isEmpty);
        expect(r.drops[ProductAnalyticsDropReason.attemptsExhausted], 1);
        expect(
          sink.batches.length,
          ProductAnalyticsLimits.maxAttempts,
          reason: 'one first send plus four retries',
        );
      },
    );

    test('a refused batch is dropped, never retried', () async {
      sink.answer = (_) => const ProductAnalyticsRefused('consent_absent');
      final ProductAnalyticsRecorder r = recorder()
        ..bindAccount('user-a')
        ..record(opened);
      await r.flush();
      await r.flush();
      expect(sink.batches, hasLength(1));
      expect(allQueued(store), isEmpty);
    });
  });

  group('PA-T06 bounds and failures never break the user flow', () {
    test('overflow drops new events; a batch carries at most 20', () async {
      final ProductAnalyticsRecorder r = recorder()..bindAccount('user-a');
      for (int i = 0; i < ProductAnalyticsLimits.queueMaxEvents + 3; i += 1) {
        r.record(opened);
      }
      expect(
        allQueued(store),
        hasLength(ProductAnalyticsLimits.queueMaxEvents),
      );
      expect(r.drops[ProductAnalyticsDropReason.overflow], 3);
      await r.flush();
      expect(
        eventsOf(sink.batches.single),
        hasLength(ProductAnalyticsLimits.batchMaxEvents),
      );
      final int queuedBytes = allQueued(
        store,
      ).fold<int>(0, (int sum, ProductAnalyticsQueuedEvent e) => sum + e.bytes);
      expect(queuedBytes <= ProductAnalyticsLimits.queueMaxBytes, isTrue);
    });

    test('a sink that never answers times out as unknown', () async {
      sink.answer = (_) => Completer<ProductAnalyticsSendResult>().future;
      final ProductAnalyticsRecorder r =
          recorder(sendTimeout: const Duration(milliseconds: 20))
            ..bindAccount('user-a')
            ..record(opened);
      await r.flush();
      expect(allQueued(store).single.attempts, 1);
    });

    test(
      'a broken store and a broken sink leave the Favorites flow intact',
      () async {
        sink.answer = (_) => throw StateError('sink down');
        final ProductAnalyticsRecorder r = recorder(withStore: ThrowingStore())
          ..bindAccount('user-a');
        final FavoritesController controller = _favorites(r);
        await controller.addFavorite(
          _favorite('evt_9', 'event'),
          sourceScreen: 'discover_details',
        );
        await r.flush();
        expect(controller.isFavorite('evt_9'), isTrue);
        expect(
          r.drops[ProductAnalyticsDropReason.storeFailure],
          greaterThan(0),
        );
      },
    );
  });
}

FavoritesController _favorites(ProductAnalyticsRecorder recorder) {
  final _MemoryFavorites repository = _MemoryFavorites();
  return FavoritesController(
    getFavoritesUseCase: GetFavoritesUseCase(repository),
    addFavoriteUseCase: AddFavoriteUseCase(repository),
    removeFavoriteUseCase: RemoveFavoriteUseCase(repository),
    analyticsService: _NoopAnalytics(),
    productAnalytics: recorder,
  );
}

FavoriteItemEntity _favorite(String id, String? objectType) =>
    FavoriteItemEntity(
      id: id,
      objectType: objectType,
      title: 'Synthetic $id',
      subtitle: 'Synthetic',
      city: 'Riga',
      category: 'wellness',
      startsAtUtc: null,
      distanceKm: 1.0,
      priceAmount: null,
      isFree: true,
      savedAtUtc: DateTime.utc(2026, 10, 25),
      targetRoute: '/discover/details/$id',
    );

class _NoopAnalytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _MemoryFavorites implements FavoritesRepository {
  final List<FavoriteItemEntity> _items = <FavoriteItemEntity>[];

  @override
  Future<void> addFavorite(FavoriteItemEntity item) async {
    _items
      ..removeWhere((FavoriteItemEntity e) => e.id == item.id)
      ..add(item);
  }

  @override
  Future<List<FavoriteItemEntity>> getFavorites() async =>
      List<FavoriteItemEntity>.of(_items);

  @override
  Future<void> removeFavorite(String itemId) async {
    _items.removeWhere((FavoriteItemEntity e) => e.id == itemId);
  }
}
