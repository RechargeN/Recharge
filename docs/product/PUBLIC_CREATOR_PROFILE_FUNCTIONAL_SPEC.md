# RECHARGE — Public Creator Profile Functional Specification

Status: **Draft for product and architecture review**

Version: **1.9** (supersedes v1.8 — separates non-restrictive pending review
from an already-effective card restriction so a new report can never weaken
an existing moderator decision; see §0.12)

Date: **2026-08-12**

Scope: **target full-release product; documentation only**

Verified-against snapshot (exact versions; a mismatch means this snapshot
is stale and MUST be refreshed whenever this document is substantively
changed, but does not by itself prove content incompatibility):
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.15 (targeted verification:
`AccountStatus`'s five values/casing, §12.3's bidirectional-Block rule and
`VP-D10`/`VP-D12` still have the meaning consumed below),
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9,
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.28 (targeted verification:
`PP-D44`, `PP-D25` and `PP-D23` still have the meaning cited below).
See `docs/product/PROFILE_DOCUMENTS_INDEX.md` for the cross-document
registry this citation block is checked against.

**On the pace of sibling-document change:**
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` and
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` are under active, frequent revision
independent of this document's own edit cycle. A full
line-by-line re-verification against every sibling version bump is not
sustainable at that pace; this document's practice is a targeted
spot-check of the specific facts it actually cites, recorded above, each
time this header is touched — not a claim of exhaustive re-reading. A
version mismatch is therefore a maintenance signal requiring a new targeted
check, not automatic evidence that the documents' semantics conflict.

## 0. Document authority and purpose

This document defines the target functional model of the **public card** of
a verified Creator — what another authorized account sees. It is one of
three **personal-identity** documents
(this one, `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`,
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`), plus a related **`ManagedPage` peer
specification** (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`) — four documents
total participate in the same cross-document
compatibility/conflict protocol (§0.1) because they share canonical
aggregates (`UserProfile`, `CreatorVerification`, Create content,
`ManagedPage`, Favorites, Scenario, Follow, etc.), but Professional Page is
not a fourth personal-identity sibling. A surface already owned by one
document is referenced, never redefined, by the others:

```text
VIEWER_PROFILE_FUNCTIONAL_SPEC.md   — private personal libraries; the
                                       minimal Public User Projection every
                                       Viewer has (§12.2 there), which this
                                       document extends; and the `AccountStatus`
                                       axis (§15.1 there).
CREATOR_PROFILE_FUNCTIONAL_SPEC.md  — verification + personal publisher
                                       context; the private-management half
                                       of every feature this document shows
                                       publicly.
PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md (this document)
                                     — the public card itself: field list,
                                       visibility, discoverability, and this
                                       document's own half of any joint
                                       cross-document decision (§7).
PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md — the ManagedPage public projection;
                                       not redefined here, only linked (§5).
```

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
   `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
   `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`. None of them outranks another by
   virtue of which one a reader opened first; a conflict between them is
   blocked pending a joint decision (§0.1), not resolved by this tier
   ordering.
6. `docs/product/VISION.md` and other general product material.

If any statement in this document contradicts an Accepted ADR, an Approved
spec, `LAUNCH_STATUS.md`, or a shared cross-product contract (items 1–4),
that is a defect in this Draft, to be corrected.

### 0.1 When sibling documents disagree

All four documents in item 5 above are `Draft`. If two of them disagree on
a shared invariant and no higher-priority source (items 1–4) resolves it,
**implementation of that invariant is blocked pending a joint decision —
neither document's wording wins by default.** This document does not treat
its own draft position on Follow (§7) as settled for exactly this reason.

Two terms collide across the sibling documents and MUST be disambiguated on
every use in this document, never left implicit:

- **`owner`** means a page-team role
  (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `ManagedPageMembership.
  relationship = owner`) in that document, and a personal content item's
  own ownership relationship (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2's
  **Quick Plan** `relationship: owned | invited` — not Scenario's; Scenario
  uses the separate, Approved `owner|editor|viewer|unlistedViewer`
  `ScenarioAccessGrant` model, `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1,
  which `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §10 cites directly) in that
  one. This document uses neither sense for card ownership — "the owner"
  here always means the account this card is about.
- **Follow** is not yet confirmed as one shared relationship/consent/
  retention model (proposed by `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
  `PP-D44`) or a genuinely separate model for a person versus a page. This
  document's `PCP-D02` is this document's own half of that joint decision,
  not an independent design (§7).

### 0.2 Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` and their Russian equivalents are
normative. `Target` describes intended full-release behavior. `Current` is
only a status snapshot and must be verified in `LAUNCH_STATUS.md` before
work.

### 0.3 Current implementation boundary

At the date of this document there is no production Follow, Reviews,
personal analytics, moderation-visible-state or externally reachable public
Creator card. `profile_page.dart` presents only the account's own view of
itself; no code path renders one account's profile the way another account
would see it. No target statement below may be presented as currently
implemented unless `LAUNCH_STATUS.md` contains corresponding evidence.

### 0.4 v1.1 → v1.2: round-2 cross-document review fixes

1. **Reciprocates the joint-decision protocol** the sibling documents
   established after v1.1 shipped (§0.1): this document no longer presents
   its own Follow model as an independent design. `PCP-D02` is redefined as
   this document's half of the joint `PP-D44`/`VP-D12`/`PCP-D02` decision,
   and §7 states this document's proposed position for that decision rather
   than a settled rule — the same correction
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` had to make to its own prior
   "universal Follow, accepted" claim.
2. Fixes `AccountStatus` value casing — `securityLocked`/`deletionPending`
   (camelCase), matching `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1's actual
   contract exactly; v1.1 used `security-locked`/`deletion-pending`, which
   read as a different (and wrong) contract inside a code block (§3).
3. Gives card **visibility** an actual field: `PublicCreatorProfileConfig`
   (§4.2) now has `visibility`, `aboutOptIn`, `cityOptIn` and
   `activatedAtUtc?`, with an explicit safe default (`private` until first
   explicit activation) — v1.1 described three visibility states with no
   entity to persist which one applied (§4.2).
4. Resolves the `private`-card vs. universal-Follow-via-direct-link
   contradiction a reviewer identified: `private` now explicitly withdraws
   only the **extended card** (§4's Creator-specific fields); it does not
   hide the underlying account's baseline Public User Projection or its
   reachability for Follow, both of which
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` owns and does not gate on this
   document's `visibility` setting (§3.1, §3.4). Anti-enumeration (§10) is
   correspondingly narrowed to `AccountStatus`
   (`suspended`/`securityLocked`/`tombstoned`) — a `private` card was never
   actually hiding the account's existence and should not have implied it
   did.
5. Adds a normative **resolver table** (§3.6) giving one deterministic
   result — `notFound | baselineProjection | extendedCard |
   extendedCardWithRestrictions` — for the axis combinations a reviewer
   listed as ambiguous (`suspended+underReview`, `revoked+public`,
   `quarantined+private`, a valid unlisted token held by a blocked viewer,
   `expired+restricted`, a card with no approved field yet).
6. Restructures `restricted` (§3.5) from a bare enum value into a
   `restrictions: [{target, reasonCode, expiresAtUtc?}]` list, so a single
   restricted field/module does not require withdrawing the whole card.
7. Adds detail to `publicContactPolicy` (§4.2): the contact address itself
   is never embedded in the public payload; `safeChannel(kind)` resolves
   server-side per request, with verification-before-display and no raw
   email/phone leaking regardless of `kind`.
8. Adds a minimal `socialLinks` entry shape (id, order, per-platform
   uniqueness, moderation status, dead-link handling) and defers the rest to
   `PCP-D11` rather than leaving the array untyped (§4.2).
9. Expands the `unlisted` opaque-token requirement (§3.4, `PCP-D10`) to
   name what was previously only implied as needed: bearer- vs.
   recipient-bound tokens, rotation, replay protection, referrer/analytics
   leakage, on-device storage and blanket revocation of every issued link.
10. Adds an explicit offline-safety floor (§12.1): a maximum cache TTL,
    `unlisted`/`private` never opening from cache without a fresh check,
    and every interactive action (Follow, Report, Contact) disabled while
    offline regardless of cached card freshness.
11. Cross-references, rather than re-describes,
    `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3's now-detailed Block
    mechanics (bidirectional by default, Scenario/Quick Plan joint-content
    ownership split from card visibility) instead of leaving this
    document's own §7 as the sole,
    less detailed source (§7).
12. Fixes two stale cross-references: the roadmap's portfolio-display
    dependency pointed at `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-07`
    (cache/revocation propagation in that document's current numbering) —
    corrected to `CP-08` (Portfolio rights); `PCP-D07` (localization) is
    moved from "Not yet in roadmap" onto its own roadmap row (§14, §17.1).

### 0.5 v1.2 → v1.3: round-3 cross-document review fixes

1. Replaces §0's 5-item priority order with the 6-tier model
   `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.14 established — Draft
   profile-surface documents sit on equal footing (item 5) rather than
   this document unconditionally outranking `VISION.md`;
2. **fixes two real resolver bugs in §3.6**: (a) an `expired`-verification
   card could previously match the "not verified → baselineProjection" row
   ambiguously, depending on evaluation order — verification states are now
   an explicit enumeration, with `expired` as its own distinct step; (b) a
   blocked viewer holding a valid `unlisted` token previously resolved to
   `baselineProjection` — contradicting `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`
   §12.3's bidirectional Block, which withdraws **both** projections, not
   only the extended card. The resolver now runs a Block check immediately
   after account status and before verification/visibility, and blocked
   access resolves to `notFound` in every case;
3. **removes the Block/Mute ownership cycle** (§7.2): this document
   previously described itself as "referenced by"
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s Block/Mute split while that
   document described the split as established by this one — each citing
   the other as source. This
   document now cedes Block/Mute fully to `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`
   with no shared-ownership claim;
4. **removes `cityOptIn`** (§4.2) — a separate extended-card-only toggle for
   a field already part of the baseline projection could silently break
   §1's "strict superset" guarantee (extended card hiding `city` while
   baseline still shows it); `city` now inherits the baseline decision
   unconditionally, and only `aboutOptIn` (a field with no baseline
   exposure at all) remains a genuine opt-in;
5. gives `cardModerationState` an actual server-owned entity shape
   (`CardModerationRecord`: audit reference, appeal linkage, optimistic
   concurrency) instead of a bare union type, and makes
   `restrictions[].target` a versioned identifier rather than a free-form
   string (§4.2);
6. adds §4.3, the activation/configuration edge cases a reviewer listed as
   missing: pre-verification draft editing, activation requiring
   `VerifiedCreatorIdentity`, the `visibility != private` +
   `activatedAtUtc = null` inconsistency, unknown-enum fail-closed
   behavior, and revision/idempotency on every config mutation;
7. gates the Follow CTA/follower count in §4's field set, and §3.1's
   reachability language, behind the joint `PP-D44`/`VP-D12`/`PCP-D02`
   decision explicitly — both previously read as unconditional despite §7.1
   already saying Follow is not yet accepted anywhere;
8. fixes §4.2's cross-reference: the owner edits this config from
   `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.2 (entity definition), not that
   document's §7 (capabilities);
9. expands `PCP-D11`'s scope to explicitly cover `safeChannel.kind` values,
   address verification, anti-spam/rate limiting and provider-failure
   fallback, not only social-link platforms.

### 0.6 v1.3 → v1.4: fixes from `docs/product/PROFILE_DOCUMENTS_INDEX.md` v1.0

`PROFILE_DOCUMENTS_INDEX.md` is a new non-normative cross-document registry
tracking version citations, ownership and confirmed defects across all four
profile-surface documents; it decides nothing itself (its own §0), but its
§7/§8 identified two real, confirmed self-contradictions this document
introduced in its own v1.3 edits and had not yet caught:

1. `PCP-AC-15` (renumbered `PCP-AC-16` as of §0.11's pass) still listed
   `cityOptIn` as an owned field after §4.2 had already removed it —
   fixed to match §4.2 exactly;
2. §16's test matrix still described a blocked viewer holding a valid
   `unlisted` token as resolving to `baselineProjection` — stale relative
   to §3.6's own resolver fix in this same version, which routes that case
   to `notFound` via the Block check. Fixed to match §3.6.

Also updates stale sibling-version citations
(`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` v1.7→v1.8,
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.14→v2.15) per the index's §1/§7
registry, with the re-verification note each requires
rather than a silent bump.

### 0.7 v1.3 → v1.4: full read-through and versioning-hygiene fix

A complete top-to-bottom re-read (not a targeted check against a specific
review's claims) found no duplicate-ID or dangling-structural defect in this
document — every `PCP-D*`, `PCP-AC*` and `§X.Y` heading is unique and
sequential, verified programmatically rather than by inspection alone.

One hygiene gap remained: §0.6's fixes were applied without a header
version bump, leaving the document at `1.3` both before and after — a
sibling citing "Public Creator Profile v1.3" could not tell whether it had
those fixes. The header now reads `1.4` and accounts for §0.6 together with
this section, closing the same gap `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
v1.4→v1.5 closed for itself in its own §0.9.

### 0.8 v1.4 → v1.5: three real gaps from a round-4 cross-document review

1. **Minor gate was absent from the resolver (§3.6) entirely**, while §9
   independently required it — the five-step resolver had no step that
   ever consulted minor status, so an implementation following §3.6 alone
   could not have enforced §9's rule. Adds resolver step 3 (minor gate),
   renumbering verification/visibility/moderation to steps 4–6;
2. **`PCP-AC-13` (renumbered `PCP-AC-14` as of §0.11's pass) and the test
   matrix asserted an unconditional "baseline projection only" outcome for
   a minor account**, while §9 itself says the baseline's exact content is
   `VP-D10`'s still-open
   decision — the acceptance criterion and test both overclaimed a
   settled outcome. Both now assert only that the extended card is
   unconditionally withheld (`CP-D14`), deferring the baseline's content
   to `VP-D10` as §9 already did;
3. **`deletionPending` was missing from §10's anti-enumeration list,
   `PCP-AC-04`, the §13 UX-states list and the test matrix**, despite
   §3.3's own table already placing it in the not-found bucket — a
   deletion request in progress is a security-sensitive fact and must not
   become observable, exactly like `suspended`/`securityLocked`/
   `tombstoned`; added everywhere the other three already appeared.
   Additionally, §13's first UX-state bullet incorrectly implied any
   `AccountStatus` withdrawal resolves to baseline-only — corrected to
   state plainly that `AccountStatus` withdrawal always resolves to
   not-found, never baseline-only, which only applies to pre-verification/
   `revoked` states on an otherwise `active` account.

Also, per that same review: fixes the moderation-overlay integration gap
(§4 now sources `displayName`/`avatar` from
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §16.1's overlay on the extended card,
with the cross-surface consistency question tracked as that document's
`CP-D20`); un-hedges no further than necessary the `FollowRef` mentions in
§1 to "a future accepted Follow contract"; corrects §0.1's `owner`
disambiguation, which named `relationship: owned | invited` as Scenario's
field when it is Quick Plan's (Scenario uses the Approved
`ScenarioAccessGrant` role model); narrows `PCP-D06`'s scope explicitly to
this card's own Created-content list; marks "the Review contract" as an
illustrative future example in §0's precedence order, not an already-
Approved one; and reframes the document-count language in §0 from a flat
"four sibling documents" to "three personal-identity documents plus a
`ManagedPage` peer", matching `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s own
framing.

### 0.9 v1.5 → v1.6: adopts the default-publish-trust / reactive-moderation policy

`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.4 adopted the product owner's
policy that a verified Creator's content publishes immediately by default
and is moderated reactively (on report), with a new per-item
`suspendedAfterModeration` lifecycle state distinct from `AccountStatus` or
this card's own `CardModerationState`. This document's own changes:
§4.1 now excludes `suspendedAfterModeration` items from the public
Created-content list, the same way it already excludes drafts/pending/
unpublished/archived items; §7.3 now explicitly distinguishes this
document's own card-level Report (reporting the person) from a
content-item report (reporting one specific published item, owned by
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.4) — the two are independent
mechanisms and MUST NOT be conflated.

### 0.10 v1.6 → v1.7: mirrors a correction — a report alone must never restrict publication

`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.4 was corrected immediately after
v1.6 shipped: the report itself must never restrict publication — only a
moderator's **upheld** decision does; a report merely queues for review
while the item stays fully `published`. This document's §4.1 and §7.3 are
updated to match: an item reaches `suspendedAfterModeration` (and is
excluded from this card's list) only once a moderator upholds a
content-item report, never merely because one was filed.

### 0.11 v1.7 → v1.8: the same gap existed one level up — card-level Report

A self-review after the §9.4/§0.10 correction found the identical gap in
this document's own card-level mechanism: §3.5/§7.3 described a report as
"resulting in a card moderation-state transition" without distinguishing
`underReview` (a neutral, non-restrictive "pending" flag — this is the
only state a report reaches by itself) from `restricted`/`quarantined`
(actual restrictions, which now require a moderator's confirmed decision,
exactly mirroring §9.4's content-item principle). §3.5 and §7.3 are
rewritten to state this explicitly, a new `PCP-AC-07` is added asserting
it directly, the renumbered ACs that followed are shifted accordingly, and
a test-matrix bullet is added. This is the second instance of the same
underlying mistake — an unreviewed signal (a report) treated as sufficient
to restrict something by itself — found in as many review passes; worth
treating as a standing check for any future moderation-adjacent mechanism
in this document family, not only these two.

### 0.12 v1.8 → v1.9: pending review no longer overwrites enforcement

v1.8 represented `underReview`, `restricted` and `quarantined` as mutually
exclusive values of one `CardModerationState`. That shape contradicted the
very rule v1.8 intended to establish: filing a new report against an already
restricted or quarantined card would have replaced the effective moderator
decision with the neutral `underReview` value and could therefore have made
the card less restricted. It also could not represent two concurrent open
reports safely.

This revision splits the server-owned record into two orthogonal axes:
`enforcement = clear | restricted(...) | quarantined` and
`reviewStatus = none | underReview`, backed by server-only
`activeReviewIds`. Filing a report changes only the review axis; moderator
enforcement remains unchanged. Dismissing one review removes only that
review ID, and clears `underReview` only when no active reviews remain.
The resolver, entity shape, UX, roadmap, acceptance criteria and test matrix
are updated together.

## 1. Product definition

The Public Creator Profile is a **presentation/aggregation surface**, not an
owner of state — it never stores Follow relationships, Reviews or content
itself; it projects them from their own canonical aggregates
(`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s Created-content list; a future
accepted Follow contract, once `PP-D44`/`VP-D12`/`PCP-D02` resolve one,
§7.1; `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s Reviews-authored) and renders a
safe read view for another authorized account.

It answers, for a viewing account: **"who is this Creator, and what have
they published?"** It is a strict superset of
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.2's Public User Projection (display
name, avatar, optional city) — every field that projection allows, this
document also allows, plus the fields §4 adds once the subject is a
`verified` Creator with an activated public card.

It is not:

- a fourth global role or `Pro` tier;
- the owner of verification mechanics (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`);
- the owner of private personal libraries, `AccountStatus`, or the base
  Follow relationship (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`);
- a `ManagedPage` public projection — a Professional Page's own public page
  is `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §8.2's subject; this document
  MAY link to it by ID, never duplicate its field list;
- a messaging surface (§8);
- an authorization shortcut based on verified-badge presence.

## 2. Full-release extension policy

| Class | Meaning |
|---|---|
| Release foundation | Required for the public card to be coherent and safe |
| Mature extension | Valuable for full release and suitable for incremental, reversible slices |
| Gated expansion | Retained in target architecture but blocked on backend, legal, moderation or operational readiness |

A capability is retained only if it (1) solves a recurring discovery job,
(2) reuses the sibling documents' canonical data rather than duplicating it,
(3) degrades honestly offline, (4) does not silently broaden access or
expose sensitive data, (5) ships behind a bounded flag with tests and
rollback.

## 3. Visibility, verification and moderation — five independent axes

```text
Account status
  active | securityLocked | suspended | deletionPending | tombstoned
  (owned by VIEWER_PROFILE_FUNCTIONAL_SPEC.md §15.1 — this document only
  reacts to it, using its exact camelCase values, §3.3)

Creator verification
  notStarted | pending | verified | rejected | expired | revoked
  (owned by CREATOR_PROFILE_FUNCTIONAL_SPEC.md §5.2 — this document only
  reacts to it, §3.2)

Card visibility
  private | unlisted | public
  (owned by this document, §3.4 / PublicCreatorProfileConfig.visibility,
  §4.2 — gates only the EXTENDED card, never the baseline projection or
  Follow reachability, both owned by VIEWER_PROFILE_FUNCTIONAL_SPEC.md)

Card enforcement
  clear | restricted(restrictions[]) | quarantined
  (owned by this document, §3.5 — only a confirmed moderator decision may
  restrict the card)

Card review status
  none | underReview
  (owned by this document, §3.5 — a report may set this neutral axis without
  changing card enforcement or suspending the account)
```

These MUST NOT collapse into one status field — in particular, "reported" is
not "suspended", and "card set to private" is not "account hidden".

### 3.1 Existence versus visibility

Every account has a Public User Projection
(`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.2) regardless of Creator status.
Follow reachability against that baseline is not yet an accepted contract
(§7.1) — once the joint `PP-D44`/`VP-D12`/`PCP-D02` decision resolves it,
this document's `visibility` setting is not intended to gate that baseline
reachability, only the extended Creator card (§4); this is this document's
position for that joint decision, not a unilateral rule already in force. The extended
card exists only once verification first reaches `verified` (§3.2's
mapping) **and** the owner has explicitly activated it (§4.2); it is never
presented before that, and it is never retroactively deleted merely because
verification later lapses — it degrades per §3.2's table instead.

### 3.2 Verification-state mapping

| Verification state | Public Creator Profile (extended card) | Public User Projection (baseline) |
|---|---|---|
| `notStarted` / `pending` / `rejected` | Does not exist | Shown, as for any account |
| `verified`, card visibility = `public` | Shown, full §4 field set | Superseded by the extended card |
| `verified`, card visibility = `private`/`unlisted` | Not shown to the general public; `unlisted` resolves only via an opaque link (§3.4) | Unaffected — shown/reachable exactly as for any other account (§3.1) |
| `expired` | **Not yet decided — `PCP-D09`.** Illustrative direction only: the card likely remains with a "verification lapsed" badge and already-published content stays visible, but exact scope (Follow CTA? portfolio? indexing?) is not this document's settled rule | Unaffected |
| `revoked` | Extended card is withdrawn; falls back to Public User Projection only | Unaffected |

This mirrors `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §22.2's page cascade
(verification revoked → hidden from Discovery, but not deleted) applied to
an individual instead of a page, for the `revoked` row only. The `expired`
row is deliberately left open rather than asserted, per `PCP-D09` (§17).

### 3.3 Account-status mapping

Uses `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1's exact `AccountStatus`
values verbatim — `active | securityLocked | suspended | deletionPending |
tombstoned` — not a locally re-cased approximation.

| Account status | Card behavior |
|---|---|
| `active` | Per §3.2 and §3.5 |
| `securityLocked` / `suspended` | Extended card withdrawn; Public User Projection also withdrawn, per `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3's own rule ("withdrawn entirely, not merely degraded") — this document only reacts to that, never redefines it |
| `deletionPending` | Same as `suspended`, for the retention window |
| `tombstoned` | A direct link returns the same safe not-found response a genuinely nonexistent account would (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3's anti-enumeration rule — this document's own rendering responsibility to honor it) |

### 3.4 Card visibility states

`PublicCreatorProfileConfig.visibility` (§4.2), owner-editable, defaulting
to `private` until the owner explicitly activates the card for the first
time (§4.2's `activatedAtUtc?`):

- `private` — the **extended card** is never shown to another account,
  including via direct link; only the owner (previewing their own card) and
  Admin moderation see it. Does **not** hide the baseline projection or
  Follow reachability (§3.1) — those are `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s
  own axis and are unaffected by this setting.
- `unlisted` — the extended card is not surfaced in Search/Discover or
  Follow suggestions. **Resolution requires an opaque, revocable link or
  token — not a guessable `userId` or handle-based URL** (`PCP-D10`, §17):
  if the link is built only from a stable identifier, `unlisted` is merely
  undiscoverable, not access-controlled, and the implementation MUST be
  honest about that distinction. A blocked viewer
  (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3) does not get this exception regardless of
  token possession (§3.6).
- `public` — the extended card is indexable in Search/Discover, subject to
  `PCP-D01`'s exact indexing/ranking rules (open).

An account with zero published `{type:user}` content and `public`
visibility MAY still show a minimal card (identity header, "no published
content yet") rather than being hidden — hiding an active verified Creator
outright because they have not yet published is a worse experience than an
honest empty state; exact threshold is `PCP-D01`.

### 3.5 Card moderation — independent enforcement and review axes

Independent of the three axes above and independent of each other.
`restricted` is a **structured list**, not a bare flag, so a single field or
module can be restricted without withdrawing the whole card:

```text
CardEnforcement = clear
  | restricted({ restrictions: [{ target, reasonCode, expiresAtUtc? }] })
  | quarantined

CardReviewStatus = none | underReview
```

- enforcement `clear` — normal display.
- review status `underReview` — **the only axis a report or automated flag
  changes by itself, automatically, with no moderator action required.** It
  restricts nothing and never overwrites enforcement: a `clear` card remains
  fully visible, a `restricted` card keeps every existing restriction, and a
  `quarantined` card remains quarantined. The card continues to use its last
  approved field values (§16 of the sibling document, referenced not
  redefined), unless account status independently withdraws it (§3.3).
- `restricted` — reached **only by a moderator's confirmed decision**,
  never automatically by a report alone (mirrors
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.4's identical principle for a
  content-item report). Each entry in `restrictions` names one hidden
  target (e.g. `"follow"`, `"portfolio"`, or a specific field) with a
  reason code and optional expiry, without withdrawing the rest of the
  card.
- `quarantined` — reached **only by a moderator's confirmed decision**,
  never automatically. The extended card is withdrawn (falls back to
  baseline Public User Projection) as a moderation action short of full
  account suspension.

A dismissed report removes only its own opaque ID from `activeReviewIds`.
`reviewStatus` returns to `none` only when no active review remains;
enforcement is unchanged. An upheld report also concludes that review and
MAY change enforcement through the moderator's explicit decision. Concurrent
reports therefore never erase each other or weaken an existing restriction.
The record invariant is exact: `reviewStatus == underReview` iff
`activeReviewIds` is non-empty; `reviewStatus == none` iff it is empty.
Report create/dismiss/uphold commands update that set idempotently under the
record's `revision` check.

Exact transition triggers, SLA and appeal path: `PCP-D06`.

### 3.6 Resolver — one deterministic outcome per axis combination

Applied in this fixed order — account status first (broadest), then the
requester's Block relationship to the subject, then the subject's minor
eligibility gate, then verification (as an **explicit enumeration**, not a
"not verified" catch-all that would ambiguously overlap `expired`), then
card visibility/token validity, then card enforcement (narrowest); review
status is applied afterward as a non-restrictive decoration —
producing exactly one of `notFound | baselineProjection | extendedCard |
extendedCardWithRestrictions`:

| Step | Combination | Resolved outcome |
|---|---|---|
| 1. Account status | `tombstoned` (any other axis) | `notFound` |
| 1. Account status | `suspended` / `securityLocked` (any other axis) | `notFound` (§3.3 — both projections withdrawn) |
| 1. Account status | `deletionPending` (any other axis) | `notFound` — same treatment as `suspended`/`securityLocked`, for the retention window; a deletion request in progress MUST NOT itself become an observable account state (§10) |
| 2. Block | `active` + requester is blocked by or has blocked the subject (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3 — bidirectional by default) | `notFound` — Block removes visibility of **both** the baseline projection and the extended card, in both directions; it is stronger than "extended card withheld", not weaker |
| 3. Minor gate | Subject is a known minor (§9) | `baselineProjection`, **pending `VP-D10`** — this row is provisional, not a settled outcome: it reflects the illustrative direction in §9, and MUST be revisited once `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` `VP-D10` resolves what a minor's baseline itself may contain. The extended card (§4) is withheld regardless of what `VP-D10` decides — that part is settled (`CP-D14` gates it independently) |
| 4. Verification (explicit values, not blocked, not a gated minor) | `notStarted` / `pending` / `rejected` / `revoked` | `baselineProjection` |
| 4. Verification | `expired` | Per `PCP-D09` once decided; until then, `extendedCardWithRestrictions` with the badge as the only guaranteed-safe field (conservative default, not the final rule) — never silently folded into the "not verified → baseline" row above, since `expired` is a distinct state with its own §3.2 row |
| 4. Verification | `verified` | proceed to step 5 |
| 5. Visibility/token (`verified`, not blocked, not a gated minor) | `private` | `baselineProjection` (extended card withheld, §3.4 — baseline itself is unaffected) |
| 5. Visibility/token | `unlisted` + no/invalid token | `baselineProjection` |
| 5. Visibility/token | `unlisted` + valid token | proceed to step 6 |
| 5. Visibility/token | `public` | proceed to step 6 |
| 6. Card enforcement (`verified`, visible per step 5) | `clear` | `extendedCard` |
| 6. Card enforcement | `restricted(restrictions[])` | `extendedCardWithRestrictions` (per `restrictions[]`, §3.5) |
| 6. Card enforcement | `quarantined` | `baselineProjection` |
| Review decoration (orthogonal to step 6) | `underReview` with any enforcement value | Preserve step 6's resolved outcome unchanged. A pending-review indicator MAY appear only inside an `extendedCard*` response; it is suppressed for `baselineProjection`/`notFound`, so it cannot reveal a withheld card. Use last-approved field values (§16 of the sibling document). A report never upgrades an outcome or removes an existing restriction |
| Field-level (within any `extendedCard*` outcome) | A field with no `lastApprovedPublicValue` yet (first submission) | Field renders as **absent**, never blank |

Step 3 (minor gate) is deliberately placed **before** verification: a
minor's extended-card eligibility is not a function of whether they are
`verified` — `CP-D14` may forbid minors from becoming verified Creators at
all, in which case step 3 never matters for them, but if `CP-D14` is ever
accepted with conditions, the gate must still apply independently of
verification status, not be inferred from it.

The Block check (step 2) runs before verification/visibility precisely so
that a valid `unlisted` token or `public` visibility can never be used to
route around an active Block — a bug in an earlier revision of this
resolver treated a blocked `unlisted`-token holder as still entitled to the
baseline projection, contradicting `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`
§12.3's "removes both accounts' ability to view each other's card/
projection" rule; that row is corrected above.

## 4. Public card field set (release foundation)

Extends `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.2's baseline
(`displayName`, `avatar`, optional `city`) with, subject to §3.6's resolver:

- `displayName`/`avatar` themselves, on the extended card, are read from
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §16.1's
  `IdentityFieldModerationOverlay` when a row exists for this account
  (i.e. once it has been `VerifiedCreatorIdentity`), not from raw
  `UserProfile` — the same `lastApprovedPublicValue`/absent-not-blank rule
  as `headline`/`specialtyTagIds` below applies. **Whether the baseline
  projection this document extends does the same is not yet settled** —
  that is `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-D20`, owned by
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` to accept; until `CP-D20` resolves,
  this document's own extended-card sourcing rule above is correct in
  isolation, but the two documents' verified-against snapshots do not yet
  represent a fully reconciled identity-field display across every
  surface;
- safe verification badge (three states only: verified / lapsed / none —
  never `rejected`/`revoked` internal detail);
- `headline`, `specialtyTagIds` (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.2),
  shown at `lastApprovedPublicValue` (or absent, if none exists yet) even
  while `ownerDraftValue` is under review
  (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §16);
- `about`, only if `PublicCreatorProfileConfig.aboutOptIn` is set (§4.2);
- the Created-content list, scoped exactly as
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.3 defines it —
  `PublisherRef == {type:user, id:userId}` only, filtered to each item's own
  public-visibility state and lifecycle stage (published only);
- a Follow CTA and follower count — **only once the joint
  `PP-D44`/`VP-D12`/`PCP-D02` decision is accepted** (§7.1); until then this
  row does not exist on the card, it is not merely undesigned display —
  consuming `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s base `FollowRef`
  relationship once that decision resolves; this document does not own who
  may follow whom;
- portfolio gallery, once `PCP-D03` is accepted;
- aggregated review summary **on published content**, once `PCP-D04` is
  accepted — this does not depend on person-level reviews (§6);
- a computed Creator level/rating, once `PCP-D08` is accepted — explicitly
  **not** part of this document's release-foundation scope (§6.1).

MUST NOT expose: email, phone, verification evidence, private
Favorites/Visit History/Notifications/drafts
(`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.1), membership/team data on any
Professional Page this account manages, or precise location beyond an
opted-in `city`.

### 4.1 Content attribution correctness

The Created-content list on this card MUST exclude anything the account
merely authored/actor'd under a different `PublisherRef`
(`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.2, §9.3, `CP-AC-05`) — a page's
content is never shown as this person's personal publication just because
they happen to manage that page. It MUST also exclude any item in
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.4's `suspendedAfterModeration`
state — the same lifecycle-stage filter that already excludes
`durableDraft`, `pendingModeration`, `rejected`, `unpublished` and
`archived` extends to this state. This state is reached only by a
moderator **upholding** a content-item report, never by the report alone
— an unreviewed report never removes an item from this list — and is
distinct from account- or card-level moderation (§3.5): a content-item
report is **not** the same mechanism as this document's own §7.3
card-level Report, and does not by itself change card enforcement, card
review status or `AccountStatus`.

```text
PublicCreatorProfileConfig {
  userId,
  visibility: private | unlisted | public,     // default: private
  activatedAtUtc?,                             // set on first non-private
                                                 // visibility change
  aboutOptIn: bool,                             // default: false — `about`
                                                 // has no baseline exposure
                                                 // at all (see §12.1 of the
                                                 // Viewer sibling doc), so
                                                 // this is a genuine
                                                 // extended-card-only opt-in
  followerVisibilityPolicy: countVisible | countHidden,
  publicContactPolicy: none | safeChannel(kind),
  socialLinks: [SocialLinkEntry],
  revision, schemaVersion
}

SocialLinkEntry {
  id, platform, url,
  displayOrder,
  moderationStatus: clear | queued | rejected,
}
```

**There is no `cityOptIn`.** `city` is part of the baseline Public User
Projection already (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.1 owns its
default/opt-in there); the extended card **inherits** whatever that
baseline decision is rather than exposing a second, independent toggle —
§1 states this document is a strict superset of the baseline, and a
separate extended-card-only override that could hide `city` while the
baseline still shows it would silently break that guarantee. `about` has
no baseline equivalent at all, so `aboutOptIn` remains a genuine
extended-card-only setting.

`socialLinks` entries have a stable `id` independent of array position (for
reordering and deep-linking to a moderation decision), and `platform` is
unique per config — two entries for the same platform are rejected, not
silently overwritten. A moderation-rejected or dead link is hidden from
display without deleting the entry, so the owner can fix and resubmit
rather than re-enter it. Supported platforms, URL allowlist/validation,
dead-link detection, `safeChannel.kind` values, address verification,
anti-spam/rate limiting and provider-failure fallback: `PCP-D11`.

`publicContactPolicy.safeChannel(kind)` never embeds a raw contact address
in the card payload — the channel is resolved server-side per request
(e.g. a routed message or a provider-hosted contact form), with the
underlying address itself verified before it is ever offered as a channel.
This is required precisely because §4 forbids exposing email/phone
directly: a naive `safeChannel` implementation that echoes the raw address
would violate that rule silently.

**Card moderation (§3.5) is not part of this entity** — it is a separate,
server-owned projection, never client-writable through this config:

```text
CardModerationRecord {
  userId,
  enforcement: clear | restricted(restrictions[]) | quarantined,
  reviewStatus: none | underReview,
  activeReviewIds: [opaqueReviewId], // server-only; never in public payload
  decidedAtUtc?,
  updatedAtUtc,
  moderatorActorRef?,        // opaque audit reference, never displayed
  appealId?,                 // links to the report/appeal flow, §7.3
  revision, schemaVersion    // optimistic concurrency, same fail-closed
                              // rule as §16 of the sibling document
}
```

`restrictions[].target` is a versioned identifier/enum
(`follow | portfolio | about | headline | specialtyTagIds | ...`), not a
free-form string, so an unrecognized value can fail closed rather than
silently matching nothing.

### 4.3 Activation and configuration edge cases

- The owner MAY edit `PublicCreatorProfileConfig` (as a draft) before
  verification reaches `verified` — nothing here requires `verified` to
  *configure* the card, only to *activate* it (below);
- setting `visibility` to anything other than `private` (activating the
  card) requires `VerifiedCreatorIdentity`
  (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.1); an attempt while
  unverified fails closed and `visibility` remains `private`;
- an inconsistent stored state — `visibility != private` with
  `activatedAtUtc` absent — is treated as `private` until a valid
  `activatedAtUtc` exists; this is a defensive read-time rule, not an
  expected write path;
- an unrecognized/future `visibility`, `moderationStatus` or
  `restrictions[].target` value fails closed to the most restrictive
  interpretation available (e.g. an unknown `visibility` renders as
  `private`) rather than being ignored or defaulting open;
- every `PublicCreatorProfileConfig` mutation requires the `revision` it
  was based on plus an idempotency key; a stale `revision` is rejected
  rather than silently overwritten, the same fail-closed pattern as §16 of
  the sibling document.

The owner edits `PublicCreatorProfileConfig` from
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s Settings surface — that document's
§4.2 links here rather than redefining the fields (not its §7, which
covers capabilities, not settings navigation); this document owns the
entity's shape and display rules.

## 5. Relationship to a managed Professional Page

If this account manages one or more Professional Pages, the public card MAY
show a link to each page's own public projection by ID
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §8.2), never inline duplication of
that page's field set, team, or content list. Exact display rule (a
dedicated "Pages" section versus no cross-link at all) is `PCP-D05`.

## 6. Reviews — two independent features, not one dependency chain

`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §9 separates "reviews about published
content" from "reviews about a person" and defers the latter to its own
open decision, `VP-D08`. These are **two different features with
independent dependencies**:

- **Reviews about published content** — an aggregated rating shown on this
  card for the account's own `{type:user}`-published items. This does
  **not** depend on `VP-D08` at all; it depends only on `PCP-D04`
  (computation, minimum sample size, display placement) and the underlying
  canonical Review contract existing.
- **Reviews about this account as a person** — out of this document's
  design scope. If Recharge ever supports this, it is entirely gated on
  `VP-D08` being accepted first, and this document would need a new,
  separate decision for its display (not `PCP-D04`, which is scoped to
  content).

Until `PCP-D04` is accepted, no content-review score/count renders — an
absent feature, not a zero. Person-level review display is not designed at
all pending `VP-D08`.

### 6.1 Creator level/rating — explicitly next-stage, not release foundation

A gamification-style "Creator level" (a computed tier surfaced on the
public card, distinct from the verification badge) was raised during
review as a future direction. This document intentionally does not design
it now, and explicitly excludes **account age** as a candidate input:
rewarding tenure independent of quality, indirectly revealing account age,
creating gaming incentives, and reading as an unearned authority signal are
all unforced risks for a feature that is already gated and undesigned.

- MUST NOT be confused with `CreatorVerificationStatus`
  (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §5.2) — verification is a trust/
  identity fact set by moderation; a level is a computed engagement metric
  and grants no capability, exactly like every other display-only field in
  this document (§1);
- MUST NOT gate any capability, module or Discover placement by itself —
  the same non-authorization rule `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
  §4.3(4) applies here; a "level" is display only until (and unless) a
  separate entitlement decision says otherwise (`PCP-D08`);
- depends on `PCP-D04` (content review aggregation) and cannot be scoped
  before that is accepted;
- tracked as `PCP-D08` (§17); Gated expansion until scoped.

## 7. Follow, block and report

### 7.1 Follow is a joint decision, not this document's model

Follow is **not yet an accepted contract anywhere in the sibling
documents** — the same status `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.4
states about its own proposal, and this document must not contradict that
by presenting a different, independently-designed Follow model. This
document's `PCP-D02` is the public-card half of the joint
`PP-D44`/`VP-D12`/`PCP-D02` decision, not a self-contained design.

**This document's own proposed position**, for input into that joint
decision:

- the extended card displays a Follow CTA and follower count, consuming
  whichever base `FollowRef` model the joint decision adopts — it does not
  itself decide who may follow whom, whether approval is required, or
  retention/consent rules;
- `followerVisibilityPolicy` (§4.2) controls only whether the **count** is
  shown on this card, never whether Follow itself is possible;
- if `unlisted`/`private` visibility is ever allowed to restrict Follow
  reachability specifically (as opposed to the baseline projection, which
  it does not restrict per §3.1), that interaction is part of the joint
  decision, not decided unilaterally here.

### 7.2 Block and mute — fully owned by `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`

`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3 is the **sole** canonical source
for Block/Mute mechanics: the Block/Mute distinction itself, bidirectional
Block by default (including its effect on this document's own card, per
§3.6's resolver), one-directional Mute, and the split between what an
owning aggregate (e.g. a shared Scenario) still shows versus what this
document's card shows. This document has no independent Block/Mute model
and does not establish, split, or co-define any part of it — an earlier
revision implied a two-way "each document establishes half the split"
relationship with that section, which was circular (each document citing
the other as the source) rather than a real ownership split; this section
now only consumes the result.

This document's own remaining scope is narrower than Block/Mute mechanics
themselves: whether **pre-existing shared content state** (e.g. a jointly
visible Scenario predating the Block) is retroactively hidden from this
card's Created-content list versus only blocking new joint interaction —
tracked as `PCP-D06`.

### 7.3 Report

Report on a card follows the same audited report/appeal flow as
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D25`, generalized to a person.
**The report by itself adds one opaque review ID and sets `reviewStatus =
underReview` — a neutral, non-restrictive axis (§3.5).** Nothing is hidden,
removed or withdrawn at that point, and any existing `restricted` or
`quarantined` enforcement remains in force. Only a moderator's subsequent
confirmed decision can change enforcement to `restricted` or `quarantined`;
the report never causes either directly, and never automatically causes an
`AccountStatus` suspension either — that remains
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s own
decision to make, informed by but not automatically triggered by a
card-level report. Admin reviewing a report never becomes this account's
publisher (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §1's principle).

**This is a card-level report — reporting the person.** Reporting a
*specific published item* is a separate, narrower mechanism owned by
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §9.4: the item stays fully published
while the report is queued, and only a moderator's upheld decision
suspends that one item (`suspendedAfterModeration`, excluded from this
card's list per §4.1) — the report by itself never does, and neither
outcome touches card enforcement, card review status or `AccountStatus`. The two
report mechanisms are independent and MUST NOT be conflated — a person can
have `clear` card enforcement while one specific item of theirs is
`suspendedAfterModeration`, and vice versa.

## 8. Direct messaging — explicitly out of scope here

Person-to-person messaging, if ever built, is a **gated expansion** per
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s classification rationale (higher
abuse/harassment surface than page operational messaging). This document
defines no messaging entry point on the public card until that gate clears;
a "Contact" affordance, if any, routes to the safe contact channel the
owner explicitly opts into (`publicContactPolicy`, §4.2), never to an
inbox.

## 9. Minors (deferred, fails closed — two independent gates)

A minor account's exposure on this card depends on **two independent,
separately owned decisions**, not one:

- `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-D14` — whether a minor may ever
  become a `verified` Creator at all (gates the extended card, §4,
  entirely);
- `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` `VP-D10` — the minor's own baseline
  Public User Projection policy, which this document's baseline (§3.1)
  inherits regardless of Creator status, and which that document also
  notes may further restrict who may follow/be followed by a minor
  (`VP-D12`).

Until both exist, this document requires the extended card (§4) to fail
closed for a known-minor account, and the baseline projection to follow
whatever `VP-D10` resolves.

## 10. Handle and deep links (public-management half)

- A deep link resolved by `userId` MUST NOT depend on the current display
  handle (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §17 owns rename mechanics).
- A retired handle redirects to the current one rather than 404s or
  resolving to an unrelated account — the same principle
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §22.4 applies to a page `slug` —
  **except** where the redirect itself would leak a public→private
  visibility transition or a rename intended to distance the account from
  a prior identity; exact handling is `PCP-D10`.
- Resolving a handle/link MUST NOT leak `AccountStatus`
  (`suspended`/`securityLocked`/`deletionPending`/`tombstoned`, §3.3)
  across any externally observable signal — HTTP/app status, response
  shape, visible UI, redirect target, cache headers and response timing
  must all be indistinguishable from the nonexistent-account case,
  including timing-side-channel resistance where feasible. `deletionPending`
  is explicitly included here, not only in §3.3's table: an account
  mid-deletion is a security-sensitive fact in its own right, and a
  deletion request in progress MUST NOT become observable to another
  account through this surface. `private` card visibility (§3.4) is **not**
  part of this anti-enumeration requirement — it never hid the account's
  existence in the first place (§0.4(4)).

## 11. International display (open — no assumed data owner)

This document does not assume where a translatable public field's locale
data lives — `UserProfile` (`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.1) does
not currently define `defaultLocale` or per-locale content, and Settings
"language" may be a local UI preference rather than a publisher-content
locale. Open, tracked as `PCP-D07`:

- which fields (`headline`, `about`, ...) are ever translatable at all;
- where locale data and translation ownership live;
- fallback-locale behavior when the viewer's locale has no translation;
- whether partial translation blocks publication (mirrors
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D23`, scoped to a person).

`city` remains a display string, not a stable location ID with independent
geocoding authority, consistent with `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
§4.1's `UserProfile.city` field — this much is settled; the localization
question above is not.

## 12. Security, privacy, offline and operations

- Public projections exclude every field §4 does not explicitly allow.
- Deep links revalidate the resolver (§3.6) on every load, not only at
  cache time.
- Logs/analytics use opaque IDs and stable reason codes.

### 12.1 Operational and security requirements

- rate limits and idempotency keys on Follow (once its owning contract
  exists), Report and any future Contact action;
- cache invalidation triggered by: verification state change, account
  status change, card visibility change, Block/unblock, and card
  enforcement or review-status change — a TOCTOU window between a visibility
  change and an in-flight Follow/view request must fail closed to the more
  restrictive state;
- **offline safety floor:** a maximum cache TTL for any card projection;
  `unlisted` and `private`-adjacent (owner-preview) card data MUST NOT be
  served from cache without a fresh authorization check, regardless of
  freshness label; every interactive action (Follow, Report, Contact) is
  disabled while offline, never optimistically queued against a stale
  authorization state;
- pagination for the Created-content list and (once built) the follower
  list, with defined stale-page/cursor-invalidation behavior;
- maximum field lengths and Unicode normalization for `headline`/`about`;
- a URL allowlist and validation policy for `socialLinks` (§4.2, `PCP-D11`);
- media processing requirements for portfolio content — EXIF/location
  stripping and license-evidence retention (mirrors
  `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-D07`);
- audit events with stable reason codes for Block, Report, review-status
  changes and moderator enforcement decisions;
- independent feature flags/kill switches for: card display itself, Follow
  CTA, portfolio display, review-summary display;
- observability for anti-enumeration failures (§10) as a security-severity
  signal, not routine error logging.

## 13. Required UX states

- baseline Public User Projection only, `active` account, pre-verification
  or verification `revoked` (§3.2) — note this is distinct from any
  `AccountStatus` withdrawal, which resolves to not-found instead (below),
  never to a baseline-only state;
- extended card, `public` visibility, with and without published content
  (§3.4);
- extended card, `unlisted`, resolved only via an opaque link/token;
- extended card, `private` — extended fields withheld, baseline still
  reachable elsewhere (§3.1, §0.4(4));
- lapsed-verification badge state (`expired`) — pending `PCP-D09`'s exact
  scope, not a fixed target state (§3.2);
- `AccountStatus`-driven not-found, indistinguishable across every
  observable signal (§10), for `suspended`/`securityLocked`/
  `deletionPending`/`tombstoned` — all four, not only three;
- every combination of card review status (`none`/`underReview`) with
  enforcement (`clear`/`restricted(...)`/`quarantined`), including an
  already-restricted card receiving another report (§3.5), all distinct
  from account suspension;
- Follow CTA rendered, pending the joint decision on the underlying model
  (§7.1);
- blocked-viewer state, per `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3;
- moderation-under-review field state showing `lastApprovedPublicValue` or
  absent-not-blank for a never-approved field (§4);
- minor-account state: extended card unconditionally withheld (`CP-D14`);
  baseline content pending `VP-D10` (§3.6 step 3, §9);
- Admin presentation preview with no authority.

All critical flows must support en/ru/lv-ready strings, 360 dp width, 150%
text scale, keyboard/screen-reader semantics and no color-only status
meaning.

## 14. Delivery roadmap

| Slice family | Scope | Class | Key dependency |
|---|---|---|---|
| PCP-01 Baseline card | Public User Projection + extended-card gating per §3 | Release foundation | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-01 |
| PCP-02 Created-content display | Attribution-correct list per §4.1 | Release foundation | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-03 |
| PCP-03 `PublicCreatorProfileConfig` | Visibility, opt-ins, follower/contact policy, social links backend | Release foundation | `PCP-D11` |
| PCP-04 Handle resolution | Redirect + anti-enumeration per §10 | Release foundation | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-13 |
| PCP-05 Card moderation axes | independent enforcement and review status (§3.5), including concurrent-report preservation | Release foundation | Moderation infra |
| PCP-06 Cache/revocation propagation | §12.1's invalidation triggers, TOCTOU handling, offline safety floor | Release foundation | PCP-01 |
| PCP-07 Search/Discover indexing | `public`-visibility ranking/indexing | Mature extension | `PCP-D01` |
| PCP-08 Follow display | Card-side CTA/count once the joint model (§7.1) is accepted | Mature extension | `PP-D44`/`VP-D12`/`PCP-D02` jointly resolved |
| PCP-09 Portfolio display | Public gallery rendering | Mature extension | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-08 |
| PCP-10 Report/quarantine | §7.3 mechanics, card-level moderation transitions | Mature extension | `PCP-D06` |
| PCP-11 Content-review display | Aggregated summary on published content | Mature extension | `PCP-D04` |
| PCP-12 Localization | Translatable fields, fallback locale | Mature extension | `PCP-D07` |
| PCP-13 Legal/privacy review | Data export/erasure, retention windows | Mature extension | Legal sign-off |
| PCP-14 Person-level reviews | Only if `VP-D08` is ever accepted | Gated expansion | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` VP-D08 |
| PCP-15 Minors policy | Full gating once both `CP-D14` and `VP-D10` resolve | Gated expansion | Both cited decisions |
| PCP-16 Creator level | §6.1 | Gated expansion | `PCP-D04`, `PCP-D08` |

## 15. Acceptance criteria

### Visibility, verification and moderation

- **PCP-AC-01:** Account status, Creator verification, card visibility, card
  enforcement and card review status are evaluated as five independent
  inputs, resolved only through §3.6's resolver; no ad hoc combination
  bypasses it.
- **PCP-AC-02:** The extended card exists only once verification first
  reaches `verified` **and** the owner has explicitly activated the card
  (§4.2); it is never shown before both are true.
- **PCP-AC-03:** `revoked` verification withdraws the extended card and
  falls back to the baseline Public User Projection; the `expired` card's
  exact behavior is not asserted as settled until `PCP-D09` is accepted.
- **PCP-AC-04:** `AccountStatus` values `suspended`/`securityLocked`/
  `deletionPending`/`tombstoned` all four produce a not-found response
  indistinguishable from a nonexistent account across status, shape, UI,
  redirect, cache headers and timing; `private` card visibility does
  **not** produce this response.
- **PCP-AC-05:** `unlisted` resolves only via an opaque, revocable
  link/token — never a guessable `userId`/handle URL — and never appears
  in Search/Discover/Follow suggestions; a valid token never overrides an
  active Block (§3.6).
- **PCP-AC-06:** Card review status `underReview` and enforcement
  `restricted`/`quarantined` (§3.5) do not imply the owning account is
  `suspended`, and vice versa.
- **PCP-AC-07:** A report by itself changes only review status to
  `underReview` and adds its opaque review ID — never enforcement, account
  status or content visibility. Existing `restricted`/`quarantined`
  enforcement remains effective; only a moderator's confirmed decision may
  change it (§3.5, §7.3).

### Field correctness

- **PCP-AC-08:** The public field set never includes email, phone,
  verification evidence, private libraries or team/membership data.
- **PCP-AC-09:** The Created-content list excludes anything published under
  a different `PublisherRef`, even if this account authored it.
- **PCP-AC-10:** A field under moderation review displays
  `lastApprovedPublicValue` when one exists, and renders as **absent**
  (never blank) when none exists yet; `ownerDraftValue` is visible only to
  the owner.
- **PCP-AC-11:** No content-review score/count renders until `PCP-D04` is
  accepted; a person-level review score never renders regardless of
  `PCP-D04`, unless `VP-D08` is separately accepted first.

### Follow, block, report

- **PCP-AC-12:** This document renders no Follow model claim beyond §7.1's
  stated proposal; it does not present Follow mechanics as settled ahead of
  the joint `PP-D44`/`VP-D12`/`PCP-D02` decision.
- **PCP-AC-13:** Block/Mute mechanics are read from
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3, never independently
  redefined here.
- **PCP-AC-14:** A minor account's extended card (§4) is withheld
  unconditionally, gated on `CP-D14`; the exact content of the baseline
  projection shown instead is `VP-D10`'s open decision (§3.6 step 3) — this
  criterion does not assert a specific baseline shape ahead of that
  decision.
- **PCP-AC-15:** Report never makes Admin this account's publisher; it adds
  an active review and sets neutral `reviewStatus = underReview`, never an
  implicit `AccountStatus` suspension or enforcement change.

### Data and operations

- **PCP-AC-16:** `PublicCreatorProfileConfig` (§4.2) is the sole owner of
  `visibility`/`aboutOptIn`/`followerVisibilityPolicy`/
  `publicContactPolicy`/`socialLinks`; no other document defines these
  fields; there is no `cityOptIn` (§4.2 — `city` inherits the baseline
  Public User Projection's own visibility unconditionally), and
  `CardModerationRecord` is never client-writable
  through this config.
- **PCP-AC-17:** A visibility, verification, enforcement or review-status
  change invalidates cached card reads within the bound defined by `§12.1`; an
  in-flight request during that window resolves to the more restrictive
  state, never the stale permissive one; `unlisted`/owner-preview data is
  never served from cache without a fresh check.
- **PCP-AC-18:** `publicContactPolicy.safeChannel` never embeds a raw
  email/phone in the served payload, regardless of `kind`.

### Quality

- **PCP-AC-19:** en/ru/lv-ready labels, 360 dp and 150% text scale are
  covered.
- **PCP-AC-20:** Unit, widget, integration and negative security/privacy
  tests are proportional to each slice.
- **PCP-AC-21:** `flutter analyze`, `flutter test`, boundary and diff
  checks pass for every implementation slice.
- **PCP-AC-22:** `LAUNCH_STATUS.md` records exact implementation evidence
  and remaining gates.

## 16. Required test matrix

The account-status × verification-state × card-visibility × enforcement ×
review-status space is **5 × 6 × 3 × 3 × 2 = 540** combinations in full.
Full
enumeration is impractical; coverage strategy is:

- pairwise coverage across all five axes as the general-case baseline;
- every §3.6 resolver row tested explicitly, individually, regardless of
  pairwise sampling;
- `suspended`/`securityLocked`/`deletionPending`/`tombstoned` — all four —
  direct-link responses verified indistinguishable from a nonexistent
  account across status, response shape, UI, redirect, cache headers and
  timing, including `deletionPending` specifically (a deletion request in
  progress MUST NOT be observable); `private` visibility explicitly tested
  to confirm it does **not** produce this response
  (distinguishing it from the `AccountStatus` cases above);
- Created-content list snapshot excluding a page-published item the account
  authored;
- moderation-queued headline/specialty-tag edit: `lastApprovedPublicValue`
  (or absent-not-blank, for a never-approved field) stays visible publicly
  while `ownerDraftValue` differs for the owner;
- a valid `unlisted` token held by a blocked viewer resolves to
  `notFound` — the Block check (resolver step 2) runs before token
  validation and overrides it unconditionally, never falling back to
  `baselineProjection` or `extendedCard` (§3.6);
- minor-account extended card is withheld regardless of verification state
  (`CP-D14`); the baseline projection's exact content in that case is
  re-tested once `VP-D10` resolves rather than asserted now (§3.6 step 3);
- a card-level report by itself adds an active review and changes only
  `reviewStatus` to `underReview`; a `clear` card renders unchanged, an
  already-`restricted` card keeps exactly its restrictions, and an already-
  `quarantined` card remains at `baselineProjection` with no review metadata
  leaked into that baseline response;
- two concurrent reports produce two server-only active review IDs;
  dismissing one leaves `reviewStatus = underReview`, dismissing the last
  returns it to `none`, and neither dismissal changes enforcement;
- only a moderator's upheld decision may change enforcement to `restricted`
  or `quarantined`, without clearing any unrelated active review;
- handle rename redirect preserves an existing deep link, except where
  `PCP-D10` requires suppressing the redirect;
- localization fallback when a translation is missing, once `PCP-D07`
  resolves whether translation exists at all;
- offline: cached card never allows a live Follow/Report/Contact action;
  `unlisted`/owner-preview data never renders from a stale cache without a
  fresh check;
- cache invalidation propagates within the bound from §12.1 across
  verification change, visibility change, enforcement change and review-
  status change, including a concurrent-request TOCTOU test.

## 17. Decisions required before implementation

1. **PCP-D01 — Indexing and empty-card threshold:** exact Search/Discover
   ranking inputs for a `public` card, and whether/when a zero-content
   verified Creator is hidden versus shown with an empty state (§3.4).
2. **PCP-D02 — Follow display, this document's half of the joint decision:**
   CTA/count placement and interaction with `followerVisibilityPolicy` —
   contingent on `PP-D44`/`VP-D12` resolving the underlying model first
   (§7.1).
3. **PCP-D03 — Portfolio rights:** display-side rules (ordering, moderation
   surfacing) layered on `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-D07`'s
   upload/rights decision.
4. **PCP-D04 — Content-review aggregation display:** whether the public
   card shows a computed rating on published content, and if so its
   computation and minimum sample size. Independent of `VP-D08` (§6).
5. **PCP-D05 — Page cross-link display:** dedicated section versus no
   inline reference to a managed Professional Page at all (§5).
6. **PCP-D06 — Report and card-visibility interaction with Block:** report
   categories, appeal path, enforcement decision triggers/SLA and review
   lifecycle (§3.5), and — scoped specifically to **this card's own Created-content
   list** (§7.2; not shared state on another aggregate, which
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` owns) — whether Block retroactively
   hides pre-existing entries there or only blocks new joint interaction.
7. **PCP-D07 — Localized public fields and data ownership:** which fields
   are translatable, where locale data and translation ownership live,
   fallback-locale behavior (§11).
8. **PCP-D08 — Creator level/rating:** whether a computed gamification tier
   is ever shown, its inputs (excluding account age, §6.1), formula,
   minimum sample size and display placement — explicitly out of
   release-foundation scope.
9. **PCP-D09 — Expired-verification card scope:** exactly what remains
   active on an `expired`-verification card — badge only, or also Follow,
   portfolio, indexing — and any grace period (§3.2).
10. **PCP-D10 — Unlisted access and handle-redirect privacy:** bearer- vs.
    recipient-bound opaque token generation/rotation/replay-protection/
    revocation for `unlisted` access (§3.4); referrer/analytics leakage
    prevention; whether a handle-rename redirect is ever suppressed to
    avoid leaking a public→private transition (§10).
11. **PCP-D11 — `PublicCreatorProfileConfig` data contract:** supported
    `socialLinks` platforms, URL allowlist/validation, dead-link detection;
    the exact `safeChannel.kind` values, their address-verification
    requirement, anti-spam/rate limiting and provider-failure fallback for
    `publicContactPolicy` (§4.2).

### 17.1 Decision tracking

| Decision | Status | Target slice (§14) | Owner | Gate |
|---|---|---|---|---|
| PCP-D01 | Open | PCP-07 | TBD | — |
| PCP-D02 | Open | PCP-08 | TBD | Joint with `PP-D44`/`VP-D12` |
| PCP-D03 | Open | PCP-09 | TBD | Depends on CP-D07 |
| PCP-D04 | Open | PCP-11 | TBD | — |
| PCP-D05 | Open | PCP-01 | TBD | — |
| PCP-D06 | Open | PCP-10 | TBD | Moderation infra |
| PCP-D07 | Open | PCP-12 | TBD | — |
| PCP-D08 | Open | PCP-16 | TBD | Depends on PCP-D04 |
| PCP-D09 | Open | PCP-01 | TBD | — |
| PCP-D10 | Open | PCP-04 | TBD | — |
| PCP-D11 | Open | PCP-03 | TBD | — |

## 18. Definition of Done

### 18.1 Foundation-only Approval gate — no circular dependency

This document may become **Approved** only after `PCP-D01, PCP-D03, PCP-D05,
PCP-D06, PCP-D07, PCP-D09, PCP-D10, PCP-D11` are either accepted or
explicitly deferred with owners and gates (§17.1).

`PCP-D02` (Follow) is explicitly **not** required for this document's
foundation Approval — it is blocked on a joint decision this document
cannot make alone (§7.1, §0.1), and this document's foundation scope
functions correctly with the Follow CTA simply absent until that joint
decision resolves. `PCP-D04` and `PCP-D08` (content-review display, Creator
level) are likewise not required — they gate only their own Mature/Gated-
expansion features. `VP-D08` (person-level reviews) and `CP-D14` (minors as
Creator) are not required either — §6 and §9 already specify the
fail-closed foundation behavior that holds regardless of when, or whether,
those sibling decisions resolve.

The Public Creator Profile is production Done only when:

1. the four-axis model and its resolver (§3.6) are authoritative and fail
   closed;
2. the Created-content list is attribution-correct (§4.1) with test
   evidence;
3. `AccountStatus`-driven not-found responses are anti-enumeration-safe
   across every observable signal, and `private` visibility is confirmed
   distinct from them (not producing the same response);
4. `PublicCreatorProfileConfig` (§4.2) is the sole implemented owner of its
   fields;
5. the selected release modules meet their own acceptance criteria (§15);
6. public/privacy/legal/security requirements are accepted;
7. analyzer, tests, boundary and diff gates are green;
8. `LAUNCH_STATUS.md` records the exact evidence;
9. no local/mock fixture or UI preview is represented as production
   authority.

## 19. Relationship to the sibling documents

This document reuses, rather than restates independently, every invariant
that does not depend on the public/private distinction: `PublisherRef`
resolution, the fail-closed mutation principle and the state-family
separation are the same contract across all sibling documents.

Explicit non-overlap, restated from the owning side:

- `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` owns the `AccountStatus` axis (§3.3
  here only reacts to it, using its exact camelCase values), the baseline
  Public User Projection this document extends (unaffected by this
  document's `visibility` setting, §3.1), the base Follow relationship
  (§7.1 here only proposes a display-side position for the joint decision),
  Block/Mute mechanics (§7.2 here only references them), reviews-about-a-
  person (`VP-D08`, §6 here only defers to it), and minors' baseline-
  projection policy (`VP-D10`, §9).
- `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` owns the verification axis (§3.2
  here only reacts to it), verification/publisher mechanics, Created-
  content management, handle rename mechanics (§10 here only defers to
  it), and minors-as-Creator policy (`CP-D14`, §9).
- `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` owns the `ManagedPage` public
  projection this document links to but never duplicates (§5), and
  proposes the joint Follow foundation (`PP-D44`) this document's `PCP-D02`
  is one party to, not the decider of.

Any future edit to a shared invariant in one document SHOULD check whether
the sibling documents need the same edit, and SHOULD record the check even
when no change was needed.
