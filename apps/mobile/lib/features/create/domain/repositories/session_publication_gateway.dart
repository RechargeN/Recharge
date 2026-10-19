import '../entities/create_draft_entity.dart';
import '../entities/session_publication.dart';
import '../entities/publisher_ref.dart';

export 'place_publication_gateway.dart' show ContentDraftReader;

/// The Session draft the user is editing in Create, exactly as Create stored it.
abstract interface class SessionDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local "my sessions" journal (D3.5 §5.6). Records are bound to the account and
/// publisher they were created for; others are kept but never returned here.
abstract interface class SessionPublicationJournal {
  Future<List<SessionPublicationRecord>> list(String accountId);

  Future<SessionPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });

  Future<void> save(SessionPublicationRecord record);
}

/// Every command asks it first; the default-off Session test entry implements it.
abstract interface class SessionPublicationCommandGate {
  bool get allowed;
  void assertAllowed();
}
