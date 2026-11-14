import 'package:flutter/services.dart' show appFlavor;
import 'di/dev_auth_bundle.dart';
import '../core/localization/locale_controller.dart';
import 'di/service_locator.dart';
import '../core/config/cloud_environment.dart';

Future<void> bootstrap() async {
  await setupDependencies(
    devAuth: CloudEnvironment.forFlavor(appFlavor) != null
        ? await createDevAuthBundleFromEnvironment()
        : null,
  );
  // L4: restore the stored UI language before the first frame.
  await sl<LocaleController>().load();
}
