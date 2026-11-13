import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// CLG-PST-01: the storage primitive `CollectionPublicationLocalDatasource`
/// builds its staged-write/verified-commit-marker/atomic-pointer scheme on
/// top of. A thin interface (not just a direct `FlutterSecureStorage`
/// dependency) so tests can simulate "write A succeeded, write B threw"
/// mid-sequence — not reproducible against
/// `FlutterSecureStorage.setMockInitialValues`, which only seeds an initial
/// snapshot.
///
/// Unlike `RouteRecordingSecureStore` (Route's own precedent for this
/// pattern), this store adds no AES-GCM encryption layer of its own —
/// Collection publish metadata is not materially more sensitive than what
/// `PublishedCollectionDiscoveryLocalDataSource` already stores in plain
/// `FlutterSecureStorage`, so the extra layer Route's raw GPS trail needed
/// would be unjustified complexity here.
abstract interface class CollectionPublicationStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// Every currently-stored key/value pair whose key starts with [prefix]
  /// — used only by moderation-request enumeration (`pendingRequests()`),
  /// which is the one read in this datasource that cannot be a simple
  /// keyed lookup by a known id. Deliberately not backed by a hand-rolled
  /// index key: an index is itself a single point of corruption that could
  /// take every moderation request down with it, defeating the
  /// corrupt-record-isolation requirement this store exists to satisfy.
  Future<Map<String, String>> readAllWithPrefix(String prefix);
}

class SecureCollectionPublicationStore implements CollectionPublicationStore {
  const SecureCollectionPublicationStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAllWithPrefix(String prefix) async {
    final Map<String, String> all = await _storage.readAll();
    return <String, String>{
      for (final MapEntry<String, String> entry in all.entries)
        if (entry.key.startsWith(prefix)) entry.key: entry.value,
    };
  }
}
