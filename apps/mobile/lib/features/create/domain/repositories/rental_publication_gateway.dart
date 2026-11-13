import '../entities/create_draft_entity.dart';
import '../entities/publisher_ref.dart';
import '../entities/rental_publication.dart';

/// The Rental draft the user is editing in Create, exactly as Create stored it.
abstract interface class RentalDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local "my rentals" journal (D3.3 §4). Records are bound to the account and
/// publisher they were created for; others are kept but never returned here.
abstract interface class RentalPublicationJournal {
  Future<List<RentalPublicationRecord>> list(String accountId);

  Future<RentalPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });

  Future<void> save(RentalPublicationRecord record);
}

/// Every command asks it first; the default-off Rental test entry implements it.
abstract interface class RentalPublicationCommandGate {
  bool get allowed;
  void assertAllowed();
}
