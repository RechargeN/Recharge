# RECHARGE — DTL-RTE-01: Route Details Renderer Slice Spec

Версия: v0.3 (2026-08-24) — уточнение после третьего раунда review.
Статус: **Approved** (утверждён владельцем продукта 2026-08-24, вслед за
`DTL-FND-01`/`DTL-LINK-01`/`DTL-CLG-01`; реализация авторизована и
выполнена в изолированном worktree `dtl-fnd-01`; `DTL-OBJ-01`
приостановлен отдельно — Rental Create-сторона отсутствует в git-истории
этой ветки — и не блокирует этот slice).

Runtime effect (этого документа): **none**. Сам текст не меняет код —
изменения внесены отдельным implementation-коммитом, под собственными
analyzer/test/boundary/diff gates.

## Реализация — фактические отклонения от плана

Зафиксировано явно, не молча:

1. **`compatibility_object_renderer.dart` затронут** сверх исходного
   file map (§2 не называл его). `RouteDetailsRenderer` реиспользует
   `SummaryCard`/`DetailsActionHub`/`OrganizerCard`/`InfoGrid`/
   `HighlightsCard`/`LocationCard`/`DetailsBottomBar` (и их приватные
   помощники — `MetricTile`, `DetailsPill`, `DetailsActionTile`,
   `DetailsRoutePreview`, `InfoRow`, `routeProfileLabelForDetails` и
   т.д.) без изменения их поведения — только промоушен из
   file-private в public, по тому же принципу, что `DTL-FND-01`
   применил к `RouteSafetyReportDialog`. `_PublishedRouteCard` и
   photo-hero (`_DetailsHero`/`_CoverFallback`/`_CategoryBadge`)
   остались приватными и теперь мёртвым кодом (Route больше не
   диспетчеризуется на этот класс) — не вычищены, поскольку файл вне
   file map этого slice, а более глубокая чистка рискует зацепить
   больше, чем slice авторизовал.
2. **Заголовок маршрута добавлен в `buildBody`**, не заявленный явно в
   file map. Фото-hero раньше показывал `item.title` поверх картинки;
   интерактивная карта не даёт естественного места для такого оверлея.
   Без этой строки Route Details полностью лишился бы заголовка —
   реальная регрессия, не входившая в намерение ни одного AC. Заголовок
   вынесен первой строкой тела, тем же способом, что
   `CollectionDetailsRenderer` показывает свой.
3. **GoogleMap не тестируется через `flutter test` виджет-пампы** —
   подтверждённый существующий прецедент в этом репозитории
   (`discover_map_create_route_test.dart` тестирует только чистые
   URL-builder функции, никогда не пампит реальный `GoogleMap`). Карта
   покрыта тестами `published_route_polyline_builder_test.dart` (чистая
   функция geometry→Polyline) — её собственный виджет-тест подтверждает
   отсутствие построения/layout ошибок, не визуальный вывод плитки
   карты.

## Что изменилось относительно v0.2

`_buildPolylines` в `discover_map_page.dart` строит **и** Published
Route, **и** Scenario-маршрут в одном методе (проверено прямым чтением
кода: первая ветка декодирует `fullEncodedPolyline` через
`GeometryEncoding.decode`, вторая независимо строит polyline из
`scenarioRoute.stops`). Заменять весь метод было бы неверно — этот slice
извлекает **только** pure-функцию построения Published-Route polyline из
public projection; ветка Scenario остаётся на месте в
`discover_map_page.dart`, не трогается и не переносится.

Design-system-промоушен `route_map_preview.dart` — закрыт, не
рассматривается: два использования внутри одной фичи (`discover`)
недостаточны по правилу «используется минимум в двух фичах» из
`UI_BASELINE_DESIGN_SYSTEM.md`, и design_system не должен зависеть от
Route/Google Maps-специфичной семантики.

## Что изменилось относительно v0.1

1. **Elevation-график убран.** `PublishedRouteDiscoveryEntity` содержит
   только `elevationAvailability` (string) + `ascentMeters`/`descentMeters`
   (nullable totals) — проверено прямым чтением файла. Ни один график из
   двух суммарных чисел честно не строится. Этот slice **явно
   исключает** изменение read-модели (§1.2), поэтому вместо графика —
   **elevation summary** (те же данные, первоклассная визуальная секция
   вместо `Wrap`-пилюли, но без графика).
2. **`shape`/topology (one-way/loop/out-and-back) убран из claims.**
   `PublishedRouteDiscoveryEntity` не содержит поля формы маршрута —
   только `startPoint`, `bounds`, две encoded polyline. Map-hero
   показывает **geometry-derived start/end**, не заявляет
   one-way/loop/out-and-back семантику, которую нельзя надёжно вывести
   из одной polyline без отдельного `shapeId`/topology-поля в
   read-модели.
3. **GPX-экспорт убран из scope.** Существующий GPX export
   (`features/create/domain/repositories/route_gpx_repository.dart`,
   `route_gpx_exporter.dart`) — authoring-side use case над Create
   draft-доменом, не над `PublishedRouteDiscoveryEntity`. Подключить его
   к Details означало бы либо нарушить feature boundary (импорт Create в
   Discover), либо построить новый export use case над public
   projection — то и другое не «просто кнопка», а отдельный объём
   работы вне этого slice.
4. **Navigation решение закрыто заранее**, не оставлено «уточняется
   владельцем продукта»: в этом slice — только внутренний переход в
   Discover Map (переиспользование существующего seed-паттерна).
   Внешнее картографическое приложение — отдельная будущая интеграция,
   не входит сюда.

## Approval gates

Заблокировано до:

1. `DISCOVER_DETAILS_SYSTEM_SPEC.md` принят владельцем продукта.
2. `DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` реализован и принят.
3. `DTL_LINK_01_DEEP_LINK_MIGRATION_SLICE_SPEC.md` реализован и принят —
   `route` уже резолвится через `DiscoverItemDetailsLookup`, этот slice
   меняет только renderer, не механизм резолюции.
4. Сам этот документ отдельно получает статус `Approved`.

## Связанные документы

- `DISCOVER_DETAILS_SYSTEM_SPEC.md` §6 (Route Details, target contract).
- `ROUTE_BUILDER_SPEC.md` v3.2; LAUNCH_STATUS RTE-08/RTE-09/RTE-10.
- `published_route_discovery_entity.dart` — точный список полей (см.
  «Что изменилось», пп. 1-2) — единственный источник истины о том, что
  реально доступно этому renderer'у.
- Текущий код: `discover_details_page.dart` (`_PublishedRouteCard`,
  `_reportRoute`, `_RouteSafetyReportDialog`), `discover_map_page.dart`
  (`_buildPolylines`).

## 1. Scope

### 1.1 В scope

1. **Интерактивный map-hero** вместо фото-hero: `GoogleMap` read-only,
   polyline из `fullEncodedPolyline`, geometry-derived start/end pins
   (не «one-way/loop/out-and-back» — эта семантика не заявляется). Из
   `_buildPolylines` (`discover_map_page.dart`) извлекается **только**
   ветка построения Published-Route polyline (декодирование
   `fullEncodedPolyline` через `GeometryEncoding.decode` + сборка
   `Polyline`) как чистая функция, переиспользуемая Map и Route Details.
   Ветка Scenario-маршрута (`scenarioRoute.stops`) остаётся в
   `discover_map_page.dart` без изменений — оба вызова чистой функции
   происходят из своих мест, метод `_buildPolylines` не удаляется
   целиком, а делегирует первую ветку извлечённой функции.
2. **Elevation summary** (не график): честное текстовое/иконочное
   представление `elevationAvailability`/`ascentMeters`/`descentMeters`,
   первоклассная секция вместо строки в `Wrap`.
3. **Difficulty/surface/POI count/field-verified** — первоклассные
   секции вместо `Wrap`-пилюль внутри чужой карточки.
4. **Safety reporting** остаётся в основном потоке экрана — уже так
   реализовано сегодня (`_reportRoute` — кнопка внутри карточки, не
   отдельная ссылка), сохраняется без переизобретения.
5. **Navigation action** — только `Открыть на карте`, переиспользующее
   существующий Map-переход с seed-параметрами конкретного маршрута.

### 1.2 Вне scope

- Изменение `PublishedRouteDiscoveryEntity` (никакие elevation samples
  или `shapeId`/topology-поля не добавляются этим slice).
- Elevation-график — возможен только отдельным будущим slice, который
  явно расширит read-модель типизированными samples и включит
  entity/adapter/migration/tests в свой scope.
- GPX-экспорт с публичной Route Details — отдельный будущий slice,
  который явно спроектирует public-facing export use case поверх
  `PublishedRouteDiscoveryEntity`, не переиспользование
  authoring-side Create GPX-кода.
- Turn-by-turn навигация, GPS-recording-режим просмотра чужого
  маршрута, внешнее картографическое приложение.
- Изменение Route creation/authoring домена (RTE-01…RTE-12).
- Изменение canonical resolver vertical — `DTL-LINK-01` (предшествующий
  этому slice по обновлённому порядку) уже регистрирует
  `DiscoverItemDetailsLookup`, обслуживающий `route` через
  `isPublishedRoute`; этот slice только меняет, **каким renderer'ом**
  отрисовывается уже резолвленная Route-projection, не то, как она
  находится.

## 2. Предлагаемый file map

| Файл | Тип | Назначение |
|---|---|---|
| `apps/mobile/lib/features/discover/presentation/renderers/route_details_renderer.dart` | новый | `DetailsRenderer` для `objectType: route` |
| `apps/mobile/lib/features/discover/presentation/widgets/published_route_polyline_builder.dart` | новый | Чистая функция: `PublishedRouteDiscoveryEntity → Polyline?`, только Published-Route ветка (не Scenario); остаётся внутри `features/discover/`, не промоутится в `design_system` |
| `apps/mobile/lib/features/discover/presentation/widgets/route_elevation_summary.dart` | новый | Честное summary-представление (не график) существующих полей |
| `apps/mobile/lib/features/discover/presentation/pages/discover_map_page.dart` | изменён | **Только** Published-Route ветка `_buildPolylines` делегирует в извлечённую функцию; ветка Scenario-маршрута не изменена |
| `apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart` | изменён | Регистрация `route`/`item.isPublishedRoute` на `RouteDetailsRenderer` |
| тесты паритета Map | новые | Поведение Map не изменилось после извлечения |
| тесты Route Details (map-hero, elevation summary, difficulty, safety report, navigation) | новые | Покрывают AC ниже |

## 3. Acceptance criteria

- **RTE-D-AC-01.** Route открывается через отдельный `RouteDetailsRenderer`.
- **RTE-D-AC-02.** Hero — интерактивная карта с треком; при ошибке
  загрузки — секция деградирует к `temporarilyUnavailable`, не крашится.
- **RTE-D-AC-03.** Только Published-Route ветка `_buildPolylines`
  делегирует в извлечённую чистую функцию; ветка Scenario-маршрута
  (`scenarioRoute.stops`) остаётся нетронутой в том же файле; поведение
  Map не изменилось для обеих веток (тест паритета).
- **RTE-D-AC-04.** Elevation отображается как честное summary
  (`elevationAvailability`/ascent/descent), **без графика** — критерий
  явно проверяет отсутствие визуализации, для которой нет source-данных.
- **RTE-D-AC-05.** Ни один pin/лейбл не заявляет
  one-way/loop/out-and-back — только geometry-derived start/end.
- **RTE-D-AC-06.** Safety reporting остаётся в основном потоке.
- **RTE-D-AC-07.** Navigation action — только переход в Discover Map;
  ни turn-by-turn, ни внешнее приложение, ни GPX-кнопка не добавлены.
- **RTE-D-AC-08.** Route-домен (RTE-01…RTE-11) и Create-фича GPX-кода не
  затронуты — diff не пересекает `features/create`.
- **RTE-D-AC-09.** `flutter analyze --no-pub`, `flutter test --no-pub`,
  boundary gate, `git diff --check` — зелёные.
- **RTE-D-AC-10.** Rollback возвращает `_PublishedRouteCard` и приватный
  `_buildPolylines` без потери функциональности Map.

## 4. Rollback

1. Вернуть `_PublishedRouteCard` в `discover_details_page.dart`, удалить
   регистрацию `RouteDetailsRenderer`.
2. Вернуть Published-Route ветку `_buildPolylines` инлайн, без вызова
   извлечённой функции — Scenario-ветка не затрагивалась и не требует
   отката.
3. Удалить `route_details_renderer.dart`, `route_elevation_summary.dart`,
   `published_route_polyline_builder.dart`.
4. Persisted data, Route creation/publication не затронуты.

## 5. Открытые вопросы

Design-system-промоушен закрыт (см. «Что изменилось» выше) — не
открытый вопрос. Единственное, что остаётся:

1. Будущий slice для elevation-графика и public GPX-export —
   не нумеруется здесь; фиксируется как явная будущая зависимость.
