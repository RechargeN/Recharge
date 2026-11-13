import '../domain/entities/event_publication.dart';
import '../domain/entities/find_people_publication.dart';
import '../domain/repositories/find_people_publication_gateway.dart';
import 'functions_event_publication_gateway.dart';

/// BCK-06 Find People consent over `findPeopleConsentCommandV1` and
/// `findPeopleConsentQueryV1` (D3.7 §5.1). It holds no authority: the gate is
/// asked before every call; who may consent, the age attestation and the
/// expiry are decided on the server.
final class FunctionsFindPeopleConsentGateway
    implements FindPeopleConsentGateway {
  const FunctionsFindPeopleConsentGateway({
    required ContentCallablePort port,
    required FindPeoplePublicationCommandGate gate,
  }) : _port = port,
       _gate = gate;

  final ContentCallablePort _port;
  final FindPeoplePublicationCommandGate _gate;

  @override
  Future<FindPeopleConsentView?> consent(String contentId) async {
    final Map<String, Object?> answer = await _call(
      'findPeopleConsentQueryV1',
      <String, Object?>{
        'schemaVersion': 1,
        'queryType': 'getMyFindPeopleConsent',
        'payload': <String, Object?>{'contentId': contentId},
      },
    );
    final Object? consent = answer['consent'];
    if (consent == null) return null;
    return FindPeopleConsentView.fromWire(consent) ??
        (throw const EventPublicationRejected('invalid_contract'));
  }

  @override
  Future<FindPeopleConsentView> grant({
    required String contentId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _command(
    'grantFindPeopleConsent',
    contentId,
    expectedRevision,
    idempotencyKey,
  );

  @override
  Future<FindPeopleConsentView> revoke({
    required String contentId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _command(
    'revokeFindPeopleConsent',
    contentId,
    expectedRevision,
    idempotencyKey,
  );

  Future<FindPeopleConsentView> _command(
    String commandType,
    String contentId,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final Map<String, Object?> answer = await _call(
      'findPeopleConsentCommandV1',
      <String, Object?>{
        'schemaVersion': 1,
        'commandType': commandType,
        'idempotencyKey': idempotencyKey,
        'payload': <String, Object?>{
          'contentId': contentId,
          'expectedRevision': expectedRevision,
        },
      },
    );
    return FindPeopleConsentView.fromWire(answer['consent']) ??
        (throw const EventPublicationRejected('invalid_contract'));
  }

  Future<Map<String, Object?>> _call(
    String callableName,
    Map<String, Object?> data,
  ) async {
    _gate.assertAllowed();
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
    return result;
  }
}
