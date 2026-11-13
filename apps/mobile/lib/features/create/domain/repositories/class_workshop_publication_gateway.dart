import '../entities/create_draft_entity.dart';
import '../entities/class_workshop_publication.dart';
import '../entities/publisher_ref.dart';

export 'place_publication_gateway.dart' show ContentDraftReader;

/// The Class / Workshop draft the user is editing in Create, exactly as Create stored it.
abstract interface class ClassWorkshopDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local "my classes" journal (D3.6 §5.6). Records are bound to the account and
/// publisher they were created for; others are kept but never returned here.
abstract interface class ClassWorkshopPublicationJournal {
  Future<List<ClassWorkshopPublicationRecord>> list(String accountId);

  Future<ClassWorkshopPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });

  Future<void> save(ClassWorkshopPublicationRecord record);
}

/// Every command asks it first; the default-off Class / Workshop test entry implements it.
abstract interface class ClassWorkshopPublicationCommandGate {
  bool get allowed;
  void assertAllowed();
}
