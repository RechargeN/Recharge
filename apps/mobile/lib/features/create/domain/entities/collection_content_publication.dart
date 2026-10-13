import 'collection_item_draft.dart';
import 'event_publication.dart';
import 'publisher_ref.dart';

/// One uploaded medium of a Collection publication: the stable attachment id
/// of the Create draft's photo (D3.4 §5.5), the Media asset and the SHA-256 of
/// the bytes it was made from.
final class CollectionAttachmentRecord {
  const CollectionAttachmentRecord({
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

  static CollectionAttachmentRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? attachmentId = value['attachmentId'];
    final Object? assetId = value['assetId'];
    final Object? sha256 = value['sha256'];
    if (attachmentId is! String || assetId is! String || sha256 is! String) {
      return null;
    }
    return CollectionAttachmentRecord(
      attachmentId: attachmentId,
      assetId: assetId,
      sha256: sha256,
    );
  }
}

/// One Collection this installation created through the publication path
/// (D3.4 §5.6). It is bound to the signed-in account and the publisher it was
/// created for; it lists ids only, and every status is read from the server.
final class CollectionPublicationRecord {
  const CollectionPublicationRecord({
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
    this.attachments = const <CollectionAttachmentRecord>[],
    this.submissionId,
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
  /// record whose server draft has another author is never used.
  final String serverOwnerUserId;

  /// Whether the full body was saved after the empty draft (§5.4).
  final bool bodySaved;
  final String title;
  final DateTime createdAtUtc;
  final List<CollectionAttachmentRecord> attachments;
  final String? submissionId;

  /// A body save sent but not yet answered (M1 D2).
  final PendingDraftUpdate? pendingUpdate;

  /// The publish command as first sent (M1 D1).
  final PublishIntent? publishIntent;

  bool belongsTo(String account, PublisherRef publisher) =>
      accountId == account &&
      publisherRef.type == publisher.type &&
      publisherRef.id == publisher.id;

  CollectionAttachmentRecord? attachment(String attachmentId) {
    for (final CollectionAttachmentRecord item in attachments) {
      if (item.attachmentId == attachmentId) return item;
    }
    return null;
  }

  CollectionPublicationRecord copyWith({
    int? draftRevision,
    bool? bodySaved,
    String? title,
    List<CollectionAttachmentRecord>? attachments,
    String? submissionId,
    PendingDraftUpdate? pendingUpdate,
    bool clearPendingUpdate = false,
    PublishIntent? publishIntent,
  }) => CollectionPublicationRecord(
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
    if (pendingUpdate != null) 'pendingUpdate': pendingUpdate!.toJson(),
    if (publishIntent != null) 'publishIntent': publishIntent!.toJson(),
  };

  /// A malformed or foreign-shaped entry is skipped, never repaired.
  static CollectionPublicationRecord? fromJson(Object? value) {
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
        (submissionId != null && submissionId is! String)) {
      return null;
    }
    final List<CollectionAttachmentRecord> parsed =
        <CollectionAttachmentRecord>[];
    for (final Object? item in attachments) {
      final CollectionAttachmentRecord? attachment =
          CollectionAttachmentRecord.fromJson(item);
      if (attachment == null) return null;
      parsed.add(attachment);
    }
    return CollectionPublicationRecord(
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
      attachments: List<CollectionAttachmentRecord>.unmodifiable(parsed),
      submissionId: submissionId as String?,
      pendingUpdate: PendingDraftUpdate.fromJson(value['pendingUpdate']),
      publishIntent: PublishIntent.fromJson(value['publishIntent']),
    );
  }
}

/// The server's answer about one referenced object (D3.4 §2.3), as the
/// Catalog-owned evaluator gives it: `eligible`, `withheld`, `unknown`,
/// `forbidden`, or `unavailable` when it could not be read.
final class CollectionMemberStatus {
  const CollectionMemberStatus({
    required this.ref,
    required this.status,
    this.title,
  });

  final CollectionObjectRef ref;
  final String status;

  /// Public title of an eligible object only.
  final String? title;
}
