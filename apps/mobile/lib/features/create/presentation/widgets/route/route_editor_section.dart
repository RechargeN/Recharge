import '../../../../../core/localization/recharge_formats.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/localization/l10n_context.dart';
import '../../../../../core/geo/geo_bounds.dart';
import '../../../../../core/geo/geo_point.dart';
import '../../../../../core/map/map_scene.dart';
import '../../../../../core/parsing/input_parsers.dart';
import '../../../application/route_create_coordinator.dart';
import '../../../application/route_edit_command.dart';
import '../../../domain/entities/route_draft_data.dart';
import 'route_map_builder.dart';
import '../create_form_texts.dart';

class RouteEditorSection extends StatefulWidget {
  const RouteEditorSection({
    super.key,
    required this.route,
    required this.bounds,
    required this.graphEdges,
    required this.attribution,
    required this.canUndo,
    required this.canRedo,
    required this.onCommand,
    required this.onFreehand,
    required this.onUndo,
    required this.onRedo,
    required this.onRestore,
  });

  final RouteDraftData route;
  final GeoBounds bounds;
  final List<MapPolylineData> graphEdges;
  final String attribution;
  final bool canUndo;
  final bool canRedo;
  final Future<RouteCommandOutcome> Function(RouteEditCommand command)
  onCommand;
  final Future<void> Function(List<GeoPoint> points) onFreehand;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onRestore;

  @override
  State<RouteEditorSection> createState() => _RouteEditorSectionState();
}

class _RouteEditorSectionState extends State<RouteEditorSection> {
  final TextEditingController _latitude = TextEditingController();
  final TextEditingController _longitude = TextEditingController();

  @override
  void initState() {
    super.initState();
    _latitude.text = '56.9700';
    _longitude.text = '24.1300';
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Panel(
          title: context.l10n.createRouteOfflineTrailEditor,
          subtitle: route.creationMethod == RouteCreationMethod.freehand
              ? context.l10n.createRouteDrawOneContinuousLineExistingGeometry
              : context.l10n.createRouteTapMapAddAnchorsLocalGraph,
          child: RouteMapBuilder(
            bounds: widget.bounds,
            graphEdges: widget.graphEdges,
            route: route,
            attribution: widget.attribution,
            onPointAdded: (GeoPoint point) {
              unawaited(widget.onCommand(AddRouteAnchor(position: point)));
            },
            onFreehandCompleted: (List<GeoPoint> points) {
              unawaited(widget.onFreehand(points));
            },
          ),
        ),
        const SizedBox(height: 12),
        _historyControls(),
        const SizedBox(height: 12),
        if (route.creationMethod == RouteCreationMethod.points)
          _accessibleAnchorInput(),
        if (route.creationMethod == RouteCreationMethod.points)
          const SizedBox(height: 12),
        _anchorList(),
        const SizedBox(height: 12),
        _segmentList(),
        const SizedBox(height: 12),
        _waypointList(),
      ],
    );
  }

  Widget _historyControls() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: <Widget>[
      OutlinedButton.icon(
        onPressed: widget.canUndo ? widget.onUndo : null,
        icon: const Icon(Icons.undo),
        label: Text(context.l10n.createRouteUndo),
      ),
      OutlinedButton.icon(
        onPressed: widget.canRedo ? widget.onRedo : null,
        icon: const Icon(Icons.redo),
        label: Text(context.l10n.createRouteRedo),
      ),
      OutlinedButton.icon(
        onPressed: widget.onRestore,
        icon: const Icon(Icons.restore),
        label: Text(context.l10n.createRouteLastSaved),
      ),
    ],
  );

  Widget _accessibleAnchorInput() => _Panel(
    title: context.l10n.createRouteAddAnchorWithoutMapGestures,
    subtitle: context
        .l10n
        .createRouteCoordinatesProvideKeyboardScreenReaderAlternative,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const ValueKey<String>('route-anchor-latitude'),
                controller: _latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.createRouteLatitude,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey<String>('route-anchor-longitude'),
                controller: _longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.createRouteLongitude,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey<String>('route-add-anchor-coordinates'),
          onPressed: _addCoordinateAnchor,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(context.l10n.createRouteAddAnchor),
        ),
      ],
    ),
  );

  Widget _anchorList() => _Panel(
    title: context.l10n.createRouteAnchorsTitle(widget.route.anchors.length),
    subtitle: context.l10n.createRouteEveryActionAvailableAsLabelledControl,
    child: widget.route.anchors.isEmpty
        ? Text(context.l10n.createRouteNoAnchorsYet)
        : Column(
            children: widget.route.anchors.indexed
                .map((entry) {
                  final index = entry.$1;
                  final anchor = entry.$2;
                  return Semantics(
                    container: true,
                    label: context.l10n.createRouteAnchorSemantics(
                      index + 1,
                      anchor.position.latitude.toStringAsFixed(5),
                      anchor.position.longitude.toStringAsFixed(5),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(
                          '${anchor.position.latitude.toStringAsFixed(5)}, '
                          '${anchor.position.longitude.toStringAsFixed(5)}',
                        ),
                        subtitle: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            IconButton(
                              tooltip: context.l10n.createRouteMoveAnchorNorth,
                              onPressed: () => _nudge(anchor, latitude: 0.0001),
                              icon: const Icon(Icons.north),
                            ),
                            IconButton(
                              tooltip: context.l10n.createRouteMoveAnchorSouth,
                              onPressed: () =>
                                  _nudge(anchor, latitude: -0.0001),
                              icon: const Icon(Icons.south),
                            ),
                            IconButton(
                              tooltip: context.l10n.createRouteMoveAnchorWest,
                              onPressed: () =>
                                  _nudge(anchor, longitude: -0.0001),
                              icon: const Icon(Icons.west),
                            ),
                            IconButton(
                              tooltip: context.l10n.createRouteMoveAnchorEast,
                              onPressed: () =>
                                  _nudge(anchor, longitude: 0.0001),
                              icon: const Icon(Icons.east),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: context.l10n.createRouteAnchorActions,
                          onSelected: (String value) {
                            if (value == 'poi') {
                              unawaited(
                                widget.onCommand(
                                  AddRouteWaypoint(
                                    anchorId: anchor.id,
                                    typeId: 'viewpoint.v1',
                                  ),
                                ),
                              );
                            } else if (value == 'delete') {
                              unawaited(
                                widget.onCommand(
                                  RemoveRouteAnchor(anchorId: anchor.id),
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'poi',
                              child: Text(context.l10n.createRouteAddViewpoint),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text(context.l10n.createRouteRemoveAnchor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
  );

  Widget _segmentList() => _Panel(
    title: context.l10n.createRouteSegmentsTitle(widget.route.segments.length),
    child: widget.route.orderedSegments.isEmpty
        ? Text(context.l10n.createRouteSegmentAppears)
        : Column(
            children: widget.route.orderedSegments
                .map((segment) {
                  final failed =
                      segment.operationState ==
                      RouteSegmentOperationState.failed;
                  return Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        failed ? Icons.error_outline : Icons.route_outlined,
                      ),
                      title: Text(
                        '${context.l10n.createRouteSegmentN(segment.order + 1)} • '
                        '${context.l10n.createFormDistanceKm(RechargeFormats.decimal(segment.distanceMeters / 1000, context.l10n.localeName, maxFractionDigits: 2))}',
                      ),
                      subtitle: Text(
                        '${createOptionText(context.l10n, segment.source)} • '
                        '${createOptionText(context.l10n, segment.operationState)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: context.l10n.createRouteSegmentActions,
                        onSelected: (String value) {
                          if (value == 'retry') {
                            unawaited(
                              widget.onCommand(RetryRouteSegment(segment.id)),
                            );
                          } else if (value == 'direct') {
                            unawaited(
                              widget.onCommand(
                                SetRouteSegmentDirect(segmentId: segment.id),
                              ),
                            );
                          } else if (value == 'split' &&
                              segment.geometry.points.length >= 3) {
                            unawaited(
                              widget.onCommand(
                                SplitRouteSegment(
                                  segmentId: segment.id,
                                  position:
                                      segment.geometry.points[segment
                                              .geometry
                                              .points
                                              .length ~/
                                          2],
                                ),
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => <PopupMenuEntry<String>>[
                          if (failed)
                            PopupMenuItem<String>(
                              value: 'retry',
                              child: Text(context.l10n.createRouteRetryRouting),
                            ),
                          PopupMenuItem<String>(
                            value: 'direct',
                            child: Text(
                              context.l10n.createRouteUseIntentionalDirectLine,
                            ),
                          ),
                          if (segment.geometry.points.length >= 3)
                            PopupMenuItem<String>(
                              value: 'split',
                              child: Text(
                                context.l10n.createRouteSplitAtMidpoint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
  );

  Widget _waypointList() => _Panel(
    title: context.l10n.createRouteWaypointsTitle(
      widget.route.waypoints.length,
    ),
    child: widget.route.waypoints.isEmpty
        ? Text(context.l10n.createRouteAddViewpointFromAnchorMenu)
        : Column(
            children: widget.route.waypoints
                .map((waypoint) {
                  return Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(waypoint.typeId),
                      subtitle: DropdownButton<String>(
                        value: waypoint.anchorId,
                        hint: Text(context.l10n.createRouteAttachAnchor),
                        isExpanded: true,
                        items: widget.route.anchors.indexed
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.$2.id,
                                child: Text(
                                  context.l10n.createRouteAnchorN(entry.$1 + 1),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (String? anchorId) {
                          if (anchorId != null &&
                              anchorId != waypoint.anchorId) {
                            unawaited(
                              widget.onCommand(
                                MoveRouteWaypoint(
                                  waypointId: waypoint.id,
                                  anchorId: anchorId,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      trailing: IconButton(
                        tooltip: context.l10n.createRouteRemoveWaypoint,
                        onPressed: () => unawaited(
                          widget.onCommand(RemoveRouteWaypoint(waypoint.id)),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
  );

  void _addCoordinateAnchor() {
    final latitude = parseLocaleDecimalInput(_latitude.text);
    final longitude = parseLocaleDecimalInput(_longitude.text);
    if (latitude == null || longitude == null) return;
    unawaited(
      widget.onCommand(
        AddRouteAnchor(
          position: GeoPoint(latitude: latitude, longitude: longitude),
        ),
      ),
    );
  }

  void _nudge(
    RouteAnchorDraft anchor, {
    double latitude = 0,
    double longitude = 0,
  }) {
    unawaited(
      widget.onCommand(
        MoveRouteAnchor(
          anchorId: anchor.id,
          position: GeoPoint(
            latitude: anchor.position.latitude + latitude,
            longitude: anchor.position.longitude + longitude,
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
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
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(subtitle!),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
