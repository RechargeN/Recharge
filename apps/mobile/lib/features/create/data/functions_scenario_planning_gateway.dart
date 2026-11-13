import 'package:uuid/uuid.dart';

import '../domain/entities/event_publication.dart';
import '../domain/entities/scenario_publication.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/scenario_publication_gateway.dart';
import 'functions_event_publication_gateway.dart';

/// SCN-PUB-01 owner commands over `scenarioCommandV1` / `scenarioQueryV1`,
/// through the same authenticated Functions path as Content. It holds no
/// authority: the gate is asked first and the server decides everything.
final class FunctionsScenarioPlanningGateway
    implements ScenarioPlanningGateway {
  FunctionsScenarioPlanningGateway({
    required ContentCallablePort port,
    required EventPublicationCommandGate gate,
    required String accountId,
  }) : _port = port,
       _gate = gate,
       _accountId = accountId;

  final ContentCallablePort _port;
  final EventPublicationCommandGate _gate;
  final String _accountId;

  @override
  Future<int> serverRevision(String scenarioId) async {
    final Map<String, Object?> result = await _call(
      'scenarioQueryV1',
      <String, Object?>{
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'scenarioId': scenarioId,
      },
    );
    final Object? entry = result['entry'];
    final Object? revision = entry is Map ? entry['revision'] : null;
    if (revision is! int) {
      throw const EventPublicationRejected('invalid_contract');
    }
    return revision;
  }

  @override
  Future<ScenarioDistributionRef> distribute({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final Map<String, Object?> result = await _command(
      'distribute',
      scenarioId,
      expectedRevision,
      idempotencyKey,
    );
    final Object? id = result['scenarioRevisionId'];
    final Object? hash = result['contentHash'];
    final Object? distribution = result['distribution'];
    if (id is! String || hash is! String || distribution is! Map) {
      throw const EventPublicationRejected('invalid_contract');
    }
    return ScenarioDistributionRef(
      scenarioRevisionId: id,
      contentHash: hash,
      distribution: Map<String, Object?>.from(distribution),
    );
  }

  @override
  Future<ScenarioShareLink> share({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
    int? ttlDays,
  }) async {
    final Map<String, Object?> result = await _command(
      'share',
      scenarioId,
      expectedRevision,
      idempotencyKey,
      <String, Object?>{'ttlDays': ?ttlDays},
    );
    final DateTime? expires = DateTime.tryParse('${result['expiresAtUtc']}');
    if (expires == null) {
      throw const EventPublicationRejected('invalid_contract');
    }
    final Object? token = result['token'];
    return ScenarioShareLink(
      expiresAtUtc: expires.toUtc(),
      token: token is String ? token : null,
    );
  }

  @override
  Future<bool> unshare({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async =>
      (await _command(
        'unshare',
        scenarioId,
        expectedRevision,
        idempotencyKey,
      ))['revoked'] ==
      true;

  @override
  Future<Map<String, Object?>> resolveShare(String token) async {
    final Map<String, Object?> result = await _call(
      'scenarioQueryV1',
      <String, Object?>{
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'shareToken': token,
      },
    );
    final Object? share = result['share'];
    if (share is! Map) throw const EventPublicationRejected('invalid_contract');
    return Map<String, Object?>.from(share);
  }

  Future<Map<String, Object?>> _command(
    String commandType,
    String scenarioId,
    int expectedRevision,
    String idempotencyKey, [
    Map<String, Object?> extra = const <String, Object?>{},
  ]) => _call('scenarioCommandV1', <String, Object?>{
    'schemaVersion': 1,
    'requestId': const Uuid().v4(),
    'actorContext': _accountId,
    'idempotencyKey': idempotencyKey,
    'commandType': commandType,
    'scenarioId': scenarioId,
    'expectedRevision': expectedRevision,
    'generation': 0,
    ...extra,
  });

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
