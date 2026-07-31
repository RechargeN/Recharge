import '../entities/route_recording_data.dart';

enum RouteLocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always,
  unavailable,
}

class RouteLocationRecordingSettings {
  const RouteLocationRecordingSettings({
    required this.backgroundEnabled,
    required this.distanceFilterMeters,
    required this.minimumInterval,
  });

  final bool backgroundEnabled;
  final int distanceFilterMeters;
  final Duration minimumInterval;

  bool get isValid =>
      distanceFilterMeters >= 0 && minimumInterval >= Duration.zero;
}

class RouteLocationException implements Exception {
  const RouteLocationException(this.code);

  final String code;

  @override
  String toString() => 'RouteLocationException($code)';
}

abstract interface class RouteLocationRecordingPort {
  Future<bool> isServiceEnabled();

  Stream<bool> serviceEnabledChanges();

  Future<RouteLocationPermission> checkPermission();

  Future<RouteLocationPermission> requestForegroundPermission();

  Future<RouteLocationPermission> requestBackgroundPermission();

  Stream<RouteRecordingSample> samples(RouteLocationRecordingSettings settings);

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}
