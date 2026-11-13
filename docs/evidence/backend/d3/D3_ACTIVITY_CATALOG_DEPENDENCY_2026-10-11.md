# Activity Catalog: accepted decision and implementation prerequisite

Date: 2026-10-11. Checkout: C:/Users/User/.claude/worktrees/recharge-d3-2.
HEAD: b1e678a23a4db584e496a9d44593fbcf86c45dc0; existing working-tree implementation preserved. This report is documentation verification, not a runtime gate or owner acceptance of D3 publication slices.

The owner explicitly accepted BCK08-OD-04-A with «полностью согласен. выполняй». The bounded schema, Activity Details family, D2 invariants and default-off Emulator scope are recorded in the decision document. Other families and production remain outside scope.

## Verified prerequisite

REFERENCE_DATA_INTERNAL_SOURCE_RECORDS.md §3.6 binds SRCREC-CATEGORY-143-001 to Category System v1.4.3 and normalized-LF semantic source SHA-256 5dfe5347363eeb7d72933812424f22667e730a6edfb16aeb7c79fbeb8ef259f9. Its explicit state is “accepted semantic source; executable dataset absent”. This source hash is not an executable dataset hash.

modules/reference_data/domain/repositories.ts exposes only MarketConfig publication, reading and activation-pointer operations. MarketConfig taxonomyRevisionRef is a reference, not a dataset reader.

modules/content/application/ports/reference_data_port.ts resolves references and validation lookups by marketId, typeId and nowUtc. It has no input for the immutable published revision's pinned taxonomy revision, no immutable dataset read result and no public-criterion allowlist. It cannot supply accepted historical semantics for Catalog replay.

The existing Emulator Activity taxonomy explicitly identifies itself as test-only-tx-activity-1, a five-entry fixture. It cannot supply accepted BCK-20 runtime evidence. No fixture was promoted and no draft rewritten.

## Concrete dependency through existing BCK-20 boundary

1. An executable immutable Category System dataset with accepted revision identity, dataset content hash and provenance bound to the semantic source. It must represent Activity applicability, required criteria and public criterion allowlists.
2. The BCK-20-owned contract for reading exactly the taxonomy revision pinned by published Content, with explicit unknown/unavailable outcomes; extend the existing boundary rather than creating another dictionary or silently resolving latest.
3. The reader adapter and environment composition providing the accepted artifact through the existing reference-data port. The synthetic resolver cannot establish immutable replay/rebuild semantics.

These are dependencies, not invented interfaces. No method name or wire shape is prescribed without the owning BCK-20 contract. Acceptance does not authorize production MarketConfig activation.

## Execution and evidence

Only the decision document, LAUNCH_STATUS Activity row and this report changed in this continuation. The accepted proposal places implementation after acceptance AND dependency resolution. Dependent Catalog/Discover implementation remains gated; Activity remains disabled and Event-only behavior is unchanged.

Documentation checks: direct inspection and git diff --check; runtime tests not repeated for documentation-only changes. Earlier D3.7 evidence retains its original fingerprint and is not relabelled. No commit, merge or deployment performed.

Rollback: revert these documentation edits only; runtime and immutable revisions remain untouched.


Continuation: dependency state and implementation evidence are superseded by [D3_ACTIVITY_CATALOG_2026-10-11.md](D3_ACTIVITY_CATALOG_2026-10-11.md). This report retains its original source fingerprint and historical results.
