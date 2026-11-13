class ActivityPlaceCandidate {
  const ActivityPlaceCandidate({
    required this.id,
    required this.title,
    required this.publishedRevisionId,
    required this.pointerRevision,
  });
  final String id, title, publishedRevisionId;
  final int pointerRevision;
}

class ActivityPlaceResolution {
  const ActivityPlaceResolution(this.status, [this.place]);
  final String status;
  final ActivityPlaceCandidate? place;
}

class ActivityPlacePage {
  const ActivityPlacePage({
    required this.available,
    this.items = const [],
    this.nextCursor,
  });
  final bool available;
  final List<ActivityPlaceCandidate> items;
  final String? nextCursor;
}

abstract interface class ActivityPlaceLinkRepository {
  Future<ActivityPlaceResolution> resolve(String id);
  Future<ActivityPlacePage> candidates(String text, {String? after});
}
