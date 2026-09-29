# RECHARGE — Rental Create Stabilization: Audit and File Plan

- Статус: **Done.** Аудит + file plan (§1-7, шаги 1-2) написаны
  2026-08-24 в исходном checkout. Разделение/перенос/gates (шаги 3-6)
  выполнены в этом заходе — см. §8.
- Дата: 2026-08-24
- Контекст: prerequisite для возобновления `DTL-OBJ-01`
  (`docs/product/DTL_OBJ_01_OBJECT_OFFER_ENGINE_SLICE_SPEC.md`,
  Blocked on Rental Create prerequisite), по треку 1 из решения
  владельца продукта в `DISCOVER_DETAILS_PIPELINE_COVERAGE_MATRIX.md`
  §3. Не относится к Discover Details архитектуре напрямую — это
  Create-side git-гигиена.
- Порядок (владелец продукта): 1. Аудит и зависимости — этот документ.
  2. Точный file plan без кода — этот документ. 3. Отделить Rental от
  Session/LocationSearch и прочих примесей — выполнено, см. §8.
  4. Перенести самостоятельными prerequisite-коммитами — выполнено,
  см. §8. 5. Прогнать analyze/test/boundary/diff — выполнено, см. §8.
  6. Возобновить `DTL-OBJ-01` — разблокировано, не начато в этом заходе.

## 1. Итог аудита (executive summary)

Исходное предположение («304 Rental-фрагмента вперемешку с
Session/LocationSearch, разделение рискованно») **уточнено прямым
чтением diff'ов**: фрагменты действительно физически соседствуют в
общих файлах, но **каждая добавленная строка однозначно атрибутируется
ровно одной фиче** по имени идентификатора/пути импорта — это не
семантическое переплетение, а последовательные независимые блоки
(imports по алфавиту, constructor-параметры по одному на фичу,
copyWith-поля по одному на фичу, целые contiguous-блоки методов). Ни
одного места, где Rental-логика реально *вызывает* или *зависит* от
Session/Collection/LocationSearch-кода, не обнаружено.

Найдено **22 файла**, целиком принадлежащих Rental Create, с **нулевыми
кросс-фичевыми импортами** (только друг на друга и на уже
закоммиченные baseline-файлы `create_availability.dart`/
`publisher_ref.dart`/`create_draft_entity.dart`/`create_state.dart`,
которые побайтово идентичны между checkout и worktree, кроме самих
Rental/Session/Collection-полей). Единственная реальная работа —
**7 уже закоммиченных shared-файлов**, куда нужно добавить ровно
Rental-относящиеся строки, без Session/Collection/LocationSearch.

Дополнительно обнаружено: Rental Create **уже был полностью
реализован и верифицирован** прежней сессией 21.08.2026 —
`docs/architecture/LAUNCH_STATUS.md` (сам этот файл частично
незакоммичен) содержит подробную запись `RNT-CRT-01` (статус Review) с
заявленными зелёными gates (34 новых теста, `flutter analyze` 0 issues,
`flutter test` 879 total зелёный кроме уже известного постороннего
golden-теста, boundary 0 нарушений 71/71, `git diff --check` чист) —
**на момент той сессии, для полного незакоммиченного дерева, включая
Session/Collection/LocationSearch**. Это не эквивалентно «Rental в
изоляции зелёный» — именно это предстоит подтвердить заново на шаге 5
после разделения.

## 2. Что уже закоммичено в worktree-ветку и не требует переноса

Проверено побайтовым diff между `worktree-dtl-fnd-01` (ветка,
основанная на `codex/map-main-ui-s3-logic`) и исходным checkout:

- `CreateObjectType.rental` enum-значение — уже в `create_draft_entity.dart`.
- Rental `CreateBlockConfig` запись (`objectType: CreateObjectType.rental`,
  `defaultCategoryId/subcategoryId`, `locationLabel`, `priceLabel`) — уже
  в `create_taxonomy.dart`. Diff этого файла содержит ровно один
  посторонний Session-хунк (`requiresStartDateTime: false` для
  bookable session), не Rental — не трогать.
- `create_availability.dart`, `publisher_ref.dart` — побайтово
  идентичны, отдельного переноса не требуют.
- `service_locator.dart` — **ноль строк с «Rental»** ни в checkout, ни
  в worktree. `CreateController`'s Rental-конструкторные параметры
  (`ValidateRentalDraftUseCase`, `EvaluateRentalAvailabilityUseCase`,
  `EstimateRentalRateUseCase`, `BuildRentalPublicProjectionUseCase`,
  `RentalPrivateAuthoringRepository?`) все имеют рабочие `const`-дефолты
  или nullable — DI wiring **не нужен** для сегодняшнего mock-объёма.
- `create_providers.dart` — ноль строк с «Rental» в diff'е вообще.
- `app/router/*`, `app/adapters/*` — Rental read/write-в-Discover
  vertical (`RentalPublicationDiscoveryAdapter` и т.д.) — предмет
  самого `DTL-OBJ-01` §3, не этой стабилизации; здесь не создаётся.

## 3. Новые файлы — 22, zero cross-feature imports (проверено импортами каждого)

| Файл | Строк | Импортирует (кроме друг друга/baseline) |
|---|---|---|
| `features/create/domain/entities/rental_draft_data.dart` | 727 | `create_availability.dart`, `publisher_ref.dart` |
| `features/create/domain/entities/rental_listing.dart` | 93 | `rental_draft_data.dart` |
| `features/create/domain/entities/rental_private_authoring_data.dart` | 89 | `shared/primitives/geo/geo_point.dart` |
| `features/create/domain/entities/rental_create_policy.dart` | 56 | — |
| `features/create/domain/entities/rental_validation_issue.dart` | 24 | — |
| `features/create/domain/repositories/rental_private_authoring_repository.dart` | 13 | `rental_private_authoring_data.dart` |
| `features/create/domain/usecases/build_rental_public_projection_usecase.dart` | 59 | `rental_draft_data.dart`, `rental_listing.dart` |
| `features/create/domain/usecases/estimate_rental_rate_usecase.dart` | 73 | `rental_draft_data.dart` |
| `features/create/domain/usecases/evaluate_rental_availability_usecase.dart` | 144 | `rental_draft_data.dart` |
| `features/create/domain/usecases/validate_rental_draft_usecase.dart` | 538 | `create_draft_entity.dart` (уже committed), `rental_create_policy.dart`, `rental_draft_data.dart`, `rental_validation_issue.dart` |
| `features/create/data/datasources/rental_private_authoring_local_datasource.dart` | 41 | `flutter_secure_storage`, `rental_private_authoring_data.dart` |
| `features/create/data/models/rental_draft_mapper.dart` | 477 | `create_availability.dart` (уже committed), `rental_draft_data.dart` |
| `features/create/data/repositories/rental_private_authoring_repository_impl.dart` | 21 | свои 3 файла выше |
| `features/create/application/rental_availability_section.dart` | 54 | `rental_draft_data.dart`, `rental_validation_issue.dart`, `evaluate_rental_availability_usecase.dart`, `rental_section_disclosure.dart` |
| `features/create/application/rental_create_config.dart` | 114 | — |
| `features/create/application/rental_external_fulfillment_section.dart` | 51 | `rental_draft_data.dart`, `rental_validation_issue.dart`, `rental_section_disclosure.dart` |
| `features/create/application/rental_handover_section.dart` | 45 | то же |
| `features/create/application/rental_inventory_section.dart` | 51 | то же |
| `features/create/application/rental_pricing_section.dart` | 52 | + `estimate_rental_rate_usecase.dart` |
| `features/create/application/rental_section_disclosure.dart` | 22 | — |
| `features/create/application/rental_terms_section.dart` | 51 | + `rental_create_config.dart` |
| `features/create/presentation/widgets/rental_create_block.dart` | 1085 | `create_controller.dart`, `rental_create_config.dart`, `create_state.dart`, `create_draft_entity.dart`, `rental_draft_data.dart`, `rental_listing.dart`, `rental_validation_issue.dart`, `rental_template_panel.dart` (все — либо друг на друга, либо на уже committed shared-файлы) |
| `features/create/presentation/widgets/rental_template_panel.dart` | 84 | `create_controller.dart` |

**Итого ~3690 строк, действие — добавить как есть, без модификации.**

## 4. Существующие closed-committed файлы — точные Rental-only добавки

Каждый пункт ниже — редактирование уже закоммиченного файла, добавляющее
**только** перечисленное. Ничего Session/Collection/LocationSearch-
относящегося сюда не входит, даже если в checkout эти добавки физически
соседствуют.

### 4.1 `features/create/domain/entities/create_draft_entity.dart`

- 1 новый import: `rental_draft_data.dart`.
- Конструктор: `this.rentalData` (nullable named param).
- Поле: `final RentalDraftData? rentalData;`
- `CreateDraftEntity.empty()`/дефолтный фабричный конструктор:
  `rentalData: null`.
- `copyWith`: параметр `RentalDraftData? rentalData` + `bool
  clearRentalData = false` + тело `rentalData: clearRentalData ? null :
  (rentalData ?? this.rentalData)`.
- **Не добавлять**: `sessionData`, `collectionData` и их аналогичные
  места — они физически соседствуют в checkout, но не Rental.

### 4.2 `features/create/application/state/create_state.dart`

- 1 новый import: `rental_validation_issue.dart`.
- Конструктор: `required this.rentalStep`, `required
  this.rentalValidationIssues`.
- `CreateState.initial()`: `rentalStep: 0`, `rentalValidationIssues:
  const <RentalValidationIssue>[]`.
- Поля: `final int rentalStep;`, `final List<RentalValidationIssue>
  rentalValidationIssues;`.
- `copyWith`: `int? rentalStep`, `List<RentalValidationIssue>?
  rentalValidationIssues`, `bool clearRentalValidationIssues = false` +
  тело.
- **Не добавлять**: `sessionValidationIssues`, `placeLocationSuggestions`,
  `placeLocationSearchLoading`, `collectionStep`.

### 4.3 `features/create/application/controllers/create_controller.dart` (основной объём)

Импорты (11 строк, все с префиксом `rental_`/`Rental` в пути):
`collection_draft_data.dart`-соседи исключить; добавить ровно:
`domain/entities/rental_draft_data.dart`,
`domain/entities/rental_listing.dart`,
`domain/entities/rental_private_authoring_data.dart`,
`domain/entities/rental_validation_issue.dart`,
`domain/repositories/rental_private_authoring_repository.dart`,
`domain/usecases/build_rental_public_projection_usecase.dart`,
`domain/usecases/estimate_rental_rate_usecase.dart`,
`domain/usecases/evaluate_rental_availability_usecase.dart`,
`domain/usecases/validate_rental_draft_usecase.dart`,
`../rental_availability_section.dart`, `../rental_create_config.dart`,
`../rental_external_fulfillment_section.dart`,
`../rental_handover_section.dart`, `../rental_inventory_section.dart`,
`../rental_pricing_section.dart`, `../rental_section_disclosure.dart`,
`../rental_terms_section.dart`.

Конструктор (`CreateController({...})`):
- Именованные параметры: `ValidateRentalDraftUseCase
  validateRentalDraft = const ValidateRentalDraftUseCase()`,
  `EvaluateRentalAvailabilityUseCase evaluateRentalAvailability = const
  EvaluateRentalAvailabilityUseCase()`, `EstimateRentalRateUseCase
  estimateRentalRate = const EstimateRentalRateUseCase()`,
  `BuildRentalPublicProjectionUseCase buildRentalPublicProjection =
  const BuildRentalPublicProjectionUseCase()`,
  `RentalPrivateAuthoringRepository? rentalPrivateAuthoringRepository`.
- Initializer list: 5 соответствующих присвоений приватным полям.

Поля класса:
- `final ValidateRentalDraftUseCase _validateRentalDraft;`
- `final EvaluateRentalAvailabilityUseCase _evaluateRentalAvailability;`
- `final EstimateRentalRateUseCase _estimateRentalRate;`
- `final BuildRentalPublicProjectionUseCase _buildRentalPublicProjection;`
- `final RentalPrivateAuthoringRepository? _rentalPrivateAuthoringRepository;`
- `List<CreateTemplateEntity> _rentalTemplates = const <CreateTemplateEntity>[];`

Capability-геттеры (5, рядом с существующими Route-геттерами):
`canCreateRental`, `canSubmitRental`, `canPublishRentalDirect`,
`canManageRental`, `canArchiveRental` — паттерн идентичен Route.

Section-state геттеры (contiguous-блок, проверено прямым чтением
checkout строки ~204–309 старого файла): `rentalInventoryState`,
`rentalAvailabilityState`, `rentalHandoverState`, `rentalTermsState`,
`rentalPricingState`, `rentalFulfillmentState`, `rentalPublicPreview`,
`rentalTemplates`, `lastRentalTemplate`, `_rentalDestinationHost`.
**Точная граница**: этот блок заканчивается прямо перед
Session-геттером `sessionSchedulePreview` — последний не переносится.

Мутаторы (единый contiguous-блок, проверено — самый большой в файле,
747 строк diff в checkout, из которых Rental — первая часть, ~495
строк, до `_updateSession`): `_updateRental`, `updateRentalCategory`,
`confirmRentalCategory`, `updateRentalTitle`,
`updateRentalShortDescription`, `updateRentalFullDescription`,
`updateRentalBrandModel`, `addRentalInventoryGroup`,
`updateRentalInventoryGroup`, `removeRentalInventoryGroup`,
`duplicateRentalInventoryGroup`, `confirmRentalAvailabilityCoverage`,
`addRentalAvailabilityBlock` и весь остальной §14-validation-matrix
набор сеттеров (handover/terms/pricing/fulfillment/attestation —
точный список — по прямому чтению файла на шаге 3, не переписывается
здесь по памяти), `startAnotherRental`, `_loadRentalTemplates`,
`_rentalTemplateById`. **Точная граница конца блока**: последняя
Rental-строка — `return null; }` внутри `_rentalTemplateById`, сразу
после неё в checkout начинается `_updateSession`'s doc-comment — не
переносится.

Прочее (мелкие одиночные строки, каждая — свой affected-getter/setter,
не блок): `_placeLocationSearchOperationSeq`-подобных Rental-аналогов
нет (это LocationSearch-поле, не переносится).

### 4.4 `features/create/presentation/pages/create_page.dart`

- 1 import: `../widgets/rental_create_block.dart`.
- 1 `else if (state.draft.objectType == CreateObjectType.rental)` ветка
  (~13 строк, `RentalCreateBlock(controller:, state:, onPublished:)`),
  вставляется как sibling к существующим `else if`-веткам (Route,
  Scenario и т.д.) — порядок в цепочке не важен для поведения, но
  **не вставлять** соседние Session/Collection-ветки.

### 4.5 `features/create/presentation/pages/create_hub_page.dart`

- `final bool canCreateRental = capabilities.contains('create.rental');`
- Добавить условие `(config.objectType != CreateObjectType.rental ||
  canCreateRental)` в существующий `.where(...)` фильтр
  `availableBlocks` (сосед по той же цепочке `&&`, что уже
  `canCreatePlace`/`canCreateRoute`).
- Иконка `CreateObjectType.rental => Icons.handyman` — **уже
  закоммичена** (проверено прямым чтением worktree-файла — diff по
  этой строке в checkout оказался артефактом реформатирования
  окружающего кода, не реальным изменением).

### 4.6 `features/create/data/models/create_draft_model.dart`

- 2 импорта: `../../domain/entities/rental_draft_data.dart`,
  `rental_draft_mapper.dart`.
- `toJson`-эквивалент: `if (entity.rentalData != null) {
  serializedSections['rental_details'] =
  RentalDraftMapper.toJson(entity.rentalData!); }`.
- `fromJson`-эквивалент: `final RentalDraftData? rentalData =
  parsedObjectType == CreateObjectType.rental ?
  RentalDraftMapper.fromJson(migratedSectionData['rental_details'],
  defaults: RentalDraftData.defaults(userId: organizerId, currencyCode:
  currency, timeZoneId: timezone)) : null;` + `rentalData: rentalData,`
  в финальном `CreateDraftEntity(...)`.
- **Не добавлять**: `sessionData`/`SessionDraftMapper`-логику (более
  объёмная, отдельный `try`/`UnsupportedSessionSchemaException`-блок с
  legacy-миграцией — целиком Session, не переносится).
- `schemaVersion: 8` — **уже** текущее значение в worktree на обоих
  местах записи (`toJson`/фабрике) — версию бампать не нужно, обе
  стороны совпадают до и после этой правки.

### 4.7 `features/create/data/repositories/create_repository_impl.dart`

- В строке `idempotencyKey` — вставить `?? draft.rentalData?.revision`
  в существующую (не checkout'ную!) цепочку **committed** worktree-кода:
  `'$userId:${draft.id}:${draft.eventData?.revision ??
  draft.placeData?.revision ?? draft.findPeopleData?.revision ??
  draft.rentalData?.revision ?? 0}'`. **Важно**: checkout-версия этой
  строки уже включает `sessionData?.revision`/`activityData?.revision`
  — оба принадлежат другим, не входящим в этот заход, работам
  (Session; отдельный незакоммиченный ACT-CRT-01 v1.4
  «conformance-pass», не тот `ACT-CRT-01`, что уже в git log) — не
  копировать их, добавлять `rentalData?.revision` в **сегодняшнюю
  3-звенную** committed-цепочку.
- В `publishDraft`/эквивалентном `copyWith` при публикации:
  `rentalData: draft.rentalData?.replaceLocalIds(_idGenerator.generate),`
  — соседняя строка с Session-эквивалентом в checkout, не переносить
  последний.

## 5. Явно НЕ переносится этим заходом

- Session Create целиком: `session_*` файлы, `SessionCreateCoordinator`,
  `sessionData`/`sessionValidationIssues`/`sessionSchedulePreview` и
  все Session-геттеры/сеттеры/import'ы в перечисленных выше shared-
  файлах.
- Collection Create целиком (Create-сторона; Discover read-сторона уже
  перенесена отдельно в `DTL-LINK-01`): `collection_create_*` файлы,
  `CollectionCreateCoordinator`, `collectionData`/`collectionStep`.
- Location Search целиком: `location_search_suggestion.dart`,
  `place_search_coordinator.dart`, `google_places_search_datasource.dart`,
  `placeLocationSuggestions`/`placeLocationSearchLoading`,
  `LocationSearchRuntimeConfig`. (Заметка: `CollectionCreateCoordinator`
  зависит от `LocationSearchRepository` — ещё одна причина, по которой
  Collection нельзя было тихо перенести вместе с Rental же заходом,
  что и обнаружено ранее при работе над `DTL-LINK-01`/`DTL-OBJ-01`.)
- Отдельный, уже незакоммиченный «ACT-CRT-01 conformance pass против
  v1.4» (не путать с уже закоммиченным `ACT-CRT-01` v1.3 — оба
  существуют, разные объёмы): 360dp-тест доступности, taxonomy-проверки,
  `activityData?.revision` в idempotency-ключе. Не Rental, не
  переносится.
- Identity-фичи (`PP-01A` managed page editor, `PP-03A` team
  invitation) — другая фича, не Create, не в этом файле-соседстве
  вообще (отдельные файлы, проверено — ноль Rental-строк).
- `RentalPublicationIndexSink`/`PublishedRentalDiscoveryPort`/
  `RentalPublicationDiscoveryAdapter`/`RentalDetailsLookup` — write/read
  Discover-vertical из `DTL-OBJ-01` §3–4. Эта стабилизация касается
  только Create; Discover-vertical остаётся предметом `DTL-OBJ-01`
  самого, после того как этот prerequisite закрыт.

## 6. Существующие тесты (уже написаны в checkout, к переносу)

| Файл | Импорты вне Rental+baseline |
|---|---|
| `test/unit/rental_availability_test.dart` | чисто (проверено на шаге 3) — `rental_draft_data.dart`, `evaluate_rental_availability_usecase.dart` |
| `test/unit/rental_controller_test.dart` | чисто (проверено) — `create_controller.dart`, `create_state.dart`, `create_draft_entity.dart`, `rental_draft_data.dart`, стандартные Create usecase/repository интерфейсы, `../support/event_create_test_support.dart` |
| `test/unit/rental_draft_data_test.dart` | чисто (проверено на шаге 3) — только `rental_draft_data.dart` |
| `test/unit/rental_draft_mapper_test.dart` | чисто (проверено на шаге 3) — `rental_draft_mapper.dart`, `rental_draft_data.dart` |
| `test/unit/rental_draft_validation_test.dart` | чисто (проверено на шаге 3) — `create_draft_entity.dart`, `rental_draft_data.dart`, `validate_rental_draft_usecase.dart` |
| `test/unit/rental_pricing_test.dart` | чисто (проверено на шаге 3) — `rental_draft_data.dart`, `estimate_rental_rate_usecase.dart` |
| `test/unit/rental_public_projection_test.dart` | чисто (проверено на шаге 3) — `rental_draft_data.dart`, `build_rental_public_projection_usecase.dart` |
| `test/widget/rental_create_block_test.dart` | чисто (проверено) — та же схема + `rental_create_block.dart`, `widget_test_viewport.dart` |

`test/support/event_create_test_support.dart` — общий support-файл,
diff с checkout — **только различие в line endings (CRLF/LF)**,
содержимое побайтово идентично. Переносить не нужно, использовать
committed worktree-версию как есть.

## 7. Открытый вопрос — закрыт эмпирически, см. §8

`RNT-CRT-01`'s собственная (уже написанная в checkout) правка
репойнтила 2 предсуществовавших теста в `create_page_test.dart` и
capability-список в третьем — с «Rental как generic-fallback пример» на
«Collection как generic-fallback пример» (ровно тем же паттерном, каким
`SES-CRT-01` до этого репойнтил их с Session на Rental). Эмпирическая
проверка на шаге 3 (§8) показала: Session, ClassWorkshop и Collection
всё ещё падают в generic fallback в текущем committed worktree — ни
один существующий тест не пришлось репойнтить.

## 8. Фактический статус реализации (2026-08-24, шаги 3-5 выполнены)

- Статус: **Done.** Шаги 3 (отделение), 4 (самостоятельные коммиты),
  5 (analyze/test/boundary/diff) выполнены в worktree
  `rental-stabilization` (branch `worktree-rental-stabilization`,
  поверх `0a75675`). Пять коммитов: `f8a253b` (domain),
  `3bf06ac` (data), `3a0473c` (application + controller wiring),
  `51b7bba` (presentation), `7773d6b` (tests). `git status` чист.
- Гейты: `flutter analyze --no-pub` — 0 issues. `flutter test --no-pub`
  (полный набор) — 776/777, единственный failure —
  `route_create_block_method` golden (2.52% pixel diff), файл и golden
  PNG подтверждённо не тронуты этим заходом (`git status --porcelain`
  на них пуст до начала работы) — pre-existing чувствительность
  рендеринга шрифтов на этой машине, вне scope. Boundary gate —
  0 violations, 0 stale, бюджет 71/71 не изменился. `git diff --check`
  — чисто.
- Итоговый файл-план разошёлся с §3-7 в трёх местах, обнаруженных
  только при сквозном прогоне тестов (не при статическом чтении диффа)
  — задокументировано здесь как disclosed-отклонения, а не поглощено
  молча:
  1. **`manage_create_template_usecase.dart`** — 8-й общий файл, не
     учтённый в §4/исходном 7-файловом плане. Требовал добавления
     `createRentalTemplate`/`replaceRentalTemplate`/`materializeRental`/
     `duplicateRental` — обнаружено при переносе mutator-блока
     контроллера, который на эти методы ссылается.
  2. **`create_controller.dart`: `setObjectType()`** — отдельная
     локация внутри уже отредактированного файла, не входившая в §4.3.
     Без Rental-ветки `setObjectType(CreateObjectType.rental)` не
     засеивал `rentalData` вовсе — 4 из 5 тестов
     `rental_controller_test.dart` падали каскадно от этого. Исправлено
     добавлением `rentalData`/`clearRentalData` в основной `copyWith` и
     `rentalStep`/`clearRentalValidationIssues` во второй `_setState`.
  3. **`create_controller.dart`: `_updateDraft()`** — Rental отсутствовал
     в whitelist типов, переводящих `saveStatus` в `unsaved` и
     планирующих autosave-таймер. Без этого мутации Rental-черновика
     молча репортились как «уже сохранено». Исправлено добавлением
     `CreateObjectType.rental` в оба списка + `clearRentalValidationIssues`.
  4. **`test/widget/create_page_test.dart`** — общая (не-Rental) test-
     фикстура `_NoopAuthRepository`, не входившая в §6 (8 Rental-only
     тестов). Тест «create hub exposes all blocks» ожидает плитку
     Rental, но capability-список фикстуры не включал `create.rental` —
     добавлена ровно одна строка `'create.rental'`, без переноса
     соседних Session→ClassWorkshop generic-fallback правок из diff'а
     checkout (те принадлежат `SES-CRT-01`, вне scope).
  - §7 (открытый вопрос про generic-fallback) закрыт эмпирически:
    Session, ClassWorkshop и Collection всё ещё падают в generic
    `_CreateTaxonomyPicker` в текущем committed worktree
    (`create_page.dart`'s `else if`-цепочка не содержит для них Rental-
    подобной ветки) — ни один существующий тест не пришлось
    репойнтить с Rental на другой generic-fallback тип.
- `manage_create_template_usecase.dart`'s Rental-методы адаптированы
  под текущий baseline: в checkout `materializeRental()` также чистит
  `clearSessionData`/`clearCollectionData`, которых на этом worktree
  ещё не существует (`create_draft_entity.dart` их не содержит,
  Session/Collection сознательно не переносятся этим заходом) — эти два
  флага убраны из перенесённой версии.
- Разблокировано: `DTL-OBJ-01` может возобновляться (шаг 6) — Rental
  Create теперь доступен как committed prerequisite в отдельном
  worktree с честной git-историей и зелёными гейтами.
