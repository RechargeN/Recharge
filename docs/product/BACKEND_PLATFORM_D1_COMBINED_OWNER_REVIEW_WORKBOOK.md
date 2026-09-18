# Recharge Backend — D1 Combined Owner Review Workbook

- Workbook ID: **BCK-D1-OWN-REV-01**
- Version: **1.26**
- Date: **2026-09-17**
- Status: **Technical owner verdicts recorded; remaining D1 verdicts required**
- Assigned owner: **RechargeN / Product owner**
- Independence: **combined-role self-review; no independent reviewer**
- Legal qualification: **not evidenced**
- Runtime status: **Local R0 tooling and disabled Emulator-only RAW-C source Present; product/cloud runtime Absent**
- Parent review package: [BCK-D1-REV-01 v1.30](BACKEND_PLATFORM_D1_REVIEW_EVIDENCE_PACKAGE.md)
- Sign-off ledger: [BCK-D1-SIG-01 v1.28](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md)
- Recorded Batch A decision: [BCK-D1-OWN-A-DEC-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_A_DECISION.md)
- Recorded Operations decision: [BCK03-OPS-DEC-01 v0.1](BACKEND_API_OPERATIONS_OWNER_DECISION.md)
- Recorded Security/Privacy decision: [BCK03-SEC-DEC-01 v0.1](BACKEND_API_SECURITY_PRIVACY_OWNER_DECISION.md)
- Recorded BCK-04 technical decision: [BCK04-SEC-DEC-01 v0.1](BACKEND_SECURITY_PRIVACY_OWNER_DECISION.md)
- Recorded threat-model technical decision: [BCK04-OD01-DEC-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_OWNER_DECISION.md)
- Recorded BCK-20 technical decision: [BCK20-OWN-DEC-01 v0.1](REFERENCE_DATA_LOCALIZATION_OWNER_DECISION.md)
- Recorded translation-governance decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- Recorded Product/Content pre-review decision: [BCK20-OD02-PC-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW_DECISION.md)
- Recorded Product/Content combined-owner decision: [BCK20-OD02-PC-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md)
- Recorded Mobile/Security pre-review decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Recorded exact-v0.4 combined-owner decision: [BCK20-OD02-V04-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_V04_COMBINED_OWNER_DECISION.md)
- Recorded source-authority decision: [BCK20-OD02-SRC-AUTH-DEC-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_OWNER_DECISION.md)
- Recorded source-record decision: [BCK20-OD02-SRC-REC-DEC-01 v0.1](REFERENCE_DATA_SOURCE_RECORDS_OWNER_DECISION.md)
- Recorded external-evidence plan decision: [BCK20-OD02-EXT-EV-PLAN-DEC-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_OWNER_DECISION.md)
- Recorded Mobile decision: [BCK03-MOB-DEC-01 v0.1](BACKEND_API_MOBILE_OWNER_DECISION.md)
- Runtime effect: **none**

---

## 0. Owner verdict reconciliation

Version 1.26 records BCK20-OD02-EXT-EV-PLAN-DEC-01. EXT-G0 is satisfied only
for the frozen plan under five combined roles with zero independence.
EXT-G1–G6, all markets, network/external evidence/independent/qualified and
implementation gates remain closed.

Version 1.25 records BCK20-OD02-SRC-REC-DEC-01. Twenty-three internal records
are accepted only as documentation inputs and eight external candidates only
as a work queue under six combined roles with zero independence. All markets,
external/source-copy/independent/qualified and implementation gates remain
closed.

Version 1.24 records BCK20-OD02-SRC-AUTH-DEC-01. The frozen matrix is accepted
only as a source-authority design boundary under six combined roles with zero
independence. Actual source records, external-source license/terms and pinned
ingestion evidence, independent/qualified review and all implementation gates
remain open.

Version 1.12 records the explicit 2026-09-08 Owner Batch A verdict. It closes
only the combined-owner BCK-03/API disposition: D1-SIG-API is Accepted with
required amendments, the broader API-DEC-01–05 scopes are Deferred, and OD-09
remains Proposed. Existing Booking-v1 API-DEC-01/03 Acceptance is preserved.
Every other Pending or Inconclusive row and the missing qualified
Legal/Privacy evidence remain unchanged.

Version 1.13 records the bounded D1-SIG-OPS verdict from
BCK03-OPS-DEC-01. It applies only to the BCK-03 operational boundary;
independent Operations evidence and all BCK-05/runtime gates remain open.

Version 1.14 records the bounded D1-SIG-SEC verdict from
BCK03-SEC-DEC-01. It applies only to the BCK-03 Security/Privacy boundary;
BCK-04, independent Security/Privacy, qualified Legal and runtime gates remain
open.

Version 1.15 records the bounded D1-SIG-MOBILE verdict from
BCK03-MOB-DEC-01. It applies only to the BCK-03 Mobile boundary; BCK-18,
BCK-20, independent Mobile and runtime gates remain open.

Version 1.16 records BCK04-SEC-DEC-01 for the combined-owner technical BCK-04
boundary and its fourteen amendments. It does not accept BCK-04,
BCK04-OD-01/09, OD-11 or replace independent Security/Privacy and qualified
Legal evidence.

Version 1.17 records BCK04-OD01-DEC-01 for the combined-owner technical
threat-model boundary. It keeps OD-01 Proposed pending independent and
cross-boundary evidence.

Version 1.18 records BCK20-OWN-DEC-01 for the combined-owner technical BCK-20
decision triage. BCK-20 remains Draft, OD-10 remains Proposed,
BCK20-OD-02/05 remain Open and specialist/Legal/runtime gates remain intact.

Version 1.19 records BCK20-OD02-DEC-01 and amended workflow v0.2 for the
combined-owner technical boundary only. OD-02 remains Open and no specialist,
Legal, schema or runtime authority is inferred.

Version 1.20 records BCK20-OD02-PC-PRE-DEC-01 and F-001–F-008 integration in
workflow v0.3. It re-freezes specialist review without supplying either
specialist verdict or changing OD-02, OD-10, BCK-20 or runtime status.

Version 1.21 records two separate effective Product Localization and Content
combined-owner verdicts through BCK20-OD02-PC-COMB-DEC-01. The shared owner and
zero independence are explicit; all remaining OD/Legal/runtime gates persist.

Version 1.22 records BCK20-OD02-MS-PRE-DEC-01 and workflow v0.4. It integrates
seven documentation corrections, keeps the v0.3 Product/Content verdicts as
historical exact-hash evidence and leaves v0.4 Product/Content/Mobile/Security
verdicts Pending. No implementation gate changes.

Version 1.23 records BCK20-OD02-V04-COMB-DEC-01 and four separately
attributable exact-v0.4 design verdicts under one owner with zero independence.
Source-authority, independent Security/Privacy, qualified Legal, OD and
runtime gates remain open.

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
| Operations | environment/release/rollback structure, bounded R0 evidence, accepted BCK05-OD-01 baseline and numerical SLO, cost and recovery proposals are documented | remaining OD/specialist verdicts, representative stage/restore evidence and executable controls |
| Languages/reference data | LV-first, EE/LT isolation and fallback model are documented | approved locale tables, mandatory legal-copy matrix and distribution choices |
| Physical backend | target structure exists on paper | all server code, cloud resources, deployment and runtime evidence |

D1 is not complete. This workbook is a decision aid, not evidence that the
backend exists.

## 3. Decision batch A — owner can decide now

These recommendations preserve every runtime gate. Accepting them does not
create an endpoint, schema, project or database.

| Decision | Recommended owner verdict | Reason | Preserved gate |
|---|---|---|---|
| `API-DEC-01` — exact callable/HTTPS mapping and deadlines | **Deferred outside Accepted Booking v1** to executable API scaffold | the Booking-v1 choice remains Accepted; a general mapping before scaffold/load evidence would be false precision | no general endpoint until G1 and a separate Approved executable slice |
| `API-DEC-02` — generator versus fixture-verified consumers | **Deferred** to codegen/tooling slice | Booking fixtures work today; no new generator is justified yet | no generator/tooling until separate Approval |
| `API-DEC-03` — canonical request-hash algorithm/version | **Deferred outside Accepted Booking v1** to the applicable mutation-contract slice | the Booking-v1 algorithm remains Accepted; broader adoption requires exact implementation/parity tests | no non-Booking mutation runtime until Accepted decision |
| `API-DEC-04` — minimum-client bootstrap/offline behavior | **Deferred** to production client-gate slice | it requires actual client/config integration evidence | no production client enforcement until Accepted decision |
| `API-DEC-05` — language-neutral schemas beyond Booking | **Deferred** to a new architecture decision | current authority covers Booking only | no platform/non-Booking schema creation |
| `OD-09` — event/outbox delivery | **Retain Proposed** | D1 minimum is met; exact transport/retry/quarantine evidence belongs before effects | no worker/effect until OD-09 Accepted and D3 Approved |
| BCK-03 contract semantics | **Accept with required amendments** | semantic core is coherent; deferred decisions and later parity must remain visible | BCK-03 stays Draft until the recorded review verdict is applied |

Recommended review date for all deferred Batch A items: the start of the named
blocking slice, or **2026-11-20**, whichever occurs first. A deferred decision
that reaches its gate unresolved fails closed.

### 3.1 Recorded owner response

The Product owner selected `Accept Batch A exactly as recommended` on
2026-09-08. The immutable scope and controls are recorded in
[BCK-D1-OWN-A-DEC-01](BACKEND_PLATFORM_D1_OWNER_BATCH_A_DECISION.md). This does
not convert any other recommendation into a verdict.

## 4. Decision batch B — technical evidence to prepare next

These items are not owner-preference questions. They need concrete tables,
models or review evidence before an effective verdict.

| Work item | Decisions served | What must be produced | Current recommendation |
|---|---|---|---|
| Full backend threat model | `BCK04-OD-01` | [BCK04-OD01-TM-01 v0.2](BACKEND_SECURITY_THREAT_MODEL.md) provides stable assets/actors/boundaries, 49 classified threats, per-threat owners/gates/residual states and checksum | **Combined-owner technical verdict recorded; OD-01 Proposed pending independent/cross-boundary evidence** |
| Incident risk/severity model | `BCK04-OD-09`, `BCK05-OD-08` | [BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) defines the response model; [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) supplies Scenario A, injects, evaluator key and blank result record | **Package ready/not executed; both decisions Proposed; owner/Legal verdict and completed result pending** |
| Infrastructure choice record | `OD-07` | [evidence v0.6](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md) completes the resource matrix, dated vendor facts, latency/cost thresholds, residency limits and export/rollback plan; [OD07-DEC-01 v0.2](BACKEND_OD_07_INFRASTRUCTURE_OWNER_DECISION.md) records the exact verdict | **Accepted at `OD07-A1-EU-MR-v1` with controls; no cloud or Legal authority** |
| Service targets | `BCK05-OD-03` | [BCK05-OD03-SLO-01](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) now supplies journey SLIs/SLOs, error budgets, burn alerts and release rules | **Product baseline recorded; OD-03 Proposed; domain/Operations specialist verdict and stage evidence pending** |
| Recovery targets | `BCK05-OD-05` | [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) now supplies record-family RPO/RTO, protection, isolated restore, privacy reconciliation and drills | **Product baseline recorded; OD-05 Proposed; Platform/Privacy/domain verdict and restore evidence pending** |
| Cost containment | `BCK05-OD-04` | [BCK05-OD04-COST-01](BACKEND_INFRASTRUCTURE_COST_MODEL.md) now supplies five envelopes, formulas, directional estimates, EUR alert levels and safe containment actions | **Product baseline recorded; OD-04 Proposed; Finance Inconclusive; Operations/EUR SKU/stage evidence pending** |
| Numeric cross-model review | `BCK05-OD-03/04/05` | [BCK05-NUM-REV-01 v0.2](BACKEND_OPERATIONS_NUMERIC_OWNER_REVIEW.md) reconciles exact SLO v0.1, cost v0.2 and recovery v0.1, including the backup-cost correction and bounded verdict | **Product baseline accepted for stage validation; Operations/Security require evidence; Finance/Legal Inconclusive; no status promotion** |
| Runtime, identity and deployment controls | `BCK05-OD-01`, `BCK05-OD-02`, `BCK05-OD-07` | Toolchain status record v0.3.4, technical review v0.2.4, R0 v0.2.2/result, BCK05-OD-01 decision v0.2, IAM model v0.2.1, BCK05-OD-02 decision v0.2, release model v0.2.1 and BCK05-OD-07 release decision v0.2 | **BCK05-OD-01/02/07 Accepted with controls; executable release/IAM/cloud/runtime evidence remains absent** |
| Localization decision record | `OD-10`, `BCK20-OD-01`–`07` | BCK20-OWN-DEC-01 defers 01/03/04/06/07; BCK20-OD02-DEC-01 records amended technical workflow v0.2 | keep BCK-20 Draft, OD-10 Proposed and OD-02/05 Open; obtain named specialist review next |

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

### 4.2 Recorded runtime/toolchain disposition

On 2026-08-24 the Product owner gave the exact
`BCK05-OD01-DEC-01 v0.2` verdict accepting `BCK05-OD-01` baseline v0.3.3
with controls. `TCH-OD-01..05` are Accepted; `TCH-OD-06..08` remain deferred.
The decision does not complete D1-SIG-OPS/SEC, accept BCK-05, pass G1 or
authorize R1. A fresh dependency audit and reachable-path review are mandatory
before R1 because the bounded R0 advisory exception does not propagate.

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
- `OD-07` engineering topology is Accepted with controls; qualified
  Legal/Privacy conclusions and `OD-10` remain unresolved;
- BCK-04 cannot be Approved;
- affected production processing and market activation remain disabled.

## 6. Role-by-role recommended verdicts

These are recommendations for the assigned owner, not signatures.

| Sign-off ID | Recommended verdict now | Blocking amendment/evidence |
|---|---|---|
| `D1-SIG-API` | **Recorded: Accept with required amendments** | broader API-DEC-01–05 scopes Deferred; preserve Accepted Booking-v1 API-DEC-01/03 and independent boundary gates |
| `D1-SIG-OPS` | **Recorded for BCK-03 boundary: Accept with required amendments** | preserve/revalidate OD-07; BCK-05, stage/restore/deployment and independent Operations evidence remain incomplete |
| `D1-SIG-SEC` | **Recorded for combined-owner technical BCK-03/BCK-04 boundaries: Accept with required amendments** | independent review, Proposed threat/incident decisions, tabletop and qualified Legal boundaries remain incomplete |
| `D1-SIG-LEGAL` | Inconclusive | qualified Legal/Privacy evidence absent |
| `D1-SIG-REF` | Accept with required amendments | complete OD-10 and reference distribution/deprecation decisions |
| `D1-SIG-L10N` | Accept with required amendments | translation source/review workflow and exact locale policies |
| `D1-SIG-MOBILE` | **Recorded for BCK-03 boundary: Accept with required amendments** | BCK-18/BCK-20 Approval, independent Mobile evidence and runtime remain incomplete |
| `D1-SIG-CONTENT` | Accept with required amendments | source-language/readiness behavior plus mandatory Legal-copy matrix |
| `D1-SIG-FIN` | Inconclusive | cost proposal is Present, but Finance verdict, EUR SKU/tax treatment and measured reconciliation are absent |
| `D1-SIG-BOOK` | Accept for D1 semantic boundary only | executable transaction/outbox parity remains later |
| `D1-SIG-NOTIF` | Accept for D1 boundary only | consumer/delivery/read runtime design remains later |

No combined verdict may hide the `Inconclusive` Legal or Finance scopes.

## 7. Artifact recommendations

| Artifact | Recommendation | Why it cannot advance further now |
|---|---|---|
| BCK-03 v0.3.14 | API, Operations, Security and Mobile boundary reviews recorded as `Accept with required amendments`; spec remains Draft | Independent evidence remains Pending |
| BCK-04 v0.4.23 | retain Draft | BCK-04 and threat-model combined-owner technical verdicts recorded; `BCK04-OD-01` remains Proposed pending independent/cross-boundary evidence; OD-09/tabletop/Legal gates remain |
| BCK-05 v0.2.30 | retain Draft | BCK05-OD-01/02/07 and cross-domain OD-07 are Accepted and bounded R0 is Pass; owner-boundary verdicts do not accept BCK-05; executable/specialist/stage/product-cloud evidence remains incomplete |
| BCK-20 v0.2.18 | retain Draft | internal inputs and EXT-G0 plan accepted with zero independence; EXT-G1–G6/external/source-copy/independent/Legal evidence incomplete; OD-10 Proposed and OD-02/05 Open |
| OD-07 | retain Accepted with controls | exact `OD07-A1-EU-MR-v1` verdict is recorded; provisioning, qualified production Legal/Privacy and revalidation remain separate gates |
| OD-09 | retain Proposed | sufficient for D1 minimum, insufficient for effects/runtime |
| OD-10 | retain Proposed | exact market/legal-copy/distribution decisions incomplete |
| OD-11 | retain Open | qualified Legal/Privacy policy not supplied |

## 8. Recorded owner confirmation

The following confirmation was supplied explicitly on 2026-09-08 and is
preserved by BCK-D1-OWN-A-DEC-01:

```text
Owner identity: RechargeN / Product owner
Combined-role disclosure: accepted; no independent review
Batch A verdict: accept exactly as recommended
BCK-03 recommendation: accept with required amendments
All other BCK/OD statuses: retain exactly as listed in §7
Legal/Privacy qualification: not claimed
Runtime authorization: none
Date: 2026-09-08
```

This confirmation authorizes only documentation disposition updates. It does
not expand completed R0 or authorize D2, G1, R1, Firebase/cloud resources,
product backend code, credentials or production data processing.

The separate 2026-09-08 BCK03-SEC-DEC-01 confirmation records D1-SIG-SEC only
for the BCK-03 boundary with required amendments. It does not accept BCK-04,
independent Security/Privacy evidence or qualified Legal conclusions.

The separate 2026-09-09 BCK03-MOB-DEC-01 confirmation records D1-SIG-MOBILE
only for the BCK-03 boundary. It does not accept BCK-18/BCK-20, replace
independent Mobile evidence or authorize runtime.

The separate 2026-09-12 BCK04-SEC-DEC-01 confirmation records only the
combined-owner technical BCK-04 boundary with required amendments. It does not
accept BCK-04/BCK04-OD-01/09, replace independent or qualified Legal evidence,
or authorize runtime.

The separate 2026-09-15 BCK04-OD01-DEC-01 confirmation records only the
combined-owner technical threat-model boundary and amended v0.2. BCK04-OD-01
remains Proposed until independent Security/Privacy and required API,
Operations, Identity, Mobile and affected-domain confirmations pass.

The separate 2026-09-16 BCK20-OWN-DEC-01 confirmation records only the
combined-owner technical BCK-20 decision triage. It defers
BCK20-OD-01/03/04/06/07, retains BCK20-OD-02/05 Open and OD-10 Proposed, and
does not accept BCK-20 or supply specialist, Legal or runtime authority.

The same-day BCK20-OD02-DEC-01 confirmation records only the amended technical
translation-governance boundary. It keeps BCK20-OD-02 Open and creates no
Product Localization, Content, Mobile, Security/Privacy or Legal verdict.

## 9. What happens after owner confirmation

1. Keep the recorded Batch A dispositions and D1-SIG-API verdict reconciled in
   BCK-D1-SIG-01 and BCK-03.
2. Preserve the bounded BCK-03, BCK-04, threat-model, BCK-20 triage and
   translation-governance verdicts; obtain named specialist reviews of
   workflow v0.4 next for Mobile and Security/Privacy and revalidate
   Product/Content against the same exact hash. Keep applicable
   qualified Legal review mandatory before its gate.
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
16. **D1-OWN-AC-16:** BCK04-OD01-DEC-01 records only the technical threat-model
    boundary; OD-01 remains Proposed until independent and cross-boundary
    evidence passes.
17. **D1-OWN-AC-17:** BCK20-OWN-DEC-01 records only BCK-20 decision triage;
    OD-10, specialist, Legal and runtime gates remain open.
18. **D1-OWN-AC-18:** BCK20-OD02-DEC-01 records only the amended technical
    workflow and leaves OD-02 and all specialist/Legal/runtime gates open.
19. **D1-OWN-AC-19:** BCK20-OD02-PC-PRE-DEC-01 integrates technical
    corrections only; specialist identities/verdicts and source-authority
    content remain absent.
20. **D1-OWN-AC-20:** BCK20-OD02-PC-COMB-DEC-01 records two separate
    combined-owner verdicts with zero independence and leaves all remaining
    specialist, Legal, source-authority and runtime gates open.
21. **D1-OWN-AC-21:** BCK20-OD02-MS-PRE-DEC-01 integrates seven corrections
    only; it does not itself supply exact-v0.4 owner verdicts, which require a
    separate explicit decision.
22. **D1-OWN-AC-22:** BCK20-OD02-V04-COMB-DEC-01 records four separate
    exact-v0.4 design verdicts with zero independence and leaves full D1,
    source-authority, independent Security/Privacy, qualified Legal and
    implementation gates incomplete.
23. **D1-OWN-AC-23:** BCK20-OD02-SRC-AUTH-DEC-01 accepts only the frozen
    source-authority design boundary; actual source evidence,
    independent/qualified review and implementation gates remain incomplete.
24. **D1-OWN-AC-24:** BCK20-OD02-SRC-REC-DEC-01 accepts internal records only
    as documentation inputs and external candidates only as a work queue; all
    market, evidence, independent/qualified and implementation gates remain closed.
25. **D1-OWN-AC-25:** BCK20-OD02-EXT-EV-PLAN-DEC-01 satisfies EXT-G0 only;
    EXT-G1–G6, market, network/evidence, independent/qualified and
    implementation gates remain closed.
