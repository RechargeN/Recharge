# RECHARGE — Route Implementation Roadmap

Версия: v1.7 (2026-07-25).
Статус: Approved execution roadmap.
Текущий этап: `RTE-08`–`RTE-11` остаются Review до обязательных
device/boundary gates.

Документ делит реализацию полноценного Route Create на небольшие проверяемые
slices. Один slice имеет один основной результат, ограниченный набор файлов,
собственные acceptance criteria и обязательную точку остановки. Следующий
slice не начинается, пока предыдущий не прошёл свой gate либо явно не
зафиксирована разрешённая независимость.

Источники продуктового и платформенного контракта:

- [ROUTE_BUILDER_SPEC.md](ROUTE_BUILDER_SPEC.md) v3.2;
- [ROUTE_CREATE_BLOCK_SLICE_SPEC.md](ROUTE_CREATE_BLOCK_SLICE_SPEC.md) v1.2;
- [PLATFORM_FOUNDATION_SPEC.md](../architecture/PLATFORM_FOUNDATION_SPEC.md)
  v2.1;
- [ARCHITECTURE_BASELINE.md](../architecture/ARCHITECTURE_BASELINE.md);
- Accepted ADR из `docs/adr/`.

Roadmap не ослабляет acceptance criteria исходных спецификаций. Он определяет
порядок доказательства этих критериев без одного огромного change set.

---

## §1. Правила исполнения

1. Одновременно активен только один Route slice.
2. Перед кодом каждого slice публикуется точный file plan и получается
   подтверждение пользователя.
3. Существующие пользовательские изменения не перезаписываются и не
   включаются в Route scope молча.
4. Каждый slice заканчивается профильными тестами, полным `flutter analyze`,
   полным `flutter test`, boundary check и `git diff --check`.
5. Новый внешний provider, backend integration, package или изменение Accepted
   ADR не включается в соседний slice «заодно».
6. Firebase остаётся за post-stabilization gate.
7. Investor-demo использует локальный bounded graph и выполняет ноль
   тарифицируемых routing/elevation/Places вызовов.
8. Demo adapter и production adapter реализуют один domain contract, но demo
   provenance никогда не выдаётся за production data.
9. UI не получает routing, validation, versioning и projection business logic.
10. Незавершённый slice остаётся `In progress` или `Review`; статус `Done`
    требует доказательств, а не визуальной готовности.

## §2. Карта этапов

```text
RTE-00  Roadmap + repository checkpoint
   ↓
RTE-01  Geo foundation
   ↓
RTE-02  Route domain
   ↓
RTE-03  Draft persistence
   ↓
RTE-04  Local trail graph
   ↓
RTE-05  Application coordinator
   ↓
RTE-06  Route Create UI
   ↓
RTE-07  Local immutable publish
   ↓
RTE-08  Investor Search vertical ────── investor-ready milestone
   ↓
RTE-09  Quality and safety
   ↓
RTE-10  GPX
   ↓
RTE-11  GPS recording
   ↓
RTE-12  Production adapters and operations
```

`RTE-01–07` входят в специализированный Route Create scope. `RTE-08`
затрагивает Search/Details и начинается только после выхода из активной
стабилизации либо отдельного изменения приоритета репозитория. `RTE-12`
начинается только после всех production gates.

## §3. RTE-00 — Roadmap и repository checkpoint

### Цель

Создать однозначный план поставки и доказать безопасную исходную точку, не
добавляя Route runtime.

### Разрешённые изменения

- этот roadmap;
- ссылки и stage dependencies в Route/Platform документах;
- фактические строки `RTE-00–12` в `LAUNCH_STATUS.md`;
- диагностические команды без изменения runtime.

### Запрещено

- добавлять Route domain/application/UI;
- менять существующие Create payload;
- подключать SDK, assets, Firebase или provider;
- присваивать `Done` при красных проверках или неразобранном рабочем дереве.

### Gate

- все локальные Markdown-ссылки существуют;
- структуры/acceptance criteria связанных документов непрерывны;
- boundary check зелёный;
- `flutter analyze` — 0 ошибок;
- полный `flutter test` зелёный;
- `git diff --check` зелёный;
- существующие изменения имеют понятный checkpoint и не смешаны с RTE-01.

### Фактическая проверка 2026-07-20

- documentation/link/structure audit — passed;
- boundary gate — passed, 59 существующих allowlist suppressions;
- direct Dart analyze `lib test integration_test` — no issues;
- `flutter analyze --no-pub` — no issues;
- полный `flutter test --no-pub --concurrency=1` — 257 tests passed;
- `git diff --check` — passed, только line-ending warnings;
- runtime Route не изменён.

Статус остаётся `Review`, потому что до RTE-00 в ветке уже находились 39
изменённых tracked-файлов и 82 untracked entries. Их нельзя автоматически
смешивать в один checkpoint или присваивать Route. `RTE-01` начинается после
явного решения о сохранении существующего рабочего дерева.

Решение владельца продукта от 2026-07-24: посторонние накопленные файлы
оставить нетронутыми и продолжить через изолированные Route change sets.
Поэтому repository checkpoint остаётся `Review`, но не блокирует RTE-01 и
следующие slices, пока в них добавляются только заранее согласованные файлы.

## §4. RTE-01 — Geo foundation

### Результат

Один provider-neutral набор geo value objects и geometry utilities без Flutter.

### Scope

- `GeoPoint`, `GeoBounds`, `GeometryHash`;
- canonical point validation;
- versioned geometry encoding/decoding;
- distance и precision utilities;
- compatibility export для существующего Discover `GeoPoint` без второго класса;
- unit/property tests.

### Не входит

- Route entity;
- UI/карта;
- routing graph;
- миграция всех географических моделей приложения;
- новый package без ADR.

### Gate

- единственный runtime-класс `GeoPoint`;
- domain utilities не импортируют Flutter/provider SDK;
- encoding round-trip укладывается в заданный precision budget;
- старые Discover-тесты проходят без продуктовых изменений.

### Фактическая проверка 2026-07-24

- добавлен единый provider-neutral `GeoPoint` с optional finite elevation;
  прежний Discover path стал compatibility export и не создаёт второй
  runtime-класс;
- `GeoBounds` поддерживает обычные bounds и пересечение антимеридиана;
- Haversine distance и длина polyline не зависят от Flutter или map SDK;
- versioned encoded-polyline policy поддерживает precision 5/6, строгий decode
  и канонический fixture;
- SHA-256 geometry hash включает версию схемы, encoding policy, число точек и
  упорядоченную геометрию;
- `crypto 3.0.7`, уже присутствовавший в lockfile транзитивно, закреплён как
  прямая зависимость;
- профильный и compatibility-набор — 25 tests passed;
- boundary gate — passed, 59 существующих allowlist suppressions;
- `flutter analyze --no-pub` — no issues;
- полный `flutter test --no-pub --concurrency=1` — 270 tests passed;
- `git diff --check` для RTE-01 — passed, только line-ending warnings.

## §5. RTE-02 — Route domain

### Результат

Полная typed-модель Route draft, не подключённая к UI или persistence.

### Scope

- anchors, segments, geometry и topology;
- movement profiles/options и shapes;
- waypoint с track position/distance;
- provenance и operation state;
- metrics/elevation status без provider implementation;
- validation issues и readiness use case;
- routing/elevation/GPX repository ports;
- unit/property fixtures.

### Gate

- topology invariants доказаны property tests;
- domain не содержит provider DTO, Flutter или общих Create map-полей;
- Route data round-trip fixture имеет стабильный geometry hash;
- unrelated Create-типы не изменены.

### Фактическая проверка 2026-07-24

- реализована immutable typed-модель Route draft: creation method, versioned
  profile/preferences, shape, anchors, ordered segments, source/derivation,
  canonical geometry, waypoints, conditions, metrics, provenance и async
  operation guards;
- geometry одновременно фиксирует source points, antimeridian-aware bounds,
  encoding policy, encoded polyline, distance и SHA-256 hash; validator
  обнаруживает рассогласование любого производного значения;
- topology validator доказывает непрерывность и правила `oneWay`, `loop`,
  `outAndBack`, включая обязательную пройденную turning anchor;
- readiness блокирует invalid/stale geometry, временные и дублирующиеся ids,
  незавершённые операции, неверные endpoints/revisions/metrics, unresolved
  waypoint, неподдержанные profile options и непубликуемую provider license;
- warnings имеют стабильные ids, location и remediation и не дублируются;
- routing, generation, elevation, GPX и authoring access оформлены как
  provider-neutral domain ports без adapters;
- профильный unit/property/negative-набор — 24 tests passed;
- Route domain не импортирует Flutter, Firebase или map/provider SDK;
- boundary gate — passed, 59 существующих allowlist suppressions;
- `flutter analyze --no-pub` — no issues;
- полный `flutter test --no-pub --concurrency=1` — 294 tests passed;
- scoped `git diff --check` — passed.

## §6. RTE-03 — Draft persistence

### Результат

Route draft сохраняется, восстанавливается и мигрируется через существующий
Create repository.

### Scope

- nullable typed `routeData` в общем draft;
- `RouteDraftMapper` и schema version;
- additive envelope semantics;
- revision-safe autosave;
- permanent IDs до локальной публикации;
- forward-compatible unknown fields;
- migration/round-trip/fault tests.

### Gate

- `sectionData` не дублирует geometry;
- старые draft fixtures читаются без потери смысла;
- более старая запись не перезаписывает новую revision;
- Event/Place и другие payload не мигрируют массово в этом slice.

### Выполнено

- общий Create envelope поднят до schema v7 и получил nullable typed
  `routeData`; Route хранится только в `route_details`, без дублирования
  geometry в runtime `sectionData`;
- строгий `RouteDraftMapper` сохраняет полный Route aggregate, стабильный
  geometry hash и неизвестные поля, включая вложенные поля и элементы списков;
- неподдерживаемая будущая schema и повреждённый Route payload остаются
  восстанавливаемыми как opaque data и не перезаписываются условным save;
- per-user compare-and-set сериализует Route autosave: старая revision не может
  затереть новую, а конфликт допускает безопасный повтор той же revision;
- замена временных id на постоянные атомарно обновляет anchors, segments,
  waypoints, issues, operations и все их связи;
- профильный persistence-набор — 14 tests passed; объединённый
  Route/migration-набор — 41 tests passed;
- boundary gate — passed, 59 существующих allowlist suppressions;
- `flutter analyze --no-pub` — no issues;
- полный `flutter test --no-pub --concurrency=1` — 308 tests passed;
- scoped `git diff --check` — passed.

## §7. RTE-04 — Local trail graph

### Результат

Бесплатный детерминированный adapter действительно соединяет anchors по edges
ограниченного versioned graph.

### Scope

- `AuthoringMapSurface` и `ConsumerMapRenderer` contracts;
- `DemoRouteGraphAdapter` за `RouteRoutingRepository`;
- `DemoCoverageConfig`;
- graph manifest: bounds, version, source, attribution, license references;
- route/profile fixtures;
- outside-coverage, no-route, cancellation и deterministic replay tests;
- cost ledger с нулём тарифицируемых запросов.

### Отдельное разрешение

Добавление или генерация map/graph assets согласуется в file plan RTE-04,
поскольку assets нельзя менять молча.

### Gate

- маршрут следует edges graph, а не соединяет anchors случайной линией;
- один request/fingerprint даёт один canonical result;
- публичные OSM tile endpoints не используются;
- provenance `demoGraph` блокируется production publish policy.

### Выполнено

- provider-neutral `AuthoringMapSurface` и `ConsumerMapRenderer` разделены:
  consumer-контракт принимает только camera, markers и сохранённые polylines,
  без routing, elevation и edit-команд;
- добавлен локальный walking graph Mežaparks: 44 OSM nodes и 53 edges внутри
  versioned bounded coverage; asset загружается из package без сетевого вызова;
- manifest фиксирует graph/data/algorithm/weighting versions, исходный OSM API
  snapshot, SHA-256 snapshot, attribution, ODbL и copyright references;
- `DemoRouteGraphAdapter` детерминированно строит путь по edges, поддерживает
  snapping, walking profile/preferences, cancellation и typed
  `outsideCoverage`, `noPath`, `unsupportedProfile` failures;
- provenance имеет source `demoGraph`, а provider reference запрещает
  production publication до отдельной проверки;
- `ProviderCostPolicy` и ledger запрещают metered policy для demo adapter;
  профильный ledger подтверждает `0 metered calls`;
- graph loader отклоняет будущую schema, повреждённые relations, дубли node/edge
  ids и данные вне coverage;
- профильный RTE-04 набор — 17 tests passed; объединённый Route
  domain/persistence/routing-набор — 55 tests passed;
- boundary gate — passed, 59 существующих allowlist suppressions;
- `flutter analyze --no-pub` — no issues;
- полный `flutter test --no-pub --concurrency=1` — 325 tests passed;
- scoped `git diff --check` — passed.

## §8. RTE-05 — Application coordinator

### Результат

Route редактируется командами application layer без UI business logic.

### Scope

- Route step config;
- add/move/remove anchor;
- split/merge/change profile/shape;
- segment-local async states;
- operationId/revision/fingerprint stale guards;
- bounded undo/redo;
- validation orchestration;
- autosave scheduling;
- controller/coordinator tests.

### Gate

- поздний provider response не меняет новый draft;
- failed command не попадает в history;
- новая команда очищает redo;
- одна ошибка segment не стирает остальную geometry.

### Выполнено

- добавлены versioned Route step config, immutable command model, application
  state и coordinator без UI business logic;
- add/move/remove anchor, split/merge, profile/segment profile, shape,
  explicit direct, reroute и retry выполняются атомарно; `oneWay`, `loop` и
  `outAndBack` сохраняют topology после принятой команды;
- routed/generated участки перестраиваются только там, где затронуты входные
  данные; imported/recorded/freehand geometry без Preview не изменяется;
- async routing защищён совпадением operation id, geometry revision, request
  fingerprint, segment endpoints и canonical geometry hash; поздние ответы
  отменённых операций учитываются, но не меняют новый draft;
- segment-local failure сохраняет остальную geometry и допускает retry либо
  явный direct fallback;
- bounded undo/redo восстанавливает точную geometry, увеличивает revision,
  не записывает rejected commands и очищает redo после новой команды;
- validation и revision-safe autosave оркестрированы coordinator; autosave не
  пишет snapshot с pending operations, ждёт последнюю очередь при dispose и
  не помечает более новую правку сохранённой ответом старой записи;
- индивидуальный versioned profile segment сохраняется mapper без потери
  неизвестных полей;
- профильный RTE-05 набор — 34 tests passed; объединённый Route
  foundation/domain/persistence/routing/application-набор — 92 tests passed;
- boundary gate — passed, 59 существующих allowlist suppressions;
- `flutter analyze --no-pub` — no issues;
- полный `flutter test --no-pub --concurrency=1` — 349 tests passed;
- `git diff --check` и trailing-whitespace scan RTE-05 — passed, только
  существующие line-ending warnings.

## §9. RTE-06 — Route Create UI

### Результат

Уполномоченный demo-author создаёт Route по points/freehand внутри общего
Create Hub и восстанавливает draft после restart.

### Scope

- декларативные Route sections;
- map builder widget;
- points/freehand modes;
- базовые waypoint;
- textual anchor/segment controls для accessibility;
- preview/readiness;
- recoverable error actions;
- widget/golden/accessibility tests.

### Gate

- отдельный form engine не создан;
- весь flow проходит на поддерживаемом устройстве;
- создание возможно без drag-only действий;
- restart восстанавливает последнюю persisted revision.

### Выполнено

- специализированный Route-блок встроен в общий config-driven Create Hub и
  открывается только при capability `create.route`; отдельный form engine,
  экранный router и формат черновика не создавались;
- пять декларативных шагов покрывают method, profile/preferences, track
  editor, details/conditions и review/readiness;
- points соединяют anchors через бесплатный локальный Mežaparks graph;
  freehand сохраняет точную выбранную геометрию после явного подтверждения
  замены существующего трека;
- bounded map editor рисует graph, segments, anchors и waypoint без сетевых
  либо тарифицируемых вызовов; все основные действия доступны также через
  подписанные текстовые controls и координатный ввод;
- реализованы one-way/loop/out-and-back, waypoint add/move/remove,
  undo/redo, segment retry/direct fallback, сохранение и восстановление
  последней persisted revision;
- review показывает сохранённую polyline, derived metrics, blocking issues и
  warnings; Route publication намеренно закрыта immutable gate до RTE-07;
- restart-тест создаёт новый controller/runtime над тем же persistence и
  подтверждает точное восстановление anchors, segments и geometry hashes;
- Route UI проверен на viewport 390×844 и text scale 1.5; добавлен
  детерминированный golden первого шага;
- объединённый Route/geo/map-набор — 101 tests passed;
- boundary gate — passed, 59 существующих allowlist suppressions;
- `flutter analyze` — no issues;
- полный `flutter test` — 356 tests passed;
- scoped `git diff --check` — passed.

## §10. RTE-07 — Local immutable publish

### Результат

Validated draft выпускает локальную неизменяемую Route version и согласованные
read-модели.

### Scope

- typed access/publisher demo policy;
- первичная публикация и каждое изменение через sealed moderation request;
- capability fast-track для доверенных профилей без новой роли;
- publish attempt idempotency;
- `RouteVersion`, `PublishedRouteGeometry`, `RouteSearchProjection`;
- atomic local transaction;
- local archive/new-version behavior;
- Create success/preview;
- integration/fault tests.

### Gate

- bundle имеет один route/version/hash;
- retry attempt не создаёт дубликат;
- partial transaction не показывается как publish success;
- изменение опубликованного Route создаёт новую version;
- прежняя active version остаётся видимой до одобрения новой;
- отказ требует reason code, а решение и публикация попадают в audit trail.

### Выполнено

- стандартный Creator с `submit.route` отправляет неизменяемый snapshot в
  `pendingReview`;
- Creator с `publish.route.direct` использует тот же validation и immutable
  bundle, но версия сразу становится active;
- `moderate.route` открывает локальную очередь approve/reject;
- `manage.route` создаёт новый черновик с `basedOnPublishedVersionId`;
- `archive.route` снимает Route с публикации без удаления истории версий;
- отзыв `publish.route.direct` влияет только на следующие публикации;
- общий Create repository не может обойти Route publication repository;
- локальный `demoGraph` разрешён только как явно помеченная `demoOnly` версия
  и не ослабляет production provider policy.

### Проверка

- 10 focused immutable publication/security/fault tests — passed;
- полный `flutter test` — 367 tests passed;
- `flutter analyze` — no issues;
- boundary gate — passed с 59 существующими allowlist suppressions;
- scoped `git diff --check` — passed.

## §11. RTE-08 — Investor Search vertical

### Результат

Инвестор видит полную вертикаль Create → Search → Details → consumer map.

### Scope

- индексирование локальной `RouteSearchProjection`;
- active-query/viewport loading;
- Search card и Details;
- saved polyline через consumer renderer/Google adapter;
- version/hash mismatch protection;
- zero-routing-on-view boundary tests;
- investor-demo reset/replay script.

### Gate

- активная стабилизация завершена или приоритет изменён явно;
- Route появляется только после Search;
- Search/Details выполняют 0 routing/elevation/Places calls;
- restart и повторный Search показывают ту же published version;
- стандартный investor script проходит на реальном устройстве.

### Реализация 2026-07-25

Готовы durable active-version index, единая фильтрация Search/Map,
Route-specific карточка и Details, отображение выбранной сохранённой polyline
из immutable published snapshot, version/hash guards и удаление projection при
archive. Pending/rejected версии в Discover не индексируются, а одобренная
ревизия заменяет предыдущую searchable version. Просмотр не имеет зависимости
от routing/elevation/Places ports. Guided reset/replay helper находится в
`tools/scripts/route-investor-demo.ps1`; очистка данных требует явного
`-ResetAppData`. Статус остаётся `Review`, пока не завершены обязательные
Flutter gates и replay на реальном устройстве.

## §12. RTE-09 — Quality и safety

### Результат

Route получает доказуемое качество, проверку актуальности и безопасное
управление изменениями.

### Scope

- расширенные waypoint/POI;
- surface/elevation/difficulty calculations;
- technical/field verification;
- map snapshot candidate и visual diff;
- accept/reject/defer/new version;
- safety report, needs-review и suspension policy;
- provenance/attribution UI.

### Gate

- external data не мутирует published geometry;
- field verification требует audited author action;
- критический report может скрыть Search projection, не уничтожая history;
- rollback выпускает новую version.

### Реализация 2026-07-25 — Review

Готовы schema-v2 quality model и совместимая миграция старых Route drafts:
полный/частичный/недоступный elevation без ложного нуля, versioned
spike/noise filtering, ascent/descent, известные и неизвестные surfaces,
детерминированная рекомендация difficulty и расширенные POI. Качество
пересчитывается после принятой команды, stale revision блокируется, а
аудированные technical/field verification records сохраняются.

Локальные workflow хранят immutable map snapshot candidates с diff и решениями
accept/reject/defer; accept создаёт отдельный revision draft от active version
и не меняет опубликованную geometry. High/critical safety reports переводят
Route в needs-review/suspended, critical удаляет только Search projection,
а admin restore возвращает ту же version с audit. Rollback создаёт следующую
immutable version вместо переключения указателя на историю. Create Review и
Discover Details показывают quality/provenance/verification; недостоверные
elevation chips скрыты. Пользователь может отправить safety report из Route
Details, а capability-guarded admin queue обрабатывает map candidates и safety
reports. Полный analyzer чист; 269 unit и 111 widget tests прошли пакетами
(380 total), boundary gate зелёный с 59 существующими allowlist suppressions.
Остаётся device-проверка перед Done.

## §13. RTE-10 — GPX

### Результат

Безопасный импорт/экспорт GPX приводит к той же canonical Route model.

### Scope

- inspect before import;
- size/point/decompression limits;
- multi-track/segment/waypoint selection;
- gaps и normalization preview;
- metadata stripping;
- canonical export и round-trip fixtures.

### Gate

- malformed input не повреждает draft;
- выбор автора обязателен при неоднозначности;
- private/internal metadata не попадает в publish/export;
- supported fixtures проходят round-trip.

### Реализация 2026-07-25 — Review

RTE-10A завершён: GPX 1.0/1.1 инспектируется локально через bounded XML
events и opaque temporary-file token. DTD, entities, processing instructions,
невалидные encoding/XML/coordinates и превышение file/point/candidate/segment/
depth/event/text limits отклоняются fail-closed. Preview summary перечисляет
tracks, routes, segment gaps, waypoints, bounds с antimeridian, duration,
elevation/timestamp quality, privacy metadata и unsupported extension names.
Исходные bytes копируются, ограничиваются до помещения во временное хранилище
и удаляются по token; полный путь не сохраняется. Профильные tests: 8/8.
RTE-10B также завершён: ordered candidate selection требует явных решений
для каждого внутреннего и cross-candidate gap; waypoint импортируется только
по решению автора, а privacy/timestamps всегда удаляются из canonical payload.
Один нормализованный track применяется как одна атомарная Route revision после
подтверждения замены. Stale import не перезаписывает новый draft, temporary
source удаляется, а раздельные tracks возвращают typed решение вместо скрытого
объединения. Совместный GPX/Route-command набор: 28/28.

RTE-10C завершён: canonical draft экспортируется в GPX 1.1 без
internal ids, private notes, safety fields и timestamps; elevation включается
только при полной достоверности. Export проходит обратную inspection.
Официальные бесплатные `file_selector` и `share_plus` изолированы app-adapter
и не проникают в domain. Desktop/web используют native save, Android/iOS —
системный Share Sheet fallback. UI показывает локальный preview, позволяет
выбрать один track, требует явного подтверждения прямых gap connectors,
опционально импортирует POI как off-track до ручной проверки и подтверждает
замену существующей геометрии. Export имеет явные elevation/POI настройки и
никогда не включает private metadata.

RTE-10D: полный analyzer зелёный; 287 unit и 115 widget tests прошли
ограниченными пакетами (402 total), включая GPX UI и обновлённый phone golden;
`git diff --check` зелёный. Общий boundary gate пока блокируют два посторонних
cross-feature import в untracked Visited Places page. До Done также остаётся
реальная device-проверка file open/save/share.

## §14. RTE-11 — GPS recording

### Результат

Записанный на устройстве трек безопасно восстанавливается и превращается в
canonical geometry.

### Scope

- permission lifecycle;
- start/pause/resume/finish;
- background journal;
- crash/restart recovery;
- accuracy/outlier processing preview;
- private start/end trimming;
- battery/privacy tests.

### Gate

- permission revoke и process restart не теряют подтверждённый journal;
- raw GPS history не попадает в telemetry/publish;
- обработанная geometry применяется только после preview;
- platform behavior проверен на поддерживаемых устройствах.

### Реализация 2026-07-25 — Review

Добавлены immutable GPS journal/sample/leg, preview, gap, quality и
apply-result models. Bounded processing fail-closed исключает точки
с плохой accuracy, mocked location и неправдоподобным перемещением, не соединяя
разрывы молча; pause и time discontinuity становятся явными gaps. Recorded
duration не включает pause. Privacy trim начала/конца применяется только в
Preview и ограничен config.

Каждый gap требует typed решения `keepGap`, `connectDirect`, `routeBetween`
или `splitDraft`; routing остаётся явным application-шагом следующей части.
Per-sample UTC/monotonic history остаётся только в локальном journal, наружу
выходят geometry и safe aggregate metrics. Подтверждённый единый track
атомарно применяется как `recordedGps`; замена существующей geometry требует
подтверждения.

Application lifecycle реализует permission check/request, start, pause, resume
в новом leg, finish, revoke/service-loss pause и sample/write limits.
Незавершённый journal восстанавливается только в paused state: запись никогда
не продолжается после restart без явного действия автора. Journal хранится
порциями в AES-256-GCM encrypted app-support files, а master key — в platform
secure storage; chunks записываются до manifest commit point, revision/session
guards запрещают stale overwrite, а аварийная частичная запись не расширяет
подтверждённый snapshot.

Бесплатный BSD-licensed `geolocator 14.0.2` изолирован adapter-ом за domain
port. Android и iOS получили foreground/background purpose declarations;
background включается только по явному выбору, с системным индикатором.
Create UI показывает start/pause/resume/finish, сохранённые точки,
восстановление, обработанный track preview, quality summary, start/end privacy
trim и обязательные решения по gaps. Apply проходит через общую atomic Route
command и требует подтверждения замены существующей geometry.

Targeted analyzer чист. Прошли 22 GPS unit tests, один end-to-end widget test
`record → preview → apply` и ранее 15 Route-command compatibility tests.
Перед Done остаются реальные Android/iOS проверки permission revoke,
foreground/background, screen lock, process restart, secure recovery и battery
behavior, а также общий stabilization gate.

## §15. RTE-12 — Production adapters и operations

### Результат

Demo adapters заменены production infrastructure без изменения Route domain,
commands и пользовательских шагов.

### Scope

- Accepted map/routing ADR implementation;
- licensed authoring tiles;
- approved routing/elevation adapters через backend;
- ManagedPage ownership и backend capability enforcement;
- Firebase repository после stabilization gate;
- media upload lifecycle;
- quotas, kill switches, SLI/SLO, alerts, rollback/runbooks;
- legal/security/load review.

### Gate

- provider contract suites зелёные;
- client не содержит routing/elevation secrets;
- metered adapters включаются только после budget approval;
- public viewing работает при недоступном authoring provider;
- release/rollback/incident runbooks проверены.

## §16. Investor-ready milestone

Investor-ready наступает после `RTE-08`, когда на реальном устройстве
воспроизводится:

```text
authorized demo author
→ anchors over bounded trail coverage
→ real graph routing
→ edit + autosave + restart
→ immutable local publish
→ Search result
→ saved polyline in Details
→ repeated viewing with 0 routing/elevation/Places calls
```

`RTE-09–12` усиливают качество, ввод и production scale, но не требуются для
первой честной демонстрации основной ценности инвестору.

## §17. Статусы и изменение roadmap

Допустимые статусы: `Planned`, `In progress`, `Review`, `Done`, `Blocked`.

- `Done` ставится только после всех обязательных проверок slice.
- `Review` означает, что реализация закончена, но проверка/приёмка не завершена.
- `Blocked` требует конкретного внешнего gate; сложность сама по себе не blocker.
- Добавление scope в активный slice требует обновить file plan до кода.
- Новый продуктовый результат получает новый slice ID, а не добавляется в
  существующий change set.

Фактический статус хранится в
[LAUNCH_STATUS.md](../architecture/LAUNCH_STATUS.md); этот документ описывает
порядок и критерии, но не заменяет execution tracker.
