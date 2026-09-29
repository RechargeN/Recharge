# RECHARGE — Public Professional Page Functional Specification

Status: **Draft for product and architecture review**

Version: **1.3**

Date: **2026-08-16**

Scope: **the public-facing projection of a Professional Page — the public
identity, resolver, field contract, content projection and UX states — as a
presentation split of `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`; documentation
only**

## 0. Document authority and purpose

This document defines the **public projection** of a Professional Page:
when it exists at all (§2), exactly which fields it carries and under what
moderation rule (§3), how content and relations render (§4–§5), what a
Viewer can do on it (§6), and the UX states a design must cover (§7).

`ManagedPage` itself — its team, workspace, lifecycle, verification,
membership, capability and `PublisherRef` model, and every `PP-D`/`PP-AC`
decision governing them — remains owned entirely by
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`. This document introduces its own
`PPP-D` decisions (§13) and `PPP-AC` acceptance criteria (§10) **only** for
questions that are genuinely about public presentation and belong to
neither document yet; it never re-decides a `PP-D`, never redefines
`ManagedPage`, and never restates an existing `PP-AC` under a new number.

This document is not an Accepted ADR and does not authorize runtime,
backend, Firebase or production work. Before implementation, each delivery
slice still requires an Approved bounded slice specification, exactly as
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §0 already states.

### 0.1 Authority split with the parent document

Three explicit rules, not one blanket "the parent always wins":

1. **A conflict touching a `ManagedPage` invariant, `PP-D` decision,
   lifecycle, verification, membership, capability or `PublisherRef`**
   resolves in `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`'s favor. This
   document must be corrected to match, never the reverse.
2. **A question that is purely about public presentation** — field layout,
   CTA copy, section ordering, UX-state handling, the exact resolver logic
   consuming an already-Accepted state rule — is owned by this document.
   The parent document does not restate or override it.
3. **A conflict that is genuinely shared and neither of the above resolves
   cleanly** blocks implementation of the affected behavior. It is never
   auto-resolved by which document a reader opened first, and it is not
   silently assumed resolved by either document alone.

This mirrors `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §0 item 5's own
statement of the same split — that section is the controlling copy; this
one restates it here for a reader who opens this document first.

Canonical supporting source:

- `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.34 — owns `ManagedPage`, every
  `PP-D` decision cited below, and every invariant this document's rules
  derive from.

### 0.2 Normative language

`MUST`, `MUST NOT`, `SHOULD`, `MAY` and their Russian equivalents are
normative. `Target` describes intended full-release behavior. `Current` is
only a status snapshot and must be verified in `LAUNCH_STATUS.md` before
work.

## 1. Product definition

**Scope.** This document covers the public-facing projection of a
Professional Page **in public-view context, regardless of whether the
current Viewer is a page team member**. Public data is identical for every
Viewer who resolves it (§2); a team member's session does not change the
public payload in any way. A team member additionally MAY see separate
`Manage page` and `Edit page` affordances layered on top of the same public
view — §6.3 defines why they are two different checks, not one — determined
entirely by `canOpenPageWorkspace`/`canPerformPageAction`
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §3.1) and never themselves part of
the public projection this document defines.

The public Professional Page answers one question for whoever is looking:
**"What is this, and what can I do here?"** It is a safe, read-only
projection — never a second copy of `ManagedPage`'s authoritative state,
never a place where a Viewer mutates page data directly. Every action a
Viewer can take (§6) delegates to that action's own owning contract
(Follow, Block, Report, Save, Booking, content).

### 1.1 Relationship to sibling documents

This document is the public half of the Professional Page pair in the
six-document, three-pair profile-surface family
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §1.1 describes — it splits
that document's own "any other Viewer, about a page" audience out of "the
page's own team" audience, the same way
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` already splits "any other
Viewer, about a verified Creator" out of `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`'s
"the Creator, about themselves." The parallel is deliberate:

| Private/management view | Public view (this pattern) |
|---|---|
| `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` | `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` |
| `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` |
| `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` | `PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` (this document) |

**Verified-against snapshot.** Every citation below of
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` was checked directly against its
v2.34 text as of 2026-08-16. A later version of that document moving past
this pin does not retroactively make this document wrong, but does mean its
citations are unconfirmed against the newer text until the next
verification pass.

## 2. Public visibility resolver (`PPP-D01`)

Nothing in `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` previously defined *when*
a public page exists at all as one resolver — `PP-D02` (Accepted) fixes the
underlying rule (verified + active only, no `unlisted` in v1); this section
is the resolver consuming it:

```text
PublicManagedPageResolution(pageId | slug, viewer):

authenticated Viewer                                  (ADR 0015)
  AND page.verification == verified
  AND page.lifecycle == active
  AND no tombstone/deletion in effect
  AND no effective moderation restriction hiding the page
  => publicPage

otherwise
  => notFound
```

Rules that follow directly from this and from already-Accepted decisions,
stated explicitly so no implementation reinvents them differently:

- **Team membership never changes this resolution.** A team member with an
  otherwise-valid session resolving the *public* view gets exactly the same
  `publicPage`/`notFound` outcome as any other Viewer for the same page —
  per §1's scope rule. Reaching the *management* view is a fully separate
  check (`canOpenPageWorkspace`), evaluated independently, never inferred
  from a successful public resolution or vice versa.
- **`unlisted` does not exist in v1** — `PP-D02`'s own text is explicit
  about this; every non-`verified+active` combination resolves to the same
  `notFound`, not to a lesser-visibility state.
- **ID and slug resolve through the same function.** A slug is a display
  alias (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §22.4) over the same
  `pageId`-keyed resolution — it MUST NOT have its own, looser visibility
  rule.
- **Unavailable and non-existent return the identical safe state.** A
  `pageId`/slug that resolves to a real but non-public page (`suspended`,
  `tombstoned`, unverified, etc.) and a `pageId`/slug that does not exist at
  all both produce `notFound` with no distinguishing signal — this is
  deliberate enumeration resistance, the same discipline
  `PROFILE_DOCUMENTS_INDEX.md` records elsewhere in this document family
  for account-existence checks.
- **A `notFound` page does not retroactively hide its own published
  content.** An Event, Route or other aggregate this page published keeps
  following its own contract (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §22.2:
  "MUST NOT dictate the fate of already published content... each Create
  type keeps its own contract"). The page's own card becomes unreachable;
  content the page previously published is a separate resolution entirely,
  owned by that content's aggregate.

## 3. Public field contract (`PPP-D02`, Accepted — see §13)

`PublicManagedPageProjection` is the exact typed public payload — not a
`SHOULD include` list. It exists only once `PublicManagedPageResolution`
(§2) resolves `publicPage`; a `notFound` result carries no payload at all.
This payload is the **cacheable, viewer-independent** half of a public
response — §3.3 defines the separate, per-viewer half that is never cached
or asserted identical across Viewers.

```text
PublicManagedPageProjection {
  pageId,
  slug?,
  displayName,
  avatarMediaRef?,          # MediaRef, §3.4
  coverMediaRef?,           # MediaRef, §3.4
  shortDescription?,
  description?,
  serviceCategories[],      # PublicCategoryRef, §3.4
  customActivityLabel?,
  operatingArea?,
  verificationBadge,
  publicContacts[],         # PublicContactChannel, §3.4 — never a raw address
  externalLinks[],          # PublicExternalLink, §3.4
  relations[],              # PublicManagedPageRelation, §3.4
  contentSummary,           # PublicContentSummary, §3.4 — counts/availability, never raw lists
  publicRevision,           # opaque cache/ETag token — see note below
  schemaVersion
}
```

`publicRevision` is a deliberately **opaque** cache token, not
`ManagedPage.revision` republished — exposing the internal revision counter
would leak how often a page's authoritative state changes, which is not
public information. It changes whenever any field in this payload changes
and is otherwise meaningless to a client: equality comparison only, never
numeric ordering, arithmetic, sequencing or monotonicity assumptions. Cache
identity is `(pageId, requestedLocale, publicRevision, schemaVersion)`.

Per-field contract — source, requiredness, localization, moderation
behavior and fallback. "Canonical source" cites the `PP-D`/`PP-AC` this
field's *existence and semantics* already come from; this document decides
none of that itself, only how the field is packaged and rendered:

| Field | Canonical source | Required? | Localized? | Moderated? | Hidden when |
|---|---|---|---|---|---|
| `pageId` | `ManagedPage.id` — core, §4.1 | Yes | No | No | Never — the resolver's own key |
| `slug` | `ManagedPage.slug` — core, §4.1; rename/uniqueness rule §22.4 (`PP-D17`, Accepted) | No | No | No | Absent until assigned |
| `displayName` | `ManagedPage.displayName` — core, §4.1 | Yes | Per-locale (`PP-D23`, Accepted) | Yes — §3.1 (via `PP-D48`) | Never while `publicPage` resolves; a missing `defaultLocale` value blocks publication entirely (`PP-AC-77`), not just this field |
| `avatarMediaRef`/`coverMediaRef` | Media rights and lifecycle (§7's `Portfolio/media` row, `PP-D24` Accepted core) | No | n/a | Yes — §3.1 (via `PP-D48`); licensing per `PP-D24` — the exact media object schema itself is not yet defined anywhere in this document family, so `MediaRef` below is this document's own minimal shape, not a canonical one | Absent if never set |
| `description` | `ManagedPage.description` — **core, §4.1** (not the profile extension) | No | Per-locale | Yes — §3.1 (via `PP-D48`) | Absent if never set |
| `shortDescription` | `ManagedPageProfileExtension.shortDescription` — proposed, §4.2 | No | Per-locale | Yes — §3.1 (via `PP-D48`) | Absent if never set |
| `serviceCategories` | projected from `ManagedPage.serviceCategoryIds` — core, §4.1; adapter rule `PP-D01` (Accepted) | No | `PublicCategoryRef.label` localized via the Category System's own contract | Category System's own moderation, not re-defined here | Empty array if none assigned |
| `customActivityLabel` | §6 (`PP-D01`, Accepted) | No | User-entered, preserved in entry language (§6 there) | Yes — impersonation/abuse per §6 there | Absent if unset |
| `operatingArea` | `ManagedPageProfileExtension` (§4.2) | No | Display string, market-dependent | No | Absent if unset |
| `verificationBadge` | §5.2 (`PP-D02`'s own precondition) | Yes when `publicPage` resolves | No | No — a safe projection only, never evidence | Never, while `publicPage` resolves (it's the reason the page is public at all) |
| `publicContacts` | `ManagedPage.contactProjection` — core, §4.1 (which channels are exposable at all); reveal gating `PP-D05` Accepted core, §15.1 | No | Label text only | Anti-spam rate limit on **reveal**, per channel — see §3.2 for why the raw address is never in this payload | Contact-type-by-market rule Explicitly deferred to Privacy/Legal (`PP-D05`'s open remainder) — until resolved for a given market, that market's page omits that channel kind entirely rather than guessing |
| `externalLinks` | `ManagedPageProfileExtension.socialLinks` (§4.2) | No | No | Safe-URL validation is this document's own rule (`PPP-D02`) — the parent document does not yet define one | Absent if unset |
| `relations` | §4.4 (`PP-D47`, Accepted) | No | n/a | Relation-kind-specific moderation, not re-defined here | Empty array if none |
| `contentSummary` | §4 content projection (`PPP-D03`) | Yes (may be zero) | n/a | n/a | Never — a zero count is shown as zero (§4 below), never omitted |

### 3.1 Moderation of editable public fields

Reads, but does not define, `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §4.5's
`ManagedPageFieldModerationOverlay` (`PP-D48`, **Accepted**) — this
is a real persisted state with its own seeding, atomicity and revision
questions, not this document's presentation packaging, and this document
does not own its persistence lifecycle. The rule this document applies is:

- the public payload always serves the overlay's `lastApprovedValue` for a
  moderated field (`displayName`, `description`, `shortDescription`,
  `customActivityLabel`, media);
- if no value has ever been approved, the field is **absent**, not blank —
  an empty string and "no approved value yet" MUST NOT be conflated;
- a `pendingValue` or `rejectedValue` **never** enters the public payload,
  regardless of who is viewing, including the page's own team looking at
  the public view per §1's scope rule;
- a `clearedAtUtc` transition removes the field from the public payload
  entirely — distinct from an empty string, which this document never
  emits for a moderated field;
- a moderation restriction MUST NOT retroactively weaken an
  already-stricter state — e.g. a new report under review never causes a
  previously-hidden field to become visible, and never causes a
  currently-visible approved value to revert to a stale one.

This is deliberately the same shape
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9 already uses for its own
pending-review/effective-enforcement split (per that document's own
Revision History), so the two public surfaces do not diverge on moderation
semantics without a stated reason — but the underlying persisted state each
reads is a separate contract per surface (`PP-D48` here).

### 3.2 Safe contact reveal (closes a rate-limit bypass)

v1.1 put a raw `publicContacts[]` value — an actual email/phone/handle —
directly in the cacheable public payload. That defeats the anti-spam
reveal rate limit `PP-D05` already requires: once the client has the raw
value, a "rate limit" on revealing it again is meaningless. Corrected:

```text
PublicContactChannel {
  kind,                # e.g. phone | email | website | messagingHandle
  displayLabel?,        # a safe hint, e.g. "Email" — never the address itself
  revealActionRef       # opaque reference to a separate reveal command
}
```

The public payload (§3) carries `PublicContactChannel[]` only — never a raw
address. `revealActionRef` is not a bearer credential: it is an opaque,
short-lived, single-channel reference bound server-side to the authenticated
Viewer, exact `pageId`, channel kind, market policy and expiry. It rotates on
use or expiry and is never accepted for another Viewer/page/channel. A Viewer
requesting the actual value calls a separate rate-limited server command,
which returns a typed `revealed | rateLimited | expired | forbidden |
unavailable` result, enforces `PP-D05` and never logs the raw contact value.
This is `PPP-D02`'s own resolution (public-payload
packaging, §0.1 rule 2) — it does not change `PP-D05`'s own accepted
content (which channel kinds exist, that reveal is rate-limited), only
fixes how this document was packaging the result.

### 3.3 Per-viewer context — never part of the cached payload

Not everything a public page's UI needs is safe to cache or assert
identical across Viewers. `PublicManagedPageProjection` (§3) is the
cacheable half; this is the other half, resolved per request and never
cached across Viewers:

```text
PublicPageViewerContext {
  followState?,           # per PP-D06 / PP-D44 once Follow exists at all
  blockMuteState?,         # per §6.2
  canOpenPageWorkspace,    # PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md §3.1
  canPerformPageAction,    # same, exact-action-scoped — see §6.3's
                           #   Manage-vs-Edit split
  requestedLocale
}
```

A test or implementation MUST NOT assert that two different Viewers'
*entire* public-page response is identical — only that their
`PublicManagedPageProjection` is identical when `requestedLocale` matches
(§10, §11 correct this from v1.1's overclaim).

### 3.4 Nested types

Minimal shapes this document needs to render §3's payload — not canonical
schemas for their underlying concepts, which remain owned elsewhere (or, in
`MediaRef`'s case, remain genuinely undefined anywhere in this document
family yet):

```text
MediaRef {
  mediaId,
  altText?
}

PublicCategoryRef {
  categoryId,
  label                 # resolved via the Category System's own localization
}

PublicExternalLink {
  url,
  label?
}

PublicManagedPageRelation {
  relationKind,          # operatesPlace | branchOf | partnerOf | providerOf
  targetRef,              # {type: place | page | provider, id}
  verificationStatus      # verified | unconfirmed
}

PublicContentSummary {
  upcomingCount,
  ongoingCount,
  pastCount,
  timelessCount,
  relatedCount
}
```

### 3.5 Reserved extension boundary

`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §4.2 reserves
`ManagedPagePublicAttribute`/`ManagedPagePublicSection` as names for a
*possible* future bounded profile-builder extension — not implemented, not
part of `PublicManagedPageProjection` above. This document inherits that
reservation unchanged: no field here may be extended into a generic
`attributes`/`sectionData` map under any name before that extension is
separately Approved (`PP-AC-95`).

## 4. Public content projection (`PPP-D03`, Accepted — see §13)

### 4.1 Two unrelated sources — do not conflate them

v1.1 sourced "Related/co-hosted" content partly from `§4.4`
`ManagedPageRelation` — wrong. `ManagedPageRelation` is a **structural**
Page↔Place/Page/Provider relation (§5); it carries no content ID and cannot
resolve to a co-hosted Event, Route or any other content item. The two
content sections have two entirely separate, unrelated sources:

- **"Published by this page"** resolves strictly by
  `aggregate.publisherRef == {type: page, id: pageId}`
  (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §3.3, §9) — never by relation,
  never by category or brand-name similarity.
- **"Related / co-hosted"** resolves strictly from the specific *content
  aggregate's own* relation field — e.g. an Event's own `hostRef`/
  co-organizer list (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §9's
  aggregate-owned relations) — never from `§4.4`'s page-to-page/place/
  provider `ManagedPageRelation`, which has no content-list role at all and
  is used only for §5's entity cards.

A relation, of either kind, is never authority and never implies the
content was published by this page.

### 4.2 Cross-aggregate read model (`PPP-D05`, Accepted)

The ten Create types (Event, Route, Place, Scenario, and the rest) have
different repositories and different time semantics — there is no single
"owning aggregate query" this document can point to for a combined,
paginated public feed spanning all of them. v1.1 asserted both "no new
index/cache" and "query the owning aggregate" without resolving how those
combine. The accepted solution is a read-only
`PublicPageContentProjectionRepository`,
  indexed by `PublisherRef`, populated from each Create type's own
  authoritative write — a materialized read view, never itself
  authoritative, never consulted for anything but rendering this list.
  Each canonical aggregate remains the source of truth for its own item's
  state (availability, cancellation, etc.), re-checked at
  action/CTA-render time (§6.1), not trusted from the projection alone.
The repository stores only projection fields, namespaces every lookup by
the full discriminated `PublisherRef`, is rebuildable from canonical
aggregates and MUST NOT accept public-page writes as aggregate mutations.
The local/mock implementation may return an empty read view until a Create
type has an Approved publisher-projection adapter; it must never infer
ownership from names, categories or `ManagedPageRelation`.

### 4.3 Sorting and sectioning

Not every Create type has an Event-like `start`/`end` — Route, Place,
Collection/Guide and others do not. `ManagedPage.timezone` (§4.1 there)
governs *this page's* scheduling display, never a blanket timezone for
every content type's own data. Sections, each with its own cursor
(regardless of which §4.2 option is chosen):

- **Dated content** (Event, Bookable Session and any other type with an
  occurrence time) — sorted by occurrence start ascending for upcoming and
  ongoing, occurrence start descending for past, rendered
  in that specific item's own timezone, split into upcoming/ongoing/past;
- **Timeless content** (Route, Place reference, Collection/Guide and
  similar) — a separate section, sorted by `publishedAt` descending, never
  forced into the dated section's upcoming/ongoing/past framing;
- **Related/co-hosted content** (§4.1) — its own section and cursor,
  regardless of whether the underlying item is dated or timeless; dated
  related items use occurrence start and timeless related items use
  `publishedAt`, grouped in that order.

Every sort uses stable `contentId` ascending as the final tie-breaker. Each
section has its own opaque cursor encoding its section and last sort key; a
cursor is never reused across sections or locales.

Common rules across all three sections:

- cancelled, suspended or otherwise unavailable content follows its own
  aggregate's contract (§13.1 there for the honest-fallback pattern) — it
  is never silently dropped from a public list without a state label, and
  never presented as still bookable;
- stale or offline-cached content projections carry an explicit
  freshness/staleness label (§15.2 there) rather than presenting cached
  data as current;
- an empty section is hidden from the layout rather than rendered as a
  visible empty state with no content — the page-level empty state (§8)
  covers the all-sections-empty case;
- content whose owning aggregate is not yet ready (e.g. mid-migration, or a
  readiness gate not yet met) is excluded from the public projection
  entirely, not shown in a degraded form.

## 5. Relation display (`PPP-D04`, Accepted)

`§4.4`'s four v1 `relationKind` values render with distinct, explicit
presentation — a public reader MUST be able to tell what kind of
relationship they are looking at, not just that "a relationship exists":

| `relationKind` | Target type | Public rendering |
|---|---|---|
| `operatesPlace` | Place | Rendered as a linked venue/location card, distinct from the page's own identity header |
| `branchOf` | Page | Rendered as a linked sibling Professional Page, labeled as a branch/headquarters relationship, never merged into one identity |
| `partnerOf` | Page | Rendered as a linked sibling Professional Page, labeled as a partnership, never implying shared authority |
| `providerOf` | Provider | Rendered as a provider-brand association only — never exposes connector credentials or field authority (§4.4 there) |

Common rules:

- a `verified` relation renders normally; an `unconfirmed` relation renders
  with an explicit, neutral "unconfirmed" label, never hidden and never
  shown as equivalent to `verified` (`PP-AC-94`);
- a relation never grants or implies authority, management access or
  `PublisherRef` on the related entity — rendering a relation is purely
  descriptive;
- legacy `placeIds` (§4.1) and `§4.4` relations MUST NOT produce two
  visual copies of the same linked Place — if both exist for the same
  target, the relation-based entry (with its `relationKind` label) is
  the one rendered; the plain `placeIds` reference does not additionally
  appear as a second, unlabeled card for the same Place.

## 6. Viewer actions

The public projection never mutates `ManagedPage`. Every action below
delegates to its own owning contract — this document only says which
actions are relevant here and what they render as, never redefines how
they work:

| Action | Owning contract | Notes |
|---|---|---|
| Follow | `PP-D06` (Accepted core), `PP-D44` (blocked, trilateral) | Opt-in; shared-vs-personal-follow question stays with `PP-D44`, not resolved here |
| Contact | §3/§3.2 safe reveal | Rate-limited server-side reveal command, never a raw address in the cached payload; per-market legal gating per `PP-D05`'s remainder |
| Share | Platform share mechanism | No page-side state change |
| Report | `PP-D37` (Accepted core, `PP-AC-66`/`78`/`93`) | Never restricts the page's publication or visibility by itself, at any report volume — only an affirmative moderator decision does |
| Block | §6.2 (`PPP-D06`, Accepted) | Viewer-scoped; see §6.2 for the exact effect |
| Mute | §6.2 (`PPP-D06`, Accepted) | Viewer-scoped, weaker than Block — deprioritizes, never hides |
| Save | The target content's own save/Favorites contract | Per content type, not a page-level action |
| Register/Book | The target content's own owning contract (§13 there) | External handoff vs. internal Booking per that content's own readiness — see §6.1's CTA table |
| Open a related Place/Page | §5 relation rendering | Navigates to that entity's own public projection; grants nothing |
| Open a map/route | The target content's own contract, where supported | Never a page-level feature independent of specific content |
| `Manage page` (team members only) | `canOpenPageWorkspace` | See §6.3 — distinct from `Edit page` below |
| `Edit page` (team members with the capability only) | `canPerformPageAction` with a `manage_page`-class capability | See §6.3 |

### 6.1 Call-to-action by content contract

Illustrative, non-normative examples — each inherits the normative rule in
the final column and establishes no new requirement:

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

Unavailable or unknown capacity MUST NOT be presented as bookable.

### 6.2 Block and Mute against a Page

`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` is the canonical owner of Block/Mute
mechanics for a Viewer, and its own text (restated via
`PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md`) fixes the general shape: **Block
is bidirectional by default** for a person-to-person target — neither side
can view the other's card, follow, or initiate new contact. **Mute is
one-directional** — content stays visible but deprioritized for the muting
account only, and the muted account is never notified of either action.

A Page target is not fully symmetric with a person target — a page has no
personal account "browsing" the Viewer's own profile the way a blocked
person would — so the bidirectional half of that rule does not transfer
unchanged. Applying the same underlying principle
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` `PP-AC-66`'s "a Viewer's block/mute
is a personal, reversible relationship fact") to a page target specifically:

- **Block** removes that Viewer's own ability to resolve the page's
  `publicPage` view (a Viewer-scoped override on top of §2's resolver —
  the page still resolves `publicPage` for every other Viewer), removes any
  existing `followerUserId → target{type: page, id}` Follow relation, if
  that shared contract is implemented, and prevents a
  new Follow or Contact reveal from that Viewer while the Block stands. It
  never unpublishes the page's content and never changes the page's state
  for any other Viewer (`PP-AC-66`'s own guarantee) — this remains true and
  unaffected by the person-target Block rule's bidirectionality, which has
  no page-side counterpart to apply to.
- **Mute** does not change resolution or content visibility at all — the
  page still resolves normally and remains fully visible if the Viewer
  navigates to it directly. It suppresses that page's appearance in the
  muting Viewer's own Search/Recommendations/Notifications surfaces only.
  The page is never notified of a Mute, exactly as the person-target rule
  states.
- Report is a separate moderation submission (§6, `PP-D37`) — it is not a
  Block state and does not itself change what any other Viewer sees.
- **Unblock** is available from Settings → Blocked pages, is idempotent and
  restores only eligibility to resolve/interact; it never recreates a
  deleted Follow relation or contact state. Unmute is available from the
  same relationship-management surface and likewise restores no deleted
  state.

These page-target semantics are `PPP-D06` (Accepted). They do not alter the
person-target bidirectional rule owned by Viewer Profile and do not resolve
`PP-D44`'s still-deferred shared Follow lifecycle.

### 6.3 `Manage page` versus `Edit page`

v1.1 collapsed these into one affordance — wrong, because
`canOpenPageWorkspace` and `canPerformPageAction`
(`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §3.1) are deliberately different
checks:

- **`Manage page`** requires only `canOpenPageWorkspace` — active
  membership at its current revision and a compatible page lifecycle,
  **no capability**. A team member with an empty capability set still sees
  this affordance and can open the restricted management shell.
- **`Edit page`** requires `canPerformPageAction` with the specific
  `manage_page`-class capability. A team member who can open the shell but
  holds no such capability sees `Manage page` (leading to a safe restricted
  view) but never sees `Edit page`.

Neither affordance is part of `PublicManagedPageProjection` (§3) — both are
resolved from `PublicPageViewerContext` (§3.3) and rendered only for a
Viewer who is an active team member, per §1's scope rule.

## 7. What the public page never exposes

The public page MUST NOT expose (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
§8.2's former list, §15.1, Appendix B):

- membership lists or capabilities;
- identity or verification evidence, or reviewer/moderation notes;
- private contacts (only explicitly public ones, per §3 above);
- private content, drafts or archive not covered by an approved public
  content rule;
- audience segments or any historical cross-event audience;
- Booking participant data or internal analytics;
- any field the owning document's Appendix B lists as non-negotiable.

## 8. Required UX states

Every state below must be covered by a design/implementation slice for this
surface, not only the happy path:

- initial loading;
- session restoring (`authenticated Viewer` precondition from §2);
- public page unavailable / not found — the single safe state §2 defines
  for every non-public combination, indistinguishable from a truly
  non-existent `pageId`/slug;
- empty page (no descriptive fields set beyond the required minimum);
- no published content (all content sections empty, page-level empty
  state, not per-section);
- contact hidden or rate-limited (§3's contact-reveal gating);
- a field pending moderation (renders as absent or as the prior approved
  value, per §3.1 — never as the pending value);
- Viewer has Blocked this page (§6.2 — that Viewer's own `publicPage`
  resolution is overridden, no other Viewer is affected) or Muted it
  (§6.2 — resolution unaffected, only that Viewer's Search/Recommendations/
  Notifications suppress it);
- offline or stale content projection (explicit staleness label, §4.3);
- public visibility cache expired offline (§9's TTL rule — fails closed to
  `notFound`, distinct from a stale-but-labeled content card);
- an `unconfirmed` relation (§5 — distinct rendering from `verified`);
- Booking/availability unknown (§6.1's CTA table — never presented as
  bookable);
- an unsupported/gated module (e.g. Reviews before the canonical Review
  contract is approved) — absent, not a broken placeholder;
- partial localization (a secondary locale incomplete — labeled per
  `PP-AC-64`, never blocking, distinct from a missing `defaultLocale`
  value, which blocks the whole page per `PP-AC-77`);
- 360 dp minimum width;
- 150% text scale without clipped critical controls;
- keyboard/screen-reader semantics, status never communicated by color
  alone;
- a team member viewing their own page's public view — `PublicManagedPageProjection`
  (§3) identical to any other Viewer's at the same locale (§3.3), with
  `Manage page`/`Edit page` affordances (§6.3) resolved separately and
  layered on top per §1, never folded into the shared payload.

## 9. Security, privacy and offline

- Public projections exclude identity evidence, private contacts beyond
  §3's explicit list, team grants, private audience/Booking data and
  moderation notes (§7).
- The resolver (§2) and field contract (§3) apply identically whether the
  request originates from a deep link, search/Discover, or direct
  navigation — no separate, looser check for any entry point.
- **Public visibility cache TTL** — resolves a real tension v1.1 left
  unstated: this document both allows a stale cached page to render (with a
  label) and forbids offline state from fabricating a `publicPage`
  resolution the page no longer qualifies for. Both hold only with an
  explicit bound:
  - the resolver's `publicPage`/`notFound` outcome (§2) is cached with a
    short, bounded TTL;
  - once that TTL expires, an offline client fails closed to `notFound`
    rather than continuing to show a possibly-stale `publicPage` result;
  - a known revoke, suspension or tombstone event invalidates the cached
    resolution immediately wherever connectivity allows, ahead of the TTL;
  - **content cards** (§4) MAY retain a separately longer stale window,
    always with the explicit staleness label §4.3 already requires — this
    is a different, looser tolerance than the resolver's own TTL, because a
    stale *content* label is honest about itself in a way a stale
    `publicPage`/`notFound` boolean is not.
  - the exact TTL duration is an implementation-slice parameter, not fixed
    by this document.
- Logs/analytics use opaque IDs and stable reason codes, consistent with
  `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §15.1.

## 10. Acceptance criteria

- **`PPP-AC-01`:** A page with `verification != verified` or
  `lifecycle != active` resolves `notFound` for every Viewer, including
  the page's own team members viewing the public surface, with no
  distinguishing signal from a non-existent `pageId`/slug.
- **`PPP-AC-02`:** `pageId`-based and slug-based lookups for the same page
  produce identical resolution results at every point in time.
- **`PPP-AC-03`:** A field with no approved value renders as absent, never
  as an empty string; a pending or rejected edit value never appears in the
  public payload for any Viewer.
- **`PPP-AC-04`:** A moderation action never causes an already-visible
  approved value to revert, and never causes an already-hidden field to
  become visible as a side effect of an unrelated review.
- **`PPP-AC-05`:** Content attributed to this page via a `PP-D47` relation
  never appears under "Published by this page"; only exact `PublisherRef`
  match does.
- **`PPP-AC-06`:** An `unconfirmed` relation is visually distinguishable
  from a `verified` one in every rendering surface that shows relations.
- **`PPP-AC-07`:** A page or Place already linked via legacy `placeIds`
  and also via a `PP-D47` relation renders exactly one card for that
  target, not two.
- **`PPP-AC-08`:** No content list item is presented with a bookable CTA
  when the owning aggregate's availability is unknown or stale.
- **`PPP-AC-09`:** A Viewer's Block of a page overrides `publicPage`
  resolution to `notFound` for that Viewer only, and removes the existing
  `Viewer → Page` Follow relation if that contract is live; a Mute never
  changes resolution, only that Viewer's own Search/Recommendations/
  Notifications; neither changes any other Viewer's resolution or
  experience. Unblock/unmute are idempotent and never recreate a deleted
  Follow relation.
- **`PPP-AC-10`:** Reaching `canOpenPageWorkspace` for a page never alters
  what that same actor's `PublicManagedPageProjection` request for the same
  page returns; `Manage page` and `Edit page` resolve independently of each
  other and of the projection.
- **`PPP-AC-11`:** The public payload (§3) never contains a raw contact
  address — only a `PublicContactChannel` with a `revealActionRef`; the
  actual value is returned only by the separate reveal command. The ref is
  auth/page/channel/expiry-bound, cannot be replayed as a bearer credential,
  and the command enforces `PP-D05` without logging the raw value.
- **`PPP-AC-12`:** A dated content item never sorts into the timeless
  section and vice versa; a related/co-hosted item never appears under
  "Published by this page" regardless of any `§4.4` relation between the
  two pages.
- **`PPP-AC-13`:** After the public-visibility cache TTL expires without
  connectivity, an offline client resolves `notFound`, never a
  previously-cached `publicPage` result.
- **`PPP-AC-14`:** `serviceCategories` contains complete
  `PublicCategoryRef` objects, `contentSummary.timelessCount` is always
  present, cache identity includes locale, and `publicRevision` is used only
  for equality — never parsed or compared numerically.
- **`PPP-AC-15`:** Each content section has an independent opaque cursor and
  deterministic final `contentId` tie-breaker; a cursor from another section
  or locale fails closed rather than changing the result order.

## 11. Required test matrix

- resolver: every `(verification, lifecycle)` combination against §2's
  rule, including the boundary cases `pending`/`rejected` and
  `suspended`/`archived`/`tombstoned`, each producing `notFound`;
- resolver: `pageId` and slug lookups for the same page, before and after
  a rename, produce consistent results;
- resolver: an actual non-existent `pageId`/slug and a real-but-hidden page
  are response-indistinguishable;
- field contract: each moderated field's pending/rejected/approved/absent
  states, verified against §3.1's rule set;
- field contract: `defaultLocale` missing blocks the whole page; a
  secondary locale incomplete only labels that locale, never blocks;
- content projection: "Published by this page" resolves from `PublisherRef`
  only; "Related/co-hosted" resolves from the content aggregate's own
  relation field only; neither ever pulls from `§4.4`'s
  `ManagedPageRelation` (`PPP-AC-12`);
- content projection: dated vs. timeless vs. related sectioning, exact sort
  keys, `contentId` tie-breakers and independent locale-bound cursors,
  verified against mixed-type content (§4.3, `PPP-AC-15`);
  pagination cursor stability across a page with content additions between
  requests;
- contact safety: the public payload never carries a raw address
  (`PPP-AC-11`); the reveal command enforces `PP-D05` independently of
  page-load frequency and rejects cross-viewer/page/channel reuse, expiry
  and replay without logging the raw value;
- relation display: all four `relationKind` values render distinctly;
  `unconfirmed` vs. `verified` distinguishable; no duplicate card for a
  target linked by both `placeIds` and a relation;
- actions: Report produces no page-wide visibility change at any volume;
  Block overrides resolution to `notFound` for the blocking Viewer only and
  removes the existing Viewer→Page Follow if present; Mute changes only
  Search/Recommendations/Notifications for the muting Viewer, never
  resolution; unblock/unmute never recreate deleted state;
- team-member parity: an authenticated team member's `PublicManagedPageProjection`
  request for their own page, at a matched `requestedLocale`, is identical
  to a non-team Viewer's — never asserted for the full response, since
  `PublicPageViewerContext` (§3.3) legitimately differs; `Manage page`/
  `Edit page` verified present or absent per §6.3's exact capability rule,
  not as one combined affordance;
- offline: resolver TTL expiry fails closed to `notFound` (`PPP-AC-13`); a
  known revoke/suspend/tombstone invalidates the cache ahead of TTL when
  connectivity allows; a stale content card retains its own longer window
  with a label, never silently extended to cover the resolver's own result;
- accessibility: 360 dp, 150% text scale, keyboard/screen-reader semantics,
  non-color status, across every §8 state.

## 12. Delivery roadmap

| Slice | Scope | Class | Key dependency |
|---|---|---|---|
| PPP-01 Public resolver and field contract | §2 resolver, §3 field contract and moderation | Release foundation | Decisions Accepted; bounded local/mock implementation is `PUBLIC_PROFESSIONAL_PAGE_LOCAL_SLICE_SPEC.md`; production identity/moderation remains separately gated |
| PPP-02 Content and relation projection | §4 content projection, §5 relation display | Release foundation | All-ten `PublisherRef` migration (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §0.2); `PP-D47` accepted; per-type projection adapters approved |
| PPP-03 Viewer actions and CTA | §6 actions, §6.1 CTA table, §6.2 Block/Mute, §6.3 Manage/Edit split | Release foundation | Follow remains gated on `PP-D44`; Booking on ECL-03 runtime; contact/report/block/mute runtime each require their own Approved implementation slice |
| PPP-04 Accessibility and localization proof | §8 UX states, 360 dp/150%/screen-reader | Release foundation | Repository localization/accessibility infrastructure |

## 13. Decisions required before implementation

The product owner confirmed `PPP-D01`–`PPP-D06` for the target product on
2026-08-16. Acceptance fixes product semantics but does not authorize
production backend/Firebase work; delivery still follows §12.

| Decision | Status | Owner | Gate |
|---|---|---|---|
| `PPP-D01` — Public visibility resolver | **Accepted** | Product/Architecture | Production verification/lifecycle authority remains required |
| `PPP-D02` — Public field contract and moderation | **Accepted** | Product + Trust & Safety | Parent `PP-D48` is Accepted; production moderation adapters remain gated |
| `PPP-D03` — Content projection mechanics | **Accepted** | Product/Architecture | Per-type adapters remain gated |
| `PPP-D04` — Relation display | **Accepted** | Product | Runtime relation adapters remain gated |
| `PPP-D05` — Cross-aggregate content read model | **Accepted** | Product/Architecture | Shared read-only projection repository selected in §4.2 |
| `PPP-D06` — Page-target Block/Mute semantics | **Accepted** | Product + Viewer/Profile | §6.2 fixes one-way page-target behavior; `PP-D44` Follow lifecycle remains separate |

1. **`PPP-D01` — Public visibility resolver:** §2 defines the fail-closed
   resolver consuming `PP-D02`.
2. **`PPP-D02` — Public field contract and moderation:** §3/§3.1 fix the
   typed payload and the accepted `PP-D48` projection rule.
3. **`PPP-D03` — Content projection mechanics:** §4.3 fixes sorting,
   pagination-cursor and empty-section handling for whichever read model
   `PPP-D05` selects.
4. **`PPP-D04` — Relation display:** §5 fixes per-`relationKind` rendering
   and the `verified`/`unconfirmed` distinction.
5. **`PPP-D05` — Cross-aggregate content read model:** §4.2 selects the
   shared, read-only, rebuildable `PublicPageContentProjectionRepository`.
6. **`PPP-D06` — Page-target Block/Mute:** §6.2 fixes Viewer-scoped Block,
   one-way Mute, relationship restoration and the exact Follow interaction.

## 14. Definition of Done

This target specification has dispositions for `PPP-D01`–`PPP-D06`, and
the parent has Accepted `PP-D02`, `PP-D47` and `PP-D48` (v2.34). It remains
Draft because approval of a target functional specification and production
delivery approval are separate gates; each roadmap slice still needs its
own Approved bounded specification and evidence.

Public Professional Page is production Done only when:

1. the resolver (§2) is implemented against production `verification`/
   `lifecycle` state, not local/mock fixtures;
2. the field contract (§3) round-trips through the shared media and
   category adapters without a generic-JSON fallback;
3. `§10`'s acceptance criteria and `§11`'s test matrix are green;
4. `LAUNCH_STATUS.md` records the exact evidence;
5. no local/mock fixture or UI preview is represented as a production
   public resolution.

## Revision History

| Version | Summary |
|---|---|
| 1.0 | Initial split-out from `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §8.2 and Appendix A.1/A.2 (v2.30). No content changed in the move — later found to be exactly the problem: a relocation, not a functional specification. |
| 1.1 | External review found the split direction correct but the result incomplete — no resolver, no typed field contract, no moderation rule, wrong content-projection cross-reference (§17 does not define a "Content / Created surface concept"; corrected to §8.1/§9), missing relation-display detail, missing several already-Accepted user actions (Report, Block, Save, Manage page), missing UX states, and no own `PPP-D`/`PPP-AC`/test matrix/DoD — making this a reference excerpt rather than a standalone specification. All fixed: added §2 `PublicManagedPageResolution` (`PPP-D01`) consuming the already-Accepted `PP-D02`; added the typed `PublicManagedPageProjection` field contract and moderation rule (§3, `PPP-D02`); corrected the content-projection cross-reference and added sorting/pagination/empty-section/staleness rules (§4, `PPP-D03`); added per-`relationKind` display rules (§5, `PPP-D04`); added the full action set and its CTA table (§6); added a complete UX-state list (§8); added §10 acceptance criteria, §11 test matrix, §12 roadmap and §14 DoD. Corrected §1's scope to make clear team members also see the public view — the public payload never differs by membership, only the `Manage page` affordance layers on top. Corrected §0's authority split from "the parent always wins" to the three explicit rules the parent's own §0 item 5 states (aggregate invariant wins / pure-presentation question is owned here / genuinely shared unresolved conflict blocks). Refreshed the version pin to the parent's v2.32. Also corrected the stale `PP-D01`-is-open framing the old UI inventory carried over from before that decision's acceptance, and added an explicit `PP-D24` media-rights cross-reference for avatar/cover fields (§3) the old inventory list did not carry. `PP-D07` (Communications) has no natural place in this document — it governs the page's own outbound messages to its audience, not a Viewer-facing public-page action — so it is deliberately not cross-referenced here. |
| 1.2 | A second external review, verified point by point before acting: (1) §3's `publicContacts[]` put a raw address directly in the cached payload, defeating `PP-D05`'s reveal rate limit — replaced with `PublicContactChannel{kind, displayLabel?, revealActionRef}` (§3.2); the raw value now comes only from a separate rate-limited reveal command. (2) §3.1's `lastApprovedPublicValue` was presentation packaging for a *new persisted state* this document had no authority to define — added `ManagedPageFieldModerationOverlay` and `PP-D48` (Open) to the parent document (v2.33 §4.5); this document's §3.1 now only reads that overlay's result, and `PPP-D02` is formally blocked on `PP-D48`. (3) Nested types were undefined and two field-source citations were wrong: `description` is core `ManagedPage` (§4.1 there), not the profile extension — only `shortDescription` is; `serviceCategoryRefs` renamed to `serviceCategoryIds` to match the parent's actual field name; added minimal `MediaRef`/`PublicCategoryRef`/`PublicExternalLink`/`PublicManagedPageRelation`/`PublicContentSummary` shapes (§3.4); `revision` replaced with an opaque `publicRevision` token so internal change frequency isn't leaked. (4) §4 asserted both "no new index" and "query the owning aggregate" for a ten-type combined feed with no single owning aggregate to query — added §4.2's `PublicPageContentProjectionRepository` read-model question as new `PPP-D05` (Open, genuinely undecided between a shared read index and per-type sections). (5) A uniform start/end sort cannot apply to Route/Place/Collection, which have no occurrence time — split into dated/timeless/related sections, each its own cursor (§4.3). (6) §4 wrongly sourced "Related/co-hosted" content partly from `§4.4` `ManagedPageRelation`, which carries no content ID at all — corrected to source strictly from the content aggregate's own relation field (e.g. an Event's `hostRef`); `ManagedPageRelation` is now stated as used only for §5's entity cards (§4.1). (7) The test matrix asserted a full-response byte-identical guarantee across Viewers, which locale, Follow state, Block/Mute state and capability make impossible — split `PublicManagedPageProjection` (cacheable, asserted identical only at matched locale) from a new `PublicPageViewerContext` (§3.3, per-viewer, never cached or compared). (8) `Manage page`/`Edit page` were one combined affordance — split: `Manage page` needs only `canOpenPageWorkspace`, `Edit page` needs `canPerformPageAction` with a `manage_page`-class capability (§6.3). (9) The offline rule was self-contradictory (stale pages allowed to render, offline forbidden from fabricating visibility) with no bound connecting them — added an explicit public-visibility-cache TTL, fail-closed offline after expiry, immediate invalidation on a known revoke/suspend/tombstone, and a separately-longer labeled staleness window for content cards only (§9). (10) Block/Mute had no defined effect — read `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s canonical bidirectional-Block/one-directional-Mute rule (via the newly-discovered sibling `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md`) and applied it to a page target, flagging explicitly that a page has no symmetric "view of the Viewer" to lose, so the applied version is this document's own reading, not an assumed identical transfer (§6.2). Also fixed: `§13`'s decision table replaced "Accepted by virtue of" self-assertions with a real `Proposed`/`Open`/`Owner`/`Gate` table — none of `PPP-D01`–`PPP-D05` are actually Accepted yet; `§0`'s own cross-reference to where decisions/AC live corrected from "§9–§10" to "§13, §10". Refreshed the version pin to the parent's v2.33 throughout (except this table's own historical 1.1 entry, left as written). Noted for an accurate count only, not tracked as a sibling: the wider ecosystem is six profile-surface documents as of this revision, `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` having split its own `PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` independently of this work. Mechanical verification: `PPP-D01`–`05` and `PPP-AC-01`–`13` each present exactly once, no gaps; every real `PP-D`/`PP-AC` citation re-checked directly against the parent's actual text; 0 CR bytes; every `§` reference resolves to this document's own or the parent's real headings. |
| 1.3 | Product-owner confirmation completed the target contract. `PPP-D01`–`PPP-D06` are Accepted; `PP-D48` is consumed from parent v2.34; the shared read-only `PublicPageContentProjectionRepository` is selected. Corrected category refs, timeless count, locale-aware opaque revision caching, stable section sort/cursors, non-bearer contact reveal, and one-way page-target Block/Mute with explicit unblock. Added `PPP-AC-14`/`15`, updated tests/roadmap/DoD, and kept runtime authorization in the separate bounded local/mock slice rather than presenting this Draft as production authority. |
