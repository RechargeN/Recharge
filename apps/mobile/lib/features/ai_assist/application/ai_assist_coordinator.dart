import '../../../core/id/id_generator.dart';
import '../domain/entities/ai_assist_contract.dart';
import '../domain/repositories/ai_prompt_registry.dart';
import '../domain/usecases/execute_ai_assist_usecase.dart';
import 'ai_assist_runtime_config.dart';

class AiAssistCoordinator {
  const AiAssistCoordinator({
    required ExecuteAiAssistUseCase executeAiAssist,
    required AiPromptRegistry promptRegistry,
    required IdGenerator idGenerator,
    required this.config,
  }) : _executeAiAssist = executeAiAssist,
       _promptRegistry = promptRegistry,
       _idGenerator = idGenerator;

  final ExecuteAiAssistUseCase _executeAiAssist;
  final AiPromptRegistry _promptRegistry;
  final IdGenerator _idGenerator;
  final AiAssistRuntimeConfig config;

  bool isEnabled(AiAssistCapability capability) =>
      config.platformEnabled && config.enabledCapabilities.contains(capability);

  List<AiAssistPromptDefinition> availablePrompts(
    AiAssistCapability capability,
  ) => _promptRegistry.forCapability(capability);

  Future<AiAssistResult> execute({
    required AiAssistCapability capability,
    required String promptDefinitionId,
    required int promptVersion,
    required AiAssistLocale locale,
    required String input,
    Map<String, Object?> context = const <String, Object?>{},
  }) => _executeAiAssist(
    AiAssistRequest(
      operationId: _idGenerator.generate(),
      capability: capability,
      promptDefinitionId: promptDefinitionId,
      promptVersion: promptVersion,
      locale: locale,
      input: input,
      context: context,
    ),
    policy: config.executionPolicy,
  );
}
