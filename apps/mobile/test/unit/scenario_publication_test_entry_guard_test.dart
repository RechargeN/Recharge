import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/scenario_publication_composition.dart';

/// I3: the Scenario test entry is its own default-off switch with the same four
/// conditions as the other publication entries; it closes the route and every
/// Planning, Content and Media command.
void main() {
  final Uri base = Uri.parse(
    'http://127.0.0.1:5001/demo-recharge/europe-west1',
  );

  ScenarioPublicationTestEntryGuard guard({
    bool flag = true,
    bool release = false,
    BackendBindingMode mode = BackendBindingMode.testBackend,
    Uri? emulatorBase,
  }) => ScenarioPublicationTestEntryGuard(
    flag: flag,
    releaseMode: release,
    binding: BookingBackendBindingController(
      emulatorBase: emulatorBase ?? base,
      releaseMode: release,
      initial: mode,
    ),
  );

  test('the define is off by default in this build', () {
    expect(scenarioPublicationTestEntryDefined, isFalse);
  });

  test('all four conditions are required at once', () {
    expect(guard().allowed, isTrue);
    expect(guard(flag: false).allowed, isFalse);
    expect(guard(release: true).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.localOnly).allowed, isFalse);
    expect(
      guard(emulatorBase: Uri.parse('https://example.org/x')).allowed,
      isFalse,
    );
  });

  test('a closed entry refuses every command and redirects the route', () {
    expect(() => guard(flag: false).assertAllowed(), throwsStateError);
    expect(
      scenarioPublicationTestEntryRedirect(guard(flag: false), fallback: '/x'),
      '/x',
    );
    expect(scenarioPublicationTestEntryRedirect(null, fallback: '/x'), '/x');
    expect(
      scenarioPublicationTestEntryRedirect(guard(), fallback: '/x'),
      isNull,
    );
  });
}
