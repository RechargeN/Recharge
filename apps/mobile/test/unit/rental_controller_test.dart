import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/state/create_state.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
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

  test(
    'setObjectType(rental) seeds RentalDraftData with market defaults',
    () async {
      await controller.ensureLoaded(
        userId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
      );

      controller.setObjectType(CreateObjectType.rental);

      expect(controller.state.draft.objectType, CreateObjectType.rental);
      expect(controller.state.draft.rentalData, isNotNull);
      expect(controller.state.draft.rentalData!.pricing.currencyCode, 'EUR');
      expect(
        controller.state.draft.rentalData!.availability.timeZoneId,
        'Europe/Riga',
      );
      expect(controller.state.rentalStep, 0);
    },
  );

  test('mutating a Rental draft marks it unsaved (autosave gate)', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    controller.setObjectType(CreateObjectType.rental);
    await repository.saveDraft('u1', controller.state.draft);

    controller.updateRentalTitle('Mountain bikes');

    expect(controller.state.saveStatus, CreateSaveStatus.unsaved);
    expect(controller.state.draft.rentalData!.title, 'Mountain bikes');
  });

  test('capability getters reflect loaded capabilities', () async {
    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );
    expect(controller.canCreateRental, isFalse);

    await controller.ensureLoaded(
      userId: 'u1',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
      capabilities: const <String>['create.rental', 'submit.rental'],
    );

    expect(controller.canCreateRental, isTrue);
    expect(controller.canSubmitRental, isTrue);
    expect(controller.canPublishRentalDirect, isFalse);
  });

  test(
    'goToRentalStep blocks forward navigation past an incomplete listing step',
    () async {
      await controller.ensureLoaded(
        userId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
      );
      controller.setObjectType(CreateObjectType.rental);

      final bool advanced = await controller.goToRentalStep(1);

      expect(advanced, isFalse);
      expect(controller.state.rentalStep, 0);
      expect(controller.state.rentalValidationIssues, isNotEmpty);
    },
  );

  test(
    'addRentalInventoryGroup enables progressing past the inventory step',
    () async {
      await controller.ensureLoaded(
        userId: 'u1',
        organizerEmail: 'user@example.com',
        organizerName: 'user',
      );
      controller.setObjectType(CreateObjectType.rental);
      controller.updateRentalTitle('Mountain bikes for weekend trail rides');
      controller.updateRentalShortDescription(
        'Well maintained trail bikes in several sizes, helmets included.',
      );
      controller.updateRentalFullDescription(
        'Full length description with more than fifty characters describing '
        'the bikes available for rent near the city center.',
      );
      controller.confirmRentalCategory();
      await controller.goToRentalStep(1);

      final bool blockedWithoutInventory = await controller.goToRentalStep(2);
      expect(blockedWithoutInventory, isFalse);

      controller.addRentalInventoryGroup(
        const RentalInventoryGroup(
          id: 'loc_group_1',
          label: 'Adult M',
          quantity: 5,
          condition: RentalCondition.good,
          sizeOrVariant: 'M',
        ),
      );
      final bool advanced = await controller.goToRentalStep(2);
      expect(advanced, isTrue);
    },
  );
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
