enum PageLimitIncreaseRequestStatus { pending, approved, rejected, cancelled }

class PageLimitIncreaseRequestEntity {
  const PageLimitIncreaseRequestEntity({
    required this.id,
    required this.userId,
    required this.currentOwnedPageCount,
    required this.requestedOwnedPageLimit,
    required this.status,
    required this.createdAtUtc,
    required this.revision,
  });

  final String id;
  final String userId;
  final int currentOwnedPageCount;
  final int requestedOwnedPageLimit;
  final PageLimitIncreaseRequestStatus status;
  final DateTime createdAtUtc;
  final int revision;

  bool get isPending => status == PageLimitIncreaseRequestStatus.pending;

  @override
  bool operator ==(Object other) {
    return other is PageLimitIncreaseRequestEntity &&
        other.id == id &&
        other.userId == userId &&
        other.currentOwnedPageCount == currentOwnedPageCount &&
        other.requestedOwnedPageLimit == requestedOwnedPageLimit &&
        other.status == status &&
        other.createdAtUtc == createdAtUtc &&
        other.revision == revision;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    currentOwnedPageCount,
    requestedOwnedPageLimit,
    status,
    createdAtUtc,
    revision,
  );
}
