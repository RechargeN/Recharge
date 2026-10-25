import 'dart:convert';

/// L3 product analytics contract (ANALYTICS_L3_PRODUCT_ANALYTICS_AMENDMENT.md
/// §3–4, §8). Mirrors `packages/api_contracts/schema/product_analytics/v1/
/// product_analytics_event_registry.v1.json`; the contract test keeps them
/// equal. Events are typed and carry only enum fields: no ID, free text, URL,
/// location, token or account reference has a place to go.
///
/// This is not the legacy console `AnalyticsService` (developer log only); the
/// two never exchange events.
const String productAnalyticsRegistryRevision = 'pa-l3-v1';

/// Declared purpose; not accepted (PA-B01), so no production policy exists.
const String productAnalyticsPurposeId = 'product_usage_measurement';
const String? productAnalyticsLegalBasisRef = null;

/// No account, Session, device or subject key in an event (BCK21-OD-03).
const String productAnalyticsSubjectMode = 'none';
const String productAnalyticsDataClass = 'personal';

class ProductAnalyticsLimits {
  const ProductAnalyticsLimits._();

  static const int batchMaxEvents = 20;
  static const int batchMaxBytes = 8192;
  static const int eventMaxBytes = 512;
  static const int queueMaxEvents = 100;
  static const int queueMaxBytes = 32768;
  static const int maxAttempts = 5;
  static const int sendTimeoutSeconds = 10;
  static const int futureSkewMinutes = 5;
  static const int aggregateReadMaxDays = 31;

  static const Map<String, int> asJson = <String, int>{
    'batchMaxEvents': batchMaxEvents,
    'batchMaxBytes': batchMaxBytes,
    'eventMaxBytes': eventMaxBytes,
    'queueMaxEvents': queueMaxEvents,
    'queueMaxBytes': queueMaxBytes,
    'maxAttempts': maxAttempts,
    'sendTimeoutSeconds': sendTimeoutSeconds,
    'futureSkewMinutes': futureSkewMinutes,
    'aggregateReadMaxDays': aggregateReadMaxDays,
  };
}

/// The ten accepted object types; legacy `quick_plan` has no value here.
enum ProductAnalyticsObjectKind {
  event('event'),
  activity('activity'),
  route('route'),
  place('place'),
  session('session'),
  scenario('scenario'),
  findPeople('find_people'),
  classWorkshop('class_workshop'),
  rental('rental'),
  collection('collection');

  const ProductAnalyticsObjectKind(this.wire);

  final String wire;

  /// Maps a Create/Catalog taxonomy ID (`find_people`) or a Dart object
  /// kind name (`findPeople`); anything else, including `quick_plan`, is
  /// not reported.
  static ProductAnalyticsObjectKind? fromObjectType(String? objectType) {
    for (final ProductAnalyticsObjectKind kind in values) {
      if (kind.wire == objectType || kind.name == objectType) return kind;
    }
    return null;
  }
}

enum ProductAnalyticsEntrySurface {
  details('details'),
  map('map'),
  planner('planner'),
  other('other');

  const ProductAnalyticsEntrySurface(this.wire);

  final String wire;
}

enum ProductAnalyticsPublishOutcome {
  published('published'),
  submitted('submitted'),
  denied('denied'),
  failed('failed');

  const ProductAnalyticsPublishOutcome(this.wire);

  final String wire;
}

const Map<String, List<String>> productAnalyticsEnums = <String, List<String>>{
  'objectKind': <String>[
    'event',
    'activity',
    'route',
    'place',
    'session',
    'scenario',
    'find_people',
    'class_workshop',
    'rental',
    'collection',
  ],
  'entrySurface': <String>['details', 'map', 'planner', 'other'],
  'publishOutcome': <String>['published', 'submitted', 'denied', 'failed'],
};

/// A typed client UX fact. None of them proves a publication, a saved entry,
/// a booking or any other business outcome; the owning domains hold those.
sealed class ProductAnalyticsEvent {
  const ProductAnalyticsEvent();

  String get eventName;
  int get eventVersion => 1;
  Map<String, String> get fields;
}

/// `details_opened` v1 — Which object types do people open in Details?
final class DetailsOpened extends ProductAnalyticsEvent {
  const DetailsOpened(this.objectKind);

  final ProductAnalyticsObjectKind objectKind;

  @override
  String get eventName => 'details_opened';

  @override
  Map<String, String> get fields => <String, String>{
    'object_kind': objectKind.wire,
  };
}

/// `favorite_added` v1 — Which object types do people save, and from where?
final class FavoriteAdded extends ProductAnalyticsEvent {
  const FavoriteAdded(this.objectKind, this.entrySurface);

  final ProductAnalyticsObjectKind objectKind;
  final ProductAnalyticsEntrySurface entrySurface;

  @override
  String get eventName => 'favorite_added';

  @override
  Map<String, String> get fields => <String, String>{
    'object_kind': objectKind.wire,
    'entry_surface': entrySurface.wire,
  };
}

/// `create_publish_finished` v1 — For which Create types does a publish
/// attempt end in refusal?
final class CreatePublishFinished extends ProductAnalyticsEvent {
  const CreatePublishFinished(this.createType, this.outcome);

  final ProductAnalyticsObjectKind createType;
  final ProductAnalyticsPublishOutcome outcome;

  @override
  String get eventName => 'create_publish_finished';

  @override
  Map<String, String> get fields => <String, String>{
    'create_type': createType.wire,
    'outcome': outcome.wire,
  };
}

class ProductAnalyticsDefinition {
  const ProductAnalyticsDefinition({
    required this.eventName,
    required this.eventVersion,
    required this.productQuestion,
    required this.eventOwner,
    required this.processingOwner,
    required this.producer,
    required this.retentionClass,
    required this.fields,
  });

  final String eventName;
  final int eventVersion;
  final String productQuestion;
  final String eventOwner;
  final String processingOwner;

  /// The only file allowed to construct this event (repository-relative).
  final String producer;
  final String retentionClass;
  final Map<String, String> fields;

  Map<String, Object?> toJson() => <String, Object?>{
    'eventName': eventName,
    'eventVersion': eventVersion,
    'productQuestion': productQuestion,
    'eventOwner': eventOwner,
    'processingOwner': processingOwner,
    'producer': producer,
    'retentionClass': retentionClass,
    'fields': fields,
  };
}

const List<ProductAnalyticsDefinition>
productAnalyticsEventRegistry = <ProductAnalyticsDefinition>[
  ProductAnalyticsDefinition(
    eventName: 'details_opened',
    eventVersion: 1,
    productQuestion: 'Which object types do people open in Details?',
    eventOwner: 'product.discover',
    processingOwner: 'data_platform',
    producer:
        'apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart',
    retentionClass: 'pa.raw_event',
    fields: <String, String>{'object_kind': 'objectKind'},
  ),
  ProductAnalyticsDefinition(
    eventName: 'favorite_added',
    eventVersion: 1,
    productQuestion:
        'Which object types do people save to Favorites, and from which surface?',
    eventOwner: 'product.library',
    processingOwner: 'data_platform',
    producer:
        'apps/mobile/lib/features/favorites/application/controllers/favorites_controller.dart',
    retentionClass: 'pa.raw_event',
    fields: <String, String>{
      'object_kind': 'objectKind',
      'entry_surface': 'entrySurface',
    },
  ),
  ProductAnalyticsDefinition(
    eventName: 'create_publish_finished',
    eventVersion: 1,
    productQuestion:
        'For which Create types does a publish attempt end in refusal?',
    eventOwner: 'product.create',
    processingOwner: 'data_platform',
    producer:
        'apps/mobile/lib/features/create/application/controllers/create_controller.dart',
    retentionClass: 'pa.raw_event',
    fields: <String, String>{
      'create_type': 'objectKind',
      'outcome': 'publishOutcome',
    },
  ),
];

const List<String> _envelopeKeys = <String>[
  'eventId',
  'eventName',
  'eventVersion',
  'occurredAtUtc',
  'policyRevision',
  'fields',
];
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _hourInstant = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:00:00\.000Z$');
final RegExp productAnalyticsPolicyRevisionPattern = RegExp(
  r'^[a-z0-9][a-z0-9.-]{0,63}$',
);

ProductAnalyticsDefinition? productAnalyticsDefinition(
  Object? eventName,
  Object? eventVersion,
) {
  for (final ProductAnalyticsDefinition definition
      in productAnalyticsEventRegistry) {
    if (definition.eventName == eventName &&
        eventVersion is int &&
        definition.eventVersion == eventVersion) {
      return definition;
    }
  }
  return null;
}

bool _exactKeys(Map<Object?, Object?> value, Iterable<String> keys) {
  final Set<String> expected = keys.toSet();
  return value.length == expected.length &&
      value.keys.every(
        (Object? key) => key is String && expected.contains(key),
      );
}

/// UTF-8 size of the canonical JSON form; the queue and batch bounds use it.
int productAnalyticsJsonBytes(Object? value) =>
    utf8.encode(jsonEncode(value)).length;

/// Strict check of one envelope with the same rules as the server; `false`
/// means it is dropped before it can reach the queue.
bool isValidProductAnalyticsEnvelope(Object? raw) {
  if (raw is! Map || !_exactKeys(raw, _envelopeKeys)) return false;
  final Object? eventId = raw['eventId'];
  if (eventId is! String || !_uuidV4.hasMatch(eventId)) return false;
  final ProductAnalyticsDefinition? definition = productAnalyticsDefinition(
    raw['eventName'],
    raw['eventVersion'],
  );
  if (definition == null) return false;
  final Object? occurred = raw['occurredAtUtc'];
  if (occurred is! String || !_hourInstant.hasMatch(occurred)) return false;
  final DateTime? parsed = DateTime.tryParse(occurred);
  if (parsed == null || parsed.toUtc().toIso8601String() != occurred) {
    return false;
  }
  final Object? revision = raw['policyRevision'];
  if (revision is! String ||
      !productAnalyticsPolicyRevisionPattern.hasMatch(revision)) {
    return false;
  }
  final Object? fields = raw['fields'];
  if (fields is! Map || !_exactKeys(fields, definition.fields.keys)) {
    return false;
  }
  for (final MapEntry<String, String> field in definition.fields.entries) {
    final Object? value = fields[field.key];
    if (value is! String ||
        !productAnalyticsEnums[field.value]!.contains(value)) {
      return false;
    }
  }
  return productAnalyticsJsonBytes(raw) <= ProductAnalyticsLimits.eventMaxBytes;
}

/// Strict check of a batch envelope.
bool isValidProductAnalyticsBatch(Object? raw) {
  if (raw is! Map ||
      !_exactKeys(raw, const <String>['schemaVersion', 'events'])) {
    return false;
  }
  final Object? events = raw['events'];
  if (raw['schemaVersion'] != 1 || events is! List) return false;
  if (events.isEmpty || events.length > ProductAnalyticsLimits.batchMaxEvents) {
    return false;
  }
  return productAnalyticsJsonBytes(raw) <= ProductAnalyticsLimits.batchMaxBytes;
}
