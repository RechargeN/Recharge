import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/ai_assist/data/datasources/local_ai_prompt_registry.dart';
import 'package:recharge/features/ai_assist/domain/entities/ai_assist_contract.dart';

void main() {
  test('registry resolves an exact version for its capability', () {
    final LocalAiPromptRegistry registry = LocalAiPromptRegistry();

    final AiAssistPromptDefinition? definition = registry.resolve(
      id: 'smart-search-local',
      version: 1,
    );

    expect(definition, isNotNull);
    expect(definition!.capability, AiAssistCapability.smartSearch);
    expect(
      registry.forCapability(AiAssistCapability.smartSearch),
      hasLength(1),
    );
    expect(registry.resolve(id: 'smart-search-local', version: 2), isNull);
  });

  test('registry rejects duplicate or invalid prompt definitions', () {
    final AiAssistPromptDefinition definition = _definition();

    expect(
      () => LocalAiPromptRegistry(
        definitions: <AiAssistPromptDefinition>[definition, definition],
      ),
      throwsArgumentError,
    );
    expect(
      () => LocalAiPromptRegistry(
        definitions: <AiAssistPromptDefinition>[
          _definition(maximumInputCharacters: 0),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('request and response collections are recursively immutable', () {
    final AiAssistRequest request = AiAssistRequest(
      operationId: 'op-1',
      capability: AiAssistCapability.smartSearch,
      promptDefinitionId: 'smart-search-local',
      promptVersion: 1,
      locale: AiAssistLocale.en,
      input: 'quiet Riga',
      context: <String, Object?>{
        'nested': <String, Object?>{
          'values': <Object?>['one'],
        },
      },
    );

    expect(() => request.context['new'] = true, throwsUnsupportedError);
    final Map<String, Object?> nested =
        request.context['nested']! as Map<String, Object?>;
    expect(() => nested['new'] = true, throwsUnsupportedError);
    final List<Object?> values = nested['values']! as List<Object?>;
    expect(() => values.add('two'), throwsUnsupportedError);
  });
}

AiAssistPromptDefinition _definition({int maximumInputCharacters = 100}) =>
    AiAssistPromptDefinition(
      id: 'test-prompt',
      version: 1,
      capability: AiAssistCapability.smartSearch,
      supportedLocales: const <AiAssistLocale>{AiAssistLocale.en},
      inputSchemaId: 'test.input.v1',
      outputSchemaId: 'test.output.v1',
      maximumInputCharacters: maximumInputCharacters,
      instruction: 'Return a deterministic test result.',
      allowedReadToolIds: const <String>{},
    );
