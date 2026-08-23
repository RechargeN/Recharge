# Discover Details Pipeline — cumulative cross-type coverage matrix

- Версия аудита: 2026-08-24
- Статус: **Audit — documentation only; no runtime claim; не отменяет ни
  одного Accepted решения**
- Канон: [DISCOVER_DETAILS_SYSTEM_SPEC.md](DISCOVER_DETAILS_SYSTEM_SPEC.md)
  v0.2 (Draft for review) — целевая архитектура, которой этот аудит
  измеряет фактическое отставание
- Следующий gate: не блокирует ничего сам по себе; используется для выбора
  очерёдности `DTL-*` slice'ов (см. §3 «Синтез»)

## 1. Назначение и правила оценки

Матрица фиксирует фактическое runtime-состояние всех 10 Create-типов по
восьми стадиям конвейера (`Create → Publish → Feed → Search → Map →
Details → Primary action → Lifecycle`) на момент аудита и отделяет
реализованный mock/local runtime от продуктовой спеки, которая его лишь
описывает. Наличие спеки, enum'а или файла не доказывает, что стадия
реально проходима пользователем.

Статусы:

- **I — Implemented:** стадия реально проходима в mock/local runtime;
- **P — Partial:** полезное подмножество работает, полный канонический
  контракт стадии — нет;
- **S — Specified only:** контракт стадии описан в Accepted/Draft спеке
  или отдельном `DTL-*` документе, runtime-кода нет;
- **M — Missing:** ни спеки, ни кода для этой стадии у этого типа нет;
- **B — Blocked:** стадия намеренно недостижима до отдельного gate
  (не технический долг, а осознанное решение).

`I` относится только к описанному scope стадии — Implemented Create для
Rental не означает Implemented Details для Rental.

## 2. Матрица по типам

### 2.1 Event

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | P | `EVENT_CLASSIFICATION_SPEC.md` v2.2.3 (Accepted); EVT-CRT-01 | Реализован C0+schedule-C1, не полные 34 архетипа |
| Publish | P | ECL-01/02 | Creator-capability gate на publish не выведен (repo-wide) |
| Feed | I | `discover_item_entity.dart` (`objectKind.event`) | — |
| Search | I | `SEARCH_FILTERS_TIME_SPEC.md` | — |
| Map | I | `discover_map_page.dart` | — |
| Details | I | `discover_details_page.dart` (generic) | Типизированный `participation`-профиль не построен (DTL-OBJ-01 Draft) |
| Primary action | P | AGENTS.md: MVP redirect на `externalBookingUrl` | Authoritative Booking backend не авторизован (ECL-03C-P — план) |
| Lifecycle | P | ADR 0013 | Admin moderation queue не подтверждена как enforced |

### 2.2 Recharge Activity

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | I (mock) | `RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md` v1.4 (Approved); ACT-CRT-01 (Review) | Idempotency-ключ без `PublisherRef`/`actionKind` (cross-type) |
| Publish | P | ACT-CRT-01 | Capability gate не выведен |
| Feed | I | `objectKind.activity` (дефолт) | — |
| Search | I | тот же `DiscoverQuery` | — |
| Map | I | — | — |
| Details | I | generic `discover_details_page.dart` | Нет типизированного `participation`-профиля |
| Primary action | P | generic "Join activity" | Нет специфичной механики |
| Lifecycle | P | — | Repo-wide gap |

### 2.3 Route

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | P | `ROUTE_BUILDER_SPEC.md` v3.2; RTE-01–07 Done, RTE-08–11 Review | Реальная device-верификация GPS/GPX не пройдена |
| Publish | I | RTE-07 | Самый зрелый publish-flow из десяти |
| Feed | P | RTE-08: «default feed does not load Routes» | Осознанно вне дефолтной ленты |
| Search | I | RTE-08 | — |
| Map | I | `_buildPolylines` (Published-Route ветка) | — |
| Details | P | `_PublishedRouteCard` bolt-on в generic странице | Целевой `RouteDetailsRenderer` — S (`DTL-RTE-01` Draft) |
| Primary action | P | safety report/GPX import есть | Навигация — S, не turn-by-turn |
| Lifecycle | I | RTE-07/09 | Самый зрелый lifecycle из десяти |

### 2.4 Place

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | I | `PLACE_CREATE_BLOCK_SPEC.md` v1.0 (Approved); PLC-ADP-01; LOC-SRCH-01 | — |
| Publish | P | — | Capability gate не подтверждена |
| Feed | I | `objectKind.place` | — |
| Search | I | — | — |
| Map | I | — | — |
| Details | P | generic + 1 action-tile | Нет `venue`-профиля как первоклассных секций |
| Primary action | I | `VIS-HIST-01` Done | — |
| Lifecycle | P | — | Repo-wide gap |

### 2.5 Bookable Session

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | I (mock) | `BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md` v1.1 — **Draft for review**; SES-CRT-01 | Апстрим-документ не Accepted |
| Publish | M | — (нет `create.session`-подобных capability строк) | Нет типизированного publish-пути |
| Feed | M | нет `session` в `DiscoverObjectKind` | — |
| Search | M | — | — |
| Map | M | — | — |
| Details | M | Candidate по родительскому документу §5.1 | `DTL-OBJ-0x` не начат |
| Primary action | M | — | Booking CTA нигде не достижим |
| Lifecycle | M | — | Публичного lifecycle нет |

### 2.6 Scenario

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | I | `SCENARIO_BUILDER_SPEC.md` v1.7 (Accepted); SCN-SB-00–04, AI-01, LV-DATA, INTAKE-01 | — |
| Publish | **M** | `SCN-PUB-01` — Required/Planned | **Единственная блокирующая точка типа** |
| Feed | M | — | Заблокировано публикацией |
| Search | M | — | Заблокировано публикацией |
| Map | P | `_ScenarioMapRoute` — визуализация **собственного** черновика | Не публичный объект |
| Details | B | `DTL-SCN-01` — явно Blocked | Ждёт Approved `SCN-PUB-01` contract |
| Primary action | S | `SCENARIO_BUILDER_SPEC.md` §2113 (`Use this scenario`) | Нечего вызывать без публикации |
| Lifecycle | S | `enum ScenarioVisibility` §512 | Определён, не подключён |

### 2.7 Find People

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | I (mock) | `find_people_create_block.dart`, зарегистрирован в `create_page.dart:230` | — |
| Publish | P | `validate_find_people_draft_usecase.dart` | Нет подтверждённого capability-gated publish |
| Feed | M | нет `find_people` в `DiscoverObjectKind` | — |
| Search | M | спека ссылается на `DiscoverQuery v3` | Non-goal родительского документа |
| Map | M | — | — |
| Details | M | Candidate §5.1 | `DTL-OBJ-0x` не начат |
| Primary action | S | `FIND_PEOPLE_CREATE_BLOCK_SPEC.md` §14.5 — 14 viewer-states | Ноль runtime, но самый готовый к спецификации кандидат |
| Lifecycle | S | §entityStatus/moderationStatus/recruitmentStatus | Не подключено |

### 2.8 Class / Workshop

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | M | `CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md` v1.1 — «Ready for approval» | Нет `class_workshop_create_block.dart`, только generic engine |
| Publish | M | — | — |
| Feed | M | — | — |
| Search | M | — | — |
| Map | M | — | — |
| Details | M | — | — |
| Primary action | M | — | — |
| Lifecycle | M | — | — |

Наименее развитый тип из десяти — нет специализированной реализации ни на
одной стадии.

### 2.9 Rental / Equipment

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | I | `RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md` v1.0 (Approved); RNT-CRT-01 | — |
| Publish | I | capability-строки `create.rental`/`submit.rental`/`publish.rental.direct` | Только `externalBookingUrl`, без `contact_host` (принятый trade-off) |
| Feed | M | нет discover-адаптера в runtime | `DTL-OBJ-01` Draft, не Approved |
| Search | M | — | — |
| Map | M | — | — |
| Details | **S** | `DTL_OBJ_01_OBJECT_OFFER_ENGINE_SLICE_SPEC.md` — полный write+read vertical спроектирован | Ноль кода, но самый «shovel-ready» разрыв из всех |
| Primary action | S | `Rent` CTA в §5.1 родительского документа | — |
| Lifecycle | P | `moderationStatus` в Create-драфте | Discover-facing lifecycle недостижим без read-пути |

### 2.10 Collection / Guide

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | I | `COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md` v1.0 (Approved); CLG-CRT-01 | — |
| Publish | I | идемпотентный publish, asymmetric moderation | — |
| Feed | P | отдельная секция «Guides» (`CollectionDiscoverSection`) | Не unified ranking с point-object лентой (осознанно отложено) |
| Search | M | не интегрирован в `DiscoverQuery` | — |
| Map | P | своя мини-карта на Details | Не маркеры на основной Discover Map |
| Details | I | `CollectionDetailsPage` | Визуально черновой (собственное признание LAUNCH_STATUS) |
| Primary action | N/A (by design) | `DTL-CLG-01` AC-10 | Не разрыв — сознательное решение, у Collection нет единого booking-CTA |
| Lifecycle | I | `removeItemsFromActiveVersion`, asymmetric moderation | — |

## 3. Синтез: приоритизация следующих `DTL-*`

1. **Route и Collection** — единственные два типа с почти полным правым
   краем матрицы (Details/Primary action/Lifecycle). Подтверждает, что
   `DTL-RTE-01`/`DTL-CLG-01` — наименее рискованные следующие слайсы:
   почти всё переиспользуется, мало нового пишется с нуля.
2. **Rental** — единственный тип, где весь Discover-разрыв уже полностью
   спроектирован (`DTL-OBJ-01`), но не реализован. Самый дешёвый
   следующий шаг по соотношению «спроектировано/написано».
3. **Event/Activity/Place** — Feed/Search/Map/Details формально
   Implemented, но только через устаревшую общую `DiscoverItemEntity`.
   Подтверждает пометку `DTL-OBJ-01` как **Phase 1**, не Done: работают
   достаточно, чтобы не быть срочным приоритетом, но не на целевой
   архитектуре.
4. **Scenario** — ровно одна блокирующая точка (`SCN-PUB-01`), от
   которой зависит весь остальной ряд. `DTL-SCN-01` не имеет смысла
   продвигать дальше документа, пока она не сдвинется.
5. **Session, Find People, Class/Workshop** — почти пустой правый край
   у всех трёх, но с разной готовностью к спецификации: Find People уже
   имеет готовый §14.4/§14.5 контент (не Accepted, но написан); Session
   и особенно Class/Workshop — нет даже черновика такого объёма.

Этот документ не создаёт и не авторизует ни один `DTL-*` слайс — он
только фиксирует основание, по которому их очерёдность выбирается.
