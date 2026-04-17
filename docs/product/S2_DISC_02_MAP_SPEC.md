# S2-DISC-02 Map Spec

Status: Done (checkpoint fixed)  
Date: 2026-04-18

## Approved Decisions

1. SDK: `google_maps_flutter`.
2. Geocoding: one provider for `city/address -> lat/lng`, fallback later.
3. Default center: `last selected center`, else `Rezekne`.
4. Radius:
   - default `5km`,
   - min `1km`,
   - max `200km`,
   - unlimited mode supported.
5. Interaction model:
   - camera move updates draft area (UI),
   - full reload only by `Search this area`.
6. Clustering:
   - dense mode when `>40` points in viewport,
   - raw marker cap `120`.
7. Sorting: `geo + freshness`.
8. Preview CTA:
   - `Open details`,
   - `Save`,
   - `Open list`.
9. Empty suggestions baseline:
   - increase radius,
   - adjust budget,
   - change time/date.
10. Permission UX:
   - manual area available,
   - `Open settings` action available.
11. Unified contract:
   - one `DiscoverQuery` for A/B/C/D,
   - owner: discover application layer.
12. Cache:
   - last query/center/radius persisted locally,
   - map/data cache TTL target `5 min`.
13. Performance DoD:
   - interaction < `150ms`,
   - filter apply < `300ms`,
   - no visible jank on average device.

## Current Implementation Scope

- `DiscoverQuery` contract and serialization.
- Unified feed pipeline:
  - global filters,
  - geo filter,
  - scoring,
  - consistent output for map/list/count.
- Map page:
  - search/category/free controls,
  - draft area + `Search this area`,
  - radius + unlimited mode,
  - marker preview card,
  - list-sync CTA.
- Results list page synced with same controller state/query.

## Checkpoint Verification (2026-04-18)

- `dart analyze lib test integration_test` -> no issues
- `flutter test .\test\unit\discover_feed_controller_test.dart` -> passed (`+4`)
- `flutter test .\test\widget\discover_feed_section_test.dart` -> passed (`+1`)
- `flutter test` -> passed (`+9`)
