# Recharge Backend — D1 Platform Review Evidence Package

- Package ID: **BCK-D1-REV-01**
- Version: **1.28**
- Date: **2026-09-17**
- Package status: **Draft review evidence — D1 exit blocked**
- Runtime status: **Local R0 tooling and disabled Emulator-only ECL-03C source Present; product/cloud runtime Absent**
- Coordination owner: **RechargeN / Product owner**
- Required accountable owners: **API Platform, Platform Operations, Security/Privacy, Legal/Privacy, Reference Data, Product Localization, Content and Mobile**
- Accepted decision input: [BCK-D1-DEC-01](BACKEND_PLATFORM_D1_DECISION_PACKAGE.md)
- Owner sign-off ledger: [BCK-D1-SIG-01](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md)
- Combined-owner review workbook: [BCK-D1-OWN-REV-01](BACKEND_PLATFORM_D1_COMBINED_OWNER_REVIEW_WORKBOOK.md)
- Owner Batch A decision: [BCK-D1-OWN-A-DEC-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_A_DECISION.md)
- Operations boundary decision: [BCK03-OPS-DEC-01 v0.1](BACKEND_API_OPERATIONS_OWNER_DECISION.md)
- Security/Privacy boundary decision: [BCK03-SEC-DEC-01 v0.1](BACKEND_API_SECURITY_PRIVACY_OWNER_DECISION.md)
- BCK-04 technical decision: [BCK04-SEC-DEC-01 v0.1](BACKEND_SECURITY_PRIVACY_OWNER_DECISION.md)
- Threat-model technical decision: [BCK04-OD01-DEC-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_OWNER_DECISION.md)
- BCK-20 technical decision: [BCK20-OWN-DEC-01 v0.1](REFERENCE_DATA_LOCALIZATION_OWNER_DECISION.md)
- Translation-governance decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- Product/Content pre-review decision: [BCK20-OD02-PC-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW_DECISION.md)
- Product/Content combined-owner decision: [BCK20-OD02-PC-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md)
- Mobile/Security pre-review decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Exact-v0.4 combined-owner decision: [BCK20-OD02-V04-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_V04_COMBINED_OWNER_DECISION.md)
- Source-authority decision: [BCK20-OD02-SRC-AUTH-DEC-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_OWNER_DECISION.md)
- Mobile boundary decision: [BCK03-MOB-DEC-01 v0.1](BACKEND_API_MOBILE_OWNER_DECISION.md)
- Runtime effect: **none**

---

## 0. Revision notes

### v1.28 — source-authority design-boundary decision

BCK20-OD02-SRC-AUTH-DEC-01 accepts the frozen matrix as a bounded design
authority under six combined roles with zero independence. Actual source
records, external-source license/terms and pinned ingestion evidence,
independent Security/Privacy, qualified Legal, OD and runtime gates remain
open; BCK-20 remains Draft and D1 exit remains blocked.

### v1.27 — exact-v0.4 combined-owner verdicts

BCK20-OD02-V04-COMB-DEC-01 records four separately attributable design
verdicts under one disclosed owner with zero independence. Source-authority,
independent Security/Privacy, qualified Legal, OD and runtime gates remain
open; BCK-20 remains Draft and D1 exit remains blocked.

### v1.26 — translation Mobile/Security pre-review corrections

BCK20-OD02-MS-PRE-DEC-01 integrates MS-F-001–MS-F-007 in workflow v0.4.
Product/Content v0.3 verdicts remain historical exact-hash evidence pending
v0.4 revalidation; separate Mobile and Security/Privacy reviews are Proposed,
not effective. BCK20-OD-02 remains Open, BCK-20 Draft, OD-10 Proposed and
BCK20-OD-03 Deferred; all Legal/schema/runtime gates remain unresolved.

### v1.25 — Product/Content combined-owner verdicts

BCK20-OD02-PC-COMB-DEC-01 records two separate effective Product Localization
and Content verdicts for exact workflow v0.3. The shared owner and zero
independence are explicit; OD-02, OD-10, BCK-20, Mobile, Security/Privacy,
Legal, source-authority and runtime gates remain unchanged.

### v1.24 — translation Product/Content pre-review corrections

BCK20-OD02-PC-PRE-DEC-01 integrates F-001–F-008 in workflow v0.3 and re-freezes
the Product/Content package. BCK20-OD-02 remains Open, BCK-20 Draft and OD-10
Proposed; both specialist signatures and every Legal/schema/runtime gate remain
unresolved.

### v1.23 — translation-governance technical verdict

BCK20-OD02-DEC-01 records the amended combined-owner technical workflow v0.2.
BCK20-OD-02 remains Open, BCK-20 Draft and OD-10 Proposed; specialist, Legal,
schema, runtime and infrastructure gates are unchanged.

### v1.22 — BCK-20 owner decision triage

BCK20-OWN-DEC-01 records the combined-owner technical BCK-20 disposition:
five decisions are Deferred, BCK20-OD-02/05 remain Open, OD-10 remains
Proposed and BCK-20 remains Draft. Specialist/Legal/runtime gates are unchanged.

### v1.21 — BCK04-OD-01 technical threat-model verdict

BCK04-OD01-DEC-01 records the combined-owner technical verdict and integrates
twenty amendments in threat-model v0.2. BCK04-OD-01 remains Proposed;
independent Security/Privacy, cross-boundary confirmations, qualified Legal,
D1/G1 and runtime remain blocked.

### v1.20 — BCK-04 technical owner verdict

BCK04-SEC-DEC-01 records the combined-owner technical BCK-04 verdict and
fourteen amendments. BCK-04 remains Draft; independent Security/Privacy,
qualified Legal, BCK04-OD-01/09, OD-11, D1/G1 and runtime remain blocked.

### v1.19 — BCK-03 Mobile boundary verdict

D1-SIG-MOBILE is recorded as Accept with required amendments for the BCK-03
boundary only. BCK-18/BCK-20 Approval, independent Mobile evidence, D1/G1 and
runtime remain blocked.

### v1.18 — BCK-03 Security/Privacy boundary verdict

D1-SIG-SEC is recorded as Accept with required amendments for the BCK-03
boundary only. BCK-04 owner/independent review, qualified Legal evidence,
D1/G1 and runtime remain blocked.

### v1.17 — BCK-03 Operations boundary verdict

D1-SIG-OPS is recorded as Accept with required amendments for the BCK-03
boundary only. Independent Operations evidence, BCK-05 Approval, stage proof,
D1/G1 and runtime remain blocked.

### v1.16 — Owner Batch A evidence

The Product owner explicitly accepted Batch A on 2026-09-08. BCK-03 receives
an owner review verdict of Accept with required amendments but remains Draft;
the broader API-DEC-01–05 scopes are Deferred, Accepted Booking-v1
API-DEC-01/03 remain intact and OD-09 remains Proposed. All other signatures,
qualified Legal/Privacy evidence, D1/G1 and runtime gates remain unchanged.

### v1.15 — D1-B atomic reconciliation

D1-B reconciles current parent/coordination/runtime anchors across BCK-03/04/05/20,
their coverage matrices and the D1 decision/review/sign-off chain. It preserves
every Draft, Review, Proposed, Open, Pending and Inconclusive status. No runtime,
Firebase, contract, ADR, deployment, push or merge authority is created.

### v1.14 — post-RAW-C D1-A audit

This revision records a documentation-only audit after RAW-C v0.3 hosted
evidence and BCK-01/BCK-02/BCK-02-A1 reconciliation. It changes no Accepted
decision and grants no runtime authority.

- canonical coordination is BCK-02 v2.4.54;
- BCK-01 is Review v0.4.50 and BCK-02-A1 is Draft v1.1;
- BCK-09 v1.13, ECL-03C v1.11 and RAW-C v0.3 are Present in Review with all
  nine independent Booking signatures Pending;
- bounded R0 remains Pass, but G1-G7, R1 and product/cloud runtime remain
  blocked or absent;
- current-version drift in the D1 child documents is now an explicit D1-B
  reconciliation task rather than a silent assumption.

## 1. Verdict

D1 documentation has a coherent review baseline, but D1 is **not complete** and
none of G1–G7 or R1–R12 is opened by this package.

- BCK-01 is in `Review`.
- BCK-03, BCK-04, BCK-05 and BCK-20 remain `Draft`.
- OD-07 is `Accepted` at `OD07-A1-EU-MR-v1` with controls; OD-09 and OD-10
  remain `Proposed`.
- OD-11 remains `Open`.
- BCK-D1-DEC-01 is Accepted and closes only the request/idempotency semantic
  contradiction; it does not close executable parity.
- `apps/backend` contains bounded R0 tooling plus exactly five disabled
  Emulator-only Booking v1 callable exports and nine RAW-C operational
  collections. Firebase cloud resources, deployment, activation, mobile
  integration, credentials and production processing remain absent and
  unauthorized.
- `RechargeN / Product owner` is assigned to all D1 roles through
  BCK-D1-SIG-01 with a combined-role disclosure. The bounded numerical Product
  baseline is recorded, but every broader D1 role sign-off remains incomplete.

The full-SHA runtime/toolchain review, exact R0 plan, formal decisions and
local/hosted execution evidence are Present; bounded R0 is Pass and
`BCK05-OD-01` is Accepted at baseline v0.3.3 with controls. This is not BCK-05
Approval, G1, R1 or cloud/product runtime authorization.

`BCK05-OD02-IAM-01 v0.2.1` records `BCK05-IAM-A1-ENV-WIF-v1` as Accepted with
controls through BCK05-OD02-DEC-01 v0.2. This is architecture policy only; no
GitHub/GCP setting, identity, binding, secret or runtime exists.

`BCK05-OD07-REL-01 v0.2.1` and exact BCK05-OD07-DEC-01 v0.2 record
`BCK05-REL-A1-DUAL-PROV-v1` as Accepted with controls. No release workflow, repository setting,
attestation, artifact, registry, cloud deploy or runtime is authorized.

## 2. D1 entry and exit contract

| Requirement | Required state | Actual state | Verdict |
|---|---|---|---|
| D0 accepted documentation baseline | accepted | BCK-02 canonical coordination baseline exists | Pass |
| BCK-01 first | Review or stronger | Review | Pass |
| BCK-03 API | Approved | Draft | Blocked |
| BCK-04 Security/Privacy | Approved | Draft | Blocked |
| BCK-05 Operations | Approved | Draft | Blocked |
| BCK-20 Reference/Localization | Approved | Draft | Blocked |
| OD-07 topology | Accepted | Accepted with controls | Pass for this D1 requirement; provisioning still blocked |
| OD-10 localization | Accepted | Proposed | Blocked |
| OD-09 event/outbox | at least Proposed for D1; Accepted before effects | Proposed | D1 minimum met; runtime blocked |
| OD-11 minors/age | at least Proposed for D1 | Open | Blocked |
| conflicts logged/reconciled | required | split-key conflict closed; remaining blockers explicit | Pass with blockers |
| runtime authorization | forbidden by D1 docs | bounded R0/RAW-C exist only under separate approvals; this revision creates no runtime | Pass for D1-A; no G1/G4/R1 authority |

## 3. Evidence artifact registry

| Artifact | Purpose | Status | Decision impact |
|---|---|---|---|
| [BCK-D1-DEC-01 v0.14](BACKEND_PLATFORM_D1_DECISION_PACKAGE.md) | request/idempotency, threat-model and BCK-20 reconciliation plus current OD/status ledger | Accepted traceability amendment | BCK-20/OD-02/OD-10 and all runtime gates remain unpromoted |
| [BCK-D1-OWN-A-DEC-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_A_DECISION.md) | bounded API dispositions and BCK-03 owner review verdict | Accepted with controls; documentation only | D1-SIG-API recorded; all peer/independent/runtime gates preserved |
| [BCK03-OPS-REV-01 v0.2](BACKEND_API_OPERATIONS_BOUNDARY_REVIEW.md) + [owner decision v0.1](BACKEND_API_OPERATIONS_OWNER_DECISION.md) | bounded BCK-03 API/Operations seam and required amendments | owner verdict recorded; independent evidence pending | D1-SIG-OPS recorded for BCK-03 only; BCK-05/G1/R1 unchanged |
| [BCK03-SEC-REV-01 v0.2](BACKEND_API_SECURITY_PRIVACY_BOUNDARY_REVIEW.md) + [owner decision v0.1](BACKEND_API_SECURITY_PRIVACY_OWNER_DECISION.md) | bounded BCK-03 Security/Privacy seam and ten required amendments | owner verdict recorded; independent/Legal evidence pending | D1-SIG-SEC recorded for BCK-03 only; BCK-04/G1/R1 unchanged |
| [BCK04-SEC-REV-01 v0.2](BACKEND_SECURITY_PRIVACY_OWNER_REVIEW.md) + [owner decision v0.1](BACKEND_SECURITY_PRIVACY_OWNER_DECISION.md) | technical BCK-04 architecture boundary and fourteen amendments | combined-owner verdict recorded; independent/Legal/OD evidence pending | BCK-04 remains Draft; G1/R1/runtime unchanged |
| [BCK03-MOB-REV-01 v0.2](BACKEND_API_MOBILE_BOUNDARY_REVIEW.md) + [owner decision v0.1](BACKEND_API_MOBILE_OWNER_DECISION.md) | bounded BCK-03 Mobile seam and ten required amendments | owner verdict recorded; independent Mobile evidence pending | D1-SIG-MOBILE recorded for BCK-03 only; BCK-18/BCK-20/G1/R1 unchanged |
| [OD-07 evidence v0.6](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md) + [owner decision v0.2](BACKEND_OD_07_INFRASTRUCTURE_OWNER_DECISION.md) | exact topology/resource matrix, source snapshot, thresholds, residency limits and rollback | exact owner verdict recorded | OD-07 Accepted with controls; no cloud permission |
| [OD-09 evidence](BACKEND_OD_09_EVENT_DELIVERY_EVIDENCE.md) | Booking mapping and failure/recovery matrix | Draft evidence | OD-09 remains Proposed |
| [OD-10 evidence](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md) | deterministic localization fixtures | Draft evidence | OD-10 remains Proposed |
| [BCK20 owner decision](REFERENCE_DATA_LOCALIZATION_OWNER_DECISION.md) | exact decision triage and twelve amendments | Accepted combined-owner technical boundary only | BCK-20 Draft; OD-10 Proposed; specialist/Legal/runtime gates unchanged |
| [BCK20 Product/Content pre-review decision](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW_DECISION.md) | F-001–F-008 technical corrections and specialist re-freeze | Accepted documentation correction boundary only | both specialist signatures Pending; no source-authority or runtime authority |
| [BCK20 Mobile/Security pre-review decision](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md) | MS-F-001–MS-F-007 corrections and exact-v0.4 review re-freeze | Accepted documentation correction boundary only | Product/Content revalidation and Mobile/Security verdicts Pending; no runtime authority |
| [BCK20 Product/Content combined-owner decision](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md) | two separate exact-hash L10N/Content verdicts | Accepted combined-owner boundary; no independence | OD-02 and remaining Mobile/Security/Privacy/Legal/runtime gates unchanged |
| [OD-11 legal brief](BACKEND_OD_11_AGE_POLICY_LEGAL_BRIEF.md) | legal facts versus product decisions | Draft legal brief | OD-11 remains Open |
| [Owner sign-off ledger](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md) | bounded assignments, verdicts and signatures | Draft v1.26; source-authority design decision recorded; D1 sign-offs incomplete | no D1 status promotion |
| [Combined-owner workbook](BACKEND_PLATFORM_D1_COMBINED_OWNER_REVIEW_WORKBOOK.md) | plain-language decision batches and recorded/recommended verdicts | v1.21; Product/Content verdicts recorded | other owner/specialist responses still required |
| [Full threat model](BACKEND_SECURITY_THREAT_MODEL.md) | stable assets/actors/boundaries, 49 classified threats, per-threat owners/gates/residual states and checksum | Draft v0.2; combined-owner technical verdict Present; BCK04-OD-01 Proposed | independent Security/Privacy and cross-boundary confirmations pending |
| [Incident-response model](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) | SEV-1/2/3, privacy-risk assessment, roles, timing, notification and exercise contract | Draft evidence; BCK04-OD-09/BCK05-OD-08 Proposed | owner/Legal verdict, executable routes and completed tabletop pending |
| [Incident tabletop package](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) | Scenario A, optional rotations, injects, evaluator key, finding/result templates and 30 AC | Ready v0.1; explicitly not executed | participants, execution, result, owner/Legal verdict and runtime proof pending |
| [Infrastructure/cost model](BACKEND_INFRASTRUCTURE_COST_MODEL.md) | dated prices, five workload envelopes, corrected backup-retention estimates, EUR budgets/containment and 40 AC | Draft v0.4; OD-07 Accepted, BCK05-OD-04 Proposed | Finance Inconclusive; Operations/EUR SKU/measured stage evidence pending |
| [Service reliability/SLO model](BACKEND_SERVICE_RELIABILITY_SLO_MODEL.md) | journey-scoped SLIs/SLOs, error budgets, zero-tolerance invariants, burn alerts and 40 AC | Draft evidence; Product baseline recorded; BCK05-OD-03 Proposed | domain/Operations specialist verdict, stage telemetry and executable alert evidence pending |
| [Backup/recovery model](BACKEND_BACKUP_RECOVERY_MODEL.md) | record-family RPO/RTO, candidate protection, isolated restore, privacy re-deletion, drills and 40 AC | Draft evidence; Product baseline recorded; BCK05-OD-05 Proposed | Platform/Privacy/domain verdict, representative restore and executable protection evidence pending |
| [Operations numeric owner review](BACKEND_OPERATIONS_NUMERIC_OWNER_REVIEW.md) | exact-version cross-model audit, ten findings, corrected cost and bounded verdict | v0.2; bounded Product-owner disposition recorded | OD-03/04/05 remain Proposed; no runtime authority |
| [Runtime/toolchain standard](BACKEND_RUNTIME_TOOLCHAIN_STANDARD.md) | dated Node.js 22, exact SDK/JDK/lint plus three full-SHA Actions, signed Terraform archives and 56 AC | v0.3.4; BCK05-OD-01 Accepted at baseline v0.3.3; bounded R0 Pass | fresh audit/reachability evidence required before R1 |
| [Runtime/toolchain technical review](BACKEND_RUNTIME_TOOLCHAIN_TECHNICAL_REVIEW.md) | findings, exact minimal package/supply-chain recommendation and 48 AC | v0.2.4; completed bounded technical review | separate owner verdict recorded |
| [R0 toolchain/emulator slice](BACKEND_R0_TOOLCHAIN_EMULATOR_SLICE_SPEC.md) | exhaustive local-only file map, commands, CI, evidence, rollback and 60 AC | v0.2.2; Pass — bounded tooling feasibility only | no G1/R1/cloud authorization |
| [R0 approval decision record](BACKEND_R0_APPROVAL_DECISION_RECORD.md) | execution approval, immutable supply-chain controls and advisory disposition | v0.2; bounded decisions Accepted | product/cloud scope explicitly excluded |
| [BCK05-OD-01 owner decision](BACKEND_RUNTIME_TOOLCHAIN_OWNER_DECISION.md) | exact toolchain disposition and preserved R1/G1 gates | Accepted v0.2 | BCK05-OD-01 closed; BCK-05/G1/R1 unchanged |
| [IAM/workload identity model](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md) and [owner decision](BACKEND_IAM_WORKLOAD_IDENTITY_OWNER_DECISION.md) | exact OIDC/WIF topology/claims, identity catalogue, least privilege, approvals, lifecycle, break-glass and 60 AC | model v0.2.1 and decision v0.2 Accepted with controls | executable fixtures/permissions/bindings/JIT/runtime evidence pending; no cloud permission |
| [Release provenance/promotion model](BACKEND_RELEASE_PROVENANCE_PROMOTION_MODEL.md) | separate manifest/plan/receipt/promotion records, dual provenance, immutable storage, Functions boundary, rollback and 65 AC | Accepted v0.2.1 with exact [owner decision v0.2](BACKEND_RELEASE_PROVENANCE_PROMOTION_OWNER_DECISION.md) | executable policy/provider evidence pending |
| [RAW-C disabled adapter v0.3](BACKEND_EVENT_BOOKING_DISABLED_RUNTIME_ADAPTER_SLICE_SPEC.md) | bounded Booking v1 transaction/adapter evidence outside D1 completion | local and hosted technical gates pass; independent verdicts Pending | does not satisfy BCK-03/04/05/20 Approval, G1 or R1 |

Evidence being present is not the same as evidence being accepted. Each packet
contains its own missing proofs and signatures.

## 4. Specification review ledger

### 4.1 BCK-03 — API Platform

Combined-owner technical decision triage is recorded for:

- common envelopes/errors/idempotency/query/version semantics;
- BCK-D1-DEC-01 split request/logical-idempotency identity;
- Booking v1 compatibility boundary;
- OD-09 proposed envelope plus failure/recovery evidence.

Still blocking Approval:

- API Platform accountable verdict/sign-off;
- BCK-04/BCK-05 delegated reviews plus a named Mobile Platform boundary review;
- no BCK-18 file is required before D1 because BCK-18 is a D2 deliverable;
- API-DEC-01–05 in their applicable scopes;
- executable fixture/generator parity where later authorized.

### 4.2 BCK-04 — Security and Privacy

Ready for owner review of:

- AuthN/AuthZ, capability, anti-enumeration and data-class boundaries;
- Accepted Booking product retention baseline versus separate Legal activation;
- OD-07 residency boundary and OD-11 legal-question package.
- full BCK04-OD-01 threat model as a Proposed evidence package.
- BCK04-OD09-IR-01 incident-response model as a Proposed evidence package.
- BCK04-OD09-TTX-01 as a ready-but-unexecuted exercise package.

Still blocking Approval:

- Security/Privacy and Legal/Privacy verdicts; qualified Legal evidence where
  professional legal judgment is required;
- OD-07 Accepted and OD-11 at least Proposed;
- BCK04-OD-01/BCK04-OD-09 owner/security verdicts, qualified Legal review and
  incident tabletop evidence;
- BCK04-OD-06 and applicable ROPA/DPIA/processor/transfer decisions.

### 4.3 BCK-05 — Deployment and Operations

Ready for owner review of:

- environment isolation, release, flags, observability and rollback boundaries;
- OD-07 exact Accepted `OD07-A1-EU-MR-v1` baseline, rejected alternatives,
  evidence checklist, recorded verdict and revalidation contract;
- OD-09 transport ownership boundary;
- BCK05-OD-08 incident-response boundary and exercise contract;
- honest budget-alert, cost, recovery and runtime status.
- BCK05-OD04-COST-01 numerical cost/budget proposal and fail-safe actions.
- BCK05-OD03-SLO-01 numerical reliability/error-budget proposal.
- BCK05-OD05-REC-01 numerical recovery/protection/restore proposal.
- BCK05-NUM-REV-01 exact-version cross-model findings and recorded bounded
  Product-owner disposition.
- BCK05-OD01-TCH-01 v0.3.4 accepted status record for baseline v0.3.3.
- BCK05-OD01-TCH-REV-01 v0.2.4 completed technical review.
- BCK-R0-TCH-01 v0.2.2 bounded tooling Pass and decision record v0.2.
- BCK05-OD01-DEC-01 v0.2 exact Accepted owner decision.
- BCK05-OD02-IAM-01 v0.2.1 exact keyless workload-identity baseline and
  Accepted BCK05-OD02-DEC-01 v0.2 owner verdict.
- BCK05-OD07-REL-01 v0.2.1 Accepted dual-provenance/promotion/rollback
  baseline with an explicit Functions source-deploy limitation and exact
  BCK05-OD07-DEC-01 v0.2 owner evidence.

Still blocking Approval:

- accountable Platform Operations specialist verdict/sign-off beyond the
  bounded Product-owner baseline;
- every remaining BCK-05 decision and specialist verdict;
- owner-approved and stage-measured SLO/RPO/RTO/cost evidence;
- remaining IAM/release decisions and executable stage/provider evidence;
- backup/restore, executable incident routes and tabletop evidence;
- BCK05 open decisions recorded in the specification.

### 4.4 BCK-20 — Reference Data and Localization

Ready for owner review of:

- one Reference Data authority and immutable revision model;
- Category System v1.4.3 identity/28/530 preservation;
- LocalizedText v1 and deterministic LV/EE/LT fixture vectors;
- market-isolated activation and rollback.

The provider-neutral BCK20-OD-02 translation-governance workflow v0.4, its
bounded technical decision and both correction decisions are recorded.
Four exact-v0.4 combined-owner verdicts are recorded and separately
attributable. They do not supply source-authority content, independence,
qualified Legal evidence or full D1 sign-off.

Still blocking Approval:

- accountable Reference Data and Product Localization verdict/sign-off;
- OD-10 Accepted;
- BCK20-OD-02 translation governance and BCK20-OD-05 qualified policy;
- API/Content/Mobile/Legal review of fixtures;
- schema/tooling decision and executable evidence only when separately allowed.

## 5. Required review sequence

1. **API Platform:** review BCK-03 and OD-09; record comments/decision evidence.
2. **Platform Operations:** review BCK-05 and preserve the exact OD-07 verdict;
   revalidate dated vendor facts before any irreversible command,
   models, thresholds and cost/recovery evidence without provisioning resources.
3. **Security/Privacy + Legal/Privacy:** review BCK-04, OD-07 boundary and OD-11;
   keep age-sensitive paths disabled.
4. **Reference Data + Localization + Mobile/Content:** execute paper/fixture
   review for OD-10 and enumerate mandatory Legal locales.
5. **Cross-owner reconciliation:** resolve conflicting requested changes in one
   record; do not fork BCK semantics.
6. **Status update:** only after signatures/evidence, update BCK-01/02, affected
   BCK specs/matrices, reconciliation report and LAUNCH_STATUS atomically.

Reviews may run in parallel after this package, but no reviewer may accept a
decision outside their authority.

## 6. Review response template

Every reviewer records:

```text
Reviewer role:
Named reviewer:
Artifact and version:
Scope reviewed:
Verdict: accept | accept-with-required-amendments | reject | inconclusive
Blocking findings:
Non-blocking findings:
Evidence links:
Decision IDs affected:
Required owner/action/date:
Signature/date:
```

`Inconclusive` is not `Pass`. Product-owner coordination cannot substitute for
specialist sign-off.

## 7. Status transition rules

- `Draft -> Review`: required sections complete, owners assigned, contradictions
  reconciled and evidence package reviewable.
- `Review -> Approved`: DoD and all non-deferrable decisions satisfied with
  accountable-owner sign-off.
- `Open -> Proposed`: one concrete policy/option with evidence and owner exists.
- `Proposed -> Accepted`: selected option, rationale, migration/rollback,
  evidence and accountable signatures exist.
- Runtime `Absent -> Planned/Present`: only by separately Approved executable
  slice; a documentation status never causes this transition.

No bulk “D1 Approved” label may conceal a Draft child specification.

## 8. Known verification evidence

The D1-C final documentation verification recorded:

- Booking contract package: 9/9 passed;
- direct Dart analyzer over mobile lib/test/integration_test: no issues;
- boundary gate: 380 Dart files, 71 known suppressions, zero violations/stale/
  expired suppressions;
- 31 changed Markdown files: local links, fences and AC sequences passed;
- `git diff --check`: passed;
- the full Flutter suite was not rerun for the docs-only D1-C delta; its latest
  known result remains 663 passed and one pre-existing Route golden failed by
  2.52%, so the repository-wide suite is honestly **not green**.

D1-C changes only Markdown. The existing golden failure must not be relabeled
as a D1 pass or silently updated in a backend documentation slice.

The post-RAW-C D1-A audit additionally records:

- stage-0 reconciliation commit `7cc2d51c54a034a78185b6543b90b275b46ff86c`;
- BCK-02 registry checksum remains 22 BCK specifications and 6 runbooks;
- local links in the four stage-0 documents pass with zero broken targets;
- `git diff --check` passed and no mobile/backend runtime file changed;
- current source-version drift listed in §8.2 remains open for D1-B.

## 8.1 Technical pre-review reconciliation

The D1-C technical pass closed the following documentation contradictions
without accepting any owner decision:

| Finding | Resolution |
|---|---|
| D1-TR-01 — BCK-03 depended on the future BCK-18 document | D1 now requires a named Mobile Platform boundary review; BCK-18 remains a D2 artifact. |
| D1-TR-02 — OD-07 required cloud measurements before cloud provisioning was allowed | Pre-Acceptance uses dated published/modelled evidence and thresholds; actual synthetic validation follows separately Approved R1 provisioning and precedes traffic. |
| D1-TR-03 — OD-09 appeared both Open and Proposed | All current D1 records use Proposed — not Accepted. |
| D1-TR-04 — current-version references drifted | BCK-01/02/03/04/05/20 and their matrices are synchronized by D1-C. |
| D1-TR-05 — DoR evidence could be read as satisfied by document presence alone | Current readiness now states the exact evidenced count and missing named assignments. |
| D1-TR-06 — OD-10 paper vectors could be mistaken for executable schema fixtures | Owner-approved documentation results are separated from later API-DEC-05 executable parity. |
| D1-TR-07 — evidence presence could be mistaken for specialist acceptance | BCK-D1-SIG-01 separates assignment, bounded Product disposition, specialist verdict and signature; broader D1 rows remain incomplete. |

### 8.2 Current source reconciliation result

The factual drift identified by v1.14 was corrected by the D1-B docs-only
batch. Current versions below include the later bounded owner-verdict
reconciliations. Historical changelog references remain historical and are not
rewritten.

| Artifact | Reconciled version | Current result |
|---|---|---|
| BCK-03 | v0.3.14 Draft; API/Operations/Security/Mobile boundary reviews Accept with required amendments | broader API-DEC-01–05 scopes Deferred; independent evidence Pending |
| BCK-04 + coverage | v0.4.23 / v0.3.23 Draft | BCK-04/threat-model technical verdicts recorded; OD-01 remains Proposed pending independent/cross-boundary evidence; Legal/OD-09 gates unchanged |
| BCK-05 + coverage | v0.2.30 Draft | current platform/API/Security/Mobile/roadmap anchors and R0/RAW-C boundary recorded; owner-boundary verdicts do not accept BCK-05; R1 blocked |
| BCK-20 + coverage | v0.2.16 Draft | source-authority design boundary accepted; actual sources, external evidence, independent/Legal, OD-02/05, OD-10 and runtime unresolved |
| BCK-01-REV-01 | v1.24 | Review-entry evidence points to BCK-01 v0.4.64/BCK-02 v2.4.68 without implying Approval |
| BCK-D1-DEC-01 | v0.16 Accepted traceability amendment | source-authority design decision recorded; OD/runtime dispositions unchanged |
| BCK-D1-SIG-01 / BCK-D1-OWN-REV-01 | v1.26 / v1.24 | bounded source-authority decision recorded with zero independence; full D1 sign-offs remain incomplete |

The current reconciliation updates the affected specifications, matrices,
review records, BCK-01, BCK-02, BCK-02-A1 and LAUNCH_STATUS atomically. It
modifies no `apps/backend`, mobile, shared contract, Accepted ADR or
Firebase/cloud resource.

The follow-up owner instruction assigns `RechargeN / Product owner` to all
roles. The ledger records the bounded numeric Product baseline separately from
still-incomplete broader D1 sign-offs. The lack of
independent review is disclosed, and qualified Legal/Privacy evidence remains
required where the specifications depend on professional legal judgment.

## 9. Explicitly absent and unauthorized

- product/domain backend modules beyond bounded local R0 and disabled RAW-C;
- deployed Firebase/GCP projects, databases, buckets or Functions, and cloud
  Auth/App Check setup;
- service accounts, credentials, billing/project IDs and production secrets;
- schema/code generation beyond already accepted Booking assets;
- event workers, dispatch, notification delivery or replay tooling;
- localization datasets/distribution/mobile adapters;
- age/guardian/verification schema or provider;
- production data, migration, deployment, traffic or market activation.

## 10. D1 review acceptance criteria

1. **D1-REV-AC-01:** every BCK/OD status matches its actual evidence.
2. **D1-REV-AC-02:** BCK-01 Review is not described as Approved.
3. **D1-REV-AC-03:** BCK-03/04/05/20 remain Draft despite bounded owner
   verdicts until their complete required and independent sign-offs pass.
4. **D1-REV-AC-04:** OD-07 is Accepted with controls while OD-09/10 remain Proposed.
5. **D1-REV-AC-05:** OD-11 remains Open and contains no invented product age.
6. **D1-REV-AC-06:** BCK-D1-DEC-01 scope is not expanded to runtime.
7. **D1-REV-AC-07:** specialist review cannot be replaced by coordination.
8. **D1-REV-AC-08:** evidence presence is distinct from acceptance.
9. **D1-REV-AC-09:** each OD package has owner, evidence, gates and rollback.
10. **D1-REV-AC-10:** Booking compatibility remains explicit.
11. **D1-REV-AC-11:** LV-first does not silently activate EE/LT.
12. **D1-REV-AC-12:** legal consent age is distinct from product eligibility.
13. **D1-REV-AC-13:** D1 exit remains blocked until the full exit contract passes.
14. **D1-REV-AC-14:** G1–G7 and R1–R12 remain closed.
15. **D1-REV-AC-15:** no cloud resource or runtime is created.
16. **D1-REV-AC-16:** verification reports known non-green evidence honestly.
17. **D1-REV-AC-17:** status changes update all canonical registries atomically.
18. **D1-REV-AC-18:** Review comments use the stable template and named owner.
19. **D1-REV-AC-19:** unresolved conflicts fail closed.
20. **D1-REV-AC-20:** the next action is owner review, not implementation.
21. **D1-REV-AC-21:** disabled RAW-C evidence does not satisfy G1, G4 or R1.
22. **D1-REV-AC-22:** `BCK05-OD-*` IDs are never conflated with cross-domain
    `OD-*` IDs.
23. **D1-REV-AC-23:** post-RAW-C current-version drift must block status
    promotion until an atomic reconciliation passes; v1.15 records that pass
    without promoting D1.
24. **D1-REV-AC-24:** D1-A changes only this evidence package and creates no
    runtime, contract, Firebase, deployment, push or merge authority.
25. **D1-REV-AC-25:** D1-B reconciles the exact source chain atomically while
    preserving all unresolved owner, specialist, Legal, Finance and runtime gates.
26. **D1-REV-AC-26:** Owner Batch A records only D1-SIG-API and the named API
    dispositions; it preserves every other signature and runtime gate.
27. **D1-REV-AC-27:** BCK03-OPS-DEC-01 records only the BCK-03 Operations
    boundary verdict and does not approve BCK-05 or runtime.
28. **D1-REV-AC-28:** BCK03-SEC-DEC-01 records only the BCK-03
    Security/Privacy boundary verdict and does not approve BCK-04, Legal or
    runtime.
29. **D1-REV-AC-29:** BCK03-MOB-DEC-01 records only the BCK-03 Mobile boundary
    and does not accept BCK-18/BCK-20 or replace independent Mobile evidence.
30. **D1-REV-AC-30:** BCK04-SEC-DEC-01 records only the combined-owner
    technical BCK-04 boundary and does not satisfy independent, qualified
    Legal, BCK04-OD-01/09, OD-11 or runtime gates.
31. **D1-REV-AC-31:** BCK04-OD01-DEC-01 records only the combined-owner
    technical threat-model boundary; OD-01 remains Proposed pending exact
    independent and cross-boundary evidence.
32. **D1-REV-AC-32:** BCK20-OWN-DEC-01 records only decision triage; BCK-20,
    OD-10, specialist, Legal and executable gates remain unaccepted.
33. **D1-REV-AC-33:** BCK20-OD02-DEC-01 records only the amended technical
    translation-governance boundary and does not close OD-02 or any named
    specialist, Legal, schema or runtime gate.
34. **D1-REV-AC-34:** BCK20-OD02-PC-PRE-DEC-01 records eight documentation
    corrections without supplying specialist, source-authority, Legal,
    schema or runtime authority.
35. **D1-REV-AC-35:** BCK20-OD02-PC-COMB-DEC-01 records two separate
    non-independent Product/Content verdicts without closing OD-02, OD-10,
    BCK-20 or any remaining specialist/Legal/runtime gate.
36. **D1-REV-AC-36:** BCK20-OD02-MS-PRE-DEC-01 integrates seven
    documentation corrections only; it does not itself supply exact-v0.4
    owner verdicts or runtime authority.
37. **D1-REV-AC-37:** BCK20-OD02-V04-COMB-DEC-01 records four separate
    exact-v0.4 design verdicts with zero independence and does not satisfy
    source-authority, independent Security/Privacy, qualified Legal, OD or
    runtime gates.
38. **D1-REV-AC-38:** BCK20-OD02-SRC-AUTH-DEC-01 accepts only the frozen
    source-authority design boundary; actual source records, external evidence,
    independent/qualified review, OD and runtime gates remain incomplete.

## 11. Final statement

Owner Batch A, bounded BCK-03 boundary verdicts and the combined-owner
technical BCK-04, threat-model, BCK-20 triage and translation-governance
verdicts, including four bounded exact-v0.4 perspectives with zero
independence, are recorded against the reconciled post-RAW-C source chain.
BCK04-OD-01 remains Proposed and
BCK-03/BCK-04 remain
Draft because required independent, cross-boundary, qualified Legal and exact
OD evidence is incomplete. Physical product/cloud backend remains blocked.
