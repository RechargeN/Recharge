import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/geo/geo_point.dart';
import '../../../application/controllers/route_recording_controller.dart';
import '../../../application/state/route_recording_state.dart';
import '../../../domain/entities/route_recording_data.dart';

class RouteRecordingPanel extends StatefulWidget {
  const RouteRecordingPanel({
    super.key,
    required this.controller,
    required this.draftId,
    required this.onApply,
  });

  final RouteRecordingController controller;
  final String draftId;
  final Future<bool> Function(RouteRecordingApplyResult result) onApply;

  @override
  State<RouteRecordingPanel> createState() => _RouteRecordingPanelState();
}

class _RouteRecordingPanelState extends State<RouteRecordingPanel> {
  bool _recordInBackground = false;
  double _trimStartMeters = 0;
  double _trimEndMeters = 0;

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.gps_fixed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusTitle(state.status),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (state.status == RouteRecordingStatus.recording)
                  const _RecordingIndicator(),
              ],
            ),
            const SizedBox(height: 6),
            Text(_statusMessage(state)),
            if (state.recovered) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'Recovered safely after the previous session. Review before resuming.',
              ),
            ],
            if (state.failureCode != null) ...<Widget>[
              const SizedBox(height: 10),
              _FailureMessage(
                code: state.failureCode!,
                onSettings: () =>
                    unawaited(widget.controller.openAppSettings()),
              ),
            ],
            const SizedBox(height: 12),
            ..._controls(state),
            if (state.preview != null) ...<Widget>[
              const SizedBox(height: 14),
              _preview(state),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _controls(RouteRecordingState state) => switch (state.status) {
    RouteRecordingStatus.idle ||
    RouteRecordingStatus.failed when state.journal == null => <Widget>[
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Continue while screen is locked'),
        subtitle: const Text(
          'Requires background location permission and shows a system indicator.',
        ),
        value: _recordInBackground,
        onChanged: (value) => setState(() => _recordInBackground = value),
      ),
      FilledButton.icon(
        key: const ValueKey<String>('route-gps-start'),
        onPressed: () => unawaited(
          widget.controller.start(
            draftId: widget.draftId,
            requestBackground: _recordInBackground,
          ),
        ),
        icon: const Icon(Icons.fiber_manual_record),
        label: const Text('Start recording'),
      ),
    ],
    RouteRecordingStatus.requestingPermission ||
    RouteRecordingStatus.recovering ||
    RouteRecordingStatus.processing => const <Widget>[
      LinearProgressIndicator(),
    ],
    RouteRecordingStatus.recording => <Widget>[
      _SampleCounter(state.sampleCount),
      const SizedBox(height: 10),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey<String>('route-gps-pause'),
              onPressed: () => unawaited(widget.controller.pause()),
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey<String>('route-gps-finish'),
              onPressed: state.sampleCount < 2
                  ? null
                  : () => unawaited(widget.controller.finish()),
              icon: const Icon(Icons.stop),
              label: const Text('Finish'),
            ),
          ),
        ],
      ),
    ],
    RouteRecordingStatus.paused => <Widget>[
      _SampleCounter(state.sampleCount),
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const ValueKey<String>('route-gps-resume'),
        onPressed: () => unawaited(
          widget.controller.resume(requestBackground: _recordInBackground),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Resume recording'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: state.sampleCount < 2
            ? null
            : () => unawaited(widget.controller.finish()),
        icon: const Icon(Icons.stop),
        label: const Text('Finish and review'),
      ),
      TextButton(
        onPressed: _confirmDelete,
        child: const Text('Delete recording'),
      ),
    ],
    RouteRecordingStatus.completed || RouteRecordingStatus.failed => <Widget>[
      _SampleCounter(state.sampleCount),
      TextButton(
        onPressed: _confirmDelete,
        child: const Text('Delete recording'),
      ),
    ],
    RouteRecordingStatus.idle => const <Widget>[],
  };

  Widget _preview(RouteRecordingState state) {
    final preview = state.preview!;
    final quality = preview.quality;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Review recorded track',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        RouteRecordingPreviewMap(preview: preview),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: <Widget>[
            Text('${quality.acceptedSampleCount} accepted points'),
            Text('${(quality.rawDistanceMeters / 1000).toStringAsFixed(2)} km'),
            Text('${(quality.recordedDurationSeconds / 60).round()} min'),
            Text('${quality.averageAccuracyMeters.toStringAsFixed(1)} m avg'),
          ],
        ),
        if (quality.rejectedAccuracyCount +
                quality.rejectedMockedCount +
                quality.rejectedMovementCount >
            0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '${quality.rejectedAccuracyCount + quality.rejectedMockedCount + quality.rejectedMovementCount} unsafe points excluded.',
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'Privacy trim',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        _TrimSlider(
          label: 'Hide route start',
          value: _trimStartMeters,
          onChanged: (value) => setState(() => _trimStartMeters = value),
          onChangeEnd: (_) => _applyTrim(),
        ),
        _TrimSlider(
          label: 'Hide route end',
          value: _trimEndMeters,
          onChanged: (value) => setState(() => _trimEndMeters = value),
          onChangeEnd: (_) => _applyTrim(),
        ),
        if (preview.gaps.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Track gaps',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'A Route must stay continuous. Confirm each straight connection or record the missing section again.',
          ),
          const SizedBox(height: 8),
          ...preview.gaps.indexed.map(
            (entry) => _GapDecision(
              index: entry.$1,
              gap: entry.$2,
              value: state.gapResolutions[entry.$2.id],
              onChanged: (value) {
                if (value != null) {
                  widget.controller.resolveGap(entry.$2.id, value);
                }
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey<String>('route-gps-apply'),
          onPressed: state.hasResolvedEveryGap ? _apply : null,
          icon: const Icon(Icons.check),
          label: const Text('Use this track'),
        ),
      ],
    );
  }

  void _applyTrim() => widget.controller.updatePrivacyTrim(
    startMeters: _trimStartMeters,
    endMeters: _trimEndMeters,
  );

  Future<void> _apply() async {
    final result = widget.controller.buildApplyResult();
    if (result == null) return;
    if (await widget.onApply(result)) {
      await widget.controller.completeApply();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete GPS recording?'),
        content: const Text(
          'The recovery journal and all recorded points will be removed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.deleteRecording();
  }
}

class RouteRecordingPreviewMap extends StatelessWidget {
  const RouteRecordingPreviewMap({super.key, required this.preview});

  final RouteRecordingPreview preview;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Recorded Route preview, ${preview.tracks.length} track sections and ${preview.gaps.length} gaps',
    image: true,
    child: SizedBox(
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: CustomPaint(
            painter: _RecordingPreviewPainter(
              tracks: preview.tracks,
              lineColor: Theme.of(context).colorScheme.primary,
              gapColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RecordingPreviewPainter extends CustomPainter {
  const _RecordingPreviewPainter({
    required this.tracks,
    required this.lineColor,
    required this.gapColor,
  });

  final List<List<GeoPoint>> tracks;
  final Color lineColor;
  final Color gapColor;

  @override
  void paint(Canvas canvas, Size size) {
    final all = tracks.expand((track) => track).toList(growable: false);
    if (all.isEmpty) return;
    final minLat = all.map((point) => point.latitude).reduce(math.min);
    final maxLat = all.map((point) => point.latitude).reduce(math.max);
    final minLng = all.map((point) => point.longitude).reduce(math.min);
    final maxLng = all.map((point) => point.longitude).reduce(math.max);
    const inset = 14.0;
    Offset offset(GeoPoint point) {
      final lngSpan = math.max(maxLng - minLng, 0.000001);
      final latSpan = math.max(maxLat - minLat, 0.000001);
      return Offset(
        inset + (point.longitude - minLng) / lngSpan * (size.width - inset * 2),
        inset + (maxLat - point.latitude) / latSpan * (size.height - inset * 2),
      );
    }

    final routePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4;
    for (final track in tracks) {
      if (track.length < 2) continue;
      final path = Path()
        ..moveTo(offset(track.first).dx, offset(track.first).dy);
      for (final point in track.skip(1)) {
        final target = offset(point);
        path.lineTo(target.dx, target.dy);
      }
      canvas.drawPath(path, routePaint);
    }
    if (tracks.length > 1) {
      final gapPaint = Paint()
        ..color = gapColor
        ..strokeWidth = 2;
      for (var index = 1; index < tracks.length; index++) {
        if (tracks[index - 1].isEmpty || tracks[index].isEmpty) continue;
        canvas.drawLine(
          offset(tracks[index - 1].last),
          offset(tracks[index].first),
          gapPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RecordingPreviewPainter oldDelegate) =>
      oldDelegate.tracks != tracks ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gapColor != gapColor;
}

class _GapDecision extends StatelessWidget {
  const _GapDecision({
    required this.index,
    required this.gap,
    required this.value,
    required this.onChanged,
  });

  final int index;
  final RouteRecordingGapPreview gap;
  final RouteRecordingGapResolution? value;
  final ValueChanged<RouteRecordingGapResolution?> onChanged;

  @override
  Widget build(
    BuildContext context,
  ) => DropdownButtonFormField<RouteRecordingGapResolution>(
    key: ValueKey<String>('route-gps-gap-${gap.id}'),
    value: value,
    decoration: InputDecoration(
      labelText:
          'Gap ${index + 1}: ${gap.distanceMeters.round()} m, ${gap.elapsedSeconds} s',
    ),
    items: const <DropdownMenuItem<RouteRecordingGapResolution>>[
      DropdownMenuItem<RouteRecordingGapResolution>(
        value: RouteRecordingGapResolution.connectDirect,
        child: Text('Connect directly'),
      ),
    ],
    onChanged: onChanged,
  );
}

class _TrimSlider extends StatelessWidget {
  const _TrimSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('$label: ${value.round()} m'),
      Slider(
        value: value,
        min: 0,
        max: 1000,
        divisions: 20,
        label: '${value.round()} m',
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    ],
  );
}

class _SampleCounter extends StatelessWidget {
  const _SampleCounter(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Text(
    '$count GPS points saved',
    key: const ValueKey<String>('route-gps-sample-count'),
  );
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Recording is active',
    child: const Icon(Icons.circle, size: 12, color: Colors.red),
  );
}

class _FailureMessage extends StatelessWidget {
  const _FailureMessage({required this.code, required this.onSettings});

  final String code;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(_failureMessage(code)),
      if (code.contains('permission'))
        TextButton(
          onPressed: onSettings,
          child: const Text('Open app settings'),
        ),
    ],
  );
}

String _statusTitle(RouteRecordingStatus status) => switch (status) {
  RouteRecordingStatus.idle => 'Record with GPS',
  RouteRecordingStatus.requestingPermission => 'Checking GPS access…',
  RouteRecordingStatus.recording => 'Recording Route',
  RouteRecordingStatus.paused => 'Recording paused',
  RouteRecordingStatus.recovering => 'Recovering recording…',
  RouteRecordingStatus.processing => 'Processing track…',
  RouteRecordingStatus.completed => 'Recording ready',
  RouteRecordingStatus.failed => 'GPS needs attention',
};

String _statusMessage(RouteRecordingState state) => switch (state.status) {
  RouteRecordingStatus.idle =>
    'Walk, run or ride the Route. Points stay encrypted on this device until you apply the track.',
  RouteRecordingStatus.requestingPermission =>
    'Recharge requests location only for Route recording.',
  RouteRecordingStatus.recording =>
    state.backgroundEnabled
        ? 'Recording continues with a visible system indicator.'
        : 'Keep Recharge open while moving along the Route.',
  RouteRecordingStatus.paused =>
    'The pause stays as an explicit gap and will never be connected silently.',
  RouteRecordingStatus.recovering => 'Reading the protected local journal.',
  RouteRecordingStatus.processing => 'Filtering unsafe and noisy GPS points.',
  RouteRecordingStatus.completed =>
    'Inspect gaps, accuracy and privacy trimming before using the track.',
  RouteRecordingStatus.failed =>
    'Your saved recording is preserved when recovery is possible.',
};

String _failureMessage(String code) => switch (code) {
  'gps_permission_denied' => 'Location permission was not granted.',
  'gps_permission_denied_forever' ||
  'gps_permission_revoked' => 'Location access is disabled in app settings.',
  'gps_background_permission_denied' =>
    'Background access was not granted. Turn off screen-lock recording or allow it in settings.',
  'gps_location_service_disabled' =>
    'Device location services are switched off.',
  'gps_point_limit_reached' =>
    'The safety point limit was reached. Finish and review this recording.',
  'gps_not_enough_accepted_points' =>
    'Not enough reliable movement was recorded. Delete this recording and try again.',
  'gps_journal_write_failed' =>
    'The protected recording could not be saved. Recording was stopped safely.',
  'gps_gap_decision_required' => 'Review every track gap before continuing.',
  'gps_gap_routing_required' =>
    'This gap needs trail routing before it can be applied.',
  _ => 'GPS recording could not continue safely ($code).',
};
