import '../domain/entities/content_validation_violation.dart';
import '../domain/entities/event_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/place_publication_gateway.dart';

/// Transport used for Content: the same authenticated Functions path as
/// Booking, injected so the Create feature does not import the Booking feature.
abstract interface class ContentCallablePort {
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  );
}

/// Failure of the transport itself (no answer, no Session).
final class ContentTransportFailure implements Exception {
  const ContentTransportFailure(this.code);

  final String code;
}

/// Content owner commands and queries over `contentCommandV1`/`contentQueryV1`.
/// It holds no authority: the gate is asked before every call, and every
/// decision (Session, verified Creator, exact Page, Media readiness, review)
/// is the server's. One instance creates drafts of one [typeId] (Event by
/// default; Place for D3.1); every other command addresses ids the server
/// already bound to a type.
final class FunctionsEventPublicationGateway
    implements
        EventPublicationGateway,
        ContentDraftReader,
        ContentActivationGateway {
  FunctionsEventPublicationGateway({
    required ContentCallablePort port,
    required EventPublicationCommandGate gate,
    this.typeId = 'event',
  }) : _port = port,
       _gate = gate;

  final ContentCallablePort _port;
  final EventPublicationCommandGate _gate;
  final String typeId;

  @override
  Future<EventServerDraftRef> createDraft({
    required PublisherRef publisherRef,
    required String marketId,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async => _draftRef(
    await _command('createDraft', idempotencyKey, <String, Object?>{
      'typeId': typeId,
      'publisherRef': <String, Object?>{
        'type': publisherRef.type.wireName,
        'id': publisherRef.id,
      },
      'marketId': marketId,
      'body': body,
    }),
  );

  @override
  Future<EventServerDraftRef> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async => _draftRef(
    await _command('updateDraft', idempotencyKey, <String, Object?>{
      'draftId': draftId,
      'expectedRevision': expectedRevision,
      'body': body,
    }),
  );

  @override
  Future<String> submit({
    required String draftId,
    required int expectedDraftRevision,
    required String idempotencyKey,
  }) async {
    final Map<String, Object?> submission = await _command(
      'submitForPublication',
      idempotencyKey,
      <String, Object?>{
        'draftId': draftId,
        'expectedDraftRevision': expectedDraftRevision,
      },
    );
    return _string(submission, 'submissionId');
  }

  @override
  Future<void> publishApproved({
    required String submissionId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    await _command('publishApprovedRevision', idempotencyKey, <String, Object?>{
      'submissionId': submissionId,
      'expectedPointerRevision': expectedPointerRevision,
    });
  }

  @override
  Future<void> withdraw({
    required String contentId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    await _command('withdrawPublication', idempotencyKey, <String, Object?>{
      'contentId': contentId,
      'expectedPointerRevision': expectedPointerRevision,
      'mode': 'withdraw',
    });
  }

  @override
  Future<void> activatePublishedRevision({
    required String contentId,
    required String publishedRevisionId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    await _command(
      'activatePublishedRevision',
      idempotencyKey,
      <String, Object?>{
        'contentId': contentId,
        'publishedRevisionId': publishedRevisionId,
        'expectedPointerRevision': expectedPointerRevision,
      },
    );
  }

  @override
  Future<EventPublicationStatus> status(String contentId) async {
    _gate.assertAllowed();
    final Map<String, Object?> data = await _call(
      'contentQueryV1',
      <String, Object?>{
        'schemaVersion': 1,
        'queryType': 'getPublicationStatus',
        'payload': <String, Object?>{'contentId': contentId},
      },
    );
    final Object? pointerValue = data['pointer'];
    final Map<Object?, Object?>? pointer = pointerValue is Map
        ? pointerValue
        : null;
    final Object? submissionsValue = data['submissions'];
    final List<Map<Object?, Object?>> submissions = submissionsValue is List
        ? submissionsValue.whereType<Map<Object?, Object?>>().toList()
        : <Map<Object?, Object?>>[];
    // The latest submission is the one with the latest creation instant.
    submissions.sort(
      (left, right) =>
          '${left['createdAtUtc']}'.compareTo('${right['createdAtUtc']}'),
    );
    final Map<Object?, Object?>? latest = submissions.isEmpty
        ? null
        : submissions.last;
    final Object? hold = pointer?['moderationHold'];
    return EventPublicationStatus(
      contentId: contentId,
      latestSubmissionId: latest?['submissionId'] as String?,
      latestSubmissionState: latest?['state'] as String?,
      pointerRevision: pointer?['revision'] as int?,
      visibility: pointer?['visibility'] as String?,
      currentPublishedRevisionId:
          pointer?['currentPublishedRevisionId'] as String?,
      previousPublishedRevisionId:
          pointer?['previousPublishedRevisionId'] as String?,
      ownerHold: pointer?['ownerHold'] as String?,
      moderationHold: hold is Map ? hold['kind'] as String? : null,
    );
  }

  /// The owner's read of the draft (`getDraft`), for its revision and author.
  @override
  Future<EventServerDraftRef> draft(String draftId) async {
    _gate.assertAllowed();
    return _draftRef(
      await _call('contentQueryV1', <String, Object?>{
        'schemaVersion': 1,
        'queryType': 'getDraft',
        'payload': <String, Object?>{'draftId': draftId},
      }),
    );
  }

  Future<Map<String, Object?>> _command(
    String commandType,
    String idempotencyKey,
    Map<String, Object?> payload,
  ) {
    _gate.assertAllowed();
    return _call('contentCommandV1', <String, Object?>{
      'schemaVersion': 1,
      'commandType': commandType,
      'idempotencyKey': idempotencyKey,
      'payload': payload,
    });
  }

  Future<Map<String, Object?>> _call(
    String callableName,
    Map<String, Object?> data,
  ) async {
    final Map<String, Object?> result;
    try {
      result = await _port.invoke(callableName, data);
    } on ContentTransportFailure catch (failure) {
      throw EventPublicationUnavailable(failure.code);
    }
    if (result['kind'] != 'succeeded') {
      throw EventPublicationRejected(
        result['code'] as String? ?? 'invalid_contract',
        violations: result['code'] == 'validation_failed'
            ? ContentValidationViolation.fromWire(result['violations'])
            : const [],
      );
    }
    final Object? value = result['data'];
    if (value is! Map) throw const EventPublicationRejected('invalid_contract');
    return Map<String, Object?>.from(value);
  }

  EventServerDraftRef _draftRef(Map<String, Object?> draft) =>
      EventServerDraftRef(
        contentId: _string(draft, 'contentId'),
        draftId: _string(draft, 'draftId'),
        revision: draft['revision'] is int
            ? draft['revision']! as int
            : throw const EventPublicationRejected('invalid_contract'),
        createdByUserId: draft['createdByUserId'] is String
            ? draft['createdByUserId']! as String
            : null,
      );

  static String _string(Map<String, Object?> data, String key) {
    final Object? value = data[key];
    if (value is String) return value;
    throw const EventPublicationRejected('invalid_contract');
  }
}
