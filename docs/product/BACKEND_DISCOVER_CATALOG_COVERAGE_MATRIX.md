# BCK-08 — Discover/Search/Catalog Backend Coverage Matrix

- ID: **BCK-08-PRE**
- Version: **0.2**
- Date: **2026-08-25**
- Status: **Review — coverage and reconciliation evidence**
- Runtime status: **N/A; no catalog/search backend authority**
- Accountable owner: **Discover owner**
- Target: [BCK-08 v0.2](DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.37](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_DISCOVER_CATALOG_COVERAGE_MATRIX.md`

## 0. Changelog

### v0.2 — 2026-08-25

- reconciled the audit to BCK-08 v0.2 Review;
- verified 22/22 mandatory categories, 60 target AC and ten BCK08 decisions;
- made feed/map/search membership revision/freshness parity normative;
- preserved OD-01/03, dependency Approval, Money, privacy and runtime gates.

### v0.1 — 2026-08-25

- inventoried canonical Discover contracts and current mock/local runtime;
- recorded 19 gaps and 24 preparatory acceptance criteria.

## 1. Verdict

BCK-08 v0.2 is suitable for **Review as a documentation-only target**. It
defines one rebuildable Catalog/Search authority sourced from BCK-07 published
revisions, with separate typed Feed, Map, Search and Details projections that
share one applied query fingerprint, compatible projection-set revision and
freshness contract.

Runtime remains **Absent**. BCK-03/04/20 are Draft, BCK-07 is Review, BCK-09
runtime and BCK-16 are absent, OD-01/03 are Open, OD-10 is Proposed and no
search engine/index/catalog worker/backend/mobile adapter is authorized.

## 2. Source reconciliation

| Source | Status used here | BCK-08 treatment |
|---|---|---|
| ADR 0013 | Accepted | Geo + freshness baseline, zero-result, privacy, audit and server flags |
| BCK-01 v0.4.33 | Review | Projection ownership and shared query revision/freshness contract |
| BCK-02 v2.4.37 | Approved coordination | Scope, dependencies, OD-01/03 and D2/R3/G3 gates |
| BCK-03 v0.3.3 | Draft with Accepted split-key decision | Query/cursor/revision/freshness/typed failure semantics |
| BCK-04 v0.4.16 | Draft | Public allowlist, privacy, age, cache and abuse controls |
| BCK-07 v0.2 | Review | Published revision/visibility/provenance source; runtime Absent |
| BCK-09 v1.1 | Review/runtime Absent | Internal availability source only; never public mutation authority |
| BCK-16 | Planned/Absent | Provider availability/provenance source |
| BCK-20 v0.2.2 | Draft; OD-10 Proposed | Market/taxonomy/localization revisions |
| S2-DISC-02 | Done local slice | One applied DiscoverQuery, map/list sync and local UX evidence only |
| VISION | Product baseline | Search vs Smart Search, map/feed/details semantics |
| Proposed Firebase Architecture | Proposed input | Query/index ideas only; no provider choice by implication |
| Current mobile runtime | Mock/local | Evidence and migration debt, not backend authority |

## 3. Current runtime inventory

| Area | Present | Gap to target |
|---|---|---|
| Applied query | `DiscoverQuery` v2 shared by local feed/map/results | No backend query fingerprint, snapshot revision, cursor or freshness |
| Search | Literal substring filtering over loaded candidates | Not complete catalog search; no language/index/relevance evidence |
| Smart Search | Separate rule parser that produces applied query | Correct boundary; no server parsing/contract needed for baseline |
| Feed/map | Same controller/item list locally | No server projection parity or typed inconsistent state |
| Object kinds | Place/Event/Route/Activity only | Six canonical types missing; unknown kind defaults to Activity |
| Universal card | Requires point, start time and numeric price | Unsuitable for online/non-point/Collection/Scenario typed projections |
| Query version | Newer stored versions are normalized back to v2 | Newer unsupported must fail closed, not partially apply |
| Money | Budget/price use `double` | M2 minor-unit migration required before remote price query |
| Ranking | Device-time 65/35 distance/temporal-proximity heuristic | No server policy revision, stable tie-break, measured quality or separation from data freshness |
| Availability | Capacity/opening/time-fit local approximations | No BCK-09/BCK-16 sources, provenance or honest freshness composer |
| Routes | Separate local published-route source included only for selected query shapes | Membership can vary by query entry behavior rather than catalog truth |
| Catalog data | 60 generated mock rows from a small seed set | IDs/types/location/source/licence are demo-only; OD-03 blocks production |
| Details | One generic point-oriented Details model/page | No typed ten-type/family public projection contract |
| Geo/defaults | Legacy Rezekne migration plus Riga values in local config/data | Market/center/service-area must come from BCK-20/config |
| Pagination/cache | Entire local list and local preference storage | No bounded server page, cursor, snapshot or cache metadata |

## 4. Mandatory BCK-02 coverage

| # | Requirement | BCK-08 evidence | Coverage/gap |
|---:|---|---|---|
| 1 | Header/status/owner | Header and §1 | Full; Review/runtime Absent explicit |
| 2 | Parents/priority | §2 | Full; Draft/Proposed inputs qualified |
| 3 | Outcome/non-goals | §3 | Full |
| 4 | Scope | §4 | Full |
| 5 | Ownership | §5–6 | Full; source/index/availability writers separated |
| 6 | Data/projections | §7–8 | Full typed design; schemas/runtime absent |
| 7 | Commands/queries/events/errors | §9–11 | Full semantic inventory |
| 8 | Versions/evolution/client | §12 | Full; contract workflow open |
| 9 | AuthZ/revocation | §13 | Full public/protected boundary |
| 10 | Persistence/index/transactions | §14 | Full conditional model; OD-01 blocks choice |
| 11 | IDs/time/reference | §15 | Full; M2/OD-10 explicit |
| 12 | Idempotency/concurrency/retry/failure | §16 | Full query/rebuild/effect semantics |
| 13 | Offline/cache/freshness | §17 | Full |
| 14 | Migration/import/compat | §18 | Full fail-closed plan |
| 15 | Outbox/replay/dedupe | §19 | Full design; OD-09/runtime absent |
| 16 | Privacy/retention/Legal | §20 | Full boundary; exact evidence absent |
| 17 | Abuse/rate/App Check | §21 | Full; numeric limits absent |
| 18 | Logs/SLO/analytics/cost | §22 | Full structure; measurements absent |
| 19 | Flags/rollout/rollback | §23 | Full; activation closed |
| 20 | Exact file map | §25 | Full conditional map |
| 21 | Test matrix | §26 | Full planned evidence |
| 22 | AC/DoR/DoD/unimplemented | §27–30 | Full; 60 AC and explicit absent list |

**Coverage verdict:** 22/22 addressed at Review design level. Approval,
implementation, deployment and production readiness are not claimed.

## 5. Single-writer reconciliation

| Concern | Writer/source | BCK-08 responsibility | Forbidden overlap |
|---|---|---|---|
| Published content/current revision | BCK-07 | Consume published/visibility/provenance facts | Edit Content/publication lifecycle |
| Catalog/feed/map/search/details projection | BCK-08 | Rebuild, activate, query and tombstone | Source domains write index directly |
| Internal availability | BCK-09 | Consume ledger-derived source/revision/freshness | Confirm Booking from projection |
| Provider availability | BCK-16 | Consume provider source/provenance/freshness | Invent live/provider confirmation |
| Public composed availability | BCK-08 | Honest read projection only | Become mutation/inventory authority |
| Ratings | BCK-12 | Consume aggregate projection | Recalculate source reviews directly |
| Media | BCK-14 | Consume ready public/protected projection | Expose original/private media |
| Reference/localization | BCK-20 | Pin dataset/locale revisions | Hardcode market/category/fallback |
| Search/geo infrastructure | OD-01/BCK-05 decision | Preserve provider-neutral semantics | Provider mechanics become ranking truth |
| Cold-start content | BCK-07/OD-03 | Index only authorized published source | Mock/seed becomes production authority |

## 6. Projection parity contract

For one normalized applied query:

- response surfaces carry the same `queryFingerprint`, compatible
  `projectionSetRevision`, `rankingPolicyRevision` and freshness metadata;
- Feed is the ordered eligible result set within query/service-area semantics;
- Map is the map-eligible subset of that same result set, optionally limited by
  viewport and represented by clusters;
- every leaf object shown on Map is eligible in Feed for the same query/snapshot,
  subject only to documented viewport/pagination window;
- a Feed-only non-mappable item carries a typed map-exclusion reason;
- Search result membership uses the same filters/snapshot; text match adds a
  declared criterion, not an independent source;
- mismatch is `stale`/`inconsistentProjection`, never silent success.

## 7. Gaps

| ID | Finding | Required disposition |
|---|---|---|
| BCK08-GAP-01 | Target BCK-08 file was absent | Closed by v0.2 Review; runtime remains Absent |
| BCK08-GAP-02 | OD-01 search/geo engine is Open | No engine/index/provisioning/runtime |
| BCK08-GAP-03 | OD-03 cold-start source is Open | No production mock/seed/catalog population |
| BCK08-GAP-04 | BCK-07 is Review/runtime Absent | No authoritative projection source |
| BCK08-GAP-05 | Only four object kinds exist locally | Typed ten-type/family projections required; unsupported disabled |
| BCK08-GAP-06 | Unknown kind defaults to Activity | Backend/client contract must fail closed |
| BCK08-GAP-07 | Universal item requires geo/time/price | Separate typed projection shapes and map eligibility |
| BCK08-GAP-08 | Newer query versions silently down-map to v2 | Unsupported newer query fails closed with preserved local data |
| BCK08-GAP-09 | Feed/map/search have no shared server revision/freshness | Normative parity contract and typed inconsistency |
| BCK08-GAP-10 | Route source membership is conditionally injected locally | One catalog source and query semantics required |
| BCK08-GAP-11 | Ranking constants/device time are local implementation | Versioned server policy and deterministic evaluation evidence |
| BCK08-GAP-12 | `double` Money remains | M2 before price/budget remote query |
| BCK08-GAP-13 | Availability conflates capacity, schedule/opening and time-fit | Three source writers plus honest composer required |
| BCK08-GAP-14 | Unlimited radius can imply unbounded scan | Bounded service area/candidates/pages even in user-visible unlimited mode |
| BCK08-GAP-15 | Mock rows have demo IDs/sources/locations/images | Never migrate as production authority without OD-03 |
| BCK08-GAP-16 | Saved search/history ownership is not a backend decision | Keep local; server sync needs separate scoped decision |
| BCK08-GAP-17 | Exact public Details projection families are not accepted here | Type/family remains disabled until contract/consumer parity exists |
| BCK08-GAP-18 | Boundary exception budget is 71/71 | Executable slice adds none or reduces/separately approves debt |
| BCK08-GAP-19 | Ranking temporal relevance and projection/source freshness can be called the same thing | Use distinct typed signals; stale data never gains rank by temporal relevance |

## 8. Open owner decisions

| ID | Decision | Owners | Gate | Fail-closed default |
|---|---|---|---|---|
| BCK08-OD-01 / OD-01 | Search/geo engine with quality/latency/cost/privacy evidence | Discover + Operations + Security | Any index runtime | No engine/runtime |
| BCK08-OD-02 / OD-03 | Cold-start source/licence/provenance/refresh/removal | Content + Discover + Legal | Catalog population | No seeded catalog |
| BCK08-OD-03 | Catalog/query schema and API/codegen workflow | Discover + API + Mobile | Any adapter | No remote Discover client |
| BCK08-OD-04 | Typed Feed/Map/Search/Details projection families per ten types | Discover + Content + type owners + Mobile | Type enablement | Type disabled |
| BCK08-OD-05 | Ranking v1 features, weights/ties/freshness and evaluation thresholds | Discover + Product + Data/Privacy | Ranked output | Deterministic geo+freshness baseline only, disabled remotely |
| BCK08-OD-06 | Availability composition precedence, TTL and user wording | Discover + Booking + Integrations + Product | Availability filters/CTA | Unknown; `onlyAvailable` excludes |
| BCK08-OD-07 | Geo/service-area/viewport/clustering/candidate/page limits | Discover + Product + Operations | Map/search runtime | Query unavailable |
| BCK08-OD-08 | Per-projection freshness/cache/lag/rollback thresholds | Discover + Mobile + Operations | Cached/remote reads | Typed unavailable/stale |
| BCK08-OD-09 | Legacy mock/query/kind/details migration and compatibility | Discover + Mobile + Content | Cutover | No migration |
| BCK08-OD-10 | Numeric SLO, cost/read/egress budgets and rollout cohorts | Operations + Discover + Product | Production/scale | Feature disabled |

## 9. Preparatory acceptance criteria

1. **BCK-08-PRE-AC-01:** Review and runtime absence are explicit.
2. **BCK-08-PRE-AC-02:** All 22 mandatory categories are mapped.
3. **BCK-08-PRE-AC-03:** BCK-07 remains published Content source.
4. **BCK-08-PRE-AC-04:** BCK-08 exclusively owns public catalog projections.
5. **BCK-08-PRE-AC-05:** Booking remains internal availability authority.
6. **BCK-08-PRE-AC-06:** Provider Integration remains provider-source authority.
7. **BCK-08-PRE-AC-07:** Public availability is read-only and freshness-labelled.
8. **BCK-08-PRE-AC-08:** Feed/Map/Search share query fingerprint and snapshot revision.
9. **BCK-08-PRE-AC-09:** Map leaf membership is reconcilable to Feed.
10. **BCK-08-PRE-AC-10:** Clusters are not catalog objects.
11. **BCK-08-PRE-AC-11:** Non-mappable Feed items have a typed reason.
12. **BCK-08-PRE-AC-12:** Unknown object kind never defaults to Activity.
13. **BCK-08-PRE-AC-13:** Newer query version fails closed.
14. **BCK-08-PRE-AC-14:** Universal point-card is not the ten-type contract.
15. **BCK-08-PRE-AC-15:** OD-01 blocks engine/index runtime.
16. **BCK-08-PRE-AC-16:** OD-03 blocks production seed/catalog population.
17. **BCK-08-PRE-AC-17:** Unlimited UI radius never creates unbounded query.
18. **BCK-08-PRE-AC-18:** M2 blocks remote price/budget filtering.
19. **BCK-08-PRE-AC-19:** Zero-result relaxation requires explicit user apply.
20. **BCK-08-PRE-AC-20:** No new boundary suppression is added.
21. **BCK-08-PRE-AC-21:** Documentation checks are not runtime evidence.
22. **BCK-08-PRE-AC-22:** Proposed Firebase detail stays non-normative.
23. **BCK-08-PRE-AC-23:** Future executable files remain conditional.
24. **BCK-08-PRE-AC-24:** Runtime, Firebase, push and `main` remain untouched.

## 10. Evidence summary

- source/runtime audit: complete for this Review revision;
- mandatory coverage: 22/22;
- target AC: 60 sequential;
- owner decisions: ten Open/linked;
- runtime/cloud evidence: absent;
- new boundary suppressions: zero;
- authorized effects: documentation and a local commit only.
