import '../entities/ai_assist_contract.dart';

abstract interface class AiAssistGateway {
  Future<AiAssistGatewayResponse> execute(AiAssistGatewayRequest request);
}

abstract interface class AiAssistQuotaStore {
  bool tryConsume(AiAssistCapability capability, {required int limit});

  int usageFor(AiAssistCapability capability);
}

class AiAssistGatewayException implements Exception {
  const AiAssistGatewayException(this.code, this.message);

  final AiAssistFailureCode code;
  final String message;

  @override
  String toString() => 'AiAssistGatewayException($code, $message)';
}
