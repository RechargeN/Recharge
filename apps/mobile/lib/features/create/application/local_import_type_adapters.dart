import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/usecases/build_activity_content_body.dart';
import '../domain/usecases/build_collection_content_body.dart';
import '../domain/usecases/build_event_content_body.dart';
import '../domain/usecases/build_place_content_body.dart';
import 'place_create_config.dart';

/// Stable ids and keys of one local import (D4 §5.5): UUIDv5 in [namespace]
/// under a scope of the signed-in account, the publisher and the local draft.
/// Upload intents are the import's own, so they never collide with the test
/// publication paths of the same draft.
final class LocalImportScope {
  LocalImportScope({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
  });

  /// D4 §5.5; fixed here and in the tests.
  static const String namespace = 'f0d6a4c1-6b0e-4a3e-9a51-5d2c3e7b8d41';

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;

  String get value =>
      'recharge:local-import:v1:$accountId:'
      '${publisherRef.type.wireName}:${publisherRef.id}:$localDraftId';

  String id(String name) => const Uuid().v5(namespace, '$value:$name');

  /// The Media intent of one exact upload: same attachment, bytes and
  /// attempt, same id. Attempt 0 is the first; a later one exists only after
  /// an earlier attempt's upload session expired unfinished.
  String uploadIntentId(
    String attachmentId,
    String sha256Hex, {
    int attempt = 0,
  }) => attempt == 0
      ? id('upload:$attachmentId:$sha256Hex')
      : id('upload:$attachmentId:$sha256Hex:$attempt');

  /// Prefix of every Content idempotency key of this import.
  String get keyBase =>
      'li1-${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';
}

/// The Content import source key of a local draft (`^loc_[A-Za-z0-9_-]{1,120}$`),
/// or null when the local id cannot be expressed as one.
String? importSourceKeyOf(String localDraftId) {
  final String key = localDraftId.startsWith('loc_')
      ? localDraftId
      : 'loc_$localDraftId';
  return RegExp(r'^loc_[A-Za-z0-9_-]{1,120}$').hasMatch(key) ? key : null;
}

/// One medium of an imported draft: its stable attachment id and local file.
final class LocalImportAttachment {
  const LocalImportAttachment({
    required this.attachmentId,
    required this.localRef,
  });

  final String attachmentId;
  final String localRef;
}

/// How the import maps one Create type to its Content body (D4 §5.2). Each
/// adapter wraps the type's existing mapper of the test publication path, so
/// derived ids (periods, items, sections) are those of that path; it adds no
/// rule of its own.
abstract interface class LocalImportTypeAdapter {
  String get typeId;
  CreateObjectType get objectType;
  PublisherRef? publisherOf(CreateDraftEntity draft);

  /// Parts of the draft the server cannot hold; a non-empty list is never sent.
  List<String> unsupported(CreateDraftEntity draft, LocalImportScope scope);
  List<LocalImportAttachment> attachments(
    CreateDraftEntity draft,
    LocalImportScope scope,
  );

  /// [serverOwnerUserId] is the author the server recorded ('' in the dry
  /// run); [reviewedRevision] the server revision the save will produce.
  Map<String, Object?> body(
    CreateDraftEntity draft, {
    required LocalImportScope scope,
    required String serverOwnerUserId,
    required int reviewedRevision,
    required Map<String, String> assetIds,
  });
}

/// The four Create types the server can hold as drafts in this pass.
final Map<CreateObjectType, LocalImportTypeAdapter> localImportAdapters =
    Map<CreateObjectType, LocalImportTypeAdapter>.unmodifiable(
      <CreateObjectType, LocalImportTypeAdapter>{
        CreateObjectType.event: const _EventAdapter(),
        CreateObjectType.place: const _PlaceAdapter(),
        CreateObjectType.activity: const _ActivityAdapter(),
        CreateObjectType.collection: const _CollectionAdapter(),
      },
    );

final class _EventAdapter implements LocalImportTypeAdapter {
  const _EventAdapter();

  static const EventContentBodyMapper _mapper = EventContentBodyMapper();

  @override
  String get typeId => 'event';

  @override
  CreateObjectType get objectType => CreateObjectType.event;

  @override
  PublisherRef? publisherOf(CreateDraftEntity draft) =>
      draft.eventData?.publisherRef;

  @override
  List<String> unsupported(CreateDraftEntity draft, LocalImportScope scope) =>
      _mapper.map(draft).unsupported;

  @override
  List<LocalImportAttachment> attachments(
    CreateDraftEntity draft,
    LocalImportScope scope,
  ) => <LocalImportAttachment>[
    if (draft.media.coverImage.trim().isNotEmpty)
      LocalImportAttachment(
        attachmentId: scope.id('attachment:cover'),
        localRef: draft.media.coverImage,
      ),
  ];

  @override
  Map<String, Object?> body(
    CreateDraftEntity draft, {
    required LocalImportScope scope,
    required String serverOwnerUserId,
    required int reviewedRevision,
    required Map<String, String> assetIds,
  }) => _mapper
      .map(draft, coverMediaId: assetIds[scope.id('attachment:cover')])
      .body;
}

final class _PlaceAdapter implements LocalImportTypeAdapter {
  const _PlaceAdapter();

  static const PlaceContentBodyMapper _mapper = PlaceContentBodyMapper();

  @override
  String get typeId => 'place';

  @override
  CreateObjectType get objectType => CreateObjectType.place;

  @override
  PublisherRef? publisherOf(CreateDraftEntity draft) =>
      draft.placeData?.publisherRef;

  PlacePublicationScope _scope(CreateDraftEntity draft, LocalImportScope s) =>
      PlacePublicationScope(
        accountId: s.accountId,
        publisherRef: s.publisherRef,
        localDraftId: draft.id,
      );

  PlaceContentBody _map(
    CreateDraftEntity draft,
    LocalImportScope scope, {
    String owner = '',
    Map<String, String> assetIds = const <String, String>{},
  }) => _mapper.map(
    draft,
    scope: _scope(draft, scope),
    policy: placeCreationPolicyFor(draft.subcategory),
    serverOwnerUserId: owner,
    assetIds: assetIds,
  );

  @override
  List<String> unsupported(CreateDraftEntity draft, LocalImportScope scope) =>
      _map(draft, scope).unsupported;

  @override
  List<LocalImportAttachment> attachments(
    CreateDraftEntity draft,
    LocalImportScope scope,
  ) => <LocalImportAttachment>[
    for (final PlaceMediaAttachment item in _mapper.attachmentsOf(
      draft,
      _scope(draft, scope),
    ))
      LocalImportAttachment(
        attachmentId: item.attachmentId,
        localRef: item.localRef,
      ),
  ];

  @override
  Map<String, Object?> body(
    CreateDraftEntity draft, {
    required LocalImportScope scope,
    required String serverOwnerUserId,
    required int reviewedRevision,
    required Map<String, String> assetIds,
  }) => _map(draft, scope, owner: serverOwnerUserId, assetIds: assetIds).body;
}

final class _ActivityAdapter implements LocalImportTypeAdapter {
  const _ActivityAdapter();

  // A linked Place is never imported (fail closed, D3.2 §2.4).
  static const ActivityContentBodyMapper _mapper = ActivityContentBodyMapper();

  @override
  String get typeId => 'activity';

  @override
  CreateObjectType get objectType => CreateObjectType.activity;

  @override
  PublisherRef? publisherOf(CreateDraftEntity draft) =>
      draft.activityData?.publisherRef;

  ActivityPublicationScope _scope(
    CreateDraftEntity draft,
    LocalImportScope s,
  ) => ActivityPublicationScope(
    accountId: s.accountId,
    publisherRef: s.publisherRef,
    localDraftId: draft.id,
  );

  @override
  List<String> unsupported(CreateDraftEntity draft, LocalImportScope scope) =>
      _mapper.map(draft, scope: _scope(draft, scope)).unsupported;

  @override
  List<LocalImportAttachment> attachments(
    CreateDraftEntity draft,
    LocalImportScope scope,
  ) => <LocalImportAttachment>[
    for (final ActivityMediaAttachment item in _mapper.attachmentsOf(
      draft,
      _scope(draft, scope),
    ))
      LocalImportAttachment(
        attachmentId: item.attachmentId,
        localRef: item.localRef,
      ),
  ];

  @override
  Map<String, Object?> body(
    CreateDraftEntity draft, {
    required LocalImportScope scope,
    required String serverOwnerUserId,
    required int reviewedRevision,
    required Map<String, String> assetIds,
  }) =>
      _mapper.map(draft, scope: _scope(draft, scope), assetIds: assetIds).body;
}

final class _CollectionAdapter implements LocalImportTypeAdapter {
  const _CollectionAdapter();

  static const CollectionContentBodyMapper _mapper =
      CollectionContentBodyMapper();

  @override
  String get typeId => 'collection';

  @override
  CreateObjectType get objectType => CreateObjectType.collection;

  @override
  PublisherRef? publisherOf(CreateDraftEntity draft) =>
      draft.collectionData?.publisherRef;

  CollectionPublicationScope _scope(
    CreateDraftEntity draft,
    LocalImportScope s,
  ) => CollectionPublicationScope(
    accountId: s.accountId,
    publisherRef: s.publisherRef,
    localDraftId: draft.id,
  );

  @override
  List<String> unsupported(CreateDraftEntity draft, LocalImportScope scope) =>
      _mapper
          .map(draft, scope: _scope(draft, scope), reviewedRevision: 0)
          .unsupported;

  @override
  List<LocalImportAttachment> attachments(
    CreateDraftEntity draft,
    LocalImportScope scope,
  ) => <LocalImportAttachment>[
    for (final CollectionMediaAttachment item in _mapper.attachmentsOf(
      draft,
      _scope(draft, scope),
    ))
      LocalImportAttachment(
        attachmentId: item.attachmentId,
        localRef: item.localRef,
      ),
  ];

  @override
  Map<String, Object?> body(
    CreateDraftEntity draft, {
    required LocalImportScope scope,
    required String serverOwnerUserId,
    required int reviewedRevision,
    required Map<String, String> assetIds,
  }) => _mapper
      .map(
        draft,
        scope: _scope(draft, scope),
        reviewedRevision: reviewedRevision,
        assetIds: assetIds,
      )
      .body;
}
