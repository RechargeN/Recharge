import 'dart:typed_data';

/// Private copies of draft images (MEDIA-PICK-01 §6). A stored copy is a
/// local path the existing draft fields and upload adapters already accept.
abstract interface class CreateMediaStore {
  /// Writes a normalized copy for [draftKey]; returns its local path. Throws
  /// `CreateMediaException('media_storage_full')` past the quota.
  Future<String> save(String draftKey, Uint8List jpeg);

  /// Deletes one copy if [path] is a copy of this store; other values (URLs,
  /// paths typed in debug) are left alone.
  Future<void> remove(String path);

  /// Deletes temporary files a write left behind when the app was ended
  /// mid-write; finished copies are never touched.
  Future<int> removePartialWrites();

  /// Whether [path] is a copy written by this store.
  bool owns(String path);
}
