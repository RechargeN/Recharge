import 'package:uuid/uuid.dart';

import '../domain/entities/event_publication.dart';
import '../domain/entities/route_content_publication.dart';
import '../domain/repositories/event_publication_gateway.dart';
import '../domain/repositories/route_content_publication_gateway.dart';
import 'functions_event_publication_gateway.dart';

/// RTE-PUB-01 `distribute` over `routeCommandV1`, through the same
/// authenticated Functions path as Content. It holds no authority: the gate
/// is asked first and the server decides everything.
final class FunctionsRouteDistributionGateway
    implements RouteDistributionGateway {
  FunctionsRouteDistributionGateway({
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
  Future<RouteDistributionRef> distribute({
    required String routeId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    _gate.assertAllowed();
    final Map<String, Object?> result;
    try {
      result = await _port.invoke('routeCommandV1', <String, Object?>{
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'ownerContext': _accountId,
        'idempotencyKey': idempotencyKey,
        'commandType': 'distribute',
        'routeId': routeId,
        'expectedRevision': expectedRevision,
      });
    } on ContentTransportFailure catch (failure) {
      throw EventPublicationUnavailable(failure.code);
    }
    if (result['kind'] != 'succeeded') {
      throw EventPublicationRejected(
        result['code'] as String? ?? 'invalid_contract',
      );
    }
    final Object? id = result['routeRevisionId'];
    final Object? hash = result['contentHash'];
    final Object? distribution = result['distribution'];
    if (id is! String || hash is! String || distribution is! Map) {
      throw const EventPublicationRejected('invalid_contract');
    }
    return RouteDistributionRef(
      routeRevisionId: id,
      contentHash: hash,
      distribution: Map<String, Object?>.from(distribution),
    );
  }
}
