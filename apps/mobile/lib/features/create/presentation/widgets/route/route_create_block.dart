import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/geo/geo_point.dart';
import '../../../application/controllers/create_controller.dart';
import '../../../application/controllers/route_gpx_transfer_controller.dart';
import '../../../application/controllers/route_recording_controller.dart';
import '../../../application/create_providers.dart';
import '../../../application/create_taxonomy.dart';
import '../../../application/route_create_config.dart';
import '../../../application/route_create_coordinator.dart';
import '../../../application/route_create_runtime.dart';
import '../../../application/route_edit_command.dart';
import '../../../application/state/create_state.dart';
import '../../../application/state/route_create_state.dart';
import '../../../application/state/route_recording_state.dart';
import '../../../domain/entities/create_draft_entity.dart';
import '../../../domain/entities/route_draft_data.dart';
import '../../../domain/entities/route_recording_data.dart';
import 'route_editor_section.dart';
import 'route_recording_panel.dart';
import 'route_review_section.dart';

class RouteCreateBlock extends ConsumerStatefulWidget {
  const RouteCreateBlock({
    super.key,
    required this.controller,
    required this.state,
    required this.onPublished,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  ConsumerState<RouteCreateBlock> createState() => _RouteCreateBlockState();
}

class _RouteCreateBlockState extends ConsumerState<RouteCreateBlock> {
  RouteCreateCoordinator? _attachedCoordinator;
  String? _recoveredRecordingDraftId;
  bool _showGpsRecording = false;

  @override
  void dispose() {
    final coordinator = _attachedCoordinator;
    if (coordinator != null) {
      widget.controller.detachRouteCoordinator(coordinator);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(routeCreateRuntimeProvider);
    return runtime.when(
      loading: () => const _StatusPanel(
        icon: Icons.map_outlined,
        title: 'Loading offline trail editor…',
        message: 'No network or paid routing call is required.',
      ),
      error: (Object error, StackTrace _) => _StatusPanel(
        icon: Icons.error_outline,
        title: 'Offline map could not be loaded',
        message: '$error',
        action: FilledButton.icon(
          onPressed: () => ref.invalidate(routeCreateRuntimeProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
      data: _buildRuntime,
    );
  }

  Widget _buildRuntime(RouteCreateRuntime runtime) {
    if (!identical(_attachedCoordinator, runtime.coordinator)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final previous = _attachedCoordinator;
        if (previous != null) {
          widget.controller.detachRouteCoordinator(previous);
        }
        _attachedCoordinator = runtime.coordinator;
        widget.controller.attachRouteCoordinator(runtime.coordinator);
      });
      return const _StatusPanel(
        icon: Icons.route,
        title: 'Preparing Route draft…',
        message: 'Restoring the latest persisted revision.',
      );
    }
    final routeState = widget.controller.routeCreateState;
    if (routeState == null) {
      return const _StatusPanel(
        icon: Icons.hourglass_top,
        title: 'Preparing Route draft…',
        message: 'The editor will be ready in a moment.',
      );
    }
    final gpxTransfer = ref.watch(routeGpxTransferControllerProvider);
    final recording = ref.watch(routeRecordingControllerProvider);
    if (_recoveredRecordingDraftId != widget.state.draft.id) {
      _recoveredRecordingDraftId = widget.state.draft.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(recording.recover(widget.state.draft.id));
      });
    }
    final step = widget.state.routeStep.clamp(0, routeCreateSteps.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StepHeader(
          activeStep: step,
          onSelected: widget.controller.goToRouteStep,
        ),
        if (widget.state.message != null) ...<Widget>[
          const SizedBox(height: 10),
          _MessageBanner(widget.state.message!),
        ],
        if (routeState.status == RouteCreateStatus.routing ||
            routeState.status == RouteCreateStatus.saving ||
            routeState.status == RouteCreateStatus.importing ||
            gpxTransfer.isBusy) ...<Widget>[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey<int>(step),
            child: switch (step) {
              0 => _methodStep(routeState, gpxTransfer, recording),
              1 => _profileStep(routeState, runtime),
              2 => RouteEditorSection(
                route: routeState.route,
                bounds: runtime.coverageBounds,
                graphEdges: runtime.graphEdges,
                attribution: runtime.attribution,
                canUndo: routeState.canUndo,
                canRedo: routeState.canRedo,
                onCommand: widget.controller.applyRouteCommand,
                onFreehand: (points) => _applyFreehand(routeState, points),
                onUndo: widget.controller.undoRoute,
                onRedo: widget.controller.redoRoute,
                onRestore: widget.controller.restorePersistedRoute,
              ),
              3 => _detailsStep(routeState),
              _ => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  RouteReviewSection(
                    state: routeState,
                    bounds: runtime.coverageBounds,
                    graphEdges: runtime.graphEdges,
                    attribution: runtime.attribution,
                    onSave: () => unawaited(widget.controller.saveDraft()),
                    onRestore: widget.controller.restorePersistedRoute,
                    canSubmit:
                        widget.controller.canSubmitRoute ||
                        widget.controller.canPublishRouteDirect,
                    publishesDirectly: widget.controller.canPublishRouteDirect,
                    onPublish: () async {
                      final published = await widget.controller.publishDraft();
                      if (published && mounted) widget.onPublished();
                    },
                  ),
                  const SizedBox(height: 12),
                  _gpxExportCard(routeState, gpxTransfer),
                ],
              ),
            },
          ),
        ),
        const SizedBox(height: 14),
        _navigation(step),
      ],
    );
  }

  Widget _methodStep(
    RouteCreateState state,
    RouteGpxTransferController gpxTransfer,
    RouteRecordingController recording,
  ) => _SectionCard(
    title: 'How will you create the track?',
    subtitle:
        'All methods use one canonical Route model. This demo enables points and freehand without paid services.',
    child: Column(
      children: <Widget>[
        _MethodTile(
          icon: Icons.add_location_alt_outlined,
          title: 'Points',
          subtitle:
              'Place anchors and connect them along the offline trail graph.',
          selected: state.route.creationMethod == RouteCreationMethod.points,
          onTap: () => _selectMethod(state, RouteCreationMethod.points),
        ),
        const SizedBox(height: 8),
        _MethodTile(
          icon: Icons.gesture,
          title: 'Freehand',
          subtitle: 'Draw one continuous line and keep its exact geometry.',
          selected: state.route.creationMethod == RouteCreationMethod.freehand,
          onTap: () => _selectMethod(state, RouteCreationMethod.freehand),
        ),
        const SizedBox(height: 8),
        _MethodTile(
          icon: Icons.gps_fixed,
          title: 'Record with GPS',
          subtitle:
              'Record movement on this device, then review accuracy, gaps and privacy trimming.',
          selected:
              state.route.creationMethod == RouteCreationMethod.recordedGps ||
              recording.state.status != RouteRecordingStatus.idle,
          onTap: () => setState(() => _showGpsRecording = !_showGpsRecording),
        ),
        if (_showGpsRecording ||
            recording.state.status != RouteRecordingStatus.idle) ...<Widget>[
          const SizedBox(height: 10),
          RouteRecordingPanel(
            controller: recording,
            draftId: widget.state.draft.id,
            onApply: (result) => _applyGpsRecording(state, result),
          ),
        ],
        const SizedBox(height: 8),
        _MethodTile(
          icon: Icons.upload_file_outlined,
          title: 'Import GPX',
          subtitle:
              'Inspect a GPX file locally, choose one track and remove private metadata.',
          selected:
              state.route.creationMethod == RouteCreationMethod.importedGpx,
          onTap: gpxTransfer.isBusy
              ? null
              : () => unawaited(gpxTransfer.chooseAndInspect()),
        ),
        if (gpxTransfer.status == RouteGpxTransferStatus.failed) ...<Widget>[
          const SizedBox(height: 10),
          _GpxFailurePanel(
            code: gpxTransfer.failureCode ?? 'gpx_unknown_error',
            onDismiss: gpxTransfer.clearResult,
          ),
        ],
        if (gpxTransfer.inspection != null) ...<Widget>[
          const SizedBox(height: 12),
          _GpxPreviewCard(
            controller: gpxTransfer,
            onCancel: () => unawaited(gpxTransfer.cancelPreview()),
            onImport: () => unawaited(_importGpx(state, gpxTransfer)),
          ),
        ],
      ],
    ),
  );

  Future<bool> _applyGpsRecording(
    RouteCreateState state,
    RouteRecordingApplyResult result,
  ) async {
    var confirmed = state.route.segments.isEmpty;
    if (!confirmed) confirmed = await _confirmReplacement();
    if (!confirmed || !mounted) return false;
    final outcome = await widget.controller.applyRouteCommand(
      ApplyRouteGpsRecording(result: result, confirmGeometryReplacement: true),
    );
    return outcome.accepted;
  }

  Widget _gpxExportCard(
    RouteCreateState state,
    RouteGpxTransferController transfer,
  ) => _SectionCard(
    title: 'GPX export',
    subtitle:
        'Export only the track and optional route POI. Draft IDs, notes, safety data and timestamps are excluded.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (transfer.status == RouteGpxTransferStatus.exported)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('GPX file saved.'),
          ),
        if (transfer.status == RouteGpxTransferStatus.failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_gpxFailureMessage(transfer.failureCode)),
          ),
        FilledButton.icon(
          key: const ValueKey<String>('route-export-gpx'),
          onPressed: state.route.segments.isEmpty || transfer.isBusy
              ? null
              : () => unawaited(_exportGpx(state, transfer)),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export GPX'),
        ),
      ],
    ),
  );

  Future<void> _importGpx(
    RouteCreateState state,
    RouteGpxTransferController transfer,
  ) async {
    final selection = transfer.buildImportSelection();
    if (selection == null) return;
    var confirmed = state.route.segments.isEmpty;
    if (!confirmed) confirmed = await _confirmReplacement();
    if (!confirmed || !mounted) return;
    transfer.beginImport();
    final outcome = await widget.controller.importRouteGpx(
      selection,
      confirmGeometryReplacement: true,
    );
    transfer.completeImport(
      accepted: outcome.accepted,
      failureCode: outcome.failureCode?.name,
    );
  }

  Future<void> _exportGpx(
    RouteCreateState state,
    RouteGpxTransferController transfer,
  ) async {
    var includeElevation = state.route.orderedSegments
        .expand((segment) => segment.geometry.points)
        .every((point) => point.elevationMeters != null);
    var includeWaypoints = state.route.waypoints.isNotEmpty;
    final settings = await showDialog<(bool, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Export GPX'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include elevation'),
                subtitle: includeElevation
                    ? null
                    : const Text('Unavailable for this track'),
                value: includeElevation,
                onChanged: includeElevation
                    ? (value) => setDialogState(
                        () => includeElevation = value ?? false,
                      )
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include route POI'),
                value: includeWaypoints,
                onChanged: state.route.waypoints.isEmpty
                    ? null
                    : (value) => setDialogState(
                        () => includeWaypoints = value ?? false,
                      ),
              ),
              const Text(
                'Private metadata, notes and timestamps are never exported.',
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (includeElevation, includeWaypoints)),
              child: const Text('Save file'),
            ),
          ],
        ),
      ),
    );
    if (settings == null || !mounted) return;
    await transfer.exportRoute(
      routeId: widget.state.draft.id,
      routeVersionId: 'draft-revision-${state.route.revision}',
      route: state.route,
      includeElevation: settings.$1,
      includeWaypoints: settings.$2,
    );
  }

  Widget _profileStep(
    RouteCreateState state,
    RouteCreateRuntime runtime,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _SectionCard(
        title: 'Movement profile',
        subtitle:
            'The bundled Mežaparks graph currently validates walking routes locally.',
        child: DropdownButtonFormField<String>(
          key: const ValueKey<String>('route-profile'),
          value: state.route.profile.id,
          decoration: const InputDecoration(labelText: 'Profile'),
          items: runtime.supportedProfiles
              .map(
                (profile) => DropdownMenuItem<String>(
                  value: profile.id,
                  child: Text(_label(profile.id)),
                ),
              )
              .toList(growable: false),
          onChanged: (String? id) {
            if (id == null) return;
            final profile = runtime.supportedProfiles.firstWhere(
              (candidate) => candidate.id == id,
            );
            unawaited(
              widget.controller.applyRouteCommand(
                ChangeRouteProfile(profile: profile),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Route shape',
        child: SegmentedButton<RouteShape>(
          key: const ValueKey<String>('route-shape'),
          segments: const <ButtonSegment<RouteShape>>[
            ButtonSegment<RouteShape>(
              value: RouteShape.oneWay,
              label: Text('One way'),
            ),
            ButtonSegment<RouteShape>(
              value: RouteShape.loop,
              label: Text('Loop'),
            ),
            ButtonSegment<RouteShape>(
              value: RouteShape.outAndBack,
              label: Text('Out & back'),
            ),
          ],
          selected: <RouteShape>{state.route.shape},
          onSelectionChanged: (Set<RouteShape> values) {
            unawaited(
              widget.controller.applyRouteCommand(
                ChangeRouteShape(values.single),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Routing preferences',
        child: Column(
          children: <Widget>[
            _PreferenceSwitch(
              title: 'Avoid stairs',
              value: _boolPreference(state.route, 'avoid_stairs'),
              onChanged: (bool value) =>
                  _setPreference(state.route, 'avoid_stairs', value),
            ),
            _PreferenceSwitch(
              title: 'Prefer unpaved trails',
              value: _boolPreference(state.route, 'prefer_unpaved'),
              onChanged: (bool value) =>
                  _setPreference(state.route, 'prefer_unpaved', value),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _detailsStep(RouteCreateState state) {
    final draft = widget.state.draft;
    final category =
        createTaxonomyCategoryById(draft.mainCategory) ??
        rechargeCreateTaxonomy.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionCard(
          title: 'Route details',
          child: Column(
            children: <Widget>[
              _DraftField(
                fieldKey: 'route-title',
                label: 'Title *',
                value: draft.title,
                onChanged: widget.controller.updateTitle,
              ),
              _DraftField(
                fieldKey: 'route-short-description',
                label: 'Short description *',
                value: draft.shortDescription,
                minLines: 2,
                maxLines: 3,
                onChanged: widget.controller.updateShortDescription,
              ),
              _DraftField(
                fieldKey: 'route-full-description',
                label: 'Full description',
                value: draft.fullDescription,
                minLines: 3,
                maxLines: 7,
                onChanged: widget.controller.updateFullDescription,
              ),
              _DraftField(
                fieldKey: 'route-cover',
                label: 'Cover image URL',
                value: draft.media.coverImage,
                onChanged: widget.controller.updateCoverImage,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Taxonomy',
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('route-category'),
                value: category.id,
                decoration: const InputDecoration(labelText: 'Category'),
                items: rechargeCreateTaxonomy
                    .where((item) => item.allows(CreateObjectType.route))
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? id) {
                  if (id == null) return;
                  final selected = createTaxonomyCategoryById(id)!;
                  final candidates = selected.subcategories
                      .where((item) => item.allows(CreateObjectType.route))
                      .toList(growable: false);
                  widget.controller.applyTaxonomySelection(
                    mainCategory: selected.id,
                    subcategory: candidates.isEmpty ? '' : candidates.first.id,
                  );
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('route-subcategory-${category.id}'),
                value:
                    category.subcategories.any(
                      (item) => item.id == draft.subcategory,
                    )
                    ? draft.subcategory
                    : null,
                decoration: const InputDecoration(labelText: 'Subcategory'),
                items: category.subcategories
                    .where((item) => item.allows(CreateObjectType.route))
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? id) {
                  if (id != null) {
                    widget.controller.applyTaxonomySelection(
                      mainCategory: category.id,
                      subcategory: id,
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Conditions',
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('route-difficulty'),
                value: state.route.conditions.difficultyId,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'easy.v1',
                    child: Text('Easy'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'moderate.v1',
                    child: Text('Moderate'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'hard.v1',
                    child: Text('Hard'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) _changeDifficulty(state.route, value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Marked trail'),
                value: state.route.conditions.isMarked ?? false,
                onChanged: (bool value) => _changeMarked(state.route, value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navigation(int step) => Row(
    children: <Widget>[
      if (step > 0)
        OutlinedButton(
          onPressed: () => widget.controller.goToRouteStep(step - 1),
          child: const Text('Back'),
        ),
      const Spacer(),
      if (step < routeCreateSteps.length - 1)
        FilledButton(
          key: const ValueKey<String>('route-next-step'),
          onPressed: () => widget.controller.goToRouteStep(step + 1),
          child: const Text('Continue'),
        ),
    ],
  );

  Future<void> _selectMethod(
    RouteCreateState state,
    RouteCreationMethod method,
  ) async {
    if (state.route.creationMethod == method) return;
    var confirmed = state.route.segments.isEmpty;
    if (!confirmed) {
      confirmed = await _confirmReplacement();
    }
    if (!confirmed || !mounted) return;
    await widget.controller.applyRouteCommand(
      SelectRouteCreationMethod(
        method: method,
        confirmGeometryReplacement: true,
      ),
    );
  }

  Future<void> _applyFreehand(
    RouteCreateState state,
    List<GeoPoint> points,
  ) async {
    var confirmed = state.route.segments.isEmpty;
    if (!confirmed) {
      confirmed = await _confirmReplacement();
    }
    if (!confirmed || !mounted) return;
    await widget.controller.applyRouteCommand(
      ApplyRouteFreehandGeometry(
        points: points,
        confirmGeometryReplacement: true,
      ),
    );
  }

  Future<bool> _confirmReplacement() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace existing track?'),
          content: const Text(
            'The current geometry will remain available through Undo.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      ) ??
      false;

  void _setPreference(RouteDraftData route, String id, bool value) {
    final values = <String, RoutePreferenceValue>{
      ...route.preferences.values,
      id: RouteBoolPreferenceValue(value),
    };
    unawaited(
      widget.controller.applyRouteCommand(
        ChangeRouteProfile(
          profile: route.profile,
          preferences: RouteRoutingPreferences(
            schemaVersion: route.preferences.schemaVersion,
            values: values,
          ),
        ),
      ),
    );
  }

  void _changeDifficulty(RouteDraftData route, String value) {
    final current = route.conditions;
    unawaited(
      widget.controller.applyRouteCommand(
        ChangeRouteConditions(
          RouteConditionsDraft(
            difficultyId: value,
            surfaceIds: current.surfaceIds,
            isMarked: current.isMarked,
            bestTimeId: current.bestTimeId,
            goodToKnowIds: current.goodToKnowIds,
            verifiedAtUtc: current.verifiedAtUtc,
            manualDuration: current.manualDuration,
          ),
        ),
      ),
    );
  }

  void _changeMarked(RouteDraftData route, bool value) {
    final current = route.conditions;
    unawaited(
      widget.controller.applyRouteCommand(
        ChangeRouteConditions(
          RouteConditionsDraft(
            difficultyId: current.difficultyId,
            surfaceIds: current.surfaceIds,
            isMarked: value,
            bestTimeId: current.bestTimeId,
            goodToKnowIds: current.goodToKnowIds,
            verifiedAtUtc: current.verifiedAtUtc,
            manualDuration: current.manualDuration,
          ),
        ),
      ),
    );
  }

  static bool _boolPreference(RouteDraftData route, String id) {
    final value = route.preferences.values[id];
    return value is RouteBoolPreferenceValue && value.value;
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.activeStep, required this.onSelected});

  final int activeStep;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Route builder',
    subtitle: 'Step ${activeStep + 1} of ${routeCreateSteps.length}',
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: routeCreateSteps.indexed
          .map(
            (entry) => ChoiceChip(
              key: ValueKey<String>('route-step-${entry.$2.id}'),
              label: Text('${entry.$1 + 1}. ${entry.$2.title}'),
              selected: entry.$1 == activeStep,
              onSelected: (_) => onSelected(entry.$1),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected ? const Icon(Icons.check_circle) : null,
      onTap: onTap,
    ),
  );
}

class _GpxPreviewCard extends StatelessWidget {
  const _GpxPreviewCard({
    required this.controller,
    required this.onCancel,
    required this.onImport,
  });

  final RouteGpxTransferController controller;
  final VoidCallback onCancel;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final inspection = controller.inspection!;
    final selected = controller.selectedCandidate;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              inspection.file.displayName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatBytes(inspection.file.sizeBytes)} · '
              '${inspection.pointCount} points · '
              '${inspection.waypointCount} POI',
            ),
            if (inspection.containsPrivateMetadata ||
                inspection.candidates.any(
                  (item) => item.hasTimestamps,
                )) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'Private metadata and timestamps will be removed during import.',
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Choose one track',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            ...inspection.candidates.map(
              (candidate) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: candidate.selectionKey,
                groupValue: controller.selectedCandidateKey,
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        if (value != null) controller.selectCandidate(value);
                      },
                title: Text(
                  candidate.name?.trim().isNotEmpty == true
                      ? candidate.name!
                      : '${_label(candidate.kind.name)} ${candidate.sourceIndex + 1}',
                ),
                subtitle: Text(
                  '${(candidate.distanceMeters / 1000).toStringAsFixed(1)} km · '
                  '${candidate.pointCount} points · '
                  '${candidate.segmentCount} segment(s)',
                ),
              ),
            ),
            if (selected != null && selected.gapCount > 0)
              CheckboxListTile(
                key: const ValueKey<String>('route-gpx-confirm-gaps'),
                contentPadding: EdgeInsets.zero,
                value: controller.connectGapsConfirmed,
                onChanged: controller.isBusy
                    ? null
                    : (value) =>
                          controller.setConnectGapsConfirmed(value ?? false),
                title: Text(
                  'Connect ${selected.gapCount} gap(s) with straight lines',
                ),
                subtitle: const Text(
                  'Review these connectors on the map before publishing.',
                ),
              ),
            if (inspection.waypoints.isNotEmpty)
              SwitchListTile(
                key: const ValueKey<String>('route-gpx-import-waypoints'),
                contentPadding: EdgeInsets.zero,
                value: controller.importWaypoints,
                onChanged: controller.isBusy
                    ? null
                    : controller.setImportWaypoints,
                title: Text('Import ${inspection.waypointCount} POI'),
                subtitle: const Text(
                  'They remain off-track until reviewed and positioned.',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: controller.isBusy ? null : onCancel,
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  key: const ValueKey<String>('route-gpx-import-confirm'),
                  onPressed: controller.canImport ? onImport : null,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import track'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GpxFailurePanel extends StatelessWidget {
  const _GpxFailurePanel({required this.code, required this.onDismiss});

  final String code;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(_gpxFailureMessage(code))),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );
}

class _DraftField extends StatelessWidget {
  const _DraftField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String fieldKey;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      key: ValueKey<String>('$fieldKey-$value'),
      initialValue: value,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(subtitle!),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: title,
    child: Column(
      children: <Widget>[
        Icon(icon, size: 42),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...<Widget>[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    borderRadius: BorderRadius.circular(14),
    child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
  );
}

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (part) => part.isEmpty
          ? part
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _gpxFailureMessage(String? code) => switch (code) {
  'gpx_file_too_large' => 'The GPX file is too large.',
  'gpx_file_type_unsupported' ||
  'gpx_media_type_unsupported' => 'Choose a valid GPX file.',
  'gpx_xml_malformed' || 'gpx_root_invalid' =>
    'The GPX file is damaged or has an unsupported structure.',
  'gpx_point_limit_exceeded' => 'The GPX track contains too many points.',
  'gpx_export_geometry_invalid' || 'gpx_export_geometry_discontinuous' =>
    'Only one continuous Route track can be exported.',
  'gpx_export_destination_unavailable' =>
    'Saving GPX files is not available on this device yet.',
  'multipleGpxTracksRequireSeparateDrafts' =>
    'Choose one continuous track for this Route draft.',
  _ => 'The GPX operation could not be completed.',
};
