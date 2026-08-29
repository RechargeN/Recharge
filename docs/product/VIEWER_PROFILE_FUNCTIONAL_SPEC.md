# RECHARGE — Viewer Profile Functional Specification

Status: **Draft for product and architecture review**

Version: **1.17** (splits §12's public-facing identity projection out into
a new sibling, `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.0, at the
user's direct request, mirroring the existing
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`/`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_
SPEC.md` and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`/`PUBLIC_PROFESSIONAL_
PAGE_FUNCTIONAL_SPEC.md` splits; see Appendix B)

Date: **2026-08-16**

Scope: **target full-release product; documentation only**

Compatible with (exact versions; a mismatch means this line is stale and
MUST be fixed in the same change that moves the cited section):
`PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.0 (this document's own
public-facing pair — introduces no decisions of its own, always tracks
this document's current version),
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9,
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9 (being updated in the same
change as this split, to v1.10 — see its own changelog),
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.32 (version pin only — not
re-verified for content in this pass, since this change's only trigger was
the Viewer-side split, not a Professional Page resync),
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v1.1 (same caveat),
`SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1 (Approved). See also
`docs/product/PROFILE_DOCUMENTS_INDEX.md` — a fully non-normative
cross-document navigational and hygiene index over these four documents;
it decides nothing on its own and is itself subject to going stale, but is
a useful map of who owns which concern and which cross-document citations
currently need attention.

## 0. Document authority and purpose

This document defines the target functional model of `Viewer Profile` — the
private personal operational center every authenticated Recharge account
has, independent of Creator status. As of this revision, the public-facing
identity snippet this document used to carry directly in §12 is itself
presentation-split into a sibling document,
`PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` (§12 below is now a short
pointer to it) — mirroring the existing `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
/ `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` split and the newer
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` /
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` split. The profile-surface
family is therefore three private/public pairs over the same distinction —
who is looking, the owner or anyone else — not the three ad hoc groupings
an earlier revision of this document described:

```text
Three private/public pairs, six documents total, all Draft, all on equal
footing in the conflict-precedence tier (tier 5 of the six-tier order
stated later in this section):

  Viewer Profile (this document) <-> Public Viewer Profile
    — every authenticated account's own private operational center, versus
      the minimal identity snippet any other account may see of it,
      attached only to a specific legitimate context (never a standalone
      public page).

  Creator Profile <-> Public Creator Profile
    — a verified Creator's own verification/publisher management, versus
      the public card any other account sees of that Creator (a strict
      superset of the Public Viewer Profile snippet above).

  Professional Page <-> Public Professional Page
    — a page's own team/workspace/lifecycle management, versus the public
      page any other account sees.
```

The first two pairs describe an individual person's identity — the
*personal-identity* pairs; the third describes a `ManagedPage`, not a
person, but sits on the exact same equal-footing Draft-tier precedence and
the same obligation to resolve cross-document conflicts jointly rather than
by unilateral rewrite — a distinction `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
§0 already draws, now extended from the four-document count it was written
against to the current six. `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
`PROFILE_DOCUMENTS_INDEX.md` are refreshed to this six-document count in
the same change that introduces `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md`;
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`'s own framing text were not touched
by this change and are one document behind reality until their own next
pass — the same kind of bounded staleness this document's own Appendix B
has repeatedly named rather than silently carried forward.

The two documents this one does not redefine, each with a distinct,
non-overlapping subject:

```text
docs/product/CREATOR_PROFILE_FUNCTIONAL_SPEC.md
  — Creator verification lifecycle, the personal publisher context
    (`PublisherRef{type: user}`), Created-content management, and this
    account's relationship to any Professional Page it manages. It does not
    redefine anything this document owns.

docs/product/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md
  — the public card of a verified Creator shown to other authorized users; a
    strict superset of `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s minimal
    Public User Projection.
```

**Documents split by audience, not by data.** No document owns a different
slice of the underlying data model — every document above is a
presentation/aggregation surface over the same canonical aggregates
(`UserProfile`, `CreatorVerification`, the ten Create types,
`ManagedPage`, Favorites, Scenario, and so on); none of them is a source of
truth in its own right (§4.2). The split is purely: **who is looking, and
what may they see**:

```text
Who sees it?          Owner, viewing their own account  -> a private-management
                       (self) document (this one, or Creator Profile for the
                       verification/publisher half)

                       Any other account                -> a public-projection
                       document (Public Viewer Profile for a plain account,
                       Public Creator Profile for a verified Creator, or
                       Public Professional Page for a page)
```

A future question of the shape "how should this be visible to others" is
answered by checking whether the owning public-projection document already
resolves it — never by inventing a new rule in a private-management
document. This document does not replace `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`,
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` or
`PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md`; together they cover the full
personal-identity surface with one owner per topic. §25 records the exact
non-overlap so the documents cannot silently diverge.

This document is not an Accepted ADR, does not replace the approved Identity
/ Publisher contract and does not authorize runtime, Firebase, backend or
provider integration. Before implementation, each delivery slice still
requires an Approved bounded slice specification.

When sources conflict, the following order applies — the same six-tier
model `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and `PUBLIC_CREATOR_PROFILE_
FUNCTIONAL_SPEC.md` already converge on, and `PROFESSIONAL_PAGE_
FUNCTIONAL_SPEC.md` extends to its own new sibling, adopted here rather
than restated as an independent order that would rank this document's
siblings above or below itself inconsistently with how they rank each
other:

1. Accepted ADRs, especially ADR 0013, 0015, 0016 and 0019.
2. The Approved current-slice specification.
3. `docs/architecture/LAUNCH_STATUS.md` — only for truth about current
   implementation, never for target product semantics.
4. An Accepted/Approved owning aggregate specification or shared
   cross-product contract (e.g. `SCENARIO_CONNECTED_PLANNING_SPEC.md`,
   `IDENTITY_PUBLISHER_SLICE_SPEC.md`, a future `FollowRelation`
   foundation).
5. Draft profile-surface specifications on equal footing with each other —
   this document, `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md`,
   `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`,
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`,
   `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` and
   `PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`. None of them outranks
   another by virtue of which one a reader opened first; a conflict between
   them is blocked pending a joint decision, not resolved by this tier
   ordering — except that a conflict specifically between this document and
   `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` resolves in this document's
   favor, since that document owns no aggregate of its own (§0 there).
6. `docs/product/VISION.md` and other general product material.

If any statement in this document contradicts tiers 1–4, **that is a defect
in this Draft**, to be corrected — this document has found and fixed
exactly that kind of defect against itself before (Appendix B) and does not
assume it is now free of others.

Canonical supporting sources:

- `docs/adr/0013-domain-policy-baseline.md`;
- `docs/adr/0015-authenticated-viewer-verified-creator-professional-page.md`;
- `docs/adr/0016-bounded-identity-workspace-during-stabilization.md`;
- `docs/adr/0019-authoritative-internal-booking-ledger.md`;
- `docs/product/PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` (this document's
  own public-facing pair — the presentation split-out §12 now points to; it
  introduces no decisions of its own, see §25);
- `docs/product/CREATOR_PROFILE_FUNCTIONAL_SPEC.md` (personal-identity
  sibling — owns verification, personal publisher context and
  Created-content management; see §25);
- `docs/product/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` (personal-identity
  sibling — owns the public Creator card this document's Public User
  Projection is a
  baseline for; see §25);
- `docs/product/PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` (ManagedPage peer, not
  a personal-identity sibling — but equal-footing on the precedence tier
  above; shared invariants MUST NOT diverge without the divergence being
  recorded in §25);
- `docs/product/PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` (that peer's
  own public-facing pair, added to this list for the same reason);
- `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md`;
- `docs/product/S2_EXP_01_PROFILE_SETTINGS_SPEC.md`;
- `docs/product/SCENARIO_BUILDER_SPEC.md`;
- `docs/product/SCENARIO_CONNECTED_PLANNING_SPEC.md` (Approved — the
  canonical source of Scenario's `ScenarioAccessGrant` role model this
  document renders, §5.1);
- `docs/product/SCENARIO_QUICK_PLAN_BOUNDARY_MIGRATION_SLICE_SPEC.md`;
- `docs/product/VISIT_HISTORY_SLICE_SPEC.md`;
- `docs/product/EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md`;
- `docs/product/S3_NOTIF_01_NOTIFICATIONS_SPEC.md`;
- `docs/product/FIND_PEOPLE_CREATE_BLOCK_SPEC.md` (the canonical `find_people`
  Create type — publishing one is Creator-gated, responding to one is not;
  §5.1, §11).

### 0.1 Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` and their Russian equivalents are
normative. `Target` describes intended full-release behavior. `Current` is
only a status snapshot and must be verified in `LAUNCH_STATUS.md` before
work.

### 0.2 Current implementation boundary

At the date of this document, on local/mock runtime, without production auth
backing:

- `S2-EXP-01` is Done: personal profile view/edit (`displayName`, `about`,
  `city`, `avatar`) exists behind the auth gate;
- `VIS-HIST-01` is Done in `LAUNCH_STATUS.md`: self-reported, place-only Visit
  History with idempotent owner+place+day records, descending canonical sort,
  month/day filters and per-record removal
  (`docs/product/VISIT_HISTORY_SLICE_SPEC.md`); missing/corrupt local storage
  is an Approved exception to this document's general partial-load rule —
  see §4.3(8);
- canonical personal Scenario exists in the config-driven Create runtime and
  is shown to the Viewer through `ScenarioLibraryPanel`
  (`apps/mobile/lib/features/explore/presentation/widgets/scenario_library_panel.dart`),
  which lists active/upcoming and completed items and toggles object-update
  notifications per item, but offers no create/rename/copy/archive/delete
  action and collapses to nothing (`SizedBox.shrink()`) on an empty or
  failed load — this document's §5.4 treats that collapse as a defect;
- Quick Plan is a separate legacy runtime
  (`docs/product/SCENARIO_QUICK_PLAN_BOUNDARY_MIGRATION_SLICE_SPEC.md`) with
  no dedicated personal-library surface in Profile, and its full
  invited-membership/collaboration schema is explicitly deferred to a future
  specification by `SCENARIO_BUILDER_SPEC.md`'s own "Scenario и Quick Plan"
  section — this document does not invent that schema (§5.1, `VP-D02`);
- Favorites/Saved runtime filters, opens, maps and removes favorited catalog
  objects and manages saved searches and Smart Search history; canonical
  Scenario is already excluded from the rendered Favorites library and lives
  in the separate Scenario library panel (legacy Scenario-shaped favorite
  values remain read-compatibility debt);
- unlike Visit History's owner-namespaced v2 storage, current Favorites, Saved
  Searches and Smart Search history use device-global local keys and are not
  yet safely re-scoped on an account switch; §15.2 and `VP-05` treat this as a
  release-foundation privacy gap, not as implemented behavior;
- the Viewer Profile page
  (`apps/mobile/lib/features/explore/presentation/pages/profile_page.dart`)
  shows the three most recent Visit History records and a link to the existing
  full filtered list (`_ViewerProfileBody`, line 772), and a `Photos` tab that
  currently only opens Settings
  (`onPhotos: () => context.push(RouteNames.settings)`, line 165);
- there is no production My participation/My bookings surface — the
  authoritative Booking backend (ADR 0019) remains gated per
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §0.2;
- there is no production Review runtime, Photos/media pipeline, Follow,
  personal analytics, account deletion/export/restore, or a formal
  `AccountStatus` state machine — §15.1 defines the target `AccountStatus`
  contract and §12.4 defines the target Follow contract, but no production
  authority backs either yet;
- `S3_NOTIF_01_NOTIFICATIONS_SPEC.md` is Done for exactly: a protected
  local/mock notification list, mark-one-as-read, and opening `targetRoute`
  on tap. It explicitly excludes push delivery, mark-all-read, notification
  preferences and backend/pagination/realtime delivery — this document's
  §16 does not overstate that boundary;
- router guards (`apps/mobile/lib/app/router/app_router.dart:266`) protect
  Profile, Favorites, Visit History, Notifications, Settings and Create
  behind authentication and preserve a safe `originRoute` for post-sign-in
  return, but there is no negative test coverage yet for partial-load
  isolation between Profile's sub-libraries (§15.2).

No target statement below may be presented as currently implemented unless
`LAUNCH_STATUS.md` contains corresponding evidence.

### 0.3 Why this document was resynced with the sibling documents

Exact version-by-version deltas are tracked in Appendix B, not here — this
subsection records only the substance of the largest resync, from v1.2 to
v1.3, so a reader understands why cross-document citations are load-bearing
rather than decorative in this document.

v1.2 of this document was authored before
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` was rescoped to v1.1 and before
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` existed as a separate document.
A cross-session review (2026-08-11) found v1.2 desynced from the new
three-document split — citing section numbers, acceptance criteria and
decision IDs that had moved, been renamed or been retired in the sibling
document's own rescoping — and identified several contracts this document
must own but did not yet formally define. That revision (v1.3):

1. re-points every cross-reference into `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
   at its current v1.1 section/AC numbering, and adds
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` as a full sibling wherever it
   is now the actual owner of a claim this document used to attribute to
   Creator Profile (§1.1, §9, §12, §25);
2. adds a formal `AccountStatus` contract (§15.1) — `PUBLIC_CREATOR_PROFILE_
   FUNCTIONAL_SPEC.md` §3/§3.3 already treats this document as that
   contract's owner and reacts to five named states; v1.2 only had an
   informal bullet list;
3. corrects deep-link authorization from "revalidate ownership" to the full
   grant chain, because an invited (non-owner) participant can hold
   legitimate access (§17);
4. narrows this document's own claim about `S3_NOTIF_01_NOTIFICATIONS_
   SPEC.md`'s authority (§16) and adds the notification-category-ownership/
   dedup decision `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.5 already expects
   this document to track (`VP-D11`);
5. records `VIS-HIST-01`'s Approved corrupt-cache-returns-empty behavior as
   an explicit, named exception to this document's own partial-load
   invariant rather than an unacknowledged conflict (§4.3(8));
6. widens `VP-D02` to cover the Scenario/Quick Plan collaboration *domain*
   contract (editor definition, invitation lifecycle, leave vs revoke,
   audit), not only Profile-surface layout, and states plainly that no such
   accepted contract exists yet (§5.1);
7. widens `VP-D06` to acknowledge the sole-Professional-Page-owner deletion
   precondition `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.4/`CP-AC-19`
   already added on top of this document's deletion mechanics (§24.4);
8. narrows `VP-D07`'s open question to what is genuinely still undecided
   about Public User Projection, now that §15.1 resolves the
   suspended/security-locked display question and a minor's baseline
   projection gets its own decision (`VP-D10`, rewritten — it is not the
   same question as `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `CP-D14`);
9. adds an explicit caveat that "requires only Viewer" (§3.1) does not mean
   "requires nothing" — an owning contract may still require eligibility,
   consent, age policy, moderation readiness or rate limiting;
10. splits the delivery roadmap's two overloaded slices (privacy migration
    vs. partial-load resilience; account deletion vs. multi-device conflict)
    into four, and adds roadmap slices for `AccountStatus`/session security,
    Notifications, base IA/shell and pagination/performance, none of which
    v1.2 tracked as their own slice.

## 1. Product definition

`Viewer Profile` is the product/UI name for the personal operational center
of one individual account: the surface that answers **"What do I have going
on?"**, independent of whether the account ever becomes a verified Creator.
It is built from the same accepted `User` account and `UserProfile` fields as
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` (§4.1 there), plus the personal
libraries this document defines: Scenario library, Quick Plan library,
Favorites, Saved Searches, Smart Search history, Visit History, My
participation, Photos, and Reviews authored/received.

### 1.1 Four surfaces of one account

A single account has up to four distinct presentations, and this document's
first structural requirement is that they are never collapsed into one:

```text
Personal Profile      — private operational workspace; visible only to the
                         owner; this document's primary subject
Public User Projection — the minimal, safe identity snapshot shown next to a
                         Review, a Find People response or a shared plan,
                         even for a Viewer who never verifies as Creator;
                         defined by this document (§12.2)
Public Creator Profile — the opt-in public card of an eligible verified
                         Creator, a strict superset of Public User
                         Projection; defined by
                         PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md
Professional Page      — a separate ManagedPage aggregate; defined by
                         PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md
```

Opening one's own Personal Profile MUST NOT create, imply or require a Public
Creator Profile. A Viewer who never requests Creator verification still has
a Public User Projection wherever their identity is legitimately shown to
another account (§12.2), but never a Public Creator Profile.

Viewer Profile is simultaneously:

- the entry point to personal planning (Scenario, Quick Plan);
- the entry point to personal activity (Favorites, Searches, Visit History,
  My participation, Reviews);
- the entry point to Photos, once a media pipeline exists;
- the boundary that keeps all of the above private by default, distinct from
  whatever the same account later publishes as a Creator.

It is not:

- a `Pro`/`Pro generator` tier by itself (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
  §3.1);
- a proof of Creator authority — every rule in
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.3(3) about active workspace never
  being authorization evidence applies identically here;
- a second Create system, a `ManagedPage`, a Booking backend or a CRM;
- a single aggregated "Saved" bucket — §6 decomposes it explicitly;
- an automatic source of Visit History, Reviews or Follow relationships from
  passive activity (§7, §8);
- the owner of Quick Plan's collaboration domain contract (editor-equivalent
  tier, invitation lifecycle) — that remains genuinely undecided
  (`VP-D02`, §5.1) and belongs to whichever document `VP-D02` assigns it to,
  not to this one by default. Scenario's own collaboration contract, by
  contrast, is not an open question this document could even claim — it is
  already Approved and owned by `SCENARIO_CONNECTED_PLANNING_SPEC.md`
  (§5.1, `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-AC-16`); this document
  only renders that already-settled role set, never redefines it.

## 2. Full-release extension policy

Viewer Profile is designed for a complete product release. A capability is
retained in target scope when all of the following are true:

1. It solves a recurring personal-planning or personal-activity job that
   exists whether or not the account is a Creator.
2. It reuses accepted aggregates and repositories — Scenario, Quick Plan,
   Favorites, Visit History, Notifications — rather than inventing parallel
   ones.
3. It is provider-neutral and degrades honestly offline.
4. It does not silently publish private data or collapse a Viewer-only
   library into a public projection.
5. It can be delivered behind a bounded flag with tests and rollback.

| Class | Meaning |
|---|---|
| Release foundation | Required for Viewer Profile to be a coherent, safe personal center |
| Mature extension | Valuable for full release and suitable for incremental, reversible slices |
| Gated expansion | Retained in target architecture but blocked on backend, legal, moderation or operational readiness |

## 3. Canonical access model

### 3.1 Access states

The same underlying identity/permission split
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.1 defines, restated for this
document's broader scope rather than quoted verbatim — Creator Profile's
own formula requires full `VerifiedCreatorIdentity` unconditionally,
because everything in that document needs Creator authority by definition;
most of what this document governs does not, so the conditional form below
is the accurate generalization, not an independent second access model:

```text
Viewer = authenticated active User

canPerformPersonalAction = Viewer
  + required personal capability for that action
  + verified Creator, only when the action requires Creator authority
  + current access revision
  + target aggregate lifecycle permits the action
```

Every action this document defines — creating a personal Scenario, marking a
Visit, writing a Review, favoriting an object — requires only `Viewer`, not
`Creator`. This is the single most load-bearing rule in this document:
**no personal-library action defined in §5–§10 requires Creator verification
or a `PublisherRef`.** `SCENARIO_BUILDER_SPEC.md` §5 ("Владение, видимость и
результат"), specifically its "Owner, publisher и capabilities" subsection,
already states this for Scenario; this document extends the same principle to
Quick Plan, Favorites, Visit History, My participation, Photos and
Reviews-as-author.

**"Requires only Viewer" is not "requires nothing."** No action here needs
Creator *verification*, but the owning aggregate contract MAY still impose
its own eligibility, consent, age-policy, moderation-readiness or
rate-limiting gate that is unrelated to Creator status — e.g. a Review MAY
require a confirmed interaction with its subject before it can be authored,
and a Photo upload MAY require license confirmation and pass moderation
before it is stored, independent of whether the uploader is `verified`. This
document's own invariants (§4.3) never override such an owning contract's
gate; §3.1's rule only forbids adding a *Creator-verification* gate where
none of the aggregate's own rules require one.

### 3.2 Personal workspace, restated

`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.3 defines the one permanent personal
`WorkspaceRef{type: personal, id: userId}`. Viewer Profile is the UI surface
of that same workspace when the active destination is personal libraries
rather than a Create draft. Switching the active workspace to a Professional
Page (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §3.2) never hides, empties or
suspends Viewer Profile's personal libraries — only the Create Hub's default
publisher changes.

### 3.3 No membership, no capability gate to open

Opening Viewer Profile requires only an active authenticated session — the
same "no membership check to open" principle
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.1 states for the personal workspace
in general. Every sub-library (Scenario, Quick Plan, Favorites, Visit
History, My participation, Photos, Reviews) opens for any Viewer; only
specific mutations (e.g. Create Hub submit/publish) escalate to
`canPerformPersonalAction`.

This section describes the `active`-state case only. An account in
`securityLocked`, `suspended` or `deletionPending` (§15.1) opens a distinct,
narrower **restricted session** — read-only plus obligation-closing only,
never full `canPerformPersonalAction` — rather than ordinary `Viewer`
access; §15.1's action table is the authoritative definition of what a
restricted session may do, and this section MUST NOT be read as granting
full access to a degraded account merely because "opening" itself has no
membership check.

## 4. Domain contracts and invariants

### 4.1 Accepted core entity

Reused from `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.1 without modification:

```text
UserProfile {
  userId, displayName, about?, city?, avatar?,
  email,          // read-only projection
  currentRole,    // read-only projection: User | Creator | Admin
  revision, schemaVersion
}
```

`avatar` (not `avatarUrl`) matches the accepted `S2-EXP-01`/`ProfileEditableEntity`
field name and `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.1's own current
shape.

### 4.2 Personal library projections

The following are **semantic read projections and references**, not wire
schemas and not new source-of-truth aggregates. Each canonical aggregate owns
its own persistence, lifecycle, revision and authorization rules. Viewer
Profile contributes only an account-scoped index, UI lifecycle and privacy
boundary; exact field names require the owning Approved slice:

```text
PersonalScenarioRef {
  scenarioDraftId,          // canonical Scenario, per SCENARIO_BUILDER_SPEC.md
  viewerUserId: userId,     // account whose personal library is being rendered
  ownerId,                  // canonical Scenario owner; may differ from viewer
  accessRole: owner | editor | viewer | unlistedViewer,   // per the Approved
                            // ScenarioAccessGrant (SCENARIO_CONNECTED_
                            // PLANNING_SPEC.md v1.1 §10.1/§10.2) — this
                            // document renders that role, never a narrower
                            // or wider set of its own invention (§5.1)
  visibility: private | unlisted | public,   // canonical owner's setting
  dateMode: template | dated,
  temporalState?: upcoming | inProgress | past, // computed for dated only
  updatesEnabled,
  scenarioRevision,
  trackingRevision
}

QuickPlanRef {
  quickPlanId,               // legacy/utility aggregate, no PublisherRef
  viewerUserId: userId,
  ownerId,                   // may differ when the Viewer is an invited participant
  relationship: owned | invited,   // Quick Plan's own collaboration model
                                    // remains genuinely undecided — no
                                    // accepted contract exists for it, unlike
                                    // Scenario (§5.1, `VP-D02`)
  visibility: private | invited | unlisted,  // per SCENARIO_BUILDER_SPEC.md's
                                              // "Scenario и Quick Plan" — no
                                              // `public` value exists for
                                              // Quick Plan
  participantIds,
  revision
}

FavoriteRef {
  favoriteId, ownerId: userId, targetKind, targetId, savedAtUtc
}
// canonical Scenario is explicitly excluded from FavoriteRef — it lives in
// PersonalScenarioRef instead (current rendered runtime enforces this split;
// legacy favorite values remain read-compatibility input only)

SavedSearchRef { savedSearchId, ownerId: userId, query, savedAtUtc }
SmartSearchHistoryRef { historyId, ownerId: userId, prompt, resolvedAtUtc }

VisitHistoryRecord {
  id, userId, placeId, visitedOn, timezoneId,
  evidence: selfReported | attendanceConfirmed,  // per VIS-HIST-01
  recordedAtUtc,
  presentationSnapshot       // title/subtitle/city/category/cover per VIS-HIST-01
}

ParticipationRef {
  participationId, viewerUserId: userId, targetKind, targetId,
  family: invitation | application | booking | hold | attendance,
  sourceRef,               // ID into the family's own authoritative aggregate
  sourceSchemaVersion,      // so a projection never guesses an unversioned shape
  familySpecificStatus,     // the family's own status vocabulary — never
                             // collapsed into one shared enum (§4.3(7))
  authorityFreshness: live | cachedStale | unavailable,
  updatedAtUtc
}

ReviewAuthoredRef { reviewId, authorUserId: userId, subjectKind, subjectId }
ReviewReceivedRef {
  reviewId, profileOwnerId: userId, subjectKind, subjectId, authorUserId
}

PhotoAssetRef {
  assetId, ownerId: userId,
  visibility: private,      // `public` is reserved, not a currently settable
                             // target — §10 explains why: no rendering
                             // surface exists for it until VP-D07 (public
                             // Viewer route) or a narrower Photos-on-
                             // published-content design is decided
  linkedVisitId?, licenseConfirmed
}

FollowRef {
  followId, followerUserId, followedUserId, createdAtUtc
  // this document's PROPOSED shape for the joint PP-D44/PCP-D02 Follow
  // decision (§12.4) — not an accepted contract, and not shippable until
  // that joint decision resolves; no approval/pending state in the
  // proposal's baseline, and whether an approval-gated variant is ever
  // added is part of VP-D12.
  // KNOWN SHAPE CONFLICT (§12.4): person-only — no `target` field — cannot
  // represent following a page, unlike PP-D44's discriminated
  // `target: {type: user | page, id}` FollowRelation. PROFESSIONAL_PAGE_
  // FUNCTIONAL_SPEC.md tracks the reconciliation as its neutral FOL-01
  // slice; this document does not unilaterally pick a winner here.
}
```

Any storage/wire DTO introduced by an owning Approved slice must preserve
unknown/newer source fields without downgrade, mirroring
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.2 and
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-17`. A Viewer Profile read
projection never rewrites a source aggregate merely because it cannot render a
newer field.

### 4.3 Invariants

1. Every personal-library reference uses permanent IDs, never display
   snapshots, to resolve its canonical aggregate.
2. `PersonalScenarioRef` and `QuickPlanRef` are never merged into one
   lifecycle or one list — they are separate aggregates with separate
   repositories. Scenario's collaboration role model is the Approved
   `ScenarioAccessGrant` (`owner | editor | viewer | unlistedViewer`,
   `SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1 §10.1/§10.2), which this
   document renders exactly per `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
   `CP-AC-16` — never a narrower or wider role set invented here. Quick
   Plan's own collaboration model remains genuinely undecided — no
   equivalent accepted contract exists for it (`CP-AC-17`, `VP-D02`,
   §5.1).
3. A personal Scenario never requires `PublisherRef` while it remains
   private; it acquires one only if and when it is explicitly published,
   which is a Create Hub action, not a Profile action.
4. `Expand to Scenario` creates a **new** Scenario ID and stores source
   provenance on the new Scenario only. It never mutates, retypes or adds a
   live/back-reference to the source Quick Plan; retries with the same command
   idempotency key return the same command result, while a later explicit new
   Expand is a new copy command.
5. `FavoriteRef` never contains a canonical Scenario target — personal
   Scenario lives exclusively in `PersonalScenarioRef`.
6. `VisitHistoryRecord.evidence` is `selfReported` unless a future
   server-authoritative contract sets `attendanceConfirmed`; no other
   Viewer-Profile action (Favorite, Booking, GPS, view, Scenario add) may
   set either value (`VIS-HIST-01` §1).
7. `ParticipationRef.family` values are read projections of their own
   authoritative contracts (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §10.1,
   which `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §11 itself now points to
   rather than restating); Viewer Profile never becomes a second source of
   truth for invitation/application/Booking/hold/attendance state, and
   `familySpecificStatus` never collapses into one shared status enum
   across families.
8. A failed or partial load of one personal library MUST NOT downgrade
   Viewer Profile's other libraries to error state, and MUST NOT be
   presented as an honest empty state (§15.2) — **with one Approved,
   named exception**: `VIS-HIST-01` (§0.2) already defines that missing or
   corrupt local Visit History storage returns an empty history rather than
   an error state, because that is the safer default for a self-reported,
   privacy-sensitive record with no server-authoritative source to recover
   from locally. This document does not silently override an Approved
   sibling contract; every *other* library still follows the general rule,
   and Visit History's own corrupt-vs-genuinely-empty distinction, if ever
   added, is that spec's own future revision, not this document's.
9. `ReviewReceivedRef` indexes a Review whose subject is published content;
   `profileOwnerId` scopes the read projection and does not make that User the
   Review subject. Reviews about a person remain unresolved by `VP-D08`.
10. Local/mock state never claims production attendance, Booking
    confirmation or Review authenticity.
11. **Scenario** `accessRole` mutation rights follow
    `ScenarioAccessGrant`'s own capability table exactly
    (`SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1): `owner` may read, edit,
    invite and manage access; `editor` may read and edit content but never
    invite, manage access, or change owner/publisher/lifecycle/moderation;
    `viewer` may only read; `unlistedViewer` gets only a safe revision, no
    edit. This document renders that table; it never invents a narrower or
    wider Scenario role than the four above. **Quick Plan**
    `relationship: invited` never grants owner mutations: the Viewer may
    open, leave or copy only as the owning aggregate permits, but may not
    rename, archive or delete another account's Quick Plan — this remains a
    minimal placeholder invariant pending `VP-D02`'s Quick-Plan-only
    collaboration contract (§5.1).
12. `temporalState` is recomputed only for a dated Scenario. A template is not
    coerced into `upcoming`, and archive/delete remain separate persisted
    lifecycle states.
13. `FollowRef` (§12.4) is this document's own proposed contract for the
    joint Follow decision (`PP-D44`/`PCP-D02`); within that proposal Follow
    is never gated on Creator verification, `AccountStatus` beyond `active`,
    or any content-publishing fact, and a blocked relationship (§12.3)
    always overrides an existing or attempted `FollowRef` in both
    directions. The proposal itself does not ship until the joint decision
    resolves it — this invariant governs the design, not its current
    acceptance status.
14. `PersonalScenarioRef.visibility` transitions are asymmetric, never one
    uniform "owner setting" (§5.2): `private -> unlisted` requires only
    `Viewer` plus the `share_unlisted` capability
    (`SCENARIO_BUILDER_SPEC.md` §5); `private|unlisted -> public` is the
    Create Hub publish action and requires `VerifiedCreatorIdentity`
    (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.1's "Publish directly"
    stage). Viewer Profile MUST NOT present `public` as reachable through
    the same in-place toggle as `unlisted`, and MUST NOT gate
    `share_unlisted` behind a Creator check that only `publish` actually
    requires.
15. Inviting a specific, already-identified person into an owned Scenario
    or Quick Plan (§5.1) is never the same action as publishing a
    `find_people` request (`FIND_PEOPLE_CREATE_BLOCK_SPEC.md`), and MUST
    NOT share an entry point, a capability check, or a data model with it.
    Publishing `find_people` requires `VerifiedCreatorIdentity` like any
    other Create type; responding to one does not; inviting a known
    person requires neither and is not `find_people` at all.
16. For an account with an `IdentityFieldModerationOverlay` row
    (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §16.1 — exists only once that
    account has been `VerifiedCreatorIdentity`), the baseline Public User
    Projection (§12.2) reads `displayName`/`avatar` from that overlay's
    `lastApprovedPublicValue`, never directly from `UserProfile`, on every
    trigger surface this document defines. For an account with no overlay
    row, `UserProfile` remains the direct source. This document adopts only
    the read-source rule, not the overlay's own still-open lifecycle
    mechanics (`CP-D18`/`CP-D19`).

## 5. My planning — Scenario and Quick Plan

### 5.1 Why they are not one library — and their two different collaboration states

Scenario and Quick Plan are different aggregates with different rules
(`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §10, §9.3; `SCENARIO_QUICK_PLAN_
BOUNDARY_MIGRATION_SLICE_SPEC.md` §3.1). Viewer Profile MUST present them as
two distinct libraries with two distinct empty states, never as tabs of one
merged "Plans" list and never sharing one item card component that hides
which aggregate an item belongs to.

**Scenario collaboration is Approved and accepted.**
`SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1 (Approved, 2026-07-31) §10 defines
`ScenarioAccessGrant` with exactly four roles — `owner | editor | viewer |
unlistedViewer` — and their capability table (§10.1 there). `CREATOR_PROFILE_
FUNCTIONAL_SPEC.md` `CP-AC-16` requires this document render exactly that
role set, never a narrower or wider one invented at the profile level. An
earlier draft of this document (and, independently, an earlier draft of
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`) treated this as an open question and
kept a placeholder `owned | invited` field for Scenario — that was a
verification failure (trusting a sibling document's restatement instead of
checking the primary source), not a genuinely unresolved product decision;
both documents now cite `SCENARIO_CONNECTED_PLANNING_SPEC.md` directly.

**Quick Plan collaboration remains genuinely undecided.** No equivalent
accepted contract was found for it — `SCENARIO_BUILDER_SPEC.md`'s own
"Scenario и Quick Plan" section is explicit that Quick Plan's "full schema,
invited-membership and collaboration policy" sit in "a separate future
specification" it does not itself provide, and
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-AC-17` confirms Quick Plan
collaboration must never be presented as if an accepted role model exists
for it. This document therefore:

- keeps `relationship: owned | invited` (§4.2's `QuickPlanRef`) as the
  current minimal, already-implementable placeholder for **Quick Plan
  only** — not a claim that a full `editor` role, invitation lifecycle, or
  participant-visibility model is accepted for it;
- does not invent a Quick Plan `editor` grant, invitation states
  (`pending|accepted|declined|revoked|expired`), a participant list, a
  max-participant count or an audit trail here;
- tracks Quick Plan's own full domain contract as `VP-D02`, scoped
  exclusively to Quick Plan (§22) — `VP-D02` MUST NOT be read as reopening
  Scenario's already-Approved role model above.

**"Invite a known person" and "Find People" are two unrelated
mechanisms, not two names for one action — a distinction this document
previously left implicit.** `SCENARIO_BUILDER_SPEC.md` §"Scenario и Quick
Plan" states it directly: "invited означает координацию с известными
людьми; открытый поиск незнакомых участников остаётся Find People"
(`invited` means coordinating with known people; open search for
strangers stays Find People). The two differ in exactly the way §5.2's
visibility asymmetry does:

- **Inviting a specific, already-identified person** into an owned
  Scenario (`ScenarioAccessGrant`) or Quick Plan (`relationship:
  invited`) is a plain-Viewer action — no Creator, no publisher, no
  Discover exposure; the invitee is named by `userId`/email/phone, the
  same way `TeamInvitation` names a target (§22's `VP-D02` default).
- **An open call for people the Viewer does not already know** is
  `find_people` — one of the ten canonical Create types
  (`FIND_PEOPLE_CREATE_BLOCK_SPEC.md` §1, `CREATOR_PROFILE_FUNCTIONAL_
  SPEC.md` §9). *Publishing* one requires the same Creator-gated
  `publish.find_people` capability as any other Create type
  (`FIND_PEOPLE_CREATE_BLOCK_SPEC.md`: "публиковать может авторизованный
  Creator с capability"). *Responding to* someone else's already-published
  `find_people` request does not — that same source states plainly
  "Capability Creator для участия не требуется" (Creator capability is
  not required to participate), consistent with §3.1's principle applied
  to a different Create type's participation side.

Viewer Profile MUST NOT present "invite a known friend to my Scenario/
Quick Plan" and "publish a Find People request" as the same feature or
route them through the same entry point — one needs nothing beyond
`Viewer`, the other needs Creator verification, exactly like §5.2's
`unlisted`/`public` split. §12.2's own "Find People response" trigger
surface (Public User Projection shown to a *responder*) is already
correctly scoped to the non-Creator-gated side of this; this section is
what makes that scoping legible rather than assumed.

### 5.2 Scenario library — required lifecycle surface

Viewer Profile MUST support these common Scenario actions:

- expose `Create Scenario` as an entry into `Create Hub -> Scenario`; blank
  Scenario creation MUST NOT occur inside Profile
  (`SCENARIO_QUICK_PLAN_BOUNDARY_MIGRATION_SLICE_SPEC.md` §5.1);
- open an existing Scenario;
- continue an unfinished Scenario;
- render templates separately from dated Scenarios, and map the canonical
  dated `upcoming | inProgress | past` values to clear user-facing
  `Active/Upcoming` and `Completed/Past` groups without persisting those UI
  bucket labels;
- create an independent copy of a public Scenario (`Save a copy`, per
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` Appendix A.2's `Open / Save a
  copy` CTA);
- toggle object-update notifications (already implemented per
  `ScenarioLibraryPanel`);
- add objects to it from Details, Search and Map (already implemented on
  those source surfaces; Profile must explain and aggregate the resulting
  state, not duplicate the add action);
- distinguish `private` from `unlisted` from `public` visibility — these
  three are **not** symmetric owner-editable options; see the dedicated
  explanation below, because collapsing them into "just three visibility
  settings" is exactly the kind of imprecision that would misstate who is
  allowed to set which one;
- distinguish all four `accessRole` values — `owner`, `editor`, `viewer` and
  `unlistedViewer` (§4.2) — these MUST NOT render in one undifferentiated
  list.
- surface a stale, corrupt or revision-conflict Scenario with a safe
  recoverable state, never as if it does not exist.

`ScenarioAccessGrant`'s own capability table (§10.1 there) gives `owner`
Read/Edit/Invite/Share-publish/Manage-access and `editor` only Read/Edit —
it does not itself enumerate profile-level UI commands like rename,
duplicate, archive, soft delete or `Leave`. This document's classification
below is a **reasonable but not Approved-table-literal inference**, pending
`VP-D01`: rename/duplicate/archive/soft-delete are treated as
content-management actions requiring `Edit` **and** implicitly bound to
`owner` because they alter the Scenario's own identity/lifecycle rather
than its contents, so `editor`'s `Edit` grant is read narrowly (item/day/
logistics content only); `Leave` is treated as a `viewer`/`unlistedViewer`
self-service action outside the grant's own capability list entirely
(removing oneself from a library view, not a Scenario mutation). `VP-D01`
owns confirming or revising this mapping — this document does not present
it as settled by the capability table alone:

- `owner` additionally gets rename, independent duplicate, archive, the
  Archived view, soft delete under the canonical Scenario retention
  contract, inviting new collaborators and managing existing grants;
- `editor` gets content edit (add/remove/reorder items, adjust logistics)
  but MUST NOT see invite, access-management, rename, archive, delete,
  publish or moderation controls;
- `viewer` gets read-only open, plus `Save a copy` when source visibility
  permits, and a `Leave`/remove-from-my-library action;
- `unlistedViewer` gets only the safe revision the grant defines — no
  edit, and no guarantee the same content remains visible on a later visit
  if the owner changes it.

None of these four roles requires Creator verification or a `PublisherRef`
(§3.1) — but roles and visibility are two different axes, and that
sentence is about roles only. **Visibility's own authorization is
asymmetric, not one uniform "owner setting":**
`SCENARIO_BUILDER_SPEC.md` §5 defines `edit`, `share_unlisted`, `publish`,
`archive` and `delete` as *separately gated capabilities*, not one bundle,
and states plainly: "Creator capability требуется только для публикации в
Discover" (Creator capability is required only for publishing to
Discover) — nothing else on that list needs it.

- **`private -> unlisted`** is a plain-Viewer action, gated on
  `share_unlisted` — the same personal capability grant that lets any
  Viewer create, edit or invite collaborators to their own Scenario, not
  a Creator-tier capability. Recharge's own MVP-C behavior already reflects
  this: an "authorized User," not specifically a verified Creator, may
  create an unlisted link once the capability and backend contract are
  available (§0.2's local-mock caveat aside). An `unlisted` Scenario is
  reachable only by a revocable link/token — never indexed, never in
  Discover, exactly like `unlistedViewer`'s own access to someone else's
  Scenario (§4.2) — so "share with specific people" and "be found by
  everyone" remain genuinely different actions even though both involve
  a link.
- **`private | unlisted -> public`** is not a visibility toggle at all —
  it *is* the Create Hub publish action (`§9`/`§11`'s "acquires a
  `PublisherRef` only if and when it is explicitly published" rule),
  gated on `canPerformPersonalAction`'s full chain (§3.1), which requires
  `VerifiedCreatorIdentity` for a `publish.*` capability —
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.1's own four-stage table states
  this precisely: "Prepare local draft" (which is what a private/unlisted
  personal Scenario is, end to end) needs "Authenticated Viewer only — no
  verification, no capability," while "Publish directly" needs "Verified
  Creator + explicit trusted `publish.<type>.direct`." A plain Viewer who
  has never verified as Creator can create, edit, duplicate, archive,
  invite collaborators to, and share an unlisted link for their own
  Scenario — every planning action this document defines — but cannot
  make it `public`/Discover-visible themselves. This is not a gap in
  this document's scope; it is the intended shape of the product: full
  personal planning power without Creator verification, publication
  specifically excepted (§1.1, §11).

Viewer Profile MUST render this distinction, not only the three-value
enum: an owner-controlled `Share unlisted link` action is always
available on an owned Scenario regardless of Creator status; a `Publish`
action, if shown at all on a non-Creator account, routes to Creator
verification rather than performing a visibility change directly.

### 5.3 Quick Plan library — required lifecycle surface

Quick Plan is a personal/invited utility, never a Create Hub entry and never
publisher-bearing (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9). Viewer Profile
MUST define:

- where a Viewer's Quick Plans are listed (currently absent from Profile);
- open and continue;
- see current participants, to the extent `VP-D02` (§5.1) has resolved a
  participant-visibility contract — until then, participant display is
  limited to what the current runtime already exposes, not an assumed full
  roster view;
- perform an explicit `Expand to Scenario` action;
- what happens to the source Quick Plan after expansion — it MUST remain
  unchanged and addressable by its own ID, with no live/back-reference, and
  MUST NOT be silently retyped or deleted as a side effect (§4.3(4));
- why Quick Plan never appears in Created/public content — because it has no
  `PublisherRef` and is not part of the ten Create types
  (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9).

Only the owner may delete the Quick Plan. An invited participant receives a
distinct `Leave`/remove-from-my-library action and cannot delete or mutate the
owner's aggregate. Exact leave-versus-revoke semantics, and what happens to a
Quick Plan when its owner's account is deleted, remain `VP-D02`.

### 5.4 Required empty and error states

- an empty Scenario library MUST show a `Create Scenario` entry point routing
  to `Create Hub -> Scenario`, never collapse to nothing — this corrects the
  current `SizedBox.shrink()` behavior noted in §0.2;
- an empty Quick Plan library MUST show its own distinct empty state, not
  reuse Scenario's;
- a load failure on either library MUST show a retry affordance, never
  render as if the library were genuinely empty (§4.3(8), §15.2).

## 6. My activity — Saved is several libraries, not one

`Saved` MUST NOT be presented as one aggregate with one lifecycle. It
decomposes into independently owned libraries, each already partially
implemented on separate runtimes:

| Library | Canonical source | Current state |
|---|---|---|
| Favorites (catalog objects) | `FavoriteRef` | Implemented: filter, open, map, remove |
| Saved Search conditions | `SavedSearchRef` | Implemented on Discover/Favorites surfaces |
| Smart Search history/prompts | `SmartSearchHistoryRef` | Implemented on Discover surfaces |
| Personal Scenario | `PersonalScenarioRef` | Separate library, §5.2 — already excluded from Favorites |
| Quick Plans | `QuickPlanRef` | Separate library, §5.3 — not in Favorites |
| Local publishable drafts | Create Hub draft store | Belongs to `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s publisher context, not Saved |

Viewer Profile MUST link each library from its own entry point, MUST NOT
offer one combined "Saved" delete/clear action that spans more than one
underlying aggregate, and MUST NOT let a Favorites-count metric silently
include Scenario, Quick Plan or drafts.

## 7. Visit History

Reusing the Approved `VIS-HIST-01` contract as the canonical source, Viewer
Profile MUST support, for the account owner only:

- manually mark a Place visited;
- choose today or an earlier calendar date, never a future date;
- record the same Place on multiple different days as separate records;
- open the underlying Place from a record;
- delete an individual record;
- filter/sort the full history (the dedicated current screen already provides
  descending order plus month/day filters; Profile shows the three most recent
  and links to it — `profile_page.dart:772`);
- keep the history private by default (§12);
- on missing/corrupt local storage, return an empty history rather than an
  error — this is `VIS-HIST-01`'s own Approved behavior, not a violation of
  this document's general partial-load rule (§4.3(8)).

Viewer Profile MUST NOT auto-create a Visit History record from a Details
view, a Favorite, a Booking, GPS proximity, a check-in, or adding the Place
to a Scenario — `VIS-HIST-01` §1 and `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
§11 both already state this (via `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
§10.1's state-family separation, which both sibling documents reuse rather
than restate); this document repeats it because Visit History is the single
most likely place for a future integration to silently violate it.

## 8. My participation

My participation is the Viewer's own aggregated view across the state
families `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §10.1 defines and
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §11 reuses without restating —
invitation delivery, application/registration, Booking, hold and attendance
— filtered to `userId = self`. It is not Created content and not Visit
History. Target scope:

- my registrations/applications: `requested | approved | rejected |
  withdrawn`;
- my Bookings: `pending | confirmed | waitlisted | cancelled | expired`;
- my active holds;
- tickets or confirmations, once a Booking backend exists;
- my received invitations;
- upcoming participation, derived from confirmed/approved items with a
  future date;
- participation history (past, completed);
- cancellation/refund/support actions, gated on the same contracts that gate
  them for a publisher (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §13, which
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §13 also reuses unchanged).

**An `application/registration` entry never double-represents an event
already carried by the `booking` family.** `EVENT_CLASSIFICATION_
ECL_03_SLICE_SPEC.md` §6.1 models `admissionMode: application` as a field
on the `Booking` aggregate itself — an Event with manual-application
admission produces a `Booking` record whose canonical `state` is exactly
`pending | confirmed | cancelled | expired | waitlisted` (§6.1 there:
"`pending` is an application awaiting organizer decision"), not a
separate non-Booking application record and not a second, Profile-invented
status label. This document's `application/registration` scope above
applies only to an admission mechanism that genuinely has no `Booking`
record backing it (e.g. a pre-Booking interest/waitlist-signal contract, if
one is ever approved); for `admissionMode=application` specifically, the
single `ParticipationRef` with `family=booking` and `familySpecificStatus`
set to that same canonical `state` value (e.g. `pending`) is the only
representation — it MUST NOT also appear as a `family=application` entry
for the same event, and `familySpecificStatus` MUST NOT invent a value
like `pendingApplication` that does not exist in ECL-03's own vocabulary.

My participation MUST read each state from its own authoritative aggregate
(§4.3(7)) and MUST NOT introduce a second Booking status enum — the
`ParticipationRef` shape (§4.2) is a tagged projection (`family` +
`sourceRef` + `sourceSchemaVersion` + `familySpecificStatus` +
`authorityFreshness`) specifically so a generic `status` field can never
silently become a de facto universal enum across families. The authoritative
Booking ledger is ADR 0019's subject; its Approved implementation contract is
`docs/product/EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md`, and My
participation's own read projection is scoped by that same contract rather
than defined independently here. Until that backend is activated in
production (its runtime boundary is explicitly production/backend-only —
local/mock confirmation is not authorized), this section has no production
surface — an honest "not yet available" state is required, never a
simulated one (§4.3(10)).

## 9. Reviews — authored and received

Two distinct lists, both scoped to the canonical Review contract once
approved. This document owns **authoring** (Reviews written by me) and
**being the recipient** of a review on content it published as `{type:
user}` as private, personal-library facts; it does not own how those reviews
are aggregated and displayed on a *public* card — that half is
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §6's subject. **Reviews about
published content and reviews about a person are two independent features
with independent dependencies, not one dependency chain** — that document's
§6 is explicit about this after correcting its own earlier draft: the
public aggregated rating on a Creator's published content depends only on
`PCP-D04` (computation, sample size, placement) and the underlying Review
contract, and does **not** depend on `VP-D08` at all. `VP-D08` gates only
reviews-about-a-person (below); it never blocks content-review display:

- **Reviews written by me** — authored, editable/removable by the author
  per the Review contract's own rules;
- **Reviews about my content** — received on a specific Event/Place/
  Route/Scenario the Viewer published with personal
  `PublisherRef{type: user, id: userId}`; page-published content belongs to the
  Professional Page workspace. This is content-scoped, not identity-scoped,
  and requires no Creator verification merely to read
  (reviewing a private personal Scenario is out of scope — reviews attach
  to published content);
- **Reviews about me as a person** is explicitly out of scope for this
  document and is not implied by publishing content — it requires its own
  product decision (§22, `VP-D08`) before any
  affordance exists. Publishing content MUST NOT automatically make the
  account a Review subject for anything beyond that content.

No Review runtime exists in production today (§0.2).

## 10. Photos

Distinct from a Photos tab that redirects to Settings (§0.2). Full-release
scope requires deciding and then implementing:

1. whether personal Photos are distinct from media attached to published
   content, or the same media pipeline with a visibility flag;
2. per-photo visibility: private today; a `public` value is reserved in
   the target schema (§4.2) but not currently settable — see below for why;
3. whether a photo can be attached to a Visit History record as an
   independent relation that does not change its visibility by itself;
4. ownership/license confirmation before upload;
5. moderation policy;
6. deletion and orphan cleanup when a linked Visit or content item is
   removed;
7. original versus processed/thumbnail variants;
8. an offline upload queue with retry.

Until a production media pipeline exists (§0.2), the Photos tab MUST present
an honest "not yet available" state rather than opening an unrelated screen
that implies the feature exists.

**`PhotoAssetRef.visibility = public` (§4.2) currently has no rendering
surface, and this document does not invent one.** There is no standalone
public Viewer Profile route (§12.2's Public User Projection is a
name/avatar/city snapshot shown *within* another surface, not a page a
Photo could be displayed on), and a plain Viewer's public Photos are not
part of a Public Creator Profile either (that card shows only `{type:user}`
Created content, `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.1). Until
either a public Viewer route is decided (`VP-D07`) or Photos are scoped to
attach only to published `{type:user}` content (a narrower design this
document has not adopted), `visibility: public` on a personal Photo MUST be
treated as "not yet renderable anywhere" — the field exists in the target
schema, but setting it MUST NOT be presented to the owner as if it produces
a visible public surface today.

## 11. My publishing — boundary only

Draft management, Creator verification, the Create Hub, `PublisherRef`
resolution and the public Creator card are the sibling documents' subject
(`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §5, §9, §19;
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4). Viewer Profile's only
obligations here are boundary-preserving:

- a Viewer with `notStarted` Creator verification still has full access to
  §5–§10 of this document;
- Viewer Profile surfaces a link into Creator verification/Create Hub, but
  never performs a publish action itself;
- a personal Scenario never silently acquires a `PublisherRef` because the
  Viewer later verifies as Creator — `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s
  own invariant 7 now cites this document's §4.3(3) as the source of that
  rule, rather than the other way around;
- **a plain Viewer's personal-planning power is deliberately complete
  short of publication, not a reduced subset of Creator's.** Every
  Scenario/Quick Plan action this document defines — create, edit,
  duplicate, archive, invite collaborators, share an unlisted link — is
  available identically whether or not the account is a verified Creator
  (§3.1, §5.2's visibility asymmetry). The *only* capability a Creator has
  that a plain Viewer does not is the one this document has no business
  granting: making content `public`/Discover-visible, which is
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.1's "Publish directly" stage,
  gated on `VerifiedCreatorIdentity`. Viewer Profile MUST NOT gate
  unlisted sharing, collaboration, or any other planning action behind a
  Creator check just because publication happens to require one — doing
  so would incorrectly narrow what a plain Viewer can do, not merely fail
  to widen it;
- local pre-verification publishable drafts belong to My publishing, not to
  any library in §5–§10;
- **"Find People" is the same split under a different name, not a second
  exception to track separately.** Publishing a `find_people` request
  (`FIND_PEOPLE_CREATE_BLOCK_SPEC.md`) is Create Hub publication like any
  other of the ten types — Creator-gated, out of this document's scope,
  belongs to `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9 exactly as Scenario
  publication does. Responding to an already-published `find_people`
  request is not gated on Creator status, matching every other
  participation action this document defines (§8). Inviting a specific,
  already-known person into an owned Scenario or Quick Plan is a third,
  unrelated mechanism (§5.1) that never touches `find_people` or Creator
  status at all. This document's own scope is the second and third of
  these three, never the first.

## 12. Public projection and privacy

The public-facing identity projection — visibility defaults, the Public
User Projection field set, discoverability/blocking/deleted-account
handling, and the proposed Follow direction — is owned by
[`PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md`](./PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md),
not restated here. That document is a presentation split-out only: it
introduces no new `VP-D`/`VP-AC` numbering and defers to this document's
decisions and invariants (`VP-D07`, `VP-D10`, `VP-D12`, invariants 13 and
16 in §4.3) for every rule it states. Every `VP-AC-*` criterion, test-matrix
entry and Appendix A row in this document that cites "§12.x" still resolves
correctly — the heading numbers below are unchanged, only their content is
now a pointer.

### 12.1 Visibility defaults — see sibling document §2

### 12.2 Public User Projection — see sibling document §3

### 12.3 Discoverability, blocking, deleted accounts — see sibling document §4

### 12.4 Follow (proposed direction only) — see sibling document §5

## 13. Product modules versus authorization capabilities

Same separation as `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §7:

```text
module preference = what the profile wants to show/use
capability = what the account is authorized to do
feature flag/entitlement = what the environment/account may access
policy/readiness = whether the operation is currently safe and supported
```

| Module/surface | Delivery class | Boundary |
|---|---|---|
| Personal identity and settings | Release foundation | Safe edit of accepted `UserProfile` fields |
| `AccountStatus` and session security | Release foundation | Formal state machine per §15.1; no production authority yet (§0.2) |
| Scenario library | Release foundation | Full lifecycle per §5.2, no Creator gate |
| Quick Plan library | Release foundation | Full lifecycle per §5.3, no publisher, minimal collaboration model pending `VP-D02` |
| Favorites / Saved Searches / Smart Search history | Release foundation | Already-accepted personal projections, kept decomposed |
| Visit History | Release foundation | Self-reported only, per `VIS-HIST-01` |
| Notifications | Release foundation | Local/mock list + mark-one-read + `targetRoute` per `S3-NOTIF-01`; delivery, preferences and dedup remain `VP-D11` |
| My participation | Gated expansion | Requires authoritative Booking/invitation sources |
| Photos | Gated expansion | Requires a production media pipeline and policy |
| Reviews authored/received | Gated expansion | Requires the canonical Review and moderation contract |
| Reviews about me as a person | Gated expansion | Separate product decision, `VP-D08` |
| Public User Projection | Mature extension | Minimal safe identity snapshot per §12.2; requires a live trigger surface (Review, Find People, invited Scenario, shared plan, or Follow) |
| Follow | Gated expansion | Proposed by this document (§12.4), not accepted — blocked on the joint `VP-D12`/`PP-D44`/`PCP-D02` decision, not merely "mature" |
| Account deletion/export/restore | Gated expansion | Legal/retention review, plus Professional-Page-ownership precondition (§24.4) |

Core navigation cannot be disabled by module preferences. Disabling a module
must not delete its data or hide unresolved obligations.

## 14. Information architecture

Personal navigation is unchanged from `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
§8:

```text
Home · Favorites · Smart Search · Notifications · Profile
```

Within Profile, the current dashboard tabs vary by presentation role
(`ProfileRoleSummary`/`ProfileRoleTier` in `profile_page.dart`) — e.g. a
`user`-tier Viewer sees `Visited`/`Photos` while a `proGenerator`-tier
account sees `Page`/`Created`/`Insights`/`Photos`. This document requires
that regardless of tier, the personal surface groups in §5–§10 (Scenario,
Quick Plan, Saved/Favorites, Visit History, My participation, Reviews and
Photos) remain independently reachable when their delivery gate is enabled;
disabled gated modules show only the honest state §18 requires. A
Creator-tier presentation MUST NOT hide a Viewer's own
Scenario/Quick Plan library behind the Creator-facing `Created` tab, because
those are different libraries with different ownership semantics (§5.1).

The exact top-of-page hierarchy, card density, and section ordering for this
IA are not yet specified — tracked as roadmap slice `VP-15`.

## 15. Account, session and multi-device states

### 15.1 `AccountStatus` — formal contract

This document is the sole owner of the account-status axis.
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3/§3.3 already treats this
contract as authoritative and reacts to it without redefining it; this
subsection is that definition.

```text
AccountStatus: active | securityLocked | suspended | deletionPending
             | tombstoned
```

- Set only by the authoritative backend (Auth/session security, Admin
  moderation, or this document's own account-deletion flow); never
  client-writable, mirroring the fail-closed pattern used throughout the
  sibling documents.
- `securityLocked` is triggered by an automated security signal (e.g.
  anomalous sign-in) and is distinct from `suspended`, which is a
  moderator-initiated decision; both block the same set of actions (below),
  but only `suspended` carries a moderation-appeal path and only
  `securityLocked` carries a self-service unlock path (re-authentication/MFA).
  This document does not introduce a separate `disabled` status value — an
  administratively disabled account is represented as `suspended` with a
  reason code, not a sixth enum value, so the two sibling documents' already-
  accepted five-value contract is not broken by a later addition.

Transitions:

```text
active         -> securityLocked   (automated security signal)
securityLocked -> active           (self-service unlock — requires a fresh
                                     session-scoped StepUpGrant for THIS
                                     session, below, and revokes every
                                     OTHER active session as part of the
                                     same transition)
active         -> suspended        (moderation decision)
suspended      -> active           (appeal upheld)
active | suspended
               -> deletionPending  (owner-initiated deletion request, §24.4)
securityLocked -> deletionPending  (owner-initiated deletion request from a
                                     locked account — requires a fresh
                                     session-scoped StepUpGrant for THIS
                                     request; REJECTED, not merely flagged,
                                     without one — see below)
deletionPending -> active          (owner cancels within the request window)
deletionPending -> tombstoned      (obligations clear, §24.4; retention window starts)
tombstoned     -> active           (restore within the retention window,
                                     §24.4 — always to `active`, never to
                                     whatever status preceded tombstoning;
                                     any unresolved security lock or
                                     suspension must be re-evaluated fresh
                                     against the restored account, not
                                     silently carried over)
tombstoned     -> [purged]         (retention window elapses; not a further
                                     AccountStatus value — an irreversible
                                     action, not a state)
```

**Precedence when triggers compete.** `AccountStatus` is a single value, so
"simultaneous" `deletionPending` + `suspended` cannot occur by construction
— but a security or moderation signal arriving *while* `deletionPending` is
active MUST still be handled: it transitions the account to
`securityLocked`/`suspended` (security/moderation signals take precedence
over an in-flight deletion request), which pauses the deletion request
rather than discarding it. Once the security lock clears or the suspension
is appealed, the account returns to `deletionPending` — not to `active` —
so the owner's original request is honored rather than silently lost.

**Session-scoped step-up — replaces a global boolean that was itself a
security defect.** A prior revision of this section tracked step-up as one
account-wide `pendingSecurityVerification: bool`. That was wrong in a way
a 2026-08-12 review confirmed by reading the transition table literally:
(1) nothing gated *entering* `deletionPending` from `securityLocked` on
step-up at all — only *closing an obligation afterward* was gated, so a
hijacked session with no obligations to close could request deletion and
ride the account to `tombstoned` without ever proving anything; (2) a
single account-wide flag meant the legitimate owner completing step-up on
one device would silently clear the flag for every other session,
including a concurrently active hijacked one that never proved itself.
Both are closed by making step-up a fact about one session, not the
account:

```text
StepUpGrant {
  sessionId,              // exactly one session — never account-wide
  purpose: accountUnlock | deletionRequest | obligationClose,
  verifiedAtUtc,
  expiresAtUtc             // short-lived; VP-D15's own recommended default
                            // is 15 minutes of freshness
}
```

- A `StepUpGrant` authorizes exactly one `sessionId` for exactly one
  `purpose`. Completing step-up on session A never grants, extends, or
  implies a grant for session B — this is what actually closes the
  cross-session leak; renaming the same global boolean would not have.
- `securityLocked -> active` (self-service unlock) requires a fresh
  `StepUpGrant{purpose: accountUnlock}` for the unlocking session, and —
  as a **mandatory, non-optional part of the same transition, not a
  follow-up step** — revokes every other active session's token
  immediately. A session that never completed the challenge does not
  inherit trust when the owner unlocks elsewhere; it is logged out.
- `securityLocked -> deletionPending` requires a fresh
  `StepUpGrant{purpose: deletionRequest}` for the requesting session. This
  is the fix for the exploit path itself: a hijacked session cannot walk
  a locked account into `deletionPending` merely by being `securityLocked`
  — the request itself is the gated action, not only what happens after it
  is accepted.
- Closing an already-existing My participation obligation while
  `securityLocked` requires a fresh `StepUpGrant{purpose:
  obligationClose}` for the acting session (§8; unchanged in substance
  from the prior revision, restated in session-scoped terms).
- Because entry into `deletionPending` from `securityLocked` already
  required a verified session (above), `deletionPending -> tombstoned`
  does not need a *second* step-up check — the account can only have
  reached `deletionPending` from a locked state via a session that already
  proved itself at the point of request. "Obligations clear" remains the
  sole condition for that specific transition; the exploit is closed
  upstream, at the request, not retroactively at the point of tombstoning.
- **Recovery path for a legitimately locked-out owner.** If the true owner
  cannot complete a `StepUpGrant` (lost device, no MFA access), self-service
  unlock and self-service deletion are both correctly unavailable to them
  too — that is the security property working as intended, not a gap. The
  only path forward is a human-support-verified account-recovery flow,
  which this document does not itself design (tracked under `VP-D15`) but
  MUST exist: a locked-out true owner is not meant to be permanently
  unable to recover or delete their own account, only unable to do either
  without proving who they are.

`suspended -> tombstoned` (moderation escalation to permanent removal) is
acknowledged as a real transition but its exact mechanics are out of this
document's scope — it is a moderation/legal decision, not a Viewer Profile
UX decision, and is not blocked from existing by this contract.

**Terminology note.** §3.1 defines `Viewer = authenticated active User` —
that definition governs full `canPerformPersonalAction` access, not mere
Profile reachability. An account in `securityLocked`, `suspended` or
`deletionPending` is, by that definition, *not* a `Viewer` in the full
sense; the read-only/obligation-closing access §3.3 and the table below
grant such an account is a distinct, narrower **restricted session** —
named here so it is never confused with, or silently treated as
equivalent to, ordinary `Viewer` access in an implementation.

Allowed actions by state:

| `AccountStatus` | Personal Profile (owner's own session, or restricted session below `active`) | Public User Projection | Public Creator Profile (if eligible) |
|---|---|---|---|
| `active` | Full `Viewer` read/write per §3.1's `canPerformPersonalAction` | Shown per §12.1 defaults | Per `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.2 |
| `securityLocked` | Restricted session, blocked from new commitments; unlocking requires a fresh session-scoped `StepUpGrant{purpose: accountUnlock}` (and revokes every other session, above); closing an already-existing My participation obligation or requesting deletion each separately requires their own fresh `StepUpGrant` for the acting session — `securityLocked` exists specifically because the current session's own legitimacy is in question, so no privileged action proceeds on the strength of that session alone, only on a freshly re-proven one | Withdrawn | Withdrawn |
| `suspended` | Restricted session, blocked from new commitments; the appeal flow, and closing an already-existing My participation obligation, remain available without step-up — `suspended` alone questions the account's standing, not the current session's legitimacy, so no `StepUpGrant` is required by this row on its own | Withdrawn | Withdrawn |
| `deletionPending` | Restricted session, blocked from new commitments; the cancel-deletion action, and closing an already-existing My participation obligation, remain available without a further step-up check for *this* transition specifically — entry from `securityLocked` already required one (above) | Withdrawn | Withdrawn |
| `tombstoned` | Inaccessible via a normal or restricted session; only the restore flow (if within the retention window) is reachable | Not-found response, indistinguishable from a nonexistent account (§12.3) | Not-found response |

**Obligation continuity, not a blanket lockout.** "Read-only" in the three
degraded-but-not-terminal rows above does not mean "cannot act at all": it
means new commitments (a new Scenario, a new Booking request, a new
publish) are blocked, while *closing* an obligation already in progress —
cancelling a Booking, responding to a hold, honoring a legal or safety
requirement — remains reachable. This generalizes the same principle
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §5.4 already applies to verification
loss and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-73`/§22.2 apply to a
degraded page: a status that exists to stop new activity must not, as a
side effect, strand an obligation the account cannot then honor. `tombstoned`
is the one genuine exception — by that point the account is inaccessible by
construction, and any still-open obligation is `VP-D06`'s and
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.4's precondition to clear *before*
`deletionPending` is even allowed to transition there (§24.4).

This table is the single source of truth
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.3 already assumes; that
document MUST NOT be read as independently defining these states.

### 15.2 Session and multi-device states

Required behavior, none of which exists in production today (§0.2):

- session restore on cold start, including a mid-restore loading state that
  is distinct from "logged out";
- an expired session during active editing (e.g. mid-rename of a Scenario)
  fails closed on the next mutation and preserves the local unsaved draft
  where the owning aggregate supports drafts, without silently discarding
  it;
- switching accounts on one device fully re-scopes every library in §5–§10
  to the new `userId` — no cross-account leakage of cached Favorites, Saved
  Searches, Smart Search history, Visit History or Scenario; device-global
  keys currently used by the first three (§0.2) must migrate or be cleared by
  an Approved owner-scoping slice before production multi-account use;
- a role/capability change (e.g. Creator verification completing) while
  Profile is open updates the presentation without discarding open personal
  library state;
- Creator verification expiring mid-draft-edit is
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s concern (§9.2's step 9, restricted
  maintenance mode per its own §5.4) but Profile MUST still render the
  Viewer's own §5–§10 libraries unaffected by that expiry — `AccountStatus`
  (§15.1) and Creator verification status remain independent axes, exactly
  as `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3 requires them to;
- a conflicting edit from another device uses the owning aggregate's
  approved revision/idempotency precondition and fails closed. Viewer Profile
  MUST NOT introduce one shared per-account revision that couples independent
  libraries; exact per-contract mechanisms remain `VP-D09`;
- corrupt local profile/library cache fails closed to an explicit recovery
  state, never a silent empty state — except Visit History's own Approved
  exception (§4.3(8));
- a partial load — Profile itself loads but Scenario or Favorites does not —
  MUST isolate the failure to that one library (§4.3(8)).

## 16. Notifications and settings

`S3_NOTIF_01_NOTIFICATIONS_SPEC.md` is Done for exactly a protected local/mock
notification list, mark-one-as-read, and opening `targetRoute` on tap. It
explicitly excludes push delivery, mark-all-read, notification preferences
and backend/pagination/realtime delivery (§0.2) — this document does not
claim that spec covers delivery, preferences or production filtering; all
three remain open work tracked below and by `VP-D11`.

Notification categories, scoped to the Viewer rather than a page:

| Category | Examples |
|---|---|
| Personal planning | Scenario object update, Quick Plan participant change |
| Personal activity | Visit History reminder (if ever offered), Review received on my content |
| Participation | Booking/hold status change, invitation received |
| Social | New follower — only once the joint Follow decision (§12.4, `VP-D12`) resolves; absent until then |
| System | verification status change, security, `AccountStatus` transition, account obligation |

`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.5 defines its own Creator-tier
category (verification status change, content moderation decision on
`{type:user}` content) as **distinct** from this document's categories, and
explicitly states the two "MUST NOT duplicate the same underlying event into
two inbox entries" while deferring exact dedup ownership to this document's
own decision (`VP-D11`, §22) — that decision did not exist before this
revision.

Settings groups, extending — not replacing — the already-Approved
`S2_EXP_01_PROFILE_SETTINGS_SPEC.md` surface. Every item that spec already
approves remains in scope here; this document adds to that list, it does
not narrow it:

- personal identity: `displayName`, `about`, `city`, `avatar` (editable),
  plus `email`, `userId`, `currentRole` (read-only, per `S2-EXP-01`);
- library visibility defaults (§12.1);
- notification preferences per category above (target; not yet defined by
  any Approved contract — `VP-D11`);
- `language`, `currency` and the `notifications` on/off toggle (already
  implemented per `S2-EXP-01`);
- `logout` (already Approved per `S2-EXP-01`);
- `support/help`, `privacy policy` and `terms of service` links (already
  Approved per `S2-EXP-01`);
- privacy and data rights;
- account deletion request (§18, `VP-D06`).

## 17. Security, privacy, offline and operations

- Clients cannot write Booking, hold, attendance, Review authenticity or
  `AccountStatus` state directly — only the owning authoritative backend
  does.
- Public projections (§12) exclude every §5–§10 library by default.
- Deep links into a specific Scenario, Quick Plan, Visit History record or
  any other §5–§10 item MUST validate the full authorization chain, never
  ownership alone: authenticated actor + exact resource ID + the current
  aggregate-scoped grant (owner **or** invited participant, per that
  aggregate's own contract) + access revision + lifecycle/visibility state +
  block/revocation state. "Ownership" is only one possible grant among
  several — an invited (non-owner) participant with a legitimate,
  non-revoked grant MUST resolve successfully, and a revoked or blocked
  grant MUST fail even for a former owner or participant.
- Offline reads of §5–§10 libraries may be cached with freshness labels;
  offline state never confirms a Booking, an attendance record, a Review
  submission, or an `AccountStatus` transition.
- Stale or unknown authority fails closed with retry/recheck guidance.
- Each production module requires observability, a bounded event taxonomy,
  a feature flag/kill switch, migration and rollback.

## 18. Required UX states

- authentication/session restoring (§15.2);
- empty Scenario library with `Create Scenario` (§5.4);
- empty Quick Plan library, distinct from Scenario's;
- Scenario/Quick Plan load error, distinct from empty (§5.4, §15.2);
- all four `accessRole` values (owner/editor/viewer/unlistedViewer)
  rendered distinctly (§5.2);
- stale/corrupt/revision-conflict Scenario;
- decomposed Saved libraries, each with its own empty state (§6);
- empty Visit History, and corrupt-storage-as-empty per its own Approved
  exception (§4.3(8)) — visually indistinguishable from genuine empty, by
  that spec's own design;
- My participation "not yet available" honest state (§8);
- Photos "not yet available" honest state (§10);
- partial-library-load isolation (§4.3(8), §15.2);
- `securityLocked`/`suspended`/`deletionPending`/`tombstoned` account states,
  each with the distinct available-action set §15.1's table defines;
- Public User Projection preview, distinct from Public Creator Profile
  preview (§12.2);
- blocked-viewer access to another account's projection (§12.3);
- minor-account baseline projection state, once `VP-D10` resolves it (§12.3).

All critical flows must support en/ru/lv-ready strings, 360 dp width, 150%
text scale, keyboard/screen-reader semantics and no color-only status
meaning.

## 19. Delivery roadmap

| Slice family | Scope | Class | Key dependency |
|---|---|---|---|
| VP-01 Scenario library completion | Create Hub entry; owner rename/copy/duplicate/archive/soft-delete; editor content-edit surface; template/dated and four-role `accessRole` split; non-collapsing states | Release foundation | `ScenarioLibraryPanel` extension, `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10 |
| VP-02 Quick Plan library and collaboration contract | Profile list, open/continue, owner-delete versus invited-leave, `Expand to Scenario`, plus Quick Plan's own (still undecided) collaboration domain contract (§5.1) — Scenario's own collaboration is already Approved and out of this slice's scope | Release foundation | `SCENARIO_QUICK_PLAN_BOUNDARY_MIGRATION_SLICE_SPEC.md`, `VP-D02` |
| VP-03 Saved decomposition | Independent entry points and empty states for Favorites/Saved Search/Smart Search history | Release foundation | Existing Favorites runtime |
| VP-04 Visit History integration verification | Preserve the existing full list, month/day filters, canonical sort and 3-item Profile preview | Release foundation | Done `VIS-HIST-01` baseline |
| VP-05 Owner-scoped storage migration | Migrate device-global Favorites/Saved-Search/Smart-Search-history caches to `userId` scope | Release foundation | §0.2, §15.2 |
| VP-06 My participation | Booking/hold/invitation aggregated read view | Gated expansion | ADR 0019 authoritative Booking |
| VP-07 Reviews | Authored/received lists on the canonical Review contract | Gated expansion | Approved Review slice |
| VP-08 Photos | Production media pipeline, per-photo visibility | Gated expansion | Media pipeline decision |
| VP-09 Account deletion, export and restore | Deletion mechanics, retention window, Professional-Page-ownership precondition (§24.4) | Gated expansion | Legal/retention approval, `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-AC-19 |
| VP-10 Public User Projection | Minimal safe identity snapshot next to Reviews/Find People/shared plans | Mature extension | Reviews or Find People contract |
| VP-11 Partial-load isolation and resilience | Per-library error/empty separation across §5–§10 | Release foundation | §4.3(8), §15.2 |
| VP-12 `AccountStatus` and session security | Formal five-state contract (§15.1), transitions, per-state action gating | Release foundation | Auth/session backend |
| VP-13 Multi-device concurrent editing | Per-library revision/idempotency conflict handling | Release foundation | §15.2, `VP-D09` |
| VP-14 Notifications | Category ownership, dedup with Creator-tier notifications, delivery, preferences | Release foundation | `S3-NOTIF-01` baseline, `VP-D11` |
| VP-15 Base IA and shell | Page hierarchy, section ordering, card density for §14 | Release foundation | None |
| VP-16 Pagination and performance budgets | Load-more/pagination, sort, counts/badges, skeleton states. **Release foundation** for the already-foundation libraries (Scenario, Quick Plan, Favorites/Saved Search/Smart Search history, Visit History) — an unpaginated release-foundation library is not actually done; inherits its dependency's own class (Gated expansion/blocked) for My participation and Follow, since paginating a surface that cannot ship yet is moot | Release foundation (baseline libraries) / follows dependency (participation, Follow) | VP-01–VP-05 baseline libraries |
| VP-17 Follow (blocked on joint decision) | `FollowRef` mechanism, follow/unfollow, follower/following lists, block interaction, new-follower notification — none of it may start implementation before `PP-D44`/`PCP-D02` resolve, and the final shape depends on `FOL-01`'s resolution of the `FollowRef`/`FollowRelation` mismatch | Mature extension | `VP-D12` AND `PP-D44` AND `PCP-D02`, all three, not `VP-D12` alone; final shape from `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`'s neutral `FOL-01` slice |
| VP-18 Saved Search/Smart Search retention | Size caps, retention window, prompt redaction/telemetry policy | Release foundation | `VP-D13` |
| VP-19 Account data export | Export format, field composition, delivery mechanism | Gated expansion | `VP-D14`, shares `VP-09`'s legal gate |
| VP-20 Session list and device revoke | Session listing, remote revoke, step-up re-authentication window | Release foundation | `VP-D15`, `VP-12` (`AccountStatus`) baseline |
| VP-21 Photos media safety | Malware/type/size checks, EXIF policy, alt text, takedown path | Gated expansion | `VP-D16`, shares `VP-08`'s media pipeline |

## 20. Acceptance criteria

### Surface boundary

- **VP-AC-01:** Opening Personal Profile never creates or implies a Public
  Creator Profile.
- **VP-AC-02:** No action defined in §5–§10 requires Creator verification or
  produces a `PublisherRef`; it MAY still require the owning aggregate's own
  eligibility/consent/rate-limit gate (§3.1).
- **VP-AC-03:** Scenario and Quick Plan remain two libraries with two empty
  states and two lists; they are never merged.
- **VP-AC-04:** Favorites, Saved Searches, Smart Search history, personal
  Scenario and Quick Plans remain independently listed; no combined
  aggregate or combined "clear all" spans more than one of them.

### Scenario and Quick Plan lifecycle

- **VP-AC-05:** An empty Scenario library shows a `Create Scenario` entry
  point routed to `Create Hub -> Scenario`; it never creates a parallel flow
  or collapses to nothing.
- **VP-AC-06:** All four `accessRole` values render in visibly distinct
  groups with distinct controls, matching `ScenarioAccessGrant`'s own
  capability table exactly; `editor` never exposes invite/access-management/
  owner controls, and `viewer`/`unlistedViewer` never expose edit controls.
- **VP-AC-07:** `Expand to Scenario` creates a new Scenario ID; the source
  Quick Plan remains unchanged and addressable by its own ID afterward, with
  no live/back-reference. Only a retry of the same idempotent command may
  return the already-created result.
- **VP-AC-08:** A stale/corrupt/revision-conflict Scenario shows an explicit
  recoverable state, never a silent disappearance.

### Visit History and activity

- **VP-AC-09:** A Visit History record is created only via explicit
  self-report with today-or-earlier date; no other action creates one.
- **VP-AC-10:** The same Place can carry multiple Visit History records on
  different days; each is independently deletable.
- **VP-AC-11:** My participation renders each state family from its own
  authoritative source via the tagged `ParticipationRef` projection (§4.2);
  it never introduces a second Booking status enum.

### Privacy and public projection

- **VP-AC-12:** Public User Projection contains at most display name,
  avatar and optional city; no §5–§10 library data.
- **VP-AC-13:** A Viewer who never verifies as Creator does not appear as a
  standalone searchable public profile.
- **VP-AC-14:** A deleted/tombstoned account's projection returns the same
  safe not-found response as a nonexistent account.
- **VP-AC-15:** Mute on a Viewer changes only the muting account's own view
  and never notifies the muted account; Block is bidirectional — it removes
  both accounts' ability to view each other's projection/card, follow each
  other, or initiate new contact.

### Reliability and account state

- **VP-AC-16:** A failed or partial load of one personal library does not
  degrade another library's presented state.
- **VP-AC-17:** A partial-load failure is never presented as an honest empty
  state, except Visit History's own Approved corrupt-storage-returns-empty
  behavior (§4.3(8)), which is preserved rather than silently overridden.
- **VP-AC-18:** Switching accounts on one device fully re-scopes every
  personal library and local cache key to the new `userId`.
- **VP-AC-19:** An expired session mid-edit fails closed on the next
  mutation without silently discarding a supported local draft.
- **VP-AC-20:** `LAUNCH_STATUS.md` records exact implementation evidence and
  remaining gates for each VP slice.

### `AccountStatus`, deep links and notifications

- **VP-AC-21:** `AccountStatus` has exactly five values
  (`active|securityLocked|suspended|deletionPending|tombstoned`), is
  client-unwritable, and its per-state action table (§15.1) is authoritative
  for both this document and `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`.
- **VP-AC-22:** A deep link into a §5–§10 item resolves via the full
  authorization chain (§17), never ownership alone; an invited participant
  with a valid, non-revoked grant resolves successfully.
- **VP-AC-23:** A notification event never produces two inbox entries across
  this document's categories and `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s
  Creator-tier categories (`VP-D11`).
- **VP-AC-24:** `securityLocked`, `suspended` and `deletionPending` block
  only *new* commitments; closing an already-existing My participation
  obligation (§8) remains *reachable* in all three, mirroring
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §5.4 and
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-73` — "reachable" here means
  not permanently blocked, not "without precondition": see `VP-AC-33`/`36`
  for the session-scoped `StepUpGrant` gate that still applies on top of
  this.

### Quality

- **VP-AC-25:** en/ru/lv-ready labels, 360 dp and 150% text scale are
  covered.
- **VP-AC-26:** Unit, widget and integration tests are proportional to each
  slice.
- **VP-AC-27:** `flutter analyze`, `flutter test`, boundary and diff checks
  pass for every implementation slice.

### Follow (conditional on the joint `PP-D44`/`PCP-D02` decision, §12.4)

- **VP-AC-28:** Follow does not ship in any form — production or local/mock
  presented as real — until the joint `PP-D44`/`PCP-D02` decision resolves;
  this document's own proposal (§12.4) is not, by itself, sufficient
  authorization to implement.
- **VP-AC-29:** *If* the joint decision adopts a Follow model, it is
  available to and from every account regardless of Creator verification,
  `AccountStatus` beyond `active`, or any content-publishing fact, unless
  the joint decision explicitly narrows that.
- **VP-AC-30:** *If* Follow ships, a Block immediately removes any existing
  `FollowRef` in both directions and prevents a new one while the Block
  stands; a Mute never affects `FollowRef`.
- **VP-AC-31:** *If* Follow ships, it is reachable only via an existing
  Public User Projection trigger surface or an opaque, revocable link — never
  a raw `userId`/handle-based link, and never a new standalone-
  discoverability surface.
- **VP-AC-32:** *If* Follow ships, a `tombstoned` account loses all
  `FollowRef` relationships at the point of tombstoning; restore within the
  retention window does not silently restore them.

### `AccountStatus` precedence and session security

- **VP-AC-33:** Closing an already-existing My participation obligation
  while `AccountStatus == securityLocked` requires a fresh, session-scoped
  `StepUpGrant{purpose: obligationClose}` for the acting session; no
  account-wide flag may substitute for a per-session grant.
- **VP-AC-34:** A security or moderation signal arriving while
  `deletionPending` transitions the account to `securityLocked`/`suspended`
  and pauses rather than discards the deletion request; resolving that
  signal returns the account to `deletionPending`, never silently to
  `active`.
- **VP-AC-35:** A restored (`tombstoned -> active`) account always resumes
  at `active`; any pre-tombstoning security lock or suspension are reset
  and re-evaluated fresh, and no `StepUpGrant` survives a restore, never
  silently carried over.
- **VP-AC-36:** `securityLocked -> deletionPending` requires its own fresh
  `StepUpGrant{purpose: deletionRequest}` for the requesting session — a
  request from a locked account is *rejected*, not merely flagged for
  later, without one. This is the acceptance criterion that closes the
  exploit a review confirmed was possible in a prior revision: requesting
  deletion from `securityLocked` was previously ungated, letting a
  hijacked session with no obligations to close ride the account to
  `tombstoned` without ever proving anything.
- **VP-AC-37:** A `StepUpGrant` authorizes exactly one `sessionId` for
  exactly one `purpose`; completing step-up on one session never grants,
  extends, or implies a grant for any other session on the same account.
- **VP-AC-38:** `securityLocked -> active` (self-service unlock) revokes
  every other active session's token as a mandatory, atomic part of the
  same transition — never a separate, skippable follow-up step.

### Decision defaults

- **VP-AC-39:** A slice MAY begin *preparing its own bounded slice spec*
  against its decision's §22 "Recommended default" before that decision
  reaches `Accepted` — never runtime implementation directly from this
  Draft document, which §0 already requires an Approved bounded slice
  spec for regardless of any default's existence (§22's own framing note
  restates this explicitly). Using a default never changes the decision's
  own `Status` in §22.1, and a category (a)/(b) decision (`VP-D04`,
  `VP-D08`, `VP-D10`, `VP-D12` — blocked or no-default) MUST NOT be
  treated as having an implicit default just because other decisions in
  the same list do.

### Personal planning power short of publication

- **VP-AC-40:** `private -> unlisted` on an owned Scenario requires only
  `Viewer` plus the `share_unlisted` capability; it is never gated on
  Creator verification. `private|unlisted -> public` is the Create Hub
  publish action and requires `VerifiedCreatorIdentity`; it is never
  reachable through the same control as `unlisted` sharing.
- **VP-AC-41:** No planning action this document defines — create, edit,
  duplicate, archive, invite a collaborator, share an unlisted link — is
  gated on Creator verification for any reason, including by association
  with the one action (`public`/Discover publish) that genuinely is.
- **VP-AC-42:** Inviting a known person into an owned Scenario/Quick Plan
  and publishing a `find_people` request never share an entry point,
  capability check, or data model; a non-Creator account can do the
  former and respond to the latter, but cannot do the latter itself.
- **VP-AC-43:** For an account with an `IdentityFieldModerationOverlay`
  row, the baseline Public User Projection's `displayName`/`avatar` are
  read from that overlay's `lastApprovedPublicValue`, never from
  `UserProfile` directly, on every trigger surface (§12.2); for an account
  with no overlay row, `UserProfile` remains the direct source.

## 21. Required test matrix

At minimum, implementation slices cover:

- zero/one/many Scenario, split by template/dated and by all four
  `accessRole` values, including proof that `editor` cannot invite, manage
  access, rename, archive, delete or publish, and that `viewer`/
  `unlistedViewer` cannot edit content;
- a non-Creator (`notStarted`) Viewer setting an owned Scenario to
  `unlisted` succeeds without any verification prompt; the same account
  attempting `public` is redirected to Creator verification rather than
  the visibility change silently succeeding or silently failing
  (`VP-AC-40`, `41`);
- a non-Creator Viewer inviting a known person by `userId`/email into an
  owned Scenario or Quick Plan succeeds; the same account attempting to
  publish a `find_people` request is redirected to Creator verification;
  the same account responding to another account's already-published
  `find_people` request succeeds without a verification prompt
  (`VP-AC-42`);
- a `VerifiedCreatorIdentity` account with a pending (`queued`)
  identity-affecting `displayName`/`avatar` edit shows the same
  last-approved value on this document's baseline Public User Projection
  (Review, Find People response, invited Scenario, shared plan) and on
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s extended card — never the
  queued value on one and the approved value on the other; the same account
  with no overlay row shows its live `UserProfile` value immediately on
  both (`VP-AC-43`);
- zero/one/many Quick Plan, and expansion producing a verifiably new
  Scenario ID distinct from the source Quick Plan; same-command retry returns
  the same result while a later explicit Expand may create a new independent
  copy;
- Favorites/Saved Search/Smart Search history remaining independently
  listed under concurrent mutation;
- Visit History: future-date rejection, same-place-multiple-days,
  individual deletion, idempotent same-day re-mark, and corrupt-storage
  returning empty per its own Approved contract;
- one library failing to load while siblings remain in their own correct
  state (loading/ready/empty), not cascading to a global error;
- account switch on one device leaving no residual cache from the previous
  account in any §5–§10 library;
- session expiry mid-edit on a Scenario rename/Visit deletion, confirming
  fail-closed on the next write and preservation of any supported local
  draft;
- Public User Projection field set under snapshot testing, confirming no
  §5–§10 field leaks;
- deleted-account deep link returning the same response as a nonexistent
  account;
- Mute affecting only the muting account's own reads and never notifying
  the muted account; Block affecting both accounts' mutual visibility
  (neither can view the other's card/projection, follow, or contact),
  verified from a third account's unaffected view;
- all five `AccountStatus` values against the §15.1 action table, including
  every transition and the one intentionally out-of-scope `suspended ->
  tombstoned` moderation escalation;
- an account in `securityLocked`/`suspended`/`deletionPending` with an active
  My participation obligation confirming the obligation can still be closed
  (e.g. Booking cancelled) while a *new* commitment attempt in the same
  state is rejected (`VP-AC-24`);
- obligation-closing attempted while `securityLocked` without step-up
  re-authentication is rejected; the same attempt succeeds after step-up;
  the same action while merely `suspended` (with no prior lock) succeeds
  without step-up (`VP-AC-33`);
- **the exact exploit path a review confirmed was possible in a prior
  revision, now closed at its source:** a session on an account in
  `securityLocked`, with no `StepUpGrant{purpose: deletionRequest}` for
  that session, attempts to request account deletion — the request
  itself is rejected, the account never reaches `deletionPending` at all
  (`VP-AC-36`); the same request from the same session succeeds only
  after that session completes a fresh purpose-scoped step-up challenge;
- a `StepUpGrant` completed on session A is confirmed to grant nothing to
  a concurrently active session B on the same account — B still cannot
  close an obligation or request deletion without completing its own
  fresh grant (`VP-AC-37`);
- `securityLocked -> active` unlock is confirmed to revoke every other
  active session's token as part of the same transition, verified by a
  previously-valid session token failing immediately after unlock
  completes (`VP-AC-38`);
- a security/moderation signal delivered while `deletionPending` moves the
  account to `securityLocked`/`suspended` and preserves the original
  deletion request; resolving the signal returns the account to
  `deletionPending`, not `active` (`VP-AC-34`);
- a `tombstoned` account that previously carried a `suspended` status,
  restored within the retention window, resumes at `active` with the prior
  suspension re-evaluated rather than silently reapplied or dropped
  (`VP-AC-35`);
- a deep link resolved for an invited (non-owner) participant with a valid
  grant, and rejected after that grant is revoked;
- a notification event asserted to produce exactly one inbox entry across
  Viewer and Creator notification categories;
- *(deferred until `PP-D44`/`PCP-D02` resolve, §12.4)* Follow between two
  plain (non-Creator) accounts succeeds without approval; Follow removed on
  Block in both directions and unaffected by Mute; Follow attempted against
  a blocking account rejected; `tombstoned` account's Follow relationships
  cleared and not silently restored on restore; follower/following count
  reflects the owner's visibility preference; Follow link resolution uses
  an opaque token, never a raw `userId`;
- localization, accessibility, compact layout and deep links for every
  §5–§10 destination.

## 22. Decisions required before implementation

**Reading this list for implementation planning, not just Approval
tracking.** `Open` does not uniformly mean "nothing here yet." Three
different situations are collapsed into that one word across this list,
and treating them the same would either block work that doesn't need to be
blocked, or ship something that genuinely shouldn't ship without a real
decision:

```text
(a) Genuinely blocked on something external this document cannot supply —
    an unbuilt backend (VP-D04), or a joint cross-document resolution
    (VP-D12). No default helps; the dependency has to clear first.

(b) A real product/legal/safety judgment call, where a rushed default
    would be irresponsible regardless of how low-risk it looks — consent,
    minors, person-as-review-subject (VP-D08, VP-D10). These stay open on
    purpose and are not given a default here.

(c) A parameter or UX-flow choice with no legal/safety stakes, where any
    of several reasonable answers is fine to start building against and
    revise later without rework risk. These get an explicit "Recommended
    default (not Approved)" below — a concrete, engineerable starting
    point, not a claim that product ownership has signed off on it.
```

A slice MAY begin drafting its own bounded slice spec against a category
(c) default per `VP-AC-39` (§20) — never runtime implementation directly
from this document, which remains subject to §0's Approved-slice-spec gate
regardless of any default's existence. Using a default does not move that
decision's own `Status` in §22.1 past `Open`, and a later Approved answer
that differs from the default requires the same migration discipline as
any other spec change — a default is a starting point for engineering to
plan against, not a substitute for product ownership actually deciding, or
for the bounded slice spec §0 already requires before code is written.

1. **VP-D01 — Scenario rename/copy/duplicate/archive/delete UX:** exact
   commands and confirmation flows in Profile. Blank creation location is not
   open: `Create Scenario` routes to `Create Hub -> Scenario` per the accepted
   Scenario/Quick Plan boundary.
   **Recommended default (not Approved):** rename — inline text field,
   commit on blur/Enter, no confirmation (non-destructive, instantly
   reversible); duplicate — single tap, creates an independent `owner`
   copy titled "<name> (copy)", no confirmation; archive — single tap,
   undo snackbar, no confirmation dialog (reversible, per §5.2's Archived
   view); delete — requires an explicit confirmation dialog naming the
   Scenario, because it enters the retention-window soft-delete state
   (§24.1) rather than being instantly reversible like the other three.
2. **VP-D02 — Quick Plan collaboration domain contract** (Quick Plan only —
   Scenario's own collaboration is Approved via `ScenarioAccessGrant`,
   `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10, and is out of scope for this
   decision, §5.1): whether Quick Plan ever gets an `editor`-equivalent
   tier beyond `owned | invited`; invitation lifecycle
   (`pending|accepted|declined|revoked|expired`); who sees the participant
   list; leave
   versus revoke; what happens to a Quick Plan when its owner's account is
   deleted or tombstoned (§15.1); copy, notification and private-notes
   rights per participant; interaction with block/mute (§12.3); maximum
   participant count; audit trail. Ownership of the resulting contract —
   this document, `SCENARIO_BUILDER_SPEC.md`, or a new dedicated spec — is
   itself part of this decision, not pre-assigned.
   **Partial recommended default only (not Approved) — this resolves two
   of the nine open sub-questions above, not the contract as a whole:** no
   `editor`-equivalent tier for now — keep exactly `owned | invited`,
   matching what already runs today (§0.2), so the default is "change
   nothing" rather than a new invented behavior; invitation lifecycle
   mirrors `TeamInvitation`'s own accepted shape
   (`pending|accepted|declined|revoked|expired`,
   `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §22.1) rather than a new
   vocabulary. **Left genuinely open, no default proposed:** participant-
   list visibility, leave-versus-revoke semantics, owner-account-deletion
   interaction, copy/notification/private-notes rights, block/mute
   interaction, participant cap, audit trail, and contract ownership
   itself — a slice picking this decision up still needs product input on
   these before it is a complete engineering contract, not only a UI
   layout task.
3. **VP-D03 — Saved decomposition IA:** whether the three Saved libraries
   (§6) get three separate top-level entry points or one entry point with
   three internally distinct tabs that never share a delete action.
   **Recommended default (not Approved):** three separate top-level entry
   points — simpler mental model, and directly matches §6's own "Saved is
   several libraries, not one" framing rather than reintroducing a shared
   container at the navigation layer that the rest of this document argues
   against.
4. **VP-D04 — My participation source contract:** exact read-projection
   shape once ADR 0019's Booking backend is live; ownership sits with that
   backend's own slice. **No default proposed — category (a):** the backend
   this projection reads from does not exist yet; a default read-projection
   shape would be guessing at an unbuilt contract, not a low-risk parameter
   choice. `VP-06`'s implementation genuinely waits on `EVENT_CLASSIFICATION_
   ECL_03_SLICE_SPEC.md` activation, not on this document.
5. **VP-D05 — Photos pipeline:** authorship/license confirmation, per-photo
   visibility default, EXIF/location stripping, orphan cleanup (mirrors
   `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-D07`).
   **Recommended default (not Approved) — this decision's own listed
   "per-photo visibility default" question is already answered elsewhere
   in this document, not left open here:** `PhotoAssetRef.visibility`
   (§4.2) is `private` only in the current target schema, and §12.1's
   table states the same default — this decision does not need to
   re-decide that, only note it is already settled by construction, not
   by this default. What this default actually adds: license/authorship
   confirmation required at upload (checkbox, non-bypassable); EXIF/
   location stripping **mandatory**, not configurable (`VP-D16` restates
   this so the two decisions do not drift independently); orphan cleanup
   via an async job triggered by the linked Visit/content item's own
   deletion, not a synchronous blocking delete.
6. **VP-D06 — Account deletion and retention** (widened): exact retention
   window and disposition of §5–§10 libraries during it, **plus** the
   sole-Professional-Page-owner precondition
   `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.4/`CP-AC-19` already adds on top
   of this document's own mechanics — a deletion request MUST fail closed
   while the account is the sole owner of an active Professional Page with
   active Booking/payment/legal obligations, until ownership transfers or
   the page is archived. This document does not re-derive Professional
   Page's own payout/legal-hold mechanics; it only guarantees the deletion
   flow checks that precondition before proceeding (§24.4).
   **Recommended default, explicitly subject to legal sign-off (category
   (c) engineering-wise, but the window value itself is not this
   document's to finalize) — and only a partial default, not a claim that
   every library's retention is actually the same:** a 30-day retention
   window, matching the already-Approved precedent
   `SCENARIO_BUILDER_SPEC.md` §"Владение, видимость и результат" sets for
   Scenario's own soft-delete, as the baseline for libraries this
   document itself owns end-to-end (Scenario, Quick Plan, Favorites,
   Saved Searches, Smart Search history, Visit History, Photos where
   `VP-D16` doesn't override it). **Explicitly not resolved by this
   default:** Reviews-authored may need independent retention driven by
   the canonical Review contract's own moderation/audit requirements once
   approved, and My participation's underlying Booking/legal records may
   need to outlive the 30-day window regardless of this account's own
   deletion, per whatever ADR 0019's own retention rules turn out to be —
   this default governs only what this document's own libraries do,
   never a claim that it overrides another aggregate's independent legal
   retention obligation. Within the libraries it does cover: soft-delete
   together, restore or purge together at window's end, never a
   per-library partial restore that leaves an account "back" with some
   libraries missing.
7. **VP-D07 — Public User Projection remaining open questions** (narrowed):
   city precision and home-location protection, pseudonym versus
   `displayName`, and projection display when the review's author account is
   later deleted. Additional trigger surfaces beyond the four §12.2 already
   accepts (Review, Find People, invited Scenario, shared plan). Resolved by
   this revision and no longer open: minors (now `VP-D10`, distinct from
   `CP-D14`) and suspended/security-locked display (now §15.1).
   **Recommended default (not Approved):** city precision — city-level
   only, never coordinates or neighborhood-level granularity, matching
   §12.1's own `about`/`city` handling; no pseudonym support in v1 — show
   real `displayName` only, simpler and avoids a second identity surface to
   moderate; a deleted author's past reviews show a stable "Deleted user"
   placeholder rather than disappearing or reassigning. **No sibling
   precedent to cite for the opaque-link token itself, corrected from an
   earlier draft's mischaracterization:** that draft claimed the token was
   "structurally identical" to `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
   `PP-D17` — checked directly, `PP-D17` governs page `slug` permanence
   and anti-enumeration redirect behavior, not bearer/recipient-bound
   token issuance, and is not a template for this mechanism.
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `PCP-D10` is the actually
   adjacent concept (an opaque token for `unlisted` card resolution) but
   is itself `Open`, not an accepted pattern this decision may borrow as
   settled. The property this default commits to — signed, short-lived,
   revocable, never a raw `userId` or predictable handle — stands on its
   own merits without a false "matches an existing mechanism" claim; the
   exact token format remains this decision's own open engineering
   question, not resolved by analogy.
8. **VP-D08 — Reviews about a person:** whether Recharge ever supports a
   Review whose subject is a Viewer rather than content, and if so its
   eligibility, consent and moderation model. **No default proposed —
   category (b):** this is a harassment/consent-risk product decision (an
   unwanted review of a person, not their work, is a materially different
   harm than an unwanted review of an Event), not a UX parameter; a
   default here would be exactly the kind of premature product decision
   this document has repeatedly corrected itself for making elsewhere.
   Deliberately unresolved.
9. **VP-D09 — Multi-device conflict per library:** exact precondition and
   recovery UX for each owning contract. One shared per-account revision
   counter is excluded because it would couple independent aggregates and
   violate §4.2; each source owns its revision/idempotency semantics.
   **Recommended default (not Approved), per library category — not one
   universal rule applied verbatim everywhere:** an earlier draft proposed
   reusing `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.3's Approved
   conflict UX for every §5–§10 library uniformly; that does not actually
   fit libraries with no forkable "content" to save a copy of. Corrected
   to three category defaults instead of one:
   - **Editable-content libraries** (Quick Plan, once its own contract
     exists) — reuse §10.3's full pattern (`Use latest` / `Reapply mine`
     / `Save conflict copy`, LWW-with-warning), the same reasoning as
     Scenario itself: there is real authored content to fork;
   - **Add/remove-set libraries** (Favorites, Reviews-authored, Photos) —
     a simpler set-membership merge: a conflicting add/remove on the same
     item resolves by the more recent action winning (LWW on the
     membership fact itself), with no "conflict copy" concept, because
     there is no content to fork, only presence or absence;
   - **Read-only/derived libraries** (My participation, Visit History's
     own authoritative-source fields) — no client-side conflict exists to
     resolve at all; the authoritative backend (ADR 0019 for Booking,
     `VIS-HIST-01` for Visit History) is the sole source of truth and the
     client simply re-reads it, consistent with §4.3(7)'s own invariant
     that this document never becomes a second source of truth for those
     families.
10. **VP-D10 — Minors' baseline Public User Projection:** this document's own
    decision, distinct from `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-D14`
    (whether a minor may become a *verified Creator*). Even an account that
    never seeks verification still has a baseline Public User Projection
    (§12.2); this decision covers whether/how that baseline differs for a
    known-minor account — display name versus pseudonym, avatar/city
    exposure, Find People participation, Scenario invitability, guardian
    consent, and escalation on block/report. **No default proposed —
    category (b):** child-safety decisions do not get a low-risk
    engineering shortcut; until resolved, the fail-closed floor already
    stated in §12.3 (extended card and every optional exposure withheld
    for a known-minor account) is the only "default" this document offers,
    and it is a safety floor, not a UX recommendation to build the full
    feature against.
11. **VP-D11 — Notification category ownership and dedup:** the exact
    boundary and deduplication mechanism between this document's personal
    notification categories (§16) and `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
    §22.5's Creator-tier categories, so the same underlying event never
    produces two inbox entries. Also covers: mandatory-versus-optional
    security notifications, channel (in-app/push/email), per-object versus
    global preference, quiet hours/digest, and read-state sync across
    devices. `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.5 already expects this
    document to own this decision; prior to this revision it did not exist.
    **Recommended default (not Approved):** dedup key =
    `(recipientUserId, sourceEventId)` — deliberately **not**
    `(eventId, category)`, corrected from an earlier draft that used the
    latter: if this document's personal categories (§16) and
    `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.5's Creator-tier categories
    ever classify the same underlying event differently (plausible by
    construction — they are independently defined vocabularies over
    events that can overlap), an `(eventId, category)` key produces two
    different keys for one event and fails to dedup at all, defeating the
    entire purpose of having a key. Keying on the recipient and the
    producing event's own ID, independent of which surface's category
    vocabulary classified it, is what actually prevents the two-inbox-
    entries outcome `VP-AC-23` requires. Otherwise unchanged:
    last-write-wins on read state, in-app delivery only until `VP-D15`'s
    session/device infrastructure exists to support push targeting
    sanely; security notifications (verification loss, `AccountStatus`
    transition) are mandatory and non-mutable by the preferences UI,
    every other category is owner-toggleable.
12. **VP-D12 — this document's half of the joint Follow decision**
    (`PP-D44`/`PCP-D02`, §12.4): whether Recharge adopts this document's
    proposed universal, no-approval, Creator-status-independent Follow
    model as-is, modifies it, or rejects it in favor of separate
    person/page relationship models; **which of the two incompatible data
    shapes wins — this document's person-only `FollowRef` or `PP-D44`'s
    discriminated `target: {type: user | page, id}` `FollowRelation`, a
    mismatch `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` has confirmed and
    tracks as the neutral `FOL-01` slice** (§12.4); an approval-gated
    ("private account") variant; exact follower/following list visibility
    to other accounts; the opaque-link resolution mechanism (`VP-D07`); and
    whether a minor account's baseline (`VP-D10`) further restricts who may
    follow them or be followed by them. Unlike every other decision in this
    list, `VP-D12` cannot be resolved by this document alone — `PROFESSIONAL_PAGE_
    FUNCTIONAL_SPEC.md` §0's conflict rule requires a joint resolution with
    `PP-D44` and `PCP-D02` before any part of it, including the base
    universal-reach question, may be treated as accepted.
13. **VP-D13 — Saved Search / Smart Search history retention and cleanup**
    (§6): maximum history size, retention window, whether a raw prompt
    string is ever redacted or excluded from telemetry, cross-device merge
    behavior, and handling of a stale presentation snapshot whose target
    object was deleted or moderated. Previously listed only as informal
    "future work" with no owning decision; that omission is itself a
    governance gap this revision closes by giving it an ID, not by
    resolving it.
    **Recommended default (not Approved), split by library — not one cap
    for both, corrected from an earlier draft that applied a single
    eviction/TTL rule to both:** `SavedSearchRef` and
    `SmartSearchHistoryRef` (§4.2) are different libraries for exactly the
    reason §6 already states — one is a deliberately-kept object the
    owner chose to save, the other is a passive log of what was searched.
    Applying one automatic-eviction rule to both would silently delete a
    Saved Search the owner explicitly kept, which is a data-loss defect,
    not a retention policy.
    - **Smart Search history** (passive log): cap at 50 entries (oldest
      evicted first), 90-day rolling retention, raw prompt text excluded
      from analytics/telemetry by default (privacy-conservative — a
      search prompt is closer to a query log than a display field).
    - **Saved Searches** (explicitly kept by the owner): **no automatic
      eviction or expiry at all** — removed only by the owner's own
      explicit delete action, exactly like Favorites (§6). If a volume
      cap is ever needed, it is a distinct, separately-decided quota flow
      with its own UX (matching how `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
      handles its own ownership quota, §5.1 there) — never silent
      background deletion of something the owner chose to keep.
    - A stale snapshot whose target was deleted/moderated renders a
      "no longer available" row rather than being silently dropped, in
      both libraries, so the Viewer's own history/saved-list stays an
      honest record.
14. **VP-D14 — Account data export and format** (§16, `VP-D06`'s sibling):
    exact export format and field composition, preparation/download-link
    lifetime, which other accounts' data is excluded from an export (e.g.
    a co-participant's private details in a shared Scenario), and
    interaction with an active legal hold.
    **Recommended default (not Approved), and one claim from an earlier
    draft corrected as actively unsafe, not merely imprecise:** that draft
    said owner-scoping the export query means "no separate redaction pass
    is needed for co-participant data." That is false and should not be
    built against: `ownerId/viewerUserId = self` scoping controls which
    *rows* (which Scenarios, which Bookings) are exported, not which
    *fields inside* each exported row are safe to include. A Scenario the
    Viewer owns can still embed another participant's `accessRole`
    identity, an invited Quick Plan can list co-participant identities, a
    Booking can carry an organizer's or venue's contact details — all
    correctly present in the *app's own read model* for that owned row,
    none of them safe to hand to the owner as a raw file. The corrected
    default: JSON, one file per §5–§10 library, generated async and
    delivered via a signed download link valid 48 hours; **each library
    requires its own explicit export-projection allowlist** (fields safe
    to include verbatim) rather than exporting its normal read model
    unmodified — Scenario's export includes other participants' Public
    User Projection fields only (§12.2's own field set), never their
    private contact/session data; My participation's export includes the
    Viewer's own Booking fields, never an organizer's private management
    data. Building the allowlist per library is real, non-trivial slice
    work this default does not shortcut. Blocked entirely (not partially
    redacted) while a legal hold is active on the account.
15. **VP-D15 — Session list, re-authentication and remote device revoke**
    (§15.2): whether concurrent sessions are ever listed to the owner and
    individually revocable, the step-up re-authentication window `VP-AC-33`
    already requires for one specific action, and what a remote revoke does
    to an in-flight local draft on the revoked device.
    **Recommended default, flagged for security review before a slice
    builds against it — not a plain category (c) parameter choice.**
    Unlike most defaults in this list, this one shapes the account-
    takeover-recovery surface itself (§15.1's `StepUpGrant`), so the
    tracking table's own gate ("Security review of re-authentication
    design," §22.1) applies to the default too, not only to the eventual
    Approved answer: sessions listed with device/platform, approximate
    location and last-active time; revoke is immediate token invalidation,
    not a soft flag; a `StepUpGrant.expiresAtUtc` of 15 minutes after
    successful re-auth, a common industry figure rather than one invented
    here; a revoked device's in-flight local draft is preserved locally
    but can no longer sync until that device re-authenticates — never
    silently discarded, per §15.2's existing expired-session principle;
    the human-support-verified recovery path §15.1 requires for a
    genuinely locked-out true owner is explicitly this decision's own
    open sub-question, not answered by the default above.
16. **VP-D16 — Photos media safety** (§10): malware/file-type/size/
    dimension checks before accepting an upload, whether EXIF/location
    stripping is a mandatory acceptance criterion or a configurable policy,
    alt-text requirements, duplicate detection, and the takedown path for a
    reported or infringing Photo.
    **Recommended default (not Approved), with concrete thresholds — an
    earlier draft named categories without numbers, which is not an
    actionable default:** allowlist JPEG/PNG/WebP/HEIC only; 20 MB
    per-file cap; 8000×8000 px maximum dimension (reject, don't silently
    downscale, so the owner knows their upload was rejected rather than
    silently altered); EXIF/location stripping mandatory, not
    configurable — settling `VP-D05`'s open question in the privacy-safe
    direction rather than leaving both decisions to drift independently;
    alt-text optional at upload, not blocking; duplicate detection via
    content hash, not perceptual matching, as the low-complexity first
    pass; report/takedown reuses the same audited flow §12.3 already
    defines for account-level report, scoped to one Photo. **Upload flow
    requires a quarantine stage, not "scan before storage" as a single
    step** — a file cannot be scanned before it exists somewhere to scan,
    and "storage" is ambiguous between a private staging area and the
    servable location: the corrected flow is upload to a private
    quarantine store (not linkable, not servable) → async malware scan →
    on pass, move to the servable store and only then attach to
    `PhotoAssetRef`; on fail, delete from quarantine and surface a
    rejection to the owner. No `PhotoAssetRef` is ever created for a file
    that has not cleared quarantine.

None of `VP-D13`–`VP-D16` may be silently treated as resolved by omission —
§23's Definition of Done requires each to be either accepted or explicitly
deferred with an owner and gate (§22.1), exactly like `VP-D01`–`VP-D12`.

### 22.1 Decision tracking

`Status` uses §22's three categories so this table can be read for
implementation planning, not only Approval bookkeeping: **Open — default
proposed** (category c: a slice may start against the recommended default
today), **Open — no default (product/legal)** (category b: genuinely
waits on a human decision, not engineering), **Open — blocked** (category
a: waits on an external dependency or a joint cross-document resolution).

| Decision | Status | Target slice (§19) | Owner | Gate |
|---|---|---|---|---|
| VP-D01 | Open — default proposed | VP-01 | TBD | — |
| VP-D02 | Open — partial default (2 of 9 sub-questions) | VP-02 | TBD | — |
| VP-D03 | Open — default proposed | VP-03 | TBD | — |
| VP-D04 | Open — blocked | VP-06 | TBD | ADR 0019 backend readiness |
| VP-D05 | Open — default proposed | VP-08 | TBD | — |
| VP-D06 | Open — partial default (window pending legal; other-aggregate retention not covered) | VP-09 | TBD | Legal/privacy sign-off; `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-AC-19 |
| VP-D07 | Open — default proposed | VP-10 | TBD | — |
| VP-D08 | Open — no default (product/legal) | Not yet in roadmap | TBD | — |
| VP-D09 | Open — default proposed | VP-13 | TBD | — |
| VP-D10 | Open — no default (child-safety) | Not yet in roadmap | TBD | Distinct from `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-D14 |
| VP-D11 | Open — default proposed | VP-14 | TBD | — |
| VP-D12 | Open — blocked | VP-17 | TBD | Joint resolution with `PP-D44` and `PCP-D02` required — see §12.4 |
| VP-D13 | Open — default proposed | VP-18 | TBD | — |
| VP-D14 | Open — default proposed | VP-19 | TBD | Legal/privacy sign-off, shares `VP-D06`'s gate |
| VP-D15 | Open — default proposed, security review required before use | VP-20 | TBD | Security review of re-authentication design |
| VP-D16 | Open — default proposed | VP-21 | TBD | Shares `VP-08`'s media-pipeline dependency |

## 23. Definition of Done

This document may become **Approved** only after `VP-D01`–`VP-D16` are
either accepted or explicitly deferred with owners and gates (§22.1). That
gate is unchanged by §22's "Recommended default" additions — a default is
a starting point for *drafting the Approved bounded slice spec §0 already
requires* (`VP-AC-39`), never a substitute for either that gate or this
one, and no amount of slices shipped against category (c) defaults moves
this document closer to `Approved` on its own. What the defaults do
change is narrower and practical: twelve of sixteen decisions (§22.1) no
longer need a product meeting before a team can start drafting the
matching roadmap slice's own spec — only `VP-D04`, `VP-D08`, `VP-D10` and
`VP-D12` remain genuine blockers (an unbuilt backend, two product/legal
judgment calls, and one joint cross-document decision, respectively), and
only `VP-17` (Follow) among the twenty-one roadmap slices depends on the
one that is cross-document. Several of the twelve defaults are
**partial** — they resolve some but not all of their decision's open
questions (§22 marks each one honestly; `VP-D02`, `VP-D05`, `VP-D06`,
`VP-D09`, `VP-D15` and `VP-D16` in particular still leave real sub-questions
for the slice spec itself to close, not this document).

Viewer Profile is production Done only when:

1. Scenario supports its full four-role `accessRole` lifecycle per
   `ScenarioAccessGrant` (§5.2), and Quick Plan supports its full §5.3
   lifecycle including the resolved `VP-D02` (Quick-Plan-only)
   collaboration contract;
2. the three Saved libraries (§6) remain independently manageable;
3. Visit History exposes its full filter/sort surface, not only a preview;
4. a partial load of any one personal library never degrades the others,
   with Visit History's own Approved exception preserved;
5. Public User Projection excludes every private library by construction,
   verified by a snapshot test;
6. the `AccountStatus` contract (§15.1), including its precedence rules and
   `securityLocked` step-up requirement, is authoritative and matches what
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` assumes;
7. deep-link authorization uses the full grant chain, not ownership alone;
8. **no Follow implementation ships, in production or as a local/mock
   fixture presented as real, before the joint `PP-D44`/`PCP-D02`/`VP-D12`
   decision resolves (§12.4)** — this document being internally Done never
   by itself authorizes Follow;
9. the selected release modules meet their own acceptance criteria (§20);
10. analyzer, tests, boundary and diff gates are green;
11. `LAUNCH_STATUS.md` records the exact evidence;
12. no local/mock fixture or UI preview is represented as production
    authority.

## 24. Viewer Profile lifecycle as a personal object

### 24.1 Scenario and Quick Plan state transitions

- A dated personal Scenario's `temporalState` (`upcoming | inProgress | past`)
  is computed, never a persisted lifecycle field
  (`SCENARIO_BUILDER_SPEC.md` §5, "Владение, видимость и результат"); Profile
  MUST recompute it on
  each load rather than caching a stale bucket. A template has no temporal
  state and renders in a separate group.
- Archiving a Scenario removes it from the active list but keeps it in an
  Archived view and addressable by ID. Explicit delete enters the canonical
  soft-deleted/tombstoned retention state; Profile never presents immediate
  hard deletion.
- `Expand to Scenario` is one-directional and copy-based. Each explicit new
  Expand command may create a new independent private Scenario; a technical
  retry with the same idempotency key returns the same result. The source
  Quick Plan remains unchanged and carries no `expandedToScenarioId` or live
  link.
- What happens to a **Quick Plan** when its owner's account transitions
  through §15.1's `AccountStatus` states (in particular `tombstoned`) is
  `VP-D02`'s subject, not resolved here. For **Scenario**,
  `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.2 already establishes that an
  owner cannot be removed or demoted through the ordinary grant flow, but
  does not itself state what happens to a `ScenarioAccessGrant` when the
  owner's *account* (not just their grant) is tombstoned — that gap is
  cross-document and tracked here only for visibility, not resolved by
  either document yet.

### 24.2 Visit History record lifecycle

- A record is created, optionally has a linked Photo (§10, once VP-08
  exists), and is deleted individually — there is no edit-in-place beyond
  deletion and re-creation, per `VIS-HIST-01`'s idempotent
  owner+place+day contract.
- Deleting the underlying Place reference does not retroactively invalidate
  the historical record's own `id`/date/evidence fields; only the linked
  Place's own detail view becomes unavailable.
- Missing/corrupt local storage returns an empty history — `VIS-HIST-01`'s
  own Approved behavior (§4.3(8)) — rather than an explicit corrupt-state
  UI; that distinction, if ever introduced, is that spec's own future
  revision.

### 24.3 Concurrent editing

- Two active sessions editing the same record must not silently overwrite
  each other. Each owning aggregate applies its approved revision,
  idempotency or conditional-write contract; Viewer Profile introduces no
  shared cross-library revision. Exact recovery UX remains `VP-D09`.

### 24.4 Account deletion and retention

- Personal libraries (§5–§10) are never hard-deleted while the account has
  active My participation obligations (§8).
- Deletion is soft (`AccountStatus: tombstoned`, §15.1), with a retention
  window during which restore remains possible; disposition of each
  individual library during that window is `VP-D06`.
- **Sole Professional Page owner:** an account deletion request MUST fail
  closed while this account is the sole `ownerUserId` of **any Professional
  Page that is not `archived` or tombstoned** — deliberately not an
  enumerated lifecycle list. An earlier draft of this document enumerated
  `active|pendingReview|draft` and omitted `suspended`, which still has an
  accountable owner and obligations and MUST also block deletion; that gap
  is closed by naming the exclusion (`archived`/tombstoned) instead of the
  inclusion list, matching `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.4's own
  identical fix. The precondition also requires active Booking, payment or
  legal obligations (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-58`), or
  no completed ownership-transfer flow and no approved archive of that page
  — this is `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.4/`CP-AC-19`'s
  precondition, which this document's own deletion flow (`VP-D06`) MUST
  check before transitioning `AccountStatus` to `deletionPending`. The
  account MUST be offered, not silently blocked without a path: transfer
  ownership, or archive the page (subject to its own obligation checks),
  before deletion can proceed.
- Content the Viewer published as a Creator follows
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s own content-attribution rules
  (§9.3 there) — this document does not redefine that cascade, only
  confirms Viewer-only libraries follow the same soft-delete principle and
  that the sole-Page-owner precondition above gates entry into
  `deletionPending` in the first place.

### 24.5 Notification recipients and read state

- Personal notifications route only to the account owner.
- Read state is account-scoped and synchronized across every active
  session/device — never siloed to the one session or device that marked
  it read.
- `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.5 defines its own Creator-tier
  notification category as distinct from this document's personal
  categories (§16) and requires the two never duplicate the same underlying
  event into two inbox entries — the exact dedup mechanism is `VP-D11`,
  which did not exist before this revision.

### 24.6 Follow relationship lifecycle

- A `FollowRef` is created and removed only by explicit action of the
  follower, or as an automatic side effect of a block (§12.3, §12.4) — it
  is never created implicitly by viewing a profile, favoriting content, or
  any other passive activity (§1.1).
- Blocking either party removes the relationship in both directions
  immediately; unblocking does not restore it.
- Tombstoning an account (§15.1) clears its `FollowRef` relationships in
  both directions; restoring the account within the retention window
  restores the account's own libraries (§24.4) but not prior Follow
  relationships, which must be re-established explicitly.
- A Follow relationship carries no capability and no visibility grant
  beyond what §12.4 already defines — following an account never unlocks
  access to its private libraries (§5–§10).

## 25. Relationship to the sibling documents

This document intentionally reuses, rather than restates independently,
every invariant that does not depend on the personal-library/publishing/
public-card distinction: the access-state model (§3.1), the fail-closed
mutation principle, the `revision`-based concurrency rule and the Booking
honesty rules are the same contract across all three sibling documents by
design — a future implementation slice MUST NOT give them divergent
behavior per surface without an ADR.

Deliberate scope split, restated from the owning side:

- **This document** owns: Scenario's Profile-surface rendering of the
  Approved `ScenarioAccessGrant` roles (collaboration mechanics themselves
  are `SCENARIO_CONNECTED_PLANNING_SPEC.md`'s), Quick Plan (short of its
  still-undecided collaboration domain contract, `VP-D02`), Favorites,
  Saved Searches, Smart Search history, Visit History, My participation,
  Reviews-authored/received-as-subject, Photos, the `AccountStatus` axis
  (§15.1), Block/Mute mechanics (§12.3 — `PUBLIC_CREATOR_PROFILE_
  FUNCTIONAL_SPEC.md` §7.2 explicitly cedes this rather than establishing
  it), general session/multi-device state, the minimal Public User
  Projection (§12.2) every account has regardless of Creator status, and
  this document's own proposed half (§12.4) of the still-**open** joint
  Follow decision — not an accepted Follow contract.
- **`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`** owns: Creator verification
  (§5.2's `notStarted|pending|verified|rejected|expired|revoked` axis, which
  this document's §15.1 `AccountStatus` axis is explicitly independent of),
  the personal publisher context, Created-content management, and this
  account's relationship to any Professional Page it manages. It cites this
  document rather than redefining any of §5–§10, and this document's §11 is
  deliberately only a boundary stub for that reason.
- **`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`** owns: the public Creator
  card's field list, visibility/discoverability beyond this document's
  baseline (§3 there), the report/appeal moderation-submission flow, and
  the public-facing half of handle/deep-link resolution. It consumes but
  does not own Block/Mute mechanics — this document owns those (§12.3). It
  is a strict superset of this document's §12.2 and MUST NOT redefine the
  `AccountStatus` axis it reacts to. It owns reviews-about-content
  aggregation *display* independently of `VP-D08` — that gate applies only
  to reviews-about-a-person, a fact §9 of this document states explicitly
  precisely because an earlier draft of this document conflated the two.
  **Follow (§7 there, §12.4 here) is jointly owned, not owned by either
  document alone:** both sections are explicitly "illustrative direction
  only" / "proposed," and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D44`
  is the third input; none of the three documents may unilaterally declare
  a Follow model accepted (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §0's
  conflict rule). A prior revision of this document incorrectly declared
  its own proposal accepted — corrected in §12.4 and Appendix B.
- **`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`** owns everything
  `ManagedPage`-specific: Team, page lifecycle cascade, page-scoped Booking
  console, page transfer/merge mechanics, and the state-family separation
  table (§10.1) both other sibling documents reuse rather than restate.
  This document bridges to it only through §8's My participation and
  §24.4's sole-Page-owner deletion precondition.

Any future edit to a shared section in any of the three documents SHOULD
check whether the others need the same edit, and SHOULD record the check in
that document's own appendix even when no change was needed.

## Appendix A. Non-negotiable exclusions (index)

Mirrors `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s own exclusions index in
method — a non-normative reader index, not a new requirement.

| Viewer Profile MUST NOT | Established at |
|---|---|
| Require Creator verification for any personal-library action | §3.1, §11, `VP-AC-02` |
| Merge Scenario and Quick Plan into one library/lifecycle | §5.1, `VP-AC-03` |
| Merge Favorites, Saved Searches, Smart Search history, Scenario and Quick Plan into one "Saved" aggregate | §6, `VP-AC-04` |
| Auto-create Visit History from a view, Favorite, Booking, GPS or Scenario add | §7, `VP-AC-09` |
| Silently retype a Quick Plan into a Scenario without a new ID | §4.3(4), §5.3, `VP-AC-07` |
| Expose any §5–§10 library in a Public User Projection | §12.2, `VP-AC-12` |
| Make a Viewer standalone-searchable without Creator verification | §12.3, `VP-AC-13` |
| Let one library's load failure degrade another library's state | §4.3(8), §15.2, `VP-AC-16` |
| Present a partial-load failure as an honest empty state, other than Visit History's own Approved exception | §4.3(8), §15.2, `VP-AC-17` |
| Auto-create a Review-about-a-person from content publication | §9, `VP-D08` |
| Invent a Quick Plan `editor` role or invitation lifecycle without an accepted domain contract, or invent a Scenario role narrower/wider than `ScenarioAccessGrant`'s four | §5.1, `VP-D02`, `CP-AC-16` |
| Resolve a deep link to a §5–§10 item by ownership alone, ignoring a valid invited-participant grant | §17, `VP-AC-22` |
| Let this document's and Creator's notification categories duplicate one event into two inbox entries | §16, §24.5, `VP-D11`, `VP-AC-23` |
| Claim `S3_NOTIF_01_NOTIFICATIONS_SPEC.md` defines delivery, preferences or production filtering | §0.2, §16 |
| Let a deletion request proceed while this account is the sole owner of an active, obligated Professional Page | §24.4, `VP-D06` |
| Block closing an already-existing My participation obligation just because `AccountStatus` is `securityLocked`/`suspended`/`deletionPending` | §15.1, `VP-AC-24` |
| Ship any Follow implementation before the joint `PP-D44`/`PCP-D02` decision resolves, or present §12.4 as an accepted contract rather than a proposal | §12.4, `VP-AC-28` |
| Gate a shipped Follow on Creator verification, `AccountStatus` beyond `active`, or any content-publishing fact, unless the joint decision narrows it | §12.4, `VP-AC-29` |
| Let a shipped Follow become a new standalone-discoverability surface, or resolve it via a raw `userId`/handle link instead of an opaque token | §12.3, §12.4, `VP-AC-31` |
| Leave a `FollowRef` intact across a Block, or silently restore it on unblock | §12.3, §12.4, `VP-AC-30` |
| Treat Mute as bidirectional, or Block as affecting only the blocking account's own view | §12.3, `VP-AC-15` |
| Gate unlisted sharing, collaboration or any other planning action behind Creator verification, on the theory that publication needs it so everything adjacent might too | §5.2, §11, §4.3(14), `VP-AC-41` |
| Let `public` visibility be reachable through the same control as `unlisted`, or treat visibility as one uniform owner-editable enum instead of two differently-gated transitions | §5.2, §4.3(14), `VP-AC-40` |
| Present "invite a known person" and "publish a `find_people` request" as one feature, or route them through a shared entry point / capability check | §5.1, §11, §4.3(15), `VP-AC-42` |
| Read `displayName`/`avatar` directly from `UserProfile` for the baseline Public User Projection once an `IdentityFieldModerationOverlay` row exists for that account | §12.2, §4.3(16), `VP-AC-43` |

## Appendix B. Corrections from prior drafts

### From draft 1.16 to 1.17

Not a review round — a structural request: split the public-facing
identity projection out of §12 into its own file,
`PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.0, so it can be edited
quickly without touching the rest of this document's private-operations
content in the same diff. Directly mirrors a precedent already set inside
this same document family: `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.31
split its own public page projection out of §8.2 into
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v1.0 for the identical
reason, itself mirroring the original
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`/`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_
SPEC.md` split.

**What moved:** §12.1–12.4's descriptive content (visibility defaults, the
Public User Projection field set including the `CP-D20` identity-overlay
rule just adopted in v1.16, discoverability/blocking/deleted-account
handling, and the proposed Follow direction) now lives in the new sibling
document, re-anchored so every internal `§N` cross-reference either became
the sibling's own section number or was qualified with
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` where the target stayed here. Every
sentence that previously asserted ownership in the new document's own
voice ("this document is the sole authority...", "this document is the
sole owner of Block/Mute...") was rewritten to attribute that authority
explicitly back to `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`, since the new
document owns no decision of its own — the same discipline
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` used.

**What stayed, unmoved and unrenumbered:** `VP-D07`, `VP-D10`, `VP-D12`
(§22), every `VP-AC-*` (§20), the test matrix (§21), invariants 13 and 16
(§4.3), and the corresponding Appendix A rows all remain exactly where they
were — these are decisions and acceptance criteria, not descriptive prose,
and the established family convention (confirmed by checking exactly how
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.31 handled its own split) keeps
`*-D`/`*-AC` ownership with the parent document regardless of where the
descriptive text describing them lives. Their existing "§12.x" citations
still resolve correctly, since §12 remains a real heading — now a short
pointer instead of the full text.

**Other changes in this pass:** §0's sibling-count framing rewritten from
"three personal-identity + one `ManagedPage` peer, four documents" to
"three private/public pairs, six documents" (Viewer/Public Viewer,
Creator/Public Creator, Professional Page/Public Professional Page) —
the old framing had also gone stale independent of this split, since
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.31 had already added
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` without this document
noticing until this pass. §0's precedence-tier list (tier 5) and canonical
sources list gained both new public-facing documents. The "Compatible
with" header is refreshed to `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.31
(previously pinned at the stale v2.29) and gains the two new sibling
pins. `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s own framing text was not
touched by this change (out of scope for this pass) and is one document
behind reality until its own next revision — named explicitly here rather
than silently left stale. `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
`PROFILE_DOCUMENTS_INDEX.md` were updated in the same change (see their
own changelogs) specifically because their citations of the old §12.x
locations would otherwise have gone stale immediately.

### From draft 1.15 to 1.16

The user asked for another full review pass with instructions to fix only
genuinely radical/critical errors, not to manufacture findings. All three
sibling documents had advanced significantly since v1.15 was verified
(`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.5→v1.9,
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.4→v1.9,
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.18→v2.29), so this pass checked
every substantive cross-reference to this document across all three rather
than assuming low drift. Most held: `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
v2.29's own verified-against snapshot already targets this document's exact
v1.15 text, and the `FollowRef`/`FollowRelation` (`FOL-01`), Block/Mute,
and `AccountStatus` citations across all three siblings were re-checked and
still match this document's current text with no drift found.

**What was a real, three-document-confirmed gap, not a wording nit:**
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §16.1 defines
`IdentityFieldModerationOverlay` — the record that becomes authoritative
for a `VerifiedCreatorIdentity` account's `displayName`/`avatar` once a row
exists, so a pending or rejected identity-affecting edit does not show
inconsistently across surfaces. That document's own §16.1 states plainly it
"cannot unilaterally mandate `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s
implementation," and tracks the gap as its own `CP-D20`, explicitly gated
on this document's acceptance (§21.2/§22.1 there — "this document can state
and defer it, but cannot itself accept it").
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4 had already started reading
the overlay for its own extended card, while flagging in the same
paragraph that "whether the baseline projection this document extends does
the same is not yet settled" — meaning, until this document acted, a
Creator's pending identity edit could legitimately render differently on
this document's baseline Public User Projection (shown on a Review, a Find
People response, an invited Scenario, a shared plan, or a Follow) than on
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s extended card for the exact
same account at the exact same moment — a real display-consistency defect
with identity/trust stakes, not a documentation-only gap.

**What changed:** §12.2 gained an explicit adoption of `CP-D20` — the
baseline Public User Projection now reads `displayName`/`avatar` from
`IdentityFieldModerationOverlay.lastApprovedPublicValue` whenever a row
exists for the shown account, and continues reading `UserProfile` directly
when it does not (i.e. for every plain Viewer who has never been
`VerifiedCreatorIdentity` — the overwhelming majority of accounts, entirely
unaffected). New invariant 16 (§4.3) makes it a formal rule; `VP-AC-43` and
a matching test-matrix entry and Appendix A row give it the same
normative-form coverage this document's practice requires for a
consequential fix. This document deliberately adopts only the read-source
rule, not the overlay's still-open lifecycle mechanics
(`CP-D18` identity-affecting-change detection, `CP-D19` seeding/migration/
atomicity) — those remain `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s own open
decisions regardless of this adoption. The "Compatible with" header (§0)
is refreshed to the sibling versions actually checked in this pass.

### From draft 1.14 to 1.15

The user asked, after v1.14's visibility fix, what other similar
Creator-gate conflations might exist elsewhere in the document — an
explicit request to hunt for the same failure shape again, not a new
review round. One concrete, well-sourced instance was found and fixed.

**What was missing:** this document mentions "Find People" six times,
always only as a passive Public User Projection trigger surface, never
explaining what it actually is or how it relates to inviting a
collaborator into an owned Scenario/Quick Plan. `SCENARIO_BUILDER_SPEC.md`
already draws the line explicitly: "invited означает координацию с
известными людьми; открытый поиск незнакомых участников остаётся Find
People" (inviting means coordinating with known people; open search for
strangers stays Find People). `FIND_PEOPLE_CREATE_BLOCK_SPEC.md` —
previously not cited by this document at all — confirms `find_people` is
one of the ten canonical Create types, with the identical asymmetry v1.14
already established for Scenario visibility: "публиковать может
авторизованный Creator с capability" (publishing needs Creator) but
"Capability Creator для участия не требуется" (participating does not).

**What changed:** added `FIND_PEOPLE_CREATE_BLOCK_SPEC.md` to canonical
sources; §5.1 gained a dedicated explanation separating three previously
conflated-by-omission actions — inviting a known person (plain Viewer),
publishing a `find_people` request (Creator-gated, out of this document's
scope), and responding to one (plain Viewer, already correctly implied by
§12.2's "Find People response" wording but never stated as a rule); §11
restates the same boundary from the publishing-scope side; invariant 15
(§4.3) makes it a formal rule; `VP-AC-42` and a matching test-matrix entry
and Appendix A row complete the same normative-form coverage v1.14
established for the visibility asymmetry.

### From draft 1.13 to 1.14

Prompted by a user question about how personal Scenario/Quick Plan
copying, sharing-with-friends and publication actually work — not a
formal review round, but it surfaced a real, previously unstated
imprecision once checked against `SCENARIO_BUILDER_SPEC.md` §5 directly.

**What was imprecise:** §5.2 and §12.1 presented Scenario `visibility:
private | unlisted | public` as one owner-editable enum, distinguished
only by which value was currently set. Read literally, that invites the
conclusion that setting any of the three is the same kind of action —
which is false. `SCENARIO_BUILDER_SPEC.md` §5 defines `edit`,
`share_unlisted`, `publish`, `archive` and `delete` as *separately
gated* capabilities and states plainly that "Creator capability
требуется только для публикации в Discover" (Creator capability is
required only for publishing to Discover). `CREATOR_PROFILE_FUNCTIONAL_
SPEC.md` §9.1's four-stage table independently confirms the same split:
"Prepare local draft" (what a private/unlisted personal Scenario is, end
to end) needs "Authenticated Viewer only," while "Publish directly"
needs "Verified Creator."

**What changed:** §5.2 gained a dedicated explanation of the asymmetry —
`private -> unlisted` is a plain-Viewer action (`share_unlisted`
capability); `private|unlisted -> public` *is* the Create Hub publish
action and requires `VerifiedCreatorIdentity`, not a third visibility
value reachable the same way as the second. §11 gained an explicit
statement of the resulting product shape: a plain Viewer's personal-
planning power (create, edit, duplicate, archive, invite collaborators,
share an unlisted link) is complete and identical to a Creator's, short
of the one action — public/Discover publication — that a Creator
uniquely has. §12.1's table row, invariant 14 (§4.3), `VP-AC-40`/`41`,
a new test-matrix entry and two Appendix A rows all restate the same
fact in their respective normative forms, consistent with this
document's practice of not leaving a single-location fix for a rule
this consequential.

**Why this matters beyond wording:** the same imprecision could have
been read the other direction too — as an argument for gating
`share_unlisted`, collaboration, or any other planning action behind
Creator verification "to be safe," since publication needs it. That
would have been exactly backwards from the product's actual intent
(full personal planning power without Creator status, publication
specifically excepted) and from §3.1's own "requires only Viewer"
principle. Appendix A now names this failure mode explicitly, not only
the other direction.

### From draft 1.12 to 1.13

A 2026-08-12 review scored v1.12 7/10 architecturally but 4/10 as a safe
implementation base, on two critical security findings plus ten
lower-severity content errors in the just-added "Recommended default"
material. Both critical findings were confirmed by reading the transition
table literally, not by trusting the claim — and both were real:

**Critical, fixed with a redesign, not a patch:**

1. **`securityLocked` deletion bypass.** v1.12 gated only *closing an
   existing obligation* on step-up; *requesting deletion itself* from
   `securityLocked` was ungated. A hijacked session with nothing to close
   could walk the account through `deletionPending` to `tombstoned`
   without ever proving anything — a full account-destruction bypass of
   the lock that step-up exists to enforce.
2. **Account-wide step-up flag, not session-scoped.** `pendingSecurity
   Verification: bool` cleared globally the instant *any* session
   completed the unlock flow — so the legitimate owner verifying on
   device A would silently also clear it for a concurrently active
   hijacked session on device B, which never proved anything either.

Both are closed by the same redesign, not two separate patches: step-up
is now a `StepUpGrant{sessionId, purpose, verifiedAtUtc, expiresAtUtc}` —
scoped to one session and one purpose, never a global fact. Requesting
deletion from `securityLocked` now requires its own fresh grant (closes
#1); a grant for one session never implies one for another (closes #2);
and `securityLocked -> active` now mandatorily revokes every *other*
active session as part of the same transition, so a stolen session is
logged out rather than silently re-trusted when the owner recovers
control elsewhere. A human-support-verified recovery path is required for
a true owner who cannot complete step-up at all (tracked under `VP-D15`,
not designed here). `VP-AC-33`, `36` rewritten; `VP-AC-37`, `38` added for
the new session-scoping and mandatory-revocation properties specifically.

**Content errors in §22, all confirmed against source and fixed:**

- `VP-D02`'s invitation-lifecycle default omitted `declined` —
  `TeamInvitation.status` (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §22.1)
  has five values, not four; also downgraded from a full default to an
  explicit **partial** one (2 of 9 open sub-questions), since it read as
  more complete than it was.
- `VP-D07`'s opaque-link default cited `PP-D17` as a "structurally
  identical" precedent; checked directly, `PP-D17` governs page slug
  permanence/redirect, not token issuance — the false analogy is removed,
  the property (opaque, short-lived, revocable) stands without it.
- `VP-D09` proposed reusing Scenario's conflict-resolution UX "verbatim"
  for every library; split into three category defaults instead, since a
  read-only library (My participation) and an add/remove-set library
  (Favorites) have no forkable content for a "save conflict copy" to
  apply to.
- `VP-D11`'s dedup key `(eventId, category)` does not prevent the
  duplicate it was proposed to prevent, if Viewer and Creator categorize
  the same event differently — changed to `(recipientUserId,
  sourceEventId)`, independent of which surface's vocabulary classified
  the event.
- `VP-D13` applied one eviction/TTL rule to both Smart Search history (a
  passive log) and Saved Searches (an explicitly kept object) — the
  latter would have meant silently deleting something the owner chose to
  save. Split: history gets a cap and TTL, Saved Searches get none,
  matching Favorites' own no-auto-eviction pattern.
- `VP-D14` claimed owner-scoped export queries mean "no separate
  redaction pass is needed" — false and unsafe to build against: row-level
  scoping does not make every field inside an owned row safe to export
  (a Scenario the Viewer owns can still embed another participant's
  identity). Corrected to require a per-library export-projection
  allowlist.
- `VP-D16` named categories (malware/type/size checks) without concrete
  thresholds, and "scan before storage" doesn't specify what storage means
  before a scan can happen — added concrete numbers and an explicit
  quarantine → scan → promote-or-reject flow.
- `VP-D05`, `VP-D06` re-labeled as partial defaults where an earlier
  draft implied completeness they didn't have (D05 already had its
  visibility question settled elsewhere but didn't say so; D06's 30-day
  window was extended to libraries this document doesn't fully own,
  without flagging that). `VP-D15` re-flagged as requiring security
  review *before* a slice builds against its default, not concurrently
  with it, since it shapes the takeover-recovery surface itself.
- Sibling `Compatible with` versions updated: `CREATOR_PROFILE_
  FUNCTIONAL_SPEC.md` v1.4 → v1.5, `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_
  SPEC.md` v1.3 → v1.4, `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.17 →
  v2.18.
- Corrected an arithmetic error: v1.12 claimed 11 Recommended defaults
  and listed 12 (`D01, 02, 03, 05, 06, 07, 09, 11, 13, 14, 15, 16`);
  version line and Appendix B both said "eleven."
- Tightened the relationship between a "Recommended default" and §0's own
  Approved-bounded-slice-spec gate: `VP-AC-39` (renumbered from `37` to
  keep the document's numbering in reading order after the new `37`/`38`
  were inserted earlier in §20) now says explicitly that a default
  authorizes drafting a slice spec, never runtime implementation directly
  from this Draft document.

### From draft 1.11 to 1.12

The user asked, specifically, to raise this document's implementation-
readiness score, not its Approval status. Those are different axes: a
Draft document is legitimately not `Approved` while decisions remain
open, and this revision does not change that gate or pretend to. What it
changes is whether an engineer has to wait for a product meeting before
starting on a given roadmap slice.

§22's sixteen `Open` decisions were auditing correctly but planning
poorly: the single word `Open` was standing in for three different
situations that need different responses —

1. genuinely blocked on something this document cannot supply (an unbuilt
   backend, or a joint cross-document decision);
2. a real product/legal/safety judgment call, where guessing would be
   irresponsible regardless of how low-risk it looks;
3. a parameter or UX-flow choice where any of several reasonable answers
   is fine to build against now and revise later without meaningful
   rework risk.

Collapsing all three into one `Open` status meant every roadmap slice read
as equally stalled, when in fact only four decisions are genuine blockers.
This revision:

- adds an explicit **Recommended default (not Approved)** to eleven
  decisions (`VP-D01`, `02`, `03`, `05`, `06`, `07`, `09`, `11`, `13`,
  `14`, `15`, `16`) — concrete, engineerable answers, each reusing an
  existing in-product precedent where one exists (`SCENARIO_CONNECTED_
  PLANNING_SPEC.md`'s own conflict-resolution UX for `VP-D09`; its
  Approved 30-day Scenario retention for `VP-D06`; `TeamInvitation`'s
  shape for `VP-D02`'s invitation lifecycle) rather than inventing
  unrelated numbers or patterns;
- explicitly declines to propose a default for `VP-D08` and `VP-D10` —
  reviews-about-a-person and a minor's baseline projection are consent/
  child-safety questions, and a default there would be exactly the kind
  of premature product decision this document has repeatedly corrected
  itself for making elsewhere in earlier revisions;
- leaves `VP-D04` (unbuilt ADR 0019 backend) and `VP-D12` (joint
  cross-document Follow decision) as genuine blockers no default can
  help with;
- adds `VP-AC-37` stating plainly that building against a default never
  advances that decision's own `Status`, so this addition cannot be
  mistaken for quietly lowering the Approval bar;
- re-labels §22.1's `Status` column with the three categories above, and
  adds one sentence to §23's Definition of Done clarifying exactly what
  did and did not change: the Approval gate is untouched; what changed is
  that only `VP-17` (Follow), among twenty-one roadmap slices, is blocked
  on a decision that isn't this document's alone to make.

### From draft 1.10 to 1.11

Between the 1.9 and 1.10 revisions, `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
independently moved to v2.17 (via its own v2.16, which fixed a Scenario/
Quick Plan conflation in its own text — not this document's defect, no
action needed here) and, in v2.17, ran its own cross-document self-review
directly against this document. That review surfaced one real,
previously-unknown problem this revision addresses:

- **`FollowRef`/`FollowRelation` shape mismatch, confirmed and
  acknowledged.** This document's proposed `FollowRef` (§4.2, §12.4) is
  person-only — no `target` field — and cannot represent following a
  Professional Page. `PP-D44`'s proposed `FollowRelation` uses a
  discriminated `target: {type: user | page, id}` that covers both. This
  is not a stale citation to fix by updating a version number; it is a
  genuine open design conflict between two Draft proposals, and
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` itself now tracks the
  reconciliation as a dedicated, deliberately neutral roadmap slice
  (`FOL-01`, "not PP-owned") rather than assuming either shape wins by
  default. This document does not resolve the conflict unilaterally in
  either direction — doing so would repeat the exact error already
  corrected once in this section (declaring a Follow design settled before
  the joint decision reaches it). Instead: §12.4 states the mismatch
  explicitly as a known, unresolved fact; `VP-D12`'s text now names it as
  one of the specific questions the joint decision must answer; the
  `FollowRef` domain-model comment (§4.2) carries the same flag so a reader
  encountering only the data shape still sees it; and roadmap slice
  `VP-17` now cites `FOL-01` as the source of whichever final shape is
  eventually adopted.
- Updated the Compatible-with header's `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
  citation v2.15 → v2.17.

Confirms this document's own now-repeated pattern: acknowledging a
cross-document finding honestly, without either silently adopting a
sibling's unaccepted proposal or dismissing the finding because it did not
originate from within this document.

### From draft 1.9 to 1.10

The user asked for this document to be brought to the highest honest
quality achievable. A numeric score is not something that can be declared
into being — the response to that request was to actually do the work a
fresh, adversarial external review would do: a full front-to-back re-read
of the entire document (not only the areas touched by the most recent
edits), specifically hunting for residue from earlier rounds of correction.
Two real findings, both fixed:

- **§1.1's "It is not" list still conflated Scenario and Quick Plan
  collaboration**, describing "a full Scenario/Quick Plan collaboration
  domain contract" as something that "belongs to the Scenario aggregate
  itself, not to any profile document" — phrasing left over from before
  v1.7's correction, when Scenario's collaboration model genuinely was an
  open question. It no longer is: `SCENARIO_CONNECTED_PLANNING_SPEC.md`
  Approved it. The old wording made this document read as if it were still
  uncertain about something it has, everywhere else, correctly treated as
  settled since v1.7 — exactly the kind of Scenario/Quick-Plan conflation
  `PROFILE_DOCUMENTS_INDEX.md` §8 flags as a live defect in two *other*
  documents (`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §0,
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §0.1). This document's own
  revision history already claims to have fixed this in itself; this one
  surviving instance made that claim not quite true. Corrected: Quick
  Plan's contract is described as genuinely open (`VP-D02`), Scenario's as
  already Approved and merely rendered here.
- **`VP-AC-24`'s "remains reachable" had no forward pointer** to
  `VP-AC-33`/`36`'s `pendingSecurityVerification` step-up requirement,
  added later in the same document (§20). Read on its own, `VP-AC-24`
  could be misread as "no precondition ever applies." Added an explicit
  cross-reference so the two acceptance-criteria groups cannot be read in
  isolation and contradict each other by omission.

Everything else in this pass — the four-way document map, the six-tier
precedence order, the `AccountStatus`/`pendingSecurityVerification` model,
the Scenario `accessRole` rendering, the Follow proposal's framing, every
cross-document citation — was re-read and held up under adversarial
pressure without producing a third finding. That is not the same claim as
"no further defect exists"; it is the claim this document has made
honestly at every prior revision: verified against primary sources as of
this date, not assumed correct because it was written carefully once
already.

### From draft 1.8 to 1.9

Incorporates findings from `docs/product/PROFILE_DOCUMENTS_INDEX.md` v1.0
(2026-08-12), a new fully non-normative cross-document navigational index
over the four profile-surface documents. Per that document's own stated
role, nothing in it was treated as authoritative on its own — each item
below was checked against the actual cited primary source before this
revision changed anything, consistent with this document's standing
practice throughout its revision history.

- **Precedence order (§0):** this document's own conflict-resolution order
  ranked its personal-identity siblings inconsistently with how those
  siblings rank each other, and omitted `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
  entirely. Replaced with the same six-tier model `CREATOR_PROFILE_
  FUNCTIONAL_SPEC.md`, `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` had already converged on.
- **Sibling-count framing (§0):** this document stated "one of three
  sibling documents" at the top while its own canonical-sources list still
  called `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` a plain "sibling" with no
  distinction — internally inconsistent. Adopted
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §0's already-established frame in
  full: three personal-identity documents plus one ManagedPage peer,
  four documents on equal conflict-precedence footing.
- **Block/Mute ownership attribution (§12.3, §25):** this document credited
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §7 with "establishing" the
  Block/Mute split. That document's own §7.2 (as of its v1.3) explicitly
  disclaims establishing it and cedes full ownership here — this document's
  citation was simply never updated to match. Corrected in both §12.3 and
  the §25 ownership map, which now also lists Block/Mute explicitly among
  this document's owned concerns rather than leaving it implicit.
- **Compatible-with header:** updated `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_
  SPEC.md` v1.2 → v1.3 and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.14 →
  v2.15 (the index confirms the latter delta is cosmetic; the citation
  still needed the version bump regardless, per this document's own
  stated staleness rule). Added a pointer to the index itself as a
  non-normative navigational aid, not a new authority.

Not changed, and deliberately so: the index's Follow findings (§5.1 —
trilateral party count and a shared `FollowRelation` shape are `Direction`,
not `Propagated` or `Accepted`) are not reflected here, because they have
not been propagated into this document's own decision-tracking table by
the process the index itself describes (§5.1's own provenance note) — doing
so now would be exactly the kind of premature-acceptance error this
document has repeatedly corrected itself for. `VP-D12` remains `Open`,
unchanged, pending that propagation happening through its own proper
channel.

### From draft 1.7 to 1.8

A 2026-08-12 round-4 review scored v1.7 8/10 as a product draft but 6/10 as
an implementation base, on one P0 and a ten-item P1 list. All were verified
against primary sources before this revision changed anything.

**P0 — `securityLocked -> deletionPending` bypassed the step-up
requirement.** v1.7 added the transition (correctly — a degraded account
should not be trapped) but did not carry the *reason* for `securityLocked`'s
step-up requirement forward into `deletionPending`'s own table row, so a
hijacked session could request deletion and then close a live Booking
without ever completing step-up. Fixed with a new orthogonal
`pendingSecurityVerification` flag (§15.1) that survives the
`securityLocked -> deletionPending` transition and gates obligation-closing
regardless of the current `AccountStatus` value — deliberately not the
reviewer's proposed full three-axis (`AccountLifecycle` ×
`AccessRestriction` × `DeletionRequest`) redesign, because
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3/§3.3 already depends on the
existing five-value `AccountStatus` contract by name and value set; a
minimal additive flag closes the same hole without forcing an
uncoordinated rename on a sibling document. `VP-AC-33`/`36` and matching
test-matrix entries added.

**Confirmed mid-review: `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` had already
reached v1.4** (past the v1.3 the review cited) and had independently found
and fixed the exact same sole-Page-owner `suspended`-omission bug this
document still carried forward from `CP-AC-19`'s earlier phrasing —
confirming the review's cross-document-instability point in the most
direct way possible. §24.4 now matches Creator's fix exactly: "any
Professional Page that is not `archived` or tombstoned," not an enumerated
lifecycle list.

**P1 fixes**, each verified against its cited source:

- module table's Follow row still said "Universal... base relationship
  owned here" — contradicted the already-corrected §12.4; fixed to
  "proposed... blocked on the joint decision," reclassified Gated
  expansion;
- test matrix still said "block/mute affecting only the blocking account's
  own reads" — re-conflated Block/Mute after `VP-AC-15` had already been
  split; fixed;
- added `SCENARIO_CONNECTED_PLANNING_SPEC.md` to the canonical sources
  list — it was cited throughout the body but never declared as a source;
- "§3.1 reused verbatim from Creator Profile" was no longer true — Creator
  Profile's own §3.1 formula changed shape (`VerifiedCreatorIdentity` is
  unconditional there, because that document is Creator-specific by
  definition); reworded as a restatement for this document's broader
  scope, not a verbatim quote;
- §5.2's Scenario command permissions (rename/duplicate/archive to owner
  only, `Leave` to viewer, rename excluded from editor) were presented as
  if `ScenarioAccessGrant`'s capability table settled them; that table only
  has Read/Edit/Invite/Share-publish/Manage-access columns and does not
  itself enumerate these UI commands — reworded as this document's own
  reasonable inference pending `VP-D01`, not an Approved-table fact;
- `pendingApplication` was an invented status label; ECL-03's own `Booking.
  state` enum is `pending | confirmed | cancelled | expired | waitlisted`
  — fixed to use `pending` verbatim, closing a "never invent a second
  status enum" violation of this document's own invariant 7;
- `PhotoAssetRef.visibility` still offered `public` as a value despite §10
  already stating no rendering surface exists for it — changed the target
  schema to `private` only, with `public` marked reserved/not-settable,
  and updated the §12.1 table row to match;
- §3.3 said Profile "opens" for any Viewer without acknowledging the
  `securityLocked`/`suspended`/`deletionPending` restricted-session concept
  §15.1 introduces later in the document — added a forward reference so
  the two sections do not read as contradictory;
- §24.5's "per-session-synced to the account" was ambiguous/backwards-
  reading; reworded to "account-scoped and synchronized across every
  active session/device";
- a stale "§9.1" citation for Created-content attribution rules corrected
  to "§9.3," `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s actual current section
  for that scope;
- added a "Compatible with" header block, matching the convention
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` already established, and
  noted honestly that `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s own
  header still names this document at v1.6 — a staleness this document
  cannot fix from here.

**Governance gap closed:** four items previously described only as
non-blocking "future work" with no decision ID — Saved/Smart Search
retention, account export, session list/device revoke, Photos media safety
— are now `VP-D13`–`VP-D16` with target roadmap slices (`VP-18`–`VP-21`),
owners and gates, and §23's Definition of Done now requires `VP-D01`–`VP-D16`
resolved or explicitly deferred, not just `VP-D01`–`VP-D12`. The prior
framing risked exactly what the review named: this document reaching
`Approved` without ever having to decide retention, session revocation or
media safety at all.

### From draft 1.6 to 1.7

A 2026-08-12 cross-document review scored v1.6 as an implementation base
4/10 (product draft 7/10) on two blocking desyncs, both verified against
primary sources rather than taken on trust, plus a long P1 list. Both
blockers were confirmed real:

**P0-1 — Scenario collaboration was stale.** `SCENARIO_CONNECTED_PLANNING_
SPEC.md` v1.1 (Approved, 2026-07-31 — predates this document's every prior
draft) defines `ScenarioAccessGrant` with four roles —
`owner|editor|viewer|unlistedViewer` — and a full capability table.
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.2 independently found and corrected
the same gap in its own v1.1 (`CP-AC-16`, `CP-AC-17`). v1.6's
`relationship: owned | invited` and "no accepted collaboration model"
framing were wrong **for Scenario** — right only for **Quick Plan**, which
remains genuinely undecided. Fixed throughout §4.2, §4.3(2)/(11), §5.1,
§5.2, roadmap `VP-01`/`VP-02`, `VP-AC-06`, `VP-D02` (rescoped to Quick Plan
only), test matrix and Appendix A.

**P0-2 — Universal Follow was declared accepted unilaterally.** v1.6
presented Follow as a settled, universal contract. But
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §7 is titled "illustrative
direction only" (`PCP-D02` open), and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
`PP-D44` separately asks whether person-Follow and page-Follow share one
contract — and that document's own §0 conflict rule states implementation
is blocked on a cross-document disagreement until a joint decision is made,
with neither document's wording winning by default. v1.6's declaration was
exactly the unilateral resolution that rule forbids. §12.4 is rewritten as
this document's *proposed* input to the joint decision, not an accepted
design; `VP-AC-28`–`32` reframed as conditional; `VP-D12` reframed as this
document's half of the joint decision, not "refinements to a settled
baseline"; roadmap `VP-17` gated on all three of `VP-D12`+`PP-D44`+
`PCP-D02`; a DoD item added so this document being Done never authorizes
Follow to ship.

**P0-3 — Block/Mute were conflated.** `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_
SPEC.md` §7 establishes Block as bidirectional (both accounts lose the
ability to view/follow/contact each other) and Mute as one-directional,
silent, content-stays-visible-but-deprioritized. v1.6's `VP-AC-15` and
§12.3 said Block "changes only the blocking account's own view" — that is
Mute's definition, not Block's. Fixed in `VP-AC-15` and §12.3.

**P1 fixes**, each verified against the cited primary source before
changing:

- `avatarUrl` → `avatar` in `UserProfile` (§4.1), matching
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.1's own v1.2 fix and the actual
  `S2-EXP-01`/`ProfileEditableEntity` field name;
- `CP-AC-16` no longer means "account deletion" in
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.2 (it was renumbered to mean
  Scenario-collaboration rendering); the deletion criterion is now
  `CP-AC-19`. Fixed in §0.3, §22 (`VP-D06`), §22.1, §24.4;
- `CP-AC-12`/`CP-AC-14` no longer confirm "no Scenario role model exists" —
  rewrote invariant 2 (§4.3) to cite the actually-relevant `CP-AC-16`/`17`;
- "Creator §3.2" was never the verification-state axis in the current
  numbering (that's §5.2; §3.2 is the actor/owner/author/publisher/
  collaborator distinction) — fixed in §25;
- "§9 step 9" → "§9.2 step 9" (Creator Profile's draft/publisher rules
  moved under a numbered subsection) — fixed in §15.2;
- `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` Appendix B.2 no longer exists;
  that content is now Appendix A.2 — fixed in §5.2;
- reviews-about-published-content do **not** depend on `VP-D08` —
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §6 separates that dependency
  from reviews-about-a-person explicitly, after correcting its own earlier
  draft — fixed in §9 and §25;
- restored the already-Approved `S2-EXP-01` Settings/Profile surface
  (`logout`, `support/help`, `privacy policy`, `terms of service`,
  read-only `email`/`userId`/`currentRole`) that v1.6's §16 had silently
  dropped instead of extended;
- clarified that `EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md` models
  `admissionMode=application` as a field on `Booking` itself — My
  participation's `application/registration` scope (§8) must not
  double-represent the same event as both a `booking` and a separate
  `application` family entry;
- `AccountStatus` (§15.1): added the missing
  `securityLocked`/`suspended` → `deletionPending` transitions (a degraded
  account is not trapped), an explicit precedence rule for a security/
  moderation signal arriving mid-`deletionPending`, an explicit
  restore-always-to-`active` rule, a **restricted session** term
  distinguishing degraded access from full `Viewer` status (§3.1's
  `Viewer = authenticated active User` definition does not, on its own
  wording, cover a `securityLocked`/`suspended`/`deletionPending` account),
  and a step-up re-authentication requirement before an obligation can be
  closed from a `securityLocked` session specifically — closing a live
  Booking must not be possible on the strength of a session whose own
  legitimacy is in question;
- acknowledged that `PhotoAssetRef.visibility = public` (§4.2) currently
  has no rendering surface at all, since no standalone public Viewer route
  exists yet — §10 now states this explicitly rather than leaving it
  implied;
- aligned Follow's proposed link-resolution mechanism with
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `PCP-D10`'s requirement that
  `unlisted` resolution use an opaque, revocable token, never a raw
  `userId`/handle — a gap the Follow proposal (§12.4) previously left
  implicit as "a direct handle/link";
- added the Follow gap list (self-follow, idempotency, races with
  Block/deletion, rate limiting, retention, counter consistency,
  pagination, product-value tie-in, person/page interaction) to §12.4,
  cross-referencing rather than duplicating `PP-D44`'s own list;
- reclassified `VP-16` pagination as Release foundation for the
  already-foundation libraries specifically, rather than blanket "Mature
  extension," since an unpaginated foundation library is not actually
  done;
- added a Social notification category for a future new-follower event
  (§16), explicitly absent until the joint Follow decision resolves.

Not addressed in this pass, by design — these remain tracked as open
decisions rather than resolved here, consistent with this document's
standing practice of not inventing product decisions under review pressure:
exact retention/cleanup for Saved Searches/Smart Search prompts, full
export format, session list/revoke-device UX, Photos malware/EXIF/alt-text
specifics, and a dedicated AC set for Photos/Reviews/Settings/export/
follower-lists/pagination/session-recovery beyond what already exists.
These are legitimate future work, not errors in this draft.

### From draft 1.5 to 1.6

Adds universal Follow as a product decision made in review, not inferred:
every account may follow, and be followed by, any other non-blocking
account, with no Creator-verification gate. This was previously entirely
unaddressed — `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §7 had modeled
Follow as available only to a `verified` Creator's public card, and no
document defined a plain-Viewer-to-Viewer relationship at all (confirmed by
a full search of `docs/product/` finding no existing "friend"/personal-Follow
concept).

- added `FollowRef` (§4.2) and invariant 13 (§4.3) establishing Follow as
  universal and block-overridden;
- added §12.4 defining the base Follow contract: open by default, reachable
  only via existing trigger surfaces or a direct link (never a new
  discoverability grant), follower/following counts, unfollow/remove
  semantics, and its interaction with block and `tombstoned` `AccountStatus`;
- added §24.6 covering the Follow relationship's own lifecycle;
- added `VP-D12` for the genuinely open refinements (approval-gated
  variant, follower-list visibility to others, minors interaction) —
  scoped narrowly so it cannot be read as reopening the base universal rule;
- added roadmap slice `VP-17`, acceptance criteria `VP-AC-28`–`VP-AC-31`,
  and corresponding test-matrix and Appendix A entries;
- corrected §25's ownership map: this document, not
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`, owns the base Follow
  relationship, and flagged the resulting pending fix that document's own
  §7 needs (out of scope to edit directly from here).

### From draft 1.4 to 1.5

Final consolidation pass after re-verifying every sibling citation against
the sibling documents' current state (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
v1.1, `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.0,
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.10 — all confirmed still
consistent with this document's existing citations):

- added an explicit "audience, not data, is the decomposition axis"
  statement to §0, so the reason for three sibling documents is stated as a
  first-class principle rather than left implicit;
- retitled §0.3 to be version-neutral and pointed it at Appendix B for
  exact deltas, fixing a stale "why this is v1.3" heading left over from
  the 1.3→1.4 version bump;
- brought the `AccountStatus` action table (§15.1) in line with the
  obligation-continuity principle `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §5.4
  already applies to verification loss and
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-73`/§22.2 apply to a
  degraded page: `securityLocked`/`suspended`/`deletionPending` block only
  *new* commitments, not the closing of an obligation already in progress.
  Previously the table read as a near-total lockout in those three states,
  which would have stranded an in-progress Booking or hold with no way to
  resolve it. Added `VP-AC-24` and a corresponding test-matrix entry.

### From draft 1.3 to 1.4

`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §10 was itself corrected after v1.3 of
this document was written: it had restated the Scenario/Quick Plan
collaboration boundary using an `owner`/`editor`/`invited` example, which
was inaccurate — this document's `relationship` field (§4.2) has only
`owned | invited`, and no `editor` tier is accepted pending `VP-D02`.
§5.1's direct quote of that now-superseded phrasing is replaced with a
description of the corrected state, so this document no longer cites text
that CREATOR_PROFILE_FUNCTIONAL_SPEC.md itself has retracted.

### From draft 1.2 to 1.3

Closes the cross-session desync with `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
v1.1 and the new `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`, per a
2026-08-11 review (score 6.5/10, blocking on eight P0/P1 items). Full detail
in §0.3; summary:

- re-pointed every stale cross-reference into the two sibling documents'
  current section/AC numbering (§1.1, §3.2, §4.3(2), §5.1, §8, §9, §11,
  §12.1, §12.3, §24.4, §24.5, §25) and added
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` as a full sibling throughout;
- added the formal `AccountStatus` contract (§15.1) this document was
  already assumed to own;
- corrected deep-link authorization from "ownership" to the full grant
  chain (§17, `VP-AC-22`);
- narrowed the `S3_NOTIF_01_NOTIFICATIONS_SPEC.md` claim to its actual
  Approved scope and added the notification dedup decision
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.5 already expected (`VP-D11`);
- recorded `VIS-HIST-01`'s corrupt-cache-returns-empty behavior as a named
  exception to this document's partial-load invariant instead of an
  unacknowledged conflict (§4.3(8));
- widened `VP-D02` to the full Scenario/Quick Plan collaboration domain
  contract and stopped implying `owned | invited` is a complete model
  (§5.1);
- widened `VP-D06` to acknowledge the sole-Professional-Page-owner deletion
  precondition (§24.4);
- narrowed `VP-D07` now that suspended/security-locked display (§15.1) and
  minors (new `VP-D10`, distinct from Creator's `CP-D14`) are resolved
  elsewhere;
- added the "requires only Viewer is not requires nothing" caveat (§3.1);
- restructured `ParticipationRef` into a tagged projection to forestall a
  de facto universal status enum (§4.2, §8);
- split roadmap slices VP-05 and VP-09 into VP-05/VP-11 and VP-09/VP-13, and
  added VP-12 (`AccountStatus`), VP-14 (Notifications), VP-15 (base IA/shell)
  and VP-16 (pagination/performance), none of which 1.2 tracked separately.

### From draft 1.1 to 1.2

Closed a self-review pass: fixed two internal cross-reference bugs (§0's
non-overlap section, §1.1's Public User Projection reference), corrected a
citation that mislabeled `SCENARIO_BUILDER_SPEC.md` §5's title, cited two
previously-unused canonical sources at the claims they support, and added a
missing Public User Projection row to the module table (§13).

### From draft 1.0 to 1.1

Not separately recorded at the time. Known changes: `QuickPlanRef` dropped
the `expandedToScenarioId` back-reference in favor of one-directional
provenance stored on the new Scenario only (invariant 4); `dateMode` was
added to `PersonalScenarioRef`; ADR 0019 was added as a canonical source;
My participation, Photos and Reviews were tightened from "Mature extension"
to "Gated expansion" pending their respective backend/pipeline/contract
dependencies.
