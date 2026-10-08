/// Server-side state of an Event the user is publishing through Content (C3).
/// Every value here comes from the backend; the client never decides it.
final class EventServerDraftRef {
  const EventServerDraftRef({
    required this.contentId,
    required this.draftId,
    required this.revision,
  });

  final String contentId;
  final String draftId;
  final int revision;
}

final class EventPublicationStatus {
  const EventPublicationStatus({
    required this.contentId,
    this.latestSubmissionId,
    this.latestSubmissionState,
    this.pointerRevision,
    this.visibility,
    this.currentPublishedRevisionId,
    this.previousPublishedRevisionId,
    this.ownerHold,
    this.moderationHold,
  });

  final String contentId;
  final String? latestSubmissionId;

  /// `under_review`, `approved_for_publication`, `rejected`, `published`, ...
  final String? latestSubmissionState;
  final int? pointerRevision;

  /// `visible`, `withdrawn`, `restricted` or `archived`; null before publication.
  final String? visibility;
  final String? currentPublishedRevisionId;
  final String? previousPublishedRevisionId;
  final String? ownerHold;
  final String? moderationHold;

  bool get published => currentPublishedRevisionId != null;
  bool get approvedForPublication =>
      latestSubmissionState == 'approved_for_publication';
}

/// One object this installation created through the publication path: the
/// local "my objects" journal. It lists ids only; every status is read from the
/// server with the owner's Session.
final class EventPublicationRecord {
  const EventPublicationRecord({
    required this.localDraftId,
    required this.contentId,
    required this.draftId,
    required this.draftRevision,
    required this.title,
    required this.createdAtUtc,
    this.coverAssetId,
    this.coverDigest,
    this.submissionId,
  });

  final String localDraftId;
  final String contentId;
  final String draftId;
  final int draftRevision;
  final String title;
  final DateTime createdAtUtc;
  final String? coverAssetId;

  /// SHA-256 of the cover bytes that produced [coverAssetId].
  final String? coverDigest;
  final String? submissionId;

  EventPublicationRecord copyWith({
    int? draftRevision,
    String? title,
    String? coverAssetId,
    String? coverDigest,
    String? submissionId,
  }) => EventPublicationRecord(
    localDraftId: localDraftId,
    contentId: contentId,
    draftId: draftId,
    draftRevision: draftRevision ?? this.draftRevision,
    title: title ?? this.title,
    createdAtUtc: createdAtUtc,
    coverAssetId: coverAssetId ?? this.coverAssetId,
    coverDigest: coverDigest ?? this.coverDigest,
    submissionId: submissionId ?? this.submissionId,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'localDraftId': localDraftId,
    'contentId': contentId,
    'draftId': draftId,
    'draftRevision': draftRevision,
    'title': title,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'coverAssetId': coverAssetId,
    'coverDigest': coverDigest,
    'submissionId': submissionId,
  };

  static EventPublicationRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? localDraftId = value['localDraftId'];
    final Object? contentId = value['contentId'];
    final Object? draftId = value['draftId'];
    final Object? draftRevision = value['draftRevision'];
    final Object? title = value['title'];
    final DateTime? createdAt = DateTime.tryParse(
      value['createdAtUtc']?.toString() ?? '',
    );
    if (localDraftId is! String ||
        contentId is! String ||
        draftId is! String ||
        draftRevision is! int ||
        title is! String ||
        createdAt == null) {
      return null;
    }
    String? optional(String key) =>
        value[key] is String ? value[key] as String : null;
    return EventPublicationRecord(
      localDraftId: localDraftId,
      contentId: contentId,
      draftId: draftId,
      draftRevision: draftRevision,
      title: title,
      createdAtUtc: createdAt.toUtc(),
      coverAssetId: optional('coverAssetId'),
      coverDigest: optional('coverDigest'),
      submissionId: optional('submissionId'),
    );
  }
}

/// The server refused the command; [code] is its typed reason.
final class EventPublicationRejected implements Exception {
  const EventPublicationRejected(this.code);

  final String code;

  @override
  String toString() => 'EventPublicationRejected($code)';
}

/// No answer from the server (transport failure, no Session).
final class EventPublicationUnavailable implements Exception {
  const EventPublicationUnavailable(this.code);

  final String code;

  @override
  String toString() => 'EventPublicationUnavailable($code)';
}
