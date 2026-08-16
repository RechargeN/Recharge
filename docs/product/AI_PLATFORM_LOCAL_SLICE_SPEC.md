# RECHARGE — Local AI Assistance Platform Foundation

Версия: v1.0 (2026-08-03).
Статус: **Done**.
Slice: `AI-PLAT-LOCAL-01`.
Runtime: local/mock-only, zero metered calls.

## 1. Цель

Создать общий provider-neutral AI assistance foundation до подключения
настоящей модели. Slice не добавляет пользовательскую AI-функцию и не меняет
Scenario, Place, Smart Search или persisted schemas.

Основание: Accepted ADR 0018 и `AI_PRODUCT_STRATEGY.md`.

## 2. В scope

- отдельный layered-модуль `features/ai_assist`;
- transient request/result envelope без raw input в result;
- capability, locale, prompt/schema version, evidence, confidence, issues и
  bounded usage metadata;
- versioned local prompt registry;
- deterministic email/phone redaction до gateway boundary;
- generic structured payload validation;
- allowlist read-only tool ids;
- local success/timeout/offline/gateway-failure/malformed simulations;
- optional deterministic fallback;
- global/capability kill switches;
- in-memory session quota;
- существующие `ProviderCostPolicy` и `ProviderCostLedger` с
  `CostClass.zeroCost`;
- DI registration и focused unit coverage.

## 3. Не в scope

- OpenAI или другой production provider;
- API keys, backend, Firebase, web или network calls;
- UI и shared visual components;
- интеграция с Scenario, Place, Smart Search или другими consumers;
- persistent prompt, response, quota или telemetry storage;
- модельная модерация, ranking, translation или content generation;
- booking, payment, publication или автоматическая mutation;
- изменение существующих proposal schemas.

## 4. Lifecycle

```text
typed transient input
  -> runtime capability/kill-switch check
  -> exact prompt id + version lookup
  -> deterministic redaction
  -> in-memory quota consume
  -> provider-neutral local gateway
  -> generic envelope/schema/tool validation
  -> typed transient result
```

Feature-specific validation и Apply остаются обязанностью будущего consumer
slice и никогда не заменяются общим validator.

## 5. Контракты

`AiAssistRequest` содержит operation id, capability, prompt id/version,
locale, transient input и bounded typed context.

`AiAssistResult` содержит operation/proposal ids, capability, prompt/schema
versions, local mode, structured payload, evidence, confidence, issues,
used-tool ids, generated-at и usage counters. Raw input отсутствует.

Prompt definition фиксирует capability, version, supported locales,
input/output schema ids, maximum input length, instruction и allowlisted
read-only tools.

## 6. Failure policy

Stable failure codes различают:

- disabled platform/capability;
- invalid request or prompt definition;
- unsupported locale;
- quota exhaustion;
- timeout/offline/gateway failure;
- malformed or oversized output;
- forbidden tool usage;
- missing fallback.

Timeout/offline/gateway failure могут использовать только явно переданный
deterministic fallback gateway. Invalid/malformed output не маскируется
fallback-ом.

## 7. Privacy и cost

- Input не логируется и не возвращается в result.
- Email заменяется на `[email]`, phone-like value — на `[phone]`.
- Context string values проходят ту же redaction.
- Ledger получает только provider id, operation id, cost class и UTC time.
- Local runtime всегда zero-cost; metered/forbidden policy fail-closed.
- Никаких prompt hashes или raw analytics.

## 8. Acceptance criteria

1. Модуль не импортирует Create/Scenario/Place/Discover.
2. Существующие product features не импортируют AI module.
3. Exact prompt id/version/capability/locale проверяются до gateway.
4. Raw email/phone не достигают gateway и отсутствуют в result.
5. Result не может содержать исходный raw input.
6. Payload имеет bounded depth, entries и string lengths.
7. Неallowlisted tool id блокирует result.
8. Kill switch и quota fail closed без gateway call.
9. Local gateway поддерживает deterministic success и typed failures.
10. Fallback явный, deterministic и отмечен issue code.
11. Cost ledger фиксирует zero-cost calls; metered calls равны нулю.
12. Все коллекции результата immutable снаружи.
13. Нет файловой/сетевой/persistent записи.
14. Existing Place, Scenario и Smart Search tests не требуют изменения.
15. `flutter analyze`, полный `flutter test`, boundary и diff checks зелёные.

## 9. Rollback

Удалить DI registration и изолированный `features/ai_assist`. Миграция и
очистка данных не нужны: persisted state отсутствует, consumers не подключены.

## 10. Verification

- focused AI tests: 14 passed;
- `flutter analyze --no-pub`: 0 issues;
- full sequential `flutter test --no-pub --concurrency=1`: 539 passed;
- boundary gate: passed with 59 existing allowlist suppressions;
- scoped `git diff --check`: passed.
