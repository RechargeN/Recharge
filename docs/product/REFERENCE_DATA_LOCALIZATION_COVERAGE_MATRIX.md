# BCK-20 — Reference Data & Localization Coverage Matrix

- ID: **BCK-20-PRE**
- Version: **0.2.21**
- Date: **2026-09-19**
- Status: **Draft — preparatory audit artifact**
- Runtime status: **N/A; no runtime authority**
- Accountable owner: **Reference Data owner**
- Target: [BCK-20 v0.2.21](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Coordination baseline: [BCK-02](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Owner decision: [BCK20-OWN-DEC-01 v0.1](REFERENCE_DATA_LOCALIZATION_OWNER_DECISION.md)
- Translation decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- Pre-review decision: [BCK20-OD02-PC-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW_DECISION.md)
- Combined-owner decision: [BCK20-OD02-PC-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md)
- Mobile/Security pre-review decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Exact-v0.4 combined-owner decision: [BCK20-OD02-V04-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_V04_COMBINED_OWNER_DECISION.md)
- Source-authority decision: [BCK20-OD02-SRC-AUTH-DEC-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_OWNER_DECISION.md)
- Source-record decision: [BCK20-OD02-SRC-REC-DEC-01 v0.1](REFERENCE_DATA_SOURCE_RECORDS_OWNER_DECISION.md)
- External-evidence plan decision: [BCK20-OD02-EXT-EV-PLAN-DEC-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_OWNER_DECISION.md)
- EXT-A–D technical baseline decision: [BCK20-OD02-EXT-AD-SRC-TERMS-DEC-01 v0.1](REFERENCE_DATA_EXT_A_D_SOURCE_TERMS_OWNER_DECISION.md)
- Qualified terms/access review package: [BCK20-OD02-EXT-AD-TERMS-ACCESS-REV-01 v0.1](REFERENCE_DATA_EXT_A_D_QUALIFIED_TERMS_ACCESS_REVIEW.md)
- OD-10 documentation decision: [OD10-DOC-DEC-01 v0.1](BACKEND_OD_10_LOCALIZATION_OWNER_DECISION.md)
- D1 Owner Batch B review: [BCK-D1-OWN-B-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_B_REVIEW_PACKAGE.md)
- Canonical path: `docs/product/REFERENCE_DATA_LOCALIZATION_COVERAGE_MATRIX.md`

## 0. Owner-decision reconciliation

Current anchors are BCK-01, BCK-02, BCK-03 v0.3.14, BCK-04 v0.4.23,
BCK-05 v0.2.30, BCK-20 v0.2.21 and BCK-02-A1.
BCK20-OWN-DEC-01 records the combined-owner technical decision triage:
BCK20-OD-01/03/04/06/07 are Deferred, BCK20-OD-02/05 remain Open, OD-10
remains Proposed and every specialist verdict remains unresolved.
BCK20-OD02-DEC-01 additionally records the amended technical translation-
governance boundary without closing OD-02. BCK20-OD02-PC-PRE-DEC-01 records
eight technical corrections. BCK20-OD02-PC-COMB-DEC-01 records two historical
exact-v0.3 Product/Content verdicts without independence.
BCK20-OD02-MS-PRE-DEC-01 integrates seven Mobile/Security corrections in
workflow v0.4. BCK20-OD02-V04-COMB-DEC-01 records four separate exact-v0.4
combined-owner verdicts with zero independence. BCK20-OD02-SRC-AUTH-DEC-01
accepts the frozen source-authority matrix as a design boundary only.
BCK20-OD02-SRC-REC-DEC-01 accepts 23 internal documentation inputs and the
eight-source external work queue, while every market remains disabled. Exact
EXT-A–D P6 technical evidence is now recorded and the source register is
reconciled, but lawful allowed use, freshness/per-source decisions, source
copy, independent Security/Privacy and applicable qualified Legal evidence
remain Pending/Blocked/Deferred. No source is eligible; EXT-G5/G6 remain
closed and the qualified-review package contains no verdict. Runtime is
Absent. OD10-DOC-DEC-01 integrates F-001–F-012 into amended evidence v0.2.
BCK-D1-OWN-B-REV-01 now prepares five separate OD-10 perspective verdicts and
one separate source-governance verdict, but all six remain Pending and every
specialist/Legal/executable gate stays open.

## 1. Purpose

This matrix checks structural coverage, canonical taxonomy preservation and
OD-10 blockers. It is not a competing localization spec and does not create
schemas, translations, datasets, Firebase resources, mobile adapters or runtime.

## 2. Source reconciliation

| Source | Tracked status | Treatment |
|---|---|---|
| Accepted ADR / Architecture Baseline | Accepted/Frozen | Cannot be weakened |
| BCK-01 | Review; bounded R0/RAW-C local source, product/cloud runtime Absent | Parent market/reference boundary |
| BCK-02 | Approved semantic baseline | Registry/gates/template |
| BCK-03 v0.3.14 | Draft; API/Operations/Security/Mobile boundary reviews Accept with required amendments; API-DEC-05 Deferred | Wire/version input; no non-Booking language-neutral schema authority |
| BCK-04 v0.4.23 | Draft; BCK-04/threat-model technical verdicts recorded; BCK04-OD-01/09 and independent/Legal evidence pending | Legal/privacy/retention/incident boundary |
| BCK-05 v0.2.30 | Draft; bounded R0/RAW-C local evidence boundary; BCK05-OD-01/02/07 Accepted and BCK05-OD-03/04/05/08 Proposed | Distribution/operations input |
| Category System v1.4.3 | Accepted | Taxonomy identity/source invariant |
| BCK-02-A1 | Draft; docs only | Latvia/Baltics execution input |
| BCK-20 v0.2.21 | Draft; EXT-A–D technical baseline and amended OD-10 evidence recorded; Batch B review prepared but unsigned; no source eligible; OD-10 Proposed; specialist/Legal/EXT-G5/G6 gates closed; runtime Absent | Single target Reference Data contract |

## 3. Coverage — BCK-02 §14

| # | Requirement | Coverage | Evidence/gap |
|---:|---|---|---|
| 1 | Header/status/owner | Full | Header |
| 2 | Parents/priority | Full | §2 |
| 3 | Outcome/non-goals | Full | §3 |
| 4 | Scope | Full | §5 |
| 5 | Ownership | Full | §6 |
| 6 | Data classes/projections | Full design | §7 |
| 7 | Commands/queries/events/errors | Full semantic | §8; BCK-03/OD-09 remain gated |
| 8 | Versions/evolution/client | Full | §9 |
| 9 | AuthZ/revocation | Full target | §10 |
| 10 | Persistence/transactions | Full boundary | §11; runtime absent |
| 11 | IDs/time/reference | Full | §12 |
| 12 | Idempotency/concurrency/failure | Full | §13 |
| 13 | Offline/cache/degraded | Full | §14 |
| 14 | Migration/compatibility | Full | §15 |
| 15 | Outbox/replay/dedupe | Full boundary | §16; OD-09 gated |
| 16 | Privacy/retention/Legal | Full boundary | §17; Legal matrix open |
| 17 | Abuse/rate/App Check/fraud | Full | §18 |
| 18 | Logs/SLO/alerts/analytics/cost | Full boundary | §19; BCK-05/BCK-21 own details |
| 19 | Flags/rollout/rollback | Full | §20 |
| 20 | Exact file map | Full conditional | §22; API-DEC-05 guard |
| 21 | Test matrix | Full | §23 |
| 22 | AC/DoR/DoD/unimplemented | Full | §25–28; 68 AC |

**Coverage verdict: 22/22 addressed; Approval readiness not claimed.**

## 4. Category System reconciliation

| Invariant | Source fact | BCK-20 result |
|---|---|---|
| Categories | 27 user + `other` = 28 | Preserved |
| Subcategories | 530 by v1.4.3 counting rules | Preserved |
| Profiles | 21 + `open_event` fallback | Preserved |
| Field IDs | 36 | Preserved |
| Aliases | 5 canonical redirects; related notes distinct | Preserved |
| IDs | globally stable subcategory slugs | Never reused/reparented semantically |
| Removal | deprecated, not deleted | Preserved |
| l10n | non-empty keys en/ru/lv | Preserved; runtime copy absent |
| Route boundary | route only, not Scenario/Quick Plan | Preserved |
| Legacy | accepted mapping/read compatibility | Versioned migration only |

BCK-20 publishes accepted source revisions; it does not become a second
taxonomy owner.

## 5. OD-10 reconciliation contract

Before OD-10 acceptance:

The deterministic LV/EE/LT and invalid review vectors are in
[BCK-D1-OD10-EV-01](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md). They are review
evidence, not executable fixtures or decision acceptance.

1. API Platform accepts exact LocalizedText v1 wire semantics;
2. Product Localization accepts locale normalization and fallback behavior;
3. Content/Mobile owners accept contentLocale/fallback UI behavior;
4. Legal defines fallback-forbidden mandatory local-copy classes;
5. LV exact/fallback/missing fixtures pass for `lv-LV`, `en`, `ru`;
6. EE/LT fixtures prove disabled state and independent locale policy;
7. current/previous/newer compatibility and rollback fixtures pass;
8. API-DEC-05 is resolved before language-neutral non-Booking schemas exist;
9. BCK-02 OD-10 status is updated atomically with evidence.

## 6. Review blockers

| ID | Blocker | Owner | Exit evidence |
|---|---|---|---|
| BCK20-PRE-01 | Combined-owner technical triage recorded; specialist verdicts and independent evidence absent | Assigned owner | Completed D1-SIG-REF and D1-SIG-L10N review records in [BCK-D1-SIG-01](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md) |
| BCK20-PRE-02 | BCK-03/BCK-05 remain Draft | API + Operations | Reconciled review/approval evidence |
| BCK20-PRE-03 | OD-10 remains Proposed after F-001–F-012 documentation amendments | Reference/API/Localization/Content/Mobile/Legal | attributable full-scope verdicts and qualified policy where applicable; executable parity after API-DEC-05 in a separately Approved slice |
| BCK20-PRE-04 | Mandatory local Legal copy/fallback-forbidden matrix absent | Legal + Product | BCK20-OD-05 accepted matrix |
| BCK20-PRE-05 | 23 internal records and exact EXT-A–D technical evidence are accepted with zero independence; allowed-use/freshness/source decisions, source copy, independent Security/Privacy and applicable qualified Legal evidence remain Pending; no source is eligible and OD-02 is Open | Reference Data + Security/Privacy + Legal where applicable | qualified exact-hash terms/access verdicts, per-source owner decisions, approved source snapshots/copy and required independent/qualified evidence |
| BCK20-PRE-06 | Artifact/distribution choices Deferred behind API-DEC-05 and measured executable evidence | Reference + API + Operations | later BCK20-OD-01/03 decisions; no schema/distribution now |
| BCK20-PRE-07 | EE/LT extra locale policy Deferred | Market/Product owners | later BCK20-OD-04 evidence; markets stay disabled with no LV fallback |
| BCK20-PRE-08 | Auxiliary dictionaries Deferred without accepted source | Category/Product owner | later BCK20-OD-06 decision; dictionaries remain absent |
| BCK20-PRE-09 | Destructive retirement Deferred without minimum-client/adoption evidence | Reference + domains | later BCK20-OD-07 decision; additive/deprecated compatibility only |

## 7. Structural checks

1. All local links resolve.
2. 22/22 mandatory sections have evidence.
3. `BCK-20-AC-01…68` are unique and sequential.
4. Taxonomy metrics and aliases match Accepted v1.4.3.
5. OD-10 is visibly Proposed, never inferred Accepted.
6. LV/EE/LT activation and locale policy are independent.
7. Market/country/locale/currency/environment/timezone are distinct.
8. Runtime remains Absent and future paths are conditional.
9. Local links, whitespace, diff and boundary checks pass.

## 8. Verdict

BCK-20 v0.2.21 is structurally complete and preserves the accepted taxonomy.
Workflow v0.4 integrates the accepted documentation-only corrections and four
separate exact-v0.4 combined-owner verdicts are recorded with zero
independence. The frozen source-authority design boundary is accepted, while
23 internal documentation records and the external evidence work queue are
accepted. Exact EXT-A–D technical evidence and mixed limitations are now
recorded, while every market remains disabled, no source is eligible and
EXT-G5/G6 stay closed. Lawful allowed use, freshness/per-source decisions,
source copy, independent Security/Privacy and applicable qualified Legal
evidence stay open.
OD10-DOC-DEC-01 makes the corrected documentation design reviewable.
BCK-D1-OWN-B-REV-01 consolidates the next six bounded verdicts without
recording them. BCK20-OD-02/05 and OD-10 stay unaccepted, BCK-20 stays Draft,
and no schema, dataset service, translation runtime, mobile adapter or
infrastructure is authorized.
