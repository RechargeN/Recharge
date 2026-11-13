import '../domain/repositories/create_image_normalizer.dart';
import '../domain/repositories/create_image_picker_port.dart';
import '../domain/repositories/create_media_store.dart';

/// Runtime configuration and kill switch of MEDIA-PICK-01 (MP-OD-05: on).
/// Off brings back the URL/path field alone; drafts are not touched.
class CreateMediaPickerConfig {
  const CreateMediaPickerConfig({
    this.enabled = true,
    this.cameraEnabled = true,
  });

  final bool enabled;

  /// MP-OD-02: "Take photo" next to "Choose photo".
  final bool cameraEnabled;
}

/// What the Create controller needs to turn a picked image into a draft
/// field value: pick, normalize (no metadata), store a private copy.
class CreateMediaPicking {
  const CreateMediaPicking({
    required this.picker,
    required this.normalizer,
    required this.store,
    this.config = const CreateMediaPickerConfig(),
  });

  final CreateImagePickerPort picker;
  final CreateImageNormalizer normalizer;
  final CreateMediaStore store;
  final CreateMediaPickerConfig config;

  /// The local path of the stored copy, null when the person cancelled.
  /// Throws `CreateMediaException` with a MEDIA-PICK-01 §9 code.
  Future<String?> pickInto(String draftKey, CreateImageSource source) async {
    final PickedImage? picked = await picker.pick(source);
    if (picked == null) return null;
    final jpeg = await normalizer.normalize(picked.bytes);
    // A write the OS cut short earlier leaves only a `.tmp`; drop it first.
    await store.removePartialWrites();
    return store.save(draftKey, jpeg);
  }
}
