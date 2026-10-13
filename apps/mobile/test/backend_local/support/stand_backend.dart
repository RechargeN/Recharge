import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';

/// Connection to the real local demo-recharge Emulator stand (A1/A2).
///
/// The suite runs on the PC host: the Dart VM reaches the loopback Emulators
/// directly, so no port forwarding, LAN address or cloud credential is used.
/// Nothing here carries authority: Sessions and Bookings come from the real
/// backend, and Auth tokens come from the real Auth Emulator.
final class StandBackend {
  StandBackend._({required this.repoRoot, required this.node});

  static const String enableVariable = 'RECHARGE_B1_STAND';
  static const String skipReason =
      'B1-local stand not running; run apps/backend/scripts/stand-mobile-gate.mjs '
      '(it sets RECHARGE_B1_STAND=1)';

  static final Uri functionsBase = Uri.parse(
    'http://127.0.0.1:5001/demo-recharge/europe-west1',
  );
  static const String authHost = '127.0.0.1:9099';
  // Emulator-only credential of the synthetic seed users (stand_plan.ts).
  static const String emulatorPassword = 'emulator-only-password-123';

  final String repoRoot;
  final String node;

  /// Null unless the gate script enabled the suite.
  static StandBackend? fromEnvironment() {
    final env = Platform.environment;
    if (env[enableVariable] != '1') return null;
    final root = env['RECHARGE_REPO_ROOT'];
    if (root == null || root.isEmpty) {
      throw StateError('RECHARGE_REPO_ROOT is required with $enableVariable');
    }
    return StandBackend._(repoRoot: root, node: env['RECHARGE_NODE'] ?? 'node');
  }

  BookingBackendEndpoint get endpoint =>
      BookingBackendEndpoint.devEmulator(functionsBase);

  /// Read-only Booking counts of a stand user, taken from the backend itself.
  Future<({int total, int active})> bookingCounts(String label) async {
    final json = await _stand(<String>['bookings', label]);
    return (total: json['total']! as int, active: json['active']! as int);
  }

  /// Creates an Event Content draft through the Content owner service.
  Future<Map<String, Object?>> contentDraft(String user, String page) =>
      _stand(<String>['content-draft', user, page]);

  /// Asks Content, on the backend, whether this exact Media asset is ready.
  Future<Map<String, Object?>> mediaReadiness(
    String user,
    String draftId,
    String assetId,
  ) => _stand(<String>['media-readiness', user, draftId, assetId]);

  /// Runs an owner-service Session fixture on the verified running stand.
  Future<Map<String, Object?>> sessionFixture(List<String> args) =>
      _stand(<String>['session-fixture', ...args]);

  /// M1 stage 2: reversible Page access through the Identity owner services
  /// (`withdraw-publish`, `restore-publish`, `suspend`, `reverify`, `status`).
  Future<Map<String, Object?>> pageAccess(List<String> args) =>
      _stand(<String>['page-access', ...args]);

  /// F1 operator steps (flags, reconcile, receipts, stored-data faults) run on
  /// the stand in its trusted backend context, never by the client.
  Future<Map<String, Object?>> notifications(List<String> args) =>
      _stand(<String>['notifications', ...args]);

  /// The stand manifest: ids the owner services returned for seeded objects.
  Future<Map<String, Object?>> manifest() => _stand(<String>['manifest']);

  /// D3.1: seeds (or reuses) the stand Place and enables Place authoring on
  /// the stand only; prints no JSON, so only its exit code is checked.
  Future<void> placeSeed() async {
    final result = await Process.run(node, <String>[
      _script('stand-seed.mjs'),
      'place',
      'seed',
    ]);
    if (result.exitCode != 0) {
      throw StateError('place seed failed: ${result.stderr}${result.stdout}');
    }
  }

  /// D3.1: the ids the owner services returned for the stand Place.
  Future<Map<String, Object?>> placeManifest() =>
      _stand(<String>['place', 'manifest']);

  /// D3.3: seeds (or reuses) the stand Rental and enables Rental authoring on
  /// the stand only; prints no JSON, so only its exit code is checked.
  Future<void> rentalSeed() async {
    final result = await Process.run(node, <String>[
      _script('stand-seed.mjs'),
      'rental',
      'seed',
    ]);
    if (result.exitCode != 0) {
      throw StateError('rental seed failed: ${result.stderr}${result.stdout}');
    }
  }

  /// D3.3: the ids the owner services returned for the stand Rental.
  Future<Map<String, Object?>> rentalManifest() =>
      _stand(<String>['rental', 'manifest']);

  /// D3.2: seeds (or reuses) the stand Activity and enables Activity authoring
  /// on the stand only; prints no JSON, so only its exit code is checked.
  Future<void> activitySeed() async {
    final result = await Process.run(node, <String>[
      _script('stand-seed.mjs'),
      'activity',
      'seed',
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'activity seed failed: ${result.stderr}${result.stdout}',
      );
    }
  }

  /// D3.2: the ids the owner services returned for the stand Activity.
  Future<Map<String, Object?>> activityManifest() =>
      _stand(<String>['activity', 'manifest']);

  /// D3.4: seeds (or reuses) the stand Collection and its member Places and
  /// enables Place and Collection authoring on the stand only; prints no JSON,
  /// so only its exit code is checked. Membership needs the stand started with
  /// `RECHARGE_TEST_COLLECTION_MEMBERSHIP=true` (the D3.4 gate does).
  Future<void> collectionSeed() async {
    final result = await Process.run(node, <String>[
      _script('stand-seed.mjs'),
      'collection',
      'seed',
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'collection seed failed: ${result.stderr}${result.stdout}',
      );
    }
  }

  /// D3.4: the ids the owner services returned for the stand Collection.
  Future<Map<String, Object?>> collectionManifest() =>
      _stand(<String>['collection', 'manifest']);

  /// The C2 staff script. It holds no authority: the backend checks the staff
  /// Session and registry. A refusal (non-zero exit) still returns its JSON.
  Future<({int exitCode, Map<String, Object?> json})> moderate(
    List<String> args,
  ) async {
    final result = await Process.run(node, <String>[
      _script('stand-moderate.mjs'),
      ...args,
    ]);
    return (exitCode: result.exitCode, json: _lastJson(result, args));
  }

  Future<Map<String, Object?>> catalog(List<String> args) =>
      _stand(<String>['catalog', ...args]);

  String _script(String name) {
    final separator = Platform.pathSeparator;
    return '$repoRoot${separator}apps${separator}backend${separator}scripts'
        '$separator$name';
  }

  Future<Map<String, Object?>> _stand(List<String> args) async {
    final result = await Process.run(node, <String>[
      _script('stand-seed.mjs'),
      ...args,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        '${args.first} failed: ${result.stderr}${result.stdout}',
      );
    }
    return _lastJson(result, args);
  }

  static Map<String, Object?> _lastJson(
    ProcessResult result,
    List<String> args,
  ) {
    final lines = (result.stdout as String)
        .trim()
        .split('\n')
        .where((value) => value.trim().startsWith('{'));
    if (lines.isEmpty) {
      throw StateError(
        '${args.first}: no JSON in ${result.stderr}${result.stdout}',
      );
    }
    return Map<String, Object?>.from(jsonDecode(lines.last) as Map);
  }
}

/// Signs a seed user in through the real Auth Emulator REST endpoint. The
/// firebase_auth plugin cannot run in a host test; it is exercised on Android.
final class AuthEmulatorTokenProvider
    implements BookingFirebaseIdTokenProvider {
  AuthEmulatorTokenProvider(this.uid, {http.Client? client})
    : _client = client ?? http.Client();

  final String uid;
  final http.Client _client;
  String? _token;
  int signIns = 0;

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async {
    if (_token != null && !forceRefresh) return _token;
    final response = await _client.post(
      Uri.parse(
        'http://${StandBackend.authHost}/identitytoolkit.googleapis.com/v1/'
        'accounts:signInWithPassword?key=demo-recharge',
      ),
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, Object?>{
        'email': '$uid@example.invalid',
        'password': StandBackend.emulatorPassword,
        'returnSecureToken': true,
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Auth Emulator sign-in failed (${response.statusCode})');
    }
    signIns += 1;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _token = body['idToken'] as String;
  }
}

/// File-backed Session store, so a "restart" is a new object reading the file.
final class FileSessionStore implements BookingIdentitySessionStore {
  FileSessionStore(this._file);

  final File _file;

  @override
  Future<BookingIdentitySessionContext?> read() async {
    if (!await _file.exists()) return null;
    return BookingIdentitySessionContext.fromJson(
      Map<String, Object?>.from(jsonDecode(await _file.readAsString()) as Map),
    );
  }

  @override
  Future<void> saveServerIssued(BookingIdentitySessionContext session) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
  }
}

final class FixedInstallationId implements BookingInstallationIdProvider {
  const FixedInstallationId(this.value);

  final String value;

  @override
  Future<String> current() async => value;
}

/// Counts requests, so a test can prove no network call happened.
final class CountingClient extends http.BaseClient {
  CountingClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests += 1;
    return _inner.send(request);
  }
}
