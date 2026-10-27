import '../core/localization/locale_controller.dart';
import 'di/service_locator.dart';

Future<void> bootstrap() async {
  await setupDependencies();
  // L4: restore the stored UI language before the first frame.
  await sl<LocaleController>().load();
}
