import 'content_validation_violation.dart';

/// Server-side state of an Event the user is publishing through Content (C3).
/// Every value here comes from the backend; the client never decides it.
final class EventServerDraftRef {
  const EventServerDraftRef({
    required this.contentId,
    required this.draftId,
    required this.revision,
    this.createdByUserId,
  });

  final String contentId;
  final String draftId;
  final int revision;

  /// The author the server recorded for the draft (D3.1 §5.4); the client
  /// echoes it where a type's body names its author and never decides it.
  final String? createdByUserId;
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

/// The owner's publish command as it was first sent (M1 D1). It is journaled
/// before the call, so a retry after an unknown outcome sends exactly the same
/// payload under the same key and the server replays its stored answer.
final class PublishIntent {
  const PublishIntent({
    required this.submissionId,
    required this.expectedPointerRevision,
  });

  final String submissionId;
  final int expectedPointerRevision;

  String get idempotencyKey => '$submissionId:publish';

  Map<String, Object?> toJson() => <String, Object?>{
    'submissionId': submissionId,
    'expectedPointerRevision': expectedPointerRevision,
  };

  static PublishIntent? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? submissionId = value['submissionId'];
    final Object? expected = value['expectedPointerRevision'];
    if (submissionId is! String || expected is! int) return null;
    return PublishIntent(
      submissionId: submissionId,
      expectedPointerRevision: expected,
    );
  }
}

/// A body save whose answer has not arrived yet (M1 D2), journaled before the
/// call with its exact payload. The next save first replays exactly this
/// write: the server answers a write it did apply from its stored result, so a
/// newer server revision is known to be this install's own; anything else is
/// someone else's edit and is never overwritten without the user.
final class PendingDraftUpdate {
  const PendingDraftUpdate({
    required this.baseRevision,
    required this.idempotencyKey,
    required this.bodyDigest,
    required this.body,
  });

  final int baseRevision;
  final String idempotencyKey;
  final String bodyDigest;
  final Map<String, Object?> body;

  Map<String, Object?> toJson() => <String, Object?>{
    'baseRevision': baseRevision,
    'idempotencyKey': idempotencyKey,
    'bodyDigest': bodyDigest,
    'body': body,
  };

  static PendingDraftUpdate? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? baseRevision = value['baseRevision'];
    final Object? idempotencyKey = value['idempotencyKey'];
    final Object? bodyDigest = value['bodyDigest'];
    final Object? body = value['body'];
    if (baseRevision is! int ||
        idempotencyKey is! String ||
        bodyDigest is! String ||
        body is! Map) {
      return null;
    }
    return PendingDraftUpdate(
      baseRevision: baseRevision,
      idempotencyKey: idempotencyKey,
      bodyDigest: bodyDigest,
      body: Map<String, Object?>.from(body),
    );
  }
}

/// The server holds a newer revision of the draft that is not this install's
/// own write (M1 D2). The local edit is kept; nothing is saved until the user
/// explicitly chooses to save their version on top of [serverRevision].
final class DraftConflict {
  const DraftConflict({required this.serverRevision});

  final int serverRevision;
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
    this.publishIntent,
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

  /// The publish command as first sent, replayed unchanged on a retry (M1 D1).
  final PublishIntent? publishIntent;

  EventPublicationRecord copyWith({
    int? draftRevision,
    String? title,
    String? coverAssetId,
    String? coverDigest,
    String? submissionId,
    PublishIntent? publishIntent,
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
    publishIntent: publishIntent ?? this.publishIntent,
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
    if (publishIntent != null) 'publishIntent': publishIntent!.toJson(),
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
      publishIntent: PublishIntent.fromJson(value['publishIntent']),
    );
  }
}

/// The server refused the command; [code] is its typed reason.
final class EventPublicationRejected implements Exception {
  const EventPublicationRejected(this.code, {this.violations = const []});

  final String code;
  final List<ContentValidationViolation> violations;

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
