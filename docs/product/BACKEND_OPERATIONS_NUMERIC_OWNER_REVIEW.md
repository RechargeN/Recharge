# Recharge Backend — Operations Numeric Owner Review

- Review ID: **BCK05-NUM-REV-01**
- Version: **0.2**
- Date: **2026-08-21**
- Status: **Bounded Product-owner disposition recorded — specialist evidence pending**
- Runtime status: **N/A; documentation evidence only**
- Accountable coordinator: **RechargeN / Product owner**
- Required verdict scopes: **Product, Platform Operations, Product/Finance,
  Security/Privacy, Legal/Privacy and affected domain owners**
- Parent: [BCK-05 v0.2.8](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- SLO target: [BCK05-OD03-SLO-01 v0.1](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md)
- Cost target: [BCK05-OD04-COST-01 v0.2](BACKEND_INFRASTRUCTURE_COST_MODEL.md)
- Recovery target: [BCK05-OD05-REC-01 v0.1](BACKEND_BACKUP_RECOVERY_MODEL.md)
- Infrastructure input: [OD-07 evidence v0.4](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md)
- Runtime effect: **none**

---

## 0. Disposition update

### v0.2 — 2026-08-21

The Product owner explicitly authorized proceeding with the bounded response in
§9 after receiving its exact scope. The recorded disposition:

- accepts SLO v0.1, Cost v0.2 and Recovery v0.1 only as baselines for
  non-production stage validation and recovery drills;
- records `Accept with required evidence` for the combined-owner Operations and
  Security/Privacy perspectives, without claiming independent specialist
  review or completed evidence;
- records Product/Finance and Legal/Privacy as `Inconclusive`;
- keeps `BCK05-OD-03`, `BCK05-OD-04` and `BCK05-OD-05` Proposed;
- keeps BCK-05 Draft and grants no runtime, provisioning or production
  authority.

This is an exact-version documentation disposition, not specialist sign-off or
decision Acceptance.

## 1. Verdict first

The three numerical models are **internally reviewable after the amendments
recorded in §4**, but none is ready for `Accepted` status.

Recommended bounded disposition:

- accept the three documents as **stage-validation baselines**;
- retain `BCK05-OD-03`, `BCK05-OD-04` and `BCK05-OD-05` as **Proposed**;
- do not authorize Firebase/GCP provisioning, billing, alerts, backups, PITR,
  restore operations or production traffic;
- require the independent evidence/signatures in §7 before any decision can
  move to Accepted.

Document presence and the v0.1 technical recommendation were not owner
verdicts. The bounded Product-owner disposition is now recorded in §9; its
specialist/evidence limitations remain controlling.

## 2. Exact review scope

| Artifact | Reviewed scope | Explicit exclusion |
|---|---|---|
| BCK05-OD03-SLO-01 v0.1 | journey SLIs/SLOs, denominators, latency/freshness, invariants, burn/release policy | no telemetry, alert or observed compliance exists |
| BCK05-OD04-COST-01 v0.2 | workload/formulas, corrected retention cost, estimates, EUR guardrails, containment | no EUR SKU, invoice, tax or Finance verdict exists |
| BCK05-OD05-REC-01 v0.1 | recovery classes, RPO/RTO, protection, isolation, privacy reconciliation, drills | no backup/PITR/restore/IAM/runbook exists |
| OD-07 evidence v0.4 | topology candidates and location/cost/reliability constraints | topology remains Proposed and no resource exists |
| Booking backend spec | stricter existing SLO/invariant/retention requirements | Booking runtime remains absent |

The review does not reopen accepted Event/Booking product invariants or create a
parallel incident, privacy, domain or cost vocabulary.

## 3. Cross-model invariant map

| Product/operations need | Reliability model | Cost model | Recovery model | Verdict |
|---|---|---|---|---|
| safe Booking authority | 99.9%, p95/p99, zero oversell/duplicate/drift | critical path preserved under spend containment | RC0 1-minute RPO; safe read/cancel <=1 h | aligned; evidence absent |
| Discover honesty | availability and freshness separated; shared query revision | overfetch/index/listener cost tracked | projections rebuilt from authority | aligned |
| cost incident | burn budget independent; degraded mode preserves safe exits | 50/75/90/100% actions | protection not disabled silently | aligned after amendment |
| cold-start latency | measured, never excluded | min instances default zero | not a recovery substitute | stage trade-off required |
| media deletion/recovery | availability/freshness only | retained/soft-deleted bytes measured | explicit per-bucket soft delete; variants rebuildable | aligned after amendment |
| privacy deletion | lost task is zero-tolerance | mandatory privacy path survives containment | re-deletion/restriction before restored access | aligned; Legal evidence absent |
| Baltic expansion | market SLOs remain separate | L3 temporary envelope | representative-scale restore required | aligned; L3 budget risk open |

## 4. Technical findings and amendments

| ID | Severity | Finding | Resolution/state |
|---|---|---|---|
| NUM-REV-F01 | Material | Cost v0.1 assumed four retained backup copies while recovery proposed 14 daily + 12 weekly copies | **Fixed in cost v0.2:** 26 full-size equivalents in prod and seven in stage; estimates recalculated |
| NUM-REV-F02 | Material | L3 cost could appear below its guardrail only because recovery storage was understated | **Fixed:** directional L3 estimate is `$1,338.45` with reserve; exact EUR decision required and no silent RPO/RTO reduction |
| NUM-REV-F03 | Medium | Reliability error budget and monetary budget both used “budget” without an explicit precedence rule | **Fixed:** independent controls; either can block rollout |
| NUM-REV-F04 | Medium | `minInstances=0` cost default can conflict with C1 latency | **Fixed:** stage must compare bounded warm cost/alternatives; no hidden exclusion or silent target weakening |
| NUM-REV-F05 | Medium | Media cost did not explicitly name soft-deleted/noncurrent bytes | **Fixed:** those bytes are required in average stored GiB |
| NUM-REV-F06 | Blocking evidence | RC0 1-minute RPO and <=4-hour full RTO are unproved at representative size | Open until timed stage restore/PITR evidence exists |
| NUM-REV-F07 | Blocking evidence | same-project Firestore backups do not solve project/account compromise | Open OD-07/OD-05 architecture decision; no false solved claim |
| NUM-REV-F08 | Blocking Legal/Privacy | 12-week weekly backup may outlive some live-data retention windows | Open until re-deletion/hold/backup expiry treatment receives qualified review |
| NUM-REV-F09 | Blocking Finance | USD list model is not an EUR invoice and excludes tax/support/external providers | Open until exact EUR SKU/calculator and Finance treatment |
| NUM-REV-F10 | Non-blocking | 28-day SLO and calendar-month spend periods differ | Retained intentionally; reporting correlates both without merging denominators |

No unresolved semantic contradiction remains between the three Draft models.
The open items are evidence/authority gates, not documentation holes.

## 5. Numerical reconciliation after amendments

| Envelope | Cost v0.2 USD +25% reserve | Proposed EUR guardrail | Review interpretation |
|---|---:|---:|---|
| dev | `$2.92` | `€25` | adequate planning headroom; no billing quote |
| stage | `$9.87` | `€75` | room for load/restore drills; measured use required |
| Latvia L1 | `$51.45` | `€150` | candidate headroom for variance/small SKUs; EUR export required |
| Latvia L2 | `$334.29` | `€500` | candidate headroom is narrower; scale and retention measurements required |
| Baltic L3 stress | `$1,338.45` | `€1,000`, emergency `€1,500` | material guardrail-conflict risk after conversion; temporary explicit authorization or equally safe redesign required |

USD and EUR columns are deliberately not subtracted or converted here. The
comparison identifies decision risk, not a forecasted invoice.

## 6. Recommended owner dispositions

| Decision/artifact | Technical recommendation | Status after recommendation | Why not stronger |
|---|---|---|---|
| BCK05-OD03-SLO-01 v0.1 | Accept as stage-validation baseline | OD-03 remains Proposed | no stage telemetry, alert routing, domain/Operations verdict |
| BCK05-OD04-COST-01 v0.2 | Accept with correction F01/F02 incorporated | OD-04 remains Proposed | no EUR SKU, tax/support, Finance/Operations or actual reconciliation |
| BCK05-OD05-REC-01 v0.1 | Accept as recovery-drill baseline | OD-05 remains Proposed | no Legal/Privacy verdict, IAM, representative restore or RPO/RTO proof |
| BCK-05 v0.2.8 | Retain Draft | Draft | OD-07, identity/deploy controls and executable operations still blocked |

“Accept as baseline” means the proposal is stable enough to test. It does not
mean the BCK decision lifecycle reached `Accepted`.

## 7. Evidence and signatures still required

### 7.1 Product/domain

- confirm that C1/C2/C3 targets reflect user impact;
- confirm zero-tolerance Booking/authority/privacy invariants;
- accept safe/full recovery ordering and degraded-mode priorities;
- approve L1 first and independent EE/LT/L3 activation.

### 7.2 Platform Operations

- prove every SLI denominator/reason and alert route in representative stage;
- prove fast/slow burn and error-budget release actions;
- complete PITR/scoped/full restore, rebuild and privacy resurrection drills;
- measure cold start, load, restore throughput, RPO and safe/full RTO;
- sign exact topology/IAM/runbook only after executable authorization.

### 7.3 Product/Finance

- export exact selected-location EUR SKUs/calculator inputs;
- record VAT/tax/support/credits treatment and funding owner;
- reconcile estimate versus stage actual within ±20% or explain variance;
- explicitly decide L3 temporary ceiling/load/retention design.

### 7.4 Security/Privacy and qualified Legal/Privacy

- decide backup/PITR/soft-delete retention and re-deletion lawfulness;
- review processor/location/transfer and same-project compromise risk;
- approve break-glass, restore identity, two-person RC0 cutover and evidence;
- ensure restriction/deletion/legal-hold behavior survives restore.

## 8. Exact owner response contract

An effective response names the exact versions and one verdict per scope:

```text
Owner identity and actual role:
Combined-role/independence disclosure:
Reviewed artifacts: SLO v0.1; Cost v0.2; Recovery v0.1; BCK-05 v0.2.8

Product/domain baseline verdict:
  accept | accept-with-required-amendments | reject | inconclusive
Platform Operations verdict:
  accept | accept-with-required-amendments | reject | inconclusive
Product/Finance verdict:
  accept | accept-with-required-amendments | reject | inconclusive
Security/Privacy verdict:
  accept | accept-with-required-amendments | reject | inconclusive
Legal/Privacy verdict and qualification:
  accept | accept-with-required-amendments | reject | inconclusive

Accepted amendments/evidence limits:
Decision statuses after review:
Runtime authorization: none
Signature and UTC date:
```

One person may return multiple rows only with an explicit actual-role and
independence disclosure. Coordination assignment alone is not a verdict.

## 9. Recorded bounded owner response

The Product owner accepted the following exact bounded response on 2026-08-21:

```text
Product baseline: accept as stage-validation baseline.
Platform Operations: accept with required stage and restore evidence.
Product/Finance: inconclusive pending EUR SKU/tax/stage reconciliation.
Security/Privacy: accept with required IAM/privacy-resurrection evidence.
Legal/Privacy: inconclusive pending qualified review.
OD-03/04/05: remain Proposed.
BCK-05: remain Draft.
Runtime authorization: none.
```

Interpretation and limits:

- `Product baseline` is the only product-level baseline acceptance;
- Operations and Security/Privacy rows are combined-owner dispositions with
  required evidence, not independent specialist signatures;
- Finance and Legal remain Inconclusive and cannot be treated as Pass;
- no OD/BCK status is promoted and no executable slice is authorized.

## 10. Exit sequence

```text
recorded exact-version bounded owner response
  -> ledger records bounded verdicts
  -> separately Approved non-production executable slice
  -> stage SLI/load/cost/restore evidence
  -> amendments and exact-version re-review
  -> OD-03/04/05 may become Accepted independently
  -> BCK-05 Approval only when all non-deferrable blockers pass
  -> production remains separately gated
```

Failure of one decision does not silently accept or reject the other two.

## 11. Acceptance criteria

1. **BCK05-NUM-REV-AC-01:** exact artifact versions define review scope.
2. **BCK05-NUM-REV-AC-02:** technical recommendation is not owner verdict.
3. **BCK05-NUM-REV-AC-03:** baseline acceptance is not decision Acceptance.
4. **BCK05-NUM-REV-AC-04:** SLO, spend and recovery controls stay distinct.
5. **BCK05-NUM-REV-AC-05:** stricter domain invariants are preserved.
6. **BCK05-NUM-REV-AC-06:** backup-copy cost mismatch is corrected openly.
7. **BCK05-NUM-REV-AC-07:** full-size-equivalent assumption is conservative.
8. **BCK05-NUM-REV-AC-08:** USD estimates are not converted into EUR invoices.
9. **BCK05-NUM-REV-AC-09:** L3 conflict requires an explicit decision.
10. **BCK05-NUM-REV-AC-10:** cost pressure cannot silently weaken RPO/RTO.
11. **BCK05-NUM-REV-AC-11:** latency pressure cannot silently raise spend.
12. **BCK05-NUM-REV-AC-12:** min-instance trade-off requires stage evidence.
13. **BCK05-NUM-REV-AC-13:** soft-deleted/noncurrent media remains cost-visible.
14. **BCK05-NUM-REV-AC-14:** RC0 targets remain unproved until a timed drill.
15. **BCK05-NUM-REV-AC-15:** same-project compromise remains explicit.
16. **BCK05-NUM-REV-AC-16:** backup retention requires Privacy/Legal review.
17. **BCK05-NUM-REV-AC-17:** Finance requires exact EUR/tax/support evidence.
18. **BCK05-NUM-REV-AC-18:** 28-day reliability and monthly spend are correlated, not merged.
19. **BCK05-NUM-REV-AC-19:** every verdict names actual role and evidence limit.
20. **BCK05-NUM-REV-AC-20:** combined roles disclose independence risk.
21. **BCK05-NUM-REV-AC-21:** inconclusive is never Pass.
22. **BCK05-NUM-REV-AC-22:** OD-03/04/05 may advance independently.
23. **BCK05-NUM-REV-AC-23:** no bulk BCK-05 acceptance hides one blocker.
24. **BCK05-NUM-REV-AC-24:** stage evidence follows separate authorization.
25. **BCK05-NUM-REV-AC-25:** stage evidence is not production evidence.
26. **BCK05-NUM-REV-AC-26:** timed-out/skipped/manual proof is inconclusive.
27. **BCK05-NUM-REV-AC-27:** status changes update canonical records atomically.
28. **BCK05-NUM-REV-AC-28:** a verdict is recorded only from explicit owner instruction and with its exact scope.
29. **BCK05-NUM-REV-AC-29:** BCK-05 remains Draft after this review.
30. **BCK05-NUM-REV-AC-30:** this package creates no runtime/cloud/billing resource.
