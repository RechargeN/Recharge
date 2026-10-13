import 'event_publication.dart';
import 'publisher_ref.dart';

/// One uploaded medium of an Activity publication: the stable attachment id of
/// the Create draft's photo (D3.2 §5.5), the Media asset and the SHA-256 of the
/// bytes it was made from.
final class ActivityAttachmentRecord {
  const ActivityAttachmentRecord({
    required this.attachmentId,
    required this.assetId,
    required this.sha256,
  });

  final String attachmentId;
  final String assetId;
  final String sha256;

  Map<String, Object?> toJson() => <String, Object?>{
    'attachmentId': attachmentId,
    'assetId': assetId,
    'sha256': sha256,
  };

  static ActivityAttachmentRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? attachmentId = value['attachmentId'];
    final Object? assetId = value['assetId'];
    final Object? sha256 = value['sha256'];
    if (attachmentId is! String || assetId is! String || sha256 is! String) {
      return null;
    }
    return ActivityAttachmentRecord(
      attachmentId: attachmentId,
      assetId: assetId,
      sha256: sha256,
    );
  }
}

/// One Recharge Activity this installation created through the publication
/// path (D3.2 §5.6). It is bound to the signed-in account and the publisher it
/// was created for; it lists ids only, and every status is read from the server.
final class ActivityPublicationRecord {
  const ActivityPublicationRecord({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
    required this.contentId,
    required this.draftId,
    required this.draftRevision,
    required this.serverOwnerUserId,
    required this.title,
    required this.createdAtUtc,
    this.bodySaved = false,
    this.attachments = const <ActivityAttachmentRecord>[],
    this.submissionId,
    this.editingFromRevisionId,
    this.savedLocalBodyDigest,
    this.pendingActivationRevisionId,
    this.pendingActivationPointerRevision,
    this.pendingUpdate,
    this.publishIntent,
  });

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;
  final String contentId;
  final String draftId;
  final int draftRevision;

  /// The author the server recorded for the draft (`createdByUserId`); a
  /// journal record whose server draft names another author is not used.
  final String serverOwnerUserId;

  /// Whether the full body was saved (§5.4, step 3).
  final bool bodySaved;
  final String title;
  final DateTime createdAtUtc;
  final List<ActivityAttachmentRecord> attachments;
  final String? submissionId;
  final String? editingFromRevisionId;
  final String? savedLocalBodyDigest;
  // Persist the exact optimistic fence before sending; transport retry replays it.
  final String? pendingActivationRevisionId;
  final int? pendingActivationPointerRevision;

  /// A body save sent but not yet answered (M1 D2).
  final PendingDraftUpdate? pendingUpdate;

  /// The publish command as first sent (M1 D1).
  final PublishIntent? publishIntent;

  bool belongsTo(String account, PublisherRef publisher) =>
      accountId == account &&
      publisherRef.type == publisher.type &&
      publisherRef.id == publisher.id;

  ActivityAttachmentRecord? attachment(String attachmentId) {
    for (final ActivityAttachmentRecord item in attachments) {
      if (item.attachmentId == attachmentId) return item;
    }
    return null;
  }

  ActivityPublicationRecord copyWith({
    int? draftRevision,
    bool? bodySaved,
    String? title,
    List<ActivityAttachmentRecord>? attachments,
    String? submissionId,
    String? editingFromRevisionId,
    String? savedLocalBodyDigest,
    String? pendingActivationRevisionId,
    int? pendingActivationPointerRevision,
    bool clearPendingActivation = false,
    bool clearEditing = false,
    PendingDraftUpdate? pendingUpdate,
    bool clearPendingUpdate = false,
    PublishIntent? publishIntent,
  }) => ActivityPublicationRecord(
    accountId: accountId,
    publisherRef: publisherRef,
    localDraftId: localDraftId,
    contentId: contentId,
    draftId: draftId,
    draftRevision: draftRevision ?? this.draftRevision,
    serverOwnerUserId: serverOwnerUserId,
    bodySaved: bodySaved ?? this.bodySaved,
    title: title ?? this.title,
    createdAtUtc: createdAtUtc,
    attachments: attachments ?? this.attachments,
    submissionId: submissionId ?? this.submissionId,
    savedLocalBodyDigest: savedLocalBodyDigest ?? this.savedLocalBodyDigest,
    editingFromRevisionId: clearEditing
        ? null
        : editingFromRevisionId ?? this.editingFromRevisionId,
    pendingActivationRevisionId: clearPendingActivation
        ? null
        : pendingActivationRevisionId ?? this.pendingActivationRevisionId,
    pendingActivationPointerRevision: clearPendingActivation
        ? null
        : pendingActivationPointerRevision ??
              this.pendingActivationPointerRevision,
    pendingUpdate: clearPendingUpdate
        ? null
        : pendingUpdate ?? this.pendingUpdate,
    publishIntent: publishIntent ?? this.publishIntent,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'accountId': accountId,
    'publisherType': publisherRef.type.wireName,
    'publisherId': publisherRef.id,
    'localDraftId': localDraftId,
    'contentId': contentId,
    'draftId': draftId,
    'draftRevision': draftRevision,
    'serverOwnerUserId': serverOwnerUserId,
    'bodySaved': bodySaved,
    'title': title,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'attachments': attachments.map((item) => item.toJson()).toList(),
    if (submissionId != null) 'submissionId': submissionId,
    if (editingFromRevisionId != null)
      'editingFromRevisionId': editingFromRevisionId,
    if (savedLocalBodyDigest != null)
      'savedLocalBodyDigest': savedLocalBodyDigest,
    if (pendingActivationRevisionId != null)
      'pendingActivationRevisionId': pendingActivationRevisionId,
    if (pendingActivationPointerRevision != null)
      'pendingActivationPointerRevision': pendingActivationPointerRevision,
    if (pendingUpdate != null) 'pendingUpdate': pendingUpdate!.toJson(),
    if (publishIntent != null) 'publishIntent': publishIntent!.toJson(),
  };

  /// A malformed or foreign-shaped entry is skipped, never repaired.
  static ActivityPublicationRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? accountId = value['accountId'];
    final PublisherType? publisherType = PublisherType.fromWireName(
      value['publisherType'],
    );
    final Object? publisherId = value['publisherId'];
    final Object? localDraftId = value['localDraftId'];
    final Object? contentId = value['contentId'];
    final Object? draftId = value['draftId'];
    final Object? draftRevision = value['draftRevision'];
    final Object? serverOwnerUserId = value['serverOwnerUserId'];
    final Object? bodySaved = value['bodySaved'];
    final Object? title = value['title'];
    final DateTime? createdAt = DateTime.tryParse(
      '${value['createdAtUtc'] ?? ''}',
    );
    final Object? attachments = value['attachments'];
    final Object? submissionId = value['submissionId'];
    if (accountId is! String ||
        publisherType == null ||
        publisherId is! String ||
        localDraftId is! String ||
        contentId is! String ||
        draftId is! String ||
        draftRevision is! int ||
        serverOwnerUserId is! String ||
        bodySaved is! bool ||
        title is! String ||
        createdAt == null ||
        attachments is! List ||
        (submissionId != null && submissionId is! String) ||
        (value['savedLocalBodyDigest'] != null &&
            value['savedLocalBodyDigest'] is! String) ||
        (value['editingFromRevisionId'] != null &&
            value['editingFromRevisionId'] is! String) ||
        (value['pendingActivationRevisionId'] != null &&
            value['pendingActivationRevisionId'] is! String) ||
        (value['pendingActivationPointerRevision'] != null &&
            value['pendingActivationPointerRevision'] is! int) ||
        ((value['pendingActivationRevisionId'] == null) !=
            (value['pendingActivationPointerRevision'] == null))) {
      return null;
    }
    final List<ActivityAttachmentRecord> parsed = <ActivityAttachmentRecord>[];
    for (final Object? item in attachments) {
      final ActivityAttachmentRecord? attachment =
          ActivityAttachmentRecord.fromJson(item);
      if (attachment == null) return null;
      parsed.add(attachment);
    }
    return ActivityPublicationRecord(
      accountId: accountId,
      publisherRef: PublisherRef(type: publisherType, id: publisherId),
      localDraftId: localDraftId,
      contentId: contentId,
      draftId: draftId,
      draftRevision: draftRevision,
      serverOwnerUserId: serverOwnerUserId,
      bodySaved: bodySaved,
      title: title,
      createdAtUtc: createdAt.toUtc(),
      attachments: List<ActivityAttachmentRecord>.unmodifiable(parsed),
      submissionId: submissionId as String?,
      editingFromRevisionId: value['editingFromRevisionId'] as String?,
      savedLocalBodyDigest: value['savedLocalBodyDigest'] as String?,
      pendingActivationRevisionId:
          value['pendingActivationRevisionId'] as String?,
      pendingActivationPointerRevision:
          value['pendingActivationPointerRevision'] as int?,
      pendingUpdate: PendingDraftUpdate.fromJson(value['pendingUpdate']),
      publishIntent: PublishIntent.fromJson(value['publishIntent']),
    );
  }
}
