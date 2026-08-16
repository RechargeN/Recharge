# RECHARGE — Professional Page Functional Specification

Status: **Draft for product and architecture review**

Version: **2.28**

Date: **2026-08-12**

Scope: **target full-release product; documentation only**

## 0. Document authority and purpose

This document defines the target functional model of `Professional Page` for a
full Recharge release. It deliberately includes mature product extensions
beyond a minimal MVP when they reuse the accepted architecture and do not add
disproportionate delivery, operational or privacy cost.

This document is not an Accepted ADR, does not replace the approved Identity /
Publisher contract and does not authorize runtime, Firebase, backend,
verification, Booking, Payments or provider integration. Before implementation,
each delivery slice still requires an Approved bounded slice specification.

When sources conflict, the following order applies:

1. Accepted ADRs, especially ADR 0013, 0015, 0016, 0017 and 0019.
2. The Approved current-slice specification.
3. `docs/architecture/LAUNCH_STATUS.md` — only for truth about current
   implementation, never for target product semantics.
4. An Accepted/Approved owning aggregate specification or shared
   cross-product contract (e.g. Category System and Scenario; once
   approved, the canonical Review contract or a future `FollowRelation`
   foundation).
5. Draft profile-surface specifications on equal footing with each
   other — this document and all sibling profile documents
   (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`, `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`,
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`). None of them outranks
   another by virtue of which one a reader opened first; a conflict between
   them is blocked per §1.1, not resolved by this tier ordering.
6. `docs/product/VISION.md` and other general product material.

Canonical supporting sources:

- `docs/adr/0013-domain-policy-baseline.md`;
- `docs/adr/0015-authenticated-viewer-verified-creator-professional-page.md`;
- `docs/adr/0016-bounded-identity-workspace-during-stabilization.md`;
- `docs/adr/0017-admin-experience-preview-and-user-created-pages.md`;
- `docs/adr/0019-authoritative-internal-booking-ledger.md`;
- `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md`;
- `docs/product/CATEGORY_SYSTEM.md`;
- `docs/product/EVENT_CLASSIFICATION_SPEC.md`;
- `docs/product/SCENARIO_BUILDER_SPEC.md`;
- `docs/product/ROUTE_BUILDER_SPEC.md`.

### 0.1 Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` and their Russian equivalents are
normative. `Target` describes intended full-release behavior. `Current` is
only a status snapshot and must be verified in `LAUNCH_STATUS.md` before work.

### 0.2 Current implementation boundary

At the date of this document:

- `IDP-03A` is in Review: local/mock pages, quota, membership, notifications
  and workspace selection exist but do not prove production authority;
- `IDP-04A` is Doing: the workspace-aware shell exists; the shared
  `PublisherRef` **type** is already consumed by Place and Event, but full
  active-workspace default/non-rewrite coverage is confirmed only for
  Event — the remaining nine Create types (which still includes Place, for
  that fuller coverage) are pending. Do not collapse this into "Event
  only";
- `IDP-05A` is Planned: complete application/router guards and negative
  cross-page coverage are not Done;
- production Auth, Creator/Page verification, remote membership authority,
  Firebase enforcement and externally reachable Professional Pages remain
  gated.

No target statement below may be presented as currently implemented unless
`LAUNCH_STATUS.md` contains corresponding evidence.

## 1. Product definition

`Professional Page` is the product/UI name of the single canonical domain
aggregate `ManagedPage`. It is a professional publisher and workspace for a
company, organization, representative office, venue operator or private
professional.

Professional Page answers: **“What do I represent and manage in Recharge?”**
Personal profile answers: **“Who am I?”**

Professional Page is simultaneously:

- a safe public identity projection;
- an exact-page management workspace;
- a publisher context for the shared Create Hub;
- a team and capability boundary;
- a container for page-scoped projections such as content lists, operational
  notifications and aggregate analytics.

It is not:

- a fourth global role or a `Pro generator` mode;
- a replacement for the personal profile;
- a physical `Place`;
- a second Create system;
- an Event, Booking, CRM, chat or payments aggregate;
- an authorization shortcut based on display name, category or active tab.

### 1.1 Relationship to sibling documents

Professional Page is one of four audience-scoped surfaces over the same
underlying canonical aggregates, not a competing model. Surfaces are split
by *who is looking*, not by *what data exists*. Framed by product/profile
architecture, three of the four are personal-identity documents (Viewer,
Creator, Public Creator) and this one is a `ManagedPage` peer, not a fourth
personal-identity document — a distinction `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
§0 already states explicitly. That distinction is about what each document
is *about*; it does not change the equal-footing conflict-precedence tier
below (§0 item 5), where all four still sit together with none outranking
another. The right-hand column is
**primary surface responsibility** — which document specifies the UI/UX and
policy for that concern — not aggregate ownership: canonical aggregate
ownership always stays with that aggregate's own accepted domain
specification or ADR (`Scenario`, Booking/Hold/ledger, `ManagedPage`, an
approved canonical Review contract once one exists, etc.), regardless of
which profile document displays a projection of it.

| Document | Audience | Primary surface responsibility |
|---|---|---|
| `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` | The Viewer, about themselves | Scenario, Quick Plan, Favorites, Saved Searches, Visit History, personal participation, authored Reviews, photos, account/session state, and the baseline Public User Projection — shown only within a legitimate trigger context (Review, Find People response, invited Scenario, shared plan), never as a standalone searchable profile for every `User` |
| `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | The Creator, about themselves | `CreatorVerification` lifecycle, the personal `PublisherRef{type: user}` context, management of their own Created content, and the *private* workspace/publisher relationship to managed Professional Pages — public display of the Creator↔Page cross-link is owned separately by `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `PCP-D05` |
| `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | Any other Viewer, about a verified Creator | The public card for a verified Creator — extends the Public User Projection with verification badge, specialization, published-content list, Follow, and (§5 there) public Creator↔Page cross-link display (`PCP-D05`). Aggregated reviews-about-*content* display is gated only on `PCP-D04` and is independent of `VP-D08`; reviews-about-a-*person* remain a separate, unaccepted feature gated on `VP-D08` alone |
| This document | Any other Viewer, about a page; the page's own team | `ManagedPage` in full — team, page lifecycle, a page-scoped Booking **management projection**, and its own public projection (§8.2). The `Booking`/`BookingHold`/ledger aggregates themselves remain owned by the authoritative Booking contract (ADR 0019, §13) — this document owns the authorization boundary and UI over them, not the aggregates |

**Verified-against snapshot.** Every citation of a sibling document above
and throughout this document was last cross-checked directly against
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.15,
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9 and
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9, as of 2026-08-16 — the
prior pin (v1.10/v1.4/v1.3) had gone stale by several versions each on the
sibling side. Re-verification against the current text found this
document's specific citations (`PP-D44`'s trilateral status, the
`FollowRelation`/`FollowRef` shape mismatch, `PersonalScenarioRef` vs.
`QuickPlanRef`'s field split, and `PCP-D05`'s location) still accurate —
none of the sibling documents' intervening changes altered what was cited
here. This is
a deliberate boundary, not a claim of permanence: a sibling document moving
past its pinned version here does not retroactively make this document
wrong, but it does mean this document's citations of that specific sibling
have not yet been re-verified against the newer text and MUST be treated as
unconfirmed — never silently assumed still accurate — until the next
verification pass updates this line. Cross-document correctness is a
snapshot property of a multi-document Draft ecosystem, not a permanent one;
this document does not claim otherwise.

None of these documents stores data independently — each is a
presentation/aggregation surface over the same canonical aggregates
(`UserProfile`, `CreatorVerification`, Create content, `ManagedPage`,
Favorites, Scenario, etc.). A surface already owned by one document is
referenced, never redefined, by the others. Before changing a shared
invariant here — `PublisherRef`, the `revision`-based fail-closed rule, or
state-family separation (§10.1) — check whether the sibling documents state
the same invariant; this document is not automatically authoritative for
all four.

**When sibling documents disagree.** §0 remains the single controlling
repository-level precedence — this section does not introduce a competing
order. §0 item 4 (an owning aggregate's specification or an Approved shared
cross-product contract, e.g. a future `FollowRelation` foundation, `PP-D44`
below) defines aggregate semantics before any profile document's own
wording does. All four sibling profile documents sit together in §0 item
5's Draft profile-surface tier — none outranks another. If two of them
still disagree on a shared invariant within that same tier and no
higher-priority source in §0 resolves it, implementation of that invariant
is blocked pending a joint decision — neither document's wording wins by
default. `LAUNCH_STATUS.md` (§0 item 3) remains the source of
implementation truth, never a source of target product semantics.

Two terms collide across these documents and MUST be disambiguated on every
use, never left implicit:

- **`owner`** means two different things depending on which document is
  speaking: `ManagedPageMembership.relationship = owner` (a page-team role,
  §5.3 of this document) versus a personal content item's own ownership
  role. For **Scenario**, `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2's
  `PersonalScenarioRef.accessRole: owner | editor | viewer | unlistedViewer`
  is the Approved four-role model per
  `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1/§10.2 — it already has both
  `owner` and `editor`. For **Quick Plan** — a separate aggregate, not
  Scenario — `QuickPlanRef.relationship: owned | invited` is a different,
  genuinely undecided field with no `owner`/`editor` distinction at all
  (that document's own `VP-D02`). Earlier drafts of this document
  conflated the two by attributing Quick Plan's field to Scenario; neither
  `owner` sense here implies or grants the other, and Scenario and Quick
  Plan MUST NOT be conflated (§9 already states they are separate
  aggregates for Create Hub purposes; the same separation holds for their
  personal-library collaboration fields).
- **Follow** is not yet confirmed as one shared relationship/consent/
  retention model or two deliberately separate ones — following a page
  (§12.2, `PP-D06`) and following a person
  (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s `VP-D12`,
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `PCP-D02`) may or may not
  share a contract. This is now a **trilateral** open decision —
  `PP-D44`/`VP-D12`/`PCP-D02` — actively cross-referenced by all three
  documents' own decision-tracking tables; an earlier version of this
  document called it unreciprocated, which is no longer accurate and is
  corrected here. It remains `Open` in every one of the three; none may be
  marked `Approved` alone. The documents have not converged on one data
  shape: this document's `FollowRelation` (§20) uses a discriminated
  `target: {type: user | page, id}` covering both person- and page-follow
  in one contract, while `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s own proposed
  `FollowRef{followerUserId, followedUserId, createdAtUtc}` has no target
  discrimination and cannot represent following a page at all. Reconciling
  that shape mismatch — not only the party count or policy — is itself
  part of what the joint decision must resolve.

## 2. Full-release extension policy

Professional Page is designed for a complete product release, not only for the
smallest MVP. A capability is retained in the target scope when all of the
following are true:

1. It solves a recurring page-management job.
2. It reuses accepted aggregates, repositories and the shared Create engine.
3. It is provider-neutral and can degrade honestly when offline or unavailable.
4. It does not silently broaden access, collect sensitive data or create a new
   source of truth.
5. It can be delivered behind a bounded flag with tests and rollback.

Features requiring authoritative concurrency, money movement, high-volume
messaging, identity evidence, contact import or externally reachable private
sharing remain part of the target model but require separate gates.

The specification uses three delivery classes:

| Class | Meaning |
|---|---|
| Release foundation | Required to make Professional Page coherent and safe |
| Mature extension | Valuable for full release and suitable for incremental, reversible slices |
| Gated expansion | Retained in target architecture but blocked on backend, legal, provider or operational readiness |

## 3. Canonical identity, workspace and publisher model

### 3.1 Access states

```text
Viewer = authenticated active User

Creator = Viewer
  + CreatorVerification.status == verified
  + required personal grants

canOpenPageWorkspace = authenticated active User
  + exact active ManagedPageMembership at its current
    ManagedPageMembership.revision
  + compatible page lifecycle

canPerformPageAction = canOpenPageWorkspace
  + exact page-scoped capability for that action
  + compatible page verification policy
  + verified Creator, only when that action requires Creator authority
```

`canOpenPageWorkspace` and `canPerformPageAction` are deliberately different:
opening the workspace requires only active membership at its current
`ManagedPageMembership.revision` (§4.1) and a compatible lifecycle, never a
capability — the revision check exists specifically so a stale cached
membership snapshot cannot open a workspace after revocation. Performing any
privileged action requires the full chain in §3.4. `ManagedPageMembership.revision`
is the one field this document means whenever it says "access revision" —
no separate `authorityRevision` field exists. "Professional Page access" as
a single phrase is ambiguous and MUST NOT be used normatively elsewhere in
this document — every rule states which of the two it means.

A page team member is **not** required to be a verified Creator merely to
hold membership and open the workspace — `canOpenPageWorkspace` above does
not include Creator verification. §3.5 is the single normative statement of
exactly which operations require it; this section does not restate that
list. A non-Creator staff member's Create Hub view accordingly shows only
what their capabilities and Creator status jointly allow, never a blanket
lock-out of the whole workspace. An implementation that gates the entire
workspace shell behind Creator verification — as the current local/mock
`canActivatePage()` does — is not compliant with this model and must
migrate to the per-action check in §3.4/§3.5 (`PP-D27`, Accepted).

Persisted global roles remain only:

```text
User | Creator | Admin
```

`Pro` and `Pro generator` MUST NOT be stored roles, workspace types, publisher
types or authorization inputs. Commercial packaging, if introduced later,
must use a separate entitlement model and neutral product naming.

### 3.2 Workspace

```text
WorkspaceRef {
  type: personal | page,
  id: ULID/UUID
}
```

The user switches only between:

```text
Personal profile ↔ Professional Page A ↔ Professional Page B ↔ ...
```

Viewer and Creator are not separate switch rows. Creator tools appear inside
the same personal experience when verification and grants permit them.

Active workspace is a namespaced UX preference, never authorization evidence.
Every restoration of a page workspace MUST revalidate exact `pageId`,
membership, lifecycle and access revision. Invalid, suspended or revoked page
access returns the shell to Personal profile with a safe explanation.

`canOpenPageWorkspace` (§3.1) alone opens the page workspace shell; it does
not itself grant any privileged action. A member with active membership and
an empty capability set MAY open the workspace and see a safe restricted
state — each destination and mutation independently requires its own
`canPerformPageAction` per §3.4 and §7. Implementations MUST NOT treat
"workspace opened" as evidence of any capability, and MUST NOT grant an
implicit default capability just to avoid an empty shell.

### 3.3 Publisher

```text
PublisherRef {
  type: user | page,
  id: ULID/UUID
}
```

Every Create draft and published envelope stores one `PublisherRef` plus the
acting `createdByUserId`/audit actor where required.

- Personal workspace defaults a new draft to `{type: user, id: userId}`.
- Page workspace defaults a new draft to `{type: page, id: pageId}`.
- An existing draft keeps its persisted publisher after workspace switching.
- Ambiguous eligibility requires an explicit `Publish as` choice.
- Publisher display snapshots never authorize actions.
- Admin tools have no publisher mapping.

### 3.4 Page activation and mutation decision

Every privileged mutation MUST evaluate the full `canPerformPageAction`
(§3.1) chain — never `canOpenPageWorkspace` alone:

```text
authenticated and active actor
AND verified Creator when the action requires Creator authority
AND exact page membership is active
AND required exact-page capability is present
AND access snapshot/revision is current
AND page lifecycle permits the action
AND page verification policy permits the action
AND target aggregate lifecycle permits the action
AND command is valid and idempotent
```

UI/router guards improve UX. Application use cases enforce the decision, and
the production backend repeats it. Unknown or stale authority fails closed.

### 3.5 Non-Creator staff verification rule (`PP-D27`, Accepted)

This is the single normative statement of which page operations require
personal Creator verification versus only the page-scoped capability in
§3.4's chain. Every other reference in this document (§3.1, §9.1, `PP-AC-68`)
points here rather than restating it, so the rule has exactly one place to
change:

> Creator verification is required when content crosses the private-draft
> boundary and becomes reachable for moderation, review or public
> distribution: submit, publish, republish and scheduled publish taking
> effect. It is not required for opening the workspace, drafting, editing an
> unsubmitted draft, reducing public reach, Booking/check-in operations, or
> ordinary page/team management under an assigned capability. An
> unclassified operation fails closed — treated as requiring verification —
> until it is explicitly added to the table below.

| Operation | Creator verification required? |
|---|---|
| Open the page workspace | No |
| View existing drafts | No |
| Create a new draft | No |
| Edit an existing draft | No |
| Submit for review | Yes |
| Publish | Yes |
| Republish after edit | Yes |
| Scheduled publish taking effect | Yes |
| Unpublish / archive as a safety action | No |
| Delete (soft/tombstone) | No |
| Ownership transfer | No — gated by `PP-D30` step-up authentication instead |
| Co-host accept/end | No — gated by exact-page capability (`PP-AC-74`) |
| Media/template management (save, edit, delete) | No — capability-gated (§7) |
| Manage Booking under an assigned capability | No |
| Check-in | No |
| Edit page profile/metadata | No — capability-gated (`manage_page`-class) |
| Manage team | No — capability-gated (`manage_team`-class) |
| *(any operation not listed above)* | Yes, fail-closed until explicitly added |

## 4. Domain contracts and invariants

### 4.1 Accepted core entities

The entities below are the accepted **semantic model** — which fields exist,
what they mean and, where applicable, which external registry defines valid
values. This is not the wire/schema contract: exact serialized field names,
storage layout and `schemaVersion` numbering are a separate decision (PP-D13).

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
  marketId,
  countryCode,
  defaultLocale,
  timezone,
  defaultCurrency,
  supportedLocales,
  verificationStatus: unverified | pending | verified | rejected | revoked,
  lifecycle: draft | pendingReview | active | suspended | archived,
  ownerUserId,
  revision,
  schemaVersion
}

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

`ManagedPageMembership.status=invited` is retained above for read
compatibility with existing/legacy data only:

```text
invited status = legacy read-compatibility only;
new writes MUST use TeamInvitation (§22.1) instead;
acceptance creates an active membership atomically —
  never a two-step invited→active transition on new writes.
```

New invitations MUST NOT create a membership row in `invited` status —
§22.1's `TeamInvitation` is the only pre-acceptance record for a new
invitation. Removing `invited` from this accepted enum outright is a
separate contract/ADR-gated decision (`PP-D28`), not something this
document changes unilaterally; until then, the value stays defined but
unused by new code paths.

`ManagedPage` and `Place` are different aggregates. `placeIds` are stable
references only. A company rename cannot change content ownership, and a Place
address/name cannot become publisher identity.

The current contract has one canonical `ownerUserId`. Co-ownership and
ownership transfer MUST NOT be inferred from a second `owner` membership;
they require a separately approved transition contract.

ADR 0016/0017 require explicit stable market/country, locale, IANA timezone
and ISO currency metadata, and the current local `ManagedPageEntity` stores the
fields above as required values. The semantic types below are accepted now;
exact wire names, storage layout and schema version remain the responsibility
of the Approved implementation slice (PP-D13).

These values are metadata inputs to policy resolution, not authority. A client
or page owner cannot relax age, privacy, verification, availability, tax or
other market rules by changing page metadata. Production policy is
server-owned and resolves only validated codes. At minimum:

- `marketId` resolves against a versioned Recharge-owned market registry, not
  a public standard;
- `countryCode` uses ISO 3166-1 alpha-2;
- `timezone` is an IANA TZDB identifier;
- `defaultCurrency` uses ISO 4217;
- `defaultLocale`/`supportedLocales` are normalized BCP 47 language tags, with
  `defaultLocale` present in a deduplicated `supportedLocales`;
- an unknown or unsupported value fails closed only for the operation that
  depends on that specific field, never for unrelated operations: `timezone`
  gates scheduling, `defaultCurrency` gates price/payment display,
  `countryCode`/`marketId` gate legal/age/verification policy, and locale
  values gate localized publication/readiness;
- metadata changes never change membership, capability or `PublisherRef`.

### 4.2 Proposed profile extension

The following fields are useful for full release but are not yet accepted as
part of the canonical `ManagedPage` contract:

```text
ManagedPageProfileExtension {
  pageId,
  shortDescription?,
  customActivityLabel?,
  secondaryServiceCategoryIds,
  activityTagIds,
  operatingArea?,
  publicContactPolicy,
  socialLinks,
  modulePreferences,
  revision,
  schemaVersion
}
```

They MUST be introduced additively through an Approved slice. Unknown/newer
fields must round-trip without downgrade. Sensitive contacts, verification
evidence, team data and internal moderation notes never belong in the public
profile projection.

`ManagedPagePublicAttribute` and `ManagedPagePublicSection` are **reserved
names for a possible future bounded profile-builder extension** — they are
not fields of `ManagedPage` or of `ManagedPageProfileExtension` above, and no
implementation may add a generic `attributes`/`sectionData` map to either
merely because these names are reserved here. If product evidence later
justifies structured custom profile sections, that extension requires its own
Approved slice with an allowlisted value-type set, size/cardinality limits and
moderation — and it MUST NOT carry Booking, payment, provider, capability,
verification or lifecycle semantics. Reserving the names now exists only to
stop an ad hoc generic-JSON field from being added under a different name
before that slice is approved.

### 4.3 Invariants

1. All entity relations use permanent IDs, never display names.
2. Page A capabilities never authorize Page B.
3. Workspace preference never proves authority.
4. Category, custom label and module preference never grant a capability.
5. Enabling a module never creates a new domain aggregate or Create type.
6. Creator verification, page verification and membership are independent.
7. Existing content is not silently reassigned when membership or workspace
   changes.
8. Published content has an explicit publisher and actor audit trail.
9. Page suspension/revocation fails closed for future privileged mutations.
10. Local/mock state never claims production verification or publication.

### 4.4 Structural relations (`PP-D47`, Accepted)

`§4.1`'s `placeIds` establishes that a page may reference Places by stable
ID and that a relation never becomes authority; it remains unchanged and
continues to serve the simple Page→Place reference case for read
compatibility. `ManagedPageRelation` is a separate, accepted entity — not a
refinement of `placeIds`, which is structurally Page→Place-only and cannot
represent the Page→Page (`branchOf`, `partnerOf`) or Page→Provider
(`providerOf`) kinds below:

```text
ManagedPageRelation {
  id,
  sourcePageId,
  relationKind,   # v1 registry: operatesPlace | branchOf | partnerOf | providerOf
  targetRef,      # stable typed ref: {type: place | page | provider, id}
  verificationStatus: unconfirmed | verified,
  displayOrder?,
  revision
}
```

An unconfirmed relation displays with a neutral "unconfirmed" label in the
public projection (§8.2) rather than being hidden or shown as equivalent to
a verified one. The following invariants apply:

- a relation is never authority — it does not grant management, capability
  or `PublisherRef` (§4.3(1)/(3));
- a page-to-Place relation never copies or overrides Place geometry/address
  — Place remains the sole geometry authority (§4.1);
- an Event relation to a page (co-organizer, host, venue) remains
  Event-owned and is never duplicated here as page authority (§9);
- `relationKind` is registry/config data, not a reason to change
  `ManagedPage`'s own schema for every new relationship type.

## 5. Page creation, membership and lifecycle

### 5.1 Creation

The default account has zero pages. A page appears only after explicit creation
or an explicit membership.

An eligible Creator with `page.create` may start page creation. The flow asks
for minimum identity and market-neutral metadata, creates a permanent client
ULID/UUID, establishes explicit ownership/membership and starts the applicable
review flow.

Self-service ownership policy:

- owned pages 1–3 may be created through self-service;
- invited/delegated non-owner memberships do not consume the quota;
- page 4+ is not created without approved additional quota;
- one idempotent pending `PageLimitIncreaseRequest` is offered;
- only trusted moderation may approve a higher effective quota.

The ADR 0017 local/mock behavior (`verificationStatus=pending`, local active
workspace) is a product-validation exception, not proof that a pending page may
be publicly published in production.

### 5.2 Verification and lifecycle are separate

```text
Page verification:
unverified → pending → verified
                     ↘ rejected
verified → revoked

Page lifecycle:
draft → pendingReview → active → archived
                    ↘ suspended
active → suspended → active | archived
```

Exact transition commands, appeal, re-review, expiry and public exposure rules
must be fixed before production implementation. A verification badge displays
only a safe projection; evidence and reviewer notes remain private.

### 5.3 Membership

Membership status and relationship do not themselves grant every action.
Authorization always requires explicit capability.

| Relationship | Product meaning | Prohibited inference |
|---|---|---|
| Owner | Canonical accountable owner; consumes ownership quota | Does not bypass verification, lifecycle or capability checks |
| Manager | Broad delegated management according to grants | Is not owner and cannot transfer ownership by name alone |
| Editor | Bounded content/operational access according to grants | Has no implicit team, audience or billing access |

Named presets such as Event Manager, Content Editor, Check-in Staff or Analyst
MAY be UX shortcuts, but persisted authority remains a versioned capability
set scoped to one page.

### 5.4 Personal identity versus a new Page

ADR 0015 §4 already establishes that a verified Creator publishes personally
by default and that a page is a distinct, explicitly created identity — not
every Creator needs one, and one Creator MAY manage several. This document
did not previously give onboarding guidance on *when* creating a page is the
right call versus continuing to publish under the personal `PublisherRef`.
The following is product guidance for the creation flow (§5.1), not a new
authorization rule: it never changes what `page.create`, capability
resolution or `PublisherRef` selection do, and it MUST NOT be read as
narrowing who is eligible to create a page under §5.1.

| Situation | Recommended default |
|---|---|
| An individual Creator publishes under their own name/verification | Personal `PublisherRef{type: user}` — no page needed |
| A performer/creator maintains a distinct public brand or stage identity kept separate from their personal profile | A page is appropriate |
| A club, studio, company, NGO, institution or municipality with a persistent public identity independent of any one person | A page is appropriate |
| A one-off activity with no lasting managed identity behind it | The owning Create aggregate (e.g. one Event), not a new page |
| A team/community project intended to outlive its founding member's involvement | A page is appropriate |

A profile category or profession by itself never forces page creation, and
the onboarding flow MUST NOT block a Creator merely because their situation
does not match a row above — this table informs the `Create a Page` entry
point's own copy/help text; it does not gate `page.create` (§7's module vs.
capability separation applies here too: guidance is not authorization).

### 5.5 Ownership transfer (`PP-D03`, Accepted)

```text
request
  -> current-owner confirmation
  -> new-owner acceptance
  -> step-up re-authentication (PP-D30)
  -> 48-hour cooling-off, cancellable by either party
  -> canBecomeManagedPageOwner(userId, pageId) re-evaluated fresh
  -> atomic completion
  -> audit
```

No co-ownership: the contract has one canonical `ownerUserId` (§4.1). The
current owner remains the owner of record — with full authority, including
cancelling the transfer — until completion; the prospective new owner has
no authority before that point.

`canBecomeManagedPageOwner(userId, pageId)` is the single named predicate
re-evaluated immediately before atomic completion, replacing an ad hoc
checklist scattered across documents:

1. an eligible `AccountStatus`;
2. applicable Creator/identity eligibility;
3. the prospective new owner has explicitly accepted the transfer;
4. no prohibiting page lifecycle state (§5.5's own transfer chain sits
   downstream of `PP-D32`'s matrix — e.g. `suspended`/`tombstoned` block
   transfer outright);
5. the ownership quota (§5.1's 3-page self-service limit) is satisfied, or
   an approved `PageLimitIncreaseRequest` exists — a transfer MUST NOT
   become a way to bypass the quota that direct creation already respects;
6. no new Booking/payment/legal obligation attached to the page since the
   request (§4.1's blocking rule, evaluated fresh, never a stale snapshot);
7. the step-up re-authentication is still within its freshness window, not
   reused from request time;
8. page `revision` is unchanged since the request;
9. neither party cancelled in the interim.

Any single failed condition aborts the transfer rather than completing it
partially.

## 6. Open classification without parallel taxonomy

`ManagedPage.kind` is a stable coarse structural kind from the accepted domain
contract. It is not the same thing as the page's public activity category and
MUST NOT select business logic.

For full release, the page SHOULD support:

- one primary service category reference;
- optional secondary service category references;
- moderated free-text `customActivityLabel`;
- activity tags;
- onboarding answers describing intended work.

Category System v1.4.3 is currently defined for navigation, filtering, Create
criteria and Smart Search; it does not currently define `ManagedPage` as a
`ContentType`. Therefore Professional Page may reuse stable category IDs only
through an explicit adapter/projection contract. Implementation MUST NOT
silently add `page` to `ContentType`, duplicate the 28/530 catalog or use page
categories to drive Create validation.

A page's category/label never gates what its own Create Hub content is
allowed to be about: a page labelled `Restaurant` MAY publish an Event
archetype unrelated to food service, and a page whose primary category
differs from a specific Event's theme is not rejected for that reason
alone — each Create type's own archetype/category/admission validation
(§9) is the only thing that decides, independent of the publishing page's
descriptor.

Custom labels:

- do not create a new system category automatically;
- do not block draft creation solely because a perfect category is absent;
- are moderated for impersonation, abuse and misleading claims;
- can later be mapped to a canonical category without changing page identity;
- never grant modules, capabilities, verification or Discover placement.

## 7. Product modules versus authorization capabilities

This separation is mandatory:

```text
module preference = what the page wants to show/use
capability = what the current member is authorized to do
feature flag/entitlement = what the environment/account may access
policy/readiness = whether the operation is currently safe and supported
```

An owner may configure module preferences, but cannot grant privileged
capabilities to itself by selecting an onboarding answer. Effective availability
is the intersection of implemented feature, environment flag, entitlement,
page policy, exact membership and exact capability.

Modules are UI/composition surfaces, not new aggregates:

| Module/surface | Delivery class | Boundary |
|---|---|---|
| Page identity and branding | Release foundation | Safe public projection of ManagedPage |
| Content | Release foundation | Projections of the ten accepted Create aggregates |
| Create | Release foundation | Shared config-driven Create Hub only |
| Team | Release foundation | ManagedPageMembership and exact-page grants |
| Notifications | Release foundation | Page-scoped operational events |
| Calendar | Mature extension | Read projection over dated content; no second content store |
| Invitations | Mature extension | Aggregate-specific invitations; no generic participant authority |
| Audience | Mature extension | Consent-aware projections, not a shadow CRM |
| Messages/announcements | Mature extension | Operational communication, rate-limited and consent-aware |
| Basic analytics | Mature extension | Aggregated privacy-safe measurements |
| Portfolio/media | Mature extension | Safe media projection; no duplicate content ownership |
| Page content templates | Mature extension | Manual save/list/reuse of any content item as a template, no AI or pattern-detection involved; v1 is Event-only, matching `CRT-TPL-01`'s current coverage; extending to the other nine Create types is Explicitly deferred, one type at a time, each requiring its own sensitive-data/migration review (`PP-D46`, Accepted core) |
| Content assist / template suggestions | Mature extension | v1 is deterministic, non-AI local matching (category + recurring weekday) layered on top of the manual template mechanism above, never a replacement for it; suggestion-only, shown inline in Create Hub, never authorizes or auto-creates (`PP-D45`, Accepted); semantic/AI-based matching is a separate v2+ extension gated on `AI-PLAT-LOCAL-01` and its own Approval, not part of v1 |
| Reviews and ratings | Mature extension | Uses the canonical Review contract when approved |
| Bookable Sessions | Mature extension | Existing Create aggregate; availability remains provider-truthful |
| Internal Booking | Gated expansion | ADR 0019/ECL-03 authoritative backend only |
| Payments/tickets/payouts | Gated expansion | Separate legal, financial and backend decision |
| Contact import/high-volume CRM | Gated expansion | Consent, retention, abuse and operations review |

Core navigation cannot be disabled by module preferences. Disabling a module
must not delete its data or hide unresolved obligations such as active Booking,
appeals, moderation or retention duties.

## 8. Information architecture

### 8.1 Workspace navigation

The Professional Page workspace has exactly five top-level destinations:

```text
Page · Content · Create · Notifications · Account
```

| Destination | Responsibility |
|---|---|
| Page | Dashboard, attention items and entry points to Calendar, Audience, Messages, Analytics, Team, page editor and verification |
| Content | Draft/published/archive projections scoped to the exact active page |
| Create | Shared Create Hub with active page as default publisher for a new draft |
| Notifications | Operational notifications scoped to the active page, with explicit cross-account items where policy allows |
| Account | Personal account, Settings, workspace switcher and logout; never the public page profile |

Personal Viewer/Creator navigation remains:

```text
Home · Favorites · Smart Search · Notifications · Profile
```

### 8.2 Public page

The public projection SHOULD include, when present and policy-safe:

- display name, avatar/cover, description and safe verification badge;
- primary/secondary service categories and custom activity label;
- market/city/operating-area display without exposing private location;
- safe contacts (phone/email/website/messaging-handle) and external links,
  reveal gated on page verification with an anti-spam rate limit —
  per-market legal defaults for which contact types to expose are
  Explicitly deferred to Privacy/Legal (`PP-D05` Accepted core, §15.1);
- linked public Places by ID;
- upcoming/ongoing/past public content projections;
- optional gallery, follow/share and Review projection after their contracts
  are approved.

The public page MUST NOT expose membership lists, capabilities, identity
evidence, reviewer notes, private contacts, private content, audience segments,
Booking details or internal analytics.

CTA is derived from the target content contract and readiness, not from the
page category. For example, a Route may offer Save/Open, an Event may offer an
honest external registration handoff, and unavailable/unknown capacity must not
be presented as bookable.

## 9. Create Hub and content ownership

Professional Page uses the same config-driven Create Hub as Personal Creator.
The target ten Create types are:

1. Event.
2. Recharge Activity.
3. Route.
4. Place / Business.
5. Bookable Session.
6. Scenario.
7. Find People.
8. Class / Workshop / Experience.
9. Rental / Equipment.
10. Collection / Guide.

The legacy `quickPlan` taxonomy value is read compatibility only. Quick Plan is
a separate personal/invited utility, has no publisher and is never created or
published by a Professional Page. Explicit `Expand to Scenario` creates a new
independent Scenario.

Route, Scenario and Quick Plan remain separate aggregates. A Scenario may
reference a published Route as one item by ID, but does not copy or edit Route
geometry.

Every Create type keeps its own validation, visibility, lifecycle, moderation,
admission and readiness contract. Professional Page MUST NOT introduce one
universal content lifecycle or one universal visibility enum across all ten
types.

### 9.1 Draft and publisher rules

1. Resolve authenticated actor and current access snapshot.
2. Validate active workspace without treating it as authority.
3. Resolve eligible personal/page publishers.
4. Default only a new draft from active workspace.
5. Persist `PublisherRef` and acting user ID.
6. Require `Publish as` when the choice is ambiguous.
7. Revalidate exact-page capability on save/submit/publish, plus Creator
   verification exactly where §3.5's rule requires it (submit/publish/
   republish/scheduled publish taking effect) — never for drafting alone.
8. Preserve existing draft publisher after workspace changes.
9. If page access is revoked, keep the draft readable where policy allows but
   block page submit/publish and require an explicit eligible publisher choice.

## 10. Visibility, admission and participation

Page exposure, content visibility, admission policy, invitations and Booking
are independent axes.

- Page exposure decides whether the page projection is discoverable.
- Content visibility is defined by the specific aggregate contract.
- Admission decides who may request/join and whether approval is required.
- Invitation grants only the explicitly defined access/participation intent.
- Booking is an authoritative operational aggregate when internal Booking is
  enabled.

`Approval required` is not a visibility level. `Opened` is analytics, not a
durable participant state. Followers are not members, and possession of an
unlisted link is not page membership. Registering, attending or being
recorded as a participant on one of the page's Event/Booking aggregates does
not, by itself, create a follower relation or a `ManagedPageMembership` —
each of the four (follower, page team member, Event/Booking participant, and
any future cross-event audience projection) is a separate concept with its
own contract and MUST NOT be inferred from another.

Sensitive eligibility such as age, geography, group composition, questionnaire
or consent requires a type-specific lawful policy and safe data contract. No
generic Professional Page setting may silently impose it on all content.

### 10.1 Separate state families

The product MUST NOT merge these into one linear status chain:

| State family | Examples | Source of truth |
|---|---|---|
| Invitation delivery | pending, delivered, opened, revoked, expired | Invitation contract |
| Application/registration | requested, approved, rejected, withdrawn | Aggregate admission contract |
| Booking | pending, confirmed, waitlisted, cancelled, expired | Authoritative Booking aggregate |
| Hold | active, accepted, declined, expired, released | Authoritative BookingHold |
| Attendance | notCheckedIn, checkedIn, attended/noShow where approved | Attendance/check-in contract |
| Analytics | viewed, clicked, shared | Analytics event stream, never authority |

Visit History remains an explicit self-reported Place action; Booking, page
view, Favorite, GPS or check-in must not silently create a personal visit.

## 11. Team, audit and page isolation

Team management is a release foundation because Professional Page may outlive
one employee. It remains bounded by exact-page capabilities.

Target operations include:

- invite/revoke a member through an audited command;
- assign a relationship and bounded capability preset;
- inspect effective access without exposing private verification evidence;
- scope staff to content/operations where supported;
- revoke future mutations immediately while preserving required audit/history;
- prevent the last accountable owner from being removed without an approved
  transfer/archive flow.

Critical actions record opaque actor ID, page ID, action code, target ID,
revision, backend time and reason code where applicable. Audit data is not an
activity feed and is not public.

A departing contributor's already-published media stays visible under
whatever license/right-of-use grant it was contributed with — offboarding a
member never transfers copyright to the page (`PP-D24`, Accepted core;
licensing-capture mechanics Explicitly deferred to Legal).

Ownership transfer follows §5.5's accepted flow (`PP-D03`). Co-ownership is
rejected outright, not deferred — the contract has one canonical
`ownerUserId` (§4.1). Legal representative disputes and page claim flows
remain Explicitly deferred (`PP-D10`, `PP-D29`) and must fail closed until
their own acceptable-evidence checklists exist.

## 12. Mature full-release extensions

### 12.1 Calendar

Calendar is a read/action projection over dated page content, not a new source
of truth. It may show Events, recurring Activities, Sessions and dated drafts
for which the member has access. Reschedule delegates to the owning aggregate
and re-runs its validation. External calendar sync is gated separately.

### 12.2 Invitations and audience

Invitations may target explicit Recharge users, lawful page followers/members
or prior participants when consent and the aggregate policy permit it. Share
links/QR use revocable, scoped, expiring tokens where private access is
involved.

Audience is a privacy-safe projection, not a transferable contact database.
Segments are derived from explicit relationships and consented activity.
Personal data is minimized; audience export and contact import remain gated.
Whether following this page shares its relationship/consent model with
following a person is not decided here — see `PP-D44` (§20) and §1.1.

### 12.3 Messages and announcements

Full release should support operational questions, event announcements,
approval/booking updates, reminders and post-event follow-up without building
a general social messenger.

Requirements include sender capability, exact recipient basis, unsubscribe
where applicable, frequency/rate limits, abuse reporting, localization,
idempotent delivery, delivery status and retention. Promotional communication
must be distinct from operational communication.

### 12.4 Analytics

Basic analytics may include safe aggregates for page/content views, saves,
shares, follows, registrations, confirmed Booking and check-in only when each
source contract exists.

Analytics MUST distinguish impressions, user actions and authoritative
operational facts. Unknown attribution is explicit. Small cohorts require
suppression/aggregation. Identity evidence, private messages and raw access
tokens are prohibited.

Advanced funnels, comparison, export and attribution are a future product
entitlement, not a `Pro` role.

Event naming and lifecycle reuse `docs/analytics/ANALYTICS_TAXONOMY.md`
(`PP-D08` Accepted core); that taxonomy does not itself define a page-metric
set, attribution windows or retention — those remain Explicitly deferred to
Analytics/Privacy pending a page-metrics spec. The same owner and gate cover
`PP-D41`'s remaining data-quality questions (bot/fraud filtering, backfill,
small-cohort suppression threshold); unique-user is the canonical count,
total-action a secondary metric (`PP-D41` Accepted core).

### 12.5 Reviews and ratings

Reviews remain in full-release scope, but Professional Page consumes the
canonical Review contract rather than inventing page-local rating semantics.
Eligibility, moderation, appeals, aggregation, deletion and anti-abuse rules
must be approved before the module is enabled.

## 13. Booking, tickets and payments

### 13.1 Honest current/fallback behavior

Until internal Booking is activated, a registration/booking CTA may redirect
to a validated `externalBookingUrl` where the owning aggregate allows it. The
UI must label this as an external handoff and must not claim Recharge-confirmed
availability, reservation or payment.

Cached or provider data never confirms a booking. Unknown availability fails
closed or uses an honest `Check with provider` state.

### 13.2 Internal Booking

ADR 0019 defines separate `Booking`, `BookingHold`, inventory ledger, audit and
outbox records. They are not embedded in `ManagedPage`, Event or Session.

```text
confirmedUnits + activeHoldUnits <= capacity
```

Waitlisted entries without a hold and pending applications consume no capacity.
A `BookingHold` is a short-lived free inventory allocation used for waitlist
promotion/race-safe confirmation; it is not a payment hold or deposit.

Creator management requires publisher ownership or an exact-page
booking-management capability. `IDENTITY_PUBLISHER_SLICE_SPEC.md` currently
names that semantic capability `manage_bookings`; the implementation slice
versions the exact wire code, so this document must not be used as a hardcoded
capability registry. All capacity mutations require trusted idempotent backend
commands. Professional Page provides scoped management projections only.

### 13.3 Money movement

Tickets, checkout, deposits, refunds, payouts, tax/KYC and financial reporting
remain visible in the target architecture but require separate business,
legal, security and operational approval. No payments state may be simulated by
a page module preference.

## 14. Notifications and settings

Notification categories:

| Category | Examples |
|---|---|
| Operational | page review, registration/Booking change, cancellation |
| Team | invite, role/capability change, revocation |
| Audience | follow or Review events where those modules are enabled |
| Performance | privacy-safe periodic summary |
| System | verification, moderation, security or billing obligation |

`PP-D45`'s v1 template-reuse/content-similarity suggestion (Accepted) is
delivered inline in Create Hub, not through a Notification category — no
`Assist` category exists in v1. A dedicated notification category is a
question for a future semantic/AI-based v2+ extension, not this document's
resolved v1 scope.

Each event has a stable ID, exact recipient scope, page ID where applicable and
no identity evidence. User and moderator events are different projections.

Settings are grouped by responsibility:

- page identity and branding;
- categories/custom activity label;
- module preferences and feature availability explanation;
- content defaults, without overriding aggregate rules;
- team and permissions;
- communication preferences;
- integrations;
- privacy and data rights;
- verification and moderation status;
- archive/transfer/delete requests;
- payments/billing only when an approved module exists.

Privileged capabilities are not arbitrary user-editable switches. Settings may
request or delegate allowed grants through audited policy, never write trusted
authority directly from the client.

## 15. Security, privacy, offline and operations

### 15.1 Security and privacy

- Clients cannot write roles, verification decisions, membership grants,
  privileged capabilities or audit decisions.
- Exact page ID and current membership revision are checked on every privileged
  command.
- Public projections exclude identity evidence, private contacts, team grants,
  private audience/Booking data and moderation notes.
- Deep links revalidate authentication and exact resource access.
- Logs/analytics use opaque IDs and stable reason codes.
- Retention, deletion, appeal and legal review are mandatory before production
  identity evidence, contact import, audience export or financial data.
- Age-sensitive content and minors require separate fail-closed policy.
- Public contact reveal is gated on page verification (§8.2); which contact
  types are safe or required per market is Explicitly deferred to
  Privacy/Legal, per target launch market (`PP-D05` Accepted core).

### 15.2 Offline behavior

- Public and authorized read projections may be cached with freshness labels.
- Active workspace preference and eligible local drafts may work offline.
- Offline state never grants membership/capability or confirms Booking.
- Privileged writes queue only when the owning slice defines conflict,
  idempotency and revocation behavior; otherwise they remain unavailable.
- Stale or unknown authority fails closed with retry/recheck guidance.

### 15.3 Operational readiness

Each production module requires observability, bounded event taxonomy, feature
flag/kill switch, rate/quota policy, migration, rollback and runbook. Disabling
new work must preserve existing obligations and readable audit/history.

Reaching an operational quota never loses data or drops an existing
obligation (`PP-AC-79`); the actual numeric limits — team size, storage,
messages, export frequency, API/provider usage — are Explicitly deferred to
Infra/Operations pending real capacity planning (`PP-D38` Accepted core).

## 16. Required UX states

The experience must explicitly cover:

- authentication/session restoring;
- Creator verification not started, pending, rejected, expired or revoked;
- zero pages and `Create Professional Page` onboarding;
- page creation pending review;
- one, three and larger authorized page lists;
- ownership quota reached and one pending limit request;
- workspace restoring/selection rejected;
- active personal/page workspace;
- page suspended, archived or membership revoked;
- module unavailable, disabled, gated or unsupported in market;
- publisher selection required;
- stale draft access/publisher;
- empty Page/Content/Notifications states;
- partial offline/stale projection;
- submit/publish denied with safe next action;
- Admin presentation preview with no authority.

All critical flows must support en/ru/lv-ready strings, 360 dp width, 150% text
scale, keyboard/screen-reader semantics and no color-only status meaning.

## 17. Delivery roadmap

The target product is broad, but delivery remains independently reviewable.

| Slice family | Scope | Class | Key dependency |
|---|---|---|---|
| IDP-03/04/05 completion | Production authority, workspace, all-ten PublisherRef, guards | Release foundation | Stabilization exit, Auth/Platform |
| PP-01 Page profile | Versioned profile extension, editor, safe public projection, `PP-D47` structural relations (`ManagedPageRelation`, Accepted) | Release foundation | Approved category/profile decisions |
| PP-02 Page content | Exact-page Content lists and aggregate handoff | Release foundation | All-ten PublisherRef migration |
| PP-03 Team | Invitations, presets, revocation, audit | Release foundation | Backend authority and negative tests |
| PP-04 Calendar | Read projection and aggregate-owned actions | Mature extension | Dated content contracts |
| PP-05 Audience/follow | Consent-aware relations and segmentation | Mature extension | Privacy/retention approval |
| PP-06 Communications | Questions, announcements, reminders | Mature extension | Notification delivery, abuse/rate limits |
| PP-07 Analytics | Basic page/content/operational aggregates | Mature extension | Analytics taxonomy/privacy thresholds |
| PP-08 Reviews | Canonical Review projection | Mature extension | Approved Review slice |
| PP-09 Booking console | Exact-page internal Booking management | Gated expansion | ECL-03 runtime and operations |
| PP-10 Payments | Checkout/refund/payout surfaces | Gated expansion | Separate ADR/business/legal gates |
| PP-11 Integrations | Calendar/contact/CRM/provider integrations | Gated expansion | Provider, consent and operational gates |
| PP-12 Page governance & lifecycle | Ownership transfer, claim/merge, page lifecycle cascade signaling, slug/rename | Release foundation | PP-D03, PP-D10, PP-D15, PP-D17 accepted |
| PP-13 Media safety & rights | Authorship/license, contributor-offboarding edit rights, orphan cleanup, moderation, EXIF/location stripping | Mature extension | PP-D24 accepted |
| PP-14 Public support & moderation | Report/block, impersonation appeal, audited support access without Admin-as-publisher | Mature extension | PP-D25 accepted |
| PP-15 Security & access governance | Step-up re-authentication for critical operations, delegability matrix | Release foundation | PP-D30, PP-D31 accepted |
| PP-16 Operational limits | Team/media/message/export/API quotas with a no-data-loss, no-obligation-interruption guarantee | Release foundation | `PP-D38` core accepted; actual numeric limits await Infra/Operations capacity planning |
| `FOL-01` Follow relationship foundation *(neutral, not PP-owned)* | Reconciling this document's discriminated-target `FollowRelation` with `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s person-only `FollowRef` into one shape usable by both a page-follow and a person-follow policy (§20, `PP-D44`) | Mature extension | `PP-D44` **and** `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s `VP-D12` **and** `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `PCP-D02` jointly accepted — this document cannot accept it alone |
| PP-18 Page content templates *(no AI dependency)* | Manual save/list/reuse of a page content item as a template; v1 scope is Event only | Mature extension | `PP-D46` Accepted core; per-type extension beyond Event is Explicitly deferred (Owner: Product, staged one type at a time) — ships independently of `PP-17`/AI |
| PP-17 Content assist & templates | v1: deterministic, non-AI similarity detection (category + recurring weekday) over the page's own content history, inline Create Hub prompt to use a `PP-18` template; Event-only, matching `CRT-TPL-01`'s current coverage | Mature extension | `PP-D45` (Accepted) **and** `PP-D46`/`PP-18` (Accepted core) — v1 has no `AI-PLAT-LOCAL-01` dependency at all; semantic/AI-based matching is a separate v2+ extension requiring its own Approval and `AI-PLAT-LOCAL-01`'s quota/kill-switch gates |

Cheap extensions may ship with an earlier foundation slice when they remain
bounded, reuse the same contracts and do not weaken its acceptance criteria.
They must not be smuggled into a slice if they add a new authority source,
aggregate, sensitive dataset or production dependency.

## 18. Acceptance criteria

### Identity, workspace and publisher

- **PP-AC-01:** `Professional Page` maps only to `ManagedPage`; no fourth Pro role exists.
- **PP-AC-02:** Viewer and Creator share the personal workspace/navigation.
- **PP-AC-03:** Workspace switcher lists only Personal and exact authorized pages.
- **PP-AC-04:** Default account has zero pages.
- **PP-AC-05:** Owned page quota is three; delegated memberships do not consume it.
- **PP-AC-06:** Page 4+ is not created without approved quota; repeated request is idempotent.
- **PP-AC-07:** Page A grants never authorize Page B.
- **PP-AC-08:** Invalid/restored page access falls back safely to Personal.
- **PP-AC-09:** Active workspace defaults only a new draft publisher.
- **PP-AC-10:** Existing draft publisher is never silently rewritten.
- **PP-AC-11:** Ambiguous publisher candidates require `Publish as`.
- **PP-AC-12:** Admin preview changes presentation only.

### Page model and modules

- **PP-AC-13:** Page and Place remain different aggregates linked only by IDs.
- **PP-AC-14:** Creator verification, page verification and membership remain independent.
- **PP-AC-15:** Category/custom label/module preference grants no authority.
- **PP-AC-16:** Module enablement is separate from membership capabilities.
- **PP-AC-17:** Unknown/newer profile fields round-trip without downgrade.
- **PP-AC-18:** Disabling a module does not delete data or unresolved obligations.
- **PP-AC-19:** Public projection contains no private verification/team/audience/Booking data.
- **PP-AC-20:** Custom labels are moderated but do not block identity solely for taxonomy absence.

### Create and aggregate boundaries

- **PP-AC-21:** Page creation uses the shared config-driven Create Hub.
- **PP-AC-22:** All ten accepted Create types use canonical `PublisherRef`.
- **PP-AC-23:** Quick Plan has no page publisher and remains outside Create Hub/catalog.
- **PP-AC-24:** Route, Scenario and Quick Plan retain separate IDs, repositories and lifecycles.
- **PP-AC-25:** No universal page-defined content lifecycle overrides aggregate contracts.
- **PP-AC-26:** No universal visibility enum overrides aggregate-specific policy.
- **PP-AC-27:** Revoked page access blocks future submit/publish without changing draft ownership.
- **PP-AC-28:** Find People page publishing also validates its responsible-host contract.

### Team, communication and privacy

- **PP-AC-29:** Relationship names alone never authorize privileged actions.
- **PP-AC-30:** Team mutations are exact-page, audited and idempotent.
- **PP-AC-31:** Last-owner removal/transfer fails closed without an approved transition.
- **PP-AC-32:** Invitation, registration, Booking, hold, attendance and analytics states remain separate.
- **PP-AC-33:** Audience projections have a lawful relationship/consent basis and data minimization.
- **PP-AC-34:** Operational and promotional communication are distinguishable.
- **PP-AC-35:** Messaging has capability, recipient, unsubscribe, rate-limit and abuse controls.
- **PP-AC-36:** Small/private analytics cohorts are suppressed or aggregated.

### Booking and operations

- **PP-AC-37:** External booking handoff never claims Recharge-confirmed availability.
- **PP-AC-38:** Internal Booking/holds/ledger remain separate from ManagedPage/content.
- **PP-AC-39:** Waitlist without active hold and pending application consume no capacity.
- **PP-AC-40:** Payment/deposit/payout state is not simulated without its gated backend.
- **PP-AC-41:** Offline/cached state never grants authority or confirms Booking.
- **PP-AC-42:** Every production module has feature flag, observability and rollback.
- **PP-AC-43:** Revocation and module shutdown preserve mandatory history/obligations.
- **PP-AC-44:** `LAUNCH_STATUS.md` records exact implementation evidence and remaining gates.

### Quality

- **PP-AC-45:** en/ru/lv-ready labels, 360 dp and 150% text scale are covered.
- **PP-AC-46:** Unit, widget, integration, backend/emulator and negative security tests are proportional to each slice.
- **PP-AC-47:** `flutter analyze`, `flutter test`, boundary and diff checks pass for every implementation slice.
- **PP-AC-48:** Page market/country/locale/timezone/currency values use approved stable registries; default locale belongs to a normalized, deduplicated supported-locale set.
- **PP-AC-49:** Page metadata never grants authority, weakens server-owned policy or changes an existing `PublisherRef`.
- **PP-AC-50:** International metadata (§4.1 core `ManagedPage` fields) survives mapper round-trip, migration and unknown/newer-schema compatibility without silent defaulting or downgrade — the same principle as PP-AC-17, scoped to the core entity rather than the profile extension.
- **PP-AC-51:** An unknown or unsupported value fails closed only for the operation that depends on that specific field — `timezone` blocks scheduling, `defaultCurrency` blocks price/payment display, `countryCode`/`marketId` block legal/age/verification policy, locale values block localized publication/readiness — and never blocks an operation that does not depend on it.

### Page lifecycle as an organizational object

- **PP-AC-52:** Active membership — with an empty capability set, or held by a non-Creator — opens a restricted workspace shell whenever `ManagedPageMembership.revision` is current; Creator verification is never required merely to open the shell, only for specific actions that need it. It unlocks no destination or mutation, and no implicit default capability is granted to avoid an empty UI.
- **PP-AC-53:** Revoking a membership immediately increments that member's `ManagedPageMembership.revision`, the backend rejects any stale snapshot of it on the next privileged command, and a stale revision also fails `canOpenPageWorkspace` (§3.1) — not only mutations. It does not end the member's global authentication session. A pending invitation revoked before acceptance grants no access.
- **PP-AC-54:** Each state across the verification (§5.2), lifecycle (§4.1, §5.2) and deletion (§22.2/§22.6) axes has its own explicit publisher-validity and page-exposure policy per the §22.2 cascade; the page-level cascade never dictates a specific Create type's content outcome or Booking's own state — each aggregate's contract independently interprets the publisher-validity signal (§9, §13). No state silently reuses another axis's or another state's policy, and `verification revoked` is never treated as a `lifecycle` value.
- **PP-AC-55:** An explicit content-transfer or co-host action never changes `PublisherRef` outside the flow defined by PP-D16; the authoritative publisher remains exactly one `{type, id}`.
- **PP-AC-56:** A page's permanent ID and deep links remain stable across a slug rename; a retired slug redirects only when the resulting page is visible to the requester, and never reveals a suspended/private/deleted/moderation-blocked page's existence through a redirect that a genuinely nonexistent slug would not also produce.
- **PP-AC-57:** Concurrent edits are rejected or reconciled against `revision`, never silently overwritten; every accepted mutation records its actor.
- **PP-AC-58:** A page is never hard-deleted while active Booking, payment or legal obligations exist; restore remains possible within the retention window. Deactivating or deleting the owner's personal account access does not itself erase the minimally necessary pseudonymized legal/financial records an active obligation requires.
- **PP-AC-59:** After one terminal offboarding/security notice, a member whose membership is revoked receives no further operational or promotional page-scoped notification; legally required account-level messages are unaffected.
- **PP-AC-60:** No integration secret for Page A is usable for Page B, reachable from a public projection, or present in a client-held draft.
- **PP-AC-61:** Until PP-D22 is resolved, no implementation infers a brand/network relationship between pages from shared Place IDs, similar names or common ownership.
- **PP-AC-62:** An ownership transfer requires current-owner confirmation and new-owner acceptance as separate steps and is blocked while active Booking, payment or legal obligations exist on the page.
- **PP-AC-63:** A page merge migrates `PublisherRef`, content and audit history to the surviving page ID only through an approved, auditable plan. It does **not** carry over active memberships from the retired page at all — even relationship-only, zero-capability membership still satisfies `canOpenPageWorkspace` (§3.1) and would expose the surviving page's shell to an unvetted member. Each affected member instead receives a reconfirmation `TeamInvitation` (§22.1) to the surviving page and holds no membership there — not even zero-capability — until they accept it. A rejected or cancelled merge leaves both pages unchanged.
- **PP-AC-64:** A page with incomplete **secondary**-locale content MAY publish, but only with an explicit, viewer-visible partial-translation indicator for those locales. This never applies to a required `defaultLocale` field — that is governed by `PP-AC-77` instead, which blocks publication outright. An optional `defaultLocale` field being empty is neither blocked nor labeled as partial.
- **PP-AC-65:** A former contributor's ended membership removes their ability to edit or manage a media asset they contributed; it does not remove that asset's public availability where it remains referenced by published content under an existing license/authorship confirmation.
- **PP-AC-66:** Reporting or blocking a page never requires Admin to become that page's publisher, and every support action on page data is audited per §15.1. The act of reporting never changes page visibility or publication ability by itself, regardless of report count or pattern — a page stays visible and able to publish new content unless a moderator has first affirmatively confirmed the report and applied a separate, policy-driven interim restriction (`PP-AC-78`) with its own reason and duration. No volume or rate of unconfirmed reports substitutes for that moderator decision. A Viewer's block/mute is a personal, reversible relationship fact that does not change the page's state for any other Viewer.
- **PP-AC-67:** An entitlement downgrade never grants or removes a capability by itself (§4.3(4)); it moves the affected gated features to read-only or unavailable for *new* operations per §7's delivery class for that page, while obligation-continuity (§22.2's obligation-serving exception) keeps already-accepted Booking or legal obligations minimally serviced until completion or a safe handoff — never an abrupt cutoff. Existing data and integrations remain in a dormant, non-deleted state.

### Operational model of a real organization

- **PP-AC-68:** A non-Creator staff member opens the workspace and sees Page/Notifications sections their capabilities cover; they are blocked only from the specific actions §3.5's rule requires Creator verification for (submit/publish/republish/scheduled publish taking effect), never from the shell itself, and never from drafting, Booking/check-in or ordinary page/team management under their assigned capability.
- **PP-AC-69:** A `TeamInvitation` acceptance token is single-use; a second acceptance attempt after the first succeeds is rejected, and the flow does not reveal whether an email/phone target has a Recharge account.
- **PP-AC-70:** The sole owner of a page permanently losing account access does not leave the page unrecoverable; an emergency recovery path exists that requires evidence review before it is granted.
- **PP-AC-71:** Ownership transfer, page deletion, payout connection, audience export and integration credential rotation each require a fresh re-authentication within a bounded window, not merely an existing active session.
- **PP-AC-72:** Holding a capability does not by itself grant the right to delegate or revoke that capability for another member; `canDelegate`/`canRevoke` are evaluated independently per capability.
- **PP-AC-73:** A suspended, archived or tombstoned page still permits appeal, data export, Booking cancellation/refund, existing-Booking service and legal-hold-required actions; these are never blocked by the same rule that blocks ordinary new-content mutations (§22.2). Restore and ownership transfer are **not** uniform across the three states (`PP-D32`, Accepted): restore is self-service only from `archived`, appeal-outcome-only from `suspended`, and retention-window-bounded from `tombstoned`; ownership transfer is blocked outright during `suspended` (an active moderation action must be resolved by appeal first) and during `tombstoned` (the page must be explicitly restored first), with the sole exception of `PP-D29`'s separate emergency/legal recovery path, which is not an ordinary transfer.
- **PP-AC-74:** A co-host grant identifies the collaborator's `PublisherRef` (e.g. a second `ManagedPage`), not one fixed acting user — multiple members of that page may be authorized to represent it. Each individual command still resolves to exactly one `actingUserId`, whose membership and capability on the collaborating page are checked at command time. Suspending either page's authority does not silently transfer Booking or cancellation responsibility to the other.
- **PP-AC-75:** A bulk operation declares its commit mode — `atomic` (every object changes or none does) or `per-item` (each object's outcome is independent) — and behaves accordingly: a `per-item` operation leaves successfully processed objects in their new state with a per-object audit record and never reports partial success as full success; an `atomic` operation never leaves a mixed partial state at all.
- **PP-AC-76:** A privileged mutation submitted with a stale `revision` from an offline or multi-device draft is rejected with a reconcilable conflict, never silently overwriting a newer accepted change.
- **PP-AC-77:** A page with missing `defaultLocale` content for a required field is blocked from publishing; this is distinct from and never satisfied by the partial-translation label in PP-AC-64, which applies only to secondary locales.
- **PP-AC-78:** An interim restriction is entered only after a moderator's affirmative review of a report — never automatically by report count, rate or pattern alone. Once entered, it is time-bounded and distinct from a final decision; it does not itself constitute the final outcome or skip the appeal path.
- **PP-AC-79:** Reaching an operational quota (team size, storage, messages, etc.) blocks only the specific new action that would exceed it; it never deletes existing data or interrupts service to an existing obligation.
- **PP-AC-80:** An integration credential expiring or a provider going unavailable degrades to an honest stale/unavailable state rather than silently serving cached data as current.
- **PP-AC-81:** A notification that fails delivery is distinguishable from one that was never sent; delivery-failure state is never conflated with `read` or `acknowledged` (§22.7).
- **PP-AC-82:** Canonical product metrics exclude bot/fraud-filtered activity entirely — never merely flag it inline. A separate, privacy-safe excluded/filtered count MAY be shown alongside the canonical aggregate but never inside it. A correction or backfill recomputes the canonical aggregate rather than only appending to it, and small/private-cohort suppression (PP-AC-36) is re-applied after every recomputation.
- **PP-AC-83:** A billing failure or downgrade never revokes access to data required for an active legal or Booking obligation — the same obligation-continuity exception `PP-AC-67` and §22.2 define — even if the corresponding paid feature becomes unavailable for new operations.
- **PP-AC-84:** Until PP-D43 assigns each of PP-D27–PP-D42 to a roadmap slice, none of them may be marked `Approved` on the strength of this document alone.
- **PP-AC-85:** A `FollowRelation` for `{type: user, id}` never creates, removes or authorizes a relation for `{type: page, id}` for the same account pair, and vice versa; unfollow, block or deletion of one target never mutates the other.
- **PP-AC-86:** A template-reuse suggestion never creates, saves or publishes a draft by itself; a new draft exists only after a team member explicitly accepts the suggestion.
- **PP-AC-87:** A draft created by accepting a template suggestion has no live link to the source content it was suggested from; editing one never changes the other, mirroring the `Expand to Scenario` pattern (§9).
- **PP-AC-88:** Template-suggestion similarity detection reads only the active page's own content history; it never reads another page's, another publisher's, or any account-level personal data the page does not already own.
- **PP-AC-89:** `PP-D45` v1 uses deterministic local matching (category + recurring weekday) and MUST NOT invoke an AI provider or create AI cost — the feature is free by construction in v1, not merely free while local/mock. Semantic/AI-based matching requires a separately Approved extension and, once it exists, MUST respect `AI-PLAT-LOCAL-01`'s own session quota, privacy and kill-switch gates and `PP-D38`'s general operational-quota discipline — it MUST NOT bypass either by claiming a separate, unbudgeted cost model.
- **PP-AC-90:** Saving a content item as a template never publishes, deletes or modifies the source item; the template is a separate, independent record requiring no AI or pattern-detection component.
- **PP-AC-91:** A draft created from a manual template has no live link to that template or to any other draft made from it; editing one never affects another.
- **PP-AC-92:** A page's saved templates are visible and manageable only to members whose exact-page capability already covers that content type; no separate "template" bypass of ordinary capability gating exists.
- **PP-AC-93:** Any volume or rate of unconfirmed reports against a page, by itself, never restricts that page's ability to publish new content and never changes its visibility; only an affirmative moderator decision, recorded per §15.1's audit rule, does either.
- **PP-AC-94:** A `§4.4` `ManagedPageRelation`, however many exist, never grants `PublisherRef`, membership or any capability on the related page/Place; deleting or changing a relation never rewrites Event `PublisherRef` or Place geometry/address; an `unconfirmed` relation is never presented as equivalent to a `verified` one in the public projection.
- **PP-AC-95:** No implementation adds a generic `attributes`/`sectionData` map to `ManagedPage` or `ManagedPageProfileExtension` under any name — including the `§4.2` reserved `ManagedPagePublicAttribute`/`ManagedPagePublicSection` names — before a separately Approved profile-builder slice exists.
- **PP-AC-96:** Recording a user as an Event/Booking participant on a page's content never creates a `FollowRelation` or a `ManagedPageMembership` for that user, and vice versa — follower, page team member, Event/Booking participant and any future cross-event audience projection each resolve strictly from their own owning contract (§10.1).

## 19. Required test matrix

At minimum, implementation slices cover:

- zero/one/three/five+ page lists and quota request idempotency;
- malformed, stale, suspended, archived and revoked workspace restoration;
- page A/page B capability isolation and cache namespace isolation;
- role without capability, capability without membership and stale revision;
- personal/page publisher resolution across all ten Create types;
- existing-draft non-rewrite after workspace switch;
- Admin preview without authority;
- public projection privacy and verification evidence exclusion;
- custom label/category adapter unknown/deprecated cases;
- valid/invalid/unknown market, country, locale, IANA timezone and ISO currency
  combinations, including duplicate locales and missing default locale;
- an unknown/unsupported single field (e.g. currency) blocks only its
  dependent operation (payment display) and does not block unrelated
  operations (e.g. scheduling) on the same page;
- international metadata mapper round-trip, schema migration and confirmation
  that metadata changes do not alter authority or persisted publisher;
- module disabled with existing content/Booking obligations;
- team invite/revoke/idempotency and last-owner denial;
- aggregate-specific lifecycle/visibility preservation;
- invitation/registration/Booking/attendance state separation;
- external provider unavailable/stale/unknown states;
- internal Booking contention, ledger invariants and forged client writes when
  the gated backend is implemented;
- offline read, stale authority, retry and rollback;
- localization, accessibility, compact layout and deep links;
- page lifecycle cascade: each verification/lifecycle/deletion state from
  §22.2 against publisher validity for new submissions and page public
  exposure only — confirming the page-level rule never overrides an
  aggregate's own content/Booking outcome;
- explicit content transfer (Personal↔Page, Page A→Page B) and co-host grant
  never producing a second `PublisherRef` or a silent rewrite;
- slug collision, reservation and rename-redirect that does not bypass
  visibility/moderation of the underlying page;
- concurrent edits against a stale `revision`, including two team members
  editing the same object;
- page/account deletion attempted with active Booking or legal obligations
  (must fail closed), plus restore within the retention window;
- notification read-state isolation between members and full cutoff after
  offboarding (§22.1, §22.7);
- OAuth/webhook credential isolation between two pages and revocation
  immediately stopping background sync;
- no implicit brand/network relationship inferred from shared Place IDs or
  similar names (PP-AC-61);
- a `§4.4` `ManagedPageRelation` deleted or changed produces no rewrite of
  Event `PublisherRef` or Place geometry/address, and grants no capability
  on either related entity; an `unconfirmed` relation renders distinctly
  from a `verified` one (PP-AC-94);
- attempting to write a generic `attributes`/`sectionData` map to
  `ManagedPage`/`ManagedPageProfileExtension` under any name, including the
  reserved `§4.2` names, is rejected before a profile-builder slice is
  Approved (PP-AC-95);
- a user recorded as an Event/Booking participant on a page's content
  gaining no `FollowRelation` and no `ManagedPageMembership` from that fact
  alone, and the reverse (PP-AC-96);
- ownership transfer requiring both-party confirmation and blocked by active
  obligations; claim/merge rollback leaving both pages unchanged on
  rejection;
- a non-Creator staff member opening the workspace and being blocked only at
  the specific Creator-gated action, not at the shell — verified against
  every row of §3.5's operation table, including that draft creation and
  editing succeed and only submit/publish/republish/scheduled-publish are
  rejected;
- a page merge producing zero carried-over active memberships on the
  surviving page, only reconfirmation `TeamInvitation`s;
- a critical operation (transfer, deletion, payout connect, audience export,
  credential rotation) rejected without a fresh re-authentication even with
  a valid active session;
- a capability held without delegation rights failing to grant/revoke that
  capability for another member;
- an operational quota reached blocking only the new action, never deleting
  existing data or an in-progress obligation;
- `TeamInvitation` replay, enumeration resistance, and an `accept ↔
  revoke/expire` race resolving to exactly one outcome;
- legacy `membership.status=invited` rows migrating or aging out without
  producing a new invited-status write;
- emergency owner recovery, including a disputed-recovery case with two
  claimed representatives;
- a `PP-AC-73` exception operation still denied when the actor lacks the
  underlying capability, even though the lifecycle state itself would not
  block it; ownership transfer specifically rejected on a `suspended` page
  (even with a valid current owner and no other blocker) and on a
  `tombstoned` page that has not been restored, with the sole `PP-D29`
  emergency-recovery path exercised separately from ordinary transfer;
- co-host actor resolution per command, and one co-host page's suspension
  not silently transferring responsibility to the other;
- both `atomic` and `per-item` bulk failure modes, each verified against its
  own declared contract;
- an offline autosave draft rejected against a newer remote `revision`
  rather than silently overwriting it;
- a missing required `defaultLocale` field blocking publication, distinct
  from an incomplete secondary locale merely labeling it;
- a report leaving a page visible with no interim restriction applied, and
  a separate emergency interim restriction case with reason/duration/appeal
  fields populated;
- quota isolation between two pages sharing no state;
- integration backfill after downtime, webhook replay idempotency, and a
  reconciliation view surfacing a Recharge/provider conflict;
- a notification bounce/delivery-failure state distinguishable from `read`
  and `acknowledged`;
- an analytics correction recomputing the canonical aggregate rather than
  appending to it, with fraud-filtered activity excluded from the result;
- a downgrade continuing to serve an already-accepted obligation
  (obligation-continuity) while blocking new gated operations;
- one Viewer simultaneously following a Creator and their Page as two
  independent `FollowRelation` targets;
- unfollowing the Creator leaving the Page follow unchanged, and vice versa;
- blocking the Creator not silently hiding the Page unless a separate
  policy explicitly requires it;
- suspending or deleting one target leaving the other target's relation
  untouched;
- the same `id` value used for a `user` target and a `page` target in two
  separate `FollowRelation` rows never colliding or merging;
- a template suggestion is never auto-accepted; the resulting draft has no
  live link back to its source and edits to either never affect the other;
- similarity detection for a template suggestion never surfaces content
  from a different page or publisher;
- template-suggestion frequency respects the same rate-limit discipline as
  Messages (§12.3), and disabling the opt-in setting fully suppresses it;
- a v1 template suggestion never invokes an AI provider or records any AI
  cost, verified by confirming no call to `AI-PLAT-LOCAL-01` occurs for the
  deterministic category+weekday match; a future semantic/AI-based
  suggestion, once separately Approved, is rejected once that platform's
  session quota or kill switch triggers, never silently served outside that
  budget;
- saving an item as a manual template never mutates the source item, and a
  draft created from that template has no live link back to it;
- a member without the relevant capability cannot see or use another
  member's saved template for a content type they are not authorized to
  manage;
- the manual template mechanism (`PP-D46`) functions with `PP-D45`/
  `AI-PLAT-LOCAL-01` entirely disabled or absent;
- a simulated flood of unconfirmed reports against a page produces no
  publication or visibility change until a moderator affirmatively
  confirms one, and that confirmation — not the report volume — is what
  the audit trail records as the cause.

## 20. Decisions required before implementation

These are deliberately not hidden as settled facts.
[`PROFESSIONAL_PAGE_DECISION_PACKAGE.md`](./PROFESSIONAL_PAGE_DECISION_PACKAGE.md)
(same directory) proposes a recommended resolution for each one, in the
same spirit as `EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md` did for
ECL-03 — accepting a recommendation there is what actually moves a
decision below from listed to `Accepted` in §20.1; this document states the
problem, that one proposes the answer.

1. **PP-D01 — Page category adapter:** exact relation between
   `serviceCategoryIds` and Category System without adding a parallel taxonomy.
2. **PP-D02 — Public page exposure:** exact visibility/indexing lifecycle and
   whether unlisted page projections exist.
3. **PP-D03 — Ownership (Accepted):** §5.5 fixes the transfer flow (request,
   current-owner confirmation, new-owner acceptance, step-up
   re-authentication, 48-hour cancellable cooling-off, atomic completion,
   audit), the `canBecomeManagedPageOwner` predicate re-evaluated fresh
   immediately before completion, and that co-ownership is rejected
   outright — the contract keeps one canonical `ownerUserId` (§4.1).
4. **PP-D04 — Module configuration:** versioned module IDs, dependencies,
   disable behavior and entitlement boundary.
5. **PP-D05 — Public contacts (Accepted core; per-market legal defaults
   Explicitly deferred):** contact types are phone/email/website/messaging-
   handle, public reveal gated on page verification (§8.2), with an
   anti-spam rate limit. Which contact types are safe or required to expose
   per jurisdiction is deferred to Privacy/Legal, per target launch market
   (§15.1).
6. **PP-D06 — Audience/follow:** relationship model, consent, unfollow/block,
   retention and deletion for following this page. Whether this shares its
   model with personal Creator-follow is a separate, joint decision —
   `PP-D44`.
7. **PP-D07 — Communication:** sender identity, recipient basis, templates,
   rate limits, delivery providers and moderation.
8. **PP-D08 — Analytics (Accepted core; remainder Explicitly deferred):**
   `docs/analytics/ANALYTICS_TAXONOMY.md`'s event-naming and lifecycle
   conventions apply (§12.4) — but that taxonomy defines event names and
   required parameters only, not a page-metric set, attribution window or
   retention answer. Those stay open, owned by Analytics/Privacy, gated on
   a page-metrics spec (new, or an `ANALYTICS_TAXONOMY.md` extension) being
   written and approved.
9. **PP-D09 — Reviews:** eligibility, verified-experience policy, moderation
   and aggregation.
10. **PP-D10 — Page claim/merge (Accepted core; sufficient-evidence
    checklist Explicitly deferred to Trust & Safety/Legal):** duplicate
    detection and claim evidence beyond name similarity, dispute handling,
    and — when a merge is approved —
    the plan for migrating `PublisherRef`, content and audit history between
    the surviving and retired page IDs. No membership carries over
    automatically, not even relationship-only: affected members are
    reconfirmed via `TeamInvitation` on the surviving page (PP-AC-63), since
    even zero-capability membership opens the workspace shell. What counts as
    sufficient claim evidence remains open, but the following are already
    fixed as individually **insufficient** on their own, however many of them
    coincide: matching display name, matching address/service area, matching
    website/external-link text, an Event co-organizer/host/venue relation to
    the page, social-link similarity, and provider-imported association. Any
    combination of these MAY inform a review queue, but only an authoritative
    Identity claim workflow with audit — never fuzzy matching alone — may
    grant a claim. Plus rollback.
11. **PP-D11 — Commercial entitlements:** packaging and naming that do not
    recreate `Pro` as an authorization role.
12. **PP-D12 — Release composition:** which mature extensions join the first
    full-release candidate based on estimates and readiness evidence.
13. **PP-D13 — International metadata wire contract:** each international
    field resolves against a different, independent source of truth, and the
    implementation slice MUST NOT substitute an incompatible format for any
    one of them:
    - `marketId` — a versioned Recharge-owned market registry, not a public
      standard;
    - `countryCode` — ISO 3166-1 alpha-2;
    - `defaultCurrency` — ISO 4217;
    - `timezone` — an IANA TZDB identifier;
    - `defaultLocale`/`supportedLocales` — normalized BCP 47 language tags.

    What remains open is the exact wire field names, storage layout and
    `schemaVersion` numbering that carry these already-accepted semantic
    types into the production contract (§4.1); ownership sits with the same
    Approved implementation slice this document already defers to.
14. **PP-D14 — Team invitation and offboarding lifecycle:** §22.1 resolves
    the `TeamInvitation`/`ManagedPageMembership` relationship and revocation
    semantics. Still open: exact invitation expiry duration, resend cooldown,
    mid-membership relationship changes (e.g. Manager → Editor), and
    scoped/time-limited access (e.g. one Event or check-in only).
15. **PP-D15 — Page lifecycle cascade over content and exposure (Accepted
    core; remainder Explicitly deferred):** §22.2 resolves the state axes
    and the cascade matrix. Whether a suspended page's Booking pauses or
    continues is no longer an open question of this document's — `PP-AC-54`
    already fixes that page suspension by itself neither deletes nor
    cancels Booking/holds, and their actual disposition is Booking's own
    contract to decide (ADR 0019/ECL-03). Still open, owned jointly by Trust
    & Safety (appeal/re-review timing) and Legal/Privacy (retention window,
    same gate as `PP-D19`): the exact retention window per row and
    appeal/re-review timing.
16. **PP-D16 — Explicit content transfer and co-host model (Accepted):**
    §22.3 resolves that transfer is an explicit audited `PublisherRef`
    change, defaults to move-only, and treats copy as a separate,
    destination-initiated duplicate. Co-host remains a separate scoped
    grant; its exact capability registry belongs to the Approved `PP-02`
    implementation slice and does not reopen this accepted product model.
17. **PP-D17 — Slug, rename and deep links:** §22.4 resolves that `id` is the
    only authorization-relevant identifier and that deep links/redirects
    survive rename. Still open: uniqueness/reservation policy, forbidden-name
    list, rename frequency limits, and whether rename affects verification
    standing.
18. **PP-D18 — Concurrent editing and revisions:** §22.5 resolves
    `revision`-based rejection of stale mutations and mandatory actor
    attribution. Still open: section-level versus whole-object locking,
    diff/rollback UX, and the exact definition of a "significant edit" that
    re-triggers moderation.
19. **PP-D19 — Deletion, archive and retention (Accepted core; retention
    window Explicitly deferred to Legal/Privacy):** §22.6 resolves that
    deletion is soft/tombstoned, never hard while obligations exist, and
    that followers/team grants are frozen, not deleted, during the window.
    Still open: the retention-window length itself — 30 days is a starting
    placeholder, not a Legal/Privacy-approved figure, and page/team/audit
    retention is its own data class, independent of Booking's own retention
    table (ADR 0019/ECL-03) — one is not evidence for the other.
20. **PP-D20 — Notification recipients and read state:** §22.7 resolves
    capability-based routing, per-member read state and offboarding cutoff.
    Still open: escalation rules, quiet hours, and per-channel
    (push/email/in-app) preference.
21. **PP-D21 — Integration credentials and provider isolation (Accepted
    core; provider selection Explicitly deferred to Partnerships/Business):**
    §22.8 resolves page-scoped, backend-only secret custody and immediate
    revocation. Still open: which providers are supported first (blocking
    `PP-D39`'s own conflict-resolution policy until decided), OAuth consent
    scope granularity, and webhook signature verification specifics —
    owned jointly with Security.
22. **PP-D22 — Branch/brand hierarchy:** explicitly deferred. No parent/network
    relationship across pages sharing a brand or multiple Places exists in
    v1; `placeIds` alone does not model it, and none is inferred from shared
    Place IDs, similar names or common ownership (PP-AC-61) until a
    dedicated aggregate and its own ADR are approved.
23. **PP-D23 — Localized page content:** whether `displayName`, description,
    labels and contacts are single-value with locale fallback or fully
    per-locale, and translation ownership/workflow. Required-field
    completeness is per locale role, not one blanket rule: a required
    `defaultLocale` field missing blocks publication (`PP-AC-77`); a
    secondary locale incomplete is labeled, not blocked (`PP-AC-64`).
24. **PP-D24 — Media rights and lifecycle (Accepted core; remainder
    Explicitly deferred to Legal + Product):** a page-level shared media
    library; a departing contributor's already-published media stays
    visible only under whatever license/right-of-use grant it was
    originally contributed with — the page never automatically acquires
    copyright on membership end (§11), and use beyond that original
    grant's scope needs a fresh one; EXIF/location stripping mandatory by
    default. Still open, owned by Legal (licensing-capture mechanics at
    upload, handling of a later-revoked license) and Product (orphan-
    cleanup timing).
25. **PP-D25 — Public-page report, block and support flow:** report page,
    impersonation appeal, block/mute by a Viewer, and a support/dispute path
    that does not make Admin a publisher (§1) or bypass the audited-access
    rule in §15.1.
26. **PP-D26 — Entitlement downgrade (Accepted core; billing mechanics
    Explicitly deferred to Commercial/Billing):** downgrade never deletes
    data; lost-access features go read-only rather than disappearing,
    mirroring `PP-AC-67`'s obligation-continuity exception (§7). Still
    open: the exact feature-by-feature downgrade boundary and billing-owner
    mechanics — without an entitlement ever becoming a role or capability
    source (§4.3(4), `PP-D11`). Reopening gate: a Commercial/Billing spec
    exists and is approved, the same prerequisite `PP-D11`/`PP-D42` need.
27. **PP-D27 — Non-Creator staff scope (Accepted):** §3.5 fixes the general
    rule and the exact operation table — Creator verification gates only the
    act of content crossing the private-draft boundary (submit, publish,
    republish, scheduled publish taking effect); everything else, including
    drafting, editing, Booking/check-in and ordinary page/team management,
    does not require it. The migration plan for the current
    `canActivatePage()` guard, which requires it unconditionally, still
    needs an implementation slice, but the target rule itself is no longer
    open.
28. **PP-D28 — TeamInvitation security hardening:** permanent `id`,
    `revision`/`schemaVersion`, single-use acceptance token, atomicity of
    accept/revoke/expire, email/phone enumeration resistance, contact
    normalization/encryption/retention, verified-contact mismatch handling,
    replay protection, whether an inviter can delegate only capabilities they
    themselves hold, invitation rate limits, and migration of legacy
    `membership.status=invited` rows.
29. **PP-D29 — Emergency ownership recovery (Accepted core; evidence
    checklist Explicitly deferred to Trust & Safety/Legal):** interim
    custody is read-only/frozen until resolved; evidence review is required,
    never automatic (`PP-AC-70`). Scenarios covered: sole owner loses
    account access, owner death or departure, lost company email domain,
    legal representative change, owner deleting their account while Booking
    is active, and dispute between two claimed representatives. Still open:
    the acceptable-evidence checklist itself (e.g. death certificate, legal
    successor documentation) — the same shape as `PP-D10`'s gate.
30. **PP-D30 — Step-up authentication for critical operations:** which
    operations (ownership transfer, page deletion, payout account
    connection, audience export, granting `manage_team`-class capabilities,
    integration credential rotation) require recent re-authentication or MFA
    beyond an ordinary active session, plus device/session audit and whether
    any require two-person approval.
31. **PP-D31 — Delegability matrix:** whether holding a capability implies
    the right to grant (`canDelegate`) or revoke (`canRevoke`) it for
    another member, evaluated separately per capability — especially
    Booking, Team, Billing, integrations and data export.
32. **PP-D32 — Obligation-serving operations under a restricted lifecycle
    (Accepted):** appeal, data export, Booking cancellation/refund,
    existing-Booking service, support response and legal hold remain
    available uniformly on a suspended/archived/tombstoned page as a named
    exception class distinct from ordinary mutations (§22.2). Restore and
    ownership transfer are **not** uniform: restore is self-service only
    from `archived`, appeal-outcome-only from `suspended`, and retention-
    window-bounded from `tombstoned`; ownership transfer is blocked outright
    during `suspended` (resolve by appeal first) and `tombstoned` (restore
    first), with `PP-D29`'s emergency/legal recovery the sole exception —
    closing an evasion path where transfer could otherwise bypass moderation
    or undo a deletion.
33. **PP-D33 — Co-host execution model:** who accepts a co-host invitation,
    which `User` acts on behalf of the second page, whether that requires
    membership on both pages, participant/Booking visibility, who owns
    cancellation/refund responsibility, who can end the collaboration, the
    effect of one co-host's page being suspended, and Analytics/Review
    attribution between co-hosts.
34. **PP-D34 — Bulk and scheduled operations:** bulk archive/unpublish,
    bulk category/contact update, scheduled publish/unpublish, event/session
    recurrence, bulk cancellation, partial failure and retry, pre-apply
    preview, and per-object audit of a bulk action's effects.
35. **PP-D35 — Multi-device concurrency:** conflict between simultaneous
    mobile/web edits beyond the single-mutation `revision` check already in
    §22.5, autosave racing a remote edit, an offline draft surviving a
    revoke, cross-section merge, version recovery, and draft locking/presence
    indicators.
36. **PP-D36 — Locale-completeness enforcement:** `defaultLocale` content is
    required and MUST block publication if absent, distinct from the
    partial-translation label in PP-AC-64 (which applies to incomplete
    *secondary* locales, not a missing default). Also open: slug
    translation, the locale fallback chain, contact/CTA localization, who
    confirms a translation, and whether an edited translation re-triggers
    moderation.
37. **PP-D37 — Trust-and-safety and moderation model (Accepted core;
    remainder Explicitly deferred to Trust & Safety).** Fixed, following
    directly from discussion of this exact question: a report or complaint
    never restricts publication or visibility by itself, at any volume or
    rate — an interim restriction is entered only after a moderator has
    affirmatively reviewed and confirmed the report, never by an automated
    threshold acting alone (`PP-AC-66`, `PP-AC-78`). Content continues to be
    created and published normally while a report is pending that review; a
    verified Creator's page-scoped `PublisherRef` is not a reason to skip
    this — it changes nothing about whether restriction requires
    confirmation first, it only reflects that the account was already
    vetted before it could publish at all (§16).

    Still open: exact severity/reason codes and how they map to the
    restriction moderators may apply; how repeat or coordinated ("brigaded")
    reports are weighted without becoming a report-volume trigger in
    disguise; reporter protection; the appeal SLA a moderator's decision is
    held to; scope of a confirmed restriction (the specific reported item
    only, versus the page's new publications broadly, versus the page's
    existing visibility) as a function of severity; one Viewer's block of a
    page; and how that block affects Search, Recommendations, Messages and
    Notifications.
38. **PP-D38 — Operational quotas (Accepted core; numeric limits
    Explicitly deferred to Infra/Operations):** reaching a quota never
    loses data or drops an existing obligation (`PP-AC-79`). Still open:
    the actual numeric limits — team members, invitations, media/storage,
    drafts and published items, messages, analytics retention,
    integrations/webhooks, export frequency and API/provider usage — which
    need real infra capacity numbers, not an invented figure.
39. **PP-D39 — Integration source-of-truth and recovery:** authority on a
    Recharge/provider conflict, webhook replay and idempotency, backfill
    after downtime, partial sync, credential expiry, disconnect while
    Booking is active, a reconciliation UI, provider-side deletion/export,
    and integration transfer on ownership change.
40. **PP-D40 — Notification delivery states:** queued/sent/delivered/
    failed/bounced beyond `read`/`acknowledged` (§22.7), retry and
    dead-letter handling, device removal, email suppression lists, critical
    escalation, quiet-hours override, and a recipient losing the relevant
    capability between enqueue and delivery.
41. **PP-D41 — Analytics data quality (Accepted core; remainder Explicitly
    deferred to Analytics/Privacy, same gate as `PP-D08`):** unique-user is
    the canonical count, total-action a secondary metric.
    `ANALYTICS_TAXONOMY.md` does not define the remainder either. Still
    open: bot/fraud filtering, late-arriving events, correction/backfill,
    timezone-correct reporting, attribution changes, deletion requests
    reflected in aggregates, small-cohort suppression threshold, and
    reconciling discrepancies against Booking/provider reports.
42. **PP-D42 — Entitlement and billing completeness:** billing owner,
    trial, grace period, failed renewal, seat limits, invoices/tax,
    downgrade while obligations are active, re-activation, dormant
    integration cleanup after retention, and keeping entitlement, capability
    and verification as three separate facts (§4.3(4), PP-D26).
43. **PP-D43 — Rollout meta-decision for PP-D27–PP-D42:** sixteen
    operational areas (`PP-D27`–`PP-D42`) surfaced together as one
    operational-model gap, tracked in §20.1 against existing slices
    `PP-01`–`PP-15` — not only `PP-12`–`PP-14` — or a new slice where none
    fit (e.g. `PP-16`, PP-D38). This decision confirms or revises that
    assignment; none of the sixteen may be marked `Approved` on the strength
    of this document alone until it does.
44. **PP-D44 — Shared or separate Follow model:** whether following a
    Professional Page (§12.2, `PP-D06`) and following a verified Creator
    (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s `VP-D12`,
    `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `PCP-D02`) share one
    relationship/consent/retention contract or are deliberately separate
    models (§1.1). This is a trilateral decision —
    `PP-D44`/`VP-D12`/`PCP-D02` — cross-referenced by all three documents'
    own decision-tracking; this document previously described its proposal
    below as unreciprocated, which is corrected. It remains a proposed
    shared shape, not a unilateral adoption:

    ```text
    FollowRelation {
      id,
      followerUserId,
      target: { type: user | page, id },
      status,
      createdAtUtc,
      revision,
      schemaVersion
    }
    ```

    Even if the shape is shared, policy stays target-specific: following a
    person never implies following their page and vice versa; unfollow,
    block, delete and retention are isolated per exact target; visibility
    and consent rules for a `user` target and a `page` target may differ;
    and no audience data transfers between a person-follow and a page-follow
    relation.

    **Not yet resolved:** `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s own
    proposed `FollowRef{followerUserId, followedUserId, createdAtUtc}` has
    no `target` discrimination and cannot represent following a page at
    all — reconciling the two shapes is part of what this joint decision
    must settle, not only which party count or policy applies. This
    proposal has no roadmap slice of its own beyond the neutral placeholder
    `FOL-01` (§17).
45. **PP-D45 — Automatic template suggestion, page-authored content
    similarity (Accepted):** the page workspace detects that a new draft
    resembles content this same page previously published and proactively
    suggests reusing it as a starting point, on top of `PP-D46`'s manual
    template mechanism. v1 is final on every previously-open question:

    - similarity signal is **deterministic, non-AI local matching** —
      category + recurring day-of-week — chosen for the lowest false-
      positive risk; `AI-PLAT-LOCAL-01` is **not** invoked in v1 at all;
    - the suggestion is an **inline Create Hub prompt**, not a dedicated
      Notifications category — no `Assist` category exists (§14);
    - scope is **Event-only** for v1, matching `CRT-TPL-01`'s current
      coverage; extending to other Create types is a separate future
      decision, not part of accepting this one;
    - semantic/AI-based matching is explicitly **out of v1** — it requires
      a separately Approved extension and, once proposed, must clear
      `AI-PLAT-LOCAL-01`'s own quota, privacy and kill-switch gates plus
      `PP-D38`'s general operational-quota discipline; v1's cost is zero by
      construction, not merely zero while local/mock, because v1 makes no
      AI call to have a cost.

    The following boundaries, already established elsewhere in this
    document, continue to hold:
    - the suggestion never creates, drafts or publishes anything by
      itself — it only offers a shortcut a team member must explicitly
      accept, extending §4.3's "no silent authority" principle to
      suggestion features;
    - accepting a suggestion creates a new, independent draft with no live
      link back to the source content, mirroring `Expand to Scenario`
      (§9) — editing the new draft never edits the old one and vice versa;
    - similarity detection reads only this page's own content history —
      never another page's or another publisher's content, and never
      account-level personal data beyond what the page itself already owns;
    - the suggestion is opt-in per page and subject to the same
      frequency/rate-limit discipline already required of Messages (§12.3);
    - it is a `Mature extension` (§2), not a release-foundation
      requirement.
46. **PP-D46 — Manual page content templates, no AI dependency (Accepted
    core; per-type expansion Explicitly deferred):** a page team member can
    explicitly save any content item (draft or published) as a reusable
    template, browse the page's own saved templates, and create a new
    independent draft from a chosen one — extending the existing local/mock
    `CRT-TPL-01` mechanism to the page workspace. **v1 is Event-only**,
    matching `CRT-TPL-01`'s current coverage; templates are editable in
    place after creation; organization is a flat list (no folders/tags) for
    v1. This is a plain save/list/reuse mechanism requiring no pattern
    detection, machine learning or `AI-PLAT-LOCAL-01` connection at all.
    `PP-D45`'s automatic suggestion builds on top of this mechanism, not the
    reverse — the two are independently shippable.

    The following boundaries hold regardless:
    - saving an item as a template never publishes, deletes or modifies the
      source item — the template is a separate, independent record;
    - creating a new draft from a template produces an independent draft
      with no live link to the template or to any other draft made from
      it — editing one never affects another, the same rule `PP-AC-87`
      already states for the AI-suggested case;
    - template visibility and management follow the same exact-page
      capability gating as any other content (§3.4, §7) — no special
      bypass for templates;
    - it is a `Mature extension` (§2), not a release-foundation
      requirement, and does not require `PP-D45` or `AI-PLAT-LOCAL-01` to
      ship.

    **Explicitly deferred:** extending beyond Event to each of the other
    nine Create types is not a bulk default just because no AI dependency
    gates it — Route/Scenario carry GPS-track and geometry-reuse questions,
    Place carries adaptive-form/location-sensitivity questions, and Find
    People carries participant-safety-sensitive content a naive "save as
    template" could otherwise retain. Owner: Product, staged one Create
    type at a time. Reopening gate: each additional type's own sensitive-
    data/migration review is completed and approved. Target slice: PP-18.
    Also still open: template count limits (ties to `PP-D38`'s operational-
    quota scope, itself also a split disposition).
47. **PP-D47 — Structural page relations (Accepted):** `§4.4`'s
    `ManagedPageRelation` (operates-Place, branch/headquarters, partner,
    provider/brand association) is its own accepted record type, distinct
    from `placeIds` — `branchOf`/`partnerOf` are Page→Page and `providerOf`
    is Page→Provider, none of which `placeIds` (Page→Place-only) can
    represent; `placeIds` is unchanged for read-compatibility. The v1
    `relationKind` registry is exactly the four kinds listed. An
    `unconfirmed` relation displays with a neutral label, never hidden and
    never shown as equivalent to `verified` (§8.2). As before: a relation
    never grants management authority or `PublisherRef`, a page-to-Place
    relation never copies or overrides Place geometry, and an Event-owned
    relation to a page is never duplicated here as page authority.

### 20.1 Decision tracking

DoD requires each decision "accepted or explicitly deferred with owners and
gates" (§21) — that claim is only checkable if it is tracked, not just
listed. `Owner` below is intentionally `TBD` everywhere, including for the
one explicitly deferred decision: this document does not invent real
ownership assignment, but a deferred decision still needs an owner who
confirms and later re-opens the deferral, not `n/a`. `Status` distinguishes
a bare problem statement (`Open`) from a decision where §22 already proposes
a concrete mechanism and narrows what remains (`Proposed resolution / open
parameters`) — collapsing that distinction was itself a traceability defect.

| Decision | Status | Target slice (§17) | Owner | Gate |
|---|---|---|---|---|
| PP-D01 | **Accepted** (§6 adapter reuse) | PP-01 | TBD | — |
| PP-D02 | **Accepted** (public/indexed only once verified and `active`; no `unlisted` in v1) | PP-01 | TBD | — |
| PP-D03 | **Accepted** (§5.5 transfer flow and `canBecomeManagedPageOwner` predicate) | PP-12 | TBD | — |
| PP-D04 | **Accepted** (§7 module table is the v1 set) | PP-01 | TBD | — |
| PP-D05 | **Accepted core**; **Explicitly deferred**: per-market legal defaults | PP-01 | TBD (core); Privacy/Legal (remainder) | Privacy/Legal review completed for each target launch market |
| PP-D06 | Open | PP-05 | TBD | — |
| PP-D07 | Open | PP-06 | TBD | — |
| PP-D08 | **Accepted core** (naming reuse); **Explicitly deferred**: metric set/attribution/thresholds | PP-07 | TBD (core); Analytics/Privacy (remainder) | A page-metrics spec is written and approved |
| PP-D09 | **Explicitly deferred** — no canonical Review contract exists anywhere in the repository | PP-08 | Whoever ends up owning the Review contract | That Review contract's own acceptance |
| PP-D10 | **Accepted core** (insufficient-evidence list); **Explicitly deferred**: sufficient-evidence checklist | PP-12 | TBD (core); Trust & Safety/Legal (remainder) | T&S/Legal defines and approves the acceptable-evidence checklist |
| PP-D11 | Open | Not yet in roadmap | TBD | — |
| PP-D12 | Open | n/a (meta-decision) | TBD | — |
| PP-D13 | **Accepted** (§4.1 semantic types; wire naming is an implementation-slice detail) | PP-01 | TBD | — |
| PP-D14 | **Accepted** (§22.1 core; 7-day invite expiry, 24h resend cooldown) | PP-03 | TBD | — |
| PP-D15 | **Accepted core** (§22.2; Booking boundary per `PP-AC-54`); **Explicitly deferred**: retention window, appeal/re-review timing | PP-12 | TBD (core); Trust & Safety + Legal/Privacy (remainder) | Same gate as `PP-D19`, plus a T&S appeal/re-review SLA design |
| PP-D16 | **Accepted** (§22.3 core; move-only default, copy is a separate duplicate) | PP-02 | TBD | — |
| PP-D17 | **Accepted** (§22.4 core; global-unique slug, 1 rename/30 days, rename never resets verification) | PP-12 | TBD | — |
| PP-D18 | **Accepted** (§22.5 core; whole-object revision check in v1, no section locking) | PP-02 | TBD | — |
| PP-D19 | **Accepted core** (§22.6, soft/tombstoned deletion); **Explicitly deferred**: retention-window length | PP-12 | TBD (core); Legal/Privacy (remainder) | Legal/Privacy approves a retention period for this data class (page/team/audit — not Booking's) |
| PP-D20 | **Accepted** (§22.7 core; escalation/quiet-hours/per-channel prefs deferred as non-blocking) | PP-06 | TBD | — |
| PP-D21 | **Accepted core** (§22.8, custody/revocation); **Explicitly deferred**: provider selection, OAuth/webhook specifics | PP-11 | TBD (core); Partnerships/Business + Security (remainder) | A first integration partner is selected |
| PP-D22 | Explicitly deferred | None planned for v1 | TBD — architecture review (confirms deferral) | Requires a dedicated aggregate and its own ADR |
| PP-D23 | **Accepted** (fully per-locale storage model; translation workflow deferred as non-blocking) | PP-01 | TBD | — |
| PP-D24 | **Accepted core** (§11, license/right-of-use, EXIF stripping); **Explicitly deferred**: licensing-capture mechanics, orphan cleanup | PP-13 | TBD (core); Legal + Product (remainder) | A licensing-capture mechanism is designed |
| PP-D25 | **Accepted** (`PP-AC-66`; Report follows `PP-D37`'s moderator-confirmation gate, personal Block is immediate and Viewer-only) | PP-14 | TBD | — |
| PP-D26 | **Accepted core** (data-safety default, `PP-AC-67`); **Explicitly deferred**: billing-owner mechanics | PP-10/PP-11 | TBD (core); Commercial/Billing (remainder) | A Commercial/Billing spec exists and is approved (same prerequisite `PP-D11`/`PP-D42`) |
| PP-D27 | **Accepted** (§3.5) | PP-03 | TBD | `PP-D43` assigns the roadmap slice; content itself has no remaining gate |
| PP-D28 | **Accepted** (standard invitation-security checklist; inviter delegates only what they hold) | PP-03 | TBD | — |
| PP-D29 | **Accepted core** (`PP-AC-70`, read-only interim custody); **Explicitly deferred**: acceptable-evidence checklist | PP-12 | TBD (core); Trust & Safety/Legal (remainder) | Same gate shape as `PP-D10` |
| PP-D30 | **Accepted** (`PP-AC-71`'s list + `manage_team`-class capability grant) | PP-15 | TBD | MFA mechanism itself owned by `IDENTITY_PUBLISHER_SLICE_SPEC.md` |
| PP-D31 | **Accepted** (capability never implies `canDelegate`/`canRevoke`; least-privilege default) | PP-15 | TBD | — |
| PP-D32 | **Accepted** (`PP-AC-73`, §22.2) | PP-12 | TBD | `PP-D43` assigns the roadmap slice; content itself has no remaining gate |
| PP-D33 | **Accepted** (`PP-AC-74` per-command resolution; cancellation/refund stays with the originating page) | PP-02 | TBD | — |
| PP-D34 | **Accepted** (`PP-AC-75` atomic/per-item rule; scheduled publish is non-blocking Mature extension) | PP-02 | TBD | — |
| PP-D35 | **Accepted** (v1 scope = existing `revision` check only; no presence/merge UI) | PP-02 | TBD | — |
| PP-D36 | **Accepted** (core fixed via `PP-AC-77`/`64`; slug untranslated, `defaultLocale` is the fallback) | PP-01 | TBD | — |
| PP-D37 | **Accepted core** ("no restriction without moderator confirmation," `PP-AC-66`/`78`/`93`); **Explicitly deferred**: severity codes, repeat-report weighting, appeal SLA, restriction scope | PP-14 | TBD (core); Trust & Safety (remainder) | Trust & Safety operational design for the deferred items |
| PP-D38 | **Accepted core** (`PP-AC-79`, never-loses-data invariant); **Explicitly deferred**: numeric limits | PP-16 | TBD (core); Infra/Operations (remainder) | Real infra capacity planning produces approved numbers |
| PP-D39 | **Explicitly deferred** — cannot be written before `PP-D21`'s provider is selected | PP-11 | Whoever owns `PP-D21`'s partnership decision | A provider is selected |
| PP-D40 | **Accepted** (standard queued→sent→delivered\|failed→dead-letter pattern) | PP-06 | TBD | — |
| PP-D41 | **Accepted core** (unique-user canonical count); **Explicitly deferred**: suppression threshold, data-quality remainder | PP-07 | TBD (core); Analytics/Privacy (remainder) | Same gate as `PP-D08` |
| PP-D42 | Open | PP-10/PP-11 | TBD | — |
| PP-D43 | **Accepted** (§17's existing PP-01–PP-16 mapping promoted to the formal answer) | n/a (meta-decision) | TBD | — |
| PP-D44 | **Explicitly deferred** — trilateral (`PP-D44`/`VP-D12`/`PCP-D02`), cross-referenced by all three documents; `FollowRelation`/`FollowRef` shape mismatch unresolved | `FOL-01` | A party spanning all three sibling documents | Joint `FollowRelation`/`FollowRef` shape reconciliation with `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s `VP-D12` and `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `PCP-D02`; not resolvable by this document alone |
| PP-D45 | **Accepted** — deterministic non-AI v1 (category + recurring weekday), inline Create Hub prompt, Event-only | PP-17 | TBD | v1 has no `AI-PLAT-LOCAL-01` dependency; semantic/AI matching is a separate v2+ extension requiring its own Approval |
| PP-D46 | **Accepted core** (Event-only v1); **Explicitly deferred**: per-type expansion | PP-18 | TBD (core); Product, staged per type (remainder) | Each additional Create type's sensitive-data/migration review completed and approved |
| PP-D47 | **Accepted** — own record type (§4.4), v1 registry fixed, `unconfirmed` display rule fixed | PP-01/PP-12 | TBD | Depends on `PP-D10`'s claim/merge plan only where a relation's verification state must survive a merge |

## 21. Definition of Done

This document may become **Approved** only after PP-D01–D47 are either accepted
or explicitly deferred with owners and gates (tracked in §20.1).

Professional Page is production Done only when:

1. required Identity/Publisher production slices are Done;
2. all ten Create types enforce canonical publisher policy;
3. page/member/capability decisions are authoritative and fail closed;
4. the selected release modules meet their own acceptance criteria;
5. public/privacy/legal/security requirements are accepted;
6. migrations and rollback are proven;
7. analyzer, tests, boundary and diff gates are green;
8. `LAUNCH_STATUS.md` records the exact evidence;
9. no local/mock fixture or UI preview is represented as production authority.

## 22. Page lifecycle as an organizational object

Sections 1–21 define what exists inside an active page. This section
resolves the mechanism for what happens to a page and its team over time —
onboarding, ownership, renaming, concurrent work and offboarding — closing
PP-D14–PP-D21 as far as a specification can without business-specific
parameters (exact retention windows, cooldown durations and similar numbers
stay open and are called out per subsection).

### 22.1 Team invitation and offboarding (PP-D14)

`TeamInvitation` exists **independently** of `ManagedPageMembership` and is
the only record that exists before acceptance. It MUST support inviting a
target who is not yet a Recharge `User` — an existing `userId` is not a
precondition for sending an invitation:

```text
TeamInvitation {
  pageId,
  target: { userId } | { email } | { phone },
  proposedRelationship: manager | editor,
  proposedCapabilities,
  sentAtUtc, expiresAtUtc, resendCount,
  status: pending | accepted | declined | expired | revoked,
  invitedByUserId
}
```

- No `ManagedPageMembership` exists for the target until acceptance — the
  earlier "create an `invited`-status membership at send time" model does not
  work for an email/phone target with no `userId` yet, so it is dropped.
- Acceptance requires an authenticated `User` bound to the invitation's
  target — an existing `userId` match, or a newly authenticated account whose
  verified email/phone matches an email/phone target. Only then is a
  `ManagedPageMembership(status=active)` created; membership creation and
  invitation acceptance are the same event, not two.
- A cancelled, declined or expired `TeamInvitation` never produces a
  membership.
- Revoking access (an accepted membership or a pending invitation)
  immediately increments the affected member's `ManagedPageMembership.revision`
  (or, for a not-yet-accepted invitation, revokes the `TeamInvitation` record
  itself, which has none to increment); the authoritative backend rejects any
  stale access snapshot for that page on the next privileged command, and
  page-scoped local cache/credentials are cleared. It does **not** end the
  member's global authentication session — only account compromise or a
  separate security decision does that.
- After one terminal offboarding/security notice, a removed member receives
  no further operational or promotional page-scoped notification; legally
  required account-level messages are unaffected (§14).

Still open: exact invitation expiry duration, resend cooldown, mid-membership
relationship changes (Manager → Editor), and scoped/time-limited grants (e.g.
one Event or check-in only).

### 22.2 Page lifecycle cascade (PP-D15)

Verification (§5.2), lifecycle (§4.1, §5.2), deletion and public exposure
(§10) are independent axes and MUST NOT collapse into one status chain.

Per §9, this page-level matrix governs only what is genuinely page-scoped:
whether the page is a valid publisher for ordinary new mutations (new
submissions and edits), and the page's own public exposure — plus a named
exception class (obligation-serving and recovery/appeal/legal operations,
`PP-AC-73`) that ordinary blocking never reaches. It MUST NOT dictate the
fate of already published content, Booking state or any other
aggregate-owned outcome — each Create type (and Booking, per §13) keeps its
own contract and independently decides how to react to "publisher no longer
valid for new submissions." For example, an Event's own contract may keep
existing registrations honored while blocking new ones; that is the Event
contract's decision, not this page-level rule's.

| Trigger | Ordinary mutations (new submissions, edits) | Obligation-serving / recovery-appeal-legal ops* | Page public exposure |
|---|---|---|---|
| Verification rejected | Allowed | Allowed | Unaffected (badge only) |
| Verification revoked | Blocked | Allowed* | Hidden from Discovery |
| Lifecycle suspended | Blocked | Allowed* | Hidden from Discovery and search |
| Lifecycle archived | Blocked (read-only) | Allowed* | Out of active Discovery |
| Deletion/tombstone (PP-D19) | Blocked | Allowed* within retention window | None |

\* "Allowed" in this column means the lifecycle/verification state alone
does not block the operation — it is the named exception class from
`PP-AC-73` (appeal, data export, Booking cancellation/refund, existing-
Booking service, legal hold; plus restore and ownership transfer, each per
`PP-AC-73`'s own state-specific rule, not uniformly). `PP-AC-73` does not
itself grant the right to perform any of these: each such operation still
requires its own capability, policy and owning-aggregate support per §3.4,
exactly like any other mutation — it is only exempted from being denied by
lifecycle state as a blanket rule. Restore and ownership transfer are the
two operations in this class that are **not** uniformly "Allowed" across
all three restricted states (`PP-D32`, Accepted) — see `PP-AC-73` for the
exact per-state rule.

`deleted` is not an accepted `ManagedPage.lifecycle` value (§4.1); deletion
is modeled as a tombstone layered on `archived`, not a new enum value, unless
PP-D19 and a supporting ADR revision say otherwise.

Still open: exact retention window per row, appeal/re-review timing, and how
each individual Create type's own contract should respond to a publisher
becoming invalid (that response is each type's own decision, but the range
of acceptable responses is not yet cataloged).

### 22.3 Explicit content transfer and co-host (PP-D16)

`PublisherRef` remains exactly one `{type, id}` (§3.3, §4.3(2)); transfer and
collaboration are separate mechanisms:

- **Transfer** (Personal → Page, Page A → Page B, Page → Personal) changes
  `PublisherRef` only via an explicit, audited command — never a
  workspace-switch side effect (§3.3, §9.1); transferred published content
  re-enters applicable moderation and notifies existing participants of the
  publisher change.
- **Co-host/collaborator** access is a separate, scoped grant to another
  authorization-capable actor's `PublisherRef` — a second `ManagedPage` or a
  personal `User`/Creator — layered on top of the one authoritative
  `PublisherRef`. The grant is to the collaborator's `PublisherRef`, not to
  one fixed person: when the collaborator is a page, any of its members with
  the right capability may act on its behalf, and each command still
  resolves to exactly one `actingUserId` checked at that moment (§3.4). It
  never becomes a second entry in `PublisherRef` itself. A `Place` MUST NOT
  receive a co-host grant: it is a physical/reference aggregate, not an
  actor, and is represented only as a venue reference by ID (e.g. "held at
  this Place"), never as a party holding capabilities.

Accepted default: transfer is move-only. Copy is a separate,
destination-initiated duplicate command, never a transfer option. The exact
co-host capability registry belongs to the Approved `PP-02` implementation
slice and MUST remain page-scoped; specifying those wire-level capabilities
does not reopen `PP-D16`'s accepted product model.

### 22.4 Slug, rename and deep links (PP-D17)

- A page's permanent `id` is the only identifier used for authorization or
  content ownership; `slug` is a display convenience only — the same rule
  §4.1 already applies to a Place address/name applies to `slug`.
- A retired slug redirects to the current one only when the resulting page
  is otherwise visible to the requester under §10's exposure rules. A slug
  for a suspended, private, deleted or moderation-blocked page MUST NOT
  redirect in a way that reveals the page's existence or state — it returns
  the same safe not-found/gone response (404/410) an unrelated nonexistent
  slug would.
- A deep link resolved by `id` MUST NOT depend on the current slug at all,
  and is subject to the same exposure-safe not-found rule.

Still open: uniqueness/reservation policy, forbidden-name list, rename
frequency limits, and whether rename affects verification standing.

### 22.5 Concurrent editing (PP-D18)

- A mutation MUST include the `revision` it was based on; the backend
  rejects a stale `revision` rather than silently overwriting a newer one —
  this extends §3.4's fail-closed principle from authorization to editing.
- Every accepted mutation records its actor (§11).
- A significant edit to a publicly visible field MAY re-trigger the
  moderation/verification policy already required for initial publication
  (§5.2).

Still open: section-level versus whole-object locking, diff/rollback UX, and
the exact definition of a "significant edit."

### 22.6 Deletion, archive and retention (PP-D19)

- A page's own record and content are never hard-deleted while active
  Booking, payment or legal obligations exist (PP-AC-58).
- An owner MAY deactivate or delete their personal account access at any
  time; this ends their ability to act, but does not itself erase the
  minimally necessary pseudonymized legal/financial records an active
  obligation requires — those follow the same retention/legal-hold gate as
  identity evidence (§15.1), independent of the account's access state.
- Deletion is soft — a tombstone layered on `archived` (§22.2) — with a
  retention window during which restore remains possible.
- Data export and legal hold follow the same review gate already required
  for identity evidence and financial data (§15.1).

Still open: exact retention window length, and the disposition of
followers/team grants/content during that window.

### 22.7 Notification recipients and read state (PP-D20)

- A page-scoped operational notification routes to members whose current
  capability covers that event's subject (e.g. a Booking event routes to
  members with the booking-management capability, not to every member).
- `read` is a personal, per-member fact: a member can mark only their own
  notification read; no member can change another member's read state.
- `acknowledged`/`resolved` is a separate, team-operational fact recorded
  with actor and audit (§11) — e.g. one Manager resolving a shared
  operational item — and does not imply any other member has read or seen
  it. Read and acknowledged/resolved MUST NOT be represented as the same
  field.
- A removed member stops receiving page-scoped notifications per §22.1.

Still open: escalation rules, quiet hours, and per-channel
(push/email/in-app) preference.

### 22.8 Integration credentials and provider isolation (PP-D21)

- An integration secret is scoped to exactly one page and is never usable
  for another page — extending §4.3(2)'s "Page A capabilities never
  authorize Page B" to credentials.
- A secret never reaches a public projection (§8.2) or a client-held draft;
  only the trusted backend holds and uses it.
- Revoking an integration revokes its credential immediately and does not
  silently continue background sync.

This custody/revocation model is Accepted core (`PP-D21`). Explicitly
deferred, owned by Partnerships/Business (provider selection) and Security
(OAuth/webhook mechanics): which providers are supported first, OAuth
consent scope granularity, and webhook signature verification specifics.
Reopening gate: a first integration partner is selected.

## Appendix A. Illustrative full-release UI surface inventory

This appendix is **non-normative**. It helps product/design discussion by
showing what a person may see. It does not override sections 1–21, introduce a
module/aggregate/Create type or grant authority. Every block remains conditional
on the owning contract, policy, capability, lifecycle and Approved slice.

### A.1 Public page blocks

Subject to the safe-public-projection rules in §8.2:

- identity header: display name, avatar/cover and safe verification badge;
- short and full description;
- primary/secondary service categories, custom activity label and activity
  tags after PP-D01 is accepted;
- market/city/operating-area display without private location;
- safe contacts, website and external links after PP-D05 is accepted;
- Follow / Contact / Share only when the corresponding relation/policy is
  available;
- upcoming and ongoing public content whose aggregate is ready;
- linked public Places by ID;
- public past/archive content where the aggregate permits it;
- gallery/media;
- Review projection only after the canonical Review contract is approved.

### A.2 Illustrative CTA by content contract

These examples inherit the normative rules referenced in the final column;
they do not establish new requirements.

| Content contract | Illustrative primary action | Inherited boundary |
|---|---|---|
| Event, external handoff | `Register externally` | §13.1: label the external handoff and never claim Recharge confirmation |
| Event, internal Booking enabled | `Register` | §13.2: only when the authoritative Event ledger/readiness is live |
| Bookable Session | `Book externally` / `Check with provider` | Internal confirmation appears only after Session-specific availability/Booking authority exists |
| Route | `Open` / `Save` / `Start route` | Route readiness and navigation semantics remain Route-owned |
| Public Scenario template | `Open` / `Save a copy` | Personal `Start scenario` is available only on a dated/revalidated personal copy |
| Rental / Equipment | `Check availability` / `Open provider` | `Reserve` requires a separate approved Rental inventory/reservation contract; Event Booking is insufficient |
| Collection / Guide | `Open` / `Save` | Read projection; no admission or Booking state |
| Page with no eligible content | `Follow` / `Contact` / `Share`, when enabled | Do not show a disabled booking CTA as a substitute; fall back to safe page information |

### A.3 Workspace destinations

| Destination | Illustrative content |
|---|---|
| Page | Attention items, upcoming activity, safe quick metrics and entry points to Calendar, Audience, Messages, Analytics, Team, editor and verification |
| Content | Exact-page draft/published/archived projections across supported Create types |
| Create | Shared Create Hub with the active page as the default publisher for a new draft and explicit `Publish as` when required |
| Notifications | Exact-page operational notifications plus clearly separated personal/system items where policy permits |
| Account | Personal account, Settings, workspace switcher and logout |

### A.4 Required state coverage for design slices

A complete visual design derived from this inventory includes the applicable
§16 states, not only the happy path. At minimum: empty/loading/error, pending
verification, unavailable module, stale/offline projection, revoked access,
publisher ambiguity, compact layout and accessibility text scale.


## Appendix B. Non-negotiable exclusions (index)

This appendix is a **non-normative reader index**. Every row restates a rule
that is already normatively established at the cited section — nothing here
is a new requirement, and this list must not drift from those sections. It
exists because these are architectural prohibitions, not "not yet
implemented" gaps, and a single consolidated list is easier to check against
than twenty scattered clauses.

| Professional Page MUST NOT | Established at |
|---|---|
| Be a global `Pro` role | §1, §3.1 |
| Replace the personal profile | §1 |
| Be the Admin workspace, or make Admin a publisher | §1, §3.3 |
| Be a physical `Place` | §1, §4.1 |
| Publish Quick Plan | §9 |
| Create an eleventh Create type via a module toggle | §4.3(5), §7 |
| Grant a capability from category, custom label or module preference | §4.3(4), §6, §7 |
| Treat active workspace as authorization evidence | §3.2, §4.3(3) |
| Let Page A capabilities authorize Page B | §4.3(2) |
| Silently rewrite an existing draft's publisher | §3.3, §9.1 |
| Assign a publisher by company/Place display name | §4.1 |
| Auto-confirm a Booking from cached/provider data | §13.1 |
| Mutate Booking/capacity directly from a Flutter/Firestore client | §13.2, §15.1 |
| Count a waitlist entry without an active hold as consumed capacity | §13.2 |
| Treat Booking, Favorite, page view or GPS as a personal Visit History entry | §10.1 |
| Expose verification evidence, team grants, private audience or Booking data publicly | §8.2, §15.1 |
| Merge invitation, registration, Booking, hold, attendance and analytics into one state chain | §10.1 |
| Turn a Scenario into a Route or copy Route geometry into a Scenario | §9 |
| Promise payment/refund/payout outside a separate authoritative contour | §13.3 |
| Let a page relation grant management authority, or copy/override Place geometry | §4.4 |
| Add a generic `attributes`/`sectionData` map to the page profile under any name, including the reserved `§4.2` names, without a separately Approved slice | §4.2 |

## Appendix C. Illustrative boundary examples

This appendix is **non-normative**. It exists only to make §1's boundary and
§4.4's relation model concrete for reviewers and implementers; every row is a
worked application of rules already stated normatively elsewhere, never a
new one.

| Situation | Canonical model |
|---|---|
| A youth organization or NGO with its own ongoing public identity | Page |
| A one-off public festival that organization runs | Event, `PublisherRef = {type: page, id: <the page>}` |
| The same organization's invite-only internal team meeting | Event with a private/invite admission policy (§10) — not a new Page type |
| A restaurant's public brand | Page |
| The restaurant's physical branch | Place, linked from the page via `placeIds`/`§4.4` — not a second Page |
| A one-time wine-tasting evening the restaurant hosts | Event, published by that page |
| A sports club with several branches | One Page plus multiple `§4.4` `operatesPlace` relations — not one Page per branch, unless a branch genuinely has its own separate managed public identity |
| A tennis court | Place/resource; Bookable Session where availability applies — never a Page |
| A tennis tournament | Event |
| An independent DJ with a public stage brand kept separate from their personal profile | Page is appropriate (§5.4) |
| The same DJ performing as a credited act at someone else's event | An Event relation (performer/credit) — grants no `PublisherRef` and no page authority (§4.4) |
| A municipality | Page |
| A city festival the municipality runs | Event, `PublisherRef = {type: page, id: <municipality page>}` |
| A brand-new organization type Recharge has no dedicated label for | Same `ManagedPage` aggregate, `customActivityLabel` (§6) — never a schema fork |

## Revision History

Full detail for every version is in
[`PROFESSIONAL_PAGE_SPEC_CHANGELOG.md`](./PROFESSIONAL_PAGE_SPEC_CHANGELOG.md)
(same directory). This table is a short pointer, not a substitute — do not
treat a one-line summary below as the complete rationale for a change.

| Version | Summary |
|---|---|
| 2.0 | Corrected module/capability conflation, Category System reuse, `ManagedPage.kind` vs. public category, Owner/Manager/Editor authority, aggregate-specific lifecycle/visibility, ADR 0019 hold semantics; removed `Advanced/Pro`; replaced MVP list with delivery classes. |
| 2.1–2.2 | Manage-bookings capability sourced explicitly; UI appendix marked non-normative; public-Scenario and Rental CTAs corrected. |
| 2.3 | International metadata (market/country/locale/timezone/currency) made explicit and required. |
| 2.4 | International metadata given dedicated open decision, acceptance criteria and fail-closed rule. |
| 2.5 | Fixed DoD decision-range gate; scoped fail-closed per dependent operation, not globally; split the international metadata registry per field. |
| 2.6 | Added PP-D14–PP-D22 (team, page lifecycle, transfer, slug, concurrency, deletion, notifications, integrations, brand hierarchy) with matching ACs; added non-negotiable-exclusions index. |
| 2.7 | Split `canOpenPageWorkspace`/`canPerformPageAction`; resolved `TeamInvitation`/membership mechanism; resolved co-host, slug, concurrency, deletion, notification-routing and integration-isolation mechanisms in new §22; added PP-D23–PP-D26 (localization, media rights, support, entitlement downgrade). |
| 2.8 | Fixed §22.2's lifecycle matrix overriding aggregate-specific content lifecycle; fixed invitation model to support inviting a non-`User` target; removed `Place` as a co-host grant recipient; separated notification `read` from `acknowledged`. |
| 2.9 | Resolved non-Creator staff workspace access (fixed a live code/spec conflict); stopped merge from carrying over active memberships; catalogued sixteen further operational areas as PP-D27–PP-D42 with matching ACs; added PP-15 Security & access governance. |
| 2.10 | Fixed default-vs-secondary locale contradiction, report-visibility-vs-interim-restriction contradiction, lifecycle table vs. obligation-serving exceptions, and `invited`-status vs. `TeamInvitation` contradiction; tightened co-host/bulk/analytics/entitlement ACs; fixed `PP-D43`'s count and slice range; added PP-16 Operational limits; moved detailed correction history to this changelog file. |
| 2.11 | Added §1.1 Relationship to sibling documents (`VIEWER_PROFILE`, `CREATOR_PROFILE`, `PUBLIC_CREATOR_PROFILE`), disambiguating the `owner` term collision and adding `PP-D44` for the shared-vs-separate Follow model, per the cross-document architecture briefing. |
| 2.12 | Corrected §1.1 after verifying it against the sibling documents directly: Booking is a management projection, not owned; Reviews-about-person is a separate unaccepted feature gated on `VP-D08`, not owned by the public Creator card; "Owns" renamed to "Primary surface responsibility" with aggregate-ownership caveat; Public User Projection scoped to its legitimate trigger contexts; added a sibling-conflict precedence order; confirmed `PP-D44` is proposed, not yet reciprocated, and added its `FollowRelation` shape, `PP-AC-85`, tests and the neutral `FOL-01` slice; fixed Appendix A subsection numbering and the document date. |
| 2.13 | Fixed a real error: `PCP-D04` (content-review display) is independent of `VP-D08` (reviews-about-a-person), not dependent on it as 2.12 stated. Removed §1.1's competing 5-tier precedence order, which contradicted §0's own order (`current-slice spec` at position 2 vs. 4, `LAUNCH_STATUS.md` dropped entirely) — §1.1 now only clarifies within §0's existing tier 4, never restates it. Narrowed `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s row to the private workspace/publisher relationship only; public Creator↔Page cross-link display is `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `PCP-D05`. |
| 2.14 | §0's precedence order previously placed sibling profile documents in item 5's "other product material," below this document's own item 4 — readable as this document outranking its siblings, contradicting §1.1. §0 is restructured to six tiers: ADR → current-slice spec → `LAUNCH_STATUS.md` → owning aggregate/shared contract → all Draft profile-surface specs (this document and every sibling) on equal footing → `VISION.md`/general material. §1.1 no longer cites "§0 item 4" for the sibling tier; it cites item 5. |
| 2.15 | Cosmetic status fix: §0 item 4 and §1.1 listed "the Review contract" among existing Accepted/Approved contracts, which could read as already approved. Both now say "once approved, the canonical Review contract," consistent with §12.5/Appendix A already saying "when approved." No normative change. |
| 2.16 | Found via `docs/product/PROFILE_DOCUMENTS_INDEX.md`, verified against primary sources, and fixed two real defects: §1.1's `owner`-collision example wrongly attributed `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2's `owned \| invited` field to Scenario — it is `QuickPlanRef.relationship`, a Quick-Plan-only field (`VP-D02`); Scenario's own `PersonalScenarioRef.accessRole` is a *different*, Approved, four-value enum (`owner \| editor \| viewer \| unlistedViewer`) that already has both `owner` and `editor`. Also fixed a broken cross-reference: §1.1 cited "§21.1" in `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` for `PCP-D05`; that document ends at §19 — the correct location is §5. |
| 2.17 | Checked `PP-D44` against `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` and `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` directly: both now cross-reference it extensively as a trilateral `PP-D44`/`VP-D12`/`PCP-D02` decision, making this document's "not yet reciprocated" claim stale — corrected in §1.1, `PP-D44` and `FOL-01`. Also surfaced and flagged a real, unresolved shape mismatch: this document's `FollowRelation` discriminates `target: {type: user \| page, id}`; `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s own proposed `FollowRef` has no target field and cannot represent a page-follow at all. Added: a "3 personal-identity documents + 1 `ManagedPage` peer" framing note in §1.1 (matching `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s own framing, without changing the equal-footing precedence tier); a `PublisherRef`-rollout clarification in §0.2 (Place already consumes the shared type, not "Event only"). |
| 2.18 | A full mechanical self-audit, not a content-hunting pass: every `§N`/`§N.M` reference verified to resolve to a real heading (2 false positives found, both legitimate — an external-document citation and a quoted historical citation in the changelog; 0 real breaks); every `PP-D`/`PP-AC` mention verified to resolve to a real definition with no gaps in either range (44/44, 85/85); every cross-document decision ID (`VP-D02/08/12`, `PCP-D02/04/05`) reverified directly against the sibling files as they exist right now, including `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`, which moved v1.8→v1.10 *during this session* — a live demonstration of the cross-document staleness risk this document has repeatedly named but not previously mitigated structurally. §1.1 gains a **verified-against snapshot** naming the exact sibling versions checked (VP v1.10, CP v1.4, PCP v1.3) so future drift is a visible, checkable boundary instead of a silent assumption. |
| 2.19 | New feature, requested and scoped: `PP-D45` — automatic template-reuse suggestions based on a page's own content-similarity history, building on the existing `CRT-TPL-01` (Event-only) and the currently-unwired `AI-PLAT-LOCAL-01` local assistance foundation. Safe boundaries fixed now (suggestion-only, never auto-creates; accepted draft has no live link to its source; reads only the page's own content; opt-in with Messages-grade rate limits); similarity criteria, delivery surface and Create-type scope left open. Added `PP-AC-86`–`88`, a `§7` module row, an `Assist` notification category (`§14`), `PP-17` roadmap slice, and matching `§19` tests. |
| 2.20 | Closed a real gap in `PP-D45`, raised directly: cost. `AI-PLAT-LOCAL-01`'s Accepted status includes a genuine zero-cost ledger only because no production AI provider is connected yet — that document already anticipates real cost via its own session quota and kill switches. `PP-D45` now states explicitly that the suggestion feature is free only while local/mock, and MUST respect that platform's quota/kill-switch discipline and `PP-D38`'s general operational-quota rule once connected to a real provider — not invent a separate cost model. Added `PP-AC-89` and a matching `§19` test; updated `PP-17`'s dependency and `§20.1`'s `PP-D45` row. |
| 2.21 | Split, requested directly: manual "save and reuse" templates need no AI at all, unlike `PP-D45`'s automatic similarity suggestion. Added `PP-D46` — a plain save/list/reuse template mechanism extending `CRT-TPL-01`, with zero `AI-PLAT-LOCAL-01` dependency, shippable entirely independently of `PP-D45`. `PP-D45` reworded to state explicitly it is the detection/suggestion layer only, assuming `PP-D46`'s mechanism as its target rather than defining what a template is. Added `PP-AC-90`–`92`, a `§7` module row, a `PP-18` roadmap slice (ships without AI), matching `§19` tests, and a `§20.1` row. DoD's range moves from `PP-D01–D45` to `PP-D01–D46`. |
| 2.22 | Resolved `PP-D37`'s core question, proposed and confirmed directly: a report never restricts publication or visibility by itself, at any volume — only an affirmative moderator decision does, and that holds regardless of a verified Creator's page-scoped trust level. Strengthened `PP-AC-66`/`PP-AC-78` to state this explicitly (no automated-threshold substitute for moderator confirmation) and added `PP-AC-93` as a dedicated, directly testable statement of the same rule. `PP-D37` moves from fully `Open` to "core rule fixed, narrower parameters (severity codes, repeat-report weighting, appeal SLA, restriction scope) open" in `§20.1`. Added a matching `§19` test. |
| 2.23 | Reviewed an external "Professional Page Model v1.1" draft against this repository before taking anything from it: its cited `PROFESSIONAL_PAGE_PPR_00_RECONCILIATION_SPEC.md` source does not exist anywhere in the repo, and it explicitly declined to use ADR 0015–0017 even though ADR 0015 is titled exactly for this topic and Accepted — so most of its content re-derives, less precisely, what this document and ADR 0015/0017 already establish (it is also silent on ADR 0017's 3-page self-service quota, which this document already had correctly). Five items survived verification as genuinely new and were added: (1) §5.4, onboarding guidance on personal identity vs. creating a page, grounded in ADR 0015 §4, marked explicitly as non-authorizing; (2) §4.4 and new `PP-D47`, a proposed typed `ManagedPageRelation` (operates-Place, branch/headquarters, partner, provider) distinct from the existing undifferentiated `placeIds`; (3) reserved-but-unimplemented `ManagedPagePublicAttribute`/`ManagedPagePublicSection` names in §4.2, closing off a future generic-JSON escape hatch before it can be added under an ad hoc name; (4) `PP-D10` sharpened with an explicit list of individually insufficient claim-evidence signals (name, address, website text, Event relation, social-link similarity, provider import); (5) two new Appendix B rows and `PP-AC-94`/`PP-AC-95` making (2) and (3) directly testable, plus matching `§19` tests and a `§20.1` row for `PP-D47`. DoD's range moves from `PP-D01–D46` to `PP-D01–D47`. Everything else in the external draft (open descriptor/classification model, module-vs-capability separation, Booking/Communications/Insights/Payments/provider boundaries, merge/duplicate handling) was found to already exist here, generally with tighter grounding — not incorporated to avoid duplicating existing §6/§7/§12–§14/`PP-D10` content under new names. |
| 2.24 | Asked directly whether 2.23 took *everything* usable from the external draft — it had not. A second, more careful pass found three more items that were real, not duplicates: a new Appendix C of illustrative boundary examples (generalized from the external draft's worked cases — organization vs. its own event, brand vs. branch, performer vs. host, etc.) making §1/§4.4's boundary concrete for reviewers; a closed gap in §10.1 stating explicitly that Event/Booking participation does not by itself create a follower relation or `ManagedPageMembership` (the external draft's §21 separated these four audience concepts more explicitly than this document previously did); and one clarifying example added to §6 that a page's category never gates its own content's archetype/admission (already true per existing invariants, now stated with a concrete case). Added `PP-AC-96` and a matching `§19` test for the participation/follower/membership independence rule. Confirmed as still deliberately excluded, with reasons unchanged from 2.23: a parallel descriptor registry (duplicates the Category System integration in §6), a full data-ownership matrix (duplicates Appendix B's exclusion index from a different angle), and the external draft's fictional worked scenario (generalized into Appendix C instead of reproduced). No new `PP-D`; DoD range stays `PP-D01–D47`. |
| 2.25 | Companion to `PROFESSIONAL_PAGE_DECISION_PACKAGE.md` v1.1: refreshed the §1.1 verified-against snapshot (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.10→v1.15, `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.4→v1.8, `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.3→v1.8) after re-verifying this document's specific citations still hold against the current sibling text; added a §20 pointer to the decision package. No `PP-D`/`PP-AC` content changed here — the substantive corrections an external review found (`PP-D47`'s structural contradiction, `PP-D15` overstepping into Booking's own state, `PP-D25` conflating Report and personal Block, `PP-D24`'s copyright-implying wording, `PP-D27`'s punted operation matrix, and §7's DoD-incompatible status wording) all landed in the decision package itself, not in this document's own `PP-D` text — this document's problem statements were accurate; only the package's *recommended resolutions* were wrong. |
| 2.26 | Integrated the 17 decisions `PROFESSIONAL_PAGE_DECISION_PACKAGE.md` v1.3 resolved (`PP-D27`, `32`, `45`, `46`, `47` fully; `PP-D05`, `08`, `10`, `15`, `19`, `21`, `24`, `26`, `29`, `37`, `38`, `41` as Accepted core / Explicitly deferred remainder) directly into this document, which is now the normative source for them — the decision package becomes a historical rationale record for this scope, not a live source of truth. New §3.5 is the single normative statement of `PP-D27`'s non-Creator staff verification rule; §3.1/§9.1/`PP-AC-68` now reference it instead of restating it. `PP-AC-73`/§22.2 no longer claim ownership transfer is uniform across `suspended`/`archived`/`tombstoned` (`PP-D32`). §7/§14/`PP-17` roadmap/`PP-AC-86`–`89` drop the AI requirement from `PP-D45`'s v1 (deterministic category+weekday matching, inline Create Hub prompt, no `Assist` notification category); §7/`PP-18`/`PP-D46` fix v1 at Event-only, with per-type expansion Explicitly deferred to Product. §4.4's `ManagedPageRelation` (`PP-D47`) is now an accepted, separate entity from `placeIds`, with a locked v1 registry and an `unconfirmed` display state; `PP-AC-94` updated to match. The remaining twelve split decisions each gained an `(Accepted core; ... Explicitly deferred)` tag at their `§20` definition, a matching `§20.1` row with named remainder-owner and reopening gate, and a short pointer in their owning section (§4.2/§8.2/§11/§12.4/§15.1/§15.3/§22.6/§22.8 per `PP-D05`/`08`/`10`/`15`/`19`/`21`/`24`/`26`/`29`/`37`/`38`/`41`'s mapping). 30 decisions remain not yet integrated by this pass. Mechanical verification: `PP-D1`–`47` and `PP-AC1`–`96` unchanged in count, no gaps/duplicates; `§20.1` still has exactly 47 rows; 0 CR bytes; fences balanced. |
| 2.27 | Integrated the remaining 21 fully-`Accepted` decisions from `PROFESSIONAL_PAGE_DECISION_PACKAGE.md` v1.3's §3/§4 (`PP-D01`, `02`, `03`, `04`, `13`, `14`, `16`, `17`, `18`, `20`, `23`, `25`, `28`, `30`, `31`, `33`, `34`, `35`, `36`, `40`, `43`) and marked `PP-D09`/`39`/`44` `Explicitly deferred` with named owner roles and reopening gates in §20.1 (`PP-D22` was already correctly `Explicitly deferred` from an earlier revision, unrelated to this pass). `PP-D03` needed real new content, not just a status tag: new §5.5 adds the accepted ownership-transfer flow and the `canBecomeManagedPageOwner` predicate (nine conditions, including the ownership-quota check that closes a transfer-based bypass of §5.1's 3-page limit) — §11's stale "ownership transfer... deferred" line corrected to match. The other 20 decisions' content was already substantively present in the document; this pass tags their `§20.1` status and, for `PP-D25`, cross-references the already-existing `PP-AC-66` split (Report vs. personal Block) rather than restating it. Only `PP-D06`, `07`, `11`, `12`, `42` remain `Open` — genuine business/legal/planning calls the decision package itself declines to default, per its own §5. Mechanical verification: status counts now exactly match the decision package's own partition — 25 `Accepted`, 13 `Accepted core`/split, 4 `Explicitly deferred`, 5 `Open`, summing to 47; `PP-D1`–`47`/`PP-AC1`–`96` unchanged in count; `§20.1` still 47 rows; 0 CR bytes; fences balanced. |
| 2.28 | Corrected stale `PP-D16` prose left behind by v2.27: §20.1 already marked the decision Accepted, but its definition and §22.3 still called move-vs-copy open. Both now state the accepted move-only default, with copy as a separate destination-initiated duplicate; exact co-host capability wire codes remain an Approved `PP-02` slice detail rather than reopening the product decision. Refreshed the sibling snapshot to Creator/Public Creator v1.9. No runtime authorization. |
