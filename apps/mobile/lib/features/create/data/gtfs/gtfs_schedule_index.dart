import '../../domain/entities/scenario_transit_schedule.dart';

class GtfsScheduleIndex {
  GtfsScheduleIndex({
    required this.manifest,
    required Map<String, ScenarioTransitStop> stops,
    required Map<String, GtfsIndexedRoute> routes,
    required Map<String, GtfsIndexedTrip> trips,
    required Map<String, GtfsServiceCalendar> calendars,
  }) : _stops = Map<String, ScenarioTransitStop>.unmodifiable(stops),
       _routes = Map<String, GtfsIndexedRoute>.unmodifiable(routes),
       _trips = Map<String, GtfsIndexedTrip>.unmodifiable(trips),
       _calendars = Map<String, GtfsServiceCalendar>.unmodifiable(calendars) {
    final children = <String, Set<String>>{};
    for (final stop in _stops.values) {
      final parent = stop.parentStationId;
      if (parent != null && parent.isNotEmpty) {
        children.putIfAbsent(parent, () => <String>{}).add(stop.id);
      }
    }
    _stationChildren = <String, Set<String>>{
      for (final entry in children.entries)
        entry.key: Set<String>.unmodifiable(entry.value),
    };
  }

  final ScenarioTransitFeedManifest manifest;
  final Map<String, ScenarioTransitStop> _stops;
  final Map<String, GtfsIndexedRoute> _routes;
  final Map<String, GtfsIndexedTrip> _trips;
  final Map<String, GtfsServiceCalendar> _calendars;
  late final Map<String, Set<String>> _stationChildren;

  int get stopCount => _stops.length;
  int get routeCount => _routes.length;
  int get tripCount => _trips.length;
  int get serviceCount => _calendars.length;

  List<ScenarioTransitStop> searchStops(String query, {int limit = 20}) {
    final normalized = _normalize(query);
    if (normalized.isEmpty || limit <= 0) {
      return const <ScenarioTransitStop>[];
    }
    final matches =
        _stops.values
            .where((stop) => _normalize(stop.name).contains(normalized))
            .toList()
          ..sort((left, right) {
            final leftName = _normalize(left.name);
            final rightName = _normalize(right.name);
            final prefixOrder = (rightName.startsWith(normalized) ? 1 : 0)
                .compareTo(leftName.startsWith(normalized) ? 1 : 0);
            if (prefixOrder != 0) return prefixOrder;
            final nameOrder = leftName.compareTo(rightName);
            if (nameOrder != 0) return nameOrder;
            return left.id.compareTo(right.id);
          });
    return List<ScenarioTransitStop>.unmodifiable(matches.take(limit));
  }

  List<ScenarioTransitServiceOption> searchServices(
    ScenarioTransitSearchQuery query,
  ) {
    if (!_stops.containsKey(query.originStopId) ||
        !_stops.containsKey(query.destinationStopId)) {
      return const <ScenarioTransitServiceOption>[];
    }
    final originIds = _equivalentStopIds(query.originStopId);
    final destinationIds = _equivalentStopIds(query.destinationStopId);
    final options = <ScenarioTransitServiceOption>[];

    for (final trip in _trips.values) {
      final calendar = _calendars[trip.serviceId];
      if (calendar == null || !calendar.runsOn(query.serviceDate)) {
        continue;
      }
      final route = _routes[trip.routeId];
      if (route == null ||
          (query.allowedModes.isNotEmpty &&
              !query.allowedModes.contains(route.mode))) {
        continue;
      }

      var tripAdded = false;
      for (
        var originIndex = 0;
        originIndex < trip.stopTimes.length - 1;
        originIndex++
      ) {
        if (tripAdded) break;
        final originTime = trip.stopTimes[originIndex];
        if (!originIds.contains(originTime.stopId) ||
            originTime.departureSeconds <
                query.departAfter.secondsFromServiceDay) {
          continue;
        }
        for (
          var destinationIndex = originIndex + 1;
          destinationIndex < trip.stopTimes.length;
          destinationIndex++
        ) {
          final destinationTime = trip.stopTimes[destinationIndex];
          if (!destinationIds.contains(destinationTime.stopId) ||
              destinationTime.arrivalSeconds < originTime.departureSeconds) {
            continue;
          }
          options.add(
            ScenarioTransitServiceOption(
              providerCode: manifest.providerCode,
              tripId: trip.id,
              routeId: route.id,
              serviceId: trip.serviceId,
              mode: route.mode,
              origin: _stops[originTime.stopId]!,
              destination: _stops[destinationTime.stopId]!,
              departure: ScenarioTransitTime(originTime.departureSeconds),
              arrival: ScenarioTransitTime(destinationTime.arrivalSeconds),
              manifest: _manifestForDate(query.serviceDate),
              agencyName: route.agencyName,
              routeLabel: route.label,
              headsign: trip.headsign,
            ),
          );
          tripAdded = true;
          break;
        }
      }
    }

    options.sort((left, right) {
      var order = left.departure.compareTo(right.departure);
      if (order != 0) return order;
      order = left.arrival.compareTo(right.arrival);
      if (order != 0) return order;
      order = left.providerCode.compareTo(right.providerCode);
      if (order != 0) return order;
      return left.tripId.compareTo(right.tripId);
    });
    return List<ScenarioTransitServiceOption>.unmodifiable(
      options.take(query.limit),
    );
  }

  Set<String> _equivalentStopIds(String stopId) {
    final stop = _stops[stopId]!;
    final parentId = stop.parentStationId;
    if (parentId != null && parentId.isNotEmpty) {
      return <String>{stopId, parentId, ...?_stationChildren[parentId]};
    }
    return <String>{stopId, ...?_stationChildren[stopId]};
  }

  ScenarioTransitFeedManifest _manifestForDate(
    ScenarioTransitLocalDate serviceDate,
  ) {
    if (manifest.freshness == ScenarioTransitFreshness.stale) return manifest;
    final start = manifest.feedStartDate;
    final end = manifest.feedEndDate;
    if (start == null || end == null) {
      return manifest.withFreshness(ScenarioTransitFreshness.unknown);
    }
    if (serviceDate.compareTo(start) < 0 || serviceDate.compareTo(end) > 0) {
      return manifest.withFreshness(ScenarioTransitFreshness.stale);
    }
    return manifest;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class GtfsIndexedRoute {
  const GtfsIndexedRoute({
    required this.id,
    required this.mode,
    this.agencyName,
    this.label,
  });

  final String id;
  final ScenarioTransitMode mode;
  final String? agencyName;
  final String? label;
}

class GtfsIndexedTrip {
  const GtfsIndexedTrip({
    required this.id,
    required this.routeId,
    required this.serviceId,
    required this.stopTimes,
    this.headsign,
  });

  final String id;
  final String routeId;
  final String serviceId;
  final List<GtfsIndexedStopTime> stopTimes;
  final String? headsign;
}

class GtfsIndexedStopTime {
  const GtfsIndexedStopTime({
    required this.stopId,
    required this.sequence,
    required this.arrivalSeconds,
    required this.departureSeconds,
  });

  final String stopId;
  final int sequence;
  final int arrivalSeconds;
  final int departureSeconds;
}

class GtfsServiceCalendar {
  GtfsServiceCalendar({
    required this.serviceId,
    required this.weekdays,
    this.startDate,
    this.endDate,
    Map<ScenarioTransitLocalDate, bool> exceptions = const {},
  }) : exceptions = Map<ScenarioTransitLocalDate, bool>.unmodifiable(
         exceptions,
       );

  final String serviceId;
  final Set<int> weekdays;
  final ScenarioTransitLocalDate? startDate;
  final ScenarioTransitLocalDate? endDate;
  final Map<ScenarioTransitLocalDate, bool> exceptions;

  bool runsOn(ScenarioTransitLocalDate date) {
    final exception = exceptions[date];
    if (exception != null) return exception;
    if (startDate == null || endDate == null) return false;
    return date.compareTo(startDate!) >= 0 &&
        date.compareTo(endDate!) <= 0 &&
        weekdays.contains(date.weekday);
  }
}
