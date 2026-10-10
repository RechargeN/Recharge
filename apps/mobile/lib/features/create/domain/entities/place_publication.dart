import 'publisher_ref.dart';

/// One uploaded medium of a Place publication: the stable attachment id of the
/// Create draft's photo (D3.1 §5.5), the Media asset and the SHA-256 of the
/// bytes it was made from.
final class PlaceAttachmentRecord {
  const PlaceAttachmentRecord({
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

  static PlaceAttachmentRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? attachmentId = value['attachmentId'];
    final Object? assetId = value['assetId'];
    final Object? sha256 = value['sha256'];
    if (attachmentId is! String || assetId is! String || sha256 is! String) {
      return null;
    }
    return PlaceAttachmentRecord(
      attachmentId: attachmentId,
      assetId: assetId,
      sha256: sha256,
    );
  }
}

/// One Place this installation created through the publication path (D3.1
/// §5.6). It is bound to the signed-in account and the publisher it was
/// created for; it lists ids only, and every status is read from the server.
final class PlacePublicationRecord {
  const PlacePublicationRecord({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
    required this.contentId,
    required this.draftId,
    required this.draftRevision,
    required this.serverOwnerUserId,
    required this.title,
    required this.createdAtUtc,
    this.authorApplied = false,
    this.attachments = const <PlaceAttachmentRecord>[],
    this.submissionId,
  });

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;
  final String contentId;
  final String draftId;
  final int draftRevision;

  /// The author the server recorded for the draft (`createdByUserId`).
  final String serverOwnerUserId;

  /// Whether the full body with that author was saved (§5.4, step 3).
  final bool authorApplied;
  final String title;
  final DateTime createdAtUtc;
  final List<PlaceAttachmentRecord> attachments;
  final String? submissionId;

  bool belongsTo(String account, PublisherRef publisher) =>
      accountId == account &&
      publisherRef.type == publisher.type &&
      publisherRef.id == publisher.id;

  PlaceAttachmentRecord? attachment(String attachmentId) {
    for (final PlaceAttachmentRecord item in attachments) {
      if (item.attachmentId == attachmentId) return item;
    }
    return null;
  }

  PlacePublicationRecord copyWith({
    int? draftRevision,
    bool? authorApplied,
    String? title,
    List<PlaceAttachmentRecord>? attachments,
    String? submissionId,
  }) => PlacePublicationRecord(
    accountId: accountId,
    publisherRef: publisherRef,
    localDraftId: localDraftId,
    contentId: contentId,
    draftId: draftId,
    draftRevision: draftRevision ?? this.draftRevision,
    serverOwnerUserId: serverOwnerUserId,
    authorApplied: authorApplied ?? this.authorApplied,
    title: title ?? this.title,
    createdAtUtc: createdAtUtc,
    attachments: attachments ?? this.attachments,
    submissionId: submissionId ?? this.submissionId,
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
    'authorApplied': authorApplied,
    'title': title,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'attachments': attachments.map((item) => item.toJson()).toList(),
    if (submissionId != null) 'submissionId': submissionId,
  };

  /// A malformed or foreign-shaped entry is skipped, never repaired.
  static PlacePublicationRecord? fromJson(Object? value) {
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
    final Object? authorApplied = value['authorApplied'];
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
        authorApplied is! bool ||
        title is! String ||
        createdAt == null ||
        attachments is! List ||
        (submissionId != null && submissionId is! String)) {
      return null;
    }
    final List<PlaceAttachmentRecord> parsed = <PlaceAttachmentRecord>[];
    for (final Object? item in attachments) {
      final PlaceAttachmentRecord? attachment = PlaceAttachmentRecord.fromJson(
        item,
      );
      if (attachment == null) return null;
      parsed.add(attachment);
    }
    return PlacePublicationRecord(
      accountId: accountId,
      publisherRef: PublisherRef(type: publisherType, id: publisherId),
      localDraftId: localDraftId,
      contentId: contentId,
      draftId: draftId,
      draftRevision: draftRevision,
      serverOwnerUserId: serverOwnerUserId,
      authorApplied: authorApplied,
      title: title,
      createdAtUtc: createdAt.toUtc(),
      attachments: List<PlaceAttachmentRecord>.unmodifiable(parsed),
      submissionId: submissionId as String?,
    );
  }
}
