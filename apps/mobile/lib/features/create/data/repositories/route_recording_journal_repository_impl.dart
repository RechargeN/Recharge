import 'dart:async';
import 'dart:convert';

import '../../domain/entities/route_recording_data.dart';
import '../../domain/repositories/route_recording_journal_repository.dart';
import '../datasources/route_recording_secure_store.dart';
import '../models/route_recording_journal_mapper.dart';

class RouteRecordingJournalRepositoryImpl
    implements RouteRecordingJournalRepository {
  RouteRecordingJournalRepositoryImpl({
    required RouteRecordingSecureStore store,
    RouteRecordingJournalMapper mapper = const RouteRecordingJournalMapper(),
    this.chunkSize = 200,
  }) : _store = store,
       _mapper = mapper {
    if (chunkSize < 10 || chunkSize > 1000) {
      throw ArgumentError.value(chunkSize, 'chunkSize');
    }
  }

  final RouteRecordingSecureStore _store;
  final RouteRecordingJournalMapper _mapper;
  final int chunkSize;
  final Map<String, Future<void>> _queues = <String, Future<void>>{};

  static const String _prefix = 'route_gps_journal_v1';

  String _draftKey(String draftId) => '$_prefix.draft.$draftId';
  String _manifestKey(String sessionId) =>
      '$_prefix.session.$sessionId.manifest';
  String _chunkKey(String sessionId, String legId, int index) =>
      '$_prefix.session.$sessionId.leg.$legId.$index';

  @override
  Future<RouteRecordingJournal?> loadForDraft(String draftId) async {
    if (draftId.trim().isEmpty) return null;
    try {
      final sessionId = await _store.read(_draftKey(draftId));
      if (sessionId == null || sessionId.isEmpty) return null;
      final manifest = await _readMap(_manifestKey(sessionId));
      if (manifest == null ||
          manifest['draftId'] != draftId ||
          manifest['sessionId'] != sessionId) {
        throw const RouteRecordingException('gps_journal_invalid');
      }
      final samplesByLeg = <String, List<RouteRecordingSample>>{};
      for (final leg in _manifestLegs(manifest)) {
        final legId = _mapper.legId(leg);
        final sampleCount = _mapper.legSampleCount(leg);
        final chunkCount = _mapper.legChunkCount(leg);
        final samples = <RouteRecordingSample>[];
        for (var index = 0; index < chunkCount; index++) {
          final raw = await _store.read(_chunkKey(sessionId, legId, index));
          if (raw == null) {
            throw const RouteRecordingException('gps_journal_incomplete');
          }
          final decoded = jsonDecode(raw);
          if (decoded is! List<Object?>) {
            throw const RouteRecordingException('gps_journal_invalid');
          }
          samples.addAll(
            decoded.map((item) {
              if (item is! Map<Object?, Object?>) {
                throw const RouteRecordingException('gps_journal_invalid');
              }
              return _mapper.sampleFromJson(item.cast<String, Object?>());
            }),
          );
        }
        if (samples.length < sampleCount) {
          throw const RouteRecordingException('gps_journal_incomplete');
        }
        samplesByLeg[legId] = samples.take(sampleCount).toList(growable: false);
      }
      return _mapper.journalFromParts(
        manifest: manifest,
        samplesByLegId: samplesByLeg,
        expectedChunkSize: chunkSize,
      );
    } on RouteRecordingException {
      rethrow;
    } catch (_) {
      throw const RouteRecordingException('gps_journal_invalid');
    }
  }

  @override
  Future<void> save(RouteRecordingJournal journal) {
    if (!journal.isValid) {
      throw const RouteRecordingException('gps_journal_invalid');
    }
    return _serial(journal.draftId, () => _saveLocked(journal));
  }

  Future<void> _saveLocked(RouteRecordingJournal journal) async {
    final draftKey = _draftKey(journal.draftId);
    final indexedSession = await _store.read(draftKey);
    if (indexedSession != null && indexedSession != journal.sessionId) {
      throw const RouteRecordingException('gps_journal_session_conflict');
    }
    final manifestKey = _manifestKey(journal.sessionId);
    final previous = await _readMap(manifestKey);
    if (previous != null) {
      final previousRevision = (previous['revision'] as num?)?.toInt();
      if (previousRevision == null || journal.revision <= previousRevision) {
        throw const RouteRecordingException('gps_journal_revision_conflict');
      }
      _validateAppendOnly(previous, journal);
    }

    final previousLegs = previous == null
        ? const <Map<String, Object?>>[]
        : _manifestLegs(previous);
    for (var legIndex = 0; legIndex < journal.legs.length; legIndex++) {
      final leg = journal.legs[legIndex];
      final previousCount = legIndex < previousLegs.length
          ? _mapper.legSampleCount(previousLegs[legIndex])
          : 0;
      if (leg.samples.isEmpty) continue;
      final firstChunk = previousCount == 0
          ? 0
          : (previousCount - 1) ~/ chunkSize;
      final chunkCount = (leg.samples.length + chunkSize - 1) ~/ chunkSize;
      for (var chunkIndex = firstChunk; chunkIndex < chunkCount; chunkIndex++) {
        final start = chunkIndex * chunkSize;
        final end = (start + chunkSize).clamp(0, leg.samples.length);
        final payload = leg.samples
            .sublist(start, end)
            .map(_mapper.sampleToJson)
            .toList(growable: false);
        await _store.write(
          _chunkKey(journal.sessionId, leg.id, chunkIndex),
          jsonEncode(payload),
        );
      }
    }

    // Commit point: readers only observe chunks referenced by this manifest.
    await _store.write(
      manifestKey,
      jsonEncode(_mapper.manifestToJson(journal, chunkSize: chunkSize)),
    );
    await _store.write(draftKey, journal.sessionId);
  }

  void _validateAppendOnly(
    Map<String, Object?> previous,
    RouteRecordingJournal journal,
  ) {
    if (previous['sessionId'] != journal.sessionId ||
        previous['draftId'] != journal.draftId) {
      throw const RouteRecordingException('gps_journal_session_conflict');
    }
    final previousLegs = _manifestLegs(previous);
    if (journal.legs.length < previousLegs.length) {
      throw const RouteRecordingException('gps_journal_rewrite_rejected');
    }
    for (var index = 0; index < previousLegs.length; index++) {
      final previousLeg = previousLegs[index];
      final currentLeg = journal.legs[index];
      if (_mapper.legId(previousLeg) != currentLeg.id ||
          currentLeg.samples.length < _mapper.legSampleCount(previousLeg)) {
        throw const RouteRecordingException('gps_journal_rewrite_rejected');
      }
    }
  }

  @override
  Future<void> delete({required String draftId, required String sessionId}) =>
      _serial(draftId, () async {
        final indexedSession = await _store.read(_draftKey(draftId));
        if (indexedSession != null && indexedSession != sessionId) {
          throw const RouteRecordingException('gps_journal_session_conflict');
        }
        final manifest = await _readMap(_manifestKey(sessionId));
        if (manifest != null) {
          for (final leg in _manifestLegs(manifest)) {
            final legId = _mapper.legId(leg);
            final count = _mapper.legChunkCount(leg);
            for (var index = 0; index < count; index++) {
              await _store.delete(_chunkKey(sessionId, legId, index));
            }
          }
        }
        await _store.delete(_manifestKey(sessionId));
        await _store.delete(_draftKey(draftId));
      });

  Future<void> _serial(String draftId, Future<void> Function() operation) {
    final previous = _queues[draftId] ?? Future<void>.value();
    final completer = Completer<void>();
    late final Future<void> current;
    current = previous
        .catchError((Object _) {})
        .then((_) async {
          try {
            await operation();
            completer.complete();
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_queues[draftId], current)) _queues.remove(draftId);
        });
    _queues[draftId] = current;
    return completer.future;
  }

  Future<Map<String, Object?>?> _readMap(String key) async {
    final raw = await _store.read(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<Object?, Object?>) {
      throw const RouteRecordingException('gps_journal_invalid');
    }
    return decoded.cast<String, Object?>();
  }

  List<Map<String, Object?>> _manifestLegs(Map<String, Object?> manifest) {
    final rawLegs = manifest['legs'];
    if (rawLegs is! List<Object?> || rawLegs.isEmpty) {
      throw const RouteRecordingException('gps_journal_invalid');
    }
    return rawLegs
        .map((raw) {
          if (raw is! Map<Object?, Object?>) {
            throw const RouteRecordingException('gps_journal_invalid');
          }
          return raw.cast<String, Object?>();
        })
        .toList(growable: false);
  }
}
