import '../../domain/entities/published_bookable_session_discovery_entity.dart';
import '../../domain/entities/publisher_verification_display_state.dart';
import '../../domain/repositories/published_bookable_session_discovery_port.dart';

typedef BookableSessionFixtureBuilder =
    PublishedBookableSessionDiscoveryEntity Function();
typedef BookableSessionDatasourceClock = DateTime Function();

/// Mock-first public read source for DTL-SES-01. The fixture contains only
/// public allowlisted data and remains independent from Create drafts.
class PublishedBookableSessionDiscoveryLocalDataSource
    implements PublishedBookableSessionDiscoveryPort {
  PublishedBookableSessionDiscoveryLocalDataSource({
    BookableSessionDatasourceClock? clock,
    Map<String, BookableSessionFixtureBuilder>? fixtureBuilders,
    Set<String> hiddenSessionIds = const <String>{},
  }) : _clock = clock ?? _utcNow,
       _fixtureBuilders = fixtureBuilders == null
           ? null
           : Map<String, BookableSessionFixtureBuilder>.unmodifiable(
               fixtureBuilders,
             ),
       _hiddenSessionIds = Set<String>.unmodifiable(hiddenSessionIds);

  static const String personalTrainingSessionId =
      'session_personal_training_riga';

  final BookableSessionDatasourceClock _clock;
  final Map<String, BookableSessionFixtureBuilder>? _fixtureBuilders;
  final Set<String> _hiddenSessionIds;
  late final PublishedBookableSessionDiscoveryEntity _personalTraining =
      _buildPersonalTraining();

  @override
  Future<PublishedBookableSessionDiscoveryEntity?> getActiveBookableSession(
    String sessionId,
  ) async {
    if (sessionId.trim().isEmpty || _hiddenSessionIds.contains(sessionId)) {
      return null;
    }
    final Map<String, BookableSessionFixtureBuilder> builders =
        _fixtureBuilders ??
        <String, BookableSessionFixtureBuilder>{
          personalTrainingSessionId: () => _personalTraining,
        };
    final BookableSessionFixtureBuilder? build = builders[sessionId];
    if (build == null) return null;
    try {
      return build();
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  PublishedBookableSessionDiscoveryEntity _buildPersonalTraining() {
    final DateTime generatedAt = _clock().toUtc();
    final DateTime firstStart = generatedAt.add(const Duration(hours: 8));
    final DateTime secondStart = generatedAt.add(const Duration(days: 1));
    return PublishedBookableSessionDiscoveryEntity(
      sessionId: personalTrainingSessionId,
      publisherId: 'page_recharge_studio',
      publisherType: 'page',
      publisherName: 'Recharge Studio',
      publisherHandle: '@recharge.studio',
      publisherVerification: PublisherVerificationDisplayState.verifiedPage,
      title: 'Персональная тренировка · демо',
      resourceName: 'Зал персональных тренировок',
      shortDescription: 'Индивидуальная тренировка с тренером в центре Риги.',
      fullDescription:
          'Демонстрационные данные: реальная запись не подключена. '
          'Персональная тренировка под вашу цель и текущий уровень. '
          'Тренер адаптирует нагрузку и объясняет технику упражнений.',
      category: 'sport_fitness',
      subcategory: 'personal_training',
      serviceCategoryLabel: 'Индивидуальная тренировка',
      durationMinutes: 60,
      maxPartySize: 1,
      priceType: PublishedBookableSessionPriceType.fixed,
      priceAmountMinor: 4500,
      currencyCode: 'EUR',
      timezoneId: 'Europe/Riga',
      schedule: PublishedBookableSessionScheduleSnapshot(
        scheduleRevision: 1,
        generatedAtUtc: generatedAt,
        validUntilUtc: generatedAt.add(const Duration(minutes: 5)),
        offers: <PublishedBookableSessionOffer>[
          PublishedBookableSessionOffer(
            slotKey: 'session_slot_personal_training_1',
            startAtUtc: firstStart,
            endAtUtc: firstStart.add(const Duration(hours: 1)),
            timezoneId: 'Europe/Riga',
          ),
          PublishedBookableSessionOffer(
            slotKey: 'session_slot_personal_training_2',
            startAtUtc: secondStart,
            endAtUtc: secondStart.add(const Duration(hours: 1)),
            timezoneId: 'Europe/Riga',
          ),
        ],
      ),
      publicLocation: PublishedBookableSessionPointLocation(
        meetingMode: PublishedBookableSessionMeetingMode.inPerson,
        venueName: 'Recharge Studio',
        areaLabel: 'Центр Риги',
        publicAddress: 'Brīvības iela, Rīga',
        latitude: 56.9533,
        longitude: 24.1134,
        publicGeoPrecisionMeters: 50,
      ),
      externalBookingUri: Uri.parse(
        'https://booking.recharge.local/sessions/personal-training',
      ),
      publishedAtUtc: DateTime.utc(2026, 9, 1),
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
