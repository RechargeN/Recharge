# IDP/M2 — per-removal rollback, 2026-11-20

All30 removal items belong to coherent CP4 commit
`c78101f558d92bf2227d783333f096bbb41d6034`; their preimages exist at
`45eda2d6` and in the hash-verified Desktop review archive (22 files).
Rollback for **each row**: `git revert c78101f558d92bf2227d783333f096bbb41d6034`,
then run complete analyze/test/boundary/diff gates. Reverting the whole checkpoint
keeps codec signatures and clients consistent. No data migration was executed.

| Removed item | Source | Pre-removal proof | Removal commit / return command |
|---|---|---|---|
| ActivityContributionAmountDraft | `apps/mobile/lib/features/create/domain/entities/activity_draft_data.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| EventMoneyDraft | `apps/mobile/lib/features/create/domain/entities/event_draft_data.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| RentalMoneyDraft | `apps/mobile/lib/features/create/domain/entities/rental_draft_data.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| ScenarioMoneyDraft | `apps/mobile/lib/features/create/domain/entities/scenario_budget_draft.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| ScenarioLocalDateDraft | `apps/mobile/lib/features/create/domain/entities/scenario_item_draft.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| ScenarioGeoPointDraft | `apps/mobile/lib/features/create/domain/entities/scenario_item_draft.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| ScenarioTransitLocalDate | `apps/mobile/lib/features/create/domain/entities/scenario_transit_schedule.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| SessionMoneyDraft | `apps/mobile/lib/features/create/domain/entities/session_price_disclosure.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| SessionLocalDate | `apps/mobile/lib/features/create/domain/entities/session_schedule.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| _LocalDate | `apps/mobile/lib/features/create/domain/usecases/materialize_event_schedule_usecase.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| forwarding file | `apps/mobile/lib/core/geo/geo_bounds.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| forwarding file | `apps/mobile/lib/core/geo/geo_distance.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| forwarding file | `apps/mobile/lib/core/geo/geo_point.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| forwarding file | `apps/mobile/lib/core/geo/geometry_encoding.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| forwarding file | `apps/mobile/lib/core/geo/geometry_hash.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| forwarding file | `apps/mobile/lib/features/discover/domain/entities/geo_point.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| forwarding file | `apps/mobile/lib/features/discover/domain/entities/local_date.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| IdGenerator forwarding export only; UUID/ULID retained | `apps/mobile/lib/core/id/id_generator.dart` | cp4-zero-before-removal-complete-references.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| MarketConfig.legacy | `apps/mobile/lib/app/config/market_config.dart` | CP4-extra-zero-before-removal.json (non-getter declarations only) | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| MarketConfig.marketCityId | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| MarketConfig.timezoneId | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| MarketConfig.currencyCode | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| MarketConfig.defaultLocaleCode | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| MarketConfig.supportedLocaleCodes | `apps/mobile/lib/app/config/market_config.dart` | CP4-market-final-zero-before-removal.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| MarketRegistry.byId | `apps/mobile/lib/app/config/market_config.dart` | CP4-extra-zero-before-removal.json (non-getter declarations only) | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| MarketRegistry.resolveLegacyLocation | `apps/mobile/lib/app/config/market_config.dart` | CP4-extra-zero-before-removal.json (non-getter declarations only) | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| obsolete active-config context parameters/fields | `apps/mobile/lib/features/create/data/models/create_draft_model.dart` | CP4-extra-zero-before-removal.json (context parameter section) | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| obsolete active-config context parameters/fields | `apps/mobile/lib/features/create/data/models/create_template_model.dart` | CP4-extra-zero-before-removal.json (context parameter section) | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| obsolete active-config context parameters/fields | `apps/mobile/lib/features/create/data/datasources/create_local_datasource.dart` | CP4-extra-zero-before-removal.json (context parameter section) | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |
| obsolete active-config context parameters/fields | `apps/mobile/lib/features/create/data/datasources/create_template_local_datasource.dart` | CP4-template-context-zero-before-removal.json | `c78101f5`; `git revert c78101f558d92bf2227d783333f096bbb41d6034` |

Archive root: `C:/Users/User/Desktop/мусор на проверку/IDP-M2-2026-11-20-CP4-45eda2d6`.
Full archive paths and SHA256 are in CP4-archive-plan/receipt.json; per-row paths
are in CP4-removal-rollback-matrix.json. Seven physical files were moved, not
deleted; fifteen whole source preimages were copied before declaration removal.
UUID/ULID implementation and all necessary persisted-data readers remain.
