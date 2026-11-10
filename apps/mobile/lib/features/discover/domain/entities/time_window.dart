import 'geo_point.dart';
import 'package:recharge/shared/primitives/time/utc_instant.dart';
import 'package:recharge/shared/primitives/time/iana_time_zone.dart';

enum TimeWindowMode { exact, flexible, anytimeToday }

enum TravelOriginType { currentLocation, manualPin }

enum TransportMode { walking, driving, transit }

class TimeWindow {
  TimeWindow({
    required DateTime startAtUtc,
    required DateTime endAtUtc,
    required String timezoneId,
    required this.mode,
    required this.flexibilityMinutes,
    required DateTime resolvedAtUtc,
  }) : _start = UtcInstant(startAtUtc),
       _end = UtcInstant(endAtUtc),
       _timezone = IanaTimeZone.parse(timezoneId),
       _resolved = UtcInstant(resolvedAtUtc) {
    if (!startAtUtc.isBefore(endAtUtc)) {
      throw ArgumentError('startAtUtc must be before endAtUtc');
    }
    if (mode == TimeWindowMode.flexible && flexibilityMinutes <= 0) {
      throw ArgumentError.value(flexibilityMinutes, 'flexibilityMinutes');
    }
    if (mode != TimeWindowMode.flexible && flexibilityMinutes != 0) {
      throw ArgumentError.value(flexibilityMinutes, 'flexibilityMinutes');
    }
  }

  final UtcInstant _start;
  final UtcInstant _end;
  final IanaTimeZone _timezone;
  final UtcInstant _resolved;
  // Transitional consumer API, retained until the M2-D reference audit.
  DateTime get startAtUtc => _start.value;
  DateTime get endAtUtc => _end.value;
  String get timezoneId => _timezone.value;
  final TimeWindowMode mode;
  final int flexibilityMinutes;
  DateTime get resolvedAtUtc => _resolved.value;

  DateTime get effectiveStartAtUtc => mode == TimeWindowMode.flexible
      ? startAtUtc.subtract(Duration(minutes: flexibilityMinutes))
      : startAtUtc;

  DateTime get effectiveEndAtUtc => mode == TimeWindowMode.flexible
      ? endAtUtc.add(Duration(minutes: flexibilityMinutes))
      : endAtUtc;
}

class TravelContext {
  TravelContext({
    required this.originType,
    required this.origin,
    required this.transportMode,
    required this.includeReturnTrip,
  }) {
    if (!origin.isValid) throw ArgumentError.value(origin, 'origin');
  }

  final TravelOriginType originType;
  final GeoPoint origin;
  final TransportMode transportMode;
  final bool includeReturnTrip;

  Map<String, Object?> toMap() => <String, Object?>{
    'origin_type': originType.name,
    'origin': origin.toMap(),
    'transport_mode': transportMode.name,
    'include_return_trip': includeReturnTrip,
  };

  factory TravelContext.fromMap(Map<String, Object?> map) {
    final Map<String, Object?> originMap =
        (map['origin']! as Map<dynamic, dynamic>).map(
          (dynamic key, dynamic value) =>
              MapEntry<String, Object?>(key as String, value as Object?),
        );
    return TravelContext(
      originType: TravelOriginType.values.firstWhere(
        (TravelOriginType value) => value.name == map['origin_type'],
        orElse: () => TravelOriginType.currentLocation,
      ),
      origin: GeoPoint.fromMap(originMap),
      transportMode: TransportMode.values.firstWhere(
        (TransportMode value) => value.name == map['transport_mode'],
        orElse: () => TransportMode.walking,
      ),
      includeReturnTrip: (map['include_return_trip'] as bool?) ?? true,
    );
  }
}
