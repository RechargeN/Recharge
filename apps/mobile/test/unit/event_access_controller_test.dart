import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';
import 'package:recharge/features/create/domain/entities/event_availability_projection.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/event_inventory.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../support/event_create_test_support.dart';

void main() {
  test(
    'preset preview is transient and Apply is one schema v3 revision',
    () async {
      final _MemoryRepository repository = _MemoryRepository();
      final CreateController controller = _controller(
        repository,
        enabled: true,
      );
      addTearDown(controller.dispose);
      await _load(controller);
      final int before = controller.state.draft.eventData!.revision;

      controller.previewEventAdmissionPreset(
        EventAdmissionPreset.noRegistration,
      );
      expect(controller.state.draft.eventData!.revision, before);
      expect(controller.state.draft.eventData!.admission, isNull);
      expect(controller.eventAdmissionState.presetPreview, isNotNull);

      expect(controller.applyEventAdmissionPreset(), isTrue);
      final EventDraftData event = controller.state.draft.eventData!;
      expect(event.schemaVersion, EventDraftData.accessSchemaVersion);
      expect(event.revision, before + 1);
      expect(event.admission!.admissionMode, AdmissionMode.openEntry);
    },
  );

  test(
    'legacy suggestion requires explicit revision-safe confirmation',
    () async {
      final CreateController controller = _controller(
        _MemoryRepository(),
        enabled: true,
      );
      addTearDown(controller.dispose);
      await _load(controller);
      final int revision = controller.state.draft.eventData!.revision;

      expect(controller.eventAdmissionState.legacySuggestion, isNotNull);
      expect(
        controller.confirmEventAdmissionLegacySuggestion(
          expectedRevision: revision + 1,
        ),
        isFalse,
      );
      expect(controller.state.draft.eventData!.admission, isNull);
      expect(
        controller.confirmEventAdmissionLegacySuggestion(
          expectedRevision: revision,
        ),
        isTrue,
      );
      expect(controller.state.draft.eventData!.schemaVersion, 3);
    },
  );

  test('stale preset confirmation does not mutate the draft', () async {
    final CreateController controller = _controller(
      _MemoryRepository(),
      enabled: true,
    );
    addTearDown(controller.dispose);
    await _load(controller);
    controller.previewEventAdmissionPreset(EventAdmissionPreset.noRegistration);
    controller.updateEventFormat(EventFormat.online);
    final int revision = controller.state.draft.eventData!.revision;

    expect(controller.applyEventAdmissionPreset(), isFalse);
    expect(controller.state.draft.eventData!.revision, revision);
    expect(controller.state.draft.eventData!.admission, isNull);
  });

  test(
    'inventory commands keep stable pool ids and one revision each',
    () async {
      final CreateController controller = _controller(
        _MemoryRepository(),
        enabled: true,
      );
      addTearDown(controller.dispose);
      await _load(controller);
      final int before = controller.state.draft.eventData!.revision;

      controller.selectEventInventoryAuthority(InventoryAuthority.recharge);
      expect(controller.state.draft.eventData!.revision, before + 1);
      controller.selectEventInventoryShapes(
        primaryShape: InventoryShape.generalCapacity,
      );
      expect(controller.state.draft.eventData!.revision, before + 2);
      final String? poolId = controller.addEventInventoryPool(
        label: 'Onsite',
        shape: InventoryShape.generalCapacity,
        channel: InventoryChannel.onsite,
        capacityMode: EventCapacityMode.known,
        capacity: 20,
      );
      expect(poolId, startsWith('loc_'));
      expect(controller.state.draft.eventData!.revision, before + 3);
      expect(
        controller.state.draft.eventData!.inventory!.pools.single.id,
        poolId,
      );

      controller.updateEventInventoryPool(
        controller.state.draft.eventData!.inventory!.pools.single.copyWith(
          label: 'Main onsite',
        ),
      );
      expect(
        controller.state.draft.eventData!.inventory!.pools.single.id,
        poolId,
      );
      expect(controller.state.draft.eventData!.revision, before + 4);
    },
  );

  test('disabled flags keep v3 data readable and commands inert', () async {
    final EventDraftData event =
        CreateDraftEntity.defaults(
          organizerId: 'user-1',
          organizerEmail: 'user@example.com',
          organizerName: 'Creator',
        ).eventData!.copyWith(
          schemaVersion: 3,
          admission: const EventAdmissionDraft(
            admissionMode: AdmissionMode.openEntry,
            registrationMode: EventRegistrationMode.none,
            confirmationMode: ConfirmationMode.none,
          ),
        );
    final _MemoryRepository repository = _MemoryRepository(
      CreateDraftEntity.defaults(
        organizerId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
      ).copyWith(eventData: event),
    );
    final CreateController controller = _controller(repository, enabled: false);
    addTearDown(controller.dispose);
    await _load(controller);
    final int revision = controller.state.draft.eventData!.revision;

    expect(controller.eventAdmissionState.enabled, isFalse);
    expect(controller.state.draft.eventData!.admission, isNotNull);
    controller.updateEventAdmissionAxes(admissionMode: AdmissionMode.ticket);
    expect(controller.state.draft.eventData!.revision, revision);
    expect(
      controller.state.draft.eventData!.admission!.admissionMode,
      AdmissionMode.openEntry,
    );
  });

  test('missing local fixture stays unknown and never mutates draft', () async {
    final CreateController controller = _controller(
      _MemoryRepository(),
      enabled: true,
      mockEnabled: true,
    );
    addTearDown(controller.dispose);
    await _load(controller);
    controller.selectEventInventoryAuthority(InventoryAuthority.none);
    final int revision = controller.state.draft.eventData!.revision;

    await controller.refreshEventMockAvailabilityPreview();
    expect(
      controller.eventInventoryState.availabilityPreview.state,
      EventAvailabilityState.unknown,
    );
    expect(controller.state.draft.eventData!.revision, revision);
  });

  test('newer schema access commands fail closed without downgrade', () async {
    final CreateDraftEntity base = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );
    final _MemoryRepository repository = _MemoryRepository(
      base.copyWith(
        eventData: base.eventData!.copyWith(
          schemaVersion: 9,
          unknownFields: const <String, Object?>{
            'schemaVersion': 9,
            'futureAuthority': 'future',
          },
          unsupportedFieldIds: const <String>{'eventData'},
        ),
      ),
    );
    final CreateController controller = _controller(repository, enabled: true);
    addTearDown(controller.dispose);
    await _load(controller);

    controller.updateEventAdmissionAxes(admissionMode: AdmissionMode.ticket);
    controller.selectEventInventoryAuthority(InventoryAuthority.recharge);

    expect(controller.state.draft.eventData!.schemaVersion, 9);
    expect(controller.state.draft.eventData!.admission, isNull);
    expect(controller.state.draft.eventData!.inventory, isNull);
  });
}

Future<void> _load(CreateController controller) => controller.ensureLoaded(
  userId: 'user-1',
  organizerEmail: 'user@example.com',
  organizerName: 'Creator',
);

CreateController _controller(
  _MemoryRepository repository, {
  required bool enabled,
  bool mockEnabled = false,
}) => CreateController(
  loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
  saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
  publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
  analyticsService: _NoopAnalyticsService(),
  eventCreateCoordinator: createTestEventCoordinator(),
  eventAdmissionConfigurationEnabled: enabled,
  eventMockAvailabilityEnabled: mockEnabled,
  runtimeDefaults: const CreateRuntimeDefaults(
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  ),
);

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _MemoryRepository implements CreateRepository {
  _MemoryRepository([this.stored]);

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
