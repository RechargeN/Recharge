# Recharge Backend — Mobile Integration Standard

- ID: **BCK-18**
- Version: **0.2**
- Date: **2026-08-25**
- Status: **Review — documentation only; approval and owner decisions pending**
- Runtime status: **Absent — current product repositories remain local/mock**
- Accountable owner: **Mobile Platform owner**
- Required reviewers: **API Platform, Security/Privacy, Identity, Reference
  Data, affected domain owners and Platform Operations**
- Coordination baseline: [BCK-02 v2.4.34](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Preparatory audit:
  [BCK-18-PRE v0.2](BACKEND_MOBILE_INTEGRATION_COVERAGE_MATRIX.md)
- Canonical path: `docs/product/MOBILE_BACKEND_INTEGRATION_STANDARD.md`

## 0. Changelog

### v0.2 — 2026-08-25

- advanced the standard to Review after 22/22 coverage, 60 sequential AC,
  source/runtime reconciliation and structural validation;
- retained the BCK-03 split-key rule and Mobile v3.1 AC-42 erratum explicitly;
- verified M2 Money, OD-04/08/10, contract-generation, mock-exclusion and all
  executable/runtime gates remain blocking or fail-closed;
- kept runtime Absent and changed no contract, generated, mobile, Firebase,
  backend or deployment file.

### v0.1 — 2026-08-25

- created the complete docs-only mobile/backend integration contract;
- defined typed ports, adapters, state algebra, version mapping, cache and
  per-domain cutover boundaries;
- reconciled BCK-03 split request/idempotency keys against the mobile v3.1
  request-ID erratum;
- fixed import orchestration as checkpoint/dispatch only, never aggregate
  authority;
- preserved M2 Money, OD-04, OD-08, OD-10 and all production dependencies as
  explicit fail-closed blockers;
- authorized no runtime, Firebase dependency, schema, adapter, migration,
  deployment, push or `main` change.

## 1. Verdict

BCK-18 defines how Recharge mobile features will consume approved backend
contracts without moving business authority into Flutter, transport or cache.
The standard is complete enough for contradiction review, but it is not
Approved and no executable cutover is authorized.

Current facts:

- product repositories are local/mock;
- Booking v1 is the only implemented cross-language schema/fixture family;
- Auth uses a mock remote datasource and local secure session;
- direct GTFS HTTP is an external reference/provider integration, not Recharge
  product backend;
- Firebase Auth, Firestore, Storage and App Check are not mobile dependencies;
- Money normalization debt blocks M8 remote writes;
- product/backend runtime remains Absent.

## 2. Parents, priority and conflict resolution

### 2.1 Source order at the mobile/backend seam

1. Accepted ADR and Architecture Baseline.
2. Accepted domain/product specification for the active feature.
3. BCK-03 wire/API semantics and owning backend BCK specification at exact
   Approved status.
4. This BCK-18 standard after Approval.
5. Mobile Architecture v3.1 for mobile layering/state/cutover.
6. API Contracts Workflow and BCK-04/BCK-20 overlays.
7. Current runtime evidence.

Mobile and backend lifecycle ladders remain independent. A mobile document
cannot authorize backend runtime; a backend document cannot silently rewrite
mobile layer ownership.

### 2.2 Request-ID reconciliation

Mobile Architecture v3.1 §19 and `MOB-ARCH-AC-42` describe unknown retry with
the same `requestId`. BCK-03 contains the later Accepted D1 split-key rule:

```text
requestId = one transport attempt/correlation
idempotencyKey = one logical mutation identity
```

At the backend seam BCK-03 wins: retry creates a fresh `requestId`, preserves
the exact `idempotencyKey` and normalized semantic payload, and links attempts
to one logical command. The mobile statement requires a future non-semantic
erratum; its stable AC number is not reused or shifted.

### 2.3 Contract-source reconciliation

API Contracts Workflow currently authorizes language-neutral cross-language
schemas only for Booking through ADR 0019. BCK-03 proposes a broader standard,
but until the applicable API decision is Accepted, BCK-18 cannot create a new
hand-authored/generated non-Booking schema family.

## 3. Outcome and non-goals

### 3.1 Outcome

For every cut-over feature, BCK-18 provides:

- an existing or approved domain port;
- one data-layer local/cache/remote composition;
- fixture-verified DTO mapping;
- explicit query freshness and command lifecycle;
- auth/App Check transport context without client grants;
- idempotent retry and stale-revision handling;
- reversible local-to-remote migration/import;
- per-environment binding with no hidden mock authority;
- evidence-driven rollout and rollback.

### 3.2 Non-goals

BCK-18 does not:

- own any imported aggregate;
- define identity, content, Booking, media, notification or reference business
  policy;
- expose Firestore/Storage directly to presentation/domain;
- create one mega repository for all features;
- require every feature to use one concrete cache/UI state class;
- generate contracts before Accepted workflow authorization;
- resolve OD-04, OD-08 or OD-10 by prose;
- complete M2 Money migration;
- add Firebase, deploy backend or process production data.

## 4. Scope and integration boundary

Included:

1. command/query/result/error mobile envelopes;
2. typed ports and data adapters;
3. DTO/domain/cache separation;
4. session/access/App Check transport integration;
5. local/cache/remote read state and provenance;
6. command state, cancellation, timeout and reconciliation;
7. version/min-client behavior;
8. import session/checkpoint/dispatch/receipt/rollback;
9. per-domain cutover and binding manifest;
10. privacy-safe telemetry and test evidence.

Excluded/delegated:

| Concern | Owner |
|---|---|
| Wire semantics and schema registry | BCK-03/API Platform |
| Account/access/publisher mapping | BCK-06/OD-08 |
| Domain commands and aggregates | Owning BCK domain |
| Reference/LocalizedText | BCK-20/OD-10 |
| Security/privacy/retention | BCK-04 plus owning domain |
| Environment, flags, release/SLO | BCK-05 |
| Cross-domain deletion orchestration | BCK-04 |
| Provider-specific external integrations | BCK-16 or owning approved provider slice |

## 5. Layer and dependency contract

```text
presentation
    -> application controller/state/command orchestration
        -> domain use case + repository port

data repository implementation
    -> local/cache datasource
    -> remote datasource/transport adapter
    -> DTO mapper
    -> domain port

composition root
    -> selects environment-safe implementations
```

Rules:

- presentation renders state and dispatches intent only;
- application owns double-submit, cancellation, stale response and command
  lifecycle;
- domain owns invariant/policy and knows no DTO/Firebase/HTTP;
- data owns transport, persistence, mapping and technical retry execution;
- `core` may contain technical client primitives, never product workflow;
- `app/di` binds implementations but does not decide feature business policy;
- cross-feature work uses stable contracts/facades, not another feature's data
  or presentation layer;
- generated files are generator-owned and never manually edited.

## 6. Ownership and single-writer matrix

| Concern | Writer/owner | Mobile integration role | Forbidden |
|---|---|---|---|
| Wire schema | API/contracts owner | Generate/verify/consume | Feature-local redefinition |
| Domain entity/invariant | Owning feature domain | Map and invoke | DTO as domain model |
| Backend aggregate | Owning BCK backend | Send command/query | Client direct authoritative write |
| Application state | Feature application | Orchestrate UI-visible lifecycle | Transport decides UX policy |
| Cache/local record | Feature data | Read/write with metadata | Cache grants backend authority |
| Identity/access | BCK-06 | Carry token, consume bounded snapshot | Persist/grant roles/capabilities |
| Import session/checkpoint | BCK-18 | Inventory/dispatch/reconcile | Write aggregate directly |
| Reference revision | BCK-20 | Cache/map and declare provenance | Hardcode market wire enum |
| Server flags | BCK-05 | Consume effective read-only flags | Local override enables authority |
| Analytics | BCK-21 | Emit approved bounded facts | Logs/analytics become audit |

## 7. Contract and mapping pipeline

Target pipeline:

```text
canonical contract source
-> valid / invalid / forward fixtures
-> generated or fixture-verified immutable DTO
-> data mapper
-> domain entity/value object
-> application state
-> presentation
```

### 7.1 DTO rules

- DTO mirrors wire shape only;
- DTO validates structural bounds, not product eligibility;
- unknown optional fields are ignored or preserved according to contract;
- unknown enum/major becomes typed unsupported, never a privileged/default
  known value;
- absent and null remain distinguishable where schema does;
- no mutable raw `Map<String, dynamic>` crosses into domain/application;
- sensitive unknown payload is not logged or exposed.

### 7.2 Mapper rules

- mapper is explicit and one-direction responsibility is testable;
- wire IDs/time/Money/reference values become validated value objects;
- mapping failure has stable typed code and field path without sensitive value;
- forward fixture is either safely mapped or becomes unsupported atomically;
- mapper never calls repository, network, telemetry or UI;
- round trip is required only where write contract explicitly supports it.

### 7.3 Domain boundary

Domain does not import/re-export DTO, Firebase, HTTP, JSON schema or generated
client. Backend policy results become domain-readable value objects with source
revision/provenance; they are not recomputed from hidden client assumptions.

## 8. Mobile read-state algebra

Every remote-capable read exposes the equivalent semantics, even if features
use different domain-specific class names:

```text
localOnly
fresh
cached
stale
refreshing
unsupported
unavailable
```

Required metadata where applicable:

```text
source: local | cache | server | provider
schemaVersion
resourceRevision?
projectionRevision?
datasetRevision?
policyRevision?
marketId?
fetchedAtUtc?
freshUntilUtc?
staleReason?
```

Invariants:

- offline does not make stale data fresh;
- refreshing may retain last safe view but not upgrade its authority;
- unsupported is not empty and never partially renders unsafe newer data;
- unavailable differs from not found;
- localOnly is visibly non-server-confirmed where confirmation matters;
- projection families sharing one query preserve query/dataset revision
  compatibility and expose typed mixed/stale state otherwise;
- UI action availability comes from domain/application policy plus current
  authority, not from visual presence of cached data.

## 9. Mobile command lifecycle

```text
idle
-> validating
-> ready
-> submitting(attemptRequestId, logicalCommandId, idempotencyKey)
-> success | cancelledBeforeSend | failure | unknownOutcome
-> reconciling (when outcome unknown/stale)
```

Rules:

1. application prevents accidental double submit;
2. validation failure sends no command;
3. user cancellation before send is neutral `cancelled`;
4. after send, transport cancellation is not proof of no commit;
5. timeout/disconnect after possible send becomes `unknownOutcome`;
6. retry uses a new attempt `requestId`, same logical command ID,
   `idempotencyKey` and normalized payload;
7. stale response cannot overwrite a newer controller generation;
8. success is shown only from committed authoritative result;
9. partial async effects remain explicit pending state, not command failure;
10. destructive retry/reconcile actions require explicit UX when ambiguity
    cannot be resolved automatically.

## 10. Query, command and error mapping

### 10.1 Query adapter

Query request carries contract/query version, fresh request ID, market/locale
where required, stable filters/cursor and supported projection revision.
Auth UID/capabilities are server context, not payload grants.

Query result maps:

| Backend outcome | Mobile semantic state |
|---|---|
| success current | `fresh` |
| success from explicit cache/server stale marker | `cached` or `stale` |
| not found for visible resource | typed empty/notFound per domain |
| permission/anti-enumeration | typed unavailable/notFound policy |
| unsupported client/contract/schema | `unsupported` with safe update path |
| transport unavailable with cache | `cached`/`stale` plus refresh action |
| transport unavailable without cache | `unavailable` |

### 10.2 Command adapter

Command request carries BCK-03 version/type, fresh attempt request ID, stable
idempotency key, expected aggregate revision and semantic payload. The adapter
adds token/App Check at transport boundary and never serializes client roles,
capabilities, creator verification or resolved actor as authority.

### 10.3 Error mapping

Common BCK-03 codes map to stable mobile failures:

| Common code | Mobile meaning/action |
|---|---|
| `invalid_argument` | field/global validation; do not retry unchanged |
| `unauthenticated` | auth flow with safe intended destination |
| `permission_denied` | capability/visibility denial without enumeration |
| `not_found` | visible absence or anti-enumerating unavailable |
| `conflict` | explicit domain reconciliation |
| `idempotency_conflict` | stop; preserve logical command and inspect |
| `failed_precondition` | domain action/reason from allowlisted code |
| `rate_limited` | bounded retry-after UX |
| `unavailable` | cache/degraded policy or retry |
| `deadline_exceeded` | unknown outcome if send may have occurred |
| `unsupported_client/contract/schema` | fail closed; approved update path |
| `stale_revision` | refresh/review; never blind overwrite |
| `internal` | safe correlation ID and retry policy |

Provider/SDK/raw database exceptions never cross data boundary.

## 11. Versioning and minimum client

Distinct values:

| Version | Meaning |
|---|---|
| App/build | Installed mobile artifact |
| Package SemVer | `api_contracts` consumer release |
| Contract/operation version | Wire semantics |
| Schema version | DTO/persisted/cache shape |
| Resource revision | One aggregate concurrency |
| Projection/query revision | Derived read consistency |
| Policy/reference revision | Server-owned policy/dataset |
| Import format/session version | Migration orchestration |

Rules:

- older safe reads/export/logout may remain while dangerous mutations block;
- unsupported newer major is atomic unsupported, never partial downgrade;
- additive optional field needs valid/invalid/forward fixture evidence;
- breaking change needs migration owner, dual compatibility window or explicit
  coordinated cutover and rollback;
- server checks minimum client before mutation;
- update URL/message is approved platform config, not arbitrary server text;
- cache key includes semantics-affecting contract/market/query revisions.

## 12. Authentication, App Check and access freshness

- token acquisition/refresh/storage lives in Auth data/platform boundary;
- production providers and account lifecycle come from BCK-06;
- App Check attaches at transport adapter after approved rollout;
- neither token nor App Check contains/trusts mutable page membership graph;
- bounded access snapshot may plan UI, but mutation is server-revalidated;
- logout clears local secrets and owner-scoped sensitive cache; server revoke
  outcome remains explicit if offline;
- session/access revocation invalidates active commands and protected caches;
- a background retry never silently changes workspace/publisher/actor;
- production build fails closed if required Auth/App Check adapter is missing;
- mock Auth/access bindings are excluded from production dependency graph.

## 13. Local persistence and cache contract

Each cache/local family declares:

1. owner and purpose;
2. key including user/workspace/market where applicable;
3. schema and source revisions;
4. fetched/created/fresh-until times;
5. encryption/storage class;
6. maximum size and eviction;
7. tombstone/delete propagation;
8. logout/account-switch behavior;
9. corrupt/newer handling;
10. telemetry redaction.

Rules:

- owner-scoped data never appears under another session;
- cache corruption returns typed state and recoverable purge path;
- purge is targeted, not broad destructive storage reset;
- tombstone wins over stale cached entity;
- server-owned grant/moderation/booking/quota/publication state is never
  offline-merged;
- local drafts may remain independently editable but require explicit import or
  publish reconciliation;
- secure storage is not a substitute for retention/deletion policy.

## 14. Offline and degraded operation

| Operation | Offline behavior |
|---|---|
| Safe local draft edit | Allowed with local revision/provenance |
| Cached discover/reference read | Allowed if labelled freshness/policy permits |
| Favorite/visit local action | Only under owning domain contract; not server-confirmed |
| Identity grant/page membership | No local authority |
| Publication/moderation | No confirmed mutation |
| Booking/inventory/payment | No client confirmation |
| Consent withdrawal | Local intent may queue visibly; processing stop is confirmed only by authority |
| Import | Inventory/dry-run local only; no remote dispatch |

When network returns, repository refreshes source revisions before mutation.
It never uploads every local record automatically merely because connectivity
returned.

## 15. Idempotency, concurrency and unknown outcome

### 15.1 Key model

```text
logicalCommandId: mobile application identity for one intent
idempotencyKey: backend logical mutation identity
requestId: one transport attempt
correlationId: server/operations chain
```

The first two may be equal only if their formats/contracts permit; request ID
may also happen to equal on the first attempt but is not reused for retry.

### 15.2 Persistence

For commands where an app restart may occur after send, mobile stores a bounded
pending-command receipt containing command type/version, opaque target ID,
idempotency key, canonical payload hash, last request ID, expected revision,
created time and safe status. Tokens and sensitive payload are excluded unless
an approved encrypted domain contract requires minimal recovery data.

### 15.3 Reconciliation

- same key/hash retry returns original semantic result;
- different hash never reuses key;
- stale revision reloads and asks domain/application reconciliation;
- no automatic last-write-wins for ownership/lifecycle/Money/capacity;
- unknown outcome queries by key/target when contract offers it, otherwise
  retries safely;
- user sees `checking result`, not duplicate success/failure;
- receipts expire only after the backend safe retry/result window.

## 16. Import and local-to-cloud orchestration

### 16.1 `ImportSession`

```text
importSessionId
schemaVersion
userId / workspaceRef after explicit BCK-06 mapping
sourceAppVersion
sourceDataInventoryHash
startedAtUtc
checkpoint
perFamilyCounts
status: inventory | preview | approved | running | paused | completed | failed | rolledBack
```

### 16.2 Flow

```text
inventory local data
-> validate current identity/market/contracts
-> dry-run classify each item
-> show user disclosure/choices
-> explicit approval
-> dispatch each item to owning domain import command
-> persist receipt/mapping/checkpoint
-> reconcile server result
-> complete or bounded rollback/repair
```

### 16.3 Item outcomes

```text
importable
alreadyPresent
requiresUserChoice
unsupportedVersion
invalid
blockedByPolicy
blockedByIdentity
failedRetryable
failedTerminal
```

### 16.4 Invariants

- BCK-18 writes only import session/checkpoint/mapping receipts;
- owning domain validates and writes its aggregate;
- user/page mapping comes only from BCK-06/OD-08;
- email, display name, local device ID and organizer text never map authority;
- mock roles/grants/verification/membership/quota/moderation/consent are never
  imported as authority;
- `loc_*` becomes permanent ID before accepted remote create;
- dry run has no remote domain mutation;
- retry dispatch uses same domain idempotency key;
- checkpoint advances only after durable receipt;
- conflict is explicit, never silent overwrite/merge;
- source local data remains until confirmed policy-controlled cleanup;
- OD-04 must be Accepted before execution.

## 17. Money, IDs, time and reference prerequisites

- all authoritative IDs are permanent ULID/UUID and relationships ID-based;
- `loc_*` remains unsaved-local only;
- instants use UTC and schedule semantics preserve IANA timezone;
- Money wire/domain uses integer minor units plus ISO currency/scale metadata;
- no remote write converts normalized `double` at the boundary as a hidden fix;
- Mobile M2 Money migration, fixtures and round-trip tests must pass before M8;
- coordinates/distances may remain finite numeric primitives under their domain
  contracts and are not Money;
- market/locale/timezone/currency are independent values;
- reference/taxonomy values use stable ID + revision from BCK-20;
- unknown market/policy/reference revision fails closed for mutation;
- LocalizedText/fallback uses OD-10 only after Acceptance.

## 18. Event consumption, replay and push hints

Mobile does not consume the authoritative outbox directly. Approved backend
query/push/sync endpoints expose bounded invalidation or projection updates.

Rules:

- push is a hint to query, not authority;
- duplicate hint is harmless;
- client stores per-stream/projection checkpoint only where contract defines it;
- revision gap triggers bounded refresh/reconciliation;
- unknown event/major is ignored safely and reported without payload;
- foreground/background handlers use the same repository boundary;
- deep link validates current auth/access/resource visibility;
- notification payload excludes protected aggregate data;
- event replay cannot apply an out-of-order authority mutation locally.

## 19. Privacy, security and local deletion

- classify every DTO/cache/import field before executable work;
- tokens use platform-secure storage and never logs/analytics;
- free text, exact location, contact, evidence and sensitive unknown payload are
  redacted by default;
- owner/workspace/market namespaces prevent cross-account cache leakage;
- screen capture/clipboard/background risks are reviewed for sensitive flows;
- import disclosure lists data families, owner mapping, non-importable authority
  and rollback behavior;
- logout/account switch clears or locks applicable owner-scoped material;
- DSR deletion directive comes from BCK-04; mobile removes local replicas and
  reports bounded completion without becoming DSR authority;
- App Check complements, never replaces Auth/Rules/IAM/rate limits;
- TLS pinning or device attestation is not invented without an approved
  operations/security lifecycle;
- compromised client is assumed possible.

Exact local retention/encryption/backup behavior is BCK18-OD-07 plus owning
domain and qualified Privacy review before production personal data.

## 20. Abuse, limits and backpressure

Adapters enforce server-provided bounded limits for page size, batch/import
size, payload/media metadata, retry-after and concurrency. Client limits improve
UX but server remains authoritative.

Required behavior:

- bounded exponential backoff with jitter for retryable technical failures;
- no retry storm when offline/backgrounded;
- one active logical mutation per controller/resource where domain requires;
- rate limit displays safe wait/action, not bypass;
- import dispatch is bounded, resumable and pauses on policy/auth changes;
- unsupported/poison item cannot block unrelated safe preview, but execution
  preserves exact per-item result;
- no arbitrary server-provided URL/message execution;
- memory/disk budgets and eviction are measured per feature.

## 21. Observability, analytics, SLO and cost

Safe adapter telemetry:

```text
feature/operation
attempt outcome
transport class
app/build/contract/schema versions
marketId
cache state/freshness bucket
request/correlation hash or approved opaque ID
idempotency-hit/unknown-outcome/reconcile flags
latency bucket
```

Never include token, raw request/response, free text, exact location, email,
provider subject, verification evidence, capability list or import payload.

Required indicators:

- command/query success/failure/unknown outcome;
- cache hit/stale/unsupported/unavailable;
- mapper/fixture incompatibility;
- auth/App Check refresh/deny by safe code;
- import classified/dispatched/completed/failed counts;
- shadow-read parity and revision mismatch;
- client version distribution and unsupported block;
- request/read/write/egress and storage cost attribution.

Numeric SLO/alerts/cost budgets come from BCK-05 and owning domain. Analytics
failure never changes product outcome.

## 22. Binding manifest and environment isolation

Each executable build produces an inspectable binding manifest:

```text
environment
market
feature/domain
repository implementation
transport endpoint/project identity
contract/package version
mockAllowed=false for production
server flag revision
```

Rules:

- production refuses startup/feature activation if a required remote binding is
  missing or mock/local authority is selected;
- dev emulator, shared cloud dev, stage and prod namespaces cannot mix;
- endpoints/project IDs come from approved environment config, not UI or
  arbitrary deep link;
- secrets are absent from manifest/repository;
- one feature may remain explicitly local-only while another cuts over, but UI
  must not present it as synchronized production state;
- emergency flag disables mutation without deleting local data or restoring
  mock authority.

## 23. Rollout, cutover and rollback

Per-domain sequence:

```text
contracts/fixtures accepted
-> mapper/repository tests
-> emulator/default-deny evidence
-> remote binding in dev/stage
-> read shadow comparison
-> staff cohort
-> explicit import dry run
-> bounded write cohort
-> Latvia rollout
-> cleanup only after evidence
```

Cutover rules:

- query and command cutovers are separate flags;
- shadow reads never mutate domain/cache authority silently;
- parity compares IDs, revisions, semantic fields and exclusion reasons, not
  only counts;
- one authoritative writer at each stage;
- cohort/market/build/version recorded;
- rollback disables new remote mutations, preserves committed server truth,
  pending receipts and local source, then reconciles;
- rollback never returns to mock grants or treats local copy as server truth;
- legacy adapter removal needs zero-reference and rollback-window evidence.

## 24. Open decisions and blockers

| ID | Status | Owner/decision | Blocks | Default |
|---|---|---|---|---|
| OD-04 / BCK18-OD-01 | Open | Import mapping/conflict/checkpoint/retry/dedupe/disclosure/rollback — Mobile + domains | Any import | Disabled |
| OD-08 / BCK18-OD-02 | Open | Provider/local identity mapping — Identity + Mobile | Identity/import | No inference/import |
| BCK18-OD-03 | Open | Non-Booking contract generation/client strategy — API + Mobile | Non-Booking adapters | No new generated family |
| BCK18-OD-04 | Open | Cache/read-state freshness defaults — Mobile + domains | M8/M9 | Feature-local state, no server claim |
| BCK18-OD-05 | Open | Binding manifest/flavor/mock exclusion evidence — Mobile + Ops/Security | Production build | Required remote feature disabled |
| BCK18-OD-06 | Open | Per-domain cutover order/parity/rollback thresholds — Mobile + domains | M9/R3 | No cutover |
| BCK18-OD-07 | Open | Secure local cache classification/encryption/retention — Mobile + Privacy/domains | Production personal data | No production cache |
| OD-10 / BCK18-OD-08 | Proposed | LocalizedText/reference mapping — Reference + API + Mobile | Content/reference cutover | Unsupported/disabled |
| Mobile v3.1 erratum | Open editorial | AC-42 request-ID wording — Mobile Architecture owner | Traceability clarity | BCK-03 split-key enforced at wire seam |
| M2 Money prerequisite | Incomplete | Normalize all authoritative Money before M8 — Mobile owners | Remote writes | Writes blocked |

An owner decision requires exact version, alternatives, selected value,
evidence, controls, affected documents, rollout and rollback. BCK-18 Review
does not promote any row.

## 25. Exact conditional artifact map

Documentation in this slice:

```text
docs/product/MOBILE_BACKEND_INTEGRATION_STANDARD.md
docs/product/BACKEND_MOBILE_INTEGRATION_COVERAGE_MATRIX.md
```

Future contracts, only after Accepted workflow/domain authorization:

```text
packages/api_contracts/schema/<domain>/<version>/*
packages/api_contracts/lib/src/contracts/<domain>/*
packages/api_contracts/lib/src/dto/<domain>/*
packages/api_contracts/test/<domain>_*_test.dart
```

Future mobile foundation, only in an Approved executable slice:

```text
apps/mobile/lib/core/network/backend_transport.dart
apps/mobile/lib/core/network/backend_request_context.dart
apps/mobile/lib/core/network/backend_result_mapper.dart
apps/mobile/lib/app/di/backend_binding_manifest.dart
apps/mobile/lib/features/<feature>/data/datasources/<feature>_remote_datasource.dart
apps/mobile/lib/features/<feature>/data/models/<feature>_dto_mapper.dart
apps/mobile/lib/features/<feature>/data/repositories/<feature>_repository_impl.dart
apps/mobile/lib/features/<feature>/application/*
apps/mobile/test/unit/backend_integration/*
apps/mobile/test/integration/backend_integration/*
```

Actual filenames must be reconciled with existing feature structure before each
slice. This map does not authorize creation and generated paths remain
generator-only.

## 26. Test and evidence matrix

| Level | Required evidence |
|---|---|
| Structural | 22/22 coverage, links, AC, fences, diff and boundary |
| Contract | valid/invalid/forward fixtures across each consumer |
| Mapper | absent/null/unknown/IDs/time/Money/reference and round-trip where allowed |
| Domain | unchanged invariant behavior behind new repository |
| Application | state transitions, double submit, cancellation, stale response, unknown outcome |
| Repository | local/cache/remote precedence, freshness, tombstone and corrupt/newer cases |
| Transport | auth/App Check/envelope/error/timeout/retry and no raw exception leakage |
| Idempotency | fresh request ID + stable key, same/different hash and restart receipt |
| Import | inventory/dry-run/choice/checkpoint/resume/dedupe/conflict/rollback |
| Security | mock exclusion, spoofed grants, cross-user/workspace cache, deep-link negative |
| Emulator | Rules/default deny, callable context, revision/idempotency where backend exists |
| Two-device | revocation, server change, cache refresh and conflict observation |
| Compatibility | previous/current/newer client-contract matrix and min-client |
| Rollout | shadow parity, cohort, kill switch and rollback without authority inversion |
| Operations | SLO/alerts/cost, incident and privacy deletion evidence |

Documentation, emulator, shared-cloud stage and production evidence are
reported separately.

## 27. Definition of Ready for Review

1. 22/22 mandatory categories are present.
2. Current runtime inventory is verified.
3. Request/idempotency conflict has one wire rule and explicit erratum.
4. M2 Money blocks M8 remote writes.
5. OD-04/08/10 and local decisions have owners/gates/defaults.
6. Import cannot write another aggregate.
7. Mock/server/cache authority is unambiguous.
8. Contract generation respects current Booking-only authorization.
9. File map is conditional and layered.
10. Structural/boundary checks pass.

## 28. Definition of Done

Documentation Done requires Approved exact BCK-18 version, owner verdict,
BCK-01/BCK-02/LAUNCH reconciliation and no contradiction enabling dual
authority.

Runtime Done is per-domain and additionally requires:

- Approved parent/domain BCK specs and applicable OD decisions;
- completed M2 Money prerequisite before any Money remote write;
- contracts/fixtures/generated or verified DTOs;
- data-layer adapters behind existing ports;
- production-safe binding manifest with no mock authority;
- emulator/security/import/two-device/rollout/rollback evidence;
- privacy/retention/SLO/cost approval;
- measured LAUNCH_STATUS update.

## 29. Acceptance criteria

1. **BCK-18-AC-01:** Mobile/backend document ladders remain independent.
2. **BCK-18-AC-02:** API contracts are the single wire source of truth.
3. **BCK-18-AC-03:** Booking remains the only currently authorized cross-language schema exception.
4. **BCK-18-AC-04:** Generated files are never manually edited.
5. **BCK-18-AC-05:** DTO, mapper, domain and application state remain separate.
6. **BCK-18-AC-06:** Domain imports no transport/Firebase/DTO infrastructure.
7. **BCK-18-AC-07:** Presentation dispatches intent and renders state only.
8. **BCK-18-AC-08:** Application owns command lifecycle and stale-response protection.
9. **BCK-18-AC-09:** Data owns transport/cache/mapping technical behavior.
10. **BCK-18-AC-10:** Composition root selects environment-safe implementations.
11. **BCK-18-AC-11:** Production contains no mock-authority fallback.
12. **BCK-18-AC-12:** Missing required remote binding fails closed.
13. **BCK-18-AC-13:** Direct client authoritative Firestore writes are forbidden.
14. **BCK-18-AC-14:** Token/App Check never grants role/capability/membership.
15. **BCK-18-AC-15:** Cached access never authorizes a mutation.
16. **BCK-18-AC-16:** Read state distinguishes local/fresh/cached/stale/refreshing/unsupported/unavailable.
17. **BCK-18-AC-17:** Cache carries source/version/revision/freshness metadata.
18. **BCK-18-AC-18:** Offline never upgrades freshness or authority.
19. **BCK-18-AC-19:** Newer unsupported contract is not partially applied.
20. **BCK-18-AC-20:** Query projections expose compatible revision or typed mixed/stale state.
21. **BCK-18-AC-21:** User cancellation before send is neutral cancelled.
22. **BCK-18-AC-22:** Cancellation after possible send becomes unknown outcome unless no-commit is proven.
23. **BCK-18-AC-23:** Every retry uses a fresh attempt request ID.
24. **BCK-18-AC-24:** Logical retry preserves idempotency key and normalized payload.
25. **BCK-18-AC-25:** Same key/different hash creates no mutation.
26. **BCK-18-AC-26:** Stale revision never silently overwrites.
27. **BCK-18-AC-27:** Pending-command receipt contains no token or unnecessary sensitive payload.
28. **BCK-18-AC-28:** Success is shown only from authoritative committed result.
29. **BCK-18-AC-29:** Push/deep link is a hint and revalidates auth/visibility.
30. **BCK-18-AC-30:** Import session writes only checkpoint/mapping receipts.
31. **BCK-18-AC-31:** Owning domain command validates and writes imported aggregate.
32. **BCK-18-AC-32:** Import dry run performs no domain mutation.
33. **BCK-18-AC-33:** Identity mapping never infers from email/name/device.
34. **BCK-18-AC-34:** Mock grants/verification/membership/quota/consent never import as authority.
35. **BCK-18-AC-35:** Import retry preserves domain idempotency identity.
36. **BCK-18-AC-36:** Import conflict is explicit and user-visible where required.
37. **BCK-18-AC-37:** OD-04 Acceptance precedes import execution.
38. **BCK-18-AC-38:** OD-08 Acceptance precedes identity mapping/import.
39. **BCK-18-AC-39:** `loc_*` never crosses authoritative boundary.
40. **BCK-18-AC-40:** Money remote writes wait for completed M2 minor-unit migration.
41. **BCK-18-AC-41:** UTC/IANA schedule semantics survive mapping.
42. **BCK-18-AC-42:** Market/reference values use stable IDs and revisions.
43. **BCK-18-AC-43:** OD-10-dependent cutover stays disabled until Accepted.
44. **BCK-18-AC-44:** External GTFS transport is not Recharge backend authority.
45. **BCK-18-AC-45:** Owner/workspace/market cache namespaces prevent leakage.
46. **BCK-18-AC-46:** Tombstone wins over stale cached entity.
47. **BCK-18-AC-47:** Logout/account switch handles local secrets and protected cache explicitly.
48. **BCK-18-AC-48:** Logs/analytics contain no token/raw payload/free text/exact sensitive data.
49. **BCK-18-AC-49:** Client rate/backoff cannot bypass server policy.
50. **BCK-18-AC-50:** Binding manifest is environment/market/feature/version inspectable.
51. **BCK-18-AC-51:** Dev/emulator/stage/prod namespaces never mix.
52. **BCK-18-AC-52:** Query and command cutovers use separate server-governed flags.
53. **BCK-18-AC-53:** Shadow read never mutates authority.
54. **BCK-18-AC-54:** Rollback preserves committed server truth and pending receipts.
55. **BCK-18-AC-55:** Rollback never restores mock or revoked authority.
56. **BCK-18-AC-56:** Legacy removal requires zero-reference and rollback evidence.
57. **BCK-18-AC-57:** No new boundary suppression is introduced by documentation.
58. **BCK-18-AC-58:** Documentation/emulator/stage/production evidence remain distinct.
59. **BCK-18-AC-59:** Runtime files remain conditional on separate Approved slices.
60. **BCK-18-AC-60:** Runtime status remains Absent until measured per-domain cutover evidence exists.

## 30. Explicit unimplemented list

- general backend transport/client;
- non-Booking schemas/DTOs/codegen;
- Firebase Auth/Firestore/Storage/App Check mobile dependencies;
- production binding manifest;
- identity/content/discover/library/media/notification remote adapters;
- common cache/read-state implementation;
- pending-command receipt store;
- import session/checkpoint/dispatcher;
- OD-04/OD-08/OD-10 decisions;
- M2 Money completion;
- M8/M9 executable slices;
- emulator/shared-cloud/two-device/cutover/rollback evidence;
- production personal-data cache/retention approval.

Current local/mock repositories, Booking DTOs and external GTFS adapter are
useful evidence only and do not satisfy this list.

## 31. Final statement

BCK-18 v0.2 is a complete Review standard pending owner decisions. It creates a reversible,
typed seam between existing mobile feature architecture and future domain
backends while prohibiting dual authority, hidden mock fallback and unsafe
local import. No runtime work follows automatically from this document.
