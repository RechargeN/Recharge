import '../entities/create_draft_entity.dart';
import '../entities/event_publication.dart';
import '../entities/place_publication.dart';
import '../entities/publisher_ref.dart';

/// The owner's read of one Content draft: its revision and the author the
/// server recorded. Used to recover a save and to recognise a foreign record.
abstract interface class ContentDraftReader {
  Future<EventServerDraftRef> draft(String draftId);
}

/// The Place draft the user is editing in Create, exactly as Create stored it.
abstract interface class PlaceDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local "my places" journal (D3.1 §5.6). Records are bound to the account and
/// publisher they were created for; others are kept but never returned here.
abstract interface class PlacePublicationJournal {
  Future<List<PlacePublicationRecord>> list(String accountId);

  Future<PlacePublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });

  Future<void> save(PlacePublicationRecord record);
}

/// Every command asks it first; the default-off Place test entry implements it.
abstract interface class PlacePublicationCommandGate {
  bool get allowed;
  void assertAllowed();
}
