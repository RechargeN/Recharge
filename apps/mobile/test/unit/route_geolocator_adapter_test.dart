import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:recharge/app/adapters/route_geolocator_adapter.dart';
import 'package:recharge/features/create/domain/repositories/route_location_recording_port.dart';

/// B1D-ROUTE-BG-01: on the A34 a request with "Allow all the time" already
/// granted answered `whileInUse` (geolocator asks for the background
/// permission only from `whileInUse`), so background recording never began.
void main() {
  late LocationPermission status;
  late LocationPermission answer;
  late int requests;
  late RouteGeolocatorAdapter adapter;

  setUp(() {
    requests = 0;
    adapter = RouteGeolocatorAdapter(
      check: () async => status,
      request: () async {
        requests += 1;
        return answer;
      },
    );
  });

  test('an already granted "always" is kept without a new request', () async {
    status = LocationPermission.always;
    // What geolocator answers in this state on Android 10+.
    answer = LocationPermission.whileInUse;
    expect(
      await adapter.requestBackgroundPermission(),
      RouteLocationPermission.always,
    );
    expect(requests, 0);
  });

  test('from "while in use" the plugin is asked and its answer kept', () async {
    status = LocationPermission.whileInUse;
    answer = LocationPermission.always;
    expect(
      await adapter.requestBackgroundPermission(),
      RouteLocationPermission.always,
    );
    answer = LocationPermission.whileInUse;
    expect(
      await adapter.requestBackgroundPermission(),
      RouteLocationPermission.whileInUse,
      reason: 'Android 11+ grants background only in Settings',
    );
    expect(requests, 2);
  });

  test('denied stays denied; the foreground request is unchanged', () async {
    status = LocationPermission.denied;
    answer = LocationPermission.deniedForever;
    expect(
      await adapter.requestBackgroundPermission(),
      RouteLocationPermission.deniedForever,
    );
    status = LocationPermission.always;
    answer = LocationPermission.whileInUse;
    expect(
      await adapter.requestForegroundPermission(),
      RouteLocationPermission.whileInUse,
      reason: 'foreground requests always go to the plugin',
    );
    expect(requests, 2);
  });

  test('plugin failures keep their codes', () async {
    final failing = RouteGeolocatorAdapter(
      check: () async => throw StateError('channel'),
      request: () async => throw StateError('channel'),
    );
    await expectLater(
      failing.requestBackgroundPermission(),
      throwsA(
        isA<RouteLocationException>().having(
          (e) => e.code,
          'code',
          'gps_permission_check_failed',
        ),
      ),
    );
    await expectLater(
      failing.requestForegroundPermission(),
      throwsA(
        isA<RouteLocationException>().having(
          (e) => e.code,
          'code',
          'gps_permission_request_failed',
        ),
      ),
    );
  });
}
