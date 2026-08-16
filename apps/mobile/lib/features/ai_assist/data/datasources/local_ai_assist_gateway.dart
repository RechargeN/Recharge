import '../../../../core/config/provider_cost_policy.dart';
import '../../../../core/telemetry/provider_cost_ledger.dart';
import '../../domain/entities/ai_assist_contract.dart';
import '../../domain/repositories/ai_assist_gateway.dart';

enum LocalAiAssistBehavior {
  success,
  timeout,
  offline,
  gatewayFailure,
  malformedOutput,
}

class LocalAiAssistGateway implements AiAssistGateway {
  LocalAiAssistGateway({
    this.behavior = LocalAiAssistBehavior.success,
    this.providerId = 'local-ai-assist',
    Map<String, Map<String, Object?>>? fixtures,
    Set<String> usedToolIds = const <String>{},
    ProviderCostPolicy? costPolicy,
    ProviderCostLedger? costLedger,
    DateTime Function()? nowUtc,
  }) : fixtures = Map<String, Map<String, Object?>>.unmodifiable(
         <String, Map<String, Object?>>{
           for (final MapEntry<String, Map<String, Object?>> entry
               in (fixtures ?? _defaultFixtures).entries)
             entry.key: freezeAiAssistMap(entry.value),
         },
       ),
       usedToolIds = Set<String>.unmodifiable(usedToolIds),
       _costPolicy =
           costPolicy ??
           ProviderCostPolicy(
             providerId: providerId,
             version: 1,
             costClass: CostClass.zeroCost,
             enabled: true,
             dailyRequestLimit: 0,
           ),
       _costLedger = costLedger ?? InMemoryProviderCostLedger(),
       _nowUtc = nowUtc ?? DateTime.now;

  final LocalAiAssistBehavior behavior;
  final String providerId;
  final Map<String, Map<String, Object?>> fixtures;
  final Set<String> usedToolIds;
  final ProviderCostPolicy _costPolicy;
  final ProviderCostLedger _costLedger;
  final DateTime Function() _nowUtc;

  int invocationCount = 0;
  AiAssistGatewayRequest? lastRequest;

  static final Map<String, Map<String, Object?>> _defaultFixtures =
      <String, Map<String, Object?>>{
        'smart-search-local': <String, Object?>{
          'kind': 'local_demo',
          'conditions': <String, Object?>{},
          'intentLabels': <Object?>[],
        },
        'creator-assist-local': <String, Object?>{
          'kind': 'local_demo',
          'suggestions': <Object?>[],
          'clarifyingQuestions': <Object?>[],
        },
        'quality-assist-local': <String, Object?>{
          'kind': 'local_demo',
          'issues': <Object?>[],
        },
        'translation-assist-local': <String, Object?>{
          'kind': 'local_demo',
          'translations': <String, Object?>{},
        },
      };

  @override
  Future<AiAssistGatewayResponse> execute(
    AiAssistGatewayRequest request,
  ) async {
    if (!_costPolicy.isValid ||
        !_costPolicy.permitsRequests ||
        _costPolicy.costClass != CostClass.zeroCost ||
        _costPolicy.providerId != providerId) {
      throw const AiAssistGatewayException(
        AiAssistFailureCode.gatewayFailure,
        'The local AI cost policy is invalid or disabled.',
      );
    }
    invocationCount++;
    lastRequest = request;
    final DateTime generatedAtUtc = _nowUtc().toUtc();
    _costLedger.record(
      ProviderCostLedgerEntry(
        providerId: providerId,
        operationId: request.operationId,
        costClass: _costPolicy.costClass,
        recordedAtUtc: generatedAtUtc,
      ),
    );

    switch (behavior) {
      case LocalAiAssistBehavior.timeout:
        throw const AiAssistGatewayException(
          AiAssistFailureCode.timeout,
          'The local AI simulator timed out.',
        );
      case LocalAiAssistBehavior.offline:
        throw const AiAssistGatewayException(
          AiAssistFailureCode.offline,
          'The local AI simulator is offline.',
        );
      case LocalAiAssistBehavior.gatewayFailure:
        throw const AiAssistGatewayException(
          AiAssistFailureCode.gatewayFailure,
          'The local AI simulator failed.',
        );
      case LocalAiAssistBehavior.success:
      case LocalAiAssistBehavior.malformedOutput:
        break;
    }

    final Map<String, Object?> payload =
        fixtures[request.definition.id] ??
        const <String, Object?>{
          'kind': 'local_demo',
          'suggestions': <Object?>[],
        };
    return AiAssistGatewayResponse(
      operationId: request.operationId,
      proposalId: 'local-${request.operationId}',
      providerId: providerId,
      capability: request.definition.capability,
      promptDefinitionId: request.definition.id,
      promptVersion: request.definition.version,
      outputSchemaId: behavior == LocalAiAssistBehavior.malformedOutput
          ? '${request.definition.outputSchemaId}.invalid'
          : request.definition.outputSchemaId,
      mode: AiAssistMode.localMock,
      generatedAtUtc: generatedAtUtc,
      confidence: AiAssistConfidence.deterministic,
      structuredPayload: payload,
      evidence: const <AiAssistEvidence>[
        AiAssistEvidence(
          kind: AiAssistEvidenceKind.localRule,
          label: 'Deterministic local fixture',
        ),
      ],
      issues: const <AiAssistIssue>[
        AiAssistIssue(
          code: AiAssistIssueCode.localDemo,
          message: 'Local demo: no external AI or live data were used.',
        ),
      ],
      usedToolIds: usedToolIds,
      usage: AiAssistUsage(
        requestUnits: 1,
        inputCharacters: request.sanitizedInput.length,
        outputFields: payload.length,
        toolCalls: usedToolIds.length,
      ),
    );
  }
}

class InMemoryAiAssistQuotaStore implements AiAssistQuotaStore {
  final Map<AiAssistCapability, int> _usage = <AiAssistCapability, int>{};

  @override
  bool tryConsume(AiAssistCapability capability, {required int limit}) {
    if (limit <= 0) return false;
    final int current = _usage[capability] ?? 0;
    if (current >= limit) return false;
    _usage[capability] = current + 1;
    return true;
  }

  @override
  int usageFor(AiAssistCapability capability) => _usage[capability] ?? 0;
}
