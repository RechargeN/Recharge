# RECHARGE — поиск, фильтры и подбор по времени

Версия: 2026-07-17 · v9.1 · Accepted product specification

## Статус

**Статус: Accepted.** Утверждено владельцем продукта 2026-07-17.

Документ является канонической продуктово-технической основой Search,
Filters и time-fit flow. Он самодостаточен и не содержит открытых
технических вопросов.

Gate-условия реализации:

1. документация утверждена владельцем продукта — **выполнено**;
2. принят отдельный ADR по участию `timeFit` в ранжировании — **выполнено**,
   [ADR 0014](../adr/0014-time-fit-ranking.md);
3. завершён активный slice стабилизации — **выполнено**.

Реализация в приложении начата отдельным пользовательским запросом после
выполнения всех gates.

---

## 1. Цель и границы

Recharge должен отвечать на вопрос: «что реально помещается в моё окно
времени с учётом доступности объекта и дороги».

Один применённый `DiscoverQuery` используется Search, Results, Map, Feed и
Details. UI не вычисляет time fit: он только собирает ввод и показывает
результат application/domain-логики.

### В scope

- точное, гибкое и относительное окно «сейчас до конца дня»;
- event-slot и opening-hours модели доступности;
- время дороги туда и обратно;
- full / partial / unknown time fit;
- сохранение и миграция `DiscoverQuery`;
- заполнение расписания через единый Create form engine;
- исправление launch-market defaults на Riga / Europe/Riga;
- mock datasource, UI, аналитика и тесты.

### Вне scope

- внешняя проверка столиков, билетов и booking slots;
- уведомления о новых совпадениях;
- автоматическая мультистоп-генерация;
- интеграция TimeWindow со Scenario Builder;
- Firebase и production API;
- мультирынок как продуктовая функция.

`externalConfirmationStatus` в этом slice не добавляется: неиспользуемое
поле не резервируется в runtime-модели.

---

## 2. Подтверждённое исходное состояние

- Общая модель фильтров — `DiscoverQuery`.
- `queryVersion` уже существует и равен `1`.
- Текущие ошибочные defaults: `marketCityId = rezekne`,
  `centerLat = 56.5099`, `centerLng = 27.3332`.
- В runtime нет `EventEntity`, `PlaceEntity`, `OpeningHoursRule`,
  `GeoPoint` и `MarketConfig`.
- Выдача использует `DiscoverItemEntity`.
- Координаты объекта: `latitude` и `longitude`.
- `durationMinutes`, `capacity` и `participantsCount` сейчас non-null
  `int` с fallback `0`.
- `participantsCount = 0` — валидное значение «участников пока нет».
- UI сейчас трактует `capacity <= 0` как отсутствие подтверждённого лимита,
  а `durationMinutes <= 0` — как flexible/unknown.
- Отдельного mapper-файла для Discover нет:
  `DiscoverItemModel.fromMap` находится в `discover_item_model.dart`.
- Mock datasource:
  `discover/data/datasources/discover_remote_datasource.dart`.
- У `CreateDraftEntity` есть поля `timezone`, `country`, `city`,
  `latitude` и `longitude`; `marketCityId` отсутствует.
- Дефолт CreateDraft ошибочно равен `Europe/Moscow`.
- `MarketConfig` отсутствует.

---

## 3. Market configuration

Создаётся `app/config/market_config.dart`. Это app-level конфигурация, а не
domain-сущность Discover. Domain-слои не импортируют `app/config`:
application передаёт в domain только примитивы/значения.

Импорт `app/config` разрешён только composition root (`app/di`). Ни
Discover, ни Create не импортируют его напрямую: DI передаёт market/travel
значения в конструкторы controller/use case и factory parameters.

```
MarketConfig {
  marketCityId: String
  countryCode: String
  cityName: String
  timezoneId: String
  currencyCode: String
  centerLat: double
  centerLng: double
}
```

Активный launch market:

```
marketCityId: riga
countryCode: LV
cityName: Riga
timezoneId: Europe/Riga
currencyCode: EUR
centerLat: 56.9496
centerLng: 24.1052
```

Registry также может содержать legacy-запись `rezekne` только для чтения
старых локальных данных. Она не является launch default.

Создаётся `app/config/travel_policy_config.dart`:

```
TravelPolicyConfig {
  placeReturnSafetyRatio: 0.20
  placeReturnSafetyMinMinutes: 5
  placeReturnSafetyMaxMinutes: 20
  walkingSpeedKmh: 4.8
  walkingRouteFactor: 1.20
  drivingSpeedKmh: 25.0
  drivingRouteFactor: 1.30
  transitSpeedKmh: 18.0
  transitRouteFactor: 1.35
}
```

Запас для обратной дороги места:

```
margin = clamp(
  ceil(rawReturnMinutes * placeReturnSafetyRatio),
  placeReturnSafetyMinMinutes,
  placeReturnSafetyMaxMinutes
)
```

Значения — стартовая MVP policy. Они конфигурируемые и не хардкодятся в
use case.

---

## 4. DiscoverQuery и TimeWindow

Текущий файл Query находится в application, при этом domain repository и
use case импортируют его снизу вверх. Slice исправляет boundary: чистая
модель `DiscoverQuery` вместе с `DiscoverSortMode` переносится в
`discover/domain/entities/discover_query.dart`. Все consumers обновляют
imports; application-specific логика в Entity не добавляется.

```
DiscoverQuery {
  // все существующие поля сохраняются
  timeWindow: TimeWindow?
  travelContext: TravelContext?
  queryVersion: int // 2
}

TimeWindow {
  startAtUtc: DateTime
  endAtUtc: DateTime
  timezoneId: String
  mode: TimeWindowMode // exact | flexible | anytimeToday
  flexibilityMinutes: int
  resolvedAtUtc: DateTime
}

TravelContext {
  originType: TravelOriginType // currentLocation | manualPin
  origin: GeoPoint
  transportMode: TransportMode // walking | driving | transit
  includeReturnTrip: bool
}
```

Инварианты:

- `startAtUtc < endAtUtc`;
- `timezoneId` — валидный IANA identifier;
- `flexibilityMinutes > 0` только для `flexible`, иначе `0`;
- координаты валидны;
- при заданном `timeWindow` travel context обязателен: отсутствие дороги
  нельзя молча интерпретировать как нулевое время.

Семантика режимов:

- `exact` — исходный интервал без расширения;
- `flexible` — effective interval расширяется на
  `flexibilityMinutes` с обеих сторон;
- `anytimeToday` — application фиксирует UTC-пару от текущего момента до
  конца локального дня. В активном запросе она не «плавает». Saved Search
  при повторном применении в другой локальный день резолвится заново.

Конкретные slots хранятся в UTC. `timezoneId` используется для
пользовательского намерения и интерпретации локальных `openingHours`.

Для IANA/DST-конвертации добавляется Dart dependency `timezone` без импорта
Flutter types в domain. Domain определяет `TimezoneRepository`, data-слой —
реализацию на базе timezone database.

Правила DST:

- несуществующее локальное время пользовательского ввода отклоняется с
  validation error;
- для неоднозначного пользовательского интервала start выбирает ранний
  instant, end — поздний;
- для opening hours неоднозначный open выбирает поздний instant, close —
  ранний (консервативно, без ложного расширения доступности);
- несуществующий open сдвигается вперёд до первого валидного instant;
- несуществующий close сдвигается назад до последнего валидного instant,
  чтобы DST-gap не удлинял интервал открытости;
- если после нормализации close не позже open, правило считается невалидным,
  `openingStatus = unknown`, hard fit по нему не подтверждается и пишется
  telemetry error.

Это явная продуктово-техническая политика, а не неявный default timezone
library.

---

## 5. Availability projection в Discover

Отдельные Event/Place domain-модели этим slice не вводятся. Расширяется
проекция `DiscoverItemEntity`:

```
DiscoverItemEntity {
  // существующие поля
  marketCityId: String
  durationMinutes: int?
  durationConfidence: DurationConfidence // exact | estimated | unknown
  availabilityKind: AvailabilityKind     // eventSlots | openingHours | none
  scheduleSlots: List<TimeSlot>
  openingHours: List<OpeningHoursRule>
  allowsPartialAttendance: bool
  minimumVisitDurationMinutes: int?
  bufferBeforeMinutes: int
  bufferAfterMinutes: int
  capacity: int?
  participantsCount: int?
}

TimeSlot {
  slotId: String
  startAtUtc: DateTime
  endAtUtc: DateTime
}

OpeningHoursRule {
  dayOfWeek: DayOfWeek?
  exceptionDate: LocalDate?
  isClosedAllDay: bool
  openMinutesSinceLocalMidnight: int?
  closeMinutesSinceLocalMidnight: int?
}

LocalDate {
  year: int
  month: int
  day: int
}
```

`LocalDate` сериализуется как `YYYY-MM-DD` и не содержит времени/zone.

Инварианты:

- `eventSlots` требует непустые `scheduleSlots`;
- `openingHours` требует непустые `openingHours`;
- `none` не проходит hard time-fit и получает `unknown`, если нет
  достоверной длительности/расписания;
- одновременно непустые slots и opening hours запрещены для одной projection;
- `slotId` — постоянный ULID опубликованного slot; `loc_*` допустим только
  в локальном draft и заменяется при публикации;
- `startAtUtc < endAtUtc`;
- `durationMinutes`: `null` = неизвестно, положительное число = известно;
- `capacity`: `null` = лимит неизвестен/не задан, значение должно быть > 0;
- `participantsCount == null` означает неизвестное число, явный `0` —
  валидное значение «участников пока нет»;
- при `allowsPartialAttendance = true` обязателен положительный
  `minimumVisitDurationMinutes`;
- onsite buffers не могут быть отрицательными.

Для постоянных IDs добавляется dependency `uuid`; `IdGenerator` из core
инкапсулирует UUID v4. Domain получает готовый ID и не зависит от package API.
Mock slot IDs задаются детерминированно в seed, а не генерируются при каждом
чтении.

Политика legacy zero:

- `durationMinutes <= 0` нормализуется в `null`;
- `capacity <= 0` нормализуется в `null`;
- отсутствующий `participantsCount` нормализуется в `null`, явный `0`
  сохраняется как `0`;
- `itemSchemaVersion` не вводится: Discover items сейчас приходят из mock
  datasource и локально целиком не сохраняются. Нормализация выполняется на
  data boundary в `DiscoverItemModel.fromMap`.

Capacity status:

```
capacity == null                         -> unknown
participantsCount == null                -> unknown
capacity > 0 && participantsCount < capacity -> available
capacity > 0 && participantsCount >= capacity -> full
```

---

## 6. Create Hub

Create остаётся единым config-driven form engine. Отдельные flow для типов
не создаются.

В `CreateDraftEntity` добавляются:

```
marketCityId: String
availabilityKind: CreateAvailabilityKind
scheduleSlots: List<CreateTimeSlotDraft>
openingHours: List<CreateOpeningHoursDraftRule>
allowsPartialAttendance: bool
minimumVisitDurationMinutes: int?
bufferBeforeMinutes: int
bufferAfterMinutes: int
```

Create использует собственные draft value objects и не импортирует
`discover/domain`. Их сериализованные ID/UTC/local-date значения
маппятся внутри Create data/repository boundary. Текущий mock slice не
передаёт опубликованный CreateDraft прямо в Discover: Discover получает
projection из собственного mock datasource. Firebase/API DTO позже должен
быть добавлен в `packages/api_contracts` отдельным backend slice. Прямой
импорт между features запрещён.

```
CreateAvailabilityKind { eventSlots, openingHours, none }

CreateTimeSlotDraft {
  localId: String            // loc_* до публикации
  startAtUtc: DateTime
  endAtUtc: DateTime
}

CreateOpeningHoursDraftRule {
  dayOfWeek: int?
  exceptionDateIso: String?  // YYYY-MM-DD
  isClosedAllDay: bool
  openMinutesSinceLocalMidnight: int?
  closeMinutesSinceLocalMidnight: int?
}
```

Form config определяет допустимый `availabilityKind` для Create type и
подключает общие sections:

- Schedule slots;
- Opening hours и исключения;
- Duration и partial attendance;
- Capacity;
- Onsite buffers.

Новый domain use case `ValidateCreateAvailabilityUseCase` проверяет
инварианты §5. UI только отображает ошибки.

Для capacity переиспользуются существующие поля CreateDraft:
`maxParticipants` публикуется как `DiscoverItem.capacity`, а
`currentParticipants` — как `DiscoverItem.participantsCount`.
Новое дублирующее поле `capacity` в CreateDraft не добавляется.

`CreateDraftEntity.defaults` не импортирует MarketConfig. Application
передаёт в factory:

```
marketCityId
timezone
country
city
```

Новые drafts получают активный market `riga`. Значения передаются из app/DI
в controller/factory; Create не импортирует `app/config`. Старые drafts
мигрируются в data model, см. §11.

---

## 7. Travel-time contract

Один объект может иметь несколько slots, поэтому результат индексируется не
только по object ID.

```
GeoPoint {
  latitude: double
  longitude: double
}

TravelCandidate {
  candidateId: String      // objectId:slotId либо objectId:place
  objectId: String
  slotId: String?
  destination: GeoPoint
  outboundTiming: TravelTiming
  returnDepartureAtUtc: DateTime?
}

TravelTiming {
  kind: TravelTimingKind   // departAt | arriveBy
  atUtc: DateTime
}

TravelTimeBatchRequest {
  origin: GeoPoint
  transportMode: TransportMode
  includeReturnTrip: bool
  candidates: List<TravelCandidate>
}

TravelTimeEstimate {
  candidateId: String
  outboundMinutes: int?
  returnMinutes: int?
  returnLegStatus: TravelLegStatus
  totalMinutes: int?
  quality: TravelEstimateQuality
}

TravelLegStatus {
  notRequested
  available
  unavailable
}

TravelEstimateQuality {
  liveTraffic
  modeled
  fallback
  unavailable
}
```

Event candidate использует `arriveBy = slot.startAtUtc - bufferBefore` и
`returnDepartureAtUtc = slot.endAtUtc + bufferAfter`.

Place candidate использует `departAt = effectiveStartAtUtc`. Для обратной
ноги берётся `effectiveEndAtUtc`, затем применяется safety margin из §3.
Поскольку реальное время выезда неизвестно, quality cap явный:

```
liveTraffic -> modeled
modeled     -> modeled
fallback    -> fallback
unavailable -> unavailable
```

Контракт `includeReturnTrip` не допускает двусмысленного `null`:

```
includeReturnTrip == false:
  returnLegStatus = notRequested
  returnMinutes = 0
  totalMinutes = outboundMinutes
  returnDepartureAtUtc не передаётся

includeReturnTrip == true, ETA рассчитан:
  returnLegStatus = available
  returnMinutes = рассчитанное значение
  totalMinutes = outboundMinutes + returnMinutes

includeReturnTrip == true, ETA недоступен:
  returnLegStatus = unavailable
  returnMinutes = null
  totalMinutes = null
  quality = unavailable
```

Таким образом, `0` означает только явно не запрошенную обратную ногу, а
`null` — запрошенную, но не рассчитанную. Safety margin места применяется
только при `includeReturnTrip = true`; иначе effective return minutes равны
нулю.

Если outbound ETA недоступен, `outboundMinutes = null`, `totalMinutes = null`
и `quality = unavailable` независимо от return policy. Формулы §8 выполняются
только после проверки нужных leg values; любой запрошенный, но недоступный
leg даёт `travelFitStatus = unknown`, а не арифметику с `null`.

Application делает один логический вызов repository для списка candidates.
Repository вправе разбивать его на provider batches по лимитам API. Это не
считается повторным бизнес-расчётом.

Текущий MVP не имеет Routes/Distance Matrix provider. Поэтому обязательная
реализация включает deterministic fallback: Haversine distance умножается
на route factor соответствующего transport mode и переводится во время по
скорости из `TravelPolicyConfig`, с округлением вверх минимум до 1 минуты.
Результат всегда имеет quality `fallback` и показывается как оценка. Реальный
Google Routes provider подключается через тот же repository interface без
изменения domain/UI.

Если ETA недоступен, объект получает unknown fit; приложение не подменяет ETA
молчаливым нулём.

---

## 8. Time-fit algorithm

### 8.1 Effective window

```
exact:
  effectiveStart = startAtUtc
  effectiveEnd   = endAtUtc

flexible:
  effectiveStart = startAtUtc - flexibilityMinutes
  effectiveEnd   = endAtUtc + flexibilityMinutes
```

Границы включительные.

### 8.2 Event slots

Для каждого slot используется его `candidateId` и собственный travel
estimate:

```
attendanceStart =
  effectiveStart + outboundMinutes + bufferBeforeMinutes

effectiveReturnMinutes =
  includeReturnTrip ? returnMinutes : 0

attendanceEnd =
  effectiveEnd - effectiveReturnMinutes - bufferAfterMinutes
```

`fits`, если slot полностью лежит в
`[attendanceStart, attendanceEnd]`.

Если full fit отсутствует:

```
attendable = intersect(
  [slot.startAtUtc, slot.endAtUtc],
  [attendanceStart, attendanceEnd]
)
```

`partial`, если partial разрешён и длина `attendable` не меньше
`minimumVisitDurationMinutes`. Буферы учитываются и для partial.

Если подходит несколько slots, выбирается full fit с минимальным лишним
запасом; затем лучший partial. Выбранный `slotId` возвращается в evaluation.

### 8.3 Opening hours

1. Определить локальные даты effective window в timezone рынка объекта.
2. Для каждой даты применить `exceptionDate`; при его отсутствии —
   `dayOfWeek`.
3. `isClosedAllDay` даёт пустой интервал.
4. Local interval перевести в UTC. `close < open` означает окончание на
   следующий локальный день.
5. Для каждого непрерывного opening interval:

```
visitStart = max(
  openingInterval.startAtUtc,
  effectiveStart + outboundMinutes
)

visitEnd = min(
  openingInterval.endAtUtc,
  effectiveEnd - effectiveReturnMinutesWithMargin
)

candidateMinutes = max(0, visitEnd - visitStart)
```

6. Использовать максимальный непрерывный `candidateMinutes`. Разрывные
   куски не суммируются.
7. `fits`, если candidate minutes не меньше `durationMinutes`.
8. `partial`, если full fit отсутствует, partial разрешён и candidate
   minutes не меньше `minimumVisitDurationMinutes`.

`effectiveReturnMinutesWithMargin = 0`, когда `includeReturnTrip = false`.
Когда обратная нога запрошена, используется рассчитанный return ETA плюс
safety margin §3; недоступный ETA переводит fit в `unknown`.

### 8.4 Общая классификация

```
TimeFitEvaluation {
  objectId: String
  selectedCandidateId: String?
  selectedSlotId: String?
  timeFitStatus: fits | partial | doesNotFit | unknown
  travelFitStatus: fits | doesNotFit | unknown
  openingStatus: open | closed | unknown
  capacityStatus: available | full | unknown
  requiredMinutes: int?
  availableMinutes: int?
  travelMinutes: int?
  quality: TravelEstimateQuality?
}
```

- `doesNotFit` исключается hard-фильтром;
- `unknown` остаётся во второй группе «Время не подтверждено»;
- unknown не получает `timeFit` boost;
- `openNow = true` исключает closed, а unknown показывает во второй группе;
- `onlyAvailable = true` оставляет только `capacityStatus = available`;
- без `timeWindow` новый time-fit pipeline не меняет существующую выдачу.

---

## 9. Ranking

Accepted ADR 0013 сохраняет базу `geo + freshness`. Текущая реализация:

```
baseScore = 0.65 * geoScore + 0.35 * freshnessScore
```

[ADR 0014](../adr/0014-time-fit-ranking.md) принят: вес берётся из config,
по умолчанию равен `0.20`, ограничивается диапазоном `[0, 0.30]` и защищён
kill switch. При выключенном флаге effective weight равен `0`, но hard-фильтр,
группировка и badges продолжают работать:

```
finalScore =
  (1 - timeFitWeight) * baseScore +
  timeFitWeight * normalizedTimeFitScore
```

Деление на travel minutes и ненормализованные сигналы запрещены.

Zero-result fallback предлагает увеличить окно/радиус или снять строгий
фильтр, но никогда не меняет query без подтверждения пользователя.

---

## 10. Application и UI flow

Search добавляет:

- выбор exact/flexible/anytimeToday;
- start/end и flexibility;
- current location/manual pin;
- walking/driving/transit;
- include return trip;
- chips применённых условий.

После Apply application создаёт immutable `DiscoverQuery v2`. Один и тот же
query используется Results, Map, Feed и Details.

UI показывает:

- «Подходит»;
- «Можно частично»;
- «Время не подтверждено»;
- «Открыто/закрыто/неизвестно»;
- estimated travel marker для `modeled/fallback`;
- выбранный slot.

Analytics:

- `time_window_applied`;
- `time_fit_result_shown`;
- `time_fit_unknown_shown`;
- `time_fit_relaxation_selected`;
- `travel_estimate_failed`.

---

## 11. Serialization и миграции

### DiscoverQuery

`queryVersion` повышается до `2`. `toMap/fromMap` сериализуют
`timeWindow` и `travelContext`.

При чтении v1:

```
timeWindow = null
travelContext = null
queryVersion = 2
```

Если legacy query имеет старые default center/market, одновременно выполнены
условия:

- `marketCityId == rezekne`;
- center точно равен `56.5099/27.3332`;
- `manualAreaSelected == false`,

то defaults мигрируют на Riga из MarketConfig. Явно выбранная пользователем
Rezekne area не перезаписывается.

`anytimeToday` пересчитывается при повторном применении Saved Search в
другой локальный день.

### DiscoverItemModel

`fromMap` использует реальные keys:

- `latitude` / `longitude`;
- `duration_minutes`;
- `capacity`;
- `participants_count`;
- новые availability keys.

Нормализация:

```
duration_minutes absent/null/<=0 -> null
capacity absent/null/<=0         -> null
participants_count absent/null   -> null
participants_count >= 0          -> value, включая явный 0
```

Отдельная schema migration не нужна: целые Discover items сейчас не
персистятся локально.

### CreateDraftModel

В JSON добавляется `schemaVersion = 2` и `marketCityId`.

Legacy v1:

- отсутствующий market ID резолвится один раз по нормализованным
  `country/city`;
- пустой city при `country = Latvia` и сломанном default
  `timezone = Europe/Moscow` резолвится в активный market Riga;
- явная Rezekne резолвится в legacy market ID и не превращается в Riga;
- после получения market ID сломанный `Europe/Moscow` заменяется timezone
  этого market;
- неизвестная location не перезаписывается наугад.

После миграции runtime lookup выполняется только по `marketCityId`.

---

## 12. Точный план файлов

### Новые

- `apps/mobile/lib/app/config/market_config.dart`
- `apps/mobile/lib/app/config/travel_policy_config.dart`
- `apps/mobile/lib/features/discover/domain/entities/geo_point.dart`
- `apps/mobile/lib/features/discover/domain/entities/discover_query.dart` —
  перенос чистой модели из application
- `apps/mobile/lib/features/discover/domain/entities/time_window.dart`
- `apps/mobile/lib/features/discover/domain/entities/time_slot.dart`
- `apps/mobile/lib/features/discover/domain/entities/opening_hours_rule.dart`
- `apps/mobile/lib/features/discover/domain/entities/local_date.dart`
- `apps/mobile/lib/features/discover/domain/entities/time_fit_evaluation.dart`
- `apps/mobile/lib/features/discover/domain/repositories/travel_time_repository.dart`
- `apps/mobile/lib/features/discover/domain/repositories/timezone_repository.dart`
- `apps/mobile/lib/features/discover/domain/usecases/calculate_travel_times_usecase.dart`
- `apps/mobile/lib/features/discover/domain/usecases/apply_time_window_usecase.dart`
- `apps/mobile/lib/features/discover/domain/usecases/calculate_time_fit_score_usecase.dart`
- `apps/mobile/lib/features/discover/data/repositories/travel_time_repository_impl.dart`
- `apps/mobile/lib/features/discover/data/repositories/timezone_repository_impl.dart`
- `apps/mobile/lib/core/id/id_generator.dart` — UUID/ULID generation для
  постоянных slot IDs
- `apps/mobile/lib/features/create/domain/entities/create_availability.dart`
- `apps/mobile/lib/features/create/domain/usecases/validate_create_availability_usecase.dart`

### Изменяемые

- `apps/mobile/lib/app/di/service_locator.dart`
- `apps/mobile/pubspec.yaml`
- `apps/mobile/pubspec.lock`
- `apps/mobile/lib/features/discover/application/queries/discover_query.dart` —
  удаляется после обновления imports
- `apps/mobile/lib/features/discover/application/controllers/discover_feed_controller.dart`
- `apps/mobile/lib/features/discover/application/state/discover_feed_state.dart`
- `apps/mobile/lib/features/discover/application/discover_providers.dart`
- `apps/mobile/lib/features/discover/domain/entities/discover_item_entity.dart`
- `apps/mobile/lib/features/discover/domain/repositories/discover_repository.dart`
- `apps/mobile/lib/features/discover/domain/usecases/get_discover_feed_usecase.dart`
- `apps/mobile/lib/features/discover/data/models/discover_item_model.dart`
- `apps/mobile/lib/features/discover/data/datasources/discover_remote_datasource.dart`
- `apps/mobile/lib/features/discover/data/datasources/discover_preferences_local_datasource.dart`
- `apps/mobile/lib/features/discover/data/repositories/discover_repository_impl.dart`
- `apps/mobile/lib/features/discover/presentation/pages/search_page.dart`
- `apps/mobile/lib/features/discover/presentation/pages/discover_results_page.dart`
- `apps/mobile/lib/features/discover/presentation/pages/discover_map_page.dart`
- `apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart`
- `apps/mobile/lib/features/discover/presentation/widgets/discover_feed_section.dart`
- `apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart`
- `apps/mobile/lib/features/create/data/models/create_draft_model.dart`
- `apps/mobile/lib/features/create/data/datasources/create_local_datasource.dart`
- `apps/mobile/lib/features/create/application/controllers/create_controller.dart`
- `apps/mobile/lib/features/create/application/state/create_state.dart`
- `apps/mobile/lib/features/create/application/create_providers.dart`
- `apps/mobile/lib/features/create/presentation/pages/create_page.dart`

Mock datasource остаётся `discover_remote_datasource.dart`; отдельного
`mock_discover_datasource.dart` не создаётся.

---

## 13. Acceptance criteria

### Query и market

| ID | Проверка | Ожидаемый результат |
|---|---|---|
| Q1 | Новый query | Riga, 56.9496/24.1052, Europe/Riga |
| Q2 | V1 query без time fields | Мигрирует в v2, остальные условия сохранены |
| Q3 | Legacy автоматический Rezekne default | Мигрирует в Riga |
| Q4 | Пользователь вручную выбрал Rezekne | Не перезаписывается |
| Q5 | exact window | Effective window не расширяется |
| Q6 | flexible +30 | Обе границы расширены ровно на 30 минут |
| Q7 | 23:00–01:00 | UTC end больше start, переход суток корректен |
| Q8 | anytimeToday повторно применён завтра | Создана новая UTC-пара |
| Q9 | Локальное время отсутствует из-за DST | Validation error для пользовательского окна |
| Q10 | Opening boundary неоднозначна при DST | Использован консервативный instant |
| Q11 | Close попал в несуществующий DST-gap | Выбран последний валидный instant до gap; интервал не удлинён |
| Q12 | DST-нормализация дала close <= open | Rule invalid, openingStatus unknown, записана telemetry error |

### Data semantics

| ID | Проверка | Ожидаемый результат |
|---|---|---|
| D1 | duration отсутствует/0 | `null`, не «0 минут» |
| D2 | capacity отсутствует/0 | `null`, status unknown |
| D3 | participants отсутствует | `null`, status unknown |
| D4 | participants = 0 | Остаётся `0`, не превращается в unknown |
| D5 | capacity 5, participants 5 | full |
| D6 | capacity 5, participants 4 | available |
| D7 | slots и opening hours одновременно | Validation error |
| D8 | partial без minimum duration | Validation error |

### Event fit

| ID | Проверка | Ожидаемый результат |
|---|---|---|
| E1 | Duration + buffers + travel больше окна | doesNotFit |
| E2 | Сумма точно равна окну | fits |
| E3 | Full не входит, partial разрешён и minimum достигнут | partial |
| E4 | Minimum не достигнут после buffers | doesNotFit |
| E5 | Несколько slots | Выбран лучший slot, возвращён slotId |
| E6 | Разные slot times | Используются отдельные candidateId и travel timing |
| E7 | ETA отсутствует | unknown, не нулевой travel |
| E8 | Provider не подключён | Fallback ETA детерминирован и quality=fallback |
| E9 | includeReturnTrip=false, outbound рассчитан | returnLegStatus=notRequested, returnMinutes=0, fit не вычитает обратную дорогу |
| E10 | includeReturnTrip=true, return ETA недоступен | returnLegStatus=unavailable, returnMinutes/totalMinutes=null, fit=unknown |

### Place fit

| ID | Проверка | Ожидаемый результат |
|---|---|---|
| P1 | opening start позже arrival | visitStart равен opening start |
| P2 | 22:00–02:00 | Интервал через полночь корректен |
| P3 | exceptionDate конфликтует с weekday | Побеждает exception |
| P4 | Обеденный перерыв | Куски не суммируются |
| P5 | Full duration входит | fits |
| P6 | Только minimum partial входит | partial |
| P7 | Ни minimum, ни full не входят | doesNotFit |
| P8 | Return estimate | Добавлен 20%, минимум 5, максимум 20 минут |
| P9 | Provider live response для approximate return | Итоговая quality = modeled |
| P10 | includeReturnTrip=false | Return safety margin не применяется, effective return=0 |

### Filters, ranking и UI

| ID | Проверка | Ожидаемый результат |
|---|---|---|
| U1 | timeWindow отсутствует | Старая выдача и geoFreshness не меняются |
| U2 | timeWindow задан, ranking flag выключен | Hard filter работает, effective ranking weight = 0 |
| U3 | unknown fit | Вторая группа и явный badge |
| U4 | openNow + closed | Объект исключён |
| U5 | openNow + unknown | Вторая группа |
| U6 | onlyAvailable + unknown/full | Объект исключён |
| U7 | Results/Map/Feed | Одинаковый applied query и набор IDs |
| U8 | Zero results | Только предложения relaxation, query сам не меняется |

### Create и миграции

| ID | Проверка | Ожидаемый результат |
|---|---|---|
| C1 | Новый draft | marketCityId=riga, timezone=Europe/Riga |
| C2 | Feature boundaries | Ни Create, ни Discover не импортируют app/config; значения приходят через DI |
| C3 | Legacy Latvia + пустой city + Moscow default | Мигрирует в Riga |
| C4 | Legacy Rezekne | Сохраняет legacy market, timezone Europe/Riga |
| C5 | Неизвестная location | Не перезаписывается наугад |
| C6 | Event-type form | Использует общую Schedule section |
| C7 | Place-type form | Использует общую Opening Hours section |
| C8 | Публикация draft с `loc_*` slot ID | ID заменён постоянным ULID |
| C9 | Create imports | Нет импорта `discover/*`; draft-типы feature-local |
| C10 | Повторное чтение mock feed | Slot IDs стабильны, candidate IDs не меняются |

---

## 14. Тесты и Definition of Done

Добавить/обновить:

- `apps/mobile/test/unit/discover_item_model_test.dart`
- `apps/mobile/test/unit/discover_feed_controller_test.dart`
- `apps/mobile/test/unit/create_draft_migration_test.dart`
- `apps/mobile/test/unit/create_controller_test.dart`
- `apps/mobile/test/unit/time_fit_evaluation_test.dart`
- `apps/mobile/test/unit/travel_time_repository_test.dart`
- `apps/mobile/test/unit/timezone_repository_test.dart`
- `apps/mobile/test/unit/market_config_test.dart`
- `apps/mobile/test/widget/search_page_test.dart`
- `apps/mobile/test/widget/discover_feed_section_test.dart`
- `apps/mobile/test/widget/discover_details_page_test.dart`
- `apps/mobile/test/widget/create_page_test.dart`

Обязательные проверки:

```
flutter analyze
flutter test
git diff --check
```

Slice считается Done только если:

- все acceptance criteria покрыты;
- analyzer — 0 ошибок;
- все тесты зелёные;
- boundary check зелёный;
- `LAUNCH_STATUS.md` отражает фактический статус;
- новый ADR принят до включения ненулевого `timeFitWeight`;
- рабочее дерево не содержит build/cache artifacts.
