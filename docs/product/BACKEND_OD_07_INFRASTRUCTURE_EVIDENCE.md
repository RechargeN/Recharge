# BCK-D1 — OD-07 Infrastructure Decision Evidence

- Evidence ID: **BCK-D1-OD07-EV-01**
- Version: **0.5**
- Date: **2026-08-24**
- Decision: **OD-07 — Firebase topology, edition and per-resource locations**
- Decision status: **Proposed — owner decision prepared, not Accepted**
- Evidence status: **Review-ready — owner verdict required**
- Candidate baseline: **OD07-A1-EU-MR-v1**
- Owner-decision record: [OD07-DEC-01 v0.1](BACKEND_OD_07_INFRASTRUCTURE_OWNER_DECISION.md)
- Runtime status: **Absent**
- Accountable decision owner: **Platform Operations owner**
- Decision reviewers: **Security/Privacy and Product/Finance**
- Required production activation reviewer: **qualified Legal/Privacy**
- Parent specifications: [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md),
  [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md),
  [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Cost evidence: [BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md) v0.3 (Draft; numerical baseline remains v0.2)
- Reliability evidence: [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) v0.1 (Draft)
- Recovery evidence: [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) v0.1 (Draft)
- Runtime effect: **none**

---

## 1. Purpose and verdict

This record supplies a complete, reviewable infrastructure choice without
creating a Firebase/GCP project, enabling billing, provisioning a location-bound
resource, creating credentials, deploying code or processing production data.

The recommended baseline is **OD07-A1-EU-MR-v1**:

- one logical backend platform in three isolated projects: `dev`, `stage`,
  `prod`;
- Firestore **Standard edition, Native mode, `(default)` database, `eur3`**;
- Cloud Functions for Firebase **2nd gen, explicitly `europe-west1`**;
- Firebase client media and backend media-processing buckets **regional
  `europe-west1`**;
- Firestore managed backups remain in the database location; a future managed
  export/exit bucket is **`EU` multi-region** and stays disabled until its own
  recovery/export slice;
- location-capable operational resources use the exact locations in §7;
- Latvia is the only initially activatable market; Estonia and Lithuania stay
  server-disabled until their independent market gates;
- Local Emulator Suite remains test tooling, never a fourth environment.

This baseline optimizes for an authoritative Booking/data platform that can
tolerate a regional failure while keeping the function and media processing
plane together. It deliberately accepts the documented multi-region cost and
write-latency trade-off. Actual Latvia/Tallinn/Vilnius measurements remain a
mandatory post-provision validation gate before production traffic.

## 2. Exact scope of OD-07

OD-07 decides:

1. environment/project isolation;
2. Firestore edition, mode, database role and immutable location;
3. the default region/location for each location-capable runtime resource;
4. which global or US-operated Firebase services are not covered by the EU
   resource-location claim;
5. cost/latency validation thresholds;
6. the migration, replacement and rollback boundary for immutable resources.

OD-07 does **not** decide legal basis, DPA/SCC/transfer sufficiency, retention,
IAM roles, secret values, billing account, final globally unique provider
project IDs, backup schedules, product activation or deployment permission.
Those concerns keep their BCK-04/BCK-05/R1 gates.

## 3. Dated authoritative evidence snapshot

Official sources were re-checked on **2026-08-24**. They must be refreshed
immediately before any irreversible command because availability, pricing and
service behavior can change.

| Official source | Verified constraint | Recharge consequence |
|---|---|---|
| [Firebase product/resource locations](https://firebase.google.com/docs/projects/locations) | There is no one project/app location. Firestore, new `*.firebasestorage.app` buckets and 2nd-gen Functions select locations independently. | The matrix must name each resource; “Firebase is in EU” is insufficient. |
| [Firestore locations](https://firebase.google.com/docs/firestore/locations) | A database location cannot be changed in place. `eur3` has read-write replicas in Belgium/Netherlands and a Finland witness. Multi-region and regional SLA targets differ. | Database creation is irreversible; replacement requires a new database/project and migration. |
| [Firestore editions](https://firebase.google.com/docs/firestore/editions) | Standard and Enterprise both support Native mobile/web SDKs, real-time and offline Core operations. Enterprise adds an advanced query engine and a different unit-based price model. | Standard is sufficient for the accepted architecture; Enterprise adds cost/query complexity without a current required capability. |
| [Functions locations](https://firebase.google.com/docs/functions/locations) | Functions are regional; `europe-west1` supports 2nd gen and is the documented closest Functions region for `eur3`. Cross-location use can affect latency/cost. | Every function and callable client binds an explicit region; default `us-central1` is forbidden. |
| [Storage for Firebase locations](https://firebase.google.com/docs/storage/locations) | New Firebase buckets select their own location, cannot change it in place and currently do not support configurable dual-regions. | Media buckets are decided separately and use regional `europe-west1`. |
| [Cloud Storage locations](https://cloud.google.com/storage/docs/locations) | Cloud Storage supports regional and `EU` multi-region buckets. | Runtime media stays regional; the disabled exit/export destination may use `EU`. |
| [Firestore backups](https://cloud.google.com/firestore/docs/backups) | A managed backup resides in the same location as its source database. | Backup residency follows `eur3`; schedule/retention remain BCK05-OD-05. |
| [Cloud Logging locations](https://cloud.google.com/logging/docs/region-support) | Log buckets are location-bound, while automatically created defaults can be global; existing bucket location is immutable. | Project/folder logging defaults must be inspected before creation; global mandatory/service logs are disclosed, not called EU-only. |
| [Firebase privacy and security](https://firebase.google.com/support/privacy) | Some Firebase services are global and Firebase Authentication is operated from US data centers. A selectable database/bucket region does not localize all Firebase processing. | Production Auth and any global service need the BCK-04 processor/transfer/legal gate. |
| [Resource location restriction](https://cloud.google.com/resource-manager/docs/organization-policy/restrict-locations) | Organization policy can restrict creation of supported location-capable resources, but does not prove where every service processes data. | Apply policy where supported and keep a service-by-service exception register. |
| [Cloud Billing budgets](https://cloud.google.com/billing/docs/how-to/budgets) | Budgets alert; they do not automatically cap spend. | Quotas, flags and circuit breakers provide containment. |

Vendor documentation proves service constraints, not Recharge legal compliance
or performance. A qualified Legal/Privacy conclusion is still required before
production personal-data processing, especially for Authentication and other
global/US-operated surfaces.

## 4. Decision drivers and non-negotiable constraints

1. Authoritative Booking must preserve invariants during a single-region
   failure; fail-closed is preferred to oversell or double allocation.
2. Mobile clients in LV, EE and LT need bounded interactive latency, but no
   unmeasured latency value may be presented as fact.
3. Firestore/Storage location is immutable; reversible defaults are mandatory
   everywhere else.
4. Environment authority, credentials, quotas, apps and data never cross
   `dev`/`stage`/`prod`.
5. Production personal data never enters `dev` or `stage`; stage uses synthetic
   or approved anonymized data only.
6. A market flag is independent from an environment. EE/LT do not become live
   because they share the same European platform.
7. No resource silently inherits `us-central1`, `global` or another console
   default.
8. The selected topology must be replaceable through export/import, compatible
   dual-read comparison and explicit cutover; in-place location mutation is not
   a rollback mechanism.

## 5. Options and disposition

| Option | Firestore | Functions | Runtime media | Strength | Why it loses/wins |
|---|---|---|---|---|---|
| **A1 — selected candidate** | Standard Native `eur3` | 2nd gen `europe-west1` | regional `europe-west1` | multi-region Firestore availability; documented Functions proximity; media/function colocation | **Wins** for authoritative core resilience with one explicit cross-location database/function boundary. |
| A2 | Standard Native `eur3` | 2nd gen `europe-west1` | `EU` multi-region | broader media placement | Rejected initially: higher/less predictable transfer and storage cost without a proven media resilience requirement. |
| B | Standard Native `europe-west1` | 2nd gen `europe-west1` | regional `europe-west1` | simplest colocation, lower write latency/cost candidate | Rejected initially: regional Firestore availability is weaker for authoritative Booking; may be reconsidered only if A1 misses declared latency/cost thresholds. |
| C | Standard Native `europe-north1` | 2nd gen `europe-north1` | regional `europe-north1` | geographically closer to Baltic users | Rejected initially: proximity is not measured end-to-end performance, and it trades away multi-region database resilience. |
| D | Enterprise Native or MongoDB-compatible | not selected | not selected | advanced query engine/MongoDB compatibility | Rejected: no accepted Recharge capability currently requires it; different pricing/index/query semantics create avoidable migration and operational scope. |

Option B is the declared replacement candidate if A1 fails latency, contention
or cost thresholds after authorized stage provisioning. The team must not
silently relax thresholds to preserve A1.

## 6. Environment and project contract

| Property | dev | stage | prod |
|---|---|---|---|
| Logical project handle | `recharge-eu-dev` | `recharge-eu-stage` | `recharge-eu-prod` |
| Provider project-ID rule | globally unique ID derived from `rechargen-eu-dev` | derived from `rechargen-eu-stage` | derived from `rechargen-eu-prod` |
| Data | disposable synthetic | synthetic/anonymized release-scale | production only after all activation gates |
| Billing/budget | separate attribution and low ceiling | separate attribution and rehearsal ceiling | protected budget/alerts and named emergency owner |
| IAM/WIF | isolated | isolated | isolated, protected approval |
| Firebase app IDs | separate Android/Apple registrations | separate registrations | separate registrations |
| Mutation flags | off except exact test | default off | default off until cohort approval |
| Markets | synthetic fixtures | LV/EE/LT test fixtures, all external traffic off | LV may activate later; EE/LT off |

Provider project IDs are globally unique and cannot be truthfully guaranteed
before availability validation. OD-07 therefore accepts the logical handles and
deterministic naming rule. R1 records the exact available project ID and project
number **before** creation. Any suffix is non-semantic, must be uniform across
IaC/config/evidence, and requires owner acknowledgement; project reuse is
forbidden.

## 7. Per-resource location and activation matrix

`Disabled` is a complete fail-closed decision for OD-07. Enabling such a row
requires its owning decision and an OD-07-compatible exact location update.

| Resource/surface | dev | stage | prod | Location/processing statement | Activation owner/gate |
|---|---|---|---|---|---|
| Firestore database | `(default)`, Standard/Native, `eur3` | same | same | immutable database location | R1 exact plan; prod traffic later |
| Firestore PITR/scheduled backup | off | off until restore rehearsal | off until BCK05-OD-05 | managed backup follows source `eur3` | Recovery owner |
| Firestore managed export bucket | absent | `EU`, only in approved rehearsal | `EU`, disabled initially | separate GCS bucket; no Firebase client access | Recovery + Privacy |
| Functions/callables | 2nd gen `europe-west1` | same | same | explicit function region and callable client region | R1 then per-domain slices |
| Firebase default media bucket | regional `europe-west1` | same | same | new `*.firebasestorage.app`; independent from Firestore | Media slice |
| Backend quarantine/derived bucket | absent until media slice | regional `europe-west1` | regional `europe-west1`, disabled | backend-only, lifecycle-bound | Media + Security |
| Artifact Registry | `europe-west1` | same | same | build artifact, no production user data | Release owner |
| Secret Manager | absent until BCK05-OD-02 | exact `europe-west1` compatible design required | same, disabled | regional/user-managed placement only after Functions compatibility proof | Security/Operations |
| Cloud Logging user-defined operational bucket | `eu` or approved regional test bucket | `eu` | `eu` | redacted operational logs; mandatory/global service buckets disclosed separately | Operations + Privacy |
| Cloud Monitoring | metrics only after redaction policy | same | same | global service; no raw payload/PII labels | Operations + Privacy |
| Cloud Scheduler / Cloud Tasks | disabled | disabled | disabled | when authorized: `europe-west1` | OD-09/BCK05-OD-06 |
| Pub/Sub/Eventarc transport | emulator only | disabled | disabled | exact storage/processing behavior reviewed in OD-09 | OD-09 |
| Firebase Authentication | mock/emulator | disabled | disabled | official Firebase statement: US data-center processing | BCK-04 transfer/processor + BCK-06 |
| Firebase App Check | debug/test only | disabled | disabled | global/service-specific processing; not authorization | BCK-04/BCK-05 rollout |
| Crashlytics/Performance | disabled | disabled | disabled | no location claim by this decision | Privacy + release slice |
| Google Analytics | disabled | disabled | disabled | reporting location does not prove processing residency | BCK-21 + consent/legal |
| FCM/Remote Config | disabled | disabled | disabled | separate global/service processing review | owning slices |
| External search/AI/payments/providers | absent | absent | absent | no provider/location selected | separate Accepted decisions |

Before project creation, R1 inventories any existing App Engine app, legacy
`*.appspot.com` bucket, default-resource location or logging bucket. Any
pre-existing incompatible resource blocks reuse of that project.

## 8. Residency and international-transfer statement

The precise claim allowed by this baseline is:

> Recharge stores customer content in the selected location-controlled
> Firestore, Storage and approved log/export resources in European locations.
> This does not mean every Firebase service or service datum is stored or
> processed only in the EU/EEA.

The following are separate facts and must never be conflated:

- **resource location** — where a selectable database, bucket, function or log
  bucket is configured;
- **processing location** — where a provider may process customer/service data;
- **international transfer mechanism** — DPA, adequacy/SCC and supplementary
  safeguards for processing outside the EU/EEA;
- **market activation** — whether LV, EE or LT users may use a capability.

Production Firebase Authentication, Analytics, Crashlytics, App Check, FCM or
any other global/US-operated service remains disabled until BCK-04 records the
processor/subprocessor inventory, DPA/transfer conclusion, data inventory,
legal basis, retention and user-facing transparency. OD-07 Acceptance is an
architecture decision, not legal advice or a GDPR compliance certificate.

## 9. Performance and contention validation

Pre-provision values are **thresholds**, not measurements. After a separately
Approved R1 creates only authorized non-production resources, stage must test
Riga, Tallinn and Vilnius separately on representative mobile networks.

| Journey | Stage threshold before production | Failure action |
|---|---|---|
| Auth/access authority synthetic | p95 `<=750 ms`, p99 `<=2 s` | keep Auth/product activation off |
| Authoritative command | p95 `<=1.5 s`, p99 `<=3 s` | no production mutation traffic |
| Booking create/cancel/manage | p95 `<=1.5 s`, p99 `<=3 s`; zero oversell/drift | disable new allocations; preserve safe read/cancel |
| Own/profile/library/Booking read | p95 `<=750 ms`, p99 `<=2 s` | review topology/query path |
| Discover details/feed/map/search | p95 `<=1.5 s`, p99 `<=4 s` | typed degraded/stale state; compare Option B |

The evidence records request count, payload/query shape, cold/warm state,
network, city, SDK/runtime versions, concurrency, Firestore operations/index
reads, function duration, cross-location transfer and cost. Average latency,
emulator results or a single Riga desktop connection are not sufficient.

## 10. Cost and capacity controls

The dated formulas and workload envelopes live in BCK05-OD04-COST-01. OD-07
selects A1 as its calculator/stage baseline and preserves these controls:

- proposed monthly guardrails: dev EUR 25, stage EUR 75, prod L1 EUR 150 and
  prod L2 EUR 500; L3 stress requires separate authorization;
- thresholds at 50/75/90/100% are alerts with owned actions, never hard caps;
- quotas, max instances, bounded queries/listeners, media lifecycle, egress
  controls and server flags perform containment;
- exact selected-location EUR SKUs, tax/support treatment and billing-account
  currency are refreshed before any chargeable provisioning;
- stage reconciles estimate versus actual per critical journey before prod.

Price drift does not silently change topology. If current EUR pricing breaks
the accepted guardrail, provisioning remains blocked and A1/B is re-reviewed.

## 11. Irreversibility, migration and rollback

### 11.1 Before creation

Rollback is deletion of the unexecuted plan: no cloud state exists. A failed
preflight changes documentation/IaC only.

### 11.2 After non-production creation, before traffic

- an incorrect project/database/bucket is quarantined from apps and CI;
- inventory and cost are captured as incident evidence;
- no data is treated as authoritative;
- replacement uses a new clean project/resource with the accepted location;
- deletion follows an explicit verified cleanup plan, never an ad-hoc console
  action.

### 11.3 After authoritative data exists

Firestore and Storage locations are not changed in place. Replacement requires:

1. new target project/database/buckets with an Accepted superseding decision;
2. compatible schema/index/Rules/IAM configuration;
3. managed export/import or an approved versioned migration;
4. integrity counts/hashes, domain reconciliation and privacy re-deletion;
5. bounded write freeze or an approved change-capture strategy;
6. shadow reads and query/latency/invariant comparison;
7. explicit cutover, observation window and old-system read-only period;
8. owner-approved retirement only after restore/export proof.

Rules, Functions, configuration, data migration and disaster recovery each
have independent rollback. A code rollback never claims to undo a database
location or already-committed authoritative state.

## 12. Provisioning preflight contract

Even after OD-07 Acceptance, R1 remains unauthorized until G1 and a separate
Approved executable slice exist. That slice must fail closed unless it proves:

1. current branch/approved commit and clean reviewed IaC plan;
2. target project is new/empty and its provider ID is recorded;
3. no legacy App Engine/default-resource location/`*.appspot.com` dependency;
4. organization/folder location and logging defaults are known;
5. exact edition/mode/database/location values match this baseline;
6. billing budget, alert routes and emergency owner are reachable;
7. IAM/WIF identities are least-privilege and environment-isolated;
8. all mutation/product/market flags are off;
9. rollback/cleanup commands target only the exact new resources;
10. observed cloud state is reconciled back to repository evidence.

Console clicks, implicit defaults and project reuse are prohibited.

## 13. Owner decision and remaining gates

[OD07-DEC-01](BACKEND_OD_07_INFRASTRUCTURE_OWNER_DECISION.md) contains the
exact review scope and verdict phrase. Until that phrase is supplied:

- OD-07 remains `Proposed`;
- D1/G1 and R1 remain blocked;
- no provider project ID, billing account, credential or resource exists;
- every production Firebase/global service remains disabled.

After exact acceptance, OD-07 becomes Accepted only as the architecture
baseline above. BCK-04/05, OD-10, complete D1/G1, exact R1 authorization,
qualified Legal/Privacy review and production activation remain independent.

## 14. Revalidation and supersession

Re-review is mandatory before provisioning and whenever:

- official edition/location/Functions/Storage behavior changes;
- a required resource cannot use the selected location;
- Enterprise-only capability becomes an accepted requirement;
- stage misses a latency, contention, availability or cost threshold;
- a processor/transfer/legal conclusion requires different placement;
- a new market requires physical isolation;
- recovery/export testing shows the replacement path is not viable.

A superseding record names old/new topology, data classes, cost/performance
evidence, migration, rollback, owner and effective date. Existing production
resources never redefine the decision merely because they exist.

## 15. Evidence acceptance criteria

1. **OD07-EV-AC-01:** one exact candidate baseline is named.
2. **OD07-EV-AC-02:** all three environments have isolated authority.
3. **OD07-EV-AC-03:** logical handles and provider project IDs are distinguished.
4. **OD07-EV-AC-04:** Standard, Native mode, `(default)` and `eur3` are explicit.
5. **OD07-EV-AC-05:** Standard-versus-Enterprise rationale is recorded.
6. **OD07-EV-AC-06:** Firestore location immutability is acknowledged.
7. **OD07-EV-AC-07:** Functions and callable clients bind `europe-west1` explicitly.
8. **OD07-EV-AC-08:** Storage location is independent and immutable.
9. **OD07-EV-AC-09:** media and export buckets have different purposes/locations.
10. **OD07-EV-AC-10:** every disabled service stays fail-closed.
11. **OD07-EV-AC-11:** global/US-operated services are disclosed.
12. **OD07-EV-AC-12:** EU resource placement is not called full-EU processing.
13. **OD07-EV-AC-13:** Auth production waits for processor/transfer/legal review.
14. **OD07-EV-AC-14:** LV activation cannot enable EE/LT.
15. **OD07-EV-AC-15:** pre-provision thresholds are not called measurements.
16. **OD07-EV-AC-16:** post-provision tests cover Riga/Tallinn/Vilnius separately.
17. **OD07-EV-AC-17:** Booking validation includes zero oversell/drift.
18. **OD07-EV-AC-18:** cost includes operations, storage, transfer, logs and recovery.
19. **OD07-EV-AC-19:** budget alerts are not hard spend caps.
20. **OD07-EV-AC-20:** exact EUR SKUs are refreshed before chargeable work.
21. **OD07-EV-AC-21:** managed backups follow source location.
22. **OD07-EV-AC-22:** resource replacement uses new target plus migration.
23. **OD07-EV-AC-23:** code rollback is separate from data/location rollback.
24. **OD07-EV-AC-24:** legacy default-resource dependencies block project reuse.
25. **OD07-EV-AC-25:** acceptance and provisioning are separate gates.
26. **OD07-EV-AC-26:** production activation remains separately gated.
27. **OD07-EV-AC-27:** revalidation triggers fail closed.
28. **OD07-EV-AC-28:** this revision creates no runtime or cloud resource.

---

**Current conclusion:** `OD07-A1-EU-MR-v1` is decision-ready and recommended,
but OD-07 remains **Proposed** until the exact owner verdict in OD07-DEC-01 is
recorded. No cloud action or merge to `main` is authorized by this document.
