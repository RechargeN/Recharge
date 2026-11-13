# S1-DISC-01 Spec

Status: Done (checkpoint fixed)  
Date: 2026-04-17

## Scope

This slice includes:

- discover feed (read-only);
- open details page from feed item;
- baseline UI states: loading, empty, error, success.

Out of scope:

- search/filter/map interactions;
- personalization ranking tuning;
- booking, moderation, recommendations logic.

## Implementation Baseline

1. Flow
   - `DiscoverHub` shows feed section.
   - Feed item tap opens `Details` route by `itemId`.

2. State model
   - `DiscoverFeedStatus`: `initial`, `loading`, `success`, `empty`, `error`.
   - Retry action available for `empty` and `error`.

3. Data source
   - Mock remote datasource for Sprint 1 read-only baseline.

## Routing Contract

- Feed is available in guest and authenticated modes.
- Details route: `/discover/details/:itemId`.

## Test Requirements

Required:

- unit test for feed controller states;
- widget test for feed rendering success state.

## Checkpoint Verification (2026-04-17)

- `dart analyze lib test integration_test` -> no issues
- `flutter test .\test\unit\discover_feed_controller_test.dart` -> passed (`+3`)
- `flutter test .\test\widget\discover_feed_section_test.dart` -> passed (`+1`)
- `flutter test` -> passed (`+8`)

