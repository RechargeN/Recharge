# IDP/M2 integration — CP4, 2026-11-20

Status: verified local cleanup checkpoint; owner acceptance separate.
Base checkpoint: `45eda2d6` (CP3 analyze/full 2713 pass, 83 skip, boundary/diff 0).
Combined base `78d6a386` includes merged PR #12 and #13; original PR heads and
WIP safety tags remain unchanged. No main/foreign branch rewrite or push.

## Removal order and proof

1. Compatibility tree passed the complete CP3 gates with all nine public
   wrappers, private LocalDate alias and forwarding exports retained.
2. Read-only `audit_m2_references.py --label cp4-compatibility-before-migration`:
   1372 Dart files; zero public wrapper consumers, 41 forwarding dependencies;
   alias still used; combined-tree ancestry true; zero-reference proof false.
3. Remaining production/test/integration-test imports migrated; UUID/ULID
   implementation imports explicitly use `show`, interface imports use shared.
   Private alias callers migrated. `--label cp4-zero-before-removal` then proved
   zero public/private wrapper consumers and zero forwarding reliance **while
   definitions/files still existed**. Fingerprint and every directive/definition
   are in `outputs/M2-DE-2026-11-19/`.
4. Typed MarketConfig clients migrated; unused heuristic registry lookup and
   legacy constructor removed separately from required persisted-data readers.
   90 obsolete active-config named arguments were removed at codec/datasource
   callers before their four receiving API parameter/field sets were removed.
   Recorded restore APIs now cannot receive active configuration at all.
5. Exact old files/source preimages were archived with SHA256 verification to
   `C:/Users/User/Desktop/мусор на проверку/IDP-M2-2026-11-20-CP4-45eda2d6`:
   **22 verified entries, seven moved forwarder files, fifteen source copies**.
   No physical delete command was used. Archive plan/receipt are attached.
6. Final text/token audit: 1366 files, zero consumers/forwarding dependencies,
   zero retained obsolete definitions or private aliases. The +1 verification
   Dart script and seven moved files explain 1372 → 1366. Legacy data codecs,
   UUID/ULID implementation and feature-specific GTFS time remain.

### Corrected MarketConfig getter proof

The initial text-only receiver list missed two `market.currencyCode/timezoneId`
references in a typed `for-in` localization test. Analyze correctly failed.
All five getters were restored **before** correcting those callers. The initial
Market getter claim is marked invalid/superseded, never used as final evidence.
`audit_m2_market_references.dart` then resolved 1365 source units plus the
excluded declaration file: zero references and zero unresolved units. A two-case
canary proves inferred-local and typed-for-in receivers are detected; unresolved
members are also detected via their receiver type. The valid resolved proof,
source fingerprint and retained-getter marker were saved **before** removing
getters again. This was a tooling defect in the first static check, not flaky
Flutter behavior. No checkpoint with broken getter callers was committed.

## Kept compatibility

MoneyLegacyAdapter still reads historical decimal numbers and integer Money
objects with explicit recorded currency. Create/templates retain versioned data
reads and fail closed without overwriting corrupt values. Legacy Event/Session
slots, Scenario manual snapshots/future fields, Visit v2 owner-scoped records and
necessary Class compatibility remain. Removing unused declarations does not
change their wire keys or schema versions; no storage migration was executed.
MarketConfig still supplies independent MarketRef/LocaleTag/CurrencyCode/IANA
values; Riga/legacy Rezekne registry entries remain explicit, not enabled-market
grants. The obsolete city-name resolver had no readers and was removed.

## Gates

- Reference tool self-test: pass (comments, strings, conditional directives,
  exports, definitions, private alias, integration-test scope).
- Resolved Market proof: 1365 units, canary 2, consumer refs 0, unresolved 0,
  exit 0 (`CP4-market-final-zero-before-removal`).
- `flutter analyze --no-pub`: no issues, exit 0 (`CP4-analyze-final`).
- Focused Market/legacy/templates/Money/Geo/ID/localization: 42 pass, exit 0.
- Full `flutter test --no-pub --reporter expanded`: 2713 pass, 83 existing
  skips, zero failed, exit 0 (`CP4-flutter-full.log/.exit`).
- Read-only boundary: 710 scanned files, 69/71 exceptions, zero violations /
  stale / expired, exit 0 (`CP4-boundary.log/.exit`).
- `git diff --check`: exit 0.

Source-only formatting was limited to changed existing Dart files. Generated
boundary inventory and exception registry are untouched pending the single CP5
regeneration. Protected Event/Booking/router/auth files did not change in CP4.

## Per-removal rollback

`CP4-removal-rollback-matrix.json` lists every public wrapper, private alias,
forwarding file/export, Market API member and removed context API, with proof,
archive path, removal commit and coherent rollback command. All preimages also
exist at CP3 `45eda2d6`. Revert the whole CP4 implementation commit to restore a
compiling compatibility tree; do not restore one complete old codec file while
keeping callers that use its new signature. Run full gates after rollback.

| Removed item | File | Proof |
|---|---|---|
| ActivityContributionAmountDraft | `apps/mobile/lib/features/create/domain/entities/activity_draft_data.dart` | cp4-zero-before-removal-complete-references.json |
| EventMoneyDraft | `apps/mobile/lib/features/create/domain/entities/event_draft_data.dart` | cp4-zero-before-removal-complete-references.json |
| RentalMoneyDraft | `apps/mobile/lib/features/create/domain/entities/rental_draft_data.dart` | cp4-zero-before-removal-complete-references.json |
| ScenarioMoneyDraft | `apps/mobile/lib/features/create/domain/entities/scenario_budget_draft.dart` | cp4-zero-before-removal-complete-references.json |
| ScenarioLocalDateDraft | `apps/mobile/lib/features/create/domain/entities/scenario_item_draft.dart` | cp4-zero-before-removal-complete-references.json |
| ScenarioGeoPointDraft | `apps/mobile/lib/features/create/domain/entities/scenario_item_draft.dart` | cp4-zero-before-removal-complete-references.json |
| ScenarioTransitLocalDate | `apps/mobile/lib/features/create/domain/entities/scenario_transit_schedule.dart` | cp4-zero-before-removal-complete-references.json |
| SessionMoneyDraft | `apps/mobile/lib/features/create/domain/entities/session_price_disclosure.dart` | cp4-zero-before-removal-complete-references.json |
| SessionLocalDate | `apps/mobile/lib/features/create/domain/entities/session_schedule.dart` | cp4-zero-before-removal-complete-references.json |
| _LocalDate | `apps/mobile/lib/features/create/domain/usecases/materialize_event_schedule_usecase.dart` | cp4-zero-before-removal-complete-references.json |
| forwarding file | `apps/mobile/lib/core/geo/geo_bounds.dart` | cp4-zero-before-removal-complete-references.json |
| forwarding file | `apps/mobile/lib/core/geo/geo_distance.dart` | cp4-zero-before-removal-complete-references.json |
| forwarding file | `apps/mobile/lib/core/geo/geo_point.dart` | cp4-zero-before-removal-complete-references.json |
| forwarding file | `apps/mobile/lib/core/geo/geometry_encoding.dart` | cp4-zero-before-removal-complete-references.json |
| forwarding file | `apps/mobile/lib/core/geo/geometry_hash.dart` | cp4-zero-before-removal-complete-references.json |
| forwarding file | `apps/mobile/lib/features/discover/domain/entities/geo_point.dart` | cp4-zero-before-removal-complete-references.json |
| forwarding file | `apps/mobile/lib/features/discover/domain/entities/local_date.dart` | cp4-zero-before-removal-complete-references.json |
| IdGenerator forwarding export only; UUID/ULID retained | `apps/mobile/lib/core/id/id_generator.dart` | cp4-zero-before-removal-complete-references.json |
| MarketConfig.legacy | `apps/mobile/lib/app/config/market_config.dart` | CP4-extra-zero-before-removal.json (non-getter declarations only) |
| MarketConfig.marketCityId | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json |
| MarketConfig.timezoneId | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json |
| MarketConfig.currencyCode | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json |
| MarketConfig.defaultLocaleCode | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json |
| MarketConfig.supportedLocaleCodes | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json |
| MarketRegistry.byId | `apps/mobile/lib/app/config/market_config.dart` | CP4-extra-zero-before-removal.json (non-getter declarations only) |
| MarketRegistry.resolveLegacyLocation | `apps/mobile/lib/app/config/market_config.dart` | CP4-extra-zero-before-removal.json (non-getter declarations only) |
| obsolete active-config context parameters/fields | `apps/mobile/lib/features/create/data/models/create_draft_model.dart` | CP4-extra-zero-before-removal.json (context parameter section) |
| obsolete active-config context parameters/fields | `apps/mobile/lib/features/create/data/models/create_template_model.dart` | CP4-extra-zero-before-removal.json (context parameter section) |
| obsolete active-config context parameters/fields | `apps/mobile/lib/features/create/data/datasources/create_local_datasource.dart` | CP4-extra-zero-before-removal.json (context parameter section) |
| obsolete active-config context parameters/fields | `apps/mobile/lib/features/create/data/datasources/create_template_local_datasource.dart` | CP4-template-context-zero-before-removal.json |
