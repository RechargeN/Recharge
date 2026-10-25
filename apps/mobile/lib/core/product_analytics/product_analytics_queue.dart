/// One allowlisted envelope waiting for delivery. It holds no account,
/// Session or device reference; the namespace it is stored under is a hash
/// that never leaves the device.
class ProductAnalyticsQueuedEvent {
  const ProductAnalyticsQueuedEvent({
    required this.envelope,
    required this.enqueuedAtUtc,
    required this.bytes,
    this.attempts = 0,
  });

  final Map<String, Object?> envelope;
  final DateTime enqueuedAtUtc;
  final int bytes;
  final int attempts;

  String get eventId => envelope['eventId']! as String;
  String get policyRevision => envelope['policyRevision']! as String;

  ProductAnalyticsQueuedEvent withAttempt() => ProductAnalyticsQueuedEvent(
    envelope: envelope,
    enqueuedAtUtc: enqueuedAtUtc,
    bytes: bytes,
    attempts: attempts + 1,
  );
}

/// Storage of the per-account queues. Only already validated envelopes are
/// written; a store may fail, and the recorder treats that as a drop.
abstract interface class ProductAnalyticsQueueStore {
  List<ProductAnalyticsQueuedEvent> read(String namespace);
  void write(String namespace, List<ProductAnalyticsQueuedEvent> events);
  void delete(String namespace);
  List<String> namespaces();
}

/// In-process store. It outlives a recorder instance, which stands in for an
/// app restart in tests; the persistent (encrypted, file-backed) store is a
/// disabled path until BCK21-OD-09 is decided (PA-B09).
class InMemoryProductAnalyticsQueueStore implements ProductAnalyticsQueueStore {
  final Map<String, List<ProductAnalyticsQueuedEvent>> _queues =
      <String, List<ProductAnalyticsQueuedEvent>>{};

  @override
  List<ProductAnalyticsQueuedEvent> read(String namespace) =>
      List<ProductAnalyticsQueuedEvent>.of(
        _queues[namespace] ?? const <ProductAnalyticsQueuedEvent>[],
      );

  @override
  void write(String namespace, List<ProductAnalyticsQueuedEvent> events) {
    if (events.isEmpty) {
      _queues.remove(namespace);
    } else {
      _queues[namespace] = List<ProductAnalyticsQueuedEvent>.unmodifiable(
        events,
      );
    }
  }

  @override
  void delete(String namespace) => _queues.remove(namespace);

  @override
  List<String> namespaces() => List<String>.of(_queues.keys);
}
