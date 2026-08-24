# Recharge Backend — Service Reliability, SLO and Error-Budget Model

- Evidence ID: **BCK05-OD03-SLO-01**
- Version: **0.1**
- Date: **2026-08-21**
- Decision served: **BCK05-OD-03**
- Decision status: **Proposed — Product/domain/Operations verdict pending**
- Evidence status: **Draft — stage measurement and owner review required**
- Runtime status: **Absent**
- Accountable coordinator: **RechargeN / Product owner**
- Required reviewers: **Platform Operations, Product, Identity, Content,
  Discover, Booking, Notifications, Privacy and Mobile owners**
- Parent: [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Cost boundary: [BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md)
- Recovery boundary: [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md)
- Markets: **Latvia first; Estonia and Lithuania measured independently**
- Runtime effect: **none**

---

## 1. Purpose and verdict

This document defines the first numerical backend reliability proposal for
Recharge. It turns the BCK-05 service classes into measurable user journeys,
SLIs, SLOs, latency/freshness limits, error budgets, burn alerts and release
rules.

It advances `BCK05-OD-03` from Open to **Proposed**, not Accepted. The numbers
are product/operations hypotheses until stage proves their measurability and
owners approve the trade-offs. This document creates no metric, alert, on-call
route, Cloud Monitoring resource, backend service or production commitment.

## 2. Scope and exclusions

Included:

- backend-authoritative Identity/access, publication, Discover, Booking,
  personal-library, notification and operational journeys;
- request, latency, freshness, async-lag and invariant SLIs;
- 28-day rolling compliance plus calendar-month reporting;
- fast/slow burn alerts and release/error-budget policy;
- Latvia launch targets and independent EE/LT validation;
- exact evidence required before Acceptance and production use.

Excluded:

- mobile rendering/frame/network-radio performance before the backend edge;
- offline availability and local/mock behavior;
- third-party provider, payment, Maps, email/SMS or AI availability guarantees;
- legal response deadlines, security incident severity and recovery RPO/RTO;
- a contractual customer SLA or compensation promise;
- production topology, provisioning and executable alert configuration.

External dependencies remain observable. Their failure is not silently removed
from the end-to-end user SLO when Recharge selected or integrated them.

## 3. Vocabulary and non-substitution rules

| Term | Recharge meaning |
|---|---|
| SLI | measured ratio/distribution from a named user or operational journey |
| SLO | internal objective for an SLI over a defined compliance period |
| Error budget | permitted bad events/windows: `(1 - objective) × eligible total` |
| Vendor SLA | provider contract/credit boundary; evidence input, not Recharge SLO |
| Availability | valid eligible interaction receives a correct typed outcome |
| Latency | backend edge receive to final authoritative response, not UI animation |
| Freshness | projection age/revision remains within declared product bound |
| Invariant | correctness rule with zero tolerated breach, outside normal budget |

A typed product outcome such as `sold_out`, `not_eligible`, `cancelled` or a
valid conflict is a **good availability event** when it is correct and timely.
Returning an incorrect success is always bad and can be an invariant incident.

## 4. Evidence hierarchy and dated provider context

1. Accepted Recharge domain invariants and user-safety requirements govern.
2. This proposal supplies initial internal objectives.
3. Stage and production telemetry supplies measured capability.
4. Provider SLA is a dependency floor/contract, never proof of end-to-end SLO.

Official context checked **2026-08-21**:

- Firestore location documentation lists multi-region availability SLA
  `>=99.999%` and regional `>=99.99%`;
- current Cloud Run non-GPU SLA lists `99.95%` for the proposed Belgium region;
- Cloud Storage Standard lists `99.95%` for multi/dual-region and `99.9%` for
  regional placement;
- Cloud Monitoring defines burn rate as actual failure rate divided by the
  sustainable failure rate and recommends fast- and slow-burn alerting.

Sources:

- [Firestore locations and SLA](https://docs.cloud.google.com/firestore/docs/locations)
- [Cloud Run SLA](https://cloud.google.com/run/sla)
- [Cloud Storage classes and availability](https://docs.cloud.google.com/storage/docs/storage-classes)
- [Cloud Monitoring burn-rate alerts](https://docs.cloud.google.com/stackdriver/docs/solutions/slo-monitoring/alerting-on-budget-burn-rate)
- [Google SRE alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)

These facts expire for approval when the chosen services/locations or terms
change. Recharge targets below remain proposals even if provider numbers stay
unchanged.

## 5. Service classes and journey ownership

| Class | Journey examples | Owning boundary | Failure-safe priority |
|---|---|---|---|
| C1 — authority/safety mutation | sign-in/session authority; publish; Booking create/cancel/manage; privacy restriction/deletion command | owning domain command | correctness, idempotency and safe exit before availability |
| C2 — interactive read | profile/details; own Booking; availability; catalog/feed/map/search; favorites/history | owning read projection/query | honest typed stale/unavailable before false freshness |
| C3 — asynchronous obligation | outbox dispatch; notification; projection update; expiry/cleanup; reconciliation | producing domain plus worker owner | no duplicate authority effect; bounded lag and poison visibility |
| C4 — operational control | deploy, rollback, flag propagation, backup and restore | Platform Operations | evidence and safe containment before speed |

No aggregate inherits a weaker target merely because it uses a shared class.
A domain may declare a stricter objective or invariant. Booking's accepted
product requirements remain the stricter contract where applicable.

## 6. Eligible, good and bad events

### 6.1 Request availability

Eligible event:

- reaches the Recharge backend edge;
- uses a supported contract and valid transport shape;
- is attributable to the correct environment/service/journey;
- is not synthetic traffic explicitly tagged and reported separately.

Good event:

- returns the correct typed success, cancelled or product rejection;
- returns a final response rather than a gateway/client-visible timeout; latency
  quality is budgeted independently by the p95/p99 objectives in §7;
- does not violate authorization, idempotency or domain invariants.

Bad event:

- unhandled 5xx/infrastructure failure;
- timeout/connection termination after reaching Recharge;
- incorrect/ambiguous success or unknown outcome after mutation;
- valid request rejected because Recharge quota/config/capacity is wrong;
- response violates its contract, authority or freshness declaration.

Excluded from the availability ratio but counted separately:

- malformed/unsupported client contract rejected as designed;
- correct AuthZ, rate-limit, abuse or feature-disabled rejection;
- client cancellation before authoritative execution starts;
- traffic from an explicitly blocked market/capability.

Exclusions are bounded reason codes. `unknown`, missing reason or a provider
error is never converted into excluded traffic.

### 6.2 Latency

Latency eligibility uses the same valid events. Expected product rejections are
included. Retries are separate attempts correlated to one logical operation;
the user-journey view also measures time to one authoritative outcome.

### 6.3 Async completion

An async obligation begins at authoritative commit. Good means the obligation
reaches its declared durable terminal state once, within the time target.
Notification delivery cannot claim success merely because it was enqueued.

## 7. Numerical launch SLO proposal

Compliance is a **rolling 28-day window**, reported additionally by UTC calendar
month. Stage uses the same definitions but does not count as production proof.

| SLO ID | Journey/SLI | Objective | Latency/freshness objective | Minimum volume treatment |
|---|---|---:|---|---|
| SLO-C1-AUTH | valid Identity/session/access-authority evaluation | **99.9%** good | p95 `<=750 ms`; p99 `<=2 s` | synthetic evidence when `<100` eligible/5 min |
| SLO-C1-CMD | valid authoritative mutation, excluding stricter domain row | **99.9%** good | p95 `<=1.5 s`; p99 `<=3 s` | request ratio plus continuous synthetic probe |
| SLO-C1-BOOK | Booking create/cancel/manage valid command | **99.9%** good | p95 `<=1.5 s`; p99 `<=3 s` | preserves Booking spec; no dilution by other commands |
| SLO-C2-OWN | own profile/library/Booking authorized read | **99.9%** good | p95 `<=750 ms`; p99 `<=2 s` | per journey, not one pooled read metric |
| SLO-C2-DISC | details/catalog/feed/map/search valid query | **99.5%** good | p95 `<=1.5 s`; p99 `<=4 s` | query shape and market dimensions mandatory |
| SLO-C2-FRESH | Discover projection revision/freshness | **99.5%** within bound | source-to-visible p95 `<=5 min`; p99 `<=15 min` | stale typed response remains availability-good but freshness-bad |
| SLO-C3-OUT | durable outbox obligation starts dispatch | **99.5%** within target | p95 `<=60 s`; p99 `<=5 min` | zero-volume period is `no_data`, not 100% |
| SLO-C3-TERM | async obligation reaches terminal resolution | **99.5%** within target | p95 `<=5 min`; p99 `<=30 min` | poison/dead-letter remains bad until resolved |
| SLO-C3-PROJ | accepted source revision reaches critical projection | **99.5%** within target | p95 `<=5 min`; p99 `<=15 min` | source and projection revisions required |
| SLO-C4-FLAG | emergency server flag effective in target scope | **99.9%** verified | p95 `<=2 min`; p99 `<=5 min` | measured by signed synthetic acknowledgement |

`SLO-C2-FRESH` does not permit feed/map/search inconsistency. One DiscoverQuery
uses a shared query revision/freshness contract; silent divergence is an
invariant finding or typed inconsistent/stale result.

### 7.1 Domain overrides and zero-tolerance invariants

| Invariant/signal | Target | Response |
|---|---:|---|
| unauthorized protected/private read or mutation | **0** | immediate security incident and affected path containment |
| Booking oversell | **0** | disable create/approve/promote for affected pool; preserve safe read/cancel |
| duplicate allocation/effect | **0** | contain writer/consumer; reconcile before reopen |
| unexplained Booking ledger/usage drift | **0 unresolved** | block affected pool and use audited repair |
| authority from client-declared role/workspace | **0** | security incident; revoke unsafe path |
| silent newer-critical contract downgrade | **0** | fail closed and compatibility incident |
| lost acknowledged privacy restriction/deletion task | **0** | privacy incident/recovery workflow |

Zero-tolerance invariants do not gain permission from remaining error budget.

## 8. Error-budget arithmetic

For request-based objectives:

```text
eligible = good + bad
availability = good / eligible
budget_events = eligible * (1 - objective)
budget_remaining = budget_events - bad
burn_rate = observed_bad_rate / (1 - objective)
```

Time-equivalent reference for a 30-day month (request SLOs still use events):

| Objective | Error fraction | Equivalent allowance |
|---:|---:|---:|
| 99.9% | 0.1% | 43 min 12 s |
| 99.5% | 0.5% | 3 h 36 min |
| 99.0% | 1.0% | 7 h 12 min |

Budgets are not pooled across C1/C2 journeys, markets or invariants. A high-
volume healthy feed cannot hide broken cancellation or access control.

## 9. Latency, freshness and async budgets

- latency SLO requires both p95 and p99; an average is not evidence;
- percentiles use server-side histograms with defined buckets and exemplar-
  safe correlation, not raw personal payloads;
- cold starts, retries and dependency time are included when user-visible;
- freshness uses authoritative commit time/revision to projection-visible time;
- `stale` can be a correct availability outcome but consumes freshness budget;
- async lag starts at commit, not when a worker first observes the record;
- clock skew, missing revision or missing start time produces `unmeasurable`,
  which blocks Acceptance and cannot be counted good.

## 10. Burn-rate alerts and operational response

Initial thresholds follow current Google Cloud guidance as starting points and
must be tuned on stage without weakening the objective:

| Alert | Condition | Severity/action |
|---|---|---|
| fast burn | `>=10x` sustainable burn for 1 hour, confirmed by a 5-minute window | page Operations; incident assessment |
| slow burn | `>=2x` sustainable burn for 24 hours, confirmed by a 2-hour window | owned ticket and release review |
| budget 50% consumed | any SLO in current 28-day period | freeze expansion/risky flags for that journey |
| budget 75% consumed | any SLO | reliability work only except approved safety/security fixes |
| budget exhausted | remaining `<=0` | no ordinary release; owner-approved recovery plan/postmortem |
| invariant breach | one confirmed event | immediate page/containment regardless of burn rate |
| telemetry absent | eligible traffic with no valid SLI for 10 min C1 / 30 min C2–C3 | monitoring incident; no green status |

Both fast and slow conditions require low-volume safeguards. Alert resolution
requires recovery signal plus budget/telemetry reconciliation, not manual close.

## 11. Error-budget release policy

| Remaining budget | Release policy |
|---:|---|
| `>75%` | normal bounded releases after all gates |
| `50–75%` | no cohort/market expansion; elevated observation |
| `25–50%` | only low-risk fixes and reliability/security work |
| `0–25%` | change freeze except incident, privacy, security and proven recovery |
| `<=0` | stop ordinary rollout; postmortem and owner recovery decision required |

Budget is never reset by renaming a service, changing the query denominator,
excluding errors after the fact or raising the SLO window mid-period. A target
change is a versioned Product + Operations decision effective next period.

Reliability error budget and BCK05-OD04 monetary budget are independent. Either
one can block rollout; remaining money cannot excuse unreliability, and
remaining reliability budget cannot excuse uncontrolled spend.

## 12. Degraded-mode contract

During reliability incidents the platform prefers honest reduced capability:

- preserve authenticated access to own state where safe;
- preserve Booking read/cancel/safe release before new allocation;
- preserve privacy request status/restriction and incident evidence;
- freeze create/approve/promote when authority/inventory is uncertain;
- return typed stale/unavailable for projections rather than fabricated data;
- pause optional notifications, variants, exports, rebuilds and AI/provider
  effects before safety-critical paths;
- never switch production authority to mobile/local/mock storage.

Every degraded mode has a server-owned flag, scope, owner, expiry, audit and
tested recovery condition.

## 13. Required telemetry contract

Every SLI event contains only bounded operational fields:

```text
timestampUtc, environment, market, serviceId, journeyId, sloId,
outcomeClass, reasonCode, latencyBucket, contractVersion,
sourceRevisionPresent, projectionFreshnessBucket,
retryClass, dependencyClass, releaseManifestId, flagRevision
```

Forbidden in metrics/labels: user ID, email, phone, name, precise location,
search/free text, application content, access code, private join link, raw IP,
Booking guest data or high-cardinality request/correlation IDs.

Traces/logs follow BCK-04 redaction/retention. Metric cardinality has a declared
budget; market/service/journey dimensions are bounded allowlists.

## 14. Low traffic, synthetic and no-data policy

- zero eligible events yields `no_data`, never 100%;
- below 100 events per 5 minutes, C1 pages also require a safe synthetic probe;
- synthetic traffic uses non-production/synthetic identities and cannot mutate
  real inventory, privacy or publication state;
- synthetic success does not replace real-traffic SLI when traffic exists;
- Latvia, Estonia and Lithuania are never pooled to hide a market outage;
- a newly enabled market needs seven stage days and a bounded cohort observation
  window before its SLO is called representative.

## 15. Baltic and localization dimensions

Required dimensions: `market=LV|EE|LT`, locale, environment, service and journey.
Locale is not a reliability exclusion. Missing mandatory Legal/safety copy,
wrong market policy, timezone/currency error or newer unsupported reference
revision is a typed bad outcome or fail-closed disabled path as owned by BCK-20.

EE/LT targets begin equal to Latvia. A weaker target requires a Product/Operations
decision and must not weaken authority, privacy or Booking invariants.

## 16. Stage validation plan

Before Acceptance:

1. implement identical SLI definitions in stage and the proposed production map;
2. run normal, peak, cold-start, retry, dependency-failure and partial-outage load;
3. prove every good/bad/excluded reason with fixture/trace evidence;
4. inject 5xx, timeout, contention, queue lag, stale projection and missing
   telemetry;
5. demonstrate fast/slow burn notification delivery to a reachable owner;
6. demonstrate 50/75/100% release-policy actions and recovery;
7. validate Booking automatic stops and safe read/cancel preservation;
8. compare Riga/Tallinn/Vilnius latency separately;
9. retain dashboard/export, manifest, config revision, command and UTC result;
10. reconcile SLO load with BCK05-OD04 cost envelope.

The cost baseline keeps `minInstances=0`. If representative stage evidence
cannot meet an accepted latency target, the review compares bounded warm
capacity plus revised cost against architectural alternatives; it never hides
cold-start failures or silently weakens the SLO.

A timed-out, skipped, manually asserted or emulator-only result is inconclusive.

## 17. Governance and Acceptance gate

`BCK05-OD-03` may become Accepted only when:

1. Product accepts the user-impact/reliability trade-off;
2. Operations accepts measurement, alerting and response ownership;
3. every affected domain accepts its journey mapping and stricter overrides;
4. stage proves denominator integrity and all SLI reason classes;
5. seven consecutive representative stage days meet targets;
6. burn alerts reach a named responder and link a tested runbook;
7. zero-tolerance invariant alerts and containment are exercised;
8. Mobile confirms backend-edge versus end-to-end UX measurement boundaries;
9. cost/retention/cardinality remain within BCK-04/BCK05-OD04 policy;
10. BCK-01/02/05, ledger, evidence package and LAUNCH_STATUS update atomically.

Acceptance of this model still does not authorize cloud provisioning or traffic.

## 18. Explicitly absent

- stage/production metric series, dashboards, alerts or notification routes;
- representative traffic, seven-day observation or load evidence;
- owner/domain/Operations verdicts;
- executable SLI schemas/config and runbooks;
- production on-call, incident automation or error-budget enforcement;
- any contractual customer SLA;
- backend/Firebase resources, billing, credentials or runtime.

## 19. Acceptance criteria

1. **BCK05-SLO-AC-01:** provider SLA and Recharge SLO remain distinct.
2. **BCK05-SLO-AC-02:** every SLO names one journey, SLI and compliance window.
3. **BCK05-SLO-AC-03:** good, bad, eligible and excluded events are explicit.
4. **BCK05-SLO-AC-04:** exclusions use bounded reason codes and are observable.
5. **BCK05-SLO-AC-05:** typed expected rejection can be availability-good.
6. **BCK05-SLO-AC-06:** incorrect success is always bad.
7. **BCK05-SLO-AC-07:** client/offline availability is outside backend SLO.
8. **BCK05-SLO-AC-08:** Recharge-owned dependency failure stays end-to-end visible.
9. **BCK05-SLO-AC-09:** C1 authority journeys use 99.9% proposal.
10. **BCK05-SLO-AC-10:** Booking preserves its stricter existing objectives.
11. **BCK05-SLO-AC-11:** own-state read is not pooled with public feed traffic.
12. **BCK05-SLO-AC-12:** Discover availability and freshness are separate SLIs.
13. **BCK05-SLO-AC-13:** stale typed result cannot pass freshness SLO.
14. **BCK05-SLO-AC-14:** feed/map/search share query revision/freshness semantics.
15. **BCK05-SLO-AC-15:** async lag starts at authoritative commit.
16. **BCK05-SLO-AC-16:** enqueue alone is not terminal delivery success.
17. **BCK05-SLO-AC-17:** p95 and p99 are measured without averages as substitute.
18. **BCK05-SLO-AC-18:** retries have attempt and logical-operation views.
19. **BCK05-SLO-AC-19:** unmeasurable is not good.
20. **BCK05-SLO-AC-20:** zero traffic is no-data, not 100%.
21. **BCK05-SLO-AC-21:** low traffic has safe synthetic coverage.
22. **BCK05-SLO-AC-22:** synthetic probes never mutate real authority.
23. **BCK05-SLO-AC-23:** error budgets are not pooled across critical journeys.
24. **BCK05-SLO-AC-24:** zero-tolerance invariants ignore remaining budget.
25. **BCK05-SLO-AC-25:** fast and slow burn signals both exist.
26. **BCK05-SLO-AC-26:** telemetry absence produces an alert, not green state.
27. **BCK05-SLO-AC-27:** error-budget release actions are deterministic.
28. **BCK05-SLO-AC-28:** exhausted budget cannot be reset by metric relabelling.
29. **BCK05-SLO-AC-29:** degraded mode preserves safe exits and evidence.
30. **BCK05-SLO-AC-30:** production never falls back to local/mock authority.
31. **BCK05-SLO-AC-31:** metrics contain no direct user identity/free text.
32. **BCK05-SLO-AC-32:** metric dimensions have a cardinality allowlist/budget.
33. **BCK05-SLO-AC-33:** LV/EE/LT results remain independently visible.
34. **BCK05-SLO-AC-34:** locale/market correctness is not excluded as noise.
35. **BCK05-SLO-AC-35:** stage validates normal and injected-failure paths.
36. **BCK05-SLO-AC-36:** timed-out/skipped/emulator-only proof is inconclusive.
37. **BCK05-SLO-AC-37:** Product, Operations and domain verdicts remain distinct.
38. **BCK05-SLO-AC-38:** cost and telemetry retention are reconciled.
39. **BCK05-SLO-AC-39:** Acceptance remains separate from provisioning/traffic.
40. **BCK05-SLO-AC-40:** this document creates no runtime or customer SLA.
