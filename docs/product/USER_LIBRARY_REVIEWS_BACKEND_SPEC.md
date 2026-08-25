# Recharge Backend — User Library & Reviews Specification

- ID: **BCK-12**
- Version: **0.2**
- Status: **Review — documentation only; approval and owner decisions pending**
- Runtime status: **Absent**
- Date: **2026-08-26**
- Owner: **User Platform owner**
- Required reviewers: **API Platform, Security/Privacy, Identity, Discover,
  Mobile Platform, Trust & Safety, Legal/Privacy and Operations**

## 0. Changelog

### v0.2 — 2026-08-26

- completed all 22 mandatory BCK-02 design categories;
- separated User Library and Reviews into two bounded aggregates;
- preserved the Approved VIS-HIST-01 explicit-action invariant;
- defined typed catalog references, private library records, public review
  projections and revisioned rating aggregates;
- added migration, DSR, abuse, offline, idempotency, test and rollback contracts;
- recorded 60 sequential acceptance criteria and ten owner decisions;
- did not add backend, Firebase, contracts, adapters or mobile runtime.

### v0.1 — 2026-08-26

- initial coverage and reconciliation draft.

## 1. Verdict and status semantics

BCK-12 v0.2 is a complete **Review contract**, not an Approved implementation
slice. It defines intended backend behavior while preserving current local data.

- **Present**: this document exists;
- **Review**: contradictions and decisions are reviewable;
- **Approved**: qualified verdicts and blocking decisions are recorded;
- **Runtime Absent**: no authoritative cloud implementation exists;
- local/mock behavior is evidence and migration input, not authority.

No section authorizes Firebase, Firestore, deployment, production processing,
client cutover or a merge to `main`.

## 2. Parents, priority and reconciliation

BCK-12 inherits, without silently overriding:

1. Accepted ADRs in `docs/adr/`;
2. [RECHARGE_BACKEND_MASTER_SPEC.md](RECHARGE_BACKEND_MASTER_SPEC.md) (`BCK-01`);
3. [RECHARGE_BACKEND_DELIVERY_MAP.md](RECHARGE_BACKEND_DELIVERY_MAP.md) (`BCK-02`);
4. [BACKEND_API_CONTRACT_STANDARD.md](BACKEND_API_CONTRACT_STANDARD.md) (`BCK-03`);
5. [BACKEND_SECURITY_PRIVACY_SPEC.md](BACKEND_SECURITY_PRIVACY_SPEC.md) (`BCK-04`);
6. [IDENTITY_PUBLISHER_BACKEND_SPEC.md](IDENTITY_PUBLISHER_BACKEND_SPEC.md)
   (`BCK-06`);
7. [DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md](DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md)
   (`BCK-08`);
8. [MOBILE_BACKEND_INTEGRATION_STANDARD.md](MOBILE_BACKEND_INTEGRATION_STANDARD.md)
   (`BCK-18`);
9. [VISIT_HISTORY_SLICE_SPEC.md](VISIT_HISTORY_SLICE_SPEC.md) (`VIS-HIST-01`).

Authority remains split: BCK-06 owns identity; BCK-08 catalog identity;
BCK-12 library/review source and rating projection; BCK-22 reports, sanctions,
appeals and block/mute; BCK-19 privileged tools; BCK-18 mobile orchestration;
BCK-04 privacy/DSR/retention acceptance. Draft/Review dependencies remain
fail-closed blockers rather than implicit Accepted policy.

## 3. Outcome and non-goals

### 3.1 Outcome

BCK-12 defines two bounded modules:

1. **User Library** — actor-owned Favorites and explicit Visit History;
2. **Reviews** — author-owned reviews and rebuildable public ratings.

Both use canonical IDs, actor-bound commands, revisions, idempotency,
privacy-safe projections and reversible migration.

### 3.2 Non-goals

BCK-12 does not own catalog publication/ranking, identity, Booking attendance
truth, reports/sanctions/appeals, media, notifications, staff tooling, payments,
rewards, creator replies or automatic Visit History.

## 4. Scope

### 4.1 In scope

- add/remove/list Favorites;
- explicit Place-only self-reported Visit History;
- disabled-by-default future confirmed-attendance boundary;
- review draft/submit/edit/author-removal lifecycle;
- typed BCK-22 enforcement handoff;
- public review and rating projections;
- offline/cache/retry, migration, DSR, abuse and rollback contracts.

### 4.2 Disabled until later gates

- production review submission and rating exposure;
- `attendanceConfirmed` and verified-visit badges;
- review incentives, replies, reactions or comments;
- public Favorites/Visit History;
- automatic local-to-cloud upload.

## 5. Ownership and single writers

| Record/projection | Authoritative writer | Consumers |
|---|---|---|
| Favorite | User Library command service | Owner/mobile |
| VisitRecord | User Library command service | Owner/mobile/DSR |
| AttendanceEvidence | Booking/provider verification domain | BCK-12 trusted consumer |
| Review | Reviews command service | Author/BCK-22/workers |
| PublicReviewProjection | Reviews projection worker | Discover/mobile |
| RatingAggregate | Reviews projection worker | BCK-08/Details |
| CatalogObjectRef | BCK-08 | BCK-12 consumer |
| User/public author identity | BCK-06 | BCK-12 consumer |
| Report/sanction/appeal | BCK-22 | Typed integration |

Clients, consoles and staff tools never write domain records directly. A
projection does not become authority over its source facts.

## 6. Actors and trust boundaries

| Actor | Allowed | Denied |
|---|---|---|
| Authenticated User | Own library/review commands | Foreign private library |
| Review author | Own draft/edit/remove under policy | Publish/moderation authority |
| Eligible Viewer | Public review/rating reads | Protected draft/notes |
| BCK-22 service | Typed enforcement instruction | Direct persistence write |
| Projection worker | Derived public projections | Source mutation |
| Support/Admin | BCK-19 audited workflow | Impersonation/direct write |

Consumer actions use the personal User principal. Page membership, Creator
status and Admin preview cannot impersonate a reviewer or library owner.

## 7. Canonical references and data classes

```text
CatalogObjectRef { contentTypeId, contentId }
```

This pair maps to BCK-08 catalog identity. Title, category, image, price and
route are cache snapshots, never identity.

| Record | Class | Public behavior |
|---|---|---|
| Favorite/VisitRecord | Protected/private | Never public by default |
| Review draft/moderation fields | Protected | Author/service only |
| Published review allowlist | Public | Sanitized projection only |
| Rating aggregate | Derived/Public | Revisioned/freshness-labelled |
| Idempotency/audit/outbox | Operational | Service/audited tool only |

Public output excludes email, exact private location, capabilities, raw
evidence, device IDs and private history.

## 8. User Library domain model

### 8.1 Favorite

```text
Favorite {
  favoriteId, ownerUserId, targetRef,
  savedAtUtc, sourceSurface?, recordRevision,
  createdAtUtc, updatedAtUtc
}
```

Uniqueness is `{ownerUserId, contentTypeId, contentId}`. Add/remove are idempotent.
Re-add never creates two active relations.

### 8.2 VisitRecord

```text
VisitRecord {
  visitId, ownerUserId, placeId,
  localDate, placeTimezoneId,
  evidence, evidenceRef?, recordedAtUtc, recordRevision
}
```

VIS-HIST-01 rules remain normative:

1. target is explicitly a Place; inference is forbidden;
2. date is today/past in the Place IANA timezone;
3. uniqueness is `{ownerUserId, placeId, localDate}`;
4. the same Place may appear on different dates;
5. only explicit confirmation creates `selfReported`;
6. view, Favorite, CTA, Booking, GPS, map, Route and Scenario never do;
7. self-report is not confirmed attendance or a verified-review badge;
8. removal is per record and owner-bound.

`attendanceConfirmed` is reserved. Only an Approved trusted source may upgrade
the same record after actor/place/date/timezone/replay validation. The client
cannot assert it.

## 9. Reviews domain model

### 9.1 Review

```text
Review {
  reviewId, authorUserId, targetRef,
  ratingValue, body?, bodyLocale?, lifecycle,
  eligibilitySnapshot { policyRevision, decision, evidenceKind? },
  moderationOverlayRef?, contentRevision,
  createdAtUtc, updatedAtUtc, submittedAtUtc?,
  publishedAtUtc?, removedAtUtc?
}
```

Candidate lifecycle:

```text
draft -> pendingReview -> published
                    \-> rejected
published -> pendingReview | hiddenByEnforcement | removedByAuthor
```

Exact states/direct moderation require `BCK12-OD-03`. Unknown/newer states
fail closed for mutation and public output.

### 9.2 PublicReviewProjection

Allowlisted only: review/target ID, rating, sanitized body, BCK-06 public author
projection and revision, published/edited times, safe badges, source/projection
revisions and intended visibility wording. Evidence, email, staff notes and case
details never enter it.

The projection must not preserve a stale public-author snapshot after Identity
withdraws that field or the account enters deletion. It applies the Accepted
Identity/Privacy outcome (a non-identifying removed-author label or hidden
review) and propagates the corresponding source revision; it never guesses or
leaks the prior profile.

### 9.3 RatingAggregate

```text
RatingAggregate {
  targetRef, scaleRevision, includedReviewCount,
  distributionByValue, averageScaled, scaleFactor, sourceWatermark,
  aggregateRevision, generatedAtUtc, freshness
}
```

`averageScaled` and `scaleFactor` encode the average with fixed-point integers
under an Accepted scale. Binary floating point is forbidden. Only currently
public eligible reviews contribute.

## 10. Review eligibility and product rules

Candidate rules pending owner acceptance:

- authenticated personal User and exact reviewable BCK-08 target;
- one active review per author/target; permanent review ID;
- required rating, optional sanitized text;
- no review of owned/published/administered object;
- BCK-06 server facts, never client role claims;
- self-reported Visit grants no verified badge;
- Favorite/Visit/Review lifecycles never implicitly mutate one another;
- incentives remain disabled without a future disclosure contract.

Scale, limits, edit window, target types and eligibility are blocking decisions.

## 11. Commands and authorization

| Command | Principal | Rule |
|---|---|---|
| `library.addFavorite` | Exact user | Validate target; idempotent relation |
| `library.removeFavorite` | Exact owner | Idempotent, anti-enumerating |
| `library.recordVisit` | Exact user | Explicit Place/date/timezone validation |
| `library.removeVisit` | Exact owner | One record only |
| `library.confirmAttendance` | Trusted service | Disabled by default |
| `reviews.createDraft` | Exact user | Permanent ID, private draft |
| `reviews.submit` | Exact author | Revalidate target/policy/revision |
| `reviews.edit` | Exact author | Expected revision/edit policy |
| `reviews.remove` | Exact author | Idempotent removal |
| `reviews.applyEnforcement` | BCK-22 service | Case/revision/idempotency |

Every mutation carries request ID, stable logical idempotency key, expected
revision where applicable, contract version and normalized payload hash.
Authorization is re-evaluated server-side at execution.

## 12. Queries and pagination

| Query | Visibility |
|---|---|
| `library.listFavorites` / `listVisits` | Exact owner |
| `reviews.getOwnReview` / `listOwnReviews` | Exact author |
| `reviews.listPublicForTarget` | Eligible viewer |
| `reviews.getRatingAggregate` | Same visibility as target |

Opaque cursors bind actor/scope, normalized query, limit and compatible
revision. Mismatch/expiry/version returns typed failure. Private denial is
anti-enumerating; public absence never reveals draft/rejection/case existence.

## 13. Catalog lifecycle and tombstones

- save requires an exact eligible target;
- archive/tombstone exposes only bounded `unavailable` to the owner;
- unavailable target rejects new review submission;
- public reviews disappear when target visibility no longer permits them;
- restoration requires the same canonical ID, never name matching;
- propagation is revisioned, replay-safe and observable.

## 14. Events and typed failures

Events include favorite/visit add/remove, evidence upgrade, review submitted/
published/updated/removed/visibility changed and rating aggregate updated.
Each carries stable ID, aggregate ID/revision, actor/service, UTC time, schema,
correlation/causation IDs and privacy-safe payload. Events are facts, not patches.

Typed failures include `unauthenticated`, `permission_denied`, `not_found`,
`invalid_argument`, `unsupported_contract`, `unsupported_target_type`,
`target_unavailable`, `target_not_reviewable`, `self_review_forbidden`,
`future_visit_date`, `invalid_place_timezone`, `visit_evidence_untrusted`,
`review_already_exists`, `review_policy_blocked`, `content_rejected`,
`stale_revision`, `idempotency_conflict`, `conflict`, `rate_limited`,
`temporarily_unavailable`, `dependency_unavailable`, `cursor_invalid`,
`cursor_expired`, `cancelled` and `unknown_outcome`.

Cancellation is neither success nor domain failure. Unknown outcome requires
receipt reconciliation before retry.

## 15. Contract versioning and compatibility

- BCK-03 envelopes and typed failures;
- unknown schema/enum is opaque and mutation-fail-closed;
- additive safe reads may be ignored by compatible clients;
- semantic/requiredness/scale/state changes require a new version;
- rating declares scale and aggregate revision;
- server controls minimum supported client;
- older clients never downgrade newer cached records.

## 16. Persistence, indexes and atomicity

Exact Firestore topology is deferred. Runtime must preserve actor-scoped
private queries, unique favorite/visit-day/active-review constraints, atomic
source mutation plus outbox/audit/receipt, bounded transactions, rebuildable
projections, reviewed indexes and service-only counters/projections.

Rating may be eventually consistent but exposes watermark, revision, generated
time and freshness. Rebuild/replay converges deterministically.

## 17. IDs, time, idempotency and concurrency

- permanent ULID/UUID IDs and ID-only relations;
- backend time for lifecycle/audit ordering;
- Visit date interpreted in Place IANA timezone;
- BCK-20 DST/calendar semantics;
- same key/hash returns prior receipt;
- same key/different hash mutates nothing;
- expected revision prevents blind overwrite;
- concurrent submissions preserve one active review;
- out-of-order events reconcile by source revision.

## 18. Offline, multi-device and cache

- Favorite/self-reported Visit may be explicit pending local commands under
  BCK-18, never remote-confirmed truth;
- Review draft may be local; submit/edit/remove needs online authority;
- UI distinguishes local-only/syncing/confirmed/failed/conflict;
- offline never upgrades evidence or visibility;
- server revision drives multi-device reconciliation;
- public cache retains target/projection revision/freshness;
- sign-out clears account-scoped decrypted cache;
- retry keeps logical idempotency and payload.

## 19. Migration and cutover

### 19.1 Favorites

Current Favorites are screen-oriented snapshots with category strings,
`targetRoute` and binary floating values. Migration requires inventory,
resolvable/ambiguous/unsupported classification, exact BCK-08 ID mapping,
user-visible dry run/choice, per-item idempotency/checkpoint and no guessing.

### 19.2 Visit History

Owner-scoped v2 self-reports may be offered for explicit import after exact
Place/date/timezone validation and remain `selfReported`. Legacy
`visited_places_v1_*` seeded demo data is permanently non-importable.

### 19.3 Reviews

No authoritative runtime exists. Demo/fixture/screenshot/UI content is never
migrated. Cutover begins empty absent a separately audited legitimate source.

Rollback disables new remote mutations without deleting confirmed server truth
or restoring stale local authority.

## 20. Privacy, consent, retention and DSR

Purposes are separate: library convenience, self-reported history, public
review, abuse prevention and audit. Bundled consent is forbidden.

| Family | Lifecycle rule | Blocker |
|---|---|---|
| Favorite | Until removal/account deletion | Propagation contract |
| VisitRecord | Until removal/account deletion | Legal basis/retention |
| Review draft | Until submit/remove/account policy | Terminal retention |
| Published Review | While published/lawfully retained | Erasure/anonymization |
| RatingAggregate | Rebuildable from eligible reviews | Source deletion |
| Receipt/audit | Minimal operational evidence | Numeric retention |

BCK-04 provides no generic numeric default. Production waits for Accepted
values, triggers, lawful bases, exceptions and deletion/anonymization actions.

DSR export separates authored public reviews from private library data and
excludes other users, staff notes and secrets. Restriction/deletion propagates
to public projections, ratings, caches and indexes. Backup restore cannot
resurrect logically deleted active records.

## 21. Security, moderation and abuse controls

- server-derived actor/ownership and default deny;
- service-only projection writes and anti-enumeration;
- Unicode/text validation and output-safe rendering;
- bounded body/command/query sizes and rate limits;
- spam/coordinated-abuse signals routed to BCK-22;
- no opaque automatic sanction from rating alone;
- BCK-06 public author projection;
- BCK-19 case/reason/audit for staff access;
- no review body/private history in logs or metrics.

BCK-12 owns Review transitions. BCK-22 owns enforcement decisions and sends a
typed authorized instruction. Neither writes the other's source records.

## 22. Observability, SLO, analytics and cost

Signals cover command/idempotency/unknown outcomes, projection lag/divergence,
cursor/cache freshness, invalid visit/evidence attempts, moderation queue age,
tombstone and DSR propagation, privacy-safe migration counts, storage/index/
read/write volume and cost. Exact SLOs, alerts and budgets require BCK-05.
Review bodies, Favorite lists and Visit dates are not analytics payloads.

## 23. Flags, rollout and rollback

Separate flags control remote Favorites, remote Visits, review mutations,
public reviews, ratings, attendance confirmation and per-family import. Flags
are environment/market/cohort/version scoped, default off, audited and do not
grant authority. Rollback preserves source truth, receipts and audit.

## 24. Dependency and delivery gates

| Gate | Requirement | Effect |
|---|---|---|
| Documentation Review | Compatible dependencies; decisions assigned | Review only |
| Approval | Qualified verdicts and decisions closed/deferred safely | No runtime |
| R4 Library | BCK-12 Approved; IAM/Rules/contracts/evidence | Library candidate |
| R8 Reviews/T&S | BCK-12/BCK-22 Approved; relevant legal policy | Reviews candidate |
| Latvia production | Privacy/residency/retention/DSR/abuse evidence | Cohort before GA |

Reviews runtime waits for BCK-03/04/05/06/08/18 and BCK-22 compatibility.
Library may be gated independently, but production personal-data processing
still requires privacy, identity and platform readiness.

## 25. Conditional exact file map

No path below is authorized by this Review:

```text
apps/backend/src/modules/user_library/
  domain/{favorite,visit_record,library_failures}.ts
  application/{add_favorite,remove_favorite,record_visit,remove_visit,confirm_attendance,list_library}.ts
  infrastructure/{library_repository,library_projection_consumer}.ts
  transport/{library_commands,library_queries}.ts
apps/backend/src/modules/reviews/
  domain/{review,review_policy,rating_aggregate,review_failures}.ts
  application/{create_review_draft,submit_review,edit_review,remove_review,apply_review_enforcement,rebuild_rating_aggregate}.ts
  infrastructure/{review_repository,public_review_projection,rating_projection}.ts
  transport/{review_commands,review_queries}.ts
apps/backend/test/modules/{user_library,reviews}/
packages/api_contracts/schemas/{user_library,reviews}/v1/
packages/api_contracts/fixtures/{user_library,reviews}/v1/
```

Exact language, paths, collections and indexes require an Approved runtime
slice and fresh repository audit.

## 26. Test and evidence matrix

| Area | Evidence |
|---|---|
| Ownership | Foreign denial and anti-enumeration |
| Favorites | Add/remove/re-add/idempotency/tombstone/multi-device |
| Visits | Explicit Place/date/timezone/day uniqueness/removal |
| Passive signals | View/Favorite/Booking/GPS/map/Route/Scenario never create Visit |
| Evidence | Client confirmation denied; trusted replay denied |
| Reviews | Create/submit/edit/remove/uniqueness/self-review denial |
| Moderation | BCK-22 authorization/revision/replay/projection removal |
| Rating | Distribution/fixed-point/rebuild/order/delete divergence |
| Contracts | Valid/invalid/forward fixtures and failures |
| Offline | Pending/confirmed/conflict/unknown outcome/stable retry |
| Migration | Dry run/ambiguity/v1 seed exclusion/checkpoint/rollback |
| Privacy | Export/delete/restrict/cache/index/backup propagation |
| Operations | Rate/load/lag/alert/cost |
| Emulator | Default deny/Rules/service writers/index/transaction |
| Two device | Concurrent favorite/review and reconciliation |

Fixtures are synthetic only.

## 27. Definition of Ready

Review DoR requires 22/22 coverage, separate aggregates, single writers,
preserved VIS-HIST-01, honest runtime/migration facts, sequential AC and owned
fail-closed decisions. v0.2 meets documentation DoR only; qualified verdicts,
contracts, privacy values and executable evidence remain absent.

## 28. Definition of Done

Implementation Done requires Approved decisions/spec, contracts/fixtures,
backend/security/mobile runtime, emulator Rules/index/transaction/replay tests,
migration/rollback, DSR/retention/rating rebuild, SLO/cost, two-device/degraded
tests, Latvia cohort evidence and synchronized status registries.

## 29. Acceptance criteria

1. **BCK-12-AC-01:** BCK-12 remains Review/docs-only until Approval.
2. **BCK-12-AC-02:** Runtime and production processing remain Absent.
3. **BCK-12-AC-03:** User Library and Reviews are separate aggregates.
4. **BCK-12-AC-04:** Every source record has one writer.
5. **BCK-12-AC-05:** BCK-22 owns reports/sanctions/appeals/block/mute.
6. **BCK-12-AC-06:** BCK-08 owns catalog identity/visibility.
7. **BCK-12-AC-07:** BCK-06 owns actor/public-author identity.
8. **BCK-12-AC-08:** Library records are private by default.
9. **BCK-12-AC-09:** Library identity is typed object type plus ID.
10. **BCK-12-AC-10:** Snapshot text/route/category is never identity.
11. **BCK-12-AC-11:** Favorite uniqueness is owner plus target.
12. **BCK-12-AC-12:** Favorite add/remove/retry is idempotent.
13. **BCK-12-AC-13:** Visit History is Place-only and explicit.
14. **BCK-12-AC-14:** Passive/product signals create no Visit.
15. **BCK-12-AC-15:** Visit date uses the Place IANA timezone.
16. **BCK-12-AC-16:** Future Visit dates are rejected.
17. **BCK-12-AC-17:** Visit uniqueness is owner/place/local date.
18. **BCK-12-AC-18:** Same Place may have different visit dates.
19. **BCK-12-AC-19:** Self-report is not confirmed attendance.
20. **BCK-12-AC-20:** Only trusted server authority confirms attendance.
21. **BCK-12-AC-21:** Review commands use personal User principal.
22. **BCK-12-AC-22:** Page/Creator/Admin preview cannot impersonate reviewer.
23. **BCK-12-AC-23:** Review target is exact/active/reviewable.
24. **BCK-12-AC-24:** One active review exists per author/target.
25. **BCK-12-AC-25:** Self-owned/administered review fails closed.
26. **BCK-12-AC-26:** Rating is required under a versioned scale.
27. **BCK-12-AC-27:** Review text is optional/bounded/sanitized.
28. **BCK-12-AC-28:** Mutation revalidates policy/revision.
29. **BCK-12-AC-29:** Unknown lifecycle is not publicly exposed.
30. **BCK-12-AC-30:** Public review is allowlist-only.
31. **BCK-12-AC-31:** Public author data comes from BCK-06.
32. **BCK-12-AC-32:** Enforcement comes from BCK-22 typed command.
33. **BCK-12-AC-33:** Staff never directly writes BCK-12 records.
34. **BCK-12-AC-34:** Rating includes public eligible reviews only.
35. **BCK-12-AC-35:** Rating average uses fixed-point integers.
36. **BCK-12-AC-36:** Rating rebuild is deterministic.
37. **BCK-12-AC-37:** Rating carries watermark/revision/freshness.
38. **BCK-12-AC-38:** Hidden/removed review propagates downstream.
39. **BCK-12-AC-39:** Cursor binds scope/query/revision.
40. **BCK-12-AC-40:** Private denial is anti-enumerating.
41. **BCK-12-AC-41:** Mutation carries request/idempotency/contract identity.
42. **BCK-12-AC-42:** Same key/different payload mutates nothing.
43. **BCK-12-AC-43:** Unknown outcome reconciles before retry.
44. **BCK-12-AC-44:** Offline state is not server authority.
45. **BCK-12-AC-45:** Multi-device conflict is explicit.
46. **BCK-12-AC-46:** Favorite migration uses exact ID mapping.
47. **BCK-12-AC-47:** Favorite import has dry-run/choice/checkpoint.
48. **BCK-12-AC-48:** Visit v2 import preserves self-report.
49. **BCK-12-AC-49:** Visit v1 demo seed is never imported.
50. **BCK-12-AC-50:** Demo/fixture reviews are never production data.
51. **BCK-12-AC-51:** Retention is per family without invented default.
52. **BCK-12-AC-52:** DSR separates private library/public reviews.
53. **BCK-12-AC-53:** Deletion/restriction propagates downstream.
54. **BCK-12-AC-54:** Backup cannot reactivate deleted records.
55. **BCK-12-AC-55:** Logs exclude review body/private history.
56. **BCK-12-AC-56:** Abuse signals create no opaque auto-sanction.
57. **BCK-12-AC-57:** Flags separate Library/Reviews/ratings/attendance.
58. **BCK-12-AC-58:** Rollback preserves source truth/receipts.
59. **BCK-12-AC-59:** Runtime needs contract/Rules/emulator/device evidence.
60. **BCK-12-AC-60:** Registries separate docs/runtime/deployment.

## 30. Explicit unimplemented list

Absent: backend modules; Firestore/Rules/indexes; schemas/fixtures/DTOs;
authoritative repositories; review/rating workers; attendance integration;
BCK-22 runtime handoff; DSR/retention workers; import pipeline; production flags,
dashboards, runbooks, deployment and remote mobile adapter. Favorites and Visit
History remain local/mock; Reviews backend remains absent.

## 31. Owner decisions required

| ID | Owner | Decision | Fail-closed default |
|---|---|---|---|
| `BCK12-OD-01` | Product + Reviews | Scale, text/locale limits, edit policy | Submission off |
| `BCK12-OD-02` | Product + Identity | Target types and self/page exclusion | Unsupported denied |
| `BCK12-OD-03` | Reviews + T&S | Lifecycle/moderation/visibility | Public projection off |
| `BCK12-OD-04` | Booking/Provider + Product | Trusted attendance/badge | Confirmation off |
| `BCK12-OD-05` | Legal/Privacy + Security | Legal basis/retention/DSR | Processing off |
| `BCK12-OD-06` | Mobile + Data owners | Import/disclosure/rollback | Auto-import forbidden |
| `BCK12-OD-07` | Reviews + Discover + Ops | Rating consistency/freshness/SLO | Rating off |
| `BCK12-OD-08` | Product + Discover | Favorite scope/tombstone UX | Exact supported public only |
| `BCK12-OD-09` | Security + T&S + Ops | Abuse/rate/enforcement | Conservative/no auto-sanction |
| `BCK12-OD-10` | Legal + Product | Markets/minors/incentives | Sensitive paths off |

Each decision needs a versioned record, owner verdict, date, controls, gates,
rollout and rollback. Listing it here is not acceptance.

## 32. Final statement

BCK-12 v0.2 provides a coherent privacy-safe target without converting local
demo state into cloud truth. It is ready for owner contradiction review, not
implementation, provisioning, deployment or production processing.
