import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recharge/features/create/data/datasources/google_places_search_datasource.dart';
import 'package:recharge/features/create/domain/entities/location_search_suggestion.dart';
import 'package:recharge/features/create/domain/repositories/location_search_repository.dart';
import 'package:recharge/features/create/domain/usecases/search_location_suggestions_usecase.dart';

/// LOC-SRCH-01 (Review triage 2026-11-13): the search path had no tests.
/// Minimum query length, the Places (New) REST contract and degradation to
/// empty results on every failure; never an exception for Create.
class _CountingRepository implements LocationSearchRepository {
  final List<String> queries = <String>[];

  @override
  Future<List<LocationSearchSuggestion>> search(
    String query, {
    required String marketCityId,
  }) async {
    queries.add('$marketCityId:$query');
    return <LocationSearchSuggestion>[
      LocationSearchSuggestion(id: 'p1', primaryText: query),
    ];
  }

  @override
  Future<LocationSearchResolution> resolve(String suggestionId) async =>
      const LocationSearchResolution(
        formattedAddress: 'Riga',
        latitude: 56.95,
        longitude: 24.1,
      );
}

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

void main() {
  test('short queries never reach the provider; the rest is trimmed', () async {
    final _CountingRepository repository = _CountingRepository();
    final SearchLocationSuggestionsUseCase search =
        SearchLocationSuggestionsUseCase(repository);
    expect(await search('  ab ', marketCityId: 'riga'), isEmpty);
    expect(repository.queries, isEmpty);
    final List<LocationSearchSuggestion> found = await search(
      '  Doms  ',
      marketCityId: 'riga',
    );
    expect(repository.queries, <String>['riga:Doms']);
    expect(found.single.primaryText, 'Doms');
  });

  test('autocomplete: key header, structured text, text fallback', () async {
    late http.Request seen;
    final GooglePlacesSearchDatasource datasource =
        GooglePlacesSearchDatasource(
          client: MockClient((http.Request request) async {
            seen = request;
            return _json(<String, Object?>{
              'suggestions': <Object?>[
                <String, Object?>{
                  'placePrediction': <String, Object?>{
                    'placeId': 'a',
                    'structuredFormat': <String, Object?>{
                      'mainText': <String, Object?>{'text': 'Riga Cathedral'},
                      'secondaryText': <String, Object?>{
                        'text': 'Riga, Latvia',
                      },
                    },
                  },
                },
                <String, Object?>{
                  'placePrediction': <String, Object?>{
                    'placeId': 'b',
                    'text': <String, Object?>{'text': 'Freedom Monument'},
                  },
                },
                <String, Object?>{'queryPrediction': <String, Object?>{}},
                <String, Object?>{
                  'placePrediction': <String, Object?>{'placeId': ''},
                },
              ],
            });
          }),
          apiKey: 'test-key',
        );
    final List<LocationSearchSuggestion> found = await datasource.autocomplete(
      'riga',
    );
    expect(seen.method, 'POST');
    expect(seen.url.path, '/v1/places:autocomplete');
    expect(seen.headers['X-Goog-Api-Key'], 'test-key');
    expect(jsonDecode(seen.body), <String, Object?>{'input': 'riga'});
    expect(found.map((s) => s.id), <String>['a', 'b']);
    expect(found.first.primaryText, 'Riga Cathedral');
    expect(found.first.secondaryText, 'Riga, Latvia');
    expect(found.last.primaryText, 'Freedom Monument');
  });

  test('every failure degrades to empty or null, never throws', () async {
    var calls = 0;
    final GooglePlacesSearchDatasource unconfigured =
        GooglePlacesSearchDatasource(
          client: MockClient((_) async {
            calls += 1;
            return _json(<String, Object?>{});
          }),
          apiKey: '',
        );
    expect(await unconfigured.autocomplete('riga'), isEmpty);
    expect(await unconfigured.placeDetails('a'), isNull);
    expect(calls, 0, reason: 'no key, no request');

    for (final MockClient client in <MockClient>[
      MockClient((_) async => _json(<String, Object?>{}, status: 403)),
      MockClient((_) async => http.Response('not json', 200)),
      MockClient((_) async => _json(<Object?>[])),
      MockClient((_) async => throw const SocketExceptionLike()),
    ]) {
      final GooglePlacesSearchDatasource datasource =
          GooglePlacesSearchDatasource(client: client, apiKey: 'k');
      expect(await datasource.autocomplete('riga'), isEmpty);
      expect(await datasource.placeDetails('a'), isNull);
    }
  });

  test('place details: field mask, point and address', () async {
    late http.Request seen;
    final GooglePlacesSearchDatasource datasource =
        GooglePlacesSearchDatasource(
          client: MockClient((http.Request request) async {
            seen = request;
            return _json(<String, Object?>{
              'formattedAddress': 'Doma laukums 1, Riga',
              'location': <String, Object?>{
                'latitude': 56.949,
                'longitude': 24.104,
              },
            });
          }),
          apiKey: 'k',
        );
    final details = await datasource.placeDetails('abc');
    expect(seen.url.path, '/v1/places/abc');
    expect(seen.headers['X-Goog-FieldMask'], 'formattedAddress,location');
    expect(details?.formattedAddress, 'Doma laukums 1, Riga');
    expect(details?.latitude, 56.949);
    expect(details?.longitude, 24.104);
  });
}

/// A transport failure without dart:io (tests run on every platform).
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
