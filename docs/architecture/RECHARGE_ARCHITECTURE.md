# RECHARGE — архитектура продукта

- Версия: v1.2 (2026-07-31)
- Статус: актуальный архитектурный обзор
- Владелец: Recharge team

Этот документ — единая точка входа в архитектуру Recharge. Он объясняет, как
принятые решения складываются в работающую систему, но не заменяет Accepted
ADR, frozen baseline или спецификацию активной задачи.

## 1. Архитектурная власть

При конфликте применяется следующий приоритет:

1. Accepted ADR в `docs/adr/`;
2. спецификация активной задачи в `docs/product/`;
3. [LAUNCH_STATUS](LAUNCH_STATUS.md);
4. [Product Vision](../product/VISION.md);
5. этот обзор как навигационное и объясняющее представление.

Канонические основания:

- [ADR 0011 — Architecture Freeze](../adr/0011-architecture-freeze.md);
- [ADR 0012 — Tech Stack Defaults](../adr/0012-tech-stack-defaults.md);
- [ADR 0013 — Domain And Product Policy](../adr/0013-domain-policy-baseline.md);
- [ADR 0014 — Time-Fit Ranking](../adr/0014-time-fit-ranking.md);
- [ADR 0015 — Authenticated Viewer, Verified Creator And Professional Page](../adr/0015-authenticated-viewer-verified-creator-professional-page.md);
- [ADR 0016 — Bounded Identity And Workspace During Stabilization](../adr/0016-bounded-identity-workspace-during-stabilization.md);
- [ADR 0017 — Admin Experience Preview And User-Created Professional Pages](../adr/0017-admin-experience-preview-and-user-created-pages.md);
- [Architecture Baseline](ARCHITECTURE_BASELINE.md);
- [Import Boundaries](IMPORT_BOUNDARIES.md);
- [Change Policy](CHANGE_POLICY.md).

Новый top-level package, новый слой, изменение направления зависимостей,
ответственности package или обязательного стека требует mini-RFC и нового ADR.
Этот файл обновляется после принятия решения, а не используется вместо него.

### Обозначения

| Метка | Значение |
|---|---|
| Accepted | решение обязательно и обеспечивается review/CI |
| Implemented | решение присутствует в текущем коде |
| Target | утверждённое направление, реализация ещё неполна |
| Proposed | предложение, которое нельзя считать решением до ADR/approval |
| Debt | известное расхождение кода и принятой модели |

---

## 2. Архитектурные цели

Архитектура должна обеспечивать одновременно:

1. единый пользовательский поток поиска и выбора досуга;
2. создание всех принятых типов контента через один form engine;
3. изоляцию бизнес-правил от Flutter, Firebase и картографических SDK;
4. заменяемые mock/local/remote datasources;
5. безопасную офлайн-работу с черновиками;
6. capability-based доступ, переключение personal/page workspace и публикацию
   от имени user или ManagedPage без смешивания этих понятий;
7. версионируемые taxonomy, contracts, drafts и published entities;
8. предсказуемые изменения без прямых связей между features;
9. независимые deploy/rollback высокорисковых integrations через config;
10. обязательные quality gates до завершения каждой задачи.

Не является целью создание универсального framework внутри приложения.
Абстракция вводится вокруг реальной изменяемой зависимости или устойчивого
контракта, а не ради потенциального переиспользования.

---

## 3. Системный контекст

```text
Authenticated account: User / Creator / Admin
          │ access snapshot
          ├─ Personal workspace
          ├─ Professional Page workspace(s)
          └─ Admin tools (not a workspace/publisher)
          │
          ▼
┌───────────────────────────────┐
│ Flutter mobile app            │
│ presentation + application    │
│ domain + data adapters        │
└──────────────┬────────────────┘
               │ repository/API contracts
      ┌────────┼───────────────┐
      ▼        ▼               ▼
 local/mock  Firebase target  external providers
 storage     Auth/Firestore   maps/routing/media
             Storage          telemetry
```

Сейчас продукт работает преимущественно на mock/local datasources. Firebase —
целевая backend-платформа, но её подключение является отдельной задачей после
стабилизации. Переход не должен менять domain, application или presentation
contracts.

---

## 4. Monorepo

```text
recharge/
├─ apps/
│  └─ mobile/
│     ├─ android/ ios/ web/
│     ├─ assets/
│     ├─ lib/
│     │  ├─ app/
│     │  ├─ core/
│     │  ├─ shared/
│     │  ├─ features/
│     │  ├─ generated/
│     │  └─ main.dart
│     ├─ test/
│     └─ integration_test/
├─ packages/
│  ├─ design_system/
│  └─ api_contracts/
├─ docs/
│  ├─ adr/
│  ├─ architecture/
│  ├─ product/
│  ├─ api/
│  └─ runbooks/
├─ tools/
├─ melos.yaml
└─ analysis_options.yaml
```

### Ответственность верхнего уровня

| Область | Владеет | Не владеет |
|---|---|---|
| `apps/mobile` | composition, features, platform integration | reusable design tokens, canonical API DTO |
| `packages/design_system` | tokens, theme, primitives, reusable UI | feature state, repositories, product rules |
| `packages/api_contracts` | canonical contracts, DTO, serializers, generated clients | domain entities, UI models, repository policy |
| `docs/adr` | принятые архитектурные решения | детали одной реализации |
| `docs/product` | поведение и acceptance criteria | изменение frozen architecture без ADR |
| `tools` | repeatable local/CI automation | runtime business logic |

`apps/mobile` может зависеть от обоих packages. Packages не зависят от app или
features. `design_system` и `api_contracts` не зависят друг от друга без
отдельно обоснованного контракта.

---

## 5. Слои feature

Каждый product feature использует четыре слоя:

```text
presentation ──► application ──► domain
      │                              ▲
      └──────────────────────────────┘

data ───────────────────────────────► domain
```

### Матрица импортов

| Из слоя | Разрешено | Запрещено |
|---|---|---|
| `presentation` | presentation, application, domain | data |
| `application` | application, domain | data, presentation |
| `data` | data, domain | application, presentation |
| `domain` | domain | data, application, presentation, Flutter/SDK |

### Domain

Содержит:

- entities и value objects;
- repository/service interfaces;
- usecases и чистые policies;
- validators и типизированные failures;
- бизнес-инварианты и state transitions.

Domain не импортирует Flutter, SDK provider, datasource, DTO или UI types.

### Application

Содержит:

- `Notifier`/`AsyncNotifier` controllers;
- immutable feature state;
- orchestration нескольких domain operations;
- cancellation, concurrency и stale-response guards;
- mapping domain result в состояние пользовательского потока.

Controller получает зависимости через constructor injection и не создаёт
repository/datasource самостоятельно.

### Data

Содержит:

- repository implementations;
- local, mock и remote datasources;
- persistence/network models;
- DTO ↔ domain mappers;
- cache, retry и migration mechanics в рамках domain contract.

Raw infrastructure exception преобразуется в `AppException`/`Failure` до
выхода из data boundary.

### Presentation

Содержит pages, feature widgets и UI composition. Presentation:

- читает application state и отправляет user intents controller;
- не вызывает datasource;
- не рассчитывает бизнес-показатели;
- не решает permissions, validation или publish lifecycle;
- использует design system вместо локальных копий общих компонентов.

---

## 6. App, core и shared

### `app/` — composition root

`app/` связывает систему:

- bootstrap environments и services;
- `get_it` registrations;
- `ProviderScope` и observers;
- `go_router`, global guards и deep links;
- theme composition из `packages/design_system`;
- market/runtime config;
- feature facades.

`app/` может знать о feature entry points для wiring, но не содержит их
бизнес-логику.

### `core/` — техническая инфраструктура

Допустимы errors, telemetry, security, storage, network, platform services,
configuration, id generation и общие технические utilities.

Запрещены product workflows, правила поиска, публикации, маршрута, категорий
или permissions. Техническая универсальность важнее числа потребителей.

### `shared/` — стабильные междоменные примитивы

Здесь допустимы устойчивые primitives вроде `GeoPoint`, `Money`, pagination и
унифицированного result type. Тип не становится shared только потому, что его
используют две features: сначала определяется семантический владелец и
стабильность контракта.

Cross-feature product entities не переносятся в shared для обхода boundaries.
Для взаимодействия используются contracts/facades.

---

## 7. Cross-feature взаимодействие

Прямой import `features/A → features/B` запрещён.

Разрешённые механизмы:

1. стабильный facade, объявленный владельцем capability;
2. domain-neutral contract в допустимом общем package;
3. route/deep-link contract;
4. app-level orchestration в composition root;
5. immutable id/seed object без передачи controller или repository.

```text
Feature A ─► contract/facade ◄─ app wiring ─► Feature B
```

Feature владеет своими entities, storage и state. Другой feature передаёт id
или request contract, а не читает его datasource или внутренний controller.

Boundary gate обязателен локально и в CI. Новая запись в legacy allowlist без
mini-RFC и ADR запрещена.

---

## 8. Обязательный технический стек

| Область | Принятый default | Граница ответственности |
|---|---|---|
| State | Riverpod `Notifier` / `AsyncNotifier` | application state, не DI-container |
| DI | `get_it` в `app/di` | registrations в composition root, constructor injection внутри features |
| Navigation | `go_router` | centralized names, guards, deep links |
| HTTP | `dio` + interceptors | только за datasource/repository boundary |
| Secure storage | `flutter_secure_storage` | secrets/tokens, не обычные prefs |
| Maps | Google Maps для основной карты | SDK скрыт за feature/platform adapter |
| Errors | `AppException` → typed `Failure` | raw infra errors не пересекают boundary |
| Telemetry | единый facade | analytics, crash, logs без sensitive payload |

Immutable state обязателен. Способ генерации immutable/serialization code не
фиксируется этим обзором; generated files никогда не редактируются вручную.

Любое отклонение проходит workflow из ADR 0012 и имеет owner, срок,
migration/rollback plan.

---

## 9. Доменные области

| Область | Владеет | Основной contract |
|---|---|---|
| Auth | identity, session, auth state | `AuthRepository`, session facade |
| Discover | query, filters, feed, map projection, details lookup | `DiscoverRepository`, `DiscoverQuery` |
| Create | draft, form config, validation, media, publish | `CreateRepository`, type registry |
| Explore | profile и settings до принятого разделения | profile/settings repositories |
| Favorites | сохранённые объекты и запросы | `FavoritesRepository` |
| Notifications | notification feed и read state | `NotificationsRepository` |
| Quick Plan | локальный план независимых остановок | собственный draft/controller contract |

Route создаётся внутри Create как специализированный непрерывный трек. Quick
Plan является отдельным продуктовым доменом и не передаёт в Route свои поля,
режимы или внутреннее состояние. Между ними допустим только явный seed/intent
contract, утверждённый спецификацией.

Текущий legacy feature naming для Quick Plan — технический долг и не является
источником новой доменной модели.

---

## 10. Единый Discover flow

Сильное ядро Discover — один typed query и несколько независимых потребителей:

```text
Search input ─┐
Filters ──────┤
Categories ───┼─► DiscoverQueryController ─► DiscoverQuery
Time window ──┤                              │
Map area ─────┘                 ┌────────────┼────────────┐
                               ▼            ▼            ▼
                         FeedController MapController Details lookup
```

### Инварианты

1. Search, Filters, Map и Feed не хранят конкурирующие копии query.
2. Изменение query создаёт новую immutable revision.
3. Map viewport сначала меняет draft bounds; поиск выполняется после явного
   apply/search-this-area action согласно активной спецификации.
4. Feed и Map используют одну repository semantics, pagination и taxonomy.
5. Details загружает объект по id из того же доменного источника.
6. Stale async result не заменяет состояние более новой query revision.
7. Regular Search и Smart Search имеют разные entry UI/history, но используют
   общий downstream query/evaluation pipeline.
8. Zero-result relaxation предлагается пользователю и не меняет query молча.
9. Time-fit ranking применяется только по ADR 0014 и имеет kill switch.

### MapObject

`MapObject` — read projection разных content types, а не базовый класс их
domain entities. Projection содержит только поля, необходимые выдаче: id,
content type, publisher summary, location, availability summary, media preview
и ranking metadata.

Добавление нового content type расширяет mapper/contract выдачи, но не
заставляет остальные domain entities наследоваться от общего UI-типа.

---

## 11. Config-driven Create Hub

Create Hub поддерживает десять утверждённых `ContentType`:

```text
event | activity | route | place | session | classWorkshop |
quickPlan | findPeople | rental | collection
```

Все типы проходят единый lifecycle:

```text
select type
  → resolve CreateTypeConfig
  → render section registry
  → edit typed draft data
  → autosave
  → validate
  → preview
  → publish
  → pending_review / published lifecycle
```

### Главные компоненты

| Компонент | Ответственность |
|---|---|
| `CreateTypeRegistry` | отображает `ContentType` на versioned config |
| `CreateTypeConfig` | sections, defaults, limits, validators, preview contract |
| `CreateSectionDefinition` | декларативное подключение общей/специальной секции |
| `CreateDraft` | общие поля, publisher, schema/revision, typed section payload |
| `CreateController` | application orchestration и state transitions |
| `ValidateDraftUseCase` | общие + type-specific rules одной версии |
| `PublishDraftUseCase` | capabilities, media, ids, idempotency, repository publish |
| `CreateRepository` | local/mock/remote persistence contract |

### Правила расширения

- новый блок для одного из десяти типов добавляется секцией и config;
- отдельный flow/page/controller на content type не создаётся;
- общая секция не содержит `if (type == ...)` business logic;
- type-specific domain data типизированы в runtime;
- raw `Map<String, Object?>` допустим только на mapper/storage boundary;
- форма, Preview и publish используют одну config/validation version;
- category/criteria берутся из Category System, а не локального списка;
- publisher хранится как `{type: user | page, id}`;
- локальный `loc_*` заменяется permanent ULID/UUID до публикации.

Route подключается через `RouteMapBuilderSection` внутри Create. Его
geometry, GPX, elevation, GPS и waypoint logic остаются в специализированных
domain/application компонентах, но используют общий draft/publish lifecycle.

Источник продуктового контракта:
[Route Builder Spec](../product/ROUTE_BUILDER_SPEC.md).

---

## 12. Route Builder в архитектуре

Route — непрерывная ordered geometry из anchors и segments. Это не список
самостоятельных мест и не общий механизм планирования.

Рекомендуемое размещение без нового top-level feature:

```text
features/create/
├─ domain/
│  ├─ route/entities/
│  ├─ route/repositories/
│  ├─ route/services/
│  └─ route/usecases/
├─ application/
│  ├─ route/controllers/
│  └─ route/state/
├─ data/
│  └─ route/{datasources,models,repositories,adapters}/
└─ presentation/
   └─ route/{sections,widgets,sheets}/
```

### Границы

- presentation отображает map/editor state и отправляет intents;
- application управляет revisions, async cancellation, autosave и commands;
- domain владеет topology, calculations, validation и service interfaces;
- data реализует GPX, persistence, routing/elevation adapters и mapper;
- provider SDK types не проходят в domain/application;
- main-map provider не определяет outdoor renderer автоматически;
- renderer, routing, elevation, tiles, attribution и offline topology требуют
  отдельного Accepted ADR до production integration.

Специализированный Create-блок является завершением принятого Create Hub
scope. Он не разрешает Firebase или иную интеграцию, запрещённую активной
стабилизацией.

Accepted ADR 0016 дополнительно разрешает во время стабилизации только
bounded local/mock IDP-03A/04A/05A: access/workspace foundation,
personal/page shell, local new-draft publisher defaults и capability guards.
Исключение не разрешает Firebase, production auth/verification/grants,
externally reachable ManagedPage publication или unrelated feature scope.

---

## 13. Identity, permissions и publisher

### Роли и capabilities

```text
roles: User | Creator | Admin
decision: role + capabilities + ownership + entity state
```

Роль используется для базовой классификации. Каждое привилегированное действие
проверяется отдельной capability: create, edit, publish, archive, delete,
manage page, moderation и другие принятые действия.

Viewer — продуктовый термин для авторизованного личного User-интерфейса.
Creator verification и grants расширяют этот же personal workspace; отдельного
ручного переключения Viewer/Creator нет. `Pro generator` — legacy UI debt, а
целевая профессиональная поверхность называется `Professional Page`.

Presentation может скрывать недоступное действие, но авторитетная проверка
выполняется в application/usecase и повторяется backend security rules.

### Account, workspace и Admin tools

Одна authenticated account может иметь:

```text
WorkspaceRef { type: personal | page, id: userId | pageId }
```

`personal` использует один consumer shell для Viewer и Creator:
`Home / Favorites / Smart Search / Notifications / Profile`. Наличие Creator
grants добавляет инструменты в Profile/Create Hub, но не меняет personal
navigation.

`page` использует professional shell:
`Page / Content / Create / Notifications / Account`. Page workspace активируется
только после проверки exact membership, page lifecycle и page-scoped grants.
Один пользователь может иметь произвольное число ManagedPage; active workspace
является preference и не выдаёт authority.

Admin tools — отдельный capability-gated route group. Он не кодируется в
`WorkspaceRef`, не участвует в `Publish as` и не может стать publisher.

Application-level workspace controller оркестрирует выбор shell и default
publisher через стабильный facade/contract. Feature presentation не импортирует
другие feature реализации напрямую. Settings только открывает workspace
switcher route; identity/application слой загружает membership и принимает
решение.

### Publisher

Публикуемый объект принадлежит owner и публикуется от имени:

```text
PublisherRef { type: user | page, id: ULID/UUID }
```

Display name, avatar или page title не являются связью. Rename не меняет
ownership. ManagedPage capabilities проверяются относительно конкретной page.

Active workspace задаёт publisher по умолчанию только новому draft:
personal → user publisher, page → page publisher. Persisted `PublisherRef`
существующего draft имеет приоритет. Workspace switch не переписывает его
молча; invalid/revoked page publisher блокирует privileged mutation до явного
решения.

Международные контракты используют stable country/market codes, IANA timezone,
ISO currency и locale metadata. UI labels локализуются отдельно от persisted
role/workspace/capability codes.

### Lifecycle

Принятые состояния:

```text
draft → pending_review → published → archived
                         │
                         ├─ hidden
                         └─ deleted (после retention/legal policy)
```

Переходы выполняются usecase, проверяют capability и записываются в audit.
UI не присваивает lifecycle status напрямую.

---

## 14. Data, contracts и Firebase

### Три модели — три ответственности

| Модель | Где | Назначение |
|---|---|---|
| Domain entity | feature/domain | бизнес-смысл и инварианты |
| Data model | feature/data | local/remote persistence representation |
| API DTO | `packages/api_contracts` | versioned wire contract |

Совпадение полей не отменяет mapper. Domain entity не аннотируется под
Firestore/HTTP только ради удобства сериализации.

### API contracts

- canonical sources находятся в `packages/api_contracts/lib/src/contracts`;
- DTO/client генерируются и не редактируются вручную;
- breaking changes используют contract change workflow и SemVer;
- previous compatible artifact сохраняется на rollback window;
- app repository adapter переводит DTO в domain entity.

См. [API Contracts Workflow](../api/API_CONTRACTS_WORKFLOW.md).

### Firebase target

Целевые adapters:

- Firebase Auth: Google/Apple identity и session restore;
- Firestore: remote repositories, query projections и lifecycle data;
- Storage: media upload, variants и orphan cleanup;
- security rules: server-side ownership/capability enforcement.

Подключение выполняется отдельной задачей после стабилизации. До неё mock/local
datasources остаются единственной заявленной runtime-реализацией. UI и domain
не знают о Firestore collection paths, snapshots или SDK exceptions.

### ID, время и гео

- persistent ids — client-generated ULID/UUID;
- `loc_*` допустим только для несохранённого локального draft;
- timestamps сохраняются в UTC, локальная интерпретация использует IANA zone;
- geo содержит lat/lng, accuracy и market metadata;
- region, currency, locale и default coordinates приходят из config.

---

## 15. Local storage, offline и sync

Repository владеет persistence policy. UI не читает storage keys и не
сериализует entities.

### Draft guarantees

1. schema version присутствует с первого сохранения;
2. запись атомарна либо восстанавливается из последнего целого snapshot;
3. migration выполняется forward с guarded fallback;
4. media lifecycle отделён от finalization draft;
5. autosave failure видим пользователю;
6. logout не удаляет несинхронизированный draft молча.

Accepted baseline разрешает offline drafts и задаёт конфликтную политику
`last-write-wins + user warning`. Более сильное разрешение конфликтов —
например, ручной выбор geometry revision — требует нового ADR, потому что
меняет принятую policy.

Additional database/cache technology вводится только при подтверждённой
нехватке key-value storage и по deviation/ADR workflow.

---

## 16. Maps и location

Основная карта продукта использует Google Maps. Архитектурная граница отделяет:

| Компонент | Владелец |
|---|---|
| Domain geo primitives | `shared` или domain владельца |
| Search/map state | Discover application |
| Google Maps widget/adapter | Discover presentation/platform boundary |
| Location permission/service | core platform service |
| Route geometry/topology | Create Route domain |
| Routing/elevation contracts | Create Route domain services |
| Provider implementations | Create Route data adapters |

SDK coordinate, marker, camera и error types не становятся domain types.
Adapter выполняет mapping в обе стороны.

Для основной карты и Route Builder могут использоваться разные renderer/data
providers. Выбор outdoor renderer, routing/elevation, offline data, licensing,
attribution, cache и privacy фиксируется отдельным ADR.

Точные coordinates не попадают в analytics, logs или crash breadcrumbs.

---

## 17. Configuration, environments и flags

Поддерживаются `dev`, `stage`, `prod` с соответствующими flavors.

Configuration делится на:

- build-time environment identifiers;
- non-secret runtime config;
- remote product config;
- secret credentials в CI/secret manager;
- local untracked overrides для разработки.

Критические integrations имеют kill switch и rollback без app release.
Feature flag не используется как постоянная замена архитектурного решения или
permission check.

Нельзя хранить API keys, tokens, service accounts и signing data в source,
fixtures, docs, logs или analytics. См.
[Env, Flavors And Secrets](ENV_FLAVORS_SECRETS.md).

---

## 18. Design system

`packages/design_system` — единственный источник reusable visual foundations:

```text
foundation/tokens → theme → primitives → reusable composites
                                      ↘ feature composition in app
```

### В package

- color, typography, spacing, radius, elevation и motion tokens;
- theme contracts;
- reusable buttons, inputs, chips, cards, badges;
- generic loading, empty и error states;
- accessibility semantics и golden contracts.

### В feature

- page layout;
- domain-aware section/card;
- controller binding;
- product copy и behavior;
- compositions, не имеющие устойчивого reusable API.

`app/theme` только собирает выбранную theme/configuration и не дублирует
tokens. Компонент переводится в design system после отделения бизнес-логики,
стабилизации API, accessibility и test coverage.

См. [UI Baseline And Design System](UI_BASELINE_DESIGN_SYSTEM.md).

---

## 19. Errors, telemetry, privacy и security

### Errors

```text
SDK/HTTP/storage exception
  → data mapper
  → AppException
  → typed Failure
  → application state
  → localized UI message/action
```

Raw exception и provider message не показываются пользователю и не входят в
domain.

### Telemetry

Единый facade принимает allowlisted events и безопасные dimensions. Нельзя
передавать точную geometry, свободный текст, tokens, private media URL или
sensitive profile data.

Каждая production-critical operation имеет correlation id, но user/session
correlation применяется только при разрешённой privacy policy.

### Security

- least privilege для credentials и backend rules;
- capability/ownership checks на client и backend;
- idempotency для publish и других повторяемых mutations;
- bounded parsing/upload и защита от hostile inputs;
- encryption для secrets и чувствительных local data;
- dependency/secrets scanning в delivery process;
- documented incident, rollback и rotation runbooks.

EU launch требует opt-in consent и legal/privacy review. Withdrawal, export и
deletion flows проектируются вместе с persistence, а не добавляются только в
UI перед release.

---

## 20. Testing и quality gates

### Матрица

| Изменение | Минимальная проверка |
|---|---|
| Domain/usecase/validator | unit |
| Mapper/parser/migration | unit + fixtures/round-trip |
| Controller/state/concurrency | unit |
| Feature interaction | widget |
| Reusable visual component | widget + golden + accessibility |
| Repository/datasource | unit + integration |
| Navigation/guard/deep link | unit + widget + integration |
| Publish/auth/location/schema | unit + widget + integration |
| API contract | contract + consumer integration |

### Blocking gates

1. `flutter analyze`;
2. полный `flutter test`;
3. code generation consistency;
4. import boundary check;
5. профильные security/privacy/performance checks по scope.

Из корня используются Melos scripts; Flutter-команды выполняются из
`apps/mobile`. Новая boundary allowlist entry, manual generated edit или
необъяснённый skipped test блокируют завершение задачи.

См. [Testing Strategy](TESTING_STRATEGY.md) и
[CI Gates Policy](CI_GATES_POLICY.md).

---

## 21. Delivery и изменение архитектуры

### Обычная feature-задача

```text
Approved spec
  → file plan
  → implementation by layers
  → tests
  → analyze + full test + boundaries
  → LAUNCH_STATUS update
  → review/merge
```

### Архитектурное изменение

```text
problem + evidence
  → mini-RFC
  → alternatives/trade-offs
  → migration + rollback
  → Accepted ADR
  → baseline/overview update
  → implementation
```

Код не используется для молчаливого принятия архитектуры. Временное исключение
имеет owner, expiry и follow-up task.

---

## 22. Текущее состояние и целевое направление

| Область | Сейчас | Target |
|---|---|---|
| Monorepo/layers | реализованы, есть legacy allowlist | ноль boundary violations |
| Design system | package создан, foundations частично реализованы | полный token/component governance |
| API contracts | package scaffold | versioned contracts и generated clients |
| Data | mock/local | Firebase adapters после стабилизации |
| Discover | единый query flow реализован | production data и измеряемое ranking quality |
| Create Hub | общий runtime десяти типов на mock | полные специализированные секции |
| Route Builder | целевая спецификация, runtime не реализован | полный Create-блок по утверждённой spec/ADR |
| Roles/capabilities | UI/runtime guards неполны | end-to-end client/backend enforcement |
| Active workspace / Professional Page | local/mock runtime: zero-page fixture, user-created pages, owner quota 3, pending moderator request, Settings switcher, Admin presentation preview и workspace-aware personal/page shell; default PublisherRef ещё отсутствует | all-ten-type new-draft PublisherRef, production authority, moderation decisions и backend enforcement |
| Localization | target en/ru/lv, runtime не настроен | ARB/codegen и locale QA |
| Main map | Google Maps dependency/runtime | production config, privacy, observability |
| Quick Plan | локальная реализация, legacy naming debt | чистая отдельная domain boundary |

Фактические доказательства и статус задач ведутся только в
[LAUNCH_STATUS](LAUNCH_STATUS.md), а не дублируются здесь детальным журналом.

---

## 23. Открытые решения

До соответствующей production-интеграции необходимо принять решения:

1. Route renderer, routing, elevation, tiles, attribution и offline topology.
2. Firebase collection/query/security rules и repository mapping.
3. API contract bootstrap и ownership generated clients.
4. Local database/cache, если объём Route/offline data превысит key-value.
5. Усиленная conflict policy для сложной geometry, если baseline LWW
   недостаточен.
6. Полная publisher/ManagedPage модель, active-workspace persistence,
   page projection и capability matrix.
7. Localization pipeline en/ru/lv.
8. Migration legacy Quick Plan naming и оставшихся cross-feature handoffs.

Каждый пункт получает ADR только при наличии вариантов, trade-offs,
migration, rollout и rollback.

### Документальный долг

Текущий Route Builder document имеет более новую рабочую версию, чем версия,
зафиксированная в LAUNCH_STATUS. До implementation approval необходимо
согласовать статус, затем обновить LAUNCH_STATUS одним документальным change.

---

## 24. Architecture compliance checklist

Перед завершением задачи reviewer подтверждает:

- [ ] изменение разрешено Accepted ADR и активной spec;
- [ ] файл расположен в правильном app/package/feature/layer;
- [ ] domain не зависит от Flutter, SDK, DTO или data;
- [ ] controller расположен в application;
- [ ] presentation не импортирует data и не содержит business rules;
- [ ] feature не импортирует другой feature напрямую;
- [ ] cross-feature связь использует facade/contract/app wiring;
- [ ] reusable UI и tokens находятся в design system;
- [ ] API DTO не заменяет domain entity;
- [ ] ids, time, geo, locale и publisher соответствуют policy;
- [ ] permissions проверены не только визуально;
- [ ] local/remote failures типизированы;
- [ ] secrets и sensitive payload не попали в source/telemetry;
- [ ] schema/contract change имеет migration и rollback;
- [ ] feature flag имеет owner и removal/rollback rule;
- [ ] нужные unit/widget/integration tests добавлены;
- [ ] analyze, tests, codegen и boundaries зелёные;
- [ ] LAUNCH_STATUS отражает фактическое состояние.

Если любой пункт требует изменения frozen baseline, работа останавливается до
Accepted ADR.
