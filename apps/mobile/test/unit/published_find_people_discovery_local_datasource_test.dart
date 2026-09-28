import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/published_find_people_discovery_local_datasource.dart';
import 'package:recharge/features/discover/data/repositories/find_people_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/published_find_people_discovery_entity.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

void main() {
  final PublishedFindPeopleDiscoveryLocalDataSource datasource =
      PublishedFindPeopleDiscoveryLocalDataSource();

  test('returns the allowlisted active public fixture', () async {
    final PublishedFindPeopleDiscoveryEntity? projection = await datasource
        .getActiveFindPeopleRequest(
          PublishedFindPeopleDiscoveryLocalDataSource.morningRunRequestId,
        );
    expect(projection, isNotNull);
    expect(projection!.publicLocation, isA<PublishedFindPeoplePointLocation>());
  });

  test('unknown id fails closed', () async {
    expect(await datasource.getActiveFindPeopleRequest('missing'), isNull);
  });

  test('lookup classifies only Find People', () async {
    final FindPeopleDetailsLookup lookup = FindPeopleDetailsLookup(datasource);
    final Object? projection = await lookup.lookup(
      PublishedFindPeopleDiscoveryLocalDataSource.morningRunRequestId,
    );
    expect(projection, isA<PublishedFindPeopleDiscoveryEntity>());
    expect(lookup.classify(projection!), CatalogObjectType.findPeople);
  });
}
