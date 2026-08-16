import '../../../../shared/primitives/geo/geo_point.dart';
import 'route_draft_data.dart';

enum RouteRecordingJournalStatus { recording, paused, completed }

enum RouteRecordingSampleSource { satellite, network, fused, unknown }

enum RouteRecordingGapReason {
  pause,
  timeDiscontinuity,
  rejectedAccuracy,
  rejectedMockLocation,
  implausibleMovement,
}

enum RouteRecordingGapResolution {
  keepGap,
  connectDirect,
  routeBetween,
  splitDraft,
}

class RouteRecordingSample {
  const RouteRecordingSample({
    required this.position,
    required this.horizontalAccuracyMeters,
    required this.elapsedMilliseconds,
    required this.capturedAtUtc,
    required this.source,
    this.isMocked = false,
  });

  final GeoPoint position;
  final double horizontalAccuracyMeters;
  final int elapsedMilliseconds;
  final DateTime capturedAtUtc;
  final RouteRecordingSampleSource source;
  final bool isMocked;

  bool get isValid =>
      position.isValid &&
      horizontalAccuracyMeters.isFinite &&
      horizontalAccuracyMeters >= 0 &&
      elapsedMilliseconds >= 0 &&
      capturedAtUtc.isUtc;
}

class RouteRecordingLeg {
  RouteRecordingLeg({
    required this.id,
    required Iterable<RouteRecordingSample> samples,
  }) : samples = List<RouteRecordingSample>.unmodifiable(samples);

  final String id;
  final List<RouteRecordingSample> samples;

  bool get isValid {
    if (id.trim().isEmpty) return false;
    var previousElapsed = -1;
    for (final sample in samples) {
      if (!sample.isValid || sample.elapsedMilliseconds <= previousElapsed) {
        return false;
      }
      previousElapsed = sample.elapsedMilliseconds;
    }
    return true;
  }
}

class RouteRecordingJournal {
  RouteRecordingJournal({
    this.schemaVersion = 1,
    this.revision = 0,
    required this.sessionId,
    required this.draftId,
    required this.startedAtUtc,
    required this.updatedAtUtc,
    required this.status,
    required Iterable<RouteRecordingLeg> legs,
  }) : legs = List<RouteRecordingLeg>.unmodifiable(legs);

  final int schemaVersion;
  final int revision;
  final String sessionId;
  final String draftId;
  final DateTime startedAtUtc;
  final DateTime updatedAtUtc;
  final RouteRecordingJournalStatus status;
  final List<RouteRecordingLeg> legs;

  int get sampleCount =>
      legs.fold<int>(0, (total, leg) => total + leg.samples.length);

  bool get isValid =>
      schemaVersion == 1 &&
      revision >= 0 &&
      sessionId.trim().isNotEmpty &&
      draftId.trim().isNotEmpty &&
      startedAtUtc.isUtc &&
      updatedAtUtc.isUtc &&
      !updatedAtUtc.isBefore(startedAtUtc) &&
      legs.isNotEmpty &&
      legs.every((leg) => leg.isValid);
}

class RouteRecordingProcessingConfig {
  const RouteRecordingProcessingConfig({
    this.maximumRawSamples = 200000,
    this.maximumHorizontalAccuracyMeters = 50,
    this.maximumSpeedMetersPerSecond = 25,
    this.maximumContinuousGap = const Duration(seconds: 45),
    this.minimumMovementMeters = 1.5,
    this.maximumPrivacyTrimMeters = 2000,
    this.rejectMockedLocations = true,
  });

  final int maximumRawSamples;
  final double maximumHorizontalAccuracyMeters;
  final double maximumSpeedMetersPerSecond;
  final Duration maximumContinuousGap;
  final double minimumMovementMeters;
  final double maximumPrivacyTrimMeters;
  final bool rejectMockedLocations;

  bool get isValid =>
      maximumRawSamples >= 2 &&
      maximumHorizontalAccuracyMeters.isFinite &&
      maximumHorizontalAccuracyMeters > 0 &&
      maximumSpeedMetersPerSecond.isFinite &&
      maximumSpeedMetersPerSecond > 0 &&
      maximumContinuousGap > Duration.zero &&
      minimumMovementMeters.isFinite &&
      minimumMovementMeters >= 0 &&
      maximumPrivacyTrimMeters.isFinite &&
      maximumPrivacyTrimMeters >= 0;
}

class RouteRecordingGapPreview {
  const RouteRecordingGapPreview({
    required this.id,
    required this.beforeTrackIndex,
    required this.afterTrackIndex,
    required this.reason,
    required this.distanceMeters,
    required this.elapsedSeconds,
  });

  final String id;
  final int beforeTrackIndex;
  final int afterTrackIndex;
  final RouteRecordingGapReason reason;
  final double distanceMeters;
  final int elapsedSeconds;
}

class RouteRecordingQualitySummary {
  const RouteRecordingQualitySummary({
    required this.rawSampleCount,
    required this.acceptedSampleCount,
    required this.rejectedAccuracyCount,
    required this.rejectedMockedCount,
    required this.rejectedMovementCount,
    required this.suppressedNoiseCount,
    required this.rawDistanceMeters,
    required this.recordedDurationSeconds,
    required this.averageAccuracyMeters,
    required this.maximumAccuracyMeters,
    required this.trimmedStartCount,
    required this.trimmedEndCount,
  });

  final int rawSampleCount;
  final int acceptedSampleCount;
  final int rejectedAccuracyCount;
  final int rejectedMockedCount;
  final int rejectedMovementCount;
  final int suppressedNoiseCount;
  final double rawDistanceMeters;
  final int recordedDurationSeconds;
  final double averageAccuracyMeters;
  final double maximumAccuracyMeters;
  final int trimmedStartCount;
  final int trimmedEndCount;

  Map<String, num> get safeMetrics => <String, num>{
    'raw_samples': rawSampleCount,
    'accepted_samples': acceptedSampleCount,
    'rejected_accuracy': rejectedAccuracyCount,
    'rejected_mocked': rejectedMockedCount,
    'rejected_movement': rejectedMovementCount,
    'suppressed_noise': suppressedNoiseCount,
    'raw_distance_m': rawDistanceMeters,
    'recorded_duration_s': recordedDurationSeconds,
    'average_accuracy_m': averageAccuracyMeters,
    'maximum_accuracy_m': maximumAccuracyMeters,
    'trimmed_start': trimmedStartCount,
    'trimmed_end': trimmedEndCount,
  };
}

class RouteRecordingPreview {
  RouteRecordingPreview({
    required this.sessionId,
    required Iterable<List<GeoPoint>> tracks,
    required Iterable<RouteRecordingGapPreview> gaps,
    required this.quality,
    required this.trimStartMeters,
    required this.trimEndMeters,
  }) : tracks = List<List<GeoPoint>>.unmodifiable(
         tracks.map((track) => List<GeoPoint>.unmodifiable(track)),
       ),
       gaps = List<RouteRecordingGapPreview>.unmodifiable(gaps);

  final String sessionId;
  final List<List<GeoPoint>> tracks;
  final List<RouteRecordingGapPreview> gaps;
  final RouteRecordingQualitySummary quality;
  final double trimStartMeters;
  final double trimEndMeters;

  int get pointCount =>
      tracks.fold<int>(0, (total, track) => total + track.length);
}

class RouteRecordingApplyResult {
  RouteRecordingApplyResult({
    required Iterable<List<GeoPoint>> tracks,
    required Iterable<RouteSourceIssueDraft> sourceIssues,
    required this.provenance,
    required this.rawStats,
  }) : tracks = List<List<GeoPoint>>.unmodifiable(
         tracks.map((track) => List<GeoPoint>.unmodifiable(track)),
       ),
       sourceIssues = List<RouteSourceIssueDraft>.unmodifiable(sourceIssues);

  final List<List<GeoPoint>> tracks;
  final List<RouteSourceIssueDraft> sourceIssues;
  final RouteProvenanceDraft provenance;
  final RouteSegmentRawStats rawStats;
}

class RouteRecordingException implements Exception {
  const RouteRecordingException(this.code);

  final String code;

  @override
  String toString() => 'RouteRecordingException($code)';
}
