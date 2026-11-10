import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/route_create_coordinator.dart';
import 'package:recharge/features/create/application/route_create_config.dart';
import 'package:recharge/features/create/application/route_draft_autosave_coordinator.dart';
import 'package:recharge/features/create/domain/entities/route_draft_save_result.dart';
import 'package:recharge/features/create/domain/repositories/route_draft_persistence_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_routing_repository.dart';
import '../support/route_domain_fixtures.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/draft_publisher.dart';
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
  const types = <CreateObjectType>[
    CreateObjectType.event,
    CreateObjectType.place,
    CreateObjectType.activity,
    CreateObjectType.findPeople,
    CreateObjectType.rental,
    CreateObjectType.collection,
    CreateObjectType.session,
    CreateObjectType.scenario,
    CreateObjectType.route,
    CreateObjectType.classWorkshop,
  ];
  for (final type in types) {
    for (final publisher in <PublisherRef>[_user, _page]) {
      test(
        '${type.name}: captures once, survives switches, save and restore (${publisher.type.name})',
        () async {
          final repository = _MemoryRepository();
          final controller = await _loaded(publisher, repository: repository);
          addTearDown(controller.dispose);
          controller.setObjectType(type);
          expect(controller.state.draft.objectType, type);
          expect(controller.state.draft.effectivePublisher, publisher);
          final id = controller.state.draft.id;
          for (final next in <PublisherRef>[
            const PublisherRef(type: PublisherType.page, id: 'page-2'),
            _user,
          ]) {
            await controller.ensureLoaded(
              userId: 'user-1',
              organizerEmail: '',
              organizerName: '',
              activePublisherRef: next,
              capabilities: const ['create.route', 'create.collection'],
            );
            // Initializing a different block is not a new draft identity.
            controller.setObjectType(CreateObjectType.classWorkshop);
            controller.setObjectType(type);
            expect(controller.state.draft.id, id);
            expect(controller.state.draft.effectivePublisher, publisher);
          }
          controller.updateTitle('Content edit keeps draft identity');
          expect(controller.state.draft.effectivePublisher, publisher);
          if (type == CreateObjectType.route) {
            final coordinator = RouteCreateCoordinator(
              idGenerator: _Ids(),
              routingRepository: _NoRouting(),
              autosaveCoordinator: RouteDraftAutosaveCoordinator(repository),
              config: RouteCreateConfig(
                version: 1,
                validationPolicy: routeValidationPolicy(
                  requirePermanentIds: false,
                ),
              ),
            );
            controller.attachRouteCoordinator(coordinator);
            addTearDown(coordinator.dispose);
          }
          await controller.saveDraft();
          expect(repository.stored, isNotNull);
          final restored = await _loaded(_user, repository: repository);
          addTearDown(restored.dispose);
          expect(restored.state.draft.objectType, type);
          expect(restored.state.draft.effectivePublisher, publisher);
          expect(restored.state.draft.publisherSelectionRequired, isFalse);
          restored.resetToFreshDraft(
            organizerId: 'user-1',
            organizerEmail: '',
            organizerName: '',
          );
          restored.setObjectType(type);
          expect(restored.state.draft.id, isNot(id));
          expect(restored.state.draft.effectivePublisher, _user);
        },
      );
    }
  }
  for (final type in <CreateObjectType>[
    CreateObjectType.place,
    CreateObjectType.findPeople,
  ]) {
    test(
      '${type.name}: missing restored block never captures current Page',
      () async {
        final repository = _MemoryRepository();
        repository.stored =
            CreateDraftEntity.defaults(
              organizerId: 'user-1',
              organizerEmail: '',
              organizerName: '',
            ).copyWith(
              objectType: type,
              clearEventData: true,
              clearPublisher: true,
            );
        final controller = await _loaded(_page, repository: repository);
        addTearDown(controller.dispose);
        expect(controller.state.draft.publisherSelectionRequired, isTrue);
        await controller.saveDraft();
        final restored = await _loaded(_page, repository: repository);
        addTearDown(restored.dispose);
        expect(restored.state.draft.publisherSelectionRequired, isTrue);
        expect(await restored.publishDraft(), isFalse);
      },
    );
  }
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
  List<String> capabilities = const <String>[
    'create.route',
    'create.collection',
  ],
  _MemoryRepository? repository,
}) async {
  final store = repository ?? _MemoryRepository();
  final CreateController controller = CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(store),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(store),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(store),
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

class _MemoryRepository
    implements CreateRepository, RouteDraftPersistenceRepository {
  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async {
    await saveDraft(userId, draft);
    return RouteDraftSaveResult(
      status: RouteDraftSaveStatus.saved,
      requestedRevision: draft.routeData!.revision,
      persistedRevision: draft.routeData!.revision,
    );
  }

  CreateDraftEntity? stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    stored = CreateDraftModel.fromJson(
      CreateDraftModel.fromEntity(draft).toJson(),
    ).toEntity();
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    stored = CreateDraftModel.fromJson(
      CreateDraftModel.fromEntity(draft).toJson(),
    ).toEntity();
    return draft;
  }
}

class _Ids implements IdGenerator {
  int value = 0;
  @override
  String generate() => 'test-id-${value++}';
}

class _NoRouting implements RouteRoutingRepository {
  @override
  Future<RouteRoutingResult> route(RouteRoutingRequest request) =>
      throw StateError('No routing needed for publisher persistence');
  @override
  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  ) => throw StateError('No generation needed');
}
