import '../../domain/entities/ai_assist_contract.dart';
import '../../domain/repositories/ai_prompt_registry.dart';

class LocalAiPromptRegistry implements AiPromptRegistry {
  LocalAiPromptRegistry({List<AiAssistPromptDefinition>? definitions})
    : _definitions = _validate(definitions ?? _defaultDefinitions);

  final Map<String, AiAssistPromptDefinition> _definitions;

  static final List<AiAssistPromptDefinition>
  _defaultDefinitions = <AiAssistPromptDefinition>[
    AiAssistPromptDefinition(
      id: 'smart-search-local',
      version: 1,
      capability: AiAssistCapability.smartSearch,
      supportedLocales: AiAssistLocale.values.toSet(),
      inputSchemaId: 'ai.smart_search.input.v1',
      outputSchemaId: 'ai.smart_search.result.v1',
      maximumInputCharacters: 500,
      instruction: 'Interpret intent only through deterministic local rules.',
      allowedReadToolIds: const <String>{},
    ),
    AiAssistPromptDefinition(
      id: 'creator-assist-local',
      version: 1,
      capability: AiAssistCapability.creatorAssist,
      supportedLocales: AiAssistLocale.values.toSet(),
      inputSchemaId: 'ai.creator_assist.input.v1',
      outputSchemaId: 'ai.creator_assist.result.v1',
      maximumInputCharacters: 1000,
      instruction: 'Return bounded local suggestions without publication.',
      allowedReadToolIds: const <String>{},
    ),
    AiAssistPromptDefinition(
      id: 'quality-assist-local',
      version: 1,
      capability: AiAssistCapability.qualityAssist,
      supportedLocales: AiAssistLocale.values.toSet(),
      inputSchemaId: 'ai.quality_assist.input.v1',
      outputSchemaId: 'ai.quality_assist.result.v1',
      maximumInputCharacters: 1000,
      instruction: 'Return deterministic quality signals without moderation.',
      allowedReadToolIds: const <String>{},
    ),
    AiAssistPromptDefinition(
      id: 'translation-assist-local',
      version: 1,
      capability: AiAssistCapability.translationAssist,
      supportedLocales: AiAssistLocale.values.toSet(),
      inputSchemaId: 'ai.translation_assist.input.v1',
      outputSchemaId: 'ai.translation_assist.result.v1',
      maximumInputCharacters: 1500,
      instruction:
          'Return an empty local translation draft for explicit review.',
      allowedReadToolIds: const <String>{},
    ),
  ];

  @override
  AiAssistPromptDefinition? resolve({
    required String id,
    required int version,
  }) => _definitions['$id@$version'];

  @override
  List<AiAssistPromptDefinition> forCapability(AiAssistCapability capability) =>
      List<AiAssistPromptDefinition>.unmodifiable(
        _definitions.values.where(
          (AiAssistPromptDefinition value) => value.capability == capability,
        ),
      );

  static Map<String, AiAssistPromptDefinition> _validate(
    List<AiAssistPromptDefinition> source,
  ) {
    final Map<String, AiAssistPromptDefinition> result =
        <String, AiAssistPromptDefinition>{};
    for (final AiAssistPromptDefinition definition in source) {
      if (!definition.isValid || result.containsKey(definition.registryKey)) {
        throw ArgumentError(
          'AI prompt definitions must be valid and uniquely versioned.',
        );
      }
      result[definition.registryKey] = definition;
    }
    return Map<String, AiAssistPromptDefinition>.unmodifiable(result);
  }
}
