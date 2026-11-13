import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';

/// The synthetic Find People Create draft whose wire body is the `valid` case
/// of `packages/api_contracts/schema/content/v1/fixtures/find_people_create_compat.json`.
CreateDraftEntity userFindPeopleDraft({
  required String userId,
  String localId = 'local-find-people-1',
  String title = 'Morning run along the Daugava',
  DateTime? startAtUtc,
}) {
  final DateTime start = startAtUtc ?? DateTime.utc(2027, 5, 15, 6);
  final base = CreateDraftEntity.defaults(
    organizerId: userId,
    organizerEmail: 'runner@example.org',
    organizerName: 'Runner',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  final FindPeopleDraftData data =
      FindPeopleDraftData.defaults(
        userId: userId,
        currencyCode: 'EUR',
      ).copyWith(
        revision: 3,
        skillLevel: FindPeopleSkillLevel.beginner,
        languageCodes: <String>{'en', 'lv'},
        participationGoal: FindPeopleParticipationGoal.social,
        experienceRequirements: const <String>['Comfortable running 5 km'],
        equipmentNotes: 'Running shoes and water.',
        houseRuleIds: const <String>{'be_on_time', 'respect_boundaries'},
        meetingPlaceName: 'Ķīpsala riverside steps',
        publicAreaLabel: 'Ķīpsala, Riga',
        // A local preview only: never sent, the server computes the public cell.
        publicGeo: const FindPeopleGeoPointDraft(
          latitude: 56.951,
          longitude: 24.086,
        ),
        exactGeo: const FindPeopleGeoPointDraft(
          latitude: 56.95182,
          longitude: 24.08571,
        ),
        exactAddressLine: 'Ķīpsalas iela 6, Riga',
        meetingInstructions: 'By the blue bench.',
        publicPlaceConfirmed: true,
        targetGroupSize: 6,
        safetyRulesAccepted: true,
        accuracyConfirmed: true,
        ageRequirementConfirmed: true,
      );
  return base.copyWith(
    id: localId,
    objectType: CreateObjectType.findPeople,
    clearEventData: true,
    title: title,
    shortDescription: 'Easy 8 km jog at a relaxed pace, all levels welcome.',
    fullDescription:
        'We meet by the river and run an easy loop together. No pressure on speed: we wait for each other at every turn.',
    mainCategory: 'sport',
    subcategory: 'running',
    tags: const <String>['running'],
    scheduleSlots: <CreateTimeSlotDraft>[
      CreateTimeSlotDraft(
        localId: 'loc_slot_1',
        startAtUtc: start,
        endAtUtc: start.add(const Duration(minutes: 90)),
      ),
    ],
    registrationDeadlineUtc: start.subtract(const Duration(hours: 12)),
    findPeopleData: data,
  );
}
