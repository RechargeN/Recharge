# Mobile Architecture M2 — Primitive Reconciliation Plan

**ID:** MOB-ARCH-M2-P
**Версия:** 1.0
**Дата:** 2026-08-11
**Статус:** Approved — M2-A Done; M2-B–M2-E not started
**Parent:** [Recharge Mobile Architecture v3.1](RECHARGE_MOBILE_ARCHITECTURE_V3.md)
**Depends on:** MOB-ARCH-M1 — Done, merged as `f893a931a58cff9ef9f779e17517af0d28c2f454`
**Нормативные AC:** MOB-ARCH-AC-05–06, AC-52–53, AC-56–60, AC-74
**Runtime effect:** M2-A architecture-only refactor; product behavior unchanged
**Backend/Firebase effect:** none

## 0. Решение

M2 устраняет расхождение общих mobile primitives без изменения продуктовых
aggregate boundaries. Работа выполняется пятью отдельными, обратимыми slices:

1. `M2-A` — boundary-safe Geo, ID generation и identity presentation mapping;
2. `M2-B` — единые `CurrencyCode` и `Money` в integer minor units;
3. `M2-C` — `LocalDate`, `UtcInstant`, `IanaTimeZone`, `LocaleTag`, `MarketRef`;
4. `M2-D` — consumer migration, compatibility reads и zero-reference cleanup;
5. `M2-E` — финальные gates, debt reconciliation и status evidence.

План не разрешает автоматически ни один runtime slice. Каждый slice получает
отдельный reviewed diff. `M2-B` обязан завершиться до M8 remote writes.

## 1. Scope и ограничения

### 1.1 В scope

- pure immutable primitives, одинаковые минимум в двух bounded contexts;
- удаление всех 35 M1 exceptions с `targetSlice = MOB-ARCH-M2-PRIMITIVES`;
- migration с normalized monetary `double` на integer minor units;
- единые structural contracts для валюты, локальной даты, UTC и IANA zone;
- compatibility reads для существующих local/mock drafts и projections;
- zero-reference proof перед удалением legacy declarations и adapters;
- domain/application/data/presentation tests в объёме фактического impact.

### 1.2 Не в scope

- Firebase, `apps/backend`, remote datasource, production identity или deploy;
- изменение Event/Booking lifecycle, admission, inventory или Payments;
- новая локализация UI и создание `lib/l10n`;
- обмен валют и live exchange-rate provider;
- изменение пользовательских цен, округления или отображаемой бесплатности;
- массовая смена всех строковых taxonomy/config keys на typed IDs;
- изменение wire schemas Booking v1 без отдельного contract slice;
- рефакторинг Create presentation, не требуемый сменой primitive type.

## 2. Factual baseline на 2026-08-11

| Область | Фактическое состояние | Debt |
|---|---|---|
| Boundary registry | 106 suppressions; 35 назначены на M2 | 23 domain sources импортируют 7 `core` targets |
| Geo | один фактический `GeoPoint` в `core/geo`; 42 production files используют тип | domain не может зависеть от `core` |
| ID generation | интерфейс и UUID v4 implementation находятся в одном `core/id` файле | domain зависит от infrastructure-owned path |
| Identity preview | domain extension возвращает Flutter-facing `AccountExperience` | presentation mapping находится в domain |
| Money, compliant | Event и Scenario уже используют integer minor units | два параллельных money-класса и raw currency strings |
| Money, debt | Discover, Favorites, legacy Scenario, Place, Find People и filters используют `double` | normalized floating-point amount и неявная EUR semantics |
| Time | Discover `LocalDate`, Event private `_LocalDate`, Scenario local-date types; два timezone ports | повторение structural semantics и разная DST vocabulary |
| Locale/market | market/timezone/currency/locale представлены raw `String` | нет structural validation и typed boundary |

M1 evidence остаётся baseline: 380 Dart files, 106 findings, 106 exact
suppressions, 0 unsuppressed, 0 stale, 0 expired. M2 не может увеличивать
exception budget ни временно, ни «до следующего cleanup».

## 3. Reconciliation contract

### 3.1 Общие правила primitive

Primitive допускается в `shared/primitives`, только если он:

- не импортирует Flutter, Riverpod, storage, HTTP, mapper или feature code;
- immutable и имеет полную equality/hash semantics;
- проверяет только общие structural invariants;
- не решает feature policy и не знает о UI;
- не сериализует себя в Firestore/DTO shape;
- имеет явные invalid/edge tests;
- не создаёт generic `BaseEntity`, `BaseRepository` или «универсальный» JSON.

Feature-specific semantics остаются в feature domain. Например, `Money` может
структурно представлять отрицательную дельту, но Event price и Place entry fee
по-прежнему запрещают её собственными validators.

Единственный non-value shared contract в M2 — dependency-free интерфейс
`IdGenerator`: он живёт рядом с ID primitives, не содержит implementation и
не импортирует `uuid`. Это узкий cross-feature port, а не разрешение складывать
repository/service contracts в `shared/primitives`.

### 3.2 Money contract

```text
CurrencyCode
  value: uppercase ISO 4217 alpha-3

Money
  minorUnits: integer in JSON-safe range -9007199254740991..9007199254740991
  currency: CurrencyCode

CurrencyMetadata
  code: CurrencyCode
  exponent: integer 0..6
```

- normalized/domain/data/application state не хранит amount в `double`;
- input parser принимает locale-aware decimal text и конвертирует точно;
- excess fractional digits дают typed validation result, а не rounding guess;
- render formatter использует currency exponent metadata;
- арифметика разрешена только при одинаковой валюте;
- multi-currency totals не складываются без явного exchange-rate snapshot;
- free — product state, а не автоматически `minorUnits == 0` во всех contexts;
- legacy `double` читается только mapper adapter и сразу переводится в minor
  units по зафиксированной currency metadata;
- новые writes используют только integer minor units + currency code.

Начальный metadata registry обязан покрывать `EUR` с exponent `2`. Добавление
других валют не требует изменения primitive, но требует отдельного market/data
решения. M2 не выполняет currency conversion.

### 3.3 Geo contract

- `GeoPoint` — WGS 84 decimal degrees; elevation optional in meters;
- latitude/longitude и elevation обязаны быть finite;
- `GeoBounds`, distance, encoding и hash остаются pure deterministic;
- equality текущих persisted values не меняется;
- map/provider DTO conversion остаётся в adapters/data;
- старые `core/geo` paths могут существовать только как временные forwarding
  exports внутри `M2-A`; `M2-D` удаляет их после zero-reference proof.

### 3.4 Identifier contract

- permanent entity IDs — UUID/ULID-compatible opaque values;
- `loc_*` допустим только для unsaved local draft parts;
- taxonomy IDs, capability strings, schema keys и external provider IDs не
  оборачиваются механически в entity ID;
- generator interface не зависит от package `uuid`;
- UUID implementation остаётся в infrastructure/composition;
- domain use case получает generator port или заранее созданный ID через
  constructor/command; прямой `DateTime.now().microsecondsSinceEpoch` не
  становится альтернативным permanent-ID generator;
- publish/persist validators fail closed при `loc_*`, где нужен permanent ID.

### 3.5 Time, locale и market contract

- `UtcInstant` принимает только UTC и не выполняет implicit `.toLocal()`;
- `LocalDate` не означает UTC midnight и не используется как instant;
- `IanaTimeZone` хранит canonical zone ID; фактическая TZDB-resolution остаётся
  за repository/data adapter;
- DST gap/overlap policy остаётся feature policy, но outcomes используют общую
  structural vocabulary;
- Visit History date интерпретируется в IANA-зоне Place;
- `LocaleTag` нормализует поддерживаемый BCP 47 subset без запуска l10n;
- `MarketRef` хранит stable market ID, а не city label;
- adapters явно переводят primitive в legacy string field и обратно;
- никакого fallback на device timezone для persisted schedules.

### 3.6 Compatibility и failure policy

- новые поля читаются первыми;
- legacy field читается только при отсутствии нового;
- ambiguous/overflow/unknown currency/invalid zone дают typed failure;
- mapper не подставляет EUR, Riga или device locale без market/config context;
- dual-write допустим только в bounded local migration window и удаляется в
  том же M2 program;
- rollback выполняется переключением reader/writer adapter, без destructive
  rewrite local data;
- unknown newer schema остаётся fail closed.

## 4. Slice M2-A — Boundary-safe Geo, ID и identity mapping

**Статус:** Done — commit `6f00b2f`, draft PR #3, target CI green.

### 4.1 Новые файлы

```text
apps/mobile/lib/shared/primitives/geo/geo_point.dart
apps/mobile/lib/shared/primitives/geo/geo_bounds.dart
apps/mobile/lib/shared/primitives/geo/geo_distance.dart
apps/mobile/lib/shared/primitives/geo/geometry_encoding.dart
apps/mobile/lib/shared/primitives/geo/geometry_hash.dart
apps/mobile/lib/shared/primitives/id/id_generator.dart
apps/mobile/test/unit/shared_geo_primitives_test.dart
apps/mobile/test/unit/shared_id_generator_contract_test.dart
```

### 4.2 Перемещение implementation ownership

```text
apps/mobile/lib/core/geo/geo_point.dart
apps/mobile/lib/core/geo/geo_bounds.dart
apps/mobile/lib/core/geo/geo_distance.dart
apps/mobile/lib/core/geo/geometry_encoding.dart
apps/mobile/lib/core/geo/geometry_hash.dart
apps/mobile/lib/core/id/id_generator.dart
```

`core/geo/*` временно становятся deprecated forwarding exports. В
`core/id/id_generator.dart` остаётся только `UuidV4IdGenerator`, реализующий
shared interface. Forwarders удаляются только в `M2-D`.

### 4.3 Exact domain sources для удаления 35 suppressions

```text
apps/mobile/lib/features/create/domain/entities/route_draft_data.dart
apps/mobile/lib/features/create/domain/entities/route_edit_command.dart
apps/mobile/lib/features/create/domain/entities/route_publication_data.dart
apps/mobile/lib/features/create/domain/entities/route_recording_data.dart
apps/mobile/lib/features/create/domain/repositories/route_elevation_repository.dart
apps/mobile/lib/features/create/domain/repositories/route_gpx_repository.dart
apps/mobile/lib/features/create/domain/repositories/route_routing_repository.dart
apps/mobile/lib/features/create/domain/usecases/apply_route_edit_command_usecase.dart
apps/mobile/lib/features/create/domain/usecases/apply_scenario_object_intake_usecase.dart
apps/mobile/lib/features/create/domain/usecases/apply_scenario_transit_selection_usecase.dart
apps/mobile/lib/features/create/domain/usecases/build_route_geometry_diff_usecase.dart
apps/mobile/lib/features/create/domain/usecases/build_route_publication_bundle_usecase.dart
apps/mobile/lib/features/create/domain/usecases/calculate_route_quality_usecase.dart
apps/mobile/lib/features/create/domain/usecases/expand_quick_plan_to_scenario_usecase.dart
apps/mobile/lib/features/create/domain/usecases/manage_create_template_usecase.dart
apps/mobile/lib/features/create/domain/usecases/process_route_recording_usecase.dart
apps/mobile/lib/features/create/domain/usecases/validate_route_draft_usecase.dart
apps/mobile/lib/features/discover/domain/entities/geo_point.dart
apps/mobile/lib/features/discover/domain/entities/published_route_discovery_entity.dart
apps/mobile/lib/features/identity/domain/entities/admin_experience_preview.dart
apps/mobile/lib/features/identity/domain/usecases/create_professional_page_usecase.dart
apps/mobile/lib/features/identity/domain/usecases/request_page_limit_increase_usecase.dart
apps/mobile/lib/features/visited/domain/usecases/record_place_visit_usecase.dart
```

Identity correction не создаёт общий identity primitive: extension из
`admin_experience_preview.dart` удаляется, а mapping в `AccountExperience`
переезжает в
`features/identity/application/state/identity_workspace_state.dart`.

### 4.4 Registry files

```text
tools/scripts/boundary-exceptions.json
tools/scripts/boundary-policy.json
docs/architecture/MOBILE_BOUNDARY_INVENTORY.md
```

Из registry удаляются ровно BND-LEGACY-0060–0094 после успешного scan. Budget
уменьшается с 106 до 71. Любое другое изменение registry делает slice invalid.

## 5. Slice M2-B — Canonical Money

### 5.1 Новые shared primitives и adapters

```text
apps/mobile/lib/shared/primitives/money/currency_code.dart
apps/mobile/lib/shared/primitives/money/currency_metadata.dart
apps/mobile/lib/shared/primitives/money/money.dart
apps/mobile/lib/shared/primitives/money/money_parse_result.dart
apps/mobile/lib/shared/primitives/money/money_parser.dart
apps/mobile/lib/shared/primitives/money/money_formatter.dart
apps/mobile/test/unit/money_primitive_test.dart
apps/mobile/test/unit/money_parser_test.dart
apps/mobile/test/unit/money_formatter_test.dart
apps/mobile/test/unit/money_legacy_adapter_test.dart
```

Formatter/parser не импортируют Flutter. UI locale передаётся как value.

### 5.2 Domain owners, подлежащие миграции

```text
apps/mobile/lib/features/create/domain/entities/event_draft_data.dart
apps/mobile/lib/features/create/domain/entities/scenario_budget_draft.dart
apps/mobile/lib/features/create/domain/entities/quick_plan_conversion.dart
apps/mobile/lib/features/create/domain/entities/place_draft_data.dart
apps/mobile/lib/features/create/domain/entities/find_people_draft_data.dart
apps/mobile/lib/features/discover/domain/entities/discover_item_entity.dart
apps/mobile/lib/features/discover/domain/entities/discover_query.dart
apps/mobile/lib/features/favorites/domain/entities/favorite_item_entity.dart
apps/mobile/lib/features/scenarios/domain/entities/scenario_draft_entity.dart
```

`EventMoneyDraft` и `ScenarioMoneyDraft` сначала получают lossless adapters к
`Money`, затем удаляются в `M2-D`, если zero-reference proof подтверждён.

### 5.3 Data/application consumers

```text
apps/mobile/lib/features/create/data/models/create_draft_model.dart
apps/mobile/lib/features/create/data/models/event_draft_mapper.dart
apps/mobile/lib/features/create/data/models/find_people_draft_mapper.dart
apps/mobile/lib/features/create/data/models/place_draft_mapper.dart
apps/mobile/lib/features/create/data/models/scenario_draft_mapper.dart
apps/mobile/lib/features/create/application/controllers/create_controller.dart
apps/mobile/lib/features/create/application/scenario_create_coordinator.dart
apps/mobile/lib/features/create/domain/usecases/evaluate_scenario_readiness_usecase.dart
apps/mobile/lib/features/create/domain/usecases/expand_quick_plan_to_scenario_usecase.dart
apps/mobile/lib/features/create/domain/usecases/validate_place_draft_usecase.dart
apps/mobile/lib/features/create/domain/usecases/validate_scenario_draft_usecase.dart
apps/mobile/lib/features/discover/application/controllers/discover_feed_controller.dart
apps/mobile/lib/features/discover/application/smart_search_parser.dart
apps/mobile/lib/features/discover/data/models/discover_item_model.dart
apps/mobile/lib/features/discover/data/repositories/discover_repository_impl.dart
apps/mobile/lib/features/favorites/data/models/favorite_item_model.dart
apps/mobile/lib/features/scenarios/application/state/scenario_builder_state.dart
apps/mobile/lib/app/adapters/legacy_quick_plan_conversion_adapter.dart
```

### 5.4 Presentation boundary

Presentation сохраняет text input и форматированный output, но не выполняет
арифметику и не хранит normalized amount в `double`. Impact surfaces:

```text
apps/mobile/lib/features/create/presentation/pages/create_page.dart
apps/mobile/lib/features/create/presentation/pages/create_success_page.dart
apps/mobile/lib/features/create/presentation/widgets/find_people_create_block.dart
apps/mobile/lib/features/create/presentation/widgets/place_create_block.dart
apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart
apps/mobile/lib/features/discover/presentation/pages/discover_map_page.dart
apps/mobile/lib/features/discover/presentation/pages/discover_results_page.dart
apps/mobile/lib/features/discover/presentation/pages/search_page.dart
apps/mobile/lib/features/discover/presentation/pages/smart_search_page.dart
apps/mobile/lib/features/discover/presentation/widgets/discover_feed_section.dart
apps/mobile/lib/features/favorites/presentation/pages/favorites_page.dart
apps/mobile/lib/features/scenarios/presentation/pages/scenario_builder_page.dart
apps/mobile/lib/features/explore/presentation/pages/profile_page.dart
apps/mobile/lib/features/auth/presentation/pages/discover_hub_page.dart
```

## 6. Slice M2-C — Time, locale и market primitives

### 6.1 Новые primitives

```text
apps/mobile/lib/shared/primitives/time/local_date.dart
apps/mobile/lib/shared/primitives/time/utc_instant.dart
apps/mobile/lib/shared/primitives/time/iana_time_zone.dart
apps/mobile/lib/shared/primitives/locale/locale_tag.dart
apps/mobile/lib/shared/primitives/market/market_ref.dart
apps/mobile/test/unit/local_date_primitive_test.dart
apps/mobile/test/unit/utc_instant_test.dart
apps/mobile/test/unit/iana_time_zone_test.dart
apps/mobile/test/unit/locale_tag_test.dart
apps/mobile/test/unit/market_ref_test.dart
```

### 6.2 Canonicalization targets

```text
apps/mobile/lib/app/config/market_config.dart
apps/mobile/lib/features/discover/domain/entities/local_date.dart
apps/mobile/lib/features/discover/domain/entities/time_window.dart
apps/mobile/lib/features/discover/domain/repositories/timezone_repository.dart
apps/mobile/lib/features/discover/data/repositories/timezone_repository_impl.dart
apps/mobile/lib/features/create/domain/repositories/event_timezone_repository.dart
apps/mobile/lib/features/create/data/repositories/event_timezone_repository_impl.dart
apps/mobile/lib/features/create/domain/usecases/materialize_event_schedule_usecase.dart
apps/mobile/lib/features/create/domain/entities/scenario_item_draft.dart
apps/mobile/lib/features/create/domain/entities/scenario_transit_schedule.dart
apps/mobile/lib/features/visited/domain/entities/visited_place_entity.dart
apps/mobile/lib/features/visited/domain/usecases/record_place_visit_usecase.dart
apps/mobile/lib/features/visited/data/models/visited_place_model.dart
```

Feature-specific `EventDstGapPolicy`, `EventDstOverlapPolicy`, transit service
date rules и Visit idempotency остаются в своих domains. M2 объединяет только
совпадающую structural semantics.

## 7. Slice M2-D — Compatibility removal

Cleanup разрешён только при одновременном выполнении:

1. `rg` подтверждает ноль production/test imports старых `core/geo` paths;
2. ноль domain imports `core/id` и `core/identity`;
3. ноль normalized monetary declarations типа `double` для amount/budget;
4. legacy monetary fixtures всё ещё читаются losslessly;
5. current writers не создают legacy monetary shape;
6. все persisted schedule instants UTC и сохраняют IANA zone;
7. все 35 M2 exceptions удалены, новых exceptions нет;
8. generated inventory соответствует scanner output.

Только после этого удаляются forwarding exports, legacy money wrappers и
duplicate local-date declarations. Если хотя бы один consumer остаётся,
deprecated adapter сохраняется и M2 не получает `Done`.

## 8. Migration и rollback

### 8.1 Read path

1. читать canonical integer field;
2. если его нет — читать legacy number;
3. получить currency только из record/market context;
4. выполнить exact decimal-to-minor conversion;
5. при ambiguity вернуть typed migration failure;
6. не переписывать запись только из-за read.

### 8.2 Write path

- новые local writes — canonical fields;
- dual-write включается только отдельным temporary adapter flag;
- remote writes отсутствуют;
- migration не запускается автоматически при app startup;
- rollback возвращает legacy writer/reader order без удаления local data.

Canonical local field names:

| Context | Legacy read | Canonical write |
|---|---|---|
| Event fixed price | `price.amountMinor`, `price.currencyCode` | `price.minorUnits`, `price.currencyCode` |
| Scenario budget component | `amount.minorUnits`, `amount.currencyCode` | shape сохраняется; mapper создаёт shared `Money` |
| Quick Plan stop | `priceMinorUnits` + draft currency | `price.minorUnits`, `price.currencyCode` |
| Place pricing | `entryPriceFrom/To`, `typicalSpendFrom/To` | соответствующие `*MinorUnits` + `currencyCode` |
| Find People expense | `amount` + draft currency | `amountMinorUnits` + `currencyCode` |
| Discover projection | `price_amount` + implicit market currency | `price_minor_units` + `currency_code` |
| Discover budget query | `budget_min/max` + implicit market currency | `budget_min/max_minor_units` + `currency_code` |
| Favorite projection | `priceAmount` + implicit market currency | `priceMinorUnits` + `currencyCode` |
| Legacy Scenario step | `priceAmount` + implicit EUR | `priceMinorUnits` + `currencyCode` |

Новые snake_case/camelCase имена соответствуют существующему storage context;
primitive сам не знает форму ключей. Переименование внешнего wire contract в
этом slice запрещено.

### 8.3 Rollback unit

Каждый M2 slice откатывается отдельным revert. Нельзя смешивать M2-A imports,
M2-B Money и M2-C timezone в один необратимый commit. Cleanup M2-D выполняется
после минимум одного зелёного полного suite на compatibility state.

## 9. Verification matrix

| Gate | M2-A | M2-B | M2-C | M2-D/E |
|---|---:|---:|---:|---:|
| primitive unit/property tests | required | required | required | required |
| legacy mapper fixtures | smoke | required | required | required |
| affected controller/usecase tests | required | required | required | required |
| affected widget tests | smoke | required | required | required |
| `flutter analyze --no-pub` | required | required | required | required |
| full `flutter test --no-pub` | required | required | required | required |
| boundary self-test + repo scan | required | required | required | required |
| inventory `--check-output` | required | required | required | required |
| `git diff --check` | required | required | required | required |
| GitHub Actions Linux | required | required | required | required |

Timeout, cancelled job, missing SDK/runtime или частичный test run не являются
pass. Flutter target остаётся pinned по M1 policy.

## 10. Acceptance criteria

- **MOB-M2-AC-01:** M2 выполняется slices A–E, а не одним bulk rewrite.
- **MOB-M2-AC-02:** Ни один runtime slice не начинается без принятия этого плана.
- **MOB-M2-AC-03:** Shared primitive не импортирует framework/infrastructure.
- **MOB-M2-AC-04:** Feature policy не переносится в shared primitive.
- **MOB-M2-AC-05:** M2 не создаёт backend/Firebase runtime.
- **MOB-M2-AC-06:** Exception budget никогда не увеличивается.
- **MOB-M2-AC-07:** M2-A удаляет ровно BND-LEGACY-0060–0094.
- **MOB-M2-AC-08:** После M2-A budget равен 71 при отсутствии иных изменений.
- **MOB-M2-AC-09:** Geo semantics WGS 84/elevation остаются совместимыми.
- **MOB-M2-AC-10:** Geo algorithms deterministic на прежних fixtures.
- **MOB-M2-AC-11:** Domain импортирует Geo только из shared primitives.
- **MOB-M2-AC-12:** Generator interface не зависит от `uuid` package.
- **MOB-M2-AC-13:** UUID implementation остаётся composition dependency.
- **MOB-M2-AC-14:** `loc_*` не проходит permanent-ID validation.
- **MOB-M2-AC-15:** Identity domain не импортирует Flutter-facing experience.
- **MOB-M2-AC-16:** Money хранит integer minor units + currency metadata.
- **MOB-M2-AC-17:** CurrencyCode нормализуется и валидируется структурно.
- **MOB-M2-AC-18:** Money arithmetic запрещает неявное смешение валют.
- **MOB-M2-AC-19:** Decimal input не проходит через binary floating-point.
- **MOB-M2-AC-20:** Excess scale даёт typed validation, не silent rounding.
- **MOB-M2-AC-21:** Legacy `double` читается только migration adapter.
- **MOB-M2-AC-22:** Current writers не создают normalized `double` amounts.
- **MOB-M2-AC-23:** Free semantics не выводится универсально из нулевой суммы.
- **MOB-M2-AC-24:** Multi-currency total не вычисляется без rate snapshot.
- **MOB-M2-AC-25:** EUR exponent 2 покрыт boundary/property tests.
- **MOB-M2-AC-26:** Money M2 завершён до M8 remote writes.
- **MOB-M2-AC-27:** LocalDate не маскируется под UTC instant.
- **MOB-M2-AC-28:** UtcInstant fail closed для non-UTC input.
- **MOB-M2-AC-29:** Persisted schedule хранит UTC + IANA zone.
- **MOB-M2-AC-30:** DST gap/overlap outcomes детерминированы тестами.
- **MOB-M2-AC-31:** Visit date использует timezone Place.
- **MOB-M2-AC-32:** LocaleTag не означает готовность l10n.
- **MOB-M2-AC-33:** MarketRef использует stable ID, не display name.
- **MOB-M2-AC-34:** Mapper не угадывает market/currency/timezone.
- **MOB-M2-AC-35:** Unknown/invalid primitive даёт typed failure.
- **MOB-M2-AC-36:** Compatibility read не выполняет скрытый destructive rewrite.
- **MOB-M2-AC-37:** Legacy declaration удаляется только при zero references.
- **MOB-M2-AC-38:** Полный analyzer/test/boundary/diff CI зелёный для каждого slice.
- **MOB-M2-AC-39:** LAUNCH_STATUS обновляется только после evidence.
- **MOB-M2-AC-40:** M2 Done не утверждает backend или production readiness.

## 11. Definition of Ready

До M2-A владелец продукта отдельно принимает:

1. slices A–E и их порядок;
2. shared ownership для перечисленных primitives;
3. exact Money contract и legacy-read policy;
4. удаление 35 suppressions и budget 106 → 71 в M2-A;
5. M2 → M8 blocking dependency;
6. AC-01–AC-40 и exclusions.

## 12. Definition of Done

M2 получает `Done`, только когда M2-A–E завершены, все compatibility/deprecation
paths либо удалены с zero-reference proof, либо имеют отдельный принятый debt
owner, Money migration полностью блокирует legacy normalized writes, GitHub
Actions зелёный, а `LAUNCH_STATUS` содержит проверяемое evidence.

Принятие этого документа само по себе не изменяет приложение и не разрешает
backend, Firebase, Payments, provider integrations или M8 remote adapters.

## 13. Acceptance record

Владелец продукта разрешил переход к реализации сообщением «идем дальше»
2026-08-11 после публикации и принятия полного M2-плана. Это разрешение
охватывает только последовательные mobile slices M2-A–M2-E в указанном scope;
каждый slice остаётся отдельным reviewed diff и не разрешает backend/Firebase.

## 14. M2-A implementation evidence

M2-A реализован отдельным обратимым commit `6f00b2f` без Money,
time/locale/market, backend, Firebase или продуктовых UI-изменений:

- Geo implementation ownership перенесён в `shared/primitives/geo`, а старые
  `core/geo` paths оставлены forwarding exports до M2-D;
- dependency-free `IdGenerator` перенесён в `shared/primitives/id`, UUID v4
  implementation остался composition dependency в `core/id`;
- identity preview mapping перенесён из domain в application state;
- domain больше не импортирует `core/geo`, `core/id` или `core/identity`;
- удалены ровно BND-LEGACY-0060–0094, budget уменьшен 106 → 71;
- repository scan: 380 Dart files / 71 finding / 71 suppression /
  0 violation / 0 stale / 0 expired / budget 71;
- локально прошли boundary self-test, inventory drift, diff check и 26
  targeted Geo/ID/identity tests;
- GitHub Actions на Flutter 3.44.9 для draft PR #3: `boundaries`, `codegen`,
  `lint` и полный suite из 664 tests прошли.

Это закрывает только M2-A. Compatibility exports остаются осознанным долгом
M2-D; M2-B–M2-E и весь M2 остаются незавершёнными.
