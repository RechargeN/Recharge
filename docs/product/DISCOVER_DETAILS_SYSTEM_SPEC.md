# RECHARGE — Discover Details System Spec

Версия: v0.3 (2026-08-24) — добавлен Этап 4 (фактический статус
staged-реализации: FND/LINK/CLG/RTE Done, OBJ Blocked on Rental Create
prerequisite, SCN Blocked on Approved `SCN-PUB-01`); §1–15 по содержанию
не менялись. Статус: **Accepted** (принят владельцем продукта
2026-08-24, после трёх раундов review дочерних `DTL-*` документов).
Runtime effect: **none**. Принятие этого документа само по себе не
изменяет код, маршруты, тесты, DI или ADR — оно фиксирует целевую
архитектуру Details-поверхности Discover и авторизует переход к
реализации отдельных `DTL-*` implementation slice по их собственному
approval-статусу (см. Этап 3 ниже).

## Что изменилось с v0.1

Правки внесены по итогам трёх раундов review дочерних `DTL-*` документов
(та же evidence, что и в них, здесь не повторяется целиком):

- §8: unavailable-item policy Collection исправлена на Approved-поведение
  (`COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md:919` — публично скрывается, не
  показывается со статусом).
- §7: видимость Scenario исправлена — только `public`+published входит в
  Discover, `unlisted` вне каталога (`SCENARIO_BUILDER_SPEC.md` §5).
- §11 (DTL-D09): единый универсальный canonical URI отменён — Scenario
  сохраняет Accepted `recharge://scenario/{id}`; резолюция вынесена в
  application-layer (`ResolveDetailsUseCase`/`DetailsLookupRegistry`),
  отделена от router и от presentation renderer registry; терминология
  синхронизирована с финальными именами компонентов `DTL-LINK-01` v0.3.
- §14/Этап 3: порядок реализации пересмотрен на
  `FND → LINK → {OBJ, RTE, CLG} → SCN` — canonical resolver должен
  существовать до typed renderer'ов.
- §15: убрана устаревшая формулировка «point-object» из AC, приведена к
  DTL-D12 (primary listing/continuous route/executable composition/
  editorial composition вместо «point object»).
- §2 (косвенно, через `DTL-FND-01`): presentation renderer registry
  явно не является data authority — уточнение синхронизировано между
  документами.

Owner: Recharge team.
Аудит, предшествующий этому документу, проведён evidence-first по
`AGENTS.md`, `docs/architecture/ARCHITECTURE_BASELINE.md`,
`docs/architecture/LAUNCH_STATUS.md`, ADR 0013 и текущим Details-файлам;
результаты аудита (contradiction table, DTL-D01–D12, открытые вопросы)
согласованы с владельцем продукта перед написанием этого документа и не
повторяются здесь целиком — только используются как основание решений.

## Зависимости от других спецификаций

| Документ | Версия | Статус | Роль здесь |
|---|---|---|---|
| `EVENT_CLASSIFICATION_SPEC.md` | rev 2.2.3 | Accepted | источник Event-профиля |
| `PLACE_CREATE_BLOCK_SPEC.md` | v1.0 | Approved | источник Place/`venue`-профиля |
| `RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md` | v1.4 | Approved slice spec | источник Activity-профиля |
| `RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md` | v1.0 (V1) | Approved | источник Rental/`offer`-профиля |
| `COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md` | v1.0 | Approved | источник Collection renderer, образец read-модели |
| `SCENARIO_BUILDER_SPEC.md` | v1.7 | Accepted | источник Scenario renderer (target) |
| `ROUTE_BUILDER_SPEC.md` | v3.2 | целевая продуктовая спецификация | источник Route renderer (target) |
| `BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md` | v1.1 | **Draft for review** | Session — family membership принята здесь, поля/CTA — Candidate |
| `FIND_PEOPLE_CREATE_BLOCK_SPEC.md` | v3.1 | **Reconciled Final Product Blueprint** (не Accepted/Approved) | Find People — family membership принята здесь, §14.4/§14.5 используются как evidence, поля/CTA — Candidate |
| `CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md` | v1.1 | **Ready for approval** | Class/Workshop — family membership принята здесь, поля/CTA — Candidate |

Ни один из трёх «Pending»-источников не повышается этим документом до
Accepted/Approved. Details System фиксирует только то, что перечисленные типы
принадлежат семейству `Object/Offer`; их точный набор секций, полей и CTA
остаётся `Candidate` до отдельного утверждения апстрим-спеки продукт-оунером.

## Non-goals

- Profile и Professional Page — не часть этого документа.
- `DiscoverQuery` v3 и ranking/поиск Find People — внешняя зависимость,
  не часть контракта Details и не блокирует ни один DTL-слайс.
- Payments, authoritative Booking backend, Firebase — вне scope.
- Quick Plan — не входит в публичный Details ни в каком виде (см. §3).
- Точные Dart-сигнатуры типов, миграции схем БД, тестовые фикстуры —
  предмет отдельных Approved slice spec на Этапе 3 (`DTL-*`), не этого
  документа.

---

## 1. Статус и границы

Этот раздел резюмирует шапку документа: v0.1 / Draft for review / Runtime
effect: none. Ничего из описанного ниже не реализовано, если явно не
помечено как «текущий runtime».

Фактическое текущее runtime-состояние (зафиксировано здесь вместо правки
`LAUNCH_STATUS.md`, по решению владельца продукта — Этап 1, открытый вопрос
2):

- Существует ровно один общий Details-экран, `DiscoverDetailsPage`
  (`apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart`),
  и один отдельный, `CollectionDetailsPage`
  (`apps/mobile/lib/features/discover/presentation/pages/collection_details_page.dart`).
- `DiscoverDetailsPage` покрывает Event, Recharge Activity и Place через
  `DiscoverObjectKind {place, event, route, activity}`; Route получает
  внутри неё одну дополнительную карточку (`_PublishedRouteCard`) поверх
  того же generic hero/organizer/location layout.
- Bookable Session, Find People, Class/Workshop, Rental/Equipment **не
  подключены** к Details ни в каком виде.
- Scenario **не имеет** публичного Details вообще — публикация Scenario
  (`SCN-PUB-01`) ещё не реализована.
- Зарегистрировано ровно два маршрута:
  `/discover/details/:itemId` и `/collection/details/:collectionId`
  (`apps/mobile/lib/app/router/route_names.dart`).

## 2. Термины

- **Details System** — совокупность shell, четырёх renderer contracts и
  read-моделей, описанных этим документом.
- **Details Shell (`DetailsHost`)** — переиспользуемая host-оболочка,
  не привязанная к форме данных конкретного типа (см. §4).
- **Renderer** — один из четырёх typed contracts: `ObjectOfferDetailsRenderer`,
  `RouteDetailsRenderer`, `ScenarioDetailsRenderer`, `CollectionDetailsRenderer`.
- **Object adapter** — компонент, преобразующий publication bundle
  конкретного Create-типа в typed public read-модель конкретного renderer
  contract (см. §9).
- **Section** — именованный, независимо включаемый/выключаемый блок
  контента внутри renderer (например «Расписание», «Локация»).
- **Primary action** — единственное основное CTA экрана, определяемое
  viewer-state resolver, а не creator-capability (см. §10, DTL-D11).
- **Secondary action** — вспомогательное действие (Save, Share, Report,
  Add to Scenario и т.д.), не занимающее sticky-слот.
- **Public read model** — типизированная, Discover-owned проекция,
  построенная adapter'ом из Create publication bundle; никогда не
  Create draft domain type напрямую.
- **Primary listing** — самостоятельный публикуемый объект или предложение
  (Place, Event, Activity, Session, Find People, Class/Workshop, Rental).
  Не обязан иметь единственную координату: может иметь точку, service area,
  online-режим, скрытый точный адрес или вовсе не иметь публичной геометрии.
- **Continuous route** — объект с непрерывной геометрией (Route): трек,
  anchors, elevation, POI по километражу.
- **Executable composition** — Scenario: упорядоченный, датируемый план из
  независимых остановок с логистикой, допускающий `Create my copy`.
- **Editorial composition** — Collection: курируемый, недатированный список
  ссылок на пять вечнозелёных Create-типов с секциями и заметками куратора.

## 3. Каноническое решение

```
DetailsHost
├── ObjectOfferDetailsRenderer   (Event, Activity, Place, Session,
│                                 Find People, Class/Workshop, Rental)
├── RouteDetailsRenderer         (Route)
├── ScenarioDetailsRenderer      (Scenario — target, заблокирован до
│                                 public Scenario projection)
└── CollectionDetailsRenderer    (Collection)
```

Явно фиксируется:

- Четыре движка **не означают** четыре полностью независимые UI-системы —
  все четыре размонтированы на общий `DetailsShell` (§4) и общий контракт
  состояний (§12).
- Десять Create-типов **не означают** десять Details-страниц — семь из
  десяти делят один `ObjectOfferDetailsRenderer` с тремя визуальными
  профилями (§5).
- Один общий shell **не означает** одну универсальную nullable-сущность —
  каждый renderer получает typed family read-модель, не расширение
  `DiscoverItemEntity` (§9, DTL-D02).
- Quick Plan не является пятым renderer'ом и не подключается к
  `DetailsHost` ни в каком виде: он не публикуется, не входит в каталог и
  не появляется в Discover ни при каких обстоятельствах (AGENTS.md,
  конфликт №6; LAUNCH_STATUS Current Domain Clarification;
  `SCENARIO_BUILDER_SPEC.md` v1.7).

## 4. Общий Details Shell

`DetailsShell` предоставляет переиспользуемые элементы всем четырём
renderer'ам:

- app bar (back, share, save/favorite);
- hero / media gallery (фото для Object/Offer и Collection; интерактивная
  карта для Route; multi-point карта для Scenario);
- title and taxonomy badge;
- publisher/trust block (имя, verified-статус, ссылка на профиль/страницу);
- save/share/report;
- loading/error/not-found состояния (§12);
- moderation/unavailable state (§12, DTL-D10);
- analytics (allowlist, §13);
- deep-link handling (§11);
- related content (площадка для «Похожие», «Добавить в сценарий» и т.п.);
- sticky action container (primary + до одной secondary action);
- responsive и accessibility поведение (§13).

Shell **не должен предполагать наличие**:

- координаты;
- одной даты;
- цены;
- одного publisher CTA;
- одного места;
- одного расписания.

Любое из перечисленного — забота конкретного renderer'а и его секций, не
shell'а. Renderer, которому нечего показать в секции, скрывает секцию
целиком, а не рендерит её в пустом/nullable виде.

## 5. Object / Offer Details

Один layout engine, `ObjectOfferDetailsRenderer`, для семи типов:

| Тип | Визуальный профиль | Нормативность в этом документе |
|---|---|---|
| Place | `venue` | Accepted (источник — Approved спека) |
| Event | `participation` | Accepted (источник — Accepted спека) |
| Recharge Activity | `participation` | Accepted (источник — Approved спека) |
| Find People | `participation` | Family membership Accepted; поля/секции/CTA — **Candidate** |
| Class / Workshop | `participation` | Family membership Accepted; поля/секции/CTA — **Candidate** |
| Bookable Session | `offer` | Family membership Accepted; поля/секции/CTA — **Candidate** |
| Rental / Equipment | `offer` | Accepted (источник — Approved спека) |

Три профиля — визуальные варианты одного renderer'а, не отдельные
страницы: они делят shell, секционный движок и state-машину; отличаются
только тем, какие секции обязательны/опциональны/запрещены и как
трактуется поле "место"/"время"/"цена".

### 5.1 Матрица по типам

Для типов со статусом Accepted матрица ниже нормативна. Для Session,
Find People, Class/Workshop — матрица описывает **целевое намерение**
(на основании их create-спек и, для Find People, готового §14.4/§14.5
блока) и остаётся Candidate до утверждения апстрим-документа; она не
блокирует §3–4, §9 этого документа.

| | Place (`venue`) | Event (`participation`) | Activity (`participation`) | Find People (`participation`, Candidate) | Class/Workshop (`participation`, Candidate) | Session (`offer`, Candidate) | Rental (`offer`) |
|---|---|---|---|---|---|---|---|
| Обязательные секции | hero, название, часы работы, adress/area | hero, дата/время, место, цена, publisher | hero, название, "куда идти", гибкое время | hero, дата/варианты времени, group size, publisher, safety notice | hero, дата/время, уровень, publisher | hero, доступные слоты, длительность, цена, publisher | hero, инвентарь/доступность, цена, pickup, publisher |
| Опциональные секции | удобства, фото-галерея | описание, highlights, схема программы | подсказки по доступу, «неофициальное место» | payment/cost split, co-hosts, conversation preview | оборудование, требования | буфер/notice window, отмена/перенос | залог, условия возврата |
| Запрещённые секции | одна дата начала, capacity | opening hours таблица | opening hours таблица, жёсткая capacity | точный адрес до одобрения (см. ниже) | opening hours таблица | opening hours таблица | opening hours таблица |
| Primary CTA | `Mark as visited` | `Join` / `Book for {price}` | `Save` / `Mark as done` | viewer-state-driven, см. §10.1 | `Join` / `Book` | `Book` | `Rent` |
| Secondary actions | Directions, Save, Report | Save, Share, Add to Scenario | Save, Add to Scenario | Save, Report, Contact host (после approval) | Save, Add to Scenario | Save, Add to Scenario | Save, Contact publisher |
| Availability representation | opening hours + exceptions | одна дата/время или recurrence | soft time-of-day чипы | occurrence-based слоты | одна дата/время или recurrence | typed availability calendar | typed availability calendar |
| Location policy | точный адрес публичен | публичный venue | публичное приблизительное место | публичная meeting area + мини-карта; точный адрес скрыт до approval | публичный venue | публичный venue/pickup | публичный pickup |
| Price policy | диапазон/typical spend | фиксированная цена/бесплатно | опционально, часто бесплатно | expected spend per person | цена участия | цена бронирования | цена + залог |
| Publisher policy | Place owner | User/Page `PublisherRef` | User/Page `PublisherRef` | автор запроса, verified badge | User/Page `PublisherRef` | User/Page `PublisherRef` | User/Page `PublisherRef` |
| Privacy/moderation | стандартная (§12) | стандартная (§12) | стандартная (§12) | точный адрес — privacy-gated отдельно от moderation (§12) | стандартная (§12) | стандартная (§12) | стандартная (§12) |
| Failure/fallback | `unavailable` при closed | `notFound`/`unavailable` (§12) | `notFound`/`unavailable` (§12) | полная CTA state-machine, §10.1 (14 viewer states) | `notFound`/`unavailable` (§12) | `notFound`/`unavailable`/slot-full | `notFound`/`unavailable`/no-stock |

Ни один из семи типов не обязан иметь точный публичный адрес — это
намеренно вынесено из «обязательных секций» (правка Этапа 1: «не делать
точный адрес обязательным для Object/Offer»).

## 6. Route Details

Отдельный renderer, `RouteDetailsRenderer`. Основой являются:

- интерактивная карта с track geometry (не фото-hero);
- start/end/loop semantics;
- distance и duration;
- difficulty;
- surface;
- elevation (full/partial/unavailable, без выдуманного нуля);
- anchors/POI;
- field verification badge;
- safety/reporting, встроенный в основной поток, не отдельной ссылкой;
- navigation/`Start route` action;
- GPX/offline возможности — только если соответствующий slice это разрешает.

Текущая карточка Route внутри общего Details
(`_PublishedRouteCard` в `discover_details_page.dart`) **не соответствует
предлагаемому target contract** и рассматривается как migration debt —
не потому, что нарушает принятую архитектуру (этот документ сам ещё
Draft, а не Accepted), а потому, что целевой Route renderer, описанный
выше, ещё не реализован.

## 7. Scenario Details

Отдельный renderer, `ScenarioDetailsRenderer`, для Scenario template.
**Уточнение видимости** (по Accepted `SCENARIO_BUILDER_SPEC.md` §5,
строки 494-509): в общей Discover-выдаче появляется только
`public`-Scenario, прошедший publish/moderation flow. `unlisted`
Scenario остаётся разновидностью личного плана — не появляется в
Discover-каталоге/поиске, открывается только по прямой ссылке владельца
через отдельный guarded link flow. `ScenarioDetailsRenderer` обслуживает
оба сценария открытия (из каталога для `public`, по прямой ссылке для
`unlisted`), но только `public` — предмет обычной Discover-навигации;
`unlisted` не проходит через canonical `/discover/details/...`
листинг/поиск, только через свою прямую ссылку.

- overview;
- days;
- ordered stops;
- time blocks;
- логистика между остановками;
- planned/not-live статус транспорта (никогда не выдаётся за live);
- estimated budget;
- publisher;
- `Create my copy` (соответствует `Use this scenario` из
  `SCENARIO_BUILDER_SPEC.md` §413);
- save/share;
- multi-point карта (`ScenarioGeoSummary`: primary location, centroid —
  уже специфицировано в `SCENARIO_BUILDER_SPEC.md` §673).

Явно отделяются:

- **reader-facing Scenario Details** (этот раздел) — просмотр чужого
  публичного/unlisted плана;
- **Scenario Builder** — редактор собственного плана автора;
- **личный Quick Plan** — вне Details System целиком (§3);
- **Route Details** (§6) — другой aggregate, другая геометрия.

Публикация Scenario (`SCN-PUB-01`) в LAUNCH_STATUS помечена
`Required / Planned`, реализация не начата. Весь этот раздел —
**target contract**, не текущее состояние: если публичный Scenario
появится в Discover раньше, чем `ScenarioDetailsRenderer` реализован,
это является нарушением этого документа, а не основанием тихо
рендерить Scenario через `ObjectOfferDetailsRenderer`.

## 8. Collection / Guide Details

Отдельный renderer, `CollectionDetailsRenderer`:

- editorial hero;
- короткое описание;
- publisher;
- area/budget;
- секции;
- упорядоченные item-карточки;
- заметки куратора;
- highlights;
- multi-point мини-карта;
- unavailable-item policy — **по Approved-контракту**
  `COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md` (line 919): пункт, ставший
  `unavailable`, **публично скрывается** из списка и с мини-карты без
  ошибки — читатель не видит битых карточек. Предупреждение по
  конкретному пункту и агрегированный сигнал по всей Collection видит
  только автор в своём редакторе (§3.10 источника), не публичный
  viewer. Это НЕ противоречит Details System — Details System просто
  никогда не видит `unavailable`-пункт в public read result, ему нечего
  скрывать на своей стороне;
- переход во вложенный объект — через canonical route (§11), поскольку
  вложенные типы (Place, Route, Bookable Session, Class/Workshop, Rental —
  пять вечнозелёных типов `CLG-CRT-01`) сами являются either
  `ObjectOfferDetailsRenderer`, either `RouteDetailsRenderer` targets.

Collection **не получает** фиктивные `startsAt`, `latitude`, `distanceKm`
или единый booking CTA — уже реализованный
`PublishedCollectionDiscoveryEntity`
(`apps/mobile/lib/features/discover/domain/entities/published_collection_discovery_entity.dart`)
служит здесь прямым, а не гипотетическим образцом: он typed, primitives-only
(enum'ы как plain string), и его собственный doc-комментарий прямо
фиксирует «Discover never imports `CollectionDraftData` or any other Create
domain type».

## 9. Read-модели

```
Create publication bundle
        ↓ adapter (boundary-compliant, integration/application слой)
Discover-owned public read model (typed family model)
        ↓
Details renderer
```

Требования (уточнено по правкам Этапа 1 — DTL-D02, DTL-D05):

- Discover не импортирует Create draft domain — ни напрямую, ни через
  transitively доступный тип.
- Никаких `Map<String, dynamic>` в контракте read-модели.
- `DiscoverItemEntity` остаётся **legacy point-feed read model**: она
  продолжает обслуживать существующие Search/Map/feed-поверхности для
  уже подключённых типов (Event, Activity, Place, Route-as-augmented) на
  время миграции и **не расширяется** дополнительными nullable-полями под
  Session/Find People/Class-Workshop/Rental/Scenario.
- Details System использует **typed family read-модели** — не
  обязательно один класс на каждый Create-тип. Допустима как per-type
  модель (`PublishedRentalDiscoveryEntity`), так и sealed union/одна
  family-модель на несколько типов одного визуального профиля
  (например, единая typed `ParticipationListingReadModel` для Event/
  Activity/Class-Workshop, если поля действительно совпадают по форме),
  при условии что каждый тип сохраняет собственную типизированную
  projection внутри family-модели без потери семантики.
- Publication → Discover projection выполняется **boundary-compliant
  adapter'ом** по уже существующему паттерну: `RoutePublicationDiscoveryAdapter`
  и `CollectionPublicationDiscoveryAdapter`
  (`apps/mobile/lib/app/adapters/`) — оба живут в `app/adapters/`, а не в
  `features/discover/` и не в `features/create/`, что уже совместимо с
  правилом 5 `ARCHITECTURE_BASELINE.md` («`features/*` must not import each
  other directly»). Новые адаптеры для Session/Find People/Class-Workshop/
  Rental/Scenario следуют тому же паттерну; допустимы как per-type, так и
  grouped family adapters — выбор физической структуры не фиксируется
  этим документом и остаётся на усмотрение конкретного `DTL-*` slice, пока
  сохраняется typed contract и отсутствие Create-domain импорта в Discover.
- Каждый тип имеет adapter в один из четырёх renderer contracts — не
  обязательно в отдельный файл.

## 10. Actions и capability policy

**DTL-D11 (обязательное разделение):** viewer CTA policy отделена от
creator authoring capabilities. Строки вида `create.rental`,
`submit.rental`, `publish.rental.direct`
(`RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md:202`) регулируют создание и
публикацию объекта его автором и **не являются основанием** для показа
viewer-действий `Rent`, `Book` или `Contact` читателю Details. Viewer CTA
availability определяется отдельным viewer-state resolver'ом (§10.1),
не пересечением с authoring capability set.

| Действие | Auth required | Capability (viewer) | Personal/Page scope | Moderation restriction | Execution | Unavailable/degraded |
|---|---|---|---|---|---|---|
| Open map | нет | — | — | — | internal | нет данных о месте → скрыть действие |
| Navigate | нет | — | — | — | external (deep link в карты) | нет координаты/area → скрыть |
| Join | да | базовая (authenticated User) | — | active moderation → hidden | internal | `Group full` / `Closed` |
| Request to join | да | базовая | — | active moderation → hidden | internal | см. §10.1 |
| Book | да | базовая | — | active moderation → hidden | internal (redirect на externalBookingUrl в MVP) | нет доступных слотов |
| Rent | да | базовая | — | active moderation → hidden | internal/external по `RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md` | нет доступного инвентаря |
| External booking | да | базовая | — | — | external | нет `externalBookingUrl` → скрыть, не заглушка |
| Save | да | базовая | — | — | internal | — |
| Add to Scenario | да | базовая (существующий `SCN-INTAKE-01`) | owner-scoped target | — | internal | — |
| Create my copy (Scenario) | да | базовая | новый private Scenario | — | internal | недоступно, пока §7 не реализован |
| Report | да | базовая | — | — | internal | — |
| Contact publisher | да | базовая, plus approval-gate для Find People (см. §5.1) | Personal/Page `PublisherRef` | точный контакт скрыт до approval | internal | — |

### 10.1 Пример richer CTA state-machine (Find People, Candidate)

Find People — единственный тип, чья CTA-логика уже полностью
специфицирована апстрим (`FIND_PEOPLE_CREATE_BLOCK_SPEC.md` §14.5, 14
viewer states: Guest/Автор/Eligible/Pending/Waitlisted/Seat-offered/
Invited/Accepted/Co-host/Rejected/Full/Cancelled/Hidden/Blocked). Этот
документ фиксирует, что подобная state-machine — легитимный паттерн
внутри `participation`-профиля, не нарушающий §3 (один общий renderer),
и не требует отдельного renderer'а. Точный список состояний остаётся
Candidate до утверждения `FIND_PEOPLE_CREATE_BLOCK_SPEC.md`.

## 11. Routing и совместимость

**DTL-D09 (пересмотрено во втором раунде).** `CatalogObjectRef` — **shared
app-level primitive**, не router-only тип:

```
CatalogObjectRef {
  objectType,   // стабильный taxonomy ID, см. список ниже
  objectId
}
```

Это не изобретение с нуля: Accepted `SCENARIO_BUILDER_SPEC.md` уже
независимо использует форму `{objectType: scenario, objectId}` для
Favorites (§строка про «Favorites хранит `{objectType: scenario,
objectId}` и не классифицирует Scenario как Route») и для Review — этот
документ обобщает уже принятый паттерн на остальные девять типов, не
придумывает новый. Поэтому `CatalogObjectRef` размещается как shared/app
primitive (используется Favorites, Collection, Notifications, Scenario
intake), не как тип, приватный для `app/router`.

`objectType` использует те же стабильные taxonomy ID, что и
`CreateObjectType.taxonomyId`
(`apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart`),
за вычетом `quick_plan`:

```
event
activity
route
place
session
scenario
find_people
class_workshop
rental
collection
```

**Публичный canonical deep link — не один универсальный URI для всех
типов.** Там, где у типа уже есть свой Accepted канонический deep link,
этот документ его не отменяет и не заменяет:

- **Scenario**: Accepted `SCENARIO_BUILDER_SPEC.md` (line 2118) уже
  фиксирует `recharge://scenario/{id}` как canonical deep link. Это
  остаётся публичным canonical URI Scenario. Типизированный Discover-путь
  `/discover/details/scenario/:id` — **внутренний app-route/alias**,
  который резолвит `recharge://scenario/{id}` в `CatalogObjectRef(scenario,
  id)` и открывает тот же общий `DetailsHost`; он не является новым
  публичным canonical URI, отменяющим принятый.
- **Остальные девять типов** (пока ни у одного нет собственного
  Accepted внешнего deep link contract) — `/discover/details/:objectType/:objectId`
  выступает публичным canonical route.

Если в будущем у другого типа появится собственный Accepted внешний
deep link (по аналогии со Scenario), тот же принцип применяется к нему:
типизированный Discover-путь становится внутренним alias, не заменой.

Текущие маршруты сохраняются **без изменений** этим документом:

```
/discover/details/:itemId
/collection/details/:collectionId
```

Их дальнейшая судьба (compatibility adapter бессрочно, частичная миграция
или итоговое удаление) не решается здесь — она требует отдельной принятой
compatibility policy и migration evidence на уровне `DTL-LINK-01`.

**Резолюция — application-layer ответственность, не presentation
registry.** Три ответственности разделены явно:

1. **Router** парсит URI (`objectType`/`objectId` из пути или alias-схемы
   вроде `recharge://scenario/{id}`) — ничего не резолвит сам.
2. **Application-layer резолвер** — `ResolveDetailsUseCase`, опирающийся
   на `DetailsLookupRegistry` (`objectType → DetailsLookupPort`,
   `DTL-LINK-01`) — загружает public projection через typed lookup ports
   и проверяет, что фактически найденный объект соответствует
   заявленному `objectType`; при несовпадении — безопасный `notFound`
   (§12), не последовательный перебор всех repository (источник
   enumeration leak).
3. **Presentation renderer registry** (из `DetailsShell`/`DetailsRenderer`,
   §4) только выбирает, каким renderer'ом отрисовать уже резолвленную
   typed projection — он не доказывает тип объекта и не обращается к
   repository напрямую.

Presentation registry, определённый в `DTL-FND-01`, **не является**
источником истины о фактическом типе хранимого объекта — он лишь
отображение «известный renderer family → виджет». Смешение этой роли с
резолюцией URL (как ошибочно предполагалось в первом черновике
`DTL-LINK-01`) — исправлено на уровне архитектуры, не только формулировки.

Остальные пункты:

- **Открытие объектов из Collection** — только через canonical route
  (`objectType` берётся из
  `PublishedCollectionItemRef.objectType`), не через отдельный
  Collection-specific deep link.
- **Favorites/Search/Map entry points** — существующие точки входа
  (`item.id` в Favorites, Search, Map) мигрируют на `CatalogObjectRef`
  в рамках `DTL-LINK-01`, не в этом документе.
- **Поведение неизвестного или удалённого объекта** — единая матрица §12
  (`notFound`), независимо от точки входа.

## 12. Состояния и ошибки

**DTL-D10.** Public Details **не наследует напрямую** `DraftStatus`,
`ModerationStatus` или внутренние причины недоступности из Create-домена
(`create_draft_entity.dart`: `DraftStatus {draft, pendingReview,
published, archived, hidden, deleted}`, `ModerationStatus {...}`). Эти
enum'ы — Create lifecycle, не публичный Details-контракт.

Viewer-facing resolver использует единый безопасный набор состояний:

```
available | temporarilyUnavailable | unavailable | notFound
```

Он **не раскрывает** viewer'у различие между `hidden`, `deleted`,
`moderation-blocked` и объектом, которого никогда не существовало —
там, где раскрытие создавало бы enumeration leak (например, различие
между «скрыто модерацией» и «не существует» может выдать информацию о
чужом контенте, к которому у viewer'а нет прав).

| Внутреннее (Create/Discover) | Публичное viewer-состояние |
|---|---|
| loading | `loading` (отдельно от четырёх выше, transient) |
| stale (Route/Scenario snapshot) | `available` + inline freshness badge, не отдельное состояние |
| partially available (частичная elevation/POI) | `available` + honest partial-data badge внутри секции |
| `draft`, `pending_review` | `notFound` |
| `published`, активная версия | `available` |
| `archived` | `unavailable` |
| `hidden` (moderation) | `notFound` (не `unavailable` — не подтверждать существование) |
| `deleted` | `notFound` |
| unsupported/future schema | `temporarilyUnavailable` |
| offline / no network | `temporarilyUnavailable` |
| external provider unavailable (Booking redirect, map tile) | секция помечается `temporarilyUnavailable`, не весь экран |
| nested Collection item unavailable | item публично скрывается из списка/мини-карты без ошибки (Approved `COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md:919`); видимый только автору в его редакторе, не public viewer'у. Collection целиком остаётся `available` |

## 13. Accessibility, localization и telemetry

Для каждого из четырёх renderer'ов обязательны:

- 360dp minimum width без переполнения;
- 150% text scale без потери контента;
- осмысленный screen reader order (hero → title → primary meta → CTA →
  секции), одинаковый по структуре для всех renderer'ов;
- keyboard/focus порядок, синхронный с screen reader order;
- контраст по существующим design tokens (`packages/design_system`);
- en/ru/lv-ready строки — локализация сейчас не настроена репозиторно
  (`AGENTS.md`, статус «Локализация en/ru/lv»: не настроена); Details
  System не создаёт новый локализационный долг сверх уже существующего,
  но обязана использовать строки, готовые к последующей экстракции, не
  захардкоженные предположения о языке.
- telemetry allowlist — enum/bucket-only события, без raw geo, private
  notes, booking-sensitive данных; по образцу уже принятого
  `scenario_transit_action`/`scenario_object_intake_action` allowlist
  паттерна.

## 14. Migration plan

1. Выделить `DetailsShell` из общих элементов текущего
   `DiscoverDetailsPage` без изменения поведения (`DTL-FND-01`).
2. Ввести canonical-resolver vertical (`CatalogObjectRef`, typed lookup
   registry, application-layer resolve use case) с loader'ами,
   оборачивающими уже существующие репозитории Event/Activity/Place/
   Route/Collection — до типизированных Object/Offer/Route-рендеров, а
   не после (`DTL-LINK-01`). Это устраняет необходимость во временных
   маршрутах на следующих шагах: любой новый renderer сразу
   регистрируется в уже существующем резолвере.
3. Не меняя поведения, перенести текущий Object/Offer-подобный Details
   (Event/Activity/Place) под `ObjectOfferDetailsRenderer` как есть;
   добавить typed adapter для Rental (первый Accepted/Approved тип без
   read-пути) через уже существующий резолвер шага 2, без временного
   маршрута.
4. Выделить `RouteDetailsRenderer`, заменив `_PublishedRouteCard`
   внутри общего экрана на отдельный renderer, зарегистрированный в том
   же резолвере.
5. Подключить Collection к общему `DetailsShell`, сохранив отдельный
   `CollectionDetailsRenderer` и уже существующую read-модель без
   переписывания.
6. Ввести typed Object/Offer adapters для Pending-типов (Session, Find
   People, Class/Workshop) по мере их апстрим-approval — без ожидания,
   что все три получат approval одновременно (`DTL-OBJ-02`+, не
   планируются здесь).
7. Добавить `ScenarioDetailsRenderer` только после появления **Approved
   typed publication/read-projection contract** `SCN-PUB-01` (не
   обязательно его runtime-реализации — см. `DTL-SCN-01`).
8. Сохранить legacy deep links (`/discover/details/:itemId`,
   `/collection/details/:collectionId`) и Accepted внешние canonical URI
   (`recharge://scenario/{id}`) рабочими на всём протяжении миграции.
9. Удалять старые ветки (`_PublishedRouteCard`, прямые untyped ссылки)
   только после migration evidence — зелёных analyzer/test/boundary
   проверок на конкретном `DTL-*` слайсе, не по этому документу.

## 15. Acceptance criteria

- Все 10 Create-типов отображены ровно один раз в маппинге §3/§5–8.
- Quick Plan явно исключён (§3, §7).
- Profile и Professional Page явно исключены (Non-goals).
- Четыре renderer contract описаны (§3, §6–8).
- Общий shell не предполагает наличие координаты, одной даты, цены,
  одного publisher CTA, одного места или одного расписания (§4) —
  формулировка синхронизирована с DTL-D12: «point object» не используется
  как эквивалент Object/Offer.
- У каждого из 7 Object/Offer-типов есть section/CTA матрица (§5.1), с
  явной пометкой Candidate для трёх Pending-типов.
- Current и target разделены везде, где они расходятся (§1, §6, §7).
- Capability и privacy boundaries определены, включая явное отделение
  viewer CTA от creator capability (§10, DTL-D11) и enumeration-safe
  состояния (§12, DTL-D10).
- Deep-link compatibility определена, включая non-authority статус
  `objectType` из URL (§11, DTL-D09).
- Rollback описан (§14, шаг 9).
- Нет runtime-изменений — этот документ и его принятие не составляют
  Approved slice spec сами по себе.

---

## Этап 3

**Спецификационный этап: Drafts created, implementation not started.**
Все перечисленные ниже документы существуют как `Draft for review —
Proposed implementation slice. Implementation not authorized.`; ни один
не Approved, ни один не начат в runtime.

Implementation order (пересмотрен в третьем раунде review — canonical
resolver должен существовать до typed renderer'ов, чтобы не заводить
временные маршруты на каждый новый тип):

1. `DTL-FND-01` — Details Shell и typed renderer foundation.
2. `DTL-LINK-01` — canonical resolver vertical (loader'ы для уже
   существующих Event/Activity/Place/Route/Collection) — до, не после
   типизированных рендеров.
3. `DTL-OBJ-01`, `DTL-RTE-01`, `DTL-CLG-01` — используют уже
   существующий резолвер из шага 2, без временных маршрутов.
4. `DTL-SCN-01` — после Approved `SCN-PUB-01` publication/read-projection
   contract (не обязательно его runtime).
5. `DTL-OBJ-0x` (не пронумерован) — follow-up для Pending-типов (Session,
   Find People, Class/Workshop) по мере апрува их апстрим-спек.

`DTL-OBJ-01` покрывает не весь Object/Offer, а только Phase 1: Place/
Event/Activity (визуальный паритет на новом рендере, legacy projection)
и Rental (первый typed read-путь). Полный typed target contract для
всех семи типов — предмет `DTL-OBJ-01` + будущего `DTL-OBJ-0x`
follow-up, не одного слайса.

Ни один из перечисленных документов не создаётся этим документом и не
имеет статуса Approved.

---

## Этап 4 — фактический статус реализации (2026-08-24)

Зафиксировано после staged-реализации в изолированном worktree
`dtl-fnd-01`, по прямой авторизации владельца продукта. Обновляется
здесь, а не переписывается задним числом в «Этап 3» — тот раздел
описывает исходный план, этот — что из него реально произошло.

| Slice | Статус | Коммит | Примечание |
|---|---|---|---|
| `DTL-FND-01` | **Done** — зелёные analyzer/test/boundary/diff gates | `7d4636d` | Details Shell + typed renderer foundation |
| `DTL-LINK-01` | **Done** — зелёные gates | `026c7cd` | Canonical resolver vertical; попутно перенесён read-side Collection (~14 файлов), отсутствовавший в git-истории ветки |
| `DTL-CLG-01` | **Done** — зелёные gates | `adb2d61` | Чистая shell-миграция Collection, без визуальной полировки |
| `DTL-RTE-01` | **Done** — зелёные gates | `7810a9e` | `RouteDetailsRenderer`; добавлен заголовок в тело (map-hero не даёт места под оверлей — не было в исходном file map, задокументировано в самом slice-документе) |
| `DTL-OBJ-01` | **Blocked on Rental Create prerequisite** | — | Не техническое «не начато» — реализация физически невозможна без отдельного prerequisite-захода (см. сам документ slice'а: стабилизировать/отделить/прогнать gates/закоммитить Rental Create в исходном checkout, только затем возвращаться) |
| `DTL-SCN-01` | **Blocked on Approved `SCN-PUB-01`** | — | Без изменений с Этапа 3 — ждёт апстрим publication/read-projection contract |

Каждый Done-slice прошёл `flutter analyze --no-pub` (0 замечаний),
`flutter test --no-pub` (полный suite, единственный неродственный
провал — заранее задокументированный golden-baseline
`route_create_block_test.dart`), boundary gate (71/71, 0 нарушений) и
`git diff --check` — по отдельности, каждый на своём коммите, не одним
общим слайсом.
