# RECHARGE — Find People Create Block Spec

- Статус: Reconciled Final Product Blueprint
- Версия: 3.1
- Дата: 2026-07-19
- Тип контента: `find_people`
- Legacy alias: `social_request` — только чтение и миграция
- Фактическая реализация на дату документа: slice `FP-CRT-FIND-01` реализован
  на общем config-driven Create runtime с local/mock persistence и publish;
  Discover, participation, communication и Firebase остаются отдельными
  post-stabilization slices

## 1. Назначение документа

Документ фиксирует полную production-логику блока **Find People**: от создания
запроса на поиск компании до публикации, рекомендаций, выдачи и карты, заявок,
приглашений, waitlist, совместного выбора времени, группового общения,
проведения встречи, trust & safety, модерации и удаления данных.

Это спецификация конечного действующего продукта, а не сокращённого первого
релиза. Реализация может поставляться по техническим slices, но нельзя упрощать
доменную модель так,
чтобы последующие возможности требовали несовместимого переписывания данных или
контрактов. Временное отсутствие возможности отражается только в
`LAUNCH_STATUS.md` и feature flags, но не удаляет её из этой спецификации.

Спецификация не является разрешением на изменение приложения. Реализация
выполняется отдельными slices после стабилизации с трассировкой до acceptance
criteria этого документа.

При конфликте действуют приоритеты из `AGENTS.md`: Accepted ADR → spec активного
slice → `LAUNCH_STATUS.md` → `VISION.md`.

## 2. Главный продуктовый инвариант

**Find People — это публичный запрос найти компанию для конкретного занятия,
а не поиск профилей и не показ живого местоположения людей.**

Для in-person/hybrid request на карте отображается место планируемой встречи.
Online request участвует в том же Map/Discover surface через отдельный Online
rail без фиктивного marker. Координаты устройства автора и участников никогда
не публикуются. Функция не поддерживает:

- карту людей «рядом сейчас»;
- фоновое или live-отслеживание геопозиции;
- поиск пользователя по телефону, email или контактам;
- открытый просмотр списка людей поблизости;
- автоматический мэтчинг по чувствительным персональным признакам.

Если в UI используется короткое название «Люди», под ним всё равно находится
выдача запросов `find_people`, а не каталог аккаунтов.

## 3. Связь с каноническими решениями

1. Канонический type ID — `find_people`; `social_request` принимается только
   мигратором старых черновиков.
2. `FindPeopleRequest` — полноценный `MapObject`, участвующий в общей цепочке
   `Search → Results → Map → Feed → Details`. Spatial variant равен
   `point` для in-person/hybrid и `online` без fake coordinates для online.
3. Категория описывает, **для какого занятия** ищут компанию. По
   `CATEGORY_SYSTEM.md` тип принимает любую активную категорию и подкатегорию;
   проверка `applicableTypes` для него не выполняется.
4. Постоянные ID — ULID, создаваемые на клиенте. `loc_*` допустим только у
   несохранённого локального черновика и заменяется при публикации.
5. Все связи строятся по ID. Имя, avatar и title могут денормализоваться только
   как display cache.
6. Время хранится в UTC вместе с IANA timezone места встречи.
7. Базовый ranking — `geo + freshness`; иные сигналы не могут незаметно
   вытеснить эту основу.
8. Стандартный lifecycle и moderation policy берутся из ADR 0013.
9. Firebase является целевым production backend. Mock datasource допустим только
   для разработки, preview и тестов за теми же repository contracts и никогда не
   определяет продуктовую семантику.

## 4. Термины

| Термин | Значение |
|---|---|
| `FindPeopleRequest` | Публичный объект: кто, для какого занятия, когда и где ищет компанию |
| Автор / host | Пользователь, создавший запрос и принимающий решения по заявкам |
| Applicant | Пользователь, подавший заявку на участие |
| Participant | Applicant с принятой заявкой |
| `JoinRequest` | Заявка пользователя на одно или несколько мест |
| `Invitation` | Персональное приглашение присоединиться к request |
| `WaitlistEntry` | Policy-view над `JoinRequest(status = waitlisted)`, содержащий порядок без отдельного источника истины |
| `Occurrence` | Конкретная встреча одиночного или повторяющегося request |
| Co-host | Пользователь с делегированными правами управления request |
| Group conversation | Закрытое общение host/co-hosts и принятых участников |
| Public meeting area | Безопасная приблизительная точка, видимая в выдаче и на карте |
| Exact meeting point | Точная публичная точка встречи, доступная после принятия заявки |
| Group size | Общее число людей вместе с автором |
| Remaining seats | Число ещё доступных мест |
| Recruitment status | Операционный статус набора: открыт, заполнен, отменён и т.д. |

## 5. Scope

### 5.1 В scope

- создание и локальное сохранение черновика;
- выбор занятия через Category System;
- один или несколько конкретных временных слотов;
- single, time-poll и ограниченный recurring schedule;
- публичное место встречи и безопасное раскрытие точной точки;
- размер группы от 2 до 20 человек;
- требования, не использующие запрещённую дискриминацию;
- publisher `user | page`, ответственные hosts и co-hosts;
- публикация и модерация;
- выдача, карта, карточка и details;
- ручное и rule-based автоматическое одобрение;
- заявки, приглашения, waitlist, seat offer и подтверждение участия;
- защита capacity от гонок;
- приватные applicant threads и group conversation;
- уведомления, realtime updates и reminders;
- планирование и прозрачное разделение ожидаемых расходов;
- trust signals, verification requirements и no-show handling;
- жалобы, блокировки, скрытие и audit events;
- истечение, отмена и завершение запроса;
- аналитика без чувствительных данных.

### 5.2 Исключено из продукта по смыслу и безопасности

- live location и трекинг маршрута пользователя;
- swipe/dating-механики;
- подбор по полу, этничности, религии, здоровью, политическим взглядам или
  другим чувствительным признакам;
- публичная лента профилей «рядом»;
- отзывы «о человеке» и публичный рейтинг участника;
- участие аккаунтов младше 18 лет до принятия отдельного Child Safety ADR и
  внедрения guardian/consent enforcement;
- бесконечные recurrence без горизонта материализации и контроля автором;
- скрытые или частные домашние адреса как место встречи.

Импорт контактов не является частью поиска людей, но продукт может дать
пользователю локально выбрать контакт для отправки обычной share-ссылки. Адресная
книга не загружается на backend и не превращается в social graph без отдельного
явного consent flow.

Find People не является коммерческой услугой организатора. Если автор продаёт
участие, бронирование или занятие, применяется Event, Session или
Class/Workshop. При этом прозрачный общий бюджет, добровольное разделение
фактических расходов и settlement через отдельный платежный контур допустимы.

## 6. Роли, capabilities и доступ

### 6.1 Чтение

- Guest может видеть опубликованные безопасные поля в Results, Map и Details.
- Guest не видит точный meeting point, участников, текст заявки и контакты.
- Заблокированные друг другом пользователи не видят объекты друг друга.

### 6.2 Публикация

По канонической модели ролей публиковать может авторизованный `Creator` с capability
`create.find_people`. Текущая mock capability `create.social_request` считается
legacy alias и должна мигрировать отдельно, без вечного дублирования политики.

Publisher использует общий contract `{type: user | page, id}`:

- `user` — личный поиск компании;
- `page` — некоммерческий клуб, сообщество или ManagedPage ищет участников для
  совместной активности;
- Page-request обязан иметь хотя бы одного видимого
  `responsibleHostUserId` с `manage_page` и `manage_find_people`;
- коммерческое предложение от Page должно быть создано как Event, Session или
  Class/Workshop, даже если ему нужны участники.

Участник всегда понимает, публикует ли запрос человек или страница, и видит
ответственных hosts до подачи заявки.

### 6.3 Участие

- Подать заявку может любой авторизованный совершеннолетний User, кроме автора.
- Capability Creator для участия не требуется.
- Один аккаунт имеет не более одной активной заявки на один непересекающийся
  request scope. Для recurring новая occurrence добавляется в scope существующей
  series application или получает occurrence-scoped application; scopes и seat
  reservations одного пользователя не могут пересекаться.
- Автор не может подать заявку в собственный request.
- Заблокированный, удалённый или принудительно вышедший аккаунт не может
  участвовать.

### 6.4 Управление

- Владелец управляет request, co-hosts, заявками, waitlist и conversation.
- Co-host получает только явно выданные capabilities: `review_applications`,
  `manage_schedule`, `manage_participants`, `moderate_conversation`. Передача
  ownership требует подтверждения нового владельца и audit event.
- Admin управляет видимостью и moderation state, но не пишет от имени автора.
- Audit trail административных действий не виден обычным пользователям.

## 7. Возраст и production safety baseline

1. По product safety policy Find People доступен только пользователям 18+.
   Расширение аудитории требует отдельного Child Safety ADR и полноценного
   guardian/consent enforcement.
2. Перед первой публикацией или заявкой требуется подтверждение возраста и
   принятие Safety Rules. Самодекларация не является KYC и должна называться
   честно.
3. Public request не публикует точный возраст. Допустимы только нейтральные
   возрастные диапазоны из policy-controlled enum, если market legal review
   разрешает их; default — `18+`, верхний предел не обязателен.
4. Запрещено искать «только мужчин/женщин», людей конкретной национальности,
   религии, диагноза или иного чувствительного класса.
5. Допустимы требования, непосредственно относящиеся к занятию: уровень навыка,
   язык общения, темп, необходимое снаряжение, accessibility needs.
6. Встреча должна быть назначена в публичном месте. Домашний адрес, номер
   квартиры, код двери и текущая геопозиция отклоняются.
7. UI до отправки заявки показывает safety notice: встречаться в публичном
   месте, не переводить деньги незнакомым людям, сообщить близким о планах,
   использовать Report/Block при проблеме.
8. Identity verification имеет единый канонический enum:
   `none | phone | identity_document | organization`. Требуемый уровень зависит
   от риска и market policy. UI не называет самодекларацию verified identity.
9. Верификационные документы и дата рождения не входят в Find People domain и
   недоступны host: feature получает только policy result/capabilities.

## 8. Жизненный цикл

У объекта две независимые оси состояния.

### 8.1 Entity lifecycle по ADR 0013

```text
draft → pending_review → published → archived → deleted
                       ↘ hidden
```

- `draft` — виден только автору;
- `pending_review` — ожидает проверки, в Discover отсутствует;
- `published` — может участвовать в выдаче при открытом operational status;
- `hidden` — скрыт системой или модерацией;
- `archived` — снят автором или автоматически завершён, восстановим;
- `deleted` — soft delete; hard delete после retention или legal request.

### 8.2 Recruitment status

```text
collecting_availability → open | waitlist_only | full
open → waitlist_only ↔ open
open → full ↔ open
collecting_availability | open | waitlist_only | full
  → completed | cancelled | expired
non-terminal + pauseState.isPaused → effectiveStatus = paused
```

| Статус | Значение | В общей выдаче |
|---|---|---|
| `collecting_availability` | Time poll собирает подходящие варианты | Да, с CTA выбора времени |
| `open` | Заявки принимаются, есть места и не прошёл deadline | Да |
| `waitlist_only` | Свободных мест нет, но очередь открыта | Да, с CTA `Join waitlist` |
| `full` | Все места заняты и waitlist закрыт | Только если не включён `onlyAvailable`; CTA недоступен |
| `paused` | Pause overlay временно запрещает новые заявки | Нет; только authorized deep link |
| `completed` | Последний слот завершился | Нет |
| `cancelled` | Автор отменил встречу | Нет |
| `expired` | Истёк application deadline или все слоты прошли | Нет |

`full` и `waitlist_only` не переводят entity в `archived`: принятый участник
может отказаться, после чего первое подходящее место предлагается waitlist или
request снова становится `open`. После завершения или истечения request
автоматически архивируется политикой cleanup.

`paused` не является отдельным источником capacity state. `PauseState` хранит
`isPaused`, actor/time и `resumeStatusSnapshot` только для audit/UI. Pause
доступен из любого нетерминального состояния request/occurrence. Пока pause
активен, объект всегда исключён из публичной Discover-выдачи, но остаётся
доступен по deep link владельцу, hosts, текущим Applicants и accepted
participants. Resume снимает overlay и пересчитывает
`collecting_availability | open | waitlist_only | full` из актуальных selected
slot, seats и deadline; слепое восстановление snapshot запрещено.

### 8.3 JoinRequest lifecycle

```text
pending → accepted → withdrawn | cancelled_by_host
   ├────→ waitlisted → offer_pending → accepted
   │              └───────────────→ offer_expired
   ├────→ rejected
   ├────→ withdrawn
   └────→ expired
```

`offer_pending` временно резервирует seats до `offerExpiresAtUtc`. При
подтверждении заявка становится `accepted`; при истечении — `offer_expired`, а
место атомарно предлагается следующему. Очередь упорядочивается прозрачной
policy (`joinedAtUtc` по умолчанию); скрытая продажа приоритета запрещена.

Терминальный статус не переиспользуется. После `withdrawn` или `offer_expired`
Applicant может подать новую заявку с новым ULID после configured cooldown, если
request/occurrence снова принимает заявки. После `rejected`,
`cancelled_by_host` или `expired` повторная заявка в тот же scope запрещена.
Прежняя запись всегда остаётся в audit history.

Фактическое посещение хранится отдельно в `AttendanceRecord` со статусом
`unknown | confirmed | attended | no_show | excused` на participant +
occurrence. Оно не меняет историю решения по заявке и не публикуется как рейтинг
человека.

## 9. Create flow

Find People использует единый config-driven form engine. Нельзя создавать
отдельный параллельный wizard для этого типа. Типо-специфичные sections
подключаются декларативно.

### Шаг 0. Вход и guard

1. Пользователь выбирает `Find People` в Create Hub.
2. Guest проходит Auth и возвращается в intended route.
3. Проверяются `18+`, Safety Rules и `create.find_people`.
4. При незавершённом черновике предлагается Continue / Start new.
5. Новый локальный draft получает `loc_*`; сохранённый постоянный draft — ULID.

### Шаг 1. Занятие и описание

Поля:

| Поле | Обязательное | Правило |
|---|---:|---|
| `title` | Да | 5–80 символов; конкретное действие, без контактов |
| `categoryId` | Да | Любая active Category |
| `subcategoryId` | Да | Active subcategory выбранной Category |
| `tags` | Нет | До 8 разрешённых catalog/user tags |
| `shortDescription` | Да | 20–180 символов |
| `fullDescription` | Да | 50–2000 символов |
| `skillLevel` | Да | `any`, `beginner`, `intermediate`, `advanced` |
| `pace` | Нет | Config-driven значения для применимых категорий |
| `languageCodes` | Да | 1–3 BCP-47 language codes; минимум один |
| `participationGoal` | Да | `social`, `practice`, `team_up`, `shared_trip`, `accountability`, `other` |
| `experienceRequirements` | Нет | Структурированные безопасные требования к занятию |
| `equipmentNotes` | Нет | До 500 символов |
| `accessibilityNotes` | Нет | До 500 символов, без медицинского профилирования |
| `houseRules` | Нет | До 10 правил из enum + пояснение до 500 символов |

Телефон, email, username мессенджера и внешняя платёжная ссылка в public text
запрещены. Sanitizer не должен молча менять смысл: поле подсвечивается, причина
объясняется, publish блокируется.

### Шаг 2. Когда

Используется общая availability section с тремя режимами:

| `scheduleMode` | Поведение |
|---|---|
| `single` | Автор сразу фиксирует одну встречу |
| `time_poll` | Автор предлагает варианты, Applicants отмечают подходящие, затем host фиксирует один общий слот |
| `recurring` | Ограниченная серия встреч; occurrences материализуются в заданном горизонте |

Общие правила:

- количество вариантов и materialized occurrences задаётся policy config;
- каждый slot и occurrence имеет постоянный ULID;
- локальный ввод интерпретируется в IANA timezone market/location;
- длительность одного слота: от 30 минут до 24 часов включительно;
- слоты не пересекаются и идут по возрастанию;
- первый start — не раньше минимального publish lead time из Remote Config;
- последний start — не дальше planning horizon из Remote Config;
- application deadline принадлежит occurrence и всегда раньше её выбранного
  start; у provisional time-poll occurrence до finalize действует
  `pollResponseDeadlineUtc`;
- неоднозначное DST-время требует явного подтверждения;
- несуществующее локальное DST-время отклоняется.

Occurrence материализуется для всех режимов:

- `single` — ровно одна open occurrence создаётся при publish и сразу ссылается
  на выбранный slot;
- `time_poll` — при publish создаётся ровно одна provisional occurrence со
  status `collecting_availability`, непустыми `candidateSlotIds` и
  `selectedSlotId = null`;
- `recurring` — occurrences материализуются по конечному horizon.

В `time_poll` Applicant выбирает один или несколько приемлемых `slotId`. Host
видит агрегированные количества без раскрытия ответов другим Applicants и
фиксирует `occurrence.selectedSlotId` до окончательного accept. Finalize одной
транзакцией выбирает slot, закрывает остальные варианты, переносит deadline/
private meeting data, сохраняет reservations и пересчитывает occurrence status.
Совмещённая операция `finalize + accept` допустима и идемпотентна. Capacity и
reservations до и после finalize принадлежат той же provisional occurrence,
поэтому pre-occurrence окна не существует.

`recurring` содержит `recurrenceRule`, timezone, `seriesEndAtUtc` или
`maxOccurrences`; бесконечная серия запрещена. Для каждой occurrence отдельно
хранятся selected slot, capacity, deadline, status и private meeting data. Пользователь
выбирает `joinScope = occurrence | series`. Изменение серии поддерживает
`this occurrence | this and following | whole series`, не переписывая историю
прошедших occurrences.

### Шаг 3. Где

Поддерживаются `meetingMode = in_person | online | hybrid`.

Поля:

- `marketCityId`;
- `timezoneId`;
- `meetingMode`;
- `meetingPlaceName`;
- `publicAreaLabel`;
- `publicGeo {lat, lng}` — приблизительная точка для Discover/Map;
- `exactGeo {lat, lng}` — точка входа/встречи для принятых участников;
- `exactAddressLine` — только для принятых участников;
- `meetingInstructions` — только для принятых участников, до 500 символов.
- `onlineProvider` и закрытый `onlineAccessSecretRef` — для online/hybrid;
- `backupMeetingPlan` — опционально для weather/provider failure.

В draft эти значения образуют meeting template. При materialization они
копируются в occurrence public snapshot и связанный private meeting document.
Дальнейшее изменение одной occurrence не меняет template или другие встречи без
явного scope `this and following | whole series`.

Правила:

1. Для in-person/hybrid автор выбирает POI или ставит pin и подтверждает, что
   место публичное.
2. `publicGeo` вычисляется детерминированно из `exactGeo` через privacy
   quantization/config; случайный сдвиг при каждом чтении запрещён.
3. В public DTO отсутствуют `exactGeo`, `exactAddressLine` и instructions.
4. Владелец видит обе точки; accepted participant получает exact data после
   принятия, но не раньше `selectedSlot.startAtUtc - revealWindowMinutes`.
   Фактический момент доступа равен более позднему из acceptance time и начала
   reveal window.
5. Если точная точка меняется после принятия заявок, все accepted participants
   получают уведомление и должны увидеть отметку `Location changed`.
6. При существенном переносе за пределы public area требуется подтверждение
   автора и повторная moderation check.
7. Location permission нужна только для центрирования picker. Отказ не блокирует
   ручной выбор.
8. Online-only request имеет market/language scope для Discover, но не получает
   фиктивную координату. На Map он показывается в отдельном `Online` слое/rail,
   а не marker в центре города.
9. `onlineAccessSecretRef` раскрывается по той же access policy, что exact location;
   URL и passcode отсутствуют в public DTO, analytics и push payload.
10. Hybrid request показывает marker по public physical area и badge `Hybrid`.
11. Online access должен быть session/request-scoped, а не вечной персональной
    ссылкой host. При утечке, удалении участника или смене provider secret можно
    ротировать с уведомлением текущих accepted participants.

### Шаг 4. Группа и условия участия

| Поле | Обязательное | Правило |
|---|---:|---|
| `targetGroupSize` | Да | 2–20, включает автора |
| `hostSeatCount` | Да | Personal default 1; у Page равно числу hosts, реально участвующих во встрече |
| `approvalMode` | Да | `manual`, `automatic`, `invite_only` |
| `allowPartyApplications` | Да | Default `false` |
| `maxSeatsPerApplication` | Условно | 1–4 и не больше `targetGroupSize - 1` |
| `applicationQuestions` | Нет | Config-limited safe questions: text, single/multi choice, yes/no |
| `verificationRequirement` | Да | `none`, `phone`, `identity_document`, `organization` по policy |
| `waitlistEnabled` | Да | Default `true` для public request |
| `waitlistPolicy` | Условно | `first_come`, `host_review`; критерии видимы Applicants |
| `waitlistSeatFitPolicy` | Условно | `strict_order` или `first_fitting`; видна до вступления |
| `attendanceConfirmationRequired` | Да | Требовать reconfirmation перед встречей |
| `guestPolicy` | Да | Правила party applications и данных гостей |
| `costType` | Да | `free`, `estimated`, `unknown` |
| `expectedSpendAmount` | Нет | Оценка на человека, не оплата автору |
| `currency` | Условно | Валюта active market, для Riga — EUR |
| `costNote` | Нет | До 300 символов |
| `expenseSplitMode` | Да | `none`, `equal`, `itemized`, `settle_later` |
| `plannedExpenseItems` | Условно | Обязательны для `itemized`; сумма/категория/кто обычно платит |
| `cancellationPolicy` | Да | Policy template + локализованное пояснение |

Производные значения:

```text
acceptedSeats = сумма requestedSeats у accepted JoinRequest occurrence
currentGroupSize = occurrence.hostSeatCount + occurrence.acceptedSeats
reservedSeats = активные seat offers и bounded invitation reservations occurrence
occupiedSeats = currentGroupSize + reservedSeats
remainingSeats = max(0, occurrence.targetGroupSize - occupiedSeats)
occurrence.recruitmentStatus = waitlist_only,
  если remainingSeats == 0 и waitlistEnabled
occurrence.recruitmentStatus = full,
  если remainingSeats == 0 и !waitlistEnabled
```

Ответственный host считается первым участником личного request. У Page-request
явно задаётся число host seats; co-host может быть `organizer_only` и не занимать
место. `currentParticipants` не вводится вручную и не является доверенным
клиентским счётчиком.

`automatic` approval использует только прозрачные hard rules: доступные места,
подходящий slot, подтверждённые requirements, verification level и block/safety
checks. ML score, пол, возрастная точность, платежеспособность и иные скрытые
сигналы не могут решать допуск. При заполнении мест заявка атомарно уходит в
waitlist.

После одобрения party application переходит в `offer_pending` и резервирует
`requestedSeats`, но каждое место должно быть связано с отдельным
совершеннолетним authenticated participant до `guestClaimDeadlineUtc`.
Applicant отправляет гостям expiring claim links;
контактные данные при этом не загружаются в request. Неподтверждённые seats
освобождаются атомарно; после всех claims reservation одним transition
заменяется на `acceptedSeats`. Частичное принятие party возможно только после
явного согласия Applicant; exact meeting/online access выдаётся каждому
подтвердившему участнику персонально, а не через общий публичный token.

При `costType = free` amount отсутствует или равен нулю. При
`costType = estimated` положительные amount и currency обязательны. При
`costType = unknown` amount отсутствует, а UI честно показывает, что расходы не
указаны. Фраза «бесплатно» означает, что участие и ожидаемые обязательные расходы
равны нулю. Автор не может собирать оплату через Find People. Платная
организованная активность должна публиковаться как Event, Session или
Class/Workshop.

### Шаг 5. Hosts, видимость и коммуникация

Поля:

- `publisherRef` и `responsibleHostUserIds`;
- co-hosts с отдельными capabilities;
- `visibility = public | unlisted | invite_only`;
- `discoverability` по market/category/language;
- `conversationPolicy = accepted_only | applicants_and_accepted`;
- `allowParticipantInvites`;
- `sharePolicy` и expiry для invite links;
- quiet hours и notification preferences по request.

`public` участвует в Discover. `unlisted` доступен по ссылке и не попадает в
общую выдачу. `invite_only` требует действующий `Invitation` и не раскрывает
закрытые данные по одной лишь пересланной ссылке. Co-host обязан принять роль;
до принятия capability не действует.

### Шаг 6. Медиа, preview и публикация

- Cover необязателен; при отсутствии используется category visual из design
  system/assets, но не аватар автора в полный размер.
- Gallery и короткое preview video ограничиваются media policy/Remote Config,
  проходят compression, moderation, retry и orphan cleanup.
- Документы, билеты и скриншоты с контактами не публикуются как media.
- Preview повторяет public Details и отдельно показывает автору закрытый блок
  exact location.
- Validation summary ведёт к конкретному полю.
- Publish требует явного подтверждения Safety Rules и accuracy checkbox.
- Двойное нажатие Publish использует один idempotency key.
- Автор может опубликовать сразу или запланировать `publishAtUtc`; scheduled
  publish повторно проверяет актуальность slots, capabilities и moderation.

### Сквозная validation matrix

| Условие | Обязательное поведение |
|---|---|
| `publisherRef.type = page` | Есть responsible host с page capabilities |
| `hostSeatCount` | От 1 до `targetGroupSize - 1`; organizer-only co-host не учитывается |
| `scheduleMode = single` | Ровно один selected slot; publish создаёт одну open occurrence |
| `scheduleMode = time_poll` | Не менее двух вариантов; publish создаёт одну provisional occurrence |
| `scheduleMode = recurring` | Есть конечный recurrence horizon и materializable occurrences |
| `meetingMode = in_person` | Есть public/exact geo; online secret отсутствует |
| `meetingMode = online` | Есть provider/access secret; public/exact geo отсутствуют |
| `meetingMode = hybrid` | Валидны обе ветки location и online access |
| `approvalMode = invite_only` | `visibility = invite_only`; public Apply отсутствует |
| `visibility = invite_only` | `approvalMode = invite_only` и нужен валидный Invitation |
| `waitlistEnabled = false` | `waitlistPolicy` и seat-offer automation не применяются |
| `allowPartyApplications = false` | `maxSeatsPerApplication = 1` |
| `costType = estimated` | Положительный Money и currency обязательны |
| `expenseSplitMode = itemized` | `plannedExpenseItems` не пуст; коммерческая комиссия отсутствует |
| `visibility != public` | Request исключён из Discover/Map public index |
| `publishAtUtc != null` | Publish time раньше первого occurrence/poll deadline и relevant slot |

Cross-field validator работает одинаково в preview, publish, update и scheduled
publish. UI validation является подсказкой; authoritative validation всегда
повторяется в domain/backend boundary.

## 10. Сохранение черновика

1. Изменения autosave локально после debounce и при выходе со шага.
2. Черновик хранит `schemaVersion`, `updatedAtUtc` и dirty state.
3. Offline draft разрешён; публикация offline запрещена и не имитируется.
4. Конфликт sync — last-write-wins + явное предупреждение по ADR 0013.
5. Частично заполненный draft может нарушать publish validation, но не должен
   терять введённые данные.
6. Удаление draft — подтверждаемое и recoverable, если это поддерживает общий
   draft store.
7. При публикации все `loc_*` ID самого объекта и slots заменяются ULID до
   создания связей.

## 11. Publish pipeline

Порядок обязателен:

1. Auth/session validation.
2. Capability, 18+ и Safety Rules validation.
3. Schema migration до актуальной версии.
4. Нормализация строк, времени, языка, денег и координат.
5. Полная domain validation.
6. Проверка public-place policy и запрещённых контактов/контента.
7. Rate limit и duplicate/suspicious activity check.
8. Замена временных ID на ULID.
9. Создание immutable publisher reference.
10. Запись request и обязательных occurrences с одним idempotency key:
    single — одна finalized, time-poll — одна provisional, recurring —
    materialized horizon.
11. Проверка occurrence invariants и transactional aggregates.
12. Выбор `pending_review` или `published` по moderation policy/feature flag.
13. Обновление локального draft только после подтверждённого результата.
14. Analytics и audit event.

Неопределённый timeout не считается успехом или ошибкой. Клиент повторяет
операцию с тем же idempotency key и получает уже созданный результат.

## 12. Доменная модель

Ниже — целевой domain contract. Имена полей нормативны по смыслу; точный Dart
API утверждается implementation slice без изменения семантики.

```text
FindPeopleRequest {
  id: ULID
  publisherRef: { type: user | page, id: ULID }
  responsibleHostUserIds: List<ULID>
  coHostGrants: List<CoHostGrant>

  title: String
  categoryId: String
  subcategoryId: String
  tagIds: List<String>
  shortDescription: String
  fullDescription: String
  skillLevel: any | beginner | intermediate | advanced
  pace: String?
  languageCodes: List<String>
  participationGoal: String
  experienceRequirements: List<Requirement>
  equipmentNotes: String?
  accessibilityNotes: String?
  houseRules: List<HouseRule>

  scheduleMode: single | time_poll | recurring
  slots: List<FindPeopleSlot>
  recurrenceRule: RecurrenceRule?
  occurrenceIds: List<ULID>
  timezoneId: IanaTimezone
  marketCityId: ULID

  defaultMeetingMode: in_person | online | hybrid
  defaultSpatialVariant: point | online
  defaultMeetingPlaceName: String?
  defaultPublicAreaLabel: String?
  defaultPublicGeo: GeoPoint?

  defaultTargetGroupSize: int
  defaultHostSeatCount: int
  acceptedSeatsAggregate: int
  reservedSeatsAggregate: int
  approvalMode: manual | automatic | invite_only
  allowPartyApplications: bool
  maxSeatsPerApplication: int
  applicationQuestions: List<ApplicationQuestion>
  verificationRequirement: none | phone | identity_document | organization
  waitlistEnabled: bool
  waitlistPolicy: first_come | host_review
  waitlistSeatFitPolicy: strict_order | first_fitting
  attendanceConfirmationRequired: bool
  guestPolicy: GuestPolicy

  costType: free | estimated | unknown
  expectedSpendAmount: Money?
  costNote: String?
  expenseSplitMode: none | equal | itemized | settle_later
  plannedExpenseItems: List<PlannedExpenseItem>
  cancellationPolicyId: String
  mediaRefs: List<MediaRef>

  entityStatus: draft | pending_review | published | archived | hidden | deleted
  recruitmentStatusAggregate: collecting_availability | open | waitlist_only |
                              full | completed | cancelled | expired
  pauseState: PauseState
  moderationStatus: none | pending | approved | rejected
  visibility: public | unlisted | invite_only
  conversationPolicy: accepted_only | applicants_and_accepted
  allowParticipantInvites: bool
  reportCount: int

  createdAtUtc: Instant
  updatedAtUtc: Instant
  publishAtUtc: Instant?
  publishedAtUtc: Instant?
  cancelledAtUtc: Instant?
  completedAtUtc: Instant?
  schemaVersion: int
}

FindPeoplePrivateMeeting {
  id: ULID
  requestId: ULID
  occurrenceId: ULID
  exactGeo: GeoPoint?
  exactAddressLine: String?
  meetingInstructions: String?
  onlineProvider: String?
  onlineAccessSecretRef: SecretRef?
  revealAtUtc: Instant?
  updatedAtUtc: Instant
}

FindPeopleSlot {
  id: ULID
  startAtUtc: Instant
  endAtUtc: Instant
  lifecycleStatus: available | cancelled | completed
}

FindPeopleOccurrence {
  id: ULID
  requestId: ULID
  candidateSlotIds: List<ULID>
  selectedSlotId: ULID?
  pollResponseDeadlineUtc: Instant?
  applicationDeadlineUtc: Instant?
  targetGroupSize: int
  hostSeatCount: int
  acceptedSeats: int
  reservedSeats: int
  meetingMode: in_person | online | hybrid
  spatialVariant: point | online
  meetingPlaceName: String?
  publicAreaLabel: String?
  publicGeo: GeoPoint?
  privateMeetingRef: ULID
  recruitmentStatus: collecting_availability | open | waitlist_only | full |
                     cancelled | completed | expired
  pauseState: PauseState
  createdAtUtc: Instant
  updatedAtUtc: Instant
}

PauseState {
  isPaused: bool
  pausedAtUtc: Instant?
  pausedByUserId: ULID?
  resumeStatusSnapshot: collecting_availability | open | waitlist_only | full |
                        null
}

JoinRequest {
  id: ULID
  findPeopleRequestId: ULID
  applicantId: ULID
  joinScope: occurrence | series
  occurrenceIds: List<ULID>
  acceptableSlotIds: List<ULID>
  selectedSlotId: ULID?
  requestedSeats: int
  seatClaimUserIds: List<ULID>
  guestClaimDeadlineUtc: Instant?
  answers: List<ApplicationAnswer>
  status: pending | waitlisted | offer_pending | accepted | rejected |
          withdrawn | offer_expired | cancelled_by_host | expired
  offerExpiresAtUtc: Instant?
  decisionReasonCode: String?
  createdAtUtc: Instant
  decidedAtUtc: Instant?
  updatedAtUtc: Instant
  schemaVersion: int
}

AttendanceRecord {
  id: ULID
  findPeopleRequestId: ULID
  occurrenceId: ULID
  participantId: ULID
  status: unknown | confirmed | attended | no_show | excused
  source: self | host | system
  updatedAtUtc: Instant
}

Invitation {
  id: ULID
  findPeopleRequestId: ULID
  inviterId: ULID
  inviteeId: ULID?
  joinScope: occurrence | series
  occurrenceIds: List<ULID>
  inviteTokenHash: String?
  reservedSeats: int
  status: pending | accepted | declined | revoked | expired
  expiresAtUtc: Instant
  createdAtUtc: Instant
}

CoHostGrant {
  id: ULID
  findPeopleRequestId: ULID
  userId: ULID
  capabilities: Set<CoHostCapability>
  status: invited | active | declined | revoked
  createdAtUtc: Instant
  acceptedAtUtc: Instant?
  revokedAtUtc: Instant?
}

ApplicationQuestion {
  id: ULID
  type: text | single_choice | multi_choice | yes_no
  localizedPrompt: LocalizedText
  required: bool
  optionIds: List<String>
  position: int
}

ApplicationAnswer {
  questionId: ULID
  selectedOptionIds: List<String>
  textValue: String?
}

FindPeopleConversation {
  id: ULID
  findPeopleRequestId: ULID
  occurrenceId: ULID?
  type: applicant_thread | participant_group
  memberRefs: List<UserRef>
  status: active | read_only | archived
  createdAtUtc: Instant
  updatedAtUtc: Instant
}

ExpenseEntry {
  id: ULID
  findPeopleRequestId: ULID
  occurrenceId: ULID
  payerId: ULID
  amount: Money
  categoryId: String
  participantShareRefs: List<ExpenseShareRef>
  receiptMediaRef: MediaRef?
  status: proposed | confirmed | disputed | adjusted | settled
  createdAtUtc: Instant
}
```

### 12.1 Инварианты модели

- `publisherRef` идентифицирует публичного издателя. Реальные управленческие
  права определяются `responsibleHostUserIds`, co-host grants и capabilities, а
  не display cache издателя.
- User publisher содержит самого владельца в `responsibleHostUserIds`.
- Page publisher имеет минимум одного активного responsible host.
- Каждая published сущность имеет минимум одну occurrence. Draft может ещё не
  иметь occurrence ID.
- `single` publish создаёт ровно одну occurrence с непустым selected slot.
- `time_poll` publish создаёт ровно одну provisional occurrence со status
  `collecting_availability`, непустыми candidates и null selected slot. Finalize
  изменяет эту же occurrence; новый ID не создаётся.
- `recurring` материализует occurrences по horizon; прошлые occurrences не
  переписываются при изменении будущей серии.
- Source of truth для capacity, accepted/reserved seats, deadline, selected
  slot, recruitment status, public/private meeting data — всегда occurrence.
- Request-level `acceptedSeatsAggregate`, `reservedSeatsAggregate` и
  `recruitmentStatusAggregate` — transactional read-model из occurrences, а не
  независимое изменяемое состояние.
- `privateMeetingRef` принадлежит occurrence и резолвится только
  авторизованным policy-aware repository. `FindPeoplePrivateMeeting.occurrenceId`
  обязателен. Public DTO никогда не содержит private meeting fields.
- Request-level `defaultMeeting*` fields — template для новых occurrences.
  Каждая occurrence хранит собственный public meeting snapshot; изменение одной
  встречи не переписывает location прошлых/соседних occurrences.
- `reservedSeats` occurrence — денормализация активных `offer_pending` и bounded
  invitations. Guest claims внутри party offer не считаются повторно.
  Reservation имеет expiry и не является фактическим участником.
- `remainingSeats` вычисляется только в occurrence scope и не сохраняется как
  независимый mutable field.
- Для finalized occurrence `selectedSlotId` обязателен. У provisional time-poll
  он null, пока status равен `collecting_availability`.
- `applicationDeadlineUtc` обязателен для finalized occurrence; provisional
  time-poll использует `pollResponseDeadlineUtc` до finalize.
- `FindPeopleSlot.lifecycleStatus` не содержит `selected`: UI выводит selection
  из `occurrence.selectedSlotId`. Ручная запись selected-state запрещена.
- Для non-recurring aggregate равен единственной occurrence. Для recurring:
  `open`, если хотя бы одна будущая occurrence open; `waitlist_only`, если open
  нет, но есть waitlist-only; `full`, если доступные occurrences заполнены без
  waitlist; terminal status — только когда все relevant occurrences terminal.
- Pause является overlay. `resumeStatusSnapshot` используется для audit/UI, но
  resume всегда пересчитывает status из фактических seats и deadlines.
- `JoinRequest.occurrenceIds` непуст для любого persisted request. Для accepted
  application `selectedSlotId` равен selected slot соответствующей occurrence,
  входит в `acceptableSlotIds` и активен.
- `requestedSeats >= 1` и не больше лимита на момент подачи и принятия.
- Перед reveal private meeting data число уникальных `seatClaimUserIds` равно
  `requestedSeats`; каждый user прошёл собственные guards.
- Waitlist order и seat offers меняются только транзакционно; одновременно одно
  seat не может быть зарезервировано двум applications/invitations.
- Invitation содержит `inviteeId` для персонального invite или token hash для
  share link; хотя бы один идентификатор обязателен. Reservation имеет expiry и
  не может превышать доступную capacity.
- Co-host capabilities не действуют в статусе `invited`, а revoked grant не
  восстанавливается повторным использованием старой ссылки.
- ApplicationAnswer соответствует существующему question ID/type; неизвестные
  вопросы сохраняются для миграции, но не интерпретируются как новые права.
- Conversation membership вычисляется из актуальных grants/applications и
  проверяется на каждом read/write, а не доверяется cached member list.
- Expense adjustments создают новые entries/references и не переписывают
  подтверждённую финансовую историю.
- Attendance и фактический ExpenseEntry всегда принадлежат конкретной
  occurrence; один status/расход серии не перезаписывает другую встречу.
- Деньги хранятся как minor units + currency, не `double`.
- `costType` однозначно отличает `free` от `unknown`; отсутствие Money не может
  само по себе означать нулевую стоимость.
- Contacts, verification documents и чувствительные атрибуты в модели
  отсутствуют намеренно.

## 13. Интеграция с Discover

### 13.1 Object type

`find_people` — object/content type, а не Category. Общий query должен иметь
явный фильтр типов (`selectedContentTypeIds` или эквивалентный contract).
Нельзя кодировать тип как fake category или определять его по title/tags.

Полный contract повышается до `DiscoverQuery v3` (`schemaVersion = 3`) и
добавляет:

- `selectedContentTypeIds`;
- `meetingModes`;
- `languageCodes`;
- `acceptedVerificationRequirements` — optional явный filter по каноническому
  VerificationLevel;
- `includeWaitlistOnly`.

`viewerVerificationLevel` приходит из auth/policy context при проверке action и
не сохраняется в query/history. Saved query v2 мигрирует автоматически:
отсутствующие новые поля равны null/empty и не фильтруют выдачу. Это
зафиксированный post-stabilization implementation gap, а не основание урезать
Find People.

### 13.2 Eligibility до ranking

В candidates попадает request, если одновременно:

- `entityStatus == published`;
- moderation не скрывает объект;
- request и relevant occurrence не paused;
- relevant occurrence имеет status `collecting_availability`, `open`,
  `waitlist_only` или `full`;
- не прошёл relevant poll/application deadline;
- request и viewer не заблокированы друг для друга;
- market/type/category/date filters совпадают;
- для in-person/hybrid `occurrence.publicGeo` попадает в radius, если radius не
  unlimited;
- online request попадает в отдельную online group по market/language scope и
  никогда не проходит radius через фиктивную координату;
- при `onlyAvailable == true` есть достаточно remaining seats;
- request не нарушает visibility policy.

Собственный request автора может показываться с badge `Your request` и CTA
`Manage`; он не исключается молча.

### 13.3 Семантика общих фильтров

| Discover filter | Find People semantics |
|---|---|
| Text | title, description, category, subcategory, разрешённые tags |
| What | `contentType == find_people` |
| Category | Занятие, для которого ищут компанию |
| Date/time | Хотя бы один slot пересекает applied window |
| People count | `occurrence.remainingSeats >= peopleCount`; default applicant party = 1 |
| Meeting mode | `in_person`, `online`, `hybrid` без подмены геосемантики |
| Language | Пересечение с `languageCodes` |
| Verification | Требуемый уровень не выше уровня viewer при action eligibility |
| Waitlist | Показывать/скрывать `waitlist_only` независимо от immediate availability |
| Budget | `costType = estimated` и `expectedSpendAmount` на одного человека; `free` = 0; `unknown` следует общей unknown policy |
| Free only | Только явный `costType = free` |
| Radius | Только in-person/hybrid: расстояние до `publicGeo`, не до live user location |
| Available duration | Полная длительность хотя бы одного подходящего slot |
| Mood | Только через канонические category/facet mappings |
| Only available | Только `open` с достаточным immediate remaining seats; waitlist не считается available |

Unknown money/time/capacity не превращаются в ноль. Они обрабатываются по общей
политике unknown и не получают ложный boost.

Geo filtering и displayed distance используют один
`occurrence.publicGeo`; exact point никогда не участвует в public ranking. UI маркирует расстояние как
приблизительное. Privacy quantization может сдвинуть объект через границу radius,
но сервер и клиент обязаны дать один детерминированный результат.

### 13.4 Ranking

База по ADR:

```text
baseScore = geo + freshness
```

Совпадение category/subcategory и подтверждённый time fit могут использоваться
только по принятому ranking contract/ADR. Количество заявок, фото, пол, возраст,
контактные данные и платёжеспособность не являются ranking signals.

Online-only objects не получают поддельный geo score и показываются отдельной
группой. Их production ranking должен быть утверждён новым ADR до включения,
поскольку ADR 0013 фиксирует базу `geo + freshness` для географической выдачи.

### 13.5 Consistency

Results, Map, Feed и count используют один applied `DiscoverQuery` и один набор
eligible IDs. Draft camera area не запускает reload до `Search this area`.

## 14. Представление в интерфейсе

### 14.1 Search entry

В фильтре «Что» есть отдельный тип `Люди / Find people`. Выбор типа не сбрасывает
категорию занятия. Активные chips отражают оба условия, например:
`Find people · Tennis · Today · 5 km`.

### 14.2 Карточка Results/Feed

Показывает:

- badge `Find people`;
- title и category/subcategory;
- public area и расстояние до неё;
- ближайший подходящий slot в timezone viewer/market;
- schedule badge `One time`, `Time poll` или `Recurring`;
- длительность;
- `N spots left`, `Waitlist open` или `Group full`;
- ожидаемые расходы на человека;
- skill level и языки;
- publisher type, avatar/display name, responsible host и корректный verified
  badge;
- moderation-safe cover;
- CTA `View request`.

Не показывает exact address, список applicants, текст заявок, contact data,
live status или точную историю перемещений.

### 14.3 Карта

- In-person/hybrid marker строится из occurrence projection:
  `{objectId: requestId, occurrenceId, publicGeo}`.
- Отличается от Event/Place marker через variant из
  `packages/design_system`, не через локальный hex/icon hack.
- Разные eligible occurrences одного recurring request могут иметь разные
  markers. Совпадающие request/location projections группируются в preview по
  request, но cluster count остаётся честным числом occurrence projections.
- Preview использует те же summary data и eligibility, что Feed.
- Нажатие открывает preview; `Open details` ведёт в единый Details contract.

### 14.4 Details

Порядок блоков:

1. Hero, type badge, title, save/share.
2. Дата/варианты времени и длительность.
3. Public meeting area и мини-карта либо безопасный online/hybrid block.
4. Размер группы и remaining seats.
5. О занятии, уровень, темп, языки, оборудование.
6. Ожидаемые расходы.
7. Автор: display profile, verified, report/block actions.
8. Safety notice.
9. Co-hosts, conversation preview и cancellation policy.
10. Sticky CTA по state matrix.

### 14.5 CTA matrix

| Viewer state | CTA |
|---|---|
| Guest, request open | `Join` → Auth → возврат в Details |
| Автор | `Manage request` |
| Eligible User | `Request to join` |
| Pending | `Request pending` + `Withdraw` |
| Waitlisted | `On waitlist` + position policy + `Leave waitlist` |
| Seat offered | Countdown + `Confirm spot` / `Decline` |
| Invited | `Accept invitation` / `Decline` |
| Accepted | `View meeting details` + `Leave` |
| Accepted, conversation enabled | `Open group chat` |
| Co-host | `Manage request` по выданным capabilities |
| Rejected | Недоступно; понятный статус без публичной причины |
| Full | `Group full` |
| Cancelled/expired/completed | Терминальный статус, CTA отсутствует |
| Hidden/deleted | Not found / unavailable согласно route policy |
| Blocked relation | Объект недоступен |

## 15. Подача заявки

1. Пользователь нажимает `Request to join`.
2. Срабатывают Auth, 18+, block и Safety Rules guards.
3. Клиент получает актуальный request snapshot.
4. Пользователь выбирает occurrence/join scope и приемлемые slots.
5. Если party applications разрешены, выбирает `requestedSeats`; иначе `1`.
6. Отвечает на структурированные безопасные application questions.
7. Система проверяет verification requirement и guest policy, не раскрывая host
   verification documents.
8. Пользователь видит public area/online mode, расходы, cancellation policy,
   waitlist policy и правила общения.
9. Подтверждает заявку и consent на обработку её закрытых данных.
10. Создаётся idempotent `JoinRequest`: `pending`, `waitlisted` или `accepted`
    согласно approval/capacity policy.
11. Автор и Applicant получают согласованные notification/state updates.

Заявка не резервирует seats навсегда. Capacity проверяется повторно в транзакции
принятия. Для защиты от спама действуют Remote Config rate limits и cooldown;
точные значения не хардкодятся в UI. Для series приложение отдельно показывает,
на какие occurrences подана заявка и можно ли изменить scope без повторного
одобрения.

## 16. Решение автора по заявке

### 16.1 Inbox автора

Автор видит только заявки к собственному request:

- display profile Applicant;
- requested seats;
- приемлемые slots;
- answers с field-level access policy;
- время подачи;
- actions Accept / Decline / Report / Block.

Нельзя сортировать или фильтровать по чувствительным признакам.

### 16.2 Accept transaction

Операция атомарна:

1. Проверить actor и operation-specific transition:
   - manual accept: authorized host + `pending`;
   - automatic accept: policy service + `pending`;
   - confirm seat offer: сам Applicant + `offer_pending`.
2. `waitlisted` никогда не переходит прямо в `accepted`: сначала создаётся
   `offer_pending`. Invitation accept использует отдельный idempotent flow §16.6.
3. Разрешить ровно одну target occurrence и проверить её pause/status/deadline.
   Для `collecting_availability` accept допускается только вместе с finalize.
4. Пересчитать `acceptedSeats`, активные `reservedSeats` и expiry из доверенного
   occurrence scope.
5. Проверить `requestedSeats <= remainingSeats` этой occurrence. Собственная
   действующая reservation заявки учитывается ровно один раз, а не вычитается
   повторно.
6. Для provisional time-poll атомарно зафиксировать
   `occurrence.selectedSlotId`, закрыть остальные варианты и перевести
   occurrence из `collecting_availability` в пересчитанный recruitment status.
   Для finalized occurrence разрешён только её selected slot.
7. Установить тот же selected slot в заявке, status `accepted`,
   `decidedAtUtc`.
8. Обновить occurrence counters и request aggregate в той же транзакции.
9. Если remaining seats = 0, перевести occurrence в `waitlist_only` при
   включённой очереди, иначе в `full`; request aggregate пересчитать.
10. Создать audit и notification.

Повтор с тем же idempotency key возвращает прежний результат. При гонке второй
accept получает `capacity_changed`, UI обновляет список и не показывает ложный
успех.

### 16.3 Decline

- Pending заявка становится `rejected`.
- Applicant получает нейтральное уведомление без private moderation details.
- Свободные места не меняются.
- Автор может выбрать только безопасный reason code; свободный оскорбительный
  текст не отправляется.

### 16.4 Automatic approval

Automatic approval выполняет тот же transaction pipeline без host tap. До
мутации система проверяет все опубликованные hard rules, verification, capacity,
slot и safety restrictions. Результат объясним: Applicant видит, какое явное
условие не выполнено. Нельзя использовать непрозрачный «compatibility score» для
автоматического отказа.

Для `time_poll` automatic approval не может окончательно принять участника, пока
общий slot не зафиксирован. Заявка остаётся `pending`; после finalize система
повторно проверяет acceptable slots, deadline и capacity и только затем выполняет
automatic transition.

### 16.5 Waitlist и seat offer

1. При отсутствии capacity подходящая заявка становится `waitlisted`.
2. Позиция рассчитывается по опубликованной policy; точная позиция может быть
   скрыта, если очередь `host_review`, но тип порядка видим всегда.
3. Освободившееся место создаёт атомарный `offer_pending` первому подходящему
   Applicant и временно резервирует `requestedSeats`.
   При party request применяется опубликованный `waitlistSeatFitPolicy`:
   `strict_order` ждёт достаточной capacity, `first_fitting` может временно
   пропустить большую party и предложить место следующей подходящей заявке.
4. Applicant подтверждает до `offerExpiresAtUtc` или отклоняет предложение.
5. Expired/declined offer освобождает резерв и запускает следующего кандидата.
6. Host не может вручную продать или скрыто повысить приоритет в
   `first_come`; любое override в `host_review` записывается в audit.

### 16.6 Invitations и share links

- Host/co-host с capability создаёт персональное приглашение или share link с
  expiry, seat limit и revocation.
- Персональное приглашение адресуется по user ID; телефон/email не становятся
  relation key.
- Share link не резервирует место, если явно не создана bounded reservation.
- Персональный invitee выбирается из уже доступного пользователю контекста
  (явная связь, предыдущая совместная встреча, открытый профиль). Find People не
  создаёт глобальный поиск аккаунтов по контактам или proximity.
- Accept проходит те же age, block, verification, capacity и safety guards.
- При accept bounded reservation атомарно снимается и теми же seats увеличивает
  accepted count; промежуточное окно свободной capacity отсутствует.
- Invite не обходит moderation/visibility и не раскрывает exact meeting data до
  принятия.
- `invite_only` request доступен только валидному invitee/token и владельцам.

## 17. Отзыв заявки и выход участника

### Pending → withdrawn

Applicant отзывает заявку без подтверждения автора. Notification автору может
агрегироваться, чтобы не создавать шум.

### Waitlisted / offer_pending → withdrawn

Выход из waitlist удаляет активную позицию, но сохраняет audit record. Отказ от
seat offer немедленно снимает reservation и продвигает следующего Applicant.

### Accepted → withdrawn

1. Требуется подтверждение пользователя.
2. Seats освобождаются атомарно.
3. Если request был `full`, он возвращается в `open`, пока не истёк deadline.
4. Автор получает notification.
5. Exact meeting data перестают быть доступны вышедшему участнику в приложении;
   уже увиденные данные физически отозвать невозможно, что отражается в privacy
   notice.

Автор может удалить принятого участника только с reason code. Статус становится
`cancelled_by_host`, seats освобождаются, участник уведомляется. Abuse pattern
попадает в telemetry/moderation signals.

## 18. Изменение опубликованного request

### 18.1 Незначимые изменения

Исправления текста, media и notes сохраняют заявки, но проходят повторную
content moderation при необходимости.

### 18.2 Существенные изменения

Существенными считаются:

- выбранный slot/date/time;
- public или exact meeting area;
- activity category;
- expected spend;
- skill/equipment requirement;
- target group size ниже уже принятого состава.

Правила:

1. Нельзя установить target ниже `currentGroupSize`.
2. Удаление slot с pending заявками делает его недоступным и просит Applicants
   выбрать другой вариант.
3. Удаление выбранного slot accepted participant требует выбора нового slot и
   явного уведомления; молчаливая замена запрещена.
4. Перенос времени/места помечается `Changed` в Details и Notifications.
5. Существенное изменение может вернуть объект в `pending_review` по policy.

## 19. Отмена, истечение и завершение

### Отмена автором

- Требуется confirmation и reason code.
- Recruitment → `cancelled`.
- Все pending → `expired`, accepted → `cancelled_by_host`.
- Все затронутые пользователи уведомляются.
- Request исключается из Discover немедленно.
- Public details может временно показывать cancelled state по deep link.

### Автоматическое истечение

- После `occurrence.applicationDeadlineUtc` новые заявки в этот scope запрещены.
- Если встреча ещё впереди и есть accepted participants, объект остаётся
  доступным им, но исчезает из набора.
- Если заявок/участников нет или все slots прошли, recruitment → `expired`.

### Завершение

- Single/time-poll завершается после selected slot + grace period; recurring
  parent — после последней materialized occurrence и закрытия серии.
- Request уходит из публичной выдачи и затем архивируется.
- Продукт не создаёт публичный рейтинг людей: это постоянная safety policy.
- После встречи доступен private structured feedback: meeting happened,
  safety issue, no-show, report. Он влияет только на enforcement/trust policy,
  имеет appeal path и не превращается в публичные звёзды.

### Общие расходы и settlement

1. До заявки видны `costType`, валюта, estimated amount, expense items и правило
   деления.
2. После встречи authorized participant может добавить фактический расход с
   суммой, категорией, payer и receipt media; остальные участники видят и
   подтверждают свою долю.
3. Ledger использует immutable entries и compensating adjustments, а не
   перезаписывание истории.
4. In-app settlement включается только при наличии отдельного принятого payment
   contract, market compliance и provider integration. Без него продукт
   показывает расчёт долей, но не имитирует перевод денег.
5. Host не получает скрытую комиссию и не может сделать перевод условием
   acceptance. Коммерческое участие публикуется другим content type.
6. Payment status не влияет на Discover ranking, автоматическое одобрение или
   публичные trust signals.
7. Dispute, refund, chargeback и financial retention принадлежат payment domain;
   Find People хранит только references и безопасный display status.

## 20. Communication и Notifications

### 20.1 Applicant thread

- Applicant и authorized hosts получают закрытый thread после подачи заявки,
  если `conversationPolicy = applicants_and_accepted`.
- До acceptance запрещены attachments, payment requests, массовая рассылка и
  автоматическое раскрытие контактов.
- Rejected/withdrawn thread становится read-only после retention grace period.
- Report может включать выбранные сообщения только с явным действием reporter.

### 20.2 Group conversation

- После acceptance участник получает conversation конкретного request или
  occurrence.
- Поддерживаются text, reactions, location card самого meeting point, images и
  системные события; типы вложений задаются moderation policy.
- Exact location и online access публикуются системной карточкой с access check,
  а не копируются в push payload.
- Hosts могут закреплять правила/обновления, ограничивать отправку и удалять
  сообщения по policy; moderation action всегда аудируется.
- Выход/удаление участника немедленно прекращает новые reads/writes. Уже
  доставленные данные физически отозвать невозможно.
- Calls могут подключаться отдельным provider contract, но не меняют membership
  и privacy rules conversation.

### 20.3 Notifications

Обязательные semantic notification events:

| Событие | Получатель | Target |
|---|---|---|
| `join_request_received` | Автор | Manage applicants |
| `join_request_accepted` | Applicant | Accepted details |
| `join_request_rejected` | Applicant | Request details |
| `join_request_withdrawn` | Автор | Manage applicants |
| `participant_removed` | Participant | Request details |
| `request_became_open` | Автор | Manage request |
| `waitlist_joined` | Applicant | Request details |
| `seat_offer_created` | Applicant | Confirm spot |
| `seat_offer_expiring` | Applicant | Confirm spot |
| `invitation_received` | Invitee | Invitation details |
| `schedule_poll_closing` | Applicants | Time poll |
| `schedule_finalized` | Applicants/participants | Request details |
| `request_time_changed` | Pending/accepted | Request details |
| `request_location_changed` | Accepted | Accepted details |
| `find_people_cancelled` | Pending/accepted | Cancelled details |
| `find_people_reminder` | Accepted | Accepted details |
| `conversation_mention` | Conversation member | Group conversation |

Payload содержит только IDs, безопасный display text и stable target route.
Exact address, online access, application answers и контакты запрещены в push
payload и lock-screen preview. Текущий Notifications slice поддерживает только
local/mock list; production contract включает inbox, realtime sync, push,
deduplication, preferences, quiet hours и delivery analytics. Текущее local/mock
состояние — implementation gap, не ограничение продукта.

## 21. Privacy, блокировки и модерация

### 21.1 Public data

Public: title, activity, description, public area, approximate geo, slots,
duration, group summary, expected spend, safe requirements, publisher display.

### 21.2 Restricted data

Restricted:

- exact meeting point, online access и instructions — authorized hosts +
  accepted participants по reveal policy;
- application answers — Applicant + hosts с `review_applications` + moderation
  по report/legal flow;
- список заявок и waitlist — authorized hosts;
- applicant thread — Applicant + authorized hosts;
- group conversation — текущие accepted members + authorized moderators;
- audit trail — admin/moderation;
- block relation — только владелец relation и enforcement layer.

### 21.3 Report

Report доступен для request, автора и конкретной заявки там, где применимо.
Reason codes: harassment, scam/payment request, unsafe location, hate or
discrimination, sexual content, impersonation, spam, underage concern, other.

По ADR 0013 объект auto-hidden при `>= 5` уникальных reporter за 24 часа.
Один user учитывается один раз на object; report не заменяет moderation review.

### 21.4 Block

Block немедленно:

- скрывает взаимные public objects;
- запрещает новые заявки и решения;
- отзывает pending relation;
- для accepted relation запускает безопасный leave/cancel flow и предупреждает
  о последствиях для встречи;
- не удаляет audit/moderation evidence.

### 21.5 Trust signals

- Public UI может показывать только проверяемые нейтральные badges: phone/
  identity-document/organization verified, completed-meetings band,
  responsible-host status.
- Единый публичный числовой «рейтинг человека» запрещён.
- No-show, abuse, repeated cancellations и moderation outcomes используются
  только policy engine для rate limit, verification step-up или review.
- Любое ограничение имеет reason category, срок, audit trail и appeal path.
- Host не видит внутренний risk score и не может сортировать Applicants по нему.
- Trust state не денормализуется в request как источник истины; он резолвится по
  user/page ID через отдельный policy-aware contract.

### 21.6 Retention

Soft delete retention — 30 дней по ADR 0013. Более точные сроки для rejected
applications, private meeting details и telemetry должны пройти EU/Latvia legal
review до запуска функции в конкретном market. Conversation/media retention,
legal hold, account deletion и export должны иметь отдельные data-retention
policies. Документ не устанавливает юридически непроверенный срок.

## 22. Ошибки и recovery

| Code | Ситуация | Поведение UI |
|---|---|---|
| `auth_required` | Guest выполняет protected action | Auth с intended route |
| `capability_denied` | Нет права публикации | Объяснение и доступный upgrade/apply flow |
| `age_confirmation_required` | Не подтверждено 18+ | Age/Safety gate |
| `validation_failed` | Невалидные поля | Summary + переход к полю |
| `unsafe_location` | Место не проходит policy | Выбрать публичное место |
| `contacts_not_allowed` | Контакты в public text/media | Исправить конкретное поле/media |
| `slot_unavailable` | Slot удалён/прошёл | Обновить и выбрать другой |
| `occurrence_unavailable` | Occurrence закрыта/изменена | Показать актуальные occurrences |
| `deadline_passed` | Приём заявок закрыт | Терминальный state без retry |
| `already_applied` | Есть активная заявка | Открыть текущую заявку |
| `capacity_changed` | Места заняты конкурентной операцией | Refresh, без ложного success |
| `waitlist_closed` | Очередь закрыта | Обновить CTA и не создавать запись |
| `offer_expired` | Seat offer истёк | Показать cooldown и разрешить новую заявку новым ULID после него |
| `invitation_invalid` | Invite revoked/expired/used | Безопасный unavailable state |
| `verification_required` | Недостаточный verification level | Объяснить требование и открыть verification flow |
| `online_access_unavailable` | Provider/link временно недоступен | Backup plan + retry, host alert |
| `conversation_forbidden` | Нет membership/capability | Закрыть thread без утечки metadata |
| `blocked_relation` | Между сторонами block | Объект/действие недоступно |
| `moderation_hidden` | Request скрыт | Unavailable + appeal route для автора |
| `rate_limited` | Слишком много действий | Retry after, без потери draft |
| `network_unavailable` | Нет сети | Сохранить draft; mutation не считать выполненной |
| `timeout_unknown` | Результат mutation неизвестен | Повторить с тем же idempotency key |
| `conflict` | Объект обновился | Показать свежие данные и изменения |

## 23. Repository и use case boundaries

UI не выполняет бизнес-логику. Целевые domain contracts:

```text
FindPeopleRepository
JoinRequestRepository
FindPeopleOccurrenceRepository
FindPeopleInvitationRepository
FindPeopleWaitlistQueryService
FindPeopleConversationRepository
FindPeopleModerationRepository
PrivateMeetingRepository
ExpenseSettlementRepository
```

`FindPeopleWaitlistQueryService` — только read-model над `JoinRequestRepository`;
отдельного waitlist-хранилища и второго источника истины нет. Enqueue/offer/
withdraw mutations изменяют JoinRequest через соответствующие use cases.

Минимальные use cases:

- `CreateFindPeopleDraftUseCase`;
- `ValidateFindPeopleDraftUseCase`;
- `PublishFindPeopleRequestUseCase`;
- `UpdateFindPeopleRequestUseCase`;
- `CancelFindPeopleRequestUseCase`;
- `ExpireFindPeopleRequestsUseCase`;
- `MaterializeOccurrencesUseCase`;
- `UpdateRecurringSeriesUseCase`;
- `FinalizeTimePollUseCase`;
- `SubmitJoinRequestUseCase`;
- `WithdrawJoinRequestUseCase`;
- `AcceptJoinRequestUseCase`;
- `RejectJoinRequestUseCase`;
- `EnqueueWaitlistUseCase`;
- `OfferAvailableSeatsUseCase`;
- `ConfirmSeatOfferUseCase`;
- `CreateInvitationUseCase`;
- `AcceptInvitationUseCase`;
- `RevokeInvitationUseCase`;
- `AssignCoHostUseCase`;
- `TransferFindPeopleOwnershipUseCase`;
- `RemoveParticipantUseCase`;
- `ConfirmAttendanceUseCase`;
- `OpenFindPeopleConversationUseCase`;
- `SendFindPeopleMessageUseCase`;
- `SettleSharedExpensesUseCase`;
- `GetVisibleMeetingDetailsUseCase`;
- `ReportFindPeopleObjectUseCase`;
- `BlockFindPeopleUserUseCase`.

Presentation вызывает application controller. Application оркестрирует use
cases и состояние, но не содержит capacity, moderation или lifecycle rules.
Domain не зависит от Flutter/Firebase. Data layer реализует
production Firebase mapping и contract-equivalent mock mapping. Discover не
импортирует Create или Find People feature напрямую: интеграция идёт через общий
MapObject/Discover contract.

## 24. Route и deep-link contracts

Целевые стабильные ссылки:

```text
recharge://find-people/{requestId}
recharge://find-people/{requestId}/apply
recharge://find-people/{requestId}/manage
recharge://find-people/{requestId}/applications/{joinRequestId}
recharge://find-people/{requestId}/occurrences/{occurrenceId}
recharge://find-people/{requestId}/waitlist
recharge://find-people/{requestId}/invitations/{invitationId}
recharge://find-people/{requestId}/conversation
```

Все ссылки проходят общие auth/ownership/visibility guards. Deep link на private
meeting details не содержит координаты и открывается только после policy check.

## 25. Analytics

События ниже обязательны для production analytics contract и добавляются в
`docs/analytics/EVENT_CATALOG.md` в implementation slices. Этот документ сам
каталог не изменяет, потому что приложение в текущей задаче не меняется.

| Event | Trigger | Обязательные параметры |
|---|---|---|
| `find_people_create_started` | Открыт новый flow | `source_screen` |
| `find_people_draft_saved` | Завершён save | `result,error_code?` |
| `find_people_publish_completed` | Publish завершён | `result,moderation_state,error_code?` |
| `find_people_details_opened` | Открыты Details | `request_id,source` |
| `find_people_apply_started` | Открыта форма заявки | `request_id,source` |
| `find_people_apply_completed` | Заявка отправлена | `request_id,result,error_code?` |
| `find_people_application_decided` | Accept/Reject | `request_id,decision,result` |
| `find_people_application_withdrawn` | Applicant отозвал заявку | `request_id,previous_status` |
| `find_people_waitlist_joined` | Создана waitlist entry | `request_id,policy,result` |
| `find_people_seat_offer_completed` | Seat offer подтверждён/истёк | `request_id,result,error_code?` |
| `find_people_invitation_completed` | Invite создан/принят/отклонён | `request_id,action,result` |
| `find_people_schedule_finalized` | Зафиксирован poll slot | `request_id,option_count,result` |
| `find_people_occurrence_updated` | Изменена recurring occurrence | `request_id,scope,result` |
| `find_people_conversation_action` | Conversation open/send/report | `request_id,action,result` |
| `find_people_attendance_recorded` | Private attendance state обновлён | `request_id,result` |
| `find_people_request_cancelled` | Автор отменил request | `request_id,reason_code` |
| `find_people_report_submitted` | Отправлен report | `target_type,reason_code,result` |

Нельзя отправлять в analytics: свободный текст, exact location, applicant IDs,
телефон/email, age/date of birth, block target, health/accessibility notes.

## 26. Feature flags и Remote Config

Минимальные настройки:

- `findPeopleEnabled` — kill switch чтения/создания;
- `findPeoplePublishingEnabled` — отдельный kill switch mutation;
- `findPeopleMinLeadMinutes`;
- `findPeoplePlanningHorizonDays`;
- `findPeopleExactLocationRevealMinutes`;
- `findPeoplePublicGeoPrecision`;
- schedule option/materialization limits;
- waitlist offer TTL и ordering policies;
- invitation TTL/seat reservation limits;
- media/conversation limits и attachment types;
- verification requirements по risk/market;
- recurrence horizon и cleanup policy;
- publish/apply/decision rate limits;
- moderation thresholds, кроме зафиксированного ADR auto-hide baseline;
- max active requests per user/page publisher.

При выключении publishing существующие безопасные Details остаются читаемыми,
если нет отдельного emergency hide. Активные accepted participants не должны
терять критическую информацию о уже назначенной встрече без migration/incident
plan.

## 27. Acceptance criteria

### 27.1 Модель и создание

| ID | Given / When | Then |
|---|---|---|
| FP-C01 | Создан новый Find People draft | Type = `find_people`, ID локального несохранённого draft допускает `loc_*` |
| FP-C02 | Legacy draft имеет `social_request` | Он мигрирует в `find_people`, данные не теряются |
| FP-C03 | Выбрана любая active category | `applicableTypes` не блокирует Find People |
| FP-C04 | Duration <30 мин или >24 ч | Publish validation отклоняет slot |
| FP-C05 | Group size <2 или >20 | Publish заблокирован |
| FP-C06 | Public text содержит контакт/платёжную ссылку | Поле отклонено с понятной причиной |
| FP-C07 | Указан домашний/небезопасный meeting point | Publish заблокирован |
| FP-C08 | Publish успешен | Все `loc_*` IDs заменены ULID до создания relations |
| FP-C09 | Publish повторён после timeout | Idempotency не создаёт дубликат |
| FP-C10 | Пользователь offline | Draft сохраняется, fake publish success отсутствует |
| FP-C11 | `scheduleMode = time_poll` | Publish создаёт одну provisional occurrence; finalize сохраняет её ID и выбирает slot |
| FP-C12 | `scheduleMode = recurring` | Серия имеет конечный horizon, occurrences и независимые deadlines/capacity |
| FP-C13 | Page публикует request | Есть responsible host с нужными page capabilities |
| FP-C14 | Co-host приглашён | Права не действуют до принятия роли и не превышают grant |
| FP-C15 | `meetingMode = online` | Public DTO не содержит access URL/secret и не создаёт fake map coordinate |
| FP-C16 | `approvalMode = automatic` | Решение использует только опубликованные hard rules и проходит capacity transaction |
| FP-C17 | `scheduleMode = single`, publish успешен | Создана ровно одна open occurrence с selected slot, deadline и capacity |

### 27.2 Приватность и карта

| ID | Given / When | Then |
|---|---|---|
| FP-P01 | Guest читает public DTO | Exact geo/address/instructions отсутствуют |
| FP-P02 | Marker отображён на карте | Координата равна стабильной `publicGeo`, не live location |
| FP-P03 | Pending Applicant открывает Details | Exact meeting data недоступны |
| FP-P04 | Accepted participant после reveal policy открывает Details | Exact meeting data доступны |
| FP-P05 | Accepted participant вышел | Дальнейший policy read exact data запрещён |
| FP-P06 | Push сформирован | Exact address, online access и application answers отсутствуют в payload |
| FP-P07 | Пользователи заблокировали друг друга | Request и действия взаимно недоступны |
| FP-P08 | Участник удалён из group conversation | Новые reads/writes запрещены, audit сохранён |
| FP-P09 | Report включает сообщения | Передаются только явно выбранные reporter сообщения по policy |

### 27.3 Discover

| ID | Given / When | Then |
|---|---|---|
| FP-D01 | Выбран type `find_people` | Он фильтруется как content type, не fake category |
| FP-D02 | Один applied query открыт в Results/Map/Feed | Набор eligible IDs одинаков |
| FP-D03 | Radius применён | Расстояние считается до public meeting geo |
| FP-D04 | `peopleCount = 3`, remaining = 2 | Request исключён hard filter |
| FP-D05 | `onlyAvailable = true`, status full | Request исключён |
| FP-D06 | Deadline прошёл | Новая заявка и публичный набор недоступны |
| FP-D07 | Request hidden/cancelled/expired | В общей выдаче отсутствует |
| FP-D08 | Собственный request автора подходит query | Видим с `Your request` и `Manage` |
| FP-D09 | Online-only request подходит query | Он в Online group/rail, без fake geo score или marker |
| FP-D10 | Request `waitlist_only` | Видим с корректным badge; `onlyAvailable` исключает его |
| FP-D11 | Unlisted/invite-only request | Не попадает в публичную выдачу |

### 27.4 Заявки и capacity

| ID | Given / When | Then |
|---|---|---|
| FP-J01 | Guest нажимает Join | Auth открывается и возвращает в тот же request |
| FP-J02 | Автор нажимает Join своего request | Действие запрещено, доступен Manage |
| FP-J03 | Уже есть active заявка | Дубликат не создаётся, открывается существующий state |
| FP-J04 | Manual заявка успешно отправлена | Status pending, автор уведомлён |
| FP-J05 | Автор принимает заявку при наличии мест | Status accepted, occurrence seats и request aggregate обновлены атомарно |
| FP-J06 | Два accept конкурируют за последнее место | Только один успешен, второй получает `capacity_changed` |
| FP-J07 | Remaining стал 0 | Occurrence = `waitlist_only`, если очередь включена, иначе `full` |
| FP-J08 | Accepted participant вышел до deadline | Seat предложен waitlist; при пустой очереди occurrence возвращается в `open` |
| FP-J09 | Автор отклонил заявку | Status rejected, seats не изменились |
| FP-J10 | Slot не входит в acceptable slots | Accept validation запрещает выбор |
| FP-J11 | Capacity закончилась, waitlist включён | Заявка атомарно получает `waitlisted` |
| FP-J12 | Место освободилось | Ровно одна подходящая заявка получает expiring seat offer |
| FP-J13 | Seat offer истёк | Reservation снята, следующий Applicant обработан |
| FP-J14 | Валидное приглашение принято | Те же age/verification/block/capacity guards применены |
| FP-J15 | Automatic approval и последнее место конкурируют | Только одна заявка accepted, остальные waitlisted/failed по policy |
| FP-J16 | Series application | Scope и occurrences сохранены; capacity считается по каждой occurrence |
| FP-J17 | `offer_expired`, cooldown прошёл, occurrence open | Создан новый JoinRequest с новым ULID; старый остаётся в audit |

### 27.5 Изменение и завершение

| ID | Given / When | Then |
|---|---|---|
| FP-L01 | Автор уменьшает target ниже current group | Изменение запрещено |
| FP-L02 | Изменено время accepted meeting | Участники уведомлены, Details показывает Changed |
| FP-L03 | Изменена exact location | Accepted participants уведомлены, public DTO private data не раскрывает |
| FP-L04 | Автор отменяет request | Все заявки получают terminal status, request исчезает из Discover |
| FP-L05 | Последний slot завершён | Recruitment = completed/expired по фактическому состоянию, набор закрыт |
| FP-L06 | Объект получил 5 unique reports за 24 ч | Auto-hidden и отправлен на moderation review |
| FP-L07 | Изменена одна recurring occurrence | Остальная серия и история прошедших occurrences не меняются |
| FP-L08 | Time poll финализирован | Все Applicants уведомлены, несовместимые заявки получают понятный action |
| FP-L09 | Host передаёт ownership | Новый владелец подтвердил, capabilities и audit обновлены атомарно |
| FP-L10 | Встреча завершена | Доступен private feedback/no-show flow без публичного рейтинга человека |
| FP-L11 | Paused request/occurrence возобновлён после изменения seats | Status пересчитан из фактических данных, snapshot не восстановлен слепо |

### 27.6 Архитектура и качество

| ID | Проверка | Ожидаемый результат |
|---|---|---|
| FP-A01 | Layer review | В presentation и application нет domain business rules |
| FP-A02 | Import boundaries | Feature-to-feature imports отсутствуют; действуют frozen baseline/facades |
| FP-A03 | Data access | Firebase/mock скрыты за repository contracts |
| FP-A04 | Design review | Общие tokens/components находятся в `packages/design_system` |
| FP-A05 | Localization | Все пользовательские строки и plural forms проверены для en/ru/lv |
| FP-A06 | Analyzer/tests | `flutter analyze` и полный `flutter test` зелёные |
| FP-A07 | Privacy contract tests | Public DTO никогда не сериализует private meeting fields |
| FP-A08 | Transaction tests | Capacity и idempotency выдерживают повтор/гонку |
| FP-A09 | Recurrence tests | DST, materialization и scope edits не дублируют occurrences |
| FP-A10 | Security rules | Page host, co-host, Applicant, waitlist, accepted и blocked matrices закрыты deny-by-default |
| FP-A11 | Communication | Membership, moderation и attachment policies проверены негативными тестами |

## 28. Обязательные тестовые группы полной реализации

- unit: draft validation, time/DST, group math, money normalization;
- unit: lifecycle/recruitment transitions;
- unit: JoinRequest transitions и idempotency;
- unit: concurrent capacity decisions;
- unit: waitlist ordering, seat offer TTL и reservation races;
- unit: invitation expiry/revocation и co-host grants;
- unit: time poll finalization и recurring materialization/DST;
- unit: provisional occurrence сохраняет ID при time-poll finalize;
- unit: pause/resume пересчитывает status из seats/deadline;
- unit: `offer_expired` re-apply создаёт новый ULID после cooldown;
- unit: automatic approval explainability и запрещённые signals;
- unit: public/private DTO serialization;
- unit: Discover type/date/geo/people/budget eligibility;
- unit: legacy `social_request` migration;
- widget: Create steps, validation summary, preview;
- widget: Results card, map preview, Details CTA matrix;
- widget: Apply, pending, waitlisted, offer, invited, accepted и manage states;
- widget: single/time-poll/recurring create sections;
- widget: in-person/online/hybrid location/access states;
- integration: publish → discover → apply → accept → reveal → withdraw;
- integration: full → waitlist → seat offer → confirm;
- integration: invitation → accept → group conversation;
- integration: recurring series edit scopes;
- integration: cancel/reschedule notifications;
- security rules/emulator: owner, page host, co-host, applicant, waitlist,
  accepted participant, blocked user, guest, admin;
- accessibility: semantics, focus order, dynamic text, contrast;
- localization: en/ru/lv overflow and plural forms;
- privacy regression: exact fields отсутствуют в logs, analytics, push и public
  cache.

## 29. Архитектурный план полной реализации

Канон — текущий monorepo и frozen architecture baseline. Этот документ не
создаёт альтернативное дерево `recharge/lib`, корневые `lib/contracts` или
`lib/design_system`. Любое изменение baseline требует нового Accepted ADR.

Перед каждым техническим slice план уточняется по фактическому дереву без
сокращения продуктового контракта.

### Новая feature-зона

```text
apps/mobile/lib/features/find_people/
  domain/entities/
  domain/repositories/
  domain/usecases/
  data/models/
  data/datasources/
  data/repositories/
  application/controllers/
  application/state/
  presentation/pages/
  presentation/widgets/
  find_people_feature.dart
```

Обязанности слоёв:

- `domain` — entities, repository interfaces, use cases и все business rules;
- `data` — models/mappers/datasources/repository implementations;
- `application` — controller/state и оркестрация use cases без domain rules;
- `presentation` — pages/widgets без доступа к data.

App-internal pure contracts/facades следуют существующему
`apps/mobile/lib/shared/` и app composition. API DTO/clients принадлежат
`packages/api_contracts`. Новый neutral package или новая корневая зона требуют
Accepted ADR. Feature-to-feature imports запрещены.

Create form engine остаётся внутри четырёхслойной `features/create`:

- declarative configs/value objects — domain/application по ответственности;
- flow controller/state — application;
- type-specific sections/widgets — presentation;
- datasource/model mapping — data.

Отдельная пятая папка-слой `features/create/engine` не вводится без ADR.
Find People sections регистрируются декларативно через app composition/facade и
не создают собственный wizard.

### Точки интеграции

- Create form engine: declarative config и type-specific sections;
- shared MapObject/facade и `DiscoverQuery v3` migration;
- DI и router;
- Notifications semantic types/routes;
- analytics catalog;
- feature flags/Remote Config;
- `packages/api_contracts` для DTO/API clients;
- `packages/design_system` для tokens/components/marker variants;
- mock seed/datasource;
- tests по §28;
- `LAUNCH_STATUS.md` только после фактической реализации.

Нельзя размещать domain logic в `presentation`, Firebase DTO в domain или
создавать прямой импорт `discover ↔ find_people ↔ create`.

### Разрешённый slice во время стабилизации: FP-CRT-FIND-01

Это завершение одного из утверждённых 10 Create-блоков и не является новой
фичей. Slice работает на текущем mock/local contract и включает только:

- типизированные Find People draft data/schema migration;
- полный declarative Create config всех product modes;
- type-specific sections внутри общего form engine;
- domain validation use case;
- autosave/load/preview и mock publish mapping;
- unit/widget tests блока.

Slice не добавляет DiscoverQuery v3, Join/Waitlist, Report/Block, conversation,
новые cross-feature routes или Firebase. Он обязан завершиться зелёными
`flutter analyze` и полным `flutter test`.

### Post-stabilization slices

| Slice | Scope |
|---|---|
| FP-DOM-01 | Универсальные occurrences, lifecycle, repositories и migrations |
| FP-DISC-01 | Shared MapObject facade, DiscoverQuery v3, Results/Map/Details |
| FP-JOIN-01 | Applications, occurrence capacity, waitlist, offers, invitations |
| FP-SAFE-01 | Verification, Report/Block, moderation/audit integration |
| FP-COMM-01 | Conversations, reminders, attendance и expenses |
| FP-BE-01 | Firebase/FCM/Remote Config после отдельной readiness/ADR проверки |

Persisted schema с первого production write совместима с полной моделью v3.1.
Feature flags управляют доставкой поведения, но не переопределяют semantics
полей и не удаляют возможности из product blueprint.

## 30. Definition of Done production-функции

Find People как production-функция не считается Done, пока:

- все обязательные acceptance criteria реализованы и покрыты тестами;
- privacy/security rules проверены негативными тестами;
- data migration и rollback path описаны;
- feature flags и kill switches работают;
- analytics catalog обновлён без sensitive payload;
- legal/privacy review для Riga/Latvia завершён;
- production datasource, security rules, indexes, background jobs, backup и
  data export/delete flows проверены; mock не входит в production flavor;
- waitlist/capacity/invitation transactions проверены под конкурентной
  нагрузкой;
- conversation moderation, abuse rate limits и incident runbook готовы;
- observability покрывает publish, Discover, application, waitlist, messaging,
  recurrence jobs и delivery failures без sensitive payload;
- performance/SLO gates для Search, Map, Details и mutations утверждены и
  измерены на целевых устройствах;
- accessibility и en/ru/lv проверены на всех состояниях, включая ошибки и
  plural forms;
- `flutter analyze` возвращает 0 ошибок;
- полный `flutter test` проходит;
- boundary check проходит;
- `LAUNCH_STATUS.md` отражает фактическое, а не целевое состояние;
- рабочее дерево не содержит build/cache artifacts.

## 31. Итоговое пользовательское поведение

1. Creator или ManagedPage с ответственным host создаёт запрос о конкретном
   занятии, выбирает single/time-poll/recurring schedule, in-person/online/
   hybrid format, состав группы, approval, waitlist, расходы и видимость.
2. Система сохраняет draft, валидирует безопасность и публикует request как
   `find_people` MapObject.
3. Пользователи находят public request через общий Search/Results/Map/Feed;
   online requests видны без fake marker, unlisted/invite-only не протекают в
   публичную выдачу.
4. До принятия видны только безопасные public data, приблизительная область или
   online badge; точная точка и access secrets закрыты.
5. Совершеннолетний User подаёт заявку либо принимает приглашение. Manual/
   automatic approval, capacity и verification работают через одинаковые
   guards и атомарные transitions.
6. При отсутствии мест пользователь входит в прозрачный waitlist, получает
   expiring seat offer и подтверждает его без гонок за capacity.
7. Time poll фиксирует один общий slot, recurring request управляет отдельными
   occurrences без потери истории.
8. Принятый участник получает точную точку/online access по reveal policy,
   reminders и доступ в закрытую group conversation.
9. Co-hosts, изменения, отмена, attendance, выход участника и общие расходы
   корректно обновляют статусы, доступы, audit и уведомления.
10. После встречи request закрывается, исчезает из активной выдачи и предлагает
    private safety/no-show feedback без публичного рейтинга человека.
11. Ни на одном этапе функция не превращается в dating-механику, карту реальных
    людей или механизм слежения.

## 32. Продуктовое обещание

Find People помогает человеку безопасно и быстро найти компанию **для уже
понятного занятия**, договориться о времени и месте, собрать подходящую группу и
реально встретиться. Ценность измеряется состоявшимися встречами, а не числом
просмотров, свайпов или сообщений.

Функция считается качественной, если пользователь:

1. понимает предложение по одной карточке;
2. видит, подходит ли время, место, стоимость и уровень;
3. принимает осознанное решение без раскрытия лишних данных;
4. получает предсказуемый ответ на заявку;
5. не теряет место из-за race condition;
6. знает, что изменилось и что делать дальше;
7. безопасно получает meeting details;
8. может выйти, пожаловаться или получить помощь в любой момент;
9. после встречи не превращается в объект публичного рейтинга.

Первый market — Riga/Latvia, но категории, языки, валюты, timezone, safety и
legal policies разрешаются через market contracts, а не хардкодятся в flow.

## 33. Пользователи и Jobs To Be Done

| Пользователь | Основная задача | Успешный исход |
|---|---|---|
| Participant | Найти компанию для конкретной активности | Подходящая встреча найдена, заявка понятна, участие подтверждено |
| Personal host | Собрать надёжную группу | Нужное число участников подтвердилось и пришло |
| Page host | Организовать некоммерческую активность сообщества | Ответственные hosts, прозрачные правила, управляемая группа |
| Co-host | Помочь с заявками, временем и участниками | Действия ограничены grant и полностью аудируются |
| Invited guest | Безопасно принять приглашение | Понятен источник invite, условия и требуемые данные |
| Waitlisted user | Получить честный шанс на освободившееся место | Очередь прозрачна, offer не теряется, решение ограничено по времени |
| Support/Admin | Разрешить проблему без лишнего доступа к данным | Есть evidence, audit, policy actions и appeal path |

Ключевые пользовательские формулировки:

- «Хочу сегодня поиграть в теннис, но не с кем».
- «Ищу ещё двух человек для спокойной прогулки в субботу».
- «Мы не уверены во времени — давайте выберем общий вариант».
- «Наш беговой клуб ищет компанию на несколько воскресений».
- «Место освободилось — хочу подтвердить его без повторной анкеты».

## 34. Принципы идеального опыта

1. **Activity first.** Сначала занятие, потом люди; функция не становится
   каталогом профилей.
2. **Intent before data.** Пользователь понимает цель запроса до раскрытия
   профиля, заявки или точной точки.
3. **Progressive disclosure.** Поля появляются только когда нужны выбранному
   schedule, meeting, approval или cost mode.
4. **One source of truth.** Search, Results, Map, Feed, Details, capacity и CTA
   читают одни applied state и authoritative contracts.
5. **Explain every decision.** Фильтр, auto-approval, waitlist, moderation и
   verification имеют понятную причину и следующий шаг.
6. **Safety without fear design.** Предупреждения конкретны и своевременны, но
   не перегружают обычный сценарий тревожными экранами.
7. **No surprise mutations.** Время, место, цена, состав и доступ не меняются
   молча.
8. **Calm UI.** Минимализм, `designTokens.brand.primary`, много воздуха,
   скруглённые карточки и один главный CTA. Значение цвета живёт только в
   `packages/design_system`.
9. **Accessible by default.** Весь flow работает без цвета, жестов и точного
   моторного управления как единственного способа понять или выполнить действие.
10. **Recovery over dead ends.** Ошибка предлагает безопасное продолжение,
    сохраняя draft и введённые ответы.

## 35. Идеальный journey владельца

### 35.1 Создание

1. Владелец выбирает Find People и сразу видит короткое объяснение: «Создайте
   запрос найти компанию для занятия».
2. Выбирает activity/category; form engine показывает релевантные поля уровня,
   темпа, оборудования и формата.
3. Выбирает single, time poll или recurring schedule.
4. Настраивает in-person, online или hybrid meeting без публикации secret data.
5. Задаёт размер группы, approval, вопросы, waitlist и расходы.
6. Выбирает publisher, responsible hosts, co-host grants и visibility.
7. Получает preview, идентичный public Details, плюс отдельный private preview.
8. Validation summary объясняет каждую блокирующую проблему и ведёт к полю.
9. Publish создаёт один объект даже при повторном tap/timeout.

### 35.2 Набор группы

1. Manage dashboard показывает funnel: views → applications → accepted →
   confirmed, но не раскрывает чувствительную аналитику.
2. Time poll показывает совместимость вариантов и срок финализации.
3. Inbox группирует pending, waitlist, offers, accepted и reported без потери
   индивидуального state.
4. Accept/Reject/Waitlist доступны только если actor имеет capability.
5. Capacity, reservations и invitation seats обновляются атомарно.
6. При заполнении группы dashboard предлагает закрыть waitlist, оставить её
   открытой или приостановить набор.

### 35.3 Проведение и завершение

1. Host публикует закреплённое сообщение, meeting instructions и backup plan.
2. Система собирает reconfirmation и предупреждает о риске недобора.
3. Host меняет время/место только через change flow с impact preview.
4. После встречи отмечает attendance, подтверждает расходы и закрывает request.
5. Private feedback/report остаётся доступным из истории.

## 36. Идеальный journey участника

1. Пользователь входит через Search, Home, Map, category, recommendation, share
   link или Invitation.
2. Карточка отвечает на пять вопросов: что, когда, где/online, сколько людей,
   сколько стоит.
3. Details показывает требования, publisher/hosts, safety, cancellation и
   актуальное состояние мест.
4. Apply sheet содержит только необходимые вопросы и сохраняет прогресс при
   Auth/verification handoff.
5. Пользователь сразу получает однозначный state: Pending, Waitlisted, Offered,
   Accepted или недоступность с причиной.
6. Waitlist/offer не требует повторного ввода анкеты.
7. После acceptance открываются meeting details, conversation, reminders и
   управление attendance.
8. При изменении условий пользователь видит diff и обязан подтвердить
   критическое изменение, если policy этого требует.
9. Leave/Block/Report доступны из Details и conversation не глубже двух taps.
10. История показывает завершённые встречи и private actions без публичной
    оценки личности.

## 37. Карта экранов и состояний

| Surface | Обязательное содержание | Главный action |
|---|---|---|
| Create Hub card | Назначение, пример, draft badge | `Create request` / `Continue` |
| Create stepper | Progress, autosave, contextual sections | `Continue` |
| Preview | Public/private comparison, validation | `Publish` |
| Results card | Activity, time, area/mode, seats, spend, host | `View request` |
| Map preview | Public marker или Online rail item | `Open details` |
| Details | Полные public условия, trust, safety, CTA state | Контекстный Join/Manage |
| Apply sheet | Slots/scope, seats, questions, consent | `Send request` |
| Application status | Timeline, state reason, withdrawal | Контекстный action |
| Manage dashboard | Funnel, capacity, schedule, alerts | `Review applications` |
| Applicant inbox | Pending/waitlist/offers/accepted tabs | `Review` |
| Time poll | Options, aggregate fit, deadline | `Finalize time` |
| Waitlist manager | Policy, positions, active offers | `Offer seats` / policy action |
| Invitation manager | Invitees, links, reservations, expiry | `Invite` |
| Meeting hub | Exact access, attendees, rules, backup | `Open conversation` |
| Conversation | Messages, pinned update, report | `Send` |
| Expense ledger | Planned/actual shares, disputes | `Confirm share` |
| Post-meeting | Attendance, private feedback, report | `Complete` |
| Cancel/change flow | Impact preview, recipients, reason | `Confirm change` |

Каждый async surface имеет состояния initial/loading/content/empty/refreshing/
recoverable-error/terminal-error. Skeleton не подменяет empty state, а retry не
создаёт повторную mutation.

## 38. UX Create-блока

Create block состоит из шести динамических шагов:

1. **Activity** — title, category, description, level, language, rules.
2. **Schedule** — single/time poll/recurring, timezone, deadlines.
3. **Meeting** — in-person/online/hybrid и private reveal preview.
4. **Group** — size, approval, questions, waitlist, guests, costs.
5. **Hosts & access** — publisher, co-hosts, visibility, conversation.
6. **Media & preview** — cover/gallery/video, validation, publish timing.

Поведение:

- верхний progress показывает смысл шага, а не только номер;
- Back никогда не удаляет данные;
- Continue валидирует текущий шаг, но draft можно закрыть невалидным;
- переключение mode показывает impact до удаления несовместимых данных;
- удалённые mode-specific данные сохраняются в reversible draft cache до
  подтверждения или конца session;
- preview доступен с любого шага после заполнения минимальных public fields;
- autosave status имеет `Saving`, `Saved`, `Offline`, `Conflict`, `Error`;
- publish summary отдельно показывает public, accepted-only и admin-only data;
- все destructive действия требуют точного именованного подтверждения и имеют
  recoverable outcome там, где это допускает lifecycle.

## 39. Matching и рекомендации

### 39.1 Разрешённые сигналы

- явный query и выбранные filters;
- content type/category/subcategory/tags;
- time fit и available duration;
- public geo или online market/language scope;
- remaining seats и party size;
- expected spend;
- freshness в рамках принятого ranking contract;
- безопасные activity requirements;
- пользовательская история сохранений/участий только при действующем consent.

### 39.2 Запрещённые сигналы

- пол, этничность, религия, здоровье, политические взгляды;
- private messages/application answers;
- exact location или перемещения;
- внутренний risk score;
- платежеспособность;
- цена продвижения как скрытая замена organic ranking;
- публичная «привлекательность» или personality compatibility score.

### 39.3 Объяснимость

Recommendation имеет одну короткую причину: `Near you`, `Fits your time`,
`Matches tennis`, `2 spots left`, `In your language`. Пользователь может скрыть
request, publisher или recommendation reason. Zero-result relaxation никогда не
меняет query без подтверждения.

Online ranking, персонализация и любой новый weight включаются только после
требуемого ADR, offline evaluation, bias review и kill switch.

## 40. Cold start и качество предложения

Чтобы функция была полезна с первого дня:

- Page/Creator onboarding предлагает качественные templates по категориям;
- seed requests существуют только как явно маркированные demo/curated объекты и
  никогда не притворяются реальными людьми;
- пустая выдача предлагает соседние даты, radius, online или смежную категорию;
- запрос без cover получает качественный category visual;
- title/description assistant предлагает текст, но автор подтверждает его и
  остаётся ответственным;
- duplicate detection объединяет повторную публикацию после timeout и
  предупреждает о похожем активном request;
- stale/abandoned requests автоматически закрываются по lifecycle;
- supply dashboard показывает реальные gaps по category/time/area без
  публикации индивидуального спроса.

## 41. Trust & Safety operation

### 41.1 До публикации

- capability, age policy, rate limit и session risk checks;
- text/media/contact/payment solicitation moderation;
- unsafe/private-location validation;
- duplicate/spam detection;
- step-up verification по risk/market policy;
- pending review для объектов, требующих human moderation.

### 41.2 Во время набора

- block/report enforcement в Search, Details, applications и conversation;
- rate limits на apply/invite/message/decision;
- prohibited-question moderation;
- detection массовых отказов, harassment и payment scams;
- auto-hide строго по ADR 0013 с дальнейшим review.

### 41.3 Перед встречей

- reconfirmation;
- reminder с safety actions;
- emergency change/cancel flow;
- быстрый Report/Block;
- backup plan для погоды или provider failure.

### 41.4 После встречи

- private attendance/safety feedback;
- no-show и repeated-cancellation policy с appeal;
- evidence preservation по retention/legal hold;
- support handoff с correlation ID без копирования secret data.

Критический safety report не должен ждать общей auto-hide границы. Emergency
policy может немедленно ограничить object/user action с audit и обязательным
human review.

## 42. Admin, moderation и support console

Production operation требует отдельных staff surfaces:

- moderation queue с priority/risk reason и SLA;
- object/user/page/application/conversation report context;
- redacted public/private field comparison;
- duplicate, rate-limit и suspicious-activity evidence;
- action panel: approve, reject, hide, restore, restrict, escalate;
- immutable audit timeline;
- appeal queue и independent reviewer assignment;
- support lookup по object/user/correlation ID;
- safe impersonation-free preview ролей Guest/Applicant/Accepted/Host;
- incident banner/kill-switch status;
- data export/delete/legal hold workflows.

Staff RBAC следует least privilege. Exact meeting, application answers и message
content открываются только когда это необходимо для конкретного case и каждое
чтение аудируется. Secret links/passcodes не показываются в console открытым
текстом.

## 43. Здоровый рост продукта

Разрешённые growth loops:

- share request/invitation с expiry;
- повторить завершённый request как новый draft;
- создать recurring series из успешной одиночной встречи;
- follow Page/community с явным consent;
- сохранить category/time search;
- пригласить прежнего участника из существующего relationship context;
- показать похожие активности после завершения.

Запрещены:

- автоприглашения контактам;
- публикация от имени пользователя без preview;
- искусственная срочность при наличии мест;
- скрытые подписки;
- notification spam;
- pay-to-win admission;
- dark patterns против Leave, Block, Report или Delete.

## 44. Монетизация без разрушения доверия

Find People остаётся некоммерческим поиском компании. Допустимая монетизация:

- Creator/Page subscription за расширенные management/insights tools;
- платные организационные инструменты, не влияющие на admission;
- прозрачная комиссия отдельного payment provider за добровольный settlement;
- явно маркированное promoted placement только в отдельном рекламном слое,
  никогда не смешанное с organic ranking.

Недопустимы продажа мест в waitlist, платный приоритет заявки, скрытая комиссия
host, продажа exact location, application answers или behavioral data.

## 45. Accessibility, локализация и инклюзивность

- Цель — WCAG 2.2 AA для всех Find People surfaces.
- Touch targets, contrast, focus order, screen-reader labels и Dynamic Type
  проверяются автоматически и вручную.
- Цвет не является единственным носителем status; badge имеет текст/иконку.
- Motion respects reduced-motion setting; countdown доступен текстом.
- Map имеет эквивалентный list flow и не является обязательной точкой входа.
- Time, date, number, currency, distance и plural forms форматируются locale.
- User-generated content не переводится молча; auto-translation помечается и
  позволяет открыть оригинал.
- Canonical UI локализуется на en/ru/lv; data model принимает расширяемые BCP-47
  languages.
- RTL, длинные строки и увеличение текста не должны ломать action hierarchy.
- Accessibility requirements описывают условия активности, но не раскрывают
  диагноз и не используются для скрытого профилирования.

## 46. Production SLO и отказоустойчивость

Целевые quality gates:

| Область | Цель |
|---|---|
| Локальная UI interaction | p95 < 150 ms без visible jank |
| Apply filters после готовых данных | p95 < 300 ms |
| Details из сети | p95 < 1.5 s на поддерживаемой сети |
| Mutation acknowledgement | p95 < 2 s либо честный `timeout_unknown` |
| Realtime conversation delivery | p95 < 3 s при доступном provider |
| Critical notification enqueue | p95 < 60 s |
| Crash-free sessions | ≥ 99.5% |
| Backend availability Find People | ≥ 99.9% monthly |

Все SLO измеряются отдельно по platform/build/market без sensitive dimensions.
При деградации:

- drafts продолжают сохраняться локально;
- mutations используют idempotency и reconciliation;
- cached Details явно показывают freshness;
- exact meeting data для уже accepted participants имеет защищённый offline
  access policy, если legal/security review это разрешает;
- conversation показывает delivery state;
- background jobs materialization/expiry повторяются безопасно;
- fallback не создаёт fake success, capacity или location;
- incident runbook определяет disable, read-only и recovery modes.

## 47. Метрики идеального продукта

### 47.1 North-star metric

`Safe completed meetups per weekly active Find People user` — число завершённых
встреч с подтверждённым участием и без unresolved critical safety incident.

### 47.2 Funnel

- Create started → valid draft → published;
- impression → Details → Apply;
- Apply → accepted/waitlisted/rejected;
- waitlist → offer → confirmed;
- accepted → reconfirmed → attended;
- recurring occurrence retention;
- time to first qualified application;
- time to filled group.

### 47.3 Quality guardrails

- cancellation/no-show rate;
- report rate и severity;
- block-after-interaction rate;
- moderation false-positive/appeal overturn rate;
- capacity conflict rate;
- expired seat-offer rate;
- notification opt-out and mute rate;
- message/report response SLA;
- exact-data access denial anomalies;
- accessibility task completion.

Метрики не оптимизируются по отдельности. Рост completed meetups не считается
успехом, если ухудшаются safety, fairness, privacy или cancellation guardrails.

## 48. Experimentation policy

- Эксперимент имеет hypothesis, owner, primary metric, guardrails и stop rule.
- Security, exact-location access, block/report, legal consent и capacity
  correctness не отключаются экспериментом.
- Ranking test не использует sensitive traits и проходит bias review.
- User assignment стабилен и не попадает в analytics как прямой identifier.
- Experiment не меняет видимые условия после подачи заявки.
- Dark patterns и deceptive urgency запрещены.
- Победивший эксперимент обновляет spec/config/tests; вечные скрытые ветки
  запрещены.

## 49. Production rollout и миграция

1. Утвердить необходимые ADR для online ranking/spatial contract и иных
   архитектурных изменений.
2. Зафиксировать API/data schema, indexes, security rules и migration version.
3. Мигрировать legacy `social_request` drafts в `find_people` с dry run и
   обратимым mapping report.
4. Заполнить production taxonomy/config без demo-профилей, выдаваемых за людей.
5. Проверить emulator/security matrix и нагрузочные transactions.
6. Провести internal dogfood с production-equivalent backend.
7. Включать capabilities по cohort/market через flags, не меняя data semantics.
8. Проверить support/moderation staffing, alerts и incident runbook.
9. Пройти legal/privacy/accessibility/localization gates.
10. Удалить rollout flags только после стабильного периода и cleanup plan.

Phased rollout управляет риском доставки, но не определяет урезанную модель
продукта: все persisted contracts с первого production write совместимы с полной
спецификацией.

## 50. Финальный критерий идеального продукта

Find People готов как продукт, когда одновременно выполняется следующее:

- запрос создаётся без лишней сложности во всех schedule/meeting modes;
- public/unlisted/invite-only visibility не протекают друг в друга;
- Search/Map/Feed/Details дают согласованный результат;
- Page, hosts и co-host capabilities проверяются на каждом действии;
- manual/automatic/invite admission объясним и недискриминационен;
- capacity, reservations, parties, waitlist и invitations не допускают
  oversubscription;
- private meeting/online access доступен только текущим authorized users;
- recurring occurrences, attendance и expenses не переписывают историю;
- conversation безопасен, модерируем и membership-aware;
- change/cancel/leave/block/report работают предсказуемо;
- support и moderation имеют достаточный, но минимальный доступ;
- accessibility и en/ru/lv не являются вторичной доработкой;
- SLO, аналитика и safety guardrails наблюдаемы;
- rollout, rollback, migration и incident recovery проверены;
- North-star растёт без ухудшения privacy, fairness и safety;
- приложение никогда не показывает живых людей на карте и не превращает
  совместный досуг в dating-механику.

Идеальный результат для пользователя звучит просто: **«Я нашёл подходящую
компанию, всё было понятно и безопасно, и мы действительно встретились».**
