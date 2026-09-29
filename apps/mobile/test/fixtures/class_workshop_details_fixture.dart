import 'package:recharge/features/discover/domain/entities/published_class_workshop_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/publisher_verification_display_state.dart';

PublishedClassWorkshopDiscoveryEntity classWorkshopFixture({
  String id = 'class-1',
  String publisherId = 'page-1',
  String contextId = 'run-1',
  int revision = 1,
  DateTime? publishedAtUtc,
  String title = 'Мастер-класс по гончарному делу',
  String publisherName = 'Студия «Глина»',
  ClassWorkshopInstructor? instructor,
  ClassWorkshopContextKind contextKind = ClassWorkshopContextKind.singleClass,
  ClassWorkshopSchedule? schedule,
  ClassWorkshopPrice? price,
  ClassWorkshopEnrollment? enrollment,
  ClassWorkshopPublicLocation? location,
  int? groupLimit = 8,
  int? durationMinutes = 120,
  ClassWorkshopDurationScope durationScope =
      ClassWorkshopDurationScope.perClass,
  String description =
      'Познакомитесь с основами гончарного круга и слепите свою первую чашку.',
  String shortDescription = '',
  List<String> outcomes = const ['Основы работы с глиной'],
  List<String> materials = const ['Глина, инструменты и обжиг'],
  List<String> requirements = const ['Удобная одежда'],
  String cover = '',
  List<String> gallery = const [],
}) => PublishedClassWorkshopDiscoveryEntity(
  offeringId: id,
  revision: revision,
  publishedAtUtc: publishedAtUtc ?? DateTime.utc(2026, 9, 1),
  publisherId: publisherId,
  publisherType: 'page',
  publisherName: publisherName,
  publisherHandle: '@clay_studio',
  publisherVerification: PublisherVerificationDisplayState.verifiedPage,
  instructor:
      instructor ??
      ClassWorkshopGuestInstructor(
        name: 'Ирина Смирнова',
        handle: '@irina_ceramics',
      ),
  title: title,
  kind: ClassWorkshopKind.masterclass,
  category: 'workshops_masterclasses',
  subcategory: 'workshop',
  disciplineLabel: 'Гончарное дело',
  levelLabel: 'Для начинающих',
  languageLabels: ['Русский'],
  fullDescription: description,
  shortDescription: shortDescription,
  learningOutcomes: outcomes,
  includedMaterials: materials,
  requirements: requirements,
  coverImageUrl: cover,
  galleryImageUrls: gallery,
  displayContextId: contextId,
  contextKind: contextKind,
  schedule: schedule ?? ClassWorkshopAnnouncedSchedule([classOccurrence()]),
  price:
      price ??
      ClassWorkshopPriceFixed(
        amountMinor: 2500,
        currencyCode: 'EUR',
        minorUnitDigits: 2,
        scope: ClassWorkshopPriceScope.perPersonPerClass,
      ),
  enrollment:
      enrollment ??
      ClassWorkshopExternalEnrollment(
        Uri.parse('https://booking.example/class?source=organizer'),
      ),
  publicLocation:
      location ??
      ClassWorkshopPointLocation(
        delivery: ClassWorkshopDelivery.offline,
        venueName: 'Студия «Глина»',
        areaLabel: 'Рига',
        publicAddress: 'Brīvības iela 55, Rīga',
        latitude: 56.95,
        longitude: 24.1,
        precisionMeters: 50,
      ),
  declaredGroupLimit: groupLimit,
  durationMinutes: durationMinutes,
  durationScope: durationMinutes == null ? null : durationScope,
);

ClassWorkshopOccurrence classOccurrence({
  String id = 'occ-1',
  DateTime? start,
  DateTime? end,
  String timezone = 'Europe/Riga',
}) => ClassWorkshopOccurrence(
  occurrenceId: id,
  startAtUtc: start ?? DateTime.utc(2026, 9, 12, 10),
  endAtUtc: end ?? DateTime.utc(2026, 9, 12, 12),
  timezoneId: timezone,
  title: 'Практика за гончарным кругом',
);
