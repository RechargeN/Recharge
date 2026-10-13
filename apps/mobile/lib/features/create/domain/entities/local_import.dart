import 'publisher_ref.dart';

/// Dry-run class of one local item (D4 §5.2, BCK-18 §33.5).
enum LocalImportClass {
  /// Not on the server yet; it would be created as a server draft.
  create,

  /// Already imported and verified, and the local item has not changed since.
  alreadyMapped,

  /// Already imported, but the local item changed since: the user chooses.
  conflict,

  /// The server cannot hold it (type, section, schema); never sent.
  unsupported,

  /// Owner or publisher checks failed; never sent.
  blocked,
}

/// Progress of one item through the import (D4 §5.3). Each state is written
/// only after the server answered the step, so a resume restarts the step.
enum LocalImportItemState {
  created,
  mediaUploaded,
  bodySaved,
  verified,
  failed,
}

LocalImportItemState? localImportItemStateOf(Object? value) {
  for (final LocalImportItemState state in LocalImportItemState.values) {
    if (state.name == value) return state;
  }
  return null;
}

/// One local item as the dry run sees it. Nothing here is server truth.
final class LocalImportCandidate {
  const LocalImportCandidate({
    required this.localDraftId,
    required this.typeId,
    required this.title,
    required this.classification,
    this.publisherRef,
    this.sourceHash,
    this.reason,
    this.serverContentId,
  });

  final String localDraftId;

  /// Content type id (`place`, `event`, …) or the local type name when the
  /// type is not importable.
  final String typeId;
  final String title;
  final LocalImportClass classification;
  final PublisherRef? publisherRef;

  /// SHA-256 of the canonical local source (D4 §5.2); null when not mappable.
  final String? sourceHash;

  /// Why it is not `create` (a stable code), if it is not.
  final String? reason;

  /// The server object it already maps to, if any.
  final String? serverContentId;
}

/// One uploaded medium of an imported item.
final class LocalImportAttachmentRecord {
  const LocalImportAttachmentRecord({
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

  static LocalImportAttachmentRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? attachmentId = value['attachmentId'];
    final Object? assetId = value['assetId'];
    final Object? sha256 = value['sha256'];
    if (attachmentId is! String || assetId is! String || sha256 is! String) {
      return null;
    }
    return LocalImportAttachmentRecord(
      attachmentId: attachmentId,
      assetId: assetId,
      sha256: sha256,
    );
  }
}

/// The local→server mapping receipt of one item (D4 §5.3, §5.5). Bound to the
/// account and publisher; it lists ids and hashes only, and is never authority
/// over the server object.
final class LocalImportReceipt {
  const LocalImportReceipt({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
    required this.typeId,
    required this.importSourceKey,
    required this.sourceHash,
    required this.contentId,
    required this.draftId,
    required this.serverOwnerUserId,
    required this.serverRevision,
    required this.state,
    required this.updatedAtUtc,
    this.title = '',
    this.attachments = const <LocalImportAttachmentRecord>[],
    this.sentBodyHash,
    this.verifiedAtUtc,
    this.confirmedAtUtc,
    this.localDeletedAtUtc,
    this.failureCode,
  });

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;
  final String typeId;
  final String importSourceKey;

  /// Hash of the local source this receipt imported.
  final String sourceHash;
  final String contentId;
  final String draftId;

  /// The author the server recorded (`createdByUserId`).
  final String serverOwnerUserId;
  final int serverRevision;
  final LocalImportItemState state;
  final DateTime updatedAtUtc;
  final String title;
  final List<LocalImportAttachmentRecord> attachments;

  /// Hash of the body the client saved, compared with the server's on verify.
  final String? sentBodyHash;
  final DateTime? verifiedAtUtc;

  /// The user's explicit confirmation that the server copy is the one to keep.
  final DateTime? confirmedAtUtc;
  final DateTime? localDeletedAtUtc;
  final String? failureCode;

  bool belongsTo(String account, PublisherRef publisher) =>
      accountId == account &&
      publisherRef.type == publisher.type &&
      publisherRef.id == publisher.id;

  LocalImportAttachmentRecord? attachment(String attachmentId) {
    for (final LocalImportAttachmentRecord item in attachments) {
      if (item.attachmentId == attachmentId) return item;
    }
    return null;
  }

  LocalImportReceipt copyWith({
    String? sourceHash,
    int? serverRevision,
    LocalImportItemState? state,
    DateTime? updatedAtUtc,
    String? title,
    List<LocalImportAttachmentRecord>? attachments,
    String? sentBodyHash,
    DateTime? verifiedAtUtc,
    bool clearVerified = false,
    DateTime? confirmedAtUtc,
    bool clearConfirmed = false,
    DateTime? localDeletedAtUtc,
    String? failureCode,
    bool clearFailure = false,
  }) => LocalImportReceipt(
    accountId: accountId,
    publisherRef: publisherRef,
    localDraftId: localDraftId,
    typeId: typeId,
    importSourceKey: importSourceKey,
    sourceHash: sourceHash ?? this.sourceHash,
    contentId: contentId,
    draftId: draftId,
    serverOwnerUserId: serverOwnerUserId,
    serverRevision: serverRevision ?? this.serverRevision,
    state: state ?? this.state,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    title: title ?? this.title,
    attachments: attachments ?? this.attachments,
    sentBodyHash: sentBodyHash ?? this.sentBodyHash,
    verifiedAtUtc: clearVerified ? null : (verifiedAtUtc ?? this.verifiedAtUtc),
    confirmedAtUtc: clearConfirmed
        ? null
        : (confirmedAtUtc ?? this.confirmedAtUtc),
    localDeletedAtUtc: localDeletedAtUtc ?? this.localDeletedAtUtc,
    failureCode: clearFailure ? null : (failureCode ?? this.failureCode),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'accountId': accountId,
    'publisherType': publisherRef.type.wireName,
    'publisherId': publisherRef.id,
    'localDraftId': localDraftId,
    'typeId': typeId,
    'importSourceKey': importSourceKey,
    'sourceHash': sourceHash,
    'contentId': contentId,
    'draftId': draftId,
    'serverOwnerUserId': serverOwnerUserId,
    'serverRevision': serverRevision,
    'state': state.name,
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
    'title': title,
    'attachments': attachments.map((item) => item.toJson()).toList(),
    if (sentBodyHash != null) 'sentBodyHash': sentBodyHash,
    if (verifiedAtUtc != null)
      'verifiedAtUtc': verifiedAtUtc!.toUtc().toIso8601String(),
    if (confirmedAtUtc != null)
      'confirmedAtUtc': confirmedAtUtc!.toUtc().toIso8601String(),
    if (localDeletedAtUtc != null)
      'localDeletedAtUtc': localDeletedAtUtc!.toUtc().toIso8601String(),
    if (failureCode != null) 'failureCode': failureCode,
  };

  /// A malformed or foreign-shaped entry is skipped, never repaired.
  static LocalImportReceipt? fromJson(Object? value) {
    if (value is! Map) return null;
    final PublisherType? publisherType = PublisherType.fromWireName(
      value['publisherType'],
    );
    final LocalImportItemState? state = localImportItemStateOf(value['state']);
    final DateTime? updatedAt = _instant(value['updatedAtUtc']);
    final Object? attachments = value['attachments'];
    final List<String?> strings = <String?>[
      _string(value['accountId']),
      _string(value['publisherId']),
      _string(value['localDraftId']),
      _string(value['typeId']),
      _string(value['importSourceKey']),
      _string(value['sourceHash']),
      _string(value['contentId']),
      _string(value['draftId']),
      _string(value['serverOwnerUserId']),
      _string(value['title']),
    ];
    if (publisherType == null ||
        state == null ||
        updatedAt == null ||
        strings.contains(null) ||
        value['serverRevision'] is! int ||
        attachments is! List ||
        !_optionalString(value['sentBodyHash']) ||
        !_optionalString(value['failureCode']) ||
        !_optionalInstant(value['verifiedAtUtc']) ||
        !_optionalInstant(value['confirmedAtUtc']) ||
        !_optionalInstant(value['localDeletedAtUtc'])) {
      return null;
    }
    final List<LocalImportAttachmentRecord> parsed =
        <LocalImportAttachmentRecord>[];
    for (final Object? item in attachments) {
      final LocalImportAttachmentRecord? attachment =
          LocalImportAttachmentRecord.fromJson(item);
      if (attachment == null) return null;
      parsed.add(attachment);
    }
    return LocalImportReceipt(
      accountId: strings[0]!,
      publisherRef: PublisherRef(type: publisherType, id: strings[1]!),
      localDraftId: strings[2]!,
      typeId: strings[3]!,
      importSourceKey: strings[4]!,
      sourceHash: strings[5]!,
      contentId: strings[6]!,
      draftId: strings[7]!,
      serverOwnerUserId: strings[8]!,
      title: strings[9]!,
      serverRevision: value['serverRevision']! as int,
      state: state,
      updatedAtUtc: updatedAt,
      attachments: List<LocalImportAttachmentRecord>.unmodifiable(parsed),
      sentBodyHash: value['sentBodyHash'] as String?,
      verifiedAtUtc: _instant(value['verifiedAtUtc']),
      confirmedAtUtc: _instant(value['confirmedAtUtc']),
      localDeletedAtUtc: _instant(value['localDeletedAtUtc']),
      failureCode: value['failureCode'] as String?,
    );
  }
}

/// Status of one import session (BCK-18 §16.1).
enum LocalImportSessionStatus { approved, running, paused, completed, failed }

/// One approved import run: the exact local items the user approved, in
/// order, and the checkpoint (D4 §5.4). The checkpoint advances only after an
/// item's verified receipt is durable.
final class LocalImportSession {
  const LocalImportSession({
    required this.sessionId,
    required this.accountId,
    required this.inventoryHash,
    required this.plannedLocalDraftIds,
    required this.plannedSourceHashes,
    required this.checkpoint,
    required this.status,
    required this.startedAtUtc,
    required this.updatedAtUtc,
  });

  final String sessionId;
  final String accountId;

  /// Hash of the approved dry run (ids, classes and source hashes).
  final String inventoryHash;
  final List<String> plannedLocalDraftIds;

  /// The source hash the user approved for each planned item (same order): an
  /// item that changed since is not imported in this session.
  final List<String> plannedSourceHashes;

  /// Index of the next item to import.
  final int checkpoint;
  final LocalImportSessionStatus status;
  final DateTime startedAtUtc;
  final DateTime updatedAtUtc;

  bool get open =>
      status == LocalImportSessionStatus.approved ||
      status == LocalImportSessionStatus.running ||
      status == LocalImportSessionStatus.paused;

  LocalImportSession copyWith({
    int? checkpoint,
    LocalImportSessionStatus? status,
    DateTime? updatedAtUtc,
  }) => LocalImportSession(
    sessionId: sessionId,
    accountId: accountId,
    inventoryHash: inventoryHash,
    plannedLocalDraftIds: plannedLocalDraftIds,
    plannedSourceHashes: plannedSourceHashes,
    checkpoint: checkpoint ?? this.checkpoint,
    status: status ?? this.status,
    startedAtUtc: startedAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionId': sessionId,
    'accountId': accountId,
    'inventoryHash': inventoryHash,
    'plannedLocalDraftIds': plannedLocalDraftIds,
    'plannedSourceHashes': plannedSourceHashes,
    'checkpoint': checkpoint,
    'status': status.name,
    'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
  };

  static LocalImportSession? fromJson(Object? value) {
    if (value is! Map) return null;
    LocalImportSessionStatus? status;
    for (final LocalImportSessionStatus item
        in LocalImportSessionStatus.values) {
      if (item.name == value['status']) status = item;
    }
    final Object? planned = value['plannedLocalDraftIds'];
    final Object? hashes = value['plannedSourceHashes'];
    final DateTime? started = _instant(value['startedAtUtc']);
    final DateTime? updated = _instant(value['updatedAtUtc']);
    if (_string(value['sessionId']) == null ||
        _string(value['accountId']) == null ||
        _string(value['inventoryHash']) == null ||
        planned is! List ||
        planned.any((Object? id) => id is! String) ||
        hashes is! List ||
        hashes.length != planned.length ||
        hashes.any((Object? hash) => hash is! String) ||
        value['checkpoint'] is! int ||
        status == null ||
        started == null ||
        updated == null) {
      return null;
    }
    final int checkpoint = value['checkpoint']! as int;
    if (checkpoint < 0 || checkpoint > planned.length) return null;
    return LocalImportSession(
      sessionId: value['sessionId']! as String,
      accountId: value['accountId']! as String,
      inventoryHash: value['inventoryHash']! as String,
      plannedLocalDraftIds: List<String>.unmodifiable(planned.cast<String>()),
      plannedSourceHashes: List<String>.unmodifiable(hashes.cast<String>()),
      checkpoint: checkpoint,
      status: status,
      startedAtUtc: started,
      updatedAtUtc: updated,
    );
  }
}

String? _string(Object? value) => value is String ? value : null;

bool _optionalString(Object? value) => value == null || value is String;

DateTime? _instant(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

bool _optionalInstant(Object? value) =>
    value == null || (value is String && DateTime.tryParse(value) != null);
