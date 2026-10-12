# BCK08-OD-04-A — Activity Catalog/Discover: bounded decision proposal

Date: 2026-10-11. Status: **Accepted Activity design; implementation in Review — local Emulator only**.
This document does not enable Activity in Catalog or accept the other nine
projection families. Authority: DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md §7.3,
BCK08-OD-04 and RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md v1.4.

## Current evidence and requested decision

`catalogEnabledTypes` contains only `event`; `CatalogEventItem.typeId` is the
literal `event`. The coverage matrix still lists OD-04 as open; D3.2 explicitly
excludes Activity Catalog/Details. Before this decision, no accepted Activity projection/Details
mapping was found in repository documentation. The owner accepted BCK08-OD-04-A on 2026-10-11 with «полностью согласен. выполняй». The BCK-20 implementation below now supplies the pinned local reader and artifact.

Accepted scope: enable only `activity` in the existing Emulator Catalog,
with a distinct `CatalogActivityItem` and Activity Details family. Keep the
Event shape and existing query/response envelopes compatible. The discriminant
is canonical `typeId: activity`; unknown types/revisions fail closed. Extend
existing Catalog/Discover adapters and Details routing, without a second index,
repository, dictionary, generic Event conversion or production binding.

## Public schema proposal

All fields below derive from the immutable BCK-07 published revision, plus its
current pointer facts. No draft, submission, moderation evidence or private
publisher fields enter public projection. Proposed schema ID:
`catalog-activity-projection-v1`; snapshot set schema must pin the union of
supported families, not mislabel Activity as `catalog-event-projection-v3`.

| Public field | Source and semantics | Surfaces |
|---|---|---|
| typeId, contentId, publishedRevisionId, sourcePointerRevision, marketId, publisherRef, referenceRevisions, publishedAtUtc | Existing Catalog common identity/freshness semantics | All |
| title, shortDescription, categoryId, subcategoryId | Explicit public Content fields | Feed, Map card, Search, Details |
| fullDescription | Public Content description | Details |
| point: latitude/longitude | Confirmed `location` pin only; no fake coordinates | Map, distance, Details |
| addressLine, accessNotes | Optional public location text; absent stays absent | Details |
| accessCaution: isInformal, note | Preserve approved caution wording; visible warning, no denial introduced | Details; Feed warning indicator |
| typicalDurationMinutes: min/max | Required positive whole range; never an Event start/end | Feed, Details; typed Search facets remain follow-up |
| suggestedGroupSize: min/max | Optional suggested range; never capacity/availability | Details |
| bestTime: timeOfDay/season | Optional enums from Activity source, including `any`; no invented instant, recurrence or opening hours | Feed, Details; typed Search facets remain follow-up |
| optionalContribution: kind/note/amountHint | Optional customary contribution, not a ticket/price. amountHint is integer minor units + currencyCode. Missing stays missing, never free/zero | Feed optional indicator; complete wording in Details |
| coverMediaId, galleryMediaIds | Allowlisted ready public Media refs minus pointer suppression facts | Feed, Map card, Details |
| criteria | Omitted in the first Activity Catalog version by explicit owner clarification on 2026-10-11; a later public allowlist is required | Deferred |
| searchText | Existing normalization over public title/summary/category and location text | Search |

Contribution does not populate Event `price`, paid/free filters, Booking CTA or
inventory. Activity remains evergreen: no occurrence/registration/Booking ref,
start time, live availability, capacity, route or transport fields. Query-time
Event time/price/availability predicates must explicitly exclude Activity where
inapplicable; `bestTime` is public typed data; a dedicated filter facet remains follow-up. No dummy Event fields.

`linkedPlaceId` remains denied at Content composition until the authoritative
Place existence/public eligibility lookup is available. This slice does not
enable Place Catalog or resolve that dependency by fixture. It covers standalone
confirmed-pin Activity only; no automatic draft rewriting.

## D2, replay/rebuild and rollback invariants

- Consume Content's existing `suppressedMediaIds` on every fact; do not infer
  restoration from the immutable body or from a later Media-ready result.
- Visibility/tombstone/withdraw/restrict/archive wins before type projection.
  Pointer revisions are monotonic; duplicate or older facts cannot resurrect
  media or visibility. A missing cover cannot be replaced by a suppressed gallery.
- Inactive rebuild and reconciliation use current authoritative pointer facts
  with suppression. Validate public allowlists and source revision hashes before
  atomic set activation. Rollback to a set must not revive an older suppression
  epoch; existing live reconciliation/visibility fences remain mandatory.
- Only explicit Content owner Activate may reconfirm restored media. Catalog
  never activates Content or rewrites immutable revisions.
- Preserve existing Catalog/Discover kill switches. Add default-off Activity
  type enablement for backend projection and mobile read composition; rollback
  disables both and retains history. Event behavior remains compatible.

## Dependencies and implementation continuation

BCK20-ACT-TX-01 supplies a deterministic local artifact derived from accepted Category System v1.4.3 and an exact-revision reader through the existing ReferenceDataPort. See ACTIVITY_BCK20_TAXONOMY_SLICE_SPEC.md and the current D3_ACTIVITY_CATALOG_2026-10-11.md evidence. The earlier missing-reader report describes the pre-implementation state.
Unknown/unavailable revision must refuse projection/read, not substitute the
five-entry test fixture. Test fixtures remain test evidence only.

BCK-22 authoritative informal-access threshold/nonblocking review signal stays
open. This slice neither turns its warning into a prohibition nor claims that
publication moderation implements that signal. Existing D2 residual windows,
Linux/device/cloud/production gates remain open.

## Implementation file plan after acceptance and dependency resolution

Backend: existing `modules/catalog/domain/catalog_item.ts`, `catalog_config.ts`,
`discover_query.ts`, `evaluation.ts`; `application/catalog_projector.ts`, `discover_query_handler.ts`,
`catalog_query_service.ts`, `catalog_sets.ts`, `catalog_reconciler.ts` and repository/port DTOs as required by the
Activity union; public Catalog schemas/fixtures in `packages/api_contracts`.
Mobile: existing `features/discover/data/models/catalog_wire_models.dart`,
`data/repositories/catalog_discover_repository.dart`, snapshot session, existing
Catalog query port/composition, Activity Details mapping and existing Details
route/page; no new Create form. Test/stand sources only for affected invariants.
Before implementation, resolve exact file names against the checkout and publish
an exact file plan. This is a bounded proposal, not implementation evidence.

## Required acceptance evidence for the future slice

1. Contract fixtures prove Activity discriminant, optional omission, units,
   enum boundaries and unknown/unavailable revision refusal; legacy Event
   fixtures remain readable. Public/private allowlist negative tests.
2. Projection tests prove standalone confirmed location, duration, bestTime,
   contribution and no invented Event/Booking facts.
3. D2 negative scenarios: suppressed cover/gallery before and after duplicate,
   out-of-order replay, inactive rebuild, reconciliation and set rollback;
   restored Media alone remains suppressed until owner Activate.
4. Real local stand reads Activity via Catalog Feed/Map/Search/Details, proves
   remote source instead of local fixture, and checks both kill switches.
5. Affected Catalog/Discover/Content gates and mobile mapping tests, full Flutter
   analyzer/test, boundary and diff checks on one source fingerprint. Reuse only
   unchanged earlier evidence with exact revision/log links.

**Owner decision recorded:** BCK08-OD-04-A accepted on 2026-10-11 by the explicit response «полностью согласен. выполняй» to the proposal acceptance question. This closes the Activity-only type/Details design decision; it does not accept other Catalog families, D3 publication slices or production. The executable BCK-20 dataset and pinned local reader are implemented for this bounded slice; publication owner acceptance and production remain separate gates. See [dependency verification](../evidence/backend/d3/D3_ACTIVITY_CATALOG_DEPENDENCY_2026-10-11.md).

Owner clarification 2026-10-11: first Activity Catalog version omits dynamic criteria. The owner requested execution after the separate BCK-20 slice preparation. Implementation derives the immutable taxonomy artifact mechanically from the accepted v1.4.3 semantic source; this does not accept publication slices or activate production MarketConfig. Current implementation evidence supersedes the earlier missing-reader report.
