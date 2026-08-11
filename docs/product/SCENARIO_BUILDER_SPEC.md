# RECHARGE — Scenario Builder Product Spec

Версия: v1.7 (2026-08-04). Статус: **Accepted**.
Уровень: продуктовая спецификация самостоятельного блока Scenario в Create
Hub и personal Scenario flow.

Этот документ описывает продуктовую и системную логику самостоятельного
**Scenario**: personal/public плана из дней, остановок, времени, логистики и
бюджета. **Scenario Builder** — его редактор. **Quick Plan** является отдельным
лёгким personal/invited продуктом и не входит в Scenario aggregate. Документ
сам по себе не утверждает завершённую реализацию и не меняет текущий код
приложения. Решения §27 приняты владельцем продукта 2026-07-19; реализация
ведётся отдельными Scenario Create slices с собственными file plan, acceptance
criteria и проверками.

Связанные документы:

- [VISION.md](VISION.md);
- [AI_PRODUCT_STRATEGY.md](AI_PRODUCT_STRATEGY.md);
- [SCENARIO_AI_GENERATION_SPEC.md](SCENARIO_AI_GENERATION_SPEC.md);
- [ROUTE_BUILDER_SPEC.md](ROUTE_BUILDER_SPEC.md);
- [S3_CRT_01_CREATE_SPEC.md](S3_CRT_01_CREATE_SPEC.md);
- `docs/architecture/ARCHITECTURE_BASELINE.md`;
- `docs/adr/`.

---

## 0B. Changelog v1.6 → v1.7

`SCN-FUEL-CLEANUP-01` завершил принятое в v1.6 упрощение:

1. Fuel consumption, price, budget toggle и inferred `fuel` cost удалены из
   canonical runtime и Scenario Create UI.
2. `Own car`, manual duration/distance и explicit `travel_extra` сохранены.
3. Старые fuel-ключи читаются терпимо, игнорируются и больше не записываются;
   legacy derived component `fuel` отбрасывается при нормализации.
4. Полный gate: analyzer 0 issues, 590 tests passed, boundary passed с 59
   существующими suppressions, diff check passed.

Реализация завершена 2026-08-04. Подробности — в
`SCENARIO_FUEL_CLEANUP_SLICE_SPEC.md`.

---

## 0A. Changelog v1.5 → v1.6

Владелец продукта утвердил упрощение основного Scenario UX:

1. Тип топлива, расход, цена топлива и автоматический fuel budget estimate не
   входят в целевой продукт и удаляются отдельным backward-compatible cleanup
   slice. Автомобиль остаётся primary mode с временем, расстоянием и явными
   ручными дополнительными расходами.
2. Exact planned-transport snapshot остаётся внутренним механизмом
   воспроизводимости, offline и Recheck. Основной UI не показывает GTFS ids,
   feed digest и технический `source status`; пользователю достаточно
   `Плановое расписание`, времени последней проверки, понятного предупреждения
   об изменении/устаревании, действия `Перепроверить` и обязательного `не live`.
   Необходимая licence/provider attribution может оставаться во вторичных
   сведениях.
3. Local-demo AI generation сохраняется, но скрыта как experimental feature за
   feature flag и не входит в основной путь создания Scenario.
4. Основной путь продукта: `создать → добавить места/события → распределить по
   дням → проверить время и логистику → сохранить`.

Решение принято 2026-08-03. Фактическое удаление legacy fuel-полей и
упрощение transport disclosure требуют отдельного согласованного file plan,
миграции/rollback и полного gate; эта редакция spec сама код не меняет.

---

## 0. Changelog v1.4 → v1.5

Версия v1.5 фиксирует Latvia-wide transport foundation:

1. Рига является пилотным рынком качества, а не границей Scenario.
2. Личный автомобиль становится полноценным primary travel mode; новый
   Scenario по умолчанию допускает car/walking/transit.
3. Статическое расписание автобусов и поездов всегда маркируется
   `Плановое расписание · не live`.
4. Manual, schedule, estimate и provider provenance не смешиваются.
5. Автоматический импорт официальных GTFS вынесен в отдельный
   `SCN-LV-DATA-01`; SCN-SB-04 остаётся local/manual и не требует платного API.
6. Подробный контракт находится в
   `SCENARIO_LATVIA_TRANSPORT_SLICE_SPEC.md`.

### Changelog v1.3 → v1.4

Версия v1.4 добавляет AI Scenario Generation как опциональный
post-stabilization entry mode:

1. AI является одним способом получить transient Scenario proposal/seed,
   наряду с ручным созданием, selected-object composition, Quick Plan
   conversion и public template copy.
2. AI proposal не является отдельным aggregate и не обходит typed mapper,
   permanent-ID rules, deterministic validation или explicit apply.
3. Web/provider facts имеют source, freshness и confidence; unresolved
   candidate не становится catalog relation.
4. Live AI/web/availability/logistics требуют отдельных Approved slices,
   backend proxy, quotas, privacy review и kill switches.
5. Общая AI strategy вынесена в `AI_PRODUCT_STRATEGY.md`, подробный контракт —
   в `SCENARIO_AI_GENERATION_SPEC.md`.

### Changelog v1.2 → v1.3

Версия v1.3 исправляет продуктовую иерархию после решения владельца продукта:

1. Scenario стал самостоятельным personal/public aggregate и Create-типом
   `scenario`; он больше не является payload Quick Plan (§2, §5, §6).
2. Quick Plan определён как отдельный лёгкий personal/invited план на несколько
   часов вне Create Hub, Discover, publisher и Review (§2).
3. Добавлен явный one-way `Expand to Scenario`: новый Scenario ULID, snapshot
   переноса, предупреждения о потерях и отсутствие live-связи (§7).
4. Scenario занимает planning-slot целевой десятки Create Hub; текущий
   `quickPlan` Create type становится migration debt, а не одиннадцатым типом
   (§22, §24).
5. Сохранены сильные решения v1.2: независимые delivery capabilities,
   Create-owned picker port, Route snapshot policy, secure unlisted sharing и
   проверенная dependency matrix.
6. Quick Plan sharing ограничен invited/unlisted координацией и никогда не
   превращает план в каталоговый объект. Scenario distribution остаётся
   отдельной capability.

---

## 1. Продуктовый инвариант

**Scenario не является Route. Route не является Scenario.**

### Route

Route — один непрерывный трек для прогулки, туризма или спорта. Его основа:

- геометрия пути;
- start/finish и anchors;
- километраж;
- набор высоты;
- покрытие и сложность;
- POI, расположенные на нити маршрута;
- профиль движения: hike, bike или trail run.

Route отвечает на вопрос: **«Как пройти или проехать этот путь?»**

### Scenario

Scenario — самостоятельный составной план досуга или поездки. Его основа:

- самостоятельные места, события, активности и маршруты;
- один или несколько дней;
- порядок посещения;
- время внутри каждого объекта;
- логистика между объектами;
- бюджет;
- участники и ограничения;
- бронирования и организационные заметки.

Scenario отвечает на вопрос:
**«Что мы делаем, когда, в каком порядке и что делать дальше?»**

Пример Scenario:

> Отель → завтрак → природный Route → заселение → ресторан → концерт.

В этом примере природный Route является одним самостоятельным Scenario item.
Геометрия Route не переносится в Scenario: план хранит ссылку на
опубликованный Route по id и использует его публичные итоги. Внутренние POI
Route не становятся остановками Scenario автоматически. Если место нужно как
самостоятельная остановка до/после Route, пользователь добавляет его отдельным
item по id.

### Что не является Scenario

- одиночное место без плана продолжения;
- один непрерывный пеший или велосипедный трек;
- неупорядоченная коллекция рекомендаций;
- поисковая выдача без сохранённого порядка и параметров;
- текстовая заметка о поездке без объектов и расписания.

---

## 2. Термины и граница с соседними продуктами

Чтобы не смешивать географию, каталог и расписание, документ использует
следующие термины:

- **Location** — координата, адрес или географическая область;
- **Place** — самостоятельный опубликованный объект каталога, расположенный
  в Location;
- **Item** — одно появление Place/Event/Activity/Route или служебного блока
  в конкретном Scenario;
- **Leg** — перемещение между двумя соседними Item;
- **Day** — логическая часть многодневного Scenario в своей локальной дате и
  IANA timezone;
- **Template** — сценарий без обязательных календарных дат;
- **Plan** — личная редактируемая копия; она может оставаться template, но для
  `Start scenario` её обязательно перевести в dated mode.

Place и Location не взаимозаменяемы: Scenario объединяет каталоговые объекты
и, при необходимости, пользовательские locations. Location сама по себе не
получает карточку Place и не появляется в Discover.

| Продукт | Основная единица | Порядок | Время | Логистика | Публикация |
|---|---|---:|---:|---:|---:|
| Route | геометрия трека | обязательный | длительность трека | внутри трека | да |
| Scenario | городской/многодневный план | обязательный | по элементам/дням | между элементами | personal, unlisted или public template |
| Quick Plan | лёгкий план на несколько часов | обязательный | простой, один день | упрощённая | private, invited или unlisted; не каталог |
| Collection | карточка объекта | необязательный | нет | нет | да |
| Favorites | ссылка на объект | нет | нет | нет | нет |

### Scenario и Quick Plan

Это два разных aggregates и два разных пользовательских намерения:

- Quick Plan — быстрый план «сегодня / вечером / в субботу»;
- Quick Plan обычно содержит 2–8 stops, одну локальную дату и 30 минут–6 часов;
- Quick Plan доступен обычному User, не имеет publisher, public lifecycle,
  Discover card или Review;
- допустимые visibility Quick Plan: `private | invited | unlisted`; значения
  `public` у Quick Plan нет;
- `invited` проверяет membership/ACL, `unlisted` — possession of revocable
  token; ни один режим не создаёт каталоговую projection;
- invited означает координацию с известными людьми; открытый поиск незнакомых
  участников остаётся Find People;
- если пользователь организует активность «для всех» с собственным временем,
  местом и участниками, это Event/Activity, а не Quick Plan;
- Scenario — city/day/weekend/trip с днями, logistics, stay, transport,
  alternatives, multi-timezone и бюджетом;
- Scenario имеет собственный ULID, repository, lifecycle и object type
  `scenario`;
- Scenario может быть personal, unlisted или public template;
- public Scenario публикует воспроизводимый itinerary template, но не создаёт
  occurrence, capacity или attendee list — эти semantics принадлежат Event;
- `Expand to Scenario` копирует допустимые stops/context в новый Scenario и
  сохраняет origin snapshot, но не создаёт live-связь;
- последующие изменения Quick Plan и Scenario не синхронизируются;
- Scenario нельзя «сжать» обратно в Quick Plan без явного нового export flow.

Quick Plan остаётся лёгким даже после появления Scenario: расширенные поля не
прячутся в нём за progressive disclosure, а появляются только после явного
`Expand to Scenario`.

Полная schema, invited-membership и collaboration policy Quick Plan находятся
в отдельной будущей спецификации. Этот документ фиксирует только границу и
conversion contract, необходимые Scenario; он не делает Quick Plan частью
Scenario domain.

### Scenario и Collection

Collection — подборка без обязательного времени и логистики. Пользователь
может создать Scenario из Collection, но это новая сущность с собственным id,
порядком, расписанием и переходами. Изменение исходной Collection не должно
молча менять уже сохранённый Scenario.

### Архитектурные инварианты

1. Scenario Builder расширяет Scenario в едином config-driven Create form
   engine, а не создаёт параллельный publish flow.
2. UI не считает schedule, totals, readiness и optimization. Эта логика живёт
   в domain/application.
3. Runtime работает с typed entities; raw `sectionData` существует только на
   data boundary через versioned mapper.
4. Все catalog relations идут по immutable id/type. Название, категория или
   координата не заменяют identity.
5. Catalog data читаются через repositories/datasources; UI/domain не знают
   про Firestore или конкретного logistics provider.
6. Scenario repository, source resolver, availability, exchange rates и
   logistics — разные зависимости.
7. Offline draft обязателен; подключение Firebase и live providers выполняется
   отдельными slices.
8. Market, locale, currency, timezone, limits и defaults приходят из config.
9. Route geometry принадлежит Route. Scenario хранит только Route reference и
   публичный snapshot stats.
10. AI/LLM generation не входит в MVP и включается только отдельными
    post-stabilization slices по `SCENARIO_AI_GENERATION_SPEC.md`;
    deterministic seed/optimizer не выдаются за AI-рекомендацию.
11. Features не импортируют друг друга напрямую. Create-owned port выбора
    каталоговых объектов объявляется в Create domain; app composition adapter
    связывает его с публичным Discover facade и переводит модели на границе.
12. Общие primitives/value objects не дублируются по features, но эта
    спецификация не меняет frozen project tree: размещение следует Accepted
    ADR 0011 и `ARCHITECTURE_BASELINE.md`. Новый `core/domain` требует нового
    Accepted ADR и не может появиться решением feature spec.
13. Delivery capabilities независимы: отключение public sharing не отключает
    multi-day, а отключение optimizer не меняет возможность ручного
    редактирования. UI, validator и mapper читают один versioned config.

---

## 3. Пользовательская ценность и основные случаи

### Продуктовое обещание

Scenario превращает набор идей в **выполнимый план**, который за один экран
отвечает на пять вопросов: что делать, когда начать, что будет дальше, сколько
займёт дорога и во сколько обойдётся день или поездка.

North-star outcome: пользователь не просто сохраняет места, а начинает план и
доходит по нему до следующей остановки без необходимости пересобирать детали в
заметках, картах и нескольких приложениях.

### Jobs to be done

1. Когда у меня есть свободные часы, быстро собрать реалистичный порядок мест
   с учётом времени работы и дороги.
2. Когда я планирую выходные или поездку, разложить идеи по дням, увидеть
   конфликты, пробелы и примерный бюджет.
3. Когда мне понравился чужой план, безопасно скопировать его и адаптировать
   под свои даты, состав группы и ограничения.
4. Когда план уже начался, понимать текущую и следующую остановку и получать
   предложение, как восстановиться после задержки.
5. Когда я создаю публичную рекомендацию, опубликовать воспроизводимый шаблон,
   не раскрывая личные данные и не обещая неактуальные цены или доступность.

### Принципы продукта

1. **Preview before complexity.** Готовый seed сначала показывается как план;
   форма открывается только по `Edit` или при обязательном выборе.
2. **Полезный результат за 30 секунд.** Для city/day достаточно контекста,
   2–3 объектов и одного действия Save; расширенные поля не блокируют старт.
3. **Неизвестное не равно нулю.** Неизвестные время, цена и дорога видимы и не
   маскируются ложной точностью.
4. **Намерение пользователя сильнее оптимизации.** Fixed/locked порядок,
   выбранные alternatives и ручные legs не переписываются автоматически.
5. **Точное отделено от оценочного.** Provider data, авторская оценка и ручной
   ввод имеют source, freshness и confidence.
6. **Личное отделено от публичного.** Заметки, участники, бронирования,
   completion и точные private locations не попадают в public definition.
7. **Деградация без потери данных.** Сбой сети или provider уменьшает точность,
   но не удаляет и не переставляет пользовательский план.
8. **Одна сущность — одна терминология.** Пользователь сохраняет Scenario;
   Quick Plan означает только лёгкий отдельный план, Route — только
   непрерывный трек.
9. **AI предлагает, domain решает.** AI output является transient proposal;
   IDs, schedule/readiness и materialization проверяются детерминированно до
   явного применения.

### Три уровня опыта

| Уровень | Цель | Что видит пользователь | Результат |
|---|---|---|---|
| Instant | получить основу за секунды | preview, краткий контекст, `Save` / `Edit` | transient Scenario seed |
| Edit | адаптировать под себя | дни, timeline, карта, логистика, бюджет | personal Scenario |
| Publish | поделиться воспроизводимым планом | Create Hub sections, review, privacy, moderation | public Scenario template |

Все уровни используют одну typed модель и один mapper. Instant не является
облегчённой второй сущностью, а Publish не является отдельным редактором.

### Варианты создания Scenario

| Вариант | Источник | Результат до Save |
|---|---|---|
| Manual | пустой builder/context | редактируемый personal draft |
| Selected objects | Search/Map/Details object IDs | typed seed/preview |
| Quick Plan Expand | выбранные stops + conversion snapshot | новый независимый Scenario draft |
| Public template | immutable public definition | новая personal copy |
| AI generation | prompt + typed context + read-only tools | transient verified proposal/seed |

AI generation не создаёт новый Create type, repository или lifecycle. При
отключённом AI остальные варианты полностью работоспособны.

### 3.1 City leisure

План на несколько часов в одном городе: кафе, выставка, прогулка, бар,
концерт. Главный риск — время работы, пересечения и длинные переходы.

### 3.2 Day plan

План на полный день: последовательность активностей, перерывы, бюджет,
фиксированные события и гибкие места.

### 3.3 Weekend

Два или три дня с разными районами, вариантами на утро/день/вечер и
возможностью переносить элементы между днями.

### 3.4 Trip

Многодневная поездка по одному или нескольким городам. Содержит проживание,
междугороднюю логистику, события, места, активности и отдельные Route.

### 3.5 Reusable public scenario

Creator публикует готовый сценарий. User открывает его, просматривает,
сохраняет копию и адаптирует под свои даты, бюджет и состав группы.

### 3.6 Контрольный пример

`Weekend in Riga and Sigulda`:

- Day 1 / Riga: hotel stay → Old Town Place → dinner Place → Event;
- Day 2: train Riga–Sigulda как plannedTransport item → опубликованный hiking
  Route как один item → dinner → hotel stay;
- Day 3: breakfast → museum, с rainy-day Place как alternative → train back;
- walking/transit между городскими objects — ScenarioLeg;
- билеты, confirmation codes и фактические расходы — personal state;
- Route polyline/POI остаются внутри Route;
- activity, local travel, planned transport, stays и budget считаются
  раздельно.

Если модель или UI не могут выразить этот пример без специальных полей в
presentation, спецификация считается неполной.

### 3.7 Канонические пользовательские пути

**Мгновенный вечер:** Search → `Quick plan for tonight` → Quick Plan preview →
Save/invite. Этот путь не создаёт Scenario без `Expand to Scenario`.

**Ручной городской Scenario:** объект в Search/Map/Details → `Add to scenario`
→ новый или существующий Scenario → reorder → resolve conflicts → Save.

**Выходные/поездка:** Create Hub → Scenario → контекст и даты → дни → items
и alternatives → logistics → review → private Save или Publish.

**Копия публичного плана:** Details → `Use this scenario` → выбор дат → immutable
personal copy с новым id → revalidation → Edit/Start.

**Прохождение:** My scenarios → Start → current/next item → Done/Skip → при
задержке предложение replan → явное Apply.

### 3.8 Канонический язык интерфейса

- продуктовый тип: **Scenario** / `scenario`;
- пользовательский объект: **Scenario** / локализованное «Сценарий»;
- действие создания: **Create scenario**;
- редактор: **Scenario Builder**;
- копирование: **Use this scenario**;
- начало прохождения: **Start scenario**;
- отдельный быстрый продукт: **Quick Plan** / «Быстрый план»;
- расширение: **Expand to Scenario**;
- запрещённые формулировки: `Scenario Route`, `Route Scenario`, «маршрут» для
  порядка независимых мест.

Тексты локализуются через будущий en/ru/lv slice; строки из этого документа не
должны хардкодиться в presentation.

---

## 4. Форматы Scenario

```dart
enum ScenarioFormat {
  city,       // несколько часов в одном городе
  day,        // один календарный день
  weekend,    // 2–3 дня
  trip,       // многодневная поездка
}
```

Формат влияет на стартовые значения и UI, но не создаёт четыре разные
доменные модели.

Предлагаемые ограничения:

| Формат | Длительность | Дни | География |
|---|---:|---:|---|
| city | 1–12 часов | 1 | один город/район |
| day | до 24 часов | 1 | город или ближайший регион |
| weekend | 2–3 дня | 2–3 | один или несколько городов |
| trip | 2–30 дней | 2–30 | один или несколько регионов/часовых поясов |

Ограничения должны находиться в конфигурации типа, а не дублироваться в UI,
контроллере и валидаторе.

**MVP-B limit:** 30 дней, 250 items всего, из них не более 200
active и 50 unscheduled; максимум 20 alternative groups и 5 вариантов в одной
group. Limits версионируются в `ScenarioTypeConfig` и проверяются до тяжёлых
расчётов.

### Даты: Template и Dated plan

```dart
enum ScenarioDateMode { template, dated }
```

- `template` хранит номера дней и локальное рекомендуемое время, но не
  притворяется, что знает актуальные opening hours и availability;
- `dated` хранит конкретные даты, UTC instants и IANA timezone каждого дня/
  элемента;
- публичный Scenario по умолчанию является template;
- Scenario с конкретным Event, билетом или отправлением становится dated;
- `Use this scenario` создаёт личную копию и, при необходимости, просит даты,
  после чего повторно проверяет расписание, цены и доступность.

Переход template → dated создаёт даты/UTC instants только после выбора start
date и повторной проверки. Обратный переход dated → template не стирает даты
молча: calendar-bound Event/booking/transport нужно удалить, заменить generic
alternative либо оставить Scenario dated.

---

## 5. Владение, видимость и результат

Scenario поддерживает два разных результата.

### Личный Scenario

- доступен обычному User;
- сохраняется в личные планы;
- по умолчанию private;
- может быть доступен по unlisted-ссылке владельца;
- не появляется в общей Discover-выдаче;
- личные заметки, booking и completion хранятся в отдельном personal state.

### Публичный Scenario

- публикуется Creator от имени User или ManagedPage;
- проходит общий publish/moderation flow;
- появляется в Discover как самостоятельный объект;
- не раскрывает личные заметки, участников и приватные booking details;
- может быть скопирован пользователем в личный план.

```dart
enum ScenarioVisibility { private, unlisted, public }
enum ScenarioStatus {
  draft,
  pendingReview,
  published,
  archived,
  hidden,
  deleted,
}
```

Lifecycle соответствует Accepted ADR 0013. `ready` — вычисляемый readiness,
а не persisted lifecycle status. Удаление soft-delete с retention 30 дней;
`hidden` устанавливает moderation/system.

Для dated Scenario отдельно вычисляется `ScenarioTemporalState`:
`upcoming | inProgress | past`. Это не lifecycle status. Past Scenario не
показывается в активной выдаче, но остаётся доступным по Details/истории до
archive/delete согласно общим политикам.

### Owner, publisher и capabilities

- каждый Scenario имеет `{ownerType, ownerId}`;
- личный plan принадлежит User и не обязан иметь publisher;
- public Scenario имеет `publisher: {type: user | page, id}`;
- owner и publisher могут различаться при публикации от ManagedPage;
- `edit`, `share_unlisted`, `publish`, `archive`, `delete` проверяются
  отдельными capabilities и теми же guards для UI, deep links и push;
- User может создавать личный Scenario; Creator capability требуется только
  для публикации в Discover.

В MVP-C авторизованный User может создать unlisted-ссылку на собственный
Scenario, если включена capability и доступен production backend contract.
Это не публикация в Discover, но действие получает rate limit, revoke и report
flow. На local mock внешняя ссылка выключена согласно §21.

---

## 6. Каноническая модель данных

Канонический тип: `CreateObjectType.scenario` с persisted taxonomy id
`scenario`. Он занимает planning-slot целевой десятки Create Hub вместо
текущего legacy `CreateObjectType.quickPlan`. Quick Plan остаётся отдельным
personal/invited aggregate вне Create taxonomy и каталога.
`CreateObjectType.route` остаётся независимым типом и aggregate.

Общие value objects не переопределяются внутри feature:

```dart
class Money {
  int minorUnits;             // без double-округления
  String currencyCode;        // ISO 4217
}

class OwnerRef { OwnerType type; String id; }
class PublisherRef { PublisherType type; String id; }
```

`GeoPoint`, `LocalDate`, `LocalTime`, Owner/Publisher enums и media ids берутся
из общих contracts. Money никогда не хранится в `double`; coordinates,
currency code и date/time value objects валидируются на data boundary.

Физическое размещение не определяется догадкой feature-команды:

- app-local переиспользуемые primitives следуют baseline
  `apps/mobile/lib/shared/primitives/`;
- DTO/API contracts принадлежат `packages/api_contracts`;
- `core` остаётся инфраструктурным и не получает product/domain workflows;
- feature-specific тип остаётся внутри своего domain, пока реальное повторное
  использование не доказано импортами и approved file plan.

SB-00 сначала инвентаризирует существующие определения и consumers через
`rg`; перенос или удаление допускается только для реально существующих файлов
и не должен создавать новый architecture root без Accepted ADR.

### 6.1 ScenarioDraft и ScenarioData

```dart
class ScenarioDraft {
  String id;
  int schemaVersion;
  int revision;

  OwnerRef owner;
  PublisherRef? publisher;
  ScenarioStatus status;
  ScenarioVisibility visibility;

  String title;
  String description;
  String? coverMediaId;

  String primaryCategoryId;
  List<String> secondaryCategoryIds;
  List<String> criteriaIds;

  String primaryMarketId;
  List<String> regionIds;

  ScenarioData data;
  ScenarioOrigin? origin;
  DateTime createdAtUtc;
  DateTime updatedAtUtc;
}

class ScenarioData {
  int scenarioSchemaVersion;
  ScenarioFormat format;
  ScenarioDateMode dateMode;
  String defaultTimezoneId;
  String displayCurrencyCode;

  ScenarioParty party;
  ScenarioConstraints constraints;

  List<ScenarioDay> days;
  List<ScenarioLocation> locations;
  List<ScenarioItem> items;
  List<String> unscheduledItemIds;
  List<ScenarioLeg> legs;

  ScenarioTotals totals;             // derived cache
}
```

Все persisted timestamps — UTC; локальная интерпретация всегда хранит IANA
timezone. `defaultTimezoneId` — только начальное значение. Многогородный
Scenario не предполагает один timezone на всю поездку.

`totals` и provider-backed часть `legs` являются вычисляемым кэшем. Источник
истины — дни, items, пользовательский порядок, locks, manual legs и overrides.
`origin` фиксирует `{sourceType, sourceId, sourceRevision}` для provenance, но
не создаёт живую зависимость от дальнейших изменений оригинала. Для
`publicScenario` sourceId — Scenario id; для `quickPlanConversion` — Quick Plan
id.

`ScenarioDraft.schemaVersion` версионирует aggregate/envelope, а
`ScenarioData.scenarioSchemaVersion` — специализированный payload; миграции
обоих уровней выполняются явно и покрываются round-trip fixtures.

`ScenarioOrigin` хранит origin type (`publicScenario`, `quickPlanConversion`,
`collection`, `search`, `smartSearch`, `mapSelection`, `manual`) и optional
source object/revision id. Raw search prompt не является identity и не попадает
в analytics. Диапазон дат не
хранится вторым источником истины: он выводится из ordered days; seed range
только создаёт days.

`ScenarioDraft` выше — логический aggregate, который видит application layer;
`ScenarioData` — его typed композиционное содержимое, а не самостоятельная
сущность и не отдельный repository root.
В public Create flow общие identity/owner/publisher/media/lifecycle поля
принадлежат общему Create envelope, а специализированные поля сериализует
`ScenarioDraftDataMapper` в `sectionData['scenario']`. Дублировать эти поля
в raw section запрещено. Personal repository собирает тот же typed aggregate
без передачи raw map в UI/domain.

Public taxonomy относится ко всему Scenario, а не копируется механически из
первого item. Система может предложить primary/secondary categories по active
items, но автор подтверждает их перед Publish. Criteria берутся только из
versioned Category System; свободные системные id не вводятся текстом.

Для Discover/Map вычисляется `ScenarioGeoSummary`: primary location, centroid,
bounds и region ids active географических items. Это derived cache. Geo-ranking
использует primary location/market, а не случайный центр большого multi-city
trip. Автор может выбрать primary location; fallback — Location первого active
public item. Centroid никогда не используется как скрытая замена primary.
Public geo summary строится только по disclosure-safe mapped locations;
personal map может использовать точные private locations владельца.

### 6.2 ScenarioDay

```dart
class ScenarioDay {
  String id;
  String title;
  int dayIndex;
  String? timezoneId;
  LocalDate? localDate;

  String? startLocationId;
  String? endLocationId;
  LocalTime? preferredStartTime;
  LocalTime? preferredEndTime;

  List<String> itemIds;
}
```

`itemIds` определяет визуальный порядок. Элемент дополнительно хранит `dayId`
для эффективных запросов, но изменение выполняется одной атомарной операцией.
`dayIndex` образует непрерывную последовательность `0..N−1` и является
каноническим порядком; days никогда не сортируются только по `localDate`, что
важно при смене timezone/линии дат.
В template `localDate=null`; в dated plan дата обязательна. Элемент относится
к дню своего локального начала и может завершиться после полуночи. Ночной
переезд или проживание не разрезается на искусственные дубликаты. UI может
показывать derived continuation в следующих днях, но item id остаётся один и
присутствует только в `itemIds` дня начала.

### 6.3 ScenarioItem

```dart
class ScenarioItem {
  String id;
  String? dayId;

  String? startLocationId;
  String? endLocationId;

  ScenarioItemKind kind;
  ScenarioItemSource source;
  ScenarioSourceStatus sourceStatus;
  ScenarioSchedule schedule;
  int? durationMinutes;
  ScenarioCost cost;

  bool orderLocked;
  bool timeLocked;
  ScenarioItemRole role;
  String? alternativeGroupId;
  bool selected;

  String publicNote;
}

enum ScenarioItemKind {
  visit,
  event,
  activity,
  route,
  bookableSession,
  stay,
  plannedTransport,
  timeBlock,
}

enum ScenarioItemRole { mandatory, optional, alternative }
enum ScenarioSourceStatus { ready, stale, unresolved, unavailable }
```

Persisted enum ids задаёт явный mapper (`bookable_session`,
`planned_transport` и т.д.), а не `enum.name`. Unknown ids проходят versioned
migration/fallback и не роняют весь draft.

Каждое появление объекта в плане получает собственный `ScenarioItem.id`.
Один и тот же Place может быть добавлен дважды, например отель утром и
вечером. Это не две копии Place, а два элемента Scenario с одной ссылкой.

- `stay` может иметь интервал check-in/check-out через несколько дней;
- `plannedTransport` — поезд, перелёт, паром или заказанный трансфер с
  собственным временем, ценой и reservation в personal overlay;
- `timeBlock` — отдых, свободное время, самостоятельный приём пищи или buffer,
  которому не обязательно иметь Location;
- `alternative` входит в расписание и totals только когда `selected=true`;
- в одной alternative group выбран максимум один item;
- mandatory item нельзя удалить/заменить оптимизатором.

Active-item predicate:

```text
mandatory    → selected всегда true
optional     → active, только если selected=true
alternative  → active, только если selected=true и это единственный выбор group
unscheduled  → не входит в schedule/totals независимо от selected
```

`durationMinutes` обязателен для visit/event/activity/route/bookableSession/
timeBlock. Для stay и plannedTransport длительность вычисляется из schedule;
ручной override хранится отдельно и не уничтожает исходный interval.

Канонический порядок items задаёт только `ScenarioDay.itemIds`; порядок days —
`dayIndex`. Отдельные `order` в Day/Item/Leg не хранятся, чтобы две версии
порядка не могли разойтись. `dayId` на item — денормализованный индекс и обязан
атомарно совпадать с членством в `itemIds`.

### 6.4 Источник элемента

```dart
sealed class ScenarioItemSource {}

class CatalogObjectSource extends ScenarioItemSource {
  String objectId;
  ScenarioCatalogObjectType objectType;
  ScenarioObjectSnapshot snapshot;
}

enum ScenarioCatalogObjectType {
  event,
  place,
  activity,
  route,
  bookableSession,
}

class CustomLocationSource extends ScenarioItemSource {
  String locationId;
}

class PlannedTransportSource extends ScenarioItemSource {
  String? carrierName;
  String? publicServiceLabel;
}

class TimeBlockSource extends ScenarioItemSource {
  String title;
  String? categoryId;
}

class ScenarioLocation {
  String id;
  GeoPoint point;
  String title;
  String? address;
  String? marketId;
  String? regionId;
  String? timezoneId;
  ScenarioLocationDisclosure disclosure;
  String? sourceObjectId;
  ScenarioCatalogObjectType? sourceObjectType;
}

enum ScenarioLocationDisclosure { private, approximate, public }
```

Правила:

- связь с каталогом — только `{objectType, objectId}`;
- snapshot нужен для стабильного preview и офлайн-чтения, но не является
  источником истины;
- устаревший snapshot обновляется явно;
- `loc_*` допустим только в несохранённом локальном черновике;
- до синхронизации/публикации custom location получает постоянный ULID;
- catalog source для Share/Publish ссылается на persistent доступный объект,
  не на чужой или незавершённый Create draft;
- удалённый каталоговый объект не удаляется из Scenario молча: элемент
  получает `sourceStatus=unavailable` и требует замены или удаления.

`ScenarioLocation.id` идентифицирует location snapshot внутри Scenario;
пара `{sourceObjectType, sourceObjectId}` связывает его с каталогом, если
источник существует.
Coordinates валидируются на finite/range. Изменение title/address не меняет id.
`sourceObjectType` и `sourceObjectId` либо оба заполнены, либо оба `null`.
Timezone location может быть не разрешён в незавершённом draft; dated
schedule/Publish/Start требуют его разрешить. Schedule timezone по умолчанию
берётся из соответствующей Location и при расхождении создаёт issue вместо
молчаливой подмены.

- `private` доступна только владельцу и personal execution;
- `approximate` публикует безопасную area/rounded point, не точный address;
- `public` допускает точную публичную точку;
- catalog Place/Event/Route endpoints наследуют публичность источника, но
  пользователь не может повысить disclosure закрытой/private source Location.

Kind и source валидируются совместно:

| Item kind | Допустимый source |
|---|---|
| visit | Place или CustomLocation |
| event | Event |
| activity | Activity или CustomLocation |
| route | Route |
| bookableSession | Bookable Session |
| stay | lodging Place/Session или CustomLocation |
| plannedTransport | PlannedTransportSource |
| timeBlock | TimeBlockSource |

Location registry является единственным источником координат/адреса/timezone
внутри aggregate:

- Day и Item ссылаются только по location id;
- visit обычно имеет одинаковые start/end ids;
- Route и plannedTransport могут иметь разные start/end ids;
- timeBlock может не иметь Location;
- CustomLocationSource указывает на entry в registry;
- для CustomLocationSource его `locationId` совпадает с item start/end id,
  если оба конца находятся в одной точке;
- удаление Location блокируется, пока на неё ссылается Day/Item;
- refresh shared Location атомарно обновляет все использующие её items;
- leg строится от `previous.endLocationId` к `next.startLocationId`, а на
  границе дня — от/к соответствующему Day location id.

Snapshot разделяется на:

- presentation snapshot: title, cover, publisher, source-location version;
- operational snapshot: opening hours/version, price/version, availability;
- live check result: актуальная проверка для конкретной даты.

Presentation snapshot обеспечивает стабильное чтение. Operational данные не
считаются актуальными после TTL и перед Start/Publish проверяются заново.

Для Route-item duration, distance и публичные stats читаются из versioned
operational snapshot:

- `ready` — значения учитываются с исходным knowledge/source;
- `stale` — last-known значения сохраняются в totals как `estimated`, получают
  warning с `checkedAtUtc` и обновляются только явным refresh;
- `unavailable` — last-known snapshot остаётся видимым для истории и может
  участвовать только в estimated preview, но mandatory item блокирует
  Publish/Start до Replace/Remove;
- если snapshot отсутствует, повреждён или признан небезопасным, duration и
  distance становятся `unknown`, а не нулём.

Смена source status не переписывает пользовательский порядок, manual
duration override или вложенную Route entity. Last-known данные всегда
помечены source/freshness и не выдаются за актуальную доступность.

Material source changes: cancellation/deletion, address change, start/end
change, loss of availability, significant price change и Route becoming
unavailable. Они создают issue и diff, но никогда не переписывают пользовательскую
копию молча. Cosmetic title/cover changes могут обновить presentation snapshot
после refresh без перестройки schedule.

Material warning дедуплицируется по `{scenarioId, itemId, sourceRevision,
changeCode}`. In-app warning показывается при открытии; push разрешён только для
time-bound/confirmed items согласно consent/settings и не содержит private
itinerary data.

### 6.5 Денежная оценка

```dart
enum PriceKnowledge { free, known, estimated, unknown }
enum PriceSource { catalog, userOverride, provider, manual }
enum PriceBasis {
  perPerson,
  perAdult,
  perChild,
  perGroup,
  perNight,
  perBooking,
}

class ScenarioCost {
  List<MoneyEstimate> components;
}

class MoneyEstimate {
  String componentCode;
  PriceKnowledge knowledge;
  Money? amount;
  PriceBasis? basis;
  PriceSource source;
  DateTime? observedAtUtc;
  double? confidence;
}
```

`unknown` не содержит amount; `free` означает подтверждённый ноль. Estimated
price всегда визуально отличается от known. Price override пользователя не
перезаписывает catalog snapshot и может быть сброшен.

Инварианты: free имеет amount=0; known/estimated имеют неотрицательный amount;
unknown имеет amount=null; confidence допустим только для estimated. Negative
price и неизвестный ISO currency code отклоняются на data boundary.

`ScenarioCost` содержит несколько непересекающихся components, поэтому один
item может одновременно иметь adult и child price. Пустой список означает
«стоимость не применима»; неизвестная стоимость представляется явным
`unknown` component, а не пустым списком.

Внутри одного `componentCode` взаимоисключающие audience bases (adult/child)
разрешены, а пересекающиеся (`perPerson` вместе с `perAdult`) запрещены. Fees с
другим code, например `admission` и `service_fee`, суммируются независимо.

### 6.6 Расписание и часовые пояса

```dart
enum ScenarioTimeMode { fixed, window, flexible }

class ScenarioSchedule {
  ScenarioTimeMode mode;
  ScenarioPlannedTime planned;
  ScenarioCalculatedTime? calculated;
}

sealed class ScenarioPlannedTime {}

class TemplatePlannedTime extends ScenarioPlannedTime {
  int startDayIndex;
  LocalTime? preferredStart;
  LocalTime? windowStart;
  LocalTime? windowEnd;
  int windowEndDayOffset;       // 0 или 1
  int? endDayIndex;
  LocalTime? preferredEnd;
  String? startTimezoneId;
  String? endTimezoneId;
}

class DatedPlannedTime extends ScenarioPlannedTime {
  DateTime? fixedStartAtUtc;
  DateTime? fixedEndAtUtc;
  LocalTime? windowStart;
  LocalTime? windowEnd;
  int windowEndDayOffset;       // 0 или 1
  String? startTimezoneId;
  String? endTimezoneId;
}

sealed class ScenarioCalculatedTime {}

class TemplateCalculatedTime extends ScenarioCalculatedTime {
  int startDayIndex;
  LocalTime start;
  int endDayIndex;
  LocalTime end;
}

class DatedCalculatedTime extends ScenarioCalculatedTime {
  DateTime startAtUtc;
  DateTime endAtUtc;
}
```

- `fixed` — билет, бронь, концерт, отправление;
- `window` — пользователь хочет посетить в определённом диапазоне;
- `flexible` — время выбирает порядок/оптимизатор;
- dated plan использует UTC instants + IANA timezone;
- template использует day index + local time без ложного UTC timestamp;
- calculated values не перезаписывают намерение пользователя;
- dated plannedTransport хранит departure/arrival как UTC instants; начало
  отображается в departure timezone, конец — в arrival timezone; template
  plannedTransport хранит относительные day/local-time значения;
- ambiguous/nonexistent local time при DST требует явного offset resolution.

Инварианты:

- `dateMode=template` допускает только Template planned/calculated time;
- `dateMode=dated` допускает только Dated planned/calculated time;
- fixed dated item имеет `fixedStartAtUtc`; end берётся из fixed end либо
  duration;
- window требует start/end; при offset 0 выполняется `start < end`, offset 1
  задаёт ночное окно до следующего локального дня;
- stay/plannedTransport могут иметь разные start/end day/timezone;
- calculated time является derived cache и полностью пересоздаётся при
  изменении последовательности, duration, leg или date mode.

### 6.7 ScenarioLeg

```dart
class ScenarioLeg {
  String id;
  String dayId;
  String? fromItemId;
  String? toItemId;
  String fromLocationId;
  String toLocationId;

  ScenarioTravelMode mode;
  ScenarioLegSource source;
  ScenarioLegStatus status;

  double? distanceM;
  int? durationMinutes;
  ScenarioCost cost;
  List<GeoPoint> displayPolyline;
  String? providerCode;
  String? warningCode;
}

enum ScenarioTravelMode {
  walking,
  bicycle,
  car,
  taxi,
  transit,
  other,
}

enum ScenarioLegSource { provider, manual, estimate, unknown }
enum ScenarioLegStatus { ready, loading, stale, failed, unavailable }
```

Leg существует между соседними items или между границей дня и первым/последним
item, когда необходимо перемещение. Он описывает вспомогательную логистику и
обычно вычисляется.

- `fromItemId=null` означает переход от `ScenarioDay.startLocationId`;
- `toItemId=null` означает переход к `ScenarioDay.endLocationId`;
- `fromLocationId/toLocationId` обязательны и существуют в registry;
- spanning stay/transport может быть endpoint следующего дня, даже если item
  канонически принадлежит дню своего начала;
- оба item ids одновременно `null` запрещены.

Транспорт с собственным расписанием, билетом или значимой длительностью
(поезд, flight, ferry, междугородний автобус) моделируется как
`plannedTransport` item, а не derived leg. Иначе он исчезал бы при reorder и
не мог бы иметь booking, fixed time и приватный confirmation code.

Leg отсутствует, если один item логически продолжается в той же Location или
у одного из items нет географической точки. В последнем случае readiness
создаёт issue, а не подставляет нулевой переход.

### 6.8 Ограничения

```dart
class ScenarioConstraints {
  Money? totalBudgetLimit;
  BudgetBasis budgetBasis;
  Set<ScenarioTravelMode> allowedTravelModes;
  int? maxWalkingMinutesPerLeg;
  int? maxTravelMinutesPerDay;
  ScenarioPace pace;
  Set<String> interestCategoryIds;
  Set<String> accessibilityRequirementIds;
  bool freeExperienceItemsOnly;
}

enum BudgetBasis { wholeGroup, perPerson }
enum ScenarioPace { relaxed, balanced, intensive }

class ScenarioParty {
  int peopleCount;
  PartyKind kind;
  int? childrenCount;
}
```

Чувствительные данные участников в публичный объект не попадают. Публичный
Scenario хранит только рекомендуемый размер/тип группы.

`childrenCount` находится в диапазоне `0..peopleCount`. Party limits и
допустимые `PartyKind` задаются config. Budget limit хранится в display
currency; сравнение с исходными ценами возможно только через тот же versioned
exchange-rate snapshot, который используется totals. `perPerson` budget limit
нормализуется в whole-group limit умножением на peopleCount только для
сравнения; введённое пользователем значение сохраняется без изменения.

### 6.9 Личное состояние

Публичное содержание и личное исполнение физически разделены:

```dart
class ScenarioPersonalState {
  String scenarioId;
  String userId;
  int revision;
  int scenarioRevision;

  Map<String, String> privateNotesByItemId;
  Map<String, ScenarioReservationOverlay> reservationsByItemId;
  Map<String, CompletionState> completionByItemId;
  Map<String, Money> actualCostsByItemId;
  Map<String, Money> actualTravelCostsByLegId;
  Set<String> hiddenOptionalItemIds;
}
```

Reservation states следуют ADR 0013: `pending`, `confirmed`, `cancelled`,
`expired`, `waitlisted`. Отсутствие бронирования — отсутствие reservation,
а не выдуманный backend status. Confirmation codes, имена участников и
фактические расходы никогда не входят в public Scenario mapper.

`ScenarioReservationOverlay` хранит state, optional external provider ref,
confirmation code и timestamps. Если item исчез из новой revision, связанный
overlay не удаляется молча: он становится orphaned и показывается владельцу
для переноса или безопасного удаления.

### 6.10 Итоги

```dart
class ScenarioTotals {
  int activityMinutes;
  int plannedBlockMinutes;
  int localTravelMinutes;
  int plannedTransportMinutes;
  int implicitWaitingMinutes;
  int stayNights;
  List<ScenarioDayTotals> dayTotals;

  Money? displayIncludedExperienceCost;
  Money? displayIncludedStayCost;
  Money? displayIncludedLocalTravelCost;
  Money? displayIncludedPlannedTransportCost;
  Money? displayFromTotalCost;
  List<ScenarioCurrencySubtotal> originalCurrencySubtotals;
  String? exchangeRateSnapshotId;
  int estimatedCostCount;
  int unknownCostCount;

  double knownLocalTravelDistanceM;
  double knownEmbeddedRouteDistanceM;
  int activeItemCount;
  int dayCount;
  int unresolvedLegCount;
  int warningCount;
}

class ScenarioDayTotals {
  String dayId;
  int activityMinutes;
  int plannedBlockMinutes;
  int localTravelMinutes;
  int plannedTransportMinutes;
  int implicitWaitingMinutes;
  int? elapsedMinutes;
  int unresolvedValueCount;
}

class ScenarioCurrencySubtotal {
  String currencyCode;
  int knownMinorUnits;
  int estimatedMinorUnits;
}
```

Totals учитывают mandatory/optional items и только выбранную alternative в
каждой группе. Невыбранные варианты отображаются отдельно и не увеличивают
время, бюджет или расстояние.

Если неизвестный leg/duration разрывает timeline, `elapsedMinutes=null`:
частичные известные минуты остаются видимыми, но не выдаются за полный итог.

Неизвестная цена не считается нулём. UI показывает, например:
`от 74 EUR · цена 2 пунктов неизвестна`.

---

## 7. Источники входа

Scenario Builder может открываться из:

1. Create Hub → Scenario;
2. Profile / My scenarios → Continue draft;
3. Search/Smart Search → Build scenario;
4. Details → Add to scenario;
5. Map → Create scenario from selected places;
6. Favorites/Collection → Build scenario;
7. опубликованного Scenario → Use this scenario;
8. общей unlisted Scenario-ссылки → Save a copy;
9. Quick Plan → Expand to Scenario.

Вход в существующий план открывает `ScenarioDraft.id`. Preview Scenario может
оставаться transient до `Edit`/`Save`; тогда создаётся draft. Параметры URL не
должны быть постоянным хранилищем полного Scenario: они передают только seed,
после materialization builder работает по draft id.

Предлагаемый seed-контракт:

```dart
class ScenarioSeed {
  ScenarioFormat? format;
  ScenarioDateMode? dateMode;
  String? sourcePrompt;
  String? marketId;
  String? displayCurrencyCode;
  ScenarioSeedDateRange? dateRange;
  ScenarioParty? party;
  ScenarioConstraints? constraints;
  List<ScenarioSeedItem> items;
}

class ScenarioSeedDateRange {
  LocalDate startDate;
  LocalDate endDate;             // inclusive
}

class ScenarioSeedItem {
  ScenarioCatalogObjectType objectType;
  String objectId;
  int? dayIndex;
  ScenarioItemRole role;
}
```

Legacy query-параметры должны разбираться отдельным adapter и не проникать в
domain entities. Seed сохраняет catalog object ids, а не категории вместо
объектов. `sourcePrompt` может помочь предложить title/constraints во время
materialization, но не сохраняется как поле Scenario. Повторный поиск остаётся
ответственностью Search history; пользовательский текст попадает в Scenario
только после явного сохранения как title/description.

Materialization валидирует range, limits и refs, создаёт постоянные client ids
и возвращает typed issues для недоступных объектов. Частичная materialization
разрешена только с видимым unresolved list; неизвестные refs не пропускаются
молча. Один seed ограничен 50 items, чтобы deep link/intent не превращался в
скрытое хранилище aggregate. Seed date range разворачивается в contiguous
dayIndex в default timezone; последующая смена timezone дня не пересортировывает
days.

### Quick Plan → Scenario conversion

Conversion является отдельным application use case, а не открытием Quick Plan
в Scenario Builder:

```dart
class ExpandQuickPlanToScenarioRequest {
  String quickPlanId;
  int expectedQuickPlanRevision;
  Set<String> selectedStopIds;
  bool copyPrivateNotes;
}

class ExpandQuickPlanToScenarioResult {
  ScenarioDraft scenario;
  List<ScenarioIssue> issues;
  Map<String, String> quickPlanStopIdToScenarioItemId;
}
```

Инварианты conversion:

1. Создаётся новый `ScenarioDraft.id` — постоянный client-generated ULID.
2. Quick Plan остаётся неизменным; conversion не является rename/move.
3. Каталоговые stops копируются как новые Scenario items с теми же
   `{objectType, objectId}` и свежим snapshot resolution.
4. Порядок и локальная дата создают Day 1; multi-day/stay/transport не
   выдумываются автоматически.
5. Invite list, share token, chat, participant identities, completion и
   фактические расходы не копируются.
6. Private notes копируются только по отдельному consent и остаются personal
   state нового владельца; в public payload они не попадают.
7. Custom locations проходят disclosure review; private home location по
   умолчанию остаётся private и блокирует public Publish.
8. Origin хранит `{sourceType: quickPlanConversion, sourceId,
   sourceRevision}` только для provenance/audit; чтение оригинала для работы
   Scenario не требуется.
9. Missing/unavailable stop создаёт typed issue и остаётся unresolved только
   после явного подтверждения; нулевые duration/cost не подставляются.
10. Повторный Expand создаёт ещё один независимый Scenario, а не обновляет
    предыдущий.
11. Requester обязан иметь read + copy permission; владельцем нового Scenario
    становится requester, а не владелец Quick Plan.
12. `expectedQuickPlanRevision` защищает от незаметного изменения источника:
    mismatch показывает diff и требует Refresh/Continue with snapshot.
13. `copyPrivateNotes` относится только к заметкам requester; заметки владельца
    или других invited members никогда не раскрываются conversion use case.

Обратный автоматический conversion запрещён: Scenario может потерять дни,
stay, transport, alternatives и timezone semantics. Отдельный будущий
`Create Quick Plan from selected items` обязан создать новый Quick Plan и
показать потери до подтверждения.

---

## 8. Основной пользовательский поток

### Экран 0 — Preview-first для готового плана

Если вход содержит готовый seed, шаблон или публичный Scenario, сначала
показывается preview:

- название и обложка;
- дни или части дня;
- последовательность активных items и доступные alternatives;
- карта;
- activity/local travel/planned transport time;
- бюджет;
- предупреждения;
- действия `Use this scenario`, `Edit`, `Open map`, `Share`.

Новый пустой Scenario сразу открывает редактор.

### Шаг 1 — Basics

Поля:

- название;
- краткое описание;
- формат;
- обложка;
- основной market/регион;
- display currency и default timezone из конфигурации;
- личный или публичный результат.

При смене формата существующие дни и элементы не удаляются. Builder показывает
последствия и предлагает безопасное преобразование.

### Шаг 2 — Context

Поля:

- даты или режим «без точных дат»;
- города/регионы по дням;
- размер и тип группы;
- общий бюджет;
- допустимый транспорт;
- максимальная пешая/дневная логистика;
- темп: relaxed, balanced, intensive;
- интересы и accessibility requirements.

Отсутствие точных дат разрешено для шаблонного публичного Scenario. Для
личного запуска с проверкой opening hours нужны конкретные даты.

### Шаг 3 — Compose

Основной экран композиции:

- вкладки/секции дней;
- временная лента дня;
- блок `Unscheduled`;
- Add place/event/activity/route/session/stay/custom location;
- Add planned transport и time block;
- optional items и alternative groups;
- поиск и выбор на карте;
- drag-and-drop внутри дня и между днями;
- duplicate, remove, move, lock;
- длительность, стоимость, время и заметки элемента.

Добавленный объект попадает в текущий день после выбранного элемента. Если
день не выбран — в `Unscheduled`. Event сохраняет исходное время как fixed;
Place получает flexible/window; Route — duration из опубликованных stats;
planned transport — departure/arrival; stay может пересекать несколько дней.

### Mobile composer contract

- app bar: Back, title, autosave/sync state, Preview;
- day rail: дни, Add day и счётчик issues;
- timeline: item cards и компактные leg rows между ними;
- item card: local time, title, kind, duration, price knowledge, lock/issue;
- tap открывает edit sheet; drag handle меняет порядок;
- long press не является единственным способом важного действия;
- alternatives отображаются одной group card с выбранным вариантом;
- `Unscheduled` не смешивается с timeline и показывает причину readiness;
- sticky summary: active items, activity/travel time, `from` budget;
- один primary CTA на шаг; destructive action всегда требует явного контекста;
- loading одного leg не блокирует редактирование остальных дней;
- все controls имеют semantic labels и используют design-system tokens.

### Шаг 4 — Logistics

После устойчивого изменения порядка builder пересчитывает только затронутые
legs. Пользователь видит:

- способ перемещения;
- продолжительность;
- расстояние;
- стоимость, если известна;
- полилинию для городских перемещений;
- предупреждения о недоступной логистике;
- ручное редактирование и lock перехода.

Автоматический provider не заменяет ручной leg без подтверждения.

### Шаг 5 — Review

Review показывает:

- общий timeline;
- карту и список дней;
- раздельные итоги activity/local travel/planned transport/budget;
- выбранные и невыбранные alternatives;
- обязательные ошибки;
- предупреждения;
- неизвестные цены/переходы;
- booking checklist из personal state;
- публичные и приватные данные отдельно.

### Шаг 6 — Save / Share / Publish

- `Save draft` доступен всегда;
- `Save to my scenarios` создаёт личный Scenario;
- `Share` доступен только при capability `unlistedShare`; на local mock CTA
  скрыт или явно development-only;
- `Publish` доступен по capability и переводит draft в `pendingReview`;
- после публикации редактирование создаёт новую revision;
- изменение публичного оригинала не меняет пользовательские копии.

### Контракт выбора каталоговых объектов

Create feature владеет требованием к выбору, поэтому port объявляется в
`features/create/domain/repositories/`, а не в Discover и не в общем
presentation-коде:

```dart
abstract interface class CatalogObjectPickerPort {
  Future<CatalogPickOutcome> pick(CatalogPickRequest request);
}

class CatalogPickRequest {
  Set<ScenarioCatalogObjectType> allowedTypes;
  GeoPoint? nearPoint;
  String? marketId;
  int maxSelectedItems;
  Set<String> excludedObjectIds;
}

sealed class CatalogPickOutcome {}
class CatalogPickConfirmed extends CatalogPickOutcome {
  List<CatalogPickResult> items;
}
class CatalogPickCancelled extends CatalogPickOutcome {}

class CatalogPickResult {
  ScenarioCatalogObjectType objectType;
  String objectId;
  ScenarioObjectSnapshot snapshot;
}
```

Адаптер находится в app composition/DI: он может импортировать публичные
facades обоих features и переводит Discover result в Create contract. Ни
Create, ни Discover не импортируют внутренние domain/application/presentation
файлы друг друга. Builder получает только устойчивые `{objectType, objectId}`
и snapshot; transient search state, controller или widget через границу не
передаются.

Контракт различает Confirmed empty selection и Cancelled, ограничивает размер
выбора до открытия picker и повторно валидирует ids после возврата. Map,
Search и Favorites являются вариантами UI реализации, а не разными domain
методами.

---

## 9. Операции редактора

### Дни

- `Add day` вставляет день после выбранного и атомарно нормализует dayIndex;
- в template новый день не получает fake date;
- в dated plan предлагается следующая локальная дата/timezone, но пользователь
  подтверждает её;
- удаление пустого дня выполняется одной undo operation;
- для непустого дня обязательный выбор: Move items to Unscheduled / Delete
  items / Cancel;
- reorder template day обновляет dayIndex, template schedules и affected legs;
- reorder dated day не переписывает fixed UTC instants молча: builder сначала
  показывает date/time conflicts и предлагает Reassign dates или Cancel;
- spanning stay/transport не дублируется и может блокировать удаление/перенос
  затронутого дня до явного решения.

### Добавление

1. Пользователь выбирает catalog object, custom location, transport или block.
2. Для catalog object Search возвращает `{objectType, objectId}`.
3. Builder создаёт новый постоянный или локальный `ScenarioItem.id`.
4. Сохраняет source и versioned snapshot.
5. Назначает kind, schedule и duration из объекта или config default.
6. Валидирует date/timezone/currency без блокировки draft save.
7. Добавляет item в выбранную позицию или `Unscheduled`.
8. Пересчитывает только соседние legs, schedule и totals затронутых дней.
9. Запускает debounce autosave.

### Перестановка

Перестановка одного элемента меняет:

- `ScenarioDay.itemIds`;
- предыдущий leg старой позиции;
- следующий leg старой позиции;
- предыдущий leg новой позиции;
- следующий leg новой позиции;
- calculated times и totals затронутых дней.

Незатронутые дни не пересчитываются.

### Перенос между днями

- сохраняет `ScenarioItem.id`;
- меняет `dayId` и order;
- удаляет старые соседние legs;
- создаёт новые legs в обоих днях;
- очищает несовместимое fixed time только после подтверждения;
- переводит template time на новый day index;
- dated fixed item с несовместимой датой не переносится без выбора:
  `Keep date`, `Change date` или `Cancel`;
- сохраняет duration, cost, public note и связанный personal state.

### Удаление

- удаляет элемент из дня;
- соединяет его прежних соседей новым leg;
- не удаляет исходный каталоговый объект;
- поддерживает Undo;
- mandatory/locked item требует подтверждения.

### Duplicate

Создаёт новый `ScenarioItem.id` с той же source reference. Personal notes,
reservation и completion по умолчанию не копируются.

### Alternatives

- `Add alternative` создаёт/использует `alternativeGroupId`;
- все варианты group находятся в одном Day или все в Unscheduled и занимают
  непрерывный участок `itemIds` как один логический slot;
- в основной timeline активен ровно один вариант группы;
- выбор другого варианта атомарно меняет `selected`, legs, schedule и totals;
- drag group переносит все варианты; перенос одного варианта требует действия
  `Detach from alternatives`;
- ноль выбранных вариантов допустим в draft, но создаёт readiness issue;
- public template показывает варианты; личный Start требует выбранный вариант.

### Undo/Redo

Минимум 20 атомарных операций:

- add/remove;
- reorder/move day;
- update time/duration/cost;
- apply optimization proposal;
- add/remove day;
- replace source;
- bulk import из Collection/Map.

Асинхронный результат routing не создаёт отдельную пользовательскую undo
operation, но привязан к revision и игнорируется, если успел устареть.

---

## 10. Планирование времени

Расчёт выполняется последовательно внутри каждого дня только для active items.

1. Для dated plan локальная дата дня разрешается в его IANA timezone.
2. Берётся preferred start дня или первый fixed item.
3. Flexible item получает ближайший допустимый interval.
4. Между географически разными items добавляется duration leg.
5. До fixed item может появиться implicit waiting/buffer.
6. Если предыдущий item + leg позже fixed start — создаётся conflict.
7. Window item должен полностью помещаться в своё окно и opening interval.
8. Dated planned transport использует собственные departure/arrival UTC
   instants; template — относительные day/local-time значения.
9. Stay может пересечь midnight; следующий day начинает расчёт от check-out
   location/time или от явно заданного day start.
10. Template рассчитывает относительный timeline и не утверждает фактическую
    availability.

При переводе template в dated plan локальные времена разрешаются в UTC только
после выбора дат и timezone. DST gap/overlap требует явного выбора пользователя
и не исправляется прибавлением фиксированных 24 часов.

Hard conflict:

- два несовместимых fixed item;
- невозможно добраться до фиксированного события;
- объект закрыт на всём допустимом окне;
- дата события не совпадает с днём Scenario;
- planned transport прибывает после следующего fixed item;
- mandatory stay/transport пересекаются несовместимым образом;
- в alternative group выбрано более одного active item;
- бронирование/вместимость явно не подходят группе.

Warning:

- слишком плотный темп;
- неизвестные opening hours;
- длинный переход;
- нет запаса перед билетом/отправлением;
- часть дня выходит за preferred end;
- длительность или цена являются оценкой.

---

## 11. Логистика

### Контракт

```dart
abstract class ScenarioLogisticsService {
  Future<ScenarioLegResult> calculateLeg(ScenarioLegRequest request);
}

class ScenarioLegRequest {
  String requestId;
  String legId;
  String? fromItemId;
  String? toItemId;
  String fromLocationId;
  String toLocationId;
  GeoPoint from;
  GeoPoint to;
  ScenarioTravelMode mode;
  ScenarioDepartureContext departure;
  int draftRevision;
}

sealed class ScenarioDepartureContext {}

class DatedDeparture extends ScenarioDepartureContext {
  DateTime departureAtUtc;
  String timezoneId;
}

class TemplateDeparture extends ScenarioDepartureContext {
  int dayIndex;
  LocalTime? preferredLocalTime;
  String timezoneId;
}
```

Сервис возвращает distance, duration, `ScenarioCost`, display geometry,
provider attribution и типизированные warnings/failures. Template request не
может обещать актуальное transit schedule: provider возвращает estimate либо
`date_required`. Failure codes: `offline`, `timeout`, `quota`, `unauthorized`,
`noRoute`, `dateRequired`, `invalidResponse`, `cancelled`, `unknown`.

### Городские переходы

Walking/bicycle/car/taxi/transit рассчитываются между точками входа объектов.
Если точка входа отсутствует, используется основная координата объекта с
warning `approximate_access_point`.

### Плановый транспорт

Train/flight/ferry/междугородний автобус в MVP создаются как
`plannedTransport` item с departure/arrival, timezone обеих точек, стоимостью
и публичной заметкой. Reservation и confirmation code хранятся только в
personal state. Автоматический поиск билетов и расписаний требует отдельного
provider slice.

### Ошибка provider

- draft продолжает сохраняться;
- leg получает `failed` или `unavailable`;
- UI показывает Retry / Enter manually / Change mode;
- неизвестное время не считается нулём;
- Preview явно отмечает неполный итог;
- unresolved failed leg блокирует dated Publish/Start;
- explicit manual leg считается разрешением ошибки и может публиковаться с
  понятной public note;
- template допускает unknown leg только с явным публичным предупреждением.

### Конкурентность запросов

- debounce после reorder: 400 мс;
- максимум 2 активных logistics request на draft;
- request содержит revision и ids endpoints;
- ответ применяется, только если leg существует, revision/mode/endpoints
  совпадают и пользователь не зафиксировал manual override;
- timeout: 5 секунд; один retry с jitter только для timeout/5xx;
- поздний ответ игнорируется без toast;
- feature flag/kill switch отключает live provider без потери manual flow.

---

## 12. Расчёты

### Время

```text
activityMinutes         = visit + event + activity + route + bookableSession durations
plannedBlockMinutes     = сумма active timeBlock durations
localTravelMinutes      = сумма известных durations active legs
plannedTransportMinutes = сумма durations active plannedTransport items
implicitWaitingMinutes  = незапланированные gaps перед fixed/window items
stayNights              = число локальных ночей active stay items
dayElapsed              = последний active end − первый active start,
                          только если timeline разрешён полностью
```

Невыбранные alternatives, unscheduled items и ночной промежуток между днями
не входят в day elapsed. Activity + travel + waiting может отличаться от
elapsed из-за explicit buffers и stays. UI показывает метрики раздельно, а не
одно неоднозначное `Total time`.

### Бюджет

```text
experienceCost       = visit/event/activity/route/bookableSession/timeBlock costs
stayCost             = active stay costs с учётом числа ночей
localTravelCost      = active leg costs
plannedTransportCost = active plannedTransport item costs
displayFromTotalCost = сумма known + estimated компонентов после конвертации
```

Цена хранит:

- amount;
- currency;
- basis: perPerson, perAdult, perChild, perGroup, perNight, perBooking;
- source: catalog, userOverride, provider;
- confidence/updatedAt для оценки.

Quantity rules:

- `perPerson` × peopleCount;
- `perAdult` × `(peopleCount − childrenCount)`;
- `perChild` × childrenCount;
- `perGroup` и `perBooking` × 1;
- `perNight` × число локальных ночей stay;
- если источник уже вернул group/booking total, повторное умножение запрещено.

Каждый Money сохраняется в исходной валюте. Display total конвертируется по
versioned rate snapshot с timestamp; исходная сумма не перезаписывается.
Если хотя бы одна known/estimated сумма не конвертируется, соответствующий unified
display total равен `null`, а UI показывает original subtotals раздельно.
`from` означает сумму всех known/estimated и конвертируемых компонентов, рядом
обязательно показывается unknown count. Estimated components входят в `from`,
но помечаются отдельно; unknown не входит. `freeExperienceItemsOnly` допускает
только подтверждённый ноль для
visit/event/activity/route/bookableSession; stay, planned transport и local legs
учитываются отдельно. Unknown price не считается free.

### Расстояние

Отдельно суммируются local-leg distance и published distance вложенных Route.
Distance Route не прибавляется к логистике второй раз. Flight/train distance
может отображаться отдельно, но не смешивается с walking/car total.

---

## 13. Проверка качества Scenario

Вместо текущего термина `Route fit` используется `Scenario readiness`.

```dart
class ScenarioReadiness {
  double confidence;            // 0..1, полнота/свежесть исходных данных
  ReadinessLevel level;
  List<ScenarioIssue> blockers;
  List<ScenarioIssue> warnings;
  List<ScenarioIssue> suggestions;
}

enum ReadinessLevel { blocked, needsAttention, readyWithWarnings, ready }
```

Числовой score намеренно отсутствует: без принятой формулы он создаёт ложную
точность. Наличие blocker даёт `blocked`; warnings и confidence определяют
`needsAttention/readyWithWarnings/ready` детерминированными правилами action.

`confidence = weightedResolvedChecks / weightedApplicableChecks` с versioned weights
из config; blockers не повышают confidence и не маскируются высоким значением.

Каждый `ScenarioIssue` имеет стабильный code, severity, dayId/itemId/legId,
читаемое сообщение и optional fix action. Один и тот же дефект не дублируется
в нескольких панелях. Большое число unknown значений снижает confidence и не
выдаёт ложное `Ready`.

Предлагаемые группы проверки:

- completeness;
- schedule;
- logistics;
- budget;
- availability;
- booking;
- accessibility;
- publication/privacy.

Readiness рассчитывается отдельно для действий:

- `savePersonal`;
- `shareUnlisted`;
- `publishTemplate`;
- `publishDated`;
- `startScenario`.

Один Scenario может быть готов к личному сохранению, но не готов к Publish
или Start.

Пример UI:

```text
Ready with warnings
• 3 days · 11 places
• 8 h 20 min activities · 2 h 05 min travel
• from 186 EUR · 2 unknown prices
• 1 long transfer and 1 place with unknown opening hours
```

---

## 14. Оптимизация

Оптимизация не должна быть скрытой мутацией. Она формирует proposal с diff,
который пользователь применяет или отклоняет.

### Hard constraints

Оптимизатор не нарушает:

- fixed time;
- locked order/time/leg;
- mandatory item;
- даты событий и бронирований;
- доступные travel modes;
- accessibility requirements;
- opening hours, если они подтверждены.

### Soft constraints

В порядке предлагаемого приоритета:

1. минимизировать опоздания и schedule conflicts;
2. минимизировать лишнюю логистику;
3. соответствовать preferred day bounds;
4. удерживать бюджет;
5. соблюдать выбранный pace;
6. распределять категории без нежелательных повторов;
7. оставлять разумные перерывы.

### Допустимые действия

- переставить flexible items;
- перенести flexible item между днями;
- предложить другой travel mode;
- предложить удалить optional item;
- предложить альтернативу закрытому/дорогому объекту;
- выбрать другой уже добавленный alternative;
- добавить buffer перед fixed item.

### Запрещённые автоматические действия

- удалять mandatory item;
- менять билет/бронь;
- публиковать;
- создавать платную бронь;
- менять город или даты поездки;
- заменять объект без показа пользователю;
- раскрывать private notes.

**MVP-A:** ручная композиция. **MVP-B:** опциональная детерминированная
локальная оптимизация порядка за независимой capability. AI/LLM generation,
полноценные рекомендации и автоматическая сборка поездки не входят в MVP и
разрешаются только отдельными post-stabilization slices по
`SCENARIO_AI_GENERATION_SPEC.md`.

### Детерминированный MVP-алгоритм

1. Разбить день на интервалы между locked/fixed anchors.
2. Исключить невыбранные alternatives; hard incompatibility mandatory item
   завершает поиск blocker-результатом, optional item можно только предложить
   убрать или перенести.
3. Для каждого интервала выполнить feasible insertion flexible items с
   учётом travel time, windows и preferred end.
4. Выполнить ограниченный local swap/2-opt только внутри интервала.
5. Пересчитать legs и schedule proposal.
6. Сравнить до/после: conflicts, travel, elapsed, budget, removed/unscheduled.
7. Показать diff; применить одной undo operation только после подтверждения.

Одинаковый input/config/provider snapshot обязан давать одинаковый proposal.
Если ни один feasible plan не найден, исходный draft не меняется и UI
показывает конкретные blockers.

---

## 15. Валидация

### Save draft

Разрешён всегда, включая пустой и частично заполненный Scenario.

### Save to my scenarios

Минимум:

- постоянный draft id;
- название или автоматически предложенное локальное имя;
- хотя бы 2 active scheduled items;
- все элементы имеют постоянный item id;
- каталоговые ссылки имеют object id/type;
- все day/item location ids существуют в registry;
- display currency и timezone каждого датированного дня определены;
- структура дней непротиворечива.

Постоянные ids генерируются клиентом, поэтому offline Save to my scenarios не
зависит от ответа сервера. `loc_*` преобразуются одной id-mapping operation с
обновлением всех day/item/leg/personal-state references.

### Share unlisted

Дополнительно обязательно:

- `ScenarioCapabilities.unlistedShare=true` и production share backend ready;
- authenticated owner или отдельная capability управления этим Scenario;
- минимум 2 active scheduled items;
- share-view mapper успешно формирует целостный план;
- private locations/notes/reservations отсутствуют в payload;
- item с private Location заменён разрешённой approximate/public точкой или
  исключён пользователем без разрушения timeline;
- share token создан онлайн, имеет revoke и проходит rate limit/report policy.

### Publish

Дополнительно обязательно:

- Creator capability;
- publisher reference;
- title и public description;
- cover согласно общей media policy;
- минимум 2 публично доступных элемента;
- валидный format;
- публичные region/market;
- отсутствие временных `loc_*`;
- нет dangling day/item/location/leg references;
- timezone каждого scheduled day разрешён;
- отсутствие hard schedule conflicts в датированном Scenario;
- template не содержит catalog Event/transport с притворно гибкой датой;
- в каждой используемой alternative group выбран ровно один item;
- все mandatory items scheduled;
- все публичные custom locations проходят geo/privacy/moderation validation;
- public payload не ссылается на private Location;
- понятные public notes для ручных/неизвестных legs;
- отсутствие private data в публичном payload;
- успешная общая moderation validation.

Publish не устанавливает `published` напрямую: успешная отправка переводит
объект в `pendingReview`. `published` выставляется только результатом принятого
moderation flow. Archive/hidden/deleted следуют ADR 0013.

Public Scenario участвует в общей report/moderation policy ADR 0013, включая
auto-hide threshold и audit trail. Scenario moderation дополнительно
проверяет misleading schedule/budget, unsafe custom locations, запрещённые
public notes и подозрительное массовое дублирование.

### Не блокируют сохранение, но дают warning

- неизвестная цена;
- неизвестные opening hours;
- ручная логистика;
- нет бронирования;
- превышение рекомендуемого темпа;
- длинный переход;
- нет точной даты у шаблона.

### Start scenario

Дополнительно обязательно:

- dated mode;
- выбран ровно один вариант в каждой используемой alternative group;
- нет hard schedule conflicts на текущий день;
- timezone разрешён;
- следующий active item доступен или явно подтверждён как unknown;
- все обязательные planned transport items имеют departure/arrival;
- пользователь ознакомился с изменениями time/availability после последней
  проверки.

---

## 16. Состояния application/UI

Единый enum `ready/autosaving/routing/publishing` не используется: эти процессы
могут идти параллельно, и один статус неизбежно скроет другой.

```dart
class ScenarioBuilderState {
  ScenarioLoadState load;
  ScenarioSaveState save;
  ScenarioLogisticsState logistics;
  ScenarioOptimizationState optimization;
  ScenarioPublishState publish;
  ScenarioDraft? draft;
  ScenarioReadiness? readiness;
  List<ScenarioIssue> issues;
}
```

UI обязан иметь состояния:

- empty;
- loading draft;
- ready;
- empty day;
- unresolved source;
- offline/stale logistics;
- autosave success/failure;
- validation errors;
- publish in progress/success/failure;
- conflict after remote revision.

---

## 17. Autosave, версии и конкурентное редактирование

- локальное изменение сразу меняет in-memory draft;
- debounce autosave запускается после устойчивого изменения;
- routing/optimization получают `draftRevision`;
- устаревший async result игнорируется;
- серверное сохранение следует Accepted ADR 0013: last-write-wins;
- при обнаруженном конфликте пользователь получает обязательное предупреждение
  с данными о том, какая версия победила;
- до overwrite клиент сохраняет recoverable local conflict copy, если это
  возможно без нарушения retention/privacy policy;
- публикация фиксирует immutable revision;
- пользовательская копия публичного Scenario получает новый id.

Scenario definition и `ScenarioPersonalState` имеют независимые revisions и
autosave streams: отметка Done/booking note не должна конфликтовать с reorder
контента. `scenarioRevision` в personal state показывает, к какой definition
revision он был привязан при последней reconciliation.

Сеть не блокирует локальное редактирование. Статус несинхронизированных
изменений виден пользователю.

---

## 18. Карта

Scenario Map показывает:

- маркеры элементов с нумерацией внутри дня;
- отдельный цвет для каждого дня;
- display polyline городских legs;
- отдельное представление plannedTransport items;
- выбранный элемент и его соседние переходы;
- warnings на проблемных legs;
- фильтр по дням;
- fit bounds только по видимым элементам.

Scenario Map не позволяет редактировать геометрию вложенного Route. Действие
`Open route` открывает Route Details/Route Builder согласно правам.

### Discover, Details и deep links

- только `public + published` Scenario попадает в Discover;
- template и upcoming/inProgress dated участвуют в активной выдаче; past — нет;
- карточка показывает формат, дни, active stops, activity/travel time,
  `from` budget, primary market и readiness warnings, допустимые публично;
- Details показывает template timeline, alternatives, map, publisher,
  revision/update date и действия `Use this scenario`, `Save`, `Share`;
- личный Scenario открывается только из My scenarios/unlisted guard;
- Favorites хранит `{objectType: scenario, objectId}` и не классифицирует
  Scenario как Route;
- Review использует `{objectType: scenario, objectId}` и общий rating contract;
- canonical deep link: `recharge://scenario/{id}`;
- устаревший/hidden/deleted объект проходит общие navigation guards и fallback;
- `Use this scenario` создаёт независимую личную копию с новым id и origin;
- source revision update не меняет копию, но может показать сравнение версий.

`Save` в публичном Details означает добавить оригинал в Favorites. `Use this
scenario` создаёт редактируемую личную копию; эти действия не объединяются под
одной неоднозначной кнопкой.

---

## 19. Режим прохождения (`Start scenario`)

Для личного датированного Scenario:

- показывает текущий день и следующий элемент;
- действие `Navigate` передаёт leg во внешний/целевой navigation flow;
- `Open object` открывает Details;
- пользователь отмечает Done / Skip;
- задержка предлагает пересчитать только оставшуюся часть дня;
- фиксированные будущие элементы остаются locked;
- planned transport никогда не переносится автоматически;
- переход через полночь и смену timezone ориентируется на UTC instants;
- фактическое прохождение не изменяет публичный оригинал;
- личные completion states хранятся отдельно от Scenario definition.

Онлайн-бронирование и оплата остаются вне Scenario Builder и используют
контракт конкретного объекта. В MVP действие `Book` открывает проверенный
`externalBookingUrl`; reservation state меняется только по явному действию или
подтверждённому результату, а не по факту открытия ссылки.

---

## 20. Ошибки и деградация

| Ошибка | Поведение |
|---|---|
| Catalog object удалён | сохранить item, показать unavailable, предложить replace/remove |
| Routing offline | сохранить draft, оставить stale/unknown leg, Retry/manual |
| Opening hours неизвестны | warning, не считать объект закрытым |
| Цена устарела | показать snapshot + stale badge, предложить refresh |
| Autosave failed | оставить local changes, показать retry state |
| Publish failed | не менять draft status на published |
| Валюта не конвертируется | показать суммы отдельно |
| Timezone неизвестен | блокировать датированный Publish/Start |
| DST time неоднозначно | запросить выбор offset, не сдвигать молча |
| Alternative не выбрана | разрешить draft, блокировать Start |
| Другая валюта без rate snapshot | исключить из unified total, показать отдельно |
| Remote revision победила | применить LWW и показать recoverable conflict warning |
| Deep link содержит старый seed | разобрать adapter или открыть безопасный empty draft |

Ни одна ошибка provider не должна молча превращаться в нулевое время,
нулевую стоимость или подтверждённую доступность.

---

## 21. Приватность

Публичная часть:

- public title/description/notes;
- порядок публичных объектов;
- рекомендуемые даты/время;
- агрегированный бюджет;
- общие требования к группе;
- публичные logistics hints.

Только личная часть:

- имена участников;
- private notes;
- booking references;
- билеты и confirmation codes;
- фактические расходы;
- completion/progress;
- точная приватная локация проживания, если пользователь её скрыл.

Mapper публичного payload использует allowlist. Простого удаления нескольких
известных полей недостаточно.

Unlisted share использует тот же content allowlist и никогда не отдаёт
`ScenarioPersonalState`. Target share token:

- генерируется доверенным backend через CSPRNG;
- содержит не менее 128 бит энтропии;
- не выводится из Scenario ULID, owner id, revision или timestamp;
- хранится только как hash, сравнивается constant-time;
- может иметь expiry, rate limit и scope `read_copy`;
- отзывается владельцем без удаления Scenario; rotation немедленно делает
  прежнюю ссылку недействительной.

Внешняя share-ссылка строится из `AppLinksConfig` как HTTPS universal link.
Token передаётся во fragment (`#share=...`), который не уходит в HTTP referrer,
извлекается клиентом и обменивается через request body/authorization channel.
После разбора navigation нормализует адрес до canonical
`recharge://scenario/{id}` без token. Token запрещён в path/query, analytics,
crash reports, referrer, notification preview и обычных application logs.

Пока используется local mock datasource, externally reachable unlisted share
выключен capability-флагом либо явно помечен development-only. Mock token не
может рекламироваться как защищённая публичная ссылка. Реальный выпуск этой
capability блокирован backend integration slice после стабилизации.

Leg polyline с private endpoint не переиспользуется в public/unlisted payload:
она удаляется либо пересчитывается по disclosure-safe locations. Одного
округления start/end недостаточно, если исходная нить раскрывает точный адрес.

Для публичного custom location запрещено публиковать точку, похожую на частное
жильё/домашний адрес, без явного подтверждения и moderation policy. Личная
точка проживания не попадает в analytics, public map, logs или provider cache
в точном виде. Внешнему routing provider передаются только данные, необходимые
для конкретного запроса, согласно consent и market privacy policy.

### Observability

Допустимые события: builder opened, seed materialized, item added/removed,
validation shown, optimization proposed/applied, save/share/publish outcome и
Start outcome. Analytics получает object/item ids только в разрешённой
псевдонимизированной форме и стабильные issue/failure codes.

В analytics/logs запрещены source prompt, private notes, confirmation codes,
точные private coordinates, имена участников и полный itinerary payload.

---

## 22. Предлагаемая структура Create Hub

Scenario занимает planning-slot целевой десятки Create Hub вместо legacy
Quick Plan Create type. Общее число типов остаётся равным десяти. Quick Plan
не является Create-блоком и живёт как отдельный personal/invited utility flow.

```text
Scenario
Plan places, activities and travel across hours or days
```

Creator открывает этот блок из Create Hub; public/unlisted actions появляются
только при соответствующих MVP-C capabilities. User открывает тот же builder
из Search, Map, Details, Favorites или My scenarios для личного Scenario.
Права проверяются на действии, а не через отдельную копию UI. Quick Plan может
передать данные только через `Expand to Scenario` use case §7.

Предлагаемый form engine:

1. `NameDescriptionSection`;
2. `MediaSection`;
3. `ScenarioContextSection`;
4. `ScenarioComposerSection`;
5. `ScenarioLogisticsSection`;
6. `ScenarioReviewSection`;
7. общий Preview/Publish orchestration.

Специализированные секции не создают отдельный параллельный Create flow.
Draft save/load, media, navigation, validation orchestration и publish status
остаются общими для Create Hub.

---

## 23. MVP и последующие этапы

### Целевой MVP: три delivery-gate

Gates не являются разными типами или схемами. Все используют
`ScenarioDraft`/`ScenarioData`, versioned mapper и `scenario`; расширение
выполняется additive forward migration при реальной необходимости. Отключённое
поле не удаляется при round-trip и не активируется скрыто.

Capabilities включаются независимо:

```dart
class ScenarioCapabilities {
  int configVersion;
  bool multiDay;
  bool stay;
  bool plannedTransport;
  bool alternatives;
  bool multiTimezone;
  bool multiCurrency;
  bool optimizer;
  bool unlistedShare;
  bool publicPublish;
}
```

Один versioned config читают UI, materializer, validator и mapper. Нельзя
показывать control, который validator запрещает, или принимать payload,
который UI не способен безопасно открыть.

#### MVP-A — личный city/day

Цель: доказать, что пользователь превращает найденные объекты в исполнимый
план, не ожидая backend integration.

- самостоятельный Scenario type с typed `ScenarioData`;
- city/day, один день, template/dated;
- диапазон 1–24 часа;
- одна timezone и одна display currency;
- Place/Event/Activity/Route/Bookable Session как catalog items;
- custom location и time block;
- ручное добавление через `CatalogObjectPickerPort`;
- reorder, mandatory/optional, fixed/window/flexible time;
- manual/deterministic local legs без live-provider обещаний;
- totals с unknown values, readiness, blockers и warnings;
- отдельный personal state, local autosave, Save/Preview/Map/Start;
- mock datasource; externally reachable sharing отсутствует.

#### MVP-B — личный weekend/trip

Цель: выразить городской отдых и большие поездки без второй модели плана.

- weekend/trip до 30 дней и перенос items между днями;
- stay и ручные междугородние plannedTransport items;
- multi-city, multi-timezone/DST и multi-currency snapshots;
- alternative groups и unscheduled backlog;
- deterministic optimizer только как proposal + explicit Apply;
- независимые capability flags позволяют выпустить multi-day без optimizer или
  alternatives, если их quality gates ещё не пройдены.

#### MVP-C — distribution

Цель: безопасно распространять воспроизводимые планы после проверки личной
ценности.

- unlisted share через backend-issued token contract §21;
- public Creator/ManagedPage authoring;
- `pendingReview`/moderation/report flow;
- Discover/Details/Favorites/Review/deep links для `scenario`;
- immutable personal copy через `Use this scenario`;
- source-update warnings и notification consent.

MVP-C блокирован реальными capabilities, publisher/moderation runtime и
backend integration. Mock может демонстрировать UI/state fixtures, но не
считается готовой внешней публикацией или защищённым sharing.

### Не входит ни в один MVP gate

- генерация или оптимизация, называемая AI без реальной LLM-модели;
- покупка, оплата и изменение бронирования внутри Recharge;
- автоматическая перестановка fixed/locked items;
- скрытая публикация private location или personal state;
- live routing без отдельного Accepted ADR, provider policy и kill switch;
- совместное редактирование и автоматический merge;
- перенос Route geometry, anchors, segments или POI в Scenario;
- гарантия цен, времени работы, наличия билетов или времени прибытия.

### Метрики продуктового успеха

North-star metric: доля сохранённых Scenarios, которые пользователь реально
запустил и в которых завершил хотя бы один item. Она измеряет переход от
подборки идей к действию, не поощряя пустые сохранения.

| Этап | Основная метрика | Диагностические метрики |
|---|---|---|
| Activation | time to first useful preview | seed success, unresolved refs, preview latency |
| Intent | preview → Save/Edit | exits by issue type, edits before save |
| Planning | Save → readiness without blockers | conflicts resolved, unknown legs, autosave recovery |
| Execution | Save → Start; Start → first Done | revalidation failures, Skip/abandon reasons |
| Reuse | public Details → Use this scenario | copy completion, date adaptation success |
| Quality | plan completion and next-item continuation | delay recovery, manual overrides, stale data |

Числовые targets фиксируются после beta baseline отдельным analytics decision,
чтобы не выдавать произвольные значения за доказанные нормы. До запуска
обязательны технические guardrails:

- 0 случаев сохранения unknown duration/cost как нуля в contract tests;
- 0 personal/private полей в public mapper fixtures;
- 0 путей, создающих Route aggregate из `ScenarioSeed`/`ScenarioData`;
- 100% destructive optimization changes требуют explicit Apply;
- provider failure сохраняет draft во всех integration fixtures;
- analytics schema не принимает prompt, private notes, confirmation codes,
  participants или точные private coordinates.

Метрики сегментируются по source, format, market и app version, но не по
чувствительным данным пользователя. Для каждой воронки задаются denominator,
окно атрибуции и событие успеха до реализации dashboards.

### Post-MVP

- LLM generation;
- автоматическое построение полной поездки;
- live train/flight/ferry providers;
- live city logistics provider после отдельного ADR;
- совместное редактирование;
- голосовое редактирование;
- real-time disruption replanning;
- покупка билетов и бронирование внутри приложения;
- offline navigation package;
- автоматическая синхронизация фактических расходов.

---

## 24. Разбиение будущей реализации

Полная логика не внедряется одним PR. После утверждения этой спецификации
специализированные Scenario Create slices для принятого planning-slot могут идти
параллельно активной стабилизации по AGENTS.md. Каждый такой slice всё равно
обязан иметь подтверждённый file plan, собственные acceptance criteria,
зелёные `flutter analyze`/`flutter test` и boundary gate. Firebase, live
providers и другие post-stabilization integrations в это исключение не входят.

### SB-00 — Product acceptance и migration design

- утвердить этот spec, delivery-gates и решения §27;
- согласовать расширение VISION до city/day и последующее включение
  weekend/trip без изменения списка десяти Create-типов;
- описать миграцию legacy `scenario route` handoffs в `scenario` без записи в
  Route domain;
- разделить текущий `CreateObjectType.quickPlan`: лёгкие personal drafts
  остаются Quick Plan utility, Scenario-shaped/public drafts получают новый
  Scenario ULID и type через явный migration mapping;
- инвентаризировать фактические definitions/consumers через `rg`/boundary gate;
- не включать в migration plan отсутствующий или только предполагаемый файл;
- зафиксировать mapping, независимые capability flags, rollout и rollback;
- определить owner, evidence и exit criteria каждой зависимости ниже.

### Проверенные зависимости на 2026-07-19

| Зависимость | Фактический статус | Блокирует |
|---|---|---|
| ADR 0011 / frozen architecture | Accepted | любое несовместимое размещение или новый architecture root |
| ADR 0013 / lifecycle, LWW, permissions policy | Accepted | отклонение lifecycle/permission semantics |
| Category System v1.4.3 | реализована | только новый несовместимый criteria contract |
| Create Hub config-driven baseline | реализован для 10 типов | SB-02 extensions должны идти через sections/config |
| Scenario typed config/mapper | не реализованы | SB-01, SB-02 |
| `CatalogObjectPickerPort` + composition adapter | не реализованы | catalog add flow в SB-02 |
| ManagedPage/capability guards runtime | не реализован | public authoring MVP-C / SB-05 |
| Moderation/report runtime | policy Accepted, runtime не реализован | external public Publish / SB-05 |
| Firebase/backend integration | запрещена до завершения стабилизации | real sync и externally reachable unlisted share |
| Live maps/logistics provider ADR | не Accepted для этого flow | SB-06 |
| Localization en/ru/lv | не настроена | production copy/localized validation, не domain core |
| Notification consent/settings | целевой контур не подтверждён | source-update push, не in-app warning |

Зависимость блокирует только указанную capability. Например отсутствие
ManagedPage не блокирует личный multi-day plan, а отсутствие live routing не
блокирует manual/estimated legs. Обход возможен только через явное approved
решение с ограничением scope, рисками и rollback.

### SB-01 — Canonical domain model

- typed model, schema v1 и mapper;
- ids/references, template/dated schedule, timezone/currency;
- alternatives, totals, validation и readiness;
- personal-state boundary;
- shared primitive placement только по ADR 0011/baseline;
- round-trip, migration и unit tests.

### SB-02 — MVP-A composer

- Scenario Create config и специализированные Scenario sections;
- один день, items, reorder, locks, mandatory/optional;
- catalog/custom/time block через `CatalogObjectPickerPort`;
- undo/redo, local autosave и widget tests.

### SB-03 — MVP-A scheduling и manual logistics

- timeline engine;
- fake/manual legs и stale-response guard;
- fixed/window/flexible conflict UI;
- schedule/logistics integration tests.

### SB-04 — MVP-B multi-day

- weekend/trip, stay, plannedTransport и перенос между днями;
- alternatives, multi-timezone/DST и multi-currency;
- deterministic optimizer proposal + explicit Apply;
- capability isolation и disabled-data round-trip tests.

### SB-05 — MVP-C distribution и migration

- Creator/ManagedPage publisher flow;
- backend-issued unlisted share/revoke/expiry;
- public allowlist mapper, moderation и immutable revisions;
- legacy handoff migration без изменения Route aggregate;
- feature-flag rollout и LAUNCH_STATUS.

UI, typed states, mapper и policy fixtures могут разрабатываться на mock в
разрешённом Create slice. Внешнее включение publish/share остаётся выключенным,
пока capabilities, moderation runtime и backend dependency не готовы.

### SB-06 — Live logistics

- отдельный Accepted maps/logistics ADR;
- provider adapter, attribution, quota, cache и privacy;
- kill switch, fallback и runbook.

### SB-07 — Start scenario

- execution mode и current-day focus;
- Done/Skip, delay proposal и revalidation;
- personal completion state и notification policy.

### Обязательная verification matrix

- mapper: round-trip/forward migration, unknown enum, corrupted section;
- identity: duplicate source refs, unique ids, `loc_*` replacement;
- schedule: fixed/window/flexible, midnight, DST gap/overlap, timezone change;
- alternatives: zero/one/multiple selected и totals isolation;
- logistics: reorder invalidation, manual override, timeout и stale response;
- money: per-person/per-group/per-night, unknown/free, conversion snapshot;
- privacy: public allowlist fixtures и отсутствие personal fields;
- sharing: token entropy/hash/expiry/revoke/log-redaction и mock-disabled guard;
- lifecycle: draft → pendingReview → published/hidden/archived/deleted;
- permissions: owner, Creator, ManagedPage и deep-link guards;
- boundaries: ни один feature не импортирует внутренности другого; picker
  проходит через Create port и app composition adapter;
- capabilities: независимое включение multi-day/alternatives/optimizer/share/
  publish и сохранность выключенных данных при round-trip;
- source snapshots: ready/stale/unavailable/missing и last-known policy;
- offline/sync: restart, LWW conflict warning и recoverable local copy;
- widget: empty/preview/composer/review/save/share/publish/error;
- integration: Search/Map/Details/Favorites/Profile/Notifications handoffs;
- migration: legacy quick plan/scenario-route fixtures не создают Route data.

Каждый slice считается Done только при зелёных `flutter analyze`, полном
`flutter test`, boundary gate и отсутствии новых allowlist violations.

---

## 25. Acceptance criteria будущей реализации

1. `CreateObjectType.route` и Scenario не используют общую
   доменную модель.
2. Route сохраняет только данные непрерывного трека согласно Route spec.
3. Канонический Scenario type — `CreateObjectType.scenario` / `scenario`; он
   занимает planning-slot целевой десятки вместо legacy Quick Plan Create type.
4. Scenario item ссылается на каталоговый объект только по object id/type.
5. Route может быть добавлен в Scenario как один item.
6. Builder поддерживает однодневный и многодневный plan, включая перенос item
   между днями.
7. После reorder пересчитываются только затронутые legs.
8. Fixed и locked items не меняются оптимизатором.
9. Неизвестные duration/cost не превращаются в ноль.
10. Итоги разделяют activity, planned blocks, stay, local travel, planned
    transport, implicit waiting и day elapsed.
11. Save draft доступен при любой заполненности.
12. Save to plans и Publish имеют разные уровни валидации.
13. Публичный mapper не включает private notes и booking details.
14. Provider failure не удаляет пользовательские данные.
15. Autosave защищён revision от устаревших async results.
16. Публичный Scenario можно скопировать без связи на последующие изменения.
17. Preview-first работает для готового seed и публичного Scenario.
18. Map визуально разделяет дни и legs.
19. Поезд/перелёт с расписанием моделируется item, а не derived leg.
20. Template не хранит фиктивные UTC timestamps; dated plan хранит UTC + IANA.
21. Ночной item и смена timezone не создают искусственных дубликатов.
22. Alternative group учитывает максимум один выбранный item в totals.
23. Разные валюты не складываются без versioned rate snapshot.
24. Offline sync следует LWW + user warning согласно ADR 0013.
25. Publish переводит draft в `pendingReview`, а не сразу в `published`.
26. Unit-тесты покрывают totals, scheduling, timezone/DST, alternatives,
    validation, migration и optimization.
27. Widget-тесты покрывают create, edit, save, share, publish и error states.
28. Порядок хранится только в dayIndex/itemIds; дублирующие order fields
    отсутствуют.
29. Day/Item/Leg ссылаются на единый Location registry только по id.
30. Experience, stay, local travel и planned transport costs не учитываются
    дважды; adult/child/group/night components рассчитываются отдельно.
31. Alternative group находится в одном logical slot и не даёт учесть больше
    одного выбранного варианта.
32. Public/unlisted mapper не раскрывает private Location или её leg polyline.
33. `ScenarioData` не получает самостоятельный repository, object id, lifecycle
    или deep link.
34. Favorites, Review и deep links используют canonical type `scenario`.
35. Instant, Edit и Publish materialize один и тот же typed aggregate и mapper.
36. Копия public Scenario получает новый ULID и origin без живой зависимости.
37. UI называет объект Scenario и не использует Route или Quick Plan для
    списка независимых мест и многодневной логистики.
38. Ключевые действия доступны без long press, имеют semantic labels и
    проходят accessibility/widget coverage.
39. Analytics contract отклоняет personal/private payload и raw prompt.
40. `flutter analyze` и полный `flutter test` зелёные.
41. Create и Discover не импортируют внутренние слои друг друга;
    `CatalogObjectPickerPort` реализуется app composition adapter.
42. Общие primitives размещены по Accepted ADR 0011/frozen baseline; новый
    `core/domain` не создаётся без нового Accepted ADR.
43. UI, materializer, validator и mapper читают один versioned
    `ScenarioCapabilities` config.
44. Multi-day, alternatives, optimizer, unlisted share и public publish
    включаются независимо; выключенная capability не стирает известные поля.
45. Route-item со `sourceStatus=stale` сохраняет last-known stats как estimated
    с freshness warning и не подставляет ноль.
46. Route-item со `sourceStatus=unavailable` сохраняет last-known historical
    preview, блокирует обязательный Start/Publish и становится unknown только
    при отсутствии достоверного snapshot.
47. Production unlisted token имеет CSPRNG entropy ≥128 бит, хранится hash,
    поддерживает expiry/revoke/rotation, передаётся только во fragment
    configured HTTPS share link и не попадает в path/query/telemetry/logs.
48. Local mock не выдаёт development token за externally secure share и держит
    реальную unlisted capability выключенной.
49. Migration plan ссылается только на существующие пути/definitions,
    подтверждённые repository audit; удаление не основывается на предположении.
50. Approved специализированный Scenario slice, идущий параллельно
    стабилизации, не включает Firebase/live integration и проходит собственные
    tests, acceptance и boundary gates.
51. Quick Plan и Scenario имеют разные ids, repositories, lifecycles и
    persistence mappers; Scenario не является полем Quick Plan.
52. Quick Plan не получает publisher, Discover projection, public catalog
    lifecycle или Review target; invited/unlisted не означает public.
53. `Expand to Scenario` всегда создаёт новый Scenario ULID и не изменяет
    исходный Quick Plan.
54. Quick Plan invite list/token/chat/participants/completion не копируются в
    Scenario; private notes требуют отдельного consent.
55. Conversion хранит только provenance snapshot и не создаёт live sync между
    Quick Plan и Scenario.
56. Scenario занимает planning-slot Create Hub; общее число Create-типов
    остаётся десять, а Quick Plan работает вне Create Hub.
57. Migration классифицирует существующие drafts по фактической shape/use, а
    не переименовывает все `quick_plan` записи в Scenario автоматически.
58. Expand разрешён только requester с read + copy permission; новый Scenario
    принадлежит requester независимо от owner исходного Quick Plan.
59. Quick Plan revision mismatch показывает diff и требует явного решения, а
    не конвертирует незаметно изменившийся источник.
60. Conversion может перенести только private notes requester после consent;
    заметки owner/других invited members недоступны mapper и analytics.
61. AI generation является опциональным entry mode существующего Scenario, а
    не отдельным aggregate/Create type.
62. AI output сначала создаёт transient proposal/seed и не записывается в
    Scenario repository напрямую.
63. Модель не генерирует permanent IDs; web candidate без resolution остаётся
    unresolved и не становится catalog relation.
64. AI proposal проходит тот же deterministic schedule/readiness validator,
    что manual Scenario.
65. При выключенном AI manual, selected-object, Quick Plan conversion и public
    template copy flows остаются работоспособны.
66. Live AI/web/provider enablement требует отдельного Approved
    post-stabilization slice, backend proxy, privacy/cost gates и kill switch.

---

## 26. Известные расхождения текущей реализации

Этот раздел фиксирует аудит, но не является разрешением менять код.

- существующий `ScenarioDraftEntity` хранит упрощённые места, но называет
  итоговую проверку `ScenarioRouteFit`;
- `optimizeRoute()` фактически оптимизирует список мест Scenario;
- `CreateObjectType.route` описан как Scenario из точек;
- Create/Map/Notifications используют смешанные значения `scenario`,
  `route`, `scenario route` и `mode=scenario`;
- текущий seed передаёт категории вместо постоянных object ids;
- длительность Scenario не включает реальное время legs;
- distance хранится на item и складывается, хотя должна относиться к legs;
- публичная Route-публикация восстанавливается из Scenario seed;
- VISION связывает Scenario Builder с Quick Plan и должно быть обновлено под
  три самостоятельных aggregate;
- `CreateObjectType.quickPlan` сейчас занимает planning-slot Create Hub, хотя
  целевая модель оставляет Quick Plan вне Create taxonomy и отдаёт slot
  Scenario;
- существующий Scenario Builder по shape ближе к лёгкому Quick Plan, но
  использует Scenario/Route naming; требуется классификация, а не массовый
  rename;
- нет самостоятельного `CreateObjectType.scenario`, Scenario repository и
  Scenario mapper;
- нет явного Quick Plan → Scenario conversion use case;
- нет разделения Scenario definition и personal execution state;
- нет модели stay/planned transport/time block/alternatives;
- текущий seed невозможно безопасно использовать как постоянное хранилище;
- нет `ScenarioCapabilities` как единого versioned источника UI/validation;
- нет Create-owned `CatalogObjectPickerPort` и composition adapter;
- local mock не может обеспечить production-grade unlisted token/sync;
- фактическое размещение всех общих primitives ещё должно быть подтверждено
  repository inventory; этот spec не объявляет отсутствующие файлы долгом.

Для исправления потребуется отдельный migration plan после утверждения этой
спецификации.

---

## 27. Рекомендуемый decision baseline

Владелец продукта принял следующий связный baseline:

| Вопрос | Рекомендуемое решение |
|---|---|
| Quick Plan | отдельный lightweight personal/invited aggregate вне Create Hub и каталога |
| Scenario | самостоятельный personal/public aggregate и Create type `scenario` |
| Route | отдельный continuous-track aggregate; не режим Scenario |
| UI naming | `Scenario` / `Scenario Builder`; `Quick Plan` / «Быстрый план» — другой продукт |
| Create blocks | Scenario занимает planning-slot вместо Quick Plan; общее число остаётся 10 |
| Quick Plan limits | обычно одна дата, 30 мин–6 ч, 2–8 stops; без stay/multi-day/public catalog |
| Conversion | только one-way Expand: новый Scenario ULID, provenance snapshot, без live sync |
| Invited boundary | приглашённые известные люди; открытый поиск участников остаётся Find People |
| Trip limit | 30 дней, 250 items всего, 200 active, 50 unscheduled, до 20 alternative groups × 5 вариантов |
| Personal authoring | доступно User вне Creator-only publish flow в MVP-A/B |
| Unlisted share | MVP-C; backend token ≥128 бит с hash/expiry/revoke/rate-limit |
| Public authoring | MVP-C; capability-based Creator/ManagedPage publish |
| Public custom location | разрешено с permanent id, geo/privacy и moderation checks |
| Minimum publish | 2 active публичных items, минимум один день |
| Alternatives | capability MVP-B; в totals выбран максимум один вариант группы |
| Budget | estimates входят в `from` total с source/confidence/unknown count |
| Multi-city | capability MVP-B; intercity transport вводится вручную |
| Live providers | отдельный slice после Accepted ADR и kill-switch design |
| Start scenario | отдельный SB-07, но часть целевого MVP |
| Source updates | warning при открытии всегда; push только для material/time-bound changes согласно consent/notification settings |
| Permissions | отдельные create/edit/share/publish/archive/delete capabilities |
| Delivery gates | MVP-A personal city/day → MVP-B personal weekend/trip → MVP-C distribution |
| Capability config | multi-day/stay/transport/alternatives/currency/optimizer/share/publish включаются независимо |
| VISION | Quick Plan, Scenario и Route описываются как три самостоятельных продукта |
| Picker boundary | Create-owned domain port + app composition adapter; features не импортируют друг друга |
| Shared primitives | только по ADR 0011/frozen baseline; новый `core/domain` требует Accepted ADR |
| Route snapshot | stale → last-known estimated; unavailable → historical estimate + Start/Publish blocker |
| Mock sharing | внешняя secure share capability выключена до backend integration |
| Stabilization | Approved Scenario Create slice разрешён параллельно; Firebase/live providers запрещены |

Baseline принят 2026-07-19. После принятия:

1. статус меняется на `Accepted`;
2. создаётся migration/rollout plan SB-00;
3. VISION и LAUNCH_STATUS приводятся в соответствие;
4. подтверждается план файлов каждого крупного slice;
5. Approved специализированные Scenario slices могут выполняться параллельно
   стабилизации в пределах исключения AGENTS.md;
6. каждый slice проходит собственные acceptance criteria, `flutter analyze`,
   полный `flutter test` и boundary gate;
7. Firebase/live-provider работа начинается только после закрытия
   стабилизации и отдельного разрешённого integration slice.
