# D3.8 Activity Catalog/Discover — bounded implementation review

Date: 2026-10-11. Status: **Accepted by owner — bounded D3.8 local/Emulator slice**. Owner acceptance recorded on 2026-10-11 from the explicit response «принимаю» to this review result. No commit, push, merge, cloud deployment or production activation performed.

Checkout: C:/Users/User/.claude/worktrees/recharge-d3-2, detached HEAD **b1e678a23a4db584e496a9d44593fbcf86c45dc0** plus preserved WIP. Unified final source fingerprint **51a55dd34b12027e15f1ec22de76d85bf94da05d629d7eb750e09e18e8e2e0ce**, abbreviated **b1e678a + wt:51a55dd34b12**. [Source manifest](D3_ACTIVITY_CATALOG_SOURCE_2026-10-11.json) records 100 modified/untracked source files, including earlier authorized work; normalized LF hashes exclude evidence files. HEAD alone does not contain this implementation. Prior reports retain their earlier fingerprints and are historical, not evidence for the current runtime.

## Owner decisions and final scope

BCK08-OD-04-A Activity-only type/Details design was explicitly accepted. After preparation of the separate BCK-20 prerequisite the owner instructed execution. The owner explicitly confirmed first Catalog version **without dynamic criteria**. Category/profile fields are used for applicability and required criteria, not exposed as arbitrary public values.

Activity now uses one mechanically derived immutable BCK-20 artifact through additive readTaxonomyRevision on the existing ReferenceDataPort. Activity consumers refuse absent capability explicitly; existing Event-only providers remain compatible. Exact pinned revision only, no latest or fixture fallback:

`taxonomy-1.4.3-sha256:d5d4472629d52b8f3db883d9a449bcbfd5fa18e5f87a6d6aa26ae5b98168c822`

Canonical source: accepted Category System v1.4.3, SRCREC-CATEGORY-143-001; document LF SHA256 `5dfe5347363eeb7d72933812424f22667e730a6edfb16aeb7c79fbeb8ef259f9`. Artifact contains 28 categories, 530 subcategories and 22 profiles. --check verifies artifact bytes, bundled runtime mirror and manifest; reader verifies content hash and returns deep-frozen data. [Parity](ACTIVITY_TAXONOMY_PARITY_2026-10-11.json): no Activity applicability/profile/required-field differences. One unrelated other_event full-type membership difference is retained as debt. Minimal five-entry fixture has no runtime consumer; drafts and immutable revisions are not rewritten. Synthetic market/localization and Place references retain their existing Emulator-only status.

CatalogActivityItem is a distinct public family: confirmed standalone location, duration range, optional group, bestTime, access caution, optional contribution and ready unsuppressed media. It contains no Event time/occurrence/price/Booking facts, arbitrary criteria or private authoring evidence. Amount hint is positive integer minor units plus currency; missing or valid empty contribution stays absent, never free/zero. Source body hash and taxonomy applicability/required criteria are checked. Old fixture taxonomy cannot be silently relabelled.

The existing Catalog index/repository/projector/snapshot/set lifecycle and mobile Catalog gateway/repository/Details renderer are extended. Mobile nullable time/price honestly represent evergreen Activity; existing date/price filters exclude inapplicable items, and favorites retain absent time/price through persistence. Details uses the listing snapshot and refuses a changed Activity revision until refresh. No separate Create form or controller lifecycle is introduced.

## Acceptance evidence

| Check | Result | Evidence |
|---|---|---|
| Backend TypeScript build | PASS before every live run | stand gate invokes tsc before start; final unit gate compiled the same runtime |
| Backend unit/contract + reference-data unit/contract/integration/reconciliation/security | **762/762**, no skip/fail; 4.657 s | d3-8-logs/recharge-d3-8-backend-all-final.log |
| Existing Activity enablement integration | **9/9**; 1.843 s | d3-8-logs/recharge-d3-8-activity-integration-final.log |
| Emulator Content/Media, including existing Event Catalog and new Activity Catalog | **64/64**, 13 invocations; **170.308 s**, timeout **330 s** | d3-8-logs/content-media.log and summary |
| Emulator Place/Activity | **29/29**, 5 invocations; **169.624 s**, timeout **300 s** | d3-8-logs/place-activity.log and summary |
| New Activity Catalog live scenario | **1/1**, 9.279 s within Content/Media group | projection, Feed/Search/Map/Details, D2, replay/rebuild/rollback/restore/Activate/withdraw |
| Final D3.8 mobile stand gate | **1/1**, **21 s**, test timeout **180 s**, command timeout **240 s**, exit 0 | d3-8-logs/recharge-d3-8-stand-current.log; runId c6a9d9e3-0c84-45d7-8e14-0c1c81b09967; verified stop |
| Final full Flutter suite | **1427 passed / 31 skipped**, 3:03, exit 0 | d3-8-logs/recharge-d3-8-mobile-all-final.log |
| Focused mobile Catalog/favorites | **11/11** | d3-8-logs/recharge-d3-8-mobile-focused-final.log |
| Full mobile analyzer | **0 issues**, 9.8 s | d3-8-logs/recharge-d3-8-mobile-analyze-final.log |
| Backend ESLint | PASS, exit 0 | d3-8-logs/recharge-d3-8-lint-final.log |
| Boundary | **0 violations**, 71 existing suppressions; no new/stale/expired | d3-8-logs/recharge-d3-8-boundary-final.log |
| Runner regression | **6/6**; all original 40 invocations retained, new Activity Catalog makes 41; failure/timeout propagation and serial execution checked | node --test apps/backend/scripts/run-emulator-test-groups.test.mjs |
| Taxonomy reproducibility/integrity | --check PASS; schema + exact unknown/unavailable/corrupt tests PASS | final contract/reference-data suite |
| Diff and source stability | git diff --check PASS, untracked whitespace check PASS, staging empty; final fingerprint unchanged | source manifest |

[Log hash index](D3_ACTIVITY_CATALOG_LOGS_2026-10-11.json). Logs are retained locally in d3-8-logs; repository ignore policy may exclude .log files from a future commit. They must be carried with the evidence package when publishing a review.

The final stand uses real Auth/Session/Content/Catalog calls, a Content-published Activity and current mobile Catalog transport for Feed/Search/Map/Details, plus the existing Details renderer. It is a **Windows PC host test against local Emulator**, not device, cloud, production or byte-delivery evidence. Existing fake stand Media scanner/processor remain unchanged. Two earlier harness attempts failed (fake-clock I/O and mocked HTTP 400); they were corrected with runAsync and the existing live integration binding. Those attempts are diagnostic logs, not green evidence. The final current-source run passed and stopped all verified stand processes.

D2 evidence: unit projection tests cover cover/gallery suppression without replacement; the real Activity gallery restriction survives duplicate and stale replay, inactive rebuild, atomic activation, rollback and Media restore. Only explicit owner Content Activate restores that media. Current tombstone/suppression fences also apply to snapshot reads. Withdraw removes the item. Backend and mobile Activity switches refuse reads when disabled; absent taxonomy reader returns explicit unavailable. Existing negative linked Place tests prove submit refusal, publish refusal for an earlier approved submission, and refusal to activate old/hidden immutable revisions without mutating pointer/revisions/effects. Activation validation was already present and was not reimplemented.

Content/Media group preceded only erased TypeScript assertion cleanup and the empty-contribution compatibility correction; the unchanged live suppression paths reuse that evidence. The final corrected projection is covered by the final unit/contract suite and the repeated final Activity stand. No runtime build ran during a live Emulator process.

## Mandatory gates and intentionally unrepeated scope

Catalog public wire, snapshots, projector and mobile nullable time/price changed: existing Event Catalog Emulator regression, full mobile suite/analyzer, schema, boundary and diff gates were mandatory and passed. Activity reference resolver changed: reference-data and Activity integration plus Place/Activity Emulator gates were mandatory and passed. D2 propagation/rebuild paths were exercised by the new live Activity scenario and existing Content/Media group. No Firestore/rules/identity/session/Booking ledger/reference-data persistence adapters changed semantically; platform/Booking/rules-reference Emulator groups and unrelated complete stand gates are not repeated. No claim that this pass reran the full 41-invocation Emulator suite. D1 binary transformation, Linux, device and production gates are outside this bounded read slice; their prior limitations remain.

## Files and rollback

Backend changes: modules/catalog domain/application/infrastructure, existing Content reference_data_port and Emulator reference composition; new reference_data taxonomy domain/reader/generated mirror; build-taxonomy-dataset.mjs, stand-d3-8-gate.mjs, runner's additional existing-style task, Catalog schemas/fixtures and focused tests. Mobile changes: existing Catalog composition/wire/repository, new ActivityCatalogFacts, shared Discover/Favorites nullable time/price compatibility and existing renderer/widgets; focused mapping, persistence and live stand tests. Product/amendment/launch documents record Review and exact debt. Earlier authoring/controller/gateway changes from passes 1–7 are preserved, not newly implemented by pass 8. Formatting-only tracked reference_data/Catalog files have no semantic diff.

Both backend `RECHARGE_TEST_ACTIVITY_CATALOG` and mobile `--dart-define=RECHARGE_TEST_ACTIVITY_CATALOG` default off. Mobile also needs existing RECHARGE_TEST_DISCOVER_CATALOG, non-release, testBackend and loopback demo-recharge guards. Rollback: disable both Activity switches. Do not rewrite immutable history. After re-enable, use reconcile/rebuild and atomic activation for sets that previously consumed type_disabled effects; receipt deduplication is preserved. Taxonomy-only rollback returns the previous Emulator composition, retaining honest old-revision refusal.

## Remaining debt

- Public dynamic criteria require an explicit typed public allowlist; deferred by owner.
- Dedicated duration/bestTime filters are not implemented. These fields are public facts and shown in Details; text/geo Search works. Event time/price predicates are not repurposed.
- Linked Place authority/Catalog eligibility, BCK-22 authoritative informal-access threshold/review signal and remaining Catalog families remain open.
- Canonical other_event all-ten membership differs from mobile declared subset outside Activity; no cross-type migration in this slice.
- Old drafts and test-only published taxonomy revisions need explicit user revision workflows; no automatic migration. Only one canonical taxonomy revision is currently bundled; unknown historical revisions explicitly fail.
- Synthetic local market/localization/Place references, existing Catalog limits/ranking/availability and D2 residual windows remain.
- Publication owner acceptance, device/Linux/cloud/production integration and production BCK-20 delivery/storage remain separate gates.

Recommendation: accept **only this standalone Activity Catalog/Discover local slice** after owner review of this evidence. This report does not exercise owner acceptance authority.

## Owner acceptance — 2026-10-11

The owner explicitly accepted this bounded D3.8 local/Emulator slice with «принимаю». Acceptance applies to HEAD b1e678a23a4db584e496a9d44593fbcf86c45dc0 plus source fingerprint 51a55dd34b12027e15f1ec22de76d85bf94da05d629d7eb750e09e18e8e2e0ce, including the first version without dynamic criteria and the remaining debt listed above. The preceding recommendation records the review outcome before this owner decision. This acceptance does not accept D3.1/D3.2 publication slices, authorize merging or production, or close device/Linux/cloud gates. This evidence-only update does not change the verified source fingerprint.
