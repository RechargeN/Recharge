# RECHARGE — Scenario Connected Planning

Версия: 1.1

Статус: **Approved**

Дата: 2026-07-31

Тип документа: execution specification

Каноническая продуктовая модель: `SCENARIO_BUILDER_SPEC.md` v1.5

## 1. Назначение

Документ описывает четыре следующих capability Scenario:

1. добавление существующих объектов в Scenario из Details, Search и Map;
2. альтернативы остановок;
3. честно маркированные manual/estimated/provider legs и плановое расписание;
4. private/unlisted/public distribution, moderation и совместный доступ.

Это не новый тип контента и не замена Scenario Builder v1.3. Документ
детализирует пользовательские потоки, application-контракты, безопасность,
порядок реализации, критерии приёмки и rollback для последующих slices.

## 2. Обязательные продуктовые границы

1. `Route != Scenario != Quick Plan`.
2. Scenario объединяет независимые Place, Event, Activity, Route, Session,
   Stay, custom location, time block и planned transport.
3. Route внутри Scenario является ссылкой на отдельный Route object. Scenario
   не копирует GPX, elevation, anchors или segments в свою domain model.
4. Quick Plan не становится контейнером Scenario. Разрешён только уже
   определённый one-way `Expand to Scenario` без live-связи.
5. Catalog relation всегда хранится как `{objectType, objectId}`. Название,
   категория, поисковый запрос или координата не используются вместо ID.
6. Каждый Scenario, day, item, location, leg, alternative group, access grant,
   share link и revision имеет отдельный постоянный ULID/UUID.
7. Полный Scenario не передаётся через URL. Внутренний переход передаёт
   короткий intent/handoff ID, после materialization работа идёт по draft ID.
8. UI не выполняет бизнес-логику. Cross-feature flow оркестрируется на app
   composition layer, а правила живут в application/domain.
9. Offline personal draft остаётся работоспособным при недоступности Search,
   live routing, sharing или moderation.
10. Отключение одной capability не удаляет уже известные поля другой.

### 2.1 Нормативные ссылки и приоритет

При конфликте применяются в таком порядке:

1. Accepted ADR, включая
   [ADR 0013](../adr/0013-domain-policy-baseline.md);
2. [Scenario Builder Spec v1.5](./SCENARIO_BUILDER_SPEC.md);
3. эта execution specification после Product approval;
4. [Launch Status](../architecture/LAUNCH_STATUS.md);
5. [Firebase Architecture](../architecture/FIREBASE_ARCHITECTURE.md) как
   целевой integration proposal, не как разрешение включить Firebase.

Этот документ не меняет Accepted ADR и не авторизует post-stabilization
интеграции сам по себе.

## 3. Scope

### 3.1 Входит

- `Add to Scenario` из Place/Event/Activity/Route/Session Details;
- selection mode в Search и Map;
- выбор существующего личного Scenario или создание нового;
- выбор day, позиции, роли и alternative group при добавлении;
- atomic bulk add, partial resolution и Undo;
- группы альтернатив и переключение выбранного варианта;
- manual/estimated walking, bicycle, driving/taxi legs и плановое transit
  расписание;
- ручная логистика и provider fallback;
- пересчёт timeline, конфликтов и итогов;
- unlisted share с backend-issued token;
- public Scenario template через publisher и moderation;
- explicit viewer/editor collaboration grants;
- revision conflict handling;
- report, auto-hide и audit trail;
- feature flags, kill switches, analytics и observability.

### 3.2 Не входит

- объединение Route и Scenario aggregates;
- автоматическая покупка билетов, бронирование или оплата;
- live flight/train/ferry inventory и fare booking;
- публичный Quick Plan;
- анонимное совместное редактирование;
- чат, комментарии, real-time cursors и видеосвязь;
- CRDT или Google Docs-подобное посимвольное редактирование;
- автоматическая публикация без moderation policy;
- хранение provider API keys в мобильном клиенте;
- включение Firebase или live provider во время активной стабилизации;
- bulk migration legacy `scenario route` данных.

## 4. Delivery gates

Capabilities поставляются независимо.

| Capability | Local/mock | Production enablement |
|---|---|---|
| Connected add | возможен после Approved slice | repository contracts и реальные catalog projections |
| Alternatives | возможен как Scenario Create extension после Approved slice | не требует backend для personal draft |
| Logistics | manual/estimated/schedule contract; static transit не live | Live provider требует Accepted ADR, backend proxy, quotas и privacy review |
| Unlisted share | UI/mapper могут быть disabled/mock | production backend, secure token service, access rules |
| Public publish | UI/mapper могут быть disabled/mock | Creator capabilities, publisher, moderation и catalog projection |
| Collaboration | локальные policy fixtures | auth, grants, sync, audit и server authorization |

Ни один disabled/mock action не показывает пользователю фиктивную внешнюю
ссылку или ложный статус публикации.

## 5. Общая архитектура

```text
Details / Search / Map
        |
        v
ScenarioCompositionIntent (IDs only)
        |
        v
app-level composition coordinator
        |
        +--> CatalogObjectResolverPort
        +--> ScenarioRepository
        +--> ScenarioAccessRepository
        |
        v
Scenario application use cases
        |
        v
typed Scenario draft + local autosave

Scenario draft
        |
        +--> ScenarioLogisticsRepository --> provider gateway/fallback
        +--> ScenarioSharingRepository   --> trusted backend
        +--> ScenarioModerationRepository --> trusted backend
```

Запрещены cross-feature imports из Details/Search/Map presentation во
внутренние Create classes. App coordinator принимает стабильные primitives и
domain DTO, а feature UI получает только typed result и navigation handoff ID.

## 6. Connected composition: Details, Search и Map

### 6.1 Пользовательский результат

Пользователь может увидеть объект, нажать `Add to Scenario`, выбрать план и
получить полноценный Scenario item с исходной catalog relation, snapshot,
длительностью, availability и location. Добавление не публикует Scenario и не
изменяет исходный объект.

### 6.2 Поддерживаемые источники

| Surface | Выбор | Основное действие |
|---|---|---|
| Details | один открытый объект | `Add to Scenario` |
| Search results | один или несколько объектов | `Add selected to Scenario` |
| Map | выбранные markers/карточки | `Create/Add Scenario` |

Первая production-версия поддерживает catalog object types:

- Place;
- Event;
- Activity;
- Route;
- Bookable Session.

Stay и planned transport добавляются специализированными Scenario editors, а
не маскируются под Place/Event.

### 6.3 Details flow

1. Пользователь нажимает `Add to Scenario`.
2. Guest проходит auth guard с сохранением pending intent ID.
3. Открывается bottom sheet со списком доступных личных Scenario.
4. Пользователь выбирает:
   - существующий Scenario;
   - `Create new Scenario`;
   - day;
   - позицию `After ...` или `End of day`;
   - роль `mandatory` или `optional`;
   - при включённой capability — `Add as alternative`.
5. UI показывает короткий preview: title, date/time, duration, location,
   expected conflicts и duplicate warning.
6. После подтверждения выполняется одна atomic add operation.
7. Результат: `Added`, `Added with warnings`, `Needs resolution` или `Failed`.
8. Snackbar предлагает `Open Scenario` и `Undo`.

### 6.4 Search selection flow

1. Long press или `Select` включает selection mode.
2. Выбранные карточки сохраняются по `{objectType, objectId}`, а не index.
3. Максимум одного bulk intent — 50 объектов.
4. Скрытый фильтром объект остаётся выбранным и показывается в счётчике.
5. Перед подтверждением показываются:
   - количество объектов;
   - типы;
   - недоступные/дублирующиеся refs;
   - proposed order;
   - целевой day.
6. Порядок по умолчанию совпадает с явным selection order. Ranking Search не
   переписывает порядок после открытия confirmation.
7. Пользователь может удалить объект из staged list и изменить порядок.
8. Добавление выполняется одной operation и одной Undo entry.

### 6.5 Map selection flow

1. `Plan` включает selection mode карты.
2. Tap marker добавляет/убирает объект из selection tray.
3. Cluster раскрывается; cluster ID не является объектом и не сохраняется.
4. Selection tray показывает ordered objects и позволяет reorder.
5. Максимум 50 объектов; при достижении лимита новые markers не выбираются.
6. `Create Scenario` создаёт новый personal draft.
7. `Add to existing` открывает Scenario picker.
8. Карта передаёт object IDs. Координаты используются только как display
   snapshot и не заменяют catalog resolution.
9. Если marker относится к Route, Scenario получает один Route item, а не все
   POI Route.

### 6.6 Intent contract

```dart
enum ScenarioCompositionSource { details, search, map }

class ScenarioCompositionIntent {
  String id;
  String requesterId;
  ScenarioCompositionSource source;
  DateTime createdAtUtc;
  DateTime expiresAtUtc;
  List<ScenarioCompositionSelection> selections;
}

class ScenarioCompositionSelection {
  ScenarioCatalogObjectType objectType;
  String objectId;
  int selectionIndex;
}

sealed class ScenarioCompositionTarget {}

class ExistingScenarioTarget extends ScenarioCompositionTarget {
  String scenarioId;
  int expectedRevision;
  String dayId;
  String? afterItemId;
}

class NewScenarioTarget extends ScenarioCompositionTarget {
  ScenarioFormat format;
  String marketId;
  String timezoneId;
  String currencyCode;
}

class AddObjectsToScenarioRequest {
  String operationId;
  String intentId;
  ScenarioCompositionTarget target;
  ScenarioItemRole defaultRole;
  String? alternativeGroupId;
  bool confirmUnavailable;
  bool confirmDuplicates;
}
```

Intent хранится в bounded local handoff store для внутреннего перехода. Он:

- принадлежит requester;
- одноразовый после успешной materialization;
- имеет TTL 15 минут;
- содержит максимум 50 refs;
- не содержит полного catalog payload;
- удаляется после success/cancel/expiry;
- не записывается в analytics целиком.

Если процесс переживает перезапуск приложения, staged intent может быть
безопасно восстановлен из локального owner-scoped storage. URL содержит только
`compositionIntentId`.

### 6.7 Resolution и snapshots

`CatalogObjectResolverPort.resolveMany(refs)` возвращает результат на каждый
входной ref:

```dart
sealed class CatalogResolution {}

class CatalogResolved extends CatalogResolution {
  ScenarioCatalogObjectRef ref;
  int sourceRevision;
  ScenarioSourceSnapshot snapshot;
  ScenarioLocationDraft location;
  ScenarioAvailabilitySnapshot availability;
}

class CatalogUnavailable extends CatalogResolution {
  ScenarioCatalogObjectRef ref;
  ScenarioResolutionFailureCode code;
  ScenarioSourceSnapshot? lastKnownSnapshot;
}
```

Правила:

1. Resolver сохраняет соответствие входному order.
2. Один недоступный объект не скрывает остальные результаты.
3. `notFound`, `forbidden`, `deleted`, `marketUnsupported`, `temporarilyFailed`
   являются разными typed codes.
4. `forbidden` не возвращает title/location или факт существования сверх
   минимального generic message.
5. Last-known snapshot используется только если уже был законно доступен
   этому пользователю и помечается `stale`.
6. Snapshot является display/planning cache. Источник identity остаётся ref.
7. Event сохраняет occurrence/date semantics; flexible time не выдумывается.
8. Custom coordinates из private source не переносятся без permission.
9. Route snapshot может содержать duration/distance/endpoints, но не GPX.

### 6.8 Atomic materialization

Use case выполняет:

1. auth/access check intent и target Scenario;
2. optimistic revision check;
3. batch resolution;
4. limit and duplicate evaluation;
5. показ typed blocking issues до записи;
6. генерацию постоянных item/location/leg IDs;
7. вставку items в одном transaction/application operation;
8. перестройку затронутых соседних legs;
9. increment Scenario revision;
10. autosave;
11. одну Undo entry;
12. idempotent receipt по `operationId`.

После materialization соблюдаются общие Scenario limits v1.3:

- максимум 30 дней;
- максимум 250 items всего;
- максимум 200 active items;
- максимум 50 unscheduled items;
- максимум 20 alternative groups;
- максимум 5 items в alternative group.

Проверка выполняется до генерации/записи новых связей. Bulk request не может
частично превысить limit: пользователь сокращает selection либо явно выбирает
resolved subset, который целиком помещается в aggregate.

Повтор одного `operationId` возвращает тот же receipt и не создаёт duplicate
items.

### 6.9 Duplicate policy

Один source ref может встречаться в Scenario несколько раз: например один
отель в разные дни. Поэтому source ref не является item ID.

- точный повтор ref внутри одного bulk request дедуплицируется до confirmation;
- source уже в том же day: `Already in Day 1` + `Open existing` / `Add another`;
- source в другом day: warning, но добавление разрешено;
- Event occurrence с другим occurrence ID не считается duplicate;
- повтор создаёт новый `ScenarioItem.id`;
- personal completion/reservation/notes не копируются.

### 6.10 Connected composition issues

| Code | Severity | Поведение |
|---|---|---|
| `intent_expired` | blocking | вернуться к source и повторить selection |
| `target_revision_conflict` | blocking | Refresh / Review changes / Cancel |
| `source_forbidden` | blocking item | generic unavailable, без data leak |
| `source_deleted` | blocking item | Remove или Keep last-known unresolved |
| `duplicate_same_day` | warning | Focus existing / Add another |
| `event_date_mismatch` | blocking item | Move day / Keep unscheduled / Remove |
| `limit_exceeded` | blocking | сократить selection |
| `partial_resolution` | warning | явное подтверждение resolved subset |
| `offline_no_snapshot` | blocking item | Retry online / Keep staged intent |

### 6.11 Изменение исходного Place/Event/Route

Catalog relation не создаёт live ownership над Scenario item.

- Scenario хранит `sourceRevision` и last-resolved snapshot;
- изменение источника не переписывает draft автоматически;
- resolver может отметить item `stale` и предложить `Review update`;
- пользователь видит diff значимых полей: date/time, availability, duration,
  location, closure/cancellation и public title;
- `Apply source update` является отдельной revisioned Undo operation;
- personal overrides duration/cost/note не стираются без подтверждения;
- canceled Event создаёт blocking issue для Start/Publish и варианты
  `Replace`, `Remove`, `Keep unresolved` для personal draft;
- deleted/forbidden source сохраняет последний законный snapshot только как
  unavailable; forbidden refresh не раскрывает новые данные;
- public publish всегда повторно разрешает refs и не публикует устаревшую
  availability как актуальную;
- immutable published revision не переписывается после отмены Event/закрытия
  Place, но public Details применяет отдельный current-source-status overlay;
  overlay показывает `cancelled`, `temporarily closed` или `unavailable`, а
  критический safety/moderation signal может скрыть projection доверенной
  operation;
- source update notification требует отдельного notification consent, но
  in-app freshness check доступен без push.

Таким образом Scenario воспроизводим, но не замораживает ложную актуальность и
не зависит от live-синхронизации с владельцем source object.

## 7. Alternatives

### 7.1 Продуктовая семантика

Alternative group — один логический slot с несколькими взаимоисключающими
вариантами: например музей или парк при хорошей погоде. Это не список
последовательных остановок.

### 7.2 Инварианты

1. В Scenario максимум 20 alternative groups.
2. В group максимум 5 items.
3. Все items группы находятся в одном day либо все в Unscheduled.
4. Items группы занимают непрерывный участок day order.
5. У каждого item собственные source, duration, location, availability и cost.
6. В draft допустимы 0 или 1 selected item.
7. Более одного selected item запрещено всегда.
8. Save personal разрешает 0 selected с readiness issue.
9. Start, unlisted share и public publish требуют ровно один selected item в
   каждой используемой группе.
10. Невыбранные alternatives не входят в timeline, legs, totals и conflicts.
11. Group и item имеют независимые IDs.
12. Отключение capability скрывает editing actions, но mapper сохраняет уже
   известные groups без потери данных.

### 7.3 Модель

```dart
class ScenarioAlternativeGroup {
  String id;
  String? dayId; // null only while the whole group is Unscheduled
  String title;
  List<String> itemIds;
  String? selectedItemId;
  ScenarioAlternativeSelectionPolicy selectionPolicy;
}

enum ScenarioAlternativeSelectionPolicy {
  requiredBeforeStart,
  optional,
}
```

`ScenarioItem.alternativeGroupId` дублирует связь для удобства валидации, но
mapper обязан проверять двустороннюю целостность. Источником order является
day item list; group хранит только membership order внутри slot.

### 7.4 Создание alternative

- item menu → `Add alternative`;
- выбрать catalog object или создать custom item;
- существующий item становится первым member;
- новый item получает новый ID;
- group вставляется на позицию исходного item;
- текущий item остаётся selected;
- операция atomic и поддерживает Undo.

Connected composition может добавить selection в существующую group только
после явного выбора group. Bulk selection по умолчанию создаёт обычные
последовательные items, а не одну огромную alternative group.

### 7.5 Переключение

Выбор alternative атомарно:

1. снимает selection с прежнего item;
2. выбирает новый item;
3. удаляет прежние adjacent derived legs;
4. создаёт новые adjacent leg IDs;
5. отменяет устаревшие routing requests;
6. пересчитывает schedule, conflicts и totals;
7. увеличивает revision;
8. создаёт одну Undo entry.

UI до применения показывает delta:

- `+/- activity time`;
- `+/- travel time`;
- `+/- known budget`;
- opening/date conflicts;
- смену района/города;
- необходимость нового live routing.

### 7.6 Group operations

- Rename group;
- Add option;
- Select option;
- Reorder options inside group;
- Move entire group;
- Move group to another day;
- Detach option;
- Remove option;
- Dissolve group.

Перетаскивание одного member за пределы group сначала требует `Detach`.
Удаление последнего member удаляет group. При одном member UI предлагает
`Keep as normal stop` и удаляет group relation.

### 7.7 Alternatives и публикация

Public Scenario показывает все разрешённые варианты, выбранный default и
разницу duration/cost. Private locations, private notes и reservation state не
попадают в alternative payload. Если хотя бы один public option небезопасен,
его нужно заменить, исключить из public revision или пройти disclosure review;
вся группа не публикуется автоматически.

## 8. Travel time, плановое расписание и логистика

### 8.1 Предусловие

Production live logistics не включается без отдельного Accepted ADR, который
выбирает provider/renderer, ownership API keys, billing limits, data retention,
attribution, supported markets и incident fallback. До этого работают manual
legs, честно помеченные estimates, статическое плановое расписание и
deterministic fake provider в тестах. Статическое расписание никогда не
называется live.

### 8.2 Что является leg

Leg соединяет два соседних active items одного timeline. Он принадлежит
Scenario и не является Route.

```dart
class ScenarioLeg {
  String id;
  String dayId;
  String fromItemId;
  String toItemId;
  ScenarioTravelMode mode;
  ScenarioLegResolution resolution;
  ScenarioLegStatus status;
  int? durationMinutes;
  int? distanceMeters;
  ScenarioCost? cost;
  ScenarioLegGeometry? displayGeometry;
  ScenarioProviderAttribution? attribution;
  ScenarioLegRequestFingerprint? appliedRequest;
  bool lockedByUser;
  int revision;
}

enum ScenarioLegResolution {
  schedule,
  provider,
  cached,
  estimated,
  manual,
  unknown,
}

enum ScenarioLegStatus {
  idle,
  queued,
  calculating,
  ready,
  stale,
  failed,
  unavailable,
}
```

Display geometry нужна только для визуализации перехода и не превращает leg в
Route domain object.

### 8.3 Режимы

- walking;
- bicycle;
- driving;
- taxi estimate;
- public transit;
- manual/other.

Transit schedule для dated departure является плановым snapshot с обязательной
пометкой `Плановое расписание · не live`, service date и feed freshness.
Template Scenario получает estimate или `date_required`, но не притворное
расписание. Train/flight/ferry/intercity bus остаются `plannedTransport`
items. Личный автомобиль является полноценным primary mode и может содержать
manual/estimated duration, distance, fuel, parking и другие явные расходы.

### 8.4 Provider contract

```dart
class ScenarioLegRequest {
  String requestId;
  String scenarioId;
  int scenarioRevision;
  String legId;
  String fromItemId;
  String toItemId;
  String fromLocationId;
  String toLocationId;
  GeoPoint from;
  GeoPoint to;
  ScenarioTravelMode mode;
  ScenarioDepartureContext departure;
  String marketId;
  String locale;
}

class ScenarioLegResult {
  String requestId;
  String legId;
  int scenarioRevision;
  int durationSeconds;
  int distanceMeters;
  ScenarioCost? estimatedCost;
  EncodedDisplayGeometry? geometry;
  ScenarioProviderAttribution attribution;
  DateTime calculatedAtUtc;
  DateTime validUntilUtc;
  List<ScenarioLogisticsWarning> warnings;
}

abstract class ScenarioLogisticsRepository {
  Future<ScenarioLegResult> calculateLeg(ScenarioLegRequest request);
  Future<List<ScenarioLegResult>> calculateLegs(
    List<ScenarioLegRequest> requests,
  );
}
```

Mobile вызывает repository. Production adapter обращается к trusted routing
gateway. Provider credentials никогда не входят в app bundle или domain.

### 8.5 Когда пересчитывать

Затронутые legs становятся stale после:

- add/remove/reorder item;
- смены day;
- смены selected alternative;
- смены координаты или access point;
- смены travel mode;
- изменения departure/date/timezone;
- обновления source snapshot, влияющего на location;
- изменения active/unscheduled state.

Изменение title, public note, cover или price не инвалидирует leg.

### 8.6 Orchestration

1. После изменения draft ждёт debounce 400 ms.
2. Controller вычисляет минимальный набор affected legs.
3. Максимум 2 provider requests выполняются одновременно на Scenario.
4. Каждый запрос несёт scenario revision, endpoints, mode и departure.
5. Ответ применяется только если всё совпадает с текущим leg.
6. Manual/locked leg никогда не перезаписывается provider или schedule
   ответом.
7. Timeout — 5 секунд.
8. Для timeout/5xx разрешён один retry с jitter.
9. Поздний или отменённый ответ тихо игнорируется и учитывается в telemetry.
10. Async result не создаёт отдельную Undo operation.
11. Пользовательская смена mode или manual value создаёт Undo operation.

### 8.7 Ошибки

Stable failure codes:

- `offline`;
- `timeout`;
- `quota_exceeded`;
- `unauthorized_provider`;
- `unsupported_market`;
- `unsupported_mode`;
- `no_route`;
- `date_required`;
- `invalid_endpoint`;
- `invalid_response`;
- `cancelled`;
- `provider_unavailable`;
- `unknown`.

При ошибке:

- draft сохраняется;
- известное время не сбрасывается в 0;
- старое значение может показываться как stale с timestamp;
- UI предлагает Retry / Change mode / Enter manually;
- totals помечаются incomplete;
- unresolved dated leg блокирует Start/Publish;
- template может сохранить unknown leg с явным warning.

### 8.8 Cache

Cache key включает provider contract version, mode, endpoints, departure bucket
и market. Он не включает user ID в analytics label.

Рекомендуемый TTL baseline:

| Mode | TTL |
|---|---|
| walking/bicycle | 24 часа |
| driving/taxi | 15 минут |
| dated schedule | до смены feed/service date; всегда с freshness label |
| template estimate | 24 часа с label `estimate` |

Точная private coordinate не хранится в shared public cache. Server-side key
использует HMAC/opaque hash; raw private endpoints не попадают в logs. Public
catalog endpoints могут использовать shared cache после privacy review.
Geometry и provider response сохраняются только на разрешённый licence TTL;
если provider запрещает persistence, app хранит лишь необходимые derived
duration/distance и повторно запрашивает display geometry при открытии карты.

### 8.9 Timeline и построение логистики

Для каждого day:

1. исключить unscheduled и невыбранные alternatives;
2. взять active items в order;
3. построить пары соседей;
4. reuse совпадающий ready/cached/manual leg;
5. создать queued leg для изменившейся пары;
6. получить duration;
7. добавить явные buffers/waiting;
8. разрешить flexible/window/fixed schedule;
9. зафиксировать hard conflicts;
10. вычислить раздельные activity, local travel, planned transport и elapsed.

До provider-результата timeline использует только честно помеченный
manual/cached/estimated/schedule duration. Изменение upstream end time
инвалидирует downstream departure-sensitive transit request, если departure
вышел из его cache bucket.
Walking/bicycle leg с неизменными endpoints/mode не пересчитывается только из-за
сдвига времени. Orchestrator ограничивает cascading recalculation тем же
debounce и concurrency cap, чтобы reorder не создавал request storm.

Provider не меняет порядок автоматически. Optimization возвращает proposal с
before/after diff; применение требует отдельного подтверждения пользователя.

### 8.10 Privacy, attribution и стоимость

- provider получает только минимальные endpoints и departure context;
- home/private location не попадает в public geometry;
- analytics не содержит raw lat/lng, адрес или polyline;
- provider attribution отображается по licence terms;
- quota и billing наблюдаются по market/build/provider;
- daily/monthly budget limits имеют server kill switch;
- после kill switch manual/cached/estimated flow остаётся доступным;
- taxi/transit cost всегда помечается estimate и не становится фактическим
  расходом пользователя.

## 9. Distribution: private, unlisted и public

### 9.1 Семантика visibility

| Visibility | Кто видит | Каталог | Редактирование |
|---|---|---|---|
| private | owner и explicit collaborators | нет | по grants/capabilities |
| unlisted | владелец ссылки или explicit grant | нет | link только viewer; edit по grant |
| public | все через published projection | да | только authorized publisher workflow |

Unlisted не является «почти public» и никогда не попадает в Search, Feed или
Map catalog queries.

### 9.2 Owner, publisher и actor

Scenario хранит отдельно:

- `owner` — пользователь, владеющий personal aggregate;
- `publisher` — `{type: user|page, id}`, от чьего имени выходит public template;
- `createdByUserId` — actor создания;
- `updatedByUserId` — actor последней revision;
- access grants — кто может читать/редактировать private Scenario.

Смена publisher не меняет owner. ManagedPage membership и page capabilities
проверяются сервером на каждой privileged operation.

### 9.3 Logical capabilities

Точные codes фиксируются capability registry, но поведение требует независимых
guards:

- create personal Scenario;
- edit own Scenario;
- view invited Scenario;
- edit invited Scenario;
- invite viewer;
- invite editor;
- manage access;
- create/revoke unlisted link;
- submit for public review;
- publish as user;
- publish as ManagedPage;
- archive/delete;
- moderate/report resolution.

UI guard, route/deep-link guard и trusted backend используют одну policy
semantics. Скрытая кнопка не является авторизацией.

### 9.4 Lifecycle

Диаграмма объединяет lifecycle status и moderation outcome. `rejected` не
становится новым persisted lifecycle status и возвращает редактируемую revision
в `draft`.

```text
draft -> pending_review -> published -> archived
  ^           |              |
  |           v              v
  +-------- rejected       hidden

deleted — soft-delete terminal state до retention cleanup
```

`rejected` является moderation outcome: редактируемый content возвращается в
draft с безопасной feedback summary. `hidden` устанавливает moderation/system.

Правило revision публикации:

- опубликованная revision immutable;
- новое редактирование создаёт новую draft revision;
- текущая approved revision остаётся публичной во время review обновления;
- approval атомарно переключает catalog projection;
- rejection новой revision не снимает старую approved revision;
- archive/remove projection выполняется trusted backend.

### 9.5 Unlisted share

Unlisted share создаётся только online доверенной operation:

```dart
class CreateScenarioShareLinkRequest {
  String operationId;
  String scenarioId;
  int expectedRevision;
  DateTime? expiresAtUtc;
  bool allowSaveCopy;
}

class ScenarioShareReceipt {
  String shareLinkId;
  String oneTimePlainToken;
  String sharedRevisionId;
  DateTime createdAtUtc;
  DateTime? expiresAtUtc;
}
```

Security requirements:

1. token имеет CSPRNG entropy минимум 128 бит;
2. backend хранит только hash/token verifier;
3. plaintext показывается только в create/rotate response;
4. token не выводится из Scenario ID, owner ID, времени или revision;
5. link имеет revoke, optional expiry и rate limit;
6. token редактируется из logs, analytics, crash reports и referrer data;
7. share view использует public-safe allowlist mapper;
8. private notes, reservations, exact private locations и moderation data
   отсутствуют;
9. possession link даёт viewer access, но не edit;
10. `Save a copy` создаёт новый независимый Scenario ID и origin snapshot;
11. update shared revision выполняется явно и записывается в audit;
12. revoke действует немедленно на backend и cache.
13. rotate атомарно создаёт новый token и инвалидирует предыдущий.
14. Число active links ограничено server config и rate limit.
15. Web-view использует `noindex`, `nofollow` и
    `Referrer-Policy: no-referrer`.
16. Open Graph/notification preview не раскрывает Scenario до успешной
    проверки token.

Development mock не генерирует внешне достижимую ссылку и не включает CTA,
если production capability выключена.

### 9.6 Public publish

1. Creator выбирает publisher identity.
2. Builder выполняет readiness и privacy review.
3. Public mapper создаёт allowlisted candidate revision.
4. Trusted backend повторно валидирует schema, capability, ownership,
   publisher membership, media, geo и rate limits.
5. Content переходит в `pending_review`.
6. Moderator approve/reject/hide записывается в audit.
7. Approve создаёт/обновляет public catalog projection.
8. Search/Map/Feed читают только projection.

Public template может включать:

- title/description/cover;
- publisher snapshot;
- format/days;
- public-safe items и source refs;
- alternatives;
- public/approximate locations;
- activity/travel estimates;
- public notes и known/estimated budget;
- provider attribution;
- immutable published revision metadata.

Public payload запрещает:

- private notes и completion;
- booking confirmation/reservation IDs;
- invite identities и access grants;
- share tokens;
- exact private/home coordinates;
- online secrets;
- moderation notes/internal scores;
- audit actor details;
- raw provider request/response;
- personal actual expenses.

### 9.7 Public readiness

Publish блокируется, если:

- меньше 2 active items;
- broken day/item/location/leg reference;
- временный `loc_*` ID;
- more than one или zero selected в используемой alternative group;
- unresolved fixed-time conflict;
- Event не соответствует дате;
- private location не заменена public/approximate representation;
- обязательный leg unknown без разрешённой public manual note;
- source forbidden/deleted без approved fallback;
- misleading duration/budget;
- publisher/capability недействительны;
- moderation validation не пройдена.

## 10. Совместный доступ

### 10.1 Модель ролей

| Collaboration role | Read | Edit content | Invite | Share/publish | Manage access |
|---|---:|---:|---:|---:|---:|
| owner | да | да | да | по capability | да |
| editor | да | да | нет по умолчанию | нет | нет |
| viewer | да | нет | нет | нет | нет |
| unlisted viewer | safe revision | нет | нет | нет | нет |

Collaboration role не заменяет User/Creator/Admin и не даёт publisher
capabilities. Это resource-scoped access grant.

### 10.2 Access grant

```dart
class ScenarioAccessGrant {
  String id;
  String scenarioId;
  String subjectUserId;
  ScenarioCollaborationRole role;
  ScenarioAccessGrantStatus status;
  String grantedByUserId;
  DateTime grantedAtUtc;
  DateTime? revokedAtUtc;
  int revision;
}
```

Правила:

- invitation требует authenticated recipient;
- email может использоваться только для поиска/доставки приглашения, identity
  в grant — permanent user ID;
- один active grant на `{scenarioId, subjectUserId}`;
- owner нельзя удалить или понизить через обычный grant flow;
- revoke действует до следующего read/write;
- editor не меняет owner, publisher, grants, lifecycle или moderation;
- exact private locations видны только если location disclosure отдельно
  разрешает collaborator access;
- все grant/revoke операции server-authorized и audited;
- broad list collaborators не попадает в public payload.

### 10.3 Совместное редактирование и конфликты

Каждая write operation содержит:

- `operationId`;
- `scenarioId`;
- `expectedRevision`;
- actor ID из auth context;
- typed command;
- touched entity IDs.

Backend возвращает new revision или `revision_conflict` с безопасным latest
snapshot/diff metadata. Базовая политика соответствует ADR 0013: LWW + user
warning, но конфликт не скрывается.

Разрешение:

- non-overlapping add нового item может быть предложен к safe reapply;
- edit разных item может быть предложен к reapply после validation;
- reorder одного day, delete/edit того же item, alternative selection и
  publisher/access changes требуют Review changes;
- пользователь выбирает `Use latest`, `Reapply mine` или `Save conflict copy`;
- `Save conflict copy` создаёт новый private Scenario ID;
- silent overwrite без warning запрещён;
- offline command queue хранит исходную expected revision;
- после revoke неотправленные editor commands отклоняются и доступны только
  как локальный export/conflict copy владельцу этих изменений.

CRDT, field-level real-time merge и presence cursors остаются out of scope.

## 11. Moderation и reports

### 11.1 Submission checks

- schema/version/limits;
- publisher/capability/membership;
- duplicate/suspicious publish velocity;
- forbidden text/media;
- misleading schedule/budget;
- unsafe custom locations;
- private-data leak scan;
- unavailable source refs;
- public notes and provider attribution;
- repeated copied templates/spam.

### 11.2 Report flow

- reportable: public и unlisted safe view;
- reporter должен быть authenticated;
- один уникальный report пользователя на object в policy window;
- baseline auto-hide: минимум 5 уникальных reporters за 24 часа;
- auto-hide не заменяет moderator review;
- report reason, object revision и timestamps сохраняются;
- reporter identity не показывается publisher;
- false-report abuse rate-limited;
- moderator actions immutable в audit.

### 11.3 Moderation outcomes

- approve;
- reject revision с safe publisher feedback;
- request changes;
- hide current published projection;
- restore после review;
- archive/delete согласно retention/legal policy.

Moderator не редактирует Scenario от имени автора. Исправление делает
authorized owner/editor и отправляет новую revision.

## 12. Repository contracts

Целевые domain ports:

```dart
abstract class ScenarioCompositionRepository {
  Future<ScenarioCompositionIntent> saveIntent(
    /* parameters intentionally omitted */
  );
  Future<ScenarioCompositionIntent?> getIntent(String id);
  Future<void> consumeIntent(String id);
}

abstract class CatalogObjectResolverPort {
  Future<List<CatalogResolution>> resolveMany(
    List<ScenarioCatalogObjectRef> refs,
  );
}

abstract class ScenarioRepository {
  Future<ScenarioDraft?> getById(String id);
  Future<ScenarioSaveReceipt> save(
    ScenarioDraft draft, {
    required int expectedRevision,
    required String operationId,
  });
}

abstract class ScenarioSharingRepository {
  Future<ScenarioShareReceipt> createLink(/* parameters intentionally omitted */);
  Future<void> revokeLink(/* parameters intentionally omitted */);
  Future<ScenarioShareView> resolveLink(/* parameters intentionally omitted */);
}

abstract class ScenarioAccessRepository {
  Future<List<ScenarioAccessGrant>> list(/* parameters intentionally omitted */);
  Future<ScenarioAccessGrant> invite(/* parameters intentionally omitted */);
  Future<void> revoke(/* parameters intentionally omitted */);
}

abstract class ScenarioPublishingRepository {
  Future<ScenarioSubmissionReceipt> submit(
    /* parameters intentionally omitted */
  );
  Future<void> archive(/* parameters intentionally omitted */);
}

abstract class ScenarioModerationRepository {
  Future<ScenarioModerationReceipt> moderate(
    /* parameters intentionally omitted */
  );
  Future<ScenarioReportReceipt> report(
    /* parameters intentionally omitted */
  );
}
```

Firebase/provider classes существуют только в data/datasource adapters. Domain,
application и presentation не импортируют Firebase/Maps SDK types.

### 12.1 Trusted backend operations

Логические названия ниже не фиксируют transport API, но фиксируют server-owned
ответственность.

| Operation | Ответственность |
|---|---|
| `resolveScenarioSources` | owner-aware batch resolution и safe unavailable codes |
| `calculateScenarioLegs` | provider proxy, quota, cache, attribution и redaction |
| `syncScenarioDraft` | expected revision, idempotency receipt и conflict response |
| `createScenarioShareLink` | allowlist revision, CSPRNG token, hash/expiry/rate limit |
| `revokeScenarioShareLink` | немедленный revoke и cache invalidation |
| `inviteScenarioCollaborator` | identity lookup, role/access validation и audit |
| `revokeScenarioCollaborator` | revoke grant и последующих remote writes |
| `submitScenarioRevision` | capability/publisher/readiness/privacy validation |
| `moderateScenarioRevision` | approve/reject/hide и immutable audit |
| `rebuildScenarioProjection` | idempotent public projection из approved revision |
| `reportScenario` | uniqueness, abuse limit и auto-hide threshold |

Каждая externally visible mutation принимает client-generated `operationId`,
проверяет Auth/App Check/capability, валидирует allowlist schema, исполняется
идемпотентно и возвращает stable application error code. Security Rules не
заменяют authorization внутри trusted operation.

## 13. UI structure

### 13.1 Scenario picker sheet

- recent personal Scenario;
- search My Scenarios;
- owner/editor access badge;
- format/day count/update time;
- incompatible target reason;
- `Create new Scenario`;
- day/position/role controls;
- confirm summary.

### 13.2 Composer additions

- day rail и active day;
- source badges;
- alternative group card;
- selected/default indicator;
- leg card между active items;
- stale/live/manual status;
- change mode/retry/manual actions;
- collaboration status;
- private/unlisted/public review entry.

### 13.3 Review

Раздельно показываются:

- activity time;
- local travel time;
- planned transport;
- waiting/buffers;
- known/estimated/unknown costs;
- unresolved sources;
- selected alternatives;
- stale/failed legs;
- private-data disclosures;
- publisher and visibility;
- moderation readiness.

### 13.4 Accessibility

- все действия имеют semantic labels;
- alternative selection не обозначается только цветом;
- drag имеет Move up/down fallback;
- loading status объявляется screen reader без постоянного spam;
- errors привязаны к item/group/leg и доступны из summary;
- 320–360 dp layout не требует горизонтального scroll основной формы;
- map selection полностью доступен через параллельный ordered list.

## 14. State machine

```text
composition intent:
staged -> resolving -> review_required -> applying -> applied
   |          |              |              |
 expired    failed         cancelled      conflict

leg:
idle -> queued -> calculating -> ready
                    |            |
                    v            v
                  failed        stale

share link:
active -> expired | revoked

collaboration grant:
invited -> active -> revoked

publish revision:
draft -> pending_review -> approved | rejected | hidden
```

Каждый переход имеет typed failure и допустимый recovery action.

## 15. Analytics и observability

### 15.1 Product events

- `scenario_add_started` — source surface/type/count;
- `scenario_add_completed` — resolved/added/warning counts;
- `scenario_add_failed` — stable reason;
- `scenario_alternative_created`;
- `scenario_alternative_selected`;
- `scenario_leg_requested` — mode/cache eligibility;
- `scenario_leg_resolved` — live/cached/manual, latency bucket;
- `scenario_leg_failed` — stable provider-independent code;
- `scenario_share_created` — expiry bucket, без token;
- `scenario_share_revoked`;
- `scenario_collaborator_invited` — role, без email/user ID;
- `scenario_revision_conflict` — operation type;
- `scenario_publish_submitted`;
- `scenario_moderation_result` — outcome/reason family;
- `scenario_report_submitted` — reason family.

### 15.2 Запрещённые analytics fields

- raw search text;
- title/private notes;
- address/lat/lng/polyline;
- share token/link;
- email, invited user ID;
- reservation/confirmation code;
- moderation free-form notes;
- provider raw response.

### 15.3 Operational metrics

- resolver success/partial/failure rate;
- add operation latency and idempotency duplicate rate;
- live routing p50/p95/error/quota/cache-hit by mode/market;
- stale response discard count;
- conflict rate by command;
- share resolve/revoke latency;
- moderation queue age;
- projection lag;
- privacy mapper rejection count;
- kill-switch activation.

## 16. Feature flags и kill switches

Независимые flags:

- `scenario_connected_add_details`;
- `scenario_connected_add_search`;
- `scenario_connected_add_map`;
- `scenario_alternatives`;
- `scenario_live_logistics`;
- `scenario_live_transit`;
- `scenario_unlisted_share`;
- `scenario_collaboration`;
- `scenario_public_submit`;
- `scenario_public_projection`.

Правила:

- flags проверяются capability service, не только UI;
- remote disable не удаляет draft data;
- live disable сохраняет manual/cached values с честным status;
- public projection kill switch может остановить новые projections без
  изменения personal drafts;
- share emergency switch запрещает новые resolve/create и допускает revoke;
- rollback не требует app release для high-risk capabilities.

## 17. Безопасность и privacy checklist

1. Default deny backend rules.
2. Auth и App Check для trusted operations.
3. Server проверяет capability, owner, publisher и page membership.
4. Immutable IDs/owner/publisher metadata нельзя переписать клиентом.
5. Private и public data физически/логически разделены.
6. Public/unlisted payload формируется allowlist mapper.
7. Share token хранится hash-only и редактируется из telemetry.
8. Exact private locations не попадают в provider shared cache/public map.
9. Access grants server-owned и audited.
10. Revoke проверяется на каждом защищённом read/write.
11. Moderation/audit writes server-only.
12. Rate limits для add bulk, share resolve, invite, publish и report.
13. All lists/strings ограничены по размеру.
14. Rule/emulator tests содержат allow и deny cases.
15. Legal/privacy review обязателен перед production enablement в EU.

## 18. Ошибки и восстановление

| Ситуация | Данные | UX recovery |
|---|---|---|
| Offline при add | staged intent сохраняется | Retry / Cancel |
| Часть refs недоступна | resolved subset не теряется | Review and confirm |
| Target revision изменена | запись не выполняется | Review changes |
| Routing timeout | draft и старый leg сохранены | Retry / Manual |
| Provider quota | manual/cached flow | Change mode / Later |
| Share backend offline | personal Scenario сохранён | Retry online |
| Invite revoke во время edit | remote write отклонён | Save conflict copy |
| Publish rejected | published old revision не теряется | Fix draft / Resubmit |
| Projection failure | canonical approved revision сохранена | idempotent rebuild |
| App crash after operation | operation receipt/idempotency | Restore exact result |

Неизвестные duration/cost никогда не преобразуются в ноль.

## 19. Implementation slices

### SCN-CONNECT-01 — Connected add

Scope:

- intent/handoff contract;
- app-level coordinator;
- resolver port и mock/real repository adapter;
- Details single add;
- Search/Map selection mode;
- Scenario picker;
- atomic add, duplicates, partial resolution и Undo.

Gate: новый cross-feature flow; реализация начинается после закрытия активной
стабилизации либо отдельного явно Approved исключения. Firebase не требуется,
если реальные catalog repositories уже доступны через существующие contracts.

### SCN-ALT-01 — Alternatives

Scope:

- group model/mapper/validation;
- composer group UI;
- create/select/detach/dissolve;
- schedule/totals/logistics isolation;
- disabled-data round trip.

Gate: Approved specialized Scenario Create slice. Может использовать mock и
не зависит от public backend.

### SCN-LOG-01 — Live logistics

Scope:

- отдельный maps/logistics ADR;
- provider gateway/repository adapter;
- leg orchestration, caching, attribution, quotas;
- stale response protection;
- manual fallback, kill switch и incident runbook.

Gate: post-stabilization, Accepted ADR, security/privacy/billing approval.

### SCN-DIST-01 — Unlisted/public foundation

Scope:

- public allowlist mapper;
- immutable revision contract;
- sharing/publishing ports;
- publisher/capability guards;
- backend share tokens;
- submission/moderation/catalog projection.

Gate: post-stabilization backend foundation, Auth, capabilities, ManagedPage,
Rules, Functions, audit and moderation runtime.

### SCN-COLLAB-01 — Collaboration

Scope:

- grants/invitations;
- owner/editor/viewer guards;
- optimistic sync and conflict recovery;
- revoke behavior and audit;
- notification hooks after separate consent policy.

Gate: SCN-DIST-01 access foundation and authenticated backend sync.

Порядок по умолчанию:

```text
SCN-ALT-01 ------------------------------+
                                         |
SCN-CONNECT-01 -> personal integration --+--> SCN-LOG-01
                                         |
backend access foundation -> SCN-DIST-01 +--> SCN-COLLAB-01
```

Connected add и alternatives не ждут live routing: legs могут быть manual или
unknown. Public/collaboration не включаются только на основании готового UI.

## 20. Рекомендуемый план файлов реализации

Документ не авторизует изменения, но фиксирует ожидаемое размещение.

### App composition

- planning composition providers/facade;
- ID-only intent/handoff store;
- adapters из Details/Search/Map selection в Scenario intent.

### Scenario domain

- composition request/result/issues;
- alternative group entity/validation;
- logistics request/result/leg states;
- sharing/access/publishing contracts;
- readiness rules и public mapper policy.

### Scenario application

- add objects use case;
- alternative commands;
- rebuild affected legs use case;
- live orchestration controller;
- create/revoke share use cases;
- invite/revoke collaborator use cases;
- submit publication use case;
- conflict resolver.

### Data

- local intent datasource;
- catalog resolver adapter;
- fake logistics datasource;
- production provider gateway adapter после ADR;
- backend sharing/access/moderation adapters;
- versioned mappers and repository contract tests.

### Presentation

- Details add action;
- Search/Map selection tray;
- Scenario picker;
- alternatives group card/editor;
- leg status/editor;
- sharing/access/publish review;
- conflict resolution sheet.

Общие UI primitives переходят в design system только при подтверждённом
повторном использовании; бизнес-специфичные widgets остаются в feature.

## 21. Test matrix

### 21.1 Connected composition

- Details/Search/Map создают одинаковый canonical intent;
- URL содержит только intent ID;
- auth resume не теряет selection;
- order сохраняется;
- 1/50/51 items;
- duplicate same day/across days/occurrences;
- all resolved/partial/none resolved;
- forbidden не раскрывает source data;
- event date mismatch;
- atomic add и one-step Undo;
- repeated operation ID idempotent;
- revision conflict не пишет partial draft;
- Route ref не переносит GPX;
- app boundary gate без новых allowlist suppressions.

### 21.2 Alternatives

- zero/one/multiple selected;
- max groups/options;
- create/detach/dissolve;
- move as group;
- switch rebuilds only adjacent legs;
- unselected option excluded from time/cost/conflicts;
- selected option included exactly once;
- public mapper strips private option data;
- disabled capability round-trip preserves groups;
- Undo/Redo restores full group state.

### 21.3 Logistics

- each supported mode;
- template transit returns estimate/date-required;
- cache hit/miss/expiry;
- debounce and max concurrency;
- reorder/removal/alternative switch invalidation;
- stale revision/mode/endpoints response discarded;
- manual lock cannot be overwritten;
- timeout/retry/offline/quota/no-route;
- old value stays stale, never zero;
- private endpoint not logged/shared;
- attribution displayed;
- kill switch fallback;
- timeline and totals after async result.

### 21.4 Distribution/collaboration

- private/unlisted/public read guards;
- token entropy/hash/expiry/revoke/redaction;
- unlisted absent from catalog queries;
- owner/editor/viewer permissions;
- revoked editor write denied;
- ManagedPage active/revoked membership;
- all lifecycle transitions and invalid skips;
- published revision immutable;
- rejected update keeps prior published revision;
- allowlist mapper contains 0 private fields;
- custom location disclosure rules;
- report uniqueness and 5/24h auto-hide;
- moderation/audit server-only writes;
- concurrent same/different item edits;
- offline conflict copy;
- idempotent projection rebuild;
- Firebase emulator allow/deny matrix before production.

### 21.5 End-to-end critical paths

1. Place Details → existing Scenario → Day 2 → live walking leg → Save.
2. Search multi-select Event + Place → new Scenario → resolve date conflict.
3. Map select 5 objects → reorder → atomic add → Undo.
4. Add rainy-day alternative → select → totals/legs change.
5. Provider timeout → manual leg → personal Save.
6. Personal Scenario → unlisted link → viewer Save a copy → independent ID.
7. Creator submit → moderation approve → catalog/details/map projection.
8. Editor changes item while owner reorders → explicit revision resolution.
9. Report threshold hides projection without deleting owner draft.

## 22. Acceptance criteria

### Connected add

1. Details, Search и Map передают immutable object IDs.
2. Пользователь выбирает new/existing Scenario, day и position.
3. Bulk add до 50 объектов выполняется атомарно.
4. Partial/unavailable sources никогда не пропускаются молча.
5. Duplicate policy не запрещает законный повтор source в другой день.
6. Add создаёт новые permanent item/location/leg IDs.
7. Операция поддерживает Undo и idempotent retry.
8. Revision conflict не перезаписывает Scenario молча.
9. Route item не загрязняет Scenario Route-полями.
10. Presentation features не импортируют внутренности Create/Scenario друг
    друга.

### Alternatives

11. Group содержит до 5 вариантов и максимум один selected.
12. Невыбранные варианты не входят в timeline/totals/legs.
13. Переключение атомарно перестраивает соседние legs.
14. Group переносится как один slot.
15. Draft с zero selected сохраняется с issue; Start/Share/Publish блокируются.
16. Disabled flag не уничтожает persisted alternatives.

### Live logistics

17. Live provider скрыт за repository и trusted gateway.
18. Каждый ответ защищён request fingerprint и Scenario revision.
19. Timeout, quota, offline и no-route имеют ручной recovery.
20. Неизвестное/stale время не считается нулём.
21. Manual locked leg не перезаписывается.
22. Cache/privacy/attribution соответствуют ADR и provider terms.
23. Kill switch оставляет Scenario редактируемым и сохраняемым.
24. Live logistics не создаёт Route aggregate.

### Distribution/collaboration

25. Unlisted token имеет минимум 128 бит entropy, hash storage, revoke/expiry.
26. Unlisted Scenario отсутствует в catalog projections.
27. Public mapper не содержит private/personal fields.
28. Publish проверяет Creator/publisher/page capabilities на backend.
29. Published revision immutable; update проходит отдельный review.
30. Owner/editor/viewer permissions проверяются на каждый read/write.
31. Link possession не даёт edit permission.
32. Revoked grant прекращает последующие remote writes.
33. Conflicts показываются пользователю; silent overwrite запрещён.
34. Reports и auto-hide соответствуют ADR 0013.
35. Moderation, grants, publisher и audit нельзя записать клиентом.
36. Все production capabilities имеют feature flag и rollback без app release.

## 23. Definition of Done каждого implementation slice

Slice считается Done только если:

- имеет Approved slice spec и acceptance criteria;
- соблюдает Accepted ADR;
- domain/application/data/presentation boundaries пройдены;
- typed errors и recovery UI реализованы;
- mapper backward/forward compatibility протестирована;
- privacy/security negative tests зелёные;
- analytics не содержит запрещённых данных;
- kill switch и rollback проверены;
- 320/360 dp и accessibility checks пройдены;
- `flutter analyze` — 0 issues;
- `flutter test` — все тесты зелёные;
- boundary gate — без новых необоснованных suppressions;
- `git diff --check` пройден;
- `LAUNCH_STATUS.md` обновлён до факта;
- Firebase/provider integration не заявлена до реального emulator/stage proof.

## 24. Rollout

1. Internal development с fake resolver/logistics и disabled sharing.
2. Unit/contract/widget coverage.
3. Dogfood personal connected add/alternatives.
4. Stage provider gateway с synthetic/private-safe test routes.
5. Малый market rollout live walking, затем bicycle/driving/transit отдельно.
6. Stage unlisted access с security/rules penetration checklist.
7. Creator public submit без catalog projection для moderation dry run.
8. Ограниченный public projection в Riga.
9. Collaboration viewer, затем editor отдельно.
10. Расширение по метрикам error/privacy/moderation/cost.

Rollout unit — capability × market × platform, а не весь Scenario целиком.

## 25. Rollback

- Connected add off: существующие Scenario остаются редактируемыми.
- Alternatives off: группы read-only, selected option сохраняется.
- Live logistics off: cached/manual values остаются, новые requests не идут.
- Transit off: walking/manual остаются.
- Sharing off: новые links не создаются; emergency mode может блокировать
  resolve, revoke остаётся доступен.
- Public submit off: drafts и текущая approved projection сохраняются.
- Projection off: trusted backend удаляет/замораживает public projections без
  удаления canonical Scenario.
- Collaboration off: новые invites/writes блокируются; owner сохраняет доступ;
  локальные editor changes можно сохранить как conflict copy.

Rollback не выполняет destructive schema downgrade и не стирает неизвестные
поля.

## 26. Риски

| Риск | Мера |
|---|---|
| Cross-feature coupling | app facade + ID-only intent + boundary gate |
| Скрытая потеря selected objects | staged review + atomic operation + receipt |
| Stale async routing | revision/fingerprint guard |
| Provider cost/quota | cache, concurrency cap, budgets, kill switch |
| Утечка private location | private endpoints, allowlist mapper, log redaction |
| Unlisted token leak | CSPRNG, hash-only, revoke, no telemetry/referrer |
| Editor overwrites owner | optimistic revision + explicit conflict recovery |
| Публикация опасного места | disclosure review + moderation blocker |
| Public revision исчезает при reject | immutable approved revision + separate draft |
| Route/Scenario снова смешиваются | catalog ref only, no GPX in Scenario |
| Mock принимают за production | capabilities disabled until backend proof |

## 27. Решения, требующие отдельного approval

Перед production implementation должны быть утверждены:

1. maps/logistics provider ADR: provider, renderer, licence, billing, cache,
   privacy и failover;
2. точный capability code registry;
3. backend operation/API schema и rate limits;
4. maximum expiry unlisted link и legal retention;
5. notification/consent policy для invitations и source updates;
6. ManagedPage membership/query model;
7. moderation SLA и operator tooling;
8. EU privacy assessment provider routing data;
9. stage/prod rollout budget и incident owners.

Эти решения не блокируют domain contracts и personal mock UI, но блокируют
соответствующий production capability.

## 28. Итоговый продуктовый контракт

После реализации всех gates пользователь сможет:

1. выбрать реальные места, события и другие catalog objects из Details,
   Search или Map;
2. добавить их в новый или существующий Scenario без потери identity;
3. построить дни и взаимоисключающие alternatives;
4. получить честное live/manual время между остановками;
5. увидеть конфликты расписания, логистики и бюджета;
6. сохранить личный Scenario offline;
7. безопасно поделиться unlisted revision;
8. пригласить viewer/editor без выдачи publisher прав;
9. опубликовать модерируемый Scenario template от User/ManagedPage;
10. сохранить независимость Place, Event, Route, Scenario и Quick Plan.

Главный принцип: connected planning повышает связность пользовательского
опыта, но не смешивает domain aggregates и не ослабляет privacy, permission
или lifecycle boundaries.
