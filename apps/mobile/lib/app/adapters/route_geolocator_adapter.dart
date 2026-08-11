import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../../core/geo/geo_point.dart';
import '../../features/create/domain/entities/route_recording_data.dart';
import '../../features/create/domain/repositories/route_location_recording_port.dart';

class RouteGeolocatorAdapter implements RouteLocationRecordingPort {
  const RouteGeolocatorAdapter();

  @override
  Future<RouteLocationPermission> checkPermission() async {
    try {
      return _permission(await Geolocator.checkPermission());
    } catch (_) {
      throw const RouteLocationException('gps_permission_check_failed');
    }
  }

  @override
  Future<bool> isServiceEnabled() async {
    try {
      return Geolocator.isLocationServiceEnabled();
    } catch (_) {
      throw const RouteLocationException('gps_location_unavailable');
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<RouteLocationPermission> requestBackgroundPermission() =>
      _requestPermission();

  @override
  Future<RouteLocationPermission> requestForegroundPermission() =>
      _requestPermission();

  Future<RouteLocationPermission> _requestPermission() async {
    try {
      return _permission(await Geolocator.requestPermission());
    } catch (_) {
      throw const RouteLocationException('gps_permission_request_failed');
    }
  }

  @override
  Stream<bool> serviceEnabledChanges() => Geolocator.getServiceStatusStream()
      .map((status) => status == ServiceStatus.enabled)
      .handleError((Object error) {
        throw const RouteLocationException('gps_service_watch_failed');
      });

  @override
  Stream<RouteRecordingSample> samples(
    RouteLocationRecordingSettings settings,
  ) {
    if (!settings.isValid) {
      return Stream<RouteRecordingSample>.error(
        const RouteLocationException('gps_settings_invalid'),
      );
    }
    final stopwatch = Stopwatch()..start();
    return Geolocator.getPositionStream(
          locationSettings: _platformSettings(settings),
        )
        .map(
          (position) => RouteRecordingSample(
            position: GeoPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              elevationMeters: position.altitude.isFinite
                  ? position.altitude
                  : null,
            ),
            horizontalAccuracyMeters: position.accuracy,
            elapsedMilliseconds: stopwatch.elapsedMilliseconds,
            capturedAtUtc: position.timestamp.toUtc(),
            source: RouteRecordingSampleSource.fused,
            isMocked: position.isMocked,
          ),
        )
        .handleError((Object error) {
          if (error is LocationServiceDisabledException) {
            throw const RouteLocationException('gps_location_service_disabled');
          }
          if (error is PermissionDeniedException) {
            throw const RouteLocationException('gps_permission_revoked');
          }
          throw const RouteLocationException('gps_location_stream_failed');
        });
  }

  LocationSettings _platformSettings(RouteLocationRecordingSettings settings) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: settings.distanceFilterMeters,
        intervalDuration: settings.minimumInterval,
        foregroundNotificationConfig: settings.backgroundEnabled
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Route recording is active',
                notificationText:
                    'Recharge is saving your route while the app is in the background.',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: settings.distanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: settings.backgroundEnabled,
        allowBackgroundLocationUpdates: settings.backgroundEnabled,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: settings.distanceFilterMeters,
    );
  }

  RouteLocationPermission _permission(
    LocationPermission permission,
  ) => switch (permission) {
    LocationPermission.denied => RouteLocationPermission.denied,
    LocationPermission.deniedForever => RouteLocationPermission.deniedForever,
    LocationPermission.whileInUse => RouteLocationPermission.whileInUse,
    LocationPermission.always => RouteLocationPermission.always,
    LocationPermission.unableToDetermine => RouteLocationPermission.unavailable,
  };
}
