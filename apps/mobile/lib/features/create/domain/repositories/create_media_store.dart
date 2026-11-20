import 'dart:typed_data';

/// MEDIA-PICK-02: the store key of [draftId] of [ownerId]. The store keeps
/// each account's copies in its own folder and never writes the account id
/// into a path.
String createMediaDraftKey(String ownerId, String draftId) =>
    'account/$ownerId/$draftId';

/// Private copies of draft images (MEDIA-PICK-01 §6, MEDIA-PICK-02). A stored
/// copy is a local path the existing draft fields and upload adapters already
/// accept. Copies of different accounts live in separate folders.
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

  /// MEDIA-PICK-02: called only after the owner's draft was saved with the
  /// server asset in place of [path]. The release is journaled before the
  /// file is deleted, so an interrupted delete is finished by
  /// [sweepReleased]; a copy of another store or path is ignored.
  Future<void> release({required String ownerId, required String path});

  /// MEDIA-PICK-02: finishes interrupted releases of [ownerId] only. A
  /// journaled copy that [referenced] still needs (the draft points at it
  /// again) is kept and leaves the journal; nothing else is touched.
  Future<int> sweepReleased({
    required String ownerId,
    required bool Function(String path) referenced,
  });
}
