import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/session_draft_data.dart';
import 'package:recharge/features/create/domain/entities/session_schedule.dart';
import 'package:recharge/features/create/domain/entities/session_price_disclosure.dart';
import 'package:recharge/features/create/domain/usecases/build_session_content_body.dart';

CreateDraftEntity userSessionDraft({
  required String userId,
  required String coverPath,
  List<String> galleryPaths = const <String>[],
  String localId = 'local-session-1',
  String title = 'Riga tennis court',
}) {
  final base = CreateDraftEntity.defaults(
    organizerId: userId,
    organizerEmail: 'creator@example.org',
    organizerName: 'Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  final draft = base.copyWith(
    id: localId,
    objectType: CreateObjectType.session,
    clearEventData: true,
    title: title,
    shortDescription: 'A fixed tennis court in central Riga.',
    fullDescription:
        'A single fixed court for a private party. Check the external booking site for current availability and terms.',
    mainCategory: 'sport',
    subcategory: 'tennis',
    venueName: 'Tennis court',
    addressLine1: 'Riga court 1',
    latitude: 56.9496,
    longitude: 24.1052,
    media: MediaEntity(coverImage: coverPath, gallery: galleryPaths),
    sessionData: const SessionDraftData(
      resourceName: 'Tennis court',
      timezoneId: 'Europe/Riga',
      timezoneConfirmed: true,
      maxPartySize: 4,
      revision: 1,
      price: SessionPriceDisclosure.free,
      externalBookingUrl: 'https://booking.example.org/court',
      schedule: SessionSchedule(
        scheduleRevision: 0,
        slotDurationMinutes: 60,
        bufferAfterSlotMinutes: 10,
        projectionWindowDays: 30,
        weeklyRules: <SessionWeeklyRule>[
          SessionWeeklyRule(
            id: 'loc_rule_1',
            isoWeekday: 1,
            startMinuteLocal: 540,
            endMinuteLocalExclusive: 780,
          ),
        ],
      ),
    ),
  );
  return draft.copyWith(
    sectionData: <String, Object?>{
      'session_pin': SessionContentBodyMapper.pinEvidence(draft),
      'session_media': <String, Object?>{
        'contentLocale': 'en',
        'rightsConfirmed': true,
        'coverAltText': <String, Object?>{'en': 'Tennis court overview'},
        'galleryAltText': <String, Object?>{
          for (final ref in galleryPaths)
            ref: <String, Object?>{'en': 'Tennis court gallery image'},
        },
      },
    },
  );
}
