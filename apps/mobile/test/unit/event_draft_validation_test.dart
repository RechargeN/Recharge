import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/event_validation_issue.dart';
import 'package:recharge/features/create/domain/usecases/validate_event_draft_usecase.dart';

void main() {
  const ValidateEventDraftUseCase validate = ValidateEventDraftUseCase();

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
}
