/// The Catalog snapshot the current listing was read from. Feed, Search and
/// Map share one listing; Details asks for the same object against this
/// snapshot, so a different revision is reported, never silently shown.
final class CatalogSnapshotSession {
  String? _snapshotToken;
  Map<String, Object?>? _query;

  String? get snapshotToken => _snapshotToken;

  Map<String, Object?>? get query => _query;

  void remember(String snapshotToken, Map<String, Object?> query) {
    _snapshotToken = snapshotToken;
    _query = Map<String, Object?>.unmodifiable(query);
  }

  void forget() {
    _snapshotToken = null;
    _query = null;
  }
}
