import 'dart:typed_data';

import '../../../../shared/primitives/errors/coded_refusal.dart';

/// Where the person takes an image from (MEDIA-PICK-01 §2, MP-OD-02).
enum CreateImageSource { gallery, camera }

/// What a platform picker returned: bytes and the reported type only. The
/// platform file reference, path and file name never leave the adapter
/// (PLATFORM_FOUNDATION_SPEC picker rule; MEDIA-PICK-01 §5).
class PickedImage {
  PickedImage({required this.bytes, this.mediaType});

  final Uint8List bytes;
  final String? mediaType;
}

abstract interface class CreateImagePickerPort {
  /// Null when the person closed the picker.
  Future<PickedImage?> pick(CreateImageSource source);
}

/// A refusal shown to the person by code (MEDIA-PICK-01 §9), worded by the
/// L4 catalog (`UserMessageFamily.clientLocal`).
class CreateMediaException implements CodedRefusal {
  const CreateMediaException(this.code);

  @override
  final String code;

  @override
  UserMessageFamily get messageFamily => UserMessageFamily.clientLocal;

  @override
  String toString() => 'CreateMediaException($code)';
}
