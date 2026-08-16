import '../domain/entities/ai_assist_contract.dart';

class AiAssistRuntimeConfig {
  AiAssistRuntimeConfig({
    this.platformEnabled = true,
    Set<AiAssistCapability>? enabledCapabilities,
    this.sessionRequestLimit = 25,
    this.maximumContextEntries = 64,
    this.maximumPayloadEntries = 128,
    this.maximumNestingDepth = 6,
    this.maximumStringCharacters = 2000,
    this.fallbackEnabled = true,
  }) : enabledCapabilities = Set<AiAssistCapability>.unmodifiable(
         enabledCapabilities ??
             <AiAssistCapability>{
               AiAssistCapability.smartSearch,
               AiAssistCapability.creatorAssist,
               AiAssistCapability.qualityAssist,
               AiAssistCapability.translationAssist,
             },
       );

  final bool platformEnabled;
  final Set<AiAssistCapability> enabledCapabilities;
  final int sessionRequestLimit;
  final int maximumContextEntries;
  final int maximumPayloadEntries;
  final int maximumNestingDepth;
  final int maximumStringCharacters;
  final bool fallbackEnabled;

  AiAssistExecutionPolicy get executionPolicy => AiAssistExecutionPolicy(
    platformEnabled: platformEnabled,
    enabledCapabilities: enabledCapabilities,
    sessionRequestLimit: sessionRequestLimit,
    maximumContextEntries: maximumContextEntries,
    maximumPayloadEntries: maximumPayloadEntries,
    maximumNestingDepth: maximumNestingDepth,
    maximumStringCharacters: maximumStringCharacters,
    fallbackEnabled: fallbackEnabled,
  );
}
