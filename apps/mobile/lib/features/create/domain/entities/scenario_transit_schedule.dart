enum ScenarioTransitMode { bus, train, tram, trolleybus, other }

enum ScenarioTransitFreshness { current, stale, unknown, unavailable }

class ScenarioTransitLocalDate implements Comparable<ScenarioTransitLocalDate> {
  const ScenarioTransitLocalDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  String get compact =>
      '${year.toString().padLeft(4, '0')}'
      '${month.toString().padLeft(2, '0')}'
      '${day.toString().padLeft(2, '0')}';

  String get iso8601 =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  bool get isValid {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    final value = DateTime.utc(year, month, day);
    return value.year == year && value.month == month && value.day == day;
  }

  int get weekday => DateTime.utc(year, month, day).weekday;

  @override
  int compareTo(ScenarioTransitLocalDate other) =>
      compact.compareTo(other.compact);

  @override
  bool operator ==(Object other) =>
      other is ScenarioTransitLocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

class ScenarioTransitTime implements Comparable<ScenarioTransitTime> {
  const ScenarioTransitTime(this.secondsFromServiceDay);

  final int secondsFromServiceDay;

  int get dayOffset => secondsFromServiceDay ~/ Duration.secondsPerDay;

  String get hhmm {
    final hours = secondsFromServiceDay ~/ Duration.secondsPerHour;
    final minutes =
        (secondsFromServiceDay % Duration.secondsPerHour) ~/
        Duration.secondsPerMinute;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(ScenarioTransitTime other) =>
      secondsFromServiceDay.compareTo(other.secondsFromServiceDay);
}

class ScenarioTransitFeedManifest {
  const ScenarioTransitFeedManifest({
    required this.providerCode,
    required this.providerDisplayName,
    required this.licenseName,
    required this.sourceUrl,
    required this.retrievedAtUtc,
    required this.sha256,
    required this.freshness,
    this.feedPublisherName,
    this.feedVersion,
    this.feedStartDate,
    this.feedEndDate,
  });

  final String providerCode;
  final String providerDisplayName;
  final String licenseName;
  final String sourceUrl;
  final DateTime retrievedAtUtc;
  final String sha256;
  final ScenarioTransitFreshness freshness;
  final String? feedPublisherName;
  final String? feedVersion;
  final ScenarioTransitLocalDate? feedStartDate;
  final ScenarioTransitLocalDate? feedEndDate;

  ScenarioTransitFeedManifest withFreshness(ScenarioTransitFreshness value) =>
      ScenarioTransitFeedManifest(
        providerCode: providerCode,
        providerDisplayName: providerDisplayName,
        licenseName: licenseName,
        sourceUrl: sourceUrl,
        retrievedAtUtc: retrievedAtUtc,
        sha256: sha256,
        freshness: value,
        feedPublisherName: feedPublisherName,
        feedVersion: feedVersion,
        feedStartDate: feedStartDate,
        feedEndDate: feedEndDate,
      );
}

class ScenarioTransitStop {
  const ScenarioTransitStop({
    required this.providerCode,
    required this.id,
    required this.name,
    this.parentStationId,
    this.latitude,
    this.longitude,
  });

  final String providerCode;
  final String id;
  final String name;
  final String? parentStationId;
  final double? latitude;
  final double? longitude;
}

class ScenarioTransitServiceOption {
  const ScenarioTransitServiceOption({
    required this.providerCode,
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    required this.mode,
    required this.origin,
    required this.destination,
    required this.departure,
    required this.arrival,
    required this.manifest,
    this.agencyName,
    this.routeLabel,
    this.headsign,
  });

  final String providerCode;
  final String tripId;
  final String routeId;
  final String serviceId;
  final ScenarioTransitMode mode;
  final ScenarioTransitStop origin;
  final ScenarioTransitStop destination;
  final ScenarioTransitTime departure;
  final ScenarioTransitTime arrival;
  final ScenarioTransitFeedManifest manifest;
  final String? agencyName;
  final String? routeLabel;
  final String? headsign;

  int get durationMinutes =>
      (arrival.secondsFromServiceDay - departure.secondsFromServiceDay) ~/ 60;
}

class ScenarioTransitSearchQuery {
  const ScenarioTransitSearchQuery({
    required this.originStopId,
    required this.destinationStopId,
    required this.serviceDate,
    this.departAfter = const ScenarioTransitTime(0),
    this.providerCodes = const <String>{},
    this.allowedModes = const <ScenarioTransitMode>{},
    this.limit = 20,
  });

  final String originStopId;
  final String destinationStopId;
  final ScenarioTransitLocalDate serviceDate;
  final ScenarioTransitTime departAfter;
  final Set<String> providerCodes;
  final Set<ScenarioTransitMode> allowedModes;
  final int limit;
}

class ScenarioTransitSearchResult {
  const ScenarioTransitSearchResult({
    required this.options,
    required this.loadedProviders,
    required this.unavailableProviders,
  });

  final List<ScenarioTransitServiceOption> options;
  final Set<String> loadedProviders;
  final Set<String> unavailableProviders;
}
