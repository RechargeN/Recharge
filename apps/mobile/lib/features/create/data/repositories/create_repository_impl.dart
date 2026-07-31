import '../../../../core/id/id_generator.dart';
import '../../domain/entities/create_availability.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/event_draft_data.dart';
import '../../domain/entities/route_draft_save_result.dart';
import '../../domain/repositories/create_repository.dart';
import '../../domain/repositories/route_draft_persistence_repository.dart';
import '../datasources/create_local_datasource.dart';
import '../models/create_draft_model.dart';

class CreateRepositoryImpl
    implements CreateRepository, RouteDraftPersistenceRepository {
  CreateRepositoryImpl({
    required CreateLocalDataSource localDataSource,
    required IdGenerator idGenerator,
  }) : _localDataSource = localDataSource,
       _idGenerator = idGenerator;

  final CreateLocalDataSource _localDataSource;
  final IdGenerator _idGenerator;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async {
    final CreateDraftModel? model = await _localDataSource.loadDraft(userId);
    return model?.toEntity();
  }

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) {
    final CreateDraftEntity stored = draft.copyWith(
      draftStatus: DraftStatus.draft,
      publishStatus: PublishStatus.draft,
      updatedAtUtc: DateTime.now().toUtc(),
      clearPublishedAtUtc: true,
    );
    return _localDataSource.saveDraft(
      userId,
      CreateDraftModel.fromEntity(stored),
    );
  }

  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async {
    final route = draft.routeData;
    if (draft.objectType != CreateObjectType.route ||
        route == null ||
        route.revision < 0 ||
        (expectedRevision != null && route.revision <= expectedRevision)) {
      return RouteDraftSaveResult(
        status: RouteDraftSaveStatus.invalidDraft,
        requestedRevision: route?.revision ?? -1,
        persistedRevision: expectedRevision,
      );
    }

    final stored = draft.copyWith(
      draftStatus: DraftStatus.draft,
      publishStatus: PublishStatus.draft,
      updatedAtUtc: DateTime.now().toUtc(),
      clearPublishedAtUtc: true,
    );
    final result = await _localDataSource.saveRouteDraftIfCurrent(
      userId: userId,
      model: CreateDraftModel.fromEntity(stored),
      expectedRevision: expectedRevision,
    );
    return RouteDraftSaveResult(
      status: switch (result.status) {
        CreateConditionalSaveStatus.saved => RouteDraftSaveStatus.saved,
        CreateConditionalSaveStatus.conflict => RouteDraftSaveStatus.conflict,
        CreateConditionalSaveStatus.invalidExistingData =>
          RouteDraftSaveStatus.conflict,
      },
      requestedRevision: route.revision,
      persistedRevision: result.persistedRevision,
    );
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    if (draft.objectType == CreateObjectType.route) {
      throw StateError(
        'Route publication requires RoutePublicationRepository.',
      );
    }
    final CreateDraftEntity? existing = await loadDraft(userId);
    final Map<String, Object?>? existingPublish =
        existing?.sectionData['publish'] as Map<String, Object?>?;
    if (existing != null &&
        existing.publishStatus == PublishStatus.pendingReview &&
        (existing.id == draft.id ||
            existingPublish?['source_draft_id'] == draft.id)) {
      return existing;
    }
    final DateTime now = DateTime.now().toUtc();
    final String idempotencyKey =
        '$userId:${draft.id}:${draft.eventData?.revision ?? draft.placeData?.revision ?? draft.findPeopleData?.revision ?? 0}';
    final String publishedId = draft.id.startsWith('loc_')
        ? _idGenerator.generate()
        : draft.id;
    final Map<String, String> occurrenceIdMap = <String, String>{
      for (final EventOccurrenceDraft occurrence
          in draft.eventData?.occurrences ?? const <EventOccurrenceDraft>[])
        if (occurrence.id.startsWith('loc_'))
          occurrence.id: _idGenerator.generate(),
    };
    final List<CreateTimeSlotDraft> publishedSlots = draft.scheduleSlots
        .map(
          (CreateTimeSlotDraft slot) => slot.localId.startsWith('loc_')
              ? slot.copyWith(
                  localId:
                      occurrenceIdMap[slot.localId] ?? _idGenerator.generate(),
                )
              : slot,
        )
        .toList(growable: false);
    final EventDraftData? sourceEventData = draft.eventData;
    final EventDraftData? publishedEventData = sourceEventData?.copyWith(
      occurrences: sourceEventData.occurrences
          .map(
            (EventOccurrenceDraft occurrence) => occurrence.copyWith(
              id: occurrenceIdMap[occurrence.id] ?? occurrence.id,
            ),
          )
          .toList(growable: false),
      occurrenceOverrides: <String, EventOccurrenceOverrideDraft>{
        for (final MapEntry<String, EventOccurrenceOverrideDraft> entry
            in draft.eventData!.occurrenceOverrides.entries)
          (occurrenceIdMap[entry.key] ??
              entry.key): EventOccurrenceOverrideDraft(
            occurrenceId: occurrenceIdMap[entry.key] ?? entry.key,
            startAtUtc: entry.value.startAtUtc,
            endAtUtc: entry.value.endAtUtc,
            capacity: entry.value.capacity,
            cancelled: entry.value.cancelled,
          ),
      },
    );
    final Map<String, Object?> sectionData = <String, Object?>{
      ...draft.sectionData,
      'publish': <String, Object?>{
        'source_draft_id': draft.id,
        'idempotency_key': idempotencyKey,
      },
    };
    if (draft.findPeopleData != null) {
      final data = draft.findPeopleData!;
      sectionData['find_people_publish_snapshot'] = <String, Object?>{
        'contract_version': 1,
        'schedule_mode': data.scheduleMode.name,
        'meeting_mode': data.meetingMode.name,
        'candidate_slot_ids': publishedSlots
            .map((CreateTimeSlotDraft slot) => slot.localId)
            .toList(growable: false),
        'target_group_size': data.targetGroupSize,
        'host_seat_count': data.hostSeatCount,
        'approval_mode': data.approvalMode.name,
        'visibility': data.visibility.name,
        'public_area_label': data.publicAreaLabel,
        'public_geo': data.publicGeo == null
            ? null
            : <String, Object?>{
                'latitude': data.publicGeo!.latitude,
                'longitude': data.publicGeo!.longitude,
              },
        'private_meeting_ref': 'local-secure:$publishedId',
      };
    }
    final CreateDraftEntity published = draft.copyWith(
      id: publishedId,
      eventData: publishedEventData,
      placeData: draft.placeData?.replaceLocalIds(_idGenerator.generate),
      findPeopleData: draft.findPeopleData?.replaceLocalIds(
        _idGenerator.generate,
      ),
      sectionData: sectionData,
      scheduleSlots: publishedSlots,
      draftStatus: DraftStatus.pendingReview,
      moderationStatus: ModerationStatus.pending,
      publishStatus: PublishStatus.pendingReview,
      updatedAtUtc: now,
      publishedAtUtc: now,
    );
    await _localDataSource.saveDraft(
      userId,
      CreateDraftModel.fromEntity(published),
    );
    return published;
  }
}
