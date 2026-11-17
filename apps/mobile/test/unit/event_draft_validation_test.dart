import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/event_validation_issue.dart';
import 'package:recharge/features/create/domain/usecases/validate_event_draft_usecase.dart';

void main() {
  const ValidateEventDraftUseCase validate = ValidateEventDraftUseCase();

  test('all Event date fields share strict Gregorian validation', () {
    final base = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Host',
    );
    for (final invalid in [
      '2026-02-29',
      '1900-02-29',
      '0000-01-01',
      '2026-1-01',
      '2026-01-01\n',
    ]) {
      final event = base.eventData!.copyWith(
        localStartDate: invalid,
        scheduleMode: EventScheduleMode.recurring,
        recurrence: EventRecurrenceRuleDraft(
          frequency: EventRecurrenceFrequency.daily,
          endMode: EventRecurrenceEndMode.untilDate,
          untilLocalDate: invalid,
          exceptionLocalDates: {invalid},
        ),
      );
      final codes = validate(
        base.copyWith(eventData: event),
      ).map((issue) => issue.code).toSet();
      expect(
        codes,
        containsAll([
          'local_start_date_invalid',
          'recurrence_until_invalid',
          'recurrence_exception_invalid',
        ]),
      );
    }
    final valid = base.eventData!.copyWith(localStartDate: '2000-02-29');
    expect(
      validate(base.copyWith(eventData: valid)).map((issue) => issue.code),
      isNot(contains('local_start_date_invalid')),
    );
  });

  test(
    'physical Event requires confirmed coordinates and accessible media',
    () {
      final CreateDraftEntity draft =
          CreateDraftEntity.defaults(
            organizerId: 'user-1',
            organizerEmail: 'user@example.com',
            organizerName: 'Host',
            marketCityId: 'riga',
            timezone: 'Europe/Riga',
            country: 'LV',
            city: 'Riga',
            currency: 'EUR',
          ).copyWith(
            title: 'Riga design meetup',
            mainCategory: 'social',
            subcategory: 'meetup',
            shortDescription: 'A friendly meetup for local designers.',
            media: const MediaEntity(
              coverImage: 'cover.jpg',
              gallery: <String>['gallery.jpg'],
            ),
            eventData:
                EventDraftData.defaults(
                  marketCityId: 'riga',
                  countryCode: 'LV',
                  city: 'Riga',
                  timezoneId: 'Europe/Riga',
                  currencyCode: 'EUR',
                ).copyWith(
                  location: const EventLocationDraft(
                    marketCityId: 'riga',
                    countryCode: 'LV',
                    city: 'Riga',
                    formattedAddress: 'Brivibas iela 1',
                  ),
                  mediaMetadata: const EventMediaMetadataDraft(
                    coverAltText: 'People talking at a meetup',
                    rightsConfirmed: true,
                  ),
                  occurrences: <EventOccurrenceDraft>[
                    EventOccurrenceDraft(
                      id: 'loc_occurrence',
                      localDate: '2030-08-03',
                      startAtUtc: DateTime.utc(2030, 8, 3, 16),
                      endAtUtc: DateTime.utc(2030, 8, 3, 18),
                    ),
                  ],
                ),
          );

      final Set<String> codes = validate(
        draft,
        nowUtc: DateTime.utc(2026, 1, 1),
      ).map((EventValidationIssue issue) => issue.code).toSet();

      expect(codes, contains('location_coordinates_required'));
      expect(codes, contains('gallery_alt_required'));
    },
  );

  test('invalid local schedule and unsafe external URL are blocking', () {
    final CreateDraftEntity base = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Host',
    );
    final EventDraftData event = base.eventData!.copyWith(
      format: EventFormat.online,
      onlineAccessMode: EventOnlineAccessMode.externalRegistration,
      localStartDate: '2026-02-31',
      registrationMode: EventRegistrationMode.external,
      externalBookingUrl: 'http://user:pass@example.com/register',
    );

    final Set<String> codes = validate(
      base.copyWith(eventData: event),
    ).map((EventValidationIssue issue) => issue.code).toSet();

    expect(codes, contains('local_start_date_invalid'));
    expect(codes, contains('external_booking_url_invalid'));
  });
  test(
    'text lengths follow the Content Event contract (A34 staging 2026-11-19)',
    () {
      // The server refused a draft the wizard accepted (empty full description).
      final CreateDraftEntity base =
          CreateDraftEntity.defaults(
            organizerId: 'user-1',
            organizerEmail: 'user@example.com',
            organizerName: 'Host',
            marketCityId: 'riga',
            timezone: 'Europe/Riga',
            country: 'LV',
            city: 'Riga',
            currency: 'EUR',
          ).copyWith(
            title: 'Riga design meetup',
            shortDescription: 'A friendly meetup for local designers.',
            fullDescription:
                'Bring a sketchbook and one project you are working on; we swap feedback in small groups.',
          );
      Set<String> codes(CreateDraftEntity draft) => validate(
        draft,
        throughStep: 0,
      ).map((EventValidationIssue issue) => issue.code).toSet();
      final ok = codes(base);
      expect(ok, isNot(contains('title_required')));
      expect(ok, isNot(contains('short_description_required')));
      expect(ok, isNot(contains('full_description_required')));
      // Whitespace is collapsed before counting, as on the server.
      expect(
        codes(base.copyWith(shortDescription: 'short   and          padded')),
        contains('short_description_required'),
      );
      expect(
        codes(base.copyWith(shortDescription: 'A' * 241)),
        contains('short_description_required'),
      );
      expect(
        codes(base.copyWith(fullDescription: '')),
        contains('full_description_required'),
      );
      expect(
        codes(base.copyWith(fullDescription: 'x' * 49)),
        contains('full_description_required'),
      );
      expect(
        codes(base.copyWith(title: 'T' * 101)),
        contains('title_required'),
      );
      expect(
        codes(base.copyWith(title: 'T' * 100)),
        isNot(contains('title_required')),
      );
    },
  );
}
