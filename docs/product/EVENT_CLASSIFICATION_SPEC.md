# Event Classification Model v2.2.3 — canonical specification

Версия: 2026-08-04 (rev. 2.2.3)
Статус: **Accepted — канонический продуктовый/доменный контракт Recharge.**
Назначение: фасетная классификация Event для Recharge без создания нового
Create-типа и без смешения Event с Place, Route, Scenario, Quick Plan,
Bookable Session или Find People.

Решение владельца продукта: спецификация принята 2026-08-04 как источник
истины для дальнейшего развития Event ecosystem. Все новые Event, Booking,
inventory, provider и admission slices обязаны расширять эту модель, а не
создавать параллельный контракт.

Принятие документа не означает, что весь контракт уже реализован, и само по
себе не разрешает production backend, Payments, Firebase или provider
integrations. Accepted ADR имеют высший приоритет. Approved ECL slice может
реализовать ограниченное подмножество этой модели, но не может молча менять её
инварианты; конфликт блокирует slice до явного согласования новой ревизией или
ADR.

Связанные источники истины:

- [EVENT_CREATE_SPEC.md](EVENT_CREATE_SPEC.md) — Creator UX и form flow;
- [EVENT_CREATE_CORE_SCHEDULE_SLICE_SPEC.md](EVENT_CREATE_CORE_SCHEDULE_SLICE_SPEC.md)
  — уже реализованное local/mock подмножество EVT-CRT-01;
- [CATEGORY_SYSTEM.md](CATEGORY_SYSTEM.md) — каноническая тематическая
  таксономия v1.4.3;
- [VISION.md](VISION.md) — продуктовый контекст Create Hub.

При расхождении по classification/admission/inventory semantics действует эта
спецификация; `EVENT_CREATE_SPEC.md` отвечает за UX/form flow и должен быть
согласован с ней в ECL-00. Тематическая таксономия остаётся в Category System
v1.4.3 и здесь не дублируется.

---

## 0. Цель

Модель должна одинаково точно описывать:

- локальную игру в мафию на 12 участников;
- любительский футбольный матч;
- регулярный разговорный клуб;
- мастер-класс;
- онлайн-лекцию;
- городской фестиваль;
- концерт со свободным танцполом;
- концерт или матч с секторами, рядами и местами;
- импортированное событие внешнего билетного/booking-провайдера.

При этом классификация не должна превращаться в один плоский enum, где тема,
формат, способ входа, цена и организация кодируются одним значением.

## 1. Границы Event

Event — публикуемая сущность с хотя бы одной определённой будущей occurrence:
конкретным проведением с датой/временем либо валидным all-day интервалом.

### 1.1. Event не является

- **Place** — постоянным местом или бизнесом;
- **Route** — непрерывным треком с anchors/segments/GPX/elevation/POI;
- **Scenario** — самостоятельным планом из независимых остановок;
- **Quick Plan** — лёгким personal/invited utility-flow;
- **Bookable Session** — постоянно доступной услугой/ресурсом с выбором
  произвольного слота;
- **Find People** — неформальным поиском компании без полноценного
  организованного события;
- **Collection/Guide** — подборкой объектов;
- публичным анонсом без подтверждённой occurrence.

### 1.2. Правила спорных границ

| Ситуация | Канонический тип |
|---|---|
| «Мафия каждую пятницу, 12 мест, организатор и правила» | Event |
| «Ищу троих поиграть сегодня в карты» | Find People |
| «Корт можно бронировать каждый день в разных слотах» | Bookable Session |
| «Турнир на этом корте 18 августа» | Event с `venueRef` |
| «Маршрут забега» | Route; Event хранит только `routeRef` |
| «Экскурсия 18 августа в 12:00» | Event |
| «Экскурсии доступны каждый день каждые 30 минут» | Bookable Session либо Event occurrences, согласно продукту поставщика |
| «Фестиваль с программой» | Event + Program Items |
| «План посещения фестиваля пользователем» | Scenario |
| «Концерт, дата будет объявлена» | Draft до появления даты; не обычный published Event |
| «Фестиваль анонсирован, даты нет, идёт сбор интереса/blind-продажа» | Не Event; внешний discovery candidate либо будущий отдельный продукт (§1.3) |

§1.2 является нормативным источником решений `Event vs adjacent aggregate`.
§6.2 — тематическая проекция и пояснение этой таблицы, а не второй источник
правил. При расхождении применяются инварианты §1 и таблица §1.2; обе таблицы
должны обновляться в одной ревизии.

### 1.3. Будущая граница для анонса без даты

Публичный материал без подтверждённой occurrence не является Event. В рамках
этой спецификации он:

- остаётся непубликуемым Event draft; либо
- существует как внешний provider/discovery candidate вне Event aggregate и
  без Event availability/Booking semantics.

Отдельная публичная authorable-сущность «Анонс», её Create flow, Discover
поверхность, подписки и конверсия в Event **не входят** в текущие десять
Create-типов. Такое расширение требует самостоятельных product spec,
Accepted ADR и Approved slice. Эта спецификация не резервирует для него
runtime entity, Publisher flow или internal ticketing.

## 2. Непересматриваемые инварианты

1. Классификация фасетная: независимые оси не кодируют друг друга.
2. Архетип описывает механику, Category System — содержание.
3. Бизнес-критичные оси используют закрытые versioned enum.
4. Описательные фасеты используют канонические справочники, а не свободные
   технические строки.
5. У Event ровно один `PublisherRef {type: user | page, id}`.
6. Соорганизатор, host, venue, promoter и provider не являются дополнительными
   publishers.
7. Все entity relations используют стабильные ID. Отображаемый текст не
   становится связью.
8. Series остаётся Event с recurrence rule и occurrences, а не новым
   aggregate.
9. Booking, Payment, Attendance, Refund и payout ledger — отдельные сущности,
   не вложенные списки Event draft.
10. Inventory изменяется только авторитетным источником и атомарными
    операциями. UI не является источником истины.
11. External provider остаётся источником истины для своих prices, inventory,
    holds, bookings, cancellations и refunds.
12. Unknown не превращается в free, zero или available.
13. `soldOut` — вычисляемое availability-состояние, а не Event lifecycle.
14. Event не хранит Route GeoJSON/GPX и не поглощает Route aggregate.
15. Scraping и неавторизованные automation не являются production source.
16. Provider secrets никогда не находятся во Flutter, draft JSON, analytics
    или логах.
17. Классификация Event не создаёт новый Create-тип или публичную сущность.

## 3. Канонические оси

```text
Event
├── classification
│   ├── eventArchetype
│   ├── participationModes
│   └── mainCategoryId / subcategoryId / tags
├── occurrence model
│   ├── eventFormat
│   ├── scheduleMode / recurrence / occurrences
│   ├── physicalLocation
│   └── onlineAccess
├── admission
│   ├── admissionMode
│   ├── registrationMode
│   ├── confirmationMode
│   ├── eligibilityRules
│   ├── guestPolicy
│   └── waitlistPolicy
├── commerce
│   ├── pricingMode? / pricingModel
│   ├── paymentCollectionMode
│   ├── ticketTypes
│   └── refundPolicyRef
├── inventory
│   ├── capacityMode
│   ├── inventoryAuthority
│   ├── inventoryShapes
│   └── inventoryPools
├── governance
│   ├── publisherRef
│   ├── eventRelations
│   ├── lifecycleStatus
│   ├── moderationStatus
│   └── visibility
└── provenance
    ├── sourceRecords
    ├── fieldAuthority
    ├── freshness
    └── verification
```

## 4. Архетип события (`eventArchetype`)

Ровно одно обязательное значение. Архетип отвечает на вопрос: **какова
основная механика происходящего?**

### 4.1. Зрелища и контент

| Код | Механика | Примеры |
|---|---|---|
| `performance` | Подготовленное представление | концерт, театр, стендап, опера, цирк, балет |
| `screening` | Совместный просмотр | кино, премьера, спортивная трансляция, watch party |
| `exhibition` | Посещение экспозиции | выставка, gallery opening, инсталляция |
| `open_stage` | Участники могут выступать | karaoke, open mic, jam session, poetry slam |
| `meet_greet` | Встреча с персоной | автограф-сессия, встреча с автором/артистом |

### 4.2. Знания и общение

| Код | Механика | Примеры |
|---|---|---|
| `talk` | Один или несколько спикеров передают материал | лекция, презентация, вебинар |
| `discussion` | Структурированный обмен мнениями | дебаты, панель, книжный клуб, группа поддержки |
| `conference` | Многосекционная профессиональная программа | конференция, форум, конгресс, саммит |
| `networking` | Целенаправленное создание связей | бизнес-завтрак, speed networking |
| `social_meetup` | Неформальное общение | языковой клуб, meetup, speed dating |

### 4.3. Игра и соревнование

| Код | Механика | Примеры |
|---|---|---|
| `hosted_game` | Ведущий/организатор проводит игру | мафия, квиз, настольные и карточные игры, LAN party |
| `open_play` | Участники собираются играть вместе | любительский футбол, padel, volleyball pickup |
| `competition` | Есть результат, места или победитель | турнир, забег, dance battle, hackathon, game jam |

### 4.4. Обучение и практика

| Код | Механика | Примеры |
|---|---|---|
| `class_session` | Ведущий обучает или тренирует | тренировка, урок, разговорный клуб |
| `workshop` | Участник создаёт/осваивает результат | мастер-класс, кулинария, керамика, plein air |
| `retreat_camp` | Ограниченная по датам cohort-программа | ретрит, лагерь, bootcamp с проживанием |
| `wellness_session` | Организованная wellness-практика | медитация, breathwork, sound healing, баня-сессия |

`retreat_camp` описывает участие в программе. Личный маршрут поездки остаётся
Scenario; физический трек остаётся Route.

### 4.5. Еда и вкус

| Код | Механика | Примеры |
|---|---|---|
| `tasting` | Дегустация с программой | вино, кофе, сыры, блюда |
| `shared_meal` | Организованный совместный приём пищи | тематический ужин, brunch meetup, supper club |

### 4.6. Праздник и развлечение

| Код | Механика | Примеры |
|---|---|---|
| `party` | Социально-развлекательная программа | DJ party, клубная ночь, afterparty |
| `celebration` | Празднование события/даты | Новый год, Jāņi, свадьба, юбилей |
| `festival` | Несколько программных элементов | музыкальный, городской, кинофестиваль |

### 4.7. Торговля и презентация

| Код | Механика | Примеры |
|---|---|---|
| `market_fair` | Несколько продавцов/стендов | craft market, flea market, expo |
| `auction` | Продажа через ставки | арт-аукцион, charity auction |
| `launch_promotion` | Представление продукта/проекта | product launch, demo day, grand opening |
| `open_day` | Drop-in посещение в заданном окне | школа, студия, коворкинг, производство |

### 4.8. Движение и природа

| Код | Механика | Примеры |
|---|---|---|
| `tour_excursion` | Группа следует программе ведущего | экскурсия, walking tour, day trip |
| `outdoor_gathering` | Встреча на открытом воздухе | прогулка, пикник, birdwatching, наблюдение за звёздами |

### 4.9. Общество и участие

| Код | Механика | Примеры |
|---|---|---|
| `community_action` | Совместное публичное действие | уборка парка, посадка деревьев, шествие, памятная акция |
| `volunteering` | Выполнение волонтёрской работы | приют, food bank, помощь на событии |
| `fundraiser` | Сбор средств является основной механикой | charity dinner, donation event, телемарафон |
| `family_program` | Программа построена для семьи/детей | детский праздник, family sports day |
| `ceremony` | Формальная церемония | награждение, официальный приём, выпускной, служба |
| `other` | Исключительная механика | обязательная модерация и аналитический сигнал |

Всего: **34 значения**, включая `other`; 33 содержательных архетипа.
Новый архетип добавляется только через revision документа, когда значимая доля
событий стабильно попадает в `other` по одной и той же механике.

### 4.10. Спорные случаи

| Случай | Маппинг |
|---|---|
| Hackathon, game jam | `competition` |
| Webinar | `talk` + `eventFormat=online` |
| Speed dating | `social_meetup` + `dating_singles` |
| Karaoke с выступлением гостей | `open_stage` |
| LAN party | `hosted_game` |
| Частная свадьба/день рождения | `celebration` + `visibility=private` |
| Группа поддержки | `discussion` |
| Митинг/парад | `community_action` |
| Watch party | `screening` |
| Salsa social | `party` или `open_play` по основной механике; тема `dance` |

## 5. Роль посетителя (`participationModes`)

Одно основное значение и до трёх дополнительных:

`watch` · `attend` · `play` · `compete` · `perform` · `practice` ·
`learn` · `create` · `meet_people` · `date` · `visit` · `explore` ·
`eat_drink` · `shop` · `support` · `volunteer` · `travel`

Основной mode влияет на copy и ranking, дополнительные — на фильтры. Ни один
participation mode не создаёт capability и не заменяет category.

## 6. Тема

Источник истины — Category System v1.4.3:

```text
mainCategoryId
subcategoryId
tags[]
```

Правила:

- категория и архетип независимы;
- `subcategoryId` обязателен, если категория имеет подкатегории;
- системные tags выбираются из канонического словаря;
- свободный текст остаётся description, а не новым tag/category;
- необычная комбинация не блокируется без отдельного явного правила;
- `other` не используется как удобный default.

### 6.1. Полнота тематического покрытия

Event использует все пользовательские группы Category System v1.4.3; ни одна
из них не требует отдельного Event-типа:

`music_nightlife` · `comedy_theatre_performance` · `cinema_screenings` ·
`art_culture_museums` · `education_talks` · `business_networking` ·
`workshops_masterclasses` · `language_social_learning` · `food_drinks` ·
`games_indoor` · `sport` · `dance` · `outdoor_nature_walking` ·
`water_activities` · `winter_seasonal` · `travel_tours` · `family_kids` ·
`pets_animals` · `community_charity` · `markets_fairs` ·
`holidays_seasonal` · `wellness_recharge` · `adrenaline_entertainment` ·
`attractions` · `auto_moto` · `geek_tech` · `dating_singles`.

Сервисная группа `other` также технически поддерживается, но требует
обоснования и moderation (§19). Таким образом, покрыты все 27 предметных
групп и сервисная группа `other`, а детализация остаётся в полном наборе
подкатегорий Category System v1.4.3 (сейчас 530). Числа являются версионной
характеристикой справочника, а не дублируемым enum внутри Event.

Тема может классифицировать Event только при выполнении основного инварианта:
есть организованное происходящее с хотя бы одной определённой occurrence.
Категория сама по себе никогда не выбирает aggregate или Create-тип.

### 6.2. Матрица допустимости Event

Эта матрица поясняет нормативные границы §1.2 на разных темах и не может их
переопределять.

| Что создаёт пользователь | Каноническая сущность | Пример на одной теме |
|---|---|---|
| Организованное происходящее в определённое время | Event | музейная ночь, тематический ужин, футбольный турнир |
| Постоянное место, бизнес или достопримечательность | Place | музей, ресторан, стадион |
| Услуга/ресурс с выбираемыми повторяемыми слотами | Bookable Session | столик, корт, массаж, ежедневная экскурсия |
| Неформальный поиск участников без организованного события | Find People | найти игроков на сегодня |
| Непрерывный географический трек | Route | маршрут забега или похода |
| План из независимых остановок и логистики | Scenario | план культурного дня или поездки |
| Личный короткий план без публикации в каталоге | Quick Plan | куда сходить компанией вечером |
| Подборка объектов без occurrence | Collection/Guide, если утверждён соответствующий продукт | список летних фестивалей или семейных мест |

Если объект сочетает несколько строк, агрегаты связываются по ID: например,
Event турнира ссылается на Place стадиона и при необходимости на Route трассы,
но не копирует их модели. Эта матрица ограничивает Event по механике, а не по
теме, поэтому новые темы не требуют расширять Create Hub.

## 7. Формат проведения (`eventFormat`)

Канонический enum сохраняется:

- `offline`;
- `online`;
- `hybrid`.

### 7.1. Фасеты физического проведения

`indoor` · `outdoor` · `moving` · `multiVenue` · `seated` · `standing` ·
`mixedSeating` · `weatherDependent`

Это фасеты, а не новые значения `eventFormat`.

### 7.2. Online access

Канонический access mode:

- `publicLink`;
- `internalBooking`;
- `externalRegistration`.

Provider-neutral metadata:

```text
onlineAccess
  providerRef?
  platformDisplayName?
  linkDelivery: immediate | afterConfirmation | beforeOccurrence
  deliveryOffsetMinutes?
  recordingPolicy: none | included | separateAccess | unknown
  streamLanguageCodes[]
  protectedAccessRef?
```

Секретная join-ссылка хранится только через encrypted reference и никогда не
попадает в публичную projection.

## 8. Расписание

Канонический `scheduleMode`:

- `oneTime`;
- `multiDate`;
- `recurring`.

Ортогональные поля:

```text
allDay: bool
startAtUtc
endAtUtc
timezoneId
recurrenceRule?
occurrences[]
occurrenceOverrides[]
admissionWindows?
```

`admissionWindows` — ограниченные окна входа внутри bounded Event date range;
они не заменяют Place opening hours:

```text
AdmissionWindowRule
  weekday?
  localStartMinute
  localEndMinute
  validFromLocalDate
  validUntilLocalDate
  exceptionLocalDates[]
```

Правила:

- multi-day Event — `oneTime` occurrence, у которой local start/end лежат в
  разных календарных днях;
- all-day — boolean, а не schedule mode;
- series — тот же Event с recurrence rule и стабильными occurrence IDs;
- discrete нерегулярные даты используют `multiDate`;
- расписание выставки в пределах date range описывается recurrence/occurrences
  и admission windows, а не Place opening hours;
- Event без подтверждённой даты остаётся draft и не участвует в Discover;
- изменение series поддерживает scopes `this occurrence`, `this and future`,
  `entire series`;
- Booking и inventory всегда ссылаются на конкретную occurrence, если Event
  имеет больше одного проведения.

## 9. Локация

```text
physicalLocation
  kind: placeRef | address | meetingPoint | areaOnly
  placeId?
  address?
  geo?
  meetingPoint?
  areaId?
  disclosure: public | afterConfirmedAccess

eventVenueLinks[]
  id
  placeId
  role: primaryVenue | stage | room | checkpoint | auxiliary

routeRef?
```

Правила:

- `offline/hybrid` требуют валидную физическую локацию;
- `online` не хранит фиктивный адрес;
- `routeRef` указывает на отдельный Route aggregate;
- Event не хранит GPX/GeoJSON Route;
- multi-venue использует стабильные Place/venue IDs;
- скрытая локация выдаётся только после подтверждённого access state;
- `areaOnly` допустим для раннего публичного описания, но точка должна
  быть известна авторитетному backend до проведения и доступна участникам
  согласно policy.

## 10. Admission и доступ

Access разделён на независимые оси.

### 10.1. Основная механика (`admissionMode`)

- `openEntry` — можно прийти без регистрации;
- `rsvp` — регистрация участия;
- `booking` — резервируется ограниченное место/квота;
- `application` — пользователь подаёт заявку;
- `ticket` — требуется билет;
- `teamRegistration` — регистрируется команда.

### 10.2. Где регистрируется пользователь (`registrationMode`)

- `none`;
- `external`;
- `internal`.

### 10.3. Подтверждение (`confirmationMode`)

- `none` — только для `openEntry`;
- `instant`;
- `manualApproval`;
- `lottery`;
- `providerManaged` — результат определяет внешний provider.

`lottery` требует окна заявок и детерминированного/auditable результата.
`providerManaged` не позволяет Recharge показывать confirmation без verified
callback или provider lookup.

### 10.4. Eligibility rules

Комбинируемый typed list:

- `invitation`;
- `accessCode`;
- `membership`;
- `allowlist`;
- `qualification`;
- `accreditation`;
- `ageRequirement`;
- `waiver`.

Eligibility не является visibility или pricing mode.

### 10.5. Waitlist

```text
waitlistPolicy
  enabled
  promotionMode: organizerManaged | fifoAutomatic
  offerTtlMinutes?
  paymentDeadlineMinutes?
```

Waitlist допустим только при конечном inventory. Promotion создаёт
ограниченный hold, а истечение возвращает квоту атомарно.

### 10.6. Guest policy

```text
guestPolicy
  mode: none | plusOne | plusN | namedGuestsOnly
  maxGuests?
  countsAgainstCapacity: true
```

Гости всегда учитываются в capacity. `countsAgainstCapacity=false` допустим
только для явно отдельной неограниченной observer-категории.

### 10.7. Onsite admission

```text
onsiteAdmissionPolicy
  allowed
  salesAtDoor
  registrationAtDoor
  subjectToAvailability
```

Door admission не отменяет общий inventory и не создаёт второй список
участников.

### 10.7a. Опциональный RSVP при свободном входе

Для открытого события организатор может предложить пользователю выразить
интерес и получить напоминание, не превращая это действие в регистрацию:

```text
interestPolicy
  optionalRsvpEnabled: bool
  reminderConsentRequired: true
  createsBooking: false
  reservesInventory: false
  registrationAtDoorRequired: false
```

Такой RSVP — только interest/reminder intent. Он не подтверждает участие, не
занимает место, не влияет на availability и не попадает в `My Bookings`.
Название кнопки в UI не должно обещать бронь. Если вместимость конечна и
пользователю гарантируется место, используется обычный `rsvp` или `booking`
с inventory, а не `openEntry`.

### 10.8. Attendance policy — немонетарная защита от no-show

Бесплатные и дешёвые события с конечным capacity (мафия, настолки,
воркшопы) страдают от no-show. До появления Payments-slice защита строится
без денег:

```text
attendancePolicy
  reconfirmationRequired: bool
  reconfirmationOpensHoursBefore: N      # окно открытия
  reconfirmationDeadlineHoursBefore: M   # дедлайн, M < N
  autoReleaseOnMissedReconfirm: bool
  cancellationDeadlineHoursBefore?
```

Правила:

- применимо только при `registrationMode=internal` и конечном inventory;
- участник получает запрос на переподтверждение в окне [N..M] часов до
  начала; при `autoReleaseOnMissedReconfirm=true` неподтверждённая бронь
  атомарно возвращается в inventory и триггерит waitlist promotion (§10.5)
  со стандартным hold TTL;
- auto-release — это отмена Booking с reason code `missedReconfirmation`,
  а не отдельный lifecycle;
- история reconfirmation хранится только как scoped Booking audit и события
  уведомлений с утверждённым сроком retention;
- эта спецификация **не создаёт** межсобытийный reliability profile, risk
  score или автоматические ограничения пользователя. Любое такое решение
  требует отдельной Trust/Risk и privacy/fairness-спецификации с правом на
  объяснение и обжалование, retention policy и anti-discrimination review;
- организатор может видеть агрегированную статистику конкретного события
  только в отдельном Insights slice, без индивидуального скоринга.

#### Единый платформенный лимит активных внутренних броней

До появления персональных Trust/Risk-механизмов Recharge может ограничивать
количество одновременно удерживающих capacity внутренних броней одинаковым
правилом для всех пользователей:

```text
platformBookingConcurrencyPolicy
  scope: internalCapacityHoldingBookings
  maxConcurrentBookings: N
  appliesUniformly: true
  countingRuleRef
```

`countingRuleRef` разрешается в versioned provider-neutral catalog внутри
Booking platform-policy config. Source of truth, schema, migrations и
rollback этого каталога определяются Approved ECL-03 Booking specification;
сам ref не хранится в Event или Event draft.

Это platform policy, а не поле Event и не характеристика пользователя:

- учитываются только внутренние Booking/holds, которые в данный момент
  резервируют конечный inventory; waitlist без hold не учитывается;
- отмена, отказ, expiry, auto-release или завершение перестают учитываться
  атомарно с освобождением inventory;
- значение `N` и counting rule являются versioned configuration и одинаково
  применяются ко всем пользователям в одном launch scope;
- лимит не зависит от no-show history, категории, цены, предполагаемой
  надёжности или иных персональных признаков;
- UI показывает лимит и причину отказа до финального подтверждения; silent
  restriction запрещён;
- индивидуальные исключения и автоматические overrides отсутствуют; изменение
  `N` или counting rule применяется ко всему соответствующему launch scope.

**Known limitation:** reconfirmation, auto-release и единый concurrency cap
снижают потерю квоты, но не устраняют no-show полностью. Персональные меры,
поведенческий скоринг и разные лимиты по предполагаемой надёжности остаются
вне scope до отдельной Trust/Risk specification.

Депозит, card authorization hold или иной денежный commitment не относится к
классификации Event и не маскируется под `pricingMode=free`. Он возможен лишь
в отдельном Payments slice с явной пользовательской стоимостью/условиями,
PSP semantics, refund/expiry policy и юридической проверкой.

### 10.9. Auxiliary admission tracks

Основной `admissionMode` описывает главный поток посетителей. Параллельные
служебные потоки — пресса, волонтёры, вендоры, staff — оформляются
отдельными треками, а не перегрузкой eligibility:

```text
auxiliaryAdmissionTracks[]
  id
  kind: accreditation | volunteer | vendor | staff | performerGuest
  admissionMode: application | booking
  registrationMode: internal | external
  confirmationMode: manualApproval | providerManaged
  eligibilityRules[]          # например accreditation или invitation
  applicationWindow?
  inventoryPoolRef?          # своя квота в общем ledger
```

Правила:

- треки не видны в основном admission UI события; доступ — по отдельной
  ссылке/форме;
- если трек потребляет конечную вместимость площадки, его квота — отдельный
  pool в том же атомарном inventory ledger, не второй источник истины;
- staff/performer, не проходящие visitor admission, могут моделироваться
  workforce/access-credential reference вне Booking; auxiliary track не
  обязан искусственно превращать их в посетителей;
- участники треков не входят в публичную статистику посетителей;
- простой случай «нужна аккредитация как условие входа в основной поток»
  по-прежнему выражается eligibility rule `accreditation` (§10.4) без
  создания трека.

## 11. Видимость

- `public` — участвует в Search/Map/Feed после moderation;
- `unlisted` — доступен по стабильной ссылке;
- `private` — доступен согласно invitation/allowlist/membership/code policy.

Visibility не определяет цену, регистрацию или раскрытие отдельных секретных
полей.

## 12. Цена и оплата

### 12.1. `pricingMode`

Сохраняется канонический enum:

- `free`;
- `fixed`;
- `ticketTypes`;
- `donation`.

### 12.2. Pricing details

```text
pricingModel: perPerson | fixedGroup | fixedTeam | fixedTable
price: Money?
donationPolicy?
membershipBenefitRef?
priceKnowledge: known | unknown
priceDisplay: exact | from | range | providerConfirmedAtCheckout
externalPricePolicy: informational | providerSynced
```

Правила:

- для manual/internal Event Creator обязан выбрать pricing mode;
- импортированное событие без цены получает `priceKnowledge=unknown`, но не
  фиктивный `pricingMode=free`;
- для такого external record `pricingMode` временно отсутствует до provider
  confirmation; это additive contract migration и не меняет текущие draft
  defaults молча;
- `free` хранит `price=null`;
- `fixed` хранит положительный Money;
- `ticketTypes` использует inventory-linked тарифы;
- `donation` хранит suggested/minimum отдельно;
- membership benefit — entitlement/discount, а не отдельный pricing mode;
- `priceFrom` — presentation-модификатор, а не pricing mode.

### 12.3. `paymentCollectionMode`

Одно авторитетное значение:

- `none`;
- `onsite`;
- `external`;
- `internal`.

Поддерживаемые способы оплаты могут быть списком provider capabilities, но не
заменяют `paymentCollectionMode`.

### 12.4. Refund

Event хранит `refundPolicyRef`; фактические Refund records находятся в
Payments domain. External checkout показывает provider policy и не обещает
Refund от Recharge.

## 13. Вместимость и inventory

### 13.1. Capacity mode

- `known` — положительный конечный лимит;
- `unknown` — лимит/остаток не подтверждён;
- `unlimited` — явное отсутствие лимита.

### 13.2. Inventory authority

- `none` — inventory не ведётся;
- `recharge` — Recharge является источником истины;
- `externalProvider` — источник истины внешний provider.

### 13.3. Inventory shapes

Одна основная shape и допустимые дополнительные:

- `generalCapacity`;
- `sharedTicketPool`;
- `separateTicketPools`;
- `zones`;
- `assignedSeating`;
- `teamSlots`;
- `participantRoles`;
- `roleBalancedSlots`;
- `tableInventory`;
- `timeSlotInventory`.

### 13.3a. Channel binding для hybrid

Каждый inventory pool имеет привязку к каналу:

```text
channel: onsite | online | any
```

Правила:

- `hybrid` Event с конечным физическим capacity обязан иметь явный bounded
  onsite pool; конечный online capacity также имеет собственный online pool,
  а unlimited обозначается явно;
- общий коммерческий entitlement/price pool допустим поверх каналов, только
  если канал выбирается и резервируется до или атомарно с Booking; такой pool
  не может быть единственным ограничителем физической вместимости;
- `channel=any` допустим для неёмкостных entitlement pools или inventory,
  который действительно не ограничен каналом; он не заменяет bounded onsite
  pool;
- availability projection считается по каналу: offline может быть soldOut
  при доступном online;
- для `offline` и `online` Event поле вырождается в единственный канал и в
  UI не показывается.

### Общие правила shapes

- `externalProvider` не является inventory shape;
- assigned seating может комбинироваться с zones;
- time slots могут иметь собственную general capacity;
- роли используют нейтральные domain codes: player, goalkeeper, host,
  leader/follower и другие канонические role IDs;
- чувствительные eligibility-ограничения не кодируются названием inventory
  role без отдельной policy/legal basis;
- shared pool не суммируется повторно через ticket types;
- `currentParticipants` вычисляется только из подтверждённых Booking/provider
  sync;
- oversell и процентное overbooking запрещены;
- host-reserved/offline guest места входят в тот же inventory ledger.

### 13.4. Availability projection

Публичные состояния:

- `available`;
- `lowAvailability`;
- `soldOut`;
- `waitlistAvailable`;
- `registrationClosed`;
- `cancelled`;
- `unknown`;
- `stale`.

Это projection из occurrence, inventory, registration window и freshness, а
не Event lifecycle enum.

### 13.5. Discover-активность

Runtime-симметрия к правилу публикации (acceptance 7):

- published Event, у которого не осталось **ни одной будущей не-cancelled
  occurrence** (все прошли, все отменены, или единственная отменена),
  автоматически исключается из Search/Map/Feed;
- прямая ссылка продолжает работать и показывает состояние `cancelled`
  или `completed`;
- lifecycle при этом **не меняется**: это projection `discoverEligible:
  false`, не переход в `archived`;
- добавление, перенос или замена occurrence создаёт versioned material
  revision согласно Event Create policy;
- Event возвращается в Discover только после прохождения применимой revision/
  moderation policy. Projection не является обходом модерации и сам по себе
  не одобряет изменённое расписание.

## 14. Audience requirements

Typed facets:

- age min/max;
- children/family policy;
- languages;
- newcomer-friendly;
- skill min/max per activity/sport;
- team composition;
- accessibility amenities;
- membership requirement;
- dress/equipment requirements;
- pet policy;
- sobriety-friendly;
- safety information;
- waiver/insurance/medical-document requirement.

Чувствительные ограничения требуют отдельной policy, legal basis, moderation
и локализованного объяснения. Они не используются как свободные ranking tags.

## 15. Publisher, организаторы и роли

### 15.1. Publisher

```text
publisherRef
  type: user | page
  id
```

У Event ровно один PublisherRef. Admin, provider, venue или sponsor не могут
стать publisher автоматически.

### 15.2. Event relations

```text
eventRelations[]
  id
  role: organizer | coOrganizer | host | venue | promoter |
        ticketProvider | paymentProvider | sponsor | performer | speaker |
        trainer | guide
  targetRef
  verificationStatus
  displayOrder?
```

`targetRef` — typed stable entity/provider reference. Неверифицированный
display credit хранится отдельно:

```text
unlinkedCredits[]
  displayName
  role
  claimStatus
```

Он не считается identity relation и не выдаёт capabilities.

### 15.3. Page profile

Organizational profile Professional Page может описывать игровой/спортивный
клуб, venue, business, promoter, NGO, institution, municipality, brand,
ticketing/travel/wellness provider и другие профили. Это metadata отдельной
Page-спецификации, а не Event capability.

### 15.4. Hosting model

`hostingModel` — опциональная аналитическая projection, а не источник
полномочий:

`selfHosted` · `pageHosted` · `venueHosted` · `coHosted` · `promoted` ·
`providerImported` · `communityHosted` · `institutionHosted`

Series не требует отдельного `seriesHosted`: это свойство schedule.

## 16. Program Items

Допустимы для festival, conference, multi-day и multi-venue Event:

```text
ProgramItem
  id
  title
  kind: act | session | screening | activity | break
  startAtUtc
  endAtUtc
  venueLinkId?
  performerRefs[]
  unlinkedCredits[]
  description?
  childEventRef?
```

Program Item:

- не является Scenario stop;
- не содержит полноценный вложенный Booking/Payment aggregate;
- использует stable IDs для stage/room/venue;
- становится отдельным child Event или Bookable Session, если имеет
  независимые visibility, access, inventory, pricing и booking lifecycle;
- child Event имеет собственный PublisherRef и явный `parentEventRef`.

## 17. Lifecycle, moderation и operational state

Независимые оси сохраняются по `EVENT_CREATE_SPEC`.

### 17.1. Event lifecycle

`draft` · `pending_review` · `published` · `archived` · `hidden` · `deleted`

### 17.2. Moderation

`none` · `pending` · `approved` · `rejected`

### 17.3. Visibility

`public` · `unlisted` · `private`

### 17.4. Occurrence

Occurrence хранит `scheduled | cancelled`. Завершённость выводится из end time
и grace period. Reschedule — versioned material edit/override с предыдущим и
новым временем, уведомлением и audit, а не новый Event lifecycle. Sold-out
вычисляется availability projection.

## 18. Source, authority и дедупликация

### 18.1. Source record

```text
EventSourceRecord
  id
  origin: manual | providerImported | apiSynced
  providerRef?
  externalTenantId?
  externalEventId?
  externalOccurrenceId?
  fetchedAt?
  expiresAt?
  verificationStatus: unverified | providerVerified |
                      organizerClaimed | staffVerified
```

`scraped` не является разрешённым production origin. Неавторизованные данные
могут существовать только во внешнем discovery-review процессе и не
публикуются как Event без подтверждённого legal/source contract.

### 18.2. Уникальность provider records

```text
(providerRef, externalTenantId, externalEventId, externalOccurrenceId)
```

Повторная синхронизация выполняет idempotent upsert.

### 18.3. Field authority

Для внешнего события поля имеют владельца:

```text
providerOwned:
  schedule, prices, ticket types, inventory, seat status,
  booking URL, cancellation/refund status

rechargeOverlay:
  Category System mapping, localized editorial summary,
  recommendation facets, Scenario suitability
```

Provider sync не перезаписывает Recharge overlay. Recharge UI не позволяет
редактировать provider-owned operational fields.

### 18.4. Duplicate candidates

Дата/venue/title/performer overlap создают только `DuplicateCandidate` с
confidence и evidence. Автоматический fuzzy merge запрещён.

Merge выполняется:

- по общей авторитетной provider identity; либо
- после moderation/organizer confirmation;
- с сохранением каждого source record и field provenance;
- без автоматической смены PublisherRef;
- без выдачи capabilities через organizer claim.

## 19. Матрица кросс-валидации

| # | Правило |
|---|---|
| 1 | `eventFormat=online` запрещает физические format facets и требует online access |
| 2 | `eventFormat=hybrid` требует физическую location и online access |
| 3 | `eventFormat=offline` не публикует online secret/link |
| 4 | `registrationMode=external` требует safe HTTPS handoff или provider ref |
| 5 | `registrationMode=internal` требует соответствующей capability/readiness |
| 6 | `admissionMode=openEntry` требует `registrationMode=none`; опциональный интерес/напоминание моделируется только через `interestPolicy` (§10.7a), без Booking и reservation |
| 7 | `confirmationMode=manualApproval` допустим для internal application/booking |
| 8 | `confirmationMode=lottery` требует application window и auditable selection |
| 9 | `confirmationMode=providerManaged` требует external registration и provider disclosure |
| 10 | Waitlist требует конечный inventory и internal lifecycle либо verified provider support |
| 11 | `pricingMode=free` требует `paymentCollectionMode=none`; денежный депозит/authorization hold не входит в эту классификацию и требует отдельного Payments slice |
| 12 | `pricingMode=fixed` требует положительный Money |
| 13 | `pricingMode=ticketTypes` требует ticket definitions и inventory/provider authority |
| 14 | Internal paid flow требует PSP/KYC/KYB/refund readiness |
| 15 | External checkout не создаёт Recharge Payment status без verified callback/lookup |
| 16 | `inventoryAuthority=externalProvider` требует provider ref и freshness |
| 17 | Assigned seating без provider hold/authoritative inventory показывается только как external handoff |
| 18 | Multi-date/recurring Booking всегда ссылается на occurrence ID |
| 19 | `routeRef` допустим, но Event не хранит Route geometry |
| 20 | Hidden location требует подтверждённый non-open access flow |
| 21 | Private visibility требует eligibility/access policy |
| 22 | `eventArchetype=other` требует moderation и reason code |
| 23 | Program Item с независимым booking lifecycle становится отдельной entity |
| 24 | Provider-owned поля не редактируются Recharge overlay |
| 25 | Unknown capacity/price/availability не отображается как zero/free/available |
| 26 | Любая relation использует ID; display credit не является relation |
| 27 | `attendancePolicy.reconfirmationRequired` допустим только при `registrationMode=internal` и конечном inventory; auto-release атомарен и триггерит waitlist promotion |
| 28 | Auxiliary admission track, потребляющий конечную venue capacity, требует отдельный inventory pool в общем ledger и не публикуется в основном admission UI |
| 29 | `hybrid` с конечным физическим capacity требует bounded onsite pool; shared/`any` pool не может быть единственным physical capacity guard |
| 30 | Published Event без будущих не-cancelled occurrences исключается из Discover projection, lifecycle не меняется |
| 31 | Новая/изменённая occurrence является material revision и не возвращает Event в Discover в обход применимой moderation policy |
| 32 | Category System покрывается полностью, но ни main category, ни subcategory не выбирает aggregate или Create-тип автоматически |
| 33 | Для capacity-holding internal Booking concurrency cap проверяется внутри той же авторитетной транзакции до inventory mutation; превышение отклоняет операцию без создания Booking/hold и без изменения inventory |

## 20. Эталонные примеры

### 20.1. Регулярная мафия

```text
archetype: hosted_game
category: games_indoor / mafia
participation: play + meet_people
format: offline [indoor, seated]
schedule: recurring weekly; occurrences
location: placeRef
admission: booking
registration: internal
confirmation: instant
waitlist: enabled (fifoAutomatic, offerTtl 120 min)
attendancePolicy: reconfirm 24h→6h before, autoRelease on miss
inventoryAuthority: recharge
capacityMode: known
inventoryShape: generalCapacity
capacity: 12
hostReserved: 1
pricing: fixed / perPerson / EUR 10
paymentCollection: onsite
visibility: public
publisher: page(game club)
```

### 20.2. Неформальный поиск игроков

```text
Не Event.
Create type: Find People
category: games_indoor / card_games
```

### 20.3. Любительский футбол

```text
archetype: open_play
category: sport / football
participation: play
format: offline [outdoor]
schedule: oneTime
admission: booking
registration: internal
confirmation: manualApproval или instant
inventoryAuthority: recharge
inventoryShapes: participantRoles + teamSlots
pricing: fixed / fixedGroup либо informational split
paymentCollection: onsite/external
publisher: user или page(sports club)
```

### 20.4. Импортированный концерт

```text
archetype: performance
category: music_nightlife / concert
participation: watch
format: offline [seated, standing]
schedule: oneTime
location: placeRef(arena)
admission: ticket
registration: external
confirmation: providerManaged
inventoryAuthority: externalProvider
inventoryShapes: assignedSeating + zones
pricing: ticketTypes; providerSynced; display from
paymentCollection: external
publisher: promoter page
relations: venue, performer, ticketProvider
source: apiSynced/providerVerified
```

### 20.5. Городской фестиваль

```text
archetype: festival
category: holidays_seasonal / city_festival
format: offline [outdoor, multiVenue]
schedule: oneTime multi-day interval
programItems: acts/sessions/breaks
admission: openEntry
registration: none
capacityMode: unlimited for common area
pricing: free
publisher: municipality page
relations: coOrganizers, venues, sponsors, performers
auxiliaryTracks:
  - accreditation (press): application, manualApproval, pool 40
  - volunteer: application, manualApproval, pool 120
```

Платный workshop внутри фестиваля с независимым inventory создаётся отдельным
child Event/Bookable Session и связывается через `childEventRef`.

### 20.5a. Hybrid-конференция

```text
archetype: conference
category: business_networking / conference
format: hybrid [indoor, seated]
schedule: oneTime multi-day interval
location: placeRef(venue); onlineAccess: internalBooking, linkDelivery
          afterConfirmation
admission: ticket
registration: internal
inventoryAuthority: recharge
inventoryShapes: separateTicketPools
pools:
  - onsite Standard: channel=onsite, capacity 300
  - onsite VIP: channel=onsite, capacity 40
  - online: channel=online, capacity 2000
availability: считается по каналу — onsite soldOut ≠ online soldOut
```

### 20.6. Онлайн-лекция

```text
archetype: talk
category: education_talks / public_talk
participation: learn
format: online
onlineAccessMode: internalBooking
linkDelivery: afterConfirmation
schedule: oneTime
admission: rsvp
registration: internal
confirmation: instant
inventoryAuthority: recharge
capacityMode: known
capacity: 500
pricing: free
publisher: institution page
```

### 20.7. Выставка

```text
archetype: exhibition
category: art_culture_museums / exhibition
participation: visit
format: offline [indoor]
schedule: recurring occurrences in bounded date range
admissionWindows: Tue-Sun 11:00-19:00
location: placeRef(museum)
admission: ticket или openEntry
inventory: none/generalCapacity/timeSlotInventory
pricing: free/fixed/ticketTypes
```

### 20.8. Экскурсия по маршруту

```text
archetype: tour_excursion
category: travel_tours / walking_tour
format: offline [moving, outdoor]
schedule: oneTime или recurring occurrences
location: meetingPoint
routeRef: отдельный published Route ID
admission: booking
inventoryShape: generalCapacity
```

## 21. UX для Creator

Creator не заполняет все оси вручную одним длинным экраном.

### 21.1. Progressive disclosure

1. Выбрать «что происходит» — archetype.
2. Выбрать тему Category System.
3. Указать format/location/schedule.
4. Выбрать понятный admission preset.
5. Настроить только релевантные pricing/inventory поля.
6. Проверить preview и source-of-truth disclosure.

### 21.2. Admission presets

Presets заполняют несколько осей, но сохраняют их отдельно:

| UI preset | Нормализованные значения |
|---|---|
| Без регистрации | openEntry + none + none |
| Бесплатная запись | rsvp + internal + instant |
| Заявка организатору | application + internal + manualApproval |
| Внешняя регистрация | booking/rsvp + external |
| Внешние билеты | ticket + external |
| Билеты Recharge | ticket + internal |
| Регистрация команды | teamRegistration + internal/external |

### 21.3. External provider UX

Организатор подключает provider один раз, сопоставляет organisation/venue и
выбирает импортируемые события. Operational data обновляется автоматически.
Organizer управляет только Recharge overlay и sync health, не дублирует цены,
места и брони.

## 22. Миграция и совместимость

### 22.1. Schema

Новые поля добавляются versioned и additive. Неизвестные future fields
сохраняются mapper-ом.

### 22.2. Legacy drafts/events

- существующие Event читаются без обязательного migration write;
- archetype для legacy может быть предложен детерминированным mapper-ом из
  subcategory, но не сохраняется молча;
- при следующем редактировании Creator подтверждает archetype;
- Publish новой material revision требует заполнить новые обязательные поля;
- старый `bookingLink` маппится в один `externalBookingUrl`, не создавая
  конкурирующие ссылки;
- `capacity<=0` нормализуется в unknown;
- существующий PublisherRef не переписывается при workspace switch.

### 22.3. Rollback

- feature flags отдельно управляют classification UI, internal booking,
  external providers, tickets, Program Items и assigned seating;
- отключение новой классификации оставляет raw versioned fields сохранёнными;
- отключение provider connector переводит freshness в stale/unknown и
  сохраняет external references;
- rollback не удаляет Booking/Payment/Attendance obligations;
- downgrade mapper не объявляет неизвестные данные бесплатными/доступными.

## 23. Этапы реализации

### ECL-00 — Canonical contract alignment

- согласовать этот документ с `EVENT_CREATE_SPEC`;
- утвердить новые enums/value objects;
- не менять runtime.

### ECL-01 — Local classification foundation

- archetype и participation modes;
- migration suggestions;
- validation;
- form-engine section;
- mapper round-trip;
- без backend/provider/payment.

### ECL-02 — Local admission/inventory configuration

- admission presets;
- capacity/inventory shapes как конфигурация;
- mock availability projections;
- без real Booking.

### ECL-03 — Internal free registration

- отдельный Approved production/backend slice;
- Booking lifecycle, atomic inventory, approval, waitlist, notifications;
- attendancePolicy: reconfirmation и atomic auto-release без межсобытийного
  reliability profile или risk score;
- единый versioned concurrency cap для capacity-holding internal Booking,
  одинаковый для всех пользователей и прозрачный в UI;
- cap является transactional precondition: проверяется внутри той же
  авторитетной операции до захвата inventory; отказ не создаёт Booking/hold,
  не изменяет inventory, а idempotent retry не учитывается повторно;
- catalog для `countingRuleRef` принадлежит versioned Booking platform-policy
  config и утверждается этой ECL-03 Booking specification;
- cancellation policy для бесплатных броней (deadline, reason codes);
- auxiliary admission tracks (application-based, без оплаты);
- без payments.

### ECL-04 — External provider handoff

- provider ADR и commercial/legal contract;
- OAuth/backend secrets;
- safe deep link, attribution, freshness;
- provider остаётся source of truth.

### ECL-05 — Provider availability and booking mirror

- verified polling/webhooks;
- prices/inventory/status sync;
- My Bookings только при разрешённом identity linkage;
- reconciliation и sync-health UI.

### ECL-06 — Program Items

- festival/conference schedule;
- stable room/stage refs;
- child entity boundary.

### ECL-07 — Internal paid tickets

- отдельный Payments/KYC/KYB/PSP slice;
- immutable price snapshot;
- refunds/disputes/payout obligations;
- QR/check-in.

Депозиты/authorization holds не включаются автоматически в ECL-07. Если они
когда-либо потребуются, для них нужен отдельный утверждённый Payments scope с
прозрачным UX и юридическими условиями.

### ECL-08 — Assigned seating presentation

- только approved provider contract;
- zones/seat-map rendering;
- interactive selection только при authoritative hold API;
- собственный seating-chart editor не входит в Event Create.

### Deferred product decisions (не ECL scope)

Эта таблица предотвращает потерю отложенных решений, но не разрешает runtime,
новый Create-тип, production integration или payment/risk capability. Каждая
строка входит в реализацию только после указанного утверждённого артефакта.

| ID | Отложенное решение | Владелец | Следующий обязательный артефакт |
|---|---|---|---|
| `EVT-ANN-01` | Публичный Announcement без occurrence | Product + Architecture | Product spec, Accepted ADR и Approved slice |
| `EVT-TRUST-01` | Персональные anti-no-show меры и поведенческий скоринг | Trust/Risk + Privacy/Legal | Trust/Risk specification, privacy/fairness review и Approved slice |
| `EVT-PAY-01` | Депозит или card authorization hold | Payments + Legal | Payments specification, PSP semantics, Accepted ADR и Approved slice |

Владельцы обязаны либо продвинуть решение при подтверждённой потребности,
либо явно закрыть его с reason code; отсутствие реализации не меняет текущие
инварианты Event.

## 24. Acceptance criteria

1. Любой Event имеет ровно один archetype и один PublisherRef.
2. Category System остаётся единственным источником темы.
3. Archetype не выводит автоматически category, access или pricing.
4. Event/Place/Route/Scenario/Quick Plan/Bookable Session/Find People не
   смешиваются.
5. Series остаётся Event с recurrence и occurrences.
6. All-day и multi-day не создают новые schedule modes.
7. Event без определённой occurrence не публикуется в Discover.
8. Access хранится по независимым admission/registration/confirmation/
   eligibility/waitlist осям.
9. Preset нормализуется в канонические отдельные поля.
10. Pricing mode не содержит deposit, membership или display modifiers.
11. Payment collection отделён от pricing.
12. Inventory authority отделён от inventory shape.
13. External provider fields read-only и имеют freshness.
14. Unknown/stale не отображается как available/free.
15. Sold-out не является lifecycle.
16. Current participants не вводятся Creator вручную.
17. Oversell/overbooking запрещены.
18. Waitlist promotion использует атомарный hold с TTL.
19. Assigned seating не выбирается внутри Recharge без authoritative hold.
20. Route связан только через `routeRef`; geometry не дублируется.
21. Event relation использует stable ID; unlinked credit не даёт authority.
22. Co-organizer не становится вторым Publisher.
23. Provider import не меняет organizer/publisher автоматически.
24. Fuzzy match создаёт duplicate candidate, но не silent merge.
25. Source provenance сохраняется после merge.
26. Scraping не является разрешённым production source.
27. Secrets отсутствуют в Flutter/public projection/logs/analytics.
28. Legacy Event читается без обязательного migration write.
29. Workspace switch не переписывает существующий PublisherRef.
30. Новые local slices проходят analyzer, tests, boundary и diff gates.
31. Production Booking/Provider/Payment запускаются только отдельными Approved
    slices и kill switches.
32. UI доступен на 360 dp при 150% text scale и не полагается только на цвет.
33. Free Event с конечным capacity поддерживает reconfirmation и atomic
    auto-release без платёжных механик и без межсобытийного reliability
    profile/risk score.
34. Published Event без будущих не-cancelled occurrences не отображается в
    Discover; прямая ссылка работает; lifecycle не меняется.
35. Hybrid Event с конечным физическим capacity имеет bounded onsite pool;
    shared/`any` pool не является единственным physical capacity guard;
    availability считается по каналу.
36. Auxiliary admission tracks, потребляющие конечную venue capacity, имеют
    отдельные pools в общем ledger, не видны в основном admission UI и не
    входят в публичную статистику.
37. Публичный материал без occurrence не является Event; новый публичный
    Announcement/Create flow не вводится этой спецификацией и требует
    отдельного Accepted ADR и Approved slice.
38. Опциональный RSVP при `openEntry` является только interest/reminder
    intent: он не создаёт Booking, не резервирует inventory и не требует
    регистрации на входе.
39. Все 27 предметных групп и сервисная группа `other` Category System v1.4.3
    применимы к Event при выполнении occurrence-инварианта; категория не
    выбирает aggregate автоматически.
40. Добавление или изменение occurrence проходит material revision и
    применимую moderation policy до возврата Event в Discover.
41. Единый concurrency cap применяется только к capacity-holding internal
    Booking, одинаков для всех пользователей launch scope, прозрачен в UI и
    не использует историю поведения или reliability score. Cap проверяется
    внутри той же авторитетной транзакции до inventory mutation; превышение
    не создаёт Booking/hold и не изменяет inventory, параллельные и повторные
    запросы остаются атомарными и идемпотентными.
42. Deferred product decision имеет ID, владельца и обязательный артефакт;
    roadmap-якорь сам по себе не расширяет Event/Create/runtime scope.
43. §1.2 является нормативной границей Event; §6.2 только поясняет её и не
    может задавать противоречащее aggregate-решение.

## 25. Итоговое решение

Recharge использует фасетную Event-модель:

- **archetype** — механика;
- **Category System** — тема;
- **format/schedule/location** — где и когда;
- **admission** — как попасть;
- **pricing/payment** — сколько и где оплачивать;
- **inventory authority/shape** — кто и как контролирует доступность;
- **Publisher/relations** — от чьего имени опубликовано и кто участвует;
- **source/freshness** — насколько данным можно доверять.

Эта структура покрывает локальные и внешние события, не создавая параллельную
систему и не превращая Recharge в обязательного продавца билетов.

---

## 26. Changelog

### v2.2.3 (2026-08-04)

- владелец продукта принял документ как канонический product/domain contract
  Recharge; файл встроен в `docs/product`, а runtime честно зафиксирован как
  частично реализованный через EVT-CRT-01 и будущие Approved ECL slices;
- правило 33 и acceptance 41 закрепили concurrency cap как transactional
  precondition внутри авторитетной Booking-операции до inventory mutation;
  превышение cap не создаёт Booking/hold и не изменяет inventory;
- `countingRuleRef` привязан к versioned provider-neutral catalog в Booking
  platform-policy config; его контракт и lifecycle принадлежат ECL-03.

### v2.2.2 (2026-08-04)

- добавлен единый прозрачный platform concurrency cap для capacity-holding
  internal Booking без персонального скоринга; зафиксировано ограничение:
  reconfirmation и cap снижают, но не устраняют no-show;
- Announcement, персональные Trust/Risk-меры и денежный commitment получили
  roadmap-якоря с ID, владельцами и обязательными артефактами без расширения
  текущего scope;
- §1.2 закреплён как нормативный источник aggregate-границ, а §6.2 — как его
  поясняющая тематическая проекция; добавлено правило синхронного обновления.

### v2.2.1 (2026-08-04)

- добавлена явная полнота тематического покрытия: 27 предметных групп,
  сервисная `other`, все 530 подкатегорий через Category System v1.4.3;
- добавлена матрица Event eligibility против Place, Bookable Session,
  Find People, Route, Scenario, Quick Plan и Collection/Guide;
- публичный Announcement выведен из текущего scope: новый Create-тип или
  сущность возможны только через отдельные ADR/spec/slice;
- optional RSVP при open entry отделён от Booking и inventory;
- убраны межсобытийный reliability profile/risk score и зарезервированный
  денежный commitment hold; reconfirmation остаётся локальной Booking policy;
- hybrid inventory уточнён: bounded onsite pool обязателен, а shared/`any`
  pool не может быть единственным ограничителем физической вместимости;
- auxiliary tracks разделены с workforce/access credentials и требуют pool
  только при фактическом потреблении конечной venue capacity;
- возврат в Discover после изменения occurrence подчинён material revision и
  moderation policy.

### v2.2 (2026-08-04)

- **Историческая версия, скорректирована v2.2.1.** В ней предлагались
  Announcement, reliability signal и commitment hold; эти предложения не
  входят в действующий контракт v2.2.1.
- **§10.8 Attendance policy**: немонетарная защита от no-show
  (reconfirmation + atomic auto-release) для бесплатных событий с конечным
  capacity.
- **§10.9 Auxiliary admission tracks**: пресса/волонтёры/вендоры как
  параллельные потоки с отдельными pools в общем ledger вместо перегрузки
  eligibility.
- **§13.3a Channel binding**: hybrid с конечным физическим capacity обязан
  разводить onsite/online pools; availability по каналам.
- **§13.5 Discover-активность**: published Event без будущих активных
  occurrences покидает Discover как projection, без смены lifecycle.
- **§9**: `areaDisclosure` переименован в `areaOnly` (kind локации отделён
  от концепции disclosure).
- **§19**: матрица перенумерована (устранён «8a»), добавлены правила 27–30.
- **§20**: примеры дополнены (attendancePolicy у мафии, auxiliary tracks у
  фестиваля, новый пример 20.5a hybrid-конференция).
- **§23**: ECL-03 расширен attendance/cancellation/auxiliary tracks.
- **§24**: acceptance criteria 33–37.

### v2.1

- Границы Event против смежных aggregates; инварианты; декомпозиция
  admission; availability projection; field authority; этапы ECL и
  acceptance criteria.

### v2.0

- Исходная фасетная модель: архетипы, participation modes, оси
  format/schedule/location/access/pricing/inventory/governance/provenance.
