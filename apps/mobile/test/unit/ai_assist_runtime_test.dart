import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/provider_cost_policy.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/telemetry/provider_cost_ledger.dart';
import 'package:recharge/features/ai_assist/application/ai_assist_coordinator.dart';
import 'package:recharge/features/ai_assist/application/ai_assist_runtime_config.dart';
import 'package:recharge/features/ai_assist/data/datasources/local_ai_assist_gateway.dart';
import 'package:recharge/features/ai_assist/data/datasources/local_ai_prompt_registry.dart';
import 'package:recharge/features/ai_assist/domain/entities/ai_assist_contract.dart';
import 'package:recharge/features/ai_assist/domain/repositories/ai_assist_gateway.dart';
import 'package:recharge/features/ai_assist/domain/usecases/execute_ai_assist_usecase.dart';

void main() {
  group('ExecuteAiAssistUseCase', () {
    test('passes only redacted input and context to the gateway', () async {
      final LocalAiAssistGateway gateway = LocalAiAssistGateway(
        nowUtc: () => DateTime.utc(2026, 8, 3),
      );
      final ExecuteAiAssistUseCase execute = _execute(gateway: gateway);

      final AiAssistResult result = await execute(
        _request(
          input: 'Contact alice@example.com for a quiet place.',
          context: <String, Object?>{'phone': '+371 20 000 000'},
        ),
        policy: _policy(),
      );

      expect(gateway.lastRequest!.sanitizedInput, contains('[email]'));
      expect(gateway.lastRequest!.sanitizedInput, isNot(contains('alice@')));
      expect(gateway.lastRequest!.sanitizedContext['phone'], '[phone]');
      expect(
        result.issues.map((AiAssistIssue value) => value.code),
        contains(AiAssistIssueCode.personalDataRedacted),
      );
      expect(result.generatedAtUtc.isUtc, isTrue);
    });

    test(
      'kill switch and capability gate stop before gateway invocation',
      () async {
        final LocalAiAssistGateway gateway = LocalAiAssistGateway();
        final ExecuteAiAssistUseCase execute = _execute(gateway: gateway);

        await _expectFailure(
          execute(_request(), policy: _policy(platformEnabled: false)),
          AiAssistFailureCode.platformDisabled,
        );
        await _expectFailure(
          execute(
            _request(),
            policy: _policy(enabledCapabilities: const <AiAssistCapability>{}),
          ),
          AiAssistFailureCode.capabilityDisabled,
        );
        expect(gateway.invocationCount, 0);
      },
    );

    test(
      'quota is consumed once and fails closed before another call',
      () async {
        final LocalAiAssistGateway gateway = LocalAiAssistGateway();
        final InMemoryAiAssistQuotaStore quota = InMemoryAiAssistQuotaStore();
        final ExecuteAiAssistUseCase execute = _execute(
          gateway: gateway,
          quotaStore: quota,
        );

        await execute(_request(), policy: _policy(sessionRequestLimit: 1));
        await _expectFailure(
          execute(
            _request(operationId: 'op-2'),
            policy: _policy(sessionRequestLimit: 1),
          ),
          AiAssistFailureCode.quotaExceeded,
        );

        expect(quota.usageFor(AiAssistCapability.smartSearch), 1);
        expect(gateway.invocationCount, 1);
      },
    );

    test(
      'uses explicit deterministic fallback only for eligible failure',
      () async {
        final LocalAiAssistGateway primary = LocalAiAssistGateway(
          behavior: LocalAiAssistBehavior.timeout,
        );
        final LocalAiAssistGateway fallback = LocalAiAssistGateway(
          providerId: 'local-ai-fallback',
        );
        final ExecuteAiAssistUseCase execute = _execute(
          gateway: primary,
          fallbackGateway: fallback,
        );

        final AiAssistResult result = await execute(
          _request(),
          policy: _policy(),
        );

        expect(result.providerId, 'local-ai-fallback');
        expect(
          result.issues.map((AiAssistIssue value) => value.code),
          contains(AiAssistIssueCode.fallbackUsed),
        );
        expect(primary.invocationCount, 1);
        expect(fallback.invocationCount, 1);
      },
    );

    test('returns typed timeout when fallback is disabled', () async {
      final ExecuteAiAssistUseCase execute = _execute(
        gateway: LocalAiAssistGateway(behavior: LocalAiAssistBehavior.timeout),
      );

      await _expectFailure(
        execute(_request(), policy: _policy(fallbackEnabled: false)),
        AiAssistFailureCode.timeout,
      );
    });

    test(
      'rejects malformed envelopes and tools outside the allowlist',
      () async {
        await _expectFailure(
          _execute(
            gateway: LocalAiAssistGateway(
              behavior: LocalAiAssistBehavior.malformedOutput,
            ),
          )(_request(), policy: _policy()),
          AiAssistFailureCode.malformedOutput,
        );
        await _expectFailure(
          _execute(
            gateway: LocalAiAssistGateway(
              usedToolIds: const <String>{'web.search'},
            ),
          )(_request(operationId: 'op-tools'), policy: _policy()),
          AiAssistFailureCode.forbiddenTool,
        );
      },
    );

    test(
      'rejects oversized payloads and raw personal input in output',
      () async {
        await _expectFailure(
          _execute(
            gateway: LocalAiAssistGateway(
              fixtures: <String, Map<String, Object?>>{
                'smart-search-local': <String, Object?>{
                  'one': 1,
                  'two': 2,
                  'three': 3,
                },
              },
            ),
          )(
            _request(operationId: 'op-large'),
            policy: _policy(maximumPayloadEntries: 2),
          ),
          AiAssistFailureCode.outputTooLarge,
        );
        const String raw = 'Contact alice@example.com';
        await _expectFailure(
          _execute(
            gateway: LocalAiAssistGateway(
              fixtures: <String, Map<String, Object?>>{
                'smart-search-local': <String, Object?>{
                  'echo': 'alice@example.com',
                },
              },
            ),
          )(
            _request(operationId: 'op-raw', input: raw),
            policy: _policy(),
          ),
          AiAssistFailureCode.malformedOutput,
        );
      },
    );

    test('records local requests without any metered calls', () async {
      final InMemoryProviderCostLedger ledger = InMemoryProviderCostLedger();
      final LocalAiAssistGateway gateway = LocalAiAssistGateway(
        costLedger: ledger,
        costPolicy: const ProviderCostPolicy(
          providerId: 'local-ai-assist',
          version: 1,
          costClass: CostClass.zeroCost,
          enabled: true,
          dailyRequestLimit: 0,
        ),
        nowUtc: () => DateTime.utc(2026, 8, 3),
      );

      await _execute(gateway: gateway)(_request(), policy: _policy());

      expect(ledger.entries, hasLength(1));
      expect(ledger.entries.single.operationId, 'op-1');
      expect(ledger.meteredCallCount, 0);
    });
  });

  test(
    'coordinator exposes enabled prompts and generates operation ids',
    () async {
      final LocalAiPromptRegistry registry = LocalAiPromptRegistry();
      final LocalAiAssistGateway gateway = LocalAiAssistGateway();
      final AiAssistRuntimeConfig config = AiAssistRuntimeConfig();
      final AiAssistCoordinator coordinator = AiAssistCoordinator(
        executeAiAssist: _execute(gateway: gateway, registry: registry),
        promptRegistry: registry,
        idGenerator: _FixedIdGenerator('generated-op'),
        config: config,
      );

      expect(coordinator.isEnabled(AiAssistCapability.smartSearch), isTrue);
      expect(
        coordinator.availablePrompts(AiAssistCapability.smartSearch),
        hasLength(1),
      );
      final AiAssistResult result = await coordinator.execute(
        capability: AiAssistCapability.smartSearch,
        promptDefinitionId: 'smart-search-local',
        promptVersion: 1,
        locale: AiAssistLocale.en,
        input: 'quiet Riga',
      );
      expect(result.operationId, 'generated-op');
    },
  );
}

ExecuteAiAssistUseCase _execute({
  required LocalAiAssistGateway gateway,
  LocalAiPromptRegistry? registry,
  InMemoryAiAssistQuotaStore? quotaStore,
  AiAssistGateway? fallbackGateway,
}) => ExecuteAiAssistUseCase(
  promptRegistry: registry ?? LocalAiPromptRegistry(),
  gateway: gateway,
  fallbackGateway: fallbackGateway,
  quotaStore: quotaStore ?? InMemoryAiAssistQuotaStore(),
);

AiAssistRequest _request({
  String operationId = 'op-1',
  String input = 'quiet Riga',
  Map<String, Object?> context = const <String, Object?>{},
}) => AiAssistRequest(
  operationId: operationId,
  capability: AiAssistCapability.smartSearch,
  promptDefinitionId: 'smart-search-local',
  promptVersion: 1,
  locale: AiAssistLocale.en,
  input: input,
  context: context,
);

AiAssistExecutionPolicy _policy({
  bool platformEnabled = true,
  Set<AiAssistCapability> enabledCapabilities = const <AiAssistCapability>{
    AiAssistCapability.smartSearch,
  },
  int sessionRequestLimit = 10,
  int maximumPayloadEntries = 20,
  bool fallbackEnabled = true,
}) => AiAssistExecutionPolicy(
  platformEnabled: platformEnabled,
  enabledCapabilities: enabledCapabilities,
  sessionRequestLimit: sessionRequestLimit,
  maximumContextEntries: 20,
  maximumPayloadEntries: maximumPayloadEntries,
  maximumNestingDepth: 5,
  maximumStringCharacters: 500,
  fallbackEnabled: fallbackEnabled,
);

Future<void> _expectFailure(
  Future<AiAssistResult> future,
  AiAssistFailureCode code,
) => expectLater(
  future,
  throwsA(
    isA<AiAssistException>().having(
      (AiAssistException value) => value.code,
      'code',
      code,
    ),
  ),
);

class _FixedIdGenerator implements IdGenerator {
  _FixedIdGenerator(this.value);

  final String value;

  @override
  String generate() => value;
}
