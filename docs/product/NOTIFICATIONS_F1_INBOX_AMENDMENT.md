# F1 — поправка контракта: Notifications inbox без push

Статус: **Accepted (2026-10-08)** с уточнениями владельца; реализация после
этой поправки, без повторного согласования остальных решений.

Область: только локальный стенд `demo-recharge` (Emulator, loopback). Не
production-контракт, не cloud, не deployment, не push. Дополняет BCK-13
(`NOTIFICATIONS_BACKEND_SPEC.md`) и BCK-09 (outbox Booking); ни одно
существующее правило не ослабляется. Числовые значения ниже — **тестовые
константы стенда**, не product defaults и не production policy.

Имя: **F1** — этот срез Notifications. Ранее записанный в
`C1_E2_CLOSURE_REVIEW.md` срез «Booking hide fence» переименован в
**`BOOKING-HIDE-FENCE-01`**; его приоритет перед реальным использованием
бронирования сохраняется.

## 0. Что меняется

1. Booking (единственный писатель `bookingOutbox`) при включённом Booking-флаге
   пишет запись **v2** в форме принятого OD-09 envelope; при выключенном — ровно
   прежнюю v1 `suppressedPreActivation` (§2).
2. Новый модуль Notifications потребляет только v2, создаёт не более одной
   логической записи inbox на эффект и получателя (§4), ведёт сохраняемые
   claim/lease-попытки (§5), подавления (§6), сверку (§7) и retention (§8).
3. Notifications становится privacy-доменом `notifications` (§9).
4. Два клиентских callable и один Firestore trigger (§12–§13).
5. Мобильный клиент получает серверный inbox за default-off тестовым входом (§14).

Старые записи `suppressedPreActivation` не активируются никогда: для них не
создаются receipt, inbox или попытки, их нельзя replay.

## 1. Флаги (все Emulator-only, по умолчанию выключены)

| Флаг | Владелец | Что включает |
|---|---|---|
| `booking.notification.effects` | Booking | Booking пишет v2 вместо v1 |
| `notifications.consume.booking` | Notifications | trigger и reconcile потребляют v2 |
| `notifications.inbox` | Notifications | `listInbox`, `unreadSummary`, `markRead`, `markAllRead`, `archive` |
| `notifications.preferences` | Notifications | `getPreferences`, `updatePreferences` |

Booking-флаг читается до транзакции через тот же `FirestoreFeatureFlagGate`
(вне Emulator всегда `false`). Выключенный consumer-флаг означает «Notifications
недоступен»: v2 остаётся необработанной и подбирается сверкой после включения
(§7), если окно доставки не истекло.

## 2. Продюсер: Booking outbox v2 (принятый OD-09 envelope)

ID документа не меняется: `${bookingId}__r${revision}` — одна запись на одну
зафиксированную семантическую транзакцию Booking; он же OD-09 `eventId`.

```text
schemaVersion: 2
effectDisposition: 'pending'
dispatchable: true
replayable: true
eventId            = ID документа
eventType          ∈ booking.confirmed | booking.cancelled |
                     booking.reconfirmationRequired | booking.reconfirmed
eventVersion: 1
producer: 'booking'
aggregateType: 'booking'
aggregateId        = bookingId
aggregateRevision  = ревизия Booking после перехода
occurredAt         = время перехода (UTC)
correlationId      = командный logicalId | `occ_`+hash(projection event) |
                     ID deadline-job | `privacy_`+hash(bookingId)
marketId           = booking.marketId
dataClass: 'personal'
payload: {
  schemaVersion: 1,
  eventContentId, occurrenceId,
  cause?: userCancelled | occurrenceCancelled | missedReconfirmation | privacyErasure,
  reconfirmationDeadlineUtc?,       // только reconfirmationRequired
  deliverUntilUtc                   // заявленная продюсером актуальность
}
actorId            = booking.userId  // субъект Booking = получатель
createdAt          = occurredAt
retentionClass: 'bookingOutbox', legalHold: false
expiresAt          = deliverUntilUtc + 30 суток
```

`causationId` не используется (необязателен в OD-09). Получатель хранится
только в `actorId`: это существующее identity-поле Booking, которое Booking
erasure уже псевдонимизирует; payload идентификаторов людей не содержит.

`deliverUntilUtc` = `occurredAt + 7 суток`; для `reconfirmationRequired` —
`min(occurredAt + 7 суток, reconfirmationDeadlineUtc)`.

Сопоставление пяти мест записи Booking:

| Место | v1 `obligationType` | v2 `eventType` / `cause` |
|---|---|---|
| `create_internal_booking.ts` | booking_confirmation | booking.confirmed |
| `cancel_internal_booking.ts` | booking_cancellation | booking.cancelled / userCancelled |
| `reconfirm_internal_booking.ts` | booking_reconfirmation | booking.reconfirmed |
| `occurrence_lifecycle.ts` (cancel) | booking_cancellation | booking.cancelled / occurrenceCancelled |
| `occurrence_lifecycle.ts` (privacy) | booking_cancellation | booking.cancelled / privacyErasure |
| `occurrence_lifecycle.ts` (reschedule) | booking_reconfirmation | booking.reconfirmationRequired |
| `reconfirmation_deadline_worker.ts` | booking_cancellation | booking.cancelled / missedReconfirmation |

v2 снимает прежнюю неоднозначность: v1 `booking_reconfirmation` означал и
«требуется подтверждение», и «пользователь подтвердил».

Порядок по агрегату (OD-09): consumer хранит `aggregateRevision`; эффект,
пришедший после уже созданной записи более новой ревизии того же Booking,
не применяется вслепую, а подавляется как `superseded` (§6).

## 3. Разрешённые эффекты и локальная политика категорий (ревизия 1)

Политика `notifications-local-policy` ревизия 1 — **локальная**, не Legal
mandatory policy (BCK13-OD-04 остаётся открытым). Booking-уведомления не
объявляются обязательными автоматически: обязательность задана явно по
категориям.

| Эффект | Категория | Шаблон | inApp по умолчанию | Пользователь может выключить |
|---|---|---|---|---|
| booking.confirmed | `booking.receipts` | booking.confirmed | включено | **да** |
| booking.cancelled / userCancelled | `booking.receipts` | booking.cancelled.byUser | включено | **да** |
| booking.reconfirmed | `booking.receipts` | booking.reconfirmed | включено | **да** |
| booking.cancelled / occurrenceCancelled | `booking.changes` | booking.cancelled.occurrence | включено | нет — локально закреплено |
| booking.cancelled / missedReconfirmation | `booking.changes` | booking.cancelled.missedReconfirmation | включено | нет — локально закреплено |
| booking.reconfirmationRequired | `booking.changes` | booking.reconfirmationRequired | включено | нет — локально закреплено |
| booking.cancelled / privacyErasure | — | — | — | всегда подавляется `recipient_erasure` |

Обоснование закрепления `booking.changes` (локальное, для стенда): изменение
активной брони инициировано организатором или системой либо требует действия
пользователя. `booking.receipts` — подтверждение собственного действия
пользователя, которое уже видно в приложении.

Что реально меняют preferences в F1:

- выключение `booking.receipts.inApp` → новые эффекты этой категории получают
  терминальное подавление `user_preference`: запись inbox **не создаётся**;
- включение обратно действует только на будущие эффекты; подавленные ранее не
  создаются задним числом, существующие записи не удаляются;
- попытка выключить закреплённую категорию → `invalid_preference`
  (`category_locked`); неизвестная категория или канал → `invalid_preference`.

Каналы ревизии 1: только `inApp`. Push, email и SMS в политике отсутствуют —
их нельзя включить (fail-closed), попыток и провайдеров нет.

Preferences: `notificationPreferences/{userId}` — `revision`, `policyRevision`,
`categories` (только незакреплённые), служебный `processingRestricted`
(§9). Отсутствующий документ = значения политики по умолчанию. Запись только
командой с `expectedRevision` (0 для отсутствующего документа).

## 4. Идентификаторы и дедупликация

| ID | Формула | Назначение |
|---|---|---|
| OD-09 `eventId` | ID документа outbox | идентичность эффекта |
| `receiptId` | `nrc_` + sha256(`notifications.inbox|1|eventId`)[0..40] | ключ consumer по OD-09: (consumerName, consumerVersion, eventId) |
| `notificationId` | `ntf_` + sha256(`inbox-item|receiptId`)[0..32] | логическая запись inbox |
| `attemptId` | `${receiptId}_a${NN}` | попытка доставки |

Receipt создаётся только один раз; запись inbox создаётся в той же транзакции,
что и терминальный `created` в receipt. Один получатель на эффект в Booking
(субъект брони); будущий fan-out потребует новой версии consumer. Повтор того же
`eventId` с другим содержимым (sha256 канонического envelope) →
`payload_conflict`, без мутации, finding в сверке.

## 5. Протокол попыток: сохраняемый claim/lease

Ответ на вопрос «где сохранится неудачная попытка, если транзакция создания
откатится»: попытка начинается **отдельной** транзакцией claim и поэтому
сохраняется независимо от исхода транзакции завершения.

**Tx1 — claim** (читает receipt и статус аккаунта получателя):

- receipt терминальный (`created`, `suppressed`, `expired`, `erased`) → повтор,
  ничего не пишется;
- `dead_lettered` → ничего (нужен replay, §7);
- `claimed` с действующим lease → `busy`; `retry_scheduled` до срока → `not_due`;
- аккаунт ограничен или отсутствует, причина privacyErasure, окно истекло →
  минимальное терминальное подавление (§6) прямо в claim;
- неразбираемый или неподдерживаемый envelope → `dead_lettered`
  (`invalid_effect` / `unsupported_effect`) — карантин poison, без повторов;
- иначе номер попытки `n = attemptCount + 1`; если `n` > бюджета →
  `dead_lettered` (`retry_exhausted`); если прежний lease истёк, его попытка
  помечается `abandoned` (`lease_expired`);
- при первой попытке **фиксируются ревизии шаблона и политики** (`pinned`);
  повторы и replay используют только их;
- пишутся receipt `claimed` с новым `leaseId` и `leaseExpiresAt` и документ
  попытки `started`.

**Tx2 — complete** (атомарно):

- перечитывает receipt; если статус не `claimed` или `leaseId` не совпадает →
  `stale`, **никаких записей** (защита от устаревшего worker);
- перечитывает статус аккаунта, preferences (включая `processingRestricted`),
  окно доставки и receipts того же агрегата (supersession);
- создаёт запись inbox (`create`; занятый чужим документом ID → постоянный
  отказ `item_conflict`) **или** терминальное подавление;
- переводит receipt в терминальное состояние и попытку в `succeeded`.

**Tx3 — fail** (после исключения в Tx2): при совпадающем `leaseId` попытка →
`failed` с классом (`transient` / `permanent`) и кодом; receipt →
`retry_scheduled` с `nextAttemptAt = now + 30 с × 2^(n−1)` либо
`dead_lettered` (постоянный отказ или исчерпан бюджет). Если и Tx3 не удалась,
claim остаётся с lease; после истечения lease следующий worker фиксирует попытку
как `abandoned` и начинает новую.

Точки падения и обязательный исход (каждая — тест):

| Падение | Что сохранено | Исход после восстановления |
|---|---|---|
| после Tx1, до Tx2 | receipt `claimed`, попытка `started` | до конца lease — `busy`; после — `abandoned` + новая попытка; одна запись |
| Tx2 откатилась (отказ записи inbox или чтения preferences) | claim + Tx3 `failed` | `retry_scheduled` → повтор с теми же pinned ревизиями; одна запись |
| Tx2 откатилась и Tx3 не удалась | claim | истечение lease → `abandoned` → новая попытка |
| после commit Tx2, до подтверждения результата | терминальный receipt + запись | повторная доставка и сверка видят терминальный receipt; дубля нет, счётчик попыток не меняется |
| устаревший worker завершает после захвата другим | — | `stale`, ни одной записи |

Тестовые константы: lease 60 с, бюджет 5 попыток, replay не более 3 раз
(каждый replay даёт новый бюджет), класс `transient` — недоступность хранилища
и нечитаемые preferences, `permanent` — `item_conflict`,
`template_unavailable`.

## 6. Подавление и минимальные receipts

Терминальные причины подавления:

| Причина | Когда |
|---|---|
| `user_preference` | категория выключена пользователем (§3) |
| `superseded` | уже создана запись более новой ревизии того же Booking |
| `expired` | `now > deliverUntilUtc` (в claim, в complete или сверкой) |
| `recipient_restricted` | аккаунт ограничен или `processingRestricted` |
| `recipient_not_found` | аккаунта получателя нет |
| `recipient_erasure` | причина отмены privacyErasure |

Любой терминальный исход, кроме `created`, сохраняется как **минимальный
receipt**: `receiptId`, `consumer`, `consumerVersion`, статус, причина,
`terminalAtUtc`, `expiresAt` и необязательная обезличенная evidence (ревизии
политики, шаблона, preferences). Без `recipientId`, `eventId`, `aggregateId`,
хэша payload, переменных и ссылок. Персональные поля живут в receipt только
пока эффект обрабатывается или пока существует созданная запись inbox.

## 7. Сверка (reconciliation)

Источник — `bookingOutbox`, порядок `createdAt`, затем ID документа. Две
позиции в `notificationReconcileCheckpoints/booking-outbox-v1`:

- **safe** — до этой позиции у каждой v2-записи есть receipt (любого
  статуса); никогда не перескакивает запись без receipt;
- **scan** — где продолжить следующий проход; идёт дальше safe, поэтому одна
  сбойная запись не останавливает обработку остальных; дойдя до конца, scan
  возвращается к safe.

Проход:

1. Скан от scan: v1 и прочие не-v2 записи пропускаются; для v2 без receipt —
   claim/complete (§5). Ошибка одной записи ловится, даёт finding
   `consume_failed`, проход продолжается.
2. Due-выборка receipts (`claimed` с истёкшим lease и `retry_scheduled` со
   сроком ≤ now): повтор по протоколу §5; эффекты с истёкшим окном, включая
   `dead_lettered`, получают терминальное `expired`.
3. Для `created` в просканированном диапазоне — проверка, что запись inbox
   существует (`inbox_item_missing`).

`complete = true`, только если нет findings (`receipt_missing`,
`consume_failed`, `dead_letter`, `inbox_item_missing`, `payload_conflict`), safe
дошёл до конца источника и нет due-receipts. Границы прохода: 100 записей на
страницу, не более 50 страниц, due-выборка 200.

Replay (`notifications replay <receiptId> --reason <text>`) — только для
`dead_lettered` в пределах окна; пишет запись аудита в receipt (не более 3) и
переводит в `retry_scheduled`. Replay отклоняется для `created`, `suppressed`,
`expired`, `erased`. Trigger, reconcile и replay работают в доверенном
backend-контексте (§13), без Session.

## 8. Retention (тестовые сроки)

| Запись | `expiresAt` (Firestore TTL) |
|---|---|
| Booking outbox v2 | `deliverUntilUtc + 30 суток` |
| запись inbox | `createdAt + 90 суток` |
| receipt `created` | как у его записи inbox |
| receipt любого другого терминального исхода, включая минимальные и tombstones | `max(terminalAt, deliverUntilUtc) + 30 суток` — не раньше конца жизни исходной outbox-записи |
| попытка | `startedAt + 30 суток` |
| receipt команды | `createdAt + 7 суток` |
| preferences | без TTL; удаляются при erasure |

Booking retention planner для класса `outbox` больше не ждёт только
`delivered`: якорь — **любой терминальный исход** Notifications (`created`,
`suppressed`, `expired`, `erased`) вместе с `reconciledAt`; кроме того, v2
получает `expiresAt` уже при создании, поэтому ни один исход не остаётся
навсегда. Если TTL удалит receipt раньше исходной записи, повтор сверки упрётся
в `expired` — запись inbox при этом не создаётся.

## 9. Privacy

Notifications — privacy-домен `notifications` (`access`, `erasure`,
`restriction`), который запускает `PrivacyDomainTaskRunner.runNotificationsTask`.

- **Не задерживает другие домены.** Restriction аккаунта при erasure
  выполняется первой и не зависит от Notifications; задачи Booking и других
  доменов идут независимо.
- **DSR не объявляется завершённым,** пока задача `notifications` не
  выполнена: существующая сверка privacy-запроса требует успеха всех
  обязательных доменов.
- **Erasure:** удаляет записи inbox, preferences, попытки и receipts команд
  субъекта; receipts субъекта превращаются в tombstone (§6, статус `erased`).
- **Restriction:** ставит `processingRestricted`; новые эффекты подавляются
  `recipient_restricted`.
- **Access:** возвращает счётчики записей.

Гонка erasure с уже работающим consumer — оба порядка безопасны, потому что
restriction фиксируется до начала удаления, а Tx1 и Tx2 читают статус аккаунта
внутри транзакции:

- claim до restriction, complete после → complete видит `erased` /
  restriction и не пишет запись;
- complete зафиксирован до удаления → удаление (начатое после restriction)
  находит и удаляет запись;
- claim после restriction → сразу минимальное подавление, персональные поля не
  пишутся.

Последующий replay или повторная доставка: receipt — tombstone `erased`, replay
отклоняется. Запись не появляется, даже если Booking erasure ещё не
псевдонимизировала outbox.

Анонимность tombstone проверена не только по `recipientId`: удаляются
`eventId`, `aggregateId`, `aggregateRevision`, хэш payload, pinned-шаблон с
переменными, `notificationId`, история попыток и replay. ID документа — хэш
только от `eventId`, без идентификатора человека. Срок хранения ограничен §8.

## 10. Неблокирование отмены брони, восстановления доступа и Privacy

Структурно:

- транзакции Booking не читают и не пишут коллекции Notifications;
- `recoverIdentitySessionsV1` не связан с Notifications;
- trigger работает с `retry: false`, ответ Booking не ждёт consumer.

Статический gate `verify-notifications-layout.mjs` запрещает Booking, Identity и
Privacy orchestration импортировать модуль Notifications (кроме композиции
runner) и запрещает SDK push, email и SMS.

Проверка реальными отказами Notifications:

| Отказ | Как воспроизводится |
|---|---|
| запись inbox | хранилище Notifications отвечает UNAVAILABLE на запись inbox (декоратор над Firestore-адаптером) |
| запись inbox | ID записи занят чужим документом — постоянный отказ `item_conflict` |
| чтение preferences | хранилище отвечает UNAVAILABLE |
| чтение preferences | в Firestore лежит нечитаемый документ preferences |
| Notifications выключен | consumer-флаг выключен |
| privacy-задача Notifications | хранилище отвечает UNAVAILABLE |

При каждом отказе отмена брони, `recoverIdentitySessions` и независимые
privacy-задачи (restriction аккаунта, задача Booking) завершаются. После
восстановления — ровно одна логическая запись либо обоснованное подавление или
истечение срока. Privacy-запрос остаётся незавершённым до успеха задачи
`notifications`.

## 11. Шаблоны

Реестр в коде; ревизия неизменяема и закреплена sha256: изменение текста
ревизии 1 валит тест, нужна новая ревизия. Ключи — по §3; ревизия 1 содержит
локали `lv-LV`, `en`, `ru` — **фикстурные тексты, не утверждённая копия**
(BCK13-OD-05 открыт), без fallback между локалями. Переменная только у
`booking.reconfirmationRequired` — `deadline` (UTC instant, форматируется в
`Europe/Riga` средствами локали).

Запись inbox хранит ключ, pinned ревизию и типизированные переменные. Текст
рендерится при запросе в локали из запроса; если у ревизии нет этой локали —
`content: null`, `contentStatus: 'unsupported_locale'`. Локаль вне продуктовых
локалей LV → отказ `unsupported_locale`.

## 12. Клиентский API

Оба callable требуют действующую Session (та же авторизация, что у Booking) и
свой флаг. Конверт:

```text
notificationsQueryV1:   { schemaVersion: 1, requestId, queryType, payload }
  listInbox      { locale, view: active|archived, pageSize ≤ 50, cursor? }
  unreadSummary  {}
  getPreferences {}
notificationsCommandV1: { schemaVersion: 1, requestId, idempotencyKey, commandType, payload }
  markRead           { notificationId }
  markAllRead        { cutoffUtc, maxItems ≤ 100 }
  archive            { notificationId, expectedRevision }
  updatePreferences  { expectedRevision, categories }
```

Результат: `{ schemaVersion: 1, requestId, queryType|commandType, kind:
'succeeded' | 'rejected' | 'unsupported', code?, ... }`.

- Сортировка: `createdAtUtc` убыв., затем `notificationId`. Курсор непрозрачен
  и привязан к получателю и view.
- Чужая запись → `notification_not_found` (без перечисления).
- Повтор команды с тем же ключом — прежний результат; тот же ключ с другим
  содержимым → `idempotency_conflict`.
- `markAllRead` помечает не более `maxItems` записей не новее `cutoffUtc` и
  возвращает `remaining`.

JSON Schema и фикстуры — `packages/api_contracts/schema/notifications/v1/`.
Это локальный контракт стенда; **BCK13-OD-01 целиком не закрыт** (codegen,
совместимость и workflow остаются решением владельцев).

## 13. Trigger и доверенный контекст

`consumeNotificationEffectV1 = onDocumentCreated('bookingOutbox/{outboxId}')`,
`retry: false`, без Session. Проверки:

- окружение: `FUNCTIONS_EMULATOR`, `GCLOUD_PROJECT = demo-recharge`,
  `FIRESTORE_EMULATOR_HOST`;
- источник: путь `bookingOutbox/{id}`, ID документа = `eventId`,
  `producer = 'booking'`, `schemaVersion = 2`;
- флаг `notifications.consume.booking`.

Reconcile и replay запускаются только командами стенда с той же проверкой
окружения. Scheduler не экспортируется.

## 14. Мобильный клиент

Вход `RECHARGE_TEST_NOTIFICATIONS_INBOX` с 4-условным guard (define,
non-release, binding testBackend, loopback `demo-recharge`), capability
`notifications.inbox` в binding manifest.

- Включён: страница уведомлений читает серверный inbox (список, отметка
  прочтения) через `notificationsQueryV1` / `notificationsCommandV1` и
  allowlist callable-адаптера; навигация через `subjectRef(event)` в
  существующие Details, которые перепроверяют видимость.
- Выключен: локальный inbox и `AppNotificationSink` работают как раньше.
- UI preferences в F1 нет.

## 15. Не входит в F1

FCM/APNs, email, SMS, регистрация устройств и токенов, фейковый push, quiet
hours, локаль в preferences, correction/withdraw, `removeFromInbox`, миграция
локального inbox (серверный стартует пустым), продюсеры Identity, Content и
moderation, scheduler, cloud, активация v1-записей.

## 16. Закрытая карта файлов

### 16.1 Документы

```text
docs/product/NOTIFICATIONS_F1_INBOX_AMENDMENT.md        (этот файл)
docs/product/NOTIFICATIONS_BACKEND_SPEC.md              (приложение F1)
docs/product/EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md (приложение: outbox v2, retention)
docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md           (строка F1)
docs/product/C1_E2_CLOSURE_REVIEW.md                    (F1 hide fence → BOOKING-HIDE-FENCE-01)
docs/architecture/LAUNCH_STATUS.md                      (строка F1; hide fence → BOOKING-HIDE-FENCE-01)
apps/backend/README.md                                  (раздел F1)
```

### 16.2 Контракты

```text
packages/api_contracts/schema/notifications/v1/notifications_query.schema.json
packages/api_contracts/schema/notifications/v1/notifications_command.schema.json
packages/api_contracts/schema/notifications/v1/notifications_result.schema.json
packages/api_contracts/schema/notifications/v1/notification_effect.schema.json
packages/api_contracts/schema/notifications/v1/fixtures/query_valid.json
packages/api_contracts/schema/notifications/v1/fixtures/query_invalid.json
packages/api_contracts/schema/notifications/v1/fixtures/command_valid.json
packages/api_contracts/schema/notifications/v1/fixtures/command_invalid.json
packages/api_contracts/schema/notifications/v1/fixtures/result_valid.json
packages/api_contracts/schema/notifications/v1/fixtures/effect_valid.json
packages/api_contracts/schema/notifications/v1/fixtures/effect_invalid.json
packages/api_contracts/lib/src/dto/response/notification_inbox_dto.dart
packages/api_contracts/lib/api_contracts.dart            (export)
packages/api_contracts/test/notification_inbox_dto_test.dart
```

### 16.3 Backend: новый модуль и вход

```text
apps/backend/functions/src/modules/notifications/domain/notification_effect.ts
apps/backend/functions/src/modules/notifications/domain/inbox_item.ts
apps/backend/functions/src/modules/notifications/domain/notification_templates.ts
apps/backend/functions/src/modules/notifications/domain/notification_policy.ts
apps/backend/functions/src/modules/notifications/domain/delivery_attempt.ts
apps/backend/functions/src/modules/notifications/domain/repositories.ts
apps/backend/functions/src/modules/notifications/application/consume_notification_effect.ts
apps/backend/functions/src/modules/notifications/application/notification_reconciler.ts
apps/backend/functions/src/modules/notifications/application/notifications_query_handler.ts
apps/backend/functions/src/modules/notifications/application/notifications_command_handler.ts
apps/backend/functions/src/modules/notifications/application/notifications_privacy_task_handler.ts
apps/backend/functions/src/modules/notifications/infrastructure/firestore_notifications_repository.ts
apps/backend/functions/src/modules/notifications/infrastructure/firestore_notification_sources.ts
apps/backend/functions/src/modules/notifications/infrastructure/in_memory_notifications_repository.ts
apps/backend/functions/src/notifications_entry.ts
```

`notification_policy.ts` — категории, локальная политика и preferences (в плане
назывался `notification_preferences.ts`; переименован, потому что содержит
политику).

### 16.4 Backend: изменяемые существующие файлы

```text
apps/backend/functions/src/index.ts                          (+3 export)
apps/backend/functions/src/notifications/outbox.ts           (тип v2; v1 без изменений)
apps/backend/functions/src/booking/notification_effects.ts   (новый: флаг и построение v2)
apps/backend/functions/src/booking/create_internal_booking.ts
apps/backend/functions/src/booking/cancel_internal_booking.ts
apps/backend/functions/src/booking/reconfirm_internal_booking.ts
apps/backend/functions/src/booking/occurrence_lifecycle.ts
apps/backend/functions/src/booking/reconfirmation_deadline_worker.ts
apps/backend/functions/src/booking/privacy.ts                (v2 в union)
apps/backend/functions/src/booking/retention.ts              (якорь — любой терминальный исход; expiresAt v2)
apps/backend/functions/src/shared/feature_flags.ts
apps/backend/functions/src/modules/privacy_orchestration/application/privacy_domain_task_runner.ts
apps/backend/firestore.rules                                 (6 явных deny)
apps/backend/firestore.indexes.json                          (индексы и TTL)
apps/backend/config/manifests/execution-manifest.json        (6 коллекций, флаг Booking)
```

Коллекции: `notificationInboxItems`, `notificationEffectReceipts`,
`notificationDeliveryAttempts`, `notificationPreferences`,
`notificationCommandReceipts`, `notificationReconcileCheckpoints`.

### 16.5 Скрипты и стенд

```text
apps/backend/scripts/verify-r1-exports.mjs          (+3 export; trigger allowlist)
apps/backend/scripts/verify-notifications-layout.mjs (новый)
apps/backend/scripts/run-emulator-tests.mjs
apps/backend/scripts/stand-seed.mjs                 (команды notifications)
apps/backend/scripts/stand-f1-gate.mjs              (новый)
apps/backend/functions/package.json
apps/backend/functions/test/stand/stand_notifications.ts (новый)
apps/backend/functions/test/stand/stand_flags.ts
apps/backend/functions/test/stand/stand_main.ts
```

### 16.6 Тесты backend

Новые:

```text
test/unit/notifications/notification_effect.test.ts
test/unit/notifications/inbox_item.test.ts
test/unit/notifications/notification_templates.test.ts
test/unit/notifications/notification_policy.test.ts
test/unit/notifications/delivery_attempt.test.ts
test/unit/notifications/consume_notification_effect.test.ts
test/unit/notifications/notification_reconciler.test.ts
test/unit/notifications/notifications_query_handler.test.ts
test/unit/notifications/notifications_command_handler.test.ts
test/unit/notifications/notifications_privacy.test.ts
test/unit/booking_notification_effects.test.ts
test/contract/notifications_fixture_parity.test.ts
test/emulator/booking_notification_effects.test.ts
test/emulator/notifications_inbox_emulator_flow.test.ts
test/emulator/notifications_unavailability.test.ts
test/emulator/notifications_privacy_emulator.test.ts
test/emulator/notifications_rules_default_deny.test.ts
test/support/notifications_world.ts
```

Изменяемые существующие Booking- и rules-тесты, поимённо:

- `test/unit/booking_retention.test.ts` — новые случаи: якорь outbox по
  терминальным исходам `suppressed` / `expired` / `erased`, `expiresAt` v2.
  Существующие случаи не меняются.

Не изменяются (v1 при выключенном флаге остаётся байт-в-байт, их утверждения
по-прежнему верны): `booking_create`, `booking_cancel`, `booking_reconfirm`,
`booking_reconfirmation_deadline_worker`, `booking_full_integration_flow`,
`booking_contention`, `test/unit/booking_outbox.test.ts`,
`test/unit/booking_privacy*.test.ts`, все `test/rules/*` и
`test/emulator/rules_default_deny.test.ts`,
`test/emulator/content_rules_default_deny.test.ts`. Deny новых коллекций
проверяется новым `notifications_rules_default_deny.test.ts`; сверку
Rules/индексов/manifest — существующий `verify-execution-manifest` без правок.

### 16.7 Mobile

```text
apps/mobile/lib/features/notifications/data/remote/notifications_inbox_port.dart        (новый)
apps/mobile/lib/features/notifications/data/remote/server_notifications_repository.dart (новый)
apps/mobile/lib/app/di/notifications_inbox_composition.dart                            (новый)
apps/mobile/lib/app/di/service_locator.dart
apps/mobile/lib/features/booking/data/booking_callable_adapter.dart                    (allowlist +2)
apps/mobile/test/unit/server_notifications_repository_test.dart                         (новый)
apps/mobile/test/unit/notifications_inbox_composition_test.dart                         (новый)
apps/mobile/test/backend_local/notifications_inbox_client_test.dart                     (новый)
```

Отклонения, обнаруженные при реализации, дописываются в этот раздел с пометкой
«добавлено при реализации».

### 16.8 Добавлено при реализации

- Booking-флаг вынесен в отдельный реестр `bookingNotificationFlagIds`, а не в
  `bookingFlagIds`: тестовый хелпер `setBookingFlags(true)` включает все
  `bookingFlagIds`, и существующие Booking-тесты иначе получили бы v2. Поэтому
  execution manifest получает только шесть коллекций, индексы и TTL; его
  список флагов (реестр `bookingFlagIds` + `identityFlagIds`) не меняется.
- `apps/mobile/test/backend_local/support/stand_backend.dart` — метод
  `notifications(...)` для операторских шагов стенда в клиентском тесте.
- Причина dead letter `policy_unavailable` (pinned ревизия политики
  отсутствует) и finding сверки `source_missing` (исходная outbox-запись
  исчезла раньше receipt).
- Booking retention planner использует существующее поле кандидата
  `terminalAtUtc` как якорь любого терминального исхода Notifications для
  класса `outbox`; `deliveredAtUtc` по-прежнему принимается.
- Коды транзиентных отказов попыток: `store_unavailable`, `store_deadline`,
  `store_aborted`, `preferences_unreadable`, `unexpected`.
- `stand_main.ts` загружает `stand_notifications.ts` лениво, только для команды
  `notifications`: остальные команды стенда не получают F1-зависимостей при
  запуске (см. риск B2 в §18).

## 17. Порядок и gate'ы

1. **F1a** — домен, Booking v2, consumer, сверка, privacy, Emulator-тесты.
2. **F1b** — callables, схемы, фикстуры, контрактные тесты.
3. **F1c** — мобильный вход, `stand-f1-gate`.

Done:

- полный регресс: `tsc`, `eslint`, `prettier`, unit, contract, все `verify-*`,
  три contract-gate, `test:emulator`;
- gates F1, E2, E2a, E1, C3, C2, C1, B2, B1 и acceptance (B-gates — с
  выключенным Booking-флагом);
- `api_contracts`, `flutter analyze`, `flutter test`;
- границы фич 71/71 без роста, `git diff --check`.

## 18. Риски

- Пять транзакционных путей Booking получают чтение флага до транзакции;
  contention-тесты Booking обязательны.
- Нет scheduler: retry и сверка в F1 запускаются командами стенда; production
  потребует отдельного export и решения.
- Тексты шаблонов — фикстуры, особенно `lv-LV`.
- Unread count — агрегат `count()` с честным временем вычисления, не
  проекция.
- Попытки и receipts команд хранятся по тестовым срокам; production retention
  — BCK13-OD-06/10.
- Обнаружено при регрессе: B2-gate чувствителен к таймингу. Команда стенда
  `bookings` (`expectActive`) длится 4,7–4,9 с, а Node держит idle keep-alive
  соединение 5 с; запрос отмены сразу после неё изредка уходит в закрываемый
  сервером сокет, и клиент честно показывает «результат не подтверждён». Риск
  существовал до F1; после ленивой загрузки модуля F1 B2 прошёл 3/3. Надёжное
  исправление (свежее соединение в тестовом клиенте B2 или ускорение команды
  стенда) — отдельное решение вне F1.
