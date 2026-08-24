# Recharge Backend — OD-07 Infrastructure Owner Decision

- ID: **OD07-DEC-01**
- Version: **0.1**
- Date: **2026-08-24**
- Status: **Review — owner verdict not recorded**
- Decision target: **OD-07**
- Candidate baseline: **OD07-A1-EU-MR-v1**
- Evidence: [BCK-D1-OD07-EV-01 v0.5](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md)
- Parent: [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md) (Draft)
- Accountable verdict: **Platform Operations + Security/Privacy + Product/Finance**
- Legal boundary: **qualified Legal/Privacy production verdict is not replaced**
- Assigned bootstrap owner: **RechargeN / Product owner acting as combined Platform coordinator**
- Runtime effect: **none**

---

## 1. Purpose

This record asks one narrow question: may Recharge adopt
`OD07-A1-EU-MR-v1` as its infrastructure architecture baseline?

Acceptance does not approve BCK-04/BCK-05, pass D1/G1, authorize R1, create a
project, attach billing, create IAM/credentials, provision a database/bucket,
deploy code, process personal data or activate Latvia/Estonia/Lithuania.

## 2. Exact baseline under review

| Concern | Selected value |
|---|---|
| Platform topology | one logical backend; isolated `dev`, `stage`, `prod` projects |
| Provider project identity | deterministic logical handles; exact globally available IDs recorded in R1 before creation; reuse forbidden |
| Firestore | Standard edition, Native mode, `(default)` database, `eur3` |
| Functions | Cloud Functions for Firebase 2nd gen, explicit `europe-west1` |
| Runtime media | Firebase/Cloud Storage regional `europe-west1` |
| Firestore backups | same location as source; disabled until BCK05-OD-05 |
| Exit/export destination | separate `EU` multi-region GCS bucket, disabled until approved recovery/export slice |
| Artifact Registry | `europe-west1` |
| Operational log bucket | `eu`; unavoidable/global service logs disclosed and minimized |
| Secrets | disabled until BCK05-OD-02 proves an exact compatible `europe-west1` placement |
| Scheduler/Tasks/Pub/Sub/Eventarc | disabled until OD-09 |
| Auth/App Check/Analytics/Crashlytics/FCM/Remote Config | disabled until owning security/privacy/product activation gates |
| Markets | LV is the only future initial cohort; EE/LT remain server-disabled |

## 3. Why this option

The selected option gives the authoritative database multi-region resilience,
uses Google's documented closest Functions region for `eur3`, and colocates
media processing with regional Storage. Standard/Native meets the accepted
mobile real-time/offline and Core-query needs without introducing Enterprise
query/index/pricing semantics that Recharge does not currently require.

The option is not claimed to be fastest or cheapest before measurement. Stage
must meet the predeclared SLO, contention and cost thresholds. If it does not,
Option B (`europe-west1` regional Firestore/function/media) is reviewed as a
replacement; thresholds are not silently weakened.

## 4. Mandatory controls

Acceptance includes all of these controls:

1. no implicit resource region or `us-central1` fallback;
2. no reuse of a project with unknown/legacy App Engine, Firestore, Storage or
   logging location state;
3. no production data in `dev`/`stage`;
4. all mutations and all markets default off;
5. exact EUR SKU/budget/owner revalidation before chargeable provisioning;
6. post-provision Riga/Tallinn/Vilnius tests before production traffic;
7. zero tolerated Booking oversell or unexplained ledger/usage drift;
8. no statement that all Firebase processing is EU-only;
9. Firebase Authentication and other global/US-operated services remain
   disabled until qualified processor/transfer/legal review;
10. immutable location replacement requires a new target and tested migration;
11. R1 requires G1 plus a separate exact Approved executable slice;
12. every revalidation/supersession trigger in the evidence fails closed.

## 5. Explicitly preserved gates

This decision does not authorize:

- merge to `main`;
- Firebase/GCP organization, folder or project creation;
- billing account linkage, budgets or any chargeable resource;
- Firestore, Storage, Functions, Logging, Artifact Registry or Secret Manager
  provisioning;
- service accounts, WIF, keys, secrets or credentials;
- Terraform plan/apply/import/destroy;
- Firebase deploy or public ingress;
- production Auth, Booking, Event, media, notifications, analytics or payments;
- personal or production-derived data;
- LV, EE or LT market activation.

OD-10, BCK-04/05 specialist decisions, complete D1/G1 and the executable R1
plan remain independent blockers.

## 6. Legal and residency boundary

The decision accepts an engineering location model, not legal advice. It permits
only this precise statement: location-controlled customer-content resources are
selected in European locations. It does not claim that Firebase Authentication,
service data, mandatory logs or all Google processing stays in the EU/EEA.

Production personal-data use still requires a qualified Legal/Privacy review of
the DPA, subprocessors, transfer mechanism, legal basis, transparency,
retention/deletion and per-service processing behavior.

## 7. Owner verdict

Allowed verdicts:

| Verdict | Result |
|---|---|
| `Accept OD07-A1-EU-MR-v1 with controls` | OD-07 becomes Accepted only as §§2–6 define; no runtime permission |
| `Accept with amendments` | remains Proposed until amendments are incorporated and re-reviewed |
| `Reject` | remains Proposed; a replacement direction is recorded |
| `Inconclusive` | remains Proposed; missing evidence/authority is named |

Recommended verdict: **Accept OD07-A1-EU-MR-v1 with controls**.

The only effective approval phrase is:

```text
Одобряю OD07-DEC-01: Accept OD07-A1-EU-MR-v1 with controls.
```

Generic “да”, “дальше”, approval of documentation work, silence or file
presence is not this decision.

## 8. Status after exact acceptance

| Item | Resulting state |
|---|---|
| OD-07 | Accepted at `OD07-A1-EU-MR-v1` with §4 controls |
| BCK-04 / BCK-05 | Draft; unchanged |
| qualified Legal/Privacy production verdict | still required |
| OD-10 / complete D1 / G1 | blocked or unchanged |
| R1 | blocked until separate exact Approval |
| Firebase/GCP runtime | Absent |
| product/cloud backend | Absent |
| `main` | untouched |

## 9. Acceptance criteria

1. **OD07-DEC-AC-01:** one exact topology baseline is the target.
2. **OD07-DEC-AC-02:** project isolation is accepted without inventing unavailable provider IDs.
3. **OD07-DEC-AC-03:** Firestore edition/mode/database/location are exact.
4. **OD07-DEC-AC-04:** Functions and Storage locations are exact and independent.
5. **OD07-DEC-AC-05:** Standard-versus-Enterprise reasoning is explicit.
6. **OD07-DEC-AC-06:** global/US Firebase services are not hidden.
7. **OD07-DEC-AC-07:** architecture acceptance is not Legal approval.
8. **OD07-DEC-AC-08:** latency values are thresholds, not measurements.
9. **OD07-DEC-AC-09:** cost revalidation precedes chargeable work.
10. **OD07-DEC-AC-10:** immutable-resource rollback means replacement/migration.
11. **OD07-DEC-AC-11:** all markets and mutations remain off.
12. **OD07-DEC-AC-12:** only the exact phrase changes decision status.
13. **OD07-DEC-AC-13:** Acceptance does not pass D1/G1 or authorize R1.
14. **OD07-DEC-AC-14:** Acceptance creates no cloud/runtime effect.
15. **OD07-DEC-AC-15:** merge to `main` is outside the decision.

---

**Current conclusion:** the decision is ready for the Product owner, but no
verdict is recorded. OD-07 remains **Proposed** and all cloud actions remain
blocked.
