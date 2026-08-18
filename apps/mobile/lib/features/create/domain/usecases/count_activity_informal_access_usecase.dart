import '../entities/create_draft_entity.dart';

class CountActivityInformalAccessUseCase {
  const CountActivityInformalAccessUseCase({
    this.publishedInformalActivityCounts = const <String, int>{},
  });

  /// publisher id -> number of already-published Recharge Activity items
  /// from that publisher with `accessCaution.isInformal == true`. Local/
  /// mock only, mirroring `CheckPlaceDuplicatesUseCase`'s injected-candidate
  /// pattern — no backend moderation queue exists yet for any Create type.
  final Map<String, int> publishedInformalActivityCounts;

  int call(CreateDraftEntity draft) {
    if (draft.objectType != CreateObjectType.activity ||
        draft.activityData == null) {
      return 0;
    }
    final String publisherId = draft.activityData!.publisherRef.id;
    return publishedInformalActivityCounts[publisherId] ?? 0;
  }
}
