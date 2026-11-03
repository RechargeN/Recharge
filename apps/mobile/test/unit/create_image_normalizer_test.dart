import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:recharge/features/create/data/media/create_image_normalizer_impl.dart';
import 'package:recharge/features/create/domain/repositories/create_image_normalizer.dart';
import 'package:recharge/features/create/domain/repositories/create_image_picker_port.dart';

/// MEDIA-PICK-01 §5 / MP-AC-02: one JPEG within the processor limits, no
/// metadata of the source, orientation in the pixels.
void main() {
  const normalizer = CreateImageNormalizerImpl(runInIsolate: false);

  /// A photo as a phone writes it: EXIF with make, GPS and orientation 6.
  Uint8List phoneJpeg({int width = 600, int height = 200}) {
    final image = img.Image(width: width, height: height);
    // Left half red, right half blue: rotation is visible in the pixels.
    for (final pixel in image) {
      pixel
        ..r = pixel.x < width ~/ 2 ? 255 : 0
        ..g = 0
        ..b = pixel.x < width ~/ 2 ? 0 : 255;
    }
    image.exif.imageIfd['Make'] = img.IfdValueAscii('samsung');
    image.exif.imageIfd['Model'] = img.IfdValueAscii('SM-A346B');
    image.exif.imageIfd.orientation = 6;
    image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
    image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(56, 1);
    image.exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('E');
    image.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(24, 1);
    return img.encodeJpg(image, quality: 95);
  }

  bool hasMarker(Uint8List bytes, List<int> marker) {
    outer:
    for (int i = 0; i + marker.length <= bytes.length; i++) {
      for (int j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  void expectClean(Uint8List out) {
    expect(out.sublist(0, 2), <int>[0xFF, 0xD8], reason: 'JPEG');
    expect(hasMarker(out, ascii.encode('Exif')), isFalse, reason: 'no EXIF');
    expect(hasMarker(out, ascii.encode('samsung')), isFalse);
    expect(hasMarker(out, ascii.encode('SM-A346B')), isFalse);
    expect(hasMarker(out, ascii.encode('http://ns.adobe.com/xap')), isFalse);
    expect(hasMarker(out, ascii.encode('ICC_PROFILE')), isFalse);
    expect(img.decodeJpg(out)!.exif.isEmpty, isTrue);
  }

  test('the source fixture really carries EXIF and GPS', () {
    final source = phoneJpeg();
    expect(hasMarker(source, ascii.encode('Exif')), isTrue);
    expect(hasMarker(source, ascii.encode('SM-A346B')), isTrue);
    expect(img.decodeJpg(source)!.exif.gpsIfd.isEmpty, isFalse);
  });

  test('a phone JPEG loses all metadata and keeps its orientation', () async {
    final out = await normalizer.normalize(phoneJpeg());
    expectClean(out);
    final decoded = img.decodeJpg(out)!;
    // Orientation 6 = rotate 90° clockwise: 600 × 200 becomes 200 × 600 and
    // the red left half becomes the top half.
    expect((decoded.width, decoded.height), (200, 600));
    expect(decoded.getPixel(100, 50).r, greaterThan(200));
    expect(decoded.getPixel(100, 550).b, greaterThan(200));
  });

  test('a large photo is scaled to 2048 px and fits 1 MiB', () async {
    final big = img.Image(width: 4000, height: 3000);
    for (final pixel in big) {
      // Gradients with fine texture, roughly like a photo (12 MP, 98 %).
      pixel
        ..r = pixel.x * 255 ~/ 4000
        ..g = pixel.y * 255 ~/ 3000
        ..b = ((pixel.x ^ pixel.y) & 31) * 8;
    }
    final out = await normalizer.normalize(img.encodeJpg(big, quality: 98));
    expectClean(out);
    expect(out.length, lessThanOrEqualTo(1048576));
    final decoded = img.decodeJpg(out)!;
    expect(
      decoded.width == 2048 || decoded.width == 1600,
      isTrue,
      reason: '${decoded.width}',
    );
    expect(decoded.height, decoded.width * 3 ~/ 4);
  });

  test('PNG transparency is flattened on white', () async {
    final png = img.Image(width: 40, height: 40, numChannels: 4);
    img.fill(png, color: img.ColorRgba8(0, 0, 0, 0));
    final out = await normalizer.normalize(img.encodePng(png));
    expectClean(out);
    final pixel = img.decodeJpg(out)!.getPixel(20, 20);
    expect((pixel.r, pixel.g, pixel.b), (255, 255, 255));
  });

  test('refusals carry their codes', () async {
    Future<String> code(Uint8List input, [CreateImageNormalizer? with_]) async {
      try {
        await (with_ ?? normalizer).normalize(input);
      } on CreateMediaException catch (error) {
        return error.code;
      }
      return 'accepted';
    }

    final animated = img.Image(width: 8, height: 8)
      ..addFrame(img.Image(width: 8, height: 8));
    expect(await code(img.encodeGif(animated)), 'media_unsupported');
    expect(await code(Uint8List(0)), 'media_decode_failed');
    expect(
      await code(Uint8List.fromList(utf8.encode('<gpx>not an image</gpx>'))),
      'media_unsupported',
    );
    final truncated = phoneJpeg();
    expect(
      await code(Uint8List.sublistView(truncated, 0, truncated.length ~/ 3)),
      anyOf('media_decode_failed', 'accepted'),
      reason: 'a cut JPEG is refused or still decodes, never crashes',
    );
    const tiny = CreateImageNormalizerImpl(
      runInIsolate: false,
      limits: CreateImageLimits(maxBytes: 200),
    );
    expect(await code(phoneJpeg(), tiny), 'media_too_large');
  });

  test('the app path runs in a separate isolate', () async {
    final out = await const CreateImageNormalizerImpl().normalize(phoneJpeg());
    expectClean(out);
  });
}
