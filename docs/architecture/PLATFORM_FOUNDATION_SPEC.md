# RECHARGE — Platform Foundation Spec for Route Creation

Версия: v2.1 (2026-07-20).
Статус: Review — product intent approved, architecture gates pending.
Реализация: не начата.

Документ определяет минимальный платформенный фундамент, который позволяет
сначала показать инвесторам действительно работающий Route Create, а затем
подключить production-инфраструктуру без переписывания домена, application
logic и пользовательского потока.

Главный принцип поставки:

```text
рабочий investor-demo без тарифицируемой инфраструктуры
→ закрытый пилот на бесплатных квотах
→ production adapters после измерения спроса и отдельного одобрения расходов
```

Это не сокращённый продуктовый контракт. Полный Route Builder остаётся
заданным в [ROUTE_BUILDER_SPEC.md](../product/ROUTE_BUILDER_SPEC.md) v3.2,
а порядок его реализации — в
[ROUTE_CREATE_BLOCK_SLICE_SPEC.md](../product/ROUTE_CREATE_BLOCK_SLICE_SPEC.md).
Этапность меняет источник данных и эксплуатационный масштаб, но не модель
Route, validation rules, versioning или итоговый пользовательский результат.

При конфликте действует приоритет репозитория:

1. Accepted ADR;
2. [ROUTE_BUILDER_SPEC.md](../product/ROUTE_BUILDER_SPEC.md) для продуктового
   контракта Route;
3. Approved-спецификация текущего implementation slice;
4. этот документ как платформенный plan;
5. остальные документы согласно правилам репозитория.

Связанные источники истины:

- [ARCHITECTURE_BASELINE.md](ARCHITECTURE_BASELINE.md);
- [CI_GATES_POLICY.md](CI_GATES_POLICY.md);
- [0012-tech-stack-defaults.md](../adr/0012-tech-stack-defaults.md);
- [0013-domain-policy-baseline.md](../adr/0013-domain-policy-baseline.md);
- [CATEGORY_SYSTEM.md](../product/CATEGORY_SYSTEM.md);
- [LAUNCH_STATUS.md](LAUNCH_STATUS.md);
- [ROUTE_IMPLEMENTATION_ROADMAP.md](../product/ROUTE_IMPLEMENTATION_ROADMAP.md);
- [AGENTS.md](../../AGENTS.md).

---

## §1. Цель и доказуемый результат

### Investor-demo

На реальном устройстве представитель Recharge должен пройти полный путь:

1. войти под локальной демонстрационной учётной записью с `create_route`;
2. открыть Route в общем Create Hub;
3. поставить anchors на карте в пределах подготовленного покрытия;
4. получить соединение anchors по дорогам и тропам демонстрационного графа;
5. отредактировать segment, добавить waypoint и увидеть пересчёт показателей;
6. сохранить draft, закрыть приложение и восстановить его после запуска;
7. пройти validation и опубликовать локальную неизменяемую версию;
8. найти Route через обычный Search;
9. открыть Details и увидеть ту же сохранённую polyline на карте;
10. повторить просмотр без единого routing/elevation запроса.

Демонстрация считается работающей только при настоящем прохождении команд,
хранения, восстановления, projection building и поиска. Записанное видео,
набор несвязанных экранов или линия, нарисованная поверх изображения без
доменной модели, не являются выполнением результата.

### Честные ограничения демонстрации

- Географическое покрытие задаётся `DemoCoverageConfig` и показывается автору.
- Вне покрытия новая маршрутизация недоступна, но draft не теряется.
- Routing строится по подготовленному локальному графу, а не имитируется
  случайной линией.
- Данные имеют provenance `demoGraph` и не могут попасть в production seed
  без повторной проверки.
- Page publisher, реальная модерация и публичный backend остаются выключены.
- Режим не заявляется инвесторам как production-scale infrastructure.

### Production-результат

После замены adapters тот же flow работает с разрешёнными tiles, routing,
elevation, backend authorization и persistent publication. UI и domain не
знают, используется локальный граф, бесплатная квота или production service.

## §2. Неизменяемые архитектурные решения

1. Репозиторий остаётся монорепо `apps/mobile + packages/*` под Melos.
2. Слои feature: `presentation → application → domain`, `data → domain`.
3. Riverpod управляет состоянием; `get_it` используется в composition root;
   feature-код получает зависимости через constructor injection.
4. Системные роли: `User`, `Creator`, `Admin`. Доверие и полномочия выражаются
   capabilities, ownership и audit, а не новыми ролями.
5. Route — непрерывный трек по местности с anchors, segments, geometry,
   elevation и waypoint по километражу.
6. Авторский и потребительский картографические контуры разделены.
7. Публичный просмотр использует сохранённую geometry и не строит маршрут.
8. Опубликованная версия неизменяема. Любое обновление создаёт новую version.
9. Клиентские secrets запрещены. Публично извлекаемый SDK identifier не
   называется secret и обязательно ограничивается platform/API restrictions.
10. Firebase и другие production integrations остаются за действующими gates.
11. Новые packages и изменения frozen baseline требуют ADR.
12. Demo-first не разрешает provider DTO, business logic или временные схемы в UI.

## §3. Стадии поставки и стоимость

| Стадия | Назначение | Данные и adapters | Целевые расходы |
|---|---|---|---|
| `D0 local` | разработка и автоматические тесты | fixtures, fake map, in-memory repositories | без внешних счетов |
| `D1 investor` | демонстрация на устройстве | локальный trail graph, локальное хранение, demo map assets или no-cost SDK | без тарифицируемых API-вызовов |
| `D2 closed pilot` | ограниченные доверенные авторы | free-tier adapter с hard quota либо собственный малый deployment | в утверждённом нулевом/минимальном бюджете |
| `P1 production` | публичный запуск | approved adapters, backend authorization, monitoring | по отдельному budget approval |

Переход между стадиями меняет DI composition и configuration. Он не создаёт
другую сущность Route и не требует миграции пользовательского flow.

### Что действительно блокирует Route

| Перед этапом | Обязательный foundation |
|---|---|
| Route domain и mapper | geo value objects, ID/envelope decision, encoding policy |
| points/freehand editor | authoring surface contract, local graph adapter, operation guards |
| локальная публикация и Search | capabilities mock, publisher contract, publish bundle, projections |
| GPX/GPS/media preview | safe file boundary и локальный media lifecycle |
| production adapters | Accepted ADR, backend authorization, legal/security/cost gates |

Миграция общей денежной модели, полный вынос каталога из Discover и полное
сокращение legacy allowlist выполняются параллельно и не блокируют Route domain
или investor-demo.

## §4. Access и Publisher foundation

### Типизированные идентификаторы

```dart
extension type const CapabilityId(String value) {}
extension type const AccessOperationId(String value) {}

abstract final class RouteCapabilities {
  static const create = CapabilityId('create_route');
  static const publish = CapabilityId('publish_route');
  static const manage = CapabilityId('manage_route');
  static const archive = CapabilityId('archive_route');
}

final class CapabilitySet {
  const CapabilitySet({
    required this.ids,
    required this.permissionsRevision,
  });

  final Set<CapabilityId> ids;
  final int permissionsRevision;
}
```

Стабильные persisted IDs сохраняются, но произвольные строки не проходят по
application-коду. Роль может задавать начальный capability bundle, однако
проверки операций никогда не ветвятся по роли.

### Publisher

```dart
enum PublisherType { user, page }

final class PublisherRef {
  const PublisherRef({required this.type, required this.id});
  final PublisherType type;
  final String id;
}

final class PublisherAuthorizationContext {
  const PublisherAuthorizationContext({
    required this.publisher,
    required this.ownershipRevision,
  });
  final PublisherRef publisher;
  final int ownershipRevision;
}
```

`Admin` не получает неограниченное владение автоматически: обход ownership,
если он вообще разрешён политикой, является отдельной audited operation.
Investor-demo публикует только от имени текущего demo-user. Page publisher
включается после ManagedPage ownership и backend enforcement.

### Access policy

```dart
sealed class AccessResource {
  const AccessResource();
}

final class NewRouteResource extends AccessResource {
  const NewRouteResource({required this.marketId});
  final String marketId;
}

final class ExistingRouteResource extends AccessResource {
  const ExistingRouteResource({
    required this.routeId,
    required this.publisher,
  });
  final String routeId;
  final PublisherRef publisher;
}

sealed class AccessDecision {
  const AccessDecision();
}

final class AccessAllowed extends AccessDecision {
  const AccessAllowed();
}

final class AccessDenied extends AccessDecision {
  const AccessDenied(this.code);
  final AccessDenyCode code;
}
```

`AccessDenyCode` — закрытый типизированный набор со стабильными persisted IDs.
Локализуемые тексты и recovery actions загружаются из presentation catalog;
неизвестный внешний код отображается как безопасный generic deny и не меняет
решение политики.

Guards независимы:

- router не открывает flow по deep link без session/capability;
- application проверяет доступ перед save/publish/manage/archive;
- backend после подключения принимает окончательное решение по свежим claims.

Client deny telemetry агрегируется и ограничивается. Полный security audit
пишется backend для привилегированных операций, без токенов и geometry.

## §5. Geo и картографические контракты

### Размещение

До отдельного ADR общие типы живут в `apps/mobile/lib/core/geo/`. Новый package
не создаётся только ради Route. Выделение `packages/geo_primitives` допустимо,
когда появится второй independently built consumer.

Минимальный канон:

- `GeoPoint` с validation latitude/longitude;
- `GeoBounds` с anti-meridian semantics;
- `Viewport` и `CameraState`;
- `GeometryHash`;
- `EncodedPolyline` и versioned encoding policy;
- distance/precision utilities без Flutter и provider SDK.

Polyline codec хранится рядом с geo serialization, но не объявляется value
object карты. Domain оперирует canonical points/geometry, data выбирает codec.

### Два интерфейса

`AuthoringMapSurface` принимает layers и преобразует edit gestures в intents:
tap, drag, select, split target, viewport change. Он не решает, как изменить
RouteDraftData.

`ConsumerMapRenderer` принимает camera, markers и сохранённые polylines. В его
API отсутствуют routing, elevation и edit-команды.

Объединённый универсальный `MapService` запрещён: он сделал бы запрещённые
операции доступными потребительскому контуру.

### Владение routing-контрактами

Platform владеет только geo primitives, renderer contracts и общим
`ProviderReference`. Route domain владеет `RouteRoutingRepository`,
`RouteElevationRepository`, requests, results, profiles и fallback policy.
Foundation не создаёт дубликаты этих портов.

### Investor routing adapter

`DemoRouteGraphAdapter` выполняет настоящее детерминированное построение по
подготовленному OSM-derived graph ограниченного покрытия:

- graph version и bounds известны;
- алгоритм и weighting version записываются в provenance;
- одинаковый request даёт одинаковую canonical geometry;
- никакой сетевой запрос не требуется;
- путь вне graph возвращает typed `outsideDemoCoverage`;
- лицензия и attribution поставляются вместе с graph manifest;
- публичные OSM tile servers не используются.

Реальный provider adapter позже проходит тот же Route repository contract
suite. Его SDK/DTO остаются в data.

## §6. Create draft envelope и публикация

### Additive envelope

```dart
final class CreateDraftEnvelope {
  const CreateDraftEnvelope({
    required this.draftId,
    required this.objectType,
    required this.publisher,
    required this.revision,
    required this.schemaVersion,
    required this.syncState,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.contentId,
    this.basePublishedVersionId,
  });

  final String draftId;
  final String? contentId;
  final CreateObjectType objectType;
  final PublisherRef publisher;
  final int revision;
  final int schemaVersion;
  final DraftSyncState syncState;
  final String? basePublishedVersionId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
}
```

- `draftId` идентифицирует черновик и создаётся клиентским ID generator.
- `contentId` отсутствует до первой публикации.
- Временный legacy `loc_*` допустим только для несохранённых старых данных и
  заменяется постоянным ID до publication bundle.
- `revision` защищает сохранение и sync всего draft.
- Route geometry имеет независимый `geometryRevision` для provider responses,
  commands и undo/redo.

Изменение geometry инкрементирует обе revision; изменение metadata — только
envelope revision. Специализированный section revision удаляется лишь когда
доказано, что он полностью дублирует envelope и не защищает свою async operation.

Envelope вводится совместимо: новые Route drafts сразу используют канон,
существующие Create-типы мигрируют отдельными reviewable slices. Investor-demo
не требует массовой перезаписи Event/Place.

### Publish attempt

Idempotency принадлежит попытке, а не постоянно draft:

```dart
final class PublishAttempt {
  final String publishAttemptId;
  final String draftId;
  final int draftRevision;
  final DateTime createdAtUtc;
}
```

Один `publishAttemptId` повторяется при retry до однозначного успеха/отмены. Новая
публикация создаёт новый attempt. Bundle атомарно связывает:

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

Investor repository сохраняет bundle локальной транзакцией. Production
repository обязан обеспечить эквивалентную атомарность или outbox protocol.

## §7. Error, media и configuration

### Ошибки

Все ошибки реализуют общий контракт `FailureCode`, но реестры принадлежат
своим namespace owners:

```text
core.*
access.*
media.*
route.routing.*
route.validation.*
route.publication.*
```

Core задаёт формат, retryability и безопасное отображение. Route и access
задают собственные закрытые наборы. Единого изменяемого god-registry нет.
Raw infrastructure exception не пересекает data boundary.

### Локальный media lifecycle

Feature domain не хранит raw path. Application работает с `MediaRef`:

```text
localPending(localMediaId)
processing(localMediaId)
ready(mediaId)
failed(localMediaId, safeFailureCode)
```

Platform picker adapter может временно видеть platform file reference, но он
не попадает в domain, telemetry или publish payload. Для investor-demo media
санитайзится и хранится локально. Production upload, retry, cancellation и
orphan cleanup включаются отдельным adapter после Storage/backend gate.

Обязательная обработка: signature check, decode/size limits, orientation
normalization, удаление EXIF/GPS/device metadata и доступное описание.

### Config

Все лимиты и switches читаются из versioned configuration:

- `RouteProductConfig`;
- `RouteImportConfig`;
- `RouteGeometryEncodingPolicy`;
- `DemoCoverageConfig`;
- `ProviderCostPolicy`;
- market, locale и attribution config.

UI не содержит числовых product limits, provider URLs и market defaults.

## §8. Cost Safety Contract

### Классы стоимости

```dart
enum CostClass { zeroCost, freeTier, metered, forbiddenByDefault }

final class ProviderCostPolicy {
  final String providerId;
  final CostClass costClass;
  final int dailyRequestLimit;
  final int monthlyRequestLimit;
  final int warningPercent;
  final bool hardStopEnabled;
  final bool enabled;
}
```

Pricing и free caps меняются во времени, поэтому суммы не хардкодятся в
product spec. Release checklist сверяет policy с актуальными официальными
условиями поставщика.

### Обязательные правила

1. Любой `metered` adapter выключен до budget approval.
2. Investor-demo не выполняет тарифицируемых routing/elevation/Places вызовов.
3. Search/Details никогда не вызывают routing/elevation.
4. Routing cache key включает graph/profile/options/input fingerprint/version.
5. Повтор одинаковой операции дедуплицируется.
6. Quota exhaustion возвращает typed failure и сохраняет draft.
7. Public viewing продолжает работать при остановленном authoring adapter.
8. Alerts срабатывают на конфигурируемых порогах до hard stop.
9. Приложение имеет kill switch для каждого внешнего adapter.
10. Автоматический upgrade тарифа или снятие hard cap запрещены.
11. Cost telemetry не содержит geometry, GPS history и пользовательские тексты.
12. Dashboard показывает requests, cache hit rate, failures и стоимость на один
    опубликованный Route; стоимость просмотра должна оставаться нулевой для
    routing/elevation контура.

### Google consumer map

Google Maps mobile SDK допускается как consumer adapter, пока release review
подтверждает его no-cost/approved usage для выбранных платформ. Billing account
и platform-restricted API identifier не считаются разрешением использовать
Routes, Places, Elevation, Street View или другие billable SKU.

При изменении цены или условий adapter отключается configuration switch без
изменения сохранённой geometry. Для investor-demo должен существовать
provider-neutral fallback renderer.

### Open data

Open-source code не означает бесплатную инфраструктуру и не отменяет лицензии.
OSM attribution, ODbL obligations, source snapshot и data version обязательны.
Публичные community tile endpoints не используются как production CDN.

## §9. Route Quality Contract

Конкурентное преимущество строится не на количестве кнопок, а на доверии к
опубликованному маршруту.

### Проверяемость

Каждая published version хранит:

- publisher и authoring audit reference;
- geometry hash и encoding version;
- graph/provider/data versions;
- source каждого segment;
- дату технической проверки;
- дату field verification, если она проводилась;
- validation snapshot;
- warnings, ограничения и сезонность;
- superseded version reference.

### Verification status

```text
draft
technicallyValidated
fieldChecked
published
needsReview
suspended
archived
```

Статус не вычисляется по рейтингу. `fieldChecked` требует подтверждённого
действия уполномоченного автора и времени проверки.

### Map-change review

Новый graph snapshot не перезаписывает published geometry. Система строит
candidate version и diff:

- изменённые segments подсвечены;
- показаны distance/elevation/surface deltas;
- указана причина: access, closure, missing path или data correction;
- автор может принять, отклонить, исправить вручную или отложить;
- принятие публикует новую immutable version;
- rollback выпускает ещё одну version и не изменяет историю.

### Safety feedback

Пользователь может сообщить о закрытии, опасности, ошибочной поверхности или
несовпадении линии. Report не правит Route автоматически. Он создаёт issue,
может переключить status в `needsReview` и уведомляет владельца по policy.
Критическое подтверждённое ограничение может скрыть Route из Search без
удаления audit/version history.

### Измеримые показатели

| Показатель | Investor gate | Production direction |
|---|---|---|
| published geometry consistency | version/hash совпадают во всех read-моделях | 100% |
| платные routing/elevation вызовы при просмотре | 0 | 0 |
| потерянные drafts после restart | 0 на acceptance suite | 0 подтверждённых incidents |
| устаревшие async ответы, применённые к draft | 0 | 0 |
| Route без provenance | 0 | 0 |
| неподтверждённая автоматическая мутация published geometry | 0 | 0 |
| время появления локально опубликованного Route в Search | в пределах UI budget | контролируемый SLO |
| investor-demo network dependency | 0 обязательных запросов | не применяется |

## §10. Parallel platform debt

Эти задачи полезны, но не входят в критический путь investor-demo:

### Catalog boundaries

Нужно сокращать прямые cross-feature импорты, но один `domain_catalog` не
решит зависимости на controllers/providers/widgets. Требуется отдельный plan:

- catalog read contracts;
- Search/favorites facades;
- composition-root wiring;
- удаление UI-to-UI imports;
- монотонное сокращение structured registry
  `tools/scripts/boundary-exceptions.json` без увеличения exception budget.

Новый package создаётся только через ADR. Money и geo не помещаются внутрь
product catalog.

### Money

Целевой канон: integer minor units + currency code + currency metadata.
Миграция `double` выполняется отдельно и не блокирует Route, пока Route не
получает денежных полей.

### Test layout

Route следует фактической структуре репозитория:

```text
apps/mobile/test/unit/
apps/mobile/test/widget/
apps/mobile/test/support/
```

Feature-first migration может быть принята позже отдельным решением. Две
одновременные конвенции для новых тестов не вводятся.

## §11. Workstreams и зависимости

| WS | Содержание | Блокирует | Gate выхода |
|---|---|---|---|
| PF-01 | geo primitives, encoding/hash contracts | Route domain | unit + property tests |
| PF-02 | additive envelope, IDs, revisions, local transaction | Route mapper/publish | migration fixtures + fault tests |
| PF-03 | typed access, publisher, demo policy | Create entry/publish | policy + deep-link integration |
| PF-04 | authoring/consumer map contracts, local graph adapter | points editor | contract + deterministic fixtures |
| PF-05 | namespaced failures, config, cost policy | external operations | unit + boundary + quota tests |
| PF-06 | local media safety boundary | GPX/GPS/media | privacy + malformed input tests |
| PF-07 | documentation synchronization | review start | links/status/file plan audit |
| PF-08 | catalog/money/allowlist debt | не блокирует investor-demo | отдельные stabilization slices |

Допустимый параллелизм:

```text
PF-01 ───────────────→ Route domain
PF-02 ───────────────→ Route mapper + local publish
PF-03 ───────────────→ guarded Create + publish
PF-04 ───────────────→ points/freehand editor
PF-05 ─┬─────────────→ provider-safe operations
PF-06 ─┘─────────────→ file/media features
PF-07 ───────────────→ implementation review
PF-08 ───────────────→ independent stabilization
```

Route work не ждёт полного завершения PF-08. Production adapters ждут
Accepted ADR, stabilization exit, backend rules, legal review и cost approval.

## §12. План файлов foundation

План уточняется каждым implementation slice до кода. Базовое размещение:

```text
apps/mobile/lib/core/geo/geo_point.dart
apps/mobile/lib/core/geo/geo_bounds.dart
apps/mobile/lib/core/geo/geometry_encoding.dart
apps/mobile/lib/core/geo/geometry_hash.dart
apps/mobile/lib/core/access/capability_id.dart
apps/mobile/lib/core/access/access_decision.dart
apps/mobile/lib/core/access/access_policy.dart
apps/mobile/lib/core/config/provider_cost_policy.dart
apps/mobile/lib/core/media/media_ref.dart
apps/mobile/lib/core/media/media_pipeline.dart
apps/mobile/lib/features/create/domain/entities/create_draft_envelope.dart
apps/mobile/lib/features/create/domain/entities/publisher_ref.dart
apps/mobile/lib/features/create/domain/entities/publish_attempt.dart
apps/mobile/lib/features/create/domain/repositories/create_publication_repository.dart
apps/mobile/lib/features/create/data/datasources/demo_route_graph_datasource.dart
apps/mobile/lib/features/create/data/repositories/demo_route_routing_repository.dart
apps/mobile/lib/features/create/application/route_create_config.dart
apps/mobile/lib/features/create/application/route_create_coordinator.dart
```

Business decisions не помещаются в `core`. Если capability policy зависит от
publisher/Route semantics, интерфейс может жить в domain Create, а core хранит
только общие value objects. Фактический file plan обязан следовать boundary
gate, а не этому списку буквально.

## §13. Тестовая стратегия

### Unit/property

- geo validation, bounds, distance, encoding precision и hash stability;
- envelope и geometry revisions;
- access matrix по operation/resource/publisher;
- deterministic graph routing и outside-coverage failure;
- stale operation rejection;
- publish attempt idempotency;
- projection/full geometry consistency;
- config defaults и cost hard stops.

### Contract/integration

- fake, demo и будущий provider adapters проходят один Route port suite;
- router/application policy не расходятся;
- local transaction не создаёт partial publication;
- restart восстанавливает последний persisted revision;
- Search получает только успешно опубликованную projection;
- consumer renderer не может вызвать routing/elevation;
- quota exhaustion не повреждает draft.

### Privacy/security

- malformed GPX/media не выходит из safe boundary;
- metadata sanitation;
- отсутствие secrets и geometry в logs/telemetry;
- direct deep link deny;
- publisher ownership deny;
- restricted SDK identifier не даёт доступ к лишним API.

### Investor end-to-end

Автоматизированный или воспроизводимый manual script проходит §1 от создания
до повторного Search/Details после restart, с cost ledger `0 metered calls`.
В demo package хранится reset action, чтобы восстановить исходное состояние
без удаления пользовательских файлов вне sandbox приложения.

## §14. Acceptance criteria

| ID | Проверяемый результат | Покрытие |
|---|---|---|
| PF-AC-01 | Investor flow §1 проходит на реальном поддерживаемом устройстве | end-to-end |
| PF-AC-02 | Demo routing использует versioned local graph и строит путь по его edges | contract + visual check |
| PF-AC-03 | Выход за demo coverage возвращает typed failure и не повреждает draft | unit + widget |
| PF-AC-04 | Demo provenance не может попасть в production seed без explicit review | boundary + publish test |
| PF-AC-05 | Системные роли ограничены User/Creator/Admin; policy проверяет capability | boundary + unit |
| PF-AC-06 | Capability, operation и resource типизированы; произвольный context map не используется | compile + review |
| PF-AC-07 | Router и application независимо блокируют запрещённую операцию | integration |
| PF-AC-08 | Demo page publishing запрещён без ManagedPage ownership | contract |
| PF-AC-09 | AuthoringMapSurface и ConsumerMapRenderer разделены | boundary |
| PF-AC-10 | Consumer contract не содержит routing/elevation/edit methods | contract snapshot |
| PF-AC-11 | Route domain остаётся владельцем routing/elevation ports | boundary |
| PF-AC-12 | Geo primitives не зависят от Flutter/provider SDK | boundary |
| PF-AC-13 | draftId, contentId и legacy temporary ID имеют разные semantics | mapper fixtures |
| PF-AC-14 | Envelope вводится без массовой миграции существующих Create payload | regression suite |
| PF-AC-15 | Envelope и geometry revisions ведут себя по §6 | unit + concurrency |
| PF-AC-16 | Publish attempt идемпотентен; partial bundle не считается успехом | integration |
| PF-AC-17 | Search projection и full geometry имеют общий version/hash | contract |
| PF-AC-18 | Namespaced failures следуют общему формату без god-registry | boundary + snapshot |
| PF-AC-19 | Domain/persisted payload не содержит raw file path | privacy boundary |
| PF-AC-20 | Media sanitation удаляет EXIF/GPS/device metadata | privacy integration |
| PF-AC-21 | Product limits, market и provider switches приходят из versioned config | unit + review |
| PF-AC-22 | Investor-demo выполняет 0 metered API calls | cost ledger + end-to-end |
| PF-AC-23 | Search/Details выполняют 0 routing/elevation calls | boundary + end-to-end |
| PF-AC-24 | Quota exhaustion сохраняет draft и не ломает published viewing | resilience |
| PF-AC-25 | Каждый metered adapter выключен до budget approval | config + release check |
| PF-AC-26 | Публичные OSM tile endpoints не используются как application CDN | config + network test |
| PF-AC-27 | Attribution и data/provider versions доступны в Route details | widget + legal review |
| PF-AC-28 | Map data update создаёт candidate/diff, но не мутирует published version | integration + audit |
| PF-AC-29 | Field verification нельзя получить без audited author action | policy test |
| PF-AC-30 | Safety report создаёт issue и не правит geometry автоматически | integration |
| PF-AC-31 | Потеря сети/provider не мешает открыть сохранённый published Route | resilience end-to-end |
| PF-AC-32 | Route tests используют текущую test structure репозитория | file audit |
| PF-AC-33 | Новые packages не добавлены без Accepted ADR | architecture gate |
| PF-AC-34 | `flutter analyze`, `flutter test` и boundary gate зелёные для каждого slice | CI |
| PF-AC-35 | Документация и LAUNCH_STATUS отражают фактическую, а не планируемую реализацию | docs audit |

## §15. Definition of Done

Foundation для investor-demo готов, когда PF-01–07 выполнены в необходимом
для соответствующего Route этапа объёме, PF-AC-01–35 подтверждены применимо к
поставленному scope, а демонстрация проходит следующую доказуемую цепочку:

```text
authorized demo author
→ real commands over a bounded trail graph
→ revision-safe persisted draft
→ validated immutable local version
→ consistent Search projection
→ saved polyline in Details
→ restart and repeat viewing
→ zero metered API calls
```

PF-08 не является условием investor-demo. Production readiness наступает
отдельно: после Accepted ADR, stabilization exit, backend authorization,
ManagedPage ownership, legal/security review, provider contract tests,
observability и утверждённого бюджета.

Инвестору показывается работающая вертикаль и честный путь масштабирования,
а не обещание бесплатной production-инфраструктуры без ограничений.

## §16. Внешние условия, проверяемые перед release

Условия поставщиков не являются вечной частью архитектуры и проверяются по
официальным источникам на каждом release gate:

- Google Maps Platform pricing and billing:
  <https://developers.google.com/maps/billing-and-pricing/overview>;
- Maps SDK usage and billing:
  <https://developers.google.com/maps/documentation/android-sdk/usage-and-billing>;
- Firebase pricing plans:
  <https://firebase.google.com/docs/projects/billing/firebase-pricing-plans>;
- OpenStreetMap tile usage policy:
  <https://operations.osmfoundation.org/policies/tiles/>;
- Valhalla repository and license:
  <https://github.com/valhalla/valhalla>.

Release review фиксирует дату проверки, применимые SKU/квоты, лицензионные
обязательства, hard limits и владельца billing alerts. Изменение условий не
переписывает domain: оно меняет policy либо adapter.
