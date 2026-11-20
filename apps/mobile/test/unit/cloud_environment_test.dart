import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/cloud_environment.dart';
import 'package:recharge/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';

/// N4a/N4b (2026-11-13): the dev and stage flavors bind to exactly one
/// reviewed project each; production and local flavors bind to none.
void main() {
  test('flavors map to the reviewed projects; others to none', () {
    expect(CloudEnvironment.forFlavor('dev'), CloudEnvironment.dev);
    expect(CloudEnvironment.forFlavor('stage'), CloudEnvironment.staging);
    for (final String? flavor in <String?>[
      null,
      'local',
      'prod',
      'production',
    ]) {
      expect(CloudEnvironment.forFlavor(flavor), isNull, reason: '$flavor');
    }
    expect(CloudEnvironment.values.map((e) => e.projectId), <String>[
      'recharge-dev-n2a01',
      'recharge-staging-y9y2y',
    ]);
  });

  test('dev keeps its N2c names, so a signed-in device stays signed in', () {
    const CloudEnvironment dev = CloudEnvironment.dev;
    expect(dev.storageScope, 'recharge_dev_n2a01');
    expect(dev.firebaseAppName, 'recharge-dev-android');
    expect(
      dev.functionsBase,
      'https://europe-west1-recharge-dev-n2a01.cloudfunctions.net',
    );
    expect(
      BookingIdentityCacheEnvironment.dev.namespace,
      'booking.dev.recharge-dev-n2a01',
    );
    expect(AuthCacheEnvironment.dev.namespace, 'auth.dev.recharge-dev-n2a01');
  });

  test('ids of one project never validate for the other', () {
    const CloudEnvironment staging = CloudEnvironment.staging;
    expect(staging.isAndroidAppId('1:30205452447:android:abc123'), isTrue);
    expect(staging.isAndroidAppId('1:420479958348:android:abc123'), isFalse);
    expect(
      staging.isGoogleServerClientId(
        '30205452447-abc.apps.googleusercontent.com',
      ),
      isTrue,
    );
    expect(
      CloudEnvironment.dev.isGoogleServerClientId(
        '30205452447-abc.apps.googleusercontent.com',
      ),
      isFalse,
    );
    expect(
      BookingIdentityCacheEnvironment.staging.namespace,
      isNot(BookingIdentityCacheEnvironment.dev.namespace),
    );
  });

  test('the identity endpoint accepts dev and staging only', () {
    for (final CloudEnvironment e in CloudEnvironment.values) {
      expect(
        BookingBackendEndpoint.devIdentity(Uri.parse(e.functionsBase)).uri,
        Uri.parse(e.functionsBase),
      );
    }
    expect(
      () => BookingBackendEndpoint.devIdentity(
        Uri.parse('https://europe-west1-recharge-prod.cloudfunctions.net'),
      ),
      throwsArgumentError,
    );
  });
}
