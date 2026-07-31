# RECHARGE — Scenario Create Migration and Rollout Plan

Версия: v1.0 (2026-07-19). Статус: **Accepted**.
Slice: **SCN-SB-00**. Реализация runtime в этот документ не входит.

Каноническая продуктовая спецификация:
[SCENARIO_BUILDER_SPEC.md](SCENARIO_BUILDER_SPEC.md) v1.3.

## 1. Цель

Без потери пользовательских данных заменить legacy planning-slot
`CreateObjectType.quickPlan` самостоятельным Create-типом `scenario`, сохранив
Quick Plan отдельным personal/invited utility-flow и не меняя Route aggregate.

Общее число Create-типов остаётся равным десяти. Миграция не подключает
Firebase, live routing, externally reachable sharing, ManagedPage publish или
moderation runtime.

## 2. Непересматриваемые инварианты

1. Route, Scenario и Quick Plan имеют разные ids, repositories, lifecycles и
   persistence mappers.
2. Route хранит continuous-track geometry; Scenario не записывает свои поля в
   Route model.
3. Scenario занимает planning-slot Create Hub с canonical id `scenario`.
4. Quick Plan живёт вне Create Hub и каталога; его canonical identity не
   меняется из-за появления Scenario.
5. `Expand to Scenario` всегда создаёт новый client-generated Scenario ULID,
   не меняет Quick Plan и не создаёт live-связь.
6. Связи на catalog objects хранятся только по permanent id. `loc_*` допустим
   только для несохранённой custom location и заменяется до publish/share.
7. Никакой строковый alias сам по себе не является достаточным основанием для
   разрушительной миграции persisted payload.

## 3. Проверенный runtime inventory

Инвентаризация выполнена через `rg` 2026-07-19. Пути отражают фактически
существующее состояние, а не предполагаемую будущую структуру.

| Область | Фактическое состояние | Решение |
|---|---|---|
| `features/create/domain/entities/create_draft_entity.dart` | enum содержит `CreateObjectType.quickPlan`, writer использует `quick_plan`; `private_plan` читается тем же parser | в SB-01/02 добавить canonical `scenario`; не направлять `private_plan` в Scenario |
| `features/create/application/create_taxonomy.dart` | planning config называется Quick plan | в SB-02 заменить только Create-slot на Scenario config |
| `features/create/data/models/create_draft_model.dart` | schema v5 сериализует общий draft и typed sections Event/Place/Find People | в SB-01 добавить versioned `scenario_details` и явный migration resolver |
| `features/create/presentation/pages/create_page.dart` | есть Quick Plan selector и legacy Scenario Route seed panel | в SB-02 подключить специализированные Scenario sections; legacy handoff оставить за compatibility adapter |
| `features/scenarios/**` | существующий builder по форме ближе к Quick Plan и содержит `ScenarioRoute*` naming | не считать канонической Scenario domain model; извлекать только проверенные UX-паттерны |
| `core/config/recharge_taxonomy*.dart` | `RechargeContentType.quickPlan`, `quick_plan` и `private_plan` compatibility | Quick Plan identity сохранить; расширение core/shared contract допускается только в рамках frozen baseline/ADR |
| Discover Map/Create/Success/tests | присутствуют `mode=scenario`, `scenario route`, `Publish route` handoffs | классифицировать на входной границе; не выполнять глобальный rename |
| `docs/product/RECHARGE_CREATE_TAXONOMY_V1.md` | фиксирует старый Quick Plan Create-slot | оставить legacy implementation reference; target задают Category System v1.4.2 и Accepted Scenario spec |

## 4. Классификация legacy данных

Каждый legacy payload сначала читается без изменения, затем классифицируется
детерминированным resolver. Автоматическая запись разрешена только при
однозначном результате.

| Legacy форма | Target | Правило |
|---|---|---|
| Create draft с `objectType=quick_plan`, Scenario-shaped section/version или подтверждённым Scenario Create origin | Scenario draft | создать новый Scenario ULID, сохранить provenance и исходный payload до успешной записи |
| Лёгкий personal/invited план: одна дата, короткий горизонт, stops/participants без Scenario schema | Quick Plan | оставить Quick Plan; не показывать в Create Hub |
| `private_plan` / `privateplan` | Quick Plan compatibility | никогда не преобразовывать в Scenario только по alias |
| continuous geometry, anchors/segments, GPX/elevation или POI по километражу | Route | передать Route compatibility path; не записывать Scenario fields |
| независимые stops/days/timeline/logistics без track geometry | Scenario candidate | разрешить migration preview; запись только после typed validation |
| неоднозначный `scenario route` / `mode=scenario` seed | unresolved legacy handoff | сохранить read-only snapshot, показать выбор/issue; не угадывать target |

Миграция не подменяет `id` исходного объекта. Если создаётся Scenario, ему
выдаётся новый ULID, а origin хранит source type/id/revision только для audit и
не используется как runtime dependency.

## 5. Schema и compatibility policy

- Canonical writer после SB-01 пишет `objectType=scenario` и versioned
  `scenario_details`.
- Reader остаётся backward-compatible с известными legacy ids, но возвращает
  typed migration result: `scenario`, `quickPlan`, `route` или `unresolved`.
- Unknown fields сохраняются round-trip и не попадают в public payload без
  allowlist.
- Ошибка парсинга не заменяет payload defaults и не приводит к silent publish.
- Повторная migration идемпотентна по `{sourceId, sourceRevision, targetType}`.
- Quick Plan conversion и legacy Create migration — разные use cases. Первый
  запускает пользователь и выбирает stops; второй восстанавливает тип старого
  Create draft.

## 6. Capability flags

Флаги независимы; один master switch не должен незаметно включать недоступные
capabilities.

| Flag | Начальное значение | Назначение |
|---|---:|---|
| `scenarioCreateEnabled` | false | показывает Scenario planning-slot в Create Hub |
| `scenarioLegacyReadEnabled` | true после SB-01 | включает non-destructive compatibility reader |
| `scenarioMigrationWriteEnabled` | false | разрешает подтверждённую запись migrated draft |
| `scenarioMultiDayEnabled` | false | weekend/trip, stay и перенос между днями |
| `scenarioAlternativesEnabled` | false | alternative groups и totals policy |
| `scenarioOptimizerEnabled` | false | deterministic proposal + explicit Apply |
| `scenarioUnlistedShareEnabled` | false | backend-token sharing; запрещён на local mock |
| `scenarioPublicPublishEnabled` | false | ManagedPage/capability/moderation publish |
| `scenarioLiveLogisticsEnabled` | false | live provider после Accepted ADR |

SB-01 может читать/писать Scenario fixtures в тестах, не включая видимость
Create UI. Personal MVP-A открывается только после SB-02/03 acceptance.

## 7. Rollout

### Phase 0 — Accepted design

- Scenario spec и этот plan имеют статус Accepted.
- VISION и LAUNCH_STATUS отражают три разных продукта.
- Runtime не меняется.

### Phase 1 — Shadow schema (SB-01)

- Добавить typed Scenario model, mapper, validation/readiness и tests.
- Включить compatibility reader только в тестах/diagnostics.
- Сравнивать classification с legacy payload без записи.

### Phase 2 — Personal MVP-A (SB-02/03)

- Заменить видимый Quick Plan Create-slot на Scenario.
- Включить personal city/day composer, autosave, manual logistics и conflicts.
- Quick Plan entry points остаются вне Create Hub.
- Public/share/live flags остаются выключены.

### Phase 3 — Personal MVP-B (SB-04)

- Независимо включать multi-day, stay, transport, alternatives, currency и
  optimizer после собственных acceptance tests.

### Phase 4 — Distribution (SB-05)

- Сначала capability/publisher/moderation/backend dependencies.
- Затем backend-issued unlisted tokens и public immutable revisions.
- Local mock никогда не выдаётся за externally reachable secure sharing.

### Phase 5 — Live logistics (SB-06)

- Только после Accepted provider ADR, timeout/retry/cache/stale policy,
  observability, quota controls и kill switch.

## 8. Rollback

1. Выключить только проблемный capability flag; personal drafts остаются
   читаемыми.
2. Отключить Scenario entry в Create Hub без удаления Scenario storage.
3. Writer возвращается к предыдущей поддерживаемой schema version, reader
   продолжает читать новые сохранённые payload либо показывает явный
   unsupported-version state.
4. Никогда не переписывать Scenario обратно в Quick Plan или Route.
5. Migration journal хранит source/target ids, revisions, result и reason без
   private notes, invite tokens, chat или participant identity.
6. Cleanup migrated source разрешён только отдельной задачей после периода
   наблюдения; SB-00–SB-03 ничего не удаляют.

## 9. Dependency ownership и exit evidence

| Dependency | Owner | Exit evidence | Блокирует |
|---|---|---|---|
| Scenario typed config/mapper | Create slice owner | round-trip/migration/unit tests | SB-02 composer |
| CatalogObjectPickerPort | Create + app composition | boundary gate и contract tests | catalog add flow |
| ManagedPage/capability guards | Auth/Publisher slice | permission matrix tests | public authoring |
| Moderation/report runtime | Trust & Safety slice | moderation integration evidence | external public publish |
| Firebase/backend | Backend integration slice после стабилизации | emulator/integration/security-rule tests | sync и real unlisted share |
| Live logistics provider ADR | Architecture owner | Accepted ADR + kill-switch test | SB-06 |
| Localization en/ru/lv | Localization slice | generated catalogs + widget tests | production copy, не domain core |

## 10. Acceptance criteria SB-00

1. Scenario spec v1.3 и §27 имеют статус Accepted.
2. VISION называет Route, Scenario и Quick Plan самостоятельными продуктами.
3. Scenario занимает planning-slot существующей десятки Create Hub; Quick Plan
   не считается одиннадцатым типом.
4. LAUNCH_STATUS не описывает Scenario как Quick Plan.
5. Реальные definitions/consumers перечислены без выдуманных файлов.
6. Migration matrix запрещает bulk rename `quick_plan`.
7. `private_plan` остаётся Quick Plan compatibility alias.
8. Legacy `scenario route` не записывается в Route или Scenario без
   классификации.
9. Rollout и rollback не требуют удаления или потери данных.
10. Firebase, live providers и external sharing не входят в slice.
11. Изменения SB-00 ограничены документацией; runtime приложения неизменен.

## 11. Выход из SB-00

После выполнения критериев можно планировать SB-01. Перед кодом SB-01 требуется
отдельный подтверждённый file plan. Каждый implementation slice обязан пройти
boundary gate, `flutter analyze` и полный `flutter test` согласно AGENTS.md.
