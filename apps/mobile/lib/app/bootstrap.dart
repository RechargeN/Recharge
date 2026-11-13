import 'package:flutter/services.dart' show appFlavor;
import 'di/dev_auth_bundle.dart';
import '../core/localization/locale_controller.dart';
import 'di/service_locator.dart';

Future<void> bootstrap() async {
  await setupDependencies(
    devAuth: appFlavor == 'dev'
        ? await createDevAuthBundleFromEnvironment()
        : null,
  );
  // L4: restore the stored UI language before the first frame.
  await sl<LocaleController>().load();
}
