# Professional Page Functional Spec — Correction History

This file holds the detailed, dated correction log for
`docs/product/PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`. It exists so the main
spec can stay short and unambiguous — every entry below describes what was
true to fix *at that point in the document's history*; it is not a live
statement of the document's current state. If something here appears to
contradict the current main spec, the main spec wins (see its own §0
priority order); this file is history, not a second normative source.

Entries are in chronological order, oldest first.

---

## Corrections from draft 2.0

This revision preserves the ambitious full-release direction while correcting
the following structural problems:

- modules and security capabilities are no longer interchangeable;
- Category System reuse is an explicit open adapter decision, not an assumed
  new `page` content type;
- fixed `ManagedPage.kind` and open public activity classification are
  reconciled instead of contradicting each other;
- Owner/Manager/Editor are relationship labels plus grants, not role-only
  authority; co-owner/transfer behavior is no longer invented;
- content lifecycle and visibility remain aggregate-specific;
- invitation, application, Booking, hold, attendance and analytics states are
  separated;
- ADR 0019 holds are described as expiring free inventory allocations, not a
  generic waitlist/payment mechanism;
- `Advanced / Pro` is removed as an identity concept;
- the oversized “MVP” list is replaced by full-release delivery classes and
  independently approvable slices;
- current local/mock status is separated from target behavior;
- security, privacy, offline, idempotency, revocation, migration, rollback,
  accessibility, acceptance criteria and open decisions are explicit.


## Corrections from drafts 2.1–2.2

Version 2.3 keeps the full-release direction and closes the following review
gaps:

- international metadata is explicit, but cannot grant authority or weaken
  server-owned market/legal policy;
- exact production field registries/wire names remain versioned by an Approved
  implementation slice rather than being inferred solely from local/mock code;
- international metadata has dedicated acceptance criteria and test coverage;
- `manage_bookings` is treated as the current semantic capability name, not a
  forever-hardcoded wire code;
- the UI appendix is explicitly a non-normative inventory and introduces no
  normative requirements of its own;
- public Scenario uses `Open / Save a copy`; `Start` belongs to a ready personal
  copy;
- Rental does not inherit Event Booking authority and requires its own
  inventory/reservation contract before `Reserve` can be authoritative;
- Follow/Contact/Share and other illustrative blocks are conditional on their
  approved contracts and policies.


## Corrections from draft 2.3

Version 2.4 keeps every normative decision from 2.3 and closes a self-consistency
gap: the international-metadata rules added in 2.3 (§4.1) were not fully mirrored
in the sections whose own conventions require it.

- §20 gains `PP-D13`, naming the international metadata registries/wire-name
  decision that §4.1 already defers to an Approved slice but had not listed
  alongside the document's other twelve open decisions.
- §18 gains `PP-AC-51`: the §4.1 "unknown/unsupported market metadata fails
  closed for policy-sensitive work" rule previously had no corresponding
  acceptance criterion, unlike every other rule in that paragraph.
- `PP-AC-50` now states explicitly that it covers the same round-trip
  principle as `PP-AC-17`, scoped to core `ManagedPage` fields instead of
  `ManagedPageProfileExtension`, so the two are not mistaken for a duplicate.


## Corrections from draft 2.4

Version 2.5 fixes one blocking defect and three lower-severity gaps found by
review of 2.4:

- **Blocking:** §21 Definition of Done still gated Approval on `PP-D01–D12`
  after `PP-D13` was introduced in 2.4, which would have let the document
  become Approved with an open international-metadata decision still
  unresolved. Fixed to `PP-D01–D13`.
- `PP-AC-51` and the §4.1 fail-closed rule it tests were global
  ("policy-sensitive work"), which could be read as one unknown field (e.g.
  currency) blocking unrelated operations (e.g. scheduling). Both are now
  operation-scoped: `timezone` → scheduling, `defaultCurrency` →
  price/payment display, `countryCode`/`marketId` → legal/age/verification
  policy, locale values → localized publication/readiness. §19 gained a test
  bullet confirming isolation between fields.
- `PP-D13` collapsed five independent code sources into one generic
  "registry." It now itemizes each: `marketId` (versioned Recharge-owned
  registry), `countryCode` (ISO 3166-1 alpha-2), `defaultCurrency`
  (ISO 4217), `timezone` (IANA TZDB) and locale values (BCP 47), so an
  implementation slice cannot substitute an incompatible format for any one
  of them.
- §4.1 named exact field values while PP-D13 called their wire contract
  undecided. §4.1 now states explicitly that it accepts the **semantic
  model** (field existence, meaning, source-of-truth registry per field);
  exact wire names, storage layout and `schemaVersion` remain PP-D13's scope.
- The file previously had no trailing newline at EOF; it now ends cleanly
  (resolved incidentally by this appendix's own addition).


## Corrections from draft 2.5

Version 2.6 does not change any 2.5 decision; it closes the largest remaining
gap identified by review: the document specified page **content and access**
well but was silent on the page's own **lifecycle as an organizational
object** — team turnover, ownership change, duplicate/claim/merge, renaming,
concurrent editing, deletion, notification routing and integration security.

- §20 gains `PP-D14`–`PP-D22`, covering: team invitation/offboarding
  lifecycle, page-lifecycle cascade over content/Booking/exposure, explicit
  content transfer and co-host model, slug/rename/deep links, concurrent
  editing and revisions, deletion/archive/retention, notification recipients
  and read state, integration credential isolation, and branch/brand
  hierarchy scope.
- Existing `PP-D03` (ownership) and `PP-D10` (claim/merge), previously
  one-line problem statements with no functional flow, are expanded with the
  concrete flow steps each decision must resolve.
- §21 Definition of Done is updated from `PP-D01–D13` to `PP-D01–D22`.
- §18 gains `PP-AC-52`–`PP-AC-61`, one per new/expanded decision area,
  including a spec-level gap closed directly rather than deferred: §3.2 now
  states explicitly that active membership with an empty capability set opens
  a restricted workspace shell without granting any capability, resolving an
  ambiguity between "membership is active" and "capability is present" that
  the document's own mutation-decision chain (§3.4) never made explicit for
  the read-only case of simply opening the workspace.
- Appendix F adds a non-normative, cross-referenced index of architectural
  prohibitions ("what Professional Page cannot do") so it is checkable in one
  place instead of twenty scattered clauses; every row was verified against
  its cited section rather than restated from memory.


## Corrections from draft 2.6

Version 2.7 does not weaken any 2.6 decision. It fixes one real contradiction
introduced by 2.6, resolves the mechanism behind PP-D14–PP-D21 instead of
only cataloging them, and adds the traceability DoD already required but did
not yet have.

- §3.1 vs §3.2 contradiction: §3.1's single "Professional Page access"
  implied a capability was required to open the workspace; §3.2 (added in
  2.6) said active membership alone was enough. Both are now precise,
  separate terms — `canOpenPageWorkspace` (membership + lifecycle, no
  capability) and `canPerformPageAction` (adds capability, revision, policy,
  Creator verification where relevant) — and §3.4's mutation chain now names
  `canPerformPageAction` explicitly.
- `ManagedPageMembership.status=invited` (an accepted field) and PP-D14's
  proposed `TeamInvitation` looked like two competing models of the same
  state. §22.1 reconciles them: `TeamInvitation` is the delivery record;
  accepting it transitions the pre-existing `invited` membership to `active`
  rather than creating a new one, and revocation semantics are now
  revision-based rather than the earlier broad "invalidate sessions" claim
  (`PP-AC-53`).
- `PP-AC-54` named `verification revoked` as a `lifecycle` state and implied
  a `deleted` lifecycle value that is not in the accepted
  `ManagedPage.lifecycle` enum. §22.2 separates verification, lifecycle and
  deletion into three axes with a first-draft cascade matrix, and
  `PP-AC-54` now tests the axes instead of one collapsed list.
- `PP-AC-59` ("no further notification of any kind") would have blocked the
  offboarding notice itself and legally required messages. It is now scoped
  to operational/promotional notification after one terminal notice.
- §19 gains explicit test coverage for lifecycle cascade, transfer/co-host,
  slug/redirect, concurrent editing, deletion-with-obligations, notification
  offboarding, credential isolation, no-implicit-hierarchy, and
  transfer/merge rollback — previously PP-D14–PP-D22 had decisions and ACs
  but almost no named tests.
- §20.1 adds a decision-tracking table (status, target slice, owner, gate)
  so DoD's "accepted or explicitly deferred with owners and gates" is
  actually checkable; `Owner` is honestly `TBD` rather than invented.
- New §22 resolves the mechanism for PP-D14–PP-D21 (team
  invitation/offboarding, lifecycle cascade, transfer/co-host, slug/rename,
  concurrent editing, deletion/retention, notifications, integration
  isolation) instead of leaving them as open problem statements; each
  subsection still names its narrower remaining open question. PP-D22
  (branch/brand hierarchy) is confirmed explicitly deferred, not resolved.
- PP-D23–PP-D26 add the four missing areas raised in review: localized page
  content, media rights/lifecycle, public-page report/block/support flow,
  and entitlement downgrade — each with its own AC (`PP-AC-64`–`PP-AC-67`).
- `PP-D03` and `PP-D10` were expanded in 2.6 but, contrary to Appendix G's
  claim at the time, received no dedicated acceptance criteria. `PP-AC-62`
  and `PP-AC-63` close that gap now; Appendix G's own text is left as the
  historical record it is, not retroactively edited.
- Every bold `**PP-AC-NN**`/`**PP-DNN**` mention inside the appendices (as
  opposed to their canonical definitions in §18/§20) is now code-formatted
  instead, so a naive counter matching on bold-plus-ID no longer
  double-counts definitions that only ever existed once.
- DoD's range is updated from `PP-D01–D22` to `PP-D01–D26`.


## Corrections from draft 2.7

Version 2.8 fixes four modeling defects left in 2.7, plus the significant
inaccuracies and traceability gaps from that review. Status stays `Draft`.

- **Aggregate lifecycle boundary:** §22.2's cascade matrix dictated the fate
  of published content across all ten Create types and Booking, directly
  contradicting §9's own "MUST NOT introduce one universal content
  lifecycle" rule. The matrix now governs only publisher validity, new
  page-scoped operations and page exposure; each aggregate's own contract
  independently interprets the publisher-validity signal. `PP-AC-54` and the
  §19 test bullet are updated to match.
- **Invitation before membership:** §22.1 assumed a `userId` existed at
  invite time, which cannot invite someone without a Recharge account yet.
  `TeamInvitation` now exists independently, supports an email/phone target,
  and `ManagedPageMembership` is created only at acceptance — invitation
  acceptance and membership creation are the same event, not two.
- **Co-host principals:** §22.3 listed a hosting `Place` as a co-host grant
  recipient. `Place` is a physical/reference aggregate, not an actor; only
  `User` or `ManagedPage` can hold a co-host grant, and `Place` is
  represented only as a venue reference by ID.
- **Read vs acknowledged:** §22.7 allowed one member to mark another
  member's notification read. `read` is now strictly personal per member; a
  separate, audited `acknowledged`/`resolved` team fact exists for shared
  operational items and does not imply anyone else has read the item.

Significant inaccuracies fixed:

- "Access revision" is now explicitly `ManagedPageMembership.revision` — no
  separate field is invented — and `canOpenPageWorkspace` now checks it, so
  a stale membership snapshot cannot open a workspace after revocation.
- §22.5's reference to a nonexistent §16.3 is corrected to §5.2.
- Slug/deep-link redirects (§22.4, `PP-AC-56`) no longer reveal the
  existence of a suspended, private, deleted or moderation-blocked page;
  they return the same not-found/gone response a nonexistent slug would.
- `PP-AC-63`/`PP-D10` no longer imply capability grants carry over
  automatically on merge — `relationship` carries over, `capabilities`
  require re-confirmation or a fail-closed reset.
- §22.6/`PP-AC-58` separate account deactivation/deletion from retention of
  minimally necessary pseudonymized legal/financial records.
- `PP-AC-64` picks one outcome — publish with a partial-translation label,
  never a silent block-or-allow ambiguity — and `PP-D23` is narrowed to
  match.
- `PP-AC-65` now tests loss of edit/manage rights on contributor
  offboarding, not loss of the asset's public availability.
- `PP-AC-66`/`PP-AC-67` gained actual report/block/support and downgrade
  behavior, not only architectural-safety framing.

Traceability:

- §20.1's `Status` column now distinguishes `Open` from `Proposed resolution
  / open parameters` so it no longer contradicts §22's own "resolved"
  framing for PP-D14–PP-D21.
- §17 gains three new roadmap slices — **PP-12 Page governance & lifecycle**,
  **PP-13 Media safety & rights**, **PP-14 Public support & moderation** —
  so PP-D03, PP-D10, PP-D15, PP-D17, PP-D19, PP-D24 and PP-D25 no longer
  point at "Not yet in roadmap."
- `Gate` is filled in wherever a real dependency is derivable (an Approved
  Review slice, legal/privacy sign-off, security review) instead of left
  blank everywhere.
- PP-D22's `Owner` is `TBD — architecture review (confirms deferral)`, not
  `n/a`: DoD requires an owner even for an explicitly deferred decision.

This document remains `Draft for product and architecture review`, not
`Approved` — PP-D01–D26 are still open or explicitly deferred, consistent
with §21's own gate.


## Corrections from draft 2.8

Version 2.9 resolves one live code-versus-spec contradiction, hardens one
merge-safety gap left in 2.8, and catalogs seventeen operational-model areas
raised by review as PP-D27–PP-D43 with a matching AC each. Status stays
`Draft`.

- **Non-Creator staff access:** the local/mock `canActivatePage()` requires
  `isVerifiedCreator` to open the page workspace at all, contradicting
  §3.1's own `canOpenPageWorkspace` (which never required it). §3.1 now
  states this explicitly and names the required code migration; `PP-D27`
  narrows the remaining scope (exact operation list, Create Hub partial
  view) and `PP-AC-52`/`PP-AC-68` test it.
- **Merge no longer carries over active membership:** even a
  relationship-only, zero-capability membership satisfies
  `canOpenPageWorkspace` (§3.1) and would expose the surviving page's shell
  to an unvetted member. `PP-AC-63` and `PP-D10` now require a
  reconfirmation `TeamInvitation` instead of any membership carry-over.
- `PP-D27`–`PP-D43` catalog: non-Creator staff scope, `TeamInvitation`
  security hardening, emergency ownership recovery, step-up authentication,
  a delegability matrix, obligation-serving operations under a restricted
  lifecycle, the co-host execution model, bulk/scheduled operations,
  multi-device concurrency, locale-completeness enforcement, trust-and-safety
  and moderation, operational quotas, integration source-of-truth/recovery,
  notification delivery states, analytics data quality, entitlement/billing
  completeness, and a meta-decision (`PP-D43`) sequencing all of them into
  roadmap slices.
- §17 gains **PP-15 Security & access governance** for step-up
  authentication and the delegability matrix, which had no natural home in
  the existing fourteen slices.
- §18 gains `PP-AC-68`–`PP-AC-84`, one per new decision, plus §19 gains
  targeted tests for the highest safety-priority items (non-Creator staff,
  merge carry-over, step-up auth, delegability, quota data-loss) — not all
  seventeen areas got full test coverage in this pass; `PP-D43` explicitly
  tracks that remaining work rather than letting it go unowned.
- §20.1 is extended with all seventeen new rows; DoD's range moves from
  `PP-D01–D26` to `PP-D01–D43`.

This document remains `Draft for product and architecture review`. The
seventeen new areas are explicitly *not* claimed as resolved — most are
genuine open product/security/legal questions, unlike PP-D14–D21 in §22,
which this pass did not attempt to force into the same "resolved mechanism"
treatment.

## Corrections from draft 2.9

Version 2.10 resolves three internal contradictions introduced across the
2.9 pass, fixes a counting/traceability error in `PP-D43`, tightens four
inaccurate acceptance criteria, and completes roadmap/test traceability for
the sixteen `PP-D27`–`PP-D42` operational areas. No new PP-D items were
added this round — this pass fixes, it does not expand.

Blocking contradictions fixed:

- **Locale requirement conflict:** `PP-AC-64` allowed publishing with an
  incomplete `defaultLocale` (labeled); `PP-AC-77` blocked it. `PP-AC-64` is
  now scoped to secondary locales only; a required `defaultLocale` field is
  governed exclusively by `PP-AC-77`, which blocks. `PP-D23` is updated to
  match; `PP-D36` already had this right and needed no change.
- **Report visibility vs. interim restriction:** `PP-AC-66` claimed a
  reported page "stays visible until a moderation decision," which didn't
  leave room for `PP-AC-78`'s interim restriction. `PP-AC-66` now states
  that reporting alone never changes visibility — only a separate,
  policy-driven interim restriction (`PP-AC-78`) can, through a trusted
  moderation process with its own reason and duration.
- **Lifecycle table vs. PP-AC-73 exceptions:** §22.2's cascade said
  `Blocked`/`Read-only` with no room for `PP-AC-73`'s named exception class
  (appeal, restore, transfer, export, cancellation/refund, legal hold). The
  table now has a dedicated "obligation-serving / recovery-appeal-legal
  ops" column, with an explicit note that being in that column does not
  itself grant the right to act — capability, policy and owning-aggregate
  support are still required per §3.4.
- **`invited` vs. `TeamInvitation`:** the accepted `ManagedPageMembership`
  contract still lists `status=invited`, which §22.1 (2.9) said should never
  exist for a new invitation. §4.1 now states explicitly that `invited` is
  legacy read-compatibility only, new writes MUST use `TeamInvitation`
  instead, and removing the enum value itself is a separate, later
  contract/ADR-gated decision — not something this document changes
  unilaterally.

Inaccurate acceptance criteria tightened:

- `PP-AC-74` (co-host) no longer names one fixed acting user; a co-host
  grant targets the collaborator's `PublisherRef`, and multiple of its
  members may act, with exactly one `actingUserId` resolved per command.
- `PP-AC-75` (bulk operations) now requires a declared `atomic` or
  `per-item` commit mode instead of assuming partial-commit for everything.
- `PP-AC-82` (analytics) now requires canonical metrics to *exclude*
  bot/fraud activity, with a separate optional filtered-count display,
  rather than allowing "exclude or flag" as if those were equivalent.
- `PP-AC-67`/`PP-AC-83` (entitlement downgrade, billing) now share one
  named concept — obligation-continuity, defined once via §22.2's
  obligation-serving exception — instead of two separately worded rules
  that were easy to read as conflicting.

Traceability fixed:

- `PP-D43` miscounted its own scope as "seventeen areas... PP-D27–PP-D42"
  (that range is sixteen items; `PP-D43` itself is the seventeenth, a
  meta-decision, not an operational area) and understated the target-slice
  range as only `PP-12`–`PP-14`. Both are corrected.
- §17 gains **PP-16 Operational limits**, closing the one remaining
  `PP-D38` "Not yet in roadmap" row in §20.1.
- §19 gains explicit tests for every item on the review's test-gap list:
  invitation replay/enumeration/accept-revoke race, legacy `invited`
  migration, disputed emergency recovery, `PP-AC-73` exception still
  requiring capability, co-host actor resolution and single-co-host
  suspension, atomic vs. per-item bulk failure, offline autosave vs. remote
  revision, required-default vs. secondary locale, report-without-auto-hide
  vs. emergency interim restriction, quota isolation, integration
  backfill/replay/reconciliation, notification bounce/dead-letter, analytics
  correction/fraud-filtering, and downgrade obligation-continuity.

Editorial: this correction-history file itself is new in 2.10. Detailed
correction logs (previously Appendices A, C, D, E, G, H and I in the main
spec, covering 2.0 through 2.8) moved here unedited, so a stale historical
claim — like this file's own "Corrections from draft 2.7" entry still
saying the range was `PP-D01–D26` — cannot be mistaken for the main spec's
current state. The main spec now keeps only its two living reference
appendices (UI inventory, non-negotiable exclusions index) and a short
Revision History table pointing here for detail.

## Corrections from draft 2.10

Version 2.11 does not fix a defect — it formally connects this document to
a wider four-document architecture briefing covering `VIEWER_PROFILE`,
`CREATOR_PROFILE`, `PUBLIC_CREATOR_PROFILE` and this Professional Page
document, all as audience-scoped presentation surfaces over the same
canonical aggregates rather than four competing models.

- New §1.1 **Relationship to sibling documents** states which of the four
  documents owns which concern, and the rule that a surface owned by one is
  referenced, never redefined, by another.
- Two cross-document terminology collisions are named explicitly instead of
  staying implicit: `owner` means a page-team role here
  (`ManagedPageMembership.relationship`) but a personal content item's own
  `owned` relationship in `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2 — neither
  implies the other, and that sibling document's `relationship` is
  confirmed as `owned | invited` only, deliberately without an `editor`
  tier pending its own `VP-D02`. Earlier informal discussion of this
  document's ecosystem had stated an `owner/editor/invited` enum for
  Scenario; that was inaccurate and is not carried into this document.
- **`PP-D44`** is added: whether following this page (§12.2, `PP-D06`) and
  following a verified Creator elsewhere share one relationship/consent
  model or are deliberately separate — a joint decision with
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`, not something either
  document may resolve alone. DoD's range moves from `PP-D01–D43` to
  `PP-D01–D44`.
- No existing decision, acceptance criterion or invariant changed meaning;
  this pass only adds the cross-document map and one new joint decision.

## Corrections from draft 2.11

Version 2.12 verifies §1.1 directly against `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`
and `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` rather than restating claims
about them from memory, and fixes five gaps found by doing so.

- §1.1's table said this document owns "page-scoped Booking." ADR 0019
  treats Booking/BookingHold/ledger as a separate authoritative aggregate;
  this document owns the management projection and authorization boundary
  over it, not the aggregate. Corrected, and the "Owns" column is renamed
  **Primary surface responsibility** with an explicit note that canonical
  aggregate ownership always stays with that aggregate's own accepted
  domain specification or ADR — a profile document displaying a projection
  never becomes a competing owner of `Scenario`, Booking, the Review
  contract, or `ManagedPage` itself.
- The table claimed `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` owns
  "Reviews-about-person." Checked directly: `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s
  `VP-D08` states Reviews-about-a-person are "deliberately unresolved," and
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `PCP-D04` only governs
  displaying an aggregated *content*-review summary, itself dependent on
  `VP-D08`. Corrected to state the gating explicitly instead of implying
  either is resolved.
- "Public User Projection available for any `User`" could read as a
  standalone public profile. `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.2/§12.3
  scope it strictly to legitimate trigger contexts (Review, Find People
  response, invited Scenario, shared plan) and explicitly forbid it becoming
  a standalone searchable result. The table row now states that scope
  directly rather than the unqualified original phrasing.
- `PP-D44` was framed as a "joint decision" while being referenced by
  neither sibling document. Grepped both directly: zero references either
  direction. §1.1 and `PP-D44`'s own text now say plainly that this is a
  proposal from this document's side, not yet reciprocated, and MUST NOT be
  treated as jointly accepted until it is. `PP-D44` gained a concrete
  `FollowRelation` shape to make the proposal reviewable, `PP-AC-85`, five
  test bullets, and a neutral `FOL-01` roadmap slice explicitly marked as
  requiring joint acceptance with `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s
  `PCP-D02` — this document cannot accept it alone.
- §1.1 gained an explicit precedence order for resolving disagreements
  between sibling documents (Accepted ADR → owning aggregate spec →
  Approved shared cross-product contract → Approved current slice → profile
  surface spec), with a fail-closed rule: a conflict below that ordering is
  blocked on implementation until jointly resolved, not silently decided by
  whichever document is being read.

Minor: Appendix A's subsections were still labeled `B.1`–`B.4` after the
2.10 appendix rename; corrected to `A.1`–`A.4`. The document date was
updated to match the date this correction was actually made.

## Corrections from draft 2.12

Version 2.13 fixes two content errors introduced in 2.12 and one internal
precedence-order contradiction.

- **Reviews dependency reversed:** 2.12's §1.1 stated aggregated
  reviews-about-content display (`PCP-D04`) is "dependent on"
  reviews-about-a-person (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s `VP-D08`).
  Checked `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` directly: `PCP-D04`
  states "Independent of `VP-D08`" in its own text. §1.1 now states the
  correct relationship — the two are separate, unrelated open decisions
  that happen to both be Review-adjacent, not a dependency chain. This
  document's own Revision History row for 2.12 repeated the same
  imprecision and is corrected too (short summary rows are kept accurate as
  understanding improves; this is not the same as rewriting a detailed
  historical rationale, which this file still never does).
- **Competing precedence order removed:** 2.12 added a 5-tier "when sibling
  documents disagree" order to §1.1 that contradicted §0's own order —
  `current-slice spec` appeared at position 2 in §0 and position 4 in §1.1,
  and §1.1 dropped `LAUNCH_STATUS.md` entirely. §1.1 now explicitly defers
  to §0 as the sole controlling order and only adds a fail-closed rule for
  sibling-versus-sibling disagreement within §0's existing tier 4 — it does
  not restate or compete with §0.
- **Creator→Page link ownership narrowed:** `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s
  row claimed "the link to Professional Page" without qualification.
  Checked that document's §21.1 directly: it explicitly relocated "Public
  presentation of Creator/Page relationship" to
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s `PCP-D05` specifically to
  avoid circular approval risk. The row now says `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
  owns only the *private* workspace/publisher relationship, with public
  display cross-referenced to `PCP-D05`.

## Corrections from draft 2.13

Version 2.14 fixes a normative gap 2.13 left standing: §0's precedence
order only ever named *this* document at item 4 ("This document for the
proposed full-release Professional Page experience"); every sibling profile
document fell into item 5's "`VISION.md` and other product material." Read
literally, that lets this document outrank `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`,
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` by default — directly
contradicting §1.1's "this document is not automatically authoritative for
all four."

§0 is restructured from five tiers to six:

1. Accepted ADR (unchanged).
2. Approved current-slice specification (unchanged).
3. `LAUNCH_STATUS.md` — narrowed explicitly to implementation truth, never
   target semantics.
4. Accepted/Approved owning aggregate specification or shared
   cross-product contract (new tier, carved out of the old item 4/5).
5. Draft profile-surface specifications on equal footing — this document
   and every sibling profile document, named explicitly. None outranks
   another by default; §1.1 governs how a conflict within this tier is
   resolved.
6. `VISION.md` and other general product material (previously item 5).

§1.1's "when sibling documents disagree" text is updated to cite §0 item 5
(the correct new tier) instead of item 4, and to cite item 4 (not item 3)
for owning-aggregate/shared-contract precedence.

No decision, acceptance criterion or test changed; this is purely a
document-authority-structure fix.

## Corrections from draft 2.14

Version 2.15 is a cosmetic status fix, not a normative change. §0 item 4
and §1.1 both listed "the Review contract" alongside Category System and
Scenario as if it were an existing Accepted/Approved contract. It is not —
the rest of this document is already careful about this (§12.5 says "when
approved," Appendix A says "only after the canonical Review contract is
approved," `PP-D09`/roadmap `PP-08` treat it as a dependency, not a fact).
Both mentions now read "once approved, the canonical Review contract,"
matching the rest of the document instead of standing out as the one place
that implied it already exists.

## Corrections from draft 2.15

Version 2.16 fixes two real content defects, both surfaced by
`docs/product/PROFILE_DOCUMENTS_INDEX.md` (a new non-normative cross-document
audit index) and independently verified against
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` and
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` directly before being applied —
the index itself is non-normative and does not authorize a change by being
cited; the fix is applied because the underlying claim checked out, not
because the index said so.

- **Scenario/Quick Plan conflation.** §1.1's `owner`-terminology example
  said `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2's `relationship: owned |
  invited` field belongs to Scenario, "deliberately without an `editor`
  tier." Checked §4.2 directly: `owned | invited` is `QuickPlanRef
  .relationship` — Quick Plan's own field, genuinely undecided per that
  document's `VP-D02`. Scenario's actual field,
  `PersonalScenarioRef.accessRole`, is a different, already-**Approved**
  four-value enum (`owner | editor | viewer | unlistedViewer`) per
  `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1/§10.2 — it already has both
  `owner` and `editor`. This document's own §9 already states Route,
  Scenario and Quick Plan are separate aggregates for Create Hub purposes;
  this fix extends the same separation to their personal-library
  collaboration fields, which had drifted back into being conflated
  despite that principle.
- **Broken cross-reference.** §1.1 cited `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
  "§21.1" as the home of `PCP-D05`. That document's numbered sections end
  at §19; the actual location — "## 5. Relationship to a managed
  Professional Page," with the decision itself catalogued in that
  document's own §17 — was confirmed directly and the citation corrected
  to §5.

Minor, reported back rather than silently corrected: the index's own §8
item 4 cites this defect's location as this document's "§0.1," which does
not exist here — the content lives in §1.1. The substance of the index's
finding was still correct; only its own section pointer was off by one
level. This is exactly the kind of index-vs-primary-source divergence the
index's own maintenance notes (§9) anticipate, not a reason to distrust the
finding itself.

## Corrections from draft 2.16

Version 2.17 came from a full self-review of this document (not a fresh
external review pass), cross-checked directly against
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` and
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` before any claim was changed.

**Stale claim fixed:** §1.1 and `PP-D44` said the proposed `FollowRelation`
foundation was "not yet reciprocally referenced" by either sibling
document — true when written, no longer true. Checked both directly:
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` cross-references `PP-D44` more
than ten times as part of a joint `PP-D44`/`VP-D12`/`PCP-D02` decision, and
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` has its own `VP-D12` — "this document's
half of the joint Follow decision" — explicitly gating its entire Follow
section on all three resolving together. §1.1, `PP-D44`, `FOL-01` (§17) and
§20.1 are updated to describe this as the trilateral, mutually-referenced
decision it now is, still `Open` in all three.

**New problem surfaced, not previously known to this document:** the two
sibling proposals use incompatible data shapes.
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s own proposed `FollowRef` is
`{followId, followerUserId, followedUserId, createdAtUtc}` — no `target`
field, structurally unable to represent following a page. This document's
`FollowRelation` uses a discriminated `target: {type: user | page, id}`
covering both. `PP-D44` now names this shape mismatch explicitly as part of
what the joint decision must resolve, rather than leaving it to be
discovered only when someone tries to implement both proposals against one
schema.

**Additions, not corrections:**

- §1.1 gains a short framing note — three of the four sibling documents are
  personal-identity documents, this one is a `ManagedPage` peer — mirroring
  language `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §0 already uses. This does
  not change the equal-footing conflict-precedence tier (§0 item 5); it is
  purely descriptive of what each document is about.
- §0.2 gains a clarification that the shared `PublisherRef` **type** is
  already consumed by both Place and Event under `IDP-04A`, not Event
  alone — only full active-workspace default/non-rewrite *coverage* is
  Event-only so far. The prior wording ("incomplete for nine Create
  types") was not incorrect, only less specific than it could be about
  Place's partial progress.

## Corrections from draft 2.17

Version 2.18 was produced in response to a direct request to reach a fully
justified top score, with an explicit refusal to just assert one. The
response was a full mechanical self-audit — checking structure, not
re-reading for tone — plus one structural change addressing the one
category of risk that no amount of content editing can fully eliminate.

**Mechanical audit, every claim checked programmatically, not by eye:**

- Every `§N` and `§N.M` reference in the document (47 distinct tokens)
  cross-checked against the actual heading list. Two apparent mismatches on
  first pass, both confirmed as false positives on inspection: `§10.2`
  inside a citation of `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1/§10.2
  (an external document's section, not this one's), and `§21.1` inside the
  Revision History's own 2.16 entry, quoting the *old, already-corrected*
  broken citation as history. Zero real broken section references found.
- Every `PP-D` and `PP-AC` token in the document reconciled against its
  canonical definition: 44/44 and 85/85 resolve, no gaps in either
  numeric range, and no cross-reference points at a nonexistent ID.
- Every sibling-document decision ID this document cites (`VP-D02`,
  `VP-D08`, `VP-D12`, `PCP-D02`, `PCP-D04`, `PCP-D05`) reverified with a
  direct `grep` against the current sibling files, not assumed still valid
  from an earlier check in this session.
- The two-file structure verified internally consistent: 17 Revision
  History rows (2.0 through 2.18) and 16 `## Corrections from draft`
  entries in this file — exactly the relationship 17 version-points and 16
  transitions between them should produce, with no orphaned or duplicate
  entry on either side.

**What the audit surfaced, unprompted:** `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`
had moved from v1.8 (last checked in draft 2.16/2.17) to v1.10 *during this
same session*, performing its own independent full self-adversarial
re-read and fixing the same class of Scenario/Quick-Plan conflation this
document fixed in draft 2.16. Re-verifying against v1.10 directly (not
trusting the earlier v1.8 check) confirmed every citation this document
makes of it is still accurate, and that all four sibling documents
(`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`, `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`,
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`, and this one) now genuinely
converge on the same six-tier precedence order and the same "3
personal-identity documents + 1 `ManagedPage` peer" framing this document
adopted in draft 2.17.

**Structural fix, not a content fix:** this document has repeatedly named
cross-document staleness as an unavoidable risk of a multi-document Draft
ecosystem — accurate, but previously left as an invisible, unbounded risk
with no way for a reader to tell how current any given citation actually
was. §1.1 now carries an explicit **verified-against snapshot** — the exact
sibling versions (VP v1.10, CP v1.4, PCP v1.3) this document's citations
were last checked against, as of 2026-08-12. This does not make the
document immune to sibling drift — nothing can, in an ecosystem of
independently evolving Draft documents — but it converts an invisible
assumption into a checkable, bounded fact: a reader can now tell, at a
glance, whether a citation here has been reverified since a given sibling
version, instead of having to trust that it silently still holds.

This document remains `Draft for product and architecture review`.
Mechanical completeness and verified-as-of-today cross-document accuracy
are not the same claim as `Approved` — `PP-D01`–`PP-D44` are still open or
explicitly deferred, exactly as `PP-AC-44` and §21 require before that
status may change.

## Corrections from draft 2.18

Version 2.19 adds one new feature, requested directly in conversation:
automatic detection that a new draft resembles content the page previously
published, and a proactive suggestion to reuse it as a template. This is
new scope, not a fix — the first genuinely new capability added since the
2.6–2.9 operational-model rounds.

**Grounded in what already exists, not invented from nothing:** the real
product already has `CRT-TPL-01` — local/mock, user-managed templates for
Event creation, including "start a new independent draft from the last
template." Separately, `AI-PLAT-LOCAL-01` is an Accepted, provider-neutral
local assistance foundation, not yet wired to Create Hub, Scenario, Place
or Smart Search. `PP-D45` is scoped as connecting these two existing,
already-accepted pieces for a page's own content — not as inventing a new
AI capability or a new template mechanism from scratch.

**What is fixed now, because it follows directly from already-established
principles, not new judgment calls:**

- the suggestion is strictly a proposal — it never creates, saves or
  publishes anything without an explicit accept, the same "no silent
  authority" principle §4.3 already applies everywhere else;
- an accepted suggestion produces a new, independent draft — no live link
  to its source, mirroring the existing `Expand to Scenario` pattern (§9)
  rather than inventing a new kind of link;
- similarity detection is scoped to the active page's own content only —
  never another page's, another publisher's, or personal account data
  beyond what the page already owns;
- it is opt-in per page and rate-limited the same way Messages already are
  (§12.3) — a suggestion feature that cannot be turned off or that spams
  the team would violate principles already in place, not just be
  unpolished.

**What is deliberately left open, because it requires real product
judgment this document should not manufacture:** the exact similarity
criteria (category match, title pattern, day-of-week recurrence, location,
some combination), whether the suggestion surfaces as a dedicated
`Notifications` category or an inline `Create`-hub prompt, and whether it
extends past Event to the other nine Create types (`CRT-TPL-01` does not
yet cover them). `PP-D45`'s own text states these boundaries explicitly so
a future implementer cannot mistake "the safe parts are fixed" for "the
whole feature is fixed."

Added: `PP-AC-86`–`PP-AC-88`; a `Content assist / template suggestions`
row in the `§7` module table; an `Assist` row in `§14`'s notification
category table; a `PP-17 Content assist & templates` roadmap slice (`§17`);
four new `§19` test-matrix bullets; a `§20.1` tracking row. DoD's range
moves from `PP-D01–D44` to `PP-D01–D45`.

## Corrections from draft 2.19

Version 2.20 closes a real gap in `PP-D45`, surfaced by a direct question
in conversation: does the AI behind this feature cost anything?

Checked `AGENTS.md`'s feature-status entry for `AI-PLAT-LOCAL-01` directly
rather than answering from memory. It confirms `AI-PLAT-LOCAL-01` is
Accepted with, among other things, a `session quota`, `kill switches` and a
`zero-cost ledger` — and separately states "production
provider/network/secrets/persistence остаются gated." The honest reading:
the zero-cost ledger is real *today* specifically because no paid provider
is wired in; the quota and kill-switch machinery already exist because the
platform's own design assumes that will not stay true forever. `PP-D45` as
written in 2.19 said nothing about this, which would have let a future
implementer assume the feature is free by default rather than by current
circumstance.

Fixed: `PP-D45` now states plainly that the feature is free only while
`AI-PLAT-LOCAL-01`'s local/mock ledger is what's connected, and that a
production-provider-served suggestion MUST respect that platform's own
quota/kill-switch discipline and `PP-D38`'s general operational-quota rule
— not invent a separate, unbudgeted cost path. Added `PP-AC-89` and a
matching `§19` test asserting a suggestion is rejected once quota/kill
switch triggers rather than silently served anyway; updated `PP-17`'s
dependency and `§20.1`'s `PP-D45` row to reflect the same. Billing
ownership for that eventual cost is explicitly left to `PP-D42`
(entitlement/billing completeness), not resolved here.

## Corrections from draft 2.20

Version 2.21 separates two things `PP-D45` had conflated: a plain
save-and-reuse template mechanism, and AI-based detection of when to
suggest one. Requested directly, and a genuinely useful simplification —
the real product's `CRT-TPL-01` (Event-only manual templates) already
proves the manual half needs no AI at all.

**New:** `PP-D46` — manual page content templates, extending `CRT-TPL-01`
to the page workspace and, potentially, the other nine Create types. Pure
save/list/reuse: no pattern detection, no machine learning, no
`AI-PLAT-LOCAL-01` connection required. Fixed boundaries mirror `PP-D45`'s
for the same reasons already established elsewhere in this document
(saving never mutates the source; a draft made from a template has no live
link to it; template access follows ordinary capability gating, no
bypass). Open: per-type extension beyond Event, count limits, in-place
editing, and organization (folders/tags/search).

**`PP-D45` reworded**, not re-scoped: it now states explicitly that it is
the detection-and-suggestion layer only, assuming `PP-D46`'s save/reuse
mechanism as its target rather than defining what a template is. This
matters because it makes the dependency direction explicit — `PP-D45`
needs `PP-D46` to exist, but `PP-D46` does not need `PP-D45`, and
implementation can and should ship the manual mechanism first.

Added `PP-AC-90`–`PP-AC-92`; a `Page content templates` row in `§7`
(separate from the existing AI-suggestion row); a `PP-18` roadmap slice
explicitly marked "no AI dependency"; `PP-17`'s dependency updated to
require `PP-18` too; four new `§19` test-matrix bullets, including one
confirming the manual mechanism works with `PP-D45`/`AI-PLAT-LOCAL-01`
entirely absent; a `§20.1` row. DoD's range moves from `PP-D01–D45` to
`PP-D01–D46`.

## Corrections from draft 2.21

Version 2.22 resolves the core of `PP-D37`, which had sat fully `Open`
since draft 2.6. The trigger was a proposed policy — publish immediately
for a verified page, auto-pause on complaint — reviewed and revised in
conversation before being written in: the reviewed version keeps "publish
immediately by default" but drops "auto-pause on complaint" entirely, in
favor of "no restriction of any kind without a moderator's prior
affirmative confirmation."

This is not a new rule invented for this revision — it makes explicit and
absolute something `PP-AC-66` already implied ("a page stays visible
unless a...policy-driven interim restriction...is applied through a
trusted moderation process") but had not stated as a hard, threshold-proof
boundary. The gap mattered: "trusted moderation process" alone does not
rule out an automated system deciding report volume/rate meets some
threshold and acting without a human review step — that reading was open,
and closing it is the actual content of this revision.

**Fixed:**

- `PP-AC-66` and `PP-AC-78` reworded to state explicitly that no volume or
  rate of unconfirmed reports substitutes for a moderator's affirmative
  review — an interim restriction is entered only after that review, never
  by an automated threshold acting alone.
- `PP-AC-93` added as a standalone, directly testable statement of the same
  rule, so it does not depend on a reader parsing the longer combined
  `PP-AC-66` text to find it.
- `PP-D37`'s own text states the resolved core principle plainly, including
  the specific point raised in discussion: a verified Creator's page-scoped
  trust changes nothing about whether restriction requires confirmation
  first — it only explains why the account could publish at all, not why
  restriction rules would be relaxed for it.
- A `§19` test added: a simulated flood of unconfirmed reports produces no
  change, and the eventual audit trail records the moderator's
  confirmation as the cause, not the report volume.

**Left open, deliberately:** exact severity/reason codes; how repeat or
coordinated reports are weighted for a moderator's attention without that
weighting becoming a disguised auto-trigger; reporter protection; appeal
SLA; and whether a confirmed restriction's scope defaults to the specific
reported item, the page's new publications, or the page's existing
visibility, as a function of severity. `PP-D37` in `§20.1` moves from
`Open` to "core rule fixed, these parameters open" to reflect the partial
resolution accurately rather than either extreme.

## Corrections from draft 2.22

An external, differently-structured document ("Professional Page Model
v1.1 — canonical product/domain specification", claiming a
`PROFESSIONAL_PAGE_PPR_00_RECONCILIATION_SPEC.md` reconciliation lineage
and its own `PPR-00`–`PPR-06` staging) was proposed as a source of
possibly-useful content. It was not adopted as a parallel or replacement
canon. Verification against the actual repository first:

- The `PROFESSIONAL_PAGE_PPR_00_RECONCILIATION_SPEC.md` file it names as
  its reconciliation source does not exist anywhere in this repository —
  confirmed by an exhaustive filename search of `docs/`. The document's
  entire framing rests on an artifact that is not present.
- The document itself states it treats ADR 0015–0017 as "referenced by
  those files but not included in the current source package" and that it
  "does not silently replace them." But ADR 0015 is titled *"Authenticated
  Viewer, Verified Creator And Professional Page"* — Accepted, and directly
  on-topic, not a peripheral reference — and ADR 0017 is the Accepted
  decision governing self-service page creation. Both exist in
  `docs/adr/` and were available. As a direct consequence, the external
  document reconstructs — less precisely, and without citation — content
  ADR 0015 already establishes (`ManagedPage` boundary, `PublisherRef`,
  capability/membership independence, "Pro is not a role", one Creator
  managing several pages), and it is entirely silent on ADR 0017's
  concrete self-service ownership quota (three owned pages,
  `PageLimitIncreaseRequest`, moderator-only quota increase) — a rule this
  document already carried correctly (`PP-AC-05`/`06`, §5.1) before this
  external document was reviewed.
- Every remaining claim checked directly against `EVENT_CLASSIFICATION_SPEC.md`,
  `EVENT_CLASSIFICATION_ECL_01_SLICE_SPEC.md` and `EVENT_CREATE_SPEC.md`
  (`PublisherRef{type: user|page, id}`, `create.event`/`publish.event`/
  `manage_page`/`manage_bookings`, `Publish as`, workspace non-rewrite) did
  check out — it was not fabricated, just largely redundant with material
  this document and its cited ADRs already state more precisely.

**Added — the five items that survived verification as genuinely new,**
none of them present here before this revision:

- §5.4, onboarding guidance distinguishing personal `PublisherRef{type:
  user}` publishing from creating a page, grounded in ADR 0015 §4 and
  explicitly marked as guidance for the creation flow's own copy, not a
  new authorization rule — it does not narrow `page.create` eligibility.
- §4.4 and new `PP-D47`: a proposed typed `ManagedPageRelation`
  (`operatesPlace | branchOf | partnerOf | providerOf`) as a structural
  refinement of the existing undifferentiated `placeIds` list — marked
  `Open`, not accepted, with the parts that already follow from existing
  invariants (no authority, no Place-geometry override, Event relations
  stay Event-owned) stated as settled rather than reopened.
- `ManagedPagePublicAttribute`/`ManagedPagePublicSection` reserved as
  names for a *possible future* bounded profile-builder extension in
  §4.2 — not implemented, not fields of any accepted entity — specifically
  so a generic `attributes`/`sectionData` escape hatch cannot later be
  added under a different, unreserved name before a dedicated slice is
  Approved.
- `PP-D10` (page claim/merge) sharpened with an explicit list of
  individually insufficient claim-evidence signals — matching name,
  matching address/service area, matching website text, an Event
  co-organizer/host/venue relation, social-link similarity, and
  provider-imported association — none of which may grant a claim alone
  or in combination without an authoritative Identity workflow and audit.
- Two new Appendix B rows and `PP-AC-94`/`PP-AC-95` making the relation
  and reserved-name rules directly testable, plus matching `§19` test
  bullets, a `§20.1` row for `PP-D47`, and a `§17` note tying `PP-D47` to
  the `PP-01` slice. DoD's range moves from `PP-D01–D46` to `PP-D01–D47`.

**Deliberately not added:** the external document's open
descriptor/classification model (duplicates this document's §6, which is
more precisely grounded against the actual 28/530 Category System
catalog), its module-vs-capability separation (already §7, near-identical),
its Booking/Communications/Insights/Payments/provider boundary language
(already §4.3, §12–§14), and its abstract merge/duplicate principles
(already more concretely specified here via `PP-D10`/`PP-AC-63`). Adding
these under new names would have duplicated existing sections without
adding content.

Mechanical verification after this revision: PP-D1–47 and PP-AC1–95 each
appear exactly once with no gaps or duplicates; 0 CR bytes; balanced code
fences; all internal `§`-references resolve to an existing heading in this
document, except two long-standing references to a sibling document's own
section numbers (`SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1/§10.2) and one
historical changelog mention of an already-fixed broken reference, neither
of which is new to this revision.

## Corrections from draft 2.23

Asked directly: "did you take everything good from what I sent?" Answer at
the time was no — 2.23 converged on the five clearest, most obviously
non-duplicate items and moved on without a second, slower pass over the
rest of the external draft. Re-reading it section by section against what
2.23 actually added surfaced three more genuine items:

- The external draft's §3 boundary-matrix and §41 worked ArtMarket scenario
  make the Page/Event/Place boundary concrete through examples; this
  document had no equivalent. Added **Appendix C** with a generalized
  version of the same cases (organization vs. its own event, brand vs.
  physical branch, performer-at-someone-else's-event vs. host, one-off
  happening vs. persistent identity) — non-normative, each row citing the
  section that already makes it a rule.
- The external draft's §21 explicitly separates four audience concepts —
  followers, page team members, Event/Booking participants, and any future
  cross-event audience — and states none may be inferred from another.
  §10.1 here already said "followers are not members," but did not say
  participation doesn't create either relation. Closed that gap directly in
  §10.1, and added `PP-AC-96` plus a `§19` test so it is checkable, not just
  stated.
- The external draft's §16.3 states a page's category never gates its own
  content's archetype. This already followed from existing invariants
  (`§4.3(4)`, §6's "MUST NOT... use page categories to drive Create
  validation"), but had no concrete example. Added one to §6.

**Confirmed still excluded, same reasoning as 2.23, re-checked rather than
assumed:** a parallel descriptor registry (§6.3 of the external draft)
still duplicates the Category System integration this document already has
in §6, with no field or behavior the existing integration lacks. A
consolidated "data ownership" table (§33 of the external draft) still
duplicates Appendix B's exclusion index — same facts, different table
shape, not new information. Neither was added.

Mechanical verification after this revision: PP-D1–47 (unchanged count) and
PP-AC1–96 each appear exactly once with no gaps or duplicates; 0 CR bytes;
balanced code fences; internal `§`-references unchanged from 2.23's clean
result.

## Corrections from draft 2.24

`PROFESSIONAL_PAGE_DECISION_PACKAGE.md` v1.0 (a new companion document, not
this spec itself) was reviewed externally and found to contain six real
errors plus five weaker spots — each verified directly against this spec
and the repository before being accepted as genuine, not taken on the
review's word:

- `PP-D47`'s recommendation to ship the typed relation as "a refinement of
  `placeIds`" is structurally impossible — confirmed by re-reading §4.4's
  own model, where `branchOf`/`partnerOf` are Page→Page and `providerOf` is
  Page→Provider, none of which `placeIds` (Page→Place only) can hold.
- `PP-D15`'s recommendation that Booking holds "continue being honored
  through a suspension" oversteps into Booking's own contract — confirmed
  by re-reading `PP-AC-54`, which already assigns that exact question to
  Booking, not to this document.
- `PP-D25`'s recommendation applied the report/moderator-confirmation rule
  to "report/block/appeal" as one bundle — confirmed by re-reading
  `PP-AC-66`, which already treats a personal Viewer block as immediate and
  page-state-invisible, the opposite of a report's page-wide restriction.
- `PP-D24`'s "stays page-owned" wording for media after a contributor
  departs reads as automatic copyright transfer, which this document never
  asserts anywhere else.
- `PP-D27`'s "Recommend Accept" verdict was resting on "an implementation
  task" rather than an actual answer to which operations need Creator
  verification.
- The decision package's own §7 claimed accepting it yields `Accepted` or
  `Accepted; blocked pending <prerequisite>` — confirmed against this
  spec's own §21, which recognizes only `Accepted` or `Explicitly deferred
  with an owner and a reopening gate`, and against §20.1, where `Owner` is
  `TBD` throughout.

All six, plus the five softer issues (`PP-D46`'s "cheap" framing, `PP-D03`'s
missing ownership-during-cooling-off answer, `PP-D19`'s Booking-borrowed
retention justification, `PP-D32`'s one-size-fits-all state list, and
`PP-D08`/`PP-D41`'s overstated reliance on `ANALYTICS_TAXONOMY.md`), were
fixed in the decision package itself as v1.1 — this spec's own `PP-D`
problem statements were independently re-checked and found accurate; none
of the six errors originated here, all six were introduced when the
decision package proposed *resolutions* to already-correctly-stated
problems.

This spec's own changes are administrative, not substantive: refreshed the
§1.1 verified-against snapshot (the pinned sibling versions had drifted by
5, 4 and 5 minor versions respectively) after re-confirming every citation
still holds against current sibling text, and added a §20 pointer to the
decision package. No `PP-D`/`PP-AC` text changed.

Also noted, not yet acted on: all three files this document family produces
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`, this changelog, and
`PROFESSIONAL_PAGE_DECISION_PACKAGE.md`) remain untracked by git (`git
status` reports `??` for each) — they exist on disk but not yet in project
history. Committing is the user's call, not this session's to make
unprompted.

## Corrections from draft 2.25

The product owner reviewed `PROFESSIONAL_PAGE_DECISION_PACKAGE.md` v1.2
directly, found it materially improved but not yet acceptable whole, fixed
six specific items and a structural gap producing v1.3, then directed a
two-stage integration: fix the package first, then fold the resolved
decisions into this document itself so it — not the package — is the
normative source for them going forward.

**Stage 1 (package v1.2 → v1.3), applied to
`PROFESSIONAL_PAGE_DECISION_PACKAGE.md`, not here:** `PP-D27`'s rule reworded
and its one open `Ask` resolved (new-draft creation needs no Creator
verification, per the product owner's direct call); `PP-D32`'s tightened
transfer matrix confirmed final; `PP-D03`'s ad hoc checklist replaced with a
named `canBecomeManagedPageOwner` predicate, extended to include an
ownership-quota check that closes a real bypass; six more decisions
(`PP-D15`, `21`, `26`, `29`, `38`, `46`) moved into the package's split-
disposition section, expanding it from 7 to 13; `§7` rebuilt around an
exact, mechanically-verified 25/13/4/5 partition of all 47 IDs, replacing
the prior 31/7/1/8 count that six ID moves had made stale.

**Stage 2 (this document, v2.25 → v2.26):** the 17 decisions Stage 1 fully
or partially resolved were integrated directly:

- `PP-D27` — new §3.5 is now the single normative statement of the non-
  Creator staff verification rule; §3.1, §9.1 and `PP-AC-68` reference it
  instead of duplicating it, closing a risk the product owner flagged
  directly (four copies of one rule drifting apart over time).
- `PP-D32` — `PP-AC-73` and §22.2 no longer claim ownership transfer is
  uniform across `suspended`/`archived`/`tombstoned`; transfer is blocked
  during `suspended` (appeal first) and `tombstoned` (restore first, or
  `PP-D29`'s emergency path).
- `PP-D45` — the AI requirement is gone from v1: deterministic category +
  recurring-weekday matching, delivered as an inline Create Hub prompt; the
  `Assist` notification category (§14) is removed since v1 has nothing to
  route through it; `PP-AC-89` rewritten in place (not renumbered) to state
  v1 makes no AI call and therefore has no AI cost, full stop — semantic/AI
  matching is a distinct, separately-Approved v2+ extension.
- `PP-D46` — v1 fixed at Event-only; extending to the other nine Create
  types is Explicitly deferred, staged one type at a time, each needing its
  own sensitive-data/migration review — not a bulk "no AI dependency, so
  it's cheap" default.
- `PP-D47` — `§4.4`'s `ManagedPageRelation` is now an accepted, separate
  entity from `placeIds` (which is unchanged for read-compatibility); v1
  `relationKind` registry and the `unconfirmed` display rule are locked;
  `PP-AC-94` updated to match.
- The other twelve split decisions (`PP-D05`, `08`, `10`, `15`, `19`, `21`,
  `24`, `26`, `29`, `37`, `38`, `41`) each received an `(Accepted core; ...
  Explicitly deferred)` tag at their `§20` entry, a matching `§20.1` row
  naming the remainder's owner and reopening gate, and a short pointer in
  their owning section per the product owner's mapping — `§4.2`/`§8.2`
  (contacts), `§12.4` (analytics), `§11` (media rights), `§15.1`/`§15.3`
  (privacy/quotas), `§22.6`/`§22.8` (retention/integrations) — rather than
  a single catch-all "decisions" section, so each rule lives where an
  implementer would actually look for it.

30 decisions remain outside this pass: 21 more already-`Accepted` items,
`PP-D09`/`22`/`39`/`44` (`Explicitly deferred`), and `PP-D06`/`07`/`11`/
`12`/`42` (still awaiting owner judgment per the package's own §5). Their
integration is future work, not silently dropped — `PROFESSIONAL_PAGE_
DECISION_PACKAGE.md` v1.3's own header now states exactly which 17 IDs it
has handed off versus which 30 it still governs.

Mechanical verification after this revision: `PP-D1`–`47` and `PP-AC1`–`96`
each appear exactly once with no gaps or duplicates (count unchanged — this
was integration, not new decisions); `§20.1` has exactly 47 rows; 0 CR
bytes in both files; code fences balanced.

## Corrections from draft 2.26

Told directly to finish merging the decision package in ("влей дисишн").
Integrated everything the decision package had already resolved that did
not require the product owner's own business/legal judgment:

- The remaining 21 fully-`Accepted` decisions (`PP-D01`, `02`, `03`, `04`,
  `13`, `14`, `16`, `17`, `18`, `20`, `23`, `25`, `28`, `30`, `31`, `33`,
  `34`, `35`, `36`, `40`, `43`) got their `§20.1` status changed from
  `Open`/`Proposed resolution` to `Accepted`.
- `PP-D09`, `39`, `44` — content-resolved-and-blocked-on-a-named-
  prerequisite, the same shape as `PP-D22` — got `§20.1` status changed to
  `Explicitly deferred` with a named owner role and reopening gate, per the
  decision package's own §6.
- `PP-D03` was the one exception needing real integration work, not a
  status tag: it had no dedicated section in this document at all before
  this pass. Added §5.5 with the full accepted transfer flow and the
  `canBecomeManagedPageOwner` predicate, and corrected §11's stale line
  that still called ownership transfer "deferred."

Checked before touching anything: whether any of the 21 "obviously
Accept-able" decisions secretly had a real remainder like the 13 split ones
did — re-read each one's own `§4`/`§3` text in the decision package
directly rather than trusting the "Recommend Accept" label at face value.
None did; each cites content already substantively present in this
document (adapter reuse in §6, the module table in §7, `PP-AC-71`/`72`/`74`/
`75`/`77`/`79` already stating the relevant rule, etc.) — the decision
package's job for these 20 really was just confirmation, not new design
work, which `PP-D03` was the sole exception to.

Left untouched, deliberately: `PP-D06`, `07`, `11`, `12`, `42` remain
`Open` — the decision package's own §5 declines to default these (Follow-
model sharing, communications consent-law exposure, commercial naming,
release-composition planning, billing terms) because they are genuine
business or legal calls, not something a recommendation can responsibly
resolve. Marking them `Accepted` or `Explicitly deferred` without the
product owner's actual input would misrepresent this document's own DoD
tracking.

Mechanical verification after this revision: `§20.1` status counts —
25 `Accepted`, 13 `Accepted core`/split (unchanged from 2.26), 4
`Explicitly deferred`, 5 `Open` — sum to 47 and match the decision
package's own partition exactly, computed by script against the live
document text, not asserted from memory. `PP-D1`–`47` and `PP-AC1`–`96`
unchanged in count, no gaps or duplicates; 0 CR bytes; code fences
balanced.

## Corrections from draft 2.27

Version 2.28 corrects one status/content mismatch introduced when v2.27
integrated `PP-D16` as Accepted. The decision-tracking row already fixed the
move-only default and treated copy as a separate duplicate, but the decision
definition and §22.3 still called move-versus-copy open. Both now match the
accepted disposition: transfer is move-only; copy is a separate,
destination-initiated duplicate command. The exact co-host capability
registry remains an Approved `PP-02` implementation-slice detail and does
not reopen the product decision.

The verified-against sibling snapshot is refreshed to Creator Profile v1.9
and Public Creator Profile v1.9. This documentation correction does not
authorize runtime, backend or provider work.
