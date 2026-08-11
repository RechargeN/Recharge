import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/scenario_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/create_draft_collection_repository.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_by_id_usecase.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../support/event_create_test_support.dart';

void main() {
  test('Create opens only the exact owned Scenario id from intake', () async {
    final repository = _Repository(<String, CreateDraftEntity>{
      'scenario-a': _scenario(id: 'scenario-a', title: 'First'),
      'scenario-b': _scenario(id: 'scenario-b', title: 'Chosen'),
    });
    final controller = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      loadCreateDraftByIdUseCase: LoadCreateDraftByIdUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: _Analytics(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.test',
      organizerName: 'User',
    );

    final opened = await controller.openScenarioDraftById(
      userId: 'user-1',
      draftId: 'scenario-b',
    );

    expect(opened, isTrue);
    expect(controller.state.draft.id, 'scenario-b');
    expect(controller.state.draft.title, 'Chosen');
    expect(controller.state.scenarioStep, 1);
    controller.dispose();
  });

  test('foreign or non-Scenario exact id fails closed', () async {
    final repository = _Repository(<String, CreateDraftEntity>{
      'foreign': _scenario(id: 'foreign', title: 'Foreign', ownerId: 'user-2'),
      'event-1': _scenario(
        id: 'event-1',
        title: 'Event',
      ).copyWith(objectType: CreateObjectType.event, clearScenarioData: true),
    });
    final controller = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      loadCreateDraftByIdUseCase: LoadCreateDraftByIdUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: _Analytics(),
      eventCreateCoordinator: createTestEventCoordinator(),
    );
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.test',
      organizerName: 'User',
    );

    expect(
      await controller.openScenarioDraftById(
        userId: 'user-1',
        draftId: 'foreign',
      ),
      isFalse,
    );
    expect(
      await controller.openScenarioDraftById(
        userId: 'user-1',
        draftId: 'event-1',
      ),
      isFalse,
    );
    expect(controller.state.message, 'Scenario is no longer available.');
    controller.dispose();
  });
}

CreateDraftEntity _scenario({
  required String id,
  required String title,
  String ownerId = 'user-1',
}) =>
    CreateDraftEntity.defaults(
      organizerId: ownerId,
      organizerEmail: '$ownerId@example.test',
      organizerName: 'Owner',
      timezone: 'Europe/Riga',
      currency: 'EUR',
    ).copyWith(
      id: id,
      objectType: CreateObjectType.scenario,
      title: title,
      clearEventData: true,
      scenarioData: ScenarioDraftData.defaults(),
      visibility: VisibilityType.private,
    );

class _Repository implements CreateRepository, CreateDraftCollectionRepository {
  _Repository(this.drafts);

  final Map<String, CreateDraftEntity> drafts;
  CreateDraftEntity? singleton;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => singleton;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    singleton = draft;
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async => draft;

  @override
  Future<CreateDraftEntity?> loadDraftById({
    required String ownerId,
    required String draftId,
  }) async => drafts[draftId];

  @override
  Future<List<CreateDraftSummary>> listDrafts({
    required String ownerId,
    required CreateObjectType type,
  }) async => const <CreateDraftSummary>[];

  @override
  Future<CreateDraftCollectionSaveResult> saveIfRevision({
    required String ownerId,
    required CreateDraftEntity draft,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) async => throw UnimplementedError();
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
