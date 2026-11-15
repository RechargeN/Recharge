import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/location_search_config.dart';
import 'package:recharge/features/create/application/place_enrichment_coordinator.dart';
import 'package:recharge/features/create/data/datasources/place_enrichment_mock_datasource.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/location_search_suggestion.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/location_search_repository.dart';
import 'package:recharge/features/create/domain/usecases/generate_place_enrichment_proposal_usecase.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/place_create_block.dart';

import '../support/event_create_test_support.dart';
import 'widget_test_viewport.dart';

/// LOC-SRCH-01 (Review triage 2026-11-13): typing in the Place name searches
/// once per pause (350 ms debounce), never per keystroke; a late answer to an
/// older query never replaces the newer one; the rollback flag stops search.
class _ScriptedSearch implements LocationSearchRepository {
  final List<String> queries = <String>[];
  final Map<String, Completer<List<LocationSearchSuggestion>>> pending =
      <String, Completer<List<LocationSearchSuggestion>>>{};
  bool deferred = false;

  @override
  Future<List<LocationSearchSuggestion>> search(
    String query, {
    required String marketCityId,
  }) {
    queries.add(query);
    final List<LocationSearchSuggestion> answer = <LocationSearchSuggestion>[
      LocationSearchSuggestion(id: 'id-$query', primaryText: 'hit $query'),
    ];
    if (!deferred) return Future<List<LocationSearchSuggestion>>.value(answer);
    final Completer<List<LocationSearchSuggestion>> completer =
        Completer<List<LocationSearchSuggestion>>();
    pending[query] = completer;
    return completer.future;
  }

  @override
  Future<LocationSearchResolution> resolve(String suggestionId) async =>
      const LocationSearchResolution(
        formattedAddress: 'Riga',
        latitude: 56.95,
        longitude: 24.1,
      );
}

Future<CreateController> _placeController(
  LocationSearchRepository search, {
  bool enabled = true,
}) async {
  final _MemoryRepository repository = _MemoryRepository();
  final CreateController controller = CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
    analyticsService: _NoopAnalyticsService(),
    eventCreateCoordinator: createTestEventCoordinator(),
    placeEnrichmentCoordinator: PlaceEnrichmentCoordinator(
      generateProposal: GeneratePlaceEnrichmentProposalUseCase(
        MockPlaceEnrichmentDataSource(),
      ),
    ),
    runtimeDefaults: const CreateRuntimeDefaults(
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    ),
    locationSearchRepository: search,
    locationSearchConfig: LocationSearchRuntimeConfig(enabled: enabled),
  );
  await controller.ensureLoaded(
    userId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'Creator',
    capabilities: const <String>['create.place'],
  );
  controller.setObjectType(CreateObjectType.place);
  controller.applyTaxonomySelection(
    mainCategory: 'art_culture_museums',
    subcategory: 'monument',
  );
  return controller;
}

void main() {
  fullPageTestWidgets('one search per pause, with the last text', (
    WidgetTester tester,
  ) async {
    final _ScriptedSearch search = _ScriptedSearch();
    final CreateController controller = await _placeController(search);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? child) =>
                SingleChildScrollView(
                  child: PlaceCreateBlock(
                    controller: controller,
                    state: controller.state,
                    onPublished: () {},
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Finder name = find.widgetWithText(TextField, 'Place name *');

    await tester.enterText(name, 'Rig');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(name, 'Riga Dom');
    await tester.pump(const Duration(milliseconds: 349));
    expect(search.queries, isEmpty, reason: 'still inside the pause');
    await tester.pump(const Duration(milliseconds: 1));
    expect(search.queries, <String>['Riga Dom']);
    await tester.pumpAndSettle();
    expect(find.text('hit Riga Dom'), findsOneWidget);

    // Clearing the name drops the suggestions without a search.
    await tester.enterText(name, '');
    await tester.pump(const Duration(milliseconds: 400));
    expect(search.queries, <String>['Riga Dom']);
    expect(controller.state.placeLocationSuggestions, isEmpty);

    // Let the draft autosave timer run out.
    await tester.pump(const Duration(seconds: 2));
  });

  test(
    'a late answer to an older query never replaces the newer one',
    () async {
      final _ScriptedSearch search = _ScriptedSearch()..deferred = true;
      final CreateController controller = await _placeController(search);
      addTearDown(controller.dispose);
      final Future<void> first = controller.searchPlaceLocation('Riga');
      final Future<void> second = controller.searchPlaceLocation('Riga Dom');
      search.pending['Riga Dom']!.complete(<LocationSearchSuggestion>[
        const LocationSearchSuggestion(id: 'new', primaryText: 'newer'),
      ]);
      await second;
      search.pending['Riga']!.complete(<LocationSearchSuggestion>[
        const LocationSearchSuggestion(id: 'old', primaryText: 'older'),
      ]);
      await first;
      expect(
        controller.state.placeLocationSuggestions.map((s) => s.id),
        <String>['new'],
      );
      expect(controller.state.placeLocationSearchLoading, isFalse);
    },
  );

  test('the rollback flag stops search; the map tap stays', () async {
    final _ScriptedSearch search = _ScriptedSearch();
    final CreateController controller = await _placeController(
      search,
      enabled: false,
    );
    addTearDown(controller.dispose);
    await controller.searchPlaceLocation('Riga Dom');
    expect(search.queries, isEmpty);
    expect(controller.state.placeLocationSuggestions, isEmpty);
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _MemoryRepository implements CreateRepository {
  CreateDraftEntity? stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    stored = draft;
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    stored = draft;
    return draft;
  }
}
