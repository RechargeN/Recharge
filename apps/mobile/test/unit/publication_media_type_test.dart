import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/publication_media_type.dart';

void main() {
  test(
    'existing filename claims are case-insensitive; unknown or URL suffix remains undecided',
    () {
      for (final entry in {
        'C:/photos/UPPER.PNG': 'image/png',
        'photo.jpg': 'image/jpeg',
        'photo.JPEG': 'image/jpeg',
        'photo.webp': 'image/webp',
        'unknown.bin': 'application/octet-stream',
        'photo.png?version=1': 'application/octet-stream',
      }.entries) {
        expect(declaredPublicationMediaType(entry.key), entry.value);
      }
    },
  );
}
