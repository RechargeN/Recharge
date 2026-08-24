# Recharge Backend — Deployment & Operations Specification

- ID: **BCK-05**
- Version: **0.2.15**
- Date: **2026-08-24**
- Spec status: **Draft — Platform Operations review required**
- Runtime status: **Local R0 tooling scaffold Present; product/cloud runtime Absent**
- Accountable owner: **Platform Operations owner**
- Interim review coordinator: **RechargeN / Product owner**
- Parent architecture: [BCK-01 v0.4.20](RECHARGE_BACKEND_MASTER_SPEC.md) (Review)
- Coordination baseline: [BCK-02 v2.4.24](RECHARGE_BACKEND_DELIVERY_MAP.md)
- API boundary: [BCK-03 v0.3.3](BACKEND_API_CONTRACT_STANDARD.md) (Draft)
- Security/privacy boundary: [BCK-04 v0.4.10](BACKEND_SECURITY_PRIVACY_SPEC.md) (Draft; OD-01/09 Proposed)
- Incident-response evidence: [BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) v0.1 (Draft)
- Tabletop package: [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) v0.1 (ready; not executed)
- Infrastructure/cost evidence: [BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md) v0.2 (Draft; OD-04 Proposed)
- Reliability evidence: [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) v0.1 (Draft; OD-03 Proposed)
- Recovery evidence: [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) v0.1 (Draft; OD-05 Proposed)
- Numeric owner review: [BCK05-NUM-REV-01](BACKEND_OPERATIONS_NUMERIC_OWNER_REVIEW.md) v0.2 (bounded Product-owner baseline recorded; specialist evidence pending)
- IAM/workload identity evidence: [BCK05-OD02-IAM-01](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md) v0.1 (Draft; OD-02 Proposed)
- Release/provenance evidence: [BCK05-OD07-REL-01](BACKEND_RELEASE_PROVENANCE_PROMOTION_MODEL.md) v0.1 (Draft; OD-07 Proposed)
- Runtime/toolchain evidence: [BCK05-OD01-TCH-01](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md) v0.3.3 (Draft; OD-01 Proposed; bounded R0 Pass)
- Runtime/toolchain technical review: [BCK05-OD01-TCH-REV-01](BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md) v0.2.3 (bounded R0 Pass; OD-01 Proposed)
- Executed R0 slice: [BCK-R0-TCH-01](BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md) v0.2.2 (Pass — bounded tooling feasibility only)
- R0 approval record: [BCK-R0-TCH-DEC-01](BACKEND_R0_APPROVAL_DECISION_RECORD.md) v0.2 (bounded execution and advisory disposition; no production approval)
- Environment policy: [ENV_FLAVORS_SECRETS](../architecture/ENV_FLAVORS_SECRETS.md)
- Infrastructure input: [FIREBASE_ARCHITECTURE v2.2](../architecture/FIREBASE_ARCHITECTURE.md) (Proposed)
- Delivery annex: [BCK-02-A1 v1.0](RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md) (Draft)
- Runtime effect: **none**
- Canonical repository path: `docs/product/BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md`

---

## 0. Changelog

### v0.2.15 — 2026-08-24

- recorded owner acceptance of `BCK-R0-TCH-ADV-01` for the two root Moderate
  advisories under expiring demo-only R0 controls;
- advanced R0 to Pass for bounded tooling feasibility while retaining
  `BCK05-OD-01` and all other OD items as Proposed;
- kept BCK-05 Draft and all product/cloud runtime, R1/G1, credentials,
  provisioning and deployment blocked; updated BCK-01/BCK-02 traceability to
  v0.4.20/v2.4.24.

### v0.2.14 — 2026-08-24

- recorded green hosted R0 parity for `ubuntu-24.04` and `windows-2025` in
  draft PR #7, run `32684234236`;
- closed the hosted-parity blocker without accepting OD-01 or authorizing
  product/cloud runtime;
- retained the explicit Moderate advisory disposition and specialist/cloud
  evidence as open blockers; updated BCK-01/BCK-02 traceability to
  v0.4.19/v2.4.23.

### v0.2.13 — 2026-08-24

- reconciled the Approved local R0 scaffold and execution evidence without
  accepting OD-01 or authorizing cloud/product runtime;
- recorded green local build/emulator/Rules/Terraform/reproducibility results,
  Pending hosted parity and unresolved Moderate advisory disposition;
- updated BCK-01/BCK-02 traceability to v0.4.18/v2.4.22.

### v0.2.12 — 2026-08-23

- added exact verified full-SHA identities for the three admitted R0 Actions;
- rejected the unsigned reviewed Terraform Action and selected signed-archive
  Terraform 1.15.9 installation with exact Windows/Linux checksums;
- fixed explicit runner/action inputs and added the formal R0 decision record;
- retained OD-01 as Proposed, R0 as Review/not Approved, BCK-05 as Draft and
  runtime as Absent.

### v0.2.11 — 2026-08-23

- added the exact runtime/toolchain technical pre-review and bounded R0
  toolchain/emulator slice specification with 40 and 52 AC respectively;
- recorded proposed exact Firebase SDK, lint/format, JDK and test-runner
  resolutions while keeping compatibility and named owner/security evidence
  blocked;
- retained BCK05-OD-01 as Proposed, BCK-R0-TCH-01 as Review/not Approved,
  BCK-05 as Draft and runtime as Absent; no backend/package/cloud effect exists.

### v0.2.10 — 2026-08-21

- selected a dated Node.js 22/TypeScript/npm/Firebase CLI/Terraform candidate
  in BCK05-OD01-TCH-01 with deterministic install, build, emulator, IaC,
  upgrade and 50-AC contracts;
- advanced `BCK05-OD-01` from Open to Proposed while preserving exact R0
  compatibility, remaining tool pins, owner/security review and executable
  evidence as blockers;
- retained BCK-05 as Draft and runtime as Absent; no backend file, package,
  workflow, cloud resource or deployment was created.

### v0.2.9 — 2026-08-21

- added complete Draft IAM/workload-identity and release-provenance evidence
  models with 50 AC each;
- advanced `BCK05-OD-02` and `BCK05-OD-07` from Open to Proposed while keeping
  exact permissions, GitHub plan controls, toolchain, provider enforcement and
  executable evidence blocked;
- retained OD-07 platform topology as Proposed, BCK-05 as Draft and runtime as
  Absent; no WIF pool, identity, workflow, artifact or deployment was created.

### v0.2.8 — 2026-08-21

- recorded the Product owner's exact bounded disposition for SLO v0.1, Cost
  v0.2 and Recovery v0.1 as non-production stage-validation baselines;
- retained Operations/Security evidence conditions and Inconclusive Finance/
  Legal scopes without claiming independent specialist review;
- retained OD-03/04/05 as Proposed, BCK-05 as Draft and runtime as Absent.

### v0.2.7 — 2026-08-21

- completed the exact-version technical owner review of SLO v0.1, cost v0.2
  and recovery v0.1;
- corrected retained-backup cost from four to 26 prod full-size equivalents,
  exposed the L3 guardrail conflict and reconciled reliability/spend,
  cold-start and soft-delete cost boundaries;
- retained OD-03/04/05 as Proposed and BCK-05 as Draft; explicit owner,
  Finance/Legal, stage/restore and runtime evidence remain blocked.

### v0.2.6 — 2026-08-21

- added independent numerical reliability and recovery evidence models with
  user-journey SLIs/SLOs/error budgets plus record-family RPO/RTO, protection,
  isolated restore, privacy re-deletion and drill contracts;
- advanced `BCK05-OD-03` and `BCK05-OD-05` from Open to Proposed; owner verdicts,
  stage measurement, executable alerts/backups/restores and provisioning remain
  blocked;
- BCK-05 remains Draft, OD-07 remains Proposed and runtime remains Absent.

### v0.2.5 — 2026-08-21

- added a dated infrastructure/cost model with reproducible formulas, five
  workload envelopes, directional provider estimates and proposed EUR budgets;
- advanced `BCK05-OD-04` from Open to Proposed; Product/Finance/Operations
  verdict, actual EUR SKU export, stage reconciliation and provisioning remain
  blocked;
- OD-07 remains Proposed, BCK-05 remains Draft and runtime remains Absent.

### v0.2.4 — 2026-08-20

- added the ready-but-unexecuted incident tabletop package and its explicit
  operations checkpoints;
- `BCK05-OD-08` remains Proposed because real routing, break-glass, executable
  alert evidence, named exercise participants and a completed result are absent;
- operations semantics, 50 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.2.3 — 2026-08-20

- added the shared security/privacy incident response model without creating a
  second severity vocabulary;
- advanced `BCK05-OD-08` from Open to Proposed; real routes, break-glass,
  tabletop and executable alert evidence remain absent;
- operations semantics, 50 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.2.2 — 2026-08-20

- recorded the combined Platform Operations/Security/Legal/Finance assignments;
- retained Pending verdicts and the qualified Legal evidence boundary;
- operations semantics, 50 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.2.1 — 2026-08-20

- removed OD-09 `Open/Proposed` ambiguity: its factual status is Proposed;
- removed the OD-07 evidence/provisioning circularity by separating
  pre-Acceptance modelled evidence from post-provision synthetic validation;
- added explicit current DoR state and D1 owner sign-off ledger;
- operations semantics, 50 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.2 — 2026-08-20

- added BCK-D1-OD07-EV-01 with official per-resource location constraints,
  three candidate topologies and exact latency/cost/residency/IAM/recovery
  evidence required before acceptance;
- clarified that new Storage placement is a separate decision from Firestore
  and that alerts-only budgets do not cap spending;
- linked OD-09 failure/owner evidence; both decisions retain their existing
  statuses and no infrastructure/runtime is authorized.

### v0.1.1 — 2026-08-20

- synchronized with BCK-D1-DEC-01, BCK-03 v0.3 and BCK-04 v0.4.4;
- Booking split-key reconciliation closes the API fixture contradiction without
  changing OD-07/OD-09 or operations authority;
- OD-07 remains Proposed, all numeric/IAM/recovery specialist evidence remains
  open, and runtime remains Absent.

### v0.1 — 2026-08-20

- defined the one-platform operations boundary for local Emulator, dev, stage
  and prod without provisioning any resource;
- proposed OD-07 topology for evidence review, not acceptance by implication;
- specified environment isolation, IAM, secrets, release promotion, flags,
  observability, SLO/error-budget governance, cost containment, backup/restore,
  incident and rollback contracts;
- separated operational telemetry from product analytics and domain audit;
- added exact conditional implementation map, test/evidence matrix, Open
  Decisions, 50 sequential AC and explicit unimplemented list.

## 1. Verdict

Recharge operates **one logical backend platform** with isolated `dev`,
`stage` and `prod` environments. Local Emulator Suite is a deterministic test
surface, not a fourth environment and not production evidence.

BCK-05 owns how approved backend artifacts are built, promoted, observed,
contained, backed up and recovered. It does not own domain state, authorization
policy, product analytics, Legal decisions or market/reference semantics.

This Draft creates no Firebase project, database, bucket, function, service
account, secret, deployment, backup or production data. OD-07 remains
`Proposed` until the evidence and named specialist approvals in §26 exist.
The recorded numerical baseline disposition authorizes only future test design;
it does not open G1, R0/R1 or any cloud action.

## 2. Authority and conflict priority

1. Accepted ADR.
2. Approved bounded domain/runtime slice.
3. Frozen Architecture Baseline and accepted cross-cutting policies.
4. BCK-02 coordination/gates and BCK-01 Review architecture.
5. Approved BCK-03/BCK-04/BCK-20 where applicable.
6. This BCK-05 after Approval.
7. Proposed Firebase Architecture and BCK-02-A1 only as inputs.

Conflicts involving irreversible location, IAM authority, data residency,
retention, recovery or production blast radius block Approval. A console value,
local script or deployed fact never silently supersedes repository authority.

## 3. Product outcome and measurable non-goals

### 3.1 Outcome

- one repeatable path from verified source to immutable release artifact;
- isolated environments with least-privilege identities and no shared secrets;
- server-owned default-off mutation flags and bounded emergency disable;
- measurable service health, cost and recovery evidence;
- Latvia-first activation without automatically enabling EE/LT;
- runbooks generated from actual deployed topology before production use.

### 3.2 Non-goals

- no backend/Firebase runtime in this documentation slice;
- no domain command, Firestore collection or mobile adapter implementation;
- no production project IDs, credentials or billing account identifiers;
- no claim that Firebase budgets automatically stop spending;
- no promise of zero downtime or zero data loss;
- no product analytics destination, event taxonomy or marketing consent policy;
- no microservice split, paid provider, AI or Payments enablement.

## 4. BCK-02 §14 completeness map

| # | Mandatory section | BCK-05 evidence |
|---:|---|---|
| 1 | ID/version/date/status/runtime/owner | Header |
| 2 | Parent sources/conflict priority | §2 |
| 3 | Outcome/non-goals | §3 |
| 4 | Included/excluded scope | §5 |
| 5 | Aggregate/writer/consumer ownership | §6 |
| 6 | Data classes/projections | §7 |
| 7 | Commands/queries/events/errors | §8 |
| 8 | Versions/evolution/minimum client | §9 |
| 9 | Authorization/revocation | §10 |
| 10 | Persistence/index/transaction boundaries | §11 |
| 11 | IDs/time/reference semantics | §12 |
| 12 | Idempotency/concurrency/retries/partial failure | §13 |
| 13 | Offline/cache/freshness/degraded states | §14 |
| 14 | Migration/compatibility | §15 |
| 15 | Outbox/delivery/replay/dedupe | §16 |
| 16 | Privacy/retention/export/deletion/Legal | §17 |
| 17 | Abuse/rate/App Check/fraud | §18 |
| 18 | Logs/SLO/alerts/analytics/cost | §19–21 |
| 19 | Flags/rollout/rollback/emergency disable | §22–23 |
| 20 | Exact implementation map | §24 |
| 21 | Test/evidence matrix | §25 |
| 22 | AC/DoR/DoD/unimplemented | §27–30 |

## 5. Scope

### 5.1 Included

- environment/project/resource topology and OD-07 evidence contract;
- Firestore edition/location recommendation and migration boundary;
- workload identities, privileged access, secret lifecycle and audit;
- CI/CD provenance, artifact promotion and configuration drift controls;
- operations registry, server flags and deployment state;
- operational logs, metrics, traces, SLI/SLO, alerts and incident handoff;
- quotas, budgets, cost attribution and automatic containment controls;
- Firestore backup/PITR/export, restore, reconciliation and DR evidence;
- release, rollback, emergency disable and market-safe activation;
- operations portions of OD-09 and future RUN-01/02/05/06.

### 5.2 Excluded and delegated

| Concern | Owner |
|---|---|
| API envelope/idempotency wire semantics | BCK-03 |
| AuthZ/data classes/DSR/Legal retention | BCK-04 + owning domain |
| Identity/capability lifecycle | BCK-06 |
| Domain collections/transactions/projections | BCK-06–22 |
| Reference/localization revisions | BCK-20 |
| Product analytics taxonomy/destination | BCK-21 / OD-05 |
| Trust & Safety enforcement | BCK-22 |
| Payments/provider/AI operations | Their gated BCK specs and ADR |

## 6. Operational ownership

Platform Operations is the sole writer of:

- environment registry and resource-location evidence;
- release manifests, promotion/rollback records and deployment leases;
- server flag definitions, environment/market activation state and kill-switch
  audit, without granting domain capability;
- operational SLO/budget/alert configuration and incident markers;
- backup schedules, restore drill records and recovery evidence.

Platform Operations is **not** writer of User, Page, Content, Booking, Media,
Reference Data, product analytics or domain audit facts. A repair or restore
cannot bypass owning-domain validation and reconciliation.

| Consumer | Read/use allowed | Write forbidden |
|---|---|---|
| Deployment pipeline | release manifest, environment policy | domain records |
| Domain runtime | effective operational flags/budgets | flag policy/source |
| Mobile | bounded public service status/version | environment secrets/IAM |
| Admin/Support | incident and approved operations projection | direct deploy/restore |
| BCK-21 | correlation/release/environment dimensions | operational log source |

## 7. Operational record families and classification

| Record family | Class | Source/projection | Retention owner |
|---|---|---|---|
| Environment descriptor | Operational | immutable source + sanitized status | Platform Operations |
| Resource inventory/location decision | Operational | source | Platform + Security/Privacy |
| Release manifest/promotion record | Operational | append-only source | Release Operations |
| Deployment lease/state | Operational | ephemeral source | Platform Operations |
| Server flag policy/effective snapshot | Operational | source + bounded runtime projection | Platform Operations |
| SLI samples/alerts/incidents | Operational; may become Sensitive by content | telemetry source | BCK-05 + BCK-04 |
| Cost/quota samples | Operational | provider input + aggregation | Platform Operations |
| Backup/export/restore evidence | Operational; metadata may be Sensitive | source evidence, never user export | Platform + Privacy |
| Public service status | Public/Derived | sanitized projection | Platform Operations |

Raw payloads, secrets, tokens, private locations, email, uploaded content and
authorization evidence are prohibited in operational logs by default.

## 8. Operations command/query/event contract

All surfaces inherit BCK-03 envelopes and typed failures after BCK-03
Approval. Logical operations include:

### 8.1 Commands

- `RegisterEnvironmentDescriptor`
- `PublishReleaseManifest`
- `PromoteRelease`
- `RollbackRelease`
- `SetServerFlagPolicy`
- `ActivateFlagRevision`
- `RecordBackupEvidence`
- `StartRestoreDrill`
- `CompleteRestoreDrill`
- `OpenIncidentMarker` / `ResolveIncidentMarker`

Production mutations require a change/release/incident reference, expected
revision, idempotency key and server-resolved operator authority.

### 8.2 Queries

- `GetEnvironmentStatus`
- `GetEffectiveFlags`
- `GetReleaseStatus`
- `GetOperationalHealth`
- `GetBudgetStatus`
- `GetRecoveryReadiness`

Public/mobile status is a separate sanitized projection. It never exposes
project IDs, resource names, staff identity, alert thresholds or incident
evidence that increases attackability.

### 8.3 Events

`ReleasePromoted`, `ReleaseRolledBack`, `FlagRevisionActivated`,
`BudgetThresholdCrossed`, `BackupCompleted`, `RestoreDrillCompleted` and
`IncidentStateChanged` are future internal events. Delivery follows OD-09;
until OD-09 is Accepted, cross-domain consumers remain disabled or use an
explicit synchronous bounded path owned by their slice.

### 8.4 Typed failures

Common BCK-03 codes are extended with stable domain codes such as
`environment_mismatch`, `approval_missing`, `promotion_conflict`,
`artifact_unverified`, `location_not_accepted`, `budget_guard_active`,
`restore_evidence_missing` and `unsafe_rollback`. Provider/SDK errors never
cross the boundary raw.

## 9. Versioning and compatibility

Independent versions:

- operations contract major;
- environment descriptor revision;
- release manifest revision;
- flag schema/policy/effective revision;
- SLO/budget policy revision;
- backup/restore policy revision;
- deployed application/function/rules/index artifact versions.

Unknown critical revision fails closed. A newer read-only status projection may
be displayed as unsupported/stale but never enables a mutation. Minimum mobile
client is checked by the API layer, not inferred from deployment version.

Release manifests are immutable and content-addressed. Rollback points to a
previous verified manifest; it does not edit history.

## 10. Authorization, IAM and revocation

| Actor | Allowed | Required controls | Denied |
|---|---|---|---|
| CI build identity | build/test/sign artifact | workload identity, repo/ref policy | production deploy |
| Stage deploy identity | stage promotion only | approved artifact, protected environment | prod access |
| Prod deploy identity | prod promotion/rollback | protected environment, named approval | interactive domain writes |
| Runtime service identity | exact service resources | least privilege per module/task | broad owner/editor |
| Backup identity | backup/restore metadata and exact resources | separate duty, audit | domain repair |
| Incident operator | bounded emergency actions | incident reference, TTL, audit | permanent policy bypass |
| Human maintainer | review/approve | MFA and just-in-time scope where supported | shared credentials |

Revocation is evaluated at operation time. Removing repository access does not
replace revoking cloud/IAM/session credentials. Break-glass access is
time-bounded, separately logged and reviewed after use; it cannot disable
immutable audit or reopen Security Rules.

## 11. Persistence and transaction boundaries

- version-controlled policy/manifests are canonical for intended state;
- cloud inventory is observed state and must reconcile to intended state;
- deployment history and restore evidence are append-only;
- flag activation uses expected revision and atomic effective-pointer update;
- a deployment lease prevents two promotions to one environment concurrently;
- domain data is never written in the deployment transaction;
- console-only change is drift and blocks next promotion until reconciled;
- indexes/rules/functions are independently versioned but promoted under one
  release manifest with an explicit compatibility order.

No operational collection/path is authorized by this Draft. Exact persistence
technology is decided in the executable slice after Approval.

## 12. IDs, time and reference semantics

- operation/release/incident/evidence IDs are opaque ULID/UUID strings;
- authoritative timestamps use backend UTC/RFC 3339;
- maintenance windows include IANA timezone plus normalized UTC interval;
- environment, market, country, locale, currency and timezone are separate;
- resource and policy references use stable ID + revision;
- project IDs, bucket names and function regions are deployment facts, never
  parsed into business authority;
- local Emulator uses `demo-*` identifiers and cannot be promoted.

## 13. Idempotency, concurrency and partial failure

- promotion key binds environment + target manifest + change reference;
- same key/same manifest returns the committed result;
- same key/different manifest returns `idempotency_conflict`;
- stale expected environment revision returns `revision_conflict`;
- timeout after provider call is `unknown_outcome` until observed-state
  reconciliation completes;
- retries are bounded exponential backoff with jitter and a hard attempt/deadline;
- partial artifact promotion is not success; pipeline either completes the
  ordered compatibility plan or enters typed `degraded/recovery_required`;
- rollback itself is idempotent and must not oscillate between manifests.

## 14. Offline, cache, freshness and degraded states

Operations mutations are online-only. Cached health, flags or inventory are
never deployment authority.

Required states: `fresh`, `stale`, `unavailable`, `unsupported`, `degraded`,
`unknown_outcome`, `recovery_required`. Public status may be coarser but cannot
report healthy when the authoritative status is unknown.

A domain runtime caches the last accepted fail-safe flag snapshot only when the
flag declares its outage behavior. Risky mutation flags default to disabled on
unknown/newer configuration.

## 15. Migration and compatibility

- infrastructure changes are additive and rehearsed in dev, then stage;
- immutable-location/edition change is a new-resource migration, never an
  in-place assumption;
- migration plan includes export, verification, destination configuration,
  indexes/TTL/backup recreation, cutover, rollback window and deletion hold;
- environment promotion never copies production personal data to dev/stage;
- synthetic/anonymized stage data has documented generation/provenance;
- configuration schema supports current and explicitly supported previous
  revisions; unknown critical values fail closed;
- local/mock-to-cloud imports remain owned by BCK-18/domain specs.

## 16. Tasks, events and OD-09 boundary

Scheduled/async work is disabled until the owning domain and BCK-05 define:

- producer/outbox authority and event version;
- task identity, region, max attempts, deadline, concurrency and rate;
- idempotency/deduplication key and retention;
- poison handling, replay window, ordering/gap behavior;
- cost budget, alert and emergency disable;
- privacy classification and payload minimization.

BCK-05 owns transport operation, not event business meaning. OD-09 remains
**Proposed — not Accepted** in BCK-03 until named owners accept a single
contract.

## 17. Privacy, retention and Legal boundary

- operational records are classified by contents, not by collection name;
- raw request/response bodies are not logged by default;
- access and retention follow BCK-04 and applicable domain rules;
- backup retention never silently extends lawful domain retention;
- deletion/rectification propagation into backups follows an Accepted policy
  and documented restore-time re-deletion/reconciliation procedure;
- production data export/restore requires authorized purpose and audit;
- region selection requires recorded residency/processor/transfer review;
- stage uses synthetic/anonymized data unless a separately approved exception
  provides legal basis, minimization, TTL and deletion evidence.

## 18. Abuse, rate, App Check and supply-chain controls

App Check is defense-in-depth for exposed Firebase surfaces; it is not IAM,
AuthZ or a budget stop. Required controls include:

- per-operation/user/service quotas and bounded payloads;
- provider quota monitoring and retry-storm circuit breakers;
- secret, dependency, SAST and provenance checks;
- immutable lockfiles and generated-file integrity;
- signed/attested artifacts where the selected toolchain supports them;
- webhook replay/SSRF controls in owning integration specs;
- no production mock adapter or emulator host in release artifacts.

## 19. Environments and OD-07 proposal

### 19.1 Environment isolation

| Surface | Local Emulator | dev | stage | prod |
|---|---|---|---|---|
| Purpose | deterministic tests | disposable integration | RC/migration/load rehearsal | live cohort/GA |
| Production data | prohibited | prohibited | synthetic/anonymized only | allowed after gates |
| Credentials | local demo only | separate | separate | protected, least privilege |
| Mutation flags | off unless test | default off | default off | default off until cohort gate |
| Promotion | never | verified artifact | same verified artifact | same stage-proven artifact |

Actual project IDs are assigned only in the Approved executable slice. The
examples `recharge-dev/stage/prod` in Proposed Firebase Architecture are not
reserved facts.

### 19.2 OD-07 — Proposed decision, not Accepted

The complete comparison and sign-off checklist is
[BCK-D1-OD07-EV-01](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md). Its presence is
review preparation, not decision acceptance.

OD-07 Acceptance uses dated vendor facts, explicit cost/latency models,
predeclared thresholds and an approved validation plan; it does not require
creating cloud resources first. Actual synthetic measurements are collected
only after G1 and a separately Approved R1 non-production provisioning slice,
and must pass those thresholds before production traffic. This removes a
circular dependency without weakening the irreversible-location gate.

**Recommended option A for evidence review:**

- three isolated Firebase/GCP projects: dev, stage, prod;
- Firestore **Standard edition, Native mode** initially;
- Firestore candidate location `eur3` multi-region;
- Functions candidate region `europe-west1`, explicitly configured;
- Storage uses an EU-compatible location selected with the same residency,
  latency and egress analysis; no bucket is created until exact value accepted;
- EE/LT use the same platform/projects initially with market-level activation,
  unless Legal/residency/blast-radius evidence later requires a superseding ADR;
- Analytics reporting location and any product-specific resource location are
  decided separately and recorded per resource.

Why this is only Proposed: Firestore edition/location and several resource
locations are creation-time or migration-significant choices. Acceptance
requires the evidence matrix in §26, Security/Privacy and Platform Operations
specialist approval, cost estimate and rollback/export plan.

Official verification anchors:

- <https://firebase.google.com/docs/projects/locations>
- <https://firebase.google.com/docs/firestore/locations>
- <https://firebase.google.com/docs/functions/locations>
- <https://cloud.google.com/firestore>
- <https://cloud.google.com/storage/docs/locations>
- <https://cloud.google.com/billing/docs/how-to/budgets>

## 20. CI/CD, release and provenance

Pipeline stages:

```text
source + lockfiles
  -> lint/static/boundary/contract/codegen checks
  -> unit + emulator + Rules/security tests
  -> immutable artifact + manifest + provenance
  -> dev deploy/smoke
  -> stage promotion/migration rehearsal/load/restore evidence
  -> named prod approval
  -> prod promotion with all risky flags off
  -> observation and automatic/manual containment
```

No environment rebuilds a release from a different source. Generated files are
produced by the pinned generator only. A failed, skipped, timed-out or manually
asserted gate is inconclusive and blocks promotion.

## 21. SLI/SLO, alert and cost policy

### 21.1 Service classes

| Class | Examples | Initial proposed indicators |
|---|---|---|
| C1 authority mutation | identity grant, publish, Booking | availability, error rate, latency, invariant drift |
| C2 interactive query | details, library, catalog | availability, latency, stale/error ratio |
| C3 async effect | outbox, notification, projection | age/lag, retry/poison, completion ratio |
| C4 operations | deploy, backup, restore | success, duration, evidence completeness |

Exact production objectives and measurement windows are `BCK05-OD-03`; they
must be numeric before Approval, based on stage load and cost evidence. Domain
specs may be stricter, never weaker without explicit reconciliation.

The concrete Draft proposal is
[BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md): 28-day
journey-scoped availability, latency/freshness/lag targets, zero-tolerance
invariants, burn alerts and deterministic release policy. `BCK05-OD-03` is
Proposed; stage measurement and Product/domain/Operations verdicts are absent.

Alerts are actionable: owner, severity, threshold/window, runbook, dedupe,
escalation and recovery signal are mandatory. Alert presence without tested
routing is not evidence.

### 21.2 Cost controls

- cost labels/dimensions by environment, service and bounded module where possible;
- budget thresholds proposed at 50/75/90/100% plus anomaly alerts;
- provider budget alerts are notification signals, not guaranteed hard stops;
- separate server flags/quotas/circuit breakers perform safe containment;
- stage load tests report reads, writes, storage, egress, function/task
  invocations and projected monthly cost per critical journey;
- each optional provider/AI/payment channel has its own budget and kill switch.

The concrete Draft proposal and dated unit-price model are in
[BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md): dev €25, stage €75,
prod L1 €150 and L2 €500 monthly guardrails, with L3 stress separately
authorized. `BCK05-OD-04` is Proposed; these numbers block provisioning until
Product/Finance/Operations verdict and actual EUR SKU reconciliation.

## 22. Backup, restore and disaster recovery

The initial candidate combines Firestore scheduled backups and PITR where
supported/cost-approved. Current official limits and features must be verified
again at acceptance: <https://firebase.google.com/docs/firestore/disaster-recovery>
and <https://firebase.google.com/docs/firestore/pitr>.

Required contract:

- backup schedule, retention, encryption/residency/access and cost;
- RPO/RTO by record class and service class;
- immutable evidence of backup completion and failure alerts;
- restore to isolated destination, never blind overwrite of live truth;
- schema/index/TTL/Rules/IAM/config reconstruction inventory;
- post-restore domain reconciliation and privacy re-deletion propagation;
- quarterly restore drill before source-of-truth production and after major
  topology changes;
- delete/retire procedure only after verified export, observation and owner approval.

Exact RPO/RTO/retention are `BCK05-OD-05`; no invented value is called Accepted.
The concrete Draft proposal is
[BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md): record-family recovery
classes, numerical RPO/safe/full RTO, candidate PITR/backup/Storage protection,
isolated restore, privacy re-deletion, reconciliation and drills.
`BCK05-OD-05` is Proposed; no protection or restore runtime exists.

## 23. Flags, rollout, rollback and emergency disable

Every risky capability has a server-owned flag with:

- stable ID, owner, scope (`environment`, optional `market`, capability);
- schema/policy/effective revision and default-off value;
- allowed transitions, prerequisites, expiry/review date;
- audit, propagation/freshness SLI and fail-safe outage behavior;
- explicit distinction between disable-new, read-only, drain and full deny.

Rollback layers:

1. feature containment — disable new mutations/effects safely;
2. artifact rollback — promote previous compatible verified manifest;
3. configuration rollback — restore previous accepted flag/policy revision;
4. data reconciliation — owning domain repairs through typed commands/audit;
5. disaster restore — only under the approved recovery plan.

Rules rollback never reopens access. Emergency disable cannot erase evidence or
bypass mandatory safe exits such as viewing/cancelling already committed state.

## 24. Exact conditional implementation map

The complete product/operations tree below remains a **future target**. Its
small R0-owned subset now exists only as the Approved local tooling scaffold;
all product modules and cloud/deploy authority remain absent:

```text
apps/backend/
  firebase.json
  .firebaserc.example              # aliases only; no credentials
  firestore.rules
  storage.rules
  firestore.indexes.json
  functions/
    package.json
    tsconfig.json
    src/platform/
      config/
      iam/
      flags/
      observability/
      release/
      recovery/
    test/
      unit/
      emulator/
      rules/
      integration/
      load/
      recovery/
  config/
    environment.schema.json
    region-policy.schema.json
    flag-policy.schema.json
    slo-policy.schema.json
    budget-policy.schema.json
  scripts/
    verify-config.*
    verify-release-manifest.*
    seed-emulator.*
    backup-evidence.*
    restore-drill.*

docs/runbooks/
  backend-incident.md
  backend-rollback.md
  backend-disaster-recovery.md
  backend-security-abuse.md
```

Executable slice must replace `*` with one cross-platform implementation path,
pin runtime/tool versions, identify exact files and prove no generated/manual
or secret content. Runbooks are authored from real topology, not this target map.

## 25. Test and evidence matrix

| Family | Required proof | First gate |
|---|---|---|
| Config schema | invalid/unknown environment/location/flag fails closed | R0 |
| Unit | promotion, flags, retry, budget and recovery policy | R0 |
| Contract/fixture | BCK-03 parity and compatible revisions | R0 |
| Emulator | Functions/Firestore/Storage integration | R0/R1 |
| Rules/IAM negative | direct/cross-env/cross-user/cross-page denied | R1/R2 |
| Environment isolation | prod cannot select mock/dev/stage resources | R1 |
| Provenance | same verified artifact promoted; no manual generated edit | R1 |
| Drift | console/cloud state differs from repository intent and blocks | R1 |
| Flags | default-off, scope, revocation, stale/newer fail-safe | Every rollout |
| Retry/fault | duplicate/timeout/partial promotion safe | R1 |
| Load/soak | SLI and cost per critical flow | G5/G6 |
| Budget/quota | thresholds route; containment works independently | G5 |
| Backup | schedule/failure/access/residency evidence | G5 |
| Restore/DR | isolated restore + reconciliation within accepted RTO/RPO | G6 |
| Rollback | artifact/config/data paths rehearsed on stage | G5/G6 |
| Incident | alert-to-owner/runbook/tabletop evidence | G6 |
| Market isolation | LV change does not enable EE/LT | Every market gate |
| Privacy/security | log redaction, access, retention, deletion propagation | G5/G6 |

Evidence includes commit/build/manifest ID, environment, UTC date, exact
command, result, owner and limitations. Emulator success is not proof of real
indexes, IAM, provider configuration, billing, backup or latency.

## 26. Open decisions

| ID | Status | Owner | Decision/evidence | Blocks |
|---|---|---|---|---|
| OD-07 | Proposed option A | Platform + Security/Privacy | edition, project separation, exact per-resource location, residency/latency/cost/export review | BCK-05 Approval, G1/R1 |
| BCK05-OD-01 | Proposed | Platform Operations + Platform Security | [BCK05-OD01-TCH-01 v0.3.3](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md), [technical review v0.2.3](BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md), [R0 decision record v0.2](BACKEND_R0_APPROVAL_DECISION_RECORD.md) and [execution result](../evidence/backend/r0/BCK-R0-TCH-01_RESULT.md): bounded R0 local/hosted evidence is Pass and `BCK-R0-TCH-ADV-01` controls the residual Moderate risk through `2026-09-24` or earlier scope expansion; OD-01 still lacks separate acceptance and production evidence | separate OD-01 owner/security acceptance |
| BCK05-OD-02 | Proposed | Platform Security/Operations | [BCK05-OD02-IAM-01](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md): keyless OIDC/WIF, isolated identities, permissions, approvals, lifecycle and break-glass; exact claims/roles/plan/JIT/runtime evidence pending | BCK-05 Approval |
| BCK05-OD-03 | Proposed | Platform Operations + domain owners | [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md): Product baseline recorded; stage telemetry/alerts and specialist verdict pending | BCK-05 Approval |
| BCK05-OD-04 | Proposed | Product + Finance/Operations | [BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md): Product baseline recorded; Finance remains Inconclusive pending EUR SKU/tax/stage evidence | R1 provisioning |
| BCK05-OD-05 | Proposed | Platform + Privacy + domains | [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md): Product baseline recorded; drills, IAM/privacy and specialist verdicts pending | BCK-05 Approval |
| BCK05-OD-06 | Open | API Platform + Operations | OD-09 transport/task topology and delivery operations | D1 exit minimum Proposed; D3 effects Accepted |
| BCK05-OD-07 | Proposed | Release Operations + Platform Security | [BCK05-OD07-REL-01](BACKEND_RELEASE_PROVENANCE_PROMOTION_MODEL.md): immutable manifest, provenance, Functions/container boundary, promotion and rollback; exact toolchain/attestor/registry/policy/runtime evidence pending | executable R0 |
| BCK05-OD-08 | Proposed | Incident/Security owners | [BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) plus ready-but-unexecuted [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md); real routes/break-glass/executable evidence and completed result pending | G5/G6 |

Each Open/Proposed decision has a fail-closed default above. Acceptance records
option, evidence links, reviewers, decision date, migration and rollback.

OD-09 failure/compatibility review evidence is maintained in
[BCK-D1-OD09-EV-01](BACKEND_OD_09_EVENT_DELIVERY_EVIDENCE.md); transport and
worker activation stay blocked.

## 27. Definition of Ready for Review

- BCK-01 is Review and BCK-02 lists BCK-05 Present/Draft;
- 22/22 coverage matrix exists and links pass;
- Platform Operations accountable person/team is named;
- Security/Privacy reviews OD-07 and log/backup boundaries;
- BCK-03/04 conflicts are explicitly listed, not assumed resolved;
- no project/resource/credential/runtime file is created;
- all Open Decisions have owner, gate and fail-closed default.

Current readiness: the Platform Operations and delegated Security/Legal/Finance
roles are assigned to the combined owner in
[BCK-D1-SIG-01](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md). IAM and release
design evidence is now Present and OD-02/07 are Proposed, but exact claim/role/
toolchain/provider decisions, specialist verdicts, qualified Legal evidence,
actual EUR SKU and measured stage/restore/runtime proof remain absent. BCK-05
therefore remains Draft.

## 28. Definition of Done for Approved BCK-05

- BCK-03, BCK-04 and BCK-20 are ready and Approved/reconciled atomically as
  the D1 platform set where required;
- OD-07 is Accepted with exact project/edition/location evidence;
- OD-09 is at least Proposed for D1 and accepted before effects/workers;
- BCK05-OD-01–05, 07 and 08 are Accepted or explicitly Deferred without
  bypassing their gates;
- numeric SLO, cost, RPO/RTO and retention policies are recorded;
- IAM, secrets, environment isolation, release, flags, observability, backup,
  restore, incident and rollback plans are reviewable and consistent;
- 50 AC are sequential and coverage/reconciliation checks pass;
- runtime remains Absent until a separate Approved executable slice.

## 29. Acceptance criteria

1. **BCK-05-AC-01:** one operations standard governs the logical backend.
2. **BCK-05-AC-02:** dev, stage and prod are isolated environments.
3. **BCK-05-AC-03:** Local Emulator is not a production environment/evidence.
4. **BCK-05-AC-04:** production cannot select mock, emulator or dev adapters.
5. **BCK-05-AC-05:** project/resource creation waits for Accepted OD-07.
6. **BCK-05-AC-06:** OD-07 records edition and every location independently.
7. **BCK-05-AC-07:** Standard/Native/`eur3`/`europe-west1` remain Proposed in v0.2.7.
8. **BCK-05-AC-08:** LV activation never enables EE/LT implicitly.
9. **BCK-05-AC-09:** one writer owns each operational record family.
10. **BCK-05-AC-10:** Operations cannot mutate domain authority directly.
11. **BCK-05-AC-11:** intended repository state reconciles observed cloud state.
12. **BCK-05-AC-12:** console-only drift blocks promotion.
13. **BCK-05-AC-13:** releases are immutable/content-addressed manifests.
14. **BCK-05-AC-14:** the same verified artifact is promoted across environments.
15. **BCK-05-AC-15:** skipped/timed-out/manual gate is inconclusive, not pass.
16. **BCK-05-AC-16:** generated artifacts are never manually edited.
17. **BCK-05-AC-17:** CI and runtime use separate least-privilege identities.
18. **BCK-05-AC-18:** production deploy requires protected named approval.
19. **BCK-05-AC-19:** revocation is checked at operation time.
20. **BCK-05-AC-20:** break-glass is TTL-bound, audited and reviewed.
21. **BCK-05-AC-21:** secrets never enter Git/docs/logs/client artifacts.
22. **BCK-05-AC-22:** provider raw errors/secrets never cross the API boundary.
23. **BCK-05-AC-23:** promotions use idempotency and expected revision.
24. **BCK-05-AC-24:** mutation timeout produces typed unknown outcome.
25. **BCK-05-AC-25:** partial promotion is never reported as success.
26. **BCK-05-AC-26:** operations mutations are online-only.
27. **BCK-05-AC-27:** cached health/flags never become deployment authority.
28. **BCK-05-AC-28:** unknown critical config fails closed.
29. **BCK-05-AC-29:** risky flags default off on missing/stale/newer config.
30. **BCK-05-AC-30:** every flag has owner/scope/revision/audit/outage behavior.
31. **BCK-05-AC-31:** Remote Config/client flags cannot authorize server mutation.
32. **BCK-05-AC-32:** operational telemetry is separate from product analytics.
33. **BCK-05-AC-33:** logs exclude raw sensitive payloads by default.
34. **BCK-05-AC-34:** alerts have owner, severity, runbook and recovery signal.
35. **BCK-05-AC-35:** numeric SLO/error budgets are required before Approval.
36. **BCK-05-AC-36:** budgets/alerts do not claim automatic spend shutdown.
37. **BCK-05-AC-37:** containment uses independent quotas/flags/circuit breakers.
38. **BCK-05-AC-38:** load evidence reports unit cost per critical flow.
39. **BCK-05-AC-39:** backup metadata never substitutes restore proof.
40. **BCK-05-AC-40:** restore occurs into isolation before reconciliation.
41. **BCK-05-AC-41:** RPO/RTO/retention require recorded owner approval.
42. **BCK-05-AC-42:** restored data passes privacy re-deletion/reconciliation.
43. **BCK-05-AC-43:** Rules rollback never reopens access.
44. **BCK-05-AC-44:** artifact/config/data/DR rollback are distinct.
45. **BCK-05-AC-45:** OD-09 governs async delivery/replay/dedupe/poison handling.
46. **BCK-05-AC-46:** every task has bounded attempts/deadline/rate/concurrency.
47. **BCK-05-AC-47:** runbooks derive from actual deployed topology.
48. **BCK-05-AC-48:** target file map is not runtime authorization.
49. **BCK-05-AC-49:** Approval still requires a separate executable slice/G1.
50. **BCK-05-AC-50:** v0.2.3 creates no backend/Firebase/resource/runtime effect.

AC numbers are stable; new criteria append. Semantic removal/change requires a
new revision and reference migration note.

## 30. Explicitly unimplemented

At v0.2.15 the following remain absent:

- product/domain backend modules and handlers beyond the local R0 scaffold;
- Firebase/GCP projects, databases, buckets, functions and app registrations;
- IAM/service accounts/workload identity and production credentials;
- deploy pipelines, manifests, flags, telemetry, alerts and budgets;
- backups, PITR/export schedules, restore drills and backend runbooks;
- accepted numeric SLO/RPO/RTO/cost limits;
- OD-07/OD-09 acceptance;
- production data, migration, traffic or activation.

## 31. Next action

1. confirm BCK-05 coverage/reconciliation matrix;
2. assign named Platform Operations and specialist reviewers;
3. resolve OD-07 and BCK05-OD-01–05/07/08 evidence;
4. reconcile with BCK-03/04/20;
5. move BCK-05 to Review, then Approved only when DoD is satisfied;
6. preserve hosted parity and monitor/re-audit the expiring
   `BCK-R0-TCH-ADV-01` disposition; keep R1 and every cloud/product resource
   blocked until G1 and a separately Approved executable file plan.
