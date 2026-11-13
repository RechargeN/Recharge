import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/dev_auth_bundle.dart';

void main() {
  test(
    'missing exact dev public configuration fails before SDK initialization',
    () async {
      await expectLater(createDevAuthBundleFromEnvironment(), throwsStateError);
    },
  );
}
