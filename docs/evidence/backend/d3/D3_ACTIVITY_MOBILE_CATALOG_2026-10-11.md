# Activity passes 7–8 — review and transfer record

Date: 2026-10-11. Environment: Windows host, loopback demo-recharge Emulator.
Owner acceptance remains open. No commit, push, merge, deployment or production
binding was performed. Previous passes' WIP was preserved.

## Result

**Pass 7:** recommend acceptance of the bounded Emulator implementation; owner acceptance is not declared. Implemented in the existing default-off Activity publication flow.
The owner can explicitly Activate the current immutable published revision and
Edit it in the existing Create form. Draft-only mode saves locally and returns
instead of invoking the separate local/mock publication action. A subsequent
server Save increments the mutable draft revision under the same Content ID;
Submit creates a new review, and Publish switches the pointer after approval.
Published version ID and draft revision/editing state are shown separately.

Activate uses the existing backend command and existing composition validation
unchanged. Before sending, the local journal stores target revision and expected
pointer revision. Lost response/restart replays the same payload/idempotency key;
a definitive conflict is shown without automatic pointer-fence retry. Existing
client environment guards and server capability/Page/moderation/media guards
remain authoritative. Additive journal fields read old entries unchanged.

Create's pending local work is flushed before replacing its cached controller.
If its current draft differs, the publication controller refuses switching the
binding rather than overwriting it. A hash of the saved local body prevents
Submit of unsaved edits; changed photo bindings follow existing upload recovery.
The old immutable revision is inspected by a read-only Emulator admin test
fixture, never by application runtime or production credentials.

**Pass 8:** concrete OD-04 proposal prepared, dependent runtime deliberately not
started. The current spec requires an accepted public projection for every
enabled type; repository OD-04 remains open and Catalog enables only Event.
The proposal selects a distinct Activity projection/Details family, confirmed
location, evergreen duration/bestTime, customary contribution (not ticket price),
public allowlists, D2 suppression and replay/rebuild/rollback fences. It excludes
linked Place, Event/Booking facts and production. The required owner decision is
[ACTIVITY_CATALOG_DISCOVER_OD04_PROPOSAL.md](../../../product/ACTIVITY_CATALOG_DISCOVER_OD04_PROPOSAL.md).

## Revision and scope

HEAD: `b1e678a23a4db584e496a9d44593fbcf86c45dc0` (unchanged).
Final normalized source/document/test fingerprint:
`b1e678a23a4db584e496a9d44593fbcf86c45dc0+wt:7e0dcfbd3228`.
42 dirty source/document/test paths, excluding `docs/evidence/`; these include
35 pre-existing paths from passes 3/5/6. There are no staged changes.
The manifest is D3_ACTIVITY_MOBILE_CATALOG_SOURCE_2026-10-11.json in this folder.

Changed in passes 7–8 (15 paths; overlapping earlier WIP preserved):

- Existing Activity publication controller; shared Functions gateway and its
  optional activation capability interface; Activity journal record DTO.
- Existing Activity publication section/panel, Create page and Activity block.
- Existing controller/gateway unit tests and both Activity stand test files.
- Activity D3.2 amendment, LAUNCH_STATUS (still Review), OD-04 proposal.

Backend source/tests/scripts/contracts are byte-identical after normalization to
pass 6's verified `...+wt:734abeb388d7`. No backend lifecycle fix was reimplemented,
no Catalog source changed, and no taxonomy fixture was promoted to accepted data.

## Gate/result/log/revision table

Evidence root: `C:/Users/User/AppData/Local/Temp/recharge-d3-7-20261011/`.

| Gate | Result | Evidence and applicability |
|---|---|---|
| Backend build before live stand | Passed | build.log; pinned Node 22.23.2; no build while Emulator was live |
| Focused controller/gateway | 21/21 passed | focused.log; lost Activate response/restart, conflict, closed guard, unsaved-body refusal and exact wire payload; also covered by final full suite |
| Real stand controller | 4/4 passed | Successful controller segment at start of stand-affected.log; new edit cycle survives restart, same Content ID/new draft revision, fresh review, new published ID and unchanged old immutable data |
| Real stand UI | 1/1 passed | stand-ui-final.log; current CreatePage/ActivityCreateBlock, hide/Activate, title edit, draft-only Save & return, submit/staff review/publish |
| Base + Activity stand invariants / verified stop | Passed | End of stand-ui-final.log; verified seed invariants, verified activity invariants, stopped fd28e6d0-a6fd-4b12-846c-eac9512bb954; wrapper exit 0 |
| Full Flutter analyze, apps/mobile | 0 issues | analyze-mobile.log |
| Full Flutter test, apps/mobile | 1425 passed / 30 existing skips / 0 failures | flutter-full.log; existing stand skips remain explicit; live Activity controller/UI evidence is above |
| Boundary | 0 violations; 71/71 prior suppressions | boundary.log; no new/stale/expired exceptions |
| Tracked + untracked diff checks | Passed | diff-check.log |
| Source before/after | Identical; final fingerprint 7e0dcfbd3228 | before-final.json, after-final.json; evidence reports excluded from hash |

Scope-aware reuse: after the controller stand passed, only its unrelated app
panel, UI test navigation selector and documentation were finalized. Controller,
gateway, journal DTO, backend runtime and its controller stand assertions stayed
unchanged. Only the UI gate was repeated; final full Flutter compilation/tests
cover the final source. Accepted-type backend negative linked Place scenarios
(submit, previously approved publish, old revision Activate) reuse pass 6's
29/29 affected Emulator gate. The 965/965 backend non-Emulator and remaining
Emulator groups likewise stay valid for unchanged backend files. Their exact
revisions/logs are in D3_ACTIVITY_FOLLOWUP_2026-10-11.md; no fresh full Emulator
run is claimed for this mobile-only change.

The initial full D3.2 wrapper completed clean/resume/repeat seed digest assertions
but exited 1 at a then-unprivileged immutable-history REST test. This is not
labelled a successful full wrapper. Affected controller and UI gates were run
separately with verified stops. Diagnostic failures (wrong installed Java path,
REST Rules refusal, missing UI selector and accumulated Session rate limit) are
excluded from positive gates. Exact locked Java 21.0.12+8 was located; the UI
repeat used fresh synthetic stand data. No rate-limit or Rules policy was relaxed.
Root-level Flutter analysis also included intentionally invalid boundary fixtures
and Firebase templates in node_modules; only the mandated apps/mobile scope is
used as the final analyzer gate. No unrelated files were fixed.

## Remaining debt / owner decisions

1. Accept or amend BCK08-OD-04-A before Activity Catalog/Discover implementation.
2. BCK-20 accepted immutable taxonomy dataset/revision/hash/provenance and reader
   adapter through the existing ReferenceDataPort remain absent. Current runtime
   taxonomy is still the explicit test-only Activity subset; unknown references
   fail closed. No automatic legacy-draft rewrite.
3. Authoritative linked Place existence/eligibility lookup remains absent; any
   linkedPlaceId is refused by Emulator composition, including Activate targets.
4. BCK-22 server informal-access count/nonblocking post-review signal remains
   absent. Approved soft warning is not converted into a publication prohibition.
5. D2 residual windows, real D1 Activity variant-byte stand verification, Linux,
   physical device, cloud and production evidence remain outside this pass.
6. D3.1/D3.2 owner acceptance remains an owner decision; these changes do not
   declare either slice Done. Catalog still returns type_disabled for Activity.

Rollback pass 7: hide Activate/Edit actions (or disable the existing Activity test
entry); normal Create mode remains compatible. Immutable revisions and the
backend lifecycle do not change. The optional journal fields can remain stored.
Rollback future pass 8: disable Activity Catalog/Discover type flags; preserve
history and suppression fences. There is currently no Activity Catalog runtime
change to roll back.


Continuation: dependency state and implementation evidence are superseded by [D3_ACTIVITY_CATALOG_2026-10-11.md](D3_ACTIVITY_CATALOG_2026-10-11.md). This report retains its original source fingerprint and historical results.
