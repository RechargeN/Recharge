import 'create_draft_entity.dart';
import 'find_people_draft_data.dart';
import 'publisher_ref.dart';

/// Canonical local publisher reader. Workspace is deliberately not an input.
extension CreateDraftPublisher on CreateDraftEntity {
  bool get publisherSelectionRequired => !effectivePublisher.isValid;

  PublisherRef get effectivePublisher {
    final PublisherRef? stored = switch (objectType) {
      CreateObjectType.event => eventData?.publisherRef,
      CreateObjectType.place => placeData?.publisherRef,
      CreateObjectType.activity => activityData?.publisherRef,
      CreateObjectType.rental => rentalData?.publisherRef,
      CreateObjectType.collection => collectionData?.publisherRef,
      CreateObjectType.findPeople when findPeopleData != null => PublisherRef(
        type: findPeopleData!.publisherType == FindPeoplePublisherType.page
            ? PublisherType.page
            : PublisherType.user,
        id: findPeopleData!.publisherId,
      ),
      _ => null,
    };
    if (publisherEnvelope != null || publisherRef != null) {
      final ref = publisherRef;
      if (ref == null || !ref.isValid) return _missingPublisher;
      // A forged/mismatched compatibility block cannot publish under a different identity.
      if (stored != null && stored.isValid && stored != ref) {
        return _missingPublisher;
      }
      return ref;
    }
    if (stored != null && stored.isValid) return stored;
    return _missingPublisher;
  }
}

const PublisherRef _missingPublisher = PublisherRef(
  type: PublisherType.user,
  id: '',
);
