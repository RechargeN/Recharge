import '../entities/session_slot_projection.dart';
import '../../../../shared/primitives/time/utc_instant.dart';

/// Allowlist projector: internal → public (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md
/// §11.6, §14.1). Only `offeredBySchedule` slots cross the boundary — no
/// `blockedByCreator`/`past`/notice-window/DST-skip reason, private note, or
/// audit metadata ever reaches the Viewer.
class BuildSessionPublicProjectionUseCase {
  const BuildSessionPublicProjectionUseCase();

  PublicSessionScheduleProjection call({
    required List<SessionSlotProjection> internalProjections,
    required int scheduleRevision,
    required DateTime generatedAtUtc,
    Duration freshFor = const Duration(minutes: 5),
  }) {
    final DateTime generatedAt = UtcInstant(generatedAtUtc).value;
    final List<PublicSessionOffer> offers =
        internalProjections
            .where(
              (SessionSlotProjection p) =>
                  p.internalStatus == SessionProjectionStatus.offeredBySchedule,
            )
            .map(
              (SessionSlotProjection p) => PublicSessionOffer(
                slotKey: p.slotKey,
                // The internal entity requires both UTC bounds for any
                // resolved status; DST-skipped entries never reach here.
                startAtUtc: p.startAtUtc!,
                endAtUtc: p.endAtUtc!,
                timezoneId: p.timezoneId,
              ),
            )
            .toList(growable: false)
          ..sort(
            (PublicSessionOffer a, PublicSessionOffer b) =>
                a.startAtUtc.compareTo(b.startAtUtc),
          );
    return PublicSessionScheduleProjection(
      scheduleRevision: scheduleRevision,
      generatedAtUtc: generatedAt,
      validUntilUtc: generatedAt.add(freshFor),
      offers: offers,
    );
  }
}
