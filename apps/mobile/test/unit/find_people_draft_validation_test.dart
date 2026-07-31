import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/validate_find_people_draft_usecase.dart';

void main() {
  const ValidateFindPeopleDraftUseCase validate =
      ValidateFindPeopleDraftUseCase();

  test('complete single in-person draft passes domain validation', () {
    final CreateDraftEntity draft = _validDraft();

    expect(validate(draft), isEmpty);
  });

  test(
    'unsafe public content, capacity, and residential location are rejected',
    () {
      final CreateDraftEntity base = _validDraft();
      final CreateDraftEntity invalid = base.copyWith(
        fullDescription:
            'Message me at host@example.com and send a bank transfer before we meet.',
        findPeopleData: base.findPeopleData!.copyWith(
          targetGroupSize: 21,
          exactAddressLine: 'Apartment 12, door code 1234',
        ),
      );

      final Set<String> codes = validate(
        invalid,
      ).map((issue) => issue.code).toSet();

      expect(codes, contains('public_contact_forbidden'));
      expect(codes, contains('group_size'));
      expect(codes, contains('unsafe_location'));
    },
  );

  test('time poll requires two slots and a deadline before first option', () {
    final CreateDraftEntity base = _validDraft();
    final CreateDraftEntity invalid = base.copyWith(
      findPeopleData: base.findPeopleData!.copyWith(
        scheduleMode: FindPeopleScheduleMode.timePoll,
        pollResponseDeadlineUtc: DateTime.utc(2026, 8, 20, 18),
      ),
    );

    final Set<String> codes = validate(
      invalid,
    ).map((issue) => issue.code).toSet();

    expect(codes, contains('poll_slot_count'));
    expect(codes, contains('poll_deadline'));
  });
}

CreateDraftEntity _validDraft() {
  final DateTime start = DateTime.utc(2026, 8, 20, 16);
  final FindPeopleDraftData details =
      FindPeopleDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      ).copyWith(
        meetingPlaceName: 'Riga Central Library',
        publicAreaLabel: 'Central Riga',
        publicGeo: const FindPeopleGeoPointDraft(
          latitude: 56.95,
          longitude: 24.105,
        ),
        exactGeo: const FindPeopleGeoPointDraft(
          latitude: 56.9501,
          longitude: 24.1051,
        ),
        exactAddressLine: 'Riga Central Library main entrance',
        publicPlaceConfirmed: true,
        safetyRulesAccepted: true,
        accuracyConfirmed: true,
        ageRequirementConfirmed: true,
      );
  return CreateDraftEntity.defaults(
    organizerId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'Host',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  ).copyWith(
    objectType: CreateObjectType.findPeople,
    title: 'Weekend tennis practice',
    mainCategory: 'sport',
    subcategory: 'tennis',
    shortDescription: 'Friendly tennis practice for adults in central Riga.',
    fullDescription:
        'We will play a relaxed two-hour tennis session, rotate partners, and keep the pace welcoming for intermediate players.',
    availabilityKind: CreateAvailabilityKind.eventSlots,
    scheduleSlots: <CreateTimeSlotDraft>[
      CreateTimeSlotDraft(
        localId: 'loc_slot_1',
        startAtUtc: start,
        endAtUtc: start.add(const Duration(hours: 2)),
      ),
    ],
    registrationDeadlineUtc: DateTime.utc(2026, 8, 19, 16),
    findPeopleData: details,
  );
}
