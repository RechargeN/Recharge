# RECHARGE — Public Viewer Profile Functional Specification

Status: **Draft for product and architecture review**

Version: **1.0**

Date: **2026-08-16**

Scope: **the public-facing identity projection of any Viewer, as seen by
other accounts through a legitimate trigger surface — never a standalone
searchable profile page; documentation only**

## 0. Document authority and purpose

This document defines what any other account sees of a Viewer's identity —
the minimal safe snapshot attached to a Review, a Find People response, an
invited Scenario, a shared plan, or a Follow relationship. It is a
**presentation split-out, not a competing model**: `UserProfile`,
`FollowRef`, `AccountStatus` and every decision governing them remain owned
entirely by `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`. This document introduces
no new `VP-D`/`VP-AC` numbering of its own — every rule here traces back to
a specific section, invariant or decision in that document, cited by
number, never restated as if independently decided.

This document is not an Accepted ADR and does not authorize runtime,
backend, Firebase or production work. Before implementation, each delivery
slice still requires an Approved bounded slice specification, exactly as
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §0 already states.

When sources conflict, the same six-tier order `VIEWER_PROFILE_FUNCTIONAL_
SPEC.md` §0 defines applies here too — this document sits in that order's
Draft profile-surface tier, on equal footing with
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`, `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`,
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`,
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` and
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`. Where this document and
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` appear to disagree, the latter wins
outright — it owns the aggregate; this document owns only the public
presentation layer over it, and must be corrected to match, not the
reverse.

Canonical supporting source:

- `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` — owns `UserProfile`, `FollowRef`,
  `AccountStatus`, every `VP-D` decision cited below, and every invariant
  this document's rules derive from.

### 0.1 Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` and their Russian equivalents are
normative. `Target` describes intended full-release behavior. `Current` is
only a status snapshot and must be verified in `LAUNCH_STATUS.md` before
work.

## 1. Product definition

This document is **not** a standalone public profile page — unlike
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` or
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`, there is nowhere a Viewer
navigates to see this projection as a destination. A Viewer who never
verifies as Creator has **zero** standalone-searchable presence (§4); the
content this document describes is a minimal identity snippet — at most
display name, avatar, optional city — attached inline to one of a small,
named set of legitimate contexts. This document exists as a separate file
only because those rules had grown detailed enough to warrant independent,
faster-editable ownership, mirroring the existing
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` / `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_
SPEC.md` and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` /
`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` splits — not a claim that a
public Viewer "page" now exists.

### 1.1 Relationship to sibling documents

| Private/management view | Public view (this pattern) |
|---|---|
| `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` |
| `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` | `PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` |
| `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` | `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` (this document) |

Unlike the other two rows, this split is presentation-only in a stricter
sense: `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.2 already defined "Public
User Projection" as a baseline every account has, verified Creator or not
— this document does not add a new audience tier, it only relocates that
existing baseline's own description out of the private-operations document
so it can be edited without touching Scenario/Quick Plan/Favorites/Photos
content in the same diff.

**Verified-against snapshot.** Every citation below of
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` was checked directly against its v1.17
text as of 2026-08-16 (the version immediately after this split). A later
version of that document moving past this pin does not retroactively make
this document wrong, but does mean its citations are unconfirmed against
the newer text until the next verification pass.

## 2. Visibility defaults

Per-library default, all owner-overridable only where the underlying
aggregate contract allows it. `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` is the
sole authority for every row below — `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_
SPEC.md` §4 explicitly cites the `About` default here rather than
redefining it:

| Library | Default visibility | Public exposure |
|---|---|---|
| `displayName`, avatar, city | Owner-controlled | Part of Public User Projection when shown next to authored content |
| About | Private, owner may opt public | Shown on a Public Creator Profile only if the owner opts it public |
| Favorites, Saved Searches, Smart Search history | Private | Never public |
| Personal Scenario | Private unless the owner sets `unlisted` (any Viewer, own capability) or `public` (Creator-only Create Hub publish — `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §5.2's asymmetry) | Per Scenario's own `visibility` field |
| Quick Plan | Private to owner + explicit participants | Never public |
| Visit History | Private | Never public |
| My participation | Private | Never public |
| Notifications | Private | Never public |
| Photos | Private (`public` reserved, not settable — `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2, §10) | No public surface exists yet |
| Reviews authored | Owner-controlled per Review contract | May be public if the Review contract makes authored reviews public |
| Reviews received | Attached to the reviewed content's own visibility | Never exposes the reviewing author's private data beyond their own Public User Projection |

## 3. Public User Projection

The minimal safe identity snapshot shown next to a Review, a Find People
response, an invited Scenario or a shared plan — for **every** Viewer, not
only a verified Creator. It contains at most: display name, avatar,
optional city. It MUST NOT expose email, phone, Favorites, Visit History,
Quick Plans, private Scenario, Notifications or any other library
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §5–§10 owns.

These four trigger surfaces (Review, Find People, invited Scenario, shared
plan) are the accepted initial list — not exhaustive by construction, but
not fully open either; `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s `VP-D07` (§22
there) tracks only whether additional surfaces should be added, not
whether these four are legitimate. A Find People response showing a Public
User Projection is a targeted, consent-scoped disclosure to the searching
account, not general discoverability — it does not contradict §4's
standalone-discoverability rule, because the projection is only ever shown
as part of a specific, consented interaction, never surfaced by an open
search over all Viewers. Once an account is Followed (§5), the Follow
relationship itself becomes a fifth legitimate context in which the
followed account's Public User Projection is shown to the follower —
Follow does not add a *field* to the projection, only another place it may
legitimately appear.

The strict field set above (display name, avatar, optional city) never
grows just because Follow exists — a Follow action and a follower/following
count are §5's own adjacent feature, not part of this baseline projection.

**Identity-field source for a `VerifiedCreatorIdentity` account —
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` adopts `CREATOR_PROFILE_FUNCTIONAL_
SPEC.md` `CP-D20`.** `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §16.1 defines
`IdentityFieldModerationOverlay`, a separate record that becomes
authoritative for `displayName`/`avatar` once a row exists for an account
— which happens only once that account has been `VerifiedCreatorIdentity`
at least once (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §3.1); a plain Viewer
who never verifies has no overlay row, ever. **Whenever an
`IdentityFieldModerationOverlay` row exists for the shown account, this
projection MUST read `displayName`/`avatar` from that overlay's
`lastApprovedPublicValue` (absent, not blank, if no approved value exists
yet) — never directly from `UserProfile` — on every one of this section's
trigger surfaces (Review, Find People response, invited Scenario, shared
plan, Follow).** Without this, a Creator's pending or rejected
identity-affecting edit could legitimately show the new value on this
projection while `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s extended
card still showed the last approved one, or vice versa — the exact
inconsistency `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §16.1 warns against. For
an account with no overlay row (never `VerifiedCreatorIdentity`), this rule
is a no-op — `UserProfile` remains the direct, immediate source, exactly as
before. `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` does not adopt the overlay's
still-open lifecycle mechanics (seeding, migration, atomicity,
identity-affecting-change detection — `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
`CP-D18`/`CP-D19`); only the read-source rule above, which holds regardless
of how those separate questions resolve.

## 4. Discoverability, blocking, deleted accounts

- A Viewer who never verifies as Creator MUST NOT appear in Search/Discover
  as a public profile result — only the Public User Projection (§3)
  surfaces incidentally, attached to specific content, never as a
  standalone searchable identity. The proposed Follow model (§5) does not
  change this: an account would be reachable to follow only through an
  existing legitimate trigger surface or a revocable link, never through
  open search;
- **Block and Mute are different relationships, not two names for one
  thing.** `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` is the sole owner of
  Block/Mute mechanics for a Viewer — `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_
  SPEC.md` §7.2 explicitly disclaims establishing this split itself and
  cedes full ownership there; that document only consumes it for how a
  blocked/muted account's *card* renders. **Block is bidirectional by
  default** — it removes *both* accounts' ability to view each other's
  card/projection, follow each other, or initiate new contact, not only
  what the blocking account sees (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
  `PP-AC-66`'s principle, applied to a Viewer rather than a page). It never
  unpublishes content. **Mute is one-directional** — content stays visible
  but is deprioritized for the muting account only, and the muted account
  is never notified of either action. Block MUST remain enforceable even
  against content the blocked account already interacted with jointly
  (e.g. a shared Scenario or an invited Quick Plan) —
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §5.1 owns whether the *Scenario/Quick
  Plan itself* still shows that account's contribution, while
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §7 owns only whether the
  blocked account's *card* is shown, and whether existing shared state is
  retroactively hidden versus only blocking new joint interaction is that
  document's own `PCP-D06`. A Block removes any existing proposed
  `FollowRef` in both directions immediately (§5) and prevents a new one
  from either side while the Block stands; a Mute never affects Follow
  state at all;
- report is a separate moderation submission with its own audit/appeal
  contract; it is not a block state and does not itself change what every
  other Viewer sees;
- a direct link to a tombstoned/deleted account's Public User Projection
  returns the same safe not-found response a genuinely nonexistent account
  would (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1's anti-enumeration rule
  — `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3.3/§10 restates this
  because honoring it is that document's own rendering responsibility, but
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` remains the owner of the underlying
  `AccountStatus` fact);
- a suspended or security-locked account's Public User Projection is
  withdrawn entirely, not merely degraded — resolved by
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1's `AccountStatus` contract;
- a minor's baseline Public User Projection follows `VP-D10`
  (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §22) — a decision that document owns
  and that is distinct from `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-D14`
  (whether a minor may become a verified Creator at all): even an account
  that will never seek Creator verification still has some baseline
  projection, and that baseline's minor-specific policy is
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s own open decision, not inherited
  from `CP-D14`.

## 5. Follow (proposed direction only — joint decision pending, `PP-D44`/`PCP-D02`)

**Follow is not yet an accepted contract anywhere in the sibling
documents, and this section MUST NOT be read as one.**
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §7 is explicitly titled
"illustrative direction only" and models Follow as gated on a `verified`
Creator's card visibility; `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D44`
separately asks whether following a page and following a person share one
relationship/consent/retention contract, and proposes a neutral
`FollowRelation{followerUserId, target:{type:user|page,id}, status, ...}`
shape "as a starting point... it does not unilaterally adopt it."
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §0's own conflict rule governs here:
"if two sibling profile documents disagree below tier 5 and no higher tier
resolves it, implementation is blocked on that specific invariant until a
joint decision is made — neither document's wording wins by default."

**`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s own proposed position**, for input
into that joint decision, is stated below — recording actual product
direction from a 2026-08-12 review, not this document's unilateral ruling:

- every account should be able to follow, and be followed by, any other
  non-blocking account, with no Creator-verification gate — extending
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §3.1's "requires only Viewer"
  principle to Follow;
- the base relationship (`FollowRef`, `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`
  §4.2) would be owned by that document regardless of either party's
  Creator/Page status, with `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s
  and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`'s own Follow surfaces
  consuming it (follower count, Follow action on their respective cards)
  rather than redefining who may be followed;
- open by default — no approval required from the followed account in the
  baseline proposal;
- a Block (§4, bidirectional) removes any existing `FollowRef` in both
  directions immediately and prevents a new one while it stands; a Mute
  never affects Follow state;
- reachable only where a Public User Projection is already legitimately
  shown (§3's trigger surfaces) or via a link — and that link MUST use the
  same opaque, revocable token `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
  `PCP-D10` already requires for `unlisted` card resolution, never a raw
  `userId` or predictable handle, or Follow becomes an enumeration/privacy
  surface rather than a safe discoverability boundary —
  `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` does not yet define that token
  mechanism itself (`VP-D07`);
- follower/following counts visible per the owner's own preference,
  defaulting to visible;
- unfollow and follower-removal available to the owner at any time,
  distinct from Block;
- a `tombstoned` account (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1) would
  lose all `FollowRef` relationships at the point of tombstoning; restore
  within the retention window would not silently restore them;
- a new-follower event would be a notification category
  (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §16), subject to the same
  cross-document dedup discipline as every other category (`VP-D11`).

**Known, unresolved shape mismatch with the sibling proposal.**
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-D44` proposes a discriminated
`FollowRelation{followerUserId, target: {type: user | page, id}, status,
...}` covering both a person-follow and a page-follow in one shape.
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s `FollowRef` (§4.2 there) has no
`target` field at all — `{followId, followerUserId, followedUserId,
createdAtUtc}` — and is structurally unable to represent following a page.
This is not a wording difference to reconcile by picking better prose; the
two shapes cannot both be correct as written, and
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` tracks the reconciliation itself as
a **neutral, third-party slice** — `FOL-01`, "not PP-owned" — precisely so
the fix isn't presented as either sibling unilaterally winning. Neither
this document nor `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` resolves the mismatch
by silently adopting the discriminated shape or by insisting on the
narrower one; both remain candidate shapes for `VP-D12`/`PP-D44`/`PCP-D02`
to choose between, with `FOL-01` as the roadmap home for whichever one
wins.

**Not yet addressed even within this proposal** — self-follow prohibition
and one-active-relationship-per-pair uniqueness; idempotency and
`revision`/`schemaVersion` on `FollowRef`; race handling between Follow,
Block and account deletion arriving out of order; rate limiting and spam
protection; re-follow cooldown; retention/audit of the relationship record
after unfollow or Block; follower/following counter consistency under
concurrent writes; pagination of follower/following lists; and how Follow
is meant to affect anything else in the product (it currently gates no
feed, ranking or publish-notification) — `PP-D44` already tracks most of
these as required inputs to the joint decision; this document does not
duplicate that list, only confirms it applies here too.

**Tracked as `VP-D12`** (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §22) — that
document's half of the joint `PP-D44`/`PCP-D02` decision: whether the
proposal above is adopted as-is, modified, or rejected in favor of separate
person/page models; an approval-gated ("private account") variant on top
of it; follower/following list visibility to other accounts; the
opaque-link mechanism `VP-D07` also depends on; and whether a minor
account's baseline (`VP-D10`) further restricts who may follow them or be
followed by them. Follow does not ship in any form until this joint
decision resolves — that gate itself is not open for negotiation within
`VP-D12`.

## 6. What this projection never exposes

`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.2/§4.3(16) is the normative source;
consolidated here for a quick reference. This projection MUST NOT expose:

- email, phone, or any contact channel;
- Favorites, Saved Searches, Smart Search history;
- Visit History, My participation, Notifications;
- private Scenario or Quick Plan content (only an *invited* Scenario/plan's
  existence triggers this projection at all — never its content);
- Photos beyond what the owner has explicitly made part of the projection
  (currently none — Photos visibility is `private`, `public` reserved and
  not settable, §2 above);
- a live `UserProfile` `displayName`/`avatar` value when an
  `IdentityFieldModerationOverlay` row exists and holds a different
  `lastApprovedPublicValue` (§3);
- itself, entirely, once the account is `securityLocked`, `suspended`, or
  the requester and the shown account are in a Block relationship in
  either direction (§4);
- itself, at all, as a standalone searchable result for an account that
  has never verified as Creator (§4).

## Revision History

| Version | Summary |
|---|---|
| 1.0 | Initial split-out from `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12 (v1.16), at the user's direct request, to keep the public-facing identity projection separately editable from the full private personal-operational-center model — mirroring the existing `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`/`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`/`PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` splits. No decision, invariant or `VP-D`/`VP-AC` content changed in the move; every rule here still traces to its source section/decision in the parent document, cited by number. Bare `§N` cross-references from the original §12.1–12.4 text were re-anchored: references to content that moved here became this document's own internal section numbers (§2–§6); references to content that stayed in the parent were qualified with `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` so they remain unambiguous outside that document. |
