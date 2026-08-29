# RECHARGE — Creator Profile Functional Specification

Status: **Draft for product and architecture review**

Version: **1.9** (supersedes v1.8 — adopts Professional Page v2.28's
accepted `PP-D16` transfer disposition and refreshes the sibling-version
snapshot; see §0.13)

Date: **2026-08-12**

Scope: **target full-release product; documentation only**

Verified-against snapshot (exact versions; a mismatch means this snapshot
is stale and MUST be refreshed whenever this document is substantively
changed, but does not by itself prove content incompatibility):
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.15 (targeted verification:
`AccountStatus`'s five values/casing, §12.3's bidirectional-Block rule and
the Scenario/Quick Plan boundary still have the meaning consumed below),
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9,
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.28 (targeted verification:
`PP-D44`, `PP-D25`, `PP-AC-58`, `PP-D03` and the now-Accepted `PP-D16`
still have the meaning cited below),
`IDENTITY_PUBLISHER_SLICE_SPEC.md` v1.3.1,
`SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1 (Approved).
See `docs/product/PROFILE_DOCUMENTS_INDEX.md` for the cross-document
registry this citation block is checked against.

The Scenario `editor` conflict recorded in v1.3 of this document is
**resolved**: `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §5.1 now cites
`SCENARIO_CONNECTED_PLANNING_SPEC.md` directly and confirms the four-role
`ScenarioAccessGrant` set, matching this document's §10. Both documents
independently name the earlier mismatch a verification failure (trusting a
sibling's restatement instead of checking the primary source), not a
product decision — no further action needed here.

**On the pace of sibling-document change:**
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` and
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` are under active, frequent revision
independent of this document's own edit cycle — both
advanced several versions between two successive checks during this
document's own v1.5→v1.6 work. A full line-by-line re-verification against
every sibling version bump is not sustainable at that pace; this document's
practice instead is a targeted spot-check of the specific facts it actually
cites (enum shapes, specific `PP-D*`/`VP-D*`/`AC` IDs and their meaning)
each time this header is touched, recorded above, rather than a claim of
exhaustive re-reading. A version mismatch is therefore a maintenance signal
requiring a new targeted check, not automatic evidence that the documents'
semantics conflict.

## 0. Document authority and purpose

This document defines the target functional model of `Creator Profile`:
identity verification, the personal publisher context (`PublisherRef{type:
user}`), Created-content management, and this account's relationship to a
managed Professional Page. It is available to any authenticated Viewer from
the moment they may start verification (§5.1) — it is not gated behind
already being `verified`, even though most of its surface only becomes
useful once verification succeeds. **It does not define the public-facing
Creator card** — that is `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s
exclusive subject (§1, §23); this document's own settings surfaces link to
that document's fields without redefining them. It is one of three sibling
documents, each with a distinct, non-overlapping subject:

```text
docs/product/VIEWER_PROFILE_FUNCTIONAL_SPEC.md
  — the private personal operational center every authenticated account has,
    independent of Creator status: Scenario, Quick Plan, Favorites, Saved
    Searches, Visit History, My participation, Reviews, Photos, account and
    session state. This document does not redefine any of it.

docs/product/CREATOR_PROFILE_FUNCTIONAL_SPEC.md  (this document)
  — Creator verification lifecycle, the personal publisher context, Created
    content management, and this account's relationship to any Professional
    Page it manages.

docs/product/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md
  — the public card of a verified Creator shown to other authorized users;
    a strict superset of Viewer Profile's minimal Public User Projection.
```

This is a deliberate three-document split among **personal identity/profile**
documents, not an unresolved leftover from an earlier "two documents" plan:
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` is a sibling owned by a separate work
session with its own scope boundary, and this document's own split
(private-management vs. public card) is the two-way division that was
actually chosen for the Creator-specific surface. §23 records the exact
non-overlap between all three. `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` is a
related **peer specification** over the separate `ManagedPage` workspace —
not a fourth personal-identity document, but participating in the same
cross-document compatibility/conflict protocol (§0.1) because it shares
canonical aggregates (`PublisherRef`, Follow, etc.) with all three.

This document is not an Accepted ADR, does not replace the approved Identity
/ Publisher contract and does not authorize runtime, Firebase, backend,
verification or provider integration. Before implementation, each delivery
slice still requires an Approved bounded slice specification.

When sources conflict, the following order applies:

1. Accepted ADRs, especially ADR 0013, 0015, 0016 and 0017.
2. The Approved current-slice specification.
3. `docs/architecture/LAUNCH_STATUS.md` — only for truth about current
   implementation, never for target product semantics.
4. An Accepted/Approved owning aggregate specification or shared
   cross-product contract (e.g. `SCENARIO_CONNECTED_PLANNING_SPEC.md`,
   once approved the canonical Review contract, a future `FollowRelation`
   foundation) — the Review contract and `FollowRelation` are listed as
   illustrative future examples of this tier, not as already-Approved
   today.
5. Draft profile-surface specifications on equal footing with each other —
   this document, `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`,
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
   `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`. None of them outranks another by
   virtue of which one a reader opened first; a conflict between them is
   blocked pending a joint decision (§0.1), not resolved by this tier
   ordering.
6. `docs/product/VISION.md` and other general product material.

If any statement in this document contradicts an Accepted ADR, an Approved
spec, `LAUNCH_STATUS.md`, or a shared cross-product contract (items 1–4),
**that is a defect in this Draft**, to be corrected. This document found
and fixed exactly that kind of defect against itself in v1.1 → v1.2 (§0.5)
and does not assume it is now free of others.

### 0.1 When sibling documents disagree

All four documents in item 5 above are `Draft`. If two of them disagree on a
shared invariant and no higher-priority source (items 1–4) resolves it,
**implementation of that invariant is blocked pending a joint decision —
neither document's wording wins by default.** This document does not treat
its own position on Follow-adjacent questions as settled for exactly this
reason (§7, §12).

Two terms collide across the sibling documents and MUST be disambiguated on
every use: **`owner`** means a page-team role in
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` and a personal content item's own
ownership relationship in `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` — this
document uses neither sense without saying which. **Follow** is not yet
confirmed as one shared model or two separate ones —
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D44` proposes a shared
foundation; this document has no Follow model of its own to reconcile with
it (that is `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s and
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s joint concern, §23).

Canonical supporting sources:

- `docs/adr/0013-domain-policy-baseline.md`;
- `docs/adr/0015-authenticated-viewer-verified-creator-professional-page.md`;
- `docs/adr/0016-bounded-identity-workspace-during-stabilization.md`;
- `docs/adr/0017-admin-experience-preview-and-user-created-pages.md`;
- `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md` (Approved; bounded
  local/mock implementation allowed during stabilization) — canonical source
  for `CreatorVerification`'s exact fields (§4.1) and the capability
  namespace (§7);
- `docs/product/SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1 (**Approved**
  execution spec) — canonical source for Scenario collaboration roles (§10);
- `docs/product/S2_EXP_01_PROFILE_SETTINGS_SPEC.md`;
- `docs/product/VIEWER_PROFILE_FUNCTIONAL_SPEC.md` (sibling — owns every
  personal-library lifecycle this document must not redefine; see §23);
- `docs/product/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` (sibling — owns
  the public card field list this document must not redefine; see §23);
- `docs/product/PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` (`ManagedPage` peer,
  not a personal-identity sibling — see §0's distinction; shared invariants
  MUST NOT diverge without the divergence being recorded in §23);
- `docs/product/CATEGORY_SYSTEM.md`;
- `docs/product/SCENARIO_BUILDER_SPEC.md`;
- `docs/product/ROUTE_BUILDER_SPEC.md`.

### 0.2 Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` and their Russian equivalents are
normative. `Target` describes intended full-release behavior. `Current` is
only a status snapshot and must be verified in `LAUNCH_STATUS.md` before work.

### 0.3 Current implementation boundary

At the date of this document, per `LAUNCH_STATUS.md`:

- `S2-EXP-01` is Done (checkpoint fixed, 2026-04-18): personal profile
  view/edit exists as local/mock state behind the auth gate. The **actual
  current code entity** is `ProfileEditableEntity`
  (`apps/mobile/lib/features/explore/domain/entities/profile_editable_entity.dart`)
  with fields `displayName, about, city, avatar` (String, non-nullable,
  default-populated) — a narrower, present-tense implementation object, not
  the target `UserProfile`/`revision`/`schemaVersion` contract §4.1 below
  describes. The two MUST NOT be conflated when reading current code;
- `S3-CRT-01` (`event`/`place` draft + publish happy path) is **Done since
  2026-04-20** — it is completed, narrow-scope history, not an in-progress
  item, and the `feature/s3-crt-01` branch name is not itself evidence of
  current slice status;
- the actual in-progress item for canonical personal `PublisherRef{type:
  user}` across all ten Create types is **`IDP-04A`** (`Doing`): "ECL-01 now
  provides shared PublisherRef and active-workspace capture/non-rewrite
  coverage for Event only. Remaining before Review: canonical new-draft
  defaults and non-rewrite coverage for the other nine Create types."
  `IDP-03A` is `Review`, `IDP-05A` is `Planned`;
- `CreatorVerification`'s **Approved** canonical shape
  (`IDENTITY_PUBLISHER_SLICE_SPEC.md` §6.1) is `{userId, status, level:
  identityDocument, submittedAtUtc?, decidedAtUtc?, expiresAtUtc?,
  decisionReasonCode?, revision, schemaVersion}` — §4.1 below now matches it
  exactly instead of the v1.1 approximation that added an unaccepted
  `reviewerNotes` field and omitted `level`/`decisionReasonCode`;
- `SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1 is **Approved** and already
  defines a Scenario collaboration role model (`owner | editor | viewer |
  unlistedViewer` via `ScenarioAccessGrant`, §10) — §10 below cites it
  directly instead of treating Scenario collaboration as fully open;
- there is no production Follow, personal analytics or externally reachable
  public Creator card;
- production Auth, Creator verification authority, Firebase enforcement and
  account deletion remain gated.

No target statement below may be presented as currently implemented unless
`LAUNCH_STATUS.md` contains corresponding evidence.

### 0.4 Relationship to the two sibling documents

This is a deliberate three-document architecture, confirmed as final by
product direction during this document's own review cycle:
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` is authored and owned in a separate work
session with its own scope (§0); this document is scoped strictly to
verification + personal publisher context + this account's Professional Page
relationship — never Favorites, Scenario, Visit History, My participation,
Photos or Reviews-as-author, which are `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s
exclusive subject (§23). The public card is its own document,
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`, so "who sees what" has one
owner instead of two documents each defining a field list.

### 0.5 v1.1 → v1.2: corrections from verified cross-document review

v1.1 was reviewed against the actual canonical sources it cited rather than
taken on trust, and several of its own claims did not survive that check —
including one claim in v1.1's own "correction" of v1.0. This revision:

1. fixes an inaccurate current-status citation: v1.1 attributed the
   in-progress all-ten `PublisherRef` migration to `S3-CRT-01`/the current
   branch name; the actually in-progress item is `IDP-04A` (§0.3);
2. replaces the `CreatorVerification` shape in §4.1 with the one actually
   Approved in `IDENTITY_PUBLISHER_SLICE_SPEC.md` §6.1 — adds `level`,
   `decisionReasonCode`; removes the invented `reviewerNotes` field, which
   is not part of that Approved contract; fixes `avatarUrl` → `avatar` to
   match `S2-EXP-01`/the actual `ProfileEditableEntity` field name;
3. **corrects v1.1's own Scenario-collaboration "fix", which was itself
   wrong.** v1.1 stated that only `relationship: owned | invited` is
   accepted and that an `editor` tier is undecided (`VP-D02`). That
   statement was based on trusting a sibling document's claim without
   checking the primary source. `SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1
   is **Approved** and already defines `owner | editor | viewer | unlisted
   viewer` via `ScenarioAccessGrant` (§10.1 there). §10 below now cites that
   directly. Quick Plan's own collaboration model remains genuinely
   undecided — no equivalent accepted contract was found for it — so that
   part of v1.1's caution stands, scoped correctly to Quick Plan only;
4. replaces invented capability codes (`creator.verification.request`,
   `content.create.event`) with the Approved namespace from
   `IDENTITY_PUBLISHER_SLICE_SPEC.md` §10: `create.<type>` /
   `submit.<type>` / `publish.<type>.direct`, and removes any capability
   gate on *starting* verification — ADR 0015 §3 and that same spec make it
   available to any Viewer, not something a separate capability can
   silently withhold (§7);
5. splits the single "save/submit/publish" flow in §9 into the Approved
   four-stage table from `IDENTITY_PUBLISHER_SLICE_SPEC.md` §10 (`Prepare
   local draft → Create durable draft → Submit to moderation → Publish
   directly`), and states explicitly, in the same words as that spec, that
   an owned personal Scenario is planning state a Viewer may create/edit/
   save without verification or a `PublisherRef` — resolving the §4.3(7)
   vs. old-§9 contradiction a reviewer identified;
6. narrows §5.4's "no new draft" rule to durable publisher-bound drafts
   only — personal planning and local pre-verification drafts are
   unaffected by verification loss, per the same distinction as (5);
7. distinguishes `expired` from `revoked` by consequence, not just by name,
   and adds `CP-D16` for the exact reason-code-driven restriction matrix
   that requires a moderation-policy decision this document cannot make
   unilaterally (§5.4);
8. gives `followerVisibilityPolicy`/`publicContactPolicy`/`socialLinks` an
   actual owning contract instead of leaving them referenced-but-undefined
   after "relocation" — `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.2 now
   defines `PublicCreatorProfileConfig` as their home (§4.2 here only points
   to it);
9. fixes the circular Definition of Done: §22 now separates decisions that
   block this document's own Approval from ones this document explicitly
   does not require its siblings to have resolved first;
10. adds an Operational and security requirements section (§14.1);
11. fixes line-wrapped filenames inside code spans that broke searchability
    (a mechanical defect, throughout);
12. expands acceptance criteria and the delivery roadmap to cover gaps a
    reviewer identified (§18, §19).

### 0.6 v1.2 → v1.3: round-2 cross-document review fixes

1. Fixes §0's own scope statement — it claimed to define the public Creator
   card, contradicting §1/§23's correct statement that
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` owns it exclusively, and
   clarifies this surface is available to any Viewer starting verification,
   not gated behind already being `verified`;
2. records the known open conflict with `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`
   v1.6 §5.1 over Scenario `editor` (compatibility header above) — this
   document's §10 is correct and unchanged; the sibling needs the update;
3. adds the missing `rejected → pending` and `expired → pending`
   resubmission transitions to §5.2's state diagram — both were already
   described in prose (§5.3) but omitted from the diagram itself;
4. clarifies the relationship between the persisted `currentRole` field and
   `CreatorVerification.status` (§3.1) — `currentRole == Creator` is a
   coarse, eventually-consistent projection of verification history for
   display/analytics; it is never itself checked for authorization, only
   `VerifiedCreatorIdentity` (computed live from `CreatorVerification.status
   == verified`) is;
5. fixes a real contradiction between §4.3(7) ("acquires a `PublisherRef`
   at submit") and §9.1/§9.2 (which assign it at "Create durable draft",
   a stage *before* submit) — both now consistently say the durable-draft
   stage is where `PublisherRef` is first assigned;
6. adds the idempotent local-to-durable-draft conversion requirements §9.2
   was missing: a permanent ID assigned exactly once, safe retry after a
   failed conversion, and no duplicate durable draft from a repeated
   command (§9.2);
7. splits §3.5's mutation formula into an ordinary-mutation path and a
   narrower obligation-continuity exception path so it no longer appears to
   contradict §5.4's obligation-closing allowances (§3.5);
8. clarifies that Edit/archive/unpublish capability is owned by each Create
   type's own aggregate contract, not this document's `create/submit/
   publish` namespace (§7);
9. corrects §7's claim that `CP-D13` covers the capability wire-code
   registry — `CP-D13` is scoped to entity field/schema contracts only;
   capability wire codes are `IDENTITY_PUBLISHER_SLICE_SPEC.md`'s own
   implementation-slice responsibility, cited instead (§7);
10. adds a Created-content lifecycle breakdown (durable draft / pending
    moderation / rejected / published / unpublished / archived) to §9.3,
    beyond the publisher-attribution filter alone;
11. replaces §16's informal field-moderation description with an explicit
    `ModeratedField<T>` shape, defines the pre-first-approval state (absent,
    not blank — matching the sibling document's own correction), and adds
    revision/idempotency and rejection-reason requirements;
12. fixes §22.4's citation — sole-owner deletion blocking is
    `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D03` (ownership transfer),
    not §22.3 there (which is content transfer/co-host, `PP-D16`) — and
    widens the blocking condition from an enumerated lifecycle list (which
    omitted `suspended`) to "any non-archived, non-tombstoned page";
13. moves `CP-D01`/`CP-D03` off the `CP-01` roadmap slice, which is scoped
    to the verification console, not specialty-tag adaptation or handle
    mechanics (§18, §21.2);
14. fixes "up to five distinct people" (§3.2) — publisher may be a
    `ManagedPage`, not a person, and author/collaborator are not
    necessarily singular; reworded to avoid the false headcount claim.

### 0.7 v1.3 → v1.4: round-3 cross-document review fixes

1. Removes the now-resolved Scenario `editor` conflict note (compatibility
   header) — `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.7 corrected it;
2. replaces §0's 5-item priority order with the 6-tier model
   `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.14 established — Draft
   profile-surface documents sit on equal footing (item 5) rather than this
   document unconditionally outranking `VISION.md`, and adds a new §0.1
   "when sibling documents disagree" section reciprocating the same
   protocol;
3. reclassifies `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` explicitly as a
   related peer specification over `ManagedPage`, not a fourth
   personal-identity sibling — preserving the three-document personal-
   profile split while still covering it in the compatibility protocol;
4. removes the blanket `authenticated and active actor` gate from §3.5's
   obligation-continuity exception — it was still blocking obligation
   closure during `securityLocked`/`suspended`/`deletionPending`, which
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` allows;
5. corrects §3.1's `currentRole` description — it is not exclusively
   derived from verification history (that account does not explain
   `Admin`), it is a read-only summary of the authoritative access
   snapshot; `Admin`/`Creator` priority rules belong to the Identity
   contract, not this document;
6. wires `ModeratedField<T>` (§16) into `CreatorProfileExtension` (§4.2) —
   `headline`/`specialtyTagIds` are now typed as `ModeratedField<T>`, not
   left as raw values with an unattached wrapper description — and fixes a
   wrong `§22.5` cross-reference (notifications, not concurrency) to the
   correct `§22.3`;
7. aligns the sole-owner-deletion AC (renumbered `CP-AC-20` as of §0.9's
   pass) and the test matrix with §22.4's actual rule — "any non-archived,
   non-tombstoned Professional Page" (including `suspended`), not only
   "active", which both previously said despite §22.4 already being
   correct;
8. narrows §23's ownership claims: Follow and Block/Mute mechanics
   (including their bidirectional effect on card visibility) are
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s, not
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s to define independently —
   this document's own citation of that ownership was stale.

### 0.8 v1.4 → v1.4: fixes from `docs/product/PROFILE_DOCUMENTS_INDEX.md` v1.0, complete closure pass

`PROFILE_DOCUMENTS_INDEX.md` is a new non-normative cross-document registry
tracking version citations, ownership and confirmed defects across all four
profile-surface documents; it decides nothing itself (its own §0), but its
§7/§8 identified defects this document had introduced, all now closed:

1. two subsections both numbered `### 0.1` ("When sibling documents
   disagree" and "Normative language") — every `§0.x` heading and
   cross-reference from `§0.2` onward is renumbered one step down
   accordingly throughout this document;
2. every code-style `unlisted viewer` (two-word phrase) rendering —
   §0, §10, the Scenario-collaboration AC (renumbered `CP-AC-17` as of
   §0.9), the test matrix — changed to `unlistedViewer`, matching
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s own rendering and that AC's
   requirement to match it; noted as a `Direction`, not yet propagated
   into `SCENARIO_CONNECTED_PLANNING_SPEC.md` itself, per the index's
   §6.1. Prose quoting the Approved source's own table label ("unlisted
   viewer" as a human-readable string) is left as-is — only code-style
   enum listings were affected;
3. the index's §8 item 5 — `displayName`/`avatar` moderation was specified
   in §16 with no entity to persist it, and the two fields belong to the
   base `UserProfile` (`S2-EXP-01`), not to `CreatorProfileExtension`.
   Closed by adding `IdentityFieldModerationOverlay` (§16.1) as a separate,
   additive entity scoped to exactly these two fields and created only
   once an account has been `VerifiedCreatorIdentity` — never on
   `UserProfile` itself, so a plain Viewer's identity fields remain
   unmoderated exactly as `S2-EXP-01` specifies. New open decision
   `CP-D18` tracks the identity-affecting-change detection rule this
   closure still leaves open (§21);
4. the index's §8 item 6 wording-clarity note — §22.4's own prose used
   "not `archived` or tombstoned," which parses ambiguously as
   `(not archived) or tombstoned`; changed to the unambiguous "neither
   `archived` nor tombstoned" to match this document's own already-correct
   phrasing elsewhere (§15, and the sole-owner-deletion AC).

Also updates stale sibling-version citations
(`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.7→v1.8,
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.14→v2.15) per the index's §1/§7
registry, with the re-verification note each requires
rather than a silent bump.

### 0.9 v1.4 → v1.5: full read-through — a real duplicate-ID bug found and fixed

A complete top-to-bottom re-read (not a targeted check against a specific
review's claims) found one genuine defect §0.8's own additions had
introduced: **`CP-AC-20` was declared twice**, with different content —
once for the new `IdentityFieldModerationOverlay` criterion (§0.8 item 3)
and once, pre-existing, for the sole-owner-deletion criterion. A `sort -u`
pass across all `CP-AC-*` IDs in an earlier verification pass did not catch
this, because deduplication hides a same-ID collision instead of surfacing
it — a tooling lesson, not only a document fix.

Every `CP-AC-*` ID from the old `CP-AC-14` onward is renumbered up by one
(`CP-AC-14`→`15`, … `CP-AC-26`→`27`), and the new identity-moderation
criterion takes the now-free `CP-AC-14`, immediately after `CP-AC-13` where
it was already physically placed. Every cross-reference to the affected old
numbers (`CP-AC-16` → `CP-AC-17` for the Scenario-collaboration criterion,
`CP-AC-19` → `CP-AC-20` for the sole-owner-deletion criterion) is updated
at each of its call sites, not only at the declaration.

Lesson applied going forward: a full document re-read remains necessary
after any structural insertion, even when the change appears narrowly
scoped — a targeted fix for one reviewer's finding can introduce a
different, unrelated defect a narrower check will not catch.

Also closes a versioning-hygiene gap: §0.7 and §0.8 were both applied
without bumping the header version past `1.4`, so a sibling citing
"Creator Profile v1.4" could not tell whether it had those fixes. The
header now reads `1.5` and accounts for §0.7, §0.8 and this section
together, rather than leaving three fix passes unversioned.

### 0.10 v1.5 → v1.6: closes the moderation-overlay integration gap

A round-4 cross-document review confirmed a real blocking gap:
`IdentityFieldModerationOverlay` (§16.1) defined a shape and a rule that
public projections should read from it, but neither this document nor
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` actually wired it into any
public-facing field list, and several lifecycle mechanics (seeding,
migration, atomicity, revision authority, avatar clearing,
`expired`/`revoked` interaction) were left entirely unaddressed. This
revision:

1. strengthens §16.1 into an explicit cross-surface requirement: every
   surface displaying this account's identity, once an overlay row exists,
   MUST read `displayName`/`avatar` from it — not only the public card, but
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s baseline Public User Projection
   too, tracked as the new **`CP-D20`**, since this document cannot
   unilaterally accept that requirement on the sibling's behalf;
2. adds §16.2, naming the overlay's open lifecycle questions explicitly
   (seeding, migration, atomicity, revision authority, avatar clearing,
   `expired`/`revoked` interaction) as the new **`CP-D19`**, rather than
   letting §16.1's shape imply they were already decided;
3. adds both decisions to §21's list, §21.2's tracking table, §22.1's
   Approval gate (noting `CP-D20` can only be *deferred*, not *accepted*,
   from this document's side alone), and widens the `CP-05`/`CP-06`
   roadmap rows to name the overlay's wire contract and lifecycle
   explicitly rather than leaving them implied by §16 alone;
4. corrects §23's ownership table: it previously stated
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` "owns... the base Follow relationship
   (`FollowRef`)" as if that were already settled — Follow remains an open
   joint decision (`PP-D44`/`VP-D12`/`PCP-D02`), so the bullet now says
   Viewer *proposes*, not yet *owns*, that contract, separated from the
   Block/Mute mechanics that genuinely are settled and unchanged;
5. fixes §0's precedence-order item 4, which listed "the Review contract"
   alongside the genuinely Approved `SCENARIO_CONNECTED_PLANNING_SPEC.md`
   without noting the Review contract is not yet approved — both examples
   are now explicitly marked illustrative/future;
6. reclassifies `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` in the "Canonical
   supporting sources" list from a bare "sibling" to the same `ManagedPage`-
   peer language §0's main text already uses, closing a residual
   inconsistency within this document's own §0.

### 0.11 v1.6 → v1.7: default publish-trust and reactive moderation (product decision)

The product owner made an explicit policy decision: a verified Creator's
content publishes immediately by default, and moderation is reactive
(report-triggered) rather than a pre-publication gate — extending §16's
existing `about`/`city` pattern to Create content generally. Adds §9.4 as
the target mechanism (default `publish.<type>.direct` grant,
`suspendedAfterModeration` as a new per-item lifecycle state distinct from
`AccountStatus`/card `quarantined`, moderator resolution outcomes) and adds
`CP-D21` for the mechanism's abuse-prevention parameters (auto-suspension
threshold, rate-limiting, appeal SLA), which the product decision does not
itself specify and which this document is not positioned to invent
unilaterally — a reactive mechanism that can be triggered by an
unauthenticated or unlimited report signal would itself become an abuse
vector (silencing a legitimate Creator via report-bombing), so `CP-D21`
is treated as blocking this specific mechanism's production readiness even
though the mechanism's existence is accepted.

### 0.12 v1.7 → v1.8: correction — a report alone must never restrict publication

The product owner corrected §0.11's mechanism immediately after it shipped:
**a report must never restrict publication by itself.** Publication is
restricted only after moderation has reviewed and confirmed the report.
v1.7's design — the report itself auto-suspending the item pending review
— was exactly the abuse vector v1.7's own `CP-D21` had already flagged as
a risk (report-bombing to silence a legitimate Creator), just not yet
acted on. This revision removes the automatic step entirely:

1. A report enters a moderation queue and does not change the item's
   lifecycle state; the item stays fully `published` for the entire
   review period, with no interim/automatic restriction of any kind;
2. only a moderator's **upheld** decision transitions
   `published → suspendedAfterModeration`; a **dismissed** report leaves
   the item unchanged;
3. `CP-AC-25`/`CP-AC-26`, the test matrix and the roadmap's `CP-04` row
   are corrected to match;
4. `CP-D21` is narrowed from "abuse-prevention floor / auto-suspension
   threshold" (now moot — there is no automatic suspension step to
   threshold) to moderation queue SLA and the appeal path for an upheld
   decision — quality/trust parameters, not a safety gate, since the item
   remains live throughout review regardless of how `CP-D21` resolves.

### 0.13 v1.8 → v1.9: `PP-D16` transfer status and sibling snapshot

Professional Page v2.27 marked `PP-D16` Accepted but left older prose in
its decision definition and §22.3 calling move-versus-copy open. That made
this document's prior fail-closed rule internally defensible but stale
against the owning document's decision table. Professional Page v2.28 now
closes the mismatch: transfer is an explicit audited, move-only
`PublisherRef` change; copy is a separate destination-initiated duplicate;
co-host remains a separate scoped grant. §12, `CP-AC-21` and the test matrix
now consume that accepted target model while retaining the separate rule
that no runtime affordance ships without an Approved bounded slice.

The verified-against snapshot is also refreshed to Viewer v1.15, Public
Creator v1.9 and Professional Page v2.28. A version mismatch is consistently
treated as a maintenance signal requiring targeted re-verification, not both
a mandatory same-change defect and an expected non-defect.

## 1. Product definition

`Creator Profile` is the product/UI name for the verified-Creator-specific
capability set layered on the same account `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`
already defines. It is **not a new domain aggregate** — it is built from the
already-accepted `User` account, the accepted personal profile fields
(`S2-EXP-01`) and `CreatorVerification`. This document proposes no new
persisted aggregate; §4.2 proposes only additive optional fields.

Creator Profile is a **presentation/aggregation surface**, not an owner of
state: it never stores Favorites, Scenario, Visit History or Booking data
itself — it collects projections from their own canonical aggregates
(`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2) and provides entry points into
them and into Created content (this document's own §9).

Creator Profile is simultaneously:

- the entry point to Creator verification and its states;
- the personal publisher context — where a `{type: user}` Create draft
  resolves its publisher and, once eligible, is submitted/published;
- the account's Created-content management surface (edit/archive/unpublish
  where the content's own lifecycle allows it);
- the bridge to any Professional Page this account manages
  (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`).

It is not:

- a fourth global role or a `Pro`/`Pro generator` tier by itself;
- a second Create system;
- a `ManagedPage`, `Place`, Event, Booking or CRM aggregate;
- a team or multi-member surface — one account, one accountable person;
- the owner of Favorites, Visit History, Saved Searches, My participation,
  Photos or Reviews-authored — those belong to
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` (§23);
- the owner of the public-facing field list — that belongs to
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` (§23);
- an authorization shortcut based on display name, verified-badge presence
  or active tab.

## 2. Full-release extension policy

A capability is retained in the target scope when all of the following are
true:

1. It solves a recurring verification or personal-publishing job.
2. It reuses accepted aggregates, repositories and the shared Create engine.
3. It is provider-neutral and can degrade honestly when offline or
   unavailable.
4. It does not silently broaden access, collect sensitive data or create a
   new source of truth.
5. It can be delivered behind a bounded flag with tests and rollback.

| Class | Meaning |
|---|---|
| Release foundation | Required to make Creator Profile coherent and safe |
| Mature extension | Valuable for full release and suitable for incremental, reversible slices |
| Gated expansion | Retained in target architecture but blocked on backend, legal, moderation or operational readiness |

## 3. Canonical identity and publisher model

### 3.1 Two distinct facts: identity versus permission

```text
Viewer = authenticated active User

VerifiedCreatorIdentity =
  Viewer
  + CreatorVerification.status == verified

canPerformPersonalAction(type, action) =
  VerifiedCreatorIdentity
  + exact capability for that action/type
    (create.<type> | submit.<type> | publish.<type>.direct — §7)
  + current access revision
  + target aggregate lifecycle permits the action
```

`VerifiedCreatorIdentity` and `canPerformPersonalAction` are deliberately
different: an account is "a Creator" once `CreatorVerification.status ==
verified` — that identity fact does not by itself say anything about which
Create types the account may act on. The common case is:

```text
VerifiedCreatorIdentity == true
  + zero or partial per-type capability grants
    (e.g. create.event granted, create.route not granted)
```

Such an account opens Creator Profile normally — verification succeeded —
but each Create-type entry point independently evaluates
`canPerformPersonalAction`. An ungranted type MUST render an explicit
restricted state (`"not available for your account"`), never a silently
disabled control indistinguishable from a not-yet-loaded one, and MUST NOT
be inferred as available from `VerifiedCreatorIdentity` alone (`CP-AC-04`).

There is no separate "open the workspace" gate: every authenticated Viewer
already owns exactly one personal workspace by construction
(`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §3.2/§3.3).

Persisted global roles remain only `User | Creator | Admin`. `Pro` and `Pro
generator` MUST NOT be stored roles, workspace types, publisher types or
authorization inputs (ADR 0015 §4).

**`currentRole` versus `VerifiedCreatorIdentity`.** `UserProfile.currentRole`
(§4.1) is a read-only presentation summary sourced from the authoritative
access snapshot (`IDENTITY_PUBLISHER_SLICE_SPEC.md`'s own contract) — not a
value this document derives from verification history itself, and not
necessarily equal to "Creator iff verified": the `Admin` value in particular
is never a product of Creator verification at all, and the priority rules
for when an account is simultaneously e.g. an `Admin` and a verified
Creator belong to that Identity contract, not to this document. `currentRole`
is **never** checked for authorization here. Every authorization decision in
this document computes `VerifiedCreatorIdentity` live from
`CreatorVerification.status == verified` (§3.1) as an independent input,
regardless of what `currentRole` currently displays; if the two ever appear
to diverge, `CreatorVerification.status` is authoritative for this
document's own decisions, and any correction to `currentRole`'s display
value is the Identity contract's responsibility, not this document's.

### 3.2 Actor, owner, author, publisher and collaborator are distinct facts, not a fixed headcount

A Create draft/published item can involve several distinct facts, and this
document's own publisher-resolution logic (§9) depends on keeping them
distinct. This is not a claim that exactly five people are always involved:
`publisher` may name a `ManagedPage` rather than a person, and `author`/
`collaborator` are not necessarily singular.

| Role | Meaning | Example |
|---|---|---|
| `actor` | Who executed the specific command right now | The user who clicked "Submit" |
| `owner` | Who the draft/local state belongs to before publication | The Viewer who started the draft |
| `author`/`contributor` | Who materially created the content | Same user, or a co-author on a future collaborative type |
| `publisher` | Whose identity the published item is attributed to (`PublisherRef`) | `{type: page, id: pageA}` |
| `collaborator` | Who may edit this specific item going forward, per that item's own access grant (§10) | A Scenario `editor` per `ScenarioAccessGrant` |

These do not collapse into one another. A concrete failure mode this
document explicitly excludes: a Viewer **authors** an Event but **publishes**
it under Page A's `PublisherRef` — that Event MUST NOT appear in the
account's own Created-content list (§9) as a `{type: user}` publication,
because the account is its author/actor, not its publisher (`CP-AC-05`). The
account's Created-content list is scoped strictly to items whose
`PublisherRef.type == user` and `id == userId` — never to everything the
account happened to author.

### 3.3 Personal workspace

```text
WorkspaceRef { type: personal, id: userId }
```

Exactly one personal workspace exists per account, is permanent, and is
neither created nor destroyed by the user. Switching the active workspace to
a Professional Page (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §3.2) does not
close the personal workspace — only the Create Hub's default publisher
changes.

### 3.4 Publisher

```text
PublisherRef {
  type: user | page,
  id: ULID/UUID
}
```

The contract from ADR 0015 §5, restated:

- Personal workspace defaults a new draft to `{type: user, id: userId}`.
- An existing draft keeps its persisted publisher after workspace switching.
- If the account also manages one or more Professional Pages, ambiguous
  eligibility requires an explicit `Publish as` choice.
- Publisher display snapshots never authorize actions.
- Admin tools have no publisher mapping.

### 3.5 Personal mutation decision

Two distinct paths, not one formula stretched to cover both:

```text
Ordinary mutation (new draft, submit, publish, edit of a live field):

authenticated and active actor
AND verified Creator when the action requires Creator authority
AND required exact capability is present (§7)
AND access snapshot/revision is current
AND target aggregate lifecycle permits the action
AND command is valid and idempotent
```

```text
Obligation-continuity exception (§5.4's shared floor — cancel/unpublish,
respond to an existing Booking/registration obligation, archive):

authenticated session, not blocked by an AccountStatus exception that
  specifically withholds this action (VIEWER_PROFILE_FUNCTIONAL_SPEC.md
  §15.1 owns that exception list — this document does not invent one)
AND target aggregate lifecycle permits the action
AND command is valid and idempotent
// no VerifiedCreatorIdentity check, no §7 capability check, and critically
// no blanket "active" AccountStatus requirement — these actions close or
// service an existing obligation and remain available even when
// verification has been lost (§5.4) or the account is securityLocked,
// suspended or deletionPending, which both the ordinary-mutation formula
// above and a naive "active actor" gate would otherwise incorrectly block
```

UI/router guards improve UX. Application use cases enforce the decision, and
the production backend repeats it. Unknown or stale authority fails closed.

## 4. Domain contracts and invariants

### 4.1 Accepted core entities

`UserProfile` below is the target semantic model (`S2-EXP-01`'s field set;
current code implements the narrower `ProfileEditableEntity`, §0.3).
`CreatorVerification` below is quoted exactly from the **Approved**
`IDENTITY_PUBLISHER_SLICE_SPEC.md` §6.1 — this document adds nothing to it
and removes nothing from it:

```text
UserProfile {
  userId, displayName, about?, city?, avatar?,
  email,          // read-only projection
  currentRole,    // read-only projection: User | Creator | Admin
  revision, schemaVersion
}

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

`level: identityDocument` is the only Approved verification level today;
this document does not propose additional levels. `decisionReasonCode` is
present on the Approved entity but its exact value set and visibility rules
(owner-only vs. also-Admin) are not fixed by that spec either — tracked here
as `CP-D17`.

**Evidence and reviewer notes are not part of this entity.** They are
explicitly out of scope for the client/mobile-facing projection and belong
to a server-private moderation record this document does not model —
`CreatorVerification` above is the full accepted shape; nothing narrower or
wider should be assumed.

`UserProfile` and `ManagedPage` remain different aggregates — a
display-name change cannot reassign content ownership, and personal profile
fields can never become a `ManagedPage` identity.

`displayName`/`avatar` moderation for a `VerifiedCreatorIdentity` account
is not modeled on `UserProfile` itself — it lives in the separate
`IdentityFieldModerationOverlay` entity (§16.1), so a plain Viewer's base
`UserProfile` remains exactly `S2-EXP-01`'s unmoderated shape.

### 4.2 Proposed profile extension

`headline` and `specialtyTagIds` are moderated fields (§16) and are typed as
`ModeratedField<T>` here — not raw values — so this entity is the actual
home of `ownerDraftValue`/`lastApprovedPublicValue`/`moderationStatus`
rather than leaving §16's wrapper unattached to any real field:

```text
CreatorProfileExtension {
  userId,
  headline: ModeratedField<String>?,
  specialtyTagIds: ModeratedField<List<CategoryId>>,
  portfolioMediaIds,
  modulePreferences,
  revision, schemaVersion
}
```

Introduced additively through an Approved slice. Unknown/newer fields must
round-trip without downgrade. Verification evidence, email and phone never
belong in the public projection.

`followerVisibilityPolicy`, `publicContactPolicy` and `socialLinks` are
**not** fields of this entity. They configure what the *public card* shows,
not this account's own workspace, and are owned by
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.2's `PublicCreatorProfileConfig`
— this document only links to that entity by `userId`, never redefines it.

### 4.3 Invariants

1. All entity relations use permanent IDs, never display names.
2. Page membership/capability never grants personal authority, and personal
   capability never grants page authority
   (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §4.3(2)).
3. Having a personal workspace open is not itself Creator verification
   evidence.
4. Specialty tag, headline and module preference never grant a capability.
5. Enabling a personal module never creates a new domain aggregate or Create
   type.
6. Creator verification and any Professional Page's own verification are
   independent facts.
7. **A personal Scenario is Viewer-owned planning state, not a
   publisher-bound catalog object** — an authenticated Viewer may create,
   edit and save it without Creator verification or a `PublisherRef`
   (`IDENTITY_PUBLISHER_SLICE_SPEC.md` §10, verbatim principle). It never
   silently acquires one because the account later becomes `verified`;
   acquiring one always happens at the explicit "Create durable draft"
   stage (§9.1) — never earlier (personal planning) and never deferred to
   submit, which requires a `PublisherRef` to already be present.
8. Published personal content has an explicit publisher and actor audit
   trail, and `actor`/`author` are never substituted for `publisher` in a
   Created-content list (§3.2).
9. Verification rejection/revocation fails closed for future privileged
   mutations that require Creator authority, but does not retroactively
   revoke already-published content's standing without going through §5.4's
   restricted-maintenance rules, and does not block Viewer-level personal
   planning at all (§9, §5.4).
10. Local/mock state never claims production verification.

## 5. Creator verification lifecycle

### 5.1 Verification request

Any authenticated Viewer may start verification — ADR 0015 §3 and
`IDENTITY_PUBLISHER_SLICE_SPEC.md` make this available to Viewers generally,
not gated behind a separate capability that could silently withhold entry
from an ordinary Viewer. The flow asks for minimum required identity
evidence, creates an audited `CreatorVerification` record and starts the
applicable review flow. ADR 0016 local/mock behavior is a
product-validation exception, not proof that a `pending`/local `verified`
state may be presented as verified in production.

### 5.2 States

```text
notStarted → pending → verified
                     ↘ rejected → pending   (resubmission, §5.3)
verified → expired → pending   (resubmission, §5.3)
verified → revoked
```

A personal profile has no separate `draft|pendingReview|active|suspended|
archived` lifecycle of its own — it exists for as long as the account
exists (account-level lifecycle is `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s
subject). A verification badge displays only a safe projection; evidence
remains private and out of this document's model (§4.1).

### 5.3 Appeal and re-submission

- A `rejected` verification MAY be resubmitted; each submission is a new
  audited cycle, not a silent overwrite of the rejection record.
- `verified` MAY carry `expiresAtUtc`; expiry auto-transitions to `expired`.
- `revoked` is a moderator-initiated terminal state distinct from `expired`.

Exact appeal window and re-review timing: `CP-D04`.

### 5.4 `expired` versus `revoked`: same block, different trust posture

A blanket restricted-maintenance state for both `expired` and `revoked` was
too coarse: the two states arise for materially different reasons —
`expired` is routine (a re-verification cadence lapsed); `revoked` may
follow fraud, impersonation, abuse or a security decision. Treating them
identically risks either being unsafely permissive on `revoked` or
unnecessarily punitive on `expired`.

This document commits to the following **shared floor**, true regardless of
reason:

| Action on already-published `{type: user}` content | Allowed? |
|---|---|
| View own published content | Yes |
| Cancel/unpublish | Yes — closing an obligation is never blocked |
| Respond to an existing Booking/registration obligation | Yes, per the content aggregate's own contract |
| Archive | Yes |
| Create a **new durable publisher-bound draft**, or **submit**/**publish** (§9's `create.<type>`/`submit.<type>`/`publish.<type>.direct` stages) | No |
| **Personal planning** — create/edit/save a private Scenario, prepare a local pre-verification draft (§9's `Prepare local draft` stage) | **Unaffected** — this stage requires no verification at all (§4.3(7)) and is never blocked by verification loss |

Beyond that floor, whether `revoked` additionally restricts non-substantive
edits, contact-info changes or communication with existing participants —
things `expired` should very plausibly still allow — is a moderation-policy
question this document cannot resolve unilaterally. It requires a
`reason code (decisionReasonCode) × restriction` matrix, tracked as
**`CP-D16`**, not invented here. Until `CP-D16` resolves, an implementation
MUST apply the stricter (`revoked`-level) restriction set to both states
rather than guess a permissive default for `revoked`.

## 6. Specialty classification

`specialtyTagIds` and `headline` are the personal analogue of `ManagedPage`'s
service category / `customActivityLabel`
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §6):

- MUST NOT silently add a `creator` value to `ContentType`, duplicate the
  28/530 category catalog, or drive Create validation;
- a custom headline is moderated for impersonation, abuse and misleading
  claims (moderation matrix: §16);
- absence of a perfect specialty tag never blocks draft creation;
- specialty tags never grant modules, capabilities, verification or
  Discover placement.

## 7. Capabilities — the Approved namespace, not invented codes

```text
module preference = what this surface wants to show/use
capability = what the account is authorized to do
feature flag/entitlement = what the environment/account may access
policy/readiness = whether the operation is currently safe and supported
```

This document does not invent capability codes. Per
`IDENTITY_PUBLISHER_SLICE_SPEC.md` §10, the Approved semantic namespace is:

| Capability | Gates |
|---|---|
| `create.<type>` | Creating a durable, publisher-bound draft for that Create type |
| `submit.<type>` | Submitting that draft to moderation |
| `publish.<type>.direct` | Publishing directly, without moderation, where explicitly trusted |
| (none) | Personal planning / local pre-verification draft save — requires only an authenticated Viewer, no capability at all (§4.3(7)) |
| (none) | Starting Creator verification itself (§5.1) — requires only an authenticated Viewer |

Exact wire codes for `create.<type>`/`submit.<type>`/`publish.<type>.direct`
remain versioned by `IDENTITY_PUBLISHER_SLICE_SPEC.md`'s own implementation
slice — **not** `CP-D13`, which is scoped only to this document's entity
field names/schema (§4.1, §4.2). A role name alone never authorizes an
operation.

**Edit/archive/unpublish is not part of this namespace.** Per-type
authorization for editing, archiving or unpublishing an already-published
item belongs to that Create type's own aggregate contract (lifecycle rules,
ownership check), not to `create.<type>`/`submit.<type>`/
`publish.<type>.direct` — this document does not define a fourth
capability code for it.

| Module/surface | Delivery class | Boundary |
|---|---|---|
| Verification console | Release foundation | Submission, status, safe badge projection |
| Personal publisher context | Release foundation | `{type: user}` draft/publish resolution in Create Hub |
| Created-content management | Release foundation | Edit/archive/unpublish of `{type: user}`-published items only (§3.2), authorized by each item's own aggregate contract, not this section's namespace |
| Professional Page bridge | Release foundation | Workspace switch entry points, `Publish as` |
| Portfolio/media | Mature extension | Upload/rights only — display owned by `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` |
| Basic analytics | Mature extension | Aggregated privacy-safe personal Created-content measurements |
| Monetization/tips/payouts | Gated expansion | Separate legal, financial and backend decision |

Core navigation cannot be disabled by module preferences. Disabling a module
must not delete its data or hide unresolved obligations (§5.4).

## 8. Information architecture

Creator Profile adds no separate top-level navigation. The accepted personal
navigation (`Home · Favorites · Smart Search · Notifications · Profile`,
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`) is unchanged; Creator tools appear
inline once verification and grants permit them (ADR 0015 §2–§3).

## 9. Create Hub, publisher context and content ownership

Same ten Create types and Quick Plan carve-out as
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §9.

### 9.1 The Approved four-stage flow, not one universal guard

`IDENTITY_PUBLISHER_SLICE_SPEC.md` §10 defines four distinct stages with
different requirements — this document uses that table directly rather than
one blanket "save/submit/publish" guard:

| Stage | Personal publisher requirement |
|---|---|
| **Prepare local draft** | Authenticated Viewer only — no verification, no capability. Covers both personal planning (a private Scenario) and a local pre-verification publishable draft. |
| **Create durable draft** | Verified Creator + `create.<type>` |
| **Submit to moderation** | Verified Creator + `submit.<type>` |
| **Publish directly** | Verified Creator + explicit trusted `publish.<type>.direct` |
| Edit/archive an existing item | Ownership/capability + that item's own lifecycle rules |

A personal Scenario that never leaves the "Prepare local draft" stage never
touches this document's verification/capability gates at all — it is
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s subject end to end (§4.3(7)).

### 9.2 Draft and publisher rules

1. Resolve authenticated actor and current access snapshot.
2. Validate active workspace without treating it as authority.
3. Resolve eligible personal/page publishers.
4. Default only a new durable draft to `{type: user, id: userId}` from the
   personal workspace — never a local/personal-planning draft, which has no
   publisher at all until it explicitly reaches "Create durable draft".
5. Persist `PublisherRef` and the acting user ID as `actor` (§3.2) — never
   conflate the two.
6. Require `Publish as` when a Professional Page is also eligible.
7. Revalidate the required exact capability for that Create type and stage
   (§9.1) on save/submit/publish.
8. Preserve an existing draft's publisher after workspace changes.
9. If Creator verification is revoked or expires, apply §5.4's shared floor.

**Local-to-durable conversion is idempotent.** The "Create durable draft"
transition (§9.1) MUST assign the permanent draft ID exactly once: a retry
of the same conversion command after a failed/uncertain prior attempt MUST
NOT create a second durable draft, and the local pre-conversion copy MUST
remain intact and re-attemptable until the conversion is confirmed
successful.

### 9.3 Created-content list scope and lifecycle

The account's own "Created" list contains exactly the items where
`PublisherRef == {type: user, id: userId}` — never items the account merely
authored/actor'd under a different publisher (§3.2, `CP-AC-05`). Content
published via a Professional Page appears in that page's own Content list
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §8.1), not here.

For content-management UX, the list distinguishes at least these lifecycle
states (each already implied by §9.1's stages plus each Create type's own
lifecycle, made explicit here rather than left only as an attribution
filter):

```text
durableDraft | pendingModeration | rejected | published | unpublished
| suspendedAfterModeration | archived
```

Exact per-type mapping of these states onto that Create type's own lifecycle
enum is owned by that type's own spec, not invented here.

### 9.4 Default publication trust and reactive (report-triggered) moderation

**Target product decision, accepted:** for a `VerifiedCreatorIdentity`
account, the default publish path is `publish.<type>.direct` (§7),
**not** `submit.<type>` — a verified Creator's content goes live
immediately on publish, without a pre-publication moderation queue. This
is not a change to the Approved capability namespace itself
(`IDENTITY_PUBLISHER_SLICE_SPEC.md` §10 still defines both codes and their
meaning); it is a target policy for which capability a verified Creator is
granted by default. `submit.<type>` (pre-publication queue) remains the
actual path only for an account whose specific grants are narrower than
the default (§3.1's partial-grants case — e.g. an account explicitly
limited to `submit.event` without `publish.event.direct`).

Moderation for a verified Creator's content is therefore **reactive, not
proactive** — the same principle §16 already applies to `about`/`city`,
now extended to published `{type: user}` Create content generally. **A
report never restricts publication by itself — only a moderator's
confirmed decision does.** This is a deliberate correction from an earlier
draft of this section, which had the report itself auto-suspend the item
pending review; that was rejected as unsafe, because a mechanism that
restricts publication on the strength of an unreviewed report is itself an
abuse vector (report-bombing to silence a legitimate Creator), regardless
of any rate-limiting layered on top of it:

1. The item publishes immediately and appears in the Created-content list
   (§9.3) and, once its own public-visibility rules allow it, on the public
   card (`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4).
2. A report against that specific item (not the whole card — a narrower,
   per-item mechanism than `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
   §7.3's card-level Report) enters a moderation queue. **It does not
   change the item's lifecycle state.** The item remains `published`,
   fully visible, for the entire duration of the review — there is no
   automatic or interim restriction while a report is merely pending.
3. A moderator reviews the report's legitimacy against that Create type's
   own content policy. Two outcomes only:
   - **Dismissed** — no state change; the item was never restricted and
     nothing about it changes.
   - **Upheld** — only now does the item transition, `published →
     suspendedAfterModeration`: hidden from the public Created-content
     list and from that Create type's own public listing/Discover
     surfaces, but still visible and editable by the owner, and never
     silently deleted. A stronger action (`rejected`-style removal)
     remains that Create type's own contract to define, for a severity
     that warrants it.
4. The account is **not** otherwise restricted at any point in this flow —
   the owner may continue creating new drafts and publishing other content
   normally throughout; any restriction that does occur (step 3, upheld
   only) is scoped to the one reported item, distinct from `AccountStatus`
   (owned by `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`) or the whole-card
   `quarantined` state (owned by
   `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.5) — neither of which
   this mechanism triggers by itself.

**What this document does not resolve, tracked as `CP-D21`:** moderation
queue prioritization and target SLA (how quickly a report must be
reviewed, given the item stays live until then), the appeal path for an
upheld `suspendedAfterModeration` decision, and whether a pattern of
repeatedly-dismissed reports against the same reporter affects how future
reports from them are queued. The original auto-suspension-threshold
question this decision tracked is now moot — there is no automatic
suspension step left to threshold.

## 10. Aggregate-level collaboration is not a profile concern

Collaboration grants belong to the **aggregate**, not to any profile
document. For **Scenario**, this is not an open question — it is an
**Approved execution contract**:

```text
ScenarioCollaborationRole = owner | editor | viewer | unlistedViewer
  (semantic role Approved: SCENARIO_CONNECTED_PLANNING_SPEC.md v1.1 §10.1/
  §10.2, table label "unlisted viewer". That source declares no Dart-level
  enum; this document renders it as unlistedViewer — camelCase, one token,
  consistent with its three single-token neighbors rather than mixing a
  two-word phrase into a code-style declaration. This is a Direction, not
  yet Accepted/propagated into the owning Scenario contract — see
  `docs/product/PROFILE_DOCUMENTS_INDEX.md` §6.1; `CP-AC-17` requires this
  document to match VIEWER_PROFILE_FUNCTIONAL_SPEC.md's own rendering,
  which already uses this same casing)

ScenarioAccessGrant {
  id, scenarioId, subjectUserId, role, status,
  grantedByUserId, grantedAtUtc, revokedAtUtc?, revision
}
```

| Role | Read | Edit content | Invite | Share/publish | Manage access |
|---|---|---|---|---|---|
| `owner` | yes | yes | yes | per capability | yes |
| `editor` | yes | yes | no by default | no | no |
| `viewer` | yes | no | no | no | no |
| `unlistedViewer` ("unlisted viewer" in product-facing text) | safe revision only | no | no | no | no |

A Scenario collaboration role does not replace `User`/`Creator`/`Admin` and
does not grant publisher capabilities — it is a resource-scoped access
grant.

For **Quick Plan**, no equivalent accepted collaboration contract was found
in canonical sources; its collaboration model remains genuinely open
(`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s tracked decision) and this document
does not invent one for it. A future co-host contract on another Create
type, if ever added, would carry its own separately-decided scoped grant —
not implied by anything in this section.

Creator Profile's only obligation here is boundary-preserving: it MUST NOT
introduce a second, profile-level collaboration/capability model that
duplicates or overrides an aggregate's own grants
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §4.3(2)'s "Page A never authorizes
Page B" principle, generalized: no surface's grant list authorizes another
aggregate's action).

## 11. Visibility, admission and participation

Content published via `{type: user}` carries the same admission/Booking axes
as content published via a Professional Page — it is the same Create
aggregate regardless of publisher type
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §10). The state-family separation
table (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §10.1) applies unchanged.

## 12. Relationship to Professional Pages

- One Creator MAY manage zero, one or many Professional Pages
  (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §5.1); none of that changes this
  account's own verification, `UserProfile` fields or Created-content list.
- Losing all Professional Page memberships never affects Creator
  verification status, and losing Creator verification never removes
  existing page memberships (§4.3(6)) — though it does block acting as
  personal publisher per §5.4.
- **Content transfer between `{type: user}` and a page publisher reuses the
  accepted `PP-D16` target model; it is not a Profile-owned mechanism.**
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.28 §22.3 defines transfer as an
  explicit, audited, move-only `PublisherRef` change. Copy is a separate,
  destination-initiated duplicate, and co-host is a separate scoped grant;
  none may be produced by switching workspace. This accepted Draft-level
  product decision still does **not** authorize a runtime affordance:
  implementation requires its own Approved bounded slice and capability/
  audit contract, per §0.3.

## 13. Booking, tickets and payments

Identical honest-fallback and internal-Booking rules as
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §13 apply unchanged — capacity, holds
and payment gating are properties of the Create aggregate, not of the
publisher type.

## 14. Security, privacy, offline and operations

- Clients cannot write roles, verification decisions or privileged
  capabilities.
- Current access revision is checked on every privileged personal command.
- Verification evidence is server-private and outside this document's
  client-facing model entirely (§4.1) — visible only through Admin
  moderation tooling this document does not define.
- Deep links revalidate authentication and exact resource ownership.
- Offline state never confirms verification or Booking.
- Age-sensitive verification and public-Creator eligibility for a minor
  account fail closed until `CP-D14` exists — this document does not itself
  decide whether a minor may become a verified Creator.

### 14.1 Operational and security requirements

Production readiness for this surface additionally requires:

- rate limits and idempotency keys on verification submission and handle
  rename (§17);
- cache invalidation triggered by verification status change and by page
  membership revocation;
- audit events with stable reason codes for every privileged mutation in
  this document (§3.5);
- a bounded retention policy for verification evidence, owned by the
  server-private moderation record this document does not model (§4.1);
- an appeal SLA target, tracked alongside `CP-D04`;
- a feature flag/kill switch independently covering: verification console,
  `Publish as` selector, Created-content management, portfolio upload.

## 15. Required UX states

- verification not started, pending, rejected, expired or revoked, with
  `expired` and `revoked` visibly distinct (§5.4);
- `verified` with zero/partial content-type grants (§3.1) rendered as an
  explicit restricted state per type;
- restricted maintenance mode after verification loss, with personal
  planning visibly unaffected (§5.4);
- publisher selection required (personal vs. an eligible page);
- Created-content list empty state, distinct from Favorites' empty state
  (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` owns that one);
- account deletion blocked because this account is the sole owner of a
  Professional Page that is neither `archived` nor tombstoned (§22.4);
- Admin presentation preview with no authority.

All critical flows must support en/ru/lv-ready strings, 360 dp width, 150%
text scale, keyboard/screen-reader semantics and no color-only status
meaning.

## 16. Field moderation matrix

Field state is modeled explicitly as a typed wrapper, not one
"Immediately"/"queued" flag, so the owner's own edit and the currently
public value can differ during review without contradiction:

```text
ModeratedField<T> {
  ownerDraftValue: T          — what the owner currently sees/edits
  lastApprovedPublicValue: T? — what the public card (sibling document)
                                 displays; ABSENT (not an empty/blank T)
                                 until the field's first approval ever
                                 completes — the public card renders the
                                 field as not-yet-present, never as blank,
                                 for a field that has never been approved
  moderationStatus: clear | queued | rejected
  submittedAtUtc?
  decidedAtUtc?
  decisionReasonCode?
  revision                    — required on every resubmission; a stale
                                 revision is rejected rather than silently
                                 overwriting a newer submission (§22.3's
                                 fail-closed concurrency rule, applied here,
                                 not §22.5 which covers notification
                                 recipients — a stale cross-reference an
                                 earlier revision of this document had)
}
```

| Field | Owner sees own edit immediately? | Public value updates immediately? |
|---|---|---|
| `displayName`, `avatar` (base field, owned by `S2-EXP-01`) | Yes | Yes, **unless** the account is `VerifiedCreatorIdentity` and the edit changes the identity a prior verification evidenced — in that specific case, `IdentityFieldModerationOverlay` (below) governs, not the base entity itself |
| `about`, `city` | Yes | Yes for the value itself; still subject to report/takedown (below) — "not moderated" means no pre-publication review queue, not that the field is exempt from abuse handling |
| `headline`, `specialtyTagIds` (§4.2) | Yes | No — always `moderationStatus = queued` until reviewed; public card keeps `lastApprovedPublicValue`, or the not-yet-present state on first submission |
| `CreatorVerification` submission | N/A | N/A — always a new review cycle (§5.3) |

### 16.1 `IdentityFieldModerationOverlay` — where `displayName`/`avatar` moderation actually lives

`displayName` and `avatar` are base `UserProfile` fields every account has
(§4.1) — they are **not** Creator-only, and `CreatorProfileExtension`
(§4.2) correctly does not claim them; wrapping them in `ModeratedField<T>`
directly on `UserProfile` would incorrectly imply every Viewer's identity
edits are moderated, when the review requirement applies only once an
account is `VerifiedCreatorIdentity` and only when the edit could
undermine the identity a prior verification evidenced. This document
therefore defines a **separate, additive overlay** — not a change to the
base entity, and not a field on `CreatorProfileExtension` either, since it
tracks two specific base fields rather than Creator-specific ones:

```text
IdentityFieldModerationOverlay {
  userId,
  displayName: ModeratedField<String>?,  // present only once this account
  avatar: ModeratedField<String>?,       // has been VerifiedCreatorIdentity
                                          // at least once (§3.1); absent
                                          // entirely for a plain Viewer —
                                          // there is no overlay row to have
  revision, schemaVersion
}
```

For a plain Viewer (never `VerifiedCreatorIdentity`), no overlay row exists
and `displayName`/`avatar` edits publish immediately with no queue — the
base `UserProfile` entity is authoritative end to end, exactly as
`S2-EXP-01` already specifies. For a `VerifiedCreatorIdentity` account, an
edit to either field is evaluated against this overlay: a **non-identity-
affecting** edit (e.g. `avatar` cropped/re-uploaded without changing who it
depicts) still publishes immediately; an **identity-affecting** edit (a
different name, a different depicted person) sets `moderationStatus =
queued` on the corresponding overlay entry. Exact identity-affecting-change
detection (heuristic vs. always-queue-on-any-change) is `CP-D18`, tracked
in §21.

**Every surface that displays this account's identity, once an overlay row
exists, MUST read `displayName`/`avatar` from the overlay's
`lastApprovedPublicValue` — never from `UserProfile` directly.** This is
not limited to `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s extended card:
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s baseline Public User Projection
(§12.2 there) is shown in other legitimate contexts — a Review, a Find
People response, an invited Scenario — for the same account, and a pending
identity-affecting edit MUST NOT be visible on one surface while still
showing the old value (or vice versa) on another. This document cannot
unilaterally mandate `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s implementation,
but states the requirement here as the overlay's own consistency contract;
tracked as **`CP-D20`** (§21) — until that sibling document explicitly
adopts consuming this overlay, an implementation MUST NOT treat the two
documents' identity-field display as already reconciled, and this
document's own verified-against snapshot (top of file) does not claim that
reconciliation is done.

### 16.2 Overlay lifecycle — open questions

The overlay's *shape* is defined (§16.1), but several lifecycle mechanics
are not, and MUST NOT be assumed by an implementation:

- **Seeding.** Whether a `VerifiedCreatorIdentity` account gets an overlay
  row the moment verification first succeeds (proactively seeded from the
  then-current `UserProfile` values as the implicit first
  `lastApprovedPublicValue`), or only lazily on the account's first
  `displayName`/`avatar` edit thereafter.
- **Migration.** How an account that was already `VerifiedCreatorIdentity`
  before this overlay existed acquires its first row — whether a backfill
  treats the current `UserProfile` value as pre-approved, or requires a
  fresh moderation cycle.
- **Atomicity.** Whether a `UserProfile` write and its corresponding
  overlay write are required to commit atomically (single transaction) or
  may be eventually consistent with a defined reconciliation window.
- **Revision authority.** `IdentityFieldModerationOverlay.revision` (the
  entity-level field, §16.1) and `ModeratedField.revision` (the per-field
  wrapper, §16) are two different revision counters on the same object;
  which one a client must present for a concurrency check, and how they
  relate, is unresolved.
- **Avatar clearing.** Whether removing an `avatar` entirely (reverting to
  no image) is itself an identity-affecting edit requiring moderation, or
  always publishes immediately.
- **Interaction with `expired`/`revoked`.** Whether an already-`queued`
  identity edit is still reviewed and can complete after verification
  lapses, or is held pending re-verification; §5.4's shared floor does not
  address this specific overlay field.

Tracked as **`CP-D19`** (§21). Until `CP-D19` resolves, an implementation
MUST NOT treat any of the above as decided by §16.1's shape alone.

`about`/`city` publish without a pre-publication queue, but — because
`about` is free text that becomes public — they remain subject to
post-publication report/takedown and automated safety checks (impersonation,
external contact info, abuse, prohibited content) exactly like `displayName`/
`headline`, just without blocking the initial publish on review completion.
A rejection carries `decisionReasonCode` and MAY be resubmitted, mirroring
§5.3's verification resubmission pattern.

An impersonation report on `displayName`/`headline` follows the same
audited report flow as `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D25`; this
document does not duplicate that flow.

## 17. Handle and deep links (personal-management half)

- `userId` is the only identifier used for authorization or content
  ownership; a display handle, if `CP-D03` accepts one, is a display
  convenience only.
- Rename mechanics — uniqueness check, reservation/reuse window after
  release, forbidden/reserved-name rejection, Unicode/confusable-character
  protection, rate limit/cooldown between renames, and whether renaming
  during active verification is permitted — are this document's concern,
  expanded and tracked as `CP-D03`.
- **Resolution and redirect behavior of an existing public link** —
  including what a redirect reveals about a public→private visibility
  transition — is `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s concern
  (§23).

## 18. Delivery roadmap

| Slice family | Scope | Class | Key dependency |
|---|---|---|---|
| IDP-04A completion | Canonical `PublisherRef{type:user}` for the remaining nine Create types | Release foundation | Stabilization exit, Auth/Platform |
| CP-01 Verification console | Submission, status, appeal/re-review UX, partial-grants rendering, `expired`/`revoked` distinction | Release foundation | Backend authority |
| CP-02 Personal publisher context | `Publish as`, four-stage draft/publisher resolution (§9.1) across all ten types | Release foundation | IDP-04A completion |
| CP-03 Created-content management | Edit/archive/unpublish scoped to `{type:user}` only | Release foundation | CP-02 |
| CP-04 Restricted maintenance mode | §5.4 shared floor; `CP-D16` reason-code matrix once decided; §9.4's moderator-confirmed-only reactive-moderation mechanism and `CP-D21`'s queue SLA/appeal path | Release foundation | CP-01 |
| CP-05 Wire contract | Exact field names/schema for `UserProfile`, `CreatorVerification` client projection, `CreatorProfileExtension`, `IdentityFieldModerationOverlay` | Release foundation | `CP-D13`, `CP-D19` |
| CP-06 Moderation and audit | Field moderation matrix (§16), `IdentityFieldModerationOverlay` lifecycle (§16.2) and cross-surface consistency (§16.1), audit events, appeal SLA | Release foundation | CP-01, `CP-D18`, `CP-D19`, `CP-D20` |
| CP-07 Cache and revocation propagation | Cache invalidation on verification/membership change (§14.1) | Release foundation | CP-01, `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` |
| CP-08 Portfolio rights | Upload/license confirmation feeding the public card | Mature extension | Media pipeline reuse |
| CP-09 Analytics | Basic personal Created-content aggregates | Mature extension | Analytics taxonomy/privacy thresholds |
| CP-10 Legacy UI migration | Retire legacy `Pro generator` UI naming/tiering | Mature extension | CP-01 |
| CP-11 Monetization | Tips/payouts on personal content | Gated expansion | Separate ADR/business/legal gates |
| CP-12 Specialty tag adapter | `specialtyTagIds` ↔ Category System mapping (`CP-D01`) | Release foundation | `CATEGORY_SYSTEM.md` |
| CP-13 Handle/slug mechanics | Rename uniqueness, reservation, cooldown, Unicode protection (`CP-D03`) | Release foundation | CP-01 |

## 19. Acceptance criteria

### Identity, access and publisher

- **CP-AC-01:** `Creator Profile` maps only to the existing `User` +
  `UserProfile` + `CreatorVerification`; no new persisted aggregate.
- **CP-AC-02:** Opening the personal workspace requires no membership check.
- **CP-AC-03:** Active workspace defaults only a new durable draft's
  publisher; an existing draft's publisher is never silently rewritten.
- **CP-AC-04:** A `VerifiedCreatorIdentity` account with zero/partial
  content-type grants renders an explicit restricted state per ungranted
  type, never an implicit full-access assumption.
- **CP-AC-05:** The Created-content list contains only items with
  `PublisherRef == {type:user, id:userId}`; authored-but-published-elsewhere
  content never appears in it.
- **CP-AC-06:** Ambiguous publisher candidates require `Publish as`.
- **CP-AC-07:** Admin preview changes presentation only.
- **CP-AC-08:** A personal Scenario or local pre-verification draft never
  requires a capability check or `PublisherRef` for the "Prepare local
  draft" stage (§9.1, §4.3(7)).

### Verification lifecycle

- **CP-AC-09:** Verification revocation does not end the account's
  authentication session.
- **CP-AC-10:** A `rejected` verification's resubmission creates a new
  audited cycle rather than overwriting the rejection record.
- **CP-AC-11:** After verification loss, existing published content follows
  §5.4's shared floor — closing/servicing an obligation and personal
  planning are never blocked; only new durable-draft/submit/publish is.
- **CP-AC-12:** `expired` and `revoked` render visibly distinct states and
  are never presented identically to the account owner.
- **CP-AC-13:** Verification evidence never appears in this document's
  client-facing entity or projection (§4.1).
- **CP-AC-14:** A plain Viewer's `displayName`/`avatar` edits publish
  immediately with no `IdentityFieldModerationOverlay` row created; the
  overlay is created and enforced only once the account has been
  `VerifiedCreatorIdentity` at least once (§16.1).

### Boundary and collaboration

- **CP-AC-15:** This document does not define Favorites, Visit History, My
  participation, Photos or Scenario/Quick Plan lifecycle.
- **CP-AC-16:** This document does not define the public-facing field list.
- **CP-AC-17:** Scenario collaboration renders exactly the Approved
  `owner|editor|viewer|unlistedViewer` roles (§10) — never a narrower or
  wider set invented at the profile level.
- **CP-AC-18:** Quick Plan collaboration is never presented as if an
  accepted role model exists for it, pending its own open decision.

### Page relationship

- **CP-AC-19:** Losing all Professional Page memberships never changes this
  account's own verification or Created-content list.
- **CP-AC-20:** Account deletion is blocked while this account is the sole
  owner of a Professional Page that is neither `archived` nor tombstoned —
  including `draft`, `pendingReview` and `suspended`, not only `active` —
  until ownership is transferred or the page is archived (§22.4).
- **CP-AC-21:** Any personal↔page content transfer affordance reuses
  `PP-D16` exactly: explicit audited move-only `PublisherRef` change, copy as
  a separate duplicate, co-host as a separate grant, and never a workspace-
  switch side effect. Acceptance of the target decision alone does not show
  the affordance; an Approved bounded implementation slice is still required.

### Capability namespace

- **CP-AC-22:** Every capability referenced by this document uses the
  Approved `create.<type>` / `submit.<type>` / `publish.<type>.direct`
  namespace (§7); no invented code is used.
- **CP-AC-23:** Starting Creator verification requires only an
  authenticated Viewer — no capability gate blocks entry.

### Reactive moderation

- **CP-AC-24:** A `VerifiedCreatorIdentity` account with the default grant
  publishes immediately (`publish.<type>.direct`); pre-publication
  `submit.<type>` queuing applies only to an account whose specific grants
  are narrower than the default (§9.4).
- **CP-AC-25:** A report by itself never changes a content item's
  lifecycle state — the item stays `published` for the entire review
  period; only a moderator's **upheld** decision transitions it to
  `suspendedAfterModeration`, scoped to that one item, and never changes
  `AccountStatus`, never sets the whole card to `quarantined`, and never
  blocks the owner from creating or publishing other content (§9.4).
- **CP-AC-26:** A `suspendedAfterModeration` item remains visible and
  editable to its owner and is never silently deleted; it is excluded
  from the public Created-content list only from the point a moderator
  upholds the report, never merely because a report was filed.

### Quality

- **CP-AC-27:** en/ru/lv-ready labels, 360 dp and 150% text scale are
  covered.
- **CP-AC-28:** Unit, widget, integration and negative security tests are
  proportional to each slice.
- **CP-AC-29:** `flutter analyze`, `flutter test`, boundary and diff checks
  pass for every implementation slice.
- **CP-AC-30:** `LAUNCH_STATUS.md` records exact implementation evidence
  and remaining gates.

## 20. Required test matrix

- verification transitions (`notStarted→pending→verified→expired/revoked`,
  `pending→rejected→pending` resubmission) and their effect on
  submit/publish gating per §5.4's shared floor, not a blanket block;
- `expired` and `revoked` produce distinguishable UI/behavior even where
  the current shared-floor table treats them the same;
- `VerifiedCreatorIdentity` with a partial capability grant set: granted
  type opens normally, ungranted type shows the explicit restricted state;
- Created-content list excludes an item this account authored but that is
  published under a Professional Page's `PublisherRef`;
- a personal Scenario is created, edited and saved by an unverified Viewer
  with zero capability checks and no `PublisherRef` assigned;
- publisher resolution across all ten Create types at each of the four
  stages (§9.1), including when the account also manages one or more
  Professional Pages;
- existing-draft non-rewrite after workspace switch (personal ↔ page);
- Scenario collaboration renders all four roles
  (`owner|editor|viewer|unlistedViewer`) with the exact permission matrix
  from §10;
- Admin preview without authority;
- moderation-queued field (headline/specialty tag) leaves
  `lastApprovedPublicValue` visible while `ownerDraftValue` reflects the
  pending edit;
- a plain Viewer's `displayName`/`avatar` edit publishes immediately with
  no `IdentityFieldModerationOverlay` row; the same edit from a
  `VerifiedCreatorIdentity` account creates/updates the overlay and, when
  identity-affecting, queues it exactly like a Creator-extension field
  (§16.1);
- sole-owner account-deletion attempt fails closed until transfer/archive
  for each of `draft`, `pendingReview`, `active` and `suspended` Professional
  Page lifecycle states, and succeeds once the page is `archived`;
- no content-transfer affordance renders before an Approved bounded slice;
  once implemented, transfer is explicit/audited/move-only, copy is a
  separate duplicate and workspace switching never changes `PublisherRef`
  (`PP-D16`);
- a `VerifiedCreatorIdentity` account's default grant publishes a new item
  immediately (no pre-publication queue), while a narrower-grant account
  (`submit.<type>` only) still queues for moderation before it is public
  (§9.4);
- a content-item report by itself leaves the item's lifecycle state
  (`published`) and `AccountStatus`/card state/other items untouched for
  the full review period; only a moderator's **upheld** decision
  transitions it to `suspendedAfterModeration`, while **dismissed** leaves
  it `published` with no change at all; the item remains owner-visible/
  editable throughout either outcome;
- a `suspendedAfterModeration` item is excluded from the public Created-content
  list (`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.1) while owner-side
  visibility is confirmed unaffected;
- offline read, stale authority, retry and rollback;
- localization, accessibility, compact layout and deep links.

## 21. Decisions required before implementation

1. **CP-D01 — Specialty tag adapter:** exact relation between
   `specialtyTagIds` and Category System (mirrors `PP-D01`).
2. **CP-D03 — Handle/slug rename mechanics:** uniqueness, reservation/reuse
   window, reserved-name list, Unicode/confusable protection, rename
   cooldown, and whether renaming during active verification is permitted.
3. **CP-D04 — Verification appeal and expiry:** exact appeal window,
   re-review timing and target SLA.
4. **CP-D07 — Portfolio rights:** authorship/license confirmation, reuse
   across content, orphan cleanup when a portfolio item is unlinked.
5. **CP-D13 — Wire contract:** exact wire field names, storage layout and
   `schemaVersion` numbering for `UserProfile`, `CreatorVerification`'s
   client-facing projection and `CreatorProfileExtension` (§4.1, §4.2).
6. **CP-D14 — Minors as Creator:** whether an account below the local age
   of majority may ever become a verified Creator, and if so under what
   guardian-approval contract; fails closed until decided.
7. **CP-D15 — Commercial entitlements:** packaging/naming for future
   personal monetization that does not recreate `Pro` as an authorization
   role, and exactly which modules become read-only on downgrade without
   ever deleting data or removing a capability (`§4.3(4)`).
8. **CP-D16 — Verification-loss restriction matrix by reason code:** beyond
   §5.4's shared floor, exactly which additional actions `revoked` (by
   `decisionReasonCode`) restricts versus `expired`.
9. **CP-D17 — `decisionReasonCode` value set and visibility:** the exact
   code registry and whether the account owner sees it verbatim or only a
   safe category.
10. **CP-D18 — Identity-affecting-edit detection for `IdentityFieldModerationOverlay`:**
    the exact rule for whether a `displayName`/`avatar` edit is
    identity-affecting (requiring `moderationStatus = queued`, §16.1) —
    e.g. a fixed similarity/edit-distance heuristic versus always queuing
    any change once `VerifiedCreatorIdentity` is true — and whether the
    detection differs between the two fields.
11. **CP-D19 — `IdentityFieldModerationOverlay` lifecycle:** seeding on
    first verification vs. lazy creation, migration for accounts already
    `VerifiedCreatorIdentity` before this overlay existed, atomicity of
    `UserProfile`/overlay writes, the relationship between the overlay's
    own `revision` and each field's nested `ModeratedField.revision`,
    whether clearing `avatar` is identity-affecting, and how a `queued`
    edit is handled if verification lapses mid-review (§16.2).
12. **CP-D20 — Cross-surface identity-field consistency:** whether and how
    `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s baseline Public User Projection
    adopts reading `displayName`/`avatar` from this overlay once a row
    exists, so a pending identity edit cannot show differently on the
    baseline projection versus the extended Creator card (§16.1). This
    document can state the requirement but cannot unilaterally accept it
    on the sibling's behalf.
13. **CP-D21 — Moderation queue SLA and appeal path:** the target review
    turnaround for a content-item report (the item stays fully published
    throughout, so this is a quality/trust SLA, not a safety gate),
    the appeal path and process for an **upheld**
    `suspendedAfterModeration` decision, and whether a pattern of
    repeatedly-dismissed reports against the same reporter affects how
    their future reports are queued. The mechanism itself — immediate
    publish by default, no restriction until a moderator upholds a report
    — is accepted target policy (§9.4); this decision covers only its
    operational parameters, not whether reports can restrict publication
    on their own (they cannot).

### 21.1 Decisions relocated to a sibling document (not tracked here)

For traceability only — these were previously listed in this document and
are now the owning sibling's responsibility; duplicating them here would
create the same circular-approval risk this revision fixed (§0.5(9)):

| Former ID | Now owned by |
|---|---|
| Public field defaults | `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `PCP-D01` |
| Public presentation of Creator/Page relationship | `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `PCP-D05` |
| Follow model | `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `PCP-D02` |
| Reviews (both forms) | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` `VP-D08` / `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `PCP-D04` |
| Messaging | Out of this document's scope entirely |
| Account deletion/retention mechanics in general | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` `VP-D06` |
| Multi-device/session model in general | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15/§24.3 |
| Scenario/Quick Plan collaboration domain | Scenario: **resolved**, `SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1. Quick Plan: `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` `VP-D02` |

### 21.2 Decision tracking

| Decision | Status | Target slice (§18) | Owner | Gate |
|---|---|---|---|---|
| CP-D01 | Open | CP-12 | TBD | — |
| CP-D03 | Open | CP-13 | TBD | — |
| CP-D04 | Open | CP-01 | TBD | — |
| CP-D07 | Open | CP-08 | TBD | — |
| CP-D13 | Open | CP-05 | TBD | — |
| CP-D14 | Open | Not yet in roadmap | TBD | Requires legal/policy review |
| CP-D15 | Open | CP-11 | TBD | — |
| CP-D16 | Open | CP-04 | TBD | Requires moderation policy |
| CP-D17 | Open | CP-06 | TBD | — |
| CP-D18 | Open | CP-06 | TBD | — |
| CP-D19 | Open | CP-05/CP-06 | TBD | — |
| CP-D20 | Open | CP-06 | TBD | Requires `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` to adopt (§16.1) |
| CP-D21 | Open | CP-04 | TBD | Requires moderation queue/appeal policy |

## 22. Definition of Done and personal lifecycle

### 22.1 Approval gate — foundation-only, no circular dependency

This document may become **Approved** only after `CP-D01, CP-D03, CP-D04,
CP-D07, CP-D13, CP-D14, CP-D15, CP-D16, CP-D17, CP-D18, CP-D19, CP-D20,
CP-D21` are either accepted or explicitly deferred with owners and gates
(§21.2). Note that `CP-D20` is unusual among this list: this document can
state and defer it, but cannot itself accept it, since accepting it
requires `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s adoption — "explicitly
deferred with an owner and gate" is the only realistic path for `CP-D20`
from this document's side alone.

This document's Approval does **not** require any sibling document's own
gated/optional decisions (Follow parameters, Creator level, reviews-about-a-
person, minors' baseline projection, etc.) to be resolved — those are the
sibling's own release-foundation-vs-gated classification, and this
document's foundation scope (verification + personal publisher context) is
independent of them. This corrects v1.1's circular-approval risk, where
Approval implicitly depended on decisions this document does not need.

### 22.2 Verification appeal and expiry — mechanism

Resolved at the mechanism level in §5.3; the exact window (`CP-D04`) and
the reason-code restriction matrix (`CP-D16`) remain open.

### 22.3 Profile field edits and re-moderation — mechanism

The `headline`/`specialtyTagIds` mechanism is resolved in §16. The
`displayName`/`avatar` overlay's *shape* is resolved in §16.1, but its
*lifecycle* (`CP-D19`) and *cross-surface consistency* (`CP-D20`) are not —
§16.1/§16.2 define the open questions rather than closing them.

### 22.4 Sole Professional Page owner: account deletion

An account deletion request MUST fail closed while this account is the sole
`ownerUserId` of **any Professional Page that is neither `archived` nor
tombstoned** — unambiguous conjunctive phrasing, not "not archived or
tombstoned" (which parses ambiguously as `(not archived) or tombstoned`)
— and deliberately not an enumerated lifecycle list (an earlier
`active|pendingReview|draft` enumeration omitted `suspended`, which still
has an accountable owner and obligations), with:

- active Booking, payment or legal obligations
  (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-58`), or
- no completed ownership-transfer flow — ownership transfer itself is
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D03`, not §22.3 there (which
  covers content transfer/co-host, `PP-D16`, a different mechanism) — and
  no approved archive of that page.

The account MUST be offered, not silently blocked without a path: (a)
transfer ownership, or (b) archive the page, before deletion can proceed
(`CP-AC-20`).

### 22.5 Notification recipients

Creator-tier notifications (verification status change, content moderation
decision on `{type:user}` content) route only to the account owner and are
a **distinct category** from `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s personal
notifications. The two MUST NOT duplicate the same underlying event into two
inbox entries; exact dedup ownership is `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s
tracked routing decision, referenced not re-decided here.

## 23. Relationship to the sibling documents

This document reuses, rather than restates independently, every invariant
that does not depend on the verification/publisher distinction:
`PublisherRef`, the fail-closed mutation principle, the state-family
separation and the Booking honesty rules are the same contract across all
three sibling documents by design.

Explicit non-overlap:

- **`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`** owns: Scenario, Quick Plan,
  Favorites, Saved Searches, Smart Search history, Visit History, My
  participation, Reviews-authored, Photos, `AccountStatus`, general
  session/multi-device state, minors' baseline projection (`VP-D10`), the
  minimal Public User Projection shown to every account regardless of
  Creator status, and full Block/Mute mechanics (bidirectional Block,
  one-directional Mute) — including their effect on card visibility in
  both directions, not only what one document's own card shows. It
  **proposes**, but does not yet unilaterally own, a base Follow
  relationship (a `FollowRef` shape) — Follow remains a joint decision
  (`PP-D44`/`VP-D12`/`PCP-D02`) not yet accepted by any of the three
  parties, and this document does not treat that ownership as settled.
- **`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`** owns: the extended public
  card field list, `PublicCreatorProfileConfig` (§4.2), card
  visibility/discoverability and card moderation state, Report and its
  card-level consequences, reviews-about-content aggregation display, and
  the public-facing half of handle/deep-link resolution. It does **not**
  own Follow or Block/Mute mechanics — those are
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s; the public card only consumes
  their result for display.
- **`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`** owns everything `ManagedPage`-
  specific: Team, page lifecycle cascade, page-scoped Booking console, page
  transfer/merge mechanics — including accepted `PP-D16`, which §12 here
  consumes without redefining or treating as runtime authorization.

Any future edit to a shared invariant in one document SHOULD check whether
the sibling documents need the same edit, and SHOULD record the check even
when no change was needed.
