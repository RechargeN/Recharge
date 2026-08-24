# Recharge Backend — Infrastructure and Cost Control Model

- Evidence ID: **BCK05-OD04-COST-01**
- Version: **0.3**
- Date: **2026-08-24**
- Decision served: **BCK05-OD-04**; supporting evidence for **OD-07**
- Decision status: **Proposed — Product/Finance/Operations verdict pending**
- Evidence status: **Draft — dated vendor and model review required**
- Runtime status: **Absent**
- Accountable coordinator: **RechargeN / Product owner**
- Required reviewers: **Platform Operations, Product/Finance,
  Security/Privacy and Legal/Privacy where invoice/residency/tax facts apply**
- Parent: [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Infrastructure decision: [BCK-D1-OD07-EV-01 v0.5](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md), candidate `OD07-A1-EU-MR-v1`
- Reliability boundary: [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md)
- Recovery boundary: [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md)
- Architecture input: [Firebase Architecture v2.2](../architecture/FIREBASE_ARCHITECTURE.md) (Proposed)
- Markets: **Latvia first; Estonia and Lithuania prepared but disabled independently**
- Currency policy: **EUR spending guardrails; vendor list-price evidence in USD**
- Runtime effect: **none**

---

## 0. Changelog

### v0.3 — 2026-08-24

- bound the existing A1 formulas and guardrails to the exact review-ready
  `OD07-A1-EU-MR-v1` candidate: Firestore `eur3`, Functions/media
  `europe-west1`, disabled `EU` export bucket;
- retained all prices/guardrails as Draft planning evidence and required a
  fresh exact EUR SKU/billing-account reconciliation before chargeable work;
- no budget, billing account, resource or runtime was created.

### v0.2 — 2026-08-21

- reconciled retained-backup volume with BCK05-OD05-REC-01: stage daily/7-day
  retention equals seven full-size equivalents, while the prod candidate of
  daily/14-day plus weekly/12-week retention equals 26;
- corrected recovery, subtotal and reserve estimates; the prior four-copy
  assumption understated the proposed recovery policy;
- retained all EUR guardrails as proposals, but made the L3 retention/budget
  conflict an explicit owner decision rather than hiding it in reserve.

### v0.1 — 2026-08-21

- created the first dated topology, workload, provider-cost and EUR containment
  proposal without provisioning or billing authority.

## 1. Purpose and verdict

This document supplies the missing numerical infrastructure/cost proposal for
the Recharge backend. It defines:

- candidate topology and environment cost boundaries;
- dated vendor price anchors and reproducible formulas;
- launch, year-one and stress workload envelopes;
- proposed EUR budgets, alerts and containment actions;
- unit economics, cost ownership and Baltic expansion rules;
- exact evidence required before any cloud resource or billing link exists.

The model advances `BCK05-OD-04` from Open to **Proposed**, not Accepted.
It does not accept OD-07, choose a tax treatment, create a billing account,
provision Firebase/GCP, attach credentials or authorize production processing.

## 2. Scope and exclusions

### 2.1 Included provider spend

- Firestore Standard operations, indexes, storage, PITR, backups and restores;
- Cloud Run functions compute, requests, build/image overhead and egress;
- Cloud Storage media storage, operations, processing transfer and egress;
- Cloud Logging/Monitoring billable ingestion and checks;
- small platform services such as Scheduler, Tasks, Pub/Sub, Eventarc,
  Artifact Registry and Secret Manager as explicit reserve until topology exists;
- separate dev, stage and prod cloud environments;
- provider invoice variance and a bounded planning reserve.

### 2.2 Explicitly excluded from the provider-runtime estimate

- salaries, contractors, accounting, DPO/Legal and security review;
- company registration, insurance, domains and general SaaS;
- Apple/Google developer accounts and store fees;
- Google Maps Platform/mobile map usage;
- external search, email/SMS, AI, route, provider, payment and booking partners;
- payment processing fees and refunds;
- VAT/tax conclusion or recoverability;
- paid Google Cloud support plan;
- content acquisition, moderation and customer support operations.

Every excluded paid capability receives a separate budget and kill switch before
activation. It cannot consume the core backend budget silently.

## 3. Evidence hierarchy and price policy

1. Actual Cloud Billing EUR SKUs/export for the selected billing account and
   resource locations govern invoices.
2. Dated official price pages below are planning evidence, not a quote.
3. This document's workload assumptions are Recharge proposals, not vendor facts.
4. Free tiers, credits and discounts are treated as upside, not required for
   budget safety; they may be shared at billing-account level.
5. Taxes and support are excluded until Finance/Legal records their treatment.
6. Price snapshot expires after **30 days** for provisioning approval and is
   refreshed immediately after a vendor pricing/location change.
7. A calculator result must preserve inputs, location, currency, timestamp and
   exported estimate; a screenshot without inputs is insufficient.

## 4. Official price snapshot — checked 2026-08-21

All prices below are USD list anchors rendered by official Google/Firebase
pages. Cloud Platform EUR SKUs can differ.

| Cost family | Dated planning anchor | Model consequence |
|---|---|---|
| Firestore Standard free quota | 1 GiB stored, 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day and 10 GiB outbound/month for one free database/project | model gross cost before free quota; named databases and PITR/backup do not inherit the free allowance |
| Firestore Standard operations | rendered selector: `$0.03/100k` reads, `$0.09/100k` writes, `$0.01/100k` deletes | every query also models index-entry reads; final location/SKU export is mandatory |
| Firestore storage/recovery | `$0.000205479/GiB-hour` data and PITR (about `$0.15/GiB-month` at 730 h), `$0.000041096/GiB-hour` backup (about `$0.03/GiB-month`), `$0.20/GiB` restore | PITR can roughly double billed database storage; backups/restores are separate |
| Firestore outbound | first 10 GiB/month free, then representative Europe/worldwide tier `$0.12/GiB` through 1 TiB | payload/projection size is a first-class cost metric |
| Cloud Run request-based compute | active `$0.000024/vCPU-second`, `$0.0000025/GiB-second` and `$0.40/million` requests; 2M requests, 180k vCPU-s and 360k GiB-s monthly free allowance based on Tier-1 pricing | free allowance is not allocated independently to every project; minimum instances default to zero |
| Cloud Run lightweight function example | official `europe-west1` example: 10M requests, 200 ms, 0.167 vCPU/256 MiB ≈ `$7.25/month` after free tier | validates the request-cost formula; real concurrency/duration must be measured |
| Cloud Storage EU multi-region | Standard `$0.000035616/GiB-hour` (about `$0.026/GiB-month`); Class A `$0.01/1k`, Class B `$0.0004/1k`; internet egress commonly `$0.12/GiB` | media egress, not object storage, is expected to dominate at scale |
| Cloud Storage EU → regional Google service | same-continent transfer may be `$0.02/GiB`; region and multi-region are not the same location | EU multi-region Storage plus regional Functions requires an explicit processing-transfer line |
| Cloud Logging | `$0.50/GiB` ingested after first 50 GiB/project/month; default charge includes up to 30 days storage | redaction/sampling/retention protect privacy and cost; never disable mandatory audit |
| Firebase Auth / Identity Platform | pricing page lists a 50k MAU no-cost allowance for applicable Identity Platform MAU; phone/SAML/OIDC rules differ | Google/Apple target remains low direct cost, but exact tenant/provider SKU is rechecked |
| Firebase no-cost products | App Check, FCM, Crashlytics, Analytics, Performance and Remote Config are listed as no-cost subject to product quotas/terms | no-cost does not mean unbounded or operationally free |
| Cloud Billing budgets | alerts notify but do not cap spending; Pub/Sub can deliver programmatic notifications and billing reports are delayed | safe flags/quotas/circuit breakers, not billing alerts alone, perform containment |

Official sources:

- [Firebase pricing](https://firebase.google.com/pricing)
- [Firestore pricing](https://cloud.google.com/firestore/pricing)
- [Cloud Run pricing](https://cloud.google.com/run/pricing)
- [Cloud Storage pricing](https://cloud.google.com/storage/pricing)
- [Google Cloud Observability pricing](https://cloud.google.com/products/observability/pricing)
- [Cloud Billing budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets)

## 5. Topology cost candidates

The three-environment project split is retained for all options. Project names
remain placeholders until an Approved provisioning slice.

| Option | Firestore | Functions | Media Storage | Cost/reliability interpretation | Current disposition |
|---|---|---|---|---|---|
| A1 — balanced candidate | Standard Native `eur3` | 2nd gen `europe-west1`, min instances 0 | regional Standard `europe-west1` | resilient Firestore candidate; media processing co-located and lower transfer/storage cost | **Preferred for cost validation; not Accepted** |
| A2 — EU multi-region media | Standard Native `eur3` | 2nd gen `europe-west1` | EU multi-region Standard | higher storage/operation cost and possible `$0.02/GiB` processing transfer; broader media placement | retain only if reliability/residency evidence justifies delta |
| B — regional platform | Standard Native `europe-west1` | 2nd gen `europe-west1` | regional Standard `europe-west1` | simplest/cheapest colocation candidate; lower regional resilience requires explicit DR evidence | benchmark and compare before OD-07 Acceptance |
| C — Nordic regional | Standard Native `europe-north1` | 2nd gen `europe-north1` where all triggers supported | regional Standard `europe-north1` | geographically closer to Baltics, but service coverage, measured latency and recovery remain unknown | evidence alternative, not default |

Recommendation: use A1 as the exact **`OD07-A1-EU-MR-v1` calculator and
stage-validation baseline**, not as an already Accepted or provisioned choice.
The decision-ready evidence supplies locations, thresholds and export/rollback
design; the exact owner verdict, current EUR SKU/billing-account reconciliation,
qualified production Legal/Privacy review and runtime measurements remain
separate gates.

## 6. Environment resource and budget boundary

| Boundary | dev | stage | prod |
|---|---|---|---|
| project | isolated placeholder | isolated placeholder | isolated placeholder |
| data | disposable synthetic/demo | synthetic/anonymized release-scale | production only after gates |
| Firestore | one default candidate DB; no PITR | default candidate DB; bounded backup for rehearsal | exact Accepted OD-07 database; PITR/backup only after accepted [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) and executable authorization |
| Functions | scale-to-zero, low max instances | production-like config with bounded max | default min 0; max instances/quotas tied to load proof |
| Storage | lifecycle-limited test media | synthetic test media and restore fixture | separate original/derived/quarantine purposes and lifecycle |
| logs | aggressive non-audit retention | release/load evidence retention | accepted audit/security/operations retention; redacted |
| billing | separate project budget | separate project budget | separate project budget and market/module attribution |
| production access | none | none | protected workload identity and named approval only |

Free quotas are not used to justify mixing environments or identities.

## 7. Cost formulas

All operation counts are monthly unless stated otherwise.

```text
firestore_ops_usd =
  reads / 100000 * read_price
  + writes / 100000 * write_price
  + deletes / 100000 * delete_price
  + measured_index_entry_reads / 100000 * applicable_read_price

firestore_storage_usd = avg_data_GiB * storage_GiB_month_price
firestore_recovery_usd = avg_PITR_GiB * PITR_price
  + retained_backup_GiB_month * backup_price
  + restored_GiB * restore_price

function_usd = max(0, requests - allocated_free_requests) * request_price
  + max(0, vCPU_seconds - allocated_free_vCPU_seconds) * vCPU_price
  + max(0, GiB_seconds - allocated_free_GiB_seconds) * memory_price
  + network + Eventarc + build + artifact storage

media_usd = avg_stored_GiB * storage_price
  + ClassA_operations / 1000 * ClassA_price
  + ClassB_operations / 1000 * ClassB_price
  + internet_egress_GiB * egress_price
  + cross_location_processing_GiB * transfer_price

logging_usd = max(0, ingested_GiB - project_free_allotment) * ingest_price

planning_total = sum(all provider lines) * 1.25 variance reserve
```

The 25% reserve covers forecast error and small platform SKUs, not an unlimited
contingency. It does not include excluded §2.2 costs.

## 8. Proposed workload envelopes

`MAU` and `DAU` are forecast inputs, not billing identities. Operation counts
include server effects and projection fanout where known; stage must replace
them with measured amplification factors.

| Envelope | MAU / peak DAU | Reads | Writes | Deletes | Firestore/PITR GiB | Functions | Media stored / egress GiB | Logs GiB | Purpose |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| D — dev | ≤25 / ≤10 | 0.30M | 0.10M | 0.02M | 5 / 0 | 0.20M | 10 / 5 | 5 | developer integration |
| S — stage | ≤200 / ≤100 | 1.00M | 0.20M | 0.05M | 10 / 0 | 0.50M | 25 / 15 | 15 | QA/load/release rehearsal |
| L1 — Latvia launch | 5k / 1k | 0.90M | 0.18M | 0.03M | 25 / 25 | 1.00M | 100 / 50 | 20 | bounded LV cohort/public launch |
| L2 — Latvia year one | 30k / 8k | 7.20M | 1.44M | 0.40M | 150 / 150 | 5.00M | 750 / 300 | 80 | expected mature LV demand |
| L3 — Baltic stress | 100k / 30k | 36.0M | 7.20M | 1.50M | 500 / 500 | 20.0M | 3000 / 1500 | 250 | 2x+ expansion/load evidence; not normal budget |

Additional model inputs retained with every calculation:

- average document and index size;
- index-entry reads and write fanout per query/command;
- real-time listener reconnect/read amplification;
- function duration, CPU, memory, concurrency, retries and minimum instances;
- media upload/variant count, cache hit ratio and processing transfer;
- soft-deleted, noncurrent and quarantined media bytes inside average stored
  GiB for their actual retention window;
- backup count/retention and restore test volume;
- market share of reads/writes/media/egress;
- failed/denied/abusive traffic and App Check/rate-control effects.

The v0.1 directional table uses these explicit auxiliary inputs; later
calculator exports replace them rather than changing them silently:

| Envelope | Firestore outbound GiB | Retained backup GiB-month | Media Class A-equivalent operations |
|---|---:|---:|---:|
| D | 0 | 0 | 28k |
| S | 0 | 70 | 70k |
| L1 | 20 | 650 | 140k |
| L2 | 90 | 3900 | 1.40M |
| L3 | 490 | 13000 | 7.00M |

Functions use one deliberately simple gross planning profile for comparability:
200 ms/request, 0.167 vCPU, 0.25 GiB memory and `$0.40/million` requests,
before any shared free allowance. Media Class B operations, build/image,
Scheduler/Tasks/Pub/Sub/Eventarc/Artifact Registry and Secret Manager remain
inside the 25% reserve until stage supplies measured quantities.

Retained backup volume is modelled conservatively as full-size equivalents:
seven simultaneous daily backups in stage and 14 daily plus 12 weekly backups
in prod. If provider billing evidence proves deduplication/incremental storage,
the measured value may reduce the estimate; the safety case never depends on
that discount.

## 9. Directional provider estimate

The table applies §4 anchors, no CUD/credit assumption, 730 hours/month and the
25% planning reserve. It is a reproducible directional estimate, not a quote.
Small platform SKUs remain inside the reserve. Component cells are rounded for
display; subtotals and the reserve are calculated from unrounded line values.

| Envelope | Firestore ops/storage/egress | Functions | Media | Logs | PITR/backups | USD list subtotal | USD +25% reserve |
|---|---:|---:|---:|---:|---:|---:|---:|
| D — dev | `$0.93` | `$0.27` | `$1.14` | `$0.00` | `$0.00` | **`$2.34`** | **`$2.92`** |
| S — stage | `$1.99` | `$0.66` | `$3.15` | `$0.00` | `$2.10` | **`$7.90`** | **`$9.87`** |
| L1 — Latvia launch | `$6.59` | `$1.33` | `$10.00` | `$0.00` | `$23.25` | **`$41.16`** | **`$51.45`** |
| L2 — Latvia year one | `$36.80` | `$6.63` | `$69.50` | `$15.00` | `$139.50` | **`$267.43`** | **`$334.29`** |
| L3 — Baltic stress | `$151.23` | `$26.53` | `$328.00` | `$100.00` | `$465.00` | **`$1,070.76`** | **`$1,338.45`** |

Interpretation:

- at launch the infrastructure bill can be small; operational/legal/engineering
  work, which this table excludes, is materially larger;
- media egress, recovery storage and logs dominate before Firestore operations;
- inefficient listeners, indexes, retries, variants or unredacted logs can move
  actual spend far above this model;
- the L3 estimate is a stress envelope, not permission to spend that amount;
- L3 plus the full recovery candidate may exceed the proposed €1,000 stress
  guardrail after actual EUR SKU conversion; Finance/Operations must approve a
  temporary ceiling, reduce the authorized load or select an equally safe
  evidence-backed protection design — never silently weaken RPO/RTO;
- actual EUR SKU export supersedes every USD value before provisioning.

## 10. Proposed EUR budgets — BCK05-OD-04

These amounts are **spending guardrails**, not a USD/EUR conversion and not an
invoice forecast. Finance must record tax/support treatment separately.

| Environment/profile | Monthly budget | 50% | 75% | 90% | 100% | Separate emergency ceiling |
|---|---:|---:|---:|---:|---:|---:|
| dev | **€25** | €12.50 | €18.75 | €22.50 | €25 | €40 |
| stage | **€75** | €37.50 | €56.25 | €67.50 | €75 | €120 |
| prod — L1 Latvia launch | **€150** | €75 | €112.50 | €135 | €150 | €250 |
| prod — L2 approved year-one envelope | **€500** | €250 | €375 | €450 | €500 | €750 |
| L3 stress authorization, temporary | **€1,000** | €500 | €750 | €900 | €1,000 | €1,500 |

Rules:

- prod begins with L1 only; L2/L3 amounts require a dated owner revision;
- budget escalation is not automatic because usage grew;
- emergency ceiling is not normal spend and requires Incident/Finance owner,
  reason, expiry and post-event review;
- no single optional provider can consume more than 20% of the active prod
  budget without a separate decision;
- dev/stage combined expected spend stays below 25% of the active prod budget;
- a forecast above 100% fails closed; it cannot be solved by silently raising
  the budget.

## 11. Threshold actions and safe containment

Billing reports are delayed. Every budget threshold combines Cloud Billing
actual/forecast notifications with near-real-time service usage metrics.

| Trigger | Mandatory response | Must remain available |
|---|---|---|
| 50% actual or forecast | owner notification; compare usage to envelope and attribution | all enabled product paths |
| 75% | Operations review within one business day; freeze min-instance increases, bulk backfills and new paid features | normal critical reads/mutations |
| 90% | incident-style cost watch; throttle media variants, reindex/rebuild, non-critical exports and optional effects; validate abuse/retry loops | Auth/session safety, privacy requests, Booking view/cancel, incident/audit |
| 100% | Product/Operations decision; disable optional high-cost writes/effects with server flags, cap uploads and queues, preserve read-only safe paths | user data access/export, cancellation/safety, audit/evidence, owned recovery |
| emergency ceiling or >2x expected daily burn | declare cost incident, stop non-essential mutations/effects, investigate credentials/abuse/retry, require explicit temporary exception | containment, security, privacy and existing commitment safety |

Never automatically detach billing in production. It can disable Auth,
logging, recovery or user-safety paths unpredictably. Programmatic budget
notifications trigger owned flags/quotas/circuit breakers; direct billing
disable is limited to an explicitly approved disposable dev/stage procedure.

## 12. Cost anomaly rules

- 24-hour spend above 5% of monthly budget is Warning unless a scheduled load/
  migration record explains it;
- above 10% in 24 hours or four times the declared hourly baseline is Major;
- unknown credential use, retry storm, unbounded query/listener or rapid media
  egress escalates through the incident model regardless of absolute EUR;
- cost anomaly severity is based on blast radius, persistence and security/user
  impact, not money alone;
- alerts dedupe but never suppress a new environment/service/market dimension;
- after containment, no budget alert closes until authoritative usage and
  billing lag reconcile.

## 13. Unit economics and attribution

Required monthly views:

| Dimension | Required metric |
|---|---|
| environment | provider cost and budget utilization |
| service/SKU | usage quantity, unit price and cost |
| market | LV/EE/LT attributed usage; shared-platform allocation rule |
| module | identity, content, discover, media, booking, notification, operations |
| critical journey | reads/writes/function time/egress and estimated cost per successful outcome |
| user scale | provider spend per MAU and active user, without exporting user identities into billing labels |

Proposed warning targets after at least 5,000 MAU:

- total included provider spend above **€0.05/MAU/month**;
- media delivery above **€0.03/MAU/month**;
- logging above **10%** of included provider spend;
- failed/retried work above **5%** of the owning service cost;
- unattributed/shared cost above **10%** of total;
- any optional provider cost without a market/module owner.

Targets are diagnostic, not permission to weaken security, accessibility,
privacy, audit or recovery.

## 14. Principal cost risks and controls

| Risk | Leading signal | Required design control |
|---|---|---|
| unbounded Firestore listeners | reads/session and reconnect reads rise | bounded query, pagination, listener lifetime and cache/freshness policy |
| index fanout | writes and index storage exceed document forecast | index allowlist, exemptions and measured fanout |
| Discover/map overfetch | reads/visible result and egress/result rise | shared query revision, bounded viewport/candidates and typed stale state |
| media egress/variants | egress/MAU and variants/original rise | size limits, deterministic variants, cache/CDN decision and lifecycle |
| retry/outbox storm | invocation/effect ratio and duplicate deliveries rise | idempotency, bounded retry, poison quarantine and circuit breaker |
| minimum instances | idle compute appears without traffic | default zero; explicit latency evidence and budget owner for exceptions |
| verbose/sensitive logs | ingestion and PII findings rise | structured allowlist, redaction, sampling of non-audit noise and retention |
| PITR/backup multiplication | recovery GiB exceeds declared retention model | per-record-class RPO/RTO/retention and deletion propagation |
| cross-location processing | internal transfer and latency increase | resource/trigger colocation map and invoice attribution |
| abuse/scraping/uploads | denied/failed/egress cost rises | App Check plus AuthZ, rate limit, quota, payload bounds and kill switch |

## 15. Scaling and optimization decision rules

1. Do not buy a committed-use discount before 90 days of stable billable usage,
   a break-even calculation and Finance approval.
2. Do not keep warm instances for speculative latency; prove the affected C1/C2
   SLO need and bounded max-instance cost first.
3. Do not introduce external search/CDN solely because it sounds scalable;
   compare measured Firestore/media cost, correctness, migration and provider
   lock-in in a separate Approved decision.
4. Booking sharding/admission changes require contention/invariant evidence,
   never a general cost optimization.
5. EE/LT reuse the same platform by default but remain separately disabled and
   attributed; a new country project requires Legal/residency/blast-radius or
   scale evidence and a superseding architecture decision.
6. Optimize payload/query/index/variant/retry design before weakening
   reliability, privacy, audit or backup.
7. Free credits do not justify architecture that becomes unaffordable after
   credits expire.

## 16. Ownership and approvals

| Decision/action | Accountable | Mandatory boundary review |
|---|---|---|
| workload forecast | Product + domain owners | Operations/Finance |
| unit price snapshot/calculator | Platform Operations | Finance |
| EUR budget and emergency ceiling | Product/Finance | Operations |
| location/topology | Platform Operations | Security/Privacy + Legal/Privacy + Finance |
| cost containment flags/quotas | Platform Operations | affected domain + Security |
| retention/PITR/backup cost | Operations + Privacy | domain owners + Legal where applicable |
| market attribution/activation | Product/Finance | Reference Data + Legal/Privacy + Operations |
| budget exception | Product/Finance + Operations | Incident/Security if anomalous |

The combined Product owner can coordinate the Draft but does not create an
independent Finance, Operations, Security or Legal verdict.

## 17. Evidence required before Acceptance

`BCK05-OD-04` may become Accepted only when:

1. Product/Finance accepts exact EUR budgets, tax/support treatment and funding;
2. Operations validates formulas, price snapshot, workload assumptions and
   service attribution;
3. stage calculator export and, after authorized provisioning, actual billing
   evidence reconcile within ±20% or explain the variance;
4. every threshold has a reachable owner, tested notification and safe action;
5. critical/safety/privacy/audit paths survive 90/100% containment;
6. optional providers have independent budgets and kill switches;
7. emergency ceilings have approval, expiry and post-event review;
8. OD-07 exact topology/location EUR SKU export is linked;
9. migration/rollback and no-silent-budget-raise rules are signed;
10. BCK-01/02/05, D1 ledger and LAUNCH_STATUS update atomically.

OD-07 remains Proposed until the exact OD07-DEC-01 owner verdict. Its
engineering location/threshold/export package is decision-ready; current EUR
SKU/Finance evidence, qualified production Legal/Privacy review and runtime
measurements remain separate provisioning/activation gates.

## 18. Provisioning gate

Before any billing link or cloud resource:

- BCK-05 and OD-07 satisfy their required decision status;
- this exact-version budget proposal has owner/Finance/Operations verdicts;
- G1 and a separately Approved R1 slice name exact projects, files, commands,
  identities, resources, regions, quotas, budgets, rollback and verification;
- an owner can receive alerts before the first billable action;
- dev/stage hard bounds exist before load generation;
- production remains absent/default-off.

This document alone authorizes none of those actions.

## 19. Explicitly absent

- billing account, provider quote, invoice, tax or support-plan decision;
- Firebase/GCP project IDs and resources;
- actual EUR SKU export or calculator artifact;
- measured stage/production traffic, amplification or unit economics;
- configured budgets, alerts, Pub/Sub notifications, quotas or flags;
- accepted OD-07/BCK05-OD-04 verdicts;
- cloud credentials, production data, deployment or market activation.

## 20. Acceptance criteria

1. **BCK05-COST-AC-01:** vendor facts and Recharge assumptions are separate.
2. **BCK05-COST-AC-02:** every external price has a checked date and source.
3. **BCK05-COST-AC-03:** price evidence expires before irreversible provisioning.
4. **BCK05-COST-AC-04:** USD list estimates are not called EUR invoices.
5. **BCK05-COST-AC-05:** actual EUR SKU export supersedes planning anchors.
6. **BCK05-COST-AC-06:** taxes/support/external providers remain explicit exclusions.
7. **BCK05-COST-AC-07:** credits/free tiers are upside, not safety dependencies.
8. **BCK05-COST-AC-08:** dev, stage and prod budgets remain isolated.
9. **BCK05-COST-AC-09:** environment isolation is not weakened for free quota.
10. **BCK05-COST-AC-10:** L1/L2/L3 are distinct approval envelopes.
11. **BCK05-COST-AC-11:** L3 stress forecast is not normal spending authority.
12. **BCK05-COST-AC-12:** Firestore index/listener amplification is measured.
13. **BCK05-COST-AC-13:** Functions model includes requests, CPU, memory and egress.
14. **BCK05-COST-AC-14:** media model includes storage, operations and egress.
15. **BCK05-COST-AC-15:** PITR, backup and restore are separate cost lines.
16. **BCK05-COST-AC-16:** logs preserve mandatory audit while bounding noise.
17. **BCK05-COST-AC-17:** billing alerts are not described as spend caps.
18. **BCK05-COST-AC-18:** billing delay is covered by service usage controls.
19. **BCK05-COST-AC-19:** 50/75/90/100% thresholds have named actions.
20. **BCK05-COST-AC-20:** production billing is never detached automatically.
21. **BCK05-COST-AC-21:** containment preserves safety/privacy/audit paths.
22. **BCK05-COST-AC-22:** emergency ceiling requires owner, reason and expiry.
23. **BCK05-COST-AC-23:** optional providers have separate budgets/kill switches.
24. **BCK05-COST-AC-24:** budget is not raised silently after overrun.
25. **BCK05-COST-AC-25:** unit economics contain no user identity billing labels.
26. **BCK05-COST-AC-26:** unattributed cost is measured and bounded.
27. **BCK05-COST-AC-27:** market attribution does not activate EE/LT.
28. **BCK05-COST-AC-28:** shared-platform allocation has one documented rule.
29. **BCK05-COST-AC-29:** country project split requires evidence/new decision.
30. **BCK05-COST-AC-30:** topology remains Proposed until OD-07 passes.
31. **BCK05-COST-AC-31:** A1 is a validation baseline, not Accepted topology.
32. **BCK05-COST-AC-32:** location transfer appears as an explicit cost line.
33. **BCK05-COST-AC-33:** min instances default to zero absent accepted evidence.
34. **BCK05-COST-AC-34:** CUD purchase requires stable usage and break-even proof.
35. **BCK05-COST-AC-35:** stage replaces assumptions with measured amplification.
36. **BCK05-COST-AC-36:** estimate/actual variance above 20% is investigated.
37. **BCK05-COST-AC-37:** Product/Finance and Operations verdicts are distinct.
38. **BCK05-COST-AC-38:** Legal/Privacy/tax conclusions are not invented.
39. **BCK05-COST-AC-39:** Acceptance and provisioning remain separate gates.
40. **BCK05-COST-AC-40:** this document creates no billing/runtime/cloud resource.
