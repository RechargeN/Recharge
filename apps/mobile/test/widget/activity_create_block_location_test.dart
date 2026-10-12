import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/activity_place_link_controller.dart';
import 'package:recharge/features/create/domain/repositories/activity_place_link_repository.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/activity_create_block.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets(
    'shows the informal-access note field only when the caution switch is on',
    (WidgetTester tester) async {
      final _MemoryRepository repository = _MemoryRepository();
      final CreateController controller = CreateController(
        loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
        saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
        publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
        analyticsService: _NoopAnalyticsService(),
        eventCreateCoordinator: createTestEventCoordinator(),
        runtimeDefaults: const CreateRuntimeDefaults(
          marketCityId: 'riga',
          timezone: 'Europe/Riga',
          country: 'LV',
          city: 'Riga',
          currency: 'EUR',
        ),
      );
      addTearDown(controller.dispose);
      final picker = ActivityPlaceLinkController(_PlaceRepository());
      addTearDown(picker.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
      );
      controller.setObjectType(CreateObjectType.activity);
      controller.updateTitle('Hidden viewpoint');
      controller.updateShortDescription(
        'A quiet, lesser-known viewpoint with a great sunset view.',
      );
      controller.updateCoverImage('cover.jpg');
      final bool advanced = await controller.goToActivityStep(1);
      expect(advanced, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (BuildContext context, Widget? child) {
                return SingleChildScrollView(
                  child: ActivityCreateBlock(
                    placeLinks: picker,
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

      expect(find.text('Access notes'), findsOneWidget);
      expect(find.text('This is not an official spot'), findsOneWidget);
      expect(find.text('What to know before you go'), findsNothing);

      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      expect(find.text('What to know before you go'), findsOneWidget);

      await tester.ensureVisible(find.text('Search Places'));
      await tester.tap(find.text('Search Places'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Published park'));
      await tester.tap(find.text('Published park'));
      await tester.pumpAndSettle();
      expect(
        controller.state.draft.activityData!.location.linkedPlaceId,
        _PlaceRepository.place.id,
      );
      await tester.ensureVisible(find.text('Remove linked Place'));
      await tester.tap(find.text('Remove linked Place'));
      await tester.pumpAndSettle();
      expect(
        controller.state.draft.activityData!.location.linkedPlaceId,
        isNull,
      );
      expect(controller.state.draft.title, 'Hidden viewpoint');
      // Flush the 700ms autosave timer so no pending Timer remains at test end.
      await tester.pump(const Duration(milliseconds: 800));
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

class _PlaceRepository implements ActivityPlaceLinkRepository {
  static const place = ActivityPlaceCandidate(
    id: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
    title: 'Published park',
    publishedRevisionId: '01ARZ3NDEKTSV4RRFFQ69G5FAW',
    pointerRevision: 1,
  );
  @override
  Future<ActivityPlaceResolution> resolve(String id) async =>
      const ActivityPlaceResolution('eligible', place);
  @override
  Future<ActivityPlacePage> candidates(String text, {String? after}) async =>
      const ActivityPlacePage(available: true, items: [place]);
}
