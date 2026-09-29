import '../../domain/entities/event_occurrence.dart';
import '../../domain/entities/published_event_discovery_entity.dart';
import '../../domain/entities/published_event_program_item.dart';
import '../../domain/entities/publisher_verification_display_state.dart';
import '../../domain/repositories/published_event_discovery_port.dart';

/// Mock-first `PublishedEventDiscoveryPort` implementation
/// (`docs/product/DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §0.6) — the
/// slice's actual data source, not a boundary-compliant `app/adapters/`
/// adapter: no live Create → Discover Event publish pipeline exists to
/// adapt from. Holds exactly the demo fixture from the spec's §7.5
/// ("Sunset Tennis Meetup") in memory; a later slice that builds the real
/// pipeline replaces this class's role without changing
/// [PublishedEventDiscoveryPort]'s contract.
class PublishedEventDiscoveryLocalDataSource
    implements PublishedEventDiscoveryPort {
  /// The one fixture id this slice serves.
  static const String sunsetTennisMeetupId = 'evt_sunset_tennis_meetup';

  late final Map<String, PublishedEventDiscoveryEntity> _byId =
      <String, PublishedEventDiscoveryEntity>{
        sunsetTennisMeetupId: _buildSunsetTennisMeetup(),
      };

  @override
  Future<PublishedEventDiscoveryEntity?> getActiveEvent(String eventId) async {
    return _byId[eventId];
  }

  static PublishedEventDiscoveryEntity _buildSunsetTennisMeetup() {
    const String occurrenceId = 'occ_sunset_tennis_2026_06_21';
    const String hero1 =
        'https://images.unsplash.com/photo-1554068865-24cecd4e34b8'
        '?auto=format&fit=crop&w=1200&q=80';
    const String hero2 =
        'https://images.unsplash.com/photo-1595435742656-5272d0b3fa82'
        '?auto=format&fit=crop&w=1200&q=80';
    const String hero3 =
        'https://images.unsplash.com/photo-1622279457486-62dcc4a431d6'
        '?auto=format&fit=crop&w=1200&q=80';
    const String hero4 =
        'https://images.unsplash.com/photo-1599474924187-334a4ae5bd3c'
        '?auto=format&fit=crop&w=1200&q=80';
    const String hero5 =
        'https://images.unsplash.com/photo-1551773188-0801da12ddc2'
        '?auto=format&fit=crop&w=1200&q=80';
    return PublishedEventDiscoveryEntity(
      eventId: sunsetTennisMeetupId,
      publisherId: 'page_marine_tennis_club',
      publisherType: 'page',
      publisherName: 'Marine Tennis Club',
      publisherHandle: '@marinetennis',
      publisherVerification: PublisherVerificationDisplayState.verifiedPage,
      title: 'Sunset Tennis Meetup',
      subtitle: 'Дружеская встреча для любителей тенниса на закате',
      fullDescription:
          'Дружеская встреча для любителей тенниса любого уровня. Новые '
          'знакомства, игра и отличная атмосфера на закате. Ракетки '
          'доступны на месте.',
      category: 'sport_fitness',
      subcategory: 'tennis',
      city: 'Дубай, ОАЭ',
      marketCityId: 'dubai',
      coverImageUrl: hero1,
      galleryImageUrls: const <String>[hero1, hero2, hero3, hero4, hero5],
      galleryAltText: const <String, String>{
        hero1: 'Теннисный корт на закате',
        hero2: 'Ракетка и мячи на теннисном корте',
        hero3: 'Теннисный корт перед вечерней игрой',
        hero4: 'Игроки на открытом теннисном корте',
        hero5: 'Теннисная площадка в тёплом вечернем свете',
      },
      venueName: 'Marine Tennis Club',
      addressLine: 'Marine Tennis Club, Дубай, ОАЭ',
      latitude: 25.0805,
      longitude: 55.1403,
      distanceKm: 3.2,
      priceAmount: 12,
      isFree: false,
      currencyCode: 'EUR',
      externalBookingUrl:
          'https://example.com/recharge/events/sunset-tennis-meetup',
      participantsCount: 32,
      capacity: 40,
      durationMinutes: 150,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: <EventOccurrence>[
        EventOccurrence(
          id: occurrenceId,
          startAtUtc: DateTime.utc(2026, 6, 21, 14),
          endAtUtc: DateTime.utc(2026, 6, 21, 16, 30),
          status: EventOccurrenceStatus.scheduled,
        ),
      ],
      displayOccurrenceId: occurrenceId,
      timezoneId: 'Asia/Dubai',
      programItems: <PublishedEventProgramItem>[
        PublishedEventProgramItem(
          id: 'prog_gather_warmup',
          title: 'Сбор участников и разминка',
          kind: EventProgramItemKind.activity,
          startAtUtc: DateTime.utc(2026, 6, 21, 14),
          endAtUtc: DateTime.utc(2026, 6, 21, 14, 20),
        ),
        PublishedEventProgramItem(
          id: 'prog_doubles_minitournament',
          title: 'Парные игры и мини-турниры',
          kind: EventProgramItemKind.session,
          startAtUtc: DateTime.utc(2026, 6, 21, 14, 20),
          endAtUtc: DateTime.utc(2026, 6, 21, 16),
        ),
        PublishedEventProgramItem(
          id: 'prog_wrapup_photo',
          title: 'Завершение и фото на память',
          kind: EventProgramItemKind.breakTime,
          startAtUtc: DateTime.utc(2026, 6, 21, 16),
          endAtUtc: DateTime.utc(2026, 6, 21, 16, 30),
        ),
      ],
      publishedAtUtc: DateTime.utc(2026, 5, 1),
    );
  }
}
