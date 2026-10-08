import 'dart:typed_data';

import '../entities/create_draft_entity.dart';
import '../entities/event_publication.dart';
import '../entities/publisher_ref.dart';

/// Owner commands and queries of the Content service for one Event. Every
/// call is authorized on the server (Session, verified Creator, exact Page);
/// failures are [EventPublicationRejected] or [EventPublicationUnavailable].
abstract interface class EventPublicationGateway {
  Future<EventServerDraftRef> createDraft({
    required PublisherRef publisherRef,
    required String marketId,
    required Map<String, Object?> body,
    required String idempotencyKey,
  });

  Future<EventServerDraftRef> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  });

  /// Returns the submission id.
  Future<String> submit({
    required String draftId,
    required int expectedDraftRevision,
    required String idempotencyKey,
  });

  Future<void> publishApproved({
    required String submissionId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  });

  /// The owner's own hide (`withdrawPublication`, mode `withdraw`).
  Future<void> withdraw({
    required String contentId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  });

  Future<EventPublicationStatus> status(String contentId);
}

/// Media upload of the Event cover, bound to the exact Content draft.
abstract interface class EventCoverUploader {
  /// Returns the ready Media asset id.
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  });
}

/// The Event draft the user is editing in Create, exactly as Create stored it.
abstract interface class EventDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Reads the bytes of the cover the Create draft refers to.
abstract interface class EventCoverSource {
  Future<Uint8List?> read(String reference);
}

/// Local "my objects" journal: ids of the objects created from this install.
abstract interface class EventPublicationJournal {
  Future<List<EventPublicationRecord>> list();
  Future<EventPublicationRecord?> forLocalDraft(String localDraftId);
  Future<void> save(EventPublicationRecord record);
}

/// Every command asks it first; the default-off test entry implements it.
abstract interface class EventPublicationCommandGate {
  bool get allowed;
  void assertAllowed();
}
