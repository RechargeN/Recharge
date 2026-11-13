import '../entities/create_draft_entity.dart';
import '../entities/find_people_publication.dart';
import '../entities/publisher_ref.dart';

export 'place_publication_gateway.dart' show ContentDraftReader;

/// The Find People draft the user is editing in Create, exactly as Create stored it.
abstract interface class FindPeopleDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local "my Find People requests" journal (D3.7). Records are bound to the
/// account and publisher they were created for; others are kept but never
/// returned here.
abstract interface class FindPeoplePublicationJournal {
  Future<List<FindPeoplePublicationRecord>> list(String accountId);

  Future<FindPeoplePublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  });

  Future<void> save(FindPeoplePublicationRecord record);
}

/// BCK-06 consent commands of the signed-in author (D3.7 §5.1). The subject is
/// always the server's Session user; the client never names it.
abstract interface class FindPeopleConsentGateway {
  /// The author's consent for [contentId], or null when never granted.
  Future<FindPeopleConsentView?> consent(String contentId);

  Future<FindPeopleConsentView> grant({
    required String contentId,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<FindPeopleConsentView> revoke({
    required String contentId,
    required int expectedRevision,
    required String idempotencyKey,
  });
}

/// Every command asks it first; the default-off Find People test entry implements it.
abstract interface class FindPeoplePublicationCommandGate {
  bool get allowed;
  void assertAllowed();
}
