# BCK-20 — Reference Data & Localization Coverage Matrix

- ID: **BCK-20-PRE**
- Version: **0.1**
- Date: **2026-08-20**
- Status: **Draft — preparatory audit artifact**
- Runtime status: **N/A; no runtime authority**
- Accountable owner: **Reference Data owner**
- Target: [BCK-20 v0.1](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.6](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/REFERENCE_DATA_LOCALIZATION_COVERAGE_MATRIX.md`

## 1. Purpose

This matrix checks structural coverage, canonical taxonomy preservation and
OD-10 blockers. It is not a competing localization spec and does not create
schemas, translations, datasets, Firebase resources, mobile adapters or runtime.

## 2. Source reconciliation

| Source | Tracked status | Treatment |
|---|---|---|
| Accepted ADR / Architecture Baseline | Accepted/Frozen | Cannot be weakened |
| BCK-01 v0.4.2 | Review; runtime Absent | Parent market/reference boundary |
| BCK-02 v2.4.6 | Approved semantic baseline | Registry/gates/template |
| BCK-03 v0.2.4 | Draft; runtime Absent | Wire/version input; LocalizedText delegated |
| BCK-04 v0.4.3 | Draft; runtime Absent | Legal/privacy/retention boundary |
| BCK-05 v0.1 | Draft; runtime Absent | Distribution/operations input |
| Category System v1.4.3 | Accepted | Taxonomy identity/source invariant |
| BCK-02-A1 v1.0 | Draft; docs only | Latvia/Baltics execution input |
| BCK-20 v0.1 | Draft; runtime Absent | Single target Reference Data contract |

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
| 22 | AC/DoR/DoD/unimplemented | Full | §25–28; 50 AC |

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
| BCK20-PRE-01 | Named Reference Data/Product Localization owners absent | Product/Engineering leadership | Repository-owned assignment |
| BCK20-PRE-02 | BCK-03/BCK-05 remain Draft | API + Operations | Reconciled review/approval evidence |
| BCK20-PRE-03 | OD-10 only Proposed | Reference/API/Content/Mobile/Legal | Accepted decision and fixture report |
| BCK20-PRE-04 | Mandatory local Legal copy/fallback-forbidden matrix absent | Legal + Product | BCK20-OD-05 accepted matrix |
| BCK20-PRE-05 | Translation source/review workflow absent | Product Localization | BCK20-OD-02 accepted workflow |
| BCK20-PRE-06 | Artifact/distribution/API-DEC-05 path unresolved | Reference + API + Operations | BCK20-OD-01/03 decisions |
| BCK20-PRE-07 | EE/LT extra locale policy unresolved | Market/Product owners | BCK20-OD-04 evidence; markets stay disabled |
| BCK20-PRE-08 | Auxiliary dictionaries have no accepted source | Category/Product owner | BCK20-OD-06 or continued absence |

## 7. Structural checks

1. All local links resolve.
2. 22/22 mandatory sections have evidence.
3. `BCK-20-AC-01…50` are unique and sequential.
4. Taxonomy metrics and aliases match Accepted v1.4.3.
5. OD-10 is visibly Proposed, never inferred Accepted.
6. LV/EE/LT activation and locale policy are independent.
7. Market/country/locale/currency/environment/timezone are distinct.
8. Runtime remains Absent and future paths are conditional.
9. Local links, whitespace, diff and boundary checks pass.

## 8. Verdict

BCK-20 v0.1 is structurally complete and preserves the accepted taxonomy. It
remains Draft until §6 blockers and OD-10 evidence are resolved. No schema,
dataset service, translation workflow, mobile adapter or runtime is authorized.
