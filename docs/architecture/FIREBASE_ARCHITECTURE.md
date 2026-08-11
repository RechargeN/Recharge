# RECHARGE — Firebase Architecture

| Field | Value |
|---|---|
| Version | 2.2 |
| Status | Proposed |
| Date | 2026-07-30 |
| Scope | Production backend target after stabilization |

This document is a proposed backend architecture specification. It does not
authorize Firebase implementation during the active stabilization slice and
does not claim that any Firebase component is already implemented.

## 1. Authority and purpose

The document defines how Recharge can move from local/mock datasources to a
production Firebase backend without leaking Firebase into domain or
presentation code and without changing accepted product semantics.

When documents conflict, the repository priority remains:

1. Accepted ADRs in `docs/adr/`.
2. The approved specification of the active slice.
3. `docs/architecture/LAUNCH_STATUS.md`.
4. Product vision and supporting documents.

This proposal must be updated, or a new superseding ADR must be accepted,
before implementation if a conflict with a higher-priority source is found.
Existing Accepted ADRs are never edited to make this proposal fit.

The immediate objectives are:

- define the production data and trust boundaries;
- preserve repository and use-case contracts;
- support all accepted content aggregates, not only Event and Place;
- make permissions, publisher identity and lifecycle enforceable on backend;
- provide a safe path from mock data through stage to production;
- make security, observability, cost and rollback part of the MVP definition.

## 2. Current state and non-goals

At the time of this proposal:

- Auth and Discover use mock remote datasources;
- Create, Favorites, Profile and Notifications use local storage;
- published Create data is not projected into a shared remote catalog;
- Firebase packages, projects, rules, indexes and generated options are absent;
- client and backend capability enforcement is incomplete;
- localization `en/ru/lv` is not configured;
- Firebase implementation is explicitly gated until stabilization is complete.

This document does not:

- change the active slice;
- add an eleventh Create type;
- merge Route, Scenario and Quick Plan;
- introduce payments into MVP;
- choose the Route Builder outdoor renderer;
- replace the accepted Category System;
- authorize direct changes to generated FlutterFire files;
- define UI behavior already owned by product specifications.

## 3. Non-negotiable domain decisions

### 3.1 Identifiers

Every persistent Recharge entity uses an immutable client-generated ULID or
UUID. The current `IdGenerator` abstraction remains the entry point.

- Firestore automatic document IDs are not the canonical strategy.
- The Firestore document ID equals the entity ID where practical.
- `loc_*` IDs exist only in unsaved local drafts.
- Before the first remote write, media upload or cross-entity relation, every
  `loc_*` ID is replaced by a permanent ID.
- Retrying the same operation must reuse the same entity ID and operation ID.

Firebase Auth `uid` remains the infrastructure identity key for the
authenticated account. It is mapped to a permanent Recharge `userId`; it is not
substituted for IDs of users, profiles, pages, content, reviews or bookings.

### 3.2 Roles and capabilities

Starting roles are `user`, `creator` and `admin`. `Viewer` is an authenticated
`user`. Creator eligibility expands the same personal profile with explicit
capabilities; it does not create a second selectable personal workspace.
Professional Page access requires a verified Creator plus active membership
for an exact ManagedPage and page-scoped capabilities. `Pro generator` is
legacy UI debt, not a backend role or target product term.

Authorization is evaluated as:

```text
session + Creator verification + role + global capabilities
  + publisher membership + ownership + entity state
```

Roles provide broad defaults. Privileged actions use explicit capabilities,
including at least:

- `content.create`;
- `content.edit`;
- `content.submit`;
- `content.publish`;
- `content.archive`;
- `content.delete`;
- `page.manage`;
- `page.publish`;
- `insights.view`;
- `bookings.manage`;
- `moderation.review`;
- `admin.manage_access`.

The client may hide or disable actions, but the backend is authoritative. A
client-side guard is never accepted as an access-control boundary.

Users cannot promote themselves to Creator or Admin by editing a Firestore
field. Role and capability changes are server-controlled, audited operations.
Google/Apple authentication alone does not grant Creator. Creator identity
verification and Professional Page verification are separate server-owned
records and neither implies page membership.

### 3.3 Owner and publisher

Every major entity has an owner reference. Every publishable entity also has a
publisher reference:

```text
EntityRef    = { type, id }
PublisherRef = { type: user | page, id }
```

Content published from a ManagedPage is authorized by an active membership for
that exact page and by page-scoped capabilities. Page IDs are not packed into
Firebase custom claims: the claim size is limited and membership is dynamic.

Public cards may contain a denormalized publisher snapshot for rendering, but
the user or ManagedPage document remains the source of truth.

Active workspace and publisher are distinct. A personal/page workspace may
supply a default publisher for a new draft, but it does not authorize an
operation and never silently rewrites an existing draft's `PublisherRef`.
Admin tools are neither a workspace nor a publisher.

### 3.4 Lifecycle

Lifecycle and moderation are separate state machines:

```text
draft -> pending_review -> published -> archived -> deleted
                            |
                            +-> hidden

moderation: none -> pending -> approved | rejected
```

Rules:

- a creator edits `draft` content within their capabilities;
- submission creates an audited `pending_review` transition;
- approval sets lifecycle `published` and moderation `approved`;
- rejection is a moderation result, not a lifecycle status; the entity returns
  to the approved editable lifecycle with reason codes preserved privately;
- only a trusted server or an authorized moderator publishes, hides or rejects;
- archive is recoverable;
- hard deletion follows the accepted retention or legal-deletion policy;
- state transitions are idempotent and validate the expected current revision;
- public queries never return non-public lifecycle states.

### 3.5 Route, Scenario and Quick Plan

These are separate aggregates:

- Route is a continuous track with anchors, segments, GPX, elevation and POI
  tied to distance along the track.
- Scenario is a city/day/weekend/trip plan made from independent stops and can
  be personal, unlisted or a public template.
- Quick Plan is a lightweight personal/invited utility for several hours. It
  is not catalog content and is not a Create Hub type.
- `Expand to Scenario` creates a new Scenario ID and a snapshot of selected
  stops. No live relationship is retained.

Legacy `quickPlan` Create taxonomy and `scenario route` naming are migration
debt. Firebase documents must not preserve that debt as the target model.

## 4. Target service topology

### 4.1 Production MVP services

| Service | MVP use |
|---|---|
| Firebase Authentication | Google and Apple identity, token restore and revocation |
| Cloud Firestore | canonical data, drafts, projections, membership and lifecycle |
| Cloud Storage for Firebase | staged uploads, media originals and derived variants |
| Cloud Functions | trusted transitions, capability changes, projections, media and cleanup |
| Firebase App Check | abuse reduction for Auth, Firestore, Storage and Functions |
| Crashlytics | fatal and non-fatal diagnostics with PII redaction |
| Analytics | accepted event taxonomy and release health |
| Local Emulator Suite | integration and Security Rules tests in local development and CI |

Cloud Functions are included in production MVP because accepted permissions,
publisher membership and moderation transitions cannot safely be delegated to
an untrusted mobile client.

### 4.2 Deferred services

The following remain separate approved slices:

- FCM push delivery;
- Remote Config-backed feature flags;
- external full-text search such as Typesense or Algolia;
- server-generated image variants beyond the MVP set;
- recommendations and BigQuery pipelines;
- internal booking inventory and payments;
- admin and business web applications;
- live routing, isochrones and outdoor route rendering.

Local defaults and kill switches are still required before Remote Config is
introduced.

### 4.3 Regional placement

Before the first production database is created, the team must approve the
irreversible location decision.

Proposed European placement:

- Firestore: `eur3` multi-region;
- Storage: an EU-compatible location selected with the same residency policy;
- Functions: `europe-west1` where supported by the function and trigger type.

`eur3` uses Belgium and Netherlands read/write regions with Finland as the
witness region. Function and resource location alignment is required to avoid
avoidable latency and cross-region cost.

The final selection requires a recorded data-residency, cost and latency review.
Creating the production database before that approval is prohibited.

## 5. Environments and configuration

Repository policy requires three isolated runtime environments:

| Flavor | Firebase project | Purpose | Production data allowed |
|---|---|---|---|
| `dev` | `recharge-dev` | developer integration and disposable seed data | no |
| `stage` | `recharge-stage` | release candidate, QA and migration rehearsal | synthetic/anonymized only |
| `prod` | `recharge-prod` | public release | yes |

Requirements:

- separate Firebase projects, app registrations and billing alerts;
- distinct Android application IDs and Apple bundle identifiers per flavor;
- build-time environment selection; no runtime switching into prod;
- generated options per environment, produced by FlutterFire CLI;
- CI uses an emulator-only `demo-*` project wherever possible;
- service-account credentials exist only in protected CI or workload identity;
- Firebase client configuration is treated as public configuration, while
  service accounts, signing material and provider secrets remain secret;
- a production build fails closed if environment configuration is incomplete;
- mock datasources cannot be selected by a production flavor.

The composition root chooses adapters. Feature code never checks `isProd` and
never selects a datasource itself.

```text
bootstrap -> environment config -> Firebase initialization -> DI adapters
```

## 6. Flutter integration boundary

Firebase is allowed only in:

- `app/bootstrap.dart` and environment-specific composition code;
- `app/di/` registrations;
- feature `data/datasources`;
- Firebase-specific data models and mappers;
- core technical adapters such as telemetry and App Check.

Firebase imports are forbidden in:

- `domain/`;
- `application/`;
- `presentation/`;
- reusable design-system code;
- domain entities in `shared/`.

The dependency trace remains:

```text
presentation
  -> application controller
    -> domain use case
      -> domain repository interface
        -> data repository implementation
          -> datasource interface
            -> Firebase or mock adapter
```

Repository implementations translate Firebase exceptions into existing domain
failures. No `DocumentSnapshot`, `Timestamp`, `GeoPoint`, Firebase `User` or
`FirebaseException` crosses the data boundary.

Mock and Firebase adapters must pass the same repository contract tests.

Versioned remote shapes are declared through `packages/api_contracts`. Firebase
adapters translate snapshots and Firebase primitives into those framework-free
DTOs; generated contract files are not edited manually.

## 7. Canonical data conventions

### 7.1 Versioned documents

Every durable document contains:

- `id` matching its document ID where practical;
- `schemaVersion` as a positive integer;
- `createdAt` and `updatedAt` server timestamps;
- `createdByUserId` and, where applicable, `updatedByUserId`;
- `revision` for optimistic concurrency;
- lifecycle or active/deleted state where applicable.

Readers support the current version and explicitly supported older versions.
Future versions fail closed; they are never silently downgraded.

### 7.2 Localized content

User-facing content is stored as locale maps from the first remote schema:

```text
LocalizedText = { en?: string, ru?: string, lv?: string }
```

Each item also records `contentLocale` and available locales. Empty translations
do not masquerade as localized content. Locale selection and fallback happen in
mappers/application policy, not in Firestore DTOs or widgets.

### 7.3 Money

Money uses integer minor units:

```text
Money = { amountMinor: int, currency: ISO-4217, isFree: bool }
```

Floating-point amounts are forbidden in remote contracts. `isFree` must agree
with `amountMinor == 0`. Rental deposits, price ranges and onsite/external
collection are separate typed fields, not overloaded strings.

### 7.4 Time

- audit timestamps use trusted server timestamps;
- event instants are stored as UTC timestamps;
- local interpretation stores an IANA timezone such as `Europe/Riga`;
- recurrence retains local wall-clock rules and explicit DST gap/overlap policy;
- occurrence IDs are permanent and deterministic under the accepted schedule
  specification;
- client clocks never authorize lifecycle or moderation decisions.

### 7.5 Geography

Point-based public catalog items store:

```text
GeoRef = {
  geopoint,
  geohash,
  countryCode,
  marketCityId,
  timezone,
  publicAddress?
}
```

Exact private meeting points, access instructions and online secrets live in a
separate protected document. An online-only object has no fake coordinate and
does not produce a map marker.

Geohash queries return bounded candidate sets and require an exact distance
filter because geohash ranges produce false positives. Query cost and maximum
candidate count must be measured against Riga seed and stage data.

## 8. Aggregate and collection model

The root topology is designed around aggregate ownership and access boundaries,
not around screens.

```text
authLinks/{authUid}
users/{userId}
userPrivate/{userId}
managedPages/{pageId}
managedPages/{pageId}/members/{userId}

content/{contentId}
contentPrivate/{contentId}
content/{contentId}/occurrences/{occurrenceId}
content/{contentId}/routeSegments/{segmentId}
content/{contentId}/routePois/{poiId}
catalogItems/{contentId}

quickPlans/{quickPlanId}
quickPlans/{quickPlanId}/members/{userId}

reviews/{reviewId}
reports/{reportId}
bookmarks/{userId}/items/{contentId}
notifications/{userId}/items/{notificationId}
mediaAssets/{assetId}
auditLogs/{auditId}
operationReceipts/{receiptId}

markets/{marketId}
categories/{categoryId}
subcategories/{subcategoryId}
```

The exact names become immutable only when an approved Firebase implementation
slice accepts them. Renaming a production collection later requires an explicit
migration plan.

### 8.1 Public and private user data

`authLinks/{authUid}` is server-private and maps Firebase Auth identity to a
permanent Recharge `userId`. The `userId` is created through the canonical
client ID generator during first-profile bootstrap and accepted idempotently by
the trusted backend. The link cannot be created or changed by a normal client.

`users/{userId}` contains only profile data safe for its intended visibility:

- display name and avatar reference;
- public bio;
- public profile state;
- verification display state;
- non-sensitive counters maintained by server;
- timestamps and schema version.

Email, provider identifiers, settings, blocked users, device metadata and legal
consents are not placed in a publicly readable profile. Private preferences are
stored under `userPrivate/{userId}` or an owner-only subcollection.

The last selected `WorkspaceRef {type: personal | page, id}` may be stored as a
non-sensitive owner-only preference. It is never copied into custom claims and
is never accepted as membership or capability evidence.

Firebase Auth remains the source of truth for provider identity and verified
email state.

### 8.2 ManagedPage and membership

`managedPages/{pageId}` is a persistent entity with its own owner, profile,
verification state and lifecycle.

The model uses stable country/market codes, IANA timezone, ISO currency and
locale metadata. Registration, tax, KYC and payout fields are market-specific
private extensions rather than universally required public fields.

Membership is stored at `managedPages/{pageId}/members/{userId}` so authorization
for a specific page can be checked with a bounded document lookup. It contains:

- `userId` and `pageId`;
- membership status;
- page-scoped capabilities;
- granted/revoked timestamps;
- grant actor and revision.

Only trusted admin operations grant or revoke membership. Page lists for a user
use a deliberate indexed projection; Security Rules are not used as a query
engine.

The projection returns only pages the user may currently see in `Switch
workspace`; authorization for an action still reads or validates the exact
membership. It supports zero, one, five and larger page sets with bounded
pagination. Page A membership or cached selection never grants Page B access.

### 8.2.1 Active workspace restoration

The client restores a workspace in this order:

```text
restore authenticated user
  -> load current access snapshot and page projection
  -> read owner-only workspace preference
  -> validate exact page membership and page lifecycle
  -> activate selected page or fall back to personal workspace
```

Suspended, revoked, missing or stale page access falls back to personal
workspace with a stable reason code. The invalid preference may be repaired,
but any existing draft retains its stored publisher and fails closed until the
user explicitly resolves it.

Logout and account switching clear private in-memory workspace state. Any
persisted preference is namespaced by permanent `userId` and cannot cross
accounts.

### 8.3 Unified content envelope

All ten target Create types share a common `content/{contentId}` envelope. This
supports one lifecycle, publisher contract and catalog projection while keeping
type-specific payloads versioned.

Target content types are:

1. `event`;
2. `activity`;
3. `route`;
4. `place`;
5. `session`;
6. `scenario`;
7. `findPeople`;
8. `classWorkshop`;
9. `rental`;
10. `collection`.

This list follows the current target model: Scenario owns the planning slot.
Quick Plan remains outside Create Hub. Activation of the Scenario type and
migration of legacy `quickPlan` require their own approved migration slice.

The common envelope contains:

```text
ContentEnvelope = {
  id,
  schemaVersion,
  type,
  owner: EntityRef,
  publisher: PublisherRef,
  createdByUserId,
  lifecycle: {
    status,
    visibility,
    revision,
    createdAt,
    updatedAt,
    submittedAt?,
    publishedAt?,
    archivedAt?
  },
  moderation: {
    status
  },
  title: LocalizedText,
  shortDescription: LocalizedText,
  categoryId,
  subcategoryId,
  marketId,
  publicGeo?,
  priceSummary?,
  mediaAssetIds,
  typeSchemaVersion,
  typeData
}
```

Only data safe for the document's read policy belongs in the envelope.
Passwords, exact private locations, invitation tokens, online access secrets,
moderation notes and internal contact data are prohibited.

Large Route geometry, occurrence sets and collection membership use bounded
subcollections or Storage artifacts rather than an unbounded document. Every
list is size-limited so the Firestore document limit is never approached by
normal product use.

### 8.4 Protected content data

`contentPrivate/{contentId}` is readable only by authorized owners, page
members, participants with explicit access or admins. It can hold:

- exact Find People meeting coordinates;
- private/invited plan access data;
- online meeting links and access instructions;
- organizer-only contact fields;
- moderation feedback intended for the publisher;
- provider integration references that are safe for the authorized client.

Secrets that should never reach a mobile client remain in a secret manager or
trusted backend, not Firestore.

### 8.5 Catalog projection

`catalogItems/{contentId}` is a server-written, denormalized, public discovery
projection. It contains only fields needed by Search, Map, Feed and cards:

- content ID and type;
- lifecycle-safe public visibility;
- localized title/summary;
- publisher snapshot;
- category/subcategory;
- time/availability summary;
- public geo/geohash;
- price summary;
- cover variant reference;
- ranking inputs that clients are allowed to read;
- projection version and source revision.

Only published public items enter the catalog. Unlisted content is retrieved by
its explicit ID through a separate repository path and never appears in catalog
queries. Private content never enters the public projection.

Projection updates are idempotent and derived from the canonical content
revision. The mobile client never writes `catalogItems`.

### 8.6 Type-specific boundaries

- Event occurrences use permanent IDs and preserve recurrence/override mapping.
- Find People stores public and exact location separately and never exposes
  online secrets in catalog or public details.
- Place keeps opening rules, exceptions and operational closure as typed data.
- Route geometry and GPX are Route-only and never contain Scenario fields.
- Scenario stores independent stop references/snapshots and logistics, not a
  continuous Route track.
- Collection stores ordered content IDs; snapshots are display caches only.
- Rental inventory and Session availability remain separate typed concepts.

### 8.7 Quick Plan

`quickPlans/{quickPlanId}` is owner-private by default and supports explicitly
invited members. It is excluded from `catalogItems` and public Create queries.

Expansion to Scenario is a trusted, idempotent operation:

1. authorize access to the source Quick Plan;
2. allocate or accept a permanent new Scenario ID;
3. copy a versioned snapshot of stops and preferences;
4. record source provenance for audit only;
5. create no live synchronization link.

### 8.8 Reviews and reports

Reviews are MVP entities and use stable relations:

```text
Review = { id, authorId, objectId, objectType, rating, body, status, timestamps }
```

Rules and server operations enforce one active review per author/object policy,
accepted eligibility rules, rating range and moderation status. Aggregate rating
and count are server-maintained projections; clients cannot write counters.

Reports store reporter, target, reason and lifecycle. The accepted uniqueness
and auto-hide threshold is evaluated by trusted backend logic, not a client.

## 9. Authentication and session model

### 9.1 Providers

Production target providers are Google and Apple. ADR 0015 requires every
Viewer to authenticate, so there is no unauthenticated guest browsing state.
Anonymous Firebase accounts are not used. Without a valid session the client
opens auth and preserves only an allowlisted safe intended destination.

Email/password is not added implicitly because it expands account recovery,
abuse, support and security scope.

### 9.2 Sign-in flow

```text
provider credential
  -> Firebase Auth
  -> token validation and App Check
  -> idempotent ensure-profile/auth-link operation
  -> role/capability snapshot
  -> ManagedPage membership projection
  -> validate active workspace preference
  -> session restore
  -> post-login target
```

The flow handles:

- provider cancellation;
- provider/account collision and explicit linking;
- revoked or disabled sessions;
- token refresh;
- forced logout;
- Apple token revocation during account deletion where required;
- the accepted active-session/device policy;
- safe restoration of the intended post-login action.

### 9.3 Claims and capability source of truth

Custom claims contain only coarse, slow-changing authorization data:

- permanent Recharge `userId`;
- role;
- compact global capability codes where justified;
- claims schema/version;
- optional access revision.

ManagedPage IDs and large permission lists are not stored in claims. Page-scoped
authorization reads the exact membership or is verified inside a callable
Function.

Admin role or an `admin.*` capability does not imply Creator verification,
page membership or publisher eligibility. Admin tools use their own explicit
capabilities and audited operations.

The authoritative capability change flow is:

```text
admin action -> trusted Function -> capability/membership write
             -> audit entry -> claims refresh if needed
```

Clients never write role, capabilities, verification or moderation authority.

## 10. Trusted backend operations

The production MVP requires a small, explicit Function catalog. Names below are
logical contracts, not final deployed names.

| Operation | Responsibility |
|---|---|
| `ensureUserProfile` | idempotently link Auth UID to a proposed permanent user ID and create/repair the minimum profile |
| `syncDraft` | online optimistic draft sync with expected revision |
| `submitContent` | validate capability, publisher, schema, media and move to pending review |
| `moderateContent` | approve/reject/hide with moderator capability and reason |
| `archiveContent` | enforce publisher permission and lifecycle transition |
| `restoreContent` | restore within retention where policy permits |
| `grantAccess` / `revokeAccess` | server-owned role, capability and page membership changes |
| `createUploadSession` | authorize a bounded staging upload for an entity |
| `finalizeMedia` | validate/process media and publish immutable variants |
| `rebuildCatalogItem` | create or delete public projection from source revision |
| `submitReport` | enforce reporter uniqueness and trigger threshold policy |
| `expandQuickPlanToScenario` | one-way snapshot into a new Scenario ID |
| `deleteAccount` | reauthenticate, revoke provider, apply retention/anonymization and delete Auth user |

All operations:

- accept an `operationId` generated by the client;
- validate Auth and App Check context;
- validate input with an allowlist schema;
- execute under least-privilege IAM;
- are idempotent because background delivery and client retries can duplicate
  invocations;
- write an operation receipt for externally visible state transitions;
- redact sensitive fields from logs;
- return stable application error codes mapped by the data layer.

Server SDKs bypass Security Rules. Therefore Functions require their own input,
authorization and state-transition validation; Rules are not a substitute for
Function validation.

## 11. Firestore Security Rules strategy

The production ruleset is default-deny. Concrete rules are delivered and tested
by the implementation slice; prose examples are not considered deployable
security controls.

### 11.1 Direct client writes

Direct writes are limited to operations that can be safely expressed in Rules:

- owner preferences with strict field allowlists;
- bookmarks/favorites under the authenticated user;
- notification `isRead` updates only;
- a local-to-remote draft path if the approved sync design proves it safe;
- participant-owned state with explicit membership checks.

Submission, publication, moderation, capability changes, page membership,
counters, audit logs and catalog projections are server-only.

### 11.2 Required rule techniques

- compare `request.resource.data` with `resource.data`;
- restrict allowed and changed fields with key/diff allowlists;
- validate types, bounds, string lengths and enum values;
- make immutable IDs, ownership, publisher and creation metadata unchangeable;
- use exact membership lookups only where query/rules limits remain bounded;
- require queries to include the same visibility/ownership predicates as Rules;
- deny broad collection reads that cannot prove the rule for every result;
- validate create separately from update;
- provide explicit deny tests for every privileged field and transition.

Rules document lookups consume quotas and billed reads. The rule design must
stay within documented access-call limits for single, batch and transaction
operations.

### 11.3 Required test matrix

At minimum, emulator tests cover:

- unauthenticated denial plus authenticated User, Creator and Admin contexts;
- provider-authenticated User with missing/pending/rejected/expired/revoked
  Creator verification;
- Creator with and without each required capability;
- Creator verification and Professional Page verification as distinct facts;
- active, revoked and missing ManagedPage membership;
- personal workspace with and without Creator eligibility;
- zero, one, five and paginated ManagedPage projections;
- stale/revoked active page preference falling back to personal workspace;
- page A selection and capabilities never authorizing page B;
- Admin role without the required admin capability;
- Admin access never satisfying publisher or membership checks;
- owner versus non-owner access;
- every lifecycle transition, including invalid skips;
- every visibility mode;
- private versus public location and online secrets;
- attempts to edit IDs, publisher, counters, verification and audit metadata;
- query-shape allow and deny cases;
- oversized or unknown payload fields;
- batch/transaction rule lookup limits;
- cross-user bookmarks, notifications and private data;
- content deletion and retention behavior.

`@firebase/rules-unit-testing` runs under `firebase emulators:exec` in CI. Stage
smoke tests are also required because the emulator does not enforce every
production limit or compound index.

## 12. Storage and media pipeline

### 12.1 Path model

```text
staging/{uid}/{uploadSessionId}/{assetId}/original
public/{contentId}/{assetId}/{variant}
private/{ownerType}/{ownerId}/{assetId}/original
avatars/{uid}/{assetId}/{variant}
pages/{pageId}/{assetId}/{variant}
routes/{contentId}/{assetId}/track.gpx
```

The client does not upload directly into another content owner's public path.

### 12.2 Upload flow

1. Client obtains a trusted upload session bound to user, publisher, entity,
   asset ID, allowed MIME types, maximum size and expiry.
2. Client compresses supported images and strips unnecessary metadata where
   possible.
3. Storage Rules validate owner/session, path, size and declared content type.
4. Trusted processing validates file signatures, image decodability and rights
   metadata; declared MIME alone is insufficient.
5. Immutable variants are produced with distinct paths or generation-aware
   names.
6. `mediaAssets/{assetId}` becomes `ready` and the content references the asset.
7. Failed and abandoned staging uploads are removed by scheduled cleanup.

Public delivery never exposes a private original. Exact private media access is
authorized independently from public content access.

### 12.3 Storage Rules invariants

- authenticated is not equivalent to authorized;
- ownership or exact page membership is checked for every private write;
- a user cannot overwrite another user's asset by guessing IDs;
- public derived variants are server-written;
- file count, size and type limits are enforced both client-side and backend;
- Storage-to-Firestore authorization lookups remain within documented limits;
- delete/replace actions are audited and respect content lifecycle.

## 13. Discover, geo and search

### 13.1 One query state, multiple surfaces

`DiscoverQuery` remains the common application/domain state for applied Search,
Map, Feed, Categories and Details. Firebase query mechanics remain behind the
repository contract.

```text
DiscoverQuery
  -> query planner
    -> bounded Firestore/catalog queries
      -> exact geo and time-fit evaluation
        -> one ranked result set
          -> Map / Feed / Details
```

Manual Search and Smart Search retain separate entry UX and histories; they
only converge after producing an applied `DiscoverQuery`.

### 13.2 Query planning

Firestore is not treated as an arbitrary filter engine. Every supported query
shape has:

- an explicit server-filter plan;
- a composite index entry where needed;
- a maximum page/candidate size;
- a deterministic client/domain post-filter stage;
- a measured read-cost budget;
- a fallback and kill switch.

Geo radius uses geohash bounds plus exact distance filtering. Multiple geohash
ranges are deduplicated by content ID. False positives and reads are measured.

Time-fit and travel scoring remain domain use cases. Firestore retrieves viable
candidates; it does not become the source of product ranking semantics.

### 13.3 Text search evolution

MVP can use bounded normalized tokens/prefixes only for supported simple cases.
It must not promise general full-text, typo tolerance or multilingual relevance.

When real usage requires full text, a separate search datasource and index are
added behind the same repository contract. Firestore remains the source of
truth, while the external index is a rebuildable projection.

## 14. Offline, draft sync and conflict handling

Firestore persistence is a cache, not a complete product sync policy. On Apple
and Android it is enabled by default, but Recharge still defines behavior for
staleness, conflict and sensitive data.

### 14.1 Read behavior

- public catalog/details may render cached data with a stale/offline indicator;
- snapshot metadata distinguishes cache from server when relevant;
- destructive or privileged actions do not report success until authoritative
  confirmation is received;
- private caches are cleared on logout/account switch according to platform
  capabilities and documented limitations;
- catalog/category TTL and refresh policy is centralized.

### 14.2 Draft behavior

- local autosave remains mandatory and works without Firebase;
- remote draft sync is optional until the dedicated sync slice is approved;
- callable submission never runs offline and never returns fake success;
- sync records `revision` and the client's `expectedRevision`;
- the accepted baseline remains last-write-wins with an explicit user warning
  when a conflict is detected;
- the local autosave/recovery snapshot is retained where practical so a warning
  does not silently destroy the user's only copy;
- media upload state is resumable and separate from content publish state.

Manual merge, geometry revision selection or another stronger conflict policy
requires a superseding ADR before implementation.

### 14.3 Atomicity

- use transactions only for state derived from current remote state;
- transaction callbacks are side-effect free and tolerate retries;
- use batched writes when no reads are required;
- remember that client transactions fail offline;
- large fan-out, counters and projections belong in trusted backend processing.

## 15. Moderation, abuse and audit

### 15.1 Moderation

The backend enforces the accepted states and report policy. `pending_review`
exists from the first production schema; it is not postponed to a later schema.

Moderation decisions include:

- actor;
- previous and next state;
- reason code and optional internal note;
- target revision;
- trusted timestamp;
- operation ID.

Moderation notes never leak into public content documents.

### 15.2 Abuse controls

- App Check is rolled out in monitor mode, then enforced before public release
  after legitimate traffic is verified;
- Auth provider and Function rate limits are complemented by per-user operation
  budgets;
- Creator publish velocity follows accepted policy;
- duplicate and suspicious-activity checks run before or during moderation;
- report uniqueness is per reporter and target;
- blocked-user and privacy policy is enforced in repositories/backend, not only
  hidden in UI;
- budget and quota alerts are configured for every real environment.

### 15.3 Audit

`auditLogs` is append-only and server-written. It records privileged create,
edit, submit, publish, archive, delete, access-grant and moderation actions.

Audit visibility is restricted to authorized admin/moderation workflows. Logs
contain stable IDs and reason codes but avoid unnecessary PII or secret payloads.

## 16. Observability and privacy

### 16.1 Telemetry

Production baseline includes:

- Crashlytics with release/environment tags;
- accepted analytics events and parameter allowlists;
- backend structured logs with correlation/operation IDs;
- Function error rate, latency and retry monitoring;
- Firestore/Storage usage, quota and billing alerts;
- catalog projection lag and failed-media processing metrics;
- auth success/failure metrics without credentials or tokens.

No raw search text, exact private location, access link, authorization token,
email or uploaded content body is logged by default.

### 16.2 Privacy and deletion

Before production release the team records:

- data inventory and purpose;
- public/private field classification;
- retention for drafts, logs, deleted accounts and media;
- account deletion and provider revocation flow;
- export/access-request procedure;
- legal URLs and consent versions;
- backup residency and access policy;
- incident and breach response ownership.

Analytics consent and platform tracking requirements are handled by an approved
legal/product slice; Firebase enablement does not imply consent.

## 17. Indexes and query catalog

`firestore.indexes.json` is source-controlled and deployed identically to each
environment after environment review. Console-created indexes must be reflected
back into the repository.

The implementation slice maintains a query catalog with:

- repository method;
- collection/projection;
- equality filters;
- range/order fields;
- required composite index;
- pagination cursor;
- maximum result count;
- expected reads at Riga seed scale;
- security rule predicate;
- fallback behavior.

Initial index families are expected for:

- public catalog by market, lifecycle, type and ranking/time;
- public catalog by market, category/subcategory and time;
- geohash-bound catalog candidates scoped by market/type;
- publisher workspace by publisher and lifecycle/update time;
- user-owned drafts by user and update time;
- ManagedPage membership projections by user;
- owner-only active workspace preference by user;
- review/report moderation queues by state and creation time;
- occurrence queries by parent content and start time.

Arbitrary combinations are not enabled merely because UI can select them. The
query planner must have an index and cost policy for every supported combination.

## 18. Deployment, migration and rollback

### 18.1 Required implementation slices

Firebase work starts only after stabilization acceptance and is split into
reviewable slices:

1. **Backend contract freeze** — approve collection envelope, DTO versions,
   capability matrix and query catalog.
2. **Environment foundation** — create dev/stage/prod, flavors, FlutterFire
   configuration, emulators and CI without product cutover.
3. **Auth and identity** — Google/Apple, profile bootstrap, session edge cases
   and account deletion contract.
4. **Access foundation** — claims, capability grants, ManagedPage membership,
   active-workspace projection/preference validation, Admin tools separation,
   server operations and audit.
5. **Catalog read path** — Firestore adapters, seed, projection and Discover
   parity against mock contract tests.
6. **Create write path** — remote drafts, media, submit/moderation lifecycle and
   Discover projection for approved Create types.
7. **User data** — favorites, reviews, reports and notifications persistence.
8. **Production hardening** — App Check enforcement, observability, backup,
   load/cost tests, migration rehearsal and release gates.

Each slice has its own acceptance criteria and cannot be marked Done without
green analyze/test plus its backend/emulator tests.

### 18.2 Mock-to-Firebase migration

- mock seed has a versioned, deterministic export format;
- dev is seeded first, then contract parity is verified;
- stage receives synthetic release-scale data;
- production seed is curated and explicitly approved;
- permanent IDs are preserved across seed and projections;
- legacy type/category IDs run through accepted migration maps;
- private fields and secrets are never copied into public projections;
- a dry-run report records created, updated, skipped and rejected entities;
- rerunning a migration is idempotent;
- backup/export is taken before destructive migration steps.

The mobile app does not dual-write mock/local and Firebase as independent
sources of truth. Cutover is controlled at the composition root using a build
environment or an approved kill switch.

### 18.3 Rollback

Every production slice defines:

- previous compatible app/backend version;
- forward and backward DTO compatibility window;
- feature kill switch;
- projection rebuild procedure;
- Rules and Functions rollback artifacts;
- data backup/restore or compensating migration;
- owner and decision threshold.

Rules rollback must never reopen access. If compatibility and security conflict,
fail closed and disable the affected write flow.

## 19. CI and release gates

### 19.1 CI gates

In addition to existing Flutter and boundary gates:

- Firebase configuration lint;
- Firestore and Storage Rules compilation;
- Rules allow/deny unit tests through Emulator Suite;
- Function lint, unit and integration tests;
- repository contract tests against mock and emulator adapters;
- seed/migration dry run;
- index/query catalog consistency check;
- secret scan and production-mock exclusion check;
- stage smoke test for real indexes and platform provider configuration.

The Firestore emulator does not enforce all production compound indexes and
limits, so emulator-green alone is insufficient.

### 19.2 Public release gate

Firebase-backed public release is `GO` only when all are true:

- stabilization gates are green on a clean release commit;
- signed Android and Apple production builds are reproducible;
- dev/stage/prod are isolated and production cannot select mocks;
- Google and Apple Auth pass physical-device tests;
- role, capability, ownership and ManagedPage tests are green;
- no unauthorized lifecycle transition succeeds;
- Firestore and Storage Rules have complete deny-path coverage;
- App Check is enforced after a monitored rollout;
- legal links, deletion flow and privacy inventory are complete;
- public catalog contains no private fields or secrets;
- backups and one restore rehearsal are complete;
- migration and rollback rehearsals pass on stage;
- Crashlytics, backend alerts and billing budgets are active;
- no open P0/P1 security or critical-flow defect remains;
- Product and Engineering record a Go/No-Go decision.

## 20. Cost and scale controls

Firebase cost is an architecture input, not a post-release surprise.

- every list is paginated and bounded;
- no listener is attached to an unbounded collection;
- listeners stop when their owning screen/controller is disposed;
- geohash fan-out and false-positive reads are measured;
- rule document lookups are counted;
- catalog projections avoid repeated joins on hot card paths;
- images use bounded variants rather than original files in feeds;
- scheduled cleanup removes abandoned uploads and expired operational data;
- budget alerts exist for dev, stage and prod with different thresholds;
- load tests report reads/writes/storage/function invocations per critical flow;
- product analytics can be disabled independently from operational telemetry.

Scale evolution is additive:

- external search is a rebuildable projection;
- materialized feeds/map tiles can be added for hot markets;
- BigQuery receives analytics/export data without serving mobile queries;
- payments remain behind trusted Functions and a payment provider;
- complex routing/isochrones remain behind their own repository/provider.

## 21. Definition of Done for Firebase MVP

Firebase MVP is complete only when:

- this proposal has been accepted through the repository decision process;
- all implementation slices and migrations have accepted specs;
- all three environments exist with approved locations and ownership;
- Google/Apple Auth, session restore/revoke and deletion work;
- User/Creator/Admin plus capabilities are backend enforced;
- ManagedPage publisher access is page-scoped and audited;
- all activated content types use the common envelope and typed payloads;
- Route, Scenario and Quick Plan boundaries are preserved;
- Create submission produces `pending_review`, never fake success;
- moderation produces safe catalog and details projections;
- private locations, online secrets and moderation notes cannot leak;
- Storage staging and media ownership rules are tested;
- Discover query parity and Riga cost budgets pass;
- Reviews and accepted report rules are implemented for MVP;
- offline read and draft-conflict behavior is verified;
- Rules, Functions, adapters, migrations and rollback are tested;
- Flutter analyze/test and all repository CI gates are green;
- a signed stage release completes the critical-flow smoke matrix;
- production monitoring, budget alerts, backup and incident ownership are active.

## 22. Decisions still requiring approval

The following must be resolved by an approved slice or new ADR before their
implementation becomes irreversible:

1. Final Firestore and Storage locations after residency/cost review.
2. Final root collection names and the common content envelope version.
3. The exact role-to-capability baseline and capability code registry.
4. ManagedPage membership/query projection design.
5. Review eligibility and one-review policy details.
6. Whether remote cross-device draft sync is MVP or a later slice.
7. Public/unlisted Scenario access semantics.
8. Media variant sizes, retention and delivery URL policy.
9. Search engine trigger and provider selection beyond bounded MVP search.
10. Backup schedule, retention and restore RTO/RPO.
11. Scenario activation and legacy `quickPlan` migration.
12. Route geometry/GPX storage format after the renderer ADR.

## 23. Differences from Firebase Architecture v1

Version 2.0 intentionally changes the supplied v1 proposal:

- Firestore-generated IDs are replaced with client-generated permanent IDs.
- `creatorId`-only ownership is replaced with owner and PublisherRef.
- role-only/self-upgrade authorization is replaced with server-owned
  capabilities and page membership.
- `published`-only MVP is replaced with the accepted moderation lifecycle.
- Cloud Functions and App Check move into the production MVP trust boundary.
- Event/Place-only collections become a unified versioned content envelope and
  public projection supporting the accepted ten-type model.
- Quick Plan is removed from catalog/Create target and separated from Scenario.
- public and private content fields are split into different documents.
- unsafe direct public Storage paths are replaced with upload sessions/staging.
- dev/prod becomes dev/stage/prod to match repository environment policy.
- Rules prose is replaced by a testable default-deny strategy and deny matrix.
- offline persistence is separated from explicit draft conflict policy.
- release readiness includes signing, legal, observability, backup and rollback.

## 24. Official technical references

These references describe platform behavior; repository decisions above remain
authoritative for Recharge product semantics.

- Firebase for Flutter setup: <https://firebase.google.com/docs/flutter/setup>
- Multiple Firebase projects: <https://firebase.google.com/docs/projects/multiprojects>
- Firestore locations: <https://firebase.google.com/docs/firestore/locations>
- Cloud Functions locations: <https://firebase.google.com/docs/functions/locations>
- Firestore Security Rules conditions and limits:
  <https://firebase.google.com/docs/firestore/security/rules-conditions>
- Field-level Rules validation:
  <https://firebase.google.com/docs/firestore/security/rules-fields>
- Secure Firestore queries:
  <https://firebase.google.com/docs/firestore/security/rules-query>
- Storage Rules conditions and Firestore lookups:
  <https://firebase.google.com/docs/storage/security/rules-conditions>
- Firestore geoqueries and false-positive filtering:
  <https://firebase.google.com/docs/firestore/solutions/geoqueries>
- Firestore offline behavior:
  <https://firebase.google.com/docs/firestore/manage-data/enable-offline>
- Firestore transactions and batched writes:
  <https://firebase.google.com/docs/firestore/manage-data/transactions>
- Federated Auth for Flutter:
  <https://firebase.google.com/docs/auth/flutter/federated-auth>
- App Check for Flutter:
  <https://firebase.google.com/docs/app-check/flutter/default-providers>
- Local Emulator Suite Rules testing:
  <https://firebase.google.com/docs/rules/unit-tests>
- Firestore emulator behavior and limitations:
  <https://firebase.google.com/docs/emulator-suite/connect_firestore>

## 25. Acceptance record

This document remains `Proposed` until the product and engineering owners:

1. resolve the open decisions in section 22 that affect the first Firebase
   implementation slice;
2. confirm consistency with all Accepted ADRs and current approved specs;
3. approve a post-stabilization Firebase slice with explicit acceptance
   criteria;
4. record the decision without claiming implementation in `LAUNCH_STATUS`.

Approval of this document authorizes planning. It does not by itself authorize
production project creation, data migration or application-code changes.
