# RECHARGE — Scenario Object Intake Slice Specification

Версия: v1.3 (2026-08-03).

Статус: **Done**.

Runtime status: **SCN-INTAKE-01A–01D и parent SCN-INTAKE-01 Done**.

Slice: **SCN-INTAKE-01 — Add catalog objects to Scenario from Details, Search
and Map**.

Родительский продукт: canonical Scenario Create (`CreateObjectType.scenario`,
Scenario schema v2).

Product owner явно подтвердил реализацию 2026-08-03. Перед 01A был согласован
точный file plan. Этапы 01B–01D не считаются автоматически разрешёнными его
завершением и выполняются последовательно в границах этого spec.

Источники истины:

- `docs/product/SCENARIO_BUILDER_SPEC.md` v1.5;
- `docs/architecture/ARCHITECTURE_BASELINE.md`;
- Accepted ADR из `docs/adr/`;
- `AGENTS.md`;
- завершённые `SCN-SB-01–04` и `SCN-LV-DATA-01/02`.

---

## 1. Решение

Recharge получает одно каноническое действие `Add to Scenario`, доступное у
поддерживаемых каталоговых объектов в:

1. Details — один открытый объект;
2. Search/Feed — один результат или явно выбранный набор;
3. Map — выбранный marker или набор объектов в специальном selection mode.

Действие не строит Route, не создаёт Quick Plan и не передаёт категории вместо
реальных объектов. Оно формирует versioned ID-only intent, предлагает выбрать
личный редактируемый Scenario или создать новый, показывает точный preview
изменения и только после явного `Add` выполняет одну revision-safe mutation.

Успешная mutation:

- сохраняет стабильную ссылку `{objectType, objectId}`;
- сохраняет автономный versioned snapshot для offline/restart;
- создаёт новые постоянные Scenario item/location ids;
- помещает items в выбранный день/позицию или `Unscheduled`;
- создаёт ровно одну undo entry для всего подтверждённого batch;
- запускает ровно один autosave;
- не вызывает routing, optimization, booking, AI или publication.

## 2. Почему нужен отдельный slice

Canonical Scenario Composer уже умеет искать mock-каталог через
`CatalogObjectPickerPort` и добавлять candidate в открытый draft. Этого
недостаточно для внешнего handoff:

- Details/Search/Map сейчас не выбирают canonical Scenario target;
- существующие `Build route` переходы ведут в legacy Quick Plan-shaped
  Scenario Builder и не являются источником продуктовой модели;
- простая передача query-параметров не обеспечивает access, revision,
  idempotency, batch preview и offline recovery;
- текущее local Create persistence хранит один активный draft на пользователя
  и не даёт безопасно выбрать один из нескольких личных Scenario;
- текущий `addCatalogItem` всегда добавляет в первый день и не различает
  destination, duplicate intent или stale target revision.

SCN-INTAKE-01 закрывает эти разрывы через существующие слои и Create aggregate,
не создавая параллельный Scenario runtime.

## 3. Целевой пользовательский результат

Пользователь может:

1. открыть место, событие, активность, Route или bookable session;
2. нажать `Add to Scenario`;
3. выбрать существующий личный Scenario или `Create new Scenario`;
4. выбрать день и точку вставки либо `Unscheduled`;
5. увидеть добавляемые объекты, дубликаты, недоступные данные и последствия;
6. подтвердить одно атомарное добавление;
7. остаться на исходном экране или открыть точный обновлённый Scenario.

Сеть после открытия action не обязательна, если текущая consumer projection
содержит валидный ID и достаточный last-known snapshot.

## 4. Неподвижные продуктовые границы

1. **Route ≠ Scenario ≠ Quick Plan.** Route добавляется в Scenario как один
   catalog item по `routeId`; anchors, segments и GPX не копируются в Scenario.
2. `Add to Scenario` всегда работает с canonical Scenario Create, а не с
   legacy `features/scenarios` Builder.
3. Quick Plan не является target и не получает обратный Scenario handoff.
4. Scenario остаётся `CreateDraftEntity` с typed `ScenarioDraftData`; отдельный
   lifecycle/repository внутри `ScenarioDraftData` не создаётся.
5. Межфичевая связь — только через app composition facade и публичные
   ID/snapshot contracts. Discover и Create не импортируют внутренние слои друг
   друга.
6. URL/deep link переносит максимум короткий one-shot handoff id. Object title,
   note, координаты, полный snapshot и Scenario aggregate в URL не передаются.
7. UI не вычисляет duplicate policy, schedule, ids, revision result или totals.
8. Неизвестные duration/cost/availability не превращаются в `0` или `free`.
9. Ни одна mutation не публикует Scenario и не меняет visibility.
10. Firebase, платные API, routing provider и новый production backend не
    требуются для local/mock-first реализации.
11. Добавление в existing target не меняет его root `origin`. Для нового
    target Details получает additive `ScenarioOriginType.details`, Search —
    `search`, Map — `mapSelection`; query/viewport в origin не сохраняются.

## 5. Scope

### 5.1 Поддерживаемые source objects

| Consumer object | Scenario source type | Scenario item kind | Intake v1 |
|---|---|---|---|
| Place | `place` | `visit` | да |
| Event | `event` | `event` | да |
| Activity | `activity` | `activity` | да |
| Published Route | `route` | `route` | да |
| Bookable Session | `bookableSession` | `bookableSession` | да |

`Find People`, Scenario, Collection, unpublished Route draft, stay, custom
location и planned transport не являются catalog intake objects v1. Для них
нужны отдельные privacy/lifecycle contracts. Stay и transport продолжают
добавляться внутри Composer.

### 5.2 Source surfaces

- Details: один exact object;
- Search/Feed: single-card action и optional multi-select до 20 объектов;
- Map: selected marker action и explicit selection mode до 20 объектов;
- общий target/placement/preview sheet;
- общий application facade и одна mutation-команда.

### 5.3 Target operations

- список личных editable Scenario drafts;
- создание нового private Scenario;
- точная загрузка target по `{ownerId, scenarioDraftId}`;
- выбор существующего дня, вставка в конец/после item или `Unscheduled`;
- atomic batch Apply, Undo и autosave;
- success action `Open Scenario` по ID-only handoff.

## 6. Не входит в SCN-INTAKE-01

- public/unlisted publication, moderation и совместное редактирование;
- добавление в чужой Scenario или ManagedPage Scenario;
- realtime travel time, route calculation, optimization и automatic reorder;
- поиск с пересадками, tickets/fares/availability/booking;
- автоматическое создание alternative group;
- перенос private notes, Search query, Smart Search prompt или Map viewport;
- массовый import более 20 объектов;
- background sync или conflict merge нескольких устройств;
- изменение legacy Scenario Builder/Quick Plan domain;
- новый create-type или изменение десятки Create Hub.

## 7. UX: Details

### 7.1 Entry

В action hub поддерживаемого объекта появляется отдельное действие:

- title: `Add to Scenario`;
- subtitle: `Add this stop to a personal plan`;
- icon: planning/add, не Route/track icon;
- semantic label содержит тип действия, но не скрытый object id.

Существующее `Build route` может временно оставаться отдельным legacy action до
cleanup slice. Оно не переименовывается в `Add to Scenario` и не считается
эквивалентным.

### 7.2 Flow

```text
Details object
  → Add to Scenario
  → auth/access gate
  → target chooser
  → placement chooser
  → exact preview
  → Add
  → success: Stay here / Open Scenario
```

Back/close на любом шаге оставляет target и source без изменений.

## 8. UX: Search/Feed

### 8.1 Single item

Каждая поддерживаемая result card предоставляет доступное через обычный tap
menu/action действие `Add to Scenario`. Long press не является единственным
способом.

### 8.2 Multi-select

Search может войти в explicit `Select for Scenario` mode:

- лимит `1..20`;
- выбор сохраняет порядок tap, но preview позволяет reorder;
- unsupported result нельзя выбрать и он объясняет причину;
- смена фильтра не добавляет новые items автоматически;
- selection живёт только до Cancel/Apply и не попадает в Scenario.

Search query, filters, ranking score и prompt не копируются. Каждый selected
result materialize-ится только как exact `{objectType, objectId}` + snapshot.

## 9. UX: Map

### 9.1 Selected marker

Карточка выбранного поддерживаемого marker содержит `Add to Scenario`.

### 9.2 Selection mode

Map action `Select for Scenario` включает отдельный режим:

- обычное перемещение карты остаётся доступным;
- tap marker toggles selection;
- selected markers имеют номер порядка;
- compact tray показывает count, `Review` и `Cancel`;
- maximum 20; двадцать первый marker не выбирается и показывает limit state;
- cluster не добавляется целиком — пользователь раскрывает/выбирает объекты;
- hidden/off-screen selection остаётся в tray до явного удаления;
- Map не оптимизирует порядок по расстоянию и не строит Route.

Viewport, zoom, radius, polyline и raw coordinates не становятся source of
truth. Coordinates попадают только в разрешённый catalog snapshot выбранного
объекта через composition adapter.

## 10. Authentication, owner и capability

Viewer должен быть авторизован согласно ADR 0015. Guest target отсутствует.

Target доступен только когда:

- `target.objectType == scenario`;
- `target.organizerId == requester.userId`;
- draft не deleted/archived/hidden;
- canonical personal-authoring access policy разрешает requester редактировать
  собственный Scenario; slice не вводит новое строковое имя capability;
- `scenarioData` читается поддерживаемой schema и не corrupt.

Creator verification не требуется для личного Scenario. Professional Page и
Admin presentation preview не дают права редактировать личный target. Page
Scenario появится только в отдельном Publisher/collaboration slice.

Если auth истёк после открытия sheet, Apply fail-closed; intent может остаться
transient для повторного открытия после sign-in, но target не меняется.

## 11. Target chooser

Sheet показывает только personal editable Scenario:

- title;
- format `city/day/weekend/trip`;
- date range или `Template`;
- количество active items/days;
- last updated;
- warning, если draft имеет blocking corruption/unsupported schema.

Порядок: last updated descending. Draft выбирается только по exact ID, не по
title. Одинаковые названия разрешены.

Действия:

1. выбрать target;
2. `Create new Scenario`;
3. Cancel.

Новый target:

- получает permanent client-generated ULID до сохранения;
- принадлежит requester;
- private/personal;
- использует Latvia market runtime defaults без hardcode в UI;
- создаёт один Day 1 либо dated day только после явной даты;
- не публикуется и не получает fake collaborators;
- initial title может быть предложен, но пользователь может изменить его;
- batch применяется только после успешного materialization target.

Создание target и применение первого batch — одна logical transaction: draft и
items полностью materialize-ятся в памяти, затем выполняется одна conditional
save. Пустой target не записывается как побочный эффект неуспешного Apply.

Если создание target удалось, а добавление items не прошло, пустой target либо
не сохраняется, либо сохраняется как recoverable draft только после явного
`Keep empty draft`. Полусохранённый невидимый Scenario запрещён.

## 12. Placement chooser

Для existing target пользователь выбирает:

- day;
- `At end`;
- `After <item>`;
- `Unscheduled`;
- порядок batch;
- role: `mandatory` или `optional` для всего batch либо per-item advanced
  override.

`alternative` не предлагается здесь: alternative требует группы и отдельного
SCN-ALT-01 flow.

Defaults:

- последний открытый day, если он существует и валиден;
- иначе первый day;
- если target не имеет day — `Unscheduled`;
- single event с exact local date предлагает matching day;
- несовпадающий fixed event не переносится молча: предлагается matching day,
  `Unscheduled` или Cancel;
- batch с разными датами не распределяется автоматически без preview.

Вставка не создаёт logistics legs с выдуманными значениями. Existing affected
derived/manual legs проходят действующую invalidation policy; locked manual leg
не переписывается.

## 13. Duplicate policy и idempotency

Один catalog object иногда legitimately нужен в разные дни, поэтому глобальный
запрет duplicate source ref неверен.

### 13.1 Внутри одного intent

Повтор `{objectType, objectId}` дедуплицируется до preview. UI показывает
`Already selected`, но не создаёт второй item.

### 13.2 В target

Если exact ref уже есть:

- same day/logical slot: default action `Open existing`; explicit
  `Add another occurrence` доступен после предупреждения;
- другой day: новый item разрешён после явного подтверждения;
- existing unresolved/unavailable item не заменяется молча новым;
- duplicate не merge-ит notes, cost, locks или schedule.

### 13.3 Double tap/retry

Каждый intent имеет permanent `intentId`. Target сохраняет bounded local
idempotency receipt `{intentId, targetRevisionAfterApply}`. Повтор Apply того же
intent возвращает previous success без новых items/undo/autosave. Receipt не
попадает в public payload и может очищаться по bounded retention policy.

## 14. Versioned intake contract

Illustrative domain-neutral contract:

```dart
enum ScenarioIntakeSourceSurface { details, search, map }

class ScenarioObjectRef {
  String objectId;
  ScenarioCatalogObjectType objectType;
}

class ScenarioIntakeCandidate {
  ScenarioObjectRef ref;
  int? sourceRevision;
  ScenarioObjectSnapshot snapshot;
  ScenarioSourceStatus sourceStatus;
}

class ScenarioObjectIntakeIntent {
  int contractVersion;
  String intentId;
  String requesterId;
  ScenarioIntakeSourceSurface sourceSurface;
  List<ScenarioIntakeCandidate> candidates; // 1..20
}

class ScenarioIntakePlacement {
  String? dayId;              // null => Unscheduled
  String? afterItemId;        // null => end
  List<ScenarioObjectRef> orderedRefs;
  Map<ScenarioObjectRef, ScenarioItemRole> roles;
  Set<ScenarioObjectRef> confirmedDuplicates;
}

class ApplyScenarioObjectIntakeRequest {
  String intentId;
  String requesterId;
  String targetCreateDraftId;
  int expectedScenarioRevision;
  ScenarioIntakePlacement placement;
}
```

`ScenarioObjectSnapshot` соответствует существующему versioned Scenario
snapshot contract. Presentation consumer models не становятся Create domain
entities; app adapter выполняет allowlisted mapping.

Additive `ScenarioOriginType.details` входит в mapper/round-trip scope 01A.
Для Details `sourceId` может содержать тот же catalog object id, который уже
явно присутствует в первом item; для Search/Map raw query, prompt и viewport не
сохраняются. Existing Scenario origin никогда не переписывается intake intent.

## 15. Typed outcomes

```dart
enum ScenarioIntakeFailure {
  unauthenticated,
  accessDenied,
  targetNotFound,
  targetNotScenario,
  targetUnavailable,
  revisionConflict,
  intentExpired,
  intentAlreadyConsumed,
  invalidCandidate,
  unsupportedObjectType,
  incompleteSnapshot,
  batchLimitExceeded,
  duplicateConfirmationRequired,
  invalidPlacement,
  persistenceUnavailable,
}

sealed class ScenarioIntakeResult {}

class ScenarioIntakeApplied extends ScenarioIntakeResult {
  String targetCreateDraftId;
  int targetRevision;
  List<String> createdItemIds;
  List<String> createdLocationIds;
  bool replayedIdempotentSuccess;
}

class ScenarioIntakeRejected extends ScenarioIntakeResult {
  ScenarioIntakeFailure failure;
  ScenarioObjectIntakeIntent retainedIntent;
  int? currentTargetRevision;
}
```

Rejected result всегда возвращает target byte-for-byte equivalent исходному.
Ошибки не моделируются строковыми exception из data layer.

## 16. Atomic application command

Pure use case обязан:

1. проверить contract version, requester и limits;
2. проверить exact target type/owner/access;
3. сравнить `expectedScenarioRevision`;
4. проверить day/anchor ids и placement;
5. проверить supported refs, snapshots и duplicate confirmations;
6. выделить permanent item/location ids через injected `IdGenerator`;
7. создать все items в памяти;
8. применить batch к одному immutable Scenario copy;
9. пересчитать schedule/readiness/totals через существующие use cases;
10. вернуть accepted draft либо typed rejection без partial mutation.

CreateController/application coordinator применяет accepted draft через один
существующий command pipeline. Один batch — одна undo entry и один autosave.
Двадцать items не создают двадцать autosave или двадцать undo steps.

## 17. Snapshot resolution

### 17.1 Minimum required snapshot

- non-empty stable object id;
- supported object type;
- non-empty display title;
- versioned source status;
- duration nullable/known — не fake zero;
- optional cover/publisher/source revision;
- location только если consumer projection имеет разрешённую подтверждённую
  точку;
- event/session time только из typed source projection;
- Route stats только из active immutable published version.

### 17.2 Freshness

- `ready`: current known projection;
- `stale`: last-known snapshot можно добавить с visible warning;
- `unavailable`: можно сохранить historical snapshot только после explicit
  confirmation; обязательный Start/Publish остаётся blocked существующей
  validation policy;
- `unresolved`: Apply блокируется, если snapshot недостаточен для безопасного
  отображения.

Ни один provider refresh не запускается автоматически при открытии chooser.
Explicit Retry может повторно resolve-ить source, но не меняет уже сохранённый
Scenario без нового Apply.

## 18. Multi-Scenario local persistence

SCN-INTAKE-01 требует выбирать несколько личных Scenario. Это реализуется как
additive Create draft collection contract, а не repository внутри
`ScenarioDraftData`:

```dart
abstract interface class CreateDraftCollectionRepository {
  Future<List<CreateDraftSummary>> listDrafts({
    required String ownerId,
    required CreateObjectType type,
  });

  Future<CreateDraftEntity?> loadDraftById({
    required String ownerId,
    required String draftId,
  });

  Future<CreateConditionalSaveResult> saveIfRevision({
    required String ownerId,
    required CreateDraftEntity draft,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  });
}
```

Requirements:

- key namespace содержит exact owner id + draft id;
- list возвращает summary, не загружает все full aggregates в UI;
- corrupt/foreign entry fail-closed и не попадает как editable target;
- legacy singleton Create draft импортируется idempotently в collection;
- migration не удаляет прежний key до успешной записи и verification;
- current generic Create resume behavior сохраняется;
- no mass migration и no Firebase;
- repository contract остаётся provider-neutral.

Если collection foundation не готова, rollout может начать с `Current Scenario`
target, но slice не получает общий Done до выбора нескольких drafts и restart
coverage.

## 19. Межфичевая архитектура

```text
Details / Search / Map
        │ public consumer projection + user intent
        ▼
app/application ScenarioObjectIntakeFacade
        │ allowlisted adapter mapping
        ▼
Create application intent store / target query
        │ ID-only handoff + expected revision
        ▼
pure ApplyScenarioObjectIntakeUseCase
        │ accepted immutable CreateDraftEntity
        ▼
Create command pipeline → one undo → one conditional save
```

### Forbidden imports

- Discover presentation/application → Create internal layers;
- Create domain/application → Discover internal layers;
- feature UI → another feature controller/repository;
- shared facade → private widget/state types.

App composition может импортировать публичные contracts двух features и
инъектировать adapters через DI. Boundary gate не получает новую allowlist
suppression.

## 20. One-shot intent store

Intent store нужен, чтобы не передавать payload через URL:

- key — unguessable client-generated id;
- owner-bound;
- TTL, например 30 минут, через injected clock/config;
- consume не означает Apply: Cancel может discard, failure может retain;
- успешный Apply помечает intent consumed и сохраняет idempotency receipt;
- bounded maximum entries per owner;
- restart policy explicit: либо encrypted/local persisted bounded store, либо
  честный expired state с возможностью повторить action на source screen;
- raw Search query, notes и private fields не сохраняются;
- logs/analytics не содержат handoff id или candidate ids.

Для local-first v1 предпочтителен persisted bounded intent с schema/version и
owner namespace, чтобы system kill между chooser и Apply не терял selection.

## 21. Failure и recovery UX

| Состояние | Поведение |
|---|---|
| Нет auth | Sign-in gate; source context визуально сохраняется |
| Нет editable Scenario | Предлагается Create new Scenario |
| Target удалён/архивирован | Target unavailable; выбрать другой |
| Revision conflict | Показать summary изменений; Refresh target и повторный preview |
| Source stale | Warning + explicit Continue with saved snapshot |
| Source unavailable | Historical snapshot только после confirmation; иначе Remove |
| Offline | Использовать local targets/snapshots; никаких fake live данных |
| Persistence failure | Target не меняется; intent остаётся retryable |
| Partial invalid batch | Preview перечисляет invalid items; Remove invalid или Cancel |
| Duplicate | Open existing / explicit Add another occurrence |
| Intent expired | Вернуться к source и повторить selection; target не меняется |
| App restart | Восстановить bounded intent либо честно показать expired recovery |

Partial Apply запрещён по умолчанию. Пользователь сначала явно удаляет invalid
items из preview, после чего новый confirmed batch применяется целиком.

## 22. Review preview

Перед Apply показываются:

- exact target title/id-safe summary;
- day/Unscheduled и insertion point;
- ordered cards candidates;
- object type, title, duration knowledge и source status;
- fixed event/session time;
- duplicate warnings;
- stale/unavailable warnings;
- known/unknown price без суммирования разных currencies;
- предполагаемое количество новых items;
- disclosure: logistics ещё не пересчитана live.

Preview не меняет revision, undo stack, autosave или target timestamps.

## 23. После успешного Apply

Success state:

- `Added N items to <Scenario>`;
- secondary `Stay here`;
- primary `Open Scenario`;
- optional `Undo` только если command pipeline и target session безопасно
  поддерживают exact undo; иначе Undo доступен после открытия target;
- повторный tap `Add` возвращает idempotent success;
- исходный Details/Search/Map selection очищается только после success.

`Open Scenario` передаёт только exact target draft id через app-level handoff.
Он открывает canonical Create Scenario на Compose/Review, не legacy Builder.

## 24. Accessibility и adaptive UI

- 360×800 без overflow при text scale 1.5;
- screen reader объявляет selected count, duplicate/source warnings и Apply
  result;
- focus order: target → placement → ordered items → warnings → actions;
- selection не выражается только цветом;
- marker numbering имеет semantic label;
- важные действия доступны без swipe/long press;
- destructive `Discard selection` требует контекст, но не лишнее modal
  подтверждение для пустого transient selection;
- loading target или snapshot не блокирует закрытие sheet;
- ошибки привязаны к конкретному candidate/field и имеют Retry/Remove action.

## 25. Privacy и security

1. Intake не переносит private notes, booking details, invitees, Search query,
   Smart prompt или browsing history.
2. Exact coordinates попадают только из public catalog projection и сохраняются
   по действующей Scenario location disclosure policy.
3. Target lookup всегда owner-scoped; ID без owner/access недостаточен.
4. App deep link не даёт authority и повторно проходит auth/access guard.
5. Foreign target existence не раскрывается: внешний результат
   `targetUnavailable/accessDenied` нормализуется для UI.
6. Intent store owner-bound, bounded и versioned.
7. Public/unlisted mapper не изменяется этим slice.
8. Analytics enum-only и не содержит object/scenario/intent ids.

## 26. Analytics

Один privacy-safe event family:

`scenario_object_intake_action`

Allowed parameters:

- `source_surface`: `details | search | map`;
- `action`: `open | preview | apply | cancel | retry | open_target`;
- `result`: typed enum без raw error;
- `batch_size_bucket`: `one | two_to_five | six_to_twenty`;
- `target_kind`: `existing | new`;
- `placement`: `day | unscheduled`;
- `source_status`: aggregate enum, optional.

Forbidden:

- object/scenario/intent/user ids;
- title, notes, query, prompt;
- date/time, coordinates, address;
- category/subcategory при малой выборке;
- URLs, publisher name, revision number.

Event добавляется в `EVENT_CATALOG.md` только вместе с runtime emission и
payload unit test.

## 27. Feature flags и rollback

```dart
class ScenarioObjectIntakeConfig {
  bool enabled;
  bool detailsEnabled;
  bool searchEnabled;
  bool mapEnabled;
  bool multiSelectEnabled;
  bool createNewTargetEnabled;
  int maxBatchSize;       // 1..20
  Duration intentTtl;
}
```

Config валидируется один раз в application layer. UI и use case читают один
versioned config.

Rollback:

1. выключить surface flags — actions исчезают;
2. existing Scenario items и snapshots остаются читаемыми;
3. internal Composer catalog add продолжает работать;
4. pending intents перестают применяться, но target drafts не удаляются;
5. collection persistence остаётся backward-readable;
6. legacy `Build route` не получает новые обязанности;
7. cache/Scenario drafts автоматически не очищаются.

## 28. Этапы реализации

### SCN-INTAKE-01A — Contracts, collection persistence, atomic command

Статус: **Done (2026-08-03)**.

- versioned intent/candidate/placement/outcome contracts;
- generic owner-scoped Create draft collection access;
- legacy singleton migration/read compatibility;
- pure atomic revision-safe/idempotent Apply use case;
- duplicate/placement policy;
- mapper and unit tests;
- никакого surface UI.

Evidence: owner-scoped multi-Scenario secure collection с staged
write/verification, bounded idempotency receipts и read-compatible legacy
singleton migration; pure all-or-nothing Apply с exact owner/revision/target
guards, permanent ids, duplicate confirmation, day/after/unscheduled placement,
locked-leg protection и одной revision на batch. Targeted analyzer — 0 issues,
27 focused tests passed; полный analyzer — 0 issues, полный последовательный
Flutter suite — 560 tests passed; boundary gate — 59 existing allowlist
suppressions. UI Details/Search/Map намеренно отсутствует до 01B/01C.

### SCN-INTAKE-01B — Shared target/placement/preview flow + Details

Статус: **Done (2026-08-03)**.

- app composition facade и allowlisted Details adapter;
- one-shot intent store;
- shared sheets;
- Details `Add to Scenario`;
- auth/access, offline/retry/success/open-target;
- widget/integration tests.

Реализован единый трёхшаговый flow `target → placement → review`: выбор
личного Scenario или создание нового private Scenario, Day/Unscheduled,
`At end`/`After stop`, mandatory/optional, точный preview и подтверждения
duplicate/unavailable/fixed-date adjustment. Новый пустой Scenario не
сохраняется до успешного атомарного Apply. Intent owner-scoped, одноразовый,
переживает restart, имеет TTL 30 минут и durable consumed receipt. Повторный
Apply идемпотентен; истёкшие intent/auth, foreign owner, stale revision и
повреждённое хранилище fail closed. Details получил отдельное действие
`Add to Scenario`; legacy `Build route` не изменён. Success предлагает остаться
или открыть exact Scenario через ID-only `scenarioDraftId`, без передачи
snapshot в URL. Fixed dated Event в template Scenario требует явного
подтверждения и становится flexible template stop. Live logistics не
обещаются; unlocked boundary estimate безопасно инвалидируется atomic usecase.

Evidence: adapter/persistence/facade/domain/exact-open/widget tests, включая
restart, corrupt owner payload, auth expiry, TTL, new-target atomicity и replay;
полный `flutter analyze` — 0 issues; полный последовательный Flutter suite —
571 tests passed; boundary gate — 59 existing allowlist suppressions;
`git diff --check` — clean (только platform line-ending warnings). Search/Map
surface actions намеренно остаются до 01C, analytics/feature rollback и
финальные responsive/accessibility gates — до 01D.

### SCN-INTAKE-01C — Search and Map

Статус: **Done (2026-08-03)**.

- Search single action и explicit multi-select;
- Map marker action и selection tray;
- selection-order preview/reorder;
- 20-item limit и unsupported states;
- route-contract, accessibility и widget tests.

Search result cards получили доступное обычным tap действие `Add to Scenario`
и явный режим `Select for Scenario`. Map selected-marker card использует тот же
single flow; отдельный Map selection mode переключает marker/list item по tap,
сохраняет порядок выбора, показывает numbered markers и общий compact tray.
Selection хранит exact catalog items независимо от текущего filter result или
viewport, поэтому hidden/off-screen item остаётся выбранным до explicit remove
или Cancel. Двадцать первый item не добавляется и показывает limit state;
invalid identity/location объясняется и fail closed. Pan/zoom и filter changes
остаются доступны и не добавляют объекты автоматически. Cluster, query,
filters, ranking, viewport и zoom не materialize-ятся в intent; batch adapter
передаёт только allowlisted catalog projection в порядке пользовательских tap.
Review использует общий 01B target/placement/review sheet и его reorder. После
успешного Apply selection очищается; Cancel sheet сохраняет selection, а Cancel
selection удаляет только transient state. Runtime numbered marker icons
создаются локально только при входе в selection mode; default marker и numbered
tray остаются fallback. App-level launcher централизует auth-only gate и mapping
surface→domain, поэтому Discover UI не импортирует Create/Auth internals. Legacy
`Build route`, Route, Quick Plan и scenario-route Map preview не изменены.

Evidence: selection-controller negative tests покрывают order/toggle,
off-screen retention, limit 20, unsupported и Cancel; adapter tests покрывают
Search/Map batch order, duplicate и invalid location; Search/Map widget tests
покрывают single actions, auth без guest, ordered tray и explicit Cancel.
Targeted regression после composition refactor — 27 tests passed; полный
`flutter analyze` — 0 issues; полный последовательный Flutter suite — 580 tests
passed; boundary gate — 59 existing allowlist suppressions и ни одного нового
нарушения; `git diff --check` — clean (только platform line-ending warnings).
Analytics, feature rollback и финальный 360 dp/text-scale quality gate остаются
в 01D.

### SCN-INTAKE-01D — Quality and release gate

Статус: **Done (2026-08-03)**.

- privacy-safe analytics;
- restart/offline/corrupt/revision-conflict tests;
- 360 dp / text scale 1.5;
- feature flag rollback;
- full analyzer/test/boundary/diff evidence;
- LAUNCH_STATUS/AGENTS sync;
- parent `SCN-INTAKE-01` Done только после 01A–01D.

Реализован единый versioned/validated app-level config с общим kill switch,
отдельными Details/Search/Map и multi-select/create-new flags, bounded batch
1–20 и TTL. Surface actions fail closed и исчезают; отключённый runtime не
применяет pending intent, не меняет и не удаляет target draft, а внутренний
Scenario Composer и backward-readable persistence не затронуты. Добавлен один
enum/bucket-only event family с точным allowlist и тестом отсутствия ids,
названий, запросов, дат, координат и другого Scenario content. Sheet и
selection tray получили live-region announcements, нумерованные semantics,
явные Retry/Remove/Cancel actions и adaptive layout; полный путь и tray
проверены на 360×800 при text scale 1.5.

Evidence: `flutter analyze` — 0 issues; полный последовательный Flutter suite —
589 tests passed; boundary gate — passed с 59 существующими allowlist
suppressions и без нового нарушения; `git diff --check` — passed, только
platform line-ending warnings. Parent `SCN-INTAKE-01` завершён.

Этапы выполняются последовательно. Перед каждым этапом нужен exact file plan и
отдельное подтверждение.

## 29. Предварительный file map будущей реализации

Точные пути подтверждаются перед кодом. Ожидаемые области:

### New

- Create domain contracts для intake intent/mutation;
- pure Apply use case;
- Create draft collection repository extension/adapter;
- app-level `ScenarioObjectIntakeFacade` и consumer projection adapter;
- owner-bound one-shot handoff store;
- shared target/placement/preview presentation widgets;
- focused unit/widget/integration tests.

### Modify

- existing Scenario coordinator/CreateController command pipeline;
- Create local datasource/repository с backward-compatible collection access;
- app DI/router только для facade/handoff composition;
- Discover Details/Search/Map presentation actions;
- analytics catalog/taxonomy на этапе 01D;
- `LAUNCH_STATUS.md` и `AGENTS.md` после фактических gates.

### Must not modify

- Route domain model;
- legacy Quick Plan aggregate;
- Accepted ADR;
- Firebase/backend integration;
- public/unlisted publication contracts;
- generated files и assets без отдельной необходимости.

## 30. Test matrix

### Domain/application

- one/many candidates;
- stable IDs and source mapping for all five supported types;
- new-target origin mapping и сохранение existing-target origin;
- unsupported type and incomplete snapshot;
- batch duplicate deduplication;
- existing duplicate: same/different day;
- explicit duplicate confirmation;
- day/end/after/unscheduled placement;
- missing day/anchor;
- event date mismatch;
- revision conflict;
- owner/access denial;
- target not Scenario/corrupt/unsupported schema;
- 20 accepted / 21 rejected;
- all-or-nothing batch;
- one revision increment;
- one undo entry and exact Undo/Redo;
- idempotent double Apply;
- no fake cost/duration/location;
- affected leg invalidation without locked-leg rewrite.

### Persistence

- list/load exact owner + draft id;
- two Scenario with same title remain distinct;
- foreign draft not visible;
- multiple personal Scenario survive restart;
- legacy singleton migration idempotent and non-destructive;
- corrupt entry isolated;
- conditional save conflict;
- write failure retains target and intent;
- receipt retention/bounds.

### Details/Search/Map

- correct action only for supported object;
- unauthenticated gate;
- Cancel changes nothing;
- exact candidate mapping;
- Search/Map selection order and reorder;
- cluster not bulk-added;
- filter/viewport changes do not mutate target;
- success Stay/Open Scenario;
- canonical Create target, never legacy Builder;
- source context retained after failure;
- no UI business logic/import boundary violation.

### Privacy/analytics

- notes/query/prompt/ids/coordinates absent from intent where forbidden;
- exact allowed telemetry keys only;
- owner-bound intent access;
- deep-link target ID does not bypass access;
- private location/public mapper unchanged.

### Quality

- 360×800 / 1.5 text scale;
- screen reader/focus/semantics;
- offline cached source/target;
- app restart mid-flow;
- stale/unavailable snapshot disclosures;
- feature flags independently disabled;
- full `flutter analyze`;
- full sequential `flutter test`;
- boundary gate with no new suppression;
- `git diff --check`.

## 31. Acceptance criteria

1. Details, Search and Map используют одно действие и один intake contract.
2. Action открывает canonical Scenario Create, не legacy Quick Plan Builder.
3. Поддерживаются Place/Event/Activity/Route/Bookable Session по exact ID/type.
4. Route добавляется одним item без копирования track model.
5. Пользователь выбирает exact personal Scenario по ID или создаёт новый.
6. Несколько личных Scenario доступны после restart.
7. Foreign/page/public target нельзя изменить через подмену ID.
8. Placement поддерживает day/end/after/Unscheduled.
9. Fixed event time/date не переписывается молча.
10. Batch ограничен 20 и применяется all-or-nothing.
11. Внутренние duplicate refs дедуплицируются; target duplicate требует
    explicit decision.
12. Один confirmed batch создаёт одну revision, undo entry и autosave.
13. Retry/double tap не создаёт duplicate items благодаря intent idempotency.
14. Revision conflict не затирает новые изменения target.
15. Cancel/error оставляют source и target byte-for-byte unchanged.
16. Offline flow работает с local target и валидным last-known snapshot.
17. Stale/unavailable никогда не называется current/live.
18. Unknown duration/cost/availability не становится zero/free.
19. Search query, prompt, filters, viewport и personal notes не копируются.
20. UI не импортирует другой feature controller/repository.
21. App facade маппит только allowlisted public projection.
22. URL не содержит full snapshot или aggregate.
23. Success открывает exact canonical Scenario через ID-only handoff.
24. Feature flag rollback не удаляет добавленные items/drafts.
25. Analytics payload enum/bucket-only и проходит privacy test.
26. 360 dp и text scale 1.5 не имеют overflow.
27. Все важные действия доступны без long press и имеют semantics.
28. Mapper/persistence backward-compatible с текущим single-draft storage.
29. Ни Firebase, ни платный provider не нужны для базовой работы.
30. `flutter analyze`, полный sequential `flutter test`, boundary и diff gates
    зелёные; только после этого parent получает Done.

## 32. Definition of Done

SCN-INTAKE-01 считается Done только когда:

1. 01A–01D завершены с evidence;
2. все три surfaces используют shared flow;
3. multi-Scenario local persistence и migration доказаны restart tests;
4. atomic/idempotent/revision-safe mutation доказана negative tests;
5. Route/Scenario/Quick Plan boundaries не нарушены;
6. manual internal Composer add не регрессировал;
7. privacy/access/feature rollback gates зелёные;
8. `LAUNCH_STATUS.md` отражает фактическое состояние.

До этого момента action может существовать только за выключенным feature flag
или как bounded development preview и не называется завершённым продуктом.

## 33. Следующие slices после SCN-INTAKE-01

1. `SCN-ALT-01` — alternative groups и переключение активной остановки;
2. `SCN-LOG-02` — planned/estimated logistics и own-car enrichment без live
   обещаний;
3. `SCN-PUB-01` — public/unlisted publication, moderation и immutable copy;
4. `SCN-COLLAB-01` — owner/editor/viewer access и conflict/audit contract;
5. `SCN-LV-JOURNEY-01` / `SCN-LV-RT-01` — transfers и realtime только после
   отдельных provider/operations gates.

Ни один из них не включён в SCN-INTAKE-01 и не должен проникать в его runtime
под видом удобства.
