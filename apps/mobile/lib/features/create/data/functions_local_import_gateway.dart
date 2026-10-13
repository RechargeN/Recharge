import 'functions_event_publication_gateway.dart'
    show ContentCallablePort, ContentTransportFailure;
import '../domain/entities/event_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/local_import_gateway.dart';

/// The import's Content owner commands over `contentCommandV1` /
/// `contentQueryV1` (D4 §5.3). It holds no authority: the gate is asked before
/// every call, and every decision (Session, verified Creator, exact Page, type
/// flag, deduplication of the import source) is the server's.
final class FunctionsLocalImportGateway implements LocalImportContentGateway {
  FunctionsLocalImportGateway({
    required ContentCallablePort port,
    required LocalImportCommandGate gate,
  }) : _port = port,
       _gate = gate;

  final ContentCallablePort _port;
  final LocalImportCommandGate _gate;

  @override
  Future<LocalImportServerDraft> createImportDraft({
    required String typeId,
    required PublisherRef publisherRef,
    required String marketId,
    required String importSourceKey,
    required String idempotencyKey,
  }) async => _draft(
    await _command('createDraft', idempotencyKey, <String, Object?>{
      'typeId': typeId,
      'publisherRef': <String, Object?>{
        'type': publisherRef.type.wireName,
        'id': publisherRef.id,
      },
      'marketId': marketId,
      'body': const <String, Object?>{},
      'importSourceKey': importSourceKey,
    }),
  );

  @override
  Future<LocalImportServerDraft> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async => _draft(
    await _command('updateDraft', idempotencyKey, <String, Object?>{
      'draftId': draftId,
      'expectedRevision': expectedRevision,
      'body': body,
    }),
  );

  @override
  Future<LocalImportServerDraft> draft(String draftId) async {
    _gate.assertAllowed();
    return _draft(
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
      );
    }
    final Object? value = result['data'];
    if (value is! Map) throw const EventPublicationRejected('invalid_contract');
    return Map<String, Object?>.from(value);
  }

  static LocalImportServerDraft _draft(Map<String, Object?> data) {
    final Object? contentId = data['contentId'];
    final Object? draftId = data['draftId'];
    final Object? revision = data['revision'];
    final Object? body = data['body'];
    if (contentId is! String || draftId is! String || revision is! int) {
      throw const EventPublicationRejected('invalid_contract');
    }
    return LocalImportServerDraft(
      contentId: contentId,
      draftId: draftId,
      revision: revision,
      typeId: data['typeId'] is String ? data['typeId']! as String : null,
      createdByUserId: data['createdByUserId'] is String
          ? data['createdByUserId']! as String
          : null,
      importSourceKey: data['importSourceKey'] is String
          ? data['importSourceKey']! as String
          : null,
      body: body is Map ? Map<String, Object?>.from(body) : null,
    );
  }
}
