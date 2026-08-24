# BCK-D1 — OD-07 Infrastructure Decision Evidence

- Evidence ID: **BCK-D1-OD07-EV-01**
- Version: **0.4**
- Date: **2026-08-21**
- Decision: **OD-07 — Firebase topology, edition and per-resource locations**
- Decision status: **Proposed — not Accepted**
- Evidence status: **Draft — specialist review required**
- Runtime status: **Absent**
- Accountable decision owner: **Platform Operations owner**
- Required co-owners: **Security/Privacy, Legal/Privacy and Finance/Cost**
- Parent specifications: [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md),
  [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md),
  [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Cost evidence: [BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md) v0.2 (Draft)
- Reliability evidence: [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) v0.1 (Draft)
- Recovery evidence: [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) v0.1 (Draft)
- Runtime effect: **none**

---

## 1. Purpose and verdict

This record turns the existing OD-07 proposal into a reviewable evidence
package. It does not accept OD-07 and does not authorize project creation,
billing attachment, Firestore provisioning, Storage buckets, Functions,
credentials, deployment or production data processing.

The current preferred candidate remains **Option A**:

- separate Firebase/GCP projects for `dev`, `stage` and `prod`;
- Firestore **Standard edition, Native mode**;
- Firestore multi-region **`eur3`**;
- Cloud Functions **2nd gen, explicitly `europe-west1`** unless a trigger has
  a separately approved colocation requirement;
- Cloud Storage location selected separately from an approved EU-only option;
- Local Emulator Suite is test tooling, not an environment or production proof.

Option A is technically plausible, but it is not Accepted. Dated price anchors,
workload formulas, cost envelopes and proposed EUR controls now exist in
BCK05-OD04-COST-01; actual location-specific EUR SKU export, measured latency,
specialist verdicts, residency/processor, IAM, recovery and export evidence are
still absent.
New cloud resources are not required to prepare that decision evidence.

## 2. Authoritative external evidence snapshot

Sources were refreshed on 2026-08-21. A reviewer must re-check them on the
decision date because product availability, pricing and location behavior can
change.

| Source | Verified fact | Consequence for Recharge |
|---|---|---|
| [Firebase product/resource locations](https://firebase.google.com/docs/projects/locations) | There is no single project/app location; location is selected per product/resource. New default Storage buckets and default Firestore no longer necessarily set each other's location. | OD-07 must enumerate each resource instead of recording one ambiguous “EU location”. |
| [Cloud Firestore locations](https://firebase.google.com/docs/firestore/locations) | A database location cannot be changed after provisioning. `eur3` uses Belgium and Netherlands read-write regions with Finland as witness. Regional and multi-region choices have different availability, latency and cost characteristics. | Firestore creation is an irreversible G1 decision and requires explicit evidence/sign-off. |
| [Cloud Functions locations](https://firebase.google.com/docs/functions/locations) | Functions are regional; `europe-west1` supports 2nd gen. Cross-region use may increase latency and cost; `europe-west1` is the documented nearest Functions region for `eur3`. | Region must be explicit in source/config and verified against every trigger/data source. |
| [Cloud Storage locations](https://cloud.google.com/storage/docs/locations) | Storage supports regional, dual-region and `EU` multi-region choices; `EU` stores object data in EU member-state data centers. | Storage requires its own residency, latency, durability and price decision; Firestore choice does not settle it. |
| [Firestore product/edition overview](https://cloud.google.com/firestore) | Standard and Enterprise editions have different query capabilities and billing models; Standard supplies the mobile/web SDK and real-time/offline model needed by the current architecture. | Standard/Native remains the least-expansive candidate; Enterprise needs a new evidence-backed reason. |
| [Cloud Billing budgets](https://cloud.google.com/billing/docs/how-to/budgets) | Alerts-only budgets notify; they do not automatically cap usage or spending. | Budgets must be paired with quotas, alerts, kill switches and an owned response procedure. |

External documentation proves product constraints, not Recharge suitability or
GDPR compliance. Legal basis, processor terms, transfers, records of processing
and data-residency conclusions remain owned by BCK-04/Legal.

## 3. Options under review

| Option | Firestore | Functions | Storage | Strength | Unresolved cost/risk |
|---|---|---|---|---|---|
| **A — preferred candidate** | Standard Native, `eur3` | 2nd gen, `europe-west1` | exact EU-only location TBD | higher documented Firestore availability; compatible with Baltic rollout | multi-region cost/write latency; Storage placement; cross-resource egress |
| B — regional colocation | Standard Native, `europe-west1` | 2nd gen, `europe-west1` | `europe-west1` or approved EU topology | simpler colocation and potentially lower cost/write latency | lower Firestore regional SLA; Belgium distance; DR proof |
| C — Nordic regional | Standard Native, `europe-north1` | 2nd gen, `europe-north1` | approved Nordic/EU location | geographically closer to Baltics than Belgium | measured client latency, service coverage, cost and recovery still unknown |

No option may be selected from documentation intuition alone. The final record
must include the exact project/resource matrix and why rejected options lost.

## 4. Required project and resource matrix

The Accepted OD-07 record must fill every cell; `inherit default` is forbidden
unless the exact vendor dependency and its immutability are documented.

| Resource | dev | stage | prod | Required evidence |
|---|---|---|---|---|
| Firebase/GCP project ID | TBD | TBD | TBD | ownership, billing, labels, deletion protection |
| Firestore edition/mode | Proposed Standard/Native | Proposed Standard/Native | Proposed Standard/Native | feature and pricing comparison |
| Firestore database ID/location | TBD | TBD | TBD | location immutability acknowledgement |
| Functions generation/regions | TBD | TBD | TBD | trigger-to-data colocation map |
| Storage bucket/purpose/location | TBD | TBD | TBD | data class, residency, lifecycle and egress |
| Scheduler/task/event transport | disabled/TBD | disabled/TBD | disabled/TBD | OD-09 plus location/at-least-once proof |
| Auth/App Check configuration | mock/disabled | disabled | disabled | BCK-04/BCK-06 rollout evidence |
| Logging/monitoring destinations | TBD | TBD | TBD | redaction, retention, access and region |
| Backup/export destinations | none | none | none | RPO/RTO, encryption, deletion propagation |

## 5. Evidence still required before Acceptance

### 5.1 Platform and performance

- dated vendor topology, SLA, quota and pricing facts for every candidate;
- explicitly labelled modelled p50/p95/p99 read, query and callable latency
  from Latvia and representative Estonia/Lithuania networks, with assumptions,
  uncertainty and no claim that modelled values were measured;
- predeclared acceptance thresholds and a reproducible post-provision synthetic
  test method for Booking transaction contention/latency and Event/Discover
  query paths;
- trigger/data-source colocation and cross-region failure analysis;
- quotas, index limits, hot-key/aggregate behavior and scale assumptions;
- explicit Standard-versus-Enterprise capability comparison.

Existing lawful non-production measurements may supplement this package, but
OD-07 review does not authorize creating a project or resource to obtain them.
After a separately Approved R1/G1 provisioning slice creates the selected
non-production topology, the declared synthetic benchmarks become mandatory
before production traffic. A failed threshold keeps traffic and affected
server flags disabled and triggers the recorded replace/export decision path.

### 5.2 Cost and capacity

Present as Draft evidence in
[BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md):

- dev/stage plus launch, expected year-one and Baltic stress envelopes;
- reproducible Firestore, Functions, Storage, logs and recovery formulas;
- directional USD list estimates and separate proposed EUR guardrails;
- 50/75/90/100% actions, emergency ceilings, unit economics and cost risks;
- A1/A2/B/C topology cost interpretation.

Still required: exact selected-location EUR SKU/calculator export, Finance and
Operations verdicts, tax/support treatment, measured amplification and
post-provision estimate-versus-actual reconciliation.

### 5.3 Security, privacy and Legal

- data inventory and processor/subprocessor mapping per resource;
- DPA, international-transfer and EU/EEA processing-location review;
- organization resource-location constraints and exception procedure;
- least-privilege IAM matrix, break-glass, MFA and credential lifecycle;
- log/backup/Storage data classes, retention and erasure propagation;
- written Legal/Privacy conclusion for LV and the planned EE/LT expansion.

### 5.4 Reliability and reversibility

Present as Draft evidence:

- [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) supplies
  numerical user-journey SLO/error budgets, burn alerts and stage validation;
- [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) supplies numerical
  record-family RPO/RTO, candidate protection, isolated restore, privacy
  re-deletion, reconciliation and drill design.

Still required:

- Product/domain/Operations/Privacy/Legal verdicts on applicable targets;
- representative stage SLO and restore drill evidence;
- Firestore exit/export plan, data format and tested restore target;
- project/resource deletion protection and incident ownership;
- rollback boundary that does not pretend an already-created Firestore location
  can be changed in place.

## 6. Acceptance and provisioning gates

OD-07 becomes `Accepted` only when one immutable decision record contains:

1. selected option and rejected-option rationale;
2. completed resource matrix for all environments;
3. dated source snapshot, published/modelled evidence, declared thresholds and
   an accepted post-provision validation plan;
4. cost forecast and approved alert/containment ownership;
5. Security/Privacy and Legal/Privacy conclusions;
6. Platform Operations sign-off;
7. migration/export/restore and rollback constraints;
8. decision date, review date and supersession procedure;
9. atomic updates to BCK-01/02/04/05 and LAUNCH_STATUS.

Even Accepted OD-07 does not itself authorize provisioning. R1 additionally
requires G1 and a separately Approved executable slice with exact files,
commands, identities, rollback and verification.

The first authorized non-production resources are validation targets, not
retroactive evidence that the chosen topology was correct. Before any
production traffic, the R1 slice must record actual synthetic read/query/
callable/transaction results against the predeclared thresholds. If they fail,
production activation remains off and the selected topology must be reviewed or
superseded; silent threshold relaxation is forbidden.

## 7. Fail-closed state now

- OD-07 remains `Proposed`;
- R1 and all location-bound resource creation remain blocked;
- no production project names, credentials or billing identifiers are recorded;
- no console action is evidence of approval;
- any accidental resource creation is an incident/gap to inventory, not a new
  architectural source of truth.

## 8. Evidence acceptance criteria

1. **OD07-EV-AC-01:** every location-capable resource is decided separately.
2. **OD07-EV-AC-02:** Firestore location immutability is acknowledged.
3. **OD07-EV-AC-03:** Storage does not silently inherit Firestore semantics.
4. **OD07-EV-AC-04:** `eur3` and `europe-west1` remain proposals until sign-off.
5. **OD07-EV-AC-05:** three environment projects have isolated authority.
6. **OD07-EV-AC-06:** pre-decision latency models/thresholds and post-provision
   tests cover LV and representative EE/LT paths without conflating the two.
7. **OD07-EV-AC-07:** cost includes operations, storage, network, logs and backup.
8. **OD07-EV-AC-08:** budget alerts are not described as hard spend caps.
9. **OD07-EV-AC-09:** IAM, processor, transfer and residency reviews are explicit.
10. **OD07-EV-AC-10:** export, restore and reconciliation are testable.
11. **OD07-EV-AC-11:** Acceptance and physical provisioning remain separate gates.
12. **OD07-EV-AC-12:** this document creates no runtime or cloud resource.
