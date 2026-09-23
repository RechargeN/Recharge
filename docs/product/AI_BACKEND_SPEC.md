# Recharge Backend — AI Assistance Platform Specification

- ID: **BCK-15**
- Version: **0.3**
- Date: **2026-09-21**
- Spec status: **Draft — Present; provider, Security/Privacy, Legal and Operations review pending**
- Runtime status: **Absent — local/mock zero-cost foundation only**
- Accountable owner: **AI Platform owner**
- Coordination baseline: [BCK-02 v2.4.82](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Delivery stage: **D5 / R9 — gated and not required for Latvia GA**

## 0. Changelog

### v0.3 — 2026-09-21

- completed the Stage 5 provider-neutral gateway contract for prompts, tools,
  redaction, validation, quotas, cost and evaluation;
- fixed deterministic fallback, kill switches and proposal-only authority;
- retained the production-provider ADR, provider, privacy, budget, network and
  activation gates without creating live AI runtime.

### v0.2 — 2026-09-20

- added the Stage 2 normalized AI entity inventory;
- made AI proposal-only authority, provider separation, privacy, cost and
  deterministic fallback explicit;
- preserved all provider/network/runtime gates.

### v0.1 — 2026-09-20

- created the first canonical backend contract for provider-neutral AI assistance;
- inherited Accepted ADR 0018 and the local/mock foundation without promoting
  either into production-provider authority;
- defined server proxy, prompt/tool registry, redaction, schema validation,
  quota/cost ledger, evaluation, fallback and kill-switch boundaries;
- kept AI output transient, non-authoritative and incapable of direct mutation.

## 1. Verdict and status semantics

BCK-15 is a design contract, not permission to select a vendor, store a secret,
send personal data, make metered calls, deploy an endpoint or activate an AI use
case. ADR 0018 requires a later Accepted production-provider ADR before any live
provider call. `Draft` remains fail-closed until that ADR and the exact provider,
use case, data path, terms, residency, retention, evaluation thresholds, budgets
and operations are accepted through the required gates.

`AI-PLAT-LOCAL-01` is Done only as deterministic local/mock evidence. It has no
network, persistence, production provider or consumer integration and therefore
does not prove BCK-15 runtime readiness.

## 2. Parents, priority and reconciliation

BCK-15 inherits without silently overriding:

1. [ADR 0018](../adr/0018-provider-neutral-ai-assistance-capability.md) and all
   other Accepted ADRs;
2. the frozen [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md),
   [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md) and
   [BCK-02](RECHARGE_BACKEND_DELIVERY_MAP.md);
3. [BCK-03](BACKEND_API_CONTRACT_STANDARD.md),
   [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md),
   [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md),
   [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md),
   [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md),
   [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md) and
   [BCK-21](ANALYTICS_TELEMETRY_BACKEND_SPEC.md);
4. [AI Product Strategy](AI_PRODUCT_STRATEGY.md) and
   [local AI foundation](AI_PLATFORM_LOCAL_SLICE_SPEC.md);
5. use-case specifications, implementation notes and local/mock behavior.

Once Approved, BCK-15 owns the cross-feature AI platform boundary. Each product
domain still owns its proposal schema, deterministic validation and apply
command. BCK-15 never overrides an owning domain or Accepted policy.

## 3. Outcome and non-goals

### 3.1 Outcome

BCK-15 defines a replaceable server-side capability that accepts minimized
typed input, selects an accepted prompt/tool/provider configuration, redacts
before the provider boundary, enforces quota/cost/security policy, validates
structured output and returns a typed transient proposal with evidence/issues.

### 3.2 Non-goals

BCK-15 does not:

- own Scenario, Place, Search, Event, Booking, Review or other aggregates;
- create a role, workspace, catalog entity, Create type or chat product;
- apply, publish, book, pay, sanction or destructively mutate anything;
- grant direct Firestore, internet, provider, secret or UI access to a model;
- select a vendor/model, authorize web scraping or claim training/retention;
- remove deterministic/manual fallbacks;
- authorize Firebase, provider credentials, deployment or production traffic.

## 4. Scope

### 4.1 In scope

- provider-neutral request/result gateway and server proxy;
- versioned capability, prompt, schema and read-tool registries;
- deterministic minimization/redaction before any provider call;
- structured-output, evidence and tool-use validation;
- server-owned quota reservation and cost settlement ledger;
- timeout/retry/fallback/circuit/kill-switch behavior;
- versioned evaluation suites, run metadata and rollout thresholds;
- privacy-safe operational evidence, DSR and incident boundaries;
- per-use-case/per-market/per-locale activation and rollback.

### 4.2 Disabled until later gates

- every production provider/model and metered call;
- persistent raw prompt, provider response, chain-of-thought or private context;
- arbitrary web/browser/code execution or write-capable tools;
- model-driven ranking, moderation or personalization without separate contract;
- automatic product mutation/publication/booking/payment;
- training/fine-tuning on Recharge user data;
- hidden replacement of Search/Create/manual flows.

## 5. Ownership and single writers

| Record/config | Authoritative writer | Consumers |
|---|---|---|
| `AiCapabilityDefinition` | AI Platform config workflow | Proxy/mobile facade/ops |
| `AiPromptDefinition` / tool allowlist | AI Platform prompt workflow | AI proxy/evaluation |
| `AiRequestReceipt` | AI orchestration service | Actor/support/audit |
| `AiQuotaLedgerEntry` | AI quota service | Proxy/operations |
| `AiCostLedgerEntry` | AI cost service | Finance/operations |
| `AiEvaluationSuite` / result metadata | AI evaluation workflow | Release reviewers |
| Provider credentials/model account | BCK-05 secret/IAM workflow | Exact AI gateway identity |
| Product proposal schema/validation | Owning product domain | AI facade returns candidate only |
| Product aggregate mutation | Owning domain command | Explicit user action only |
| Product analytics | BCK-21 | Cataloged minimized events only |

Mobile never calls a production AI provider directly. Product features access
AI through an app-level facade/port and cannot import a provider SDK or gain
cross-feature authority.

## 6. Actors, capabilities and trust boundaries

| Actor/service | Allowed | Denied |
|---|---|---|
| Authenticated User | Invoke enabled use case within policy | Provider/model selection or secret access |
| Product application service | Supply typed minimized context | Raw repository/Firestore access for model |
| AI proxy | Orchestrate exact accepted definition | Product mutation or broad data read |
| Read-tool adapter | Execute exact allowlisted bounded query | Writes, arbitrary URLs or capability expansion |
| Provider gateway | Send redacted request/receive output | Persist Recharge authority |
| Evaluation runner | Run approved non-production fixtures | Production personal-data replay |
| Operator | Manage flags/budgets through audited workflow | Read raw prompts/responses by default |
| Support/Admin | BCK-19 scoped receipt access | Impersonation or prompt/content browsing |

Authorization is checked before quota reservation and again for any protected
read-tool call. Provider success never grants a product capability.

## 7. Data classification and minimization

| Data | Class | Storage rule |
|---|---|---|
| Raw user intent/context | Private, possibly sensitive | Transient only; BCK-15 persistence prohibited |
| Redacted provider input | Restricted transient | Transient only in Recharge |
| Raw provider output | Untrusted restricted transient | Validate then discard; no BCK-15 persistence |
| Typed proposal | Private transient | Consumer may persist only through domain command |
| Prompt/schema/tool definitions | Internal config | Versioned/audited |
| Quota/cost receipt | Operational/protected | IDs, counters and amounts; no raw content |
| Evaluation fixture/result | Internal/restricted | Synthetic/approved data only |
| Logs/metrics | Operational minimized | Codes, latency, versions and counters only |

Exact private locations, Booking references, contacts, notes and sensitive
profile attributes are excluded unless an accepted use-case purpose contract
explicitly allows a minimized representation. Absence of a rule means exclude.

## 8. Canonical model

```text
AiCapabilityDefinition {
  capabilityId, version, useCaseId, supportedMarkets[], supportedLocales[],
  inputSchemaRef, outputSchemaRef, promptRef, allowedToolRefs[],
  providerPolicyRef, quotaPolicyRef, evaluationPolicyRef,
  status, enabledFromUtc?, disabledAtUtc?
}

AiPromptDefinition {
  promptId, version, capabilityId, instructionTemplate,
  inputSchemaRef, outputSchemaRef, allowedToolRefs[],
  maxInputBytes, maxOutputBytes, policyRefs[], contentHash, status
}

AiRequestReceipt {
  requestId, operationId, actorUserId, capabilityId, definitionVersion,
  marketId, locale, providerRef?, modelRef?, promptVersion,
  status, failureCode?, fallbackCode?, usageSummary,
  inputClassificationSummary, createdAtUtc, completedAtUtc?
}

AiQuotaLedgerEntry {
  quotaEntryId, actorScopeHash, capabilityId, periodKey,
  reservedUnits, settledUnits, status, operationId, createdAtUtc
}

AiCostLedgerEntry {
  costEntryId, requestId, providerRef, modelRef, currency,
  estimatedMinorUnits, actualMinorUnits?, usageCounters,
  settlementStatus, observedAtUtc
}

AiEvaluationSuite {
  suiteId, version, capabilityId, fixtureManifestHash,
  metricDefinitions[], thresholds[], localeMarketMatrix[], status
}
```

Receipts never contain raw input, raw output, full prompt, tool response, secret,
chain-of-thought or hidden provider metadata.

## 9. Request lifecycle

```text
typed request
  -> authenticate/authorize/flag/policy check
  -> exact capability + prompt + schema lookup
  -> minimize and redact
  -> quota/cost reservation
  -> bounded read-only tools (if requested and allowed)
  -> provider-neutral gateway
  -> envelope/schema/tool/evidence validation
  -> consumer-specific deterministic validation
  -> typed transient proposal/issue/failure
  -> explicit user confirmation
  -> normal owning-domain command
```

The AI platform ends before the owning-domain command. A provider response,
confidence score or evaluation pass never becomes authoritative state.

## 10. Prompt, schema and tool registry

Prompt definitions are immutable by version, content-addressed and linked to
exact input/output schemas, locale/market support and allowed read tools. Draft,
review, active, suspended and retired states are distinct. Only one explicitly
activated compatible definition is used for a request cohort.

Tool definitions declare ID/version, owning service, input/output schema,
allowed data classes, result size, timeout, freshness and privacy class. The
model cannot invent a tool, URL, collection, query or wider scope. Tool output
is untrusted context and is re-sanitized; prompt injection cannot modify policy.

## 11. Redaction and privacy boundary

Minimization occurs before redaction; redaction occurs before tools/provider.
Deterministic processors cover email, phone-like values, tokens/secrets,
unneeded names/identifiers and use-case-specific sensitive fields. Both direct
input and nested context/tool output follow the same bounded policy.

Redaction records policy/version and safe counts, not original values. If a
required meaning cannot survive minimization, the request fails with a typed
privacy/purpose error rather than sending raw data. Reversible redaction maps
are prohibited unless a separate accepted use case requires a protected,
short-lived server-only mapping.

## 12. Provider gateway and isolation

The domain/application layers depend on an `AiProviderGateway` contract, never
a vendor SDK. The adapter owns vendor serialization, authentication, timeout,
usage mapping and error normalization. Provider SDK/data types do not escape
the adapter.

Production credentials exist only in accepted Secret Manager/IAM bindings and
are unavailable to mobile, prompts, tools, logs and fixtures. Every request pins
provider/model/policy revisions. Data residency, subprocessors, retention,
training use, safety, terms and deletion evidence are gates, not assumptions.

## 13. Structured output and evidence validation

The generic validator enforces payload bytes, nesting, entries, string lengths,
closed enums, schema version, tool IDs and evidence shape. It rejects executable
content, hidden instructions, unknown authoritative IDs and forbidden URLs.

The consumer then resolves permanent IDs, freshness and hard constraints using
its own deterministic validator. Unresolved names/coordinates remain candidates,
not entity references. Evidence/confidence classes never upgrade themselves:
model confidence cannot turn `estimated` into `officialSource` or
`verifiedProvider`.

## 14. Quota and cost ledger

Quota is server-owned by actor/account/capability/market/cohort and supports
per-request, rolling/daily and monthly budgets. A request reserves before the
provider call and settles/release-adjusts exactly once. Retries with the same
operation ID do not double charge quota or ledger entries.

Cost uses integer minor units and ISO currency. Estimate/actual and provider
usage counters are distinguishable. Missing or ambiguous billing evidence fails
closed according to policy. Budget alerts and hard kill thresholds are accepted
under BCK-05; product code cannot raise them.

## 15. Commands, queries and typed outcomes

Commands:

- `ExecuteAiAssistance`, `CancelAiAssistance`;
- `ReserveAiQuota`, `SettleAiUsage` (internal only);
- `RegisterPromptDefinition`, `ActivatePromptDefinition`, `SuspendPromptDefinition`;
- `RegisterEvaluationSuite`, `RecordEvaluationRun`;
- registered flag/budget/emergency actions through BCK-05.

Queries:

- enabled capability descriptor for an authenticated consumer;
- own bounded request status/receipt;
- capability/prompt/evaluation registry for authorized operators;
- quota/cost aggregate without raw request content.

Typed failures include:

```text
unauthenticated, permission_denied, not_found, capability_disabled,
market_disabled, unsupported_locale, unsupported_version,
prompt_unavailable, schema_invalid, input_too_large,
privacy_policy_blocked, forbidden_tool, tool_unavailable,
quota_exhausted, budget_exhausted, provider_disabled,
provider_timeout, provider_rate_limited, provider_unavailable,
malformed_output, oversized_output, insufficient_evidence,
validation_failed, fallback_unavailable, cancelled,
idempotency_conflict, temporarily_unavailable
```

## 16. Contract versions and compatibility

Request carries contract version, operation ID, capability/use-case, exact or
compatible definition request, locale/market and typed context. Response carries
request/proposal ID, schema/prompt/provider/model versions, evidence/issues,
usage summary, fallback marker and generated time.

Unknown/newer schema, prompt, tool, model-policy or enum values fail closed.
Breaking changes require versioned schemas, fixture/evaluation migration,
minimum-client policy and rollback. Retired prompt/model versions remain
traceable in historical receipts but cannot accept new traffic.

## 17. Persistence, transactions and idempotency

Definitions, receipts, quota ledger, cost ledger, evaluation metadata, audit and
outbox are separate. Raw prompts, provider outputs and tool payloads are never
BCK-15 persistence records. Debugging uses synthetic/reproducible fixtures and
bounded codes. Any future raw-content capture requires a superseding Accepted
ADR and a separate qualified privacy/security/legal boundary; this v0.1 does not
permit it.

Request reservation atomically creates/returns idempotency receipt plus quota
reservation. Settlement is compare-and-set and exactly-once per provider
attempt/result. Same key with changed canonical request hash returns conflict.
Stale workers cannot settle or return a superseded/cancelled request.

## 18. Retries, fallback and degraded states

Retries are bounded, jittered and allowed only for classified transient errors;
they reuse operation/request identity. No retry occurs for privacy, schema,
policy, forbidden-tool or malformed-output failures. Circuit breaker and
provider/use-case kill switches prevent retry storms.

Fallback is explicit, deterministic and typed. It may use the existing manual,
rule-based or local deterministic path; it never masks invalid/malicious output
as success. AI outage cannot block the core non-AI product flow. Offline mobile
does not queue hidden future AI calls.

## 19. Evaluation and release evidence

Each use case has versioned representative fixtures for ID/schema adherence,
grounding, hard constraints, unavailable objects, timezone/DST, Money/unknowns,
prompt injection, privacy leakage, provider failure and supported locales/markets.
Fixtures are synthetic or explicitly approved; production prompts are not copied
into evaluation by default.

Thresholds compare useful accepted results, blocker/leakage/hallucination rates,
latency and cost against a deterministic baseline. A model/prompt/provider
change runs shadow/offline evaluation before cohort. Increased call volume alone
is not success. Failed threshold blocks activation and triggers rollback.

## 20. Events, outbox and analytics separation

After Accepted OD-09 and authorization, minimized events may include:

- `ai.requestCompleted`, `ai.requestFailed`, `ai.fallbackUsed`;
- `ai.quotaThresholdReached`, `ai.budgetThresholdReached`;
- `ai.evaluationCompleted`, `ai.definitionActivated`.

Events include IDs, versions, bounded codes, latency/usage buckets and cost
class, never raw input/output/tool content. Outbox is atomic with receipt/config
state. Product analytics uses BCK-21 cataloged events and consent; operational
metrics/cost/audit are not silently repurposed as behavior analytics.

## 21. Privacy, retention, DSR and provider terms

Every use case documents purpose, legal basis where applicable, data classes,
minimization, provider/subprocessor path, region, retention/deletion, DSR,
training-use policy and user disclosure. Absence of binding evidence means no
production transfer.

DSR identifies persisted receipts/metadata without reconstructing transient
prompts. Provider deletion/retention obligations and support/debug access are
verified contractually and operationally. Numeric retention for receipts,
ledger, evaluation and any exceptional capture is accepted under BCK-04 before
production processing.

## 22. Security, abuse and prompt-injection controls

Controls include authenticated actor, App Check signal, per-scope rates,
payload bounds, injection-resistant separation, closed read-tool allowlist,
output validation, URL/domain policy, SSRF prevention, egress allowlist, secret
isolation, provider account limits and anomaly/abuse monitoring. App Check and
provider moderation never replace authorization or Recharge policy.

Provider/tool content is hostile input. It cannot change system policy, grant a
tool, request secrets, trigger a write or suppress validation. Suspicious input
produces bounded telemetry and typed failure; raw content is not copied to logs.

## 23. Observability, SLO and cost

Operational signals include request outcomes, stage latency, tool/provider
failures, quota/budget state, schema/evidence blockers, fallback/circuit/kill
state, evaluation drift and cost per accepted result. Dimensions use IDs and
bounded codes; prompts, proposals and personal context are prohibited.

BCK-05 accepts numeric timeout, availability, alert, concurrency and budget
thresholds before runtime. Metrics distinguish provider success from validated
proposal success and final user-confirmed domain outcome.

## 24. Flags, rollout, rollback and emergency disable

Server-owned flags are independent by platform, provider, model, use case,
market, locale and cohort; all default off. Mobile display is not activation.
Rollout proceeds evaluation -> internal synthetic -> staff test -> bounded
consenting cohort -> wider cohort only with accepted evidence.

Rollback disables new calls, stops tool/provider egress, returns deterministic
fallback, settles/cancels reservations safely and preserves audit/ledger. It
does not remove manual flows or mutate product aggregates. Provider compromise
rotates/revokes credentials and triggers BCK-05/BCK-04 incident paths.

## 25. Migration and mobile integration

Local/mock definitions and zero-cost ledger are compatibility evidence, not
production data to upload. Mobile adopts BCK-15 only through a consumer domain
port/app-level facade under BCK-18. No product feature imports a provider SDK or
the AI feature directly across frozen feature boundaries.

Client cutover is capability/version negotiated and reversible. Unsupported or
offline clients keep deterministic/manual behavior. No existing proposal or
aggregate is rewritten merely because AI becomes available.

## 26. Conditional implementation file map

No file is authorized by this document alone. An Approved slice may create:

```text
packages/api_contracts/schemas/ai/
packages/api_contracts/fixtures/ai/
apps/backend/functions/src/modules/ai/domain/
apps/backend/functions/src/modules/ai/application/
apps/backend/functions/src/modules/ai/data/
apps/backend/functions/src/modules/ai/transport/
apps/backend/functions/src/modules/ai/providers/
apps/backend/functions/src/modules/ai/tools/
apps/backend/functions/src/modules/ai/evaluation/
apps/backend/functions/test/contract/ai/
apps/backend/functions/test/emulator/ai/
```

Provider-specific code stays behind adapters. Generated files are generator-only.
Mobile consumer adapters are defined by their separate Approved use-case slices.

## 27. Test and evidence matrix

| Area | Required evidence |
|---|---|
| Contract | request/result/schema/version fixtures and unknown-value failure |
| Privacy | minimization/redaction/leakage/DSR/provider-retention evidence |
| Tools | allowlist, scope, injection, bounds, freshness and zero writes |
| Authorization | user/use-case/market/capability/revocation |
| Quota/cost | reserve/settle/retry/duplicate/budget/currency accuracy |
| Provider | timeout/rate/error mapping, egress/secrets, circuit and rotation |
| Validation | malformed/oversized/evidence/ID/domain hard constraints |
| Evaluation | en/ru/lv and enabled Baltic locales/markets, baseline thresholds |
| Emulator | transactions, Rules/IAM, idempotency, outbox and flags |
| Resilience | retry storm, worker crash, provider/tool outage and fallback |
| Security | prompt injection, SSRF, secret request, hostile tool/provider content |
| Load/cost | concurrency, token/byte/tool limits and hard budget stop |
| End-to-end | request -> proposal -> preview -> explicit domain command |

Unrun, timed-out, unsigned or environment-blocked checks are `Inconclusive`.

## 28. Dependency and delivery gates

Approval requires ADR 0018 conformance, applicable BCK-03/04/05/06/18/20/21
boundaries, accepted use-case specification, non-AI fallback, provider/data/legal
decision, independent Security/Privacy review, cost/operations ownership and
representative evaluation thresholds. Live provider runtime additionally
requires the later Accepted production-provider ADR mandated by ADR 0018.

Runtime requires R9 entry and an exact Approved provider/use-case slice. A new
provider/model, new data class, write-capable tool or automated high-impact use
requires a new bounded decision/ADR where applicable. BCK-15 is not required for
Latvia GA and cannot block core manual product operation.

## 29. Definition of Ready

BCK-15 is ready for formal review when:

- platform versus consumer-domain ownership is accepted;
- provider/data/tool/prompt/quota/evaluation paths are fully inventoried;
- every use case names deterministic/manual fallback;
- Security/Privacy/Legal/Operations/API/Mobile reviewers are assigned;
- every open decision has owner, fail-closed default and target gate.

## 30. Definition of Done

BCK-15 becomes `Approved` only after current attributable reviews, resolved
blocking decisions, exact contracts/slices, traceable AC/evidence and atomic
BCK-01/BCK-02/LAUNCH_STATUS reconciliation. Runtime Done remains separate and
requires code, green tests, provider evidence, rollback and activation approval.

## 31. Acceptance criteria

1. **BCK-15-AC-01:** AI remains assistance, never product authority.
2. **BCK-15-AC-02:** AI owns no product aggregate or direct mutation.
3. **BCK-15-AC-03:** Every persisted change uses an owning-domain command.
4. **BCK-15-AC-04:** Explicit user confirmation precedes product mutation.
5. **BCK-15-AC-05:** Manual/deterministic flows remain available when disabled.
6. **BCK-15-AC-06:** Mobile contains no production provider SDK/credential.
7. **BCK-15-AC-07:** Product features use domain ports/app-level facade.
8. **BCK-15-AC-08:** Provider types never escape the adapter.
9. **BCK-15-AC-09:** Raw input/output is transient and never persisted by BCK-15.
10. **BCK-15-AC-10:** Receipts/ledgers/logs exclude raw content.
11. **BCK-15-AC-11:** Minimization precedes redaction and provider/tool calls.
12. **BCK-15-AC-12:** Nested context/tool output receives the same safeguards.
13. **BCK-15-AC-13:** Unpreservable privacy meaning fails closed.
14. **BCK-15-AC-14:** Provider training/retention is never assumed.
15. **BCK-15-AC-15:** Prompt definitions are immutable/versioned/content-addressed.
16. **BCK-15-AC-16:** Prompt activation is explicit and auditable.
17. **BCK-15-AC-17:** Tool allowlist is closed, versioned and read-only.
18. **BCK-15-AC-18:** Tool/provider content cannot expand permissions.
19. **BCK-15-AC-19:** Arbitrary URL/collection/query access is prohibited.
20. **BCK-15-AC-20:** Structured output has strict schema/resource bounds.
21. **BCK-15-AC-21:** Unknown IDs remain unresolved candidates.
22. **BCK-15-AC-22:** Model confidence cannot upgrade source authority.
23. **BCK-15-AC-23:** Consumer deterministic validation is mandatory.
24. **BCK-15-AC-24:** Unknown newer schemas/policies fail closed.
25. **BCK-15-AC-25:** Breaking changes require migration/client/eval evidence.
26. **BCK-15-AC-26:** Quota is reserved before a provider call.
27. **BCK-15-AC-27:** Quota/cost settlement is exactly once.
28. **BCK-15-AC-28:** Idempotent retries do not double charge.
29. **BCK-15-AC-29:** Cost uses integer minor units and ISO currency.
30. **BCK-15-AC-30:** Budget uncertainty follows fail-closed policy.
31. **BCK-15-AC-31:** Retries are bounded to classified transient errors.
32. **BCK-15-AC-32:** Policy/schema/privacy failures are never retried.
33. **BCK-15-AC-33:** Circuit breakers and kill switches prevent retry storms.
34. **BCK-15-AC-34:** Fallback is explicit, deterministic and typed.
35. **BCK-15-AC-35:** Invalid/malicious output is not masked as fallback success.
36. **BCK-15-AC-36:** Offline clients do not queue hidden future AI calls.
37. **BCK-15-AC-37:** Evaluation fixtures use synthetic/approved data.
38. **BCK-15-AC-38:** Evaluation covers IDs, grounding and hard constraints.
39. **BCK-15-AC-39:** Evaluation covers privacy, injection and provider failure.
40. **BCK-15-AC-40:** Evaluation covers supported locales/markets and DST/Money.
41. **BCK-15-AC-41:** Activation thresholds compare deterministic baseline.
42. **BCK-15-AC-42:** Provider/model/prompt change re-runs applicable evaluation.
43. **BCK-15-AC-43:** Increased call volume alone is not success.
44. **BCK-15-AC-44:** Outbox/analytics payloads exclude raw content.
45. **BCK-15-AC-45:** Product analytics and operational telemetry stay separate.
46. **BCK-15-AC-46:** DSR does not reconstruct transient prompts.
47. **BCK-15-AC-47:** Numeric retention is accepted before production processing.
48. **BCK-15-AC-48:** Provider transfer requires terms/residency/deletion evidence.
49. **BCK-15-AC-49:** App Check/provider moderation never replaces authorization.
50. **BCK-15-AC-50:** Prompt injection cannot trigger writes or reveal secrets.
51. **BCK-15-AC-51:** Egress/SSRF/secrets are allowlisted and isolated.
52. **BCK-15-AC-52:** Logs contain bounded IDs/codes, not prompts/proposals.
53. **BCK-15-AC-53:** Metrics distinguish provider and validated/user outcomes.
54. **BCK-15-AC-54:** Numeric SLO/cost limits require BCK-05 acceptance.
55. **BCK-15-AC-55:** Provider/use-case/market/locale flags default off.
56. **BCK-15-AC-56:** Rollback preserves manual flows and settles reservations.
57. **BCK-15-AC-57:** Provider compromise revokes/rotates exact credentials.
58. **BCK-15-AC-58:** No AI output auto-publishes, books, pays or sanctions.
59. **BCK-15-AC-59:** Production AI is not required for Latvia GA.
60. **BCK-15-AC-60:** Documentation acceptance authorizes no provider/runtime.

## 32. Explicit unimplemented list and owner decisions

Unimplemented:

- backend schemas, fixtures, proxy, registries, quota/cost ledger and evaluation;
- provider adapter/account/credential, IAM, egress and secrets;
- consumer adapters and production use cases;
- persistent Rules/indexes/outbox/observability;
- provider/privacy/legal/cost evidence, SLOs and rollout.

Required decisions:

| Decision | Owner | Fail-closed default | Gate |
|---|---|---|---|
| Exact provider/model/account/region/terms | AI + Legal/Security | all live providers disabled | Runtime slice |
| Use-case data/purpose/retention/training policy | Product + Privacy/Legal | use case disabled | Approval |
| Prompt/tool approval workflow | AI + domain + Security | no active definition | Approval |
| Quota/cost/SLO numeric thresholds | Operations/Finance | conservative hard stop | R9 |
| Evaluation metrics/thresholds/cohort | Product + AI + Quality | no activation | Release |
| Supported Baltic locales/markets | Market/Product | unsupported explicit fallback | Activation |

## 33. Final statement

BCK-15 defines a safe provider-neutral AI backend seam whose only product
output is a validated transient proposal. It preserves deterministic authority,
privacy, cost control and reversible operation and authorizes no provider,
secret, metered call, deployment or production use case.

## 34. Stage 2 normalized AI entity contract

All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| PromptDefinitionRevision | AI Platform / prompt registry | AI request handler and evaluation runner | promptId + immutable revision/hash + locale/use-case schema refs |
| AiRequest | AI Platform / request orchestrator | requesting product use case and audit | aiRequestId + actor/useCase/inputSchema revision; redacted input only beyond boundary |
| ToolInvocationRecord | AI Platform / allowlisted tool broker | request orchestrator and security audit | invocationId + aiRequestId + tool/revision + bounded result metadata |
| AiProposal | AI Platform / proposal validator | requesting domain; never published automatically | proposalId + aiRequestId + output schema/revision + validation status |
| AiCostLedgerEntry | AI Platform / quota-cost ledger | user/session quota, Operations and Finance projection | ledgerEntryId + provider/model/usage/currency minor units |
| EvaluationResult | AI Platform / evaluation runner | release gate and model/prompt comparison | evalId + fixture/prompt/model revisions and deterministic verdict |

Requests move accepted → redacted → dispatched/locally-fallback → validated or
failed/cancelled; proposals are transient and never authoritative domain state.
Unredacted provider send, unallowlisted tool, schema-bypass, quota-bypass and
automatic publish are forbidden. Request idempotency is actor/use-case/intent
scoped; provider retries remain bounded and never duplicate cost ledger facts.
Quota reservation/finalization is atomic locally; provider calls and domain
acceptance are separate. Data classification/redaction/authorization,
retention and deletion
follow BCK-04; prompts/tools require versioned capability policy. Audit omits
raw sensitive prompts; telemetry/cost use bounded metadata and minor units.
Migration pins prompt/schema/model revisions; rollback selects prior prompt or
deterministic non-AI fallback. Provider/use-case/model flags and kill switches
default off. Evidence covers redaction, schema rejection, tool allowlist,
quota/cost, outage, deterministic fallback, evaluation and no-authority tests.

## 35. Stage 5 provider-neutral AI gateway contract

### 35.1 Request pipeline

```text
authorize use case -> reserve quota -> resolve prompt/tool/schema revisions
  -> redact/minimize -> provider-neutral request -> bounded provider adapter
  -> validate structured result -> release/finalize quota and cost
  -> return proposal or deterministic fallback -> domain explicitly accepts
```

The gateway accepts only registered use cases with exact actor/capability,
market, locale, purpose, prompt, schema, tool and budget revisions. Redaction
and minimization occur before any provider adapter receives data. Unknown or
newer schema/tool/prompt, unavailable policy, missing consent where applicable,
redaction uncertainty or exhausted quota fails closed or selects the declared
non-AI deterministic fallback.

### 35.2 Prompt, tool and validation governance

Prompt revisions are immutable, reviewed artifacts with bounded variables and
expected output schema. Tools are read-only by default, allowlisted per use
case, receive least-privilege typed inputs and return bounded provenance. No AI
tool directly invokes a domain mutation, publication, Booking, Payment, Admin or
T&S decision. Provider output is untrusted: structural and semantic validation,
policy filtering and exact size/range limits precede any proposal returned to a
product domain.

### 35.3 Quota, cost, resilience and fallback

Quota reservation/finalization uses actor/use-case/market windows and one cost
ledger entry per provider attempt. Money uses integer minor units plus currency;
provider token/usage values are observations, not billing authority. Retries are
bounded by request idempotency, deadline and budget and cannot double-charge the
internal cost ledger. Per-use-case/model/provider/market kill switches and
circuit breakers default off.

Fallback is explicit and deterministic for identical normalized input plus
registry revision. It is labelled non-AI/fallback and must remain useful enough
for the bounded product flow or return a typed unavailable state. Provider
failure never silently changes prompt/model or sends previously redacted fields
under a different policy.

### 35.4 Evaluation, privacy and authority

Release requires versioned offline fixtures, safety/privacy/schema/quality/cost
thresholds and regression comparison against fallback. Evaluation data is
synthetic, consented or separately governed; production prompts/responses do
not become fixtures automatically. Audit records versions, decisions, quota and
cost codes without raw sensitive prompts. AI output remains a transient
proposal; an owning-domain typed command and human/user action where required
is the only path to persisted authority or publication.

### 35.5 Additional acceptance criteria

61. **BCK-15-AC-61:** Only registered actor/use-case/purpose/prompt/schema/tool/budget revisions may run.
62. **BCK-15-AC-62:** Redaction and minimization finish before provider adapter access.
63. **BCK-15-AC-63:** Redaction uncertainty and unknown/newer contracts fail closed or use declared fallback.
64. **BCK-15-AC-64:** Prompts are immutable reviewed artifacts with bounded variables.
65. **BCK-15-AC-65:** AI tools are least-privilege, typed and non-mutating by default.
66. **BCK-15-AC-66:** No tool or model directly publishes or mutates domain/Booking/Payment/Admin/T&S state.
67. **BCK-15-AC-67:** Provider output is untrusted until structural, semantic and policy validation passes.
68. **BCK-15-AC-68:** Quota reservation/finalization and cost attempts are idempotent and bounded.
69. **BCK-15-AC-69:** Cost uses minor units/currency and provider usage is observational.
70. **BCK-15-AC-70:** Retry cannot double-count internal quota or cost.
71. **BCK-15-AC-71:** Provider/use-case/model/market kill switches and circuit breakers default off.
72. **BCK-15-AC-72:** Deterministic fallback is explicit, labelled and version-pinned.
73. **BCK-15-AC-73:** Evaluation uses governed fixtures and accepted quality/safety/privacy/cost thresholds.
74. **BCK-15-AC-74:** AI result remains proposal-only until owning-domain acceptance.
75. **BCK-15-AC-75:** v0.3 authorizes no provider selection, network, secret, runtime or activation.
