import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/controllers/route_recording_controller.dart';
import 'package:recharge/features/create/application/state/route_recording_state.dart';
import 'package:recharge/features/create/domain/entities/route_recording_data.dart';
import 'package:recharge/features/create/domain/repositories/route_location_recording_port.dart';
import 'package:recharge/features/create/domain/repositories/route_recording_journal_repository.dart';

void main() {
  late _FakeLocationPort location;
  late _MemoryJournalRepository repository;
  late RouteRecordingController controller;

  setUp(() {
    location = _FakeLocationPort();
    repository = _MemoryJournalRepository();
    controller = RouteRecordingController(
      idGenerator: _SequenceIdGenerator(),
      location: location,
      journalRepository: repository,
      clock: () => DateTime.utc(2026, 7, 25, 10),
    );
  });

  tearDown(() async {
    controller.dispose();
    await location.close();
  });

  test(
    'permission denial creates no journal and reports a typed failure',
    () async {
      location.permission = RouteLocationPermission.denied;
      location.requestedForeground = RouteLocationPermission.deniedForever;

      expect(await controller.start(draftId: 'draft-1'), isFalse);

      expect(controller.state.status, RouteRecordingStatus.failed);
      expect(controller.state.failureCode, 'gps_permission_denied_forever');
      expect(repository.current, isNull);
      expect(location.sampleListeners, 0);
    },
  );

  test('records, pauses, resumes in a new leg, and completes', () async {
    expect(await controller.start(draftId: 'draft-1'), isTrue);
    expect(repository.saved.single.sampleCount, 0);
    expect(controller.state.status, RouteRecordingStatus.recording);

    location.emitSample(_sample(0));
    location.emitSample(_sample(2000));
    await _flushEvents();
    expect(controller.state.sampleCount, 2);

    expect(await controller.pause(), isTrue);
    expect(controller.state.status, RouteRecordingStatus.paused);
    expect(await controller.resume(), isTrue);
    expect(controller.state.journal!.legs, hasLength(2));

    location.emitSample(_sample(4000));
    location.emitSample(_sample(6000));
    await _flushEvents();
    expect(await controller.finish(), isTrue);

    expect(controller.state.status, RouteRecordingStatus.completed);
    expect(controller.state.journal!.sampleCount, 4);
    expect(controller.state.journal!.legs, hasLength(2));
    expect(repository.current!.status, RouteRecordingJournalStatus.completed);
  });

  test('service loss pauses safely and preserves the journal', () async {
    await controller.start(draftId: 'draft-1');
    location.emitSample(_sample(0));
    await _flushEvents();

    location.emitServiceEnabled(false);
    await _flushEvents();

    expect(controller.state.status, RouteRecordingStatus.paused);
    expect(controller.state.failureCode, 'gps_location_service_disabled');
    expect(repository.current!.sampleCount, 1);
  });

  test(
    'recovers an interrupted recording as paused without auto-resume',
    () async {
      repository.current = _journal(
        status: RouteRecordingJournalStatus.recording,
      );

      await controller.recover('draft-1');

      expect(controller.state.status, RouteRecordingStatus.paused);
      expect(controller.state.recovered, isTrue);
      expect(
        controller.state.journal!.status,
        RouteRecordingJournalStatus.paused,
      );
      expect(location.sampleListeners, 0);
      expect(repository.current!.status, RouteRecordingJournalStatus.paused);
    },
  );

  test('does not overwrite an existing in-memory recording', () async {
    await controller.start(draftId: 'draft-1');

    expect(await controller.start(draftId: 'draft-2'), isFalse);
    expect(controller.state.journal!.draftId, 'draft-1');
    expect(repository.saved.where((item) => item.revision == 0), hasLength(1));
  });

  test(
    'journal write failure pauses and exposes a recoverable failure',
    () async {
      await controller.start(draftId: 'draft-1');
      repository.failWrites = true;

      location.emitSample(_sample(0));
      await _flushEvents();
      await _flushEvents();

      expect(
        controller.state.status,
        anyOf(RouteRecordingStatus.paused, RouteRecordingStatus.failed),
      );
      expect(controller.state.failureCode, 'gps_journal_write_failed');
      expect(controller.state.journal!.sampleCount, 1);
    },
  );

  test('deletion removes the recovery journal and returns to idle', () async {
    await controller.start(draftId: 'draft-1');
    await controller.pause();

    await controller.deleteRecording();

    expect(controller.state.status, RouteRecordingStatus.idle);
    expect(repository.current, isNull);
  });
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

RouteRecordingSample _sample(int elapsedMilliseconds) => RouteRecordingSample(
  position: GeoPoint(
    latitude: 56.95 + elapsedMilliseconds / 100000000,
    longitude: 24.10 + elapsedMilliseconds / 100000000,
  ),
  horizontalAccuracyMeters: 4,
  elapsedMilliseconds: elapsedMilliseconds,
  capturedAtUtc: DateTime.utc(
    2026,
    7,
    25,
    10,
  ).add(Duration(milliseconds: elapsedMilliseconds)),
  source: RouteRecordingSampleSource.satellite,
);

RouteRecordingJournal _journal({required RouteRecordingJournalStatus status}) =>
    RouteRecordingJournal(
      revision: 2,
      sessionId: 'session-1',
      draftId: 'draft-1',
      startedAtUtc: DateTime.utc(2026, 7, 25, 9),
      updatedAtUtc: DateTime.utc(2026, 7, 25, 10),
      status: status,
      legs: <RouteRecordingLeg>[
        RouteRecordingLeg(
          id: 'leg-1',
          samples: <RouteRecordingSample>[_sample(0)],
        ),
      ],
    );

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'id-${_next++}';
}

class _MemoryJournalRepository implements RouteRecordingJournalRepository {
  RouteRecordingJournal? current;
  final List<RouteRecordingJournal> saved = <RouteRecordingJournal>[];
  bool failWrites = false;

  @override
  Future<void> delete({
    required String draftId,
    required String sessionId,
  }) async {
    if (current?.draftId == draftId && current?.sessionId == sessionId) {
      current = null;
    }
  }

  @override
  Future<RouteRecordingJournal?> loadForDraft(String draftId) async =>
      current?.draftId == draftId ? current : null;

  @override
  Future<void> save(RouteRecordingJournal journal) async {
    if (failWrites) throw StateError('write failed');
    current = journal;
    saved.add(journal);
  }
}

class _FakeLocationPort implements RouteLocationRecordingPort {
  final StreamController<RouteRecordingSample> _samples =
      StreamController<RouteRecordingSample>.broadcast();
  final StreamController<bool> _service = StreamController<bool>.broadcast();

  bool serviceEnabled = true;
  RouteLocationPermission permission = RouteLocationPermission.whileInUse;
  RouteLocationPermission requestedForeground =
      RouteLocationPermission.whileInUse;
  RouteLocationPermission requestedBackground = RouteLocationPermission.always;
  int sampleListeners = 0;

  void emitSample(RouteRecordingSample sample) => _samples.add(sample);
  void emitServiceEnabled(bool enabled) => _service.add(enabled);

  Future<void> close() async {
    await _samples.close();
    await _service.close();
  }

  @override
  Future<RouteLocationPermission> checkPermission() async => permission;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<RouteLocationPermission> requestBackgroundPermission() async =>
      requestedBackground;

  @override
  Future<RouteLocationPermission> requestForegroundPermission() async =>
      requestedForeground;

  @override
  Stream<RouteRecordingSample> samples(
    RouteLocationRecordingSettings settings,
  ) {
    sampleListeners++;
    return _samples.stream;
  }

  @override
  Stream<bool> serviceEnabledChanges() => _service.stream;
}
