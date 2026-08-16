# RECHARGE — Profile Documents Index

Status: **Reference index — fully non-normative, no exceptions** (see §0)

Version: **1.4** (synchronizes Creator v1.9, Public Creator v1.9 and
Professional Page v2.28; replaces stale §0/§2/§7/§8 findings with the
current cross-document state; records the `PP-D16` and card-review-axis
corrections without changing this index's fully non-normative status)

Date: **2026-08-16**

Scope: **cross-document hygiene layer over the profile-surface documents;
documentation only**

## 0. Purpose, authority and non-normative boundary

`VIEWER_PROFILE_FUNCTIONAL_SPEC.md`, `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`,
`PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` and
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` are four Draft, audience-scoped
documents over the same canonical aggregates (`UserProfile`,
`CreatorVerification`, Create content, `ManagedPage`, Favorites, Scenario,
Follow, etc.). Each restates, in its own §0/§1.1/§19/§23/§25, the same kind
of cross-cutting fact — who owns which concern, which values an enum has,
which version of which sibling it was last checked against — independently
of the others. This index exists so those facts have one place to live
instead of four, and so open cross-document conflicts are tracked with an
explicit maturity level instead of being silently assumed resolved.

**This entire document is non-normative, without exception.** Nothing here
binds implementation, and nothing here outranks any sibling document's own
text, any Accepted ADR, or any Approved specification. Priority order for
all matters recorded by this index remains whatever the owning documents
establish; this index decides nothing — it records candidates, directions,
and open conflicts, and states plainly which of those it is doing in every
case, using §5's maturity ladder.

### 0.1 Three siblings, four siblings, or three-plus-a-peer?

| Document | How it currently describes the group |
|---|---|
| `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` | Explicitly states three personal-identity documents plus Professional Page as a `ManagedPage` peer; all four share one Draft conflict-precedence tier (§0) |
| `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | Uses the same three-plus-a-peer frame explicitly (§0) |
| `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | Uses the same three-plus-a-peer frame explicitly (§0) |
| `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` | §1.1 describes four audience-scoped surfaces, explicitly distinguishing the three personal-identity documents from this `ManagedPage` peer while keeping equal Draft precedence |

**Recommended frame:**

```text
Product/profile architecture:  3 personal-identity documents
                                (Viewer, Creator, Public Creator)
                                + 1 ManagedPage peer (Professional Page)
Conflict-precedence tier:      all 4 Draft documents on equal footing
```

**Adoption status:** adopted by all four documents. This remains descriptive
architecture hygiene, not an Accepted decision created by this index.

## 1. Document registry

| Document | Current version | Cited as compatible by others | Citation status |
|---|---|---|---|
| `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` | **v1.15** | CP/PCP/PP cite v1.15; VP's own header still cites CP v1.5, PCP v1.4 and PP v2.18 | Current as a cited dependency; its outbound snapshot is stale — see §7 |
| `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | **v1.9** | PCP/PP cite v1.9; VP cites v1.5 | v1.9 consumes accepted `PP-D16` without treating it as runtime authorization and refreshes its targeted sibling snapshot |
| `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | **v1.9** | CP/PP cite v1.9; VP cites v1.4 | v1.9 separates neutral pending review from effective enforcement so a report cannot weaken an existing restriction |
| `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` | **v2.28** | CP/PCP cite v2.28; VP cites v2.18 | v2.28 aligns `PP-D16`'s definition/§22.3 with its Accepted tracking row and refreshes the CP/PCP snapshot |
| `PROFESSIONAL_PAGE_SPEC_CHANGELOG.md` | — (history log, not versioned) | Not cited by version | n/a |
| `PROFESSIONAL_PAGE_DECISION_PACKAGE.md` | **v1.4** (as of 2026-08-16) | Not yet cited by any sibling document | Historical rationale record — 42 of 47 `PP-D` IDs are integrated into `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.28 itself; `PP-D06`/`07`/`11`/`12`/`42` remain open business/legal/planning calls that the package deliberately does not decide |

A version match in this table means only that the citing document's header
string is current — it does **not** mean the citing document has re-checked
the cited section for actual content compatibility.

## 2. Precedence order — target vs. actual

All four profile-surface documents converge on the same six-tier
model (Accepted ADR → Approved current-slice spec → `LAUNCH_STATUS.md` →
Accepted/Approved owning-aggregate spec or shared cross-product contract →
Draft profile-surface documents on equal footing → `VISION.md`/general
material). No open precedence-order migration remains. Future drift is a
documentation defect in the drifting Draft, not a rule this index may settle.

## 3. Ownership matrix

Two columns, kept strictly separate so the table cannot imply a Draft
document is an Accepted source of truth:

- **Accepted canonical source** — an ADR, an Approved specification;
  `None yet` if no such source exists for this concern; or `Not
  inventoried` if per-type/underlying sources may include Accepted ones
  this index has not audited one by one (a weaker, more honest claim than
  `None yet`, which asserts absence rather than absence-of-audit).
- **Draft-defining / surface owner** — which Draft document currently
  defines or presents this concern, regardless of whether an Accepted
  source exists above it.

| Concern | Accepted canonical source | Draft-defining / surface owner | Status |
|---|---|---|---|
| `AccountStatus` axis | None yet | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1 | Draft |
| `pendingSecurityVerification` overlay | None yet | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1 | Draft — see §6.2 |
| Baseline Public User Projection | None yet | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.2 | Draft |
| Block / Mute mechanics | None yet | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.3 | Draft ownership aligned across Viewer/Public Creator — see §5.4 |
| `CreatorVerification` state machine | `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md` | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §5.2 | Approved core / Draft surface |
| `PublisherRef` shape, default, non-rewrite rule | `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md` | Consumed, not redefined, by CP, PCP and PP — PP §3.3 itself restates the `{type: user \| page, id}` shape for its `type: page` variant. `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` is a **boundary consumer only**: it states explicitly and repeatedly (§3.1, §5.1) that no personal-library action requires a `PublisherRef`, and a personal Scenario acquires one only once explicitly published | Approved **shape** — see runtime-rollout row below for what is actually wired |
| `PublisherRef` runtime rollout (implementation status, not the shape's Approval) | n/a — implementation-status fact, source is `LAUNCH_STATUS.md`, not a spec | n/a | Per `docs/architecture/LAUNCH_STATUS.md` (`ECL-01`, `IDP-04A`): the shared `PublisherRef` **type** is consumed by **Place and Event**; full active-workspace default/non-rewrite coverage is confirmed only for **Event**; the remaining nine Create types (which still includes Place, for that fuller coverage) are pending under `IDP-04A` (status `Doing`). Do not collapse this into "Event only" — Place already consumes the shared type |
| Create-content lifecycle (per Create type) | `Not inventoried` — no single named specification; per-type sources may include Accepted ones this index has not audited | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` manages the personal-publisher projection | Mixed; see the `PublisherRef` runtime-rollout row above for the one part of this that is inventoried |
| Created-content list attribution | `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md` for the `PublisherRef` shape only; `Not inventoried` for the underlying per-type Create-aggregate sources | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` (private) / `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.1 (public) | Draft surfaces; same per-type caveat as above |
| `ManagedPage` entity, membership, lifecycle | `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md` | `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` | Approved core / Draft surface |
| `ManagedPage` public projection — exact field set | **None yet** — `IDENTITY_PUBLISHER_SLICE_SPEC.md` owns `ManagedPage` itself but does not define its exact public field set | `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §8.2 | Draft surface defines the field set; no Accepted source constrains it yet |
| Scenario collaboration roles (`ScenarioAccessGrant`) | `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1/§10.2 | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §5.2 and `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-AC-17` render it | Approved / Draft surfaces render it |
| Quick Plan collaboration (`relationship: owned \| invited`) | None yet (`VP-D02`, Quick-Plan-only) | `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2 | Open — still misattributed to Scenario in two other documents, see §8 |
| Public Creator card: visibility / moderation axes, field set | None yet | `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §3–§4 | Draft — internal defects noted in §8 |
| `UserProfile.displayName`/`avatar` moderation state for a verified Creator | None yet | Behavior specified by `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §16; no entity persists it — see §8 | Open — cross-document gap between `S2_EXP_01_PROFILE_SETTINGS_SPEC.md` (base `UserProfile` fields), Viewer and Creator Profile |
| Follow — base relationship/aggregate | None yet | n/a | Open, tracked in §5.1 |
| Follow — personal management surface | (as above) | Proposed: `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §12.4 | Candidate |
| Follow — display on a Creator's public card | (as above) | Proposed: `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4 | Candidate |
| Follow — display on a Professional Page | (as above) | Proposed: `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §12.2 | Candidate |

Rows above were checked against each document's own relationship-to-siblings
section; known exceptions are called out explicitly in the Status column
and detailed in §5 and §8.

## 4. Terminology disambiguation

- **`owner`** — page-team relationship (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`
  `ManagedPageMembership.relationship = owner`) vs. **Quick Plan**'s own
  `relationship: owned | invited` (`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §4.2)
  — not Scenario's.
- **Scenario collaboration vs. Quick Plan collaboration:**
  - **Scenario** (`PersonalScenarioRef.accessRole`) uses the Approved
    four-role model from `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1/§10.2
    — owner, editor, viewer, and the role that source's own table calls
    "unlisted viewer." Semantic role is Approved; its code-identifier
    rendering is a separate, open question (§6.1).
  - **Quick Plan** (`QuickPlanRef.relationship`) uses the separate,
    genuinely undecided `owned | invited` field; `VP-D02` scopes to Quick
    Plan only.
  - The earlier cross-document conflation is resolved — see §8.
- **`Follow`** — not yet a settled shared model; see §5.1.
- **`AccountStatus` casing** — `active`, `securityLocked`, `suspended`,
  `deletionPending`, `tombstoned`, camelCase. Distinct from
  `pendingSecurityVerification` — see §6.2.
- **`unlisted viewer` (Approved label) / `unlistedViewer` (identifier,
  `Direction` — not yet propagated or Approved) / wire value (undecided)**
  — see §6.1.
- **Professional Page `archived` vs. `tombstoned`** — related by a
  "layered on" design; wording clarity note, not a behavior defect — §8.

## 5. Open cross-document conflicts and proposed reconciliation

```text
Candidate    — one of several possible directions, not yet chosen
Direction    — chosen by the product owner as the one to pursue next
Propagated   — merged into the owning document(s)' own text
Accepted     — passed that document's own Approval gate
```

Nothing in this section reaches `Accepted` by virtue of appearing here.

### 5.1 Follow foundation (`PP-D44` / `VP-D12` / `PCP-D02`)

All three owning Drafts now frame this as the same **trilateral** decision:
`PP-D44`/`VP-D12`/`PCP-D02`. The remaining conflict is the data shape, not
the party count. The two proposed shapes are structurally
incompatible: `PP-D44`'s `FollowRelation` (`target: {type: user | page,
id}`, covering both a person and a page in one contract) versus `VP-D12`'s
`FollowRef` (`followedUserId` only, cannot represent following a page).

**Maturity differs by sub-question:**

| Sub-question | Maturity | What was chosen |
|---|---|---|
| Required parties | `Propagated` | Trilateral — VP, PP and PCP all required; present in all three decision trackers |
| Shared, discriminated-target approach (one contract for both person- and page-follow, vs. two separate models) | `Direction` | A single `target: {type: user \| page, id}`-discriminated shape is preferred over two independent contracts |
| Exact `FollowRelation` field list, status values, and lifecycle rules | `Candidate` / mostly `Open` | Only a sketch exists (below); self-follow, uniqueness, Block interaction, minors, deletion, consent/retention, idempotency, audit and the user/page lifecycle-sharing question are all unresolved |

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

**Provenance of the two `Direction` rows — self-contained and attributable,
but externally verifiable only through the session transcript, not
independently of it:** both were selected through an explicit multi-option
question exchange with the product owner (Follow party count, Follow
data-shape, and separately `unlistedViewer` casing in §6.1 — each with
named alternatives, "trilateral" / "bilateral" / "leave open" for the
first, specific shape options for the second; the product owner selected
"trilateral" and "`FollowRelation` (PP)" respectively). This is a recorded
selection event, not an inference by this index — but no ADR, issue, or
external decision-log entry exists beyond that session's own transcript.
The trilateral party-count direction has now been propagated into each
source document's own decision-tracking table. The preferred discriminated-
target shape remains only `Direction`, not `Accepted`; no source document
has adopted exact fields or lifecycle rules. The cleanest path remains a
dedicated shared-contract document (e.g. a future
`FOLLOW_RELATION_SPEC.md`, Draft then Approved) — recommended, not
created, by this index.

### 5.2 Precedence-order migration (Viewer Profile)

**Resolved.** Viewer Profile now uses the same six-tier order as the other
three documents (§2).

### 5.3 Sibling-count framing (three-plus-a-peer vs. flat four)

**Resolved.** All four documents now use the three personal-identity
documents plus one `ManagedPage` peer frame while retaining one equal-
footing Draft conflict-precedence tier (§0.1).

### 5.4 Block/Mute ownership attribution

**Resolved.** Both documents now state that Viewer Profile owns Block/Mute
mechanics and Public Creator Profile only consumes the result for card
rendering.

## 6. Shared enum / value registries

### 6.1 The "unlisted viewer" role — three distinct levels

`SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1 (Approved) names the fourth
Scenario collaboration role as prose in a table — "unlisted viewer" — with
no Dart-level enum declared anywhere in that file.

| Level | Value | Owner | Status |
|---|---|---|---|
| Semantic role | The fourth `ScenarioAccessGrant` role | `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1/§10.2 | Approved |
| Product / table label | "unlisted viewer" | `SCENARIO_CONNECTED_PLANNING_SPEC.md` §10.1 | Approved, unchanged |
| Code-style declaration identifier | `unlistedViewer` | Not formally declared in `SCENARIO_CONNECTED_PLANNING_SPEC.md` itself yet | `Direction` — selected by the product owner in the same exchange as Follow's two `Direction` items above (§5.1); not yet propagated into the owning Scenario contract, and not `Accepted` there |
| Wire value (API/schema) | undecided | Not yet defined | `Open` |

A role name in a descriptive table being human-readable is not a problem.
`VIEWER_PROFILE_FUNCTIONAL_SPEC.md` renders the role as `unlistedViewer` in
code-style contexts throughout and requires
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` `CP-AC-17` to match.
`CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §10 has its own code-style declaration
— `ScenarioCollaborationRole = owner | editor | viewer | unlisted viewer` —
mixing three single-token members with one two-word phrase; that internal
inconsistency, not a "canonical vs. wrong" claim (the Approved source never
declares a Dart-level enum), is the actual issue. Suggested ru UI label,
offered only as a suggestion: "Доступ по ссылке."

### 6.2 `AccountStatus` and `pendingSecurityVerification`

```text
AccountStatus = active | securityLocked | suspended | deletionPending | tombstoned
```

Owner: `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1. Verified identical, same
order, same casing, in every citing document.

```text
pendingSecurityVerification: bool
  — a separate, orthogonal session-security overlay, NOT a sixth
    AccountStatus value
  — set true the instant AccountStatus enters securityLocked; cleared only
    by completing the unlock flow; survives the securityLocked ->
    deletionPending transition
```

Owner: `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` §15.1.

## 7. Broken or stale citations between documents

| In document | Cites | As | Actual | Content delta re-verified? |
|---|---|---|---|---|
| `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` header | `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | v1.5 | v1.9 | No — outbound Viewer snapshot remains stale |
| `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` header | `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | v1.4 | v1.9 | No — outbound Viewer snapshot remains stale |
| `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` header | `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` | v2.18 | v2.28 | No — outbound Viewer snapshot remains stale |

Creator v1.9, Public Creator v1.9 and Professional Page v2.28 have mutually
current targeted snapshots. A version mismatch is a maintenance signal that
requires targeted re-verification when the citing document next changes; it
does not by itself prove content incompatibility.

### 7.1 Mechanical document defects (not cross-document citations)

None currently recorded. Add new mechanical findings here only after direct
verification against the live document.

## 8. Confirmed cross-document / intra-document content defects

**Confirmed defects (behavior- or content-affecting):**

1. **RESOLVED as of `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.4.**
   ~~`cityOptIn` removed from the entity but still required by an
   acceptance criterion, within the same document.~~ `PCP-AC-15` no longer
   lists `cityOptIn`.

2. **RESOLVED as of `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.4.**
   ~~Resolver and test-matrix disagree on a blocked viewer with a valid
   `unlisted` token, within the same document.~~ The test matrix now
   matches §3.6's `notFound` outcome.

3. **RESOLVED as of `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.5.**
   ~~Minor fail-closed rule stated in prose (§9), not encoded as a step in
   the resolver table (§3.6).~~ §3.6 now has an explicit minor-gate step
   (step 3) withholding the extended card unconditionally while explicitly
   deferring the baseline's exact content to the still-open `VP-D10` —
   `PCP-AC-13` and the test matrix were also corrected to stop asserting an
   unconditional baseline-only outcome ahead of that decision.

4. **RESOLVED.** ~~Scenario/Quick Plan conflation was live in Public Creator
   and Professional Page.~~ Public Creator v1.5 and Professional Page v2.16
   now distinguish Quick Plan's `owned | invited` relationship from the
   Approved Scenario `owner | editor | viewer | unlistedViewer` role model.

5. **PARTIALLY RESOLVED as of `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.4–v1.6.**
   `IdentityFieldModerationOverlay` (§16.1) now gives `displayName`/`avatar`
   a defined storage entity, separate from `CreatorProfileExtension`,
   scoped correctly to `VerifiedCreatorIdentity` accounts only. Still open,
   tracked as that document's own `CP-D19` (lifecycle: seeding, migration,
   atomicity, revision authority, avatar clearing,
   `expired`/`revoked` interaction) and `CP-D20` (cross-surface
   consistency — whether `VIEWER_PROFILE_FUNCTIONAL_SPEC.md`'s baseline
   projection also reads from this overlay, which that document has not
   yet adopted).

6. **RESOLVED as of `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9.**
   ~~`underReview`, `restricted` and `quarantined` were mutually exclusive
   values, so filing a report against an already restricted card could
   weaken enforcement and concurrent reports could overwrite each other.~~
   Review status and enforcement are now independent axes with server-only
   active review IDs; resolver, entity, UX, AC and tests agree.

7. **RESOLVED as of `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.28 and
   `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` v1.9.** ~~`PP-D16` was Accepted in
   the decision table but still described as open in its definition/§22.3,
   while Creator Profile correctly failed closed against the older prose.~~
   The owning spec now fixes move-only transfer and separate duplication;
   Creator consumes the accepted target without treating it as runtime
   authorization.

**Confirmed wording/clarity issues (intended meaning recoverable from
context; not behavior defects):**

6. **"Not `archived` or tombstoned" reads ambiguously as boolean logic.**
   `VIEWER_PROFILE_FUNCTIONAL_SPEC.md` and `CREATOR_PROFILE_FUNCTIONAL_SPEC.md`
   §22.4 both use the identical phrase "any Professional Page that is not
   `archived` or tombstoned." Read as `(not archived) or tombstoned` it
   inverts the intent; "deliberately not an enumerated lifecycle list"
   (stated immediately alongside it in both documents) makes the intended
   reading — neither `archived` nor `tombstoned` — clear. Identical, not
   contradictory, between the two documents by design; a clarity note.

7. **`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md`'s flat "suspended, archived or
   tombstoned" listings** don't assert mutual exclusivity merely by using
   `or`, and the document's own lifecycle model states a tombstoned page is
   "a tombstone layered on `archived`, not a new enum value" — related, not
   contradictory. Worth distinguishing `ManagedPage.lifecycle == archived`
   from the orthogonal deletion/tombstone marker in wording.

**Checked and narrowed or dismissed:**

- *`CardModerationRecord` missing* — false; fully defined in
  `PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` §4.2. Distinct entity from
  item 5 above; item 5 remains open.
- *`PCP-D06` encroaches on Scenario/Quick Plan's own content ownership* —
  not confirmed; `PCP-D06`'s defining prose (§7.2) correctly scopes it to
  "this card's Created-content list," but the decision's own catalog-entry
  wording (§17) drops that qualifier — a wording-precision gap within PCP
  itself, not a cross-document encroachment.
- *Block/Mute cycle unresolved* — false as of the current documents;
  functional ownership and citation direction are aligned (§5.4).

## 9. Maintenance notes (practical, not normative)

- when a sibling document's version bumps, update §1/§7 in the same
  change, and state explicitly whether the delta was re-verified for
  content, not only cited as a new number;
- when a sibling document's own ownership or terminology section changes,
  re-check §3/§4 rather than assuming this index still matches;
- treat any wording here that looks like "resolved," "canonical," or
  "superseded" outside an explicit `Accepted` maturity marker (§5) as a
  documentation bug in this index, not a real status;
- for implementation-status facts (what is actually wired, not what a spec
  approves), cite `docs/architecture/LAUNCH_STATUS.md` directly rather than
  a Draft document's paraphrase of it.

## 10. Reported, not independently verified

Empty. Add newly reported cross-document concerns here — with enough
citation to locate them — rather than asserting them directly in §3–§8
until checked against the source documents.

## 11. Revision history

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-08-12 | Initial release. |
| 1.1 | 2026-08-12 | §1 version registry updated (Creator v1.6, Public v1.5, Viewer v1.13, Professional Page v2.18, spot-verified not line-by-line); §8 items 1–3 marked resolved, item 4 marked partially resolved (Public's own side only), item 5 marked partially resolved (`IdentityFieldModerationOverlay` added; `CP-D19`/`CP-D20` remain open) — edited from the Creator Profile session; Viewer/Professional Page-side findings not independently re-verified. |
| 1.2 | 2026-08-16 | Registry refreshed to Viewer v1.15, Creator v1.8, Public Creator v1.8 and the then-current Professional Page v2.26/decision package v1.3 snapshot; content-level findings were deliberately not re-audited in that version-only pass. |
| 1.3 | 2026-08-16 | Professional Page registry advanced to v2.27 and decision package v1.4 after the main spec integrated 42 of 47 decisions; older §0/§2/§7/§8 findings remained explicitly unaudited. |
| 1.4 | 2026-08-16 | Synchronized Creator v1.9, Public Creator v1.9 and Professional Page v2.28; corrected the four-document framing, precedence status, outbound citation table and mechanical-defect list; marked the old Scenario/Quick Plan, card moderation-axis and `PP-D16` conflicts resolved while retaining `CP-D19`/`CP-D20` and Follow shape as open. |
