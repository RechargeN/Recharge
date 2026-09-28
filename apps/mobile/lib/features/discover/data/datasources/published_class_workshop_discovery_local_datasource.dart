import '../../domain/entities/published_class_workshop_discovery_entity.dart';
import '../../domain/repositories/published_class_workshop_discovery_port.dart';

typedef ClassWorkshopFixtureBuilder =
    PublishedClassWorkshopDiscoveryEntity Function();

/// Read-only demo; no external provider or Create publication integration.
class PublishedClassWorkshopDiscoveryLocalDataSource
    implements PublishedClassWorkshopDiscoveryPort {
  PublishedClassWorkshopDiscoveryLocalDataSource({
    Map<String, ClassWorkshopFixtureBuilder>? fixtureBuilders,
    Set<String> hiddenIds = const {},
  }) : _builders = Map.unmodifiable(fixtureBuilders ?? {demoOfferingId: _demo}),
       _hiddenIds = Set.unmodifiable(hiddenIds);

  static const demoOfferingId = '01K4K3RXRX1V4JVPGWBK4QFET6';
  final Map<String, ClassWorkshopFixtureBuilder> _builders;
  final Set<String> _hiddenIds;

  @override
  Future<PublishedClassWorkshopDiscoveryEntity?> getActiveClassWorkshop(
    String offeringId,
  ) async {
    if (_hiddenIds.contains(offeringId)) return null;
    try {
      final value = _builders[offeringId]?.call();
      return value?.offeringId == offeringId ? value : null;
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }
}

PublishedClassWorkshopDiscoveryEntity
_demo() => PublishedClassWorkshopDiscoveryEntity(
  offeringId: PublishedClassWorkshopDiscoveryLocalDataSource.demoOfferingId,
  revision: 1,
  publishedAtUtc: DateTime.utc(2026, 9, 8),
  publisherId: '01K4K3RXRX1V4JVPGWBK4QFET7',
  publisherType: 'page',
  publisherName: 'Студия керамики · демо',
  instructor: ClassWorkshopGuestInstructor(name: 'Анна · демо'),
  title: 'Керамика своими руками · демо',
  kind: ClassWorkshopKind.workshop,
  category: 'workshops_masterclasses',
  subcategory: 'workshop',
  disciplineLabel: 'Гончарное дело',
  levelLabel: 'Для начинающих',
  languageLabels: ['Русский'],
  fullDescription:
      'Демонстрационное занятие: создайте чашку и познакомьтесь с работой с глиной. Реальная запись не подключена.',
  learningOutcomes: ['Основы ручной лепки'],
  includedMaterials: ['Глина и инструменты'],
  requirements: ['Одежда, которую не жалко испачкать'],
  displayContextId: '01K4K3RXRX1V4JVPGWBK4QFET8',
  contextKind: ClassWorkshopContextKind.singleClass,
  schedule: const ClassWorkshopDatesNotAnnounced(),
  declaredGroupLimit: 8,
  durationMinutes: 120,
  durationScope: ClassWorkshopDurationScope.perClass,
  price: ClassWorkshopPriceFixed(
    amountMinor: 3500,
    currencyCode: 'EUR',
    minorUnitDigits: 2,
    scope: ClassWorkshopPriceScope.perPersonPerClass,
  ),
  publicLocation: const ClassWorkshopOnlineLocation(
    providerLabel: 'Платформа уточняется',
  ),
  enrollment: const ClassWorkshopInformationOnly(
    ClassWorkshopInformationReason.notProvided,
  ),
);
