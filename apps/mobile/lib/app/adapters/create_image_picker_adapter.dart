import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/create/domain/repositories/create_image_normalizer.dart';
import '../../features/create/domain/repositories/create_image_picker_port.dart';

/// MEDIA-PICK-01 §7: the system Photo Picker on Android 13+ (no media-read
/// permission), the document picker on older Android, PHPicker on iOS, and
/// the system camera app. The platform downsizes to [CreateImageLimits.maxEdge]
/// and turns HEIC into JPEG; the path and name of the platform copy stay
/// here, only bytes and type leave.
class CreateImagePickerAdapter implements CreateImagePickerPort {
  CreateImagePickerAdapter({
    ImagePicker? picker,
    CreateImageLimits limits = const CreateImageLimits(),
  }) : _picker = picker ?? ImagePicker(),
       _limits = limits;

  final ImagePicker _picker;
  final CreateImageLimits _limits;

  @override
  Future<PickedImage?> pick(CreateImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: switch (source) {
          CreateImageSource.gallery => ImageSource.gallery,
          CreateImageSource.camera => ImageSource.camera,
        },
        maxWidth: _limits.maxEdge.toDouble(),
        maxHeight: _limits.maxEdge.toDouble(),
        imageQuality: _limits.qualities.first,
        // Not the whole library (iOS); metadata is dropped later anyway.
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      final String code = error.code.toLowerCase();
      throw CreateMediaException(
        code.contains('access_denied') || code.contains('permission')
            ? 'media_permission_denied'
            : 'media_unsupported',
      );
    }
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedImage(bytes: bytes, mediaType: file.mimeType);
  }
}
