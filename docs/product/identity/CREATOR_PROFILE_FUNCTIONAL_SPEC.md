# RECHARGE — Creator Profile Functional Specification

Status: **Draft for product and architecture review**

Version: **1.11** — PVR-01/03 documentation transfer

Date: **2026-10-10**

Scope: **target full-release product; documentation only**

PVR-01/03 source snapshot: Viewer v1.17 / Public Viewer v1.0.
Current consumers: Creator v1.11, Public Creator v1.10, Professional Page
v2.35, Public Professional Page v1.4, index v2.0; Identity slice v1.3.2.
Targeted transfer audit: roles, projection fields, AccountStatus, block/deletion
and all VP IDs; maturity unchanged. Historical review notes below retain
their original version pins and are not current compatibility declarations.

## 0. Document authority and purpose

Under Accepted ADR 0021, Creator Profile is the one private personal profile
of any authenticated account: common personal libraries and settings plus
separately guarded verification/publisher tools. The [common personal part](#common-personal)
carries transferred Viewer v1.17 rules and IDs. The public-facing baseline
and eligible extended card are defined separately in Public Creator.

There are four active Draft surface specs: Creator, Public Creator,
Professional Page and Public Professional Page. Viewer / Public Viewer are
unchanged source documents until stage 07; no separate Viewer UI is target.
No document creates a new aggregate or grants authority through its name.
This Draft does not authorize full-release runtime, Firebase/backend or
production verification. Existing Accepted ADRs and Approved contracts keep
priority; each deferred implementation requires its own Approved bounded slice.


When sources conflict:

1. Accepted ADRs, including the narrow UI decision ADR 0021.
2. Approved current-slice specification.
3. LAUNCH_STATUS for current implementation evidence only.
4. Accepted/Approved owning aggregate or shared cross-product contract.
5. Four active Draft surface specs on equal footing; joint conflicts remain gated.
6. VISION and general product material.

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
ownership relationship in `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal` — this
document uses neither sense without saying which. **Follow** is not yet
confirmed as one shared model or two separate ones —
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D44` proposes a shared
foundation; the verification/publisher part has no separate Follow model to reconcile
with it (that is `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s and
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s joint concern, §23).

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
- `docs/product/archive/S2_EXP_01_PROFILE_SETTINGS_SPEC.md`;
- `docs/product/identity/CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal` (common personal part — profile projections only; owning aggregate
  lifecycles remain in their own contracts; see §23);
- `docs/product/identity/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#baseline-context-projection` (that sibling's
  own public-facing pair; introduces no decision of its own, always traces
  back to `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s numbering);
- `docs/product/identity/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` (sibling — owns
  the public card field list this document must not redefine; see §23);
- `docs/product/identity/PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` (`ManagedPage` peer,
  not a personal-identity sibling — see §0's distinction; shared invariants
  MUST NOT diverge without the divergence being recorded in §23);
- `docs/product/identity/PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` (that peer's
  own public-facing pair, added to this list for the same reason);
- `docs/product/CATEGORY_SYSTEM.md`;
- `docs/product/SCENARIO_BUILDER_SPEC.md`;
- `docs/product/ROUTE_BUILDER_SPEC.md`.

### 0.2 Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` and their Russian equivalents are
normative. `Target` describes intended full-release behavior. `Current` is
only a status snapshot and must be verified in `LAUNCH_STATUS.md` before work.

### 0.3 Current implementation boundary

Carried pre-transfer snapshot (source Creator v1.10 dated 2026-09-07),
not a fresh runtime audit; current evidence remains LAUNCH_STATUS / stage 00:

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

### 0.4 Relationship to active surface documents

Creator owns the common personal requirements and original verification /
publisher presentation. Public Creator has a baseline context projection and
an eligible opt-in extended card. Professional Page and its public spec retain
ManagedPage scope. [Retirement map](VIEWER_PROFILE_RETIREMENT_MAP.md) records
source ownership, status and exact destinations; it is reference only.
The prior six-document framing survives only in dated history below.

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

### 0.8 v1.4 → v1.4: fixes from `docs/product/identity/PROFILE_DOCUMENTS_INDEX.md` v1.0, complete closure pass

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

### 0.14 v1.9 → v1.10: sibling-count framing refreshed to six documents

Not a content review — this document's own framing text had gone stale
independent of any decision or invariant: both `VIEWER_PROFILE_FUNCTIONAL_
SPEC.md` (v1.17) and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` (v2.31, then
confirmed live as of v2.34) split their own public-facing half into a
sibling since this document last touched its "three personal-identity
documents plus a `ManagedPage` peer, four total" framing —
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §1.1 already uses the current
six-document, three private/public-pair model as of its own v2.33/v2.34.

**What changed:** §0's body text, the six-tier precedence list (item 5),
§0.1's "all four documents" line, the canonical supporting sources list and
§23's opening paragraph now name all six current documents — the two new
ones being `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` and
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`. §23's `VIEWER_PROFILE_
FUNCTIONAL_SPEC.md` entry gained a note that the Public User Projection and
Block/Mute mechanics it owns now have their *descriptive* text living in
the new sibling — decision ownership itself did not move. The
verified-against snapshot is refreshed to Viewer v1.17, Public Viewer
Profile v1.0, Public Creator v1.9, Professional Page v2.34 and Public
Professional Page v1.3.

**What did not change:** no `CP-D`/`CP-AC` was added, removed or
renumbered; no invariant's substance changed; §23's non-overlap statements
for `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` and `PUBLIC_CREATOR_PROFILE_
FUNCTIONAL_SPEC.md` are unchanged in substance. This document's own
content-level citations of those two siblings (beyond the count itself)
were not independently re-verified in this pass — that remains a separate,
future targeted check, named here rather than silently assumed done.

## 1. Product definition

Creator Profile is the single private personal UI for every authenticated
account under Accepted ADR 0021. Its name does not grant the system Creator
role, verification, capabilities or public discoverability. It aggregates
personal libraries, visits, settings and edit/save from their owning contracts
([common personal part](#common-personal)), alongside separately guarded
verification, publisher and Created-content tools (§§3–7/9/16/22).
It is no new domain aggregate, Create system or ManagedPage. User / Creator /
Admin roles, WorkspaceRef and PublisherRef stay unchanged. Professional Pages
remain separately selected managed contexts; Admin tools remain capability-gated.
Public fields are defined by Public Creator's contextual baseline and eligible
extended card, with different visibility rules.

## 2. Full-release extension policy

A capability is retained in the target scope when all of the following are
true:

1. It solves a recurring personal-library, verification or personal-publishing job.
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
  authenticated active User
  + owning contract eligibility/consent/access for the action
  + verified Creator only when the action requires Creator authority
  + exact capability required for the action (publishing namespace — §7)
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

Every authenticated active account opens Creator Profile normally, including
accounts with verification notStarted, pending, rejected, expired or revoked.
For an account whose verification succeeded,
but each Create-type entry point independently evaluates
`canPerformPersonalAction`. An ungranted type MUST render an explicit
restricted state (`"not available for your account"`), never a silently
disabled control indistinguishable from a not-yet-loaded one, and MUST NOT
be inferred as available from `VerifiedCreatorIdentity` alone (`CP-AC-04`).

There is no separate "open the workspace" gate: every authenticated Viewer
already owns exactly one personal workspace by construction
([VP §3.2](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-3-2)/§3.3).

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
  specifically withholds this action ([VP §15.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-15-1) owns that exception list — this document does not invent one)
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
exists (account-level lifecycle is `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s
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
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`) is unchanged; Creator tools appear
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
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s subject end to end (§4.3(7)).

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
   (owned by `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`) or the whole-card
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
  `docs/product/identity/PROFILE_DOCUMENTS_INDEX.md` §6.1; `CP-AC-17` requires this
  document to match CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal's own rendering,
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
(`CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s tracked decision) and this document
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
  (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal` owns that one);
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
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s baseline Public User Projection
(§12.2 there) is shown in other legitimate contexts — a Review, a Find
People response, an invited Scenario — for the same account, and a pending
identity-affecting edit MUST NOT be visible on one surface while still
showing the old value (or vice versa) on another. This document cannot
unilaterally mandate `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s implementation,
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
    `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s baseline Public User Projection
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
| Reviews (both forms) | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal` `VP-D08` / `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `PCP-D04` |
| Messaging | Out of this document's scope entirely |
| Account deletion/retention mechanics in general | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal` `VP-D06` |
| Multi-device/session model in general | [VP §15](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-15)/§24.3 |
| Scenario/Quick Plan collaboration domain | Scenario: **resolved**, `SCENARIO_CONNECTED_PLANNING_SPEC.md` v1.1. Quick Plan: `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal` `VP-D02` |

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
| CP-D20 | Open | CP-06 | TBD | Requires `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal` to adopt (§16.1) |
| CP-D21 | Open | CP-04 | TBD | Requires moderation queue/appeal policy |

## 22. Definition of Done and personal lifecycle

### 22.1 Verification/publisher foundation Approval gate — no circular dependency

This document may become **Approved** only after `CP-D01, CP-D03, CP-D04,
CP-D07, CP-D13, CP-D14, CP-D15, CP-D16, CP-D17, CP-D18, CP-D19, CP-D20,
CP-D21` are either accepted or explicitly deferred with owners and gates
(§21.2). Note that `CP-D20` is unusual among this list: this document can
state and defer it, but cannot itself accept it, since accepting it
requires `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s adoption — "explicitly
deferred with an owner and gate" is the only realistic path for `CP-D20`
from this document's side alone.

This document's Approval does **not** require any sibling document's own
gated/optional decisions (Follow parameters, Creator level, reviews-about-a-
person, minors' baseline projection, etc.) to be resolved — those are the
sibling's own release-foundation-vs-gated classification, and this
document's foundation scope (verification + personal publisher context) is
independent of them. This corrects v1.1's circular-approval risk, where
Approval implicitly depended on decisions this document does not need.

The foundation-only gate above applies to the original verification/publisher
part; it does not approve the transferred common personal requirements or
the entire merged Draft document. [VP §23](#vp-23) retains the common personal
full-release Approval/DoD gate, including all VP-D dispositions and owners.
PVR-01 accepts UI policy only and satisfies documentation-transfer criteria.

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
a **distinct category** from `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s personal
notifications. The two MUST NOT duplicate the same underlying event into two
inbox entries; exact dedup ownership is `CREATOR_PROFILE_FUNCTIONAL_SPEC.md#common-personal`'s
tracked routing decision, referenced not re-decided here.

## 23. Relationship to the active documents

[Common personal part](#common-personal) owns transferred personal rules and
VP-D/VP-AC tracking. Owning aggregates remain Scenario, Quick Plan, Booking,
Identity, Media and Review. This document's original verification/publisher
sections remain distinct from its common personal part.
[Public Creator](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#baseline-context-projection)
contains the baseline context projection and separately the eligible extended
card. [Professional Page](PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md) and its public
spec retain exact page membership, scope and lifecycle. Follow is joint and
Open: VP-D12 / PP-D44 / PCP-D02, with neutral FOL-01 ownership pending.
Viewer v1.17/Public Viewer v1.0 remain source records until stage 07.


<a id="common-personal"></a>

## Общая личная часть — transferred requirements

PVR-01/03, 2026-10-10. Source: Viewer v1.17, Public Viewer v1.0;
[provenance map](VIEWER_PROFILE_RETIREMENT_MAP.md). This is an active part
of the Draft Creator specification. It adds no aggregate or runtime.
VP section numbers are a stable transferred namespace, distinct from the
original Creator §§0–23. Bare §N references inside this part refer to VP §N
unless a different document is explicitly named. Original CP sections stay
numbered as before; transferred VP-D / VP-AC identifiers keep their meaning.

ADR 0021 accepts only the unified personal UI policy. Draft targets and Open
recommended/partial defaults below retain their source maturity. Approved
owning contracts remain Approved; their profile projections do not gain
independent authority. No Legal/minors/retention/Follow/security question is
accepted here. VP-D15 requires security review before a default is used;
StepUpGrant purposes/session scope and AccountStatus precedence are target
requirements, not proof of runtime safety or a closed security gate.

<a id="vp-0"></a>

## VP §0. Authority and current boundary

Creator common personal part replaces the active personal rules formerly
owned by Viewer v1.17; baseline public rendering moves to Public Creator.
The four active Draft surface specs are Creator / Public Creator /
Professional Page / Public Professional Page. Viewer source files remain
unaltered for stage 07 retirement; their historical UI framing is superseded
by ADR 0021 and this transfer. Accepted ADR → Approved slice → LAUNCH_STATUS
(current evidence only) → Accepted/Approved aggregate contract → Draft
surface specs → VISION. This part authorizes no deferred runtime.
Source VP §0.3 and Appendix B are historical context preserved in archive 01.
The snapshot in VP §0.2 below is dated source evidence, not a fresh 2026-10-10
runtime audit; stages 00–02 contain the current local baseline.

<a id="vp-0-1"></a>

### VP §0.1. Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` and their Russian equivalents are
normative. `Target` describes intended full-release behavior. `Current` is
only a status snapshot and must be verified in `LAUNCH_STATUS.md` before
work.

<a id="vp-0-2"></a>

### VP §0.2. Current implementation boundary

At the date of this document, on local/mock runtime, without production auth
backing:

- `S2-EXP-01` is Done: personal profile view/edit (`displayName`, `about`,
  `city`, `avatar`) exists behind the auth gate;
- `VIS-HIST-01` is Done in `LAUNCH_STATUS.md`: self-reported, place-only Visit
  History with idempotent owner+place+day records, descending canonical sort,
  month/day filters and per-record removal
  (`docs/product/discover/VISIT_HISTORY_SLICE_SPEC.md`); missing/corrupt local storage
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
  (`docs/product/scenario/SCENARIO_QUICK_PLAN_BOUNDARY_MIGRATION_SLICE_SPEC.md`) with
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
- the Creator Profile (common personal part) page
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

<a id="vp-1"></a>

## VP §1. Product definition

`Creator Profile (common personal part)` is the product/UI name for the personal operational center
of one individual account: the surface that answers **"What do I have going
on?"**, independent of whether the account ever becomes a verified Creator.
It is built from the same accepted `User` account and `UserProfile` fields as
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` (§4.1 there), plus the personal
libraries this document defines: Scenario library, Quick Plan library,
Favorites, Saved Searches, Smart Search history, Visit History, My
participation, Photos, and Reviews authored/received.

<a id="vp-1-1"></a>

### VP §1.1. Four surfaces of one account

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

Creator Profile (common personal part) is simultaneously:

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

<a id="vp-2"></a>

## VP §2. Full-release extension policy

Creator Profile (common personal part) is designed for a complete product release. A capability is
retained in target scope when all of the following are true:

1. It solves a recurring personal-planning or personal-activity job that
   exists whether or not the account is a Creator.
2. It reuses accepted aggregates and repositories — Scenario, Quick Plan,
   Favorites, Visit History, Notifications — rather than inventing parallel
   ones.
3. It is provider-neutral and degrades honestly offline.
4. It does not silently publish private data or collapse a personal-library
   library into a public projection.
5. It can be delivered behind a bounded flag with tests and rollback.

| Class | Meaning |
|---|---|
| Release foundation | Required for Creator Profile (common personal part) to be a coherent, safe personal center |
| Mature extension | Valuable for full release and suitable for incremental, reversible slices |
| Gated expansion | Retained in target architecture but blocked on backend, legal, moderation or operational readiness |

<a id="vp-3"></a>

## VP §3. Canonical access model

<a id="vp-3-1"></a>

### VP §3.1. Access states

The conditional personal-action formula is shared with Creator §3.1.
The former unconditional verified-identity formula applied to the old narrow
publisher scope; ADR 0021 removes that interpretation for common personal actions.

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

<a id="vp-3-2"></a>

### VP §3.2. Personal workspace, restated

`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.3 defines the one permanent personal
`WorkspaceRef{type: personal, id: userId}`. Creator Profile (common personal part) is the UI surface
of that same workspace when the active destination is personal libraries
rather than a Create draft. Switching the active workspace to a Professional
Page (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §3.2) never hides, empties or
suspends Creator Profile (common personal part)'s personal libraries — only the Create Hub's default
publisher changes.

<a id="vp-3-3"></a>

### VP §3.3. No membership, no capability gate to open

Opening Creator Profile (common personal part) requires only an active authenticated session — the
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

<a id="vp-4"></a>

## VP §4. Domain contracts and invariants

<a id="vp-4-1"></a>

### VP §4.1. Accepted core entity

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

<a id="vp-4-2"></a>

### VP §4.2. Personal library projections

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
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-17`. A Creator Profile (common personal part) read
projection never rewrites a source aggregate merely because it cannot render a
newer field.

<a id="vp-4-3"></a>

### VP §4.3. Invariants

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
   rather than restating); Creator Profile (common personal part) never becomes a second source of
   truth for invitation/application/Booking/hold/attendance state, and
   `familySpecificStatus` never collapses into one shared status enum
   across families.
8. A failed or partial load of one personal library MUST NOT downgrade
   Creator Profile (common personal part)'s other libraries to error state, and MUST NOT be
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
    stage). Creator Profile (common personal part) MUST NOT present `public` as reachable through
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

<a id="vp-5"></a>

## VP §5. My planning — Scenario and Quick Plan

<a id="vp-5-1"></a>

### VP §5.1. Why they are not one library — and their two different collaboration states

Scenario and Quick Plan are different aggregates with different rules
(`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §10, §9.3; `SCENARIO_QUICK_PLAN_
BOUNDARY_MIGRATION_SLICE_SPEC.md` §3.1). Creator Profile (common personal part) MUST present them as
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

Creator Profile (common personal part) MUST NOT present "invite a known friend to my Scenario/
Quick Plan" and "publish a Find People request" as the same feature or
route them through the same entry point — one needs nothing beyond
`Viewer`, the other needs Creator verification, exactly like §5.2's
`unlisted`/`public` split. §12.2's own "Find People response" trigger
surface (Public User Projection shown to a *responder*) is already
correctly scoped to the non-Creator-gated side of this; this section is
what makes that scoping legible rather than assumed.

<a id="vp-5-2"></a>

### VP §5.2. Scenario library — required lifecycle surface

Creator Profile (common personal part) MUST support these common Scenario actions:

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

Creator Profile (common personal part) MUST render this distinction, not only the three-value
enum: an owner-controlled `Share unlisted link` action is always
available on an owned Scenario regardless of Creator status; a `Publish`
action, if shown at all on a non-Creator account, routes to Creator
verification rather than performing a visibility change directly.

<a id="vp-5-3"></a>

### VP §5.3. Quick Plan library — required lifecycle surface

Quick Plan is a personal/invited utility, never a Create Hub entry and never
publisher-bearing (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9). Creator Profile (common personal part)
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

<a id="vp-5-4"></a>

### VP §5.4. Required empty and error states

- an empty Scenario library MUST show a `Create Scenario` entry point routing
  to `Create Hub -> Scenario`, never collapse to nothing — this corrects the
  current `SizedBox.shrink()` behavior noted in §0.2;
- an empty Quick Plan library MUST show its own distinct empty state, not
  reuse Scenario's;
- a load failure on either library MUST show a retry affordance, never
  render as if the library were genuinely empty (§4.3(8), §15.2).

<a id="vp-6"></a>

## VP §6. My activity — Saved is several libraries, not one

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

Creator Profile (common personal part) MUST link each library from its own entry point, MUST NOT
offer one combined "Saved" delete/clear action that spans more than one
underlying aggregate, and MUST NOT let a Favorites-count metric silently
include Scenario, Quick Plan or drafts.

<a id="vp-7"></a>

## VP §7. Visit History

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

Creator Profile (common personal part) MUST NOT auto-create a Visit History record from a Details
view, a Favorite, a Booking, GPS proximity, a check-in, or adding the Place
to a Scenario — `VIS-HIST-01` §1 and `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
§11 both already state this (via `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
§10.1's state-family separation, which both sibling documents reuse rather
than restate); this document repeats it because Visit History is the single
most likely place for a future integration to silently violate it.

<a id="vp-8"></a>

## VP §8. My participation

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

<a id="vp-9"></a>

## VP §9. Reviews — authored and received

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

<a id="vp-10"></a>

## VP §10. Photos

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
public Creator Profile (common personal part) route (§12.2's Public User Projection is a
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

<a id="vp-11"></a>

## VP §11. My publishing — boundary only

Draft management, Creator verification, the Create Hub, `PublisherRef`
resolution and the public Creator card are the sibling documents' subject
(`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §5, §9, §19;
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4). Creator Profile (common personal part)'s only
obligations here are boundary-preserving:

- a Viewer with `notStarted` Creator verification still has full access to
  §5–§10 of this document;
- The common personal part links into Creator verification/Create Hub;
  publishing uses the separately guarded Creator §9 flow;
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
  gated on `VerifiedCreatorIdentity`. Creator Profile (common personal part) MUST NOT gate
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

<a id="vp-12"></a>

## VP §12. Public projection and privacy

The public-facing identity projection — visibility defaults, the Public
User Projection field set, discoverability/blocking/deleted-account
handling, and the proposed Follow direction — is owned by
[`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#baseline-context-projection`](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#baseline-context-projection),
not restated here. That document is a presentation split-out only: it
introduces no new `VP-D`/`VP-AC` numbering and defers to this document's
decisions and invariants (`VP-D07`, `VP-D10`, `VP-D12`, invariants 13 and
16 in §4.3) for every rule it states. Every `VP-AC-*` criterion, test-matrix
entry and Appendix A row in this document that cites "§12.x" still resolves
correctly — the heading numbers below are unchanged, only their content is
now a pointer.

<a id="vp-12-1"></a>

### VP §12.1. Visibility defaults — see sibling document §2

<a id="vp-12-2"></a>

### VP §12.2. Public User Projection — see sibling document §3

<a id="vp-12-3"></a>

### VP §12.3. Discoverability, blocking, deleted accounts — see sibling document §4

<a id="vp-12-4"></a>

### VP §12.4. Follow (proposed direction only) — see sibling document §5

<a id="vp-13"></a>

## VP §13. Product modules versus authorization capabilities

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

<a id="vp-14"></a>

## VP §14. Information architecture — unified personal composition

ADR 0021 names the single personal profile Creator for every authenticated
account. Personal navigation remains Home / Favorites / Smart Search /
Notifications / Profile; Professional Page navigation remains separate.
Personal libraries, visits, settings and edit/save are part of the same
composition. Creator tools appear only when their existing action guards
permit them; no second Viewer composition or manual Viewer/Creator switch
is retained. Admin presentation preview offers creator | professionalPage
without changing authority. Future Draft modules remain gated individually.

<a id="vp-15"></a>

## VP §15. Account, session and multi-device states

<a id="vp-15-1"></a>

### VP §15.1. `AccountStatus` — formal contract

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
document's scope — it is a moderation/legal decision, not a Creator Profile (common personal part)
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

<a id="vp-15-2"></a>

### VP §15.2. Session and multi-device states

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
  approved revision/idempotency precondition and fails closed. Creator Profile (common personal part)
  MUST NOT introduce one shared per-account revision that couples independent
  libraries; exact per-contract mechanisms remain `VP-D09`;
- corrupt local profile/library cache fails closed to an explicit recovery
  state, never a silent empty state — except Visit History's own Approved
  exception (§4.3(8));
- a partial load — Profile itself loads but Scenario or Favorites does not —
  MUST isolate the failure to that one library (§4.3(8)).

<a id="vp-16"></a>

## VP §16. Notifications and settings

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

<a id="vp-17"></a>

## VP §17. Security, privacy, offline and operations

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

<a id="vp-18"></a>

## VP §18. Required UX states

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

<a id="vp-19"></a>

## VP §19. Delivery roadmap

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

<a id="vp-20"></a>

## VP §20. Acceptance criteria

### Surface boundary

<a id="vp-ac-01"></a>

- **VP-AC-01:** Opening Personal Profile never creates or implies a Public
  Creator Profile.
<a id="vp-ac-02"></a>

- **VP-AC-02:** No action defined in §5–§10 requires Creator verification or
  produces a `PublisherRef`; it MAY still require the owning aggregate's own
  eligibility/consent/rate-limit gate (§3.1).
<a id="vp-ac-03"></a>

- **VP-AC-03:** Scenario and Quick Plan remain two libraries with two empty
  states and two lists; they are never merged.
<a id="vp-ac-04"></a>

- **VP-AC-04:** Favorites, Saved Searches, Smart Search history, personal
  Scenario and Quick Plans remain independently listed; no combined
  aggregate or combined "clear all" spans more than one of them.

### Scenario and Quick Plan lifecycle

<a id="vp-ac-05"></a>

- **VP-AC-05:** An empty Scenario library shows a `Create Scenario` entry
  point routed to `Create Hub -> Scenario`; it never creates a parallel flow
  or collapses to nothing.
<a id="vp-ac-06"></a>

- **VP-AC-06:** All four `accessRole` values render in visibly distinct
  groups with distinct controls, matching `ScenarioAccessGrant`'s own
  capability table exactly; `editor` never exposes invite/access-management/
  owner controls, and `viewer`/`unlistedViewer` never expose edit controls.
<a id="vp-ac-07"></a>

- **VP-AC-07:** `Expand to Scenario` creates a new Scenario ID; the source
  Quick Plan remains unchanged and addressable by its own ID afterward, with
  no live/back-reference. Only a retry of the same idempotent command may
  return the already-created result.
<a id="vp-ac-08"></a>

- **VP-AC-08:** A stale/corrupt/revision-conflict Scenario shows an explicit
  recoverable state, never a silent disappearance.

### Visit History and activity

<a id="vp-ac-09"></a>

- **VP-AC-09:** A Visit History record is created only via explicit
  self-report with today-or-earlier date; no other action creates one.
<a id="vp-ac-10"></a>

- **VP-AC-10:** The same Place can carry multiple Visit History records on
  different days; each is independently deletable.
<a id="vp-ac-11"></a>

- **VP-AC-11:** My participation renders each state family from its own
  authoritative source via the tagged `ParticipationRef` projection (§4.2);
  it never introduces a second Booking status enum.

### Privacy and public projection

<a id="vp-ac-12"></a>

- **VP-AC-12:** Public User Projection contains at most display name,
  avatar and optional city; no §5–§10 library data.
<a id="vp-ac-13"></a>

- **VP-AC-13:** A Viewer who never verifies as Creator does not appear as a
  standalone searchable public profile.
<a id="vp-ac-14"></a>

- **VP-AC-14:** A deleted/tombstoned account's projection returns the same
  safe not-found response as a nonexistent account.
<a id="vp-ac-15"></a>

- **VP-AC-15:** Mute on a Viewer changes only the muting account's own view
  and never notifies the muted account; Block is bidirectional — it removes
  both accounts' ability to view each other's projection/card, follow each
  other, or initiate new contact.

### Reliability and account state

<a id="vp-ac-16"></a>

- **VP-AC-16:** A failed or partial load of one personal library does not
  degrade another library's presented state.
<a id="vp-ac-17"></a>

- **VP-AC-17:** A partial-load failure is never presented as an honest empty
  state, except Visit History's own Approved corrupt-storage-returns-empty
  behavior (§4.3(8)), which is preserved rather than silently overridden.
<a id="vp-ac-18"></a>

- **VP-AC-18:** Switching accounts on one device fully re-scopes every
  personal library and local cache key to the new `userId`.
<a id="vp-ac-19"></a>

- **VP-AC-19:** An expired session mid-edit fails closed on the next
  mutation without silently discarding a supported local draft.
<a id="vp-ac-20"></a>

- **VP-AC-20:** `LAUNCH_STATUS.md` records exact implementation evidence and
  remaining gates for each VP slice.

### `AccountStatus`, deep links and notifications

<a id="vp-ac-21"></a>

- **VP-AC-21:** `AccountStatus` has exactly five values
  (`active|securityLocked|suspended|deletionPending|tombstoned`), is
  client-unwritable, and its per-state action table (§15.1) is authoritative
  for both this document and `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`.
<a id="vp-ac-22"></a>

- **VP-AC-22:** A deep link into a §5–§10 item resolves via the full
  authorization chain (§17), never ownership alone; an invited participant
  with a valid, non-revoked grant resolves successfully.
<a id="vp-ac-23"></a>

- **VP-AC-23:** A notification event never produces two inbox entries across
  this document's categories and `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s
  Creator-tier categories (`VP-D11`).
<a id="vp-ac-24"></a>

- **VP-AC-24:** `securityLocked`, `suspended` and `deletionPending` block
  only *new* commitments; closing an already-existing My participation
  obligation (§8) remains *reachable* in all three, mirroring
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §5.4 and
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-73` — "reachable" here means
  not permanently blocked, not "without precondition": see `VP-AC-33`/`36`
  for the session-scoped `StepUpGrant` gate that still applies on top of
  this.

### Quality

<a id="vp-ac-25"></a>

- **VP-AC-25:** en/ru/lv-ready labels, 360 dp and 150% text scale are
  covered.
<a id="vp-ac-26"></a>

- **VP-AC-26:** Unit, widget and integration tests are proportional to each
  slice.
<a id="vp-ac-27"></a>

- **VP-AC-27:** `flutter analyze`, `flutter test`, boundary and diff checks
  pass for every implementation slice.

### Follow (conditional on the joint `PP-D44`/`PCP-D02` decision, §12.4)

<a id="vp-ac-28"></a>

- **VP-AC-28:** Follow does not ship in any form — production or local/mock
  presented as real — until the joint `PP-D44`/`PCP-D02` decision resolves;
  this document's own proposal (§12.4) is not, by itself, sufficient
  authorization to implement.
<a id="vp-ac-29"></a>

- **VP-AC-29:** *If* the joint decision adopts a Follow model, it is
  available to and from every account regardless of Creator verification,
  `AccountStatus` beyond `active`, or any content-publishing fact, unless
  the joint decision explicitly narrows that.
<a id="vp-ac-30"></a>

- **VP-AC-30:** *If* Follow ships, a Block immediately removes any existing
  `FollowRef` in both directions and prevents a new one while the Block
  stands; a Mute never affects `FollowRef`.
<a id="vp-ac-31"></a>

- **VP-AC-31:** *If* Follow ships, it is reachable only via an existing
  Public User Projection trigger surface or an opaque, revocable link — never
  a raw `userId`/handle-based link, and never a new standalone-
  discoverability surface.
<a id="vp-ac-32"></a>

- **VP-AC-32:** *If* Follow ships, a `tombstoned` account loses all
  `FollowRef` relationships at the point of tombstoning; restore within the
  retention window does not silently restore them.

### `AccountStatus` precedence and session security

<a id="vp-ac-33"></a>

- **VP-AC-33:** Closing an already-existing My participation obligation
  while `AccountStatus == securityLocked` requires a fresh, session-scoped
  `StepUpGrant{purpose: obligationClose}` for the acting session; no
  account-wide flag may substitute for a per-session grant.
<a id="vp-ac-34"></a>

- **VP-AC-34:** A security or moderation signal arriving while
  `deletionPending` transitions the account to `securityLocked`/`suspended`
  and pauses rather than discards the deletion request; resolving that
  signal returns the account to `deletionPending`, never silently to
  `active`.
<a id="vp-ac-35"></a>

- **VP-AC-35:** A restored (`tombstoned -> active`) account always resumes
  at `active`; any pre-tombstoning security lock or suspension are reset
  and re-evaluated fresh, and no `StepUpGrant` survives a restore, never
  silently carried over.
<a id="vp-ac-36"></a>

- **VP-AC-36:** `securityLocked -> deletionPending` requires its own fresh
  `StepUpGrant{purpose: deletionRequest}` for the requesting session — a
  request from a locked account is *rejected*, not merely flagged for
  later, without one. This is the acceptance criterion that closes the
  exploit a review confirmed was possible in a prior revision: requesting
  deletion from `securityLocked` was previously ungated, letting a
  hijacked session with no obligations to close ride the account to
  `tombstoned` without ever proving anything.
<a id="vp-ac-37"></a>

- **VP-AC-37:** A `StepUpGrant` authorizes exactly one `sessionId` for
  exactly one `purpose`; completing step-up on one session never grants,
  extends, or implies a grant for any other session on the same account.
<a id="vp-ac-38"></a>

- **VP-AC-38:** `securityLocked -> active` (self-service unlock) revokes
  every other active session's token as a mandatory, atomic part of the
  same transition — never a separate, skippable follow-up step.

### Decision defaults

<a id="vp-ac-39"></a>

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

<a id="vp-ac-40"></a>

- **VP-AC-40:** `private -> unlisted` on an owned Scenario requires only
  `Viewer` plus the `share_unlisted` capability; it is never gated on
  Creator verification. `private|unlisted -> public` is the Create Hub
  publish action and requires `VerifiedCreatorIdentity`; it is never
  reachable through the same control as `unlisted` sharing.
<a id="vp-ac-41"></a>

- **VP-AC-41:** No planning action this document defines — create, edit,
  duplicate, archive, invite a collaborator, share an unlisted link — is
  gated on Creator verification for any reason, including by association
  with the one action (`public`/Discover publish) that genuinely is.
<a id="vp-ac-42"></a>

- **VP-AC-42:** Inviting a known person into an owned Scenario/Quick Plan
  and publishing a `find_people` request never share an entry point,
  capability check, or data model; a non-Creator account can do the
  former and respond to the latter, but cannot do the latter itself.
<a id="vp-ac-43"></a>

- **VP-AC-43:** For an account with an `IdentityFieldModerationOverlay`
  row, the baseline Public User Projection's `displayName`/`avatar` are
  read from that overlay's `lastApprovedPublicValue`, never from
  `UserProfile` directly, on every trigger surface (§12.2); for an account
  with no overlay row, `UserProfile` remains the direct source.

<a id="vp-21"></a>

## VP §21. Required test matrix

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

<a id="vp-22"></a>

## VP §22. Decisions required before implementation

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

1. <a id="vp-d01"></a> **VP-D01 — Scenario rename/copy/duplicate/archive/delete UX:** exact
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
2. <a id="vp-d02"></a> **VP-D02 — Quick Plan collaboration domain contract** (Quick Plan only —
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
3. <a id="vp-d03"></a> **VP-D03 — Saved decomposition IA:** whether the three Saved libraries
   (§6) get three separate top-level entry points or one entry point with
   three internally distinct tabs that never share a delete action.
   **Recommended default (not Approved):** three separate top-level entry
   points — simpler mental model, and directly matches §6's own "Saved is
   several libraries, not one" framing rather than reintroducing a shared
   container at the navigation layer that the rest of this document argues
   against.
4. <a id="vp-d04"></a> **VP-D04 — My participation source contract:** exact read-projection
   shape once ADR 0019's Booking backend is live; ownership sits with that
   backend's own slice. **No default proposed — category (a):** the backend
   this projection reads from does not exist yet; a default read-projection
   shape would be guessing at an unbuilt contract, not a low-risk parameter
   choice. `VP-06`'s implementation genuinely waits on `EVENT_CLASSIFICATION_
   ECL_03_SLICE_SPEC.md` activation, not on this document.
5. <a id="vp-d05"></a> **VP-D05 — Photos pipeline:** authorship/license confirmation, per-photo
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
6. <a id="vp-d06"></a> **VP-D06 — Account deletion and retention** (widened): exact retention
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
7. <a id="vp-d07"></a> **VP-D07 — Public User Projection remaining open questions** (narrowed):
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
8. <a id="vp-d08"></a> **VP-D08 — Reviews about a person:** whether Recharge ever supports a
   Review whose subject is a Viewer rather than content, and if so its
   eligibility, consent and moderation model. **No default proposed —
   category (b):** this is a harassment/consent-risk product decision (an
   unwanted review of a person, not their work, is a materially different
   harm than an unwanted review of an Event), not a UX parameter; a
   default here would be exactly the kind of premature product decision
   this document has repeatedly corrected itself for making elsewhere.
   Deliberately unresolved.
9. <a id="vp-d09"></a> **VP-D09 — Multi-device conflict per library:** exact precondition and
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
10. <a id="vp-d10"></a> **VP-D10 — Minors' baseline Public User Projection:** this document's own
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
11. <a id="vp-d11"></a> **VP-D11 — Notification category ownership and dedup:** the exact
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
12. <a id="vp-d12"></a> **VP-D12 — this document's half of the joint Follow decision**
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
13. <a id="vp-d13"></a> **VP-D13 — Saved Search / Smart Search history retention and cleanup**
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
14. <a id="vp-d14"></a> **VP-D14 — Account data export and format** (§16, `VP-D06`'s sibling):
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
15. <a id="vp-d15"></a> **VP-D15 — Session list, re-authentication and remote device revoke**
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
16. <a id="vp-d16"></a> **VP-D16 — Photos media safety** (§10): malware/file-type/size/
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

<a id="vp-22-1"></a>

### VP §22.1. Decision tracking

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

<a id="vp-23"></a>

## VP §23. Definition of Done

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

The common personal requirements are production Done only when (future
full-release gate; PVR-01 does not implement these Draft requirements):

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

<a id="vp-24"></a>

## VP §24. Creator Profile (common personal part) lifecycle as a personal object

<a id="vp-24-1"></a>

### VP §24.1. Scenario and Quick Plan state transitions

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

<a id="vp-24-2"></a>

### VP §24.2. Visit History record lifecycle

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

<a id="vp-24-3"></a>

### VP §24.3. Concurrent editing

- Two active sessions editing the same record must not silently overwrite
  each other. Each owning aggregate applies its approved revision,
  idempotency or conditional-write contract; Creator Profile (common personal part) introduces no
  shared cross-library revision. Exact recovery UX remains `VP-D09`.

<a id="vp-24-4"></a>

### VP §24.4. Account deletion and retention

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
  confirms personal-library libraries follow the same soft-delete principle and
  that the sole-Page-owner precondition above gates entry into
  `deletionPending` in the first place.

<a id="vp-24-5"></a>

### VP §24.5. Notification recipients and read state

- Personal notifications route only to the account owner.
- Read state is account-scoped and synchronized across every active
  session/device — never siloed to the one session or device that marked
  it read.
- `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §22.5 defines its own Creator-tier
  notification category as distinct from this document's personal
  categories (§16) and requires the two never duplicate the same underlying
  event into two inbox entries — the exact dedup mechanism is `VP-D11`,
  which did not exist before this revision.

<a id="vp-24-6"></a>

### VP §24.6. Follow relationship lifecycle

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

<a id="vp-25"></a>

## VP §25. Relationship to the active documents

Creator common personal part owns profile-level personal-library projections,
AccountStatus/session requirements and transferred VP decisions/criteria.
Creator §§3–7/9/16/22 retain verification, publisher, field moderation and
content-management responsibilities. Public Creator's baseline part owns
contextual projection rendering, privacy and Block/Mute; its original
sections own the eligible extended card. Follow remains jointly pending
VP-D12 / PP-D44 / PCP-D02 (FOL-01), without an accepted base relationship.
Scenario, Quick Plan, Booking, Review, Media and Identity owning contracts
retain aggregate authority; profile is a projection and entry surface.
Professional Page and Public Professional Page retain page ownership,
membership, lifecycle, public moderation and page-scoped actions.


<a id="vp-appendix-a"></a>

## VP Appendix A. Non-negotiable exclusions (index)

Mirrors `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s own exclusions index in
method — a non-normative reader index, not a new requirement.

| Creator Profile (common personal part) MUST NOT | Established at |
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
