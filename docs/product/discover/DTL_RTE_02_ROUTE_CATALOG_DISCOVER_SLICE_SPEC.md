# RECHARGE — DTL-RTE-02: Route из Catalog в Discover и Details

- Версия: v0.2 (2026-10-22). Статус: **Approved — RD-01…RD-12 утверждены
  владельцем 2026-10-22 по рекомендациям** («Утверждаю RD-01…RD-12 по
  рекомендациям DTL-RTE-02. Продолжай по плану, без commit, push и deploy.»).
  Реализация принята владельцем 2026-10-22 в local/Emulator объёме
  («Принимаю DTL-RTE-02 в local/Emulator объёме. Без push и deploy.»).
- База: локальная `codex/recharge-integration` `a568b49` (J2 Done в
  local/Emulator объёме). Рабочая ветка: `claude/j2-route-publication`.
- Источник требования: RTE-PUB-01 RP-15
  ([контракт J2](../route/ROUTE_J2_PUBLICATION_BCK11_AMENDMENT.md) §3, §9) —
  показ опубликованного Route в mobile выделен в отдельный DTL-slice.
- Родители: [DISCOVER_DETAILS_SYSTEM_SPEC.md](DISCOVER_DETAILS_SYSTEM_SPEC.md)
  v0.3 §6, §11; [DTL-RTE-01](DTL_RTE_01_ROUTE_DETAILS_SLICE_SPEC.md);
  [DTL-LINK-01](DTL_LINK_01_DEEP_LINK_MIGRATION_SLICE_SPEC.md); BCK08-OD-04-R
  (Catalog family `route`).

## 0. Исходное состояние (зафиксировано 2026-10-22)

| Что | Факт |
|---|---|
| Ветки | `codex/recharge-integration` = `claude/j2-route-publication` = `a568b49`; оба checkout чистые |
| Backend | Catalog family `route`: карточка (старт trimmed-трека, сводка, превью ≤256 точек), Map leaf с превью, Details с полным trimmed-треком и waypoints (`catalog-route-projection-v1`) |
| Mobile Discover | `CatalogDiscoverRepository` знает только `event`, `activity`, `find_people`; `typeIds` без `route`; `CatalogDetails` отклоняет `route` как неизвестный тип |
| Mobile Route Details | `RouteDetailsRenderer` (DTL-RTE-01) рисует только `PublishedRouteDiscoveryEntity` — локальную проекцию RTE-07/08 |
| Почему DTL-RTE-01 не закрывает J2 | Сущность RTE-08 требует `durationSeconds > 0`, `bounds` и одну `fullEncodedPolyline`. В публичном снимке J2 длительности нет, bounds не публикуются (RP-03), трек — несколько сегментов с явными разрывами |
| Прежние проверки | J1/J2 evidence (`ROUTE_J1_VERIFICATION.md`, `ROUTE_J2_VERIFICATION.md`) — исторические; новые прогоны этого slice записываются отдельно |

## 1. Что не меняется

- Один Route aggregate (BCK-11) и один publication writer (BCK-07). Mobile
  получает только публичную проекцию Catalog, ничего не хранит и не пишет.
- Локальный путь RTE-07/08 и `PublishedRouteDiscoveryEntity` не меняются и
  работают, пока Catalog-вход выключен.
- Нет выдуманных значений: длительности, bounds, сложности, покрытия, числа
  POI в публичном снимке нет — значит, их нет и на экране.
- Нет Scenario handoff и `RouteMode`; Route в Scenario остаётся
  заблокированным (SP-08).

## 2. Решения на утверждение

Спорность: **Высокая** — есть разумная альтернатива с другими последствиями;
**Низкая** — следует из принятых документов.

| ID | Вопрос | Рекомендация | Альтернатива | Спорность |
|---|---|---|---|---|
| RD-01 | Клиентская модель | Новые read-only факты `RouteCatalogFacts` на `DiscoverItemEntity` — по образцу `activityCatalog`. Поля: revision, shape, профиль, категория, сводка (distance; ascent/descent/min/max — nullable; segments, gaps), число direct-сегментов, старт, превью-сегменты; в Details дополнительно полный trimmed-трек и waypoints (тип, название, safetyNote, точка, расстояние от старта), тип publisher. Ни duration, ни bounds. Хранилища нет | Расширить `PublishedRouteDiscoveryEntity` необязательными полями — смешивает модель RTE-07 с Catalog и ломает её инвариант coherence | Средняя |
| RD-02 | Renderer | Один `RouteDetailsRenderer`, который строит presentation-модель `RouteDetailsView` из одного из двух источников; секции без данных не показываются | Отдельный `CatalogRouteDetailsRenderer` — дублирует экран | Средняя |
| RD-03 | Геометрия | Каждый сегмент — отдельная линия; разрывы не соединяются. Direct-сегменты (`intentionalDirect`/`fallbackDirect`) — пунктиром с подписью «прямой участок». Декодирование — точность 7, тот же формат, что у сервера | Склеить сегменты в одну линию — скрывает разрывы, отклоняется контрактом J2 | Низкая |
| RD-04 | Карточка и Map | Карточка: название, краткое описание, расстояние, набор высоты (если есть), категория, «прямых участков: N» (если N > 0). Map: точка старта; у выбранного Route — превью-линии. Камера карты вписывается по точкам превью — это вычисление на клиенте для показа, не публикуемое поле | Карточка без превью (только текст) | Средняя |
| RD-05 | Когда Route попадает в ленту | Как в RTE-08: дефолтная лента без Route; `route` добавляется в `typeIds`, когда запрос явно про маршруты (route-intent Smart Search, категория/подкатегория маршрута, переход «маршруты рядом»). Фильтры цены и времени Route не проходит — сервер возвращает его как неподходящий, клиент это не скрывает и не подменяет | Route в дефолтной ленте всегда | Высокая |
| RD-06 | Включение | Отдельный define `RECHARGE_TEST_ROUTE_CATALOG` поверх `RECHARGE_TEST_DISCOVER_CATALOG`, те же четыре условия; на сервере — та же env-переменная. Выключено по умолчанию; без него работает локальный путь RTE-08 | Включать вместе с Discover Catalog | Низкая |
| RD-07 | Актуальность | Details каждый раз читает Catalog заново по snapshot списка. `changedSinceSnapshot` → состояние «Маршрут обновился» с кнопкой «Обновить» (как Activity). `excluded`/`absent` (снят автором, ограничен модератором, удалён) → одно состояние «Маршрут недоступен», без причины. Ответ на устаревший запрос (другой contentId или поколение запроса) отбрасывается; после обновления списка выбранный на карте Route сбрасывается, если исчез | Показывать причину скрытия зрителю | Средняя |
| RD-08 | Offline и сбой транспорта | Состояние «Нет связи» с повтором; геометрия не кешируется, старая версия не показывается | Кешировать последний ответ для offline | Высокая |
| RD-09 | Действия | Есть: «Открыть на карте», «Поделиться» (deep link `route/{contentId}` через DTL-LINK-01), «Сохранить» — существующее избранное по ссылке без геометрии. Нет: «Добавить в Scenario» (SP-08), «Отметить посещённым» (Visit History — только Place), жалоба (у mobile нет пути жалобы на Catalog-объект — отдельный slice K1), GPX-экспорт | Показать жалобу как локальную, как у RTE-07 | Средняя |
| RD-10 | Privacy клиентской модели | Парсер wire — точный allowlist: всё, чего нет в RD-01, не попадает в модель. Тесты проверяют отсутствие приватных маркеров во всём, что видит UI | — | Низкая |
| RD-11 | Publisher | Показывается только тип: «Автор» или «Страница». Имени нет — в Catalog его нет, подтягивать профиль — отдельная задача | Загрузить публичное имя Page | Средняя |
| RD-12 | Числа | Расстояние — км с одним знаком; высоты — целые метры; отсутствующая метрика не показывается и никогда не становится 0 | — | Низкая |

## 3. Состояния экрана Details

| Состояние | Когда | Что видит пользователь |
|---|---|---|
| Загрузка | запрос Details идёт | скелет shell |
| Доступен | `listed`, revision совпадает | карта с сегментами, сводка, waypoints, действия RD-09 |
| Обновился | `changedSinceSnapshot` | «Маршрут обновился» + «Обновить» |
| Недоступен | `excluded`/`absent`, неизвестный id, deep link на скрытый Route | «Маршрут недоступен» без причины и данных |
| Нет связи | сбой транспорта, тест-вход выключен на лету | «Нет связи» + повтор |

## 4. Acceptance criteria

- **RD-AC-01.** Опубликованный в J2 Route появляется в Catalog-ленте и Search
  по запросу о маршрутах (RD-05) и открывается в Details из карточки, с Map
  и по deep link.
- **RD-AC-02.** Карточка и Map используют только превью; Details — полный
  trimmed-трек. Число линий на карте равно числу сегментов, разрывы видны.
- **RD-AC-03.** Нет duration, bounds, сложности, покрытия и числа POI, если
  их нет в проекции; нулевых подстановок нет.
- **RD-AC-04.** Клиентская модель не содержит полей вне allowlist RD-01;
  приватные маркеры J2-фикстур не попадают ни в одну модель и ни на экран.
- **RD-AC-05.** Снятие с публикации, ограничение модератором и удаление
  дают состояние «Недоступен»; новая ревизия — «Обновился»; запоздавший
  ответ не возвращает скрытый Route на экран.
- **RD-AC-06.** Personal и Page publisher показываются по RD-11.
- **RD-AC-07.** Restart приложения открывает тот же Route заново из Catalog;
  offline даёт «Нет связи», без старых данных.
- **RD-AC-08.** С выключенным `RECHARGE_TEST_ROUTE_CATALOG` поведение RTE-08 и
  DTL-RTE-01 не меняется (существующие тесты зелёные).
- **RD-AC-09.** Нет нового Route aggregate, хранилища или writer; diff не
  трогает `features/create` и backend publication-код.
- **RD-AC-10.** `flutter analyze`, `flutter test`, boundary gate, полный
  Emulator и stand UI с новым сценарием (без skip) — зелёные на одной версии.

## 5. План файлов (после утверждения)

**Mobile** (`apps/mobile/lib/features/discover/`):

- `domain/entities/route_catalog_facts.dart` — новый (RD-01);
- `domain/entities/discover_item_entity.dart` — поле `routeCatalog`,
  классификация `CatalogObjectType.route`;
- `data/models/catalog_wire_models.dart` — `CatalogRouteItem` (карточка и
  Details), разбор `route` в `CatalogCard`/`CatalogDetails`;
- `data/repositories/catalog_discover_repository.dart` — `typeIds` с `route`
  по RD-05, маппинг в `DiscoverItemEntity`, обработка RD-07;
- `presentation/widgets/route_segment_polylines.dart` — новый: сегменты →
  линии, direct пунктиром (RD-03); `published_route_polyline_builder.dart` не
  меняется;
- `presentation/renderers/route_details_view.dart` — новый presentation-слой
  RD-02; `route_details_renderer.dart` — рисует из `RouteDetailsView`;
- `presentation/pages/discover_map_page.dart` — превью-линии выбранного
  Catalog Route; `discover_details_page.dart` — регистрация и состояния RD-07,
  поколение запроса;
- `app/di/discover_catalog_composition.dart` — define и флаг RD-06.

**Тесты:** unit wire-парсера и allowlist, маппинга, RD-05; widget-тесты
renderer (сегменты, отсутствие метрик, publisher, состояния); тест паритета
DTL-RTE-01 для локального пути; stand: seed второго Route от Page с явным
разрывом, Flutter UI stand test «публикация J2 → Catalog → Discover →
карточка → Details» с restart, offline, снятием и новой ревизией, подключённый
к `stand-j2-gate.mjs`.

**Docs:** этот spec → Approved; `DISCOVER_DETAILS_PIPELINE_COVERAGE_MATRIX.md`
(§2.3 Route), `ROUTE_J2_VERIFICATION.md` (новый раздел), LAUNCH_STATUS.

**Rollback:** выключить `RECHARGE_TEST_ROUTE_CATALOG` — Discover возвращается к
RTE-08; данных для миграции нет.

## 6. Вне scope

Device и production; жалоба на Catalog-объект из mobile (K1 client);
публичный GPX-экспорт; elevation-график; имя publisher (RD-11); offline-кеш
(RD-08); Route-items в Scenario; изменение backend-проекции. Если при
реализации окажется, что проекции чего-то не хватает, это фиксируется здесь
отдельным решением, а не обходится на клиенте.

## 7. Реализация (2026-10-22)

Рабочая копия `claude/j2-route-publication` поверх `a568b49`, без commit по
поручению владельца. Отклонения и уточнения — явно:

1. **Модель.** `RouteCatalogFacts` и поле `routeCatalog` на
   `DiscoverItemEntity`; признаки `isCatalogRoute`/`isRoute`; классификация
   `CatalogObjectType.route` для обоих источников. Геометрия декодируется при
   разборе ответа (точность 7) — UI получает точки, не строки.
2. **Wire.** `CatalogRouteItem` проверяет схему, тип publisher, политику и
   размер превью (≤ 256 точек), согласованность числа сегментов трека и
   отклоняет ответ с приватными ключами (`anchors`, `privacyTrim`,
   `provenance`, `bounds`, `durationSeconds`, `note` у waypoint и др.). Id
   publisher в модель не попадает.
3. **RD-05.** `route` добавляется в `typeIds` по тому же признаку
   `requestsPublishedRoutes`, что и локальный путь RTE-08.
4. **RD-07.** Новая ревизия даёт код `CATALOG_ROUTE_REVISION_CHANGED`; snapshot
   списка при этом сбрасывается, и «Обновить» читает текущую ревизию.
   Ответ на старый запрос не возвращается на экран: Details читается через
   `FutureProvider` по id, а запрос после сброса не несёт старый snapshot.
5. **RD-07/08 в shell.** `DetailsScreenUnavailable` получил необязательные
   `message` и `retryLabel`, а helper `detailsUnavailableForError` выдаёт
   «Маршрут обновился»/«Обновить» и «Нет связи»/«Повторить». Details lookup
   больше не превращает сбой связи и новую ревизию Route в «не найдено» —
   это касается и Activity из Catalog: без связи он тоже показывает повтор.
   «Маршрут недоступен» маршрутизатор показывает по типу из ссылки.
6. **Renderer.** Один `RouteDetailsRenderer`: для Catalog — своя карта по
   сегментам, сводка, сведения, waypoints; общих карточек события (дата, цена,
   CTA) и sticky-панели нет. Отдельный presentation-класс `RouteDetailsView`
   не понадобился: ветвление по источнику внутри renderer проще и не
   дублирует экран.
7. **Карточка.** Миниатюра превью рисуется `CustomPaint` без карт и сети.
8. **Stand.** Seed второго Route от Page `studio` (две части с разрывом, без
   высот, первая публикация Page — ручная модерация); действия stand
   `route page-revise | page-withdraw | page-restore`; UI stand test
   `route_catalog_discover_ui_stand_test.dart` в `stand-j2-gate.mjs`. На PC-хосте
   у integration binding нет platform view Google Maps, поэтому stand-тест
   рисует тело Details, а hero с картой проверен widget-тестом.
9. **Не сделано в этом slice.** Отдельная проверка «запоздалого ответа» на
   stand (покрыта механизмом провайдера и unit-тестом сброса snapshot);
   device и production.
10. **Проверка** — отдельный файл
    [DTL_RTE_02_VERIFICATION.md](../../verification/DTL_RTE_02_VERIFICATION.md),
    а не раздел `ROUTE_J2_VERIFICATION.md` (там только ссылка): прогоны этого
    slice записываются отдельно от исторических J1/J2 (§0).
