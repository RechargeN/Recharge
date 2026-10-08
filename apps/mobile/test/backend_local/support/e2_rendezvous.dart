import 'dart:convert';
import 'dart:io';

/// File barriers shared by the two independent client processes and the gate
/// script of E2b. A point is `<directory>/<who>.<name>.json`, written to a
/// temporary name and renamed, so a reader never sees half a file. Waiting
/// polls the file system until a deadline: there is no fixed delay that stands
/// in for "the other side is probably done".
final class E2Rendezvous {
  E2Rendezvous({required this.directory, required this.role})
    : assert(role == 'A' || role == 'B');

  static const String directoryVariable = 'RECHARGE_E2_RENDEZVOUS';
  static const String roleVariable = 'RECHARGE_E2_ROLE';

  /// Null unless the E2 gate started this process as one of its clients.
  static E2Rendezvous? fromEnvironment() {
    final String? path = Platform.environment[directoryVariable];
    final String? role = Platform.environment[roleVariable];
    if (path == null || path.isEmpty || (role != 'A' && role != 'B')) {
      return null;
    }
    return E2Rendezvous(directory: Directory(path), role: role!);
  }

  final Directory directory;
  final String role;

  String get peer => role == 'A' ? 'B' : 'A';

  File _file(String who, String name) =>
      File('${directory.path}${Platform.pathSeparator}$who.$name.json');

  /// Marks that this client reached [name], with what the others need.
  Future<void> arrive(
    String name, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) async {
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
    final File file = _file(who, name);
    final DateTime deadline = DateTime.now().add(timeout);
    while (!await file.exists()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('rendezvous: $who never reached $name');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return (jsonDecode(await file.readAsString()) as Map)
        .cast<String, Object?>();
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
