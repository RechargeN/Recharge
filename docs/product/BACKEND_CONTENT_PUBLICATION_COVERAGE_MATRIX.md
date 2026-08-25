# BCK-07 — Content Publication Backend Coverage Matrix

- ID: **BCK-07-PRE**
- Version: **0.2**
- Date: **2026-08-25**
- Status: **Review — coverage and reconciliation evidence**
- Runtime status: **N/A; no product backend authority**
- Accountable owner: **Content Platform owner**
- Target: [BCK-07 v0.2](CONTENT_PUBLICATION_BACKEND_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.36](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_CONTENT_PUBLICATION_COVERAGE_MATRIX.md`

## 0. Changelog

### v0.2 — 2026-08-25

- reconciled the audit to BCK-07 v0.2 Review;
- verified 22/22 mandatory design categories, 60 target AC and ten BCK07
  owner decisions;
- closed the Scenario/Quick Plan and publication/source-aggregate ownership
  ambiguity without authorizing runtime;
- preserved OD-03/10/11, dependency Approval and production gates.

### v0.1 — 2026-08-25

- inventoried canonical product/domain sources and current local Create runtime;
- recorded 16 gaps and 24 preparatory acceptance criteria.

## 1. Verdict

BCK-07 v0.2 is suitable for **Review as a documentation-only target**. It
defines one publication authority for the ten accepted Create types, while
preserving the separate source aggregates and invariants owned by Event,
Scenario, Route, Media, Identity, Booking, Reference Data and Trust & Safety.

Runtime remains **Absent**. BCK-03/04/05/20 are Draft; BCK-06/14/18 are Review;
BCK-10/11/22 are absent; OD-03 and OD-11 are Open; OD-10 is Proposed; several
type-specific product specs are not present in this checkout. No contracts,
Firebase handlers, publication records, migration, catalog projection or
production processing are authorized.

## 2. Source reconciliation

| Source | Status used here | BCK-07 treatment |
|---|---|---|
| ADR 0013 | Accepted | Lifecycle, capabilities, IDs, moderation, audit and media decoupling |
| ADR 0015 | Accepted | Authenticated Viewer draft boundary; verified Creator/capability/PublisherRef publish boundary |
| BCK-01 v0.4.32 | Review | Parent architecture and one-writer constraints |
| BCK-02 v2.4.36 | Approved coordination | Scope, dependencies, D2/R3 gates and 22-category template |
| BCK-03 v0.3.3 | Draft with Accepted split-key decision | Command/query/error/version/idempotency semantics |
| BCK-04 v0.4.16 | Draft | Security, privacy, retention, age-sensitive fail-closed controls |
| BCK-06 v0.2 | Review | Session, Creator verification, capability, page membership and PublisherRef authority |
| BCK-14 v0.2.1 | Review | Media readiness/generation receipts; Media cannot publish Content |
| BCK-18 v0.2 | Review | Mobile ports, import session and cutover boundary |
| BCK-20 v0.2.2 | Draft; OD-10 Proposed | Stable taxonomy/market/localization revisions; proposal is not Accepted |
| Event Classification v2.2.3 | Accepted | Canonical Event classification/admission/inventory/provider boundaries |
| VISION + accepted product specs | Mixed priority/status | Ten-type product contract; no silent promotion of Draft specs |
| Current mobile runtime | Local/mock | Evidence and migration debt only, not backend authority |

## 3. Canonical Create type reconciliation

| Canonical type | Publication boundary | Source-domain note | Current evidence/gap |
|---|---|---|---|
| `event` | BCK-07 publication revision | Event v2.2.3 invariants; Booking state remains BCK-09 | Typed local subset; backend absent |
| `activity` | BCK-07 | Activity product rules required | Generic local runtime; dedicated spec absent here |
| `route` | BCK-07 manifest/handoff | Route aggregate and GPX remain BCK-11 | Separate local publication path; BCK-11 absent |
| `place` | BCK-07 | Place typed schema and provenance | Typed local runtime; backend absent |
| `session` | BCK-07 | Bookable Session source; Booking authority separate | Generic/local; dedicated spec absent here |
| `scenario` | BCK-07 distribution manifest | Scenario aggregate remains BCK-10 | Typed local personal flow; BCK-10 absent |
| `find_people` | BCK-07 with OD-11/privacy gate | Consent/access input from BCK-06 | Typed local/mock; production gated |
| `class_workshop` | BCK-07 | Dedicated product spec present but not Approved by this doc | Generic local runtime |
| `rental` | BCK-07; direct publish only explicit policy | Rental inventory/fulfillment remains domain-owned | Generic local; trusted gate not production-authorized |
| `collection` | BCK-07 | Collection item refs/removal behavior remain domain-owned | Generic/local; dedicated spec absent here |

`quick_plan` is not an eleventh type. It is a private/invited utility owned by
BCK-10 and is accepted only as a legacy-read discriminator. It cannot enter a
BCK-07 publish command or catalog projection.

## 4. Current runtime inventory

| Area | Present | Gap/unsafe assumption |
|---|---|---|
| Form engine | Shared config-driven Create flow and 11 enum values including legacy Quick Plan | Backend allowlist must contain exactly ten canonical publishable types |
| Draft storage | Local datasource; generic current draft plus specialized Scenario/Route stores | No authoritative multi-draft revision model or sync |
| Lifecycle | Generic local entity carries three overlapping draft/publish/moderation statuses; submit creates pending review | Statuses can diverge and submit also sets `publishedAtUtc`; backend uses one lifecycle plus typed review/effect refs |
| Unknown type | `createObjectTypeFromId` defaults unknown to Event | Backend must return typed unsupported type, never reinterpret |
| IDs | Local `loc_*` replacement exists for some nested Event/Place/Find People values | Cross-type completeness and deterministic mapping not proven |
| Publisher | Shared PublisherRef in Event/Place; Route has parallel ref; generic organizer ID/name/contact fields remain | Ten-type exact publisher parity and public/private organizer projection are absent |
| Money | Multiple normalized models still use `double` | Remote writes blocked until M2 minor-unit migration |
| Media | Cover/gallery URL strings, local rights metadata | No BCK-14 asset readiness/generation refs |
| Provenance | Place/Route and UI seed hints exist in separate shapes | No canonical source/license/snapshot/correction/removal record |
| Publication | Generic pending-review plus separate Route/Collection/Rental local paths | Parallel writers and promotion semantics require reconciliation |
| Discover | Local sinks/projections | BCK-08 remains catalog writer; no backend outbox/projection |
| Contracts/backend | Booking schemas and R0 scaffold only | No Content API/schema/handlers/persistence |

## 5. Mandatory BCK-02 coverage

| # | Requirement | BCK-07 evidence | Coverage/gap |
|---:|---|---|---|
| 1 | Header/status/owner | Header and §1 | Full; Review/runtime Absent explicit |
| 2 | Parents/priority | §2 | Full; mixed-status inputs qualified |
| 3 | Outcome/non-goals | §3 | Full |
| 4 | Scope | §4 | Full; exactly ten publishable types |
| 5 | Ownership | §5–6 | Full; publication/source/projection/moderation writers separated |
| 6 | Data/projections | §7–8 | Full design model; executable schemas absent |
| 7 | Commands/queries/events/errors | §9–11 | Full semantic inventory |
| 8 | Versions/evolution/client | §12 | Full; Content schema workflow open |
| 9 | AuthZ/revocation | §13 | Full target boundary; BCK-06/runtime absent |
| 10 | Persistence/index/transactions | §14 | Full conditional design; implementation absent |
| 11 | IDs/time/reference | §15 | Full; OD-10/M2 gates explicit |
| 12 | Idempotency/concurrency/retry/failure | §16 | Full |
| 13 | Offline/cache/freshness | §17 | Full semantic contract; adapters absent |
| 14 | Migration/import/compat | §18 | Full fail-closed plan; OD-03/04/08 unresolved |
| 15 | Outbox/replay/dedupe | §19 | Full design; OD-09/runtime absent |
| 16 | Privacy/retention/Legal | §20 | Full boundary; OD-11/exact policies absent |
| 17 | Abuse/rate/App Check | §21 | Full; numeric controls absent |
| 18 | Logs/SLO/analytics/cost | §22 | Full structure; measurements absent |
| 19 | Flags/rollout/rollback | §23 | Full; activation closed |
| 20 | Exact file map | §25 | Full conditional map |
| 21 | Test matrix | §26 | Full planned evidence; runtime evidence absent |
| 22 | AC/DoR/DoD/unimplemented | §27–30 | Full; 60 AC and explicit absent list |

**Coverage verdict:** 22/22 addressed at Review design level; Approval,
implementation, deployment and enablement are not claimed.

## 6. Single-writer reconciliation

| Concern | Writer/source | BCK-07 responsibility | Forbidden overlap |
|---|---|---|---|
| Account/access/publisher eligibility | BCK-06 | Consume authoritative snapshot | Grant role/capability/membership |
| Publication record/current public revision | BCK-07 | Own lifecycle and distribution manifest | Type domain or client writes public state |
| Typed source invariant | Owning product/domain spec | Invoke validator and pin source revision | Generic map overwrites typed aggregate |
| Scenario/Quick Plan source aggregate | BCK-10 | Publish Scenario snapshot ref only | Store Quick Plan as catalog content |
| Route/GPX source aggregate | BCK-11 | Publish Route snapshot ref only | Interpret/write track or GPX |
| Booking/inventory ledger | BCK-09 | Pin Event content/config revision | Mutate availability/Booking state |
| Media asset/generation | BCK-14 | Consume ready generation receipt | Store blob or promote staging object |
| Catalog/feed/map/search | BCK-08 | Emit published/revoked facts | Write search/index projection directly |
| Moderation case/sanction | BCK-22 | Apply authorized visibility/lifecycle effect | Invent sanction/case outcome |
| Reference/localization | BCK-20 | Pin IDs/revisions/content language | Hardcode market/locale fallback |
| Import orchestration | BCK-18 | Validate/write through Content commands | Import writes Content storage directly |

## 7. Gaps

| ID | Finding | Required disposition |
|---|---|---|
| BCK07-GAP-01 | Target BCK-07 file was absent | Closed by v0.2 Review; runtime remains Absent |
| BCK07-GAP-02 | Taxonomy retains legacy `quickPlan` and does not expose Scenario identically | Canonical publish allowlist is ten types with Scenario; Quick Plan read-only |
| BCK07-GAP-03 | Unknown type defaults to Event locally | Backend rejects unsupported/unknown/newer type without mutation |
| BCK07-GAP-04 | Generic pending-review flow sets `publishedAtUtc` | Publication time exists only on actual public activation |
| BCK07-GAP-05 | PublisherRef representation is incomplete across ten types | BCK-06/BCK-18 reconciliation before remote write |
| BCK07-GAP-06 | Route/Rental/Collection may use parallel local publication paths | One BCK-07 publication command/record; domain adapters cannot become writers |
| BCK07-GAP-07 | BCK-10/BCK-11/BCK-22 are absent | Scenario/Route/moderation integrations disabled |
| BCK07-GAP-08 | Activity/Session/Rental/Collection complete specs are absent in this checkout | Type-specific remote publish disabled until canonical source and tests exist |
| BCK07-GAP-09 | Money remains `double` in normalized models | M2 completion required before price-bearing remote writes |
| BCK07-GAP-10 | Media values are URL strings | BCK-14 ready asset generation refs required |
| BCK07-GAP-11 | OD-03 cold-start license/provenance/removal is Open | No seeded catalog population |
| BCK07-GAP-12 | OD-10 LocalizedText is Proposed | No localized Content contract/Approval |
| BCK07-GAP-13 | OD-11 age/minors policy is Open | Age-sensitive publication disabled |
| BCK07-GAP-14 | Current seed hints are not authoritative provenance | No automatic/public seeded publish or silent attribution |
| BCK07-GAP-15 | Moderation/review policy and material-change rules are incomplete | Default submit to pending review; no direct publish |
| BCK07-GAP-16 | Boundary exception budget is 71/71 | Executable slice adds no suppression or reduces/separately approves debt |
| BCK07-GAP-17 | Draft, publish and moderation status fields can diverge locally | Backend owns one publication lifecycle; review/sanction remain typed referenced decisions |
| BCK07-GAP-18 | Legacy organizer/contact fields overlap PublisherRef and privacy projection | PublisherRef remains attribution; contact exposure uses explicit per-type public allowlist |

## 8. Open owner decisions

| ID | Decision | Owners | Gate | Fail-closed default |
|---|---|---|---|---|
| BCK07-OD-01 | Content schema/API/codegen workflow and ten type envelopes | Content + API + Mobile + domains | Any adapter | No remote Content client |
| BCK07-OD-02 | Canonical per-type source validator/revision contract | Content + ten domain owners | Type enablement | Type disabled |
| BCK07-OD-03 / OD-03 | Cold-start source, licence, publisher/provenance, refresh/correction/removal | Content + Legal + Discover | Seeded catalog | No seeded publish |
| BCK07-OD-04 / OD-10 | LocalizedText/content-language/fallback/revision contract | Reference + API + Content + Legal | BCK-07 Approval | Localized publish disabled |
| BCK07-OD-05 / OD-11 | Age/restriction/guardian/eligibility/disclosure policy | Security/Privacy + Legal + Content | Age-sensitive publish | Disabled |
| BCK07-OD-06 | Review policy, material-change matrix and trusted direct-publish allowlist | Content + Trust/Safety + Product | Activation | Pending review only |
| BCK07-OD-07 | Draft/published revision retention, deletion, DSR and legal hold | Privacy/Legal + Content + Operations | Production data | No production storage |
| BCK07-OD-08 | Scenario/Route/Media source-revision handoff contracts | Content + Planning + Route + Media | Complex type publish | Types disabled |
| BCK07-OD-09 | Legacy draft/type/ID/publisher/provenance import and rollback | Content + Mobile + Identity + domains | Import | No import |
| BCK07-OD-10 | Numeric SLO, quotas, revision limits, cost and rollout cohorts | Operations + Content + Product | Scale/production | Feature disabled |

## 9. Preparatory acceptance criteria

1. **BCK-07-PRE-AC-01:** Target Review status and runtime absence are explicit.
2. **BCK-07-PRE-AC-02:** All 22 mandatory categories are mapped.
3. **BCK-07-PRE-AC-03:** Exactly ten canonical types are publishable.
4. **BCK-07-PRE-AC-04:** Scenario occupies the planning slot.
5. **BCK-07-PRE-AC-05:** Quick Plan remains legacy-read/private utility only.
6. **BCK-07-PRE-AC-06:** Unknown type never defaults to Event at authority.
7. **BCK-07-PRE-AC-07:** Pending review is not published.
8. **BCK-07-PRE-AC-08:** Publication time starts only at public activation.
9. **BCK-07-PRE-AC-09:** Publication record has one writer.
10. **BCK-07-PRE-AC-10:** Source-domain aggregates retain their writers.
11. **BCK-07-PRE-AC-11:** Catalog projection remains BCK-08-owned.
12. **BCK-07-PRE-AC-12:** Media readiness does not publish Content.
13. **BCK-07-PRE-AC-13:** Cached identity never authorizes publish.
14. **BCK-07-PRE-AC-14:** Saved PublisherRef is not rewritten by workspace switch.
15. **BCK-07-PRE-AC-15:** Seeded source never impersonates a user/page.
16. **BCK-07-PRE-AC-16:** OD-03 blocks seeded catalog population.
17. **BCK-07-PRE-AC-17:** OD-10 proposal is not treated as Accepted.
18. **BCK-07-PRE-AC-18:** OD-11 blocks age-sensitive publication.
19. **BCK-07-PRE-AC-19:** Money M2 blocks price-bearing remote writes.
20. **BCK-07-PRE-AC-20:** No new boundary suppression is added.
21. **BCK-07-PRE-AC-21:** Documentation checks are not runtime evidence.
22. **BCK-07-PRE-AC-22:** Missing type contracts are visible blockers.
23. **BCK-07-PRE-AC-23:** Future executable files remain conditional.
24. **BCK-07-PRE-AC-24:** Runtime, Firebase, push and `main` remain untouched.

## 10. Evidence summary

- repository/source/runtime audit: complete for this Review revision;
- target coverage: 22/22;
- target AC: 60 sequential;
- owner decisions: ten Open/linked;
- runtime/cloud evidence: absent;
- new boundary suppressions: zero;
- authorized effects: documentation and a local commit only.
