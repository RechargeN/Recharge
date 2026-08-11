import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/id/id_generator.dart';
import '../../domain/entities/route_recording_data.dart';
import '../../domain/repositories/route_location_recording_port.dart';
import '../../domain/repositories/route_recording_journal_repository.dart';
import '../../domain/usecases/process_route_recording_usecase.dart';
import '../state/route_recording_state.dart';

class RouteRecordingController extends ChangeNotifier {
  RouteRecordingController({
    required IdGenerator idGenerator,
    required RouteLocationRecordingPort location,
    required RouteRecordingJournalRepository journalRepository,
    DateTime Function()? clock,
    ProcessRouteRecordingUseCase processRecording =
        const ProcessRouteRecordingUseCase(),
    this.maximumJournalSamples = 200000,
    this.settings = const RouteLocationRecordingSettings(
      backgroundEnabled: false,
      distanceFilterMeters: 2,
      minimumInterval: Duration(seconds: 2),
    ),
  }) : _idGenerator = idGenerator,
       _location = location,
       _journalRepository = journalRepository,
       _processRecording = processRecording,
       _clock = clock ?? DateTime.now {
    if (maximumJournalSamples < 2 || !settings.isValid) {
      throw ArgumentError('Invalid Route recording configuration.');
    }
  }

  final IdGenerator _idGenerator;
  final RouteLocationRecordingPort _location;
  final RouteRecordingJournalRepository _journalRepository;
  final ProcessRouteRecordingUseCase _processRecording;
  final DateTime Function() _clock;
  final int maximumJournalSamples;
  final RouteLocationRecordingSettings settings;

  RouteRecordingState _state = const RouteRecordingState.idle();
  RouteRecordingState get state => _state;

  StreamSubscription<RouteRecordingSample>? _sampleSubscription;
  StreamSubscription<bool>? _serviceSubscription;
  Future<void> _writeTail = Future<void>.value();
  bool _disposed = false;

  Future<void> recover(String draftId) async {
    if (draftId.trim().isEmpty || _isActive || _state.journal != null) return;
    _setState(
      RouteRecordingState(
        status: RouteRecordingStatus.recovering,
        journal: _state.journal,
      ),
    );
    try {
      final journal = await _journalRepository.loadForDraft(draftId);
      if (journal == null) {
        _setState(const RouteRecordingState.idle());
        return;
      }
      if (!journal.isValid || journal.draftId != draftId) {
        _fail('gps_recovery_journal_invalid');
        return;
      }
      if (journal.status == RouteRecordingJournalStatus.recording) {
        final paused = _copyJournal(
          journal,
          status: RouteRecordingJournalStatus.paused,
        );
        await _journalRepository.save(paused);
        _setState(
          RouteRecordingState(
            status: RouteRecordingStatus.paused,
            journal: paused,
            recovered: true,
          ),
        );
        return;
      }
      _setState(
        RouteRecordingState(
          status: journal.status == RouteRecordingJournalStatus.completed
              ? RouteRecordingStatus.completed
              : RouteRecordingStatus.paused,
          journal: journal,
          recovered: true,
        ),
      );
      if (journal.status == RouteRecordingJournalStatus.completed) {
        _preparePreview(journal);
      }
    } catch (_) {
      _fail('gps_recovery_failed');
    }
  }

  Future<bool> start({
    required String draftId,
    bool requestBackground = false,
  }) async {
    if (draftId.trim().isEmpty || _isActive || _state.journal != null) {
      return false;
    }
    _setState(
      const RouteRecordingState(
        status: RouteRecordingStatus.requestingPermission,
      ),
    );
    try {
      if (!await _location.isServiceEnabled()) {
        _fail('gps_location_service_disabled');
        return false;
      }
      var permission = await _location.checkPermission();
      if (permission == RouteLocationPermission.denied) {
        permission = await _location.requestForegroundPermission();
      }
      if (!_foregroundAllowed(permission)) {
        _fail(
          permission == RouteLocationPermission.deniedForever
              ? 'gps_permission_denied_forever'
              : 'gps_permission_denied',
        );
        return false;
      }
      var backgroundEnabled = false;
      if (requestBackground) {
        permission = await _location.requestBackgroundPermission();
        if (permission != RouteLocationPermission.always) {
          _fail('gps_background_permission_denied');
          return false;
        }
        backgroundEnabled = true;
      }
      return _startJournal(
        draftId: draftId,
        backgroundEnabled: backgroundEnabled,
      );
    } on RouteLocationException catch (error) {
      _fail(error.code);
      return false;
    } catch (_) {
      _fail('gps_location_unavailable');
      return false;
    }
  }

  Future<bool> _startJournal({
    required String draftId,
    required bool backgroundEnabled,
  }) async {
    final now = _nowUtc();
    final journal = RouteRecordingJournal(
      sessionId: _idGenerator.generate(),
      draftId: draftId,
      startedAtUtc: now,
      updatedAtUtc: now,
      status: RouteRecordingJournalStatus.recording,
      legs: <RouteRecordingLeg>[
        RouteRecordingLeg(id: _idGenerator.generate(), samples: const []),
      ],
    );
    try {
      await _journalRepository.save(journal);
      _setState(
        RouteRecordingState(
          status: RouteRecordingStatus.recording,
          journal: journal,
          backgroundEnabled: backgroundEnabled,
        ),
      );
      _listen(backgroundEnabled: backgroundEnabled);
      return true;
    } catch (_) {
      _fail('gps_journal_write_failed');
      return false;
    }
  }

  Future<bool> pause() async {
    if (_state.status != RouteRecordingStatus.recording) return false;
    await _cancelStreams();
    await _writeTail;
    final journal = _state.journal;
    if (journal == null) return false;
    final paused = _copyJournal(
      journal,
      status: RouteRecordingJournalStatus.paused,
    );
    try {
      await _journalRepository.save(paused);
      _setState(
        _state.copyWith(status: RouteRecordingStatus.paused, journal: paused),
      );
      return true;
    } catch (_) {
      _fail('gps_journal_write_failed', journal: journal);
      return false;
    }
  }

  Future<bool> resume({bool requestBackground = false}) async {
    if (_state.status != RouteRecordingStatus.paused) return false;
    final journal = _state.journal;
    if (journal == null) return false;
    try {
      if (!await _location.isServiceEnabled()) {
        _fail('gps_location_service_disabled', journal: journal);
        return false;
      }
      var permission = await _location.checkPermission();
      if (!_foregroundAllowed(permission)) {
        _fail('gps_permission_revoked', journal: journal);
        return false;
      }
      var backgroundEnabled = false;
      if (requestBackground) {
        if (permission != RouteLocationPermission.always) {
          permission = await _location.requestBackgroundPermission();
        }
        if (permission != RouteLocationPermission.always) {
          _fail('gps_background_permission_denied', journal: journal);
          return false;
        }
        backgroundEnabled = true;
      }
      return _resumeJournal(
        journal: journal,
        backgroundEnabled: backgroundEnabled,
      );
    } on RouteLocationException catch (error) {
      _fail(error.code, journal: journal);
      return false;
    } catch (_) {
      _fail('gps_location_unavailable', journal: journal);
      return false;
    }
  }

  Future<bool> _resumeJournal({
    required RouteRecordingJournal journal,
    required bool backgroundEnabled,
  }) async {
    final resumed = _copyJournal(
      journal,
      status: RouteRecordingJournalStatus.recording,
      legs: <RouteRecordingLeg>[
        ...journal.legs,
        RouteRecordingLeg(id: _idGenerator.generate(), samples: const []),
      ],
    );
    try {
      await _journalRepository.save(resumed);
      _setState(
        RouteRecordingState(
          status: RouteRecordingStatus.recording,
          journal: resumed,
          recovered: _state.recovered,
          backgroundEnabled: backgroundEnabled,
        ),
      );
      _listen(backgroundEnabled: backgroundEnabled);
      return true;
    } catch (_) {
      _fail('gps_journal_write_failed', journal: journal);
      return false;
    }
  }

  Future<bool> finish() async {
    if (_state.status != RouteRecordingStatus.recording &&
        _state.status != RouteRecordingStatus.paused) {
      return false;
    }
    await _cancelStreams();
    await _writeTail;
    final journal = _state.journal;
    if (journal == null) return false;
    final completed = _copyJournal(
      journal,
      status: RouteRecordingJournalStatus.completed,
    );
    try {
      await _journalRepository.save(completed);
      _setState(
        _state.copyWith(
          status: RouteRecordingStatus.completed,
          journal: completed,
          backgroundEnabled: false,
          clearFailureCode: true,
        ),
      );
      _preparePreview(completed);
      return true;
    } catch (_) {
      _fail('gps_journal_write_failed', journal: journal);
      return false;
    }
  }

  Future<void> deleteRecording() async {
    await _cancelStreams();
    await _writeTail;
    final journal = _state.journal;
    if (journal != null) {
      await _journalRepository.delete(
        draftId: journal.draftId,
        sessionId: journal.sessionId,
      );
    }
    _setState(const RouteRecordingState.idle());
  }

  void updatePrivacyTrim({
    required double startMeters,
    required double endMeters,
  }) {
    final journal = _state.journal;
    if (journal == null ||
        journal.status != RouteRecordingJournalStatus.completed) {
      return;
    }
    try {
      final preview = _processRecording.preview(
        journal,
        trimStartMeters: startMeters,
        trimEndMeters: endMeters,
      );
      _setState(
        _state.copyWith(
          status: RouteRecordingStatus.completed,
          preview: preview,
          trimStartMeters: startMeters,
          trimEndMeters: endMeters,
          clearGapResolutions: true,
          clearFailureCode: true,
        ),
      );
    } on RouteRecordingException catch (error) {
      _setState(_state.copyWith(failureCode: error.code));
    }
  }

  void resolveGap(String gapId, RouteRecordingGapResolution resolution) {
    final preview = _state.preview;
    if (preview == null || !preview.gaps.any((gap) => gap.id == gapId)) return;
    _setState(
      _state.copyWith(
        gapResolutions: <String, RouteRecordingGapResolution>{
          ..._state.gapResolutions,
          gapId: resolution,
        },
        clearFailureCode: true,
      ),
    );
  }

  RouteRecordingApplyResult? buildApplyResult() {
    final preview = _state.preview;
    if (preview == null) return null;
    try {
      final result = _processRecording.finalize(
        preview,
        gapResolutions: _state.gapResolutions,
        nowUtc: _nowUtc(),
      );
      _setState(_state.copyWith(clearFailureCode: true));
      return result;
    } on RouteRecordingException catch (error) {
      _setState(_state.copyWith(failureCode: error.code));
      return null;
    }
  }

  Future<void> completeApply() => deleteRecording();

  Future<bool> openAppSettings() => _location.openAppSettings();

  Future<bool> openLocationSettings() => _location.openLocationSettings();

  void _preparePreview(RouteRecordingJournal journal) {
    try {
      final preview = _processRecording.preview(
        journal,
        trimStartMeters: _state.trimStartMeters,
        trimEndMeters: _state.trimEndMeters,
      );
      _setState(
        _state.copyWith(
          status: RouteRecordingStatus.completed,
          preview: preview,
          clearGapResolutions: true,
          clearFailureCode: true,
        ),
      );
    } on RouteRecordingException catch (error) {
      _setState(
        _state.copyWith(
          status: RouteRecordingStatus.failed,
          clearPreview: true,
          clearGapResolutions: true,
          failureCode: error.code,
        ),
      );
    }
  }

  Future<void> _onSample(RouteRecordingSample sample) async {
    if (_state.status != RouteRecordingStatus.recording) return;
    final journal = _state.journal;
    if (journal == null || !sample.isValid) {
      await _pauseFor('gps_sample_invalid');
      return;
    }
    if (journal.sampleCount >= maximumJournalSamples) {
      await _pauseFor('gps_point_limit_reached');
      return;
    }
    final leg = journal.legs.last;
    if (leg.samples.isNotEmpty &&
        sample.elapsedMilliseconds <= leg.samples.last.elapsedMilliseconds) {
      await _pauseFor('gps_monotonic_time_invalid');
      return;
    }
    final updatedLeg = RouteRecordingLeg(
      id: leg.id,
      samples: <RouteRecordingSample>[...leg.samples, sample],
    );
    final updated = _copyJournal(
      journal,
      legs: <RouteRecordingLeg>[
        ...journal.legs.take(journal.legs.length - 1),
        updatedLeg,
      ],
    );
    _setState(_state.copyWith(journal: updated, clearFailureCode: true));
    _enqueueSave(updated);
  }

  void _enqueueSave(RouteRecordingJournal journal) {
    _writeTail = _writeTail
        .then((_) => _journalRepository.save(journal))
        .catchError((Object _) async {
          await _pauseFor('gps_journal_write_failed');
        });
  }

  Future<void> _pauseFor(String code) async {
    if (_state.status != RouteRecordingStatus.recording) return;
    await _cancelStreams();
    final journal = _state.journal;
    if (journal == null) {
      _fail(code);
      return;
    }
    final paused = _copyJournal(
      journal,
      status: RouteRecordingJournalStatus.paused,
    );
    try {
      await _journalRepository.save(paused);
      _setState(
        RouteRecordingState(
          status: RouteRecordingStatus.paused,
          journal: paused,
          failureCode: code,
          recovered: _state.recovered,
        ),
      );
    } catch (_) {
      _fail('gps_journal_write_failed', journal: journal);
    }
  }

  void _listen({required bool backgroundEnabled}) {
    final activeSettings = RouteLocationRecordingSettings(
      backgroundEnabled: backgroundEnabled,
      distanceFilterMeters: settings.distanceFilterMeters,
      minimumInterval: settings.minimumInterval,
    );
    _sampleSubscription = _location
        .samples(activeSettings)
        .listen(
          (sample) => unawaited(_onSample(sample)),
          onError: (Object error, StackTrace _) => unawaited(
            _pauseFor(
              error is RouteLocationException
                  ? error.code
                  : 'gps_location_stream_failed',
            ),
          ),
        );
    _serviceSubscription = _location.serviceEnabledChanges().listen((enabled) {
      if (!enabled) unawaited(_pauseFor('gps_location_service_disabled'));
    });
  }

  Future<void> _cancelStreams() async {
    final sample = _sampleSubscription;
    final service = _serviceSubscription;
    _sampleSubscription = null;
    _serviceSubscription = null;
    await sample?.cancel();
    await service?.cancel();
  }

  RouteRecordingJournal _copyJournal(
    RouteRecordingJournal journal, {
    RouteRecordingJournalStatus? status,
    List<RouteRecordingLeg>? legs,
  }) => RouteRecordingJournal(
    schemaVersion: journal.schemaVersion,
    revision: journal.revision + 1,
    sessionId: journal.sessionId,
    draftId: journal.draftId,
    startedAtUtc: journal.startedAtUtc,
    updatedAtUtc: _nowUtc(),
    status: status ?? journal.status,
    legs: legs ?? journal.legs,
  );

  DateTime _nowUtc() => _clock().toUtc();

  bool _foregroundAllowed(RouteLocationPermission permission) =>
      permission == RouteLocationPermission.whileInUse ||
      permission == RouteLocationPermission.always;

  bool get _isActive =>
      _state.status == RouteRecordingStatus.recording ||
      _state.status == RouteRecordingStatus.requestingPermission ||
      _state.status == RouteRecordingStatus.recovering ||
      _state.status == RouteRecordingStatus.processing;

  void _fail(String code, {RouteRecordingJournal? journal}) {
    _setState(
      RouteRecordingState(
        status: RouteRecordingStatus.failed,
        journal: journal,
        failureCode: code,
        recovered: _state.recovered,
      ),
    );
  }

  void _setState(RouteRecordingState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sampleSubscription?.cancel());
    unawaited(_serviceSubscription?.cancel());
    super.dispose();
  }
}
