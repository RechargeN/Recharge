# Identity, Creator Verification And Professional Publisher Slice

Status: Approved; bounded local/mock implementation allowed during stabilization
Version: 1.3
Date: 2026-07-31
Related: ADR 0013, ADR 0015, ADR 0016, ADR 0017,
`docs/architecture/FIREBASE_ARCHITECTURE.md`

## 1. Purpose

This slice makes the accepted identity model executable:

```text
Viewer = authenticated User
Creator = authenticated User + approved identity verification + grants
Professional Page access =
  verified Creator + active page membership + page capabilities
Admin tools = authenticated Admin + explicit admin capabilities
```

It also provides one canonical publisher contract for all ten accepted Create
types, one active-workspace contract and removes any implication that Creator
is a manually selected UI profile or that `Pro generator` is a fourth
persisted role.

ADR 0016 and ADR 0017 authorize only the bounded local/mock
IDP-03A/04A/05A slices during stabilization. Production auth migration,
verification authority, Firebase and externally reachable ManagedPage
publication remain post-stabilization.

## 2. Goals

1. Require authentication before any product surface is opened.
2. Preserve safe intended destinations through authentication and session
   restore.
3. Model Creator identity verification separately from Google/Apple sign-in.
4. Model Professional Page, membership, verification and lifecycle.
5. Let an eligible Creator publish as the personal profile or an authorized
   Professional Page.
6. Keep one personal Viewer UI while exposing Creator tools automatically from
   verified eligibility and grants.
7. Let one account switch between its personal workspace and its authorized
   Professional Pages without changing authentication; self-service ownership
   is limited to three pages and higher limits require moderator approval.
8. Give personal and page workspaces explicit navigation contracts.
9. Keep Admin tools separate from workspace and publisher selection.
10. Enforce verification, capabilities, publisher scope and lifecycle in
   application use cases and the production backend.
11. Preserve compatible local drafts without granting legacy data new rights.

## 3. Non-goals

- Adding a `Pro` system role.
- Adding a manual Viewer/Creator mode switch for ordinary users. An Admin-only
  presentation preview is allowed by ADR 0017 and never changes authority.
- Treating Admin tools as a workspace, publisher or page membership.
- Treating a phone number, email or provider account as automatic Creator
  verification.
- Treating a Professional Page as a physical Place.
- Claiming or verifying a business solely from a self-declared relationship.
- Adding an eleventh Create type.
- Activating Firebase during stabilization.
- Building payments, contracts, tax/KYC or payout onboarding in this slice.
- Exposing verification documents or sensitive review evidence in public
  profiles.

## 4. Access states and workspaces

| Access state | Required state | Allowed baseline |
|---|---|---|
| Viewer | Authenticated, active `User` | Discover, favorites, participation, profile; optional local pre-verification drafts |
| Creator | Viewer + approved identity verification + Creator grants | Same personal UI plus eligible Creator tools; submit/publish as personal publisher |
| Professional Page access | Creator + active membership for an exact page + page grants | Open that page workspace; manage and publish as that eligible page |
| Admin | Authenticated `Admin` + explicit admin capabilities | Verification, grants and moderation through audited operations |

Persisted roles remain `User`, `Creator` and `Admin`. `Viewer` is product
terminology for the personal consumer experience. Creator eligibility expands
that same personal experience and is not a second selectable profile.
`Professional Page` is the UI name of `ManagedPage`, not a role or generic
`Pro` level. `Pro generator` is legacy UI debt and is not used in the target
contract.

### 4.1 Active workspace

The user may select only a personal or page workspace:

```text
enum WorkspaceType { personal, page }

WorkspaceRef {
  type: WorkspaceType,
  id: ULID/UUID // userId for personal, pageId for page
}

ActiveWorkspacePreference {
  userId,
  workspaceRef,
  updatedAtUtc,
  revision,
  schemaVersion
}
```

The preference is non-sensitive local UX state. It never proves role,
verification, membership or capability. Restoring a page workspace requires a
fresh access check for the exact `pageId`. It is namespaced by permanent
`userId`; logout clears in-memory workspace state so one account can never
inherit another account's selection.

One account may have zero, one or many Professional Page memberships. A user
may self-create up to three owned pages. Invited/delegated memberships do not
consume that quota; a fourth owned page requires an approved moderator
request. The UI must support zero, one and three owned pages and remain usable
when an approved higher limit or delegated memberships make the list larger.

Admin tools are a separate protected destination. They do not appear as a
`WorkspaceRef`, do not set `PublisherRef` and cannot be selected as an active
publisher context.

An Admin with `admin.experience.preview` may preview Viewer, Creator or
Professional Page presentation. Preview is session-scoped presentation state,
not a role, workspace, publisher, verification, membership or capability
grant. Professional Page preview with no real page shows the creation
onboarding and never invents a placeholder page.

### 4.2 Navigation contract

| Active workspace | Bottom navigation |
|---|---|
| Personal Viewer or Creator | `Home · Favorites · Smart Search · Notifications · Profile` |
| Professional Page | `Page · Content · Create · Notifications · Account` |

Creator grants do not replace the personal central Smart Search destination.
Creator tools are surfaced from Profile, contextual actions and Create Hub.

In a page workspace, `Create` opens the shared Create Hub with the active page
as the default publisher. `Content` is scoped to that exact page. `Account`
opens the personal account, Settings, workspace switcher and logout; it is not
the page's public profile.

Smart Search remains available through consumer Home/Search when leaving the
page workspace, but it is not the central page-management destination.

### 4.3 Settings switcher

Settings contains one `Switch workspace` action and presents:

```text
Personal
  Personal profile

Professional Pages
  Page A
  Page B
  ...

Administration
  Admin tools // only when an explicit admin capability allows it
```

The list shows the current selection and safe page presentation data such as
name, avatar, kind, verification display state and a short capability summary.
It never exposes verification evidence or derives access from display fields.

Selecting `Personal profile` automatically exposes or hides Creator tools from
the current access snapshot. Viewer and Creator are not separate switch rows.
Selecting a page revalidates membership and page lifecycle before activation.

### 4.4 International product contract

Professional Page and content contracts use stable country/market codes, IANA
timezone, ISO currency and locale metadata. Registration, tax, KYC and payout
fields are market-specific and cannot be universal required fields.

Persisted roles, workspace types, capabilities and publisher types use stable
codes. Labels such as `Switch workspace`, `Professional Pages`, `Create` and
`Admin tools` are localization keys, not stored authorization values.

## 5. Authentication contract

### 5.1 Entry

Production providers are Google and Apple.

```text
app start / deep link
  → restore valid session
  → if absent, open auth
  → authenticate
  → ensure Recharge profile
  → load access snapshot
  → load page projection and validate active workspace
  → resume safe intended destination
```

There is no guest Discover destination. Logout, revocation and unrecoverable
expiry clear local session authority and return to auth.

The intended destination must be allowlisted and normalized. Authentication
parameters, tokens and arbitrary external URLs are never replayed as internal
destinations.

### 5.2 Authentication is not verification

These facts are distinct:

- provider identity and provider token validity;
- verified provider email or phone;
- Recharge Creator identity verification;
- Professional Page verification;
- membership and page-scoped authority.

UI and analytics must not label one fact as another.

## 6. Creator verification

### 6.1 Canonical state

```text
CreatorVerification {
  userId,
  status: notStarted | pending | verified | rejected | expired | revoked,
  level: identityDocument,
  submittedAtUtc?,
  decidedAtUtc?,
  expiresAtUtc?,
  decisionReasonCode?,
  revision,
  schemaVersion
}
```

The public profile receives only a safe display projection. Documents,
provider references, reviewer notes and evidence stay in server-private
storage with least-privilege access and retention policy.

### 6.2 Transitions

```text
notStarted → pending → verified
                     ↘ rejected
verified → expired | revoked
rejected | expired → pending
```

Only trusted operations decide, expire or revoke verification. Every decision
records actor, reason, time and revision in audit.

### 6.3 Access behavior

- A Viewer may start verification from an Upgrade surface.
- A Viewer may keep a local pre-verification draft.
- Submit and publish fail closed unless verification is `verified`.
- A rejected, expired or revoked Creator cannot start new submit/publish
  operations.
- Existing published content is not silently deleted when verification
  changes; moderation policy decides visibility and management rights.

## 7. Professional Page

`Professional Page` is the product/UI name of the canonical domain
`ManagedPage`. It does not introduce a second page aggregate.

### 7.1 Page model

```text
ManagedPage {
  id,
  kind: company | organization | representativeOffice
      | venueOperator | privateProfessional,
  displayName,
  slug?,
  description?,
  media,
  contactProjection,
  serviceCategoryIds,
  placeIds,
  verificationStatus: unverified | pending | verified | rejected | revoked,
  lifecycle: draft | pendingReview | active | suspended | archived,
  ownerUserId,
  revision,
  schemaVersion
}
```

`placeIds` link a professional publisher to physical Place aggregates. They do
not make the page and Place the same entity.

Examples include a Recharge-compatible venue, company, organization,
representative office or a private provider of services.

The default account starts with zero pages. A page appears only after the user
creates it or receives an explicit membership. Local/mock fixtures must not
pre-create pages on the user's behalf.

### 7.2 Membership

```text
ManagedPageMembership {
  pageId,
  userId,
  relationship: owner | manager | editor,
  status: invited | active | suspended | revoked,
  capabilities,
  grantedAtUtc?,
  revokedAtUtc?,
  grantedByUserId?,
  revision
}
```

Membership and capabilities are scoped to one page. At minimum the policy
distinguishes page profile management, content creation, content submission,
publication, insights and bookings.

### 7.3 Creation quota and moderation request

- Pages one through three may be self-created by an eligible user.
- Only `relationship: owner` pages consume the self-service quota.
- Attempting page four creates no page and offers one idempotent
  `PageLimitIncreaseRequest`.
- A pending request is visible to the user and moderator inbox.
- Only an approved moderator decision raises the effective quota.
- Bounded local/mock work may store `pending`; it must not simulate production
  approval.

Page creation notifies the user that review is pending and creates a
moderator-inbox notification. A quota request notifies both audiences. These
events use stable ids and contain no identity evidence.

### 7.3 Verification separation

- Creator verification proves the responsible person's accepted identity.
- Page verification proves the accepted professional entity or representation.
- Membership proves the person's current authority on the page.

All three may be required by market or action policy. None implies another.

## 8. Canonical publisher

```text
enum PublisherType { user, page }

PublisherRef {
  type: PublisherType,
  id: ULID/UUID
}
```

Every Create draft and published content envelope stores one `PublisherRef`.
The draft also stores `createdByUserId` for audit. Ownership, authorship and
publisher are not interchangeable.

Publisher display data is loaded by ID. A bounded snapshot may be placed in a
catalog projection, but it is never the authorization source.

For a new draft, active workspace supplies only the default publisher:

| Active workspace | Default publisher |
|---|---|
| Personal | `{type: user, id: userId}` |
| Professional Page | `{type: page, id: pageId}` |

An existing draft's persisted `PublisherRef` takes precedence over active
workspace. Switching workspace never silently rewrites the draft publisher.
Admin tools do not have a publisher mapping.

## 9. Create Hub behavior

### 9.1 Access and draft preparation

1. Require an authenticated session.
2. Load Creator verification and capability snapshot.
3. Validate the active workspace without treating it as authority.
4. Resolve personal and page publisher candidates.
5. Apply workspace only as the default publisher for a new draft.
6. A Viewer without verified Creator eligibility sees the Upgrade state.
7. If draft preparation is enabled, the Viewer may edit and autosave locally,
   but submit/publish controls remain locked with a clear next action.

Opening the form does not promise submit or publish eligibility.

### 9.2 `Publish as`

- One eligible personal publisher: select automatically.
- Personal plus one or more eligible pages: show `Publish as`.
- More than one eligible page: show `Publish as`.
- A page candidate displays name, kind, avatar, verification state and the
  applicable capability summary.
- The selection writes only `{type, id}` to the canonical draft field.
- Switching publisher re-runs type, market and page-scoped policy validation.
- Switching active workspace does not silently apply to an existing draft.

### 9.3 Revoked access

If page access is revoked after draft save:

- the draft remains readable by its draft owner where policy permits;
- page publish and submit fail closed;
- UI requires selection of another eligible publisher;
- no automatic silent switch changes the publisher identity.

If revoked or suspended page access invalidates the currently active
workspace, the app returns to `Personal profile`, explains the reason and
removes the invalid page only from future workspace choices. It still does not
rewrite any persisted draft publisher.

### 9.4 Submit and publish decision

For every accepted Create type:

```text
authenticated
  AND account active
  AND Creator verification verified
  AND create/submit/publish capability for the operation
  AND eligible PublisherRef
  AND active page membership when publisher.type == page
  AND page-scoped capability
  AND valid content and lifecycle
```

The application use case evaluates this before repository mutation. Production
backend authorization repeats the decision and records the audit event.

## 10. Capability baseline

Exact codes are versioned by the implementation slice. The minimum semantic
matrix is:

| Operation | Personal publisher | Page publisher |
|---|---|---|
| Prepare local draft | Authenticated Viewer policy | Active member with view/draft access |
| Create durable draft | Verified Creator + `create.<type>` | Same + page-scoped create |
| Submit to moderation | Verified Creator + `submit.<type>` | Same + active membership/page submit |
| Publish directly | Explicit trusted `publish.<type>.direct` | Same + active membership/page publish |
| Edit/archive | Ownership/capability + lifecycle | Active membership + page-scoped capability |
| Manage page | Not applicable | `manage_page` for the exact page |
| Insights/bookings | Not implied by publish | Separate `view_insights` / `manage_bookings` |

A role name alone never authorizes the operation.

## 11. Data and migration

### 11.1 Draft compatibility

- Add one versioned publisher field to the shared Create envelope.
- Read aggregate-specific legacy publisher fields through compatibility
  mappers.
- Existing drafts without a valid publisher resolve to an explicit
  `publisherSelectionRequired` state.
- Never infer a page publisher from organizer name, email, Place name or
  business relationship text.
- Temporary local IDs must be replaced by permanent ULID/UUID values before
  submit/publish.

### 11.2 Existing mock accounts

The current full-access demo account is test data, not migration evidence. It
must use an explicit seeded Admin role, explicit admin capabilities, verified
Creator state, personal Creator grants and page-scoped memberships. Role alone
does not grant personal or page publication.

The mock fixture must contain enough distinct pages to demonstrate switching
and permission isolation, while tests cover zero, one, five and larger page
sets. A capability such as `scenario.generate` must not derive a persisted Pro
role or unlock a Professional Page workspace.

### 11.3 Backend authority

Clients cannot write:

- global role;
- Creator verification decision;
- page verification decision;
- page membership grants;
- privileged capabilities;
- audit decision metadata.

## 12. UX states

Required states:

- authentication required;
- session restoring;
- Creator verification not started;
- verification pending;
- verification rejected with safe reason and retry path;
- verification expired/revoked;
- no eligible publisher;
- no available Professional Pages;
- active personal workspace;
- active Professional Page workspace;
- workspace restoring;
- workspace selection rejected;
- active page suspended or access revoked;
- publisher selection required;
- page access revoked;
- Admin tools available or capability denied;
- submit/publish capability missing;
- pending moderation;
- published.

The UI must explain the next action without exposing sensitive verification or
moderation evidence.

## 13. Security and privacy

- Verification evidence is private, encrypted according to platform policy and
  excluded from public profile documents and analytics payloads.
- Logs use opaque IDs and stable reason codes, not document images or identity
  values.
- Page membership checks use exact page ID and active revision.
- Active workspace preference is never used as authorization evidence.
- Admin capability does not imply page membership or publisher eligibility.
- Submit/publish commands are idempotent and reject stale access snapshots.
- Revocation is fail-closed for future privileged mutations.
- Backend rules or trusted operations repeat all client-side checks.
- Retention, deletion, appeal and legal review must be accepted before
  production identity-document collection.

## 14. Delivery slices

ADR 0016 permits only rows marked `During stabilization`. All other rows remain
behind stabilization exit and their separate provider/security gates.

| Slice | Timing | Scope | Exit evidence |
|---|---|---|---|
| IDP-01 | After stabilization | Mandatory auth routing and safe intended destination | router/controller/widget tests; no guest entry |
| IDP-02 | After stabilization | Creator verification lifecycle, production-safe workflow and Upgrade UX | transition, privacy, legal and publish-denial tests |
| IDP-03A | During stabilization | Local/mock access snapshot, explicit Admin fixture, user-created Professional Page/membership, ownership quota 3, active workspace, Settings switcher and local notification events | domain/repository/access matrix plus zero/one/three/over-limit tests |
| IDP-04A | During stabilization | Workspace-aware shell navigation and local default `PublisherRef` behavior | personal/page navigation, draft non-rewrite and local integration tests |
| IDP-05A | During stabilization | Local application/router guards, bounded Admin entry and revocation behavior | negative authorization/idempotency/deep-link tests |
| IDP-03B/04B/05B | After stabilization | Production page authority, all-ten-type PublisherRef migration, audit and backend enforcement | migration, emulator, security and all-ten-type integration gates |
| IDP-06 | After stabilization and separate approval | Firebase adapters, Rules and trusted operations | emulator, device, security and migration gates |

Each slice requires its own approved implementation scope. IDP-03A/04A/05A
must not collect real evidence, write authoritative grants, approve production
quota changes or expose production ManagedPage publication. `IDP-06` remains
blocked until Firebase is separately authorized.

### 14.1 Local/mock rollout

```text
IDP-03A contracts, zero-page fixture, create/quota/notification and switcher
  → IDP-04A workspace shell and new-draft publisher defaults
  → IDP-05A guards, Admin entry and negative coverage
```

Partial activation must be guarded so the personal consumer flow remains
usable. A local page workspace is demo/test state and must not be labelled
production-verified.

### 14.2 Local/mock rollback

Rollback disables page workspace activation and returns to the personal shell.
Workspace preferences and local user-created pages may remain readable, but
they grant no production mutation authority. Existing drafts retain their
stored `PublisherRef`; no rollback performs a silent or bulk publisher
rewrite.

## 15. Acceptance criteria

- **IDP-AC-01:** No product surface opens without a valid authenticated
  Recharge session.
- **IDP-AC-02:** Google/Apple authentication alone does not grant Creator.
- **IDP-AC-03:** Viewer can enter Upgrade and retain an allowed local draft,
  but cannot submit or publish.
- **IDP-AC-04:** Only `verified` Creator verification is eligible for new
  privileged Create mutations.
- **IDP-AC-05:** Persisted roles are limited to `User`, `Creator`, `Admin`.
- **IDP-AC-06:** Creator eligibility expands the personal profile without a
  manual Viewer/Creator switch or a different personal bottom navigation.
- **IDP-AC-07:** One account can manage multiple Professional Pages without
  cross-page permission leakage.
- **IDP-AC-08:** Creator and page verification are visibly and technically
  distinct.
- **IDP-AC-09:** All ten accepted Create types use canonical `PublisherRef`.
- **IDP-AC-10:** `Publish as` appears whenever publisher choice is ambiguous.
- **IDP-AC-11:** Revoked membership blocks page submit/publish without silently
  changing the draft publisher.
- **IDP-AC-12:** Application and backend both fail closed on missing or stale
  verification, membership, capability or lifecycle data.
- **IDP-AC-13:** Legacy drafts migrate without inferring page ownership from
  display fields.
- **IDP-AC-14:** Public profiles, analytics and logs contain no verification
  documents or sensitive evidence.
- **IDP-AC-15:** Full `flutter analyze` and `flutter test` are green for every
  implementation slice.
- **IDP-AC-16:** Settings switches only between `Personal profile` and
  authorized Professional Pages; Viewer and Creator are not separate rows.
- **IDP-AC-17:** Personal Viewer and Creator use
  `Home · Favorites · Smart Search · Notifications · Profile`.
- **IDP-AC-18:** Professional Page uses
  `Page · Content · Create · Notifications · Account`, scoped to the exact
  active page.
- **IDP-AC-19:** Active workspace is restored only after fresh access
  validation and never acts as authorization evidence.
- **IDP-AC-20:** Switching workspace supplies a default publisher only for a
  new draft and never silently changes an existing draft's `PublisherRef`.
- **IDP-AC-21:** Default access fixtures contain zero user-owned Professional
  Pages; a page appears only after explicit creation or membership.
- **IDP-AC-22:** A user may self-create at most three owned Professional Pages;
  a fourth page is not created without approved additional quota.
- **IDP-AC-23:** A fourth-page attempt can submit one idempotent pending request
  to moderators and does not grant its own approval.
- **IDP-AC-24:** Page creation and quota requests create idempotent local
  notifications for the user and moderator inbox.
- **IDP-AC-25:** Admin Viewer/Creator/Professional Page preview changes only
  presentation and cannot authorize workspace, publisher or mutations.
- **IDP-AC-21:** Suspended/revoked active page access returns the shell to the
  personal workspace with an explanation and blocks future page mutations.
- **IDP-AC-22:** Admin tools require explicit admin capabilities, are
  deep-link guarded and never become a workspace or publisher.
- **IDP-AC-23:** Workspace, publisher and page contracts remain market-neutral
  through stable locale, country/market, timezone and currency codes.

## 16. Required test matrix

At minimum:

- cold start, logout, expiry, revocation and deep-link auth restoration;
- provider auth success without Creator eligibility;
- every Creator verification transition and forbidden client mutation;
- personal publisher eligibility;
- zero, one, five and larger Professional Page membership lists;
- personal workspace restoration with and without Creator eligibility;
- no manual Viewer/Creator switch and identical personal bottom navigation;
- page workspace navigation scoped to the selected page;
- Settings selection between personal and authorized page workspaces;
- stale, suspended and revoked active workspace preference;
- membership suspended/revoked between draft save and publish;
- page A capability never authorizes page B;
- changing page A to page B does not rewrite an existing draft publisher;
- Admin role without admin capability and capability without page membership;
- Admin tools deep-link denial and confirmation that Admin is not a publisher;
- separate Creator/page verification badges;
- PublisherRef mapper round-trip and all supported legacy shapes;
- all ten Create types through personal and page publisher policy;
- stale revision, duplicate submit and idempotent retry;
- backend emulator denial for forged role, verification, membership,
  publisher and audit fields;
- compact viewport, long translated labels, RTL-safe layout and accessibility
  text scale for Upgrade, workspace switching and `Publish as`.

## 17. Definition of Done

IDP-03A/04A/05A may individually reach Done during stabilization when their
bounded acceptance criteria and repository gates pass. That status proves only
local/mock behavior.

The overall production flow is Done only when:

1. stabilization has exited;
2. ADR 0015 remains Accepted;
3. all delivery slices required for the selected environment are Done;
4. target architecture and implementation agree on mandatory auth;
5. personal/page workspace switching and navigation meet this contract;
6. publisher selection and enforcement work for all ten Create types;
7. Admin tools remain capability-gated and separate from publisher workspaces;
8. negative authorization tests are green;
9. privacy, security and legal review approve production verification data;
10. localization QA covers supported languages and international metadata;
11. `flutter analyze` and `flutter test` are green;
12. `LAUNCH_STATUS.md` records exact evidence and remaining production gates.
