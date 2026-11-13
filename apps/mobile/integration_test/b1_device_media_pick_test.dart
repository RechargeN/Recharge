import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recharge/app/adapters/create_image_picker_adapter.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/create_media_picking.dart';
import 'package:recharge/features/create/data/media/create_image_normalizer_impl.dart';
import 'package:recharge/features/create/data/media/file_create_media_store.dart';
import 'package:recharge/features/create/domain/repositories/create_image_picker_port.dart';

import '../test/backend_local/support/stand_environment.dart';

/// B1-device, operator-assisted: MEDIA-PICK-01 on the phone (MP-AC-02/04/10).
///
/// The gate pushed a synthetic JPEG with EXIF, GPS and orientation 6 into the
/// phone's Pictures; the operator picks it in the real system Photo Picker,
/// then takes a photo with the system camera. Each result is the private
/// copy the app keeps: a JPEG within the limits, without any EXIF/GPS, under
/// the app's support folder. The gate checks the manifest asks for no
/// media-read permission. Not mocked: image_picker, the system pickers, the
/// camera app, the normalizer and the file store.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'B1-device photo picker and camera',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final Directory support = await getApplicationSupportDirectory();
      final picking = CreateMediaPicking(
        picker: CreateImagePickerAdapter(),
        normalizer: const CreateImageNormalizerImpl(),
        store: FileCreateMediaStore(
          supportDirectory: () async => support,
          idGenerator: UuidV4IdGenerator(),
        ),
      );
      final List<String> kept = <String>[];
      addTearDown(() async {
        for (final path in kept) {
          await picking.store.remove(path);
        }
      });

      Future<Map<String, Object?>> check(String path) async {
        kept.add(path);
        expect(picking.store.owns(path), isTrue);
        expect(File(path).absolute.path, startsWith(support.absolute.path));
        final Uint8List bytes = await File(path).readAsBytes();
        expect(bytes.length, lessThanOrEqualTo(1048576));
        expect(bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
        final String latin = latin1.decode(bytes, allowInvalid: true);
        final img.Image decoded = img.decodeJpg(bytes)!;
        final bool clean =
            !latin.contains('Exif') &&
            !latin.contains('RechargeB1') &&
            decoded.exif.isEmpty;
        expect(clean, isTrue, reason: 'no EXIF/GPS in the kept copy');
        expect(decoded.width, lessThanOrEqualTo(2048));
        expect(decoded.height, lessThanOrEqualTo(2048));
        return <String, Object?>{
          'bytes': bytes.length,
          'width': decoded.width,
          'height': decoded.height,
          'sha256': sha256.convert(bytes).toString(),
          'metadataFree': clean,
        };
      }

      await _arrive('gallery');
      final String? fromGallery = await picking.pickInto(
        'b1-device-media',
        CreateImageSource.gallery,
      );
      expect(fromGallery, isNotNull, reason: 'the operator picked the photo');
      final Map<String, Object?> gallery = await check(fromGallery!);
      // The pushed fixture is 3200 × 2400 with orientation 6: upright portrait.
      expect(gallery['height'], greaterThan(gallery['width']! as int));
      await _arrive('gallery-picked', gallery);

      await _arrive('camera');
      final String? fromCamera = await picking.pickInto(
        'b1-device-media',
        CreateImageSource.camera,
      );
      expect(fromCamera, isNotNull, reason: 'the operator took a photo');
      await _arrive('done', <String, Object?>{
        'gallery': gallery,
        'camera': await check(fromCamera!),
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _arrive(
  String name, [
  Map<String, Object?> payload = const <String, Object?>{},
]) async {
  final http.Response response = await http.put(
    standBridgeBase.replace(
      path: '/rendezvous',
      queryParameters: <String, String>{'who': 'device', 'name': name},
    ),
    headers: const <String, String>{'content-type': 'application/json'},
    body: jsonEncode(payload),
  );
  expect(response.statusCode, 204, reason: 'bridge refused $name');
}
