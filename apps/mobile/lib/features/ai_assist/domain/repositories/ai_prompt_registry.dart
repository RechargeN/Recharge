import '../entities/ai_assist_contract.dart';

abstract interface class AiPromptRegistry {
  AiAssistPromptDefinition? resolve({required String id, required int version});

  List<AiAssistPromptDefinition> forCapability(AiAssistCapability capability);
}
