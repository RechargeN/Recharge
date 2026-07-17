import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/create_taxonomy.dart';
import 'package:recharge/features/create/application/state/create_state.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

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
      runtimeDefaults: const CreateRuntimeDefaults(
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      ),
    );
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
      516,
    );
    expect(CreateObjectType.quickPlan.taxonomyId, 'quick_plan');
    expect(createObjectTypeFromId('bookable_slot'), CreateObjectType.session);
    for (final CreateObjectType type in CreateObjectType.values) {
      expect(
        rechargeCreateBlockConfigs.map((config) => config.objectType),
        contains(type),
      );
      expect(createTaxonomyForObjectType(type), isNotEmpty);
    }
    expect(eventCategories.map((category) => category.id), contains('sport'));
    expect(
      placeCategories.map((category) => category.id),
      contains('wellness_recharge'),
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
    );

    controller.setObjectType(CreateObjectType.quickPlan);
    controller.updateTitle('Quick coffee');
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

    expect(routeSuccess, isTrue);
    expect(controller.state.publishedDraft?.objectType, CreateObjectType.route);
  });

  test('publish success sets pending_review status', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
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
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
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
