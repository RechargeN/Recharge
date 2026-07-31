import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/application/create_taxonomy.dart';
import 'package:recharge/features/create/application/state/create_state.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/entities/place_validation_issue.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../support/event_create_test_support.dart';

void main() {
  late _FakeCreateRepository repository;
  late CreateController controller;

  setUp(() {
    repository = _FakeCreateRepository();
    controller = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
      scenarioCreateCoordinator: ScenarioCreateCoordinator(
        idGenerator: _SequentialIdGenerator(),
      ),
      runtimeDefaults: const CreateRuntimeDefaults(
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      ),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('publish fails when coverImage is empty', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    controller.updateTitle('Morning Yoga');
    controller.updateMainCategory('wellness');
    controller.updateCity('Rezekne');
    controller.updateStartDateTime('2026-05-01T10:00:00Z');

    final success = await controller.publishDraft();

    expect(success, isFalse);
    expect(controller.state.validationErrors.containsKey('coverImage'), isTrue);
  });

  test(
    'new draft receives Riga defaults and creates local schedule slot',
    () async {
      await controller.ensureLoaded(
        userId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
      );

      expect(controller.state.draft.marketCityId, 'riga');
      expect(controller.state.draft.timezone, 'Europe/Riga');
      controller.updateStartDateTime('2026-07-20T10:00:00Z');

      expect(
        controller.state.draft.availabilityKind,
        CreateAvailabilityKind.eventSlots,
      );
      expect(controller.state.draft.scheduleSlots, hasLength(1));
      expect(
        controller.state.draft.scheduleSlots.single.localId,
        startsWith('loc_'),
      );
    },
  );

  test('partial attendance requires a positive minimum duration', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    controller.setObjectType(CreateObjectType.activity);
    controller.updateTitle('My Event');
    controller.updateMainCategory('outdoor_nature_walking');
    controller.updateCoverImage('cover.jpg');
    controller.updateStartDateTime('2026-07-20T10:00:00Z');
    controller.updatePartialAttendance(true);

    final bool success = await controller.publishDraft();

    expect(success, isFalse);
    expect(
      controller.state.validationErrors,
      contains('minimumVisitDurationMinutes'),
    );
  });

  test('saveDraft stores draft in repository', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    controller.updateTitle('My Draft');
    controller.updateMainCategory('music');
    controller.updateCity('Riga');

    await controller.saveDraft();

    final stored = await repository.loadDraft('u1');
    expect(stored, isNotNull);
    expect(stored!.title, 'My Draft');
  });

  test('applyTaxonomySelection updates category fields together', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );

    controller.applyTaxonomySelection(
      mainCategory: ' sport ',
      subcategory: ' tennis ',
    );

    expect(controller.state.draft.mainCategory, 'sport');
    expect(controller.state.draft.subcategory, 'tennis');
  });

  test('create taxonomy exposes source-of-truth ids for all create blocks', () {
    final eventCategories = createTaxonomyForObjectType(CreateObjectType.event);
    final placeCategories = createTaxonomyForObjectType(CreateObjectType.place);
    final sportCategory = createTaxonomyCategoryById('sport');

    expect(rechargeCreateBlockConfigs, hasLength(10));
    expect(rechargeCreateTaxonomy, hasLength(28));
    expect(
      rechargeCreateTaxonomy.fold<int>(
        0,
        (int count, category) => count + category.subcategories.length,
      ),
      530,
    );
    expect(CreateObjectType.quickPlan.taxonomyId, 'quick_plan');
    expect(CreateObjectType.scenario.taxonomyId, 'scenario');
    expect(createObjectTypeFromId('bookable_slot'), CreateObjectType.session);
    final Set<CreateObjectType> visibleTypes = rechargeCreateBlockConfigs
        .map((config) => config.objectType)
        .toSet();
    expect(visibleTypes, contains(CreateObjectType.scenario));
    expect(visibleTypes, isNot(contains(CreateObjectType.quickPlan)));
    for (final CreateObjectType type in visibleTypes) {
      expect(
        rechargeCreateBlockConfigs.map((config) => config.objectType),
        contains(type),
      );
      if (type != CreateObjectType.scenario) {
        expect(createTaxonomyForObjectType(type), isNotEmpty);
      }
    }
    expect(eventCategories.map((category) => category.id), contains('sport'));
    expect(
      placeCategories.map((category) => category.id),
      contains('wellness_recharge'),
    );
    expect(
      placeCategories
          .expand((category) => category.subcategories)
          .map((subcategory) => subcategory.id),
      containsAll(<String>['monument', 'park', 'public_square']),
    );
    expect(sportCategory, isNotNull);
    expect(
      sportCategory!.subcategories.map((subcategory) => subcategory.id),
      contains('tennis'),
    );
    expect(sportCategory.defaultParticipationMode, 'practice');
    expect(createTaxonomyLabelForPath('food_drinks.coffee'), 'Coffee');
    expect(
      createTaxonomyLabelForPath('music_nightlife.afterwork_drinks'),
      'Afterwork drinks',
    );
  });

  test('publish validation follows create block config', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
      capabilities: const <String>['create.route'],
    );

    controller.setObjectType(CreateObjectType.activity);
    controller.updateTitle('Recharge walk');
    controller.updateMainCategory('food_drinks');
    controller.updateCity('Rezekne');
    controller.updateCoverImage('cover.jpg');

    final missingTimeSuccess = await controller.publishDraft();

    expect(missingTimeSuccess, isFalse);
    expect(
      controller.state.validationErrors.containsKey('startDateTimeUtc'),
      isTrue,
    );

    controller.setObjectType(CreateObjectType.route);

    final routeSuccess = await controller.publishDraft();

    expect(routeSuccess, isFalse);
    expect(controller.state.publishedDraft, isNull);
    expect(controller.state.message, contains('Сервис публикации Route'));
  });

  test('Route selection requires create.route capability', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );

    controller.setObjectType(CreateObjectType.route);

    expect(controller.state.draft.objectType, isNot(CreateObjectType.route));
    expect(controller.state.message, contains('create.route'));

    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
      capabilities: const <String>['create.route'],
    );
    controller.setObjectType(CreateObjectType.route);

    expect(controller.state.draft.objectType, CreateObjectType.route);
    expect(controller.state.draft.routeData, isNotNull);
  });

  test('publish success sets pending_review status', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    controller.setObjectType(CreateObjectType.activity);
    controller.updateTitle('My Event');
    controller.updateMainCategory('outdoor');
    controller.updateCity('Rezekne');
    controller.updateCoverImage('cover.jpg');
    controller.updateStartDateTime('2026-05-01T10:00:00Z');

    final success = await controller.publishDraft();

    expect(success, isTrue);
    expect(controller.state.status, CreateStatus.publishSuccess);
    expect(
      controller.state.publishedDraft?.publishStatus,
      PublishStatus.pendingReview,
    );
  });

  test(
    'Scenario personal save supports undo and blocks public publish',
    () async {
      await controller.ensureLoaded(
        userId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
      );
      controller.setObjectType(CreateObjectType.scenario);
      controller.updateTitle('Riga evening');
      controller.addScenarioTimeBlock(title: 'Coffee', durationMinutes: 45);
      controller.addScenarioTimeBlock(title: 'Cinema', durationMinutes: 120);

      expect(controller.state.draft.scenarioData!.items, hasLength(2));
      expect(controller.scenarioReadiness!.canSaveToMyScenarios, isTrue);

      controller.undoScenario();
      expect(controller.state.draft.scenarioData!.items, hasLength(1));
      expect(controller.canRedoScenario, isTrue);
      controller.redoScenario();

      expect(await controller.saveScenarioToMyScenarios(), isTrue);
      expect(repository._stored?.objectType, CreateObjectType.scenario);
      expect(repository._stored?.visibility, VisibilityType.private);
      expect(await controller.publishDraft(), isFalse);
      expect(controller.state.draft.publishStatus, PublishStatus.draft);

      final CreateDraftEntity converted = controller.state.draft.copyWith(
        id: 'converted-scenario-id',
      );
      controller.setObjectType(CreateObjectType.event);
      expect(controller.applyConvertedScenario(converted), isTrue);
      expect(controller.state.draft.id, 'converted-scenario-id');
      expect(controller.state.draft.objectType, CreateObjectType.scenario);
      final CreateDraftEntity wrongOwner =
          CreateDraftEntity.defaults(
            organizerId: 'different-user',
            organizerEmail: 'other@example.com',
            organizerName: 'other',
          ).copyWith(
            id: 'wrong-owner-scenario',
            objectType: CreateObjectType.scenario,
            scenarioData: converted.scenarioData,
            clearEventData: true,
          );
      expect(controller.applyConvertedScenario(wrongOwner), isFalse);
    },
  );

  test(
    'Place flow autosaves, requires warning confirmation, and publishes',
    () async {
      await controller.ensureLoaded(
        userId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
        capabilities: const <String>['create.place'],
      );
      controller.setObjectType(CreateObjectType.place);
      controller.updateTitle('Quiet Riga Coffee House');
      controller.updateShortDescription(
        'A calm coffee place with comfortable seating for a short city break.',
      );
      controller.updatePlaceKind(PlaceKind.managedVenue);
      controller.updatePlaceRelationship(PlaceRelationship.owner);
      controller.applyTaxonomySelection(
        mainCategory: 'food_drinks',
        subcategory: 'coffee',
      );
      controller.updatePlaceAddress('Brivibas iela 1');
      controller.updatePlaceCoordinates(latitude: '56.95', longitude: '24.11');
      controller.confirmPlacePin();
      controller.updatePlaceHoursMode(PlaceHoursMode.alwaysOpen);
      controller.updatePlaceEntryType(PlaceEntryType.notApplicable);
      controller.updateCoverImage('local://cover.jpg');

      expect(await controller.goToPlaceStep(1), isTrue);
      expect(await controller.goToPlaceStep(2), isTrue);
      expect(await controller.goToPlaceStep(3), isTrue);
      expect(repository._stored?.placeData?.revision, greaterThan(0));

      expect(await controller.publishDraft(), isFalse);
      final List<PlaceValidationIssue> warnings = controller
          .state
          .placeValidationIssues
          .where(
            (PlaceValidationIssue issue) =>
                issue.severity == PlaceValidationSeverity.warning,
          )
          .toList(growable: false);
      expect(warnings, isNotEmpty);

      controller.acceptPlaceWarnings(
        warnings.map((PlaceValidationIssue issue) => issue.code),
      );
      expect(await controller.publishDraft(), isTrue);
      expect(controller.state.draft.publishStatus, PublishStatus.pendingReview);
    },
  );

  test(
    'Place gallery rejects the thirteenth image without data loss',
    () async {
      await controller.ensureLoaded(
        userId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
        capabilities: const <String>['create.place'],
      );
      controller.setObjectType(CreateObjectType.place);

      for (int index = 1; index <= 13; index++) {
        controller.addGalleryImage('local://image-$index.jpg');
      }

      expect(controller.state.draft.media.gallery, hasLength(12));
      expect(controller.state.draft.media.gallery.first, 'local://image-1.jpg');
      expect(controller.state.draft.media.gallery.last, 'local://image-12.jpg');
    },
  );
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _SequentialIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => 'scenario-id-${_value++}';
}

class _FakeCreateRepository implements CreateRepository {
  CreateDraftEntity? _stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => _stored;

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    final now = DateTime.now().toUtc();
    _stored = draft.copyWith(
      draftStatus: DraftStatus.pendingReview,
      moderationStatus: ModerationStatus.pending,
      publishStatus: PublishStatus.pendingReview,
      publishedAtUtc: now,
      updatedAtUtc: now,
    );
    return _stored!;
  }

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    _stored = draft;
  }
}
