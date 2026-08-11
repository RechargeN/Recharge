import '../../domain/entities/route_recording_data.dart';

enum RouteRecordingStatus {
  idle,
  requestingPermission,
  recording,
  paused,
  recovering,
  processing,
  completed,
  failed,
}

class RouteRecordingState {
  const RouteRecordingState({
    required this.status,
    this.journal,
    this.preview,
    this.gapResolutions = const <String, RouteRecordingGapResolution>{},
    this.trimStartMeters = 0,
    this.trimEndMeters = 0,
    this.failureCode,
    this.recovered = false,
    this.backgroundEnabled = false,
  });

  const RouteRecordingState.idle()
    : status = RouteRecordingStatus.idle,
      journal = null,
      preview = null,
      gapResolutions = const <String, RouteRecordingGapResolution>{},
      trimStartMeters = 0,
      trimEndMeters = 0,
      failureCode = null,
      recovered = false,
      backgroundEnabled = false;

  final RouteRecordingStatus status;
  final RouteRecordingJournal? journal;
  final RouteRecordingPreview? preview;
  final Map<String, RouteRecordingGapResolution> gapResolutions;
  final double trimStartMeters;
  final double trimEndMeters;
  final String? failureCode;
  final bool recovered;
  final bool backgroundEnabled;

  int get sampleCount => journal?.sampleCount ?? 0;
  bool get hasResolvedEveryGap =>
      preview != null &&
      preview!.gaps.every((gap) => gapResolutions.containsKey(gap.id));

  RouteRecordingState copyWith({
    RouteRecordingStatus? status,
    RouteRecordingJournal? journal,
    bool clearJournal = false,
    RouteRecordingPreview? preview,
    bool clearPreview = false,
    Map<String, RouteRecordingGapResolution>? gapResolutions,
    bool clearGapResolutions = false,
    double? trimStartMeters,
    double? trimEndMeters,
    String? failureCode,
    bool clearFailureCode = false,
    bool? recovered,
    bool? backgroundEnabled,
  }) => RouteRecordingState(
    status: status ?? this.status,
    journal: clearJournal ? null : (journal ?? this.journal),
    preview: clearPreview ? null : (preview ?? this.preview),
    gapResolutions: clearGapResolutions
        ? const <String, RouteRecordingGapResolution>{}
        : Map<String, RouteRecordingGapResolution>.unmodifiable(
            gapResolutions ?? this.gapResolutions,
          ),
    trimStartMeters: trimStartMeters ?? this.trimStartMeters,
    trimEndMeters: trimEndMeters ?? this.trimEndMeters,
    failureCode: clearFailureCode ? null : (failureCode ?? this.failureCode),
    recovered: recovered ?? this.recovered,
    backgroundEnabled: backgroundEnabled ?? this.backgroundEnabled,
  );
}
