import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../domain/entities/scenario_transit_schedule.dart';
import 'gtfs_csv_reader.dart';
import 'gtfs_schedule_index.dart';

class GtfsArchiveLimits {
  const GtfsArchiveLimits({
    this.maxCompressedBytes = 64 * 1024 * 1024,
    this.maxUncompressedBytes = 256 * 1024 * 1024,
    this.maxEntryBytes = 192 * 1024 * 1024,
    this.maxEntries = 64,
    this.maxExpansionRatio = 200,
  });

  final int maxCompressedBytes;
  final int maxUncompressedBytes;
  final int maxEntryBytes;
  final int maxEntries;
  final int maxExpansionRatio;
}

class GtfsArchiveParser {
  const GtfsArchiveParser({
    this.limits = const GtfsArchiveLimits(),
    this.csvReader = const GtfsCsvReader(),
  });

  final GtfsArchiveLimits limits;
  final GtfsCsvReader csvReader;

  GtfsScheduleIndex parse({
    required List<int> archiveBytes,
    required String providerCode,
    required String providerDisplayName,
    required String licenseName,
    required String sourceUrl,
    required DateTime retrievedAtUtc,
    required Duration freshnessMaxAge,
    DateTime? nowUtc,
  }) {
    if (!RegExp(r'^[a-z0-9_]{3,64}$').hasMatch(providerCode) ||
        providerDisplayName.trim().isEmpty ||
        licenseName.trim().isEmpty ||
        Uri.tryParse(sourceUrl)?.scheme != 'https') {
      throw const FormatException('GTFS provider metadata is invalid.');
    }
    if (archiveBytes.isEmpty ||
        archiveBytes.length > limits.maxCompressedBytes) {
      throw const FormatException('GTFS archive has an invalid size.');
    }
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
    } on Object {
      throw const FormatException('GTFS archive is not a valid ZIP.');
    }
    if (archive.length > limits.maxEntries) {
      throw const FormatException('GTFS archive contains too many entries.');
    }

    final files = <String, List<int>>{};
    var totalSize = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name.contains('/') ||
          name.contains('\\') ||
          name == '.' ||
          name == '..') {
        throw const FormatException(
          'GTFS files must be at the ZIP root level.',
        );
      }
      final normalized = name.toLowerCase();
      if (normalized.endsWith('.zip')) {
        throw const FormatException('Nested archives are not allowed.');
      }
      if (entry.size > limits.maxEntryBytes) {
        throw FormatException('$name exceeds the entry size limit.');
      }
      totalSize += entry.size;
      if (totalSize > limits.maxUncompressedBytes ||
          totalSize > archiveBytes.length * limits.maxExpansionRatio) {
        throw const FormatException('GTFS archive expansion limit exceeded.');
      }
      if (files.containsKey(normalized)) {
        throw FormatException('GTFS archive contains duplicate $name.');
      }
      final content = entry.content;
      if (content is! List<int>) {
        throw FormatException('Unable to decode $name.');
      }
      files[normalized] = List<int>.unmodifiable(content);
    }

    const required = <String>{
      'agency.txt',
      'stops.txt',
      'routes.txt',
      'trips.txt',
      'stop_times.txt',
    };
    final missing = required.difference(files.keys.toSet());
    if (missing.isNotEmpty) {
      throw FormatException(
        'GTFS archive is missing ${missing.toList()..sort()}.',
      );
    }
    if (!files.containsKey('calendar.txt') &&
        !files.containsKey('calendar_dates.txt')) {
      throw const FormatException(
        'GTFS requires calendar.txt or calendar_dates.txt.',
      );
    }

    final agencies = _parseAgencies(files['agency.txt']!);
    final stops = _parseStops(providerCode, files['stops.txt']!);
    final routes = _parseRoutes(files['routes.txt']!, agencies);
    final trips = _parseTrips(files['trips.txt']!);
    final calendars = _parseCalendars(
      calendarBytes: files['calendar.txt'],
      exceptionBytes: files['calendar_dates.txt'],
    );
    for (final trip in trips.values) {
      if (!routes.containsKey(trip.routeId)) {
        throw FormatException(
          'trips.txt references unknown route ${trip.routeId}.',
        );
      }
      if (!calendars.containsKey(trip.serviceId)) {
        throw FormatException(
          'trips.txt references unknown service ${trip.serviceId}.',
        );
      }
    }
    final stopTimes = _parseStopTimes(files['stop_times.txt']!, stops, trips);
    final feedInfo = files['feed_info.txt'] == null
        ? const <String, String>{}
        : _parseFeedInfo(files['feed_info.txt']!);

    final indexedTrips = <String, GtfsIndexedTrip>{};
    for (final trip in trips.values) {
      final times = stopTimes[trip.id] ?? const <GtfsIndexedStopTime>[];
      if (times.length < 2 || !calendars.containsKey(trip.serviceId)) {
        continue;
      }
      indexedTrips[trip.id] = GtfsIndexedTrip(
        id: trip.id,
        routeId: trip.routeId,
        serviceId: trip.serviceId,
        stopTimes: List<GtfsIndexedStopTime>.unmodifiable(times),
        headsign: trip.headsign,
      );
    }

    final currentTime = (nowUtc ?? DateTime.now()).toUtc();
    final retrieval = retrievedAtUtc.toUtc();
    final startDate = _parseDateOrNull(feedInfo['feed_start_date']);
    final endDate = _parseDateOrNull(feedInfo['feed_end_date']);
    final freshness = currentTime.difference(retrieval) > freshnessMaxAge
        ? ScenarioTransitFreshness.stale
        : startDate == null || endDate == null
        ? ScenarioTransitFreshness.unknown
        : ScenarioTransitFreshness.current;
    final manifest = ScenarioTransitFeedManifest(
      providerCode: providerCode,
      providerDisplayName: providerDisplayName,
      licenseName: licenseName,
      sourceUrl: sourceUrl,
      retrievedAtUtc: retrieval,
      sha256: sha256.convert(archiveBytes).toString(),
      freshness: freshness,
      feedPublisherName: _nullIfEmpty(feedInfo['feed_publisher_name']),
      feedVersion: _nullIfEmpty(feedInfo['feed_version']),
      feedStartDate: startDate,
      feedEndDate: endDate,
    );
    return GtfsScheduleIndex(
      manifest: manifest,
      stops: stops,
      routes: routes,
      trips: indexedTrips,
      calendars: calendars,
    );
  }

  Map<String, String> _parseAgencies(List<int> bytes) {
    final table = csvReader.read('agency.txt', bytes);
    _requireHeaders(table, const <String>{'agency_name', 'agency_timezone'});
    final agencies = <String, String>{};
    for (var index = 0; index < table.rows.length; index++) {
      final row = table.rows[index];
      final id = _nullIfEmpty(row['agency_id']) ?? '__single_agency__';
      final name = _required(row, 'agency_name', table.fileName, index);
      if (agencies.containsKey(id)) {
        throw FormatException('agency.txt contains duplicate agency_id $id.');
      }
      agencies[id] = name;
    }
    if (agencies.isEmpty) {
      throw const FormatException('agency.txt must contain an agency.');
    }
    return agencies;
  }

  Map<String, ScenarioTransitStop> _parseStops(
    String providerCode,
    List<int> bytes,
  ) {
    final table = csvReader.read('stops.txt', bytes);
    _requireHeaders(table, const <String>{'stop_id', 'stop_name'});
    final stops = <String, ScenarioTransitStop>{};
    for (var index = 0; index < table.rows.length; index++) {
      final row = table.rows[index];
      final id = _required(row, 'stop_id', table.fileName, index);
      if (stops.containsKey(id)) {
        throw FormatException('stops.txt contains duplicate stop_id $id.');
      }
      final latitude = _coordinate(row['stop_lat'], latitude: true);
      final longitude = _coordinate(row['stop_lon'], latitude: false);
      if ((latitude == null) != (longitude == null)) {
        throw FormatException('stops.txt stop $id has incomplete coordinates.');
      }
      stops[id] = ScenarioTransitStop(
        providerCode: providerCode,
        id: id,
        name: _required(row, 'stop_name', table.fileName, index),
        parentStationId: _nullIfEmpty(row['parent_station']),
        latitude: latitude,
        longitude: longitude,
      );
    }
    if (stops.isEmpty) {
      throw const FormatException('stops.txt must contain a stop.');
    }
    return stops;
  }

  Map<String, GtfsIndexedRoute> _parseRoutes(
    List<int> bytes,
    Map<String, String> agencies,
  ) {
    final table = csvReader.read('routes.txt', bytes);
    _requireHeaders(table, const <String>{'route_id', 'route_type'});
    final routes = <String, GtfsIndexedRoute>{};
    for (var index = 0; index < table.rows.length; index++) {
      final row = table.rows[index];
      final id = _required(row, 'route_id', table.fileName, index);
      if (routes.containsKey(id)) {
        throw FormatException('routes.txt contains duplicate route_id $id.');
      }
      final type = int.tryParse(
        _required(row, 'route_type', table.fileName, index),
      );
      if (type == null || type < 0) {
        throw FormatException('routes.txt route $id has invalid route_type.');
      }
      final agencyId = _nullIfEmpty(row['agency_id']);
      final agencyName = agencyId == null
          ? agencies.length == 1
                ? agencies.values.single
                : null
          : agencies[agencyId];
      if (agencyId == null && agencies.length > 1) {
        throw FormatException(
          'routes.txt route $id requires agency_id for a multi-agency feed.',
        );
      }
      if (agencyId != null && agencyName == null) {
        throw FormatException(
          'routes.txt references unknown agency $agencyId.',
        );
      }
      final shortName = _nullIfEmpty(row['route_short_name']);
      final longName = _nullIfEmpty(row['route_long_name']);
      if (shortName == null && longName == null) {
        throw FormatException('routes.txt route $id has no public name.');
      }
      routes[id] = GtfsIndexedRoute(
        id: id,
        mode: _modeForRouteType(type),
        agencyName: agencyName,
        label: shortName ?? longName,
      );
    }
    if (routes.isEmpty) {
      throw const FormatException('routes.txt must contain a route.');
    }
    return routes;
  }

  Map<String, _RawTrip> _parseTrips(List<int> bytes) {
    final table = csvReader.read('trips.txt', bytes);
    _requireHeaders(table, const <String>{'route_id', 'service_id', 'trip_id'});
    final trips = <String, _RawTrip>{};
    for (var index = 0; index < table.rows.length; index++) {
      final row = table.rows[index];
      final id = _required(row, 'trip_id', table.fileName, index);
      if (trips.containsKey(id)) {
        throw FormatException('trips.txt contains duplicate trip_id $id.');
      }
      trips[id] = _RawTrip(
        id: id,
        routeId: _required(row, 'route_id', table.fileName, index),
        serviceId: _required(row, 'service_id', table.fileName, index),
        headsign: _nullIfEmpty(row['trip_headsign']),
      );
    }
    if (trips.isEmpty) {
      throw const FormatException('trips.txt must contain a trip.');
    }
    return trips;
  }

  Map<String, List<GtfsIndexedStopTime>> _parseStopTimes(
    List<int> bytes,
    Map<String, ScenarioTransitStop> stops,
    Map<String, _RawTrip> trips,
  ) {
    final result = <String, List<GtfsIndexedStopTime>>{};
    final headers = csvReader.visitRows('stop_times.txt', bytes, (row, index) {
      final tripId = _required(row, 'trip_id', 'stop_times.txt', index);
      final stopId = _required(row, 'stop_id', 'stop_times.txt', index);
      if (!trips.containsKey(tripId) || !stops.containsKey(stopId)) {
        throw FormatException(
          'stop_times.txt references an unknown trip or stop.',
        );
      }
      final sequence = int.tryParse(
        _required(row, 'stop_sequence', 'stop_times.txt', index),
      );
      if (sequence == null || sequence < 0) {
        throw FormatException('stop_times.txt has invalid stop_sequence.');
      }
      final arrival = _parseTimeOrNull(row['arrival_time']);
      final departure = _parseTimeOrNull(row['departure_time']);
      if (arrival == null && departure == null) {
        return;
      }
      result
          .putIfAbsent(tripId, () => <GtfsIndexedStopTime>[])
          .add(
            GtfsIndexedStopTime(
              stopId: stopId,
              sequence: sequence,
              arrivalSeconds: arrival ?? departure!,
              departureSeconds: departure ?? arrival!,
            ),
          );
    });
    _requireHeaders(
      GtfsCsvTable('stop_times.txt', headers, const <Map<String, String>>[]),
      const <String>{'trip_id', 'stop_id', 'stop_sequence'},
    );
    for (final entry in result.entries) {
      entry.value.sort(
        (left, right) => left.sequence.compareTo(right.sequence),
      );
      for (final stopTime in entry.value) {
        if (stopTime.arrivalSeconds > stopTime.departureSeconds) {
          throw FormatException(
            'stop_times.txt trip ${entry.key} departs before arrival.',
          );
        }
      }
      for (var index = 1; index < entry.value.length; index++) {
        if (entry.value[index - 1].sequence == entry.value[index].sequence) {
          throw FormatException(
            'stop_times.txt trip ${entry.key} has duplicate stop_sequence.',
          );
        }
        if (entry.value[index - 1].departureSeconds >
            entry.value[index].arrivalSeconds) {
          throw FormatException(
            'stop_times.txt trip ${entry.key} has decreasing times.',
          );
        }
      }
    }
    return result;
  }

  Map<String, GtfsServiceCalendar> _parseCalendars({
    List<int>? calendarBytes,
    List<int>? exceptionBytes,
  }) {
    final base = <String, _MutableCalendar>{};
    if (calendarBytes != null) {
      final table = csvReader.read('calendar.txt', calendarBytes);
      _requireHeaders(table, const <String>{
        'service_id',
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
        'start_date',
        'end_date',
      });
      for (var index = 0; index < table.rows.length; index++) {
        final row = table.rows[index];
        final id = _required(row, 'service_id', table.fileName, index);
        if (base.containsKey(id)) {
          throw FormatException(
            'calendar.txt contains duplicate service_id $id.',
          );
        }
        const weekdayFields = <String>[
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ];
        if (weekdayFields.any(
          (field) => row[field] != '0' && row[field] != '1',
        )) {
          throw FormatException('calendar.txt service $id has invalid flags.');
        }
        final startDate = _requiredDate(
          row,
          'start_date',
          table.fileName,
          index,
        );
        final endDate = _requiredDate(row, 'end_date', table.fileName, index);
        if (startDate.compareTo(endDate) > 0) {
          throw FormatException(
            'calendar.txt service $id has an inverted date range.',
          );
        }
        base[id] = _MutableCalendar(
          serviceId: id,
          weekdays: <int>{
            if (row['monday'] == '1') DateTime.monday,
            if (row['tuesday'] == '1') DateTime.tuesday,
            if (row['wednesday'] == '1') DateTime.wednesday,
            if (row['thursday'] == '1') DateTime.thursday,
            if (row['friday'] == '1') DateTime.friday,
            if (row['saturday'] == '1') DateTime.saturday,
            if (row['sunday'] == '1') DateTime.sunday,
          },
          startDate: startDate,
          endDate: endDate,
        );
      }
    }
    if (exceptionBytes != null) {
      final table = csvReader.read('calendar_dates.txt', exceptionBytes);
      _requireHeaders(table, const <String>{
        'service_id',
        'date',
        'exception_type',
      });
      for (var index = 0; index < table.rows.length; index++) {
        final row = table.rows[index];
        final id = _required(row, 'service_id', table.fileName, index);
        final type = _required(row, 'exception_type', table.fileName, index);
        if (type != '1' && type != '2') {
          throw FormatException('calendar_dates.txt has invalid exception.');
        }
        final calendar = base.putIfAbsent(
          id,
          () => _MutableCalendar(serviceId: id, weekdays: const <int>{}),
        );
        final date = _requiredDate(row, 'date', table.fileName, index);
        if (calendar.exceptions.containsKey(date)) {
          throw const FormatException(
            'calendar_dates.txt contains duplicate service/date.',
          );
        }
        calendar.exceptions[date] = type == '1';
      }
    }
    if (base.isEmpty) {
      throw const FormatException('GTFS must define at least one service.');
    }
    return <String, GtfsServiceCalendar>{
      for (final entry in base.entries) entry.key: entry.value.freeze(),
    };
  }

  Map<String, String> _parseFeedInfo(List<int> bytes) {
    final table = csvReader.read('feed_info.txt', bytes);
    _requireHeaders(table, const <String>{
      'feed_publisher_name',
      'feed_publisher_url',
      'feed_lang',
    });
    if (table.rows.length != 1) {
      throw const FormatException('feed_info.txt must contain one row.');
    }
    return table.rows.single;
  }

  void _requireHeaders(GtfsCsvTable table, Set<String> required) {
    final present = table.headers.toSet();
    final missing = required.difference(present);
    if (missing.isNotEmpty) {
      throw FormatException(
        '${table.fileName} is missing headers ${missing.toList()..sort()}.',
      );
    }
  }

  String _required(
    Map<String, String> row,
    String field,
    String fileName,
    int rowIndex,
  ) {
    final value = _nullIfEmpty(row[field]);
    if (value == null) {
      throw FormatException('$fileName row ${rowIndex + 2} requires $field.');
    }
    return value;
  }

  ScenarioTransitLocalDate _requiredDate(
    Map<String, String> row,
    String field,
    String fileName,
    int rowIndex,
  ) {
    final result = _parseDateOrNull(_required(row, field, fileName, rowIndex));
    if (result == null) {
      throw FormatException(
        '$fileName row ${rowIndex + 2} has invalid $field.',
      );
    }
    return result;
  }

  ScenarioTransitLocalDate? _parseDateOrNull(String? value) {
    final text = _nullIfEmpty(value);
    if (text == null || !RegExp(r'^\d{8}$').hasMatch(text)) return null;
    final result = ScenarioTransitLocalDate(
      int.parse(text.substring(0, 4)),
      int.parse(text.substring(4, 6)),
      int.parse(text.substring(6, 8)),
    );
    return result.isValid ? result : null;
  }

  int? _parseTimeOrNull(String? value) {
    final text = _nullIfEmpty(value);
    if (text == null) return null;
    final match = RegExp(r'^(\d{1,3}):([0-5]\d):([0-5]\d)$').firstMatch(text);
    if (match == null) {
      throw FormatException('Invalid GTFS time $text.');
    }
    final hours = int.parse(match.group(1)!);
    if (hours > 47) {
      throw FormatException('GTFS time exceeds the supported service day.');
    }
    return hours * 3600 +
        int.parse(match.group(2)!) * 60 +
        int.parse(match.group(3)!);
  }

  double? _coordinate(String? value, {required bool latitude}) {
    final text = _nullIfEmpty(value);
    if (text == null) return null;
    final parsed = double.tryParse(text);
    final minimum = latitude ? -90 : -180;
    final maximum = latitude ? 90 : 180;
    if (parsed == null ||
        !parsed.isFinite ||
        parsed < minimum ||
        parsed > maximum) {
      throw const FormatException('GTFS contains invalid coordinates.');
    }
    return parsed;
  }

  ScenarioTransitMode _modeForRouteType(int type) {
    if (type == 0 || (type >= 900 && type < 1000)) {
      return ScenarioTransitMode.tram;
    }
    if (type == 2 || (type >= 100 && type < 200)) {
      return ScenarioTransitMode.train;
    }
    if (type == 3 || (type >= 700 && type < 800)) {
      return ScenarioTransitMode.bus;
    }
    if (type == 11 || (type >= 800 && type < 900)) {
      return ScenarioTransitMode.trolleybus;
    }
    return ScenarioTransitMode.other;
  }

  String? _nullIfEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class _RawTrip {
  const _RawTrip({
    required this.id,
    required this.routeId,
    required this.serviceId,
    this.headsign,
  });

  final String id;
  final String routeId;
  final String serviceId;
  final String? headsign;
}

class _MutableCalendar {
  _MutableCalendar({
    required this.serviceId,
    required this.weekdays,
    this.startDate,
    this.endDate,
  });

  final String serviceId;
  final Set<int> weekdays;
  final ScenarioTransitLocalDate? startDate;
  final ScenarioTransitLocalDate? endDate;
  final Map<ScenarioTransitLocalDate, bool> exceptions =
      <ScenarioTransitLocalDate, bool>{};

  GtfsServiceCalendar freeze() => GtfsServiceCalendar(
    serviceId: serviceId,
    weekdays: Set<int>.unmodifiable(weekdays),
    startDate: startDate,
    endDate: endDate,
    exceptions: exceptions,
  );
}
