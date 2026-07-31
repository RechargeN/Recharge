# RECHARGE — Route Create Block Slice Spec

Версия: v1.2 (2026-07-20). Статус: Approved product slice.
Реализация: RTE-01–07 выполнены; RTE-08–11 находятся в Review.
RTE-10 реализует безопасные GPX inspection/import/apply/export и пользовательский
preview/import/export UI. Analyzer и 402 теста зелёные; перед Done остаются
устранение двух посторонних boundary-нарушений и device verification.
RTE-11 реализует полный локальный GPS flow: permission lifecycle,
start/pause/resume/finish, foreground/background recording, crash-safe
chunked AES-256-GCM journal с ключом в platform secure storage, restart recovery без auto-resume,
безопасный processing Preview, карту записанного трека, privacy trim, явные
gap decisions и atomic `recordedGps` apply. Targeted analyzer, 22 GPS unit
tests и end-to-end widget test зелёные; перед Done остаётся реальная
Android/iOS device-проверка foreground/background/restart.

Документ определяет полноценный Route-блок внутри общего Create Hub: от
проверки прав автора и постановки точек на outdoor-карте до сохранения
версии геометрии, публикации поисковой проекции и показа готового маршрута
поверх Google Maps. Продуктовый контракт и полная доменная модель заданы в
[ROUTE_BUILDER_SPEC.md](ROUTE_BUILDER_SPEC.md) v3.2; при конфликте он имеет
приоритет над этим планом реализации.

Платформенные зависимости, investor-demo и правила контроля стоимости заданы
в [PLATFORM_FOUNDATION_SPEC.md](../architecture/PLATFORM_FOUNDATION_SPEC.md).
Порядок небольших slices и investor-ready milestone зафиксированы в
[ROUTE_IMPLEMENTATION_ROADMAP.md](ROUTE_IMPLEMENTATION_ROADMAP.md).
Первый поставляемый результат — полностью работающая локальная вертикаль без
тарифицируемых API-вызовов; adapters меняются по мере готовности, но Route-
контракт и Create flow не упрощаются.

Slice завершает уже утверждённый тип `CreateObjectType.route`. Он не создаёт
отдельный экранный движок, новую роль или второй формат маршрута.

---

## §1. Результат

Уполномоченный автор получает в Create Hub специализированный Route-блок и
может:

1. создать черновик от имени пользователя или закреплённой страницы;
2. поставить anchors на outdoor-карте;
3. соединить их по доступным дорогам и тропам выбранного профиля;
4. вручную исправить отдельные участки, импортировать GPX или записать трек;
5. добавить точки интереса и условия прохождения;
6. проверить итоговую геометрию, расчёты и предупреждения;
7. опубликовать неизменяемую версию Route;
8. получить карточку в Search и сохранённую линию на Google Maps без нового
   запроса маршрутизации со стороны читателя.

Публичный пользователь не видит редактор и не строит путь. Он получает
только опубликованную версию, найденную через Search или Smart Search.

## §2. Зафиксированные решения

1. Route — непрерывный трек по местности с anchors, segments, геометрией,
   elevation и POI по километражу.
2. Создание доступно только `Creator` или `Admin` с нужной capability.
   Отдельная роль «доверенное лицо» не вводится.
3. Права разделены: `create.route`, `submit.route`, `publish.route.direct`,
   `moderate.route`, `manage.route`, `archive.route`. Наличие одного права
   не подразумевает остальные. Доверенный профиль — это capability
   `publish.route.direct`, а не новая роль.
4. Автор указывается как `{type: user | page, id}`; проверяется право
   публиковать от имени выбранного автора.
5. Outdoor-редактор использует MapLibre-совместимый адаптер и лицензированный
   источник OSM-derived tiles. Выбор поставщика фиксируется ADR.
6. Соединение anchors выполняется серверным адаптером к собственному
   Valhalla/OpenRouteService deployment либо другому разрешённому движку.
7. Мобильный клиент не содержит ключей маршрутизации и не обращается к
   движку напрямую в production.
8. Google Maps SDK используется в потребительском контуре только для
   отображения уже сохранённой polyline.
9. Google Routes не является источником сохраняемой геометрии.
10. Опубликованный Route появляется только в активной поисковой выдаче и на
    карте её результатов. Он не загружается на карту заранее.
11. Изменение OSM не меняет опубликованную линию автоматически. Оно может
    создать issue или кандидат новой draft-версии.
12. Все продуктовые границы и лимиты приходят из конфигурации, а не
    зашиваются в UI.

## §3. Границы slice

### Входит

- типизированные Route-данные в общем `CreateDraftEntity`;
- декларативная конфигурация шагов Route;
- application coordinator и use cases для редактирования;
- capability-guards на вход, сохранение, публикацию и управление;
- режимы points, freehand, GPS, GPX и generation из основной спецификации;
- undo/redo, autosave, восстановление и миграция черновика;
- provider-neutral интерфейсы карты, маршрутизации, elevation и GPX;
- детерминированные mock-адаптеры для разработки и тестов;
- валидация, preview, публикационный bundle и поисковая проекция;
- version/hash consistency между карточкой и полной геометрией;
- тесты domain, application, data, widget, accessibility и end-to-end.

### Не входит без отдельного разрешающего gate

- подключение Firebase;
- production-провайдер tiles, реальный routing deployment и elevation API;
- изменение Accepted ADR;
- новая роль или новая taxonomy-сущность;
- публичное построение пути при просмотре;
- автоматическая замена опубликованной геометрии внешними данными.

Реальные интеграции выполняются только после соответствующего ADR,
legal/security review и снятия архитектурного gate. До этого контракт
реализуется на локальных и mock-адаптерах.

## §4. Доступ и безопасность

### Проверки доступа

| Операция | Обязательная capability | Дополнительная проверка |
|---|---|---|
| открыть новый Route | `create.route` | авторизованная сессия |
| сохранить свой черновик | `create.route` | ownership publisher |
| отправить версию на проверку | `submit.route` | readiness и publisher access |
| опубликовать без предварительной проверки | `publish.route.direct` | trusted capability, readiness и publisher access |
| принять или отклонить версию | `moderate.route` | sealed request и reason code при отказе |
| создать новую версию | `manage.route` | доступ к исходному Route |
| архивировать | `archive.route` | доступ к publisher |

Guard работает на трёх уровнях:

- router не открывает Route Create по прямой ссылке без capability;
- application повторно проверяет право перед мутацией и публикацией;
- backend является окончательной точкой авторизации после его подключения.

Скрытие кнопки в UI не считается защитой. Mock-policy в локальной версии
повторяет контракт, но не объявляется production security boundary.
Публикация от имени страницы становится доступна только после реализации
Publisher/ManagedPage ownership и capability enforcement. До этого локальный
adapter не должен симулировать небезопасное право на чужую страницу.

### Чувствительные данные

- исходный GPS-журнал и импортированный файл не публикуются автоматически;
- EXIF и лишние metadata медиа удаляются до загрузки;
- координаты дома или приватного старта автор может обрезать до публикации;
- логи не содержат полный GPX, точную GPS-историю и access tokens;
- аналитика использует идентификаторы действий, а не массивы координат.

## §5. Пользовательский поток

### Шаг 0 — Вход

Create Hub показывает Route только при `create.route`. После выбора типа
приложение проверяет сессию, capabilities, выбранного publisher и рыночную
конфигурацию. При отказе редактор не создаёт черновик и показывает понятную
причину с безопасным возвратом.

### Шаг 1 — Основное

Поля: название, краткое описание, категории, профиль движения, тип формы,
publisher, market и обложка. Общие поля обслуживаются form engine; Route-
специфичные значения записываются в `RouteDraftData`.

### Шаг 2 — Источник трека

Автор выбирает один из пяти способов:

- `points` — построение по anchors;
- `freehand` — ручная линия с последующей нормализацией;
- `gps` — запись движения;
- `gpx` — безопасный импорт;
- `generation` — подбор по заданным условиям.

Смена способа после появления геометрии требует явного подтверждения. Старые
данные не удаляются до успешного завершения операции замены.

### Шаг 3 — Редактор

Карта поддерживает добавление, перемещение и удаление anchors, разбиение и
объединение segments, drag-to-reroute, намеренный прямой участок, изменение
профиля отдельного segment, undo/redo и возврат к последней сохранённой
версии. Каждая асинхронная операция отображает локальное состояние только
затронутого segment.

### Шаг 4 — POI и условия

Автор добавляет точки по километражу, инструкции, поверхность, сезонность,
сложность, доступность, ограничения, предупреждения и фотографии. POI
привязывается к track position, а не только к произвольной координате.

### Шаг 5 — Проверка

Preview показывает именно будущую опубликованную линию, дистанцию, набор и
потерю высоты, длительность, поверхность, предупреждения, точку старта и
финиша. Блокирующие ошибки отделены от предупреждений, требующих просмотра.

### Шаг 6 — Публикация

После повторной проверки capability создаются:

- неизменяемая `RouteVersion` с полной геометрией;
- `PublishedRouteGeometry` для Details и карты;
- `RouteSearchProjection` с облегчённой overview polyline;
- audit event без чувствительной геометрии.

Для обычного профиля bundle запечатывается и попадает в очередь модерации.
Первичная версия и каждое последующее изменение требуют одобрения. Пока новая
версия ожидает решения, прежняя active version остаётся видимой в продукте.
Отказ не меняет active version и обязан содержать reason code.

Профиль с `publish.route.direct` создаёт тот же валидированный неизменяемый
bundle и audit event, но версия становится active без предварительной
проверки. Отзыв capability не меняет уже опубликованные версии и действует
только на следующие попытки.

Публикация идемпотентна. Повтор одного `publishAttemptId` не создаёт второй
Route. Успех показывается только после подтверждения согласованной записи.

## §6. Состояние и команды

### Application state

```dart
enum RouteCreateStatus {
  restoring,
  editing,
  routing,
  validating,
  readyToPublish,
  publishing,
  published,
  failure,
}

class RouteCreateState {
  RouteCreateStatus status;
  int step;
  RouteDraftData draft;
  List<RouteEditCommand> undoStack;
  List<RouteEditCommand> redoStack;
  Map<String, SegmentOperationState> segmentOperations;
  List<RouteValidationIssue> issues;
  int revision;
  int persistedRevision;
}
```

`CreateState` остаётся владельцем общего lifecycle. Route-состояние содержит
только данные специализированного блока; оно не дублирует глобальные поля,
publisher, общий save status и опубликованный draft.

### Команды coordinator

- `initializeRoute`;
- `selectCreationMethod`;
- `addAnchor`, `moveAnchor`, `removeAnchor`;
- `splitSegment`, `mergeSegments`, `changeSegmentProfile`;
- `setSegmentShape`, `rerouteSegment`, `retrySegment`;
- `applyFreehandGeometry`;
- `startGpsRecording`, `pauseGpsRecording`, `finishGpsRecording`;
- `inspectGpx`, `importGpxSelection`;
- `generateCandidates`, `acceptGeneratedCandidate`;
- `addWaypoint`, `moveWaypoint`, `removeWaypoint`;
- `undo`, `redo`, `restorePersistedRevision`;
- `validate`, `buildPreview`, `publish`.

UI отправляет намерения и отображает состояние. Геометрические операции,
конкурентность, validation и projection building находятся вне widget.

### Защита от устаревших ответов

Каждый routing/elevation request получает `operationId`, `draftRevision`,
`segmentId` и fingerprint входных anchors/profile. Ответ применяется только
если все значения ещё актуальны. Отмена запроса не заменяет эту проверку.
После новой команды redo очищается; неуспешная команда не попадает в history.

## §7. Домен и хранение

### Встраивание в общий черновик

В `CreateDraftEntity` добавляется nullable `RouteDraftData? routeData` с
симметричными `copyWith` и `clearRouteData`. Для `objectType == route` это
единственный типизированный источник Route-данных. `sectionData` не хранит
копию геометрии и используется только для совместимой оболочки form engine.

Общий envelope продолжает владеть `id`, `objectType`, publisher, media,
статусами, timestamps и общими текстовыми полями. Несохранённый `loc_*`
заменяется постоянным ULID при публикации; все вложенные связи используют id.

### Обязательные Route-типы

- `RouteDraftData` — revision, метод создания, профиль, форма и Route-секции;
- `RouteAnchorDraft` — id, position, order и author intent;
- `RouteSegmentDraft` — id, anchor ids, geometry, profile, shape, status;
- `RouteWaypointDraft` — id, track position, distance, kind и content;
- `RouteGeometryDraft` — encoding, precision, bounds, length и hash;
- `RouteMetricsDraft` — distance, elevation, duration, surfaces, difficulty;
- `RouteProvenanceDraft` — source, engine/version, timestamp и license refs;
- `RouteValidationIssue` — code, severity, location и remediation;
- `RouteSearchProjection` и `PublishedRouteGeometry` — read-модели публикации.

Точная схема, topological invariants и encoding policy берутся из
`ROUTE_BUILDER_SPEC.md` и не переопределяются здесь.

### Mapper и schema version

`RouteDraftMapper` выполняет строгую двустороннюю конвертацию, хранит
`routeSchemaVersion`, отклоняет неизвестную будущую major-версию и мигрирует
известные старые версии без потери исходного payload. Некорректный segment не
обнуляет весь черновик: пользователь получает recoverable error и экспорт
исходных данных для поддержки.

Autosave использует debounce из Create runtime config, последовательную
очередь записей и revision guard. Более старое сохранение не может
перезаписать новое. Закрытие экрана дожидается активной локальной записи либо
явно сообщает, что осталось несохранённым.

## §8. Порты и адаптеры

### Domain/application contracts

```dart
abstract interface class RouteRoutingRepository {
  Future<RoutedSegment> route(RouteRequest request);
  Future<List<RouteCandidate>> generate(RouteGenerationRequest request);
}

abstract interface class RouteElevationRepository {
  Future<ElevationProfile> resolve(RouteGeometry geometry);
}

abstract interface class RouteGpxRepository {
  Future<GpxInspection> inspect(SafeFileRef file);
  Future<GpxImportResult> import(GpxImportSelection selection);
  Future<SafeFileRef> export(RouteVersion route);
}

abstract interface class RoutePublicationRepository {
  Future<RoutePublishReceipt> publish(RoutePublishBundle bundle);
}

abstract interface class RouteAuthoringPolicy {
  Future<RouteAuthorizationDecision> authorize(RouteOperation operation);
}
```

Map renderer не возвращает доменные сущности и не принимает решения о
маршрутизации. Он преобразует жесты в intents и рисует переданные layers.
Провайдерские DTO остаются в `data`.

### Локальные и mock-адаптеры

До production-gates используются два явно разных набора adapters:

- детерминированный routing fake с fixtures для unit/widget тестов;
- `DemoRouteGraphAdapter`, который действительно строит путь по bounded
  versioned graph в investor-demo;
- mock elevation profile с известными контрольными точками;
- локальный GPX parser с лимитами размера и количества points;
- in-memory publication repository, атомарно сохраняющий version и projections;
- capability fixture с явным набором разрешений;
- fake map surface для widget/golden тестов.

Fake-линия всегда отмечается provenance `mock`, demo-линия — `demoGraph`.
Ни одну из них нельзя принять за production geometry или перенести в
production seed без повторной проверки.

### Production-адаптеры

После gates:

- MapLibre adapter получает style и tile endpoints из market config;
- routing client идёт через backend proxy к разрешённому deployment;
- elevation использует лицензированный dataset через backend;
- publication сохраняет bundle в целевой backend;
- Search читает projection, Details лениво получает full geometry;
- существующий Google Maps adapter рисует `PublishedRouteGeometry.polyline`.

Ни Search, ни Details не вызывают routing/elevation. Отказ authoring-сервиса
не мешает просмотру уже опубликованных версий.

## §9. Публикация и поисковая выдача

### Publish bundle

Перед записью application строит один канонический bundle:

```text
routeId
routeVersionId
geometryHash
publishedRouteVersion
publishedRouteGeometry
routeSearchProjection
publisherRef
publishAttemptId
```

`routeVersionId` и `geometryHash` совпадают во всех частях bundle. Overview
polyline создаётся из той же canonical geometry с конфигурируемым упрощением.
Backend записывает bundle атомарно или через outbox с наблюдаемой
согласованностью; частичный успех не показывается как публикация.

### Search

Search индексирует metadata, market, bounds, start point, профиль, категории,
distance/duration/difficulty и overview polyline. Карта загружает только
объекты текущей выдачи и viewport, дедуплицирует `routeId + routeVersionId` и
не получает full geometry для невидимых карточек.

После выбора результата Details запрашивает full geometry той же версии.
При несовпадении version/hash клиент не смешивает данные, повторяет чтение и
показывает безопасное состояние вместо неверной линии.

### Google Maps

Потребительский adapter получает сохранённый массив координат или encoded
polyline, декодирует его согласно `geometryEncodingVersion` и рисует обычную
Google Maps polyline. Отсутствие тропы в базовом слое Google не меняет линию;
UI может пояснить, что маршрут содержит outdoor-участок.

Атрибуция Google показывается по требованиям SDK. Если геометрия или данные
derived from OSM, рядом доступна требуемая OSM/provider attribution и ссылка
на сведения об источниках.

## §10. Валидация и деградация

### Блокирует публикацию

- нет `submit.route` / `publish.route.direct` или доступа к publisher;
- меньше минимального числа anchors для выбранной формы;
- topology segments не соединяет start и finish;
- segment остаётся в `routing`, `failed` без принятого fallback или stale;
- geometry пуста, повреждена, превышает лимит или не проходит hash check;
- POI невозможно спроецировать на track в допустимом tolerance;
- отсутствует обязательный provenance/license reference;
- обязательные поля, media safety или market constraints не пройдены;
- preview построен для другой revision;
- publish bundle содержит разные version/hash.

### Требует просмотра

- прямой segment там, где ожидалась маршрутизация;
- разрыв высоты или неполные surface data;
- экстремальный уклон, пересечение опасной зоны или сезонное ограничение;
- GPS-точность ниже порога;
- GPX содержит timestamps/metadata, которые будут удалены;
- старт похож на приватную локацию;
- опубликованная версия основана на устаревшем snapshot картографических данных.

Каждое предупреждение имеет стабильный code, привязку к section/segment и
действие: исправить, повторить, принять с причиной или отменить публикацию.

### Fallback

При временном отказе routing автор может повторить запрос, продолжить другие
sections, сохранить черновик или явно принять direct segment, если профиль и
policy это разрешают. Автоматическое молчаливое проведение прямой линии
запрещено. Ошибка одного segment не стирает остальные.

## §11. План файлов реализации

### Новые файлы

```text
apps/mobile/lib/features/create/domain/entities/route_draft_data.dart
apps/mobile/lib/features/create/domain/entities/route_validation_issue.dart
apps/mobile/lib/features/create/domain/entities/route_publication_data.dart
apps/mobile/lib/features/create/domain/repositories/route_routing_repository.dart
apps/mobile/lib/features/create/domain/repositories/route_elevation_repository.dart
apps/mobile/lib/features/create/domain/repositories/route_gpx_repository.dart
apps/mobile/lib/features/create/domain/repositories/route_publication_repository.dart
apps/mobile/lib/features/create/domain/repositories/route_authoring_policy.dart
apps/mobile/lib/features/create/domain/usecases/validate_route_draft_usecase.dart
apps/mobile/lib/features/create/domain/usecases/normalize_route_geometry_usecase.dart
apps/mobile/lib/features/create/domain/usecases/build_route_projection_usecase.dart
apps/mobile/lib/features/create/application/route_create_config.dart
apps/mobile/lib/features/create/application/route_create_coordinator.dart
apps/mobile/lib/features/create/data/models/route_draft_mapper.dart
apps/mobile/lib/features/create/data/datasources/route_routing_mock_datasource.dart
apps/mobile/lib/features/create/data/datasources/route_elevation_mock_datasource.dart
apps/mobile/lib/features/create/data/repositories/route_routing_repository_impl.dart
apps/mobile/lib/features/create/presentation/widgets/route_create_block.dart
apps/mobile/lib/features/create/presentation/widgets/route_map_builder_section.dart
apps/mobile/test/support/route_create_test_support.dart
apps/mobile/test/unit/route_create_coordinator_test.dart
apps/mobile/test/unit/route_draft_mapper_test.dart
apps/mobile/test/unit/validate_route_draft_usecase_test.dart
apps/mobile/test/widget/route_create_block_test.dart
```

Имена могут быть скорректированы под фактические conventions репозитория без
изменения слоёв и ответственности.

### Изменяемые файлы

```text
apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart
apps/mobile/lib/features/create/data/models/create_draft_model.dart
apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart
apps/mobile/lib/features/create/application/create_runtime_defaults.dart
apps/mobile/lib/features/create/application/create_providers.dart
apps/mobile/lib/features/create/application/state/create_state.dart
apps/mobile/lib/features/create/application/controllers/create_controller.dart
apps/mobile/lib/features/create/presentation/pages/create_page.dart
apps/mobile/test/widget/create_page_test.dart
```

Подключение выполняется через registry/config/coordinator существующего form
engine. В общем controller допустима только диспетчеризация по типизированному
контракту; Route-геометрия и routing rules туда не переносятся.

## §12. Этапы реализации и gates

| Этап | Foundation dependency | Результат | Gate выхода |
|---|---|---|---|
| RCB-01 | PF-01/02 | типы, mapper, additive envelope, validation | unit/property + migration fixtures |
| RCB-02 | PF-03/04 | config, coordinator, bounded local graph, points/freehand editor, undo | investor device + widget + golden + a11y |
| RCB-03 | PF-05/06 | GPS, GPX, generation, POI и расчёты | safety/fixture/privacy tests |
| RCB-04 | PF-02–05 | local idempotent publish bundle, Search projection, provider-neutral consumer renderer | zero-metered-call end-to-end |
| RCB-05 | Accepted ADR | approved map/routing/elevation adapters | legal, security, cost, load, contract review |
| RCB-06 | stabilization exit | Publisher/ManagedPage, целевой backend и capability enforcement | backend rules + migration tests |
| RCB-07 | RCB-05/06 | observability, rollout, rollback и operations | production readiness review |

Каждый этап реализуется отдельным reviewable slice. Одобрение этого документа
не снимает gates RCB-05/06 и не разрешает молча подключать внешний сервис.

## §13. Тестовая матрица

### Domain и property-based

- topology сохраняется после каждой команды;
- distance по segments монотонна, POI не выходит за track;
- encode/decode укладывается в precision budget;
- simplify сохраняет endpoints и не превышает tolerance;
- undo/redo восстанавливает точный canonical hash;
- mapper round-trip не теряет данные;
- миграции идемпотентны;
- validation codes стабильны и детерминированы.

### Application и data

- capability matrix для всех операций и publisher types;
- stale routing/elevation response никогда не применяется;
- autosave не допускает revision rollback;
- routing fallback требует явного решения;
- GPX size/point/decompression limits и metadata stripping;
- publish idempotency и атомарность bundle;
- overview/full geometry имеют общий version/hash;
- provider DTO не проходит в domain.

### Widget и accessibility

- все шаги доступны с клавиатуры и screen reader;
- карта имеет текстовый список anchors/segments и альтернативные команды;
- loading/error/retry показаны для конкретного segment;
- блокирующие ошибки ведут к нужному полю или участку;
- destructive replacement требует подтверждения;
- small/large text, светлая/тёмная тема и узкий экран не ломают flow.

### End-to-end

1. Уполномоченный автор создаёт Route по points, сохраняет и публикует.
2. Пользователь находит Route, открывает его и видит ту же линию на Google Maps.
3. При недоступном routing опубликованный Route продолжает открываться.
4. Пользователь без capability не открывает editor по прямой ссылке.
5. Повтор публикации не создаёт дубликат.
6. Изменение исходных картографических данных не меняет опубликованную версию.

## §14. Acceptance criteria

- **RCB-AC-01:** Route подключён как специализированный блок общего Create Hub,
  без отдельного form engine.
- **RCB-AC-02:** вход, сохранение, публикация, управление и архивирование
  проверяют соответствующие capabilities.
- **RCB-AC-03:** прямой URL не обходит guard; backend остаётся окончательной
  точкой авторизации.
- **RCB-AC-04:** `CreateDraftEntity` хранит типизированный `routeData`, а
  `sectionData` не дублирует Route-геометрию.
- **RCB-AC-05:** points, freehand, GPS, GPX и generation используют общий
  coordinator contract и каноническую Route-модель.
- **RCB-AC-06:** anchors можно добавить, переместить и удалить; topology после
  каждой принятой команды валидна.
- **RCB-AC-07:** профиль и shape задаются на уровне segment без скрытого
  изменения соседних участков.
- **RCB-AC-08:** routing/elevation ответы защищены operation, revision и input
  fingerprint guards.
- **RCB-AC-09:** неуспешная операция не повреждает draft и не попадает в
  undo/redo history.
- **RCB-AC-10:** fallback в direct segment возможен только явно и с provenance.
- **RCB-AC-11:** GPX проходит безопасную инспекцию, лимиты, выбор частей и
  нормализацию до записи в draft.
- **RCB-AC-12:** GPS и импортированные metadata не публикуются без явного
  продуктового назначения.
- **RCB-AC-13:** POI хранит track position и корректно перепроецируется после
  изменения геометрии либо становится validation issue.
- **RCB-AC-14:** расчёты имеют source/status и не маскируют отсутствие данных.
- **RCB-AC-15:** autosave последовательный, revision-safe и восстанавливает
  последнюю подтверждённую версию.
- **RCB-AC-16:** schema migration и mapper round-trip покрыты fixtures.
- **RCB-AC-17:** preview и publish работают только на одной актуальной revision.
- **RCB-AC-18:** публикация идемпотентна и не выдаёт частичный bundle за успех.
- **RCB-AC-19:** version/hash одинаковы в RouteVersion, full geometry и Search
  projection.
- **RCB-AC-20:** Search загружает overview только для активной выдачи и viewport.
- **RCB-AC-21:** Google Maps рисует сохранённую polyline без routing/elevation
  запросов.
- **RCB-AC-22:** отсутствие тропы на базовой карте не изменяет сохранённую линию.
- **RCB-AC-23:** обновление OSM создаёт issue или draft candidate, но не меняет
  опубликованный Route.
- **RCB-AC-24:** attribution и provider provenance доступны пользователю.
- **RCB-AC-25:** UI не содержит routing, validation и projection business logic.
- **RCB-AC-26:** provider SDK/DTO не протекают в domain/application contracts.
- **RCB-AC-27:** лимиты, endpoints, profiles, market и attribution приходят из
  конфигурации.
- **RCB-AC-28:** все ошибки имеют стабильный code, безопасное сообщение и
  recoverable действие там, где восстановление возможно.
- **RCB-AC-29:** unit, property, contract, widget, accessibility и end-to-end
  тесты из §13 проходят.
- **RCB-AC-30:** `flutter analyze` возвращает 0 ошибок, `flutter test` полностью
  зелёный, фактический статус отражён в `LAUNCH_STATUS.md`.
- **RCB-AC-31:** investor-demo проходит создание, сохранение, restart,
  локальную публикацию, Search и Details на поддерживаемом устройстве.
- **RCB-AC-32:** стандартный investor-demo выполняет 0 тарифицируемых
  routing/elevation/Places вызовов и подтверждает это cost ledger.
- **RCB-AC-33:** локальный routing строит geometry по versioned bounded graph;
  выход за покрытие честно блокируется без поддельного успешного результата.
- **RCB-AC-34:** замена demo adapters на production adapters не меняет Route
  domain, coordinator commands и пользовательские шаги.

## §15. Definition of Done

Slice считается завершённым, когда выполнены RCB-AC-01–34, решения
RCB-05/06 имеют собственные разрешающие gates, документация соответствует
фактическому коду, а опубликованный Route проходит доказуемую цепочку:

```text
authorized author
→ canonical draft
→ validated immutable version
→ consistent publish bundle
→ active Search result
→ saved polyline on Google Maps
```

Наличие красивого редактора без устойчивого хранения, capability enforcement,
версионности, поисковой проекции и проверенного потребительского отображения
не считается готовым Route-блоком.
