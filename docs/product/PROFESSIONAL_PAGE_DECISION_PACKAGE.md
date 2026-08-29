# Professional Page — Decision package PP-D01–D47

- Version: 1.4
- Date: 2026-08-16
- Status: **Decision record — non-normative after integration.** 42 of the
  47 decisions this package covers are now recorded normatively in the
  parent spec itself (v2.27) — this document is the historical rationale
  for those, not a second source of truth: all 25 `Accepted` (§3, §4, §4a,
  §4b), all 13 `Accepted core`/split (§4c), and all 4 `Explicitly deferred`
  (`PP-D09`, `22`, `39`, `44` — §3a and §6). Only **`PP-D06`, `07`, `11`,
  `12`, `42`** (§5) remain ungoverned by the parent spec — genuine
  business/legal/planning calls this package declines to default, still
  `Open` there pending your actual decision.
- Parent spec:
  [PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md](./PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md) v2.27
- Runtime effect: none

## 0. Changes from v1.0

An external review of v1.0 found six items that were wrong or overreached
what the parent spec actually settles, plus five weaker spots — all verified
directly against the parent spec and repository before being fixed here (not
taken on faith):

1. **`PP-D47`** recommended shipping the typed relation as "a refinement of
   `placeIds`" — structurally impossible, since `placeIds` can only hold
   Page→Place references and the relation kinds include Page→Page
   (`branchOf`, `partnerOf`) and Page→Provider (`providerOf`). Corrected to
   recommend §4.4's `ManagedPageRelation` as its own record type, with
   `placeIds` kept unchanged for read-compatibility.
2. **`PP-D15`** recommended that "Booking holds continue being honored
   through a suspension" — this decides Booking's own state, which
   `PP-AC-54` already assigns to Booking's own contract, not to this
   document. Corrected to state only what page suspension does *not* do,
   leaving the actual Booking/hold disposition to Booking's contract.
3. **`PP-D25`** applied `PP-D37`'s moderator-confirmation rule to
   "report/block/appeal" as one bundle. `PP-AC-66` already treats a personal
   Viewer block/mute as immediate and page-state-invisible — the opposite of
   a report's moderator-gated page-wide restriction. Corrected to state the
   two as separate rules.
4. **`PP-D24`** used "stays page-owned" for media after a contributor
   departs, which reads as the page acquiring copyright. Corrected to
   license/right-of-use language — the page never automatically acquires
   copyright.
5. **`PP-D27`** was marked "Recommend Accept" while actually punting the
   real question (which specific operations need Creator verification) to
   "an implementation task." Corrected to an explicit operation-by-operation
   matrix, moved out of §3 into its own §4a.
6. **§7**'s closing claim that accepting this package yields `Accepted` or
   `Accepted; blocked pending <prerequisite>` doesn't match the parent
   spec's own DoD, which only recognizes `Accepted` or `Explicitly deferred
   with an owner and a reopening gate` (§21) — and the owner column is
   `TBD` throughout §20.1 regardless of what this package recommends.
   Corrected §7 to state that plainly and to stop implying acceptance alone
   satisfies DoD.

Also softened: `PP-D46`'s "cheap" framing for extending templates to all ten
Create types (Route/Scenario/Place/Find People carry real sensitive-data and
migration work independent of the AI question); `PP-D03`'s cooling-off
default now states who holds ownership during the window; `PP-D19`'s 30-day
figure no longer leans on Booking's retention class as its justification;
`PP-D32` is now a state × operation matrix instead of one blanket list; and
`PP-D08`/`PP-D41` no longer imply `ANALYTICS_TAXONOMY.md` answers more than
event naming and lifecycle — it does not define page metrics, attribution
windows or suppression thresholds.

## 0a. Changes from v1.1

A second external review found v1.1's fixes genuine but incomplete — six
more issues, all verified before being fixed:

1. **`PP-D19`'s glance-table row (§2)** still said "30-day tombstone window
   (ADR 0019 precedent)" after §4's detailed row had already been corrected
   to drop that justification — confirmed as a real inconsistency between
   the two tables, not a re-litigation of the same point. Both now read the
   same way.
2. **`PP-D27`** still wasn't a real policy: a 10-row list with no stated
   principle, silent on archive/unpublish/delete/transfer/co-host/media
   management/scheduled publish. Replaced with an explicit rule (verification
   gates *increasing* public reach, not reducing it or managing team/Booking)
   plus a fail-closed default for anything not yet classified, and extended
   the table to the missing operations.
3. **`PP-D32`** allowed ownership transfer on a `tombstoned` page within its
   retention window — confirmed as a real evasion path (transfer could be
   used to quietly undo a deletion). Changed to: no ordinary transfer while
   tombstoned; restore first, or use `PP-D29`'s emergency/legal recovery
   path, which is not an ordinary transfer.
4. **`PP-D22`** was labeled "Recommend Accept (as deferred)" — confirmed
   inconsistent with §7's own Accepted-vs-Explicitly-deferred distinction.
   Moved out of §3 into a new §3a, labeled `Recommend Explicit Deferral`.
5. **Six decisions were implicitly counted as `Accepted`** (`PP-D05`, `08`,
   `19`, `24`, `37`, `41`) despite each having a real remainder needing
   Legal/Privacy/Trust & Safety sign-off — confirmed by re-reading each
   one's own §4 text, which already said things like "needs Privacy/Legal
   sign-off" without the disposition table reflecting that. Added §4c with
   an explicit `Accepted core / Explicitly deferred remainder / Owner /
   Reopening gate / Target slice` block for each.
6. **§7's "~40 decisions become Accepted"** was recomputed, not just
   reworded — doing the count mechanically (script, not by hand) surfaced a
   seventh item belonging in §4c (`PP-D10` — see below) and produced an
   exact, verified 31/7/1/8 split covering all 47 IDs with no gap or
   overlap, replacing the earlier approximate figure.

**Also found independently, not flagged by either review:** `PP-D02` and
`PP-D10` were present in the §2 glance table but never appeared in §3 or §4
at all — dropped since v1.0 and unnoticed through two review rounds. Caught
only by writing the §7 recount as a script and finding it didn't sum to 47.
`PP-D02` is now in §3 (fully accepted, no dependency); `PP-D10` is now in
§4c (its evidence-checklist remainder needs the same Trust & Safety/Legal
sign-off as the other split items).

Also softened, per the second review's remaining note: v1.1's `PP-D45`
default (category + recurring weekday) already didn't need AI, but the
package's own wording still framed the whole decision around
`AI-PLAT-LOCAL-01`. Reworded to state v1 as deterministic, non-AI matching
outright, with AI reserved for an explicit later semantic-enhancement layer.

## 0b. Changes from v1.2

The product owner reviewed v1.2's two remaining open `Ask`s directly and
resolved both, then found a real structural gap: six items (`PP-D15`, `21`,
`26`, `29`, `38`, `46`) were still sitting in §4 as plain "Accepted +
recommended default" despite their own text already admitting a real
remainder (a partnership decision, a legal review, an infra-capacity number,
a per-type extension) — the same pattern §4c already existed to fix for
seven other decisions. Applied:

1. **`PP-D27`** (§4a): rule reworded to the product owner's exact framing
   (verification gates crossing the private-draft boundary, not merely
   "increasing reach" — same effect, clearer test); the new-draft-creation
   row resolved to `No` per the product owner's direct call; the `Ask`
   removed.
2. **`PP-D32`** (§4b): the tightened matrix (transfer blocked during
   `suspended` pending appeal, blocked during `tombstoned` pending restore
   or `PP-D29` emergency recovery) confirmed as final; the `Ask` removed.
3. **`PP-D03`** (§4): the five-point ad hoc re-verification checklist
   replaced with one named predicate, `canBecomeManagedPageOwner(userId,
   pageId)`, extended to nine conditions — the five original plus Creator/
   identity eligibility, explicit transfer acceptance, lifecycle-state
   compatibility with `PP-D32`'s matrix, and critically the **ownership
   quota check** (§5.1's 3-page self-service limit), closing a real gap
   where a transfer could otherwise let a user exceed the quota that direct
   creation already respects.
4. **`PP-D15`, `21`, `26`, `29`, `38`, `46`** moved from plain §4 into §4c,
   each given a full `Accepted core / Explicitly deferred remainder / Owner
   / Reopening gate / Target slice` block — expanding §4c from 7 to 13
   decisions.
5. **§7** rebuilt around the resulting exact four-way partition — 25 fully
   `Accepted`, 13 split, 4 fully `Explicitly deferred`, 5 needing owner
   judgment — replacing the previous 31/7/1/8 count, which is now stale
   because six IDs moved buckets. Verified mechanically against the actual
   document structure (script, not by hand): the four groups derived
   independently from §3/§3a/§4/§4a/§4b/§4c/§5/§6's real content sum to
   exactly 47 with no gap or overlap, matching the stated groups exactly.
6. **§6** renamed from "Blocked" to "Explicitly deferred," and `PP-D09`/
   `39`/`44` moved out of §5's "needs owner judgment" into it — they were
   already content-resolved-and-blocked-on-a-named-prerequisite, the same
   shape as `PP-D22` (§3a), not open business questions like the five that
   remain in §5.
7. **§1**'s acceptance framing rewritten around per-proposition disposition
   rather than per-`PP-D`-ID: a decision can carry an `Accepted` core and an
   `Explicitly deferred` remainder at once, and that split must be visible
   in the parent spec's `§20.1`, not collapsed into one verdict.

## 0c. Changes from v1.3

Told to finish merging ("влей дисишн"). No recommendation content changed —
this is a status-header update reflecting that the parent spec's v2.27
integration pass absorbed the remaining 25 `Accepted` and completed the
`Explicitly deferred` bucket (`PP-D09`/`39`/`44` joined `PP-D22`), leaving
only §5's five judgment calls outside the parent spec. See
`PROFESSIONAL_PAGE_SPEC_CHANGELOG.md`'s "Corrections from draft 2.26" entry
for the parent spec's own account of what changed there, including the one
substantive addition (`PP-D03`'s new §5.5) versus the twenty that were
already-present content getting a status tag.

## 1. Purpose

`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §21 (Definition of Done) requires every
one of `PP-D01`–`PP-D47` to be "accepted or explicitly deferred with owners and
gates" before the document itself can move from Draft/Review to Accepted. That
document states each decision's problem and, for most of them, already narrows
the answer considerably — but it does not itself recommend a resolution or ask
for one in a form a product owner can act on quickly. This package does that:
for every decision it proposes a recommended resolution (or states plainly
that none can be responsibly recommended yet, and why), grouped so the owner
can dispose of the mechanical majority in bulk and spend real attention only on
the genuine judgment calls.

**What accepting this package does and does not do.** Acceptance applies
separately to each normative proposition, not to a `PP-D` ID as one
indivisible unit. Every proposition must be recorded as `Accepted` or
`Explicitly deferred` with an accountable owner and a reopening gate — no
third status exists. A decision may contain an `Accepted` core and an
`Explicitly deferred` remainder in the same breath; when it does, that split
must be visible in the parent specification's own `§20.1` tracking, not
collapsed into one blanket verdict for the `PP-D` as a whole (§4c's thirteen
decisions are exactly this case). This does **not** authorize runtime,
backend, Firebase or production work by itself — physical implementation
still requires an Approved bounded slice spec and, per `AGENTS.md`, exit
from the current stabilization slice for anything beyond the already-
permitted `IDP-03A/04A/05A` local/mock exception.

Recommendations below are optimized for minimum operational/legal risk and
honest fail-closed behavior, consistent with how `ADR 0019` and the ECL-03
package were framed — not for feature completeness. Several are explicitly
**not** recommendations at all, because the missing input is legal, financial
or a genuine business call this document has no basis to make.

## 2. Decisions at a glance

| ID | Recommended decision | Status |
|---|---|---|
| `PP-D01` | Reuse Category System stable IDs via explicit adapter; no parallel taxonomy | Recommend Accept |
| `PP-D02` | Public/indexed only once verified and `lifecycle=active`; no `unlisted` page variant in v1 | Recommend Accept |
| `PP-D03` | Explicit transfer flow (request → owner confirm → new-owner accept → step-up reauth → cooling-off → re-verification → atomic completion → audit); no co-ownership; blocked while active obligations exist | Recommend Accept core; cooling-off duration open |
| `PP-D04` | §7's module table is the v1 module ID set; disabling a module never deletes data | Recommend Accept |
| `PP-D05` | Phone/email/website/messaging-handle contact types; public reveal gated on page verification; anti-spam rate limit | Recommend Accept baseline; per-market legal defaults need Privacy/Legal sign-off |
| `PP-D06` | Page-follow proceeds on the proposed `FollowRelation` shape; opt-in only; no historical audience export in v1 | Needs owner input; shared-shape half is blocked on `PP-D44` |
| `PP-D07` | Sender = page identity; recipient basis = opt-in only; `PP-D38` rate limits apply | Needs owner input (consent-law exposure) |
| `PP-D08` | Reuse `docs/analytics/ANALYTICS_TAXONOMY.md`'s event-naming/lifecycle conventions — it does **not** define page metrics, attribution windows or thresholds, so most of `PP-D08` remains genuinely open | Recommend Accept the naming reuse only; the rest is unresolved, not answered |
| `PP-D09` | Cannot resolve — no canonical Review contract exists yet in the repo | Explicitly deferred (§6) |
| `PP-D10` | Split disposition (§4c) — insufficient-evidence list fixed (v2.23) and Accepted; the sufficient-evidence checklist is Explicitly deferred to Trust & Safety/Legal | Recommend Accept core via §4c; not a plain Accept |
| `PP-D11` | Architectural constraint (entitlement ≠ role) accepted now; tier naming/pricing out of scope here | Recommend Accept constraint only |
| `PP-D12` | Defer to a release-planning pass once this package is disposed of | Needs owner input (planning exercise) |
| `PP-D13` | Already-accepted semantic types; wire names/`schemaVersion` are an implementation-slice detail | Recommend Accept |
| `PP-D14` | §22.1 core; 7-day invite expiry, 24h resend cooldown, relationship changes follow ordinary grant rules | Recommend Accept core + defaults |
| `PP-D15` | Split disposition (§4c) — Booking-boundary core Accepted (`PP-AC-54`); retention window/appeal timing Explicitly deferred | Accepted core via §4c; not a plain Accept |
| `PP-D16` | §22.3 core; transfer defaults to move-only, not copy | Recommend Accept core + default |
| `PP-D17` | §22.4 core; global-unique slug, 1 rename/30 days, rename never resets verification | Recommend Accept core + defaults |
| `PP-D18` | §22.5 core; whole-object revision check (no section locking) in v1; "significant edit" = moderation-relevant fields only | Recommend Accept core + defaults |
| `PP-D19` | §22.6 core; 30-day starting placeholder — requires its own Page-retention justification and Legal/Privacy approval, not borrowed from Booking; followers/grants frozen, not deleted, during it | Recommend Accept core; the 30-day figure is Explicitly deferred, not Accepted, until Legal/Privacy signs off |
| `PP-D20` | §22.7 core; escalation/quiet-hours/per-channel prefs deferred as non-blocking | Recommend Accept core |
| `PP-D21` | Split disposition (§4c) — security custody core Accepted (§22.8); provider selection Explicitly deferred to Partnerships/Business | Accepted core via §4c; not a plain Accept |
| `PP-D22` | Already stated as explicitly deferred — no branch/brand hierarchy in v1 | Recommend Explicit Deferral |
| `PP-D23` | Fully per-locale storage for `displayName`/description/labels; translation workflow deferred | Recommend Accept model |
| `PP-D24` | Page-level shared media library; departing contributor's already-published media stays visible under its existing license/right-of-use grant — the page never acquires copyright by default | Recommend Accept |
| `PP-D25` | Two separate rules: Report follows `PP-D37`'s moderator-confirmation gate before any page-wide restriction; a personal Block/mute is immediate, Viewer-only and never changes page state for anyone else (`PP-AC-66`) | Recommend Accept |
| `PP-D26` | Split disposition (§4c) — data-safety core Accepted; billing-owner mechanics Explicitly deferred to Commercial/Billing | Accepted core via §4c; not a plain Accept |
| `PP-D27` | Final rule (§4a): verification required only when content crosses the private-draft boundary — submit/publish/republish/scheduled-publish; not required for opening the workspace, drafting, editing an unsubmitted draft, reducing reach, Booking/check-in or ordinary page/team management; unclassified operation fails closed | Accepted |
| `PP-D28` | Standard security-engineering baseline in full, including "inviter delegates only what they hold" | Recommend Accept in full |
| `PP-D29` | Split disposition (§4c) — evidence-review-required principle Accepted (`PP-AC-70`); acceptable-evidence checklist Explicitly deferred to Trust & Safety/Legal | Accepted core via §4c; not a plain Accept |
| `PP-D30` | PP-AC-71's list plus granting `manage_team`-class capability; MFA mechanism owned by the Identity slice | Recommend Accept list |
| `PP-D31` | Holding a capability never implies `canDelegate`/`canRevoke`; delegation is its own explicit grant | Recommend Accept |
| `PP-D32` | Final state × operation matrix (§4b) — transfer blocked during `suspended` (appeal first) and `tombstoned` (restore first, or `PP-D29` emergency recovery); `PP-AC-73`'s uniform list is superseded | Accepted |
| `PP-D33` | Acting user needs membership+capability on the collaborating page per command; cancellation/refund stays with the originating page; either side can end the collaboration | Recommend Accept |
| `PP-D34` | PP-AC-75's atomic/per-item rule applies; scheduled publish/recurrence is non-blocking Mature extension | Recommend Accept |
| `PP-D35` | v1 = existing revision check only; no real-time presence/merge UI yet | Recommend Accept minimal scope |
| `PP-D36` | Core already fixed; slug stays untranslated; `defaultLocale` is the fallback; edit re-triggers moderation only for moderation-relevant fields | Recommend Accept core + defaults |
| `PP-D37` | Core already fixed in conversation and in the spec text; remaining params are explicitly non-blocking | Recommend Accept core |
| `PP-D38` | Split disposition (§4c) — "never loses data/drops an obligation" invariant Accepted (`PP-AC-79`); numeric limits Explicitly deferred to Infra/Operations | Accepted core via §4c; not a plain Accept |
| `PP-D39` | Recharge-originated writes win over provider data on conflict for user-created fields; full spec blocked on `PP-D21`'s provider choice | Explicitly deferred (§6), blocked on `PP-D21` |
| `PP-D40` | Standard queued→sent→delivered\|failed→dead-letter pattern; retry/backoff is implementation detail | Recommend Accept |
| `PP-D41` | Unique-user is the canonical count, total-action secondary; suppression threshold needs Privacy/Legal — `ANALYTICS_TAXONOMY.md` does not define this either | Recommend Accept the counting default; suppression threshold unresolved |
| `PP-D42` | Only the architectural constraint (entitlement/capability/verification stay separate) is this document's to accept; billing terms are a separate commercial decision | Recommend Accept constraint only |
| `PP-D43` | Promote §17's existing PP-01–PP-16 mapping from implicit to the formal answer | Recommend Accept |
| `PP-D44` | Trilateral — cannot be resolved by this document alone; shape mismatch with `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s `FollowRef` still unresolved | Explicitly deferred (§6), joint decision required |
| `PP-D45` | Boundaries already fixed; v1 similarity is **deterministic, non-AI** matching (category + recurring weekday) — `AI-PLAT-LOCAL-01` is reserved for a later semantic-enhancement layer on top, not required for v1 at all; inline Create-hub prompt; Event-only scope for v1 | Recommend Accept boundaries + defaults |
| `PP-D46` | Split disposition (§4c) — Event-only v1 mechanism Accepted; per-type extension to the other nine Create types Explicitly deferred, staged one at a time | Accepted core via §4c; not a plain Accept |
| `PP-D47` | Boundaries already fixed; ship §4.4's `ManagedPageRelation` as its own record type — `branchOf`/`partnerOf` are Page→Page and `providerOf` is Page→Provider, none of which `placeIds` can represent — and keep `placeIds` unchanged for read-compatibility; v1 registry = the four kinds already listed; unverified relation shown with a neutral label | Recommend Accept boundaries + defaults |

## 3. Recommend Accept as-is

These have no real product-policy ambiguity left — they are either already
stated elsewhere in the parent spec in substance, or are standard engineering
practice with one obviously safer choice. Accepting them in bulk is low-risk.

- **`PP-D01`** — §6 already commits to adapter reuse over a parallel taxonomy; this only promotes that from "should" to "accepted."
- **`PP-D02`** — public/indexed only once verified and `lifecycle=active`, no `unlisted` variant in v1: a deliberately narrow default with no legal/business dependency, and nothing about it changes if revisited later (adding `unlisted` is additive, not a breaking reversal).
- **`PP-D04`** — §7's module table already is the intended v1 surface list; the "disable never deletes data" rule is already a standing invariant (§7 closing paragraph).
- **`PP-D13`** — the semantic types are already accepted in §4.1; only wire-level naming is left, which is an implementation-slice call, not a product one.
- **`PP-D28`** — a standard invitation-security checklist (permanent ID, single-use token, replay protection, enumeration resistance, least-privilege delegation). None of these items trade off against a legitimate competing product need.
- **`PP-D31`** — least-privilege default; the parent spec's `PP-AC-72` already assumes this split exists.
- **`PP-D40`** — a standard reliable-delivery state machine; no product choice varies it.
- **`PP-D43`** — §17 already assigns every `PP-D27`–`PP-D42` item to a slice; this is a formal confirmation, not new work.

### 3a. Recommend Explicit Deferral, not Accepted

`PP-D22` is content-resolved (no branch/brand hierarchy in v1) but its
*disposition* is the other DoD bucket, not this one — the parent spec's own
text already says "explicitly deferred… until a dedicated aggregate and its
own ADR are approved," which is a deferral with a stated reopening
condition, not an acceptance. Listing it under §3 in v1.1 blurred exactly
the distinction §7 relies on. **Recommend:** record `PP-D22` as `Explicitly
deferred` — owner: whoever would own a future branch/brand-hierarchy
proposal; reopening gate: a dedicated aggregate and its own ADR being
proposed.

## 4. Recommend Accept core, with an engineering-only parameter deferred

These already have their hard part resolved in the parent spec (usually a
`§22.x` mechanism); what remains is a parameter with a reasonable safe default
that a later implementation slice can still adjust without reopening the
decision itself.

| ID | Core (already resolved) | Recommended default for the open parameter |
|---|---|---|
| `PP-D03` | Explicit multi-step transfer flow, no co-ownership | Cooling-off window: 48h, cancellable by either party until it elapses; the **current owner remains the owner of record — with full authority, including cancelling the transfer — until the transfer completes atomically**; the prospective new owner has no authority before that point. Immediately before atomic completion, evaluate a single named predicate — `canBecomeManagedPageOwner(userId, pageId)` — rather than an ad hoc checklist scattered across documents, checking: (1) an eligible `AccountStatus`; (2) applicable Creator/identity eligibility; (3) the prospective new owner has explicitly accepted the transfer; (4) no prohibiting page `lifecycle` state (per `PP-D32`'s matrix — e.g. `suspended`/`tombstoned` block transfer outright); (5) the ownership quota (§5.1's 3-page self-service limit) is satisfied or an approved `PageLimitIncreaseRequest` exists — closing the gap where a transfer could otherwise bypass the quota that direct creation respects; (6) no new Booking/payment/legal obligation attached to the page since the request (§4.1's blocking rule, evaluated fresh, not a stale snapshot); (7) the step-up re-authentication (`PP-D30`) is still within its freshness window, not reused from request time; (8) page `revision` is unchanged since the request; (9) neither party cancelled in the interim. Any single failed condition aborts the transfer rather than completing it partially |
| `PP-D14` | §22.1 `TeamInvitation` mechanism | 7-day expiry, 24h resend cooldown, mid-membership relationship change follows ordinary capability-grant rules |
| `PP-D16` | §22.3 explicit audited transfer | Default move-only; copy is a separate, destination-initiated "duplicate," never a transfer variant |
| `PP-D17` | §22.4 ID-is-authoritative rule | Global-unique slug, 1 rename per 30 days, rename never resets verification standing |
| `PP-D18` | §22.5 `revision`-based rejection | Whole-object check in v1 (no section-level locking); "significant edit" = a moderation-relevant field, not any edit |
| `PP-D20` | §22.7 capability-based routing | Escalation, quiet hours and per-channel preference explicitly deferred as non-blocking |
| `PP-D23` | Per-locale-role completeness (`PP-AC-77`/`64`) | Storage is fully per-locale, not single-value-with-fallback; translation workflow deferred |
| `PP-D25` | — | Two separate rules, not one: **Report** — `PP-D37`'s now-fixed principle applies unchanged (no page-wide restriction without moderator confirmation). **Personal Block/mute** — takes effect immediately for that Viewer alone, needs no moderator step, and never changes the page's state or visibility for any other Viewer (`PP-AC-66`). Appeal applies to a moderator-confirmed report restriction, not to a personal Block |
| `PP-D30` | — | `PP-AC-71`'s list plus granting a `manage_team`-class capability to a new member; the MFA mechanism itself belongs to `IDENTITY_PUBLISHER_SLICE_SPEC.md`, not this document |
| `PP-D33` | `PP-AC-74`'s per-command resolution rule | Cancellation/refund responsibility stays with the page whose `PublisherRef` the content carries; either co-host can end the collaboration unilaterally (it is a grant, not a joint contract) |
| `PP-D34` | `PP-AC-75`'s atomic/per-item declaration rule | Scheduled publish/recurrence is a non-blocking Mature extension, not required for v1 |
| `PP-D35` | §22.5's single-mutation check | v1 scope stops at that check — no real-time presence or merge UI; offline draft surviving a revoke stays locally readable but cannot submit (§9.1 rule 9) |
| `PP-D36` | `PP-AC-77`/`64`'s default-vs-secondary split | Slug is never translated (it is a technical identifier); `defaultLocale` is the universal fallback; an edited translation re-triggers moderation only when it touches a moderation-relevant field |
| `PP-D45` | Boundaries fixed (no silent authority, independent draft, page-own-history only, opt-in, quota-respecting) | v1 is **deterministic local matching only** — category + recurring weekday (lowest false-positive risk) — and needs no `AI-PLAT-LOCAL-01` connection to ship at all, sharpening `PP-D45`'s own text that already calls itself "the detection and suggestion layer": a later revision MAY layer semantic/AI-based matching on top as an enhancement once `AI-PLAT-LOCAL-01` is wired up, but that is explicitly a v2+ question, not part of accepting `PP-D45` now; delivery = inline Create-hub prompt, not a Notification; scope = Event-only for v1, matching `CRT-TPL-01`'s current coverage; `PP-D46`'s manual templates remain fully independent of this decision either way |
| `PP-D47` | Boundaries fixed (§4.4: no authority, no geometry override, Event relations stay Event-owned) | Ship §4.4's `ManagedPageRelation` as its **own record type** — `branchOf`/`partnerOf` (Page→Page) and `providerOf` (Page→Provider) cannot be expressed as entries in `placeIds`, which is structurally Page→Place only; `placeIds` stays exactly as it is today for read-compatibility, not deprecated or folded in; v1 `relationKind` registry = `operatesPlace \| branchOf \| partnerOf \| providerOf`; an unverified relation displays with a neutral "unconfirmed" label rather than being hidden or shown as equal to a verified one |

## 4a. `PP-D27` — non-Creator staff verification rule

v1.1's matrix was still a punt in a different shape: ten rows, no stated
principle connecting them, and silent on several operations a real page
workspace has (archive, unpublish, delete, transfer, co-host, media/template
management, scheduled publication). A list that has to be re-consulted for
every new operation is not a resolved product policy — a **rule** is:

> Creator verification is required when content crosses the private-draft
> boundary and becomes reachable for moderation, review or public
> distribution: `submit`, `publish`, `republish` and scheduled publish
> taking effect. It is not required for opening the workspace, drafting,
> editing an unsubmitted draft, reducing public reach, Booking/check-in
> operations, or ordinary page/team management under an assigned
> capability. An unclassified operation **fails closed** — treated as
> requiring verification — until it is explicitly added to the table below.

Applying that rule to every operation this package is aware of:

| Operation | Creator verification required? | Basis |
|---|---|---|
| Open the page workspace | No | `canOpenPageWorkspace`, §3.1 — active membership only |
| View existing drafts | No | Capability-gated only, per §3.1's own example |
| Edit an existing draft | No | Not yet a publish-affecting act |
| Create a new draft | **No** | Resolved: drafting alone does not make anything public, so it follows the same rule as editing an unsubmitted draft |
| Submit for review | Yes | Newly reachable-for-review; §9.1's create/submit/publish chain |
| Publish | Yes | §3.1's explicit example; newly public |
| Republish after edit | Yes | Same act as publish under the rule above |
| Scheduled publish taking effect | Yes | The rule applies at the moment content becomes public, not at scheduling time |
| Unpublish / archive as a safety action | No | Reduces reach; the rule only gates *increasing* reach |
| Delete (soft/tombstone) | No | Reduces reach further than unpublish; same reasoning |
| Ownership transfer | No — gated by `PP-D30`'s step-up authentication instead | A different, already-covered authority control, not this rule's concern |
| Co-host accept/end | No — gated by exact-page capability per `PP-AC-74` | Authority matter, not content publication |
| Media/template management (save, edit, delete) | No | Capability-gated (§7); `PP-D46`/`§4.3` already say saving/reusing a template never itself publishes |
| Manage Booking under an assigned capability | No | §3.1's explicit staff-only example |
| Check-in | No | §3.1's explicit staff-only example |
| Edit page profile/metadata | No | Capability-gated (`manage_page`-class); not content creation |
| Manage team | No | Capability-gated (`manage_team`-class); an authority matter |
| *(any operation not listed above)* | **Yes, fail-closed**, until explicitly classified | Per the rule's own default |

Resolved: every row above is final, including new-draft creation. `PP-D27`
carries no open `Ask`.

## 4b. `PP-D32` — obligation-serving exception state matrix

v1.0 promoted `PP-AC-73`'s exception list to "the canonical answer" as one
blanket list applying identically to `suspended`, `archived` and
`tombstoned`. That conflates three states with different causes (moderation
action, voluntary archival, deletion in progress) and should not automatically
grant the same exceptions to all three. Proposed matrix:

| Operation | `suspended` | `archived` | `tombstoned` |
|---|---|---|---|
| Appeal the restriction | Yes — the point of the state | N/A (not a restriction) | N/A |
| Restore to `active` | Only via the appeal outcome, not self-service | Yes, self-service | Only within the retention window (`PP-D19`), then unavailable |
| Ownership transfer | **No** — an active moderation action must be resolved by appeal first; ordinary transfer is not a substitute for appeal | Yes | **No** — must be explicitly restored (within the retention window) before an ordinary transfer; the only exception is `PP-D29`'s emergency/legal recovery, a separate evidence-reviewed process, not an ordinary transfer |
| Data export | Yes | Yes | Yes, within the retention window |
| Booking cancellation/refund | Yes | Yes | Yes |
| Existing-Booking service (honoring an already-confirmed Booking) | Yes | Yes | Yes, until the obligation completes or the retention window closes, whichever governs per Booking's own contract |
| Legal-hold-required actions | Yes | Yes | Yes — legal hold overrides the retention window itself |

Resolved: ownership transfer is blocked during both `suspended` (must appeal
first) and `tombstoned` (must restore first, or use `PP-D29`'s separate
emergency/legal recovery) — a deliberate tightening of `PP-AC-73`'s original
blanket list, which allowed transfer identically across all three states.
`PP-AC-73` itself needs a matching edit in the parent spec; tracked as part
of integrating `PP-D32` there (Stage 2).

## 4c. Split dispositions — these are not simply "Accepted"

Thirteen items have a remainder substantial enough that treating the whole
decision as `Accepted` (with a minor implementation detail deferred) instead
of "small Accepted core + real Explicitly-deferred remainder" would overstate
what this package actually resolves. Each needs its own named owner and gate,
not just this package's recommended default. Six of the thirteen (`PP-D15`,
`21`, `26`, `29`, `38`, `46`) were still sitting in plain §4 through v1.2,
labeled only "recommended default," even though their own text already said
things like "blocked on a real partnership decision" or "needs a real legal
review" — the same pattern already fixed for the original seven. Moved here
for consistency, not because anything about their content changed.

**`PP-D10` — Page claim/merge evidence**
```
Accepted core:          the insufficient-evidence list itself (name, address,
                         website text, Event relation, social-link similarity,
                         provider import — none sufficient alone or combined)
Explicitly deferred:    the acceptable-document checklist for what IS
                         sufficient (e.g. verified business registration,
                         verified domain-matched email)
Owner:                  Trust & Safety / Legal
Reopening gate:         T&S/Legal defines and approves the acceptable-evidence
                         checklist
Target slice:           PP-12
```

**`PP-D05` — Public contacts**
```
Accepted core:          contact types (phone/email/website/messaging-handle);
                         public reveal gated on page verification; anti-spam
                         rate limit
Explicitly deferred:    per-market legal defaults — which contact types are
                         safe/required to expose per jurisdiction
Owner:                  Privacy/Legal
Reopening gate:         Privacy/Legal review completed for each target launch market
Target slice:           PP-01
```

**`PP-D08` — Analytics**
```
Accepted core:          reuse ANALYTICS_TAXONOMY.md's event-naming/lifecycle
                         conventions
Explicitly deferred:    canonical page metric set, attribution windows,
                         privacy thresholds, retention
Owner:                  Analytics/Privacy
Reopening gate:         a page-metrics spec (new or as an ANALYTICS_TAXONOMY.md
                         extension) is written and approved
Target slice:           PP-07
```

**`PP-D19` — Deletion, archive and retention**
```
Accepted core:          soft/tombstoned deletion mechanism (§22.6); followers/
                         team grants frozen, not deleted, during the window
Explicitly deferred:    the retention-window length itself — 30 days is a
                         placeholder, not a Legal/Privacy-approved figure
Owner:                  Legal/Privacy
Reopening gate:         Legal/Privacy approves a retention period for this
                         specific data class (page/team/audit — not Booking's)
Target slice:           PP-12
```

**`PP-D24` — Media rights and lifecycle**
```
Accepted core:          page-level shared media library model; EXIF/location
                         stripping mandatory; license/right-of-use framing
                         (never automatic copyright transfer on membership end)
Explicitly deferred:    licensing-capture mechanics at upload, handling of a
                         later-revoked license, orphan-cleanup timing
Owner:                  Legal (licensing terms) + Product (cleanup UX)
Reopening gate:         a licensing-capture mechanism is designed
Target slice:           PP-13
```

**`PP-D37` — Trust-and-safety and moderation model**
```
Accepted core:          the fixed rule itself — no restriction without a
                         moderator's affirmative confirmation, at any report
                         volume
Explicitly deferred:    severity/reason codes, appeal SLA, restriction scope,
                         brigaded-report weighting, block-effect-on-Search
Owner:                  Trust & Safety
Reopening gate:         Trust & Safety operational design for the deferred items
Target slice:           PP-14
```

**`PP-D41` — Analytics data quality**
```
Accepted core:          unique-user is the canonical count, total-action a
                         secondary metric
Explicitly deferred:    small-cohort suppression threshold, bot/fraud
                         filtering specifics, backfill/correction policy
Owner:                  Analytics/Privacy (same as `PP-D08` — tightly coupled)
Reopening gate:         same gate as `PP-D08`
Target slice:           PP-07
```

**`PP-D15` — Page lifecycle cascade over content and exposure**
```
Accepted core:          page suspension by itself neither deletes nor cancels
                         Booking/holds; their actual continuation, cancellation
                         or expiry is decided entirely by Booking's own
                         contract (ADR 0019/ECL-03), consistent with PP-AC-54
Explicitly deferred:    the exact retention window per each §22.2 cascade
                         row; appeal/re-review timing
Owner:                  Trust & Safety (appeal/re-review timing) + Legal/
                         Privacy (retention window — same gate as PP-D19)
Reopening gate:         PP-D19's retention-window approval, plus a Trust &
                         Safety appeal/re-review SLA design
Target slice:           PP-12
```

**`PP-D21` — Integration credentials and provider isolation**
```
Accepted core:          page-scoped, backend-only secret custody; immediate
                         revocation on membership/relevant change (§22.8)
Explicitly deferred:    which providers ship first; OAuth consent scope
                         granularity; webhook signature verification specifics
Owner:                  Partnerships/Business (provider selection) + Security
                         (OAuth/webhook mechanics)
Reopening gate:         a first integration partner is selected
Target slice:           PP-11
```

**`PP-D26` — Entitlement downgrade**
```
Accepted core:          downgrade never deletes data; lost-access features go
                         read-only rather than disappearing (mirrors PP-AC-67's
                         obligation-continuity exception)
Explicitly deferred:    exact feature-by-feature downgrade boundary; billing-
                         owner mechanics
Owner:                  Commercial/Billing
Reopening gate:         a Commercial/Billing spec exists and is approved —
                         the same prerequisite PP-D11/PP-D42 need
Target slice:           PP-10
```

**`PP-D29` — Emergency ownership recovery**
```
Accepted core:          interim custody is read-only/frozen until resolved;
                         evidence review is required, never automatic
                         (PP-AC-70)
Explicitly deferred:    the acceptable-evidence checklist itself (e.g. death
                         certificate, legal successor documentation)
Owner:                  Trust & Safety / Legal
Reopening gate:         T&S/Legal defines and approves the acceptable-
                         evidence checklist — the same shape as PP-D10's gate
Target slice:           PP-15
```

**`PP-D38` — Operational quotas**
```
Accepted core:          reaching a quota never loses data or drops an
                         existing obligation (PP-AC-79)
Explicitly deferred:    the actual numeric limits — team size, storage,
                         messages, export frequency, API/provider usage
Owner:                  Infra/Operations
Reopening gate:         real infra capacity planning produces approved
                         numbers
Target slice:           PP-16
```

**`PP-D46` — Manual page content templates**
```
Accepted core:          Event-only v1 — manual save/list/reuse mechanism;
                         source item never mutated; new draft has no live
                         link back; ordinary capability gating; editable in
                         place; flat list, no folders/tags
Explicitly deferred:    per-type extension beyond Event — each of the other
                         nine Create types needs its own sensitive-data and
                         migration review before inclusion, not a bulk
                         extension just because no AI dependency gates it
Owner:                  Product, staged one Create type at a time
Reopening gate:         each additional Create type's own sensitive-data/
                         migration review is completed and approved
Target slice:           PP-18
```

## 5. Needs explicit owner judgment

Five decisions are real business or planning calls, not something this
package can default its way through. A default is suggested only where
refusing to suggest one would just waste a review cycle — but none of these
should be accepted on the strength of this package's suggestion alone.

- **`PP-D06` — Audience/follow.** Suggested default: proceed on the proposed
  `FollowRelation` shape, opt-in only, no historical audience export in v1
  (matches the already-Gated CRM stance in Appendix B). But whether this model
  is *shared* with personal Creator-follow is not this document's call alone —
  see `PP-D44` in §6. **Ask:** accept the page-follow shape as proposed, on the
  understanding that the shared-vs-separate question stays open until `PP-D44`
  resolves?
- **`PP-D07` — Communication.** Sender identity, recipient consent basis and
  moderation touch consent/anti-spam law (e.g. GDPR/PECR-class rules for
  Latvia/EU markets) directly. A wrong default here is a compliance exposure,
  not a UX detail. **Ask:** who signs off on the recipient-consent basis
  before this is implementable — is that Legal, or is that you directly?
- **`PP-D11` / `PP-D42` — Commercial naming and billing terms.** This
  document can and does accept the *architectural* constraint (entitlement
  never becomes a role or capability source) but has no basis to propose tier
  names, pricing, trial length or tax handling — that is a business decision.
  **Ask:** should a separate Commercial/Billing spec be started, or is this
  intentionally out of scope until closer to launch? (`PP-D26`'s billing-owner
  remainder in §4c shares this same prerequisite.)
- **`PP-D12` — Release composition.** Which Mature extensions ship in the
  first full release is a prioritization call that depends on which of the
  above get accepted and staffed — better done as a short planning pass once
  this package is disposed of, not guessed at here.

## 6. Explicitly deferred — not resolvable by this document alone

Four decisions are already content-resolved or clearly scoped, but their
disposition is `Explicitly deferred`, not `Accepted` — each needs a named
owner and reopening gate, same as `PP-D22` (§3a), not a fifth "blocked"
category:

- **`PP-D09` — Reviews.** Owner: whoever ends up responsible for the
  canonical Review contract this document's `§7` already assumes will exist.
  Reopening gate: that Review contract's own acceptance — none exists
  anywhere in the repository yet.
- **`PP-D22` — Branch/brand hierarchy.** See §3a for the full disposition;
  restated here only so this section lists all four members of the bucket
  together.
- **`PP-D39` — Integration source-of-truth.** Owner: whoever owns `PP-D21`'s
  partnership decision (§4c). Reopening gate: a provider is selected —
  `PP-D39`'s conflict-resolution policy cannot be written before that.
- **`PP-D44` — Shared or separate Follow model.** Owner: a party spanning all
  three sibling documents (this one, `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`,
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md`). Reopening gate: the joint
  `FollowRelation`/`FollowRef` shape mismatch is reconciled — the two
  documents' proposed data shapes still do not match. Accepting `PP-D06`
  in §5 does not accept `PP-D44` — they are tracked separately in §20.1 of
  the parent spec for exactly this reason.

## 7. If this package is accepted

The parent spec's §21 Definition of Done recognizes exactly two states for
each proposition: `Accepted`, or `Explicitly deferred with an owner and a
reopening gate` (§20.1). v1.0 invented a third, informal state — `Accepted;
blocked pending <prerequisite>` — and v1.1/v1.2 still implied one blanket
verdict per `PP-D` ID even after §4c introduced real splits. This is the
final, exact partition of all 47 IDs into four groups — mechanically
verified to cover 1–47 with no overlap and no gap:

**Fully `Accepted`, no remainder — 25 decisions** (§3, §4, §4a, §4b):
`PP-D01`, `02`, `03`, `04`, `13`, `14`, `16`, `17`, `18`, `20`, `23`, `25`,
`27`, `28`, `30`, `31`, `32`, `33`, `34`, `35`, `36`, `40`, `43`, `45`, `47`.
`PP-D27` (§4a) and `PP-D32` (§4b) carry no open `Ask` as of this revision —
both are resolved and belong in this group outright, not a provisional one.

**`Accepted` core / `Explicitly deferred` remainder — 13 decisions** (§4c,
each with its own `Owner`/`Reopening gate`/`Target slice`): `PP-D05`, `08`,
`10`, `15`, `19`, `21`, `24`, `26`, `29`, `37`, `38`, `41`, `46`. Accepting
this package's recommendation resolves only the `Accepted core` half of
each — the `§20.1` row in the parent spec must show the split explicitly,
never a blanket `Accepted`.

**Fully `Explicitly deferred` — 4 decisions** (§3a, §6), each with its own
named owner and reopening gate: `PP-D09`, `22`, `39`, `44`.

**Needs your judgment before either disposition applies — 5 decisions**
(§5): `PP-D06`, `07`, `11`, `12`, `42`. These are not yet `Accepted` or
`Explicitly deferred` — they are business or planning calls this package
declines to default. Once you decide each, it moves to one of the two DoD
buckets above; none stays in limbo past that point.

```
25 (Accepted) + 13 (split) + 4 (Explicitly deferred) + 5 (needs judgment) = 47
```

This package still cannot satisfy DoD by itself even for the 25 fully
`Accepted` items: §20.1's `Owner` column is `TBD` throughout the parent
spec, and DoD's "accepted... with owners" wording is not met by a
recommendation alone — it needs a real name or role assigned to each
accepted decision, which remains this package's open request to you. None
of this authorizes implementation by itself (§1); it only clears the §21
gate this package exists to clear, and only once owners are actually
assigned.
