enum BackendBindingMode { localOnly, testBackend, disabled }

final class BackendBindingManifest {
  BackendBindingManifest({
    required this.revision,
    required Map<String, BackendBindingMode> bindings,
  }) : bindings = Map<String, BackendBindingMode>.unmodifiable(bindings) {
    if (revision < 1) {
      throw ArgumentError.value(revision, 'revision', 'must be positive');
    }
  }

  final int revision;
  final Map<String, BackendBindingMode> bindings;

  BackendBindingMode modeFor(String capabilityId) =>
      bindings[capabilityId] ?? BackendBindingMode.disabled;

  BackendBindingManifest rollbackTo(BackendBindingManifest previous) {
    if (previous.revision >= revision) {
      throw StateError('Rollback target must be an older manifest revision');
    }
    return previous;
  }

  static final BackendBindingManifest localSafeDefault = BackendBindingManifest(
    revision: 1,
    bindings: <String, BackendBindingMode>{},
  );
}
