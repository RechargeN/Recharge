# RECHARGE — Object / Offer Details Runtime Completion Plan

Версия: v0.2 (2026-09-06).

Статус: **Approved** (утверждён владельцем продукта
2026-09-06 после фиксации пяти уточнений §0). Runtime effect:
**none**.

Этот документ является отдельным планом завершения runtime-интеграции
Object / Offer Details. Он не изменяет и не переписывает исторически
самостоятельный `OBJECT_OFFER_DETAILS_VISUAL_SYSTEM_PLAN.md` и сам по себе не
разрешает код конкретного vertical: каждый из трёх новых
runtime-типов сначала получает отдельную Approved slice-spec по §4.

## 0. Зафиксированные уточнения владельца продукта

1. Визуальный план остаётся отдельным завершённым документом; runtime-
   completion описывается только здесь.
2. Один section matrix означает один файл/реестр с **отдельными typed-
   матрицами шести типов**, а не один универсальный nullable-список.
3. Map не является обязательным действием: online и hidden-location варианты
   не получают фиктивную кнопку карты.
4. Rental формально вне Object / Offer scope, но пока его legacy renderer
   находится в общем файле, его regression-тест обязателен на каждом этапе.
5. `DetailsShell` обслуживает четыре семейства Details. Изменения Object /
   Offer требуют неизменностных проверок Route, Scenario и Collection.

## 1. Цель и исходная точка

Цель: довести Object / Offer Details от готовых visual compositions до шести
реально разрешаемых typed runtime verticals:

| Тип | Визуал | Runtime на старте плана | Цель |
|---|---:|---:|---:|
| Place | готов | подключён через legacy `DiscoverItemEntity` | сохранить |
| Event | готов | typed projection/loader подключены | сохранить |
| Recharge Activity | готов | подключён через legacy `DiscoverItemEntity` | сохранить |
| Find People | готов | preview-only, loader отсутствует | typed runtime |
| Class / Workshop | готов | preview-only, loader отсутствует | typed runtime |
| Bookable Session | готов | preview-only, loader отсутствует | typed runtime |

Исходный baseline: визуал **6/6**, runtime **3/6**. Canonical router намеренно
возвращает `notFound` для трёх preview-only типов, потому что
`DetailsLookupRegistry` не содержит для них loader'ов.

Текущая контрольная точка, **2026-09-15**: visual **6/6**, runtime
**6/6 local/mock**. Find People, Bookable Session и Class / Workshop переведены
с preview на typed projection/port/lookup/page.
Это счётчик подключённых Details, не готовности backend или Booking.
Новые vertical остаются **Review**: общий baseline содержит ошибки
Create/Identity; полная приёмка §9 не закрыта.

## 2. Scope

### 2.1 В scope

- отдельные Discover-owned public read projections для Find People,
  Bookable Session и Class / Workshop;
- отдельные read ports, mock/local datasources и `DetailsLookupPort` adapters;
- регистрация трёх типов в `DetailsLookupRegistry`;
- typed runtime constructors существующего `ObjectOfferDetailsRenderer`;
- page-level coordination существующих разрешённых действий;
- canonical router branches;
- перенос visual tests с preview props на typed projections;
- удаление preview-only production API после завершения всех трёх verticals;
- регрессия Place/Event/Activity, Rental и остальных Details families.

### 2.2 Вне scope

- Route, Scenario, Collection или Rental redesign;
- перенос Rental в новый renderer family — это будущая отдельная спека;
- изменение Create domain ради удобства Details;
- Firebase, production backend, authoritative Booking, Payments;
- новые join/application/waitlist/booking механизмы;
- вычисление eligibility, availability или capability внутри renderer;
- расширение `DiscoverItemEntity` полями трёх новых типов;
- generic `Map<String, dynamic>` projection или универсальный nullable DTO.

## 3. Архитектурные инварианты

### 3.1 Typed read side

Каждый новый тип получает собственную цепочку:

```text
Published<Type>DiscoveryEntity
        ↓
Published<Type>DiscoveryPort
        ↓
Published<Type>DiscoveryLocalDataSource
        ↓
<Type>DetailsLookup
        ↓
DetailsLookupRegistry
        ↓
ResolvedDetailsRoute
        ↓
ObjectOfferDetailsRenderer.<type>
```

Projection принадлежит Discover и не импортирует Create domain. Если позже
появится реальный Create → Discover pipeline, преобразование выполняется
boundary-compliant adapter'ом вне Discover domain; публичный read contract от
этого не меняется.

### 3.2 Один реестр, шесть typed-матриц

`object_offer_section_matrix.dart` остаётся одним реестром порядка секций, но
содержит шесть независимых enum/list pairs:

- `PlaceDetailsSection` / `placeProfileSections`;
- `EventDetailsSection` / `eventProfileSections`;
- `ActivityDetailsSection` / `activityProfileSections`;
- `FindPeopleDetailsSection` / `findPeopleProfileSections`;
- `ClassWorkshopDetailsSection` / `classWorkshopProfileSections`;
- `BookableSessionDetailsSection` / `bookableSessionProfileSections`.

Каждый renderer dispatch использует exhaustive switch по матрице своего типа.
Запрещено заменять это одним списком секций с nullable props, runtime type
checks или набором `if (type == ...)` внутри универсального адаптера.

Legacy `RentalDetailsSection` может временно оставаться в том же файле только
из-за существующего `.rental` renderer. Он явно не является седьмой Object /
Offer матрицей и не участвует в новых abstractions.

### 3.3 Actions и location

Renderer только показывает переданное состояние и вызывает callbacks. Он не
решает, разрешено ли действие.

- `Map` показывается только при наличии публичной mappable location и
  ненулевого `onMap` callback.
- Online-only вариант не получает coordinates, marker или Map action.
- Hidden-location вариант может показывать безопасный area label, но не точный
  адрес, coordinates или Map action.
- Hybrid показывает Map только если публичная часть projection действительно
  содержит разрешённую точку.
- Отсутствующий callback удаляет действие целиком, а не создаёт no-op кнопку.
- CTA виден/активен только по переданному typed состоянию. Renderer не выводит
  availability, capacity, identity или capability самостоятельно.

### 3.4 Fail-closed resolution

- неизвестный id, скрытая/непубличная версия и type mismatch дают общий
  unavailable/not-found surface без утечки причины;
- typed route hint не запускает fallback scan по другим ports;
- projection одного типа нельзя привести к renderer другого типа;
- неподдерживаемое состояние не заменяется legacy `DiscoverItemEntity`.

## 4. Approval gates до кода

Перед реализацией каждого vertical slice утверждается его минимальный Details
read contract. Большие Create/product документы дают семантический контекст,
но не заменяют runtime-разрешение:

| Тип | Текущий источник | Что нужно утвердить |
|---|---|---|
| Find People | `FIND_PEOPLE_CREATE_BLOCK_SPEC.md` — product blueprint | публичные поля, privacy/location disclosure, recruitment/CTA state |
| Bookable Session | Create spec пока Draft; typed schedule существует в Create | независимая Discover projection, schedule freshness, внешний CTA |
| Class / Workshop | spec Ready for approval; специализированный runtime неполон | минимальный public contract, schedule/teacher/price/enrollment semantics |

Ни один slice не начинает runtime-код, пока его поля и action matrix не
зафиксированы в Approved revision этого плана либо в отдельной Approved
подспеке.

## 5. Минимальные projection contracts

Точные Dart signatures фиксируются на contract-review, но projection каждой
ветки обязана покрывать только реально потребляемые visual blocks.

### 5.1 Find People

- stable request id и publisher display reference;
- title, description, category/subcategory, media;
- meeting mode (`inPerson | online | hybrid`);
- уже нормализованные публичные time options;
- group-size/recruitment display state без вычисления в renderer;
- public requirements и participation/cost disclosure;
- privacy-safe public location variant;
- typed primary-action display state.

Запрещено публиковать device/live location, applicant identities, contact
data, exact hidden meeting point или внутренние moderation/application поля.

### 5.2 Bookable Session

- stable session id и publisher/provider display reference;
- title, description, category/subcategory, media;
- delivery mode и публичная location variant;
- duration, party-size disclosure и price display data;
- bounded public schedule offers;
- generated/fresh-until timestamps и честный provider-availability status;
- безопасный HTTPS external booking URL либо отсутствие CTA.

Create-owned `PublicSessionScheduleProjection` не импортируется напрямую в
Discover. Discover получает независимую immutable read projection с теми же
разрешёнными публичными смыслами.

### 5.3 Class / Workshop

- stable offering id и publisher/teacher display reference;
- title, description, category/subcategory, media;
- class/workshop format, level и language display data;
- публичные outcomes/about, materials и requirements;
- нормализованные schedule rows;
- public location/online variant;
- price и typed enrollment-action state.

Поля cohort, inventory, booking и payment нельзя угадывать из generic Create
flags. Если контракт их не предоставляет, соответствующая секция отсутствует.

## 6. Предлагаемый file map

### 6.1 На каждый новый тип

- `features/discover/domain/entities/published_<type>_discovery_entity.dart`;
- `features/discover/domain/repositories/published_<type>_discovery_port.dart`;
- `features/discover/data/datasources/published_<type>_discovery_local_datasource.dart`;
- `features/discover/data/repositories/<type>_details_lookup.dart`;
- typed constructor/fields/dispatch в
  `object_offer_details_renderer.dart`;
- page coordinator в boundary-safe слое, если Save/Map/CTA требуют app-level
  wiring;
- projection, port, lookup, renderer, page и router tests.

### 6.2 Общие integration-файлы

- `app/application/details_resolution_providers.dart` — три loader
  registrations;
- `app/di/service_locator.dart` — три read-port registrations;
- `app/router/app_router.dart` — три typed branches;
- `object_offer_section_matrix.dart` — существующие отдельные typed matrices,
  без универсализации;
- `object_offer_visual_preview_props.dart` — удалить только на cleanup-этапе;
- visual golden tests — перевести с preview props на typed projections.

Точный file map каждого vertical фиксируется до его первой правки. Boundary
dry-run выполняется до расширения scope; новый allowlist exception не является
плановым решением.

## 7. Порядок реализации

### Этап 0 — зафиксировать чистый baseline

1. Утвердить этот план.
2. Зафиксировать точный accepted visual state без несанкционированного commit.
3. Выполнять runtime slices в чистом/изолированном checkout либо дождаться
   завершения параллельного Create/Identity dirty-state.
4. Повторить baseline: 66 Object/Offer visual tests, 3 Rental Details tests,
   analyzer и boundary.

### Этап 1 — Find People vertical

1. Утвердить minimal projection и action/privacy matrix.
2. Добавить entity → port → datasource → lookup.
3. Зарегистрировать loader в DI/registry.
4. Заменить `.findPeoplePreview` runtime-путём `.findPeople`.
5. Добавить page coordination и typed router branch.
6. Перевести fixtures/golden на typed entity.
7. Прогнать focused + соседние regression gates.

Контрольная точка: runtime **4/6**.

Фактический статус на 2026-09-06: **реализовано, Review**. Typed projection,
public port/local datasource/lookup, registry/DI/router, page coordinator,
typed renderer и golden переведены на runtime. Focused Object/Offer + Rental
regression: 101/101 passed; boundary gate: 0 violations. `Done` пока не
зафиксирован: repo-wide analyzer/tests заблокированы предсуществующей
рассинхронизацией параллельного Create/Identity WIP (`sessionData`,
`actorUserId`, `moderationRepository` и Place location-search API).

### Этап 2 — Bookable Session vertical

1. Утвердить Discover contract, freshness и external-CTA semantics.
2. Добавить entity → port → datasource → lookup.
3. Зарегистрировать loader в DI/registry.
4. Заменить `.bookableSessionPreview` runtime-путём `.bookableSession`.
5. Добавить page coordination и typed router branch.
6. Проверить online/in-person/hidden-location и fresh/stale schedule cases.
7. Перевести fixtures/golden на typed entity и прогнать gates.

Контрольная точка: runtime **5/6**.

Фактический статус на 2026-09-08: **реализовано, Review** по Approved
`DTL_SES_01_BOOKABLE_SESSION_DETAILS_RUNTIME_SLICE_SPEC.md` v0.2.
Подключены typed read model, evaluator, mock port/lookup, DI/registry/router,
page и renderer. Freshness обновляется по таймеру/при resume; stale скрывает
время, но сохраняет exact external handoff. Map только для public point,
Save отсутствует по принятому решению. Галерея, время через полночь и
360/375dp при 150% проверены. Focused regression: **143/143**; отдельно
Session resolver **4/4**, включая Scenario fail-closed. Scoped analyzer:
**0 issues**; boundary **0 violations, 71/71**, diff check чист.
Полный analyzer: **40 issues** в существующем Create/Identity WIP, включая
его DI wiring. Collection/parity не загружаются из-за этого baseline.
Полный suite: **897 passed / 58 load/compile failures**; окончательные
gallery/resolver дополнения отдельно подтверждены focused-проверками.
Подробные результаты полного suite и ограничения — execution log DTL-SES-01.

### Этап 3 — Class / Workshop vertical

Контракт подготовлен 2026-09-08:
[`DTL_CLS_01_CLASS_WORKSHOP_DETAILS_RUNTIME_SLICE_SPEC.md`](DTL_CLS_01_CLASS_WORKSHOP_DETAILS_RUNTIME_SLICE_SPEC.md)
v0.2 **Approved** (подтверждение 2026-09-08). В нём зафиксированы bounded live read scope,
отдельные Publisher/instructor, price units и typed external/info-only
enrollment. File map и пять решений §9 утверждены; реализация завершена
до **Review** 2026-09-12. Итоговый execution log — §10 Class slice-spec.

1. Утвердить minimal Details contract до использования неполной Create-модели.
2. Добавить entity → port → datasource → lookup.
3. Зарегистрировать loader в DI/registry.
4. Заменить `.classWorkshopPreview` runtime-путём `.classWorkshop`.
5. Добавить page coordination и typed router branch.
6. Перевести fixtures/golden на typed entity и прогнать gates.

Контрольная точка: runtime **6/6**.

Подключены projection/port/lookup/DI/router/page и typed renderer. Общая
регрессия **171/171 passed**, scoped analyzer **0 issues**, boundary
**0 violations, 71/71**, diff clean. Два Class golden проверены визуально.
Full analyzer остаётся красным: 40 Create/Identity issues. Это не полный
app smoke и не закрытие общих gates: Collection/parity не компилируются.
Полный suite этапа завершился: **928 passed / 58 load/compile failures**
в Create/Identity baseline (результат запуска 2026-09-12, перечитан 2026-09-15).
Повторная focused-регрессия на текущих файлах 2026-09-15: **171/171**, boundary
**0 violations, 71/71**. Реализация остаётся Review до общих зелёных gates.
Полный analyzer 2026-09-15 также повторно подтвердил **40 issues** в прежнем
Create/Identity baseline, без ошибок нового Class Details slice.

Порядок Find People → Session → Class/Workshop выбран по фактической зрелости
контрактов, а не по визуальному порядку карточек.

### Этап 4 — удалить preview-переходный слой

- удалить три `*VisualPreviewProps` и preview constructors из production;
- сохранить test fixtures, но строить их из typed projections;
- удалить неиспользуемые preview helpers;
- подтвердить поиском отсутствие `Preview` API в `apps/mobile/lib`;
- не объединять шесть typed section matrices.

Факт на 2026-09-12: публичные Object/Offer preview props/constructors удалены,
поиск consumers в lib/test — 0. Class schedule row теперь private formatted
presentation value. Shared private `_Preview*` widgets не удалялись: они
используются runtime и не являются preview-входом. Удалённый untracked
props-файл сохранён в temp для rollback; путь указан в Class execution log.

### Этап 5 — общая runtime regression

Проверить все шесть Object / Offer типов одним suite:

- canonical typed route открывает правильную projection;
- type mismatch и unknown/hidden id fail closed;
- composition order соответствует typed matrix своего типа;
- optional blocks скрываются при отсутствии данных;
- Save/Share/CTA вызывают только переданные реальные callbacks;
- in-person с публичной точкой может показывать Map;
- online и hidden-location не показывают Map;
- no/one/many media, длинный content, 360/375dp, 150% text scale;
- шесть 430×932 golden references стабильны.

### Этап 6 — cross-family invariance

Из-за общего `DetailsShell` обязательны:

- Route: существующий `route_details_renderer_test.dart` и canonical route;
- Collection: `collection_details_page_test.dart`, отдельный renderer и
  mini-map behavior;
- Scenario: пока loader/renderer отсутствует — canonical Scenario route
  обязан по-прежнему fail closed в общий not-found/unavailable state без
  speculative projection; если Scenario vertical появится параллельно, вместо
  этого запускается его собственный renderer/page suite;
- `details_shell_test.dart` и `details_shell_accessibility_test.dart`;
- подтверждение, что default non-immersive режим соседних families не изменён.

### Этап 7 — обязательная Rental regression

Rental не входит в Object / Offer product scope, но до физического выноса из
`object_offer_details_renderer.dart` обязательны:

- `rental_details_page_test.dart`;
- typed projection/availability/pricing tests, затронутые общим файлом;
- проверка прежнего non-immersive layout;
- проверка неизменности внешнего CTA и unavailable state;
- отсутствие возврата Rental golden в Object / Offer visual suite.

### Этап 8 — финальные gates и документация

1. Targeted analyzer/tests после каждого vertical.
2. Полный `flutter analyze --no-pub`.
3. Полный `flutter test --no-pub`.
4. Boundary gate: 0 violations, без нового exception budget.
5. `git diff --check`.
6. Аудит: Discover не импортирует Create; router не содержит preview fallback.
7. Обновить этот runtime plan и `LAUNCH_STATUS.md` фактическими результатами.
8. Визуальный план не переписывать задним числом.

## 8. Test matrix

| Контур | Обязательные проверки |
|---|---|
| Projection | constructor invariants, nullable semantics, privacy allowlist |
| Port/datasource | found, hidden/not found, malformed/future data fail closed |
| Lookup/registry | correct classification, no cross-type fallback |
| Router | canonical typed target, unavailable parity, no unsafe cast |
| Renderer | typed section order, presence-based blocks, no fabricated values |
| Actions | callback ownership, hidden action without callback, Map variants |
| Adaptive | 360/375dp, 150%, long title/publisher/address, safe areas |
| Golden | шесть Object / Offer references, no Rental reference |
| Neighbors | Rental, Route, Scenario fail-closed baseline, Collection, shell |

## 9. Definition of Done

Runtime completion считается завершённым только когда:

1. Все шесть типов имеют typed visual composition.
2. Все шесть canonical `CatalogObjectRef` разрешаются через зарегистрированный
   loader в правильную typed projection.
3. Find People, Bookable Session и Class / Workshop больше не используют
   preview-only production props/constructors.
4. В одном section registry существуют шесть отдельных typed matrices.
5. Online/hidden-location варианты не показывают Map.
6. Renderer не вычисляет availability, capability или CTA eligibility.
7. Rental остаётся вне scope и проходит regression.
8. Route, Scenario и Collection проходят invariance gates.
9. Targeted и repo-wide analyzer/tests, boundary и diff gates зелёные.
10. В документации нет расхождения между visual 6/6 и runtime 6/6.

## 10. Rollback

Каждый vertical откатывается независимо:

1. удалить его registry/DI/router registration;
2. вернуть canonical route к общему fail-closed unavailable state;
3. удалить его lookup/port/local datasource и typed projection;
4. вернуть golden fixture на preview props до общего cleanup-этапа;
5. не откатывать уже принятые verticals других типов;
6. не изменять persisted Create drafts и соседние Details families.

## 11. Приёмка визуала и следующий gate — 2026-09-15

Владелец продукта подтвердил показанный итоговый Class visual. Object/Offer
runtime-композиции не требуют нового дизайна в рамках этого плана.
Статус остаётся **Review**: визуальное согласование не заменяет сборку
всего приложения и проверку canonical routes/Collection/parity.

Владелец продукта разрешил bounded compile-reconciliation (ответ «да!»)
существующего Create/Identity WIP. Это dependency repair, а не продолжение
Class visual и не новый Create/Booking scope. Текущие подтверждённые ошибки
группируются в пять причин, а не в 40 независимых функций:

| Порядок | Несогласованность | Предполагаемая граница исправления после разрешения |
|---|---|---|
| 1 | `ResolvePublicProfessionalPageUseCase` требует `moderationRepository`, которого нет в вызове DI | `apps/mobile/lib/app/di/service_locator.dart`: передать существующий repository, не отключать moderation |
| 2 | Activity informal counter требует `actorUserId` | `apps/mobile/lib/features/create/application/controllers/create_controller.dart`: текущий actor, не Publisher/подставной id |
| 3 | Session coordinator/UI/repository обращаются к отсутствующему draft/controller wiring | Согласовать существующие `create_draft_entity.dart`, mapper, coordinator, controller/state и providers; точные hunks после сверки авторских изменений, без восстановления целых файлов |
| 4 | Place UI обращается к отсутствующим location-search методам/state | Согласовать уже существующий поиск и controller/state, не добавлять новый provider/геокодинг |
| 5 | Rental repository tests ожидают `promoteRentalToPublished` | Сверить существующий promotion port/usecase/repository; сохранить поведение Rental, не возвращать его в Object/Offer |

Разрешение ограничено восстановлением совместимости существующего WIP.
Фактический file map: `app/di/service_locator.dart`; Create
`application/controllers/create_controller.dart`, `application/state/create_state.dart`,
`application/create_providers.dart`, `domain/entities/create_draft_entity.dart`,
`data/models/create_draft_model.dart`, `data/repositories/create_repository_impl.dart`,
`presentation/pages/create_page.dart`; focused regression tests и эти status docs.
Проверен текущий dirty checkout; изменения вносятся отдельными hunks.
Запрещены whole-file copy/restore,
обнуление private полей, отключение проверки прав/модерации, skip тестов
ради зелёного прогона и стирание чужого WIP.

После восстановления совместимости: full analyze → full tests → canonical
Object/Offer route smoke и Collection/parity → Rental/Route/Scenario/shell
regression → boundary/diff → фактический статус Done либо конкретный остаток.
Новые Create/Identity функции, backend и production integration не разрешены.
