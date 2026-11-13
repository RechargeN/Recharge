import '../entities/rental_draft_data.dart';

/// Honest tri-state result (spec §8.3) — never a computed real-time
/// reservation state, only what Creator has declared and how fresh that
/// declaration is.
enum RentalAvailabilityResult { declaredAvailable, unavailable, unknown }

class RentalAvailabilityAssessment {
  const RentalAvailabilityAssessment({
    required this.result,
    required this.availableUnits,
    this.confirmedAtUtc,
  });

  final RentalAvailabilityResult result;
  final int availableUnits;
  final DateTime? confirmedAtUtc;
}

/// Pure implementation of spec §8.2 (capacity invariant) and §8.3
/// (coverage/freshness-gated tri-state). Mirrors
/// `EvaluatePlaceOpeningStatusUseCase`'s pure-function style.
class EvaluateRentalAvailabilityUseCase {
  const EvaluateRentalAvailabilityUseCase({
    this.freshnessThreshold = const Duration(days: 7),
  });

  /// Recommended V1 default (spec §8.3) — a Draft recommendation, not yet
  /// an Accepted market policy; kept configurable for that reason.
  final Duration freshnessThreshold;

  RentalAvailabilityAssessment call({
    required RentalAvailabilityCalendar calendar,
    required List<RentalInventoryGroup> groups,
    required DateTime queryStartUtc,
    required DateTime queryEndUtc,
    required DateTime nowUtc,
  }) {
    final RentalAvailabilityCoverage? coverage = calendar.coverage;
    if (coverage == null || !coverage.covers(queryStartUtc, queryEndUtc)) {
      return const RentalAvailabilityAssessment(
        result: RentalAvailabilityResult.unknown,
        availableUnits: 0,
      );
    }
    final bool fresh =
        nowUtc.difference(coverage.confirmedAtUtc) <= freshnessThreshold;
    if (!fresh) {
      return RentalAvailabilityAssessment(
        result: RentalAvailabilityResult.unknown,
        availableUnits: 0,
        confirmedAtUtc: coverage.confirmedAtUtc,
      );
    }

    final Iterable<RentalInventoryGroup> activeGroups = groups.where(
      (RentalInventoryGroup g) => g.status == RentalUnitGroupStatus.available,
    );
    int totalAvailable = 0;
    for (final RentalInventoryGroup group in activeGroups) {
      final int blocked = maxConcurrentBlockedUnits(
        blocks: calendar.blocks,
        groupId: group.id,
        rangeStartUtc: queryStartUtc,
        rangeEndUtc: queryEndUtc,
      );
      final int available = group.quantity - blocked;
      totalAvailable += available > 0 ? available : 0;
    }
    return RentalAvailabilityAssessment(
      result: totalAvailable > 0
          ? RentalAvailabilityResult.declaredAvailable
          : RentalAvailabilityResult.unavailable,
      availableUnits: totalAvailable,
      confirmedAtUtc: coverage.confirmedAtUtc,
    );
  }

  /// spec §8.2: `sum(activeBlock.unitsBlocked where block overlaps t) <=
  /// group.quantity` for every instant `t`. The maximum over a continuous
  /// range only changes at a block's `startsAtUtc` (half-open intervals),
  /// so it suffices to sample the range start plus every in-range block
  /// start.
  int maxConcurrentBlockedUnits({
    required List<RentalAvailabilityBlock> blocks,
    required String groupId,
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
  }) {
    final List<RentalAvailabilityBlock> relevant = blocks
        .where(
          (RentalAvailabilityBlock b) =>
              b.groupId == groupId &&
              b.isActive &&
              b.overlapsRange(rangeStartUtc, rangeEndUtc),
        )
        .toList(growable: false);
    if (relevant.isEmpty) return 0;

    final Set<DateTime> checkpoints = <DateTime>{rangeStartUtc};
    for (final RentalAvailabilityBlock block in relevant) {
      if (block.startsAtUtc.isAfter(rangeStartUtc) &&
          block.startsAtUtc.isBefore(rangeEndUtc)) {
        checkpoints.add(block.startsAtUtc);
      }
    }

    int maxBlocked = 0;
    for (final DateTime instant in checkpoints) {
      final int blockedAtInstant = relevant
          .where((RentalAvailabilityBlock b) => b.overlaps(instant))
          .fold(
            0,
            (int sum, RentalAvailabilityBlock b) => sum + b.unitsBlocked,
          );
      if (blockedAtInstant > maxBlocked) maxBlocked = blockedAtInstant;
    }
    return maxBlocked;
  }

  /// True if adding/editing [candidate] would push concurrent blocked
  /// units above `group.quantity` at any instant within its own range —
  /// the entry-time invariant check spec §8.2 requires.
  bool wouldExceedCapacity({
    required RentalInventoryGroup group,
    required List<RentalAvailabilityBlock> existingActiveBlocksForGroup,
    required RentalAvailabilityBlock candidate,
  }) {
    final List<RentalAvailabilityBlock> withCandidate =
        <RentalAvailabilityBlock>[
          ...existingActiveBlocksForGroup.where(
            (RentalAvailabilityBlock b) => b.id != candidate.id,
          ),
          candidate,
        ];
    final int blocked = maxConcurrentBlockedUnits(
      blocks: withCandidate,
      groupId: group.id,
      rangeStartUtc: candidate.startsAtUtc,
      rangeEndUtc: candidate.endsAtUtc,
    );
    return blocked > group.quantity;
  }
}
