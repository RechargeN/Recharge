import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../domain/repositories/create_image_normalizer.dart';
import '../../domain/repositories/create_image_picker_port.dart';

/// MEDIA-PICK-01 §5 in pure Dart, off the UI isolate.
///
/// The output is a new image built from the pixels only, so it carries no
/// EXIF, GPS, XMP, ICC or text data of the source, whatever the decoder kept.
/// Orientation is applied to the pixels first; transparency is flattened on
/// white (MP-OD-07).
class CreateImageNormalizerImpl implements CreateImageNormalizer {
  const CreateImageNormalizerImpl({
    this.limits = const CreateImageLimits(),
    this.runInIsolate = true,
  });

  final CreateImageLimits limits;

  /// Tests may run inline; the app always uses a separate isolate.
  final bool runInIsolate;

  @override
  Future<Uint8List> normalize(Uint8List input) async {
    final limits = this.limits;
    final Future<_Result> work = runInIsolate
        ? Isolate.run(() => _normalize(input, limits))
        : Future<_Result>.sync(() => _normalize(input, limits));
    final _Result result;
    try {
      result = await work.timeout(limits.timeout);
    } on TimeoutException {
      throw const CreateMediaException('media_decode_failed');
    }
    final error = result.error;
    if (error != null) throw CreateMediaException(error);
    return result.bytes!;
  }
}

/// Values an isolate can return: the JPEG or a refusal code.
class _Result {
  const _Result.ok(Uint8List this.bytes) : error = null;
  const _Result.refused(String this.error) : bytes = null;

  final Uint8List? bytes;
  final String? error;
}

/// Above this the decode alone would need hundreds of MB; the platform
/// picker already downsizes, so a larger input is refused, not decoded.
const int _maxInputPixels = 40000000;

_Result _normalize(Uint8List input, CreateImageLimits limits) {
  if (input.isEmpty) return const _Result.refused('media_decode_failed');
  final img.Decoder? decoder = img.findDecoderForData(input);
  if (decoder == null ||
      decoder is! img.JpegDecoder &&
          decoder is! img.PngDecoder &&
          decoder is! img.WebPDecoder &&
          decoder is! img.GifDecoder &&
          decoder is! img.BmpDecoder) {
    return const _Result.refused('media_unsupported');
  }
  final img.Image? decoded;
  try {
    final info = decoder.startDecode(input);
    if (info == null) return const _Result.refused('media_decode_failed');
    if (info.numFrames > 1) return const _Result.refused('media_unsupported');
    if (info.width * info.height > _maxInputPixels) {
      return const _Result.refused('media_too_large');
    }
    decoded = decoder.decode(input, frame: 0);
  } catch (_) {
    return const _Result.refused('media_decode_failed');
  }
  if (decoded == null || decoded.width < 1 || decoded.height < 1) {
    return const _Result.refused('media_decode_failed');
  }
  if (decoded.numFrames > 1) return const _Result.refused('media_unsupported');
  final upright = img.bakeOrientation(decoded);
  for (final int edge in <int>[limits.maxEdge, limits.fallbackEdge]) {
    final img.Image clean = _cleanCopy(upright, edge);
    for (final int quality in limits.qualities) {
      final Uint8List jpeg = img.encodeJpg(clean, quality: quality);
      if (jpeg.length <= limits.maxBytes) return _Result.ok(jpeg);
    }
  }
  return const _Result.refused('media_too_large');
}

/// A new RGB image of at most [edge] on the long side, composited on white:
/// only pixels are copied, never the source's metadata.
img.Image _cleanCopy(img.Image source, int edge) {
  final int longSide = source.width > source.height
      ? source.width
      : source.height;
  final img.Image scaled = longSide <= edge
      ? source
      : img.copyResize(
          source,
          width: source.width >= source.height ? edge : null,
          height: source.height > source.width ? edge : null,
          interpolation: img.Interpolation.average,
        );
  final img.Image canvas = img.Image(
    width: scaled.width,
    height: scaled.height,
    numChannels: 3,
  );
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, scaled);
  return canvas;
}
