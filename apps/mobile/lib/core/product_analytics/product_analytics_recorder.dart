import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'product_analytics_contract.dart';
import 'product_analytics_queue.dart';

/// The server-provided collection policy as the client last saw it. It is
/// planning input only; the server checks policy and consent again (BCK-21
/// §11). The client never derives consent from local state.
class ProductAnalyticsClientPolicy {
  const ProductAnalyticsClientPolicy({
    required this.policyRevision,
    required this.eventNames,
    required this.collectionAllowed,
    required this.queueMaxAge,
  });

  final String policyRevision;
  final Set<String> eventNames;

  /// Server answer for the bound account: policy active and, where the policy
  /// requires it, consent granted.
  final bool collectionAllowed;
  final Duration queueMaxAge;
}

abstract interface class ProductAnalyticsPolicySource {
  ProductAnalyticsClientPolicy? current();
}

/// Production default: no accepted policy exists (PA-B01…B03), so nothing is
/// ever queued.
class NoProductAnalyticsPolicy implements ProductAnalyticsPolicySource {
  const NoProductAnalyticsPolicy();

  @override
  ProductAnalyticsClientPolicy? current() => null;
}

enum ProductAnalyticsDisposition {
  accepted,
  duplicate,
  rejectedSchema,
  rejectedPolicy,
  rejectedLate,
  conflict,
}

/// What a sink answered. A thrown error or a timeout is an unknown outcome and
/// never counts as delivered.
sealed class ProductAnalyticsSendResult {
  const ProductAnalyticsSendResult();
}

final class ProductAnalyticsDelivered extends ProductAnalyticsSendResult {
  const ProductAnalyticsDelivered(this.dispositions);

  final Map<String, ProductAnalyticsDisposition> dispositions;
}

/// The whole batch was refused (no Session, no consent, collection off, …).
final class ProductAnalyticsRefused extends ProductAnalyticsSendResult {
  const ProductAnalyticsRefused(this.code);

  final String code;
}

abstract interface class ProductAnalyticsSink {
  Future<ProductAnalyticsSendResult> send(Map<String, Object?> batch);
}

/// Production default: there is no destination and no network path (PA-B04).
class DisabledProductAnalyticsSink implements ProductAnalyticsSink {
  const DisabledProductAnalyticsSink();

  @override
  Future<ProductAnalyticsSendResult> send(Map<String, Object?> batch) =>
      Future<ProductAnalyticsSendResult>.value(
        const ProductAnalyticsRefused('collection_disabled'),
      );
}

/// Why an event left the client without being delivered. Counts only: no
/// field name, value or ID is ever kept.
enum ProductAnalyticsDropReason {
  noPolicy,
  noAccount,
  notAllowed,
  consentWithdrawn,
  invalid,
  oversized,
  overflow,
  expired,
  attemptsExhausted,
  rejected,
  storeFailure,
  accountChanged,
}

/// L3 client recorder (amendment §6, §8). `record` is synchronous, never
/// throws and never waits for delivery; `flush` never throws either. Queues
/// are kept per account under a hash namespace, and binding another account
/// (or none) deletes every other queue before anything is sent.
class ProductAnalyticsRecorder {
  ProductAnalyticsRecorder({
    required ProductAnalyticsPolicySource policy,
    required ProductAnalyticsSink sink,
    required ProductAnalyticsQueueStore store,
    DateTime Function()? clock,
    String Function()? newEventId,
    Duration sendTimeout = const Duration(
      seconds: ProductAnalyticsLimits.sendTimeoutSeconds,
    ),
  }) : _policy = policy,
       _sink = sink,
       _store = store,
       _clock = clock ?? DateTime.now,
       _newEventId = newEventId ?? const Uuid().v4,
       _sendTimeout = sendTimeout;

  /// Production composition: no policy, no destination, nothing collected.
  factory ProductAnalyticsRecorder.disabled() => ProductAnalyticsRecorder(
    policy: const NoProductAnalyticsPolicy(),
    sink: const DisabledProductAnalyticsSink(),
    store: InMemoryProductAnalyticsQueueStore(),
  );

  final ProductAnalyticsPolicySource _policy;
  final ProductAnalyticsSink _sink;
  final ProductAnalyticsQueueStore _store;
  final DateTime Function() _clock;
  final String Function() _newEventId;
  final Duration _sendTimeout;

  final Map<ProductAnalyticsDropReason, int> _drops =
      <ProductAnalyticsDropReason, int>{};
  String? _namespace;
  bool _flushing = false;

  /// Privacy-safe diagnostics: drop counts by reason.
  Map<ProductAnalyticsDropReason, int> get drops =>
      Map<ProductAnalyticsDropReason, int>.unmodifiable(_drops);

  /// Binds the signed-in account, or none. Every queue of another account is
  /// deleted at once, so a later send can never carry it.
  void bindAccount(String? accountId) {
    final String? next = accountId == null || accountId.isEmpty
        ? null
        : sha256.convert(utf8.encode('pa-l3:$accountId')).toString();
    _namespace = next;
    try {
      for (final String namespace in _store.namespaces()) {
        if (namespace != next) {
          _drop(
            ProductAnalyticsDropReason.accountChanged,
            _store.read(namespace).length,
          );
          _store.delete(namespace);
        }
      }
    } on Object {
      _drop(ProductAnalyticsDropReason.storeFailure);
    }
  }

  void record(ProductAnalyticsEvent event) {
    try {
      final ProductAnalyticsClientPolicy? policy = _policy.current();
      if (policy == null) return _drop(ProductAnalyticsDropReason.noPolicy);
      final String? namespace = _namespace;
      if (namespace == null) return _drop(ProductAnalyticsDropReason.noAccount);
      if (!policy.collectionAllowed) {
        _purge(namespace, ProductAnalyticsDropReason.consentWithdrawn);
        return _drop(ProductAnalyticsDropReason.consentWithdrawn);
      }
      if (!policy.eventNames.contains(event.eventName)) {
        return _drop(ProductAnalyticsDropReason.notAllowed);
      }
      final DateTime now = _clock().toUtc();
      final Map<String, Object?> envelope = <String, Object?>{
        'eventId': _newEventId(),
        'eventName': event.eventName,
        'eventVersion': event.eventVersion,
        'occurredAtUtc': DateTime.utc(
          now.year,
          now.month,
          now.day,
          now.hour,
        ).toIso8601String(),
        'policyRevision': policy.policyRevision,
        'fields': Map<String, String>.of(event.fields),
      };
      final int bytes = productAnalyticsJsonBytes(envelope);
      if (bytes > ProductAnalyticsLimits.eventMaxBytes) {
        return _drop(ProductAnalyticsDropReason.oversized);
      }
      if (!isValidProductAnalyticsEnvelope(envelope)) {
        return _drop(ProductAnalyticsDropReason.invalid);
      }
      final List<ProductAnalyticsQueuedEvent> queue = _fresh(
        namespace,
        policy,
        now,
      );
      final int queuedBytes = queue.fold<int>(
        0,
        (int sum, ProductAnalyticsQueuedEvent item) => sum + item.bytes,
      );
      if (queue.length >= ProductAnalyticsLimits.queueMaxEvents ||
          queuedBytes + bytes > ProductAnalyticsLimits.queueMaxBytes) {
        return _drop(ProductAnalyticsDropReason.overflow);
      }
      _store.write(namespace, <ProductAnalyticsQueuedEvent>[
        ...queue,
        ProductAnalyticsQueuedEvent(
          envelope: envelope,
          enqueuedAtUtc: now,
          bytes: bytes,
        ),
      ]);
    } on Object {
      _drop(ProductAnalyticsDropReason.storeFailure);
    }
  }

  /// Sends at most one bounded batch of the bound account. Accepted and
  /// duplicate events leave the queue; rejected ones are dropped; an unknown
  /// outcome keeps them with one more attempt. The answer is applied only if
  /// the same account is still bound and the policy still allows collection.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _flushOnce();
    } on Object {
      _drop(ProductAnalyticsDropReason.storeFailure);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flushOnce() async {
    final String? namespace = _namespace;
    if (namespace == null) return;
    final ProductAnalyticsClientPolicy? policy = _policy.current();
    if (policy == null || !policy.collectionAllowed) {
      return _purge(
        namespace,
        policy == null
            ? ProductAnalyticsDropReason.noPolicy
            : ProductAnalyticsDropReason.consentWithdrawn,
      );
    }
    final DateTime now = _clock().toUtc();
    final List<ProductAnalyticsQueuedEvent> queue = _fresh(
      namespace,
      policy,
      now,
    );
    final List<ProductAnalyticsQueuedEvent> current = queue
        .where(
          (ProductAnalyticsQueuedEvent item) =>
              item.policyRevision == policy.policyRevision &&
              policy.eventNames.contains(item.envelope['eventName']),
        )
        .toList();
    if (current.length != queue.length) {
      _drop(
        ProductAnalyticsDropReason.notAllowed,
        queue.length - current.length,
      );
      _store.write(namespace, current);
    }
    final List<ProductAnalyticsQueuedEvent> batch =
        <ProductAnalyticsQueuedEvent>[];
    for (final ProductAnalyticsQueuedEvent item in current) {
      final List<ProductAnalyticsQueuedEvent> candidate =
          <ProductAnalyticsQueuedEvent>[...batch, item];
      if (candidate.length > ProductAnalyticsLimits.batchMaxEvents ||
          !isValidProductAnalyticsBatch(_batch(candidate))) {
        break;
      }
      batch.add(item);
    }
    if (batch.isEmpty) return;
    ProductAnalyticsSendResult? result;
    try {
      result = await _sink.send(_batch(batch)).timeout(_sendTimeout);
    } on Object {
      result = null;
    }
    // The world may have changed while the batch was in flight.
    final ProductAnalyticsClientPolicy? after = _policy.current();
    if (_namespace != namespace) return;
    if (after == null || !after.collectionAllowed) {
      return _purge(namespace, ProductAnalyticsDropReason.consentWithdrawn);
    }
    final Set<String> sent = batch
        .map((ProductAnalyticsQueuedEvent item) => item.eventId)
        .toSet();
    final List<ProductAnalyticsQueuedEvent> next =
        <ProductAnalyticsQueuedEvent>[];
    for (final ProductAnalyticsQueuedEvent item in _store.read(namespace)) {
      if (!sent.contains(item.eventId)) {
        next.add(item);
        continue;
      }
      final ProductAnalyticsDisposition? disposition = switch (result) {
        ProductAnalyticsDelivered(:final dispositions) =>
          dispositions[item.eventId],
        ProductAnalyticsRefused() => ProductAnalyticsDisposition.rejectedPolicy,
        null => null,
      };
      switch (disposition) {
        case ProductAnalyticsDisposition.accepted:
        case ProductAnalyticsDisposition.duplicate:
          break;
        case ProductAnalyticsDisposition.rejectedSchema:
        case ProductAnalyticsDisposition.rejectedPolicy:
        case ProductAnalyticsDisposition.rejectedLate:
        case ProductAnalyticsDisposition.conflict:
          _drop(ProductAnalyticsDropReason.rejected);
        case null:
          final ProductAnalyticsQueuedEvent retried = item.withAttempt();
          if (retried.attempts >= ProductAnalyticsLimits.maxAttempts) {
            _drop(ProductAnalyticsDropReason.attemptsExhausted);
          } else {
            next.add(retried);
          }
      }
    }
    _store.write(namespace, next);
  }

  Map<String, Object?> _batch(List<ProductAnalyticsQueuedEvent> items) =>
      <String, Object?>{
        'schemaVersion': 1,
        'events': <Map<String, Object?>>[
          for (final ProductAnalyticsQueuedEvent item in items) item.envelope,
        ],
      };

  /// The queue without events older than the policy allows; expired ones are
  /// deleted from the store.
  List<ProductAnalyticsQueuedEvent> _fresh(
    String namespace,
    ProductAnalyticsClientPolicy policy,
    DateTime now,
  ) {
    final List<ProductAnalyticsQueuedEvent> queue = _store.read(namespace);
    final List<ProductAnalyticsQueuedEvent> fresh = queue
        .where(
          (ProductAnalyticsQueuedEvent item) =>
              now.difference(item.enqueuedAtUtc) < policy.queueMaxAge,
        )
        .toList();
    if (fresh.length != queue.length) {
      _drop(ProductAnalyticsDropReason.expired, queue.length - fresh.length);
      _store.write(namespace, fresh);
    }
    return fresh;
  }

  void _purge(String namespace, ProductAnalyticsDropReason reason) {
    final int count = _store.read(namespace).length;
    if (count == 0) return;
    _store.delete(namespace);
    _drop(reason, count);
  }

  void _drop(ProductAnalyticsDropReason reason, [int count = 1]) {
    if (count <= 0) return;
    _drops[reason] = (_drops[reason] ?? 0) + count;
  }
}
