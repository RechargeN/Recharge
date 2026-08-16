import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_classification.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../support/event_create_test_support.dart';

void main() {
  test('legacy suggestion is transient until explicit confirmation', () async {
    final CreateDraftEntity base = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );
    final _MemoryRepository repository = _MemoryRepository(
      base.copyWith(
        subcategory: 'hackathon',
        eventType: 'standard',
        eventData: base.eventData!.copyWith(
          schemaVersion: 1,
          clearPublisherRef: true,
          clearClassification: true,
        ),
      ),
    );
    final _RecordingAnalyticsService analytics = _RecordingAnalyticsService();
    final CreateController controller = _controller(
      repository,
      analyticsService: analytics,
    );
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );

    expect(controller.state.draft.eventData!.schemaVersion, 1);
    expect(controller.state.draft.eventData!.classification, isNull);
    expect(
      controller.eventClassificationState.suggestion!.archetype,
      EventArchetype.competition,
    );

    expect(
      controller.confirmEventClassificationSuggestion(expectedRevision: 99),
      isFalse,
    );
    expect(controller.state.draft.eventData!.classification, isNull);
    expect(
      controller.confirmEventClassificationSuggestion(
        expectedRevision: controller.state.draft.eventData!.revision,
      ),
      isTrue,
    );
    expect(controller.state.draft.eventData!.schemaVersion, 2);
    expect(
      controller.state.draft.eventData!.classification!.archetype,
      EventArchetype.competition,
    );
    controller.selectEventPrimaryParticipation(ParticipationMode.compete);
    controller.setEventAdditionalParticipation(ParticipationMode.play, true);
    controller.setEventAdditionalParticipation(
      ParticipationMode.practice,
      true,
    );
    controller.setEventAdditionalParticipation(ParticipationMode.support, true);
    controller.setEventAdditionalParticipation(ParticipationMode.travel, true);
    expect(
      controller
          .state
          .draft
          .eventData!
          .classification!
          .additionalParticipationModes,
      <ParticipationMode>{
        ParticipationMode.play,
        ParticipationMode.practice,
        ParticipationMode.support,
      },
    );
    await controller.saveDraft();
    expect(
      repository.stored!.eventData!.classification!.archetype,
      EventArchetype.competition,
    );
    final _TrackedEvent confirmation = analytics.events.firstWhere(
      (_TrackedEvent event) =>
          event.name == 'event_classification_archetype_selected',
    );
    expect(confirmation.params, <String, Object?>{
      'archetype': 'competition',
      'source': 'suggestion',
      'suggestion_reason': 'canonical_subcategory_exact',
      'suggestion_confidence': 'high',
    });
  });

  test('archetype change impact is bounded to classification fields', () async {
    final _MemoryRepository repository = _MemoryRepository();
    final CreateController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );

    controller.selectEventArchetype(EventArchetype.other);
    controller.updateEventArchetypeOtherReason('A new organized mechanic');
    final impact = controller.eventArchetypeImpact(EventArchetype.performance);
    expect(impact.clearsOtherReason, isTrue);
    expect(impact.affectedFieldIds, <String>{
      'eventArchetype',
      'eventArchetypeOtherReason',
    });

    final String categoryBefore = controller.state.draft.mainCategory;
    final String formatBefore = controller.state.draft.eventData!.format.name;
    final String pricingBefore =
        controller.state.draft.eventData!.pricingMode.name;
    final String registrationBefore =
        controller.state.draft.eventData!.registrationMode.name;
    final int revisionBefore = controller.state.draft.eventData!.revision;
    controller.selectEventArchetype(EventArchetype.performance);
    expect(
      controller.state.draft.eventData!.classification!.otherReason,
      isNull,
    );
    expect(controller.state.draft.mainCategory, categoryBefore);
    expect(controller.state.draft.eventData!.format.name, formatBefore);
    expect(controller.state.draft.eventData!.pricingMode.name, pricingBefore);
    expect(
      controller.state.draft.eventData!.registrationMode.name,
      registrationBefore,
    );
    expect(controller.state.draft.eventData!.revision, revisionBefore + 1);
  });

  test('disabled feature flag makes classification commands inert', () async {
    final _MemoryRepository repository = _MemoryRepository();
    final CreateController controller = _controller(
      repository,
      eventClassificationEnabled: false,
    );
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );

    expect(controller.eventClassificationState.enabled, isFalse);
    controller.selectEventArchetype(EventArchetype.performance);
    expect(controller.state.draft.eventData!.classification, isNull);
  });

  test('active Page is captured once for a fresh Event draft', () async {
    final _MemoryRepository repository = _MemoryRepository();
    final CreateController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
      activePublisherRef: const PublisherRef(
        type: PublisherType.page,
        id: 'page-1',
      ),
    );

    expect(
      controller.state.draft.eventData!.publisherRef,
      const PublisherRef(type: PublisherType.page, id: 'page-1'),
    );
  });

  test(
    'workspace switch never rewrites an existing Event PublisherRef',
    () async {
      final CreateDraftEntity saved =
          CreateDraftEntity.defaults(
            organizerId: 'user-1',
            organizerEmail: 'user@example.com',
            organizerName: 'Creator',
          ).copyWith(
            eventData:
                CreateDraftEntity.defaults(
                  organizerId: 'user-1',
                  organizerEmail: 'user@example.com',
                  organizerName: 'Creator',
                ).eventData!.copyWith(
                  publisherRef: const PublisherRef(
                    type: PublisherType.page,
                    id: 'page-original',
                  ),
                ),
          );
      final _MemoryRepository repository = _MemoryRepository(saved);
      final CreateController controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
        activePublisherRef: const PublisherRef(
          type: PublisherType.user,
          id: 'user-1',
        ),
      );
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
        activePublisherRef: const PublisherRef(
          type: PublisherType.page,
          id: 'page-new-workspace',
        ),
      );

      expect(
        controller.state.draft.eventData!.publisherRef,
        const PublisherRef(type: PublisherType.page, id: 'page-original'),
      );
    },
  );
}

CreateController _controller(
  _MemoryRepository repository, {
  bool eventClassificationEnabled = true,
  AnalyticsService? analyticsService,
}) {
  return CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
    analyticsService: analyticsService ?? _NoopAnalyticsService(),
    eventCreateCoordinator: createTestEventCoordinator(),
    eventClassificationEnabled: eventClassificationEnabled,
    runtimeDefaults: const CreateRuntimeDefaults(
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    ),
  );
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _RecordingAnalyticsService implements AnalyticsService {
  final List<_TrackedEvent> events = <_TrackedEvent>[];

  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {
    events.add(_TrackedEvent(eventName, Map<String, Object?>.from(params)));
  }
}

class _TrackedEvent {
  const _TrackedEvent(this.name, this.params);

  final String name;
  final Map<String, Object?> params;
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
