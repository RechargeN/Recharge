import 'dart:typed_data';

/// Limits of the client copy (MEDIA-PICK-01 §5, MP-OD-03): within the Media
/// processor policy (MEDIA_D1_REAL_TOOLS_AMENDMENT §4.5: JPEG/PNG/WebP,
/// ≤ 1 048 576 B, ≤ 6000 × 6000).
class CreateImageLimits {
  const CreateImageLimits({
    this.maxEdge = 2048,
    this.fallbackEdge = 1600,
    this.maxBytes = 1048576,
    this.qualities = const <int>[85, 75, 65],
    this.timeout = const Duration(seconds: 20),
  });

  final int maxEdge;
  final int fallbackEdge;
  final int maxBytes;
  final List<int> qualities;
  final Duration timeout;
}

/// Turns what a picker returned into one JPEG without any metadata (no EXIF,
/// GPS, XMP or ICC), orientation applied to the pixels, within
/// [CreateImageLimits]. Throws `CreateMediaException` with
/// `media_unsupported`, `media_decode_failed` or `media_too_large`.
abstract interface class CreateImageNormalizer {
  Future<Uint8List> normalize(Uint8List input);
}
