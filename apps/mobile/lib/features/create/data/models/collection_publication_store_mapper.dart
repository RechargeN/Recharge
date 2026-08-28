import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/entities/collection_moderation_request.dart';
import '../../domain/entities/collection_publication_data.dart';
import 'collection_publication_model.dart';

/// CLG-PST-01: JSON envelope codec for everything
/// `CollectionPublicationLocalDatasource` persists — an active/staging
/// Collection version, an idempotency receipt, or a moderation request.
///
/// Every envelope carries a `schema_version` and a `content_hash` (sha256
/// of the envelope's own canonical JSON, computed with the hash field
/// itself absent). A decode that fails schema-version or hash validation,
/// or is missing a required field, returns `null` — never a
/// partially-populated value and never a thrown exception past this class
/// — so the caller can treat exactly one record as corrupt and isolated
/// without that judgment call leaking into parsing logic scattered
/// elsewhere.
class CollectionPublicationStoreMapper {
  const CollectionPublicationStoreMapper._();

  static const int currentSchemaVersion = 1;

  // ---------------------------------------------------------------------
  // Active / staging version envelope
  // ---------------------------------------------------------------------

  static String encodeVersion(PublishedCollectionVersion version) {
    final Map<String, Object?> body = <String, Object?>{
      'schema_version': currentSchemaVersion,
      'collection_id': version.collectionId,
      'version_id': version.collectionVersionId,
      'bundle': CollectionPublicationModel.toJson(version.bundle),
      'published_at_utc': version.publishedAtUtc.toIso8601String(),
    };
    return jsonEncode(_sealed(body));
  }

  /// Returns `null` if the envelope is missing, malformed, on an
  /// unsupported schema version, or its `content_hash` does not match its
  /// own body — the one record this call was for is corrupt; nothing else
  /// stored is affected.
  static PublishedCollectionVersion? decodeVersion(String? raw) {
    final Map<String, Object?>? body = _verified(raw);
    if (body == null) return null;
    final DateTime? publishedAtUtc = _dateTime(body['published_at_utc']);
    final CollectionPublishBundle? bundle = CollectionPublicationModel.fromJson(
      body['bundle'],
    );
    if (publishedAtUtc == null || bundle == null) return null;
    return PublishedCollectionVersion(
      bundle: bundle,
      publishedAtUtc: publishedAtUtc,
    );
  }

  // ---------------------------------------------------------------------
  // Idempotency receipt envelope
  // ---------------------------------------------------------------------

  static String encodeReceipt({
    required String payloadHash,
    required CollectionPublishReceipt receipt,
  }) {
    final Map<String, Object?> body = <String, Object?>{
      'schema_version': currentSchemaVersion,
      'payload_hash': payloadHash,
      'receipt': <String, Object?>{
        'collection_id': receipt.collectionId,
        'collection_version_id': receipt.collectionVersionId,
        'outcome': receipt.outcome.name,
        'published_at_utc': receipt.publishedAtUtc?.toIso8601String(),
        'submitted_at_utc': receipt.submittedAtUtc?.toIso8601String(),
        'discover_synced': receipt.discoverSynced,
      },
    };
    return jsonEncode(_sealed(body));
  }

  static ({String payloadHash, CollectionPublishReceipt receipt})?
  decodeReceipt(String? raw) {
    final Map<String, Object?>? body = _verified(raw);
    if (body == null) return null;
    final String? payloadHash = _text(body['payload_hash']);
    final Object? rawReceipt = body['receipt'];
    if (payloadHash == null || rawReceipt is! Map) return null;
    final Map<String, Object?> receiptJson = rawReceipt.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final String? collectionId = _text(receiptJson['collection_id']);
    final String? collectionVersionId = _text(
      receiptJson['collection_version_id'],
    );
    final CollectionPublishOutcome? outcome = _enumValue(
      receiptJson['outcome'] as String?,
      CollectionPublishOutcome.values,
    );
    if (collectionId == null || collectionVersionId == null || outcome == null) {
      return null;
    }
    final DateTime? publishedAtUtc = _dateTime(
      receiptJson['published_at_utc'],
    );
    final DateTime? submittedAtUtc = _dateTime(
      receiptJson['submitted_at_utc'],
    );
    if ((publishedAtUtc == null) == (submittedAtUtc == null)) {
      // CollectionPublishReceipt's own constructor asserts exactly one of
      // these is set — a stored envelope violating that is corrupt, not a
      // case to patch around here.
      return null;
    }
    return (
      payloadHash: payloadHash,
      receipt: CollectionPublishReceipt(
        collectionId: collectionId,
        collectionVersionId: collectionVersionId,
        outcome: outcome,
        publishedAtUtc: publishedAtUtc,
        submittedAtUtc: submittedAtUtc,
        discoverSynced: receiptJson['discover_synced'] as bool? ?? true,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Moderation request envelope
  // ---------------------------------------------------------------------

  static String encodeModerationRequest(CollectionModerationRequest request) {
    final CollectionModerationDecision? decision = request.decision;
    final Map<String, Object?> body = <String, Object?>{
      'schema_version': currentSchemaVersion,
      'request_id': request.requestId,
      'bundle': CollectionPublicationModel.toJson(request.bundle),
      'submitted_at_utc': request.submittedAtUtc.toIso8601String(),
      'submitted_by_actor_id': request.submittedByActorId,
      'decision': decision == null
          ? null
          : <String, Object?>{
              'outcome': decision.outcome.name,
              'decided_at_utc': decision.decidedAtUtc.toIso8601String(),
              'decided_by_actor_id': decision.decidedByActorId,
              'rejection_reason': decision.rejectionReason?.name,
            },
    };
    return jsonEncode(_sealed(body));
  }

  static CollectionModerationRequest? decodeModerationRequest(String? raw) {
    final Map<String, Object?>? body = _verified(raw);
    if (body == null) return null;
    final String? requestId = _text(body['request_id']);
    final DateTime? submittedAtUtc = _dateTime(body['submitted_at_utc']);
    final String? submittedByActorId = _text(body['submitted_by_actor_id']);
    final CollectionPublishBundle? bundle = CollectionPublicationModel.fromJson(
      body['bundle'],
    );
    if (requestId == null ||
        submittedAtUtc == null ||
        submittedByActorId == null ||
        bundle == null) {
      return null;
    }
    final Object? rawDecision = body['decision'];
    CollectionModerationDecision? decision;
    if (rawDecision != null) {
      if (rawDecision is! Map) return null;
      final Map<String, Object?> decisionJson = rawDecision.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
      final CollectionModerationDecisionOutcome? outcome = _enumValue(
        decisionJson['outcome'] as String?,
        CollectionModerationDecisionOutcome.values,
      );
      final DateTime? decidedAtUtc = _dateTime(decisionJson['decided_at_utc']);
      final String? decidedByActorId = _text(
        decisionJson['decided_by_actor_id'],
      );
      if (outcome == null || decidedAtUtc == null || decidedByActorId == null) {
        return null;
      }
      final CollectionModerationRejectionReason? rejectionReason = _enumValue(
        decisionJson['rejection_reason'] as String?,
        CollectionModerationRejectionReason.values,
      );
      // The domain assert requires exactly rejected <=> reasonReason != null.
      if ((outcome == CollectionModerationDecisionOutcome.rejected) !=
          (rejectionReason != null)) {
        return null;
      }
      decision = CollectionModerationDecision(
        outcome: outcome,
        decidedAtUtc: decidedAtUtc,
        decidedByActorId: decidedByActorId,
        rejectionReason: rejectionReason,
      );
    }
    return CollectionModerationRequest(
      requestId: requestId,
      bundle: bundle,
      submittedAtUtc: submittedAtUtc,
      submittedByActorId: submittedByActorId,
      decision: decision,
    );
  }

  // ---------------------------------------------------------------------
  // Shared envelope sealing / verification
  // ---------------------------------------------------------------------

  static Map<String, Object?> _sealed(Map<String, Object?> body) {
    return <String, Object?>{...body, 'content_hash': _hash(body)};
  }

  /// Decodes, checks the schema version, and re-verifies `content_hash`
  /// against the body it is supposed to cover. Returns the body map (hash
  /// field stripped) only when all of that holds.
  static Map<String, Object?>? _verified(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final Map<String, Object?> envelope = decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final int? schemaVersion = _int(envelope['schema_version']);
    if (schemaVersion == null || schemaVersion != currentSchemaVersion) {
      return null;
    }
    final String? storedHash = _text(envelope['content_hash']);
    if (storedHash == null) return null;
    final Map<String, Object?> body = Map<String, Object?>.of(envelope)
      ..remove('content_hash');
    if (_hash(body) != storedHash) return null;
    return body;
  }

  static String _hash(Map<String, Object?> body) {
    return sha256.convert(utf8.encode(jsonEncode(body))).toString();
  }

  static T? _enumValue<T extends Enum>(String? name, List<T> values) {
    if (name == null) return null;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// Every use of this in this file is a required id/hash/actor field —
  /// unlike `CollectionPublicationModel`'s own `_text`, this never
  /// collapses an empty string to `null`, since a legitimately-empty
  /// required field being rejected as "missing" is exactly the bug that
  /// motivated splitting `_text`/`_requiredText` there in the first place.
  static String? _text(Object? value) {
    return value is String ? value : null;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
