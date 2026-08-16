enum AiAssistCapability {
  smartSearch,
  creatorAssist,
  qualityAssist,
  translationAssist,
  recommendations,
  scenarioGeneration,
}

enum AiAssistLocale { en, ru, lv }

enum AiAssistMode { localMock }

enum AiAssistConfidence {
  deterministic,
  catalogSnapshot,
  estimated,
  unresolved,
}

enum AiAssistEvidenceKind {
  localRule,
  catalogSnapshot,
  officialSource,
  unresolved,
}

enum AiAssistIssueCode {
  localDemo,
  personalDataRedacted,
  fallbackUsed,
  partialResult,
  unknownData,
}

enum AiAssistRedactionKind { email, phone }

enum AiAssistFailureCode {
  platformDisabled,
  capabilityDisabled,
  invalidConfiguration,
  invalidRequest,
  promptNotFound,
  invalidPromptDefinition,
  unsupportedLocale,
  quotaExceeded,
  timeout,
  offline,
  gatewayFailure,
  malformedOutput,
  outputTooLarge,
  forbiddenTool,
  fallbackUnavailable,
}

class AiAssistException implements Exception {
  const AiAssistException(this.code, this.message);

  final AiAssistFailureCode code;
  final String message;

  @override
  String toString() => 'AiAssistException($code, $message)';
}

class AiAssistPromptDefinition {
  AiAssistPromptDefinition({
    required this.id,
    required this.version,
    required this.capability,
    required Set<AiAssistLocale> supportedLocales,
    required this.inputSchemaId,
    required this.outputSchemaId,
    required this.maximumInputCharacters,
    required this.instruction,
    required Set<String> allowedReadToolIds,
  }) : supportedLocales = Set<AiAssistLocale>.unmodifiable(supportedLocales),
       allowedReadToolIds = Set<String>.unmodifiable(allowedReadToolIds);

  final String id;
  final int version;
  final AiAssistCapability capability;
  final Set<AiAssistLocale> supportedLocales;
  final String inputSchemaId;
  final String outputSchemaId;
  final int maximumInputCharacters;
  final String instruction;
  final Set<String> allowedReadToolIds;

  String get registryKey => '$id@$version';

  bool get isValid =>
      id.trim().isNotEmpty &&
      version > 0 &&
      supportedLocales.isNotEmpty &&
      inputSchemaId.trim().isNotEmpty &&
      outputSchemaId.trim().isNotEmpty &&
      maximumInputCharacters > 0 &&
      instruction.trim().isNotEmpty &&
      allowedReadToolIds.every((String value) => value.trim().isNotEmpty);
}

class AiAssistRequest {
  AiAssistRequest({
    required this.operationId,
    required this.capability,
    required this.promptDefinitionId,
    required this.promptVersion,
    required this.locale,
    required this.input,
    Map<String, Object?> context = const <String, Object?>{},
  }) : context = freezeAiAssistMap(context);

  final String operationId;
  final AiAssistCapability capability;
  final String promptDefinitionId;
  final int promptVersion;
  final AiAssistLocale locale;

  /// Transient personal input. It must not be copied into a result or ledger.
  final String input;
  final Map<String, Object?> context;
}

class AiAssistSanitizedInput {
  AiAssistSanitizedInput({
    required this.value,
    required Set<AiAssistRedactionKind> redactions,
    required this.originalLength,
  }) : redactions = Set<AiAssistRedactionKind>.unmodifiable(redactions);

  final String value;
  final Set<AiAssistRedactionKind> redactions;
  final int originalLength;
}

class AiAssistGatewayRequest {
  AiAssistGatewayRequest({
    required this.operationId,
    required this.definition,
    required this.locale,
    required this.sanitizedInput,
    required Map<String, Object?> sanitizedContext,
    required Set<AiAssistRedactionKind> redactions,
  }) : sanitizedContext = freezeAiAssistMap(sanitizedContext),
       redactions = Set<AiAssistRedactionKind>.unmodifiable(redactions);

  final String operationId;
  final AiAssistPromptDefinition definition;
  final AiAssistLocale locale;
  final String sanitizedInput;
  final Map<String, Object?> sanitizedContext;
  final Set<AiAssistRedactionKind> redactions;
}

class AiAssistEvidence {
  const AiAssistEvidence({
    required this.kind,
    required this.label,
    this.sourceId,
    this.checkedAtUtc,
  });

  final AiAssistEvidenceKind kind;
  final String label;
  final String? sourceId;
  final DateTime? checkedAtUtc;
}

class AiAssistIssue {
  const AiAssistIssue({required this.code, required this.message});

  final AiAssistIssueCode code;
  final String message;
}

class AiAssistUsage {
  const AiAssistUsage({
    required this.requestUnits,
    required this.inputCharacters,
    required this.outputFields,
    required this.toolCalls,
  });

  final int requestUnits;
  final int inputCharacters;
  final int outputFields;
  final int toolCalls;

  bool get isValid =>
      requestUnits >= 0 &&
      inputCharacters >= 0 &&
      outputFields >= 0 &&
      toolCalls >= 0;
}

class AiAssistGatewayResponse {
  AiAssistGatewayResponse({
    required this.operationId,
    required this.proposalId,
    required this.providerId,
    required this.capability,
    required this.promptDefinitionId,
    required this.promptVersion,
    required this.outputSchemaId,
    required this.mode,
    required this.generatedAtUtc,
    required this.confidence,
    required Map<String, Object?> structuredPayload,
    required List<AiAssistEvidence> evidence,
    required List<AiAssistIssue> issues,
    required Set<String> usedToolIds,
    required this.usage,
  }) : structuredPayload = freezeAiAssistMap(structuredPayload),
       evidence = List<AiAssistEvidence>.unmodifiable(evidence),
       issues = List<AiAssistIssue>.unmodifiable(issues),
       usedToolIds = Set<String>.unmodifiable(usedToolIds);

  final String operationId;
  final String proposalId;
  final String providerId;
  final AiAssistCapability capability;
  final String promptDefinitionId;
  final int promptVersion;
  final String outputSchemaId;
  final AiAssistMode mode;
  final DateTime generatedAtUtc;
  final AiAssistConfidence confidence;
  final Map<String, Object?> structuredPayload;
  final List<AiAssistEvidence> evidence;
  final List<AiAssistIssue> issues;
  final Set<String> usedToolIds;
  final AiAssistUsage usage;
}

class AiAssistResult {
  AiAssistResult({
    required this.operationId,
    required this.proposalId,
    required this.providerId,
    required this.capability,
    required this.promptDefinitionId,
    required this.promptVersion,
    required this.outputSchemaId,
    required this.mode,
    required this.generatedAtUtc,
    required this.confidence,
    required Map<String, Object?> structuredPayload,
    required List<AiAssistEvidence> evidence,
    required List<AiAssistIssue> issues,
    required Set<String> usedToolIds,
    required this.usage,
  }) : structuredPayload = freezeAiAssistMap(structuredPayload),
       evidence = List<AiAssistEvidence>.unmodifiable(evidence),
       issues = List<AiAssistIssue>.unmodifiable(issues),
       usedToolIds = Set<String>.unmodifiable(usedToolIds);

  final String operationId;
  final String proposalId;
  final String providerId;
  final AiAssistCapability capability;
  final String promptDefinitionId;
  final int promptVersion;
  final String outputSchemaId;
  final AiAssistMode mode;
  final DateTime generatedAtUtc;
  final AiAssistConfidence confidence;
  final Map<String, Object?> structuredPayload;
  final List<AiAssistEvidence> evidence;
  final List<AiAssistIssue> issues;
  final Set<String> usedToolIds;
  final AiAssistUsage usage;
}

class AiAssistExecutionPolicy {
  AiAssistExecutionPolicy({
    required this.platformEnabled,
    required Set<AiAssistCapability> enabledCapabilities,
    required this.sessionRequestLimit,
    required this.maximumContextEntries,
    required this.maximumPayloadEntries,
    required this.maximumNestingDepth,
    required this.maximumStringCharacters,
    required this.fallbackEnabled,
  }) : enabledCapabilities = Set<AiAssistCapability>.unmodifiable(
         enabledCapabilities,
       );

  final bool platformEnabled;
  final Set<AiAssistCapability> enabledCapabilities;
  final int sessionRequestLimit;
  final int maximumContextEntries;
  final int maximumPayloadEntries;
  final int maximumNestingDepth;
  final int maximumStringCharacters;
  final bool fallbackEnabled;

  bool get isValid =>
      sessionRequestLimit > 0 &&
      maximumContextEntries > 0 &&
      maximumPayloadEntries > 0 &&
      maximumNestingDepth > 0 &&
      maximumStringCharacters > 0;
}

Map<String, Object?> freezeAiAssistMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final MapEntry<String, Object?> entry in source.entries)
        entry.key: freezeAiAssistValue(entry.value),
    });

Object? freezeAiAssistValue(Object? value) {
  if (value is Map<String, Object?>) return freezeAiAssistMap(value);
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(freezeAiAssistValue));
  }
  if (value is Set<Object?>) {
    return Set<Object?>.unmodifiable(value.map(freezeAiAssistValue));
  }
  return value;
}
