# Recharge Backend — Product Analytics & Telemetry Specification

- ID: **BCK-21**
- Version: **0.2**
- Status: **Review — documentation only; approval and owner decisions pending**
- Runtime status: **Absent**
- Date: **2026-08-26**
- Owner: **Data Platform owner**
- Required reviewers: **Security/Privacy, Legal/Privacy, Product, API Platform,
  Mobile Platform, Platform Operations, Identity and domain owners**

## 0. Changelog

### v0.2 — 2026-08-26

- completed all 22 BCK-02 design categories;
- separated product analytics from operational telemetry, domain events, audit
  records and enforcement authority;
- audited the current taxonomy/catalog/runtime and made its gaps explicit;
- defined a vendor-neutral, consent/purpose-aware ingestion and dataset model;
- added pseudonymization, DSR, retention, sampling, metric, experiment, access,
  migration, rollout and rollback contracts;
- recorded 60 sequential acceptance criteria and ten owner decisions;
- did not change mobile/backend runtime, Firebase or analytics destinations.

### v0.1 — 2026-08-26

- initial coverage and reconciliation draft.

## 1. Verdict and status semantics

BCK-21 v0.2 is a complete **Review contract**, not implementation authority.

- **Present** means this file exists;
- **Review** means contradictions and owner decisions are reviewable;
- **Approved** requires qualified verdicts and closed blocking decisions;
- **Runtime Absent** means no production ingestion/dataset exists;
- current console telemetry is compatibility evidence, not backend truth.

This document authorizes no Firebase Analytics, BigQuery, third-party SDK,
collector, dataset, IAM grant, billing, production processing or deployment.

## 2. Parents, priority and reconciliation

BCK-21 inherits:

1. Accepted ADRs in `docs/adr/`;
2. [RECHARGE_BACKEND_MASTER_SPEC.md](RECHARGE_BACKEND_MASTER_SPEC.md) (`BCK-01`);
3. [RECHARGE_BACKEND_DELIVERY_MAP.md](RECHARGE_BACKEND_DELIVERY_MAP.md) (`BCK-02`);
4. [BACKEND_API_CONTRACT_STANDARD.md](BACKEND_API_CONTRACT_STANDARD.md) (`BCK-03`);
5. [BACKEND_SECURITY_PRIVACY_SPEC.md](BACKEND_SECURITY_PRIVACY_SPEC.md) (`BCK-04`);
6. [BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
   (`BCK-05`);
7. [IDENTITY_PUBLISHER_BACKEND_SPEC.md](IDENTITY_PUBLISHER_BACKEND_SPEC.md)
   (`BCK-06`);
8. [MOBILE_BACKEND_INTEGRATION_STANDARD.md](MOBILE_BACKEND_INTEGRATION_STANDARD.md)
   (`BCK-18`);
9. [ANALYTICS_TAXONOMY.md](../analytics/ANALYTICS_TAXONOMY.md) and
   [EVENT_CATALOG.md](../analytics/EVENT_CATALOG.md) as legacy/local governance
   inputs, not production-safe contracts.

Authority remains explicit:

- BCK-05 owns operational logs, metrics, traces, SLOs and alerts;
- domain owners own domain facts and audit records;
- BCK-21 owns governed product-event ingestion, curated datasets and metrics;
- BCK-04 owns privacy/legal/DSR constraints;
- BCK-06 owns identity and account lifecycle;
- BCK-19 owns audited privileged-tool workflow;
- BCK-22 owns abuse/enforcement decisions.

Shared correlation does not merge purpose, access, retention or ownership.

## 3. Outcome and non-goals

### 3.1 Outcome

BCK-21 defines a privacy-safe product analytics platform that answers reviewed
product questions using versioned events, curated datasets and reproducible
metrics. Collection is optional to product correctness and can be disabled
without breaking user journeys.

### 3.2 Non-goals

BCK-21 is not:

- a logging/SIEM/alerting system;
- a domain event bus or source of business truth;
- an authorization, fraud, moderation or sanction engine;
- advertising attribution, cross-app tracking or data brokerage;
- a raw free-text/search/prompt/location archive;
- a replacement for DSR/audit/financial/Booking records;
- permission to personalize/rank or run experiments automatically.

## 4. Scope and initial posture

### 4.1 In scope

- versioned event registry and parameter schemas;
- policy/consent-aware client and server ingestion;
- validation, minimization, pseudonymization and deduplication;
- bounded raw, curated and aggregate data zones;
- governed metric definitions and dashboard contracts;
- optional experiment measurement boundary;
- access review, DSR, retention and deletion;
- quality, lineage, sampling, cost and rollback controls.

### 4.2 Disabled until later gates

- production event transport/destination (`OD-05` Open);
- persistent pre-auth or cross-session identifiers;
- third-party analytics/marketing SDKs;
- ad identifiers, fingerprinting or cross-purpose joins;
- raw-event self-service access/export;
- personalization, experiments and automated decisions;
- raw historical-log or console-telemetry import.

## 5. Ownership and single writers

| Record/projection | Writer | Consumers |
|---|---|---|
| AnalyticsEventDefinition | Analytics governance command | SDK/codegen/validator |
| CollectionPolicy | Privacy + Analytics approved command | Client/ingress |
| IngestionReceipt | Analytics ingress | Mobile/reconciliation |
| AcceptedRawEvent | Analytics ingress only | Curated pipeline/DSR |
| CuratedDatasetRow | Dataset transform | Approved metric jobs |
| MetricDefinition | Analytics governance command | Metric jobs/dashboards |
| MetricSnapshot | Metric computation job | Governed consumers |
| ExperimentDefinition/Assignment | Future experiment authority | Measurement only |
| Operational signal | BCK-05 | BCK-21 bounded correlation consumer |
| Domain/audit fact | Owning domain | BCK-21 allowlisted derivative input |

No mobile client, dashboard, notebook, vendor console or staff user writes
accepted events, metric snapshots or catalog definitions directly.

## 6. Actors, roles and trust boundaries

| Actor | Allowed | Denied |
|---|---|---|
| Mobile client | Submit allowlisted bounded event batch | Choose purpose/identity joins |
| Backend producer | Submit registered server event | Copy raw domain payload |
| Ingress service | Validate/minimize/pseudonymize/receipt | Invent business outcome |
| Dataset worker | Deterministic versioned transform | Direct source mutation |
| Analyst | Governed aggregate/curated query | Unapproved raw export |
| Product owner | Propose event/metric/experiment | Grant own data access |
| Privacy/Security | Approve policy/access/deletion controls | Rewrite product facts |
| Support/Admin | BCK-19 case-scoped tools | Impersonation/direct dataset write |

Human access uses dedicated identity, MFA, least privilege, time-bound elevation
where required and immutable query/export audit.

## 7. Data model

### 7.1 AnalyticsEventDefinition

```text
AnalyticsEventDefinition {
  eventName
  eventVersion
  status                 // draft | active | deprecated | removed
  productQuestion
  triggerSemantics
  purposeId
  legalPolicyRef
  ownerRefs
  allowedProducers
  parameterSchema[]
  subjectMode
  samplingPolicyRef?
  retentionClass
  introducedAtUtc
  deprecatedAtUtc?
  replacementRef?
  removalAtUtc?
}
```

Every parameter defines type, requiredness, enum/bucket/range, data class,
cardinality bound, null semantics, join permission and redaction rule. Generic
maps and arbitrary strings are forbidden in an active definition.

### 7.2 ProductAnalyticsEventEnvelope

```text
ProductAnalyticsEventEnvelope {
  eventId
  eventName
  eventVersion
  occurredAtUtc
  clientSequence?
  appRelease
  platform
  environment
  market
  locale?
  sessionKey?
  subjectKey?
  policyRevision
  consentSnapshotRef?
  samplingDecision
  parameters
}
```

`receivedAtUtc`, producer identity and validation result are added by ingress.
The client never sends a raw account ID as `subjectKey`.

### 7.3 CollectionPolicy

```text
CollectionPolicy {
  policyRevision
  purposeId
  market
  legalBasisDecisionRef
  consentRequired
  allowedEventRefs
  subjectMode
  destinationRef
  effectiveFromUtc
  expiresAtUtc?
  killSwitchState
}
```

Unknown, expired, wrong-market or disabled policy blocks transmission.

### 7.4 IngestionReceipt and quarantine

Receipt records event/batch ID, accepted/rejected/duplicate result, definition
revision and safe reason codes. Rejection does not store the arbitrary payload.
Quarantine stores only minimized diagnostic metadata by default; payload samples
require separate restricted, time-bounded policy and must pass redaction first.

### 7.5 DatasetDefinition and MetricDefinition

Dataset definition records sources, schema, transformation version, lineage,
owner, access class, partitioning, freshness and retention. Metric definition
records business question, numerator, denominator, unit, grain, filters,
inclusion/exclusion, timezone/calendar, late-data rule, correction policy,
minimum privacy threshold and owner. Dashboard labels are not metric authority.

## 8. Data classes and prohibited payloads

`analytics` is a purpose/record-kind label, not a data class. Raw or
pseudonymous events are usually Protected and can become Sensitive by content.
Only genuinely anonymized/aggregated output may be treated as Derived.

Forbidden by default:

- email, phone, full name, exact address or contacts;
- raw account/page/workspace/content/notification/draft/Booking IDs;
- advertising ID, hardware ID, IP copy or fingerprint;
- precise coordinates, GPS track or unbucketed location history;
- search query, Smart Search prompt, notes, messages, review body or description;
- media, access token, code, secret, evidence or raw error/stack trace;
- full URLs/deep links with parameters;
- small-cohort dimensions that make a person inferable;
- arbitrary map/string payloads or values outside definition allowlists.

Stable internal IDs are not automatically anonymous. Existing taxonomy wording
that allows `user_id` does not authorize production transmission.

## 9. Subject, session and identity strategy

For authenticated analytics, ingress derives a purpose/environment/key-epoch
scoped pseudonymous key:

```text
subjectKey = HMAC(keyEpoch, environment || purposeId || internalUserId)
```

- raw `internalUserId` is not stored in the event;
- keys do not join across environments or purposes;
- rotation epoch is recorded;
- old key material is restricted to deletion/reconciliation duties until its
  retained events expire;
- DSR deletion recomputes retained epoch keys under controlled service identity;
- session keys are random, bounded and not reused as device identity;
- pre-auth collection, if accepted, has no stable cross-session identifier;
- sign-out ends the analytics session and clears queued subject association.

Hashing an email/phone or using an unsalted account ID is prohibited.

Object, publisher and workspace analysis uses an allowlisted purpose-scoped
opaque `dimensionKey` minted or resolved by the owning backend projection. A
client never persists a universal catalog/page/workspace ID in analytics. If an
ingress command must resolve an exact source reference, it validates authority,
derives the scoped key and discards the source reference before accepting the
event. Small-volume publisher/object output remains subject to privacy thresholds.

## 10. Registry, lifecycle and code generation

Event lifecycle is `draft -> active -> deprecated -> removed`. Activation
requires named owners, product question, exact schema, purpose/policy, tests,
retention and consumers. Deprecation requires replacement if applicable,
announce date, last-supported release, removal date and dashboard migration.

Runtime producers use generated/typed definitions or an equivalent compile-time
allowlist. Unknown event names/versions/parameters fail closed at ingress. A
schema change that alters meaning, type, requiredness, enum or privacy behavior
creates a new event version; it is never silently edited in place.

## 11. Ingestion commands and authorization

| Command | Principal | Invariant |
|---|---|---|
| `analytics.ingestBatch` | Attested client/backend producer | Definition/policy/schema validation |
| `analytics.publishDefinition` | Governance capability | Approved review evidence |
| `analytics.deprecateDefinition` | Governance capability | Replacement/removal plan |
| `analytics.publishMetric` | Governance capability | Reproducible definition/lineage |
| `analytics.requestDatasetAccess` | Named staff identity | Purpose/scope/expiry/approval |
| `analytics.revokeDatasetAccess` | Data owner/Security | Immediate deny and audit |
| `analytics.executeSubjectDeletion` | DSR service | Exact retained key epochs/replay-safe |
| `analytics.rebuildDataset` | Service identity | Versioned source/transform/manifest |

Client collection policy is presentation/planning input only. Ingress validates
effective policy, producer, market, release and consent/legal-basis state.

## 12. Query and access model

Default product access is to approved metric snapshots and sufficiently large
aggregates. Curated row-level access is exceptional, time-bound and audited.
Raw events are service/DSR restricted and unavailable to ordinary dashboards.

Queries have dataset/metric version, allowed dimensions, date bounds, row/byte
limits and privacy threshold. Results that fall below the accepted threshold are
suppressed/coarsened; thresholds cannot be bypassed by repeated slicing.
A server-owned release ledger records consumer, query fingerprint, overlapping
cohort/window and released granularity so differencing/repeated-query attacks can
be denied or coarsened under the Accepted policy.

Export requires purpose, case/request ID, approver, bounded columns/date range,
expiry, watermark and audit. Copying raw data to personal spreadsheets, chat,
email or unmanaged storage is prohibited.

## 13. Collection and ingestion pipeline

```text
Producer
  -> typed client/server schema guard
  -> effective policy and consent gate
  -> bounded encrypted queue/batch
  -> attested ingestion endpoint
  -> registry/schema/size/time validation
  -> minimization and server pseudonymization
  -> idempotency receipt + accepted raw zone
  -> versioned curated transform
  -> governed metric/aggregate
```

Invalid payload creates a typed receipt and privacy-minimized diagnostic. The
pipeline never treats ingestion success as proof that a product action itself
succeeded; authoritative domain events remain with the owning domain.

## 14. Time, ordering, idempotency and late data

- client-generated permanent event ID and batch ID;
- `occurredAtUtc` is bounded against server `receivedAtUtc`;
- server time controls retention and ingestion order;
- clock skew is bucketed, not copied as device diagnostics;
- same event ID/schema/payload is duplicate success without another row;
- same ID/different payload is rejected and alerted safely;
- client sequence is scoped to one analytics session only;
- no global total ordering claim;
- late-arrival window and metric correction are definition-owned;
- events outside accepted window are rejected or isolated, never silently
  inserted into published historical metrics.

## 15. Sampling, batching and offline behavior

- sampling is versioned, deterministic for its approved unit and decided before
  collection where possible;
- inclusion probability/policy revision accompanies accepted data;
- metrics apply documented weighting or explicitly do not extrapolate;
- errors/rare cohorts are not oversampled without privacy review;
- on-device queue has count/byte/age/retry limits and encryption;
- consent withdrawal/kill switch clears no-longer-lawful queued events;
- retries preserve event IDs and use bounded backoff/jitter;
- product flow never waits for analytics delivery;
- background transmission follows platform/user network/battery policy;
- offline events do not bypass an expired policy on reconnect.

## 16. Curated datasets, lineage and data quality

Every dataset build is reproducible from accepted source partitions plus an
immutable transform version/manifest. It records input watermark, output schema,
row counts, rejected counts, completion status and checksum/fingerprint.

Quality checks cover completeness, validity, uniqueness, consistency,
timeliness, schema drift, null/enum/range distribution, cardinality explosion,
duplicate/replay ratio, late data and internal/test/bot traffic. Failed quality
gates prevent dataset/metric promotion; they do not silently publish partial data.

## 17. Metrics and dashboard governance

- one canonical definition per metric ID/version;
- numerator/denominator and eligible population are explicit;
- count, user, session, conversion and retention units are never mixed;
- calendar/timezone and cohort entry/exit rules are explicit;
- missing data, sampling, consent coverage and late corrections are disclosed;
- dashboard numbers link to metric/dataset revisions and freshness;
- metric changes create a new version and preserve comparison notes;
- no metric is used for financial/audit/Booking authority;
- no small-cohort ranking or individual employee/creator surveillance;
- metric owner reviews continued necessity and consumers periodically.

## 18. Experiments and personalization boundary

Experimentation is disabled until separately accepted. A future experiment
requires hypothesis, owner, target population, assignment unit, exposure event,
primary/guardrail metrics, duration/stop policy, power/analysis plan, mutual
exclusion, consent/legal review, kill switch and result record.

Assignment is separate from outcome measurement. Only actual exposure enters
exposure analysis; intention-to-treat remains available. Peeking, silent metric
switching and unregistered subgroup mining cannot produce an Accepted result.

No experiment may change safety, access, price, Booking inventory, moderation,
minors/age-sensitive eligibility or other significant decisions without the
owning domain and applicable DPIA/Article 22 safeguards. Analytics data does not
authorize personalized Discover ranking by implication.

## 19. Privacy, consent and legal basis

Every event has one declared purpose and a qualified per-market legal-basis
decision. BCK-21 does not declare all analytics consent-based or legitimate-
interest-based by default.

- consent-based collection is explicit opt-in in the EU and withdrawal is as
  easy as granting consent;
- withdrawal stops future applicable collection and clears queued events;
- necessary operational telemetry remains BCK-05, not relabelled analytics;
- purpose/basis/recipient change requires notice/policy review before collection;
- third-party destination requires DPA/subprocessor/transfer/residency/deletion
  and platform disclosure review;
- SDK/device storage, ad tracking and applicable ePrivacy/ATT/store disclosures
  are reviewed independently;
- minors, profiling and large-scale tracking invoke OD-11/DPIA/Article 22 gates
  where applicable;
- product remains usable when optional analytics is declined.

## 20. Retention, DSR, deletion and anonymization

| Family | Required policy | No implicit default |
|---|---|---|
| On-device queue | Short bounded age/count/bytes and withdrawal clear | Yes |
| Accepted raw/pseudonymous event | Purpose-specific active/terminal retention | Yes |
| Quarantine sample | Short restricted retention and deletion | Yes |
| Curated pseudonymous row | Dataset-specific retention/lineage | Yes |
| Anonymous aggregate | Re-identification test and minimum cohort | Yes |
| Definition/metric lineage | Governance lifecycle | Yes |
| Access/export/deletion audit | Operational retention | Yes |

BCK-04 provides no generic analytics retention. Exact numbers, triggers,
exceptions and deletion/anonymization actions require `BCK21-OD-04` and qualified
review. Pseudonymous is not anonymous.

DSR supports access, deletion, restriction and applicable portability for
identifiable/pseudonymous records. Deletion is replay-safe across raw, curated,
cache/export and downstream datasets. Truly anonymous aggregates cannot be
linked back and are documented as such only after an approved re-identification
risk test. Backup restore cannot reactivate deleted subject data.

## 21. Security and abuse controls

- authenticated/attested bounded producers and environment isolation;
- default-deny dataset/IAM roles and separate service identities;
- schema/size/rate/cardinality limits before persistence;
- replay/idempotency and poison-batch isolation;
- server pseudonymization keys in managed secret/KMS boundary with rotation;
- no secrets/raw bodies in logs or diagnostics;
- analyst query/export audit and recurring access review;
- malicious parameter names/Unicode/formulas/URLs treated as untrusted data;
- internal/test traffic marked by trusted environment, not client flag;
- BCK-22 receives only reviewed abuse signals and remains decision authority;
- compromised destination/SDK/credential has independent kill switch and
  incident/deletion playbook.

Ingress network metadata such as source IP, TLS details and request headers is
not copied into product analytics. Any minimally necessary security/operations
record remains separately governed by BCK-05/BCK-04 purpose and retention.

## 22. Observability, SLO and cost boundary

BCK-05 monitors ingestion availability/latency/error, queue lag, transform lag,
quality failures, DSR jobs, storage/query volume and spend. BCK-21 defines
product-data correctness signals and safe dimensions. Operational telemetry may
use event/batch/correlation IDs but not analytics payload content.

Exact SLOs, alert thresholds, capacity, quotas and budgets require BCK-05 and
OD-05 evidence. Analytics backpressure drops/defers optional events rather than
degrading product authority paths. Cost anomaly can disable collection safely.

## 23. Migration and current-runtime compatibility

Repository snapshot on 2026-08-26:

- `ConsoleAnalyticsService` writes event parameters to developer logs;
- it does not construct the required production envelope;
- 66 distinct literal event names are emitted in mobile source;
- the catalog has 27 actual event definitions and all 27 owner columns are TBD;
- at least 45 emitted literal names are absent from the catalog;
- six catalogued names are not found as literal emitters;
- current calls include raw user/workspace/item/notification IDs;
- catalog/taxonomy entries are not production-safe schemas or owner evidence.

These counts are audit evidence, not a permanent invariant; dynamic emitters may
require additional inventory. Existing logs/console output are not imported or
backfilled. Cutover requires inventory, owner assignment, exact typed definition,
payload privacy review, producer mapping, dual-observation without double count,
kill switch and deletion/rollback evidence. Unsafe events are removed or remain
local-disabled; they are not grandfathered.

## 24. Flags, rollout and rollback

Independent server-controlled flags cover collection globally and by
environment/market/cohort/release, each purpose, authenticated/pre-auth events,
server producers, raw retention, curated transforms, metric publication,
experiments and each destination. Defaults are off.

Rollout: emulator/synthetic -> dev -> stage -> internal cohort -> Latvia cohort
-> Latvia GA; EE/LT enable independently after their legal/policy review.
Rollback disables collection/destination/transforms/metrics independently,
preserves governance/audit/DSR truth and never fabricates missing metrics.

## 25. Dependencies and delivery gates

| Gate | Requirement | Effect |
|---|---|---|
| Review | 22/22 coverage; decisions assigned; runtime inventory | Docs only |
| Approval | BCK-03/04/05 compatible; OD-05 and BCK21 decisions resolved | No runtime |
| Runtime foundation | Typed registry/contracts, IAM, destination, deletion | Dev candidate |
| Persistent stage | Security/privacy/access/retention/SLO/cost evidence | Stage candidate |
| Latvia cohort | Legal/store notice, consent, DSR, quality/rollback evidence | Bounded enablement |
| GA | Cohort observation and owner sign-off | Latvia only |

No runtime begins while OD-05 is Open. Experiment/personalization has its own
later gate even after base analytics is enabled.

## 26. Conditional exact file map

No path below is authorized by this Review:

```text
apps/backend/src/modules/analytics/
  domain/
    analytics_event_definition.ts
    collection_policy.ts
    dataset_definition.ts
    metric_definition.ts
    experiment_definition.ts
    analytics_failures.ts
  application/
    ingest_event_batch.ts
    publish_event_definition.ts
    publish_metric_definition.ts
    request_dataset_access.ts
    execute_subject_deletion.ts
    rebuild_dataset.ts
  infrastructure/
    analytics_ingress.ts
    subject_pseudonymizer.ts
    raw_event_repository.ts
    curated_dataset_repository.ts
    metric_repository.ts
    analytics_destination_port.ts
  transport/
    analytics_commands.ts
    analytics_queries.ts
  workers/
    curate_analytics_dataset.ts
    compute_metric_snapshot.ts
    delete_analytics_subject.ts
apps/backend/test/modules/analytics/
packages/api_contracts/schemas/analytics/v1/
packages/api_contracts/fixtures/analytics/v1/
docs/analytics/definitions/
docs/runbooks/backend-analytics-privacy.md
```

Exact technology, destination, paths, schemas and indexes require an Approved
runtime slice and fresh repository audit.

## 27. Test and evidence matrix

| Area | Required evidence |
|---|---|
| Registry | Unknown/version/param/type/enum/cardinality fail closed |
| Privacy | Forbidden payload corpus, redaction and pseudonymization |
| Identity | Purpose/environment/epoch isolation and rotation |
| Consent | Grant/withdraw/expiry/wrong market/offline queue clear |
| Ingestion | Batch limits, dedupe, conflict, retry, poison isolation |
| Time | Skew, order, late window and correction |
| Sampling | Determinism, probability, weighting/disclosure |
| Dataset | Rebuild, lineage, checksum, partial-failure denial |
| Metric | Numerator/denominator/timezone/version reproducibility |
| Access | IAM denial, JIT expiry, query/export audit |
| DSR | Epoch-key lookup, delete/restrict/export and backup restore |
| Migration | 66/27 inventory, unsafe ID denial, no log backfill |
| Emulator | Default deny, service-only writes and environment isolation |
| Load/cost | Throughput, backpressure, storage/query budget |
| Rollback | Collection/destination/transform/metric independent disable |

All fixtures are synthetic and intentionally include invalid privacy cases.

## 28. Definition of Ready and Done

Review DoR requires 22/22 categories, current-runtime reconciliation, one
writer per record, sequential AC, owned decisions and fail-closed defaults.
This v0.2 meets documentation DoR only.

Implementation Done additionally requires Approved spec/decisions, typed
contracts/codegen, destination/IAM, security/privacy/legal evidence, tests above,
accepted retention/DSR/SLO/cost, stage and Latvia cohort evidence, rollback and
synchronized registries. Documentation does not satisfy runtime Done.

## 29. Acceptance criteria

1. **BCK-21-AC-01:** BCK-21 remains Review/docs-only until Approval.
2. **BCK-21-AC-02:** Product analytics runtime/destination remains Absent.
3. **BCK-21-AC-03:** Product analytics is separate from BCK-05 telemetry.
4. **BCK-21-AC-04:** Analytics never becomes domain/audit authority.
5. **BCK-21-AC-05:** BCK-22 remains enforcement decision owner.
6. **BCK-21-AC-06:** Every event has a product question and named owners.
7. **BCK-21-AC-07:** Every event/version has an exact parameter schema.
8. **BCK-21-AC-08:** Arbitrary maps/strings fail closed.
9. **BCK-21-AC-09:** Schema semantic changes create a new version.
10. **BCK-21-AC-10:** Deprecation has replacement/support/removal evidence.
11. **BCK-21-AC-11:** Every event has one purpose/policy revision.
12. **BCK-21-AC-12:** Unknown/expired/wrong-market policy blocks send/ingest.
13. **BCK-21-AC-13:** Raw user/page/workspace/object IDs are prohibited.
14. **BCK-21-AC-14:** Free text/prompt/query/exact location is prohibited.
15. **BCK-21-AC-15:** Stable internal ID is not treated as anonymous.
16. **BCK-21-AC-16:** Subject key is purpose/environment/epoch scoped.
17. **BCK-21-AC-17:** Client never derives or sends raw subject identity key.
18. **BCK-21-AC-18:** Pre-auth collection has no cross-session identifier.
19. **BCK-21-AC-19:** Sign-out ends session/subject association.
20. **BCK-21-AC-20:** Definition/policy/consent is validated at ingress.
21. **BCK-21-AC-21:** Rejected payload is not stored as arbitrary quarantine.
22. **BCK-21-AC-22:** Ingestion receipt uses privacy-safe reason codes.
23. **BCK-21-AC-23:** Same event ID/payload is idempotent.
24. **BCK-21-AC-24:** Same event ID/different payload is rejected.
25. **BCK-21-AC-25:** Server receipt time controls retention/order boundaries.
26. **BCK-21-AC-26:** Late-data behavior is metric-definition owned.
27. **BCK-21-AC-27:** Sampling is versioned/deterministic/disclosed.
28. **BCK-21-AC-28:** Queue has count/byte/age/retry bounds.
29. **BCK-21-AC-29:** Withdrawal/kill switch clears unlawful queued data.
30. **BCK-21-AC-30:** Product flow never waits for analytics delivery.
31. **BCK-21-AC-31:** Dataset build has immutable lineage/manifest.
32. **BCK-21-AC-32:** Failed quality gate cannot publish partial data.
33. **BCK-21-AC-33:** Metric numerator/denominator/population are versioned.
34. **BCK-21-AC-34:** Metric timezone/cohort/late rules are explicit.
35. **BCK-21-AC-35:** Dashboard links metric/dataset revision/freshness.
36. **BCK-21-AC-36:** Analytics metric cannot authorize business mutation.
37. **BCK-21-AC-37:** Raw event access is exceptional/time-bound/audited.
38. **BCK-21-AC-38:** Export has purpose/scope/approval/expiry/watermark.
39. **BCK-21-AC-39:** Repeated queries cannot bypass privacy threshold.
40. **BCK-21-AC-40:** Optional analytics decline does not block product use.
41. **BCK-21-AC-41:** Legal basis is decided per purpose/market.
42. **BCK-21-AC-42:** Consent withdrawal is independent from DSR erasure.
43. **BCK-21-AC-43:** Third-party destination requires full processor review.
44. **BCK-21-AC-44:** Pseudonymous data is not called anonymous.
45. **BCK-21-AC-45:** Retention is per family with no invented default.
46. **BCK-21-AC-46:** DSR propagates across raw/curated/cache/export.
47. **BCK-21-AC-47:** Backup restore cannot reactivate deleted subject data.
48. **BCK-21-AC-48:** Experiments remain separately disabled/gated.
49. **BCK-21-AC-49:** Experiment has hypothesis/exposure/metrics/stop plan.
50. **BCK-21-AC-50:** Significant/minor-sensitive experiment requires safeguards.
51. **BCK-21-AC-51:** Current console telemetry is not production authority.
52. **BCK-21-AC-52:** Existing logs/telemetry are never backfilled by default.
53. **BCK-21-AC-53:** Every current event needs inventory/owner/schema review.
54. **BCK-21-AC-54:** Unsafe legacy IDs are removed, not grandfathered.
55. **BCK-21-AC-55:** Operational logs never copy analytics payload.
56. **BCK-21-AC-56:** Cost/backpressure cannot degrade product authority.
57. **BCK-21-AC-57:** Flags separate collection/destination/transform/metric.
58. **BCK-21-AC-58:** EE/LT activation is independent from Latvia.
59. **BCK-21-AC-59:** Runtime requires contract/privacy/IAM/load/DSR evidence.
60. **BCK-21-AC-60:** Registries distinguish document/runtime/deployment state.

## 30. Explicit unimplemented list

Absent: production event registry/schemas/codegen, collector, destination,
pseudonymization/key management, raw/curated datasets, metrics, experiments,
IAM/access workflow, DSR/deletion jobs, retention, dashboards, alerts, cost
controls, runbook, Firebase/cloud resources and mobile remote adapter.

## 31. Owner decisions required

| ID | Owner | Decision | Fail-closed default |
|---|---|---|---|
| `BCK21-OD-01` / `OD-05` | Data Platform + Security + Legal + Ops | Transport/destination/residency/DPA/export/delete/cost | Production collection off |
| `BCK21-OD-02` | Legal/Privacy + Product | Purposes, bases, consent/notices/store disclosures | Unresolved events off |
| `BCK21-OD-03` | Identity + Security | Subject/session keys, rotation, joins, pre-auth | No stable/pre-auth identity |
| `BCK21-OD-04` | Legal/Privacy + Data Platform | Per-family retention/DSR/anonymization thresholds | Persistence off |
| `BCK21-OD-05` | Product + Data governance | Canonical event catalog, owners, schemas, lifecycle | Unregistered events rejected |
| `BCK21-OD-06` | Data Platform + Domain owners | Sampling, batching, late data, dedupe/correction | No extrapolation |
| `BCK21-OD-07` | Data governance + Security | Dataset/metric/access/export/privacy thresholds | Aggregate-only access |
| `BCK21-OD-08` | Product + Legal + Security | Experiment/personalization/minors/Article 22 policy | Experiments off |
| `BCK21-OD-09` | Mobile Platform + Ops | Queue/battery/network/retry/release cutover | Remote adapter off |
| `BCK21-OD-10` | Ops + Data Platform | SLO, capacity, quality gates, quarantine and cost | Cohort blocked |

Each decision requires a stable record, exact version, owner verdict, date,
evidence, affected gates, controls, rollout and rollback. Listing is not
Acceptance.

## 32. Final statement

BCK-21 v0.2 is a production-grade Review design for privacy-safe product
analytics, not permission to collect data. It deliberately blocks the existing
untyped console telemetry from becoming production history and keeps Recharge
fully functional with analytics disabled.
