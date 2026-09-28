import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/bookable_session_schedule_evaluation.dart';
import 'package:recharge/features/discover/domain/entities/published_bookable_session_discovery_entity.dart';
import 'package:recharge/features/discover/domain/usecases/evaluate_bookable_session_schedule_usecase.dart';

void main() {
  const EvaluateBookableSessionScheduleUseCase useCase =
      EvaluateBookableSessionScheduleUseCase();

  PublishedBookableSessionOffer offer(String key, DateTime start) {
    return PublishedBookableSessionOffer(
      slotKey: key,
      startAtUtc: start,
      endAtUtc: start.add(const Duration(hours: 1)),
      timezoneId: 'Europe/Riga',
    );
  }

  PublishedBookableSessionScheduleSnapshot snapshot({
    required DateTime generated,
    required DateTime validUntil,
    List<PublishedBookableSessionOffer> offers =
        const <PublishedBookableSessionOffer>[],
  }) {
    return PublishedBookableSessionScheduleSnapshot(
      scheduleRevision: 1,
      generatedAtUtc: generated,
      validUntilUtc: validUntil,
      offers: offers,
    );
  }

  test('fresh snapshot exposes only future declared offers', () {
    final DateTime now = DateTime.utc(2026, 9, 7, 10, 30);
    final BookableSessionScheduleEvaluation result = useCase(
      snapshot: snapshot(
        generated: DateTime.utc(2026, 9, 7, 10),
        validUntil: DateTime.utc(2026, 9, 7, 11),
        offers: <PublishedBookableSessionOffer>[
          offer('past', DateTime.utc(2026, 9, 7, 10)),
          offer('future', DateTime.utc(2026, 9, 7, 12)),
        ],
      ),
      nowUtc: now,
    );
    expect(result.state, BookableSessionScheduleState.freshWithOffers);
    expect(result.visibleOffers.map((item) => item.slotKey), <String>[
      'future',
    ]);
  });

  test(
    'fresh snapshot without future offers remains a published empty state',
    () {
      final BookableSessionScheduleEvaluation result = useCase(
        snapshot: snapshot(
          generated: DateTime.utc(2026, 9, 7, 10),
          validUntil: DateTime.utc(2026, 9, 7, 11),
        ),
        nowUtc: DateTime.utc(2026, 9, 7, 10, 30),
      );
      expect(result.state, BookableSessionScheduleState.freshEmpty);
      expect(result.visibleOffers, isEmpty);
    },
  );

  test('expired and future-generated snapshots are stale and hide slots', () {
    final PublishedBookableSessionScheduleSnapshot value = snapshot(
      generated: DateTime.utc(2026, 9, 7, 10),
      validUntil: DateTime.utc(2026, 9, 7, 11),
      offers: <PublishedBookableSessionOffer>[
        offer('future', DateTime.utc(2026, 9, 8, 12)),
      ],
    );
    expect(
      useCase(snapshot: value, nowUtc: DateTime.utc(2026, 9, 7, 11)).state,
      BookableSessionScheduleState.stale,
    );
    final BookableSessionScheduleEvaluation beforeGenerated = useCase(
      snapshot: value,
      nowUtc: DateTime.utc(2026, 9, 7, 9, 59),
    );
    expect(beforeGenerated.state, BookableSessionScheduleState.stale);
    expect(beforeGenerated.visibleOffers, isEmpty);
  });

  test('requires an injected UTC clock value', () {
    expect(
      () => useCase(
        snapshot: snapshot(
          generated: DateTime.utc(2026, 9, 7, 10),
          validUntil: DateTime.utc(2026, 9, 7, 11),
        ),
        nowUtc: DateTime(2026, 9, 7, 10, 30),
      ),
      throwsArgumentError,
    );
  });
}
