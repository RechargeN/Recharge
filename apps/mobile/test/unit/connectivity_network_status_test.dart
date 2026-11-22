import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/connectivity_network_status.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  tearDown(
    () =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
  );

  void answer(List<String>? transports) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      if (transports == null) throw PlatformException(code: 'unavailable');
      return transports;
    });
  }

  test('only "none" means no network', () async {
    answer(<String>['none']);
    expect(await ConnectivityNetworkStatus().isOnline(), isFalse);
    answer(<String>['wifi']);
    expect(await ConnectivityNetworkStatus().isOnline(), isTrue);
  });

  test('an unreadable status never claims that there is no network', () async {
    answer(null);
    expect(await ConnectivityNetworkStatus().isOnline(), isTrue);
  });
}
