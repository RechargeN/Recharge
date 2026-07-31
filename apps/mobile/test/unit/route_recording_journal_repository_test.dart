import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/features/create/data/datasources/route_recording_secure_store.dart';
import 'package:recharge/features/create/data/repositories/route_recording_journal_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/route_recording_data.dart';

void main() {
  late _MemorySecureStore store;
  late RouteRecordingJournalRepositoryImpl repository;

  setUp(() {
    store = _MemorySecureStore();
    repository = RouteRecordingJournalRepositoryImpl(
      store: store,
      chunkSize: 10,
    );
  });

  test(
    'round-trips a chunked journal and deletes every persisted part',
    () async {
      final journal = _journal(revision: 0, sampleCount: 23);

      await repository.save(journal);
      final restored = await repository.loadForDraft(journal.draftId);

      expect(restored, isNotNull);
      expect(restored!.sessionId, journal.sessionId);
      expect(restored.revision, 0);
      expect(restored.sampleCount, 23);
      expect(restored.legs.single.samples.last.elapsedMilliseconds, 22000);
      expect(
        store.values.keys.where((key) => key.contains('.leg.')),
        hasLength(3),
      );

      await repository.delete(
        draftId: journal.draftId,
        sessionId: journal.sessionId,
      );

      expect(await repository.loadForDraft(journal.draftId), isNull);
      expect(store.values, isEmpty);
    },
  );

  test('append rewrites only the final partial chunk', () async {
    await repository.save(_journal(revision: 0, sampleCount: 11));
    final firstChunkKey = store.values.keys.singleWhere(
      (key) => key.endsWith('.leg.leg-1.0'),
    );
    final initialWrites = store.writeCounts[firstChunkKey];

    await repository.save(_journal(revision: 1, sampleCount: 12));

    expect(store.writeCounts[firstChunkKey], initialWrites);
    expect((await repository.loadForDraft('draft-1'))!.sampleCount, 12);
  });

  test('manifest is the commit point after an interrupted append', () async {
    await repository.save(_journal(revision: 0, sampleCount: 11));
    store.failNextManifestWrite = true;

    await expectLater(
      repository.save(_journal(revision: 1, sampleCount: 12)),
      throwsA(isA<StateError>()),
    );

    final restored = await repository.loadForDraft('draft-1');
    expect(restored!.revision, 0);
    expect(restored.sampleCount, 11);
  });

  test('rejects stale revisions and replacement sessions', () async {
    await repository.save(_journal(revision: 0, sampleCount: 2));

    await expectLater(
      repository.save(_journal(revision: 0, sampleCount: 3)),
      throwsA(
        isA<RouteRecordingException>().having(
          (error) => error.code,
          'code',
          'gps_journal_revision_conflict',
        ),
      ),
    );
    await expectLater(
      repository.save(
        _journal(revision: 1, sampleCount: 3, sessionId: 'other-session'),
      ),
      throwsA(
        isA<RouteRecordingException>().having(
          (error) => error.code,
          'code',
          'gps_journal_session_conflict',
        ),
      ),
    );
  });
}

RouteRecordingJournal _journal({
  required int revision,
  required int sampleCount,
  String sessionId = 'session-1',
}) => RouteRecordingJournal(
  revision: revision,
  sessionId: sessionId,
  draftId: 'draft-1',
  startedAtUtc: DateTime.utc(2026, 7, 25, 10),
  updatedAtUtc: DateTime.utc(2026, 7, 25, 10, 30),
  status: RouteRecordingJournalStatus.recording,
  legs: <RouteRecordingLeg>[
    RouteRecordingLeg(
      id: 'leg-1',
      samples: List<RouteRecordingSample>.generate(
        sampleCount,
        (index) => RouteRecordingSample(
          position: GeoPoint(
            latitude: 56.95 + index / 100000,
            longitude: 24.10 + index / 100000,
          ),
          horizontalAccuracyMeters: 4,
          elapsedMilliseconds: index * 1000,
          capturedAtUtc: DateTime.utc(
            2026,
            7,
            25,
            10,
          ).add(Duration(seconds: index)),
          source: RouteRecordingSampleSource.satellite,
        ),
      ),
    ),
  ],
);

class _MemorySecureStore implements RouteRecordingSecureStore {
  final Map<String, String> values = <String, String>{};
  final Map<String, int> writeCounts = <String, int>{};
  bool failNextManifestWrite = false;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failNextManifestWrite && key.endsWith('.manifest')) {
      failNextManifestWrite = false;
      throw StateError('simulated interruption');
    }
    values[key] = value;
    writeCounts[key] = (writeCounts[key] ?? 0) + 1;
  }
}
