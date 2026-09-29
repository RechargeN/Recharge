import 'published_bookable_session_discovery_entity.dart';

enum BookableSessionScheduleState { freshWithOffers, freshEmpty, stale }

/// Pure result consumed by the Details renderer. The renderer does not read a
/// clock or reinterpret provider availability.
final class BookableSessionScheduleEvaluation {
  BookableSessionScheduleEvaluation({
    required this.state,
    required List<PublishedBookableSessionOffer> visibleOffers,
  }) : visibleOffers = List<PublishedBookableSessionOffer>.unmodifiable(
         visibleOffers,
       ) {
    if (state != BookableSessionScheduleState.freshWithOffers &&
        visibleOffers.isNotEmpty) {
      throw ArgumentError('Only freshWithOffers may expose visible offers.');
    }
    if (state == BookableSessionScheduleState.freshWithOffers &&
        visibleOffers.isEmpty) {
      throw ArgumentError('freshWithOffers requires at least one offer.');
    }
  }

  final BookableSessionScheduleState state;
  final List<PublishedBookableSessionOffer> visibleOffers;
}
