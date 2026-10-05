import 'create_draft_entity.dart';
import 'find_people_draft_data.dart';
import 'publisher_ref.dart';

/// The publisher stored on a draft, or the draft organizer (personal) for
/// types that carry no typed `PublisherRef` yet (Session, Scenario, Route,
/// Class / Workshop — migration is IDP-03B/04B). Read-only: never rewrites
/// a stored publisher.
extension CreateDraftPublisher on CreateDraftEntity {
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
    if (stored != null && stored.isValid) return stored;
    return PublisherRef(type: PublisherType.user, id: organizerId);
  }
}
