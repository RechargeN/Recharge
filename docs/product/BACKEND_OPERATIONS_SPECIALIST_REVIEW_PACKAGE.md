# Recharge Backend — Operations Specialist Review Package

- Package ID: **BCK05-OPS-REV-02**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Prepared — specialist verdicts Pending**
- Runtime status: **Local R0/disabled RAW-C evidence referenced; cloud/product operations runtime Absent**
- Accountable coordinator: **RechargeN / Product owner**
- Parent BCK-05: [v0.2.30](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Parent normalized-LF SHA-256: `9a2e4eb138f46714c75c2b6f7d5f1719452b8087959417d64993a816db4e8ece`
- Coverage matrix SHA-256: `7c30b284513cf0dadfd953bae83ec0973d1c820bf6e11958a26944287281a266`
- Runtime effect: **none**

---

## 1. Purpose

This package combines the remaining BCK-05 documentation reviews without
pretending that stage telemetry, invoices, restore drills, cloud IAM or an
incident exercise already exist. It lets Operations, Finance, Security/Privacy
and affected domain owners review one coherent boundary while preserving five
separate decisions.

## 2. Frozen inputs

| Input | Version | Normalized-LF SHA-256 | Role |
|---|---:|---|---|
| [Numeric owner review](BACKEND_OPERATIONS_NUMERIC_OWNER_REVIEW.md) | 0.2 | `91c7f6b692c5b7521bd7405d4864b77674520ed71df6e4beaab27382b6518971` | current bounded owner disposition |
| [SLO model](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) | 0.1 | `f806e971c43c3f32e484deeb4e0381857a3a67ae2c7d50e90a3b61138bb42993` | OD-03 target |
| [Cost model](BACKEND_INFRASTRUCTURE_COST_MODEL.md) | 0.4 | `0f293fa71593358595ed7580303a03b1df5aaa73098e016eda201042977cc702` | OD-04 target |
| [Recovery model](BACKEND_BACKUP_RECOVERY_MODEL.md) | 0.1 | `b01a67306a90b0fe47e156accffe257268f624f909a5ab23961967f5bddb37a0` | OD-05 target |
| [Incident model](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) | 0.1 | `4717b246d01a5bab7da9a0642595c606b0c3204a2df263296e407ac162c2106c` | OD-08/security input |
| [Tabletop exercise](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) | 0.1 | `5c68ba1024c75cd5a3da885deeff05e1fd98e2b22f1d72a2d97a808a5ea6bf87` | executable evidence plan, not result |

Any change to an exact input invalidates only the affected verdict and requires
re-review; it does not silently invalidate unrelated lanes.

## 3. Decision inventory

| Decision | Current | Pre-G1 design question | Evidence that correctly remains later |
|---|---|---|---|
| BCK05-OD-03 SLO | Proposed | service classes, indicators, stage targets, error-budget response | representative telemetry, alerts, ownership drill |
| BCK05-OD-04 cost | Proposed | budget envelope, hard stops, attribution and review cadence | current EUR invoice/SKU/tax, measured stage usage |
| BCK05-OD-05 recovery | Proposed | backup classes, RPO/RTO targets, deletion/hold treatment | restore/PITR drill, IAM evidence, timed representative result |
| BCK05-OD-06 async operations | Open | OD-09-aligned queue/task/outbox ownership and failure operations | deployed workers, replay/poison drills, capacity measurements |
| BCK05-OD-08 incident operations | Proposed | severity/route/break-glass/tabletop design | named routes, credentials, executed tabletop and findings closure |

OD-01, OD-02, OD-07 and cross-domain OD-07 retain their recorded bounded
Acceptance. This package does not reopen them and does not authorize R1.

## 4. Proposed bounded verdicts

Five verdicts remain distinct even when reviewed together.

| Verdict ID | Proposed disposition | Accepts | Retains |
|---|---|---|---|
| `BCK05-OD03-SIG-OPS` | Accept design baseline with required evidence | service classes, SLI/SLO semantics, stage validation plan | OD-03 Proposed; telemetry/alerts/drills Pending |
| `BCK05-OD04-SIG-FINOPS` | Accept cost-control design with required evidence | envelope semantics, attribution, alerts and hard-stop model | OD-04 Proposed; EUR/tax/SKU/usage evidence Pending |
| `BCK05-OD05-SIG-OPSSEC` | Accept recovery design with required evidence | recovery classes, evidence plan, fail-closed restore governance | OD-05 Proposed; drills/IAM/Privacy/Legal evidence Pending |
| `BCK05-OD06-SIG-APIOPS` | Accept OD-09 alignment boundary only | ownership/failure/replay topology constraints | OD-06 Open until OD-09 exact contract review |
| `BCK05-OD08-SIG-INCSEC` | Accept incident exercise design only | severity/route/exercise structure | OD-08 Proposed; real routes/tabletop result Pending |

No combined response may collapse these verdicts into a single BCK-05
Approval.

## 5. Pre-G1 versus post-R1 evidence

| Evidence | Needed before D1/G1 design closure | Correctly measured after separately Approved R1 | Needed before production traffic |
|---|---:|---:|---:|
| accountable owners and escalation policy | yes | no | yes |
| service classes and target definitions | yes | no | yes |
| cost budget/stop thresholds | yes | revalidate | yes |
| recovery targets and data-class mapping | yes | no | yes |
| OD-09 async ownership/failure contract | minimum Proposed | implementation proof | Accepted before effects/workers |
| incident/tabletop plan | yes | execute with actual routes | passed exercise before applicable gate |
| real telemetry and alert delivery | no | yes | yes |
| current provider invoice/SKU/tax evidence | model/assumptions only | yes | yes |
| timed restore/PITR evidence | no | yes | yes |
| deployed worker replay/poison evidence | no | yes | yes |

This separation prevents both premature runtime work and the circular demand
for cloud measurements before cloud provisioning is authorized.

## 6. Specialist lanes

| Lane | Required scope | May conclude now | Must remain Pending |
|---|---|---|---|
| Platform Operations | OD-03/05/06/08 design operability | exact design verdict/findings | actual stage/runtime proof |
| Product/Finance | OD-04 budget semantics and assumptions | bounded design verdict | real EUR/tax/SKU/invoice treatment |
| Security/Privacy | recovery access, incident routes, logging/data classes | technical design verdict | independent/qualified evidence where required |
| API Platform | OD-06 compatibility with OD-09 | boundary verdict | transport implementation |
| affected domains | service class, recovery criticality, event semantics | per-domain confirmation | runtime measurements |
| qualified Legal/Privacy | backup retention/re-deletion/holds and incident duties | attributable legal verdict | any unresolved jurisdictional conclusion |

The Product owner may coordinate and accept a product boundary but cannot
impersonate these specialists.

## 7. Fail-closed defaults

- Missing SLO ownership: no production service-class claim.
- Missing current cost evidence: no irreversible resource commitment.
- Missing recovery verdict/drill: no recoverability claim or production gate.
- Missing OD-09 alignment: no asynchronous effects/workers.
- Missing incident routes/tabletop result: no production incident-readiness
  claim.
- Missing or stale exact hash: affected verdict becomes Inconclusive.

## 8. Review record requirements

Each verdict must record reviewer identity/role, exact target/hash, scope,
findings, disposition, retained evidence, date and independence/qualification
claim. A comment such as “approved” without those fields is Inconclusive.

Allowed dispositions:

- `Accept design boundary with retained gates`;
- `Accept with required amendments`;
- `Reject`;
- `Inconclusive`.

## 9. Reconciliation after verdicts

After attributable verdicts:

1. integrate required amendments into the exact child models;
2. re-freeze changed hashes and obtain affected re-review;
3. update BCK-05 and its coverage matrix atomically;
4. update the D1 ledger and closure matrix;
5. retain OD statuses unless their own complete acceptance contract passes;
6. do not open G1 or R1 through documentation reconciliation.

## 10. Acceptance criteria

1. **BCK05-OPS2-AC-01:** BCK-05 and coverage inputs are exact-hash pinned.
2. **BCK05-OPS2-AC-02:** all six supporting models are exact-hash pinned.
3. **BCK05-OPS2-AC-03:** five decisions remain independently reviewable.
4. **BCK05-OPS2-AC-04:** existing Accepted decisions are not reopened.
5. **BCK05-OPS2-AC-05:** BCK-05 remains Draft.
6. **BCK05-OPS2-AC-06:** OD-03 remains Proposed without executable evidence.
7. **BCK05-OPS2-AC-07:** OD-04 remains Proposed without current Finance evidence.
8. **BCK05-OPS2-AC-08:** OD-05 remains Proposed without drill/privacy evidence.
9. **BCK05-OPS2-AC-09:** OD-06 remains Open until OD-09 alignment is reviewed.
10. **BCK05-OPS2-AC-10:** OD-08 remains Proposed without executed tabletop evidence.
11. **BCK05-OPS2-AC-11:** pre-G1 design and post-R1 proof are separated.
12. **BCK05-OPS2-AC-12:** no circular cloud prerequisite is introduced.
13. **BCK05-OPS2-AC-13:** Product coordination is not specialist evidence.
14. **BCK05-OPS2-AC-14:** Finance evidence distinguishes EUR, tax and provider scope.
15. **BCK05-OPS2-AC-15:** recovery evidence covers re-deletion and holds.
16. **BCK05-OPS2-AC-16:** restore/PITR claims require timed representative proof.
17. **BCK05-OPS2-AC-17:** OD-06 cannot authorize workers or effects.
18. **BCK05-OPS2-AC-18:** OD-08 design cannot be called a passed exercise.
19. **BCK05-OPS2-AC-19:** every verdict identifies reviewer, target, scope and findings.
20. **BCK05-OPS2-AC-20:** missing/stale evidence is Inconclusive.
21. **BCK05-OPS2-AC-21:** amendments trigger exact affected re-review.
22. **BCK05-OPS2-AC-22:** status reconciliation is atomic.
23. **BCK05-OPS2-AC-23:** Latvia-first does not activate Estonia or Lithuania.
24. **BCK05-OPS2-AC-24:** R0 and RAW-C remain bounded historical evidence.
25. **BCK05-OPS2-AC-25:** G1 remains a separate decision.
26. **BCK05-OPS2-AC-26:** R1 requires separate explicit authorization.
27. **BCK05-OPS2-AC-27:** no production-readiness claim is created.
28. **BCK05-OPS2-AC-28:** no schema, credentials or cloud resource is created.
29. **BCK05-OPS2-AC-29:** no runtime, Firebase or deployment is authorized.
30. **BCK05-OPS2-AC-30:** push and merge remain unauthorized.

## 11. Current disposition

The package is prepared. All five verdicts and every specialist lane remain
Pending; BCK-05 remains Draft and D1/G1/R1 remain blocked.
