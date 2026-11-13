import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/application/location_search_config.dart';

/// The real app resolves `createControllerProvider` from the app DI (Profile
/// and Create watch it). Widget tests override the provider, so only this
/// test proves every dependency it reads from `sl` is registered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  tearDown(() async => sl.reset());

  test('app DI builds the Create controller', () async {
    await setupDependencies();

    expect(sl.isRegistered<LocationSearchRuntimeConfig>(), isTrue);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(createControllerProvider), returnsNormally);
  });
}
