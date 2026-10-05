import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../support/event_create_test_support.dart';

const PublisherRef _page = PublisherRef(type: PublisherType.page, id: 'page-1');
const PublisherRef _user = PublisherRef(type: PublisherType.user, id: 'user-1');

void main() {
  group('IDP-04A new-draft publisher defaults', () {
    test('Place and Activity capture the active Page', () async {
      final CreateController controller = await _loaded(_page);
      addTearDown(controller.dispose);

      controller.setObjectType(CreateObjectType.place);
      expect(controller.state.draft.placeData!.publisherRef, _page);
      controller.setObjectType(CreateObjectType.activity);
      expect(controller.state.draft.activityData!.publisherRef, _page);
    });

    test('Find People maps the active Page to its publisher fields', () async {
      final CreateController controller = await _loaded(_page);
      addTearDown(controller.dispose);

      controller.setObjectType(CreateObjectType.findPeople);
      final FindPeopleDraftData data = controller.state.draft.findPeopleData!;
      expect(data.publisherType, FindPeoplePublisherType.page);
      expect(data.publisherId, 'page-1');
    });

    test('personal workspace keeps the user as the publisher', () async {
      final CreateController controller = await _loaded(_user);
      addTearDown(controller.dispose);

      controller.setObjectType(CreateObjectType.place);
      controller.setObjectType(CreateObjectType.findPeople);
      expect(controller.state.draft.findPeopleData!.publisherId, 'user-1');
      expect(
        controller.state.draft.findPeopleData!.publisherType,
        FindPeoplePublisherType.user,
      );
    });

    test('Rental captures the active Page', () async {
      final CreateController controller = await _loaded(_page);
      addTearDown(controller.dispose);

      controller.setObjectType(CreateObjectType.rental);
      expect(controller.state.draft.rentalData!.publisherRef, _page);
    });

    test('resetToFreshDraft re-captures the current workspace', () async {
      final CreateController controller = await _loaded(_user);
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
        activePublisherRef: _page,
      );

      controller.resetToFreshDraft(
        organizerId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
      );
      expect(controller.state.draft.eventData!.publisherRef, _page);
    });

    test('workspace switch never rewrites an existing Place draft', () async {
      final CreateController controller = await _loaded(_page);
      addTearDown(controller.dispose);
      controller.setObjectType(CreateObjectType.place);

      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
        activePublisherRef: _user,
      );
      expect(controller.state.draft.placeData!.publisherRef, _page);
    });
  });
}

Future<CreateController> _loaded(
  PublisherRef publisher, {
  List<String> capabilities = const <String>[],
}) async {
  final CreateController controller = CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(_MemoryRepository()),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(_MemoryRepository()),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(_MemoryRepository()),
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
  await controller.ensureLoaded(
    userId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'Creator',
    capabilities: capabilities,
    activePublisherRef: publisher,
  );
  return controller;
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
