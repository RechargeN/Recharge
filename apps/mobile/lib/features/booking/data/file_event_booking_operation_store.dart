import 'dart:convert';
import 'dart:io';

import '../domain/repositories/event_booking_gateway.dart';

/// File-backed intent journal: one pending operation per occurrence, written
/// atomically so a crash never leaves a half-written intent.
final class FileEventBookingOperationStore
    implements EventBookingOperationStore {
  FileEventBookingOperationStore(this._file);

  final File _file;

  Future<Map<String, Object?>> _all() async {
    if (!await _file.exists()) return <String, Object?>{};
    try {
      return Map<String, Object?>.from(
        jsonDecode(await _file.readAsString()) as Map,
      );
    } on Object {
      // A corrupt journal must not block Booking; the server stays authoritative.
      return <String, Object?>{};
    }
  }

  Future<void> _save(Map<String, Object?> all) async {
    await _file.parent.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(jsonEncode(all), flush: true);
    await temp.rename(_file.path);
  }

  @override
  Future<EventBookingOperation?> read(String occurrenceId) async {
    final raw = (await _all())[occurrenceId];
    if (raw is! Map) return null;
    try {
      return EventBookingOperation.fromJson(Map<String, Object?>.from(raw));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(EventBookingOperation operation) async {
    final all = await _all();
    all[operation.occurrenceId] = operation.toJson();
    await _save(all);
  }

  @override
  Future<void> clear(String occurrenceId) async {
    final all = await _all();
    if (all.remove(occurrenceId) != null) await _save(all);
  }
}
