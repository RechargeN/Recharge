import 'event_publication.dart';
import 'publisher_ref.dart';

/// BCK-06 consent of the signed-in author for one Find People publication,
/// exactly as the server answers it (D3.7 §5.1). Never derived on the client.
final class FindPeopleConsentView {
  const FindPeopleConsentView({
    required this.state,
    required this.revision,
    required this.expiresAtUtc,
  });

  /// `active`, `revoked` or `expired`.
  final String state;
  final int revision;
  final DateTime expiresAtUtc;

  bool get active => state == 'active';

  static FindPeopleConsentView? fromWire(Object? value) {
    if (value is! Map) return null;
    final Object? state = value['state'];
    final Object? revision = value['revision'];
    final DateTime? expires = DateTime.tryParse('${value['expiresAtUtc']}');
    if (state is! String || revision is! int || expires == null) return null;
    return FindPeopleConsentView(
      state: state,
      revision: revision,
      expiresAtUtc: expires.toUtc(),
    );
  }
}

/// One Find People request this installation created through the publication
/// path (D3.7). It is bound to the signed-in account and the publisher it was
/// created for; it lists ids only, and every status is read from the server.
final class FindPeoplePublicationRecord {
  const FindPeoplePublicationRecord({
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

  /// The author the server recorded for the draft (`createdByUserId`).
  final String serverOwnerUserId;

  /// Whether the full body with that author was saved.
  final bool authorApplied;
  final String title;
  final DateTime createdAtUtc;
  final String? submissionId;

  /// A body save sent but not yet answered (M1 D2).
  final PendingDraftUpdate? pendingUpdate;

  /// The publish command as first sent (M1 D1).
  final PublishIntent? publishIntent;

  bool belongsTo(String account, PublisherRef publisher) =>
      accountId == account &&
      publisherRef.type == publisher.type &&
      publisherRef.id == publisher.id;

  FindPeoplePublicationRecord copyWith({
    int? draftRevision,
    bool? authorApplied,
    String? title,
    String? submissionId,
    PendingDraftUpdate? pendingUpdate,
    bool clearPendingUpdate = false,
    PublishIntent? publishIntent,
  }) => FindPeoplePublicationRecord(
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
    'authorApplied': authorApplied,
    'title': title,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    if (submissionId != null) 'submissionId': submissionId,
    if (pendingUpdate != null) 'pendingUpdate': pendingUpdate!.toJson(),
    if (publishIntent != null) 'publishIntent': publishIntent!.toJson(),
  };

  /// A malformed or foreign-shaped entry is skipped, never repaired.
  static FindPeoplePublicationRecord? fromJson(Object? value) {
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
        (submissionId != null && submissionId is! String)) {
      return null;
    }
    return FindPeoplePublicationRecord(
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
      submissionId: submissionId as String?,
      pendingUpdate: PendingDraftUpdate.fromJson(value['pendingUpdate']),
      publishIntent: PublishIntent.fromJson(value['publishIntent']),
    );
  }
}
