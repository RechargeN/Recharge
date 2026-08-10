import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<Map<int, BitmapDescriptor>> buildScenarioIntakeMarkerIcons({
  required Color color,
  required double devicePixelRatio,
  int count = 20,
}) async {
  final ratio = devicePixelRatio.clamp(1, 3).toDouble();
  final icons = <int, BitmapDescriptor>{};
  for (var order = 1; order <= count; order++) {
    final bytes = await _markerBytes(order: order, color: color, ratio: ratio);
    icons[order] = BitmapDescriptor.bytes(
      bytes,
      imagePixelRatio: ratio,
      width: 42,
      height: 50,
      bitmapScaling: MapBitmapScaling.none,
    );
  }
  return Map<int, BitmapDescriptor>.unmodifiable(icons);
}

Future<Uint8List> _markerBytes({
  required int order,
  required Color color,
  required double ratio,
}) async {
  const logicalWidth = 42.0;
  const logicalHeight = 50.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(ratio);
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  final outline = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  final path = Path()
    ..moveTo(21, 49)
    ..cubicTo(18, 42, 7, 34, 7, 21)
    ..arcToPoint(
      const Offset(35, 21),
      radius: const Radius.circular(14),
      clockwise: true,
    )
    ..cubicTo(35, 34, 24, 42, 21, 49)
    ..close();
  canvas
    ..drawShadow(path, const Color(0x55000000), 3, false)
    ..drawPath(path, paint)
    ..drawPath(path, outline);
  final textPainter = TextPainter(
    text: TextSpan(
      text: '$order',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    Offset(21 - textPainter.width / 2, 20 - textPainter.height / 2),
  );
  final image = await recorder.endRecording().toImage(
    (logicalWidth * ratio).round(),
    (logicalHeight * ratio).round(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('Could not render Scenario selection marker.');
  }
  return byteData.buffer.asUint8List();
}
