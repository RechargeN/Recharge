import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/place_enrichment_coordinator.dart';
import 'package:recharge/features/create/data/datasources/place_enrichment_mock_datasource.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/generate_place_enrichment_proposal_usecase.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/place_create_block.dart';

import '../support/event_create_test_support.dart';
import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets(
    'adapts landmark fields and keeps local AI suggestions explicit',
    (WidgetTester tester) async {
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
      );
      addTearDown(controller.dispose);
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
      controller.updateTitle('Памятник Свободы');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) {
                return SingleChildScrollView(
                  child: PlaceCreateBlock(
                    controller: controller,
                    state: controller.state,
                    onPublished: () {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1/3 • About'), findsOneWidget);
      expect(find.text('Finish with AI'), findsOneWidget);
      expect(find.text('Local demo'), findsOneWidget);
      expect(find.text('Simple point of interest'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Description (recommended)'),
        findsOneWidget,
      );
      expect(find.text('Place type'), findsNothing);
      expect(find.text('Short description *'), findsNothing);
      expect(find.text('Full description *'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('generate-place-assist')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggested category'), findsOneWidget);
      expect(find.textContaining('monument in Riga'), findsOneWidget);
      expect(find.text('Apply suggestions'), findsOneWidget);
      expect(controller.state.draft.shortDescription, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('apply-place-assist')),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(controller.state.draft.subcategory, 'monument');
      expect(controller.state.draft.shortDescription, isNotEmpty);
      expect(controller.state.placeEnrichmentProposal, isNull);
    },
  );
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
