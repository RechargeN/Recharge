import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> createCustomMarkerFromUrl(
  String imageUrl, {
  int size = 48, // Much smaller, standard mobile pin size
  Color borderColor = Colors.white,
  double borderWidth = 3,
}) async {
  try {
    final Completer<ImageInfo> completer = Completer<ImageInfo>();
    final NetworkImage image = NetworkImage(imageUrl);
    final ImageStream stream = image.resolve(ImageConfiguration.empty);

    stream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (!completer.isCompleted) completer.complete(info);
      }),
    );

    final ImageInfo imageInfo = await completer.future;
    final ui.Image rawImage = imageInfo.image;

    // We use 3x scaling for high-DPI clarity but keep the logical size small
    const double pixelRatio = 3.0;
    final int renderSize = (size * pixelRatio).toInt();
    final double renderBorderWidth = borderWidth * pixelRatio;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = renderSize / 2.0;

    // 1. Drop shadow (Elegant & Soft)
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6 * pixelRatio);
    canvas.drawCircle(
      Offset(radius, radius + 2 * pixelRatio),
      radius - 4 * pixelRatio,
      shadowPaint,
    );

    // 2. White Border Circle
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);

    // 3. Image Clip
    final Path clipPath = Path()
      ..addOval(
        Rect.fromLTWH(
          renderBorderWidth,
          renderBorderWidth,
          renderSize - renderBorderWidth * 2,
          renderSize - renderBorderWidth * 2,
        ),
      );

    canvas.save();
    canvas.clipPath(clipPath);

    final Rect dstRect = Rect.fromLTWH(
      renderBorderWidth,
      renderBorderWidth,
      renderSize - renderBorderWidth * 2,
      renderSize - renderBorderWidth * 2,
    );

    // Smooth image fitting
    final double imgScale =
        renderSize /
        (rawImage.width > rawImage.height ? rawImage.height : rawImage.width);
    final Rect srcRect = Rect.fromLTWH(
      (rawImage.width - renderSize / imgScale) / 2,
      (rawImage.height - renderSize / imgScale) / 2,
      renderSize / imgScale,
      renderSize / imgScale,
    );

    canvas.drawImageRect(
      rawImage,
      srcRect,
      dstRect,
      Paint()..filterQuality = ui.FilterQuality.high,
    );
    canvas.restore();

    final ui.Image finalImage = await recorder.endRecording().toImage(
      renderSize,
      renderSize,
    );
    final ByteData? byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  } catch (e) {
    if (kDebugMode) print('Error creating HD marker: $e');
    return BitmapDescriptor.defaultMarker;
  }
}
