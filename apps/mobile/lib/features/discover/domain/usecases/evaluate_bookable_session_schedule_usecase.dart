import '../entities/bookable_session_schedule_evaluation.dart';
import '../entities/published_bookable_session_discovery_entity.dart';

/// Resolves cache freshness and future public offers without claiming that
/// the provider calendar has confirmed availability (`DTL-SES-01` §2.2).
class EvaluateBookableSessionScheduleUseCase {
  const EvaluateBookableSessionScheduleUseCase();

  BookableSessionScheduleEvaluation call({
    required PublishedBookableSessionScheduleSnapshot snapshot,
    required DateTime nowUtc,
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'must use UTC');
    }
    final bool isFresh =
        !nowUtc.isBefore(snapshot.generatedAtUtc) &&
        nowUtc.isBefore(snapshot.validUntilUtc);
    if (!isFresh) {
      return BookableSessionScheduleEvaluation(
        state: BookableSessionScheduleState.stale,
        visibleOffers: const <PublishedBookableSessionOffer>[],
      );
    }

    final List<PublishedBookableSessionOffer> futureOffers = snapshot.offers
        .where((offer) => offer.startAtUtc.isAfter(nowUtc))
        .toList(growable: false);
    return BookableSessionScheduleEvaluation(
      state: futureOffers.isEmpty
          ? BookableSessionScheduleState.freshEmpty
          : BookableSessionScheduleState.freshWithOffers,
      visibleOffers: futureOffers,
    );
  }
}
