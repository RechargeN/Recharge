import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/collection_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

void main() {
  test('defaults() has no collectionData', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'u',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    );
    expect(draft.collectionData, isNull);
  });

  test('copyWith sets collectionData; clearCollectionData nulls it back out', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'u',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    );
    final CollectionDraftData collection = CollectionDraftData.defaults(
      publisherRef: const PublisherRef(type: PublisherType.user, id: 'u'),
    );
    final CreateDraftEntity withCollection = draft.copyWith(
      objectType: CreateObjectType.collection,
      collectionData: collection,
    );
    expect(withCollection.collectionData, same(collection));
    final CreateDraftEntity cleared = withCollection.copyWith(
      clearCollectionData: true,
    );
    expect(cleared.collectionData, isNull);
  });

  test('CreateObjectType.collection round-trips through taxonomy id', () {
    expect(CreateObjectType.collection.taxonomyId, 'collection');
    expect(createObjectTypeFromId('collection'), CreateObjectType.collection);
  });
}
