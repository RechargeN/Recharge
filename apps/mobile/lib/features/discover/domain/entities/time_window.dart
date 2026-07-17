import 'geo_point.dart';

enum TimeWindowMode { exact, flexible, anytimeToday }

enum TravelOriginType { currentLocation, manualPin }

enum TransportMode { walking, driving, transit }

class TimeWindow {
  TimeWindow({
    required this.startAtUtc,
    required this.endAtUtc,
    required this.timezoneId,
    required this.mode,
    required this.flexibilityMinutes,
    required this.resolvedAtUtc,
  }) {
    if (!startAtUtc.isBefore(endAtUtc)) {
      throw ArgumentError('startAtUtc must be before endAtUtc');
    }
    if (timezoneId.trim().isEmpty) {
      throw ArgumentError.value(timezoneId, 'timezoneId');
    }
    if (mode == TimeWindowMode.flexible && flexibilityMinutes <= 0) {
      throw ArgumentError.value(flexibilityMinutes, 'flexibilityMinutes');
    }
    if (mode != TimeWindowMode.flexible && flexibilityMinutes != 0) {
      throw ArgumentError.value(flexibilityMinutes, 'flexibilityMinutes');
    }
  }

  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String timezoneId;
  final TimeWindowMode mode;
  final int flexibilityMinutes;
  final DateTime resolvedAtUtc;

  DateTime get effectiveStartAtUtc => mode == TimeWindowMode.flexible
      ? startAtUtc.subtract(Duration(minutes: flexibilityMinutes))
      : startAtUtc;

  DateTime get effectiveEndAtUtc => mode == TimeWindowMode.flexible
      ? endAtUtc.add(Duration(minutes: flexibilityMinutes))
      : endAtUtc;

  Map<String, Object?> toMap() => <String, Object?>{
    'start_at_utc': startAtUtc.toUtc().toIso8601String(),
    'end_at_utc': endAtUtc.toUtc().toIso8601String(),
    'timezone_id': timezoneId,
    'mode': mode.name,
    'flexibility_minutes': flexibilityMinutes,
    'resolved_at_utc': resolvedAtUtc.toUtc().toIso8601String(),
  };

  factory TimeWindow.fromMap(Map<String, Object?> map) => TimeWindow(
    startAtUtc: DateTime.parse(map['start_at_utc']! as String).toUtc(),
    endAtUtc: DateTime.parse(map['end_at_utc']! as String).toUtc(),
    timezoneId: map['timezone_id']! as String,
    mode: TimeWindowMode.values.firstWhere(
      (TimeWindowMode value) => value.name == map['mode'],
      orElse: () => TimeWindowMode.exact,
    ),
    flexibilityMinutes: (map['flexibility_minutes'] as num?)?.toInt() ?? 0,
    resolvedAtUtc: DateTime.parse(map['resolved_at_utc']! as String).toUtc(),
  );
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
