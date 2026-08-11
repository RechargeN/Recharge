import '../../../../core/geo/geo_distance.dart';
import '../../../../core/geo/geo_point.dart';
import '../entities/route_draft_data.dart';
import '../entities/route_recording_data.dart';

class ProcessRouteRecordingUseCase {
  const ProcessRouteRecordingUseCase({
    this.config = const RouteRecordingProcessingConfig(),
  });

  final RouteRecordingProcessingConfig config;

  RouteRecordingPreview preview(
    RouteRecordingJournal journal, {
    double trimStartMeters = 0,
    double trimEndMeters = 0,
  }) {
    _validateInput(journal, trimStartMeters, trimEndMeters);
    final tracks = <_RecordedTrack>[];
    var rejectedAccuracy = 0;
    var rejectedMocked = 0;
    var rejectedMovement = 0;
    var suppressedNoise = 0;

    for (var legIndex = 0; legIndex < journal.legs.length; legIndex++) {
      final leg = journal.legs[legIndex];
      _RecordedTrack? current;
      RouteRecordingSample? previousAccepted;
      RouteRecordingGapReason? pendingReason;
      for (final sample in leg.samples) {
        if (sample.horizontalAccuracyMeters >
            config.maximumHorizontalAccuracyMeters) {
          rejectedAccuracy++;
          pendingReason ??= RouteRecordingGapReason.rejectedAccuracy;
          continue;
        }
        if (config.rejectMockedLocations && sample.isMocked) {
          rejectedMocked++;
          pendingReason ??= RouteRecordingGapReason.rejectedMockLocation;
          continue;
        }
        final previous = previousAccepted;
        if (previous != null) {
          final elapsedMillis =
              sample.elapsedMilliseconds - previous.elapsedMilliseconds;
          if (elapsedMillis <= 0) {
            throw const RouteRecordingException('gps_monotonic_time_invalid');
          }
          final distance = GeoDistance.haversineMeters(
            previous.position,
            sample.position,
          );
          final speed = distance / (elapsedMillis / 1000);
          if (speed > config.maximumSpeedMetersPerSecond) {
            rejectedMovement++;
            pendingReason = RouteRecordingGapReason.implausibleMovement;
            previousAccepted = null;
            current = null;
            continue;
          }
          if (elapsedMillis > config.maximumContinuousGap.inMilliseconds) {
            pendingReason = RouteRecordingGapReason.timeDiscontinuity;
            current = null;
          } else if (distance < config.minimumMovementMeters) {
            suppressedNoise++;
            continue;
          }
        }
        if (current == null) {
          current = _RecordedTrack(
            gapFromPrevious: tracks.isEmpty
                ? null
                : pendingReason ??
                      (legIndex > 0
                          ? RouteRecordingGapReason.pause
                          : RouteRecordingGapReason.timeDiscontinuity),
          );
          tracks.add(current);
        }
        current.samples.add(sample);
        previousAccepted = sample;
        pendingReason = null;
      }
    }

    final viable = tracks.where((track) => track.samples.length >= 2).toList();
    if (viable.isEmpty) {
      throw const RouteRecordingException('gps_not_enough_accepted_points');
    }
    final trimmedStart = _trimStart(viable, trimStartMeters);
    final trimmedEnd = _trimEnd(viable, trimEndMeters);
    final usable = viable.where((track) => track.samples.length >= 2).toList();
    if (usable.isEmpty) {
      throw const RouteRecordingException('gps_privacy_trim_too_large');
    }

    final gaps = <RouteRecordingGapPreview>[];
    for (var index = 1; index < usable.length; index++) {
      final before = usable[index - 1].samples.last;
      final after = usable[index].samples.first;
      gaps.add(
        RouteRecordingGapPreview(
          id: 'gps-gap-${index - 1}-$index',
          beforeTrackIndex: index - 1,
          afterTrackIndex: index,
          reason:
              usable[index].gapFromPrevious ?? RouteRecordingGapReason.pause,
          distanceMeters: GeoDistance.haversineMeters(
            before.position,
            after.position,
          ),
          elapsedSeconds:
              ((after.elapsedMilliseconds - before.elapsedMilliseconds) / 1000)
                  .abs()
                  .round(),
        ),
      );
    }

    final accepted = usable.expand((track) => track.samples).toList();
    final accuracies = journal.legs
        .expand((leg) => leg.samples)
        .map((sample) => sample.horizontalAccuracyMeters)
        .toList();
    final rawDistance = usable.fold<double>(
      0,
      (total, track) =>
          total +
          GeoDistance.polylineLengthMeters(
            track.samples.map((sample) => sample.position),
          ),
    );
    final recordedDurationSeconds = usable.fold<int>(
      0,
      (total, track) =>
          total +
          ((track.samples.last.elapsedMilliseconds -
                      track.samples.first.elapsedMilliseconds) /
                  1000)
              .round(),
    );
    return RouteRecordingPreview(
      sessionId: journal.sessionId,
      tracks: usable.map(
        (track) => track.samples.map((sample) => sample.position).toList(),
      ),
      gaps: gaps,
      trimStartMeters: trimStartMeters,
      trimEndMeters: trimEndMeters,
      quality: RouteRecordingQualitySummary(
        rawSampleCount: journal.sampleCount,
        acceptedSampleCount: accepted.length,
        rejectedAccuracyCount: rejectedAccuracy,
        rejectedMockedCount: rejectedMocked,
        rejectedMovementCount: rejectedMovement,
        suppressedNoiseCount: suppressedNoise,
        rawDistanceMeters: rawDistance,
        recordedDurationSeconds: recordedDurationSeconds,
        averageAccuracyMeters:
            accuracies.fold<double>(0, (sum, value) => sum + value) /
            accuracies.length,
        maximumAccuracyMeters: accuracies.reduce(
          (left, right) => left > right ? left : right,
        ),
        trimmedStartCount: trimmedStart,
        trimmedEndCount: trimmedEnd,
      ),
    );
  }

  RouteRecordingApplyResult finalize(
    RouteRecordingPreview preview, {
    required Map<String, RouteRecordingGapResolution> gapResolutions,
    required DateTime nowUtc,
  }) {
    if (!nowUtc.isUtc || preview.tracks.isEmpty) {
      throw const RouteRecordingException('gps_preview_invalid');
    }
    final tracks = preview.tracks.map(List<GeoPoint>.of).toList();
    var directGapCount = 0;
    for (var index = preview.gaps.length - 1; index >= 0; index--) {
      final gap = preview.gaps[index];
      final resolution = gapResolutions[gap.id];
      if (resolution == null) {
        throw const RouteRecordingException('gps_gap_decision_required');
      }
      switch (resolution) {
        case RouteRecordingGapResolution.connectDirect:
          tracks[gap.beforeTrackIndex] = _join(
            tracks[gap.beforeTrackIndex],
            tracks[gap.afterTrackIndex],
          );
          tracks.removeAt(gap.afterTrackIndex);
          directGapCount++;
        case RouteRecordingGapResolution.keepGap:
        case RouteRecordingGapResolution.splitDraft:
          break;
        case RouteRecordingGapResolution.routeBetween:
          throw const RouteRecordingException('gps_gap_routing_required');
      }
    }
    final issues = <RouteSourceIssueDraft>[
      if (preview.quality.rejectedAccuracyCount > 0)
        RouteSourceIssueDraft(
          id: 'loc_gps_accuracy_review',
          code: 'gps_accuracy_points_excluded',
          severity: RouteSourceIssueSeverity.warning,
          safeMetrics: <String, num>{
            'count': preview.quality.rejectedAccuracyCount,
            'maximum_accuracy_m': preview.quality.maximumAccuracyMeters.round(),
          },
        ),
      if (preview.quality.rejectedMovementCount > 0)
        RouteSourceIssueDraft(
          id: 'loc_gps_movement_review',
          code: 'gps_implausible_movement_excluded',
          severity: RouteSourceIssueSeverity.warning,
          safeMetrics: <String, num>{
            'count': preview.quality.rejectedMovementCount,
          },
        ),
      if (directGapCount > 0)
        RouteSourceIssueDraft(
          id: 'loc_gps_gap_review',
          code: 'gps_direct_gap_confirmed',
          severity: RouteSourceIssueSeverity.warning,
          safeMetrics: <String, num>{'count': directGapCount},
        ),
      if (tracks.length > 1)
        RouteSourceIssueDraft(
          id: 'loc_gps_discontinuous',
          code: 'gps_gap_kept',
          severity: RouteSourceIssueSeverity.blocking,
          safeMetrics: <String, num>{'track_count': tracks.length},
        ),
    ];
    return RouteRecordingApplyResult(
      tracks: tracks,
      sourceIssues: issues,
      provenance: RouteProvenanceDraft(
        sourceId: 'gps-recording',
        sourceRevision: 0,
        createdAtUtc: nowUtc,
        algorithmVersion: 'gps-processing-v1',
      ),
      rawStats: RouteSegmentRawStats(
        distanceMeters: preview.quality.rawDistanceMeters,
        recordedDurationSeconds: preview.quality.recordedDurationSeconds,
      ),
    );
  }

  void _validateInput(
    RouteRecordingJournal journal,
    double trimStartMeters,
    double trimEndMeters,
  ) {
    if (!config.isValid) {
      throw const RouteRecordingException('gps_config_invalid');
    }
    if (!journal.isValid) {
      throw const RouteRecordingException('gps_journal_invalid');
    }
    if (journal.status != RouteRecordingJournalStatus.completed) {
      throw const RouteRecordingException('gps_recording_not_completed');
    }
    if (journal.sampleCount > config.maximumRawSamples) {
      throw const RouteRecordingException('gps_point_limit_exceeded');
    }
    if (!trimStartMeters.isFinite ||
        !trimEndMeters.isFinite ||
        trimStartMeters < 0 ||
        trimEndMeters < 0 ||
        trimStartMeters > config.maximumPrivacyTrimMeters ||
        trimEndMeters > config.maximumPrivacyTrimMeters) {
      throw const RouteRecordingException('gps_privacy_trim_invalid');
    }
  }

  int _trimStart(List<_RecordedTrack> tracks, double radiusMeters) {
    if (radiusMeters <= 0) return 0;
    var removed = 0;
    while (tracks.isNotEmpty) {
      final track = tracks.first;
      if (track.samples.isEmpty) {
        tracks.removeAt(0);
        continue;
      }
      final origin = track.samples.first.position;
      var keepFrom = 0;
      while (keepFrom < track.samples.length - 1 &&
          GeoDistance.haversineMeters(
                origin,
                track.samples[keepFrom].position,
              ) <
              radiusMeters) {
        keepFrom++;
      }
      if (keepFrom == 0) break;
      removed += keepFrom;
      track.samples.removeRange(0, keepFrom);
      break;
    }
    return removed;
  }

  int _trimEnd(List<_RecordedTrack> tracks, double radiusMeters) {
    if (radiusMeters <= 0) return 0;
    var removed = 0;
    while (tracks.isNotEmpty) {
      final track = tracks.last;
      if (track.samples.isEmpty) {
        tracks.removeLast();
        continue;
      }
      final origin = track.samples.last.position;
      var keepUntil = track.samples.length - 1;
      while (keepUntil > 0 &&
          GeoDistance.haversineMeters(
                origin,
                track.samples[keepUntil].position,
              ) <
              radiusMeters) {
        keepUntil--;
      }
      final removeFrom = keepUntil + 1;
      if (removeFrom >= track.samples.length) break;
      removed += track.samples.length - removeFrom;
      track.samples.removeRange(removeFrom, track.samples.length);
      break;
    }
    return removed;
  }

  List<GeoPoint> _join(List<GeoPoint> first, List<GeoPoint> second) =>
      <GeoPoint>[
        ...first,
        if (first.last == second.first) ...second.skip(1) else ...second,
      ];
}

class _RecordedTrack {
  _RecordedTrack({this.gapFromPrevious});

  final RouteRecordingGapReason? gapFromPrevious;
  final List<RouteRecordingSample> samples = <RouteRecordingSample>[];
}
