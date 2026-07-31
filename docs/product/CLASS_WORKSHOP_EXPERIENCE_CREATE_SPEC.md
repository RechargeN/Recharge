# CLASS / WORKSHOP / EXPERIENCE CREATE — полная логика блока

Статус: **Full-product specification — Ready for approval**  
Версия: 1.1  
Дата: 2026-07-18  
Область: полная production-логика `classWorkshop` в едином Create Hub

> Документ описывает полноценный действующий продукт без искусственного
> ограничения MVP-срезом. Он не утверждает, что перечисленные возможности уже
> реализованы, и не разрешает менять приложение до продуктового утверждения,
> завершения активного stabilization slice и принятия необходимых ADR.

Связанные источники истины:

- [VISION.md](VISION.md) — Create Hub и продуктовые границы типа;
- [CATEGORY_SYSTEM.md](CATEGORY_SYSTEM.md) — канонические категории,
  подкатегории, applicable types и dynamic criteria;
- [S3_CRT_01_CREATE_SPEC.md](S3_CRT_01_CREATE_SPEC.md) — текущий baseline
  общего draft/publish flow;
- [EVENT_CREATE_SPEC.md](EVENT_CREATE_SPEC.md) — согласуемые общие правила
  времени, медиа, Publisher и публикации;
- [ADR 0013](../adr/0013-domain-policy-baseline.md) — обязательные правила
  ownership, capabilities, lifecycle, ULID, времени, offline, moderation,
  privacy и audit. Его MVP-ограничения не определяют конечную функциональность;
  production-расширения требуют отдельного ADR до реализации.

---

## 0. Статус решений и способ чтения

### 0.1 Что уже зафиксировано источниками более высокого приоритета

Эта спецификация не пересматривает следующие решения:

- `classWorkshop` — один из десяти типов единого config-driven Create Hub;
- для него нельзя создавать отдельный form engine, отдельное хранилище
  черновиков или копии общих секций;
- роли — `User / Creator / Admin`, а действия разрешаются capabilities;
- Publisher имеет форму `{type: user | page, id}`;
- постоянные идентификаторы — ULID/UUID, временные `loc_*` допустимы только
  для несохранённых или несинхронизированных локальных сущностей;
- timestamps хранятся в UTC вместе с IANA timezone;
- стартовый market, страна, timezone и валюта приходят из runtime config;
- первая публикация или material revision отправляет объект в `pending_review`;
- cover обязателен для Publish;
- полный продукт поддерживает внутреннюю и внешнюю запись, seat inventory,
  approval, waitlist, оплату, возвраты и attendance как отдельные согласованные
  подсистемы;
- текущий ADR 0013 фиксирует MVP baseline без payment processing; до реализации
  commerce-подсистемы обязателен новый Accepted ADR по платежам, налогам,
  payout, chargeback и финансовому audit;
- Firebase, production upload, booking backend, payments и moderation
  подключаются отдельными slices после стабилизации.

### 0.2 Фактическое состояние на дату документа

| Область | Уже есть | Целевое расширение документа |
|---|---|---|
| Тип | `CreateObjectType.classWorkshop` в общем Create Hub | Полная специализированная конфигурация типа |
| Категория | Default `workshops_masterclasses / workshop` | Только разрешённые `applicableTypes = C` и dynamic criteria |
| Draft | Общая локальная `CreateDraftEntity` | Типизированные section data, autosave и recovery |
| Время | `eventSlots`, start/end и duration | Cohorts, occurrences, recurrence, timezone, DST и attendance scope |
| Локация | Общие city/address/geo-поля | Offline/online/hybrid и точка встречи |
| Обучение | Отдельной модели нет | Variant, outcomes, agenda, instructor, prerequisites, materials |
| Цена | Free/base price | Price options, налоги, fees, discounts, payment и refunds |
| Publisher | Legacy organizer fields | Канонический Publisher и capability checks |
| Publish | Mock → `pending_review` | Readiness, idempotency, permanent IDs, moderation и operations |
| Booking | Только legacy flags/link | Inventory, holds, booking, approval, waitlist и check-in |
| Learning | Нет отдельного runtime | Curriculum, resources, homework, progress и certificates |

Документ не переводит целевые пункты в Done и не разрешает менять приложение
во время активной стабилизации. При конфликте с Accepted ADR сначала создаётся
новый superseding ADR, а не скрытое отклонение в коде.

## 1. Цель

Creator должен создать, опубликовать и полноценно управлять предложением:
занятие, мастер-класс, практический воркшоп, учебный курс или сопровождаемый
практический опыт. Пользователь до записи должен понимать:

- чему он научится или что сделает;
- кто ведёт занятие;
- подходит ли его уровень, возраст и язык;
- что нужно принести и что предоставит организатор;
- когда, где и сколько длится каждое занятие;
- является ли предложение единичным, серией или курсом;
- сколько стоит участие и к чему относится цена;
- сколько человек допускается;
- доступность мест в реальном времени;
- как записаться, оплатить, отменить участие или вступить в waitlist;
- какие материалы, задания, attendance и сертификат входят в программу.

В документе `classWorkshop` — имя enum в Category System,
`CreateObjectType.classWorkshop` — имя в приложении, а `class_workshop` —
канонический сериализованный type ID. Это одно понятие, а не три разных типа.

### 1.1 Продуктовое обещание

Recharge превращает поиск занятия в завершённый и безопасный результат:
пользователь находит подходящий формат, заранее понимает ценность и полную
стоимость, гарантированно получает место и доступ, приходит подготовленным,
проходит занятие и сохраняет подтверждённый результат.

Creator один раз создаёт качественный Offering, запускает сколько угодно
Cohort без копирования контента и управляет расписанием, продажами, участниками,
обучением и финансами из одного operational workspace.

### 1.2 Идеальный путь участника

```text
Discover
  → сравнить Offering и доступные Cohort
  → проверить outcome, уровень, ведущего, место, accessibility и total price
  → выбрать Cohort/Occurrence/PriceOption
  → hold места
  → questionnaire/approval, если требуется
  → payment или external confirmation
  → confirmed Booking + ticket/calendar/access
  → reminders + preparation/materials
  → check-in и участие
  → resources/homework/progress
  → certificate, review, повторная запись
```

Ключевые UX-инварианты:

- цена, fees, налоги и условия возврата известны до подтверждения;
- место не обещается до server-confirmed hold/Booking;
- изменение времени, места или ведущего не прячется;
- пользователь всегда видит следующий разрешённый шаг и состояние операции;
- timeout не заставляет платить или бронировать повторно вслепую;
- отмена, transfer, refund и support доступны из `My bookings`;
- приватные данные и access links показываются только их адресату.

### 1.3 Идеальный путь Creator

```text
Create Offering
  → category + value proposition
  → curriculum + instructor team
  → reusable media, materials and policies
  → create initial Cohort
  → schedule + delivery + inventory
  → prices + booking + commerce
  → preview + readiness
  → moderation + publish
  → bookings/waitlist/communications
  → delivery/check-in/learning
  → payouts/refunds/insights
  → duplicate Cohort from approved Offering
```

Creator не должен заново вводить стабильное описание курса для каждого
запуска. Любое массовое действие сначала показывает impact, затем выполняется
идемпотентно и оставляет audit.

### 1.4 Идеальный путь operational team

Staff получает только разрешённый capability slice:

- instructor видит программу, roster по необходимости, attendance и feedback;
- front desk видит check-in и минимум participant данных;
- booking manager управляет approval, waitlist, transfer и support;
- finance видит Order, ledger, payout, refund и reconciliation;
- content manager редактирует Offering/Cohort без финансовых прав;
- owner/admin управляет collaborators, policies и audit.

### 1.5 Принципы качества продукта

1. **Truth before conversion** — availability, total price и статус не
   приукрашиваются ради CTA.
2. **One source of truth** — UI показывает server-confirmed inventory, payment
   и policy snapshots.
3. **No dead ends** — каждая ошибка имеет понятный recovery path.
4. **No silent loss** — draft, payment, booking и progress не теряются при
   restart, offline или retry.
5. **Accessible by default** — accessibility является базовым контрактом, а не
   отдельным режимом.
6. **Privacy by design** — собирается минимум данных с purpose и retention.
7. **Operationally calm** — массовые изменения, refunds и incidents
   контролируемы, наблюдаемы и обратимы там, где это юридически возможно.
8. **Reusable, not duplicated** — Offering, Cohort и shared policies имеют
   ясные границы и immutable ссылки.

### 1.6 Метрики успеха и guardrails

North-star metric: **успешно завершённые релевантные участия** — подтверждённый
Booking/Enrollment, завершившийся Attendance или on-demand completion без
fraud, unresolved safety incident или ошибочного списания.

| Группа | Метрики |
|---|---|
| Discovery | details open rate, cohort availability match, zero-result rate |
| Conversion | quote→hold, hold→confirmed, approval time, waitlist conversion |
| Delivery | attendance, on-time start, completion, certificate eligibility |
| Retention | repeat participation, repeat Creator cohort, saved-to-booked |
| Creator value | time-to-first-publish, fill rate, payout latency, support load |
| Quality | verified rating, refund/cancellation/no-show, reschedule rate |
| Trust | safety incidents, disputes, fraud, privacy/access violations |
| Reliability | oversell, duplicate charge/refund, reconciliation drift, SLO |
| Inclusion | accessibility-data coverage, assistive-flow completion, locale gaps |

Метрики не оптимизируются изолированно: рост conversion не считается успехом,
если ухудшились safety, disputes, refunds, accessibility или user trust.

## 2. Доменная граница

### 2.1 Что является Class / Workshop / Experience

Объект относится к `classWorkshop`, если одновременно выполняются условия:

1. Есть ведущий, инструктор или фасилитатор.
2. Участник активно выполняет действия, получает навык, результат или
   сопровождаемый практический опыт.
3. Есть описанная структура: outcome, программа или последовательность этапов.
4. Есть конкретное расписание, cohort/series либо формализованный период
   on-demand доступа.
5. Для live delivery duration положительна; capacity либо положительна, либо
   явно unlimited там, где нет scarce resource; occurrence требуются только
   соответствующему schedule mode. Все значения проходят PolicyLimits.

Слово Experience в названии типа не создаёт отдельную предметную категорию.
Это вариант подачи guided hands-on предложения внутри разрешённой taxonomy.

### 2.2 Варианты предложения

| `offeringKind` | Смысл | Типичный результат |
|---|---|---|
| `class` | Обучающее занятие с объяснением и практикой | Освоен приём или базовый навык |
| `workshop` | Практическая работа по этапам | Сделан объект или завершена задача |
| `masterclass` | Интенсив от эксперта с демонстрацией и практикой | Освоена авторская/профессиональная техника |
| `course` | Связанная программа: cohort, rolling enrollment или on-demand | Достигнут накопительный учебный outcome |
| `experience` | Сопровождаемое практическое участие | Получен заявленный опыт или создан результат |

`offeringKind` влияет на подсказки и условные поля, но не заменяет
`categoryId`, `subcategoryId` или criteria profile.

### 2.3 Что не является этим типом

| Случай | Канонический тип |
|---|---|
| Публичная лекция, показ или встреча без обязательной практики | Event |
| Услуга или частный урок, для которого пользователь выбирает свободный слот | Bookable Session |
| Самостоятельное посещение студии, школы или площадки | Place / Business |
| Прогулка или лёгкая активность без учебной программы | Recharge Activity |
| Экскурсия или непрерывный трек по местности | Event или Route по taxonomy |
| Набор независимых остановок | Quick Plan / Scenario |
| Видеокурс с программой, доступом и progress tracking | Course этого блока |
| Отдельное видео без программы и результата | Collection/медиа-контент, не этот тип |
| Аренда материалов или оборудования без проведения занятия | Rental / Equipment |

### 2.4 Разрешение спорных случаев

Контроллер применяет решение в таком порядке:

1. Есть свободный каталог слотов, а содержание каждого слота одинаково —
   `Bookable Session`.
2. Есть объявленные occurrence/series и обязательная практическая программа —
   `classWorkshop`.
3. Основная ценность — публичное событие, выступление или общение —
   `Event`.
4. Основная ценность — геометрия непрерывного трека — `Route`.

UI может показать ненавязчивую рекомендацию сменить тип. Автоматически менять
тип и терять введённые данные нельзя.

### 2.5 Production aggregate

Полноценный продукт разделяет переиспользуемое предложение и его конкретные
запуски:

| Сущность | Ответственность |
|---|---|
| `Offering` | Стабильное описание, category, outcomes, curriculum, media и Publisher |
| `OfferingRevision` | Версионированная редактируемая и модерируемая редакция |
| `Cohort` | Конкретный набор/запуск с timezone, ценами, capacity и правилами записи |
| `Occurrence` | Одно занятие cohort: start/end, venue/online access, instructor и status |
| `InventoryPool` | Доступные места, holds и правила распределения |
| `Booking` | Резерв пользователя на occurrence, cohort, package или group |
| `Enrollment` | Учебное участие в course/cohort и доступ к материалам |
| `Order / Payment / Refund` | Финансовая операция, отдельная от reservation state |
| `WaitlistEntry` | Очередь на inventory scope с promotion policy |
| `AttendanceRecord` | Check-in, attended/no-show и audit |
| `ProgressRecord` | Выполненные модули, задания и критерии certificate |
| `Certificate` | Проверяемый результат завершения, если включён Creator |

Первый Create flow создаёт Offering и минимум один публикуемый Cohort либо
on-demand access configuration. Следующие cohorts создаются из Offering без
дублирования описания. Все связи используют immutable ID.

## 3. Taxonomy и dynamic criteria

### 3.1 Источник категорий

Форма показывает только категории и подкатегории, где
`CATEGORY_SYSTEM.md` разрешает ContentType `classWorkshop` (`C`).
На дату документа это включает:

- всю категорию `workshops_masterclasses`;
- допустимые подкатегории категории `dance`, кроме её Event-only overrides;
- `adrenaline_entertainment / parkour`.

Этот список является пояснением, а не отдельным whitelist. Runtime всегда
читает актуальный реестр Category System через use case.

Запрещено:

- вручную дублировать список в UI;
- добавлять Experience-подкатегории в обход Category System;
- публиковать `classWorkshop` с несовместимой подкатегорией;
- использовать архивный `RECHARGE_CREATE_TAXONOMY_V1.md` как источник истины.

### 3.2 Dynamic criteria

После выбора подкатегории:

1. Определяется её `profileId` или профиль категории.
2. `get_category_criteria_usecase` возвращает определения полей.
3. `DynamicCriteriaSection` строит контролы.
4. Значения сохраняются как `criteria[fieldId] = value`.
5. Publish валидирует обязательные поля текущего профиля.

Примеры:

- `hands_on_class`: обязательны `skill_level` и `equipment_provided`;
- `physical_activity`: обязательный `skill_level`, опциональны equipment,
  venue type и pace;
- `wellness_session`: skill level, equipment, language и venue type.

### 3.3 Безопасная смена категории

При смене категории или подкатегории:

1. Значения общих field IDs, совместимые по типу, сохраняются.
2. Новые обязательные поля становятся незаполненными.
3. Несовместимые значения не отправляются в public model.
4. Если будут потеряны заполненные данные, UI показывает перечень полей и
   просит подтвердить смену.
5. Cancel возвращает прежнюю категорию и данные без изменений.
6. После подтверждения удалённые значения могут жить только в локальном
   undo snapshot до следующего успешного autosave.

## 4. Доступ и Publisher

### 4.1 Вход в flow

- Guest перенаправляется в Auth, сохраняя intended destination.
- User без create capability видит Upgrade state и не получает draft.
- Creator с `create.class_workshop` может создать draft от своего имени.
- Создание от ManagedPage требует права действовать от имени этой страницы.
- Admin не обходит domain validation; расширенные права определяются
  capability policy.

### 4.2 Проверки

Capability проверяется:

1. перед созданием draft;
2. при выборе или смене Publisher;
3. перед синхронизацией remote draft;
4. перед Publish;
5. перед edit, archive, restore и delete command.

UI не передаёт доверенный owner ID. Publisher разрешается из auth context и
доступных ManagedPage memberships.

Production capabilities разделяются по границам команд:

- `create.class_workshop` и `publish.class_workshop`;
- `edit.offering` и `manage.cohort`;
- `manage.schedule` и `manage.inventory`;
- `manage.bookings` и `check_in.participants`;
- `manage.pricing`, `issue.refund` и `view.financials`;
- `manage.learning` и `issue.certificate`.

Одна широкая роль не должна автоматически выдавать доступ к финансовым или
персональным данным.

### 4.3 Publisher и instructor

Publisher отвечает за публикацию и юридически значимые контактные данные.
Instructor отвечает за фактическое проведение. Они могут совпадать, но это
разные понятия.

- `publisherRef` обязателен и имеет `type: user | page` и immutable ID;
- `publisherRef.type/id` однозначно проецируется в обязательные ADR-поля
  `owner_type/owner_id`; второй независимый owner не создаётся;
- `instructor.sameAsPublisher = true` использует публичный профиль Publisher;
- при `false` Creator задаёт display name, short bio и, опционально,
  подтверждающую ссылку;
- credentials нельзя представлять как проверенные без moderation flag;
- email и телефон не выводятся публично без отдельного consent.

Выбор instructor обязателен для всех offering kinds: либо подтверждается
`sameAsPublisher`, либо заполняется отдельный ведущий. Instructor и assistants
не получают ownership или capability на редактирование объекта.

Команда не ограничена одним ведущим: Offering имеет primary instructor,
co-instructors и assistants. Участник связывается по profile/page ID или
хранится как moderated guest instructor. Права редактирования выдаются
отдельно через `OfferingCollaborator` с capability scope и могут отличаться
от публичной роли ведущего.

## 5. Общий пользовательский flow

```text
Create Hub
  → выбрать Class / Workshop / Experience
  → проверить capability и Publisher
  → создать или восстановить loc_* Offering draft
  → Шаг 1: Основное и категория
  → Шаг 2: Программа и ведущий
  → Шаг 3: Delivery, cohorts, локации и расписание
  → Шаг 4: Участники, inventory, материалы, цены и booking
  → Шаг 5: Preview, readiness и подтверждения
  → idempotent Publish Offering + initial Cohort
  → pending_review → published → operational management
```

### 5.1 Навигация

- Back сохраняет текущие валидные и невалидные введённые значения.
- Continue запускает validation текущего шага и переводит к первому blocking
  error.
- Закрытие вызывает flush autosave; при ошибке предлагается остаться или
  закрыть с понятным риском потери последних изменений.
- Progress отражает обязательные секции, а не число заполненных контролов.
- Пользователь может вернуться на пройденный шаг без сброса следующих.
- Preview всегда строится из текущего draft через тот же mapper, что public
  details, с явной меткой Draft preview.
- Creator может сохранить Offering без Cohort как непубликуемый template.
- После первого Publish новый Cohort создаётся коротким operational flow и
  ссылается на Offering, не копируя его.

## 6. Состояния

### 6.1 UI/application state

| Состояние | Поведение |
|---|---|
| `loading` | Чтение config, capabilities и draft |
| `ready` | Редактирование разрешено |
| `saving` | Неблокирующий индикатор autosave |
| `saveFailed` | Draft остаётся доступным, показан retry |
| `validating` | Проверка шага или Publish readiness |
| `publishing` | Повторный tap заблокирован |
| `publishFailed` | Ошибка сопоставлена с полем или recovery action |
| `submitted` | Получен permanent ID и серверный moderation result |
| `readOnly` | Доступ отозван либо draft открыт не владельцем |
| `operational` | Управление cohorts, inventory, bookings и learning delivery |

### 6.2 Независимые persisted axes

Нельзя смешивать:

- entity lifecycle: `draft / pending_review / published / archived / hidden /
  deleted`;
- moderation: `none / pending / approved / rejected`;
- local sync: `local_only / dirty / syncing / synced / conflict / failed`.

Booking, payment, approval, attendance и learning progress являются отдельными
state machines. Их нельзя кодировать дополнительными значениями lifecycle
Offering.

`hidden` выставляется системой/moderation, а не Creator. `rejected` не удаляет
данные: создаётся редактируемая revision с moderation reason.

## 7. Draft, autosave и восстановление

### 7.1 Новый draft

После успешной проверки создаются Offering draft и initial Cohort draft:

- `id = loc_<ULID>`;
- `objectType = classWorkshop`;
- default category/subcategory из `CreateTypeConfig`;
- `publisherRef` из текущего publisher context;
- market, country, city, timezone и currency из runtime config;
- `availabilityKind = eventSlots`;
- lifecycle `draft`, moderation `none`;
- version, createdAtUtc и updatedAtUtc.

Ни market, ни координаты, ни currency не задаются в виджете константами.

### 7.2 Autosave

Autosave запускается:

- после debounce значимого изменения;
- при переходе между шагами;
- при уходе приложения в background;
- перед Preview;
- перед Publish.

Текст в фокусе не должен дёргать навигацию. Ошибка сохранения не очищает форму.
Медиа сохраняются как отдельные upload references и не блокируют сохранение
остальных полей.

### 7.3 Restore

При повторном входе пользователь выбирает:

- продолжить последний draft;
- открыть другой draft этого типа;
- создать новый.

Flow восстанавливает шаг, scroll anchor, значения, upload states и последнюю
известную validation summary. Пароли, auth tokens и закрытые контактные данные
в section data не сохраняются.

Offering и каждый Cohort имеют независимую revision. Restore не подменяет
незавершённый Cohort последней опубликованной редакцией Offering.

### 7.4 Offline и conflict

- Offline разрешает создавать и редактировать локальный draft.
- Publish offline запрещён; кнопка объясняет, что draft сохранён.
- После восстановления сети sync повторяется с bounded retry.
- Baseline конфликта: last-write-wins плюс обязательное предупреждение.
- До выбора пользователем нельзя молча скрывать факт remote overwrite.
- Ошибка несовместимой schema version открывает guarded read-only recovery и
  сохраняет исходные данные для migration.

## 8. Шаг 1 — Основное и категория

### 8.1 Порядок секций

1. `PublisherSection`.
2. `OfferingKindSection`.
3. `NameDescriptionSection`.
4. `CategorySection`.
5. `DynamicCriteriaSection`.
6. `MediaSection`.

### 8.2 Поля

| Поле | Правило draft | Blocking для Publish |
|---|---|---|
| Title | 3–100 символов после trim | Да |
| Short description | 20–180 символов | Да |
| Full description | 50–10 000 символов | Да |
| Offering kind | Один из пяти enum | Да |
| Category/subcategory | Только compatible `C` | Да |
| System criteria | По активному profile | Required fields профиля |
| Tags | До `PolicyLimits.tagsMax`, только constrained tags | Нет |
| Cover | 1 изображение | Да |
| Gallery | До `PolicyLimits.galleryMax` assets по media policy | Нет |

Title не должен состоять только из emoji, URL или повторяющихся знаков.
Full description не должна подменять структурные поля расписания, цены и
правил участия.

### 8.3 Медиа

- Cover проходит client preprocessing и создаёт preview.
- Поддерживаются состояния `local / processing / uploading / ready / failed`.
- Publish требует `ready` cover; gallery с `failed` не публикуется.
- Удаление медиа отменяет upload, если возможно, и ставит orphan cleanup job.
- Повторная загрузка не должна создавать дубли.
- Alt text обязателен для смыслового cover и instructional media; для
  декоративного asset разрешён explicit decorative flag.
- Нельзя публиковать изображения с неподтверждёнными правами использования.

## 9. Шаг 2 — Программа и ведущий

### 9.1 `LearningDesignSection`

| Поле | Ограничение | Обязательность |
|---|---|---|
| Outcomes | 1+ структурированных результатов | Да |
| Curriculum modules | 1+ модулей/этапов со stable ID | Да |
| Prerequisites | none или структурированный список | Явный выбор |
| Preparation | Структурированные инструкции участнику | Нет |
| Teaching language | Из locale/language dictionary | Да |
| Skill level | Из active criteria/profile | Если требует profile |
| Take-home result | Краткое описание результата | Для workshop/masterclass, иначе optional |

Outcomes описывают проверяемый результат для участника, а не рекламные
обещания. Curriculum module может содержать agenda items, resources, задания,
completion criteria и release policy. Agenda не является расписанием
occurrence.

Teaching language использует тот же field ID и то же состояние, что
`language` из dynamic criteria, если активный profile выводит это поле.
Два независимых значения языка в payload запрещены. Аналогично skill level
берётся только из criteria, а Learning section показывает его в своём
контексте без копирования.

Если duration заполнена у каждого agenda item, их сумма не может превышать
длительность связанной occurrence. Неполная разбивка по минутам допустима и
даёт warning, но не blocking error.

### 9.2 Условная логика variant

- `class`: outcome и agenda обязательны; take-home result optional.
- `workshop`: обязателен практический результат.
- `masterclass`: обязателен instructor и краткое описание expertise;
  слово «сертифицированный» требует verification/moderation evidence.
- `course`: требуется curriculum; delivery может быть fixed cohort, rolling
  enrollment или on-demand. Для cohort default `attendanceScope = full_series`,
  но отдельные modules/occurrences могут продаваться через price option.
- `experience`: требуется описание guided participation и observable result;
  нельзя использовать как способ обойти несовместимую taxonomy.

### 9.3 `InstructorSection`

| Поле | Правило |
|---|---|
| Same as Publisher | Boolean, default true для user Publisher |
| Display name | 2–80 символов |
| Short bio | 20–500 символов |
| Expertise | 1–5 constrained текстовых пунктов |
| Profile/reference URL | Только HTTPS, optional |
| Verified credentials | Только server/moderation field, UI Creator не задаёт |

Instructor assignment задаётся на Offering и может переопределяться в Cohort
или Occurrence. Замена ведущего после booking является material operational
change и запускает уведомления, transfer/refund policy и audit.

### 9.4 Learning delivery

Для course и расширенного class flow поддерживаются:

- resources: text, file, safe external link, audio/video;
- release: immediately, after booking, по дате, после attendance или
  completion предыдущего module;
- homework/assignment с due date, submission и instructor feedback;
- progress: `not_started / in_progress / completed`;
- completion rules по modules, attendance и assignments;
- certificate template, serial number и verification URL;
- learner export и privacy-controlled retention.

Материалы и задания не обязательны для простого workshop/experience, но их
наличие не требует другого Create type.

Resource и assignment upload проходят malware/type/size scan. Submission
доступен learner и разрешённой instructor team, не публикуется автоматически и
имеет retention/export/delete policy. Signed resource URL короткоживущий и
проверяет Entitlement при каждом получении.

## 10. Шаг 3 — Delivery, cohorts, локации и расписание

### 10.1 Delivery model

`deliveryFormat` задаётся по умолчанию на Cohort и может переопределяться у
Occurrence:

- `offline` — физическая локация обязательна;
- `online_live` — живое онлайн-занятие;
- `hybrid` — физическое и онлайн-участие с отдельными inventory pools;
- `on_demand` — доступ к curriculum без обязательного live occurrence;
- `blended` — комбинация live occurrences и on-demand modules.

`onlineAccessMode`:

- `gated_after_internal_booking` — персональная ссылка доступна только
  подтверждённому Booking;
- `instructions_after_external_registration` — доступ передаёт внешний
  организатор;
- `public_session_url` — публичная HTTPS-ссылка без персонального token;
- `integrated_provider` — gated access через поддерживаемого провайдера.

Registration URL, payment URL и session URL — разные поля. Секретный access
token хранится за защищённым backend boundary, не попадает в analytics, push,
logs или публичный Details и становится доступен только в разрешённое окно.

### 10.2 Физическая локация

Для offline/hybrid обязательны:

- marketCityId и city;
- venue name;
- address components;
- lat/lng и accuracy/source metadata;
- подтверждение точки на карте;
- понятный meeting point, если вход неочевиден.

Связь с существующим Place выполняется только через `placeId`. Cohort может
иметь основную площадку, а Occurrence — явный venue override. Смена площадки
после booking запускает material-change policy.

Поддерживаются room/zone, accessibility route, arrival window, parking/public
transport note и скрытые staff instructions. Последние не видны участникам.

### 10.3 Cohort и schedule modes

`scheduleMode`:

- `one_time` — один Occurrence;
- `fixed_series` — явно заданный конечный набор Occurrence;
- `recurring_rule` — recurrence rule с end condition и exceptions;
- `rolling_cohort` — повторяющиеся окна старта с независимым Enrollment;
- `on_demand` — access window без обязательного Occurrence;
- `mixed` — live schedule плюс on-demand modules.

Creator может создать несколько Cohort одного Offering: разные даты, языки,
города, instructors, capacity и price options. Cohort не копирует контент
Offering, а ссылается на конкретную approved revision.

### 10.4 Occurrence и recurrence

Для каждой live Occurrence:

- локальные дата/время вводятся в IANA timezone;
- сохраняются `startAtUtc`, `endAtUtc`, timezone и resolved UTC offset;
- start строго раньше end;
- короткие, длинные и multi-day форматы разрешаются category/market policy;
- local `loc_*` ID заменяется permanent ULID при Publish;
- status: `scheduled / rescheduled / in_progress / completed / cancelled`.

Recurrence поддерживает стандартный versioned rule contract: daily, weekly,
monthly, выбранные weekdays, interval, count/until, inclusion dates и
exception dates. Generated occurrences materialизуются на ограниченный
операционный горизонт, а правило остаётся источником будущей генерации.

Инварианты:

- Occurrence отсортированы и не пересекаются внутри одного resource scope;
- нет скрытого platform ceiling вроде «52 занятия»; защитный batch limit
  отделён от общего числа occurrence;
- прошлую Occurrence нельзя создать как новую, но разрешён админский import
  истории с provenance;
- DST gap блокирует несуществующее local time;
- DST overlap требует явного offset/fold;
- изменение timezone пересчитывается только после preview диффа;
- exceptions не меняют исходное recurrence rule молча.

### 10.5 Attendance и enrollment scope

| `attendanceScope` | Значение |
|---|---|
| `single_occurrence` | Booking относится к одной Occurrence |
| `selected_occurrences` | Пользователь выбирает разрешённый набор |
| `full_series` | Enrollment относится ко всему Cohort |
| `module_bundle` | Доступ к набору curriculum modules/occurrences |
| `on_demand_access` | Доступ на заданный период или бессрочно по policy |

Capacity может быть cohort-wide, occurrence-specific, resource-based или
разделённой по delivery channel/ticket type. Для full-series одно место
резервируется на всём требуемом наборе; операция атомарна.

### 10.6 Deadlines и access windows

Booking policy поддерживает:

- sales opens/closes;
- approval deadline;
- payment deadline;
- waitlist promotion deadline;
- cancellation/refund cutoff;
- transfer cutoff;
- online access opens/closes;
- assignment due dates.

Все timestamps хранятся UTC с timezone контекстом. Истёкший sales deadline
закрывает новую запись, но не архивирует Offering/Cohort и не отменяет
существующие Booking.

Published Cohort предоставляет versioned ICS export и calendar subscription.
Calendar event содержит stable UID, sequence/revision, timezone и cancellation
status. Приватная online access link никогда не попадает в публичный ICS;
персональный calendar feed защищён revocable token.

### 10.7 Reschedule и cancellation

До подтверждения изменения система показывает затронутые Booking, разницу
времени/места/instructor и финансовые последствия.

- Reschedule сохраняет Occurrence ID и пишет revision/audit.
- Cancellation необратимо помечает Occurrence cancelled, но не удаляет её.
- Участнику предлагаются accept change, transfer, credit или refund согласно
  policy и применимому законодательству.
- Массовое изменение выполняется idempotent job с progress и retry.
- Notification failure не откатывает confirmed schedule change, а создаёт
  retry/incident signal.

## 11. Шаг 4 — Участники, inventory, материалы, цены и booking

### 11.1 Участники и audience

| Поле | Production-правило |
|---|---|
| Minimum participants | Положительное число либо null; не больше capacity |
| Capacity | Положительное число, вычисляемый resource capacity или explicit unlimited для допустимого on-demand |
| Age min/max | 0–120, min ≤ max |
| Group composition | individual / couple / family / team / private group |
| Audience note | Локализуемый структурированный текст |
| Accessibility needs | Запрашиваются только с consent и минимизацией данных |

Platform не устанавливает скрытый предел 30 участников. Максимум приходит из
versioned PolicyLimits по category, venue, safety class и market. Необычно
большой практический формат требует staffing/safety plan или рекомендации
Event, но не молчаливого обрезания.

`currentParticipants` — вычисляемая projection подтверждённых Booking, а не
редактируемое поле. Публичные `spotsLeft` строятся из Inventory snapshot с
указанием freshness и не обещают место до успешного hold/confirmation.

### 11.2 Prerequisites, waiver и безопасность

- Если prerequisites отсутствуют, Creator явно выбирает No prerequisites.
- Опасные/физические практики требуют risk level, safety briefing, emergency
  contact policy и qualified staff.
- Age restriction согласуется с criteria и audience.
- Для несовершеннолетнего поддерживаются guardian consent, authorised pickup
  и минимизация данных ребёнка.
- Waiver имеет version, locale, effective date, signer, timestamp и immutable
  acceptance record; изменение waiver не переписывает прошлые согласия.
- Медицинские данные не собираются без legal basis, purpose и retention policy.
- Не допускаются медицинские, юридические или профессиональные гарантии без
  moderation/compliance policy.

### 11.3 `MaterialsSection`

`materialsPolicy`:

- `included` — основные материалы входят в цену;
- `bring_own` — участник приносит перечисленные предметы;
- `provided_with_extra_fee` — material add-on;
- `mixed` — комбинация;
- `digital_only` — доступ предоставляется как learning resource.

Каждый item имеет ID, название, quantity/unit, included flag, inventory impact,
age/safety note и optional price. Расходные материалы, арендуемый инвентарь и
take-home result не смешиваются.

Fulfillment mode: onsite, pickup, shipment или digital. Shipment требует
отдельного consent на адрес, delivery price/tax, supported region, tracking,
failure/return policy и удаления адреса после retention. Материальный kit не
считается доставленным только по client state.

Значение согласуется с dynamic criterion `equipment_provided`. Противоречие
блокирует Publish и предлагает исправить одно из полей; UI не выбирает
значение сам.

### 11.4 Price catalog

Offering/Cohort поддерживает versioned `PriceOption`:

- free;
- per person / occurrence;
- full cohort/course;
- selected occurrence bundle;
- group/family/team;
- tier: standard, concession, early bird, member;
- deposit + remaining balance;
- pay-what-you-want с minimum;
- subscription/membership entitlement;
- private/invite-only price.

PriceOption содержит Money, currency, inventory pool, sales window, eligibility,
included modules/materials, tax category, fee policy и cancellation policy ID.
Старая цена остаётся на существующем Order snapshot; правка не меняет уже
оплаченные заказы.

Details всегда показывает total payable до подтверждения, currency, tax/fee,
unit, refund conditions и то, что включено. «От» допустимо только при наличии
нескольких реально доступных вариантов.

### 11.5 Discounts, taxes и invoices

Поддерживаются:

- promo code и automatic promotion с priority/stacking rules;
- limited redemptions и eligibility;
- VAT/tax inclusive/exclusive по market;
- platform/organizer/service fees;
- invoice/receipt с immutable numbering;
- B2C/B2B billing data с отдельной privacy policy;
- multi-currency display и settlement без float arithmetic.

Money хранится integer minor units или decimal value object. Tax calculation,
rounding и exchange-rate snapshot выполняются server-side. Финансовые
документы после выпуска не редактируются — создаётся credit/correction record.

### 11.6 Registration modes

`registrationMode`:

- `drop_in` — без предварительной записи, если policy и capacity позволяют;
- `internal_instant` — атомарный hold → payment/confirmation;
- `internal_approval` — application form → approval → payment/confirmation;
- `internal_waitlist` — очередь при отсутствии inventory;
- `external` — безопасный переход к организатору;
- `hybrid` — inventory синхронизируется с внешней системой через connector;
- `invite_only` — signed invitation/controlled access.

Internal registration требует authenticated User. Guest может просматривать
Offering и начинать flow, но перед созданием Booking проходит Auth с
восстановлением выбранных Cohort, PriceOption и quantity.

External registration URL может быть общим, cohort-specific или
occurrence-specific. Connector обязан иметь source-of-truth policy,
idempotency, reconciliation и degradation behavior. При недоступном connector
нельзя показывать недостоверное `spotsLeft`.

### 11.7 Inventory и seat holds

Inventory scope:

- Cohort целиком;
- конкретная Occurrence;
- delivery channel;
- room/resource;
- PriceOption/ticket tier;
- shared pool между вариантами.

Создание hold — атомарная server operation с `expiresAtUtc`. Confirmed Booking
уменьшает available inventory; expired/cancelled hold освобождает его ровно
один раз. Idempotency защищает от двойного tap/webhook. Oversell разрешён
только явной policy и никогда не возникает из eventual-consistency race.

Group booking резервирует количество мест одной транзакцией. Для course
full-series резервирование всех обязательных occurrence атомарно.

### 11.8 Booking, approval и waitlist

Reservation state следует ADR 0013:

- `pending / confirmed / cancelled / expired / waitlisted`.

Отдельные axes:

- approval: `not_required / pending / approved / rejected`;
- payment: `not_required / pending / authorized / paid / failed /
  partially_refunded / refunded / disputed`;
- attendance: `not_recorded / checked_in / attended / partial / no_show`.

Эти значения на Booking — server-controlled projections. Источник payment
state — Payment/Ledger, attendance state — AttendanceRecord, approval state —
audited decision. Client не записывает их напрямую.

Application questionnaire использует typed fields, purpose, visibility и
retention. Ответ не может быть публичным. Approval имеет deadline, reason code,
staff audit и notification.

Waitlist хранит ordering policy, requested quantity, eligible price options и
promotion expiry. Promotion создаёт временный hold; пропуск освобождает место и
продвигает следующего. Creator не может тайно менять порядок без audit и
уведомления.

### 11.9 Payment, payout, refund и dispute

После отдельного Accepted commerce ADR production flow поддерживает:

1. KYC/KYB, payout account и tax profile Publisher;
2. server-calculated Order;
3. provider payment intent и SCA/3DS при необходимости;
4. idempotent webhook verification;
5. Booking confirmation только по доверенному payment result;
6. organizer ledger и payout;
7. full/partial refund, credit или transfer;
8. dispute/chargeback и negative-balance handling;
9. reconciliation и financial audit.

Internal paid mode доступен только при active CommerceAccount Publisher,
поддерживаемой currency и валидных merchant/tax settings. Ограниченный или
pending account не может принимать новые платежи, но сохраняет доступ к
refund/dispute obligations.

Ledger является immutable double-entry ledger: любая charge, fee, tax, payout,
refund и adjustment балансируется. Исправление создаёт compensating entry,
никогда не переписывает финансовую историю.

Client success screen не является доказательством оплаты. Source of truth —
server ledger + verified provider event. Секреты и card data не проходят через
Recharge client.

Cancellation policy версионируется и прикрепляется к Order snapshot. Automatic
refund рассчитывается по времени, причине, использованной части bundle,
невозвратным fees и applicable law. Staff override требует capability, reason
и immutable audit.

### 11.10 Attendance и check-in

Check-in поддерживает:

- signed rotating QR;
- staff participant search с минимально нужными данными;
- manual check-in с reason;
- offline queue с защитой от duplicate scan;
- per-occurrence attendance;
- partial attendance и no-show;
- guardian pickup для детских форматов;
- audit времени, staff ID и device/session.

Attendance может открывать learning material, подтверждать review eligibility,
выдавать certificate и влиять на no-show policy. Она не меняет payment state.

### 11.11 Transfer и participant self-service

В `My bookings` пользователь может согласно policy:

- отменить Booking;
- запросить refund/credit;
- перенести участие на другой Cohort/Occurrence;
- заменить участника;
- обновить questionnaire до cutoff;
- скачать invoice/ticket;
- получить online access;
- увидеть attendance, progress и certificate.

Каждая операция проверяет inventory, deadline, payment consequences и
idempotency до подтверждения.

### 11.12 Communications

Creator/staff может отправлять cohort announcement, occurrence update,
preparation reminder и learning feedback в пределах capability. Сообщение:

- имеет immutable sender/publisher ID и audience scope;
- локализуется либо явно помечает source language;
- проходит abuse/rate-limit и attachment policy;
- не раскрывает список получателей другим участникам;
- поддерживает delivery status и correction/follow-up вместо скрытого
  переписывания уже отправленного текста.

Support thread по Booking доступен purchaser/participant и разрешённой staff
команде. Массовый marketing не маскируется под transactional communication.

### 11.13 End-to-end booking orchestration

Internal booking выполняется server-side:

1. Получить актуальные Offering/Cohort/Inventory/PriceOption revisions.
2. Проверить eligibility, sales window, quantity и policy.
3. Рассчитать signed PriceQuote с tax/fee/discount и expiry.
4. Атомарно создать Inventory hold.
5. Собрать только требуемые participant/questionnaire/waiver данные.
6. Если нужен approval — перевести reservation в pending и применить deadline.
7. Если нужна оплата — создать Order и provider intent по idempotency key.
8. Подтвердить Payment только по verified server event.
9. Атомарно подтвердить Booking, превратить hold в allocation и создать
   Enrollment/access grants.
10. Отправить ticket/invoice/calendar/notification асинхронно с retry.

При отказе, timeout или expiry compensation освобождает hold ровно один раз.
Неизвестный payment result переводит flow в Processing до reconciliation, а не
в success/failure по догадке клиента.

External flow создаёт outbound intent и attribution, но не помечает Booking
confirmed без доверенного connector callback/import. Hybrid connector
периодически reconciles inventory и bookings с назначенным source of truth.

## 12. Amenities и accessibility

`AmenitiesSection` получает допустимые опции из `AmenityTaxonomy` с учётом
типа и category. Нельзя хардкодить полный список в classWorkshop config.

Для offline/hybrid минимум рассматриваются:

- wheelchair access;
- accessible toilet, если разрешено taxonomy;
- seating/standing arrangement;
- changing room или shower для применимых физических занятий;
- parking/public transport note;
- provided equipment и protective equipment.

Отсутствие accessibility feature не скрывается. Неизвестное значение
отличается от false. Public Details показывает только подтверждённые значения
и дату их обновления, если она доступна.

## 13. Шаг 5 — Preview и Publish readiness

### 13.1 Preview

Preview показывает в пользовательском порядке:

1. Cover, title, offering kind.
2. Выбранный Cohort, occurrences/access window, timezone и duration.
3. Location/online delivery и access policy.
4. Доступные PriceOptions, tax/fee, discounts и material add-ons.
5. Category, skill level, language и age.
6. Outcomes.
7. Curriculum, agenda, resources и completion rules.
8. Instructor team, collaborators, Publisher и verification states.
9. Included / bring-your-own materials.
10. Live availability snapshot, booking/approval/waitlist CTA.
11. Accessibility, safety, waiver и cancellation/refund information.
12. Attendance scope, ближайшие occurrences и cohort alternatives.
13. Learning access, homework/progress и certificate, если включены.

Preview использует public projection. Нельзя иметь отдельный ручной mapper,
из-за которого Preview отличается от Details.

### 13.2 Readiness

Readiness возвращает:

- blocking errors, сгруппированные по шагам;
- warnings;
- pending media;
- capability state;
- online/offline state;
- cohort/occurrence generation diff;
- inventory pools и booking policy;
- price/tax/fee calculation preview;
- payment provider/connector health;
- waiver, consent и compliance versions;
- revision, с которой будет выполнен Publish.

Tap по проблеме открывает конкретный шаг и поле.

### 13.3 Подтверждения

Перед отправкой Creator подтверждает:

- право публиковать описание и медиа;
- точность расписания, цены и условий;
- наличие права проводить заявленную активность;
- применимые safety и age requirements;
- достоверность capacity, inventory и staffing;
- применимую cancellation/refund/tax policy;
- что внешние ссылки и connectors принадлежат ожидаемому организатору;
- право собирать questionnaire/waiver данные и заявленные сроки retention.

Согласия версионируются policy version и timestamp.

## 14. Полная Publish-валидация

Publish блокируется, если:

1. auth/session недействительны;
2. нет create/publish capability для Publisher;
3. object type не `classWorkshop`;
4. категория не разрешает ContentType `classWorkshop` (обозначение `C`);
5. обязательные dynamic criteria не заполнены;
6. title/descriptions/offering kind невалидны;
7. нет outcomes или curriculum;
8. instructor не подтверждён через `sameAsPublisher` и не заполнен отдельно;
9. delivery mode не имеет Cohort/occurrence/access configuration;
10. start/end, duration или access window нарушают активный PolicyLimits;
11. заполненные agenda minutes превышают duration связанной occurrence;
12. capacity не положительна, min participants больше capacity или resource
    pools противоречат друг другу;
13. occurrence пересекается в одном resource scope или имеет
    неразрешённую DST ambiguity;
14. location/online fields не соответствуют delivery format;
15. materials policy противоречит equipment criterion;
16. PriceOption не имеет Money, unit, inventory scope, tax/fee или sales window;
17. registration mode не имеет корректного inventory/connector configuration;
18. internal payment включён без действующего provider/merchant/tax config;
19. approval questionnaire, waiver или retention не имеют versioned policy;
20. cover не в состоянии ready или обязательный alt text отсутствует;
21. media upload ещё выполняется;
22. обязательные подтверждения не приняты;
23. draft schema/revision конфликтует с ожидаемой;
24. отсутствует сеть;
25. сработали duplicate, abuse, compliance или publish velocity checks.

Warnings не блокируют Publish, если policy явно не повысила их до error.
Примеры warnings: мало media, не заполнен optional accessibility note,
необычная capacity/duration, occurrence скоро начинается, внешний inventory
connector временно degraded.

## 15. Нормализация

До проверки:

- trim строк;
- схлопывание повторных пробелов;
- нормализация line endings;
- URL scheme и hostname в каноническую форму;
- currency uppercase;
- deduplicate tags, outcomes и material items с сохранением порядка;
- local date/time → UTC только через выбранную IANA timezone;
- amount хранится decimal/minor-unit моделью, не binary floating point;
- phone/email нормализуются только после consent и не попадают в public model
  автоматически;
- recurrence materialизуется детерминированно с rule version;
- price, tax, fee и discount получают immutable calculation snapshot;
- пустые optional strings → null;
- критерии, не относящиеся к активному profile, удаляются из publish payload.

Нормализация не должна менять смысл пользовательского текста или
автоматически переводить его.

## 16. Publish pipeline

1. Flush autosave.
2. Получить immutable snapshot draft revision.
3. Нормализовать snapshot.
4. Выполнить полную validation.
5. Повторно проверить session, Publisher и capabilities.
6. Проверить media readiness.
7. Запустить duplicate/abuse checks.
8. Заменить `loc_*` Offering, Cohort, Occurrence, module и price IDs
   постоянными ULID.
9. Сохранить явный local-to-permanent ID mapping.
10. Сформировать idempotency key для snapshot revision.
11. Отправить атомарный publish command Offering revision + initial Cohort.
12. При подтверждённом успехе сохранить серверный lifecycle/moderation result
    и permanent ID; первая публикация по умолчанию `pending_review`.
13. Очистить только опубликованный draft или пометить его submitted.
14. Показать success state.

Повторный tap, timeout и retry с тем же idempotency key не создают второй
объект. При неизвестном результате клиент сначала запрашивает статус команды.

### 16.1 Success

Для первой публикации экран сообщает:

- Submitted for review;
- permanent object ID;
- что объект пока не виден в Discover;
- действия View submission, Back to Create Hub и Done.

View submission открывает read-only pending-review representation через
стабильный object route. Deep-link contract утверждается вместе с router slice,
а не придумывается виджетом.

Для нового Cohort уже approved Offering сервер может вернуть `published`,
`scheduled` или `pending_review` согласно material-change/moderation policy.
Client не подменяет этот результат локальным предположением.

## 17. Moderation

Moderation проверяет:

- соответствие типа и категории;
- вводящие в заблуждение outcomes/credentials;
- права на медиа;
- learning resources, assignments и certificate claims;
- external URL, connectors и publisher domain;
- запрещённые товары, опасные практики и age policy;
- spam/duplicates;
- price/tax/fee/cancellation consistency;
- suspicious booking/payment/refund patterns;
- questionnaire, waiver и sensitive-data purpose.

Результат:

- approved → `published`;
- rejected → editable revision + reason codes;
- needs changes → draft/revision с field anchors;
- hidden → только system/moderation action.

Повторная отправка исправленной revision использует новый idempotency key, но
сохраняет object ID и audit history.

## 18. Редактирование опубликованного объекта

### 18.1 Несущественные изменения

Исправление опечаток, alt text или необязательного описания может применяться
без снятия approved revision, если moderation policy разрешает.

### 18.2 Существенные изменения

Материальными считаются:

- Publisher или instructor identity;
- category/subcategory/offering kind;
- outcomes, prerequisites или safety requirements;
- curriculum/completion/certificate rules;
- delivery format, Cohort, location, occurrence или timezone;
- attendance scope;
- capacity/inventory, age restrictions;
- price option, tax/fee, material add-on;
- booking/approval/waitlist или cancellation/refund policy;
- cover.

Материальная правка создаёт pending revision. До approval публичной остаётся
последняя approved revision, кроме срочных safety corrections.

Новая PriceOption применяется только к новым Order. Existing Booking сохраняет
snapshot условий покупки. Изменение curriculum не отнимает уже выданный
learner access без отдельной legal/retention policy.

### 18.3 Series edits

Creator выбирает scope:

- Offering template для будущих Cohort;
- один Cohort;
- эта и будущие occurrence;
- только выбранная будущая occurrence;
- вся серия, если ни одна occurrence не началась.

Прошедшие occurrence неизменяемы, кроме moderation correction. Удаление
будущей occurrence считается cancellation и должно инициировать уведомление,
transfer/refund flow для всех Booking.

### 18.4 Operational control center

Разрешённая команда управляет:

- Offering revisions и Cohort calendar;
- live inventory, holds, bookings, approval и waitlist;
- participant list, communications и check-in;
- learning release, assignments, progress и certificates;
- orders, refunds, payouts, disputes и reconciliation;
- reviews/reports, incidents и audit exports;
- conversion, attendance, revenue и cohort-quality insights.

Каждая вкладка проверяет собственную capability. Financial и participant data
не загружаются в общий dashboard payload, если текущему staff они не нужны.

## 19. Архивирование и удаление

- Archive скрывает объект из Discover, но сохраняет его владельцу.
- Offering нельзя архивировать, пока есть активные Cohort, неразрешённые
  Booking, refunds, disputes или обязательный learner access.
- Restore проходит capability и policy checks; при существенной устарелости
  возвращает объект в pending review.
- Delete по умолчанию soft, retention 30 дней.
- Financial, consent, waiver, safety и certificate records хранятся по своим
  legal retention policies и не удаляются общей кнопкой раньше срока.
- Hard delete выполняется после применимых retention/legal checks или
  удовлетворённого legal request.
- Объект с начавшейся occurrence нельзя выдавать за deleted без корректной
  cancellation/audit записи.
- Full audit доступен только admin/moderation.

## 20. Ошибки и восстановление

| Ошибка | Поведение |
|---|---|
| Session expired | Сохранить local draft, Auth и возврат в тот же flow |
| Capability revoked | Read-only state, смена допустимого Publisher или выход |
| Offline | Draft сохранён, Publish недоступен |
| Save failed | Retry, не очищать введённые данные |
| Media failed | Retry/remove конкретного asset |
| Invalid category | Вернуть к CategorySection, не выбирать замену автоматически |
| Schedule/DST error | Подсветить occurrence и показать локальное объяснение |
| External URL rejected | Сохранить draft, заменить URL |
| Inventory changed | Пересчитать availability/total и запросить подтверждение |
| Hold expired | Освободить hold, предложить повторить или waitlist |
| Payment requires action | Возобновить provider flow по тому же Order |
| Payment/webhook unknown | Показать Processing и сверить server ledger |
| Payment failed | Booking не подтверждать, сохранить retryable Order |
| Refund pending/failed | Не менять сумму локально, показать provider status |
| Connector degraded | Не обещать availability, fallback по source-of-truth policy |
| Waitlist promotion expired | Освободить hold и продвинуть следующего |
| Check-in offline conflict | Deduplicate server-side, сохранить audit |
| Learning resource unavailable | Retry/CDN fallback, progress не терять |
| Bulk reschedule partial failure | Продолжить idempotent job с failed items |
| Duplicate candidate | Показать кандидата и разрешённые действия policy |
| Rate limited | Показать retry-after, если возвращён |
| Publish timeout | Проверить idempotency status до нового command |
| Conflict | Warning + применённая LWW policy + recovery snapshot |
| Schema incompatible | Guarded read-only export/migration path |
| Moderation rejected | Открыть revision на первом reason anchor |

## 21. Discover и Details projection

После approval объект участвует в общей выдаче как отдельный content type:

- Search/Feed/Map используют один `DiscoverQuery`;
- карта использует физическую точку offline/hybrid объекта;
- online-only объект не получает фиктивные координаты;
- time-fit строится по occurrence event slots;
- карточка показывает next occurrence/access mode, live availability,
  duration, location/online, price from/total, skill level и Publisher;
- Details показывает Offering, доступные Cohort, программу, instructor team,
  price breakdown, cancellation policy и booking/waitlist CTA;
- прошедший one-time объект не показывается в актуальной выдаче;
- series показывает следующий доступный Cohort/Occurrence;
- on-demand course участвует в отдельном availability mode без фиктивного slot;
- rating/reviews разделяют Offering quality и конкретный Cohort experience;
- verified-attendance badge выдаётся только по доверенному AttendanceRecord;
- изменение фильтров не мутирует create draft.

Geo + freshness остаются baseline ranking; popularity — secondary signal.
Zero-result flow смягчает фильтры согласно общей Discover policy, а не внутри
этого блока.

## 22. Уведомления

- submission accepted;
- moderation approved/rejected/needs changes;
- reminder Creator о незавершённом draft;
- booking created/pending/confirmed/rejected/cancelled;
- payment action required/paid/failed/refunded/disputed;
- waitlist joined/promoted/expired;
- occurrence reminder/changed/cancelled;
- venue/instructor/access change;
- sales, payment, transfer и cancellation deadlines;
- learning resource released, assignment due/feedback;
- attendance/check-in и certificate issued/revoked;
- payout/reconciliation/connector incident для разрешённой staff role;
- report/auto-hide outcome, если разрешено policy.

В уведомления не включаются приватные instructor/contact данные. Каждое
уведомление ссылается на immutable object ID, имеет deduplication key,
локализованный template, channel preference, delivery status и retry policy.
Критичные transactional сообщения не зависят от marketing consent, но
соблюдают legal basis и user channel settings.

## 23. Analytics и observability

### 23.1 Product events

| Event | Когда | Минимальные параметры |
|---|---|---|
| `create_class_workshop_started` | Создан draft | source, publisher_type |
| `create_class_workshop_step_viewed` | Открыт шаг | step_id |
| `create_class_workshop_kind_selected` | Выбран variant | offering_kind |
| `create_class_workshop_category_selected` | Выбрана taxonomy | category_id, subcategory_id, profile_id |
| `create_class_workshop_schedule_configured` | Валидное расписание | mode, occurrence_count, duration_bucket |
| `create_class_workshop_previewed` | Открыт Preview | completeness_bucket |
| `create_class_workshop_publish_attempted` | Начат command | draft_revision |
| `create_class_workshop_publish_succeeded` | Подтверждён успех | lifecycle |
| `create_class_workshop_publish_failed` | Ошибка | reason_code, step_id |
| `class_workshop_external_registration_opened` | CTA в Details | object_id, provider_domain_class |
| `class_workshop_booking_started` | Начало booking | cohort_id, inventory_scope, price_option_id |
| `class_workshop_booking_confirmed` | Подтверждение | booking_id, registration_mode |
| `class_workshop_waitlist_joined` | Вход в очередь | cohort_id, quantity_bucket |
| `class_workshop_payment_result` | Финальный payment result | order_id, controlled_status |
| `class_workshop_checked_in` | Check-in | occurrence_id, method |
| `class_workshop_module_completed` | Completion | module_id, completion_mode |
| `class_workshop_certificate_issued` | Certificate | cohort_id, template_version |

Не отправляются title, description, instructor bio, точный адрес, URL,
email/phone или свободный prerequisites text.

### 23.2 Technical signals

- autosave latency/error;
- media processing/upload latency/error;
- validation error counts по controlled code;
- publish latency/result;
- conflict/migration count;
- occurrence generation/DST error;
- inventory hold/confirm latency и oversell invariant;
- payment webhook/reconciliation/refund latency;
- waitlist promotion conversion;
- notification delivery/duplicate rate;
- check-in conflict rate;
- learning resource availability и progress consistency;
- connector health и source-of-truth drift;
- crash/performance по build/session с учётом consent.

Publish attempt связывается correlation/idempotency ID без записи секретов.
Booking/Order/Payment используют разные correlation IDs со связью через
controlled internal trace, а не через PII.

### 23.3 Reliability и эксплуатационные гарантии

- Для publish, availability, hold, booking, payment, check-in и learning access
  задаются отдельные SLO/error budgets.
- Inventory/commerce commands имеют idempotency, outbox/inbox, replay-safe
  consumers и dead-letter recovery.
- Kill switches независимы для internal sales, конкретного payment provider,
  connector, waitlist promotion и mass notifications.
- Backup/restore и disaster-recovery регулярно проверяются; RPO/RTO задаются
  по классу данных, финансовые records восстанавливаются вместе с audit chain.
- Long-running publish/reschedule/refund jobs имеют progress, checkpoint,
  cancellation policy и operator recovery.
- Degraded mode не принимает действие, которое нельзя безопасно подтвердить:
  при неизвестном inventory/payment результате показывается Processing.
- Schema/event changes versioned и backward-compatible в период rollout.

## 24. Privacy, безопасность и abuse controls

- EU analytics/marketing consent — opt-in.
- Public contact data требует отдельного согласия.
- Questionnaire, guardian, waiver и accessibility данные имеют purpose,
  legal basis, field-level access и retention.
- External URL открывается с предупреждением о переходе к третьей стороне.
- URL проходит scheme/domain safety checks.
- Free text проходит moderation и length limits.
- Creator publish velocity baseline — 100 объектов/день.
- Duplicate detection учитывает Publisher, title fingerprint, category,
  location и пересекающиеся occurrence.
- Auto-hide: не менее пяти уникальных reporters на объект за 24 часа,
  затем moderation review.
- Reporter уникален по user/object.
- Audit history immutable и недоступна обычному пользователю.
- Payment fraud controls включают velocity, device/account signals и manual
  review без раскрытия внутренних правил.
- Staff export, participant list и financial report требуют capability,
  watermark/audit и ограниченного срока download URL.
- Online access использует short-lived signed grants; raw provider secret не
  хранится в public document.
- Certificate имеет revocation status и не раскрывает лишние данные.
- Logs не содержат auth token, join link, payment instrument, private contact,
  questionnaire answer или полный payload.

## 25. Локализация и accessibility UI

- Все labels, enum values, errors и CTA используют l10n keys.
- Все поддерживаемые market locales имеют content fallback и translation
  status; en/ru/lv обязательны для стартового market.
- Дата/время показываются локально с явной timezone при неоднозначности.
- Цена форматируется locale-aware и всегда имеет unit.
- Tax, fee, discount, refund и exchange-rate disclosure локализованы.
- Curriculum и Creator content могут иметь versioned translations; машинный
  перевод помечается и не перезаписывает source locale.
- Duration доступна текстом, не только иконкой.
- Ошибка связана с полем семантически и читается screen reader.
- Focus переходит к первому error.
- Tap targets и contrast следуют design system.
- Dynamic fields сохраняют логичный traversal order.
- Booking, payment, waiver, check-in и learning player доступны с keyboard и
  assistive technologies.
- Цвет не является единственным индикатором status.

## 26. Целевые семантические контракты

Контракты показывают границы агрегатов. Их нельзя реализовывать одной
монолитной entity или невалидируемым `Map<String, Object?>`.

### 26.1 Offering draft

```yaml
ClassWorkshopOfferingDraft:
  id: ULID | loc_*
  objectType: classWorkshop
  schemaVersion: integer
  revision: integer
  publisherRef: { type: user | page, id: ULID }

  identity:
    offeringKind: class | workshop | masterclass | course | experience
    sourceLocale: languageTag
    translations: { languageTag: LocalizedOfferingContent }
    title: string
    shortDescription: string
    fullDescription: string
    categoryId: string
    subcategoryId: string
    tags: [string]
    criteria: { fieldId: typedValue }

  learning:
    outcomes: [Outcome]
    modules:
      - id: ULID | loc_*
        title: string
        agendaItems: [AgendaItem]
        resourceRefs: [ULID]
        assignmentRefs: [ULID]
        completionRule: CompletionRule?
        releaseRule: ReleaseRule
    prerequisites: PrerequisitePolicy
    preparation: [Instruction]
    languageIds: [languageCode]
    takeHomeResult: string?
    certificateTemplateId: ULID?

  team:
    primaryInstructorRef: ProfileRef | GuestInstructor
    instructorAssignments: [InstructorAssignment]
    collaborators: [OfferingCollaborator]

  media:
    cover: MediaRef
    gallery: [MediaRef]
    instructionalResources: [LearningResourceRef]

  lifecycle: draft | pending_review | published | archived | hidden | deleted
  moderation: none | pending | approved | rejected
  sync: local_only | dirty | syncing | synced | conflict | failed
  createdAtUtc: timestamp
  updatedAtUtc: timestamp
```

### 26.2 Cohort draft

```yaml
CohortDraft:
  id: ULID | loc_*
  offeringId: ULID | loc_*
  offeringRevision: integer
  schemaVersion: integer
  timezone: IANA

  delivery:
    format: offline | online_live | hybrid | on_demand | blended
    defaultPlaceId: ULID?
    defaultAddress: Address?
    defaultGeo: GeoPointWithAccuracy?
    onlineAccessPolicy: OnlineAccessPolicy?

  schedule:
    mode: one_time | fixed_series | recurring_rule |
          rolling_cohort | on_demand | mixed
    recurrenceRule: VersionedRecurrenceRule?
    occurrences: [OccurrenceDraft]
    accessWindow: AccessWindow?
    attendanceScope: single_occurrence | selected_occurrences |
                     full_series | module_bundle | on_demand_access

  participation:
    minParticipants: integer?
    audiencePolicy: AudiencePolicy
    safetyPolicy: SafetyPolicy
    waiverVersionId: ULID?
    amenities: { amenityId: availabilityState }

  inventory:
    pools: [InventoryPoolDraft]
    holdPolicy: HoldPolicy
    oversellPolicy: OversellPolicy

  materials:
    policy: included | bring_own | provided_with_extra_fee |
            mixed | digital_only
    items: [MaterialItem]

  commerce:
    priceOptions: [PriceOptionDraft]
    promotionRefs: [ULID]
    taxPolicyRef: ULID?
    feePolicyRef: ULID?
    cancellationPolicyRef: ULID
    settlementCurrency: currencyCode

  booking:
    mode: drop_in | internal_instant | internal_approval |
          internal_waitlist | external | hybrid | invite_only
    salesWindow: TimeWindow?
    questionnaireVersionId: ULID?
    externalConnectorRef: ULID?
    waitlistPolicy: WaitlistPolicy?
    transferPolicy: TransferPolicy?

  learningDelivery:
    releaseOverrides: [ModuleReleaseOverride]
    completionRuleOverride: CompletionRule?

  lifecycle: draft | pending_review | published | archived | hidden | deleted
  moderation: none | pending | approved | rejected
  revision: integer
```

### 26.3 Operational entities

```yaml
Occurrence:
  id: ULID
  cohortId: ULID
  startAtUtc: timestamp
  endAtUtc: timestamp
  timezone: IANA
  resolvedOffset: string
  deliveryOverride: DeliveryOverride?
  instructorAssignments: [InstructorAssignment]
  inventoryPoolRefs: [ULID]
  status: scheduled | rescheduled | in_progress | completed | cancelled

Booking:
  id: ULID
  cohortId: ULID
  purchaserId: ULID
  participants: [UserRef | BookingScopedGuestParticipant]
  inventoryScope: InventoryScope
  reservationState: pending | confirmed | cancelled | expired | waitlisted
  approvalState: not_required | pending | approved | rejected
  paymentState: not_required | pending | authorized | paid | failed |
                partially_refunded | refunded | disputed
  priceSnapshot: PriceCalculationSnapshot
  policySnapshots: PolicySnapshotRefs
  holdExpiresAtUtc: timestamp?
  createdAtUtc: timestamp

Enrollment:
  id: ULID
  bookingId: ULID
  learnerRef: UserRef | BookingScopedGuestParticipant
  accessWindow: AccessWindow
  progressState: not_started | in_progress | completed

Entitlement:
  id: ULID
  holderRef: UserRef | BookingScopedGuestParticipant
  sourceRef: OrderRef | MembershipRef | StaffGrantRef
  scope: OfferingRef | CohortRef | ModuleBundleRef
  validFromUtc: timestamp
  validUntilUtc: timestamp?
  status: active | suspended | expired | revoked

AttendanceRecord:
  id: ULID
  bookingId: ULID
  occurrenceId: ULID
  state: checked_in | attended | partial | no_show
  source: qr | staff | import
  recordedAtUtc: timestamp

Order:
  id: ULID
  bookingId: ULID
  lines: [OrderLineSnapshot]
  totals: PriceCalculationSnapshot
  invoiceRef: ULID?

Payment:
  id: ULID
  orderId: ULID
  provider: controlledEnum
  providerIntentRef: opaqueRef
  amount: Money
  state: pending | authorized | paid | failed | disputed
  idempotencyKey: opaque

Refund:
  id: ULID
  paymentId: ULID
  bookingId: ULID
  amount: Money
  reasonCode: controlledEnum
  state: pending | succeeded | failed
  policySnapshotRef: ULID

Payout:
  id: ULID
  publisherRef: PublisherRef
  settlementPeriod: TimeWindow
  currency: currencyCode
  gross: Money
  fees: Money
  refundsAndDisputes: Money
  net: Money
  state: pending | processing | paid | failed | held

LedgerEntry:
  id: ULID
  orderId: ULID
  accountRef: opaqueRef
  entryType: charge | fee | tax | payout | refund | adjustment
  amount: Money
  effectiveAtUtc: timestamp

WaitlistEntry:
  id: ULID
  inventoryScope: InventoryScope
  requestedQuantity: integer
  orderKey: serverControlled
  state: waiting | promoted | accepted | expired | removed

ProgressRecord:
  id: ULID
  enrollmentId: ULID
  moduleId: ULID
  state: not_started | in_progress | completed
  completionEvidence: CompletionEvidence?
  updatedAtUtc: timestamp

CohortMessage:
  id: ULID
  cohortId: ULID
  senderRef: UserRef
  audienceScope: AudienceScope
  kind: announcement | occurrence_update | feedback | support
  localizedContent: { languageTag: MessageContent }
  contentRevision: integer
  sentAtUtc: timestamp

Certificate:
  id: ULID
  enrollmentId: ULID
  templateVersionId: ULID
  serialNumber: string
  issuedAtUtc: timestamp
  verificationToken: opaque
  status: valid | revoked
```

### 26.4 Соответствие текущей `CreateDraftEntity`

| Семантика | Текущее поле | Production-разрыв |
|---|---|---|
| Object type | `objectType` | Уже есть |
| Offering | title/category/descriptions | Нужен versioned Offering aggregate |
| Criteria | `sectionData['criteria']` | Нужна schema validation |
| Learning | произвольный sectionData | Нужны modules/resources/progress contracts |
| Time | start/end/duration/scheduleSlots | Нужны Cohort, recurrence и Occurrence |
| Location | format/city/address/lat/lng | Нужны delivery override и typed geo |
| Team | organizer fields | Нужны Publisher, instructors и collaborators |
| Capacity | min/max/current | Нужны InventoryPool и atomic holds |
| Price | isFree/basePrice/currency | Нужны PriceOption, tax/fee и Order snapshot |
| Registration | bookingLink + flags | Нужны Booking/approval/waitlist/connectors |
| Payment | отсутствует | Нужны Order/Payment/Refund/Ledger boundaries |
| Attendance | отсутствует | Нужен auditable per-occurrence record |
| Status | draft/moderation/publish enums | Нельзя хранить противоречивые дубли |
| IDs | текущий draft-style ID | `loc_*` → permanent ULID mapping |

До миграции versioned `sectionData` допустим как storage adapter, но domain и
application обязаны видеть typed contracts. UI не принимает решения по
произвольным map keys.

## 27. Конфигурация form engine

```yaml
CreateTypeConfig:
  type: classWorkshop
  availabilityKinds: [eventSlots, accessWindows]
  policyLimitsRef: classWorkshopPolicyByMarketAndCategory
  defaults:
    categoryId: workshops_masterclasses
    subcategoryId: workshop
  steps:
    - id: identity
      sections: [PublisherSection, OfferingKindSection,
                 NameDescriptionSection, CategorySection,
                 DynamicCriteriaSection, MediaSection]
    - id: learning
      sections: [LearningDesignSection, InstructorTeamSection,
                 LearningResourcesSection, CertificateSection]
    - id: delivery
      sections: [CohortSection, DeliveryFormatSection, LocationSection,
                 RecurrenceScheduleSection, OnlineAccessSection]
    - id: commerce
      sections: [ParticipantsSection, InventorySection, MaterialsSection,
                 AmenitiesSection, PriceCatalogSection, PromotionSection,
                 BookingPolicySection, WaitlistSection, PaymentPolicySection]
    - id: publish
      sections: [ComplianceSection, PreviewPublishSection]
```

Каждая секция объявляет schema/version, `visibleWhen`, `requiredWhen`,
normalization, field/section/publish validation, serialization, public
projection, analytics allowlist, permission scope и migration handler.

PolicyLimits приходят из versioned config. UI не содержит константы duration,
capacity, occurrences, media count или price tiers.

`CreateController` оркестрирует draft intent и use cases. Operational
controllers управляют Cohort, Booking, commerce, attendance и learning после
Publish; CreateController не превращается в god object.

## 28. Acceptance criteria

### AC-01 — Новый draft

- Given Creator имеет capability и выбрал допустимого Publisher.
- When выбирает Class / Workshop / Experience.
- Then создаются `loc_*` Offering и initial Cohort drafts с runtime defaults.

### AC-02 — Недостаточно прав

- Given User не имеет create capability.
- When открывает тип.
- Then видит Upgrade/access state, draft не создаётся.

### AC-03 — Taxonomy compatibility

- Given выбран `classWorkshop`.
- Then UI показывает только подкатегории, разрешающие `C`.
- And publish с несовместимой подкатегорией блокируется domain validation.

### AC-04 — Безопасная смена категории

- Given заполнены dynamic criteria.
- When новая подкатегория делает часть значений несовместимыми.
- Then показано предупреждение; Cancel ничего не меняет; Confirm сохраняет
  совместимое и удаляет stale data из publish payload.

### AC-05 — Variant rules

- Given выбран каждый offering kind.
- Then отображаются соответствующие required fields.
- And course поддерживает cohort, rolling и on-demand delivery без смены типа.

### AC-06 — Learning design

- Given нет outcome или curriculum.
- When пользователь продолжает к Preview/Publish.
- Then переход блокируется с field anchor.

### AC-07 — Instructor

- Given instructor отличается от Publisher.
- Then обязательны display name и bio.
- And Creator не может выставить verified credential.

### AC-08 — Policy-driven schedule

- Given duration/recurrence соответствует active PolicyLimits.
- Then schedule валиден и сохраняется в UTC + IANA timezone.
- And UI не содержит фиксированных duration/occurrence constants.

### AC-09 — Series и DST

- Given series пересекает DST.
- Then генерируются корректные UTC occurrence.
- And gap/overlap требует разрешения, а не молча сдвигает время.

### AC-10 — Location format

- Given offline, online и hybrid.
- Then каждая комбинация требует только соответствующие поля.
- And online-only не получает фиктивные координаты.

### AC-11 — Capacity policy

- Given capacity положительна, min ≤ capacity и staffing/resource policy
  выполнена.
- Then Publish разрешён независимо от бывшего лимита 30.

### AC-12 — Materials consistency

- Given materials policy противоречит `equipment_provided`.
- Then Publish блокируется с переходом к обоим связанным полям.

### AC-13 — Pricing unit

- Given paid series.
- Then amount показывается с currency и unit.
- And Preview не выдаёт цену серии за цену occurrence.

### AC-14 — Registration modes

- Given выбран drop-in, internal, approval, waitlist, external, hybrid или
  invite-only.
- Then форма строит корректную booking policy и валидирует её dependencies.

### AC-15 — Autosave/restore

- Given Creator закрыл приложение после изменений.
- When возвращается.
- Then draft, шаг, section data и upload states восстановлены.

### AC-16 — Offline

- Given нет сети.
- Then draft редактируется и сохраняется локально.
- And Publish недоступен с понятным recovery action.

### AC-17 — Preview parity

- Given валидный draft.
- When открыть Preview и затем опубликованный Details.
- Then значения совпадают по одному public projection mapper.

### AC-18 — Permanent IDs

- Given валидный draft с local Offering/Cohort/Occurrence/module/price IDs.
- When Publish подтверждён.
- Then все публикуемые сущности получают permanent ULID, mapping сохранён.

### AC-19 — Idempotency

- Given Publish timeout или повторный tap.
- Then тот же snapshot не создаёт дубликат.

### AC-20 — Moderation

- Given первая публикация Offering успешна.
- Then lifecycle `pending_review` и объект не виден в Discover до approval.

### AC-21 — Permission revoked

- Given право Publisher отозвано во время редактирования.
- Then локальный draft сохранён, Publish запрещён, flow становится read-only
  или предлагает допустимую смену Publisher.

### AC-22 — Accessibility/l10n

- Then flow доступен screen reader, не кодирует status только цветом и не
  содержит пользовательские строки вне l10n.

### AC-23 — Проектные проверки

- После будущей реализации `flutter analyze` имеет 0 ошибок.
- Все `flutter test` проходят.
- Реализация не меняет ADR и Category System молча.

### AC-24 — Несколько Cohort

- Given Offering опубликован.
- When Creator создаёт Cohort с другим языком, городом или instructor.
- Then Cohort ссылается на Offering revision и не копирует его identity.

### AC-25 — Atomic inventory

- Given два пользователя пытаются забронировать последнее место.
- Then ровно один hold подтверждается, если oversell policy выключена.

### AC-26 — Hold expiry

- Given hold истёк без confirmation.
- Then inventory освобождается один раз и следующий waitlist candidate может
  получить promotion.

### AC-27 — Approval

- Given booking требует approval.
- Then questionnaire хранится приватно, approval имеет audit/reason/deadline,
  а payment запускается согласно policy.

### AC-28 — Waitlist

- Given мест нет.
- Then пользователь входит в auditable очередь; promotion создаёт временный
  hold и не допускает oversell.

### AC-29 — Payment source of truth

- Given client получил success, но verified webhook ещё не обработан.
- Then Booking не становится paid/confirmed только по client state.

### AC-30 — Refund

- Given участник отменяет Booking.
- Then refund/credit/transfer рассчитывается по immutable policy и Order
  snapshot, а staff override требует capability и reason.

### AC-31 — Attendance

- Given один QR отсканирован повторно online/offline.
- Then создаётся один итоговый AttendanceRecord с полным audit.

### AC-32 — Learning progress

- Given Booking/Attendance удовлетворяет release rule.
- Then participant получает module access, progress не зависит от UI cache.

### AC-33 — Certificate

- Given completion rule выполнено.
- Then выдаётся certificate с serial, verification и revocation status.

### AC-34 — Operational change

- Given изменены время, место, instructor или cancellation policy после
  bookings.
- Then показан impact preview, созданы notifications и transfer/refund actions.

### AC-35 — Независимые состояния

- Then reservation, approval, payment и attendance states независимы и не
  кодируются одним status.

### AC-36 — External reconciliation

- Given external/hybrid connector прислал duplicate или out-of-order event.
- Then reconciliation идемпотентно получает один итоговый Booking/Inventory
  result по назначенному source of truth.

### AC-37 — Calendar privacy

- Given участник экспортирует calendar.
- Then stable UID/timezone/update/cancellation корректны, а private access link
  доступна только в revocable personal feed.

### AC-38 — Communications privacy

- Given staff отправляет cohort message.
- Then audience проверен capability, получатели не раскрыты друг другу,
  transactional и marketing consent не смешаны.

### AC-39 — Reliability

- Given command/job повторяется после crash.
- Then idempotency/checkpoint восстанавливает процесс без двойной продажи,
  оплаты, возврата, attendance или notification.

### AC-40 — Retention

- Given пользователь или Publisher запрашивает удаление.
- Then personal data удаляются/анонимизируются по policy, а обязательные
  financial/waiver/audit records сохраняются только законный срок.

## 29. Обязательная тестовая матрица

| ID | Сценарий | Ожидаемый результат |
|---|---|---|
| CW-01 | User без capability | Нет draft, Upgrade state |
| CW-02 | Creator/user Publisher | Draft создан |
| CW-03 | Creator/page Publisher | Membership/capability проверены |
| CW-04 | Несовместимая category | Не показывается и не публикуется |
| CW-05 | Смена profile с потерей fields | Confirm/Cancel работают |
| CW-06 | Class | Общие learning rules |
| CW-07 | Workshop | Take-home/practical result required |
| CW-08 | Masterclass | Instructor expertise required |
| CW-09 | Course fixed cohort, rolling и on-demand | Каждый mode валиден по своим правилам |
| CW-10 | Experience с неверной taxonomy | Blocking error |
| CW-11 | Разная duration | Решение по versioned PolicyLimits |
| CW-12 | Capacity 0/1/30/31/500 | 0 fail; остальные по safety/resource policy |
| CW-13 | Min participants > capacity | Fail |
| CW-14 | Offline location без geo | Fail |
| CW-15 | Online без online access policy | Fail |
| CW-16 | Hybrid без address | Fail |
| CW-17 | DST gap | Явная ошибка |
| CW-18 | DST overlap | Требуется offset choice |
| CW-19 | Recurrence больше 52 occurrence | Pass через batched materialization |
| CW-20 | Recurrence без end policy | Валидируется по schedule mode/policy |
| CW-21 | Free pricing | Нет amount |
| CW-22 | Fixed без unit | Fail |
| CW-23 | Course full-series price | Корректный label |
| CW-24 | External HTTP URL | Fail |
| CW-25 | External HTTPS URL | Pass после safety check |
| CW-26 | Materials/criteria conflict | Fail с двумя anchors |
| CW-27 | Cover processing | Publish ждёт |
| CW-28 | Cover failed | Retry/remove |
| CW-29 | Autosave failure | Данные остаются |
| CW-30 | Offline restore | Полный local draft |
| CW-31 | Revision conflict | LWW warning + recovery snapshot |
| CW-32 | Двойной Publish | Один permanent object |
| CW-33 | Timeout после server success | Status lookup, без дубля |
| CW-34 | Capability revoked перед Publish | Local draft + запрет |
| CW-35 | Moderation rejection | Editable revision + reasons |
| CW-36 | Material edit | Pending revision, старая approved публична |
| CW-37 | Archive/restore | Visibility и policy соблюдены |
| CW-38 | Analytics payload | Нет PII/free text/URL |
| CW-39 | Screen reader traversal | Логичный порядок и field errors |
| CW-40 | Full project gates | Analyze/test зелёные |
| CW-41 | Два hold на последнее место | Один success, один sold-out/waitlist |
| CW-42 | Hold expired | Inventory освобождён один раз |
| CW-43 | Group booking | Quantity резервируется атомарно |
| CW-44 | Full-series inventory | Все required occurrences резервируются атомарно |
| CW-45 | Approval accepted/rejected | Booking и уведомления корректны |
| CW-46 | Waitlist promotion expiry | Hold освобождён, очередь продвинута |
| CW-47 | Client payment success без webhook | Не подтверждать paid |
| CW-48 | Duplicate provider webhook | Один ledger transition |
| CW-49 | Partial refund | Order/Payment/Booking states согласованы |
| CW-50 | Chargeback после attendance | Dispute отдельно от attendance |
| CW-51 | Tax rounding | Server snapshot детерминирован |
| CW-52 | Promo stacking | Priority/eligibility соблюдены |
| CW-53 | Connector drift | Reconciliation и degraded state |
| CW-54 | QR duplicate/offline sync | Один attendance result |
| CW-55 | Instructor replacement | Impact preview + notifications |
| CW-56 | Venue reschedule | Transfer/refund actions доступны |
| CW-57 | Module release after attendance | Access появляется один раз |
| CW-58 | Assignment/progress restore | Данные не теряются |
| CW-59 | Certificate verify/revoke | Проверяемо без лишних PII |
| CW-60 | Archive с active obligations | Блок до resolution |
| CW-61 | Duplicate/out-of-order connector events | Один reconciled result |
| CW-62 | Public и personal ICS | Secret только в revocable personal feed |
| CW-63 | Cohort message audience | Нет утечки recipient list/PII |
| CW-64 | Job retry после crash | Нет двойного side effect |
| CW-65 | Delete при legal retention | Anonymize/delete и lawful retention разделены |

## 30. Полный продуктовый scope

Все перечисленные capability входят в целевой действующий продукт:

1. **Content** — Offering revisions, taxonomy, media, translations,
   instructors и moderation.
2. **Delivery** — multi-cohort, recurrence, offline/online/hybrid/on-demand,
   venues, access и operational changes.
3. **Participation** — inventory, atomic holds, group booking, approval,
   waitlist, transfer и self-service.
4. **Commerce** — price catalog, discounts, tax/fees, payment, invoice,
   payout, refund, credit, dispute и reconciliation.
5. **Learning** — curriculum, resources, assignments, progress, attendance и
   certificates.
6. **Trust** — safety, minors, waiver, privacy, abuse, audit и reporting.
7. **Operations** — staff capabilities, check-in, notifications, exports,
   analytics, observability и connector health.

Feature flags и поэтапный rollout управляют риском внедрения, но не удаляют
capability из этой спецификации. Временное отсутствие backend/provider —
implementation status, а не основание урезать product contract.

## 31. Зафиксированные решения full-product модели

1. Course поддерживает full-series, selected modules, rolling enrollment и
   on-demand access через PriceOption/attendance scope.
2. Instructor team публичен согласно display policy; edit permissions
   назначаются отдельно.
3. Drop-in разрешается при любой capacity, если safety и inventory policy это
   допускают.
4. Online-only Offering не получает фиктивный geo и участвует в online
   availability/filter mode.
5. Safety requirements задаются category/market policy и могут требовать
   ручную модерацию.
6. Детские предложения требуют guardian/consent policy.
7. Budget filter использует обязательный payable total; optional add-ons
   отображаются отдельно.
8. Канонический deep link:
   `recharge://class_workshop/{offeringId}`; Cohort/Occurrence открываются
   query/path extension без ссылок по имени.
9. Capacity, duration и occurrence count не имеют MVP-констант в UI; применимы
   versioned PolicyLimits и технический batch processing.
10. Internal и external booking равноправны, но всегда имеют явный source of
    truth.
11. Existing Order и policy snapshots неизменяемы задним числом.
12. Reviews о качестве Offering отделены от operational feedback о Cohort;
    verified attendance подтверждается AttendanceRecord.

## 32. План реализации полного продукта после утверждения

1. **CW-FOUNDATION-01** — новые ADR: aggregates, booking, commerce, privacy,
   financial audit и provider boundaries.
2. **CW-DOMAIN-02** — typed Offering/Cohort/Occurrence contracts и policies.
3. **CW-CONFIG-03** — declarative form engine, PolicyLimits и migrations.
4. **CW-CONTENT-04** — learning design, team, media, translations, moderation.
5. **CW-SCHEDULE-05** — multi-cohort, recurrence, timezone, DST и resources.
6. **CW-INVENTORY-06** — pools, atomic holds, group/full-series booking.
7. **CW-BOOKING-07** — approval, waitlist, transfer и self-service.
8. **CW-COMMERCE-08** — prices, tax/fees, payment, ledger, payout и refunds.
9. **CW-DELIVERY-09** — access, check-in, attendance и operational changes.
10. **CW-LEARNING-10** — resources, assignments, progress и certificates.
11. **CW-DISCOVER-11** — projections, live availability, reviews и deep links.
12. **CW-OPS-12** — notifications, exports, analytics, SLO и incident controls.
13. **CW-QA-13** — unit/contract/integration/load/security/accessibility tests.

Этапы отражают зависимости, а не урезанный продуктовый scope. Каждый slice
обязан пройти `flutter analyze`, полный `flutter test` и применимые backend,
contract, load, security и reconciliation gates. До завершения активной
стабилизации реализация не начинается.

## 33. Definition of Product Ready

Продукт считается готовым к полноценной эксплуатации только при одновременном
выполнении всех групп:

### 33.1 Product journey

- Participant проходит Discover → Booking → Delivery → Result без ручного
  обхода системы.
- Creator проходит Offering → Cohort → Publish → Operations → Payout.
- Staff capabilities проверены для каждой operational роли.
- Internal, external, hybrid и on-demand branches имеют честный fallback.

### 33.2 Domain и data

- Offering/Cohort/Occurrence boundaries реализованы без ссылок по имени.
- Все permanent IDs — ULID/UUID; `loc_*` отсутствуют в published graph.
- Revisions, policy snapshots и financial history immutable.
- Migrations проверены на реальных предыдущих schema versions.
- Backup restore сохраняет relations, audit и ledger balance.

### 33.3 Booking и commerce

- Inventory/hold tests доказывают отсутствие случайного oversell.
- Quote, Order, Payment, Refund, Payout и Ledger reconciled.
- Duplicate/out-of-order webhook безопасны.
- SCA/tax/invoice/refund/dispute flows проверены для активного market.
- Ни client success, ни notification не являются source of truth.

### 33.4 Delivery и learning

- Calendar, reminders, access, check-in и attendance согласованы.
- Resources защищены Entitlement и проходят security scan.
- Progress и assignments восстанавливаются после restart/sync conflict.
- Certificate выдаётся и отзывается проверяемо.
- Reschedule/cancellation имеют impact, notification и transfer/refund paths.

### 33.5 Trust, legal и inclusion

- Moderation, report, auto-hide и appeal operational.
- KYC/KYB, minors, waiver, consent и retention прошли legal review.
- Privacy export/delete/anonymization проверены end-to-end.
- en/ru/lv и market formatting завершены без hardcoded user strings.
- Screen reader, keyboard, contrast, focus, reduced motion и error recovery
  проверены на реальных устройствах.

### 33.6 Reliability и operations

- SLO, dashboards, alerts, kill switches и incident runbooks готовы.
- Load tests покрывают publish spike, last-seat race, booking launch,
  waitlist promotion, check-in burst и mass reschedule.
- Security tests покрывают permissions, IDOR, payment/webhook, upload,
  signed links, exports и staff access.
- Support имеет controlled tools для lookup, retry, refund, transfer и audit.
- Rollback/degraded mode не теряет Booking, Payment, Attendance или Progress.

### 33.7 Release evidence

- `flutter analyze` — 0 ошибок.
- Полный `flutter test` и применимые integration/contract/e2e suites зелёные.
- Backend migrations, reconciliation и restore drills имеют сохранённые
  evidence.
- Product metrics и guardrails доступны до rollout.
- LAUNCH_STATUS отражает фактическую, а не целевую готовность.
- Финальное одобрение включает Product, Engineering, Design, QA,
  Security/Privacy, Legal/Finance и Operations.

Feature flag или phased rollout может ограничить аудиторию, но не позволяет
объявить capability готовой без её собственных критериев Product Ready.
