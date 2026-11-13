import '../entities/collection_content_publication.dart';
import '../entities/collection_item_draft.dart';
import '../entities/create_draft_entity.dart';
import '../entities/publisher_ref.dart';

/// The Collection draft the user is editing in Create, exactly as Create
/// stored it.
abstract interface class CollectionDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local "my collections" journal (D3.4 §5.6). Records are bound to the
/// account and publisher they were created for; others are kept but never
/// returned here.
abstract interface class CollectionPublicationJournal {
  Future<List<CollectionPublicationRecord>> list(String accountId);

  Future<CollectionPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });

  Future<void> save(CollectionPublicationRecord record);
}

/// Exact-id status of the objects a Collection references, as the server's
/// Catalog-owned evaluator answers it (D3.4 §2.3). Display only: the server
/// re-reads it at submit, publish and activation.
abstract interface class CollectionMembershipReader {
  Future<CollectionMemberStatus> statusOf(CollectionObjectRef ref);
}

/// Every command asks it first; the default-off Collection test entry
/// implements it.
abstract interface class CollectionPublicationCommandGate {
  bool get allowed;
  void assertAllowed();
}
