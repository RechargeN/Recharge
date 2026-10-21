import 'publisher_ref.dart';

/// J2 / RTE-PUB-01: what this install knows about the publication of one of
/// its own Routes. It is a list of references, not a source of truth; every
/// status is read from the server again.
final class RouteContentPublicationRecord {
  const RouteContentPublicationRecord({
    required this.accountId,
    required this.localDraftId,
    required this.routeId,
    required this.routeRevisionId,
    required this.contentHash,
    required this.distribution,
    required this.publisherRef,
    this.contentDraftId,
    this.contentRevision,
    this.coverAssetId,
    this.coverSha256,
  });

  final String accountId;

  /// The Create draft the Route was synced from.
  final String localDraftId;

  /// The server Route id, which is also its Content id (one publication each).
  final String routeId;

  /// The immutable BCK-11 snapshot the Content body is pinned to.
  final String routeRevisionId;
  final String contentHash;
  final Map<String, Object?> distribution;

  /// Captured once from the active workspace when the publication is first
  /// prepared (RP-04); the Content draft keeps it afterwards.
  final PublisherRef publisherRef;
  final String? contentDraftId;
  final int? contentRevision;
  final String? coverAssetId;
  final String? coverSha256;

  RouteContentPublicationRecord copyWith({
    String? routeRevisionId,
    String? contentHash,
    Map<String, Object?>? distribution,
    String? contentDraftId,
    int? contentRevision,
    String? coverAssetId,
    String? coverSha256,
  }) => RouteContentPublicationRecord(
    accountId: accountId,
    localDraftId: localDraftId,
    routeId: routeId,
    routeRevisionId: routeRevisionId ?? this.routeRevisionId,
    contentHash: contentHash ?? this.contentHash,
    distribution: distribution ?? this.distribution,
    publisherRef: publisherRef,
    contentDraftId: contentDraftId ?? this.contentDraftId,
    contentRevision: contentRevision ?? this.contentRevision,
    coverAssetId: coverAssetId ?? this.coverAssetId,
    coverSha256: coverSha256 ?? this.coverSha256,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'accountId': accountId,
    'localDraftId': localDraftId,
    'routeId': routeId,
    'routeRevisionId': routeRevisionId,
    'contentHash': contentHash,
    'distribution': distribution,
    'publisherRef': <String, Object?>{
      'type': publisherRef.type.wireName,
      'id': publisherRef.id,
    },
    'contentDraftId': contentDraftId,
    'contentRevision': contentRevision,
    'coverAssetId': coverAssetId,
    'coverSha256': coverSha256,
  };

  static RouteContentPublicationRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? distribution = value['distribution'];
    final Object? publisher = value['publisherRef'];
    final PublisherType? publisherType = publisher is Map
        ? PublisherType.fromWireName(publisher['type'])
        : null;
    final Object? publisherId = publisher is Map ? publisher['id'] : null;
    final List<Object?> ids = <Object?>[
      value['accountId'],
      value['localDraftId'],
      value['routeId'],
      value['routeRevisionId'],
      value['contentHash'],
    ];
    if (ids.any((Object? id) => id is! String) ||
        distribution is! Map ||
        publisherType == null ||
        publisherId is! String) {
      return null;
    }
    return RouteContentPublicationRecord(
      accountId: value['accountId']! as String,
      localDraftId: value['localDraftId']! as String,
      routeId: value['routeId']! as String,
      routeRevisionId: value['routeRevisionId']! as String,
      contentHash: value['contentHash']! as String,
      distribution: Map<String, Object?>.from(distribution),
      publisherRef: PublisherRef(type: publisherType, id: publisherId),
      contentDraftId: value['contentDraftId'] as String?,
      contentRevision: value['contentRevision'] as int?,
      coverAssetId: value['coverAssetId'] as String?,
      coverSha256: value['coverSha256'] as String?,
    );
  }
}

/// The server's immutable public snapshot of one Route revision (`distribute`).
final class RouteDistributionRef {
  const RouteDistributionRef({
    required this.routeRevisionId,
    required this.contentHash,
    required this.distribution,
  });

  final String routeRevisionId;
  final String contentHash;
  final Map<String, Object?> distribution;
}
