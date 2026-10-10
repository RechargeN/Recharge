import '../entities/activity_publication.dart';
import '../entities/create_draft_entity.dart';
import '../entities/publisher_ref.dart';

/// The Activity draft the user is editing in Create, exactly as Create stored
/// it.
abstract interface class ActivityDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local "my activities" journal (D3.2 §5.6). Records are bound to the account
/// and publisher they were created for; others are kept but never returned
/// here.
abstract interface class ActivityPublicationJournal {
  Future<List<ActivityPublicationRecord>> list(String accountId);

  Future<ActivityPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });

  Future<void> save(ActivityPublicationRecord record);
}

/// Every command asks it first; the default-off Activity test entry
/// implements it.
abstract interface class ActivityPublicationCommandGate {
  bool get allowed;
  void assertAllowed();
}
