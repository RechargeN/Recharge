import '../entities/ai_assist_contract.dart';
import '../repositories/ai_assist_gateway.dart';
import '../repositories/ai_prompt_registry.dart';
import 'sanitize_ai_input_usecase.dart';

class ExecuteAiAssistUseCase {
  const ExecuteAiAssistUseCase({
    required AiPromptRegistry promptRegistry,
    required AiAssistGateway gateway,
    required AiAssistQuotaStore quotaStore,
    AiAssistGateway? fallbackGateway,
    SanitizeAiInputUseCase sanitizer = const SanitizeAiInputUseCase(),
  }) : _promptRegistry = promptRegistry,
       _gateway = gateway,
       _fallbackGateway = fallbackGateway,
       _quotaStore = quotaStore,
       _sanitizer = sanitizer;

  final AiPromptRegistry _promptRegistry;
  final AiAssistGateway _gateway;
  final AiAssistGateway? _fallbackGateway;
  final AiAssistQuotaStore _quotaStore;
  final SanitizeAiInputUseCase _sanitizer;

  Future<AiAssistResult> call(
    AiAssistRequest request, {
    required AiAssistExecutionPolicy policy,
  }) async {
    _validatePolicyAndRequest(policy, request);
    final AiAssistPromptDefinition? definition = _promptRegistry.resolve(
      id: request.promptDefinitionId,
      version: request.promptVersion,
    );
    if (definition == null) {
      throw const AiAssistException(
        AiAssistFailureCode.promptNotFound,
        'The requested AI prompt definition is not registered.',
      );
    }
    if (!definition.isValid ||
        definition.capability != request.capability ||
        definition.id != request.promptDefinitionId ||
        definition.version != request.promptVersion) {
      throw const AiAssistException(
        AiAssistFailureCode.invalidPromptDefinition,
        'The AI prompt definition does not match this capability.',
      );
    }
    if (!definition.supportedLocales.contains(request.locale)) {
      throw const AiAssistException(
        AiAssistFailureCode.unsupportedLocale,
        'This AI prompt does not support the requested locale.',
      );
    }

    final String normalizedInput = request.input.trim();
    if (normalizedInput.isEmpty ||
        normalizedInput.length > definition.maximumInputCharacters) {
      throw const AiAssistException(
        AiAssistFailureCode.invalidRequest,
        'AI input is empty or exceeds the prompt limit.',
      );
    }
    _validateStructuredValue(
      request.context,
      maximumEntries: policy.maximumContextEntries,
      maximumDepth: policy.maximumNestingDepth,
      maximumStringCharacters: policy.maximumStringCharacters,
      failureCode: AiAssistFailureCode.invalidRequest,
    );

    final AiAssistSanitizedInput sanitizedInput = _sanitizer(normalizedInput);
    final _SanitizedContext sanitizedContext = _sanitizeContext(
      request.context,
    );
    final Set<AiAssistRedactionKind> redactions = <AiAssistRedactionKind>{
      ...sanitizedInput.redactions,
      ...sanitizedContext.redactions,
    };
    final Set<String> forbiddenRawFragments = <String>{
      if (sanitizedInput.value != normalizedInput) normalizedInput,
      ...sanitizedContext.redactedOriginals,
    };

    if (!_quotaStore.tryConsume(
      request.capability,
      limit: policy.sessionRequestLimit,
    )) {
      throw const AiAssistException(
        AiAssistFailureCode.quotaExceeded,
        'The local AI assistance session quota is exhausted.',
      );
    }

    final AiAssistGatewayRequest gatewayRequest = AiAssistGatewayRequest(
      operationId: request.operationId,
      definition: definition,
      locale: request.locale,
      sanitizedInput: sanitizedInput.value,
      sanitizedContext: sanitizedContext.value,
      redactions: redactions,
    );

    AiAssistGatewayResponse response;
    var fallbackUsed = false;
    try {
      response = await _gateway.execute(gatewayRequest);
    } on AiAssistGatewayException catch (error) {
      if (!_isFallbackEligible(error.code)) {
        throw AiAssistException(error.code, error.message);
      }
      if (!policy.fallbackEnabled) {
        throw AiAssistException(error.code, error.message);
      }
      final AiAssistGateway? fallback = _fallbackGateway;
      if (fallback == null) {
        throw const AiAssistException(
          AiAssistFailureCode.fallbackUnavailable,
          'The deterministic AI fallback is unavailable.',
        );
      }
      try {
        response = await fallback.execute(gatewayRequest);
        fallbackUsed = true;
      } on AiAssistGatewayException catch (fallbackError) {
        throw AiAssistException(fallbackError.code, fallbackError.message);
      }
    }

    _validateResponse(
      request: request,
      definition: definition,
      response: response,
      policy: policy,
      forbiddenRawFragments: forbiddenRawFragments,
    );
    final List<AiAssistIssue> issues = <AiAssistIssue>[
      ...response.issues,
      if (redactions.isNotEmpty)
        const AiAssistIssue(
          code: AiAssistIssueCode.personalDataRedacted,
          message: 'Personal contact data was redacted before processing.',
        ),
      if (fallbackUsed)
        const AiAssistIssue(
          code: AiAssistIssueCode.fallbackUsed,
          message: 'A deterministic local fallback produced this result.',
        ),
    ];

    return AiAssistResult(
      operationId: response.operationId,
      proposalId: response.proposalId,
      providerId: response.providerId,
      capability: response.capability,
      promptDefinitionId: response.promptDefinitionId,
      promptVersion: response.promptVersion,
      outputSchemaId: response.outputSchemaId,
      mode: response.mode,
      generatedAtUtc: response.generatedAtUtc,
      confidence: response.confidence,
      structuredPayload: response.structuredPayload,
      evidence: response.evidence,
      issues: _deduplicateIssues(issues),
      usedToolIds: response.usedToolIds,
      usage: response.usage,
    );
  }

  void _validatePolicyAndRequest(
    AiAssistExecutionPolicy policy,
    AiAssistRequest request,
  ) {
    if (!policy.isValid) {
      throw const AiAssistException(
        AiAssistFailureCode.invalidConfiguration,
        'The AI assistance runtime policy is invalid.',
      );
    }
    if (!policy.platformEnabled) {
      throw const AiAssistException(
        AiAssistFailureCode.platformDisabled,
        'AI assistance is disabled.',
      );
    }
    if (!policy.enabledCapabilities.contains(request.capability)) {
      throw const AiAssistException(
        AiAssistFailureCode.capabilityDisabled,
        'This AI assistance capability is disabled.',
      );
    }
    if (request.operationId.trim().isEmpty ||
        request.promptDefinitionId.trim().isEmpty ||
        request.promptVersion <= 0) {
      throw const AiAssistException(
        AiAssistFailureCode.invalidRequest,
        'AI request identifiers and versions must be valid.',
      );
    }
  }

  void _validateResponse({
    required AiAssistRequest request,
    required AiAssistPromptDefinition definition,
    required AiAssistGatewayResponse response,
    required AiAssistExecutionPolicy policy,
    required Set<String> forbiddenRawFragments,
  }) {
    final bool envelopeInvalid =
        response.operationId != request.operationId ||
        response.proposalId.trim().isEmpty ||
        response.providerId.trim().isEmpty ||
        response.capability != request.capability ||
        response.promptDefinitionId != definition.id ||
        response.promptVersion != definition.version ||
        response.outputSchemaId != definition.outputSchemaId ||
        response.mode != AiAssistMode.localMock ||
        !response.generatedAtUtc.isUtc ||
        !response.usage.isValid ||
        response.usage.toolCalls < response.usedToolIds.length ||
        response.evidence.any(
          (AiAssistEvidence value) =>
              value.label.trim().isEmpty ||
              value.checkedAtUtc != null && !value.checkedAtUtc!.isUtc,
        ) ||
        response.issues.any(
          (AiAssistIssue value) => value.message.trim().isEmpty,
        );
    if (envelopeInvalid) {
      throw const AiAssistException(
        AiAssistFailureCode.malformedOutput,
        'The AI gateway returned an invalid result envelope.',
      );
    }
    final String? forbiddenTool = response.usedToolIds
        .where((String value) => !definition.allowedReadToolIds.contains(value))
        .firstOrNull;
    if (forbiddenTool != null) {
      throw const AiAssistException(
        AiAssistFailureCode.forbiddenTool,
        'The AI gateway reported a tool outside the prompt allowlist.',
      );
    }
    _validateStructuredValue(
      response.structuredPayload,
      maximumEntries: policy.maximumPayloadEntries,
      maximumDepth: policy.maximumNestingDepth,
      maximumStringCharacters: policy.maximumStringCharacters,
      failureCode: AiAssistFailureCode.outputTooLarge,
    );
    if (_containsForbiddenRawValue(
      response.structuredPayload,
      forbiddenRawFragments,
    )) {
      throw const AiAssistException(
        AiAssistFailureCode.malformedOutput,
        'The AI result contains raw personal input.',
      );
    }
  }

  _SanitizedContext _sanitizeContext(Map<String, Object?> source) {
    final Set<AiAssistRedactionKind> redactions = <AiAssistRedactionKind>{};
    final Set<String> redactedOriginals = <String>{};

    Object? sanitize(Object? value) {
      if (value is String) {
        final AiAssistSanitizedInput result = _sanitizer(value);
        redactions.addAll(result.redactions);
        if (result.value != value) redactedOriginals.add(value);
        return result.value;
      }
      if (value is Map<String, Object?>) {
        return <String, Object?>{
          for (final MapEntry<String, Object?> entry in value.entries)
            entry.key: sanitize(entry.value),
        };
      }
      if (value is List<Object?>) {
        return <Object?>[for (final Object? item in value) sanitize(item)];
      }
      return value;
    }

    return _SanitizedContext(
      value: <String, Object?>{
        for (final MapEntry<String, Object?> entry in source.entries)
          entry.key: sanitize(entry.value),
      },
      redactions: redactions,
      redactedOriginals: redactedOriginals,
    );
  }

  void _validateStructuredValue(
    Object? value, {
    required int maximumEntries,
    required int maximumDepth,
    required int maximumStringCharacters,
    required AiAssistFailureCode failureCode,
  }) {
    var entries = 0;

    bool inspect(Object? current, int depth) {
      if (depth > maximumDepth) return false;
      if (current == null || current is bool || current is num) return true;
      if (current is String) {
        return current.length <= maximumStringCharacters;
      }
      if (current is List<Object?>) {
        entries += current.length;
        if (entries > maximumEntries) return false;
        return current.every((Object? item) => inspect(item, depth + 1));
      }
      if (current is Map<String, Object?>) {
        entries += current.length;
        if (entries > maximumEntries ||
            current.keys.any((String key) => key.trim().isEmpty)) {
          return false;
        }
        return current.values.every((Object? item) => inspect(item, depth + 1));
      }
      return false;
    }

    if (!inspect(value, 0)) {
      throw AiAssistException(
        failureCode,
        'AI structured data exceeds its safety bounds.',
      );
    }
  }

  bool _containsForbiddenRawValue(
    Object? value,
    Set<String> forbiddenRawFragments,
  ) {
    if (value is String) {
      if (_sanitizer(value).redactions.isNotEmpty) return true;
      return forbiddenRawFragments.any(
        (String raw) => raw.length >= 4 && value.contains(raw),
      );
    }
    if (value is List<Object?>) {
      return value.any(
        (Object? item) =>
            _containsForbiddenRawValue(item, forbiddenRawFragments),
      );
    }
    if (value is Map<String, Object?>) {
      return value.values.any(
        (Object? item) =>
            _containsForbiddenRawValue(item, forbiddenRawFragments),
      );
    }
    return false;
  }

  bool _isFallbackEligible(AiAssistFailureCode code) =>
      code == AiAssistFailureCode.timeout ||
      code == AiAssistFailureCode.offline ||
      code == AiAssistFailureCode.gatewayFailure;

  List<AiAssistIssue> _deduplicateIssues(List<AiAssistIssue> source) {
    final Set<AiAssistIssueCode> seen = <AiAssistIssueCode>{};
    return <AiAssistIssue>[
      for (final AiAssistIssue issue in source)
        if (seen.add(issue.code)) issue,
    ];
  }
}

class _SanitizedContext {
  _SanitizedContext({
    required Map<String, Object?> value,
    required Set<AiAssistRedactionKind> redactions,
    required Set<String> redactedOriginals,
  }) : value = freezeAiAssistMap(value),
       redactions = Set<AiAssistRedactionKind>.unmodifiable(redactions),
       redactedOriginals = Set<String>.unmodifiable(redactedOriginals);

  final Map<String, Object?> value;
  final Set<AiAssistRedactionKind> redactions;
  final Set<String> redactedOriginals;
}
