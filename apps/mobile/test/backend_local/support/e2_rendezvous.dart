import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'stand_environment.dart';

/// File barriers shared by the two independent client processes and the gate
/// script of E2b. A point is `<directory>/<who>.<name>.json`, written to a
/// temporary name and renamed, so a reader never sees half a file. Waiting
/// polls the file system until a deadline: there is no fixed delay that stands
/// in for "the other side is probably done".
///
/// B1-device: a client on the phone cannot see the PC directory, so it writes
/// and reads the same points through the gate's loopback bridge, which keeps
/// the files in that directory (the gate and the PC client read them as ever).
final class E2Rendezvous {
  E2Rendezvous({required this.directory, required this.role})
    : overBridge = false,
      assert(role == 'A' || role == 'B');

  E2Rendezvous._bridge({required this.role})
    : directory = Directory(''),
      overBridge = true,
      assert(role == 'A' || role == 'B');

  static const String directoryVariable = 'RECHARGE_E2_RENDEZVOUS';
  static const String roleVariable = 'RECHARGE_E2_ROLE';

  /// Null unless the E2 gate started this process as one of its clients.
  static E2Rendezvous? fromEnvironment() {
    final String? path = standEnvironment[directoryVariable];
    final String? role = standEnvironment[roleVariable];
    if (path == null || path.isEmpty || (role != 'A' && role != 'B')) {
      return null;
    }
    if (standOverBridge) return E2Rendezvous._bridge(role: role!);
    return E2Rendezvous(directory: Directory(path), role: role!);
  }

  final Directory directory;
  final String role;
  final bool overBridge;

  String get peer => role == 'A' ? 'B' : 'A';

  File _file(String who, String name) =>
      File('${directory.path}${Platform.pathSeparator}$who.$name.json');

  Uri _point(String who, String name) => standBridgeBase.replace(
    path: '/rendezvous',
    queryParameters: <String, String>{'who': who, 'name': name},
  );

  /// Marks that this client reached [name], with what the others need.
  Future<void> arrive(
    String name, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) async {
    if (overBridge) {
      final http.Response response = await http.put(
        _point(role, name),
        headers: const <String, String>{'content-type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 204) {
        throw StateError('rendezvous: bridge refused $role.$name');
      }
      return;
    }
    final File target = _file(role, name);
    final File temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(payload), flush: true);
    await temporary.rename(target.path);
  }

  /// The payload [who] left at [name]; fails after [timeout].
  Future<Map<String, Object?>> waitFor(
    String who,
    String name, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (true) {
      final String? body = await _read(who, name);
      if (body != null) {
        return (jsonDecode(body) as Map).cast<String, Object?>();
      }
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('rendezvous: $who never reached $name');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<String?> _read(String who, String name) async {
    if (!overBridge) {
      final File file = _file(who, name);
      return await file.exists() ? file.readAsString() : null;
    }
    final http.Response response = await http.get(_point(who, name));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError('rendezvous: bridge refused $who.$name');
    }
    return response.body;
  }

  /// Both clients reached [name]; neither starts the next step alone.
  Future<Map<String, Object?>> barrier(
    String name, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) async {
    await arrive(name, payload);
    return waitFor(peer, name);
  }
}
