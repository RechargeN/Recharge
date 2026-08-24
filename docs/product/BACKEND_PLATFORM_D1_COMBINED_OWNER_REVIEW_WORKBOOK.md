# Recharge Backend — D1 Combined Owner Review Workbook

- Workbook ID: **BCK-D1-OWN-REV-01**
- Version: **1.2**
- Date: **2026-08-23**
- Status: **Draft workbook — bounded numeric baseline recorded; remaining verdicts required**
- Assigned owner: **RechargeN / Product owner**
- Independence: **combined-role self-review; no independent reviewer**
- Legal qualification: **not evidenced**
- Runtime status: **Absent**
- Parent review package: [BCK-D1-REV-01](BACKEND_PLATFORM_D1_REVIEW_EVIDENCE_PACKAGE.md)
- Sign-off ledger: [BCK-D1-SIG-01](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md)
- Runtime effect: **none**

---

## 1. What this workbook does

This file turns the D1 material into bounded owner decisions. It does not sign
anything automatically. A recommendation becomes an owner verdict only after
the owner explicitly accepts the named decision IDs and artifact versions.

The workbook deliberately separates:

1. product/architecture choices the combined owner can make now;
2. technical evidence that can be prepared next;
3. professional Legal/Privacy conclusions that cannot be invented or replaced
   by owner preference;
4. future runtime proof that cannot exist before an Approved executable slice.

## 2. Current plain-language state

| Area | What is ready | What is missing |
|---|---|---|
| API rules | common request/result/error/version rules are coherent | five implementation choices need an explicit disposition |
| Security/privacy | boundaries, threat/incident models and a repeatable tabletop package are documented | named exercise participants, actual execution/result, owner/independent review and qualified legal decisions |
| Operations | environment/release/rollback structure, exact toolchain pre-review/R0 plan and numerical SLO, cost and recovery proposals are documented | explicit R0 Approval/execution, compatibility proof, specialist verdicts, representative stage/restore evidence and executable controls |
| Languages/reference data | LV-first, EE/LT isolation and fallback model are documented | approved locale tables, mandatory legal-copy matrix and distribution choices |
| Physical backend | target structure exists on paper | all server code, cloud resources, deployment and runtime evidence |

D1 is not complete. This workbook is a decision aid, not evidence that the
backend exists.

## 3. Decision batch A — owner can decide now

These recommendations preserve every runtime gate. Accepting them does not
create an endpoint, schema, project or database.

| Decision | Recommended owner verdict | Reason | Preserved gate |
|---|---|---|---|
| `API-DEC-01` — exact callable/HTTPS mapping and deadlines | **Deferred** to executable API scaffold | choosing transport values before the scaffold/load evidence would be false precision | no endpoint until R0/G1 Approved slice |
| `API-DEC-02` — generator versus fixture-verified consumers | **Deferred** to codegen/tooling slice | Booking fixtures work today; no new generator is justified yet | no generator/tooling until separate Approval |
| `API-DEC-03` — canonical request-hash algorithm/version | **Deferred** to first mutation contract slice | algorithm must be fixed with implementation/parity tests | no mutation runtime until Accepted decision |
| `API-DEC-04` — minimum-client bootstrap/offline behavior | **Deferred** to production client-gate slice | it requires actual client/config integration evidence | no production client enforcement until Accepted decision |
| `API-DEC-05` — language-neutral schemas beyond Booking | **Deferred** to a new architecture decision | current authority covers Booking only | no platform/non-Booking schema creation |
| `OD-09` — event/outbox delivery | **Retain Proposed** | D1 minimum is met; exact transport/retry/quarantine evidence belongs before effects | no worker/effect until OD-09 Accepted and D3 Approved |
| BCK-03 contract semantics | **Accept with required amendments** | semantic core is coherent; deferred decisions and later parity must remain visible | BCK-03 stays Draft until the recorded review verdict is applied |

Recommended review date for all deferred Batch A items: the start of the named
blocking slice, or **2026-11-20**, whichever occurs first. A deferred decision
that reaches its gate unresolved fails closed.

### 3.1 Owner response required

Nothing in Batch A is accepted by document presence. The owner must explicitly
record one of:

- `Accept Batch A exactly as recommended`;
- `Accept Batch A with these changes: ...`;
- `Reject Batch A because: ...`.

## 4. Decision batch B — technical evidence to prepare next

These items are not owner-preference questions. They need concrete tables,
models or review evidence before an effective verdict.

| Work item | Decisions served | What must be produced | Current recommendation |
|---|---|---|---|
| Full backend threat model | `BCK04-OD-01` | [BCK04-OD01-TM-01](BACKEND_SECURITY_THREAT_MODEL.md) now provides assets, actors, trust boundaries, 36 threats, controls and residual risks | **Present as Draft; OD-01 Proposed; owner/independent verdict pending** |
| Incident risk/severity model | `BCK04-OD-09`, `BCK05-OD-08` | [BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) defines the response model; [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) supplies Scenario A, injects, evaluator key and blank result record | **Package ready/not executed; both decisions Proposed; owner/Legal verdict and completed result pending** |
| Infrastructure choice record | `OD-07` | completed resource matrix, dated vendor facts, latency/cost models, thresholds, export/rollback plan | keep Option A Proposed until complete |
| Service targets | `BCK05-OD-03` | [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) now supplies journey SLIs/SLOs, error budgets, burn alerts and release rules | **Product baseline recorded; OD-03 Proposed; domain/Operations specialist verdict and stage evidence pending** |
| Recovery targets | `BCK05-OD-05` | [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) now supplies record-family RPO/RTO, protection, isolated restore, privacy reconciliation and drills | **Product baseline recorded; OD-05 Proposed; Platform/Privacy/domain verdict and restore evidence pending** |
| Cost containment | `BCK05-OD-04` | [BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md) now supplies five envelopes, formulas, directional estimates, EUR alert levels and safe containment actions | **Product baseline recorded; OD-04 Proposed; Finance Inconclusive; Operations/EUR SKU/stage evidence pending** |
| Numeric cross-model review | `BCK05-OD-03/04/05` | [BCK05-NUM-REV-01 v0.2](BACKEND_OPERATIONS_NUMERIC_OWNER_REVIEW.md) reconciles exact SLO v0.1, cost v0.2 and recovery v0.1, including the backup-cost correction and bounded verdict | **Product baseline accepted for stage validation; Operations/Security require evidence; Finance/Legal Inconclusive; no status promotion** |
| Runtime, identity and deployment controls | `BCK05-OD-01`, `BCK05-OD-02`, `BCK05-OD-07` | Toolchain v0.3, full-SHA technical review/R0 v0.2 plan, unsigned decision record, IAM and release models define exact candidates and boundaries | **Present as Draft/Review; all R0 verdicts and OD remain Pending/Proposed; no compatibility/specialist/runtime evidence exists** |
| Localization decision record | `OD-10`, `BCK20-OD-01`–`07` | exact LV policy, EE/LT disabled policy, review workflow, distribution/deprecation choices | keep OD-10 Proposed until complete |

The combined owner may approve the completed technical record, but the record
must contain evidence rather than only the owner's preference.

### 4.1 Recorded bounded numerical disposition

On 2026-08-21 the Product owner authorized the exact bounded response in
`BCK05-NUM-REV-01 v0.2`:

- SLO v0.1, Cost v0.2 and Recovery v0.1 are accepted only as stage-validation
  and recovery-drill baselines;
- combined-owner Operations and Security/Privacy dispositions are
  `Accept with required evidence`, without independent specialist sign-off;
- Product/Finance and Legal/Privacy remain `Inconclusive`;
- OD-03/04/05 remain Proposed, BCK-05 remains Draft and runtime remains absent.

This record does not accept Batch A, complete D1-SIG-OPS or authorize an
executable slice.

## 5. Decision batch C — qualified Legal/Privacy input required

The combined owner is assigned for coordination but cannot use this workbook to
claim qualified legal advice.

| Legal area | Decisions blocked | Minimum required output |
|---|---|---|
| processing purposes/legal bases, consent and marketing | `BCK04-OD-06` | Latvia purpose-by-purpose table and explicit EE/LT gaps |
| minors and feature eligibility | `OD-11` | account/Find People/Content/Booking rules separated by market and purpose |
| processor, transfers and records | `BCK04-OD-10`–`13`, part of `OD-07` | ROPA/DPA/subprocessor/transfer conclusion |
| automated decisions/high-risk processing | `BCK04-OD-11`, `BCK04-OD-14` | DPIA trigger and human-review/contest requirements |
| mandatory local legal/safety copy | `BCK20-OD-05`, part of `OD-10` | fallback-forbidden families and required local-language revisions |

Until this input exists:

- `OD-11` remains Open;
- `OD-07` and `OD-10` cannot be Accepted;
- BCK-04 cannot be Approved;
- affected production processing and market activation remain disabled.

## 6. Role-by-role recommended verdicts

These are recommendations for the assigned owner, not signatures.

| Sign-off ID | Recommended verdict now | Blocking amendment/evidence |
|---|---|---|
| `D1-SIG-API` | Accept with required amendments | accept/defer API-DEC-01–05 explicitly; preserve Booking parity gate |
| `D1-SIG-OPS` | Accept with required amendments | review OD-03/04/05 proposals; complete OD-07, stage/restore proof and deployment controls |
| `D1-SIG-SEC` | Accept with required amendments | review the Proposed threat and incident models; run the tabletop and close Legal boundaries |
| `D1-SIG-LEGAL` | Inconclusive | qualified Legal/Privacy evidence absent |
| `D1-SIG-REF` | Accept with required amendments | complete OD-10 and reference distribution/deprecation decisions |
| `D1-SIG-L10N` | Accept with required amendments | translation source/review workflow and exact locale policies |
| `D1-SIG-MOBILE` | Accept | client/domain isolation and future BCK-18 boundary are coherent; runtime remains gated |
| `D1-SIG-CONTENT` | Accept with required amendments | source-language/readiness behavior plus mandatory Legal-copy matrix |
| `D1-SIG-FIN` | Inconclusive | cost proposal is Present, but Finance verdict, EUR SKU/tax treatment and measured reconciliation are absent |
| `D1-SIG-BOOK` | Accept for D1 semantic boundary only | executable transaction/outbox parity remains later |
| `D1-SIG-NOTIF` | Accept for D1 boundary only | consumer/delivery/read runtime design remains later |

No combined verdict may hide the `Inconclusive` Legal or Finance scopes.

## 7. Artifact recommendations

| Artifact | Recommendation | Why it cannot advance further now |
|---|---|---|
| BCK-03 v0.3.3 | owner may record `Accept with required amendments` | Batch A dispositions must be explicitly accepted |
| BCK-04 v0.4.10 | retain Draft | `BCK04-OD-01`/`BCK04-OD-09` are Proposed but unsigned; tabletop is not executed and qualified Legal evidence remains absent |
| BCK-05 v0.2.12 | retain Draft | full-SHA toolchain review/R0 plan/decision record, IAM/release and bounded numerical baselines are recorded, but R0 is not Approved, all listed OD remain Proposed, and compatibility/platform/specialist/runtime evidence remains absent |
| BCK-20 v0.2.2 | retain Draft | OD-10 and Legal/localization workflow evidence incomplete |
| OD-07 | retain Proposed | resource/cost/security/legal decision record incomplete |
| OD-09 | retain Proposed | sufficient for D1 minimum, insufficient for effects/runtime |
| OD-10 | retain Proposed | exact market/legal-copy/distribution decisions incomplete |
| OD-11 | retain Open | qualified Legal/Privacy policy not supplied |

## 8. Exact owner confirmation block

The lowest-risk next confirmation is:

```text
Owner identity: RechargeN / Product owner
Combined-role disclosure: accepted; no independent review
Batch A verdict: accept exactly as recommended
BCK-03 recommendation: accept with required amendments
All other BCK/OD statuses: retain exactly as listed in §7
Legal/Privacy qualification: not claimed
Runtime authorization: none
Date: 2026-08-20
```

This confirmation authorizes only documentation disposition updates. It does
not authorize D2, G1, R0/R1, Firebase, backend code, credentials or production
data processing.

## 9. What happens after owner confirmation

1. Record Batch A dispositions and bounded role verdicts in BCK-D1-SIG-01.
2. Reconcile BCK-03 and its matrices without opening a runtime gate.
3. Use the recorded SLO/cost/recovery baselines to define a separately
   authorized stage-validation slice and collect evidence-based specialist
   verdicts; separately schedule and actually perform BCK04-OD09-TTX-01 with
   named participants, never prefilling an exercise result.
4. Obtain qualified Legal/Privacy input for Batch C.
5. Re-run the D1 exit matrix. D2 remains blocked until every D1 exit requirement
   actually passes.

## 10. Workbook acceptance criteria

1. **D1-OWN-AC-01:** recommendations are not treated as owner verdicts without explicit scoped acceptance.
2. **D1-OWN-AC-02:** combined-role and independence risks are explicit.
3. **D1-OWN-AC-03:** Legal assignment is not described as legal qualification.
4. **D1-OWN-AC-04:** API decisions retain their exact blocking gates.
5. **D1-OWN-AC-05:** Deferred never means bypassed.
6. **D1-OWN-AC-06:** OD-09 Proposed satisfies only the D1 minimum.
7. **D1-OWN-AC-07:** OD-07 Acceptance stays separate from provisioning.
8. **D1-OWN-AC-08:** OD-10 Acceptance stays separate from executable schemas.
9. **D1-OWN-AC-09:** OD-11 remains Open without qualified evidence.
10. **D1-OWN-AC-10:** BCK-04 direct blockers cannot be silently deferred.
11. **D1-OWN-AC-11:** numeric operations values require assumptions/evidence.
12. **D1-OWN-AC-12:** LV-first does not activate EE/LT.
13. **D1-OWN-AC-13:** Booking v1 compatibility remains unchanged.
14. **D1-OWN-AC-14:** status updates remain atomic after an explicit verdict.
15. **D1-OWN-AC-15:** this workbook creates no runtime or cloud resource.
