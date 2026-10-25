import 'dart:async';

import 'package:recharge/core/product_analytics/product_analytics_queue.dart';
import 'package:recharge/core/product_analytics/product_analytics_recorder.dart';

/// TEST-ONLY synthetic policy: invented values, not a product decision.
class SyntheticPolicySource implements ProductAnalyticsPolicySource {
  ProductAnalyticsClientPolicy? policy = syntheticPolicy();

  @override
  ProductAnalyticsClientPolicy? current() => policy;
}

ProductAnalyticsClientPolicy syntheticPolicy({
  String revision = 'synthetic-l3-policy-1',
  bool allowed = true,
  Set<String> events = const <String>{
    'details_opened',
    'favorite_added',
    'create_publish_finished',
  },
  Duration queueMaxAge = const Duration(hours: 24),
}) => ProductAnalyticsClientPolicy(
  policyRevision: revision,
  eventNames: events,
  collectionAllowed: allowed,
  queueMaxAge: queueMaxAge,
);

/// Local in-process sink: records what it was given and answers as told. It
/// stands for the provider-neutral ingress; no network is involved.
class CaptureSink implements ProductAnalyticsSink {
  final List<Map<String, Object?>> batches = <Map<String, Object?>>[];

  /// Default answer: every event accepted.
  FutureOr<ProductAnalyticsSendResult> Function(Map<String, Object?> batch)?
  answer;

  @override
  Future<ProductAnalyticsSendResult> send(Map<String, Object?> batch) async {
    batches.add(batch);
    final FutureOr<ProductAnalyticsSendResult> Function(Map<String, Object?>)?
    custom = answer;
    if (custom != null) return custom(batch);
    return ProductAnalyticsDelivered(<String, ProductAnalyticsDisposition>{
      for (final Map<String, Object?> event in eventsOf(batch))
        event['eventId']! as String: ProductAnalyticsDisposition.accepted,
    });
  }
}

List<Map<String, Object?>> eventsOf(Map<String, Object?> batch) =>
    (batch['events']! as List<Object?>).cast<Map<String, Object?>>();

class ThrowingStore implements ProductAnalyticsQueueStore {
  @override
  void delete(String namespace) => throw StateError('store down');

  @override
  List<String> namespaces() => throw StateError('store down');

  @override
  List<ProductAnalyticsQueuedEvent> read(String namespace) =>
      throw StateError('store down');

  @override
  void write(String namespace, List<ProductAnalyticsQueuedEvent> events) =>
      throw StateError('store down');
}

/// A UUID v4 sequence the recorder can use instead of random IDs.
String Function() sequentialEventIds() {
  int next = 0;
  return () {
    next += 1;
    return '3f2b8c1e-7a4d-4e5f-9b6a-${next.toRadixString(16).padLeft(12, '0')}';
  };
}

List<ProductAnalyticsQueuedEvent> allQueued(
  ProductAnalyticsQueueStore store,
) => <ProductAnalyticsQueuedEvent>[
  for (final String namespace in store.namespaces()) ...store.read(namespace),
];
