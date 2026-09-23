# Recharge Backend — Planning: Scenario & Quick Plan Specification

- ID: **BCK-10**
- Version: **0.3.1**
- Date: **2026-09-21**
- Spec status: **Draft — Present; owner and cross-boundary review pending**
- Runtime status: **Absent — local/mobile implementation is compatibility input only**
- Accountable owner: **Planning owner**
- Coordination baseline: [BCK-02 v2.4.82](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Delivery stage: **D4 / R7**

## 0. Changelog

### v0.3.1 — 2026-09-21

- normalized Scenario publication and planned-transport enum values to the
  BCK-03 lowerCamelCase rule;
- preserved lifecycle meaning, writers, Draft status and all runtime gates.

### v0.3 — 2026-09-21

- completed the Stage 5 Scenario/Quick Plan sync, conflict, collaboration,
  publication and privacy boundaries;
- preserved Scenario, Quick Plan and Route as distinct aggregates and made
  one-way expansion create an independent Scenario;
- added typed sync receipts, rollback and market-gated publication without
  authorizing persistence or Firebase runtime.

### v0.2 — 2026-09-20

- added the Stage 2 normalized Planning entity inventory;
- fixed separate writers/lifecycles for Scenario and Quick Plan and preserved
  Route/Content/Discover boundaries;
- added explicit security, retention, migration, rollback, flag and evidence normalization.

### v0.1 — 2026-09-20

- created the first canonical backend contract for Scenario and Quick Plan;
- preserved `Route != Scenario != Quick Plan` and separate aggregate ownership;
- defined revisioned sync, collaboration, sharing, publication and one-way
  `Expand to Scenario` semantics;
- added fail-closed Baltic market, privacy, moderation, migration and rollout
  gates without authorizing Firebase or runtime work.

## 1. Verdict and status semantics

This document is the canonical BCK-10 design input, not runtime evidence and
not an activation decision. `Draft` means that all requirements below are
normative for review, while unresolved owner decisions and parent approvals
still block `Approved` and every persistent backend implementation slice.

The current local Scenario/Quick Plan behavior proves product intent only. It
does not prove remote authorization, multi-device conflict handling,
collaboration, publication, migration, retention or production readiness.

## 2. Parents, priority and reconciliation

BCK-10 inherits without silently overriding:

1. Accepted ADRs and the frozen
   [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md);
2. [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md) architecture and
   [BCK-02](RECHARGE_BACKEND_DELIVERY_MAP.md) coordination;
3. [BCK-03](BACKEND_API_CONTRACT_STANDARD.md),
   [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md),
   [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md),
   [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md),
   [BCK-07](CONTENT_PUBLICATION_BACKEND_SPEC.md),
   [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md) and
   [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md);
4. [Scenario Builder](SCENARIO_BUILDER_SPEC.md) and
   [Connected Planning](SCENARIO_CONNECTED_PLANNING_SPEC.md) product contracts;
5. implementation notes and local/mock behavior.

Once Approved, BCK-10 is the owning-domain specification for Planning, but it
still cannot override an Accepted ADR or an Accepted cross-cutting policy.

Mandatory inherited constraints:

- identifiers are immutable ULID/UUID-style IDs and relations use IDs only;
- server mutations use authenticated actor context, capability checks,
  idempotency and typed outcomes;
- Scenario publication uses BCK-07; public projections are not source records;
- localization, market, currency and timezone values use BCK-20 references;
- mobile import/sync uses BCK-18 and never uploads local state silently;
- event/outbox delivery remains disabled until OD-09 is Accepted for the path.

## 3. Outcome and non-goals

### 3.1 Outcome

BCK-10 defines one backend module with two deliberately separate aggregates:

- **Scenario** — a personal, unlisted or public city/day/weekend/trip plan with
  days, independent stops, logistics, alternatives and typed snapshots;
- **Quick Plan** — a lightweight private/invited/unlisted utility plan for a
  bounded short period, without publisher or catalog lifecycle.

The measurable result is a reviewable contract for authoritative revisions,
access, sync, share, publication handoff, conversion and rollback.

### 3.2 Non-goals

BCK-10 does not own:

- Route geometry, GPX, anchors, segments or elevation;
- catalog object truth, Booking, payments or provider inventory;
- live transport truth or automatic optimization authority;
- media blobs, identity records, moderation sanctions or notifications;
- chat, comments, live cursors or anonymous collaborative editing;
- runtime code, Firebase resources, deployment or market activation.

## 4. Scope

### 4.1 In scope

- Scenario create/save/copy/archive and immutable revision history;
- private, unlisted and public-template lifecycle;
- Quick Plan create/save/invite/share/archive;
- owner/editor/read-only-collaborator access grants and revocation;
- optimistic concurrency and deterministic conflict responses;
- explicit one-way Quick Plan expansion into a new Scenario;
- typed catalog/custom/time-block/planned-transport snapshots;
- multi-market and multi-timezone validation;
- publication/moderation handoff and projection freshness;
- local-to-cloud import contract, rollback and DSR behavior.

### 4.2 Disabled until later gates

- production sync, collaboration and public publication;
- anonymous access other than revocable unlisted-token read;
- automatic local-draft upload;
- live provider planning, fares, booking or payment;
- AI-generated persistence without normal typed validation and explicit save;
- public Quick Plan and reverse Scenario-to-Quick-Plan synchronization.

## 5. Aggregate ownership and single writers

| Record/projection | Authoritative writer | Consumers |
|---|---|---|
| `ScenarioRecord` / current revision pointer | Scenario command service | Owner/mobile/workers |
| `ScenarioRevision` | Scenario command service | Owner/collaborators/publication |
| `ScenarioAccessGrant` | Scenario access service | Authorization/mobile/audit |
| `ScenarioShareToken` | Scenario sharing service | Unlisted read adapter |
| `QuickPlanRecord` / revision | Quick Plan command service | Owner/invitees/mobile |
| `QuickPlanAccessGrant` | Quick Plan access service | Authorization/mobile/audit |
| `PlanningExpansionReceipt` | Planning conversion service | Owner/support/audit |
| Public Scenario content/revision | BCK-07 | BCK-08/mobile |
| Catalog object identity/snapshot source | BCK-08/BCK-07 | BCK-10 consumer |
| Route | BCK-11 | Scenario stores a bounded reference snapshot only |
| User/Page/capability identity | BCK-06 | BCK-10 consumer |
| Sanction/report/appeal | BCK-22 | Typed enforcement consumer |

No client, console, projection worker or Admin tool writes Planning aggregates
directly. BCK-19 repair executes a registered BCK-10 command.

## 6. Actors, authorization and revocation

| Actor | Allowed | Denied |
|---|---|---|
| Authenticated User | Own private Planning records | Foreign records |
| Scenario owner | Edit, invite, share, archive, request publication | Silent publisher impersonation |
| Scenario editor | Edit accepted scope | Access grants, publication, ownership transfer |
| Scenario read-only collaborator | Read accepted scope | Mutation |
| Quick Plan owner | Edit/invite/revoke/share/expand | Public catalog publication |
| Quick Plan invitee | Read or edit according to grant | Expand as owner, re-share unless allowed |
| Verified Creator/Page member | Publish Scenario through BCK-07 capability | Publish Quick Plan |
| Projection worker | Build derived projections | Source mutation |
| Support/Admin | Audited BCK-19 workflow | Direct persistence or impersonation |

Revocation is evaluated on every protected command and authoritative read. A
cached grant cannot extend access after server revocation. Revoking a share
token invalidates future token reads; already exported user-controlled copies
are outside that token's reach and must be represented honestly.

## 7. Data classes and projections

| Data | Class | Projection rule |
|---|---|---|
| Private Scenario/Quick Plan content | Private | Owner/grantee only |
| Access grants, invite identity, share-token hash | Restricted | Service/audit only |
| Custom notes and precise private coordinates | Private/Sensitive | Never public by default |
| Public Scenario revision allowlist | Public | Only accepted BCK-07 revision |
| Catalog/Route snapshots | Derived | Source ID/revision/freshness retained |
| Idempotency, outbox and audit records | Operational | No product projection |

Public output excludes invitees, private notes, exact private lodging data,
raw access tokens, device IDs, unpublished alternatives and author telemetry.

## 8. Canonical domain model

```text
ScenarioRecord {
  scenarioId, ownerUserId, publisherRef?, status, visibility,
  currentRevisionId, publishedRevisionId?, revision, createdAtUtc,
  updatedAtUtc, archivedAtUtc?
}

ScenarioRevision {
  scenarioRevisionId, scenarioId, revisionNumber, schemaVersion,
  title, description?, marketRefs[], locale, startDate?, endDate?,
  timezoneRefs[], days[], logistics[], budgetSummary?, source,
  contentHash, createdByUserId, createdAtUtc
}

ScenarioAccessGrant {
  grantId, scenarioId, subjectUserId, role, status,
  grantedByUserId, grantedAtUtc, revokedAtUtc?, revision
}

QuickPlanRecord {
  quickPlanId, ownerUserId, status, visibility,
  currentRevisionId, revision, localDate, timezoneId,
  createdAtUtc, updatedAtUtc, archivedAtUtc?
}

QuickPlanRevision {
  quickPlanRevisionId, quickPlanId, revisionNumber, schemaVersion,
  title?, stops[], startAt?, endAt?, contentHash,
  createdByUserId, createdAtUtc
}

PlanningExpansionReceipt {
  expansionId, sourceQuickPlanId, sourceRevisionId, targetScenarioId,
  copiedItemIds[], omittedItemCodes[], actorUserId, createdAtUtc
}
```

Scenario and Quick Plan IDs never overlap semantically. A conversion creates a
new Scenario ID and immutable receipt; neither record stores a live reverse
sync pointer. A Route item stores `routeId`, accepted revision/snapshot fields
and freshness, never GPX or Route-owned geometry.

## 9. Lifecycle and invariants

Scenario persisted lifecycle follows the canonical product contract and keeps
visibility separate:

```text
draft -> pendingReview -> published -> archived
  ^           |              |
  |           v              v
  +-------- rejected       hidden

deleted — soft-delete terminal state until retention cleanup
```

`rejected` is a moderation outcome returning an editable revision to `draft`,
not a persisted lifecycle value. `private | unlisted | public` is visibility,
not lifecycle. Editing a published Scenario creates a new draft revision while
the last accepted revision stays public until an atomic BCK-07 switch.

Quick Plan lifecycle:

```text
draft -> active -> archived
```

Its visibility is `private | invited | unlisted`; `public` is invalid.

Invariants:

1. Scenario, Quick Plan and Route are separate aggregates.
2. Public Scenario is an itinerary template, not Event occurrence or capacity.
3. Quick Plan has no publisher, Discover card, reviews or catalog projection.
4. A published Scenario points to one immutable accepted revision.
5. Draft edits never mutate the published revision.
6. Cross-market content retains actual market/timezone references per item.
7. Planned transport is labelled `notLive` unless BCK-16 proves freshness.
8. Conversion is explicit, idempotent and one-way.

## 10. Commands, queries and typed outcomes

Commands:

- `CreateScenario`, `SaveScenarioRevision`, `ArchiveScenario`;
- `CreateScenarioFromTemplate`, `RequestScenarioPublication`;
- `InviteScenarioCollaborator`, `ChangeScenarioRole`, `RevokeScenarioGrant`;
- `CreateScenarioShare`, `RevokeScenarioShare`;
- `CreateQuickPlan`, `SaveQuickPlanRevision`, `ArchiveQuickPlan`;
- `InviteQuickPlanParticipant`, `RevokeQuickPlanGrant`;
- `CreateQuickPlanShare`, `RevokeQuickPlanShare`;
- `ExpandQuickPlanToScenario`.

Queries:

- owner/grantee Planning lists with cursor pagination;
- current record plus authorized revision;
- immutable revision history for authorized actors;
- share-token resolution with minimized output;
- publication/status receipt and conflict details.

Typed failures include:

```text
unauthenticated, permission_denied, not_found, archived,
revision_conflict, operation_in_progress, idempotency_conflict,
invalid_visibility, invalid_transition, grant_revoked, token_invalid,
token_expired, market_disabled, reference_unavailable,
publication_blocked, moderation_required, policy_blocked,
payload_too_large, rate_limited, temporarily_unavailable
```

Not-found and permission behavior follows BCK-04 anti-enumeration policy.

## 11. Contract versions and compatibility

Every command carries `contractVersion`, `schemaVersion`, `operationId` and
expected aggregate revision where mutation of an existing record occurs.
Responses use the BCK-03 envelope and expose `serverRevision`.

Additive optional fields may be introduced inside a supported version. Meaning,
requiredness, enum removal, ID semantics or lifecycle changes require a new
version plus migration and minimum-client evidence. Unsupported newer versions
fail closed; they are never partially interpreted.

## 12. Persistence, indexes and transaction boundaries

Logical stores are separate for Scenario records/revisions/grants/shares and
Quick Plan records/revisions/grants/shares. Required query dimensions are
owner/grantee, status, updated time and stable ID. Token lookup uses only a
salted/peppered hash according to BCK-04; raw tokens are never persisted.

One transaction commits:

- current revision pointer plus immutable revision;
- access change plus audit;
- share-token state plus audit;
- conversion receipt plus new Scenario initial revision;
- source state plus outbox entry when OD-09 is enabled.

Publication itself is a BCK-07 transaction/handoff, not a direct BCK-10 write
to catalog collections.

## 13. IDs, time, reference data and money

- permanent IDs are server-issued immutable ULID/UUID-style IDs;
- `loc_*` identifiers are import-only temporary IDs and require explicit map;
- instants use UTC; local calendar values carry an IANA timezone ID;
- timezone/date interpretation uses the item's/place's accepted timezone;
- market, locale, currency and taxonomy references use BCK-20 revisions;
- money uses integer minor units plus ISO currency, never floating point;
- catalog references are typed `{objectType, objectId, sourceRevision?}`.

## 14. Idempotency, concurrency and partial failure

Mutation idempotency is scoped to actor, command family and aggregate target.
Reusing a key with a different canonical request hash returns
`idempotency_conflict`. Optimistic concurrency uses expected revision; the
server never silently applies last-write-wins to ordered days/stops/logistics.

Batch materialization is atomic for one aggregate. If a referenced item cannot
be resolved, the command returns typed item outcomes without committing a
partial revision unless the command explicitly supports an accepted subset and
the user confirmed that subset. Conversion never creates a Scenario without a
durable receipt, and retry returns the same target ID.

## 15. Offline, cache and degraded behavior

Mobile may keep encrypted owner-scoped drafts and read caches under BCK-18.
Cached access is labelled with revision/freshness and does not authorize a
remote mutation. Reconnect performs explicit compare/rebase/replace/copy flows;
no hidden merge reorders user content.

When catalog, Route or provider data is unavailable, saved snapshots remain
readable with `stale`/`notLive` labels. Publication, share creation and access
changes fail closed when authority cannot be checked. Local editing may
continue without claiming server save.

## 16. Migration and local-to-cloud import

Import requires explicit user action, authenticated ownership, dry-run,
stable local-to-server ID mapping and per-record result. It never treats local
publisher/admin flags as authority. Legacy `quickPlan` Create taxonomy values
are read-compatible input, not a public eleventh Create type.

Duplicate candidates produce a user-visible decision; names are never identity.
Rollback disables new import and preserves receipts/mappings for safe retry.
An imported Quick Plan remains Quick Plan unless the owner separately expands
it to Scenario.

## 17. Events, outbox and deduplication

After Accepted OD-09 and an approved runtime slice, minimized events may include:

- `planning.scenarioCreated`, `planning.scenarioRevisionSaved`;
- `planning.scenarioAccessChanged`, `planning.scenarioArchived`;
- `planning.scenarioPublicationRequested`;
- `planning.quickPlanCreated`, `planning.quickPlanRevisionSaved`;
- `planning.quickPlanAccessChanged`, `planning.quickPlanArchived`;
- `planning.quickPlanExpanded`.

Events contain stable IDs, revisions and event IDs, not private content. Outbox
write is atomic with the source change. Consumers dedupe by event ID and
reconcile from source revision; replay does not repeat notifications or
publication commands. Until OD-09 acceptance, async effects remain disabled.

## 18. Privacy, consent, retention and DSR

Planning can reveal movements, interests, companions, dates and precise
locations. Data minimization and purpose limitation apply before persistence
and public projection. Private custom coordinates, lodging notes and invitee
identity require restricted access and must not enter analytics.

DSR export separates Scenario, Quick Plan, grants, shares and conversion
receipts. Erasure/restriction honors legal/security/audit exceptions defined by
BCK-04, revokes active shares and removes public projection through BCK-07.
Numeric retention is not invented here: the BCK-04 data inventory and qualified
review must accept it before production persistence.

## 19. Abuse, rate limits and fraud controls

Controls apply to create/save, invite, token issuance/resolution, publication
requests, imports and conversions. Limits are actor/account/device/risk aware;
App Check is only one signal and never replaces authorization. Token probing,
invite spam, mass-copy, malicious links and publication abuse produce bounded
security signals without storing raw content in logs.

BCK-22 sanctions can deny share/publication or hide a public projection through
typed commands. They do not mutate private source revisions silently.

## 20. Observability, SLO, analytics and cost

Operational telemetry includes latency, typed outcome, conflict rate, retry
rate, stale-reference rate, invite/token abuse, projection lag and outbox lag.
Logs exclude titles, notes, coordinates, tokens, invitee identity and full
payloads. Product analytics is a separate BCK-21 path with consent and cataloged
events.

SLOs and numeric budgets are accepted under BCK-05 before persistent stage.
Cost controls bound revision growth, grants, shares, payload size, list page
size and projection fanout. A high-cost dependency can be disabled without
blocking owner access to saved content.

## 21. Flags, rollout, rollback and emergency disable

Minimum server-owned flags:

- Scenario remote save, collaboration, unlisted share and publication;
- Quick Plan remote save, invites, unlisted share and expansion;
- local import and each market's public projection.

All default off until their exact slice gate passes. Rollback disables new
mutations/effects while keeping owner reads/export available where safe.
Emergency disable may revoke token resolution or publication independently;
it never deletes source data or silently downgrades visibility.

## 22. Conditional implementation file map

No file below is authorized by this document alone. An Approved executable
slice may create:

```text
packages/api_contracts/schemas/planning/
packages/api_contracts/fixtures/planning/
apps/backend/functions/src/modules/planning/domain/
apps/backend/functions/src/modules/planning/application/
apps/backend/functions/src/modules/planning/data/
apps/backend/functions/src/modules/planning/transport/
apps/backend/functions/test/contract/planning/
apps/backend/functions/test/emulator/planning/
apps/mobile/lib/features/scenario/data/remote/
apps/mobile/lib/features/quick_plan/data/remote/
```

Generated files are changed only through their generator. Scenario and Quick
Plan remain separate submodules/contracts even if they share infrastructure.

## 23. Test and evidence matrix

| Area | Required evidence |
|---|---|
| Domain | lifecycle, visibility, invariants, money/time/reference validation |
| Contract | schema/fixture parity, unknown enum/version fail-closed |
| Authorization | owner/editor/read-only-collaborator/invite/token/revocation matrix |
| Concurrency | stale revision, idempotent retry, hash mismatch, conflict copy |
| Conversion | retry returns same Scenario; no live link; omission receipt |
| Privacy | public allowlist, token hashing, log/analytics redaction, DSR |
| Emulator | transactions, indexes, Rules/IAM, projection/outbox atomicity |
| Resilience | offline/reconnect, stale dependencies, worker replay/poison |
| Migration | dry-run, ID map, legacy Quick Plan, duplicate and rollback |
| Baltic | LV/EE/LT timezone/locale/currency and cross-market visibility |
| Load/cost | revisions, collaboration fanout, token abuse and page bounds |
| End-to-end | private edit, invite/revoke, share/revoke, publish, expand |

Unrun, timed-out or environment-blocked checks are `Inconclusive`, never Pass.

## 24. Dependency and delivery gates

`Approved` requires approved applicable BCK-03/04/06/07/18/20 boundaries,
closed Planning owner decisions and cross-boundary Security/Privacy/Mobile
review. Runtime requires R7 entry, explicit executable slice authorization,
green contract/emulator/security suites and market flags default-off.

Public Scenario additionally requires BCK-22/OD-06 when UGC controls apply.
Age-sensitive content requires accepted OD-11. Provider-backed freshness uses
BCK-16; notifications use BCK-13; neither is silently required for core save.

## 25. Definition of Ready

BCK-10 is ready for owner review when:

- all parent versions and conflicts are reconciled;
- aggregate ownership and Quick Plan separation are accepted;
- data inventory/retention owners are assigned;
- publication, share and conversion contracts have named reviewers;
- every open decision has owner, fail-closed default and target gate.

## 26. Definition of Done

BCK-10 becomes `Approved` only when:

- required owner/cross-boundary verdicts are attributable and current;
- all blocking decisions are accepted or explicitly removed from scope;
- contracts and exact slices are identified without authorizing runtime;
- AC are traceable to tests/evidence;
- BCK-01, BCK-02 and LAUNCH_STATUS are reconciled atomically.

Runtime Done is separate and additionally requires implementation, green gates,
deployment evidence, rollback proof and explicit activation authority.

## 27. Acceptance criteria

1. **BCK-10-AC-01:** Scenario, Quick Plan and Route remain separate aggregates.
2. **BCK-10-AC-02:** Quick Plan has no public visibility or catalog projection.
3. **BCK-10-AC-03:** Scenario supports private, unlisted and public visibility.
4. **BCK-10-AC-04:** Published Scenario points to one immutable accepted revision.
5. **BCK-10-AC-05:** Draft edits never mutate a published revision.
6. **BCK-10-AC-06:** Every aggregate relation uses immutable typed IDs.
7. **BCK-10-AC-07:** Route references never copy GPX/segments into Scenario.
8. **BCK-10-AC-08:** Quick Plan expansion creates a new Scenario ID.
9. **BCK-10-AC-09:** Expansion creates no live or reverse synchronization link.
10. **BCK-10-AC-10:** Expansion retry returns the same target and receipt.
11. **BCK-10-AC-11:** Server actor context is authoritative for every command.
12. **BCK-10-AC-12:** Owner/editor/read-only-collaborator rights are distinct and tested.
13. **BCK-10-AC-13:** Access revocation overrides cached grants.
14. **BCK-10-AC-14:** Raw share tokens are never persisted or logged.
15. **BCK-10-AC-15:** Revoked/expired tokens fail closed without enumeration.
16. **BCK-10-AC-16:** Staff repair uses BCK-19 and registered Planning commands.
17. **BCK-10-AC-17:** Public publication flows only through BCK-07.
18. **BCK-10-AC-18:** Public projection excludes private content and invitees.
19. **BCK-10-AC-19:** Quick Plan never receives PublisherRef.
20. **BCK-10-AC-20:** Public Scenario is not Event occurrence/capacity authority.
21. **BCK-10-AC-21:** Contract/schema versions are explicit in mutations.
22. **BCK-10-AC-22:** Unsupported newer versions fail closed.
23. **BCK-10-AC-23:** Breaking changes require migration/minimum-client evidence.
24. **BCK-10-AC-24:** Revisions are immutable and current pointers are atomic.
25. **BCK-10-AC-25:** Access/share changes commit with audit evidence.
26. **BCK-10-AC-26:** Token lookup uses bounded hashed-token storage.
27. **BCK-10-AC-27:** Expected revision prevents silent last-write-wins.
28. **BCK-10-AC-28:** Idempotency key hash mismatch returns typed conflict.
29. **BCK-10-AC-29:** Batch materialization cannot create hidden partial state.
30. **BCK-10-AC-30:** Ordered content conflicts require explicit resolution.
31. **BCK-10-AC-31:** Cache freshness never grants mutation authority.
32. **BCK-10-AC-32:** Offline edits distinguish local save from server save.
33. **BCK-10-AC-33:** Stale dependency snapshots remain honestly labelled.
34. **BCK-10-AC-34:** Authority-dependent actions fail closed when offline.
35. **BCK-10-AC-35:** Import requires explicit authenticated user action.
36. **BCK-10-AC-36:** Import uses dry-run and durable local/server ID mapping.
37. **BCK-10-AC-37:** Local role/publisher flags never become server authority.
38. **BCK-10-AC-38:** Legacy `quickPlan` taxonomy is read-compatibility only.
39. **BCK-10-AC-39:** Outbox is atomic with source change when enabled.
40. **BCK-10-AC-40:** Event consumers dedupe and reconcile by source revision.
41. **BCK-10-AC-41:** Events exclude private Planning content.
42. **BCK-10-AC-42:** Async effects stay disabled before Accepted OD-09.
43. **BCK-10-AC-43:** UTC instants and IANA local-date semantics are preserved.
44. **BCK-10-AC-44:** Money uses integer minor units and ISO currency.
45. **BCK-10-AC-45:** BCK-20 revisions identify market/locale/reference values.
46. **BCK-10-AC-46:** Cross-market items retain actual market/timezone refs.
47. **BCK-10-AC-47:** Disabled-market data cannot leak through public projection.
48. **BCK-10-AC-48:** Planned transport is not labelled live without proof.
49. **BCK-10-AC-49:** DSR export separates aggregates, grants and receipts.
50. **BCK-10-AC-50:** Erasure revokes shares and reconciles public projection.
51. **BCK-10-AC-51:** Logs/analytics exclude tokens, notes and coordinates.
52. **BCK-10-AC-52:** App Check never replaces authorization or abuse controls.
53. **BCK-10-AC-53:** Rate limits cover invite/token/import/conversion abuse.
54. **BCK-10-AC-54:** BCK-22 enforcement uses typed commands, not direct writes.
55. **BCK-10-AC-55:** Product analytics is separate from operational telemetry.
56. **BCK-10-AC-56:** Revision/grant/share growth has accepted cost bounds.
57. **BCK-10-AC-57:** Every server capability has an independent default-off flag.
58. **BCK-10-AC-58:** Rollback preserves safe owner read/export paths.
59. **BCK-10-AC-59:** LV/EE/LT cross-border fixtures cover policy/timezone behavior.
60. **BCK-10-AC-60:** Documentation acceptance claims no runtime or activation.

## 28. Explicit unimplemented list

- API schemas, generated clients and shared fixtures;
- backend Planning modules, persistence, indexes, Rules/IAM and workers;
- mobile remote adapters and local-to-cloud importer;
- collaboration, unlisted sharing and publication runtime;
- outbox, notifications and BCK-22 enforcement integration;
- retention decisions, production SLOs, load evidence and market activation.

## 29. Owner decisions required

| Decision | Owner | Fail-closed default | Required before |
|---|---|---|---|
| Collaboration role/capability details | Planning + Identity | owner-only | Approval |
| Unlisted token TTL/rotation limits | Security/Privacy | feature disabled | Runtime slice |
| Planning retention schedule | Privacy/Legal | no production persistence | Persistent stage |
| Public Scenario moderation classes | Planning + T&S | publication disabled | Public cohort |
| Cross-market visibility policy | Product/Market + Legal | affected market hidden | Market activation |
| Payload/revision/grant numeric budgets | Operations | conservative disabled limits | R7 |
| Conflict UX/minimum-client window | Mobile + API | copy-only recovery | Mobile adapter |

## 30. Final statement

BCK-10 establishes a complete Planning backend boundary while preserving the
product's most important distinction: Scenario is a publishable planning
aggregate, Quick Plan is a lightweight private/invited utility, and Route is an
independent track aggregate. Nothing in this v0.2 authorizes runtime,
deployment, Firebase or production activation.

## 31. Stage 2 normalized Planning entity contract

All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| Scenario | Planning / Scenario command handler | owner/collaborator view, publication handoff | scenarioId; owner/publisher/stop refs by ID; never a Route or Quick Plan ID |
| ScenarioRevision | Planning / Scenario revision handler | readiness/summary and BCK-07 publication handoff | immutable scenarioRevisionId + scenarioId/revision/hash |
| QuickPlan | Planning / Quick Plan handler | owner/invitees only | quickPlanId; private/invited utility, never catalog ID |
| PlanStop | Planning / owning Scenario or Quick Plan aggregate handler | plan view and travel calculation | stopId stable within aggregate; catalog/custom reference explicit |
| CollaborationInvite | Planning / collaboration handler | invitee/owner status projection | inviteId + aggregate type/id + principal + expiry |
| ExpansionMapping | Planning / explicit Quick Plan→Scenario command | owner audit only | mappingId + source quickPlanId + new scenarioId; no live link |

Scenario and Quick Plan have separate state machines. Quick Plan cannot become
public or a Scenario container; Expand creates a new Scenario once. Commands
use aggregate/actor/intent idempotency and expected revision; one aggregate is
one transaction, while publication/notifications use commands/outbox.
Authorization distinguishes owner, invited collaborator and PublisherRef;
private location/planning data follows BCK-04 classification,
retention and deletion.
Audit records sharing, publish handoff and expansion without sensitive notes;
telemetry is bounded. Migration preserves aggregate type and IDs; rollback
restores a compatible revision or disables collaboration/publish. Collaboration,
publication and market flags default off. Tests cover cross-user denial,
concurrency, invitation expiry, one-way expansion, offline conflict/import,
privacy, rollback and Scenario/Quick Plan/Route separation.

## 32. Stage 5 Planning sync, collaboration and publication contract

### 32.1 Aggregate and authority separation

| Aggregate | Creation authority | Collaboration | Publication |
|---|---|---|---|
| Scenario | authenticated User may own personal draft without Creator capability or PublisherRef | owner/editor/viewer/unlistedViewer with current invitation/membership revision | BCK-07 handoff requires current Creator capability and exact PublisherRef; BCK-08 consumes only published projection |
| Quick Plan | authenticated User owns private utility plan | owned/invited only | forbidden; never enters Catalog or Discover |
| Route | BCK-11 only | Route-specific contract | BCK-07 Route handoff; never stored inside Scenario/Quick Plan |

Scenario stores independent stops/time blocks/logistics and planning results.
Route stores a continuous track. Quick Plan stores a lightweight private or
invited plan. References between them are immutable IDs or snapshots, never
shared mutable aggregate state.

### 32.2 Sync and conflict protocol

Each mutation carries aggregate ID, base revision, actor/access revision,
semantic idempotency key/hash and ordered intent. The server rechecks current
access and returns `applied`, `already_applied`, `conflict`, `revoked`,
`unsupported_version` or `unknown_outcome` with a durable receipt. Concurrent
edits never use silent last-write-wins. Conflict response contains only the
authorized current revision, bounded conflicting fields/operation IDs and a
retry/rebase instruction; clients cannot overwrite a newer revision wholesale.

Offline work remains a local draft operation log with explicit provenance.
Upload replays through typed commands in order, stops on authority/schema/
conflict failure and never treats local success as server success. Invitation
revocation immediately blocks new remote mutations; cached collaboration state
is not authority.

### 32.3 Expansion and publication

`ExpandQuickPlanToScenario` is explicit, idempotent and one-way. It creates a
new Scenario permanent ID/revision, copies only allowlisted planning content,
strips invite/authority/visibility state and records an audit mapping. Later
changes never synchronize in either direction.

Scenario publication creates a BCK-07 draft/import handoff pinned to Scenario,
owner/PublisherRef, market, source and policy revisions. BCK-07 owns review,
immutable publication and withdrawal. Planning never writes Catalog. Personal
and invited Scenario source data remain protected even when a bounded public
projection exists.

### 32.4 Privacy, retention and rollback

Private plans, collaboration membership/invites, precise/custom locations,
revision/operation history, expansion mappings, publication receipts and audit
use separate BCK-04 classes. Export/deletion removes or pseudonymizes each class
without breaking lawful shared-owner records. Rollback disables collaboration
or publication, preserves receipts/unknown outcomes and selects a compatible
revision; it never merges Scenario, Quick Plan and Route or republishes private
data.

### 32.5 Additional acceptance criteria

61. **BCK-10-AC-61:** Scenario, Quick Plan and Route remain separate aggregates and writers.
62. **BCK-10-AC-62:** Authenticated User may own a personal Scenario without Creator/PublisherRef.
63. **BCK-10-AC-63:** Scenario publication requires current Creator capability and exact PublisherRef.
64. **BCK-10-AC-64:** Quick Plan remains owned/invited and cannot publish to Catalog/Discover.
65. **BCK-10-AC-65:** Every remote mutation pins base and access revisions plus semantic idempotency.
66. **BCK-10-AC-66:** Concurrent edits never use silent last-write-wins.
67. **BCK-10-AC-67:** Conflict responses are authorized, bounded and preserve newer revisions.
68. **BCK-10-AC-68:** Offline operations retain local provenance and replay through typed commands.
69. **BCK-10-AC-69:** Revoked collaboration state cannot authorize cached/offline mutation.
70. **BCK-10-AC-70:** Expand creates one independent Scenario and no live bidirectional link.
71. **BCK-10-AC-71:** Expansion strips Quick Plan invitation, authority and visibility state.
72. **BCK-10-AC-72:** BCK-07 alone owns Scenario publication/withdrawal; BCK-08 owns projection.
73. **BCK-10-AC-73:** Private source and public projection retain distinct privacy/retention classes.
74. **BCK-10-AC-74:** Rollback never republishes private data or merges planning aggregates.
75. **BCK-10-AC-75:** v0.3.1 authorizes no persistence, Firebase, collaboration or publication runtime.
