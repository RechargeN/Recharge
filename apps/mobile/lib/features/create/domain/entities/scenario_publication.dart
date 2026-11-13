/// I3 / SCN-PUB-01: what this install knows about the publication of one of
/// its own Scenarios. It is a list of references, not a source of truth; every
/// status is read from the server again.
final class ScenarioPublicationRecord {
  const ScenarioPublicationRecord({
    required this.accountId,
    required this.scenarioId,
    required this.scenarioRevisionId,
    required this.contentHash,
    required this.distribution,
    this.contentDraftId,
    this.contentRevision,
    this.coverAssetId,
    this.coverSha256,
  });

  final String accountId;

  /// The Scenario id, which is also its Content id (one publication each).
  final String scenarioId;

  /// The immutable BCK-10 public revision the Content body is pinned to.
  final String scenarioRevisionId;
  final String contentHash;
  final Map<String, Object?> distribution;
  final String? contentDraftId;
  final int? contentRevision;
  final String? coverAssetId;
  final String? coverSha256;

  ScenarioPublicationRecord copyWith({
    String? scenarioRevisionId,
    String? contentHash,
    Map<String, Object?>? distribution,
    String? contentDraftId,
    int? contentRevision,
    String? coverAssetId,
    String? coverSha256,
  }) => ScenarioPublicationRecord(
    accountId: accountId,
    scenarioId: scenarioId,
    scenarioRevisionId: scenarioRevisionId ?? this.scenarioRevisionId,
    contentHash: contentHash ?? this.contentHash,
    distribution: distribution ?? this.distribution,
    contentDraftId: contentDraftId ?? this.contentDraftId,
    contentRevision: contentRevision ?? this.contentRevision,
    coverAssetId: coverAssetId ?? this.coverAssetId,
    coverSha256: coverSha256 ?? this.coverSha256,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'accountId': accountId,
    'scenarioId': scenarioId,
    'scenarioRevisionId': scenarioRevisionId,
    'contentHash': contentHash,
    'distribution': distribution,
    'contentDraftId': contentDraftId,
    'contentRevision': contentRevision,
    'coverAssetId': coverAssetId,
    'coverSha256': coverSha256,
  };

  static ScenarioPublicationRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? distribution = value['distribution'];
    final Object? accountId = value['accountId'];
    final Object? scenarioId = value['scenarioId'];
    final Object? revisionId = value['scenarioRevisionId'];
    final Object? hash = value['contentHash'];
    if (accountId is! String ||
        scenarioId is! String ||
        revisionId is! String ||
        hash is! String ||
        distribution is! Map) {
      return null;
    }
    return ScenarioPublicationRecord(
      accountId: accountId,
      scenarioId: scenarioId,
      scenarioRevisionId: revisionId,
      contentHash: hash,
      distribution: Map<String, Object?>.from(distribution),
      contentDraftId: value['contentDraftId'] as String?,
      contentRevision: value['contentRevision'] as int?,
      coverAssetId: value['coverAssetId'] as String?,
      coverSha256: value['coverSha256'] as String?,
    );
  }
}

/// The server's immutable public revision of the plan (Planning `distribute`).
final class ScenarioDistributionRef {
  const ScenarioDistributionRef({
    required this.scenarioRevisionId,
    required this.contentHash,
    required this.distribution,
  });

  final String scenarioRevisionId;
  final String contentHash;
  final Map<String, Object?> distribution;
}

/// An unlisted share. [token] is shown once; after a lost answer the server
/// never repeats it and the owner issues a new link instead (SCN-PUB-01 §9).
final class ScenarioShareLink {
  const ScenarioShareLink({required this.expiresAtUtc, this.token});

  final DateTime expiresAtUtc;
  final String? token;
}
