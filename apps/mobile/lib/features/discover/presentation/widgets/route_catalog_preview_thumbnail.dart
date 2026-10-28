import '../../../../core/localization/l10n_context.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/primitives/geo/geo_point.dart';
import '../../domain/entities/route_catalog_facts.dart';

/// DTL-RTE-02 RD-04: the card's small drawing of the Catalog preview line —
/// one path per segment, gaps left open. Pure painting of public points: no
/// map tiles, no network and no stored geometry.
class RouteCatalogPreviewThumbnail extends StatelessWidget {
  const RouteCatalogPreviewThumbnail({
    super.key,
    required this.facts,
    required this.color,
    this.size = 40,
  });

  final RouteCatalogFacts facts;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.discoverRoutePreview(facts.preview.length),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PreviewPainter(facts.preview, color)),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.segments, this.color);

  final List<RouteCatalogSegment> segments;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final List<GeoPoint> all = <GeoPoint>[
      for (final RouteCatalogSegment segment in segments) ...segment.points,
    ];
    if (all.length < 2) return;
    double minLat = all.first.latitude, maxLat = minLat;
    double minLon = all.first.longitude, maxLon = minLon;
    for (final GeoPoint p in all) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }
    // Longitude scaled by the latitude cosine keeps the shape undistorted.
    final double k = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final double width = math.max((maxLon - minLon) * k, 1e-9);
    final double height = math.max(maxLat - minLat, 1e-9);
    final double scale = (size.shortestSide - 6) / math.max(width, height);
    Offset project(GeoPoint p) => Offset(
      3 + ((p.longitude - minLon) * k) * scale,
      size.height - 3 - (p.latitude - minLat) * scale,
    );
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final RouteCatalogSegment segment in segments) {
      if (segment.points.length < 2) continue;
      final Path path = Path()
        ..moveTo(
          project(segment.points.first).dx,
          project(segment.points.first).dy,
        );
      for (final GeoPoint p in segment.points.skip(1)) {
        final Offset o = project(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      !identical(old.segments, segments) || old.color != color;
}
