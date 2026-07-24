import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> createCustomMarkerFromUrl(
  String imageUrl, {
  int size = 120,
  Color borderColor = Colors.white,
  double borderWidth = 8,
}) async {
  try {
    final Completer<ImageInfo> completer = Completer<ImageInfo>();
    final NetworkImage image = NetworkImage(imageUrl);
    final ImageStream stream = image.resolve(ImageConfiguration.empty);
    
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      if (!completer.isCompleted) completer.complete(info);
    }));

    final ImageInfo imageInfo = await completer.future;
    final ui.Image rawImage = imageInfo.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = size / 2;

    // Draw background circle (border)
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    // Draw the image clipped to a circle
    final Path clipPath = Path()
      ..addOval(Rect.fromLTWH(
        borderWidth,
        borderWidth,
        size - borderWidth * 2,
        size - borderWidth * 2,
      ));
    canvas.clipPath(clipPath);

    final Rect dstRect = Rect.fromLTWH(
      borderWidth,
      borderWidth,
      size - borderWidth * 2,
      size - borderWidth * 2,
    );
    
    // Scale image to fit the circle
    final double scale = size / (rawImage.width > rawImage.height ? rawImage.height : rawImage.width);
    final double scaledWidth = rawImage.width * scale;
    final double scaledHeight = rawImage.height * scale;
    final Rect srcRect = Rect.fromLTWH(
      (rawImage.width - size / scale) / 2,
      (rawImage.height - size / scale) / 2,
      size / scale,
      size / scale,
    );

    canvas.drawImageRect(rawImage, srcRect, dstRect, Paint());

    final ui.Image finalImage = await recorder.endRecording().toImage(size, size);
    final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  } catch (e) {
    if (kDebugMode) print('Error creating custom marker: $e');
    return BitmapDescriptor.defaultMarker;
  }
}
