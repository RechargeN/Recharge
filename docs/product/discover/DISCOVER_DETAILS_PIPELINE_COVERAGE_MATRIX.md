# Discover Details Pipeline — cumulative cross-type coverage matrix

- Версия аудита: v2 (2026-08-24) — пересмотр после staged-реализации
  `DTL-FND-01`/`DTL-LINK-01`/`DTL-CLG-01`/`DTL-RTE-01` (все Done,
  зелёные gates, отдельные коммиты) и обнаруженной блокировки
  `DTL-OBJ-01`. v1 (тот же день, раньше) измеряла отставание до
  реализации; см. «Что изменилось в v2» перед §1.
- Статус: **Audit — documentation only; no runtime claim; не отменяет ни
  одного Accepted решения**
- Канон: [DISCOVER_DETAILS_SYSTEM_SPEC.md](DISCOVER_DETAILS_SYSTEM_SPEC.md)
  v0.3 (Accepted) — целевая архитектура, которой этот аудит измеряет
  фактическое отставание; см. её Этап 4 для статуса slice'ов
- Следующий gate: не блокирует ничего сам по себе; используется для выбора
  очерёдности следующей работы (см. §3 «Синтез»)

## Что изменилось в v2

1. **Route Details — P → I.** `DTL-RTE-01` реализован и закоммичен
   (`7810a9e`): `RouteDetailsRenderer` с интерактивной картой,
   elevation summary, difficulty/surface/POI/field-verified как
   первоклассными секциями. Это не bolt-on поверх generic карточки —
   целевой контракт §6 родительского документа реально выполнен для
   Route.
2. **Collection Details — источник обновлён**, статус остаётся I:
   `CollectionDetailsPage` теперь на `DetailsShell`/
   `CollectionDetailsRenderer` (`DTL-CLG-01`, `adb2d61`) вместо
   собственного `Scaffold` — тот же визуал, другая оболочка.
3. **Event/Activity/Place Details — источник обновлён**, статус
   остаётся I (legacy projection, не целевой контракт): рендерятся
   через `CompatibilityObjectRenderer` под новым `DetailsShell`
   (`DTL-FND-01`, `7d4636d`), диспетчеризуемым через canonical resolver
   (`DTL-LINK-01`, `026c7cd`). Визуально и функционально не изменились
   — только оболочка.
4. **Rental Details — оба prerequisite'а резолвлены 2026-08-24**:
   Rental Create git-hygiene prerequisite стабилизирован, отделён от
   Session/LocationSearch, прогнан через полный gate suite и смёржен в
   Details-ветку (см. `RENTAL_CREATE_STABILIZATION_PLAN.md` §8). Найден
   и закрыт тем же днём второй, отдельный блокер — Rental publication
   lifecycle (`sink.activate(...)` требует `published`-only state,
   а generic publish-путь всегда давал `pending_review`) — `RNT-PUB-01`
   реализован и Done (trusted local/mock direct-publish policy, см.
   `DTL_OBJ_01_OBJECT_OFFER_ENGINE_SLICE_SPEC.md` v0.6). `DTL-OBJ-01` —
   Approved/in progress, ни git-гигиена, ни publication lifecycle
   больше не блокируют реализацию. См. также раздел
   «Git-committed-status как отдельная ось» ниже.
5. **Синтез (§3) переписан** под текущий расклад: Details-волна
   решена для 4 из 10 типов; оставшиеся два «shovel-ready» кандидата
   (Rental, Scenario) заблокированы **разнородными** причинами
   (git-гигиена vs апстрим product-decision), не одной и той же
   очередью.

## Git-committed-status как отдельная ось (обнаружено 2026-08-24)

Все строки этой матрицы измеряют «фактическое runtime-состояние» по
коду, доступному аудитору на момент проверки — не различая, закоммичен
ли этот код в текущую рабочую ветку. Реализация `DTL-*` slice'ов
происходит в изолированных git-worktree, которые видят только
**закоммиченную** историю. Обнаружено: Collection (весь read-side) и
Rental (весь Create) физически отсутствовали в истории ветки
`codex/map-main-ui-s3-logic`, существуя только как незакоммиченные
изменения в исходном checkout. Для Collection это было устранимо
точечным переносом (~14 файлов, отдельный коммит перед `DTL-LINK-01`).
Для Rental — нет: правка `CreateController` вперемешку с Session/
Location Search и другими незакоммиченными фичами (~1368 строк diff,
304 вхождения `Rental`) сделала перенос непроверяемым без отдельного
prerequisite-захода (см. `DTL_OBJ_01_OBJECT_OFFER_ENGINE_SLICE_SPEC.md`
и Этап 4 родительского документа). Это не отражено как отдельная
колонка в таблицах ниже (методология §1 её не предполагает), но
существенно для приоритизации: **тип может выглядеть «I» по коду в
исходном checkout и одновременно быть недостижим для любого `DTL-*`
slice, работающего в изолированной ветке**, пока его авторский код не
закоммичен отдельно и самостоятельно.

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
| Details | I | `ObjectOfferDetailsRenderer` (`participation`-профиль делегирует в `CompatibilityObjectRenderer`, `DTL-OBJ-01`, Done) | — |
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
| Details | I | `ObjectOfferDetailsRenderer` (`participation`-профиль делегирует в `CompatibilityObjectRenderer`, `DTL-OBJ-01`, Done) | — |
| Primary action | P | generic "Join activity" | Нет специфичной механики |
| Lifecycle | P | — | Repo-wide gap |

### 2.3 Route

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | P | `ROUTE_BUILDER_SPEC.md` v3.2; RTE-01–07 Done, RTE-08–11 Review | Реальная device-верификация GPS/GPX не пройдена |
| Publish | I | RTE-07 | Самый зрелый publish-flow из десяти |
| Feed | P | RTE-08: «default feed does not load Routes» | Осознанно вне дефолтной ленты |
| Search | I | RTE-08 | — |
| Map | I | `buildPublishedRoutePolyline` — чистая функция, теперь общая для Map и Details hero (`DTL-RTE-01`) | — |
| Details | **I** | `RouteDetailsRenderer` (`DTL-RTE-01`, `7810a9e`) — интерактивная карта, elevation summary, difficulty/surface/POI/field-verified первоклассными секциями | Целевой контракт §6 выполнен для этого slice; elevation-график и public GPX-export осознанно не в scope (нет source-данных/отдельный будущий slice) |
| Primary action | P | Safety report (в основном потоке) + navigation в Discover Map — оба I (`DTL-RTE-01`) | Turn-by-turn/внешнее приложение/GPX-кнопка — сознательно вне scope, не разрыв |
| Lifecycle | I | RTE-07/09 | Самый зрелый lifecycle из десяти |

### 2.4 Place

| Стадия | Статус | Источник | Ближайший разрыв |
|---|---|---|---|
| Create | I | `PLACE_CREATE_BLOCK_SPEC.md` v1.0 (Approved); PLC-ADP-01; LOC-SRCH-01 | — |
| Publish | P | — | Capability gate не подтверждена |
| Feed | I | `objectKind.place` | — |
| Search | I | — | — |
| Map | I | — | — |
| Details | I | `ObjectOfferDetailsRenderer` (`venue`-профиль делегирует в `CompatibilityObjectRenderer`, `DTL-OBJ-01`, Done) | — |
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
| Feed | I | `RentalPublicationIndexSink`/`PublishedRentalDiscoveryPort`/`RentalPublicationDiscoveryAdapter` (`DTL-OBJ-01`, Done) | Только Details-путь; Search/Map ленты Rental не покрывает этот slice |
| Search | M | — | Rental не участвует в `DiscoverQuery` search/filter пути |
| Map | M | — | Rental не участвует в map-слое |
| Details | I | `ObjectOfferDetailsRenderer.rental`/`RentalDetailsPage` (`DTL-OBJ-01`, Done) — первый Details-рендеринг этого типа | Availability tri-state (declared/unavailable/unknown, спека §8.3) не в `RentalListing`/проекции — показывается только статичное «Creator-declared» уведомление |
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
| Details | I | `CollectionDetailsPage` + `CollectionDetailsRenderer` под `DetailsShell` (`DTL-CLG-01`, `adb2d61`) | Визуально черновой (собственное признание LAUNCH_STATUS) — `DTL-CLG-01` намеренно чистая shell-миграция, не визуальная полировка |
| Primary action | N/A (by design) | `DTL-CLG-01` AC-10 | Не разрыв — сознательное решение, у Collection нет единого booking-CTA |
| Lifecycle | I | `removeItemsFromActiveVersion`, asymmetric moderation | — |

## 3. Синтез: что дальше после Details-волны (v2)

Правый край матрицы (Details/Primary action/Lifecycle) теперь реально
закрыт для **4 из 10 типов** — Event/Activity/Place (legacy projection,
не целевой контракт) и Route (целевой контракт, `DTL-RTE-01`) через
общий `DetailsShell`, плюс Collection на своей отдельной странице
(`DTL-CLG-01`). Это не было так в v1 этого документа: Route и Collection
были «наименее рискованные следующие слайсы» — теперь они сделаны, и
именно это меняет вывод раздела.

Оставшиеся два «полностью спроектированных, ноль кода» типа —
**Rental** и **Scenario** — заблокированы **разными по природе**
причинами, которые не решаются одним и тем же следующим шагом:

1. **Rental (`DTL-OBJ-01`)** — блокировка **git-гигиены**, не продукта
   и не архитектуры: Create-сторона физически отсутствует в истории
   Details-веток (~1368 строк diff в `CreateController`, 304 вхождения
   `Rental`, вперемешку с Session/Location Search). Спека Approved и
   готова к реализации в тот момент, когда committed Rental Create
   появится отдельным, чистым коммитом — это **инженерная
   stabilization-задача вне Details-волны** (см. prerequisite-план в
   `DTL_OBJ_01_OBJECT_OFFER_ENGINE_SLICE_SPEC.md`), не ещё один
   `DTL-*` slice в текущем смысле.
2. **Scenario (`DTL-SCN-01`)** — блокировка **product-decision**:
   `SCN-PUB-01` publication/read-projection contract ещё не Approved
   апстрим. Это решение владельца продукта, не инженерная задача —
   `DTL-SCN-01` не имеет смысла продвигать, пока оно не сдвинется.

Оба блокера — вне scope дальнейшей Details-инженерии прямо сейчас: для
Rental нужен отдельный prerequisite-заход (не Details-код), для
Scenario — решение вне engineering. **Следующая осмысленная `DTL-*`
Details-работа не существует, пока хотя бы один из двух блокеров не
снят.**

Это смещает то, где стоит искать следующий приоритет продукта:

3. **Event/Activity/Place** остаются на устаревшей общей
   `DiscoverItemEntity`-проекции (Phase 1 `DTL-OBJ-01`, тоже
   заблокирован тем же Rental-prerequisite'ом — секционная матрица
   `DTL-OBJ-01` покрывает все четыре типа одним slice'ом, включая эти
   три). Работают достаточно, чтобы не быть срочным риском, но их путь
   к целевой архитектуре идёт через тот же заблокированный slice.
4. **Session, Find People, Class/Workshop** — единственные три типа, чей
   разрыв **не** в Details, а на несколько стадий раньше (Create/
   Publish/Feed для Session и Class/Workshop; Find People чуть дальше —
   Publish есть, Feed/Search/Map ещё нет). Это значит: даже если бы
   Rental- и Scenario-блокеры снялись завтра, у этих трёх всё равно
   нет Details-slice'а, который имело бы смысл писать — сначала нужен
   апстрим-approval их Create-спек (`BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md`,
   `CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md` — оба ещё не Accepted) и
   типизированный adapter в `DiscoverObjectKind`/`DetailsLookupRegistry`
   раньше, чем Details вообще становится applicable темой для них.
   Find People — самый готовый к спецификации из трёх (готовый
   §14.4/§14.5 viewer-state контент), но всё ещё без Feed/Search/Map.

**Итог:** следующий продуктовый приоритет сейчас — не выбор между
`DTL-*` slice'ами (очередь для Details пуста, пока оба блокера открыты),
а выбор **между тремя параллельными, независимыми треками**:
(a) инженерная stabilization Rental Create (разблокирует `DTL-OBJ-01`
для 4 типов сразу — самый дешёвый по объёму нового кода, раз спека уже
Approved); (b) продуктовое решение по `SCN-PUB-01` (разблокирует
`DTL-SCN-01`, единственный полностью спроектированный, готовый к
approval документ); (c) продвижение апстрим Create-спек для Session/
Find People/Class-Workshop (открывает Details как тему для них
впервые — сейчас у них нет активного разрыва в Details конкретно, есть
разрыв на более ранних стадиях). Ни один из трёх треков не является
дальнейшей Details-инженерией в текущем понимании этого документа.

Этот документ не создаёт и не авторизует ни один `DTL-*` слайс и не
выбирает между (a)/(b)/(c) — он только фиксирует основание, по которому
это решение принимается.
