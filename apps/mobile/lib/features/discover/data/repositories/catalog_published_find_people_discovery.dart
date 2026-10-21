import 'dart:math' as math;

import '../../domain/entities/published_find_people_discovery_entity.dart';
import '../../domain/repositories/discover_repository.dart';
import '../../domain/repositories/published_find_people_discovery_port.dart';
import '../datasources/catalog_query_port.dart';
import '../models/catalog_wire_models.dart';
import 'catalog_snapshot_session.dart';

/// Find People Details over the server Catalog (D3.7, Emulator-only). The
/// public location is the server's ~1 km cell centre and its area label;
/// exact meeting data never reaches this adapter. Hidden, revoked, expired,
/// blocked or sanctioned requests answer `null`, never a stale copy, and the
/// answer is kept in memory only (nothing is written to disk).
final class CatalogPublishedFindPeopleDiscovery
    implements PublishedFindPeopleDiscoveryPort {
  CatalogPublishedFindPeopleDiscovery({
    required CatalogQueryPort port,
    required CatalogSnapshotSession session,
    String Function()? newRequestId,
  }) : _port = port,
       _session = session,
       _newRequestId = newRequestId ?? _randomRequestId;

  final CatalogQueryPort _port;
  final CatalogSnapshotSession _session;
  final String Function() _newRequestId;

  @override
  Future<PublishedFindPeopleDiscoveryEntity?> getActiveFindPeopleRequest(
    String requestId,
  ) async {
    final String? token = _session.snapshotToken;
    final Map<String, Object?>? query = _session.query;
    CatalogAnswer answer = await _ask(<String, Object?>{
      'contentId': requestId,
      if (token != null && query != null) ...<String, Object?>{
        'snapshotToken': token,
        'query': query,
      },
    });
    if (answer.kind == 'stale' && token != null) {
      // The listing snapshot expired or was superseded: read the current object.
      answer = await _ask(<String, Object?>{'contentId': requestId});
    }
    if (!answer.succeeded) {
      throw DiscoverException(
        code: 'CATALOG_${answer.kind.toUpperCase()}:${answer.code}',
        message: 'Каталог отклонил запрос',
      );
    }
    final CatalogDetails details;
    try {
      details = CatalogDetails.fromWire(answer.body);
    } on FormatException {
      throw const DiscoverException(
        code: 'CATALOG_CONTRACT_INVALID',
        message: 'Неподдерживаемый ответ каталога',
      );
    }
    final CatalogFindPeopleItem? item = details.findPeople;
    if (item == null) return null;
    return _entity(item);
  }

  Future<CatalogAnswer> _ask(Map<String, Object?> payload) async {
    try {
      return CatalogAnswer.fromWire(
        await _port.query(<String, Object?>{
          'schemaVersion': 1,
          'requestId': _newRequestId(),
          'queryType': 'details',
          'payload': payload,
        }),
      );
    } on CatalogTransportFailure catch (failure) {
      throw DiscoverException(
        code: 'CATALOG_TRANSPORT_${failure.code}',
        message: 'Каталог недоступен',
      );
    } on FormatException {
      throw const DiscoverException(
        code: 'CATALOG_CONTRACT_INVALID',
        message: 'Неподдерживаемый ответ каталога',
      );
    }
  }

  static PublishedFindPeopleCostType _cost(String value) => switch (value) {
    'free' => PublishedFindPeopleCostType.free,
    'estimated' => PublishedFindPeopleCostType.estimated,
    'unknown' => PublishedFindPeopleCostType.unknown,
    _ => throw const DiscoverException(
      code: 'CATALOG_CONTRACT_INVALID',
      message: 'Неподдерживаемый ответ каталога',
    ),
  };

  PublishedFindPeopleDiscoveryEntity _entity(CatalogFindPeopleItem item) {
    final int minutes = item.endAtUtc.difference(item.startAtUtc).inMinutes;
    final int? spend = item.expectedSpendMinor;
    return PublishedFindPeopleDiscoveryEntity(
      requestId: item.contentId,
      occurrenceId: item.occurrenceId,
      publisherId: item.publisherId ?? '',
      publisherType: item.publisherType ?? '',
      // The Catalog carries no publisher display name; never invented.
      publisherName: '',
      title: item.title,
      fullDescription: item.fullDescription ?? '',
      category: item.categoryId,
      subcategory: item.subcategoryId,
      scheduleMode: PublishedFindPeopleScheduleMode.single,
      timeOptions: <PublishedFindPeopleTimeOption>[
        PublishedFindPeopleTimeOption(
          id: item.occurrenceId,
          startAtUtc: item.startAtUtc,
          endAtUtc: item.endAtUtc,
          kind: PublishedFindPeopleTimeOptionKind.confirmed,
        ),
      ],
      timezoneId: item.timezoneId,
      durationMinutes: minutes > 0 ? minutes : null,
      targetGroupSize: item.targetGroupSize,
      // Applications are not served in T3: no seat or member counts are shown.
      recruitmentStatus: PublishedFindPeopleRecruitmentStatus.open,
      skillLevelLabel: item.skillLevel,
      languageLabels: item.languageCodes,
      costType: _cost(item.costType),
      expectedSpendAmount: spend == null ? null : spend / 100,
      currencyCode: item.currencyCode ?? '',
      publicLocation: PublishedFindPeoplePointLocation(
        meetingMode: PublishedFindPeopleMeetingMode.inPerson,
        areaLabel: item.publicAreaLabel,
        latitude: item.point.latitude,
        longitude: item.point.longitude,
      ),
      publishedAtUtc: item.publishedAtUtc!,
    );
  }
}

final math.Random _random = math.Random.secure();

String _randomRequestId() {
  final String suffix = List<String>.generate(
    16,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
  return 'discover-$suffix';
}
