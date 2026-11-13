import '../entities/create_draft_entity.dart';

class CountActivityInformalAccessUseCase {
  const CountActivityInformalAccessUseCase({
    this.publishedInformalActivityCounts = const <String, int>{},
  });

  /// Actor Creator user id -> number of already-published Recharge Activity
  /// items from that actor with `accessCaution.isInformal == true`.
  /// RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md v1.4 §10: counted by the
  /// authenticated actor, not by `PublisherRef`, so publishing through
  /// different Professional Pages cannot reset the personal anti-abuse
  /// signal. Local/mock only, mirroring `CheckPlaceDuplicatesUseCase`'s
  /// injected-candidate pattern — no backend moderation queue exists yet
  /// for any Create type.
  final Map<String, int> publishedInformalActivityCounts;

  int call(CreateDraftEntity draft, {required String actorUserId}) {
    if (draft.objectType != CreateObjectType.activity ||
        draft.activityData == null) {
      return 0;
    }
    return publishedInformalActivityCounts[actorUserId] ?? 0;
  }
}
