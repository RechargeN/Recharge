import 'package:flutter/material.dart';

import '../../../../../core/geo/geo_bounds.dart';
import '../../../../../core/geo/geo_point.dart';
import '../../../../../core/map/map_scene.dart';
import '../../../domain/entities/route_draft_data.dart';

class RouteMapBuilder extends StatefulWidget {
  const RouteMapBuilder({
    super.key,
    required this.bounds,
    required this.graphEdges,
    required this.route,
    required this.attribution,
    required this.onPointAdded,
    required this.onFreehandCompleted,
    this.interactive = true,
  });

  final GeoBounds bounds;
  final List<MapPolylineData> graphEdges;
  final RouteDraftData route;
  final String attribution;
  final ValueChanged<GeoPoint> onPointAdded;
  final ValueChanged<List<GeoPoint>> onFreehandCompleted;
  final bool interactive;

  @override
  State<RouteMapBuilder> createState() => _RouteMapBuilderState();
}

class _RouteMapBuilderState extends State<RouteMapBuilder> {
  final List<GeoPoint> _freehandPreview = <GeoPoint>[];

  bool get _isFreehand =>
      widget.route.creationMethod == RouteCreationMethod.freehand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: _isFreehand
          ? 'Offline trail map. Draw a continuous route with one finger.'
          : 'Offline trail map. Tap to add a route anchor.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1.35,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  key: const ValueKey<String>('route-map-canvas'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: !widget.interactive || _isFreehand
                      ? null
                      : (details) {
                          widget.onPointAdded(
                            _geoFor(details.localPosition, size),
                          );
                        },
                  onPanStart: !widget.interactive || !_isFreehand
                      ? null
                      : (details) {
                          setState(() {
                            _freehandPreview
                              ..clear()
                              ..add(_geoFor(details.localPosition, size));
                          });
                        },
                  onPanUpdate: !widget.interactive || !_isFreehand
                      ? null
                      : (details) {
                          final point = _geoFor(details.localPosition, size);
                          if (_freehandPreview.isEmpty ||
                              _freehandPreview.last != point) {
                            setState(() => _freehandPreview.add(point));
                          }
                        },
                  onPanEnd: !widget.interactive || !_isFreehand
                      ? null
                      : (_) {
                          if (_freehandPreview.length >= 2) {
                            widget.onFreehandCompleted(
                              List<GeoPoint>.of(_freehandPreview),
                            );
                          }
                          setState(_freehandPreview.clear);
                        },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: ColoredBox(
                      color: colorScheme.surfaceContainerLowest,
                      child: CustomPaint(
                        painter: _RouteMapPainter(
                          bounds: widget.bounds,
                          graphEdges: widget.graphEdges,
                          route: widget.route,
                          preview: _freehandPreview,
                          graphColor: colorScheme.outlineVariant,
                          routeColor: colorScheme.primary,
                          previewColor: colorScheme.tertiary,
                          anchorColor: colorScheme.secondary,
                          waypointColor: colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.attribution,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  GeoPoint _geoFor(Offset offset, Size size) {
    final x = (offset.dx / size.width).clamp(0.0, 1.0);
    final y = (offset.dy / size.height).clamp(0.0, 1.0);
    return GeoPoint(
      latitude:
          widget.bounds.north - (widget.bounds.north - widget.bounds.south) * y,
      longitude:
          widget.bounds.west + (widget.bounds.east - widget.bounds.west) * x,
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  const _RouteMapPainter({
    required this.bounds,
    required this.graphEdges,
    required this.route,
    required this.preview,
    required this.graphColor,
    required this.routeColor,
    required this.previewColor,
    required this.anchorColor,
    required this.waypointColor,
  });

  final GeoBounds bounds;
  final List<MapPolylineData> graphEdges;
  final RouteDraftData route;
  final List<GeoPoint> preview;
  final Color graphColor;
  final Color routeColor;
  final Color previewColor;
  final Color anchorColor;
  final Color waypointColor;

  @override
  void paint(Canvas canvas, Size size) {
    final graphPaint = Paint()
      ..color = graphColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final edge in graphEdges) {
      _drawLine(canvas, size, edge.points, graphPaint);
    }

    final routePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final segment in route.orderedSegments) {
      _drawLine(canvas, size, segment.geometry.points, routePaint);
    }

    if (preview.length >= 2) {
      final previewPaint = Paint()
        ..color = previewColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      _drawLine(canvas, size, preview, previewPaint);
    }

    final anchorPaint = Paint()..color = anchorColor;
    for (final anchor in route.anchors) {
      canvas.drawCircle(_offsetFor(anchor.position, size), 6, anchorPaint);
      canvas.drawCircle(
        _offsetFor(anchor.position, size),
        2.4,
        Paint()..color = Colors.white,
      );
    }
    final waypointPaint = Paint()..color = waypointColor;
    for (final waypoint in route.waypoints) {
      canvas.drawCircle(_offsetFor(waypoint.position, size), 4, waypointPaint);
    }
  }

  void _drawLine(Canvas canvas, Size size, List<GeoPoint> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()
      ..moveTo(
        _offsetFor(points.first, size).dx,
        _offsetFor(points.first, size).dy,
      );
    for (final point in points.skip(1)) {
      final offset = _offsetFor(point, size);
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, paint);
  }

  Offset _offsetFor(GeoPoint point, Size size) {
    final x = (point.longitude - bounds.west) / (bounds.east - bounds.west);
    final y = (bounds.north - point.latitude) / (bounds.north - bounds.south);
    return Offset(x * size.width, y * size.height);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.route != route ||
      oldDelegate.preview.length != preview.length ||
      oldDelegate.graphColor != graphColor ||
      oldDelegate.routeColor != routeColor;
}
