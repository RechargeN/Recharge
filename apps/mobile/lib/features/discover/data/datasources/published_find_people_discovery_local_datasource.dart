import '../../domain/entities/published_find_people_discovery_entity.dart';
import '../../domain/entities/publisher_verification_display_state.dart';
import '../../domain/repositories/published_find_people_discovery_port.dart';

/// Mock-first public read source for the first Find People Details vertical.
/// It contains public allowlisted values only; no Create draft is adapted here.
class PublishedFindPeopleDiscoveryLocalDataSource
    implements PublishedFindPeopleDiscoveryPort {
  static const String morningRunRequestId = 'fp_morning_run_riga';

  late final Map<String, PublishedFindPeopleDiscoveryEntity> _byId =
      <String, PublishedFindPeopleDiscoveryEntity>{
        morningRunRequestId: _buildMorningRun(),
      };

  @override
  Future<PublishedFindPeopleDiscoveryEntity?> getActiveFindPeopleRequest(
    String requestId,
  ) async {
    return _byId[requestId];
  }

  static PublishedFindPeopleDiscoveryEntity _buildMorningRun() {
    return PublishedFindPeopleDiscoveryEntity(
      requestId: morningRunRequestId,
      occurrenceId: 'fp_occ_morning_run_2026_09_12',
      publisherId: 'user_anna_runs',
      publisherType: 'user',
      publisherName: 'Анна К.',
      publisherHandle: '@anna_runs',
      publisherVerification: PublisherVerificationDisplayState.verifiedCreator,
      title: 'Утренняя пробежка в парке',
      purposeLabel: 'Найти партнёров для утренней пробежки',
      fullDescription:
          'Ищу компанию для регулярных утренних пробежек по парку. Темп '
          'спокойный, для новичков подходит. Встречаемся у фонтана и бежим '
          'вдоль канала.',
      category: 'sport_fitness',
      subcategory: 'running',
      scheduleMode: PublishedFindPeopleScheduleMode.single,
      timeOptions: <PublishedFindPeopleTimeOption>[
        PublishedFindPeopleTimeOption(
          id: 'fp_slot_morning_run_2026_09_12',
          startAtUtc: DateTime.utc(2026, 9, 12, 5),
          endAtUtc: DateTime.utc(2026, 9, 12, 6),
          kind: PublishedFindPeopleTimeOptionKind.confirmed,
        ),
      ],
      timezoneId: 'Europe/Riga',
      durationMinutes: 60,
      currentGroupSize: 3,
      targetGroupSize: 6,
      remainingSeats: 3,
      recruitmentStatus: PublishedFindPeopleRecruitmentStatus.open,
      skillLevelLabel: 'Новички и продолжающие',
      paceLabel: 'Спокойный темп',
      languageLabels: const <String>['Русский', 'English'],
      publicRequirements: const <String>['Базовый уровень бега'],
      equipmentNote: 'Своя обувь для бега',
      accessibilityNote: 'Маршрут можно сократить по договорённости',
      costType: PublishedFindPeopleCostType.free,
      costNote: 'Участие и ожидаемые обязательные расходы — 0',
      publicLocation: PublishedFindPeoplePointLocation(
        meetingMode: PublishedFindPeopleMeetingMode.inPerson,
        areaLabel: 'Верманский парк, Рига',
        latitude: 56.9537,
        longitude: 24.1138,
      ),
      publishedAtUtc: DateTime.utc(2026, 9, 1),
    );
  }
}
