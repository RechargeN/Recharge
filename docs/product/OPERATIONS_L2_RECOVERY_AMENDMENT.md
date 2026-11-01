# L2 — operational recovery: dead-letter, replay, reconciliation, emergency disable, restore

- ID: **OPS-L2**
- Версия: **0.2 (реализация в local/Emulator объёме)**
- Дата: **2026-10-25**
- Статус: **Review — локальная реализация §9; production operations не реализованы**
- База: `claude/l1-dsr-retention` @ `c880f08` (поверх `codex/recharge-integration`
  @ `bcebd60`), ветка `claude/l2-operational-recovery`
- Расширяет: [BCK-03](BACKEND_API_CONTRACT_STANDARD.md) §21.3 и §27 (OD-09),
  [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md) §13, §16, §23,
  [BCK05-OD05-REC-01](BACKEND_BACKUP_RECOVERY_MODEL.md) (Proposed),
  [L1](PRIVACY_L1_DSR_RETENTION_HOLD_AMENDMENT.md), [K3](K3_ADMIN_SUPPORT_READINESS.md)
- Runtime-эффект: только local/Emulator. Cloud, deployment, backup, реальные
  данные не затронуты.

Документ описывает то, что есть в коде на базе, и правила, по которым L2
дополняет существующие механизмы. Второго runner, общей очереди и
универсального механизма прямого ремонта БД L2 не создаёт.

## 1. Принятые контракты, на которые опирается L2

| Источник | Что принято | Чего нет |
|---|---|---|
| BCK-03 §21.3, §27 (OD-09 Accepted technical) | at-least-once, dedupe по `eventId` + consumer, bounded retry, poison quarantine с аудитом, replay bounded и audited, worker effects lease/checkpoint protected | транспорт, числовой replay window, alerting |
| BCK-05 §13 | timeout после вызова провайдера = `unknown_outcome` до сверки; bounded exponential backoff + jitter + hard limit; partial ≠ success | — |
| BCK-05 v0.2.41 | Event delivery: durable cursor, fenced renewable leases, retry/dead-letter, audited idempotent manual replay; dead letter без TTL, delivered 90 дней, operator decisions 180 дней | production worker, scheduler |
| BCK-05 §23, BCK-04 §25, ADR 0019 | flag блокирует новую работу, не удаляет Booking, holds, audit, history; emergency disable не стирает evidence и не закрывает safe exits; отключение — аудируемое privileged action | production operator identity |
| BCK05-OD05-REC-01 (Proposed) | restore только в изолированную новую БД; privacy re-deletion до открытия; projections пересобираются из authority; repair — owner-командами | backup/PITR runtime, drill, cutover, Accepted |
| L1 | DSR runner с lease, blocked, checkpoint; tombstones и fences; PB-15 backup propagation open | независимый deletion ledger вне основной БД |
| K3 | ремонт исходных данных — immutable proposal → approval другого principal → execution owner-командами с receipts; `unknown` шага восстанавливается по owner receipt | production staff policy |

## 2. Registry task families (по коду)

Колонки: owner → producer → consumer → effect → receipt (authoritative
доказательство эффекта) → retry/recovery. Код — `src/platform/operations/
operational_task_registry.ts`; coverage-тест сверяет его с триггерами
`index.ts` и файлами с признаками очереди (lease, dead-letter, attempt budget,
stop-on-poison checkpoint).

| ID | Owner | Producer | Consumer | Effect | Receipt | Retry / recovery |
|---|---|---|---|---|---|---|
| TF-01 Event → Booking projection | Booking | Content handoff → `eventBookingOutbox` (immutable) | trigger `consumeEventBookingOutboxV1`, schedule `retryEventBookingProjectionDeliveriesV1` | `bookingEventProjections` + lifecycle отмены броней страницами | документ проекции: `materialRevision`, `publicationRevision`, `sourceEventDigest`; delivery `delivered` | lease 2 мин (token + generation), 5 попыток, backoff 1/5/15/60 мин, dead-letter, operator replay, discovery cursor |
| TF-02 Reconfirmation deadline | Booking | discovery по `bookings` (cursor) | schedule `releaseMissedReconfirmationsV1` | auto-cancel брони (key, usage, ledger, audit, outbox) в одной транзакции | booking revision/state; job `delivered` + `outcome` | lease 2 мин, 5 попыток, backoff 1/5/15/60 мин, dead-letter, operator replay |
| TF-03 Booking notification obligation | Notifications (consumer), Booking (producer) | `bookingOutbox` | trigger `consumeNotificationEffectV1`, `NotificationReconciler` | inbox item | `notificationEffectReceipts` (`created` / minimal) + attempt records | lease 60 с, 5 попыток, backoff 30 с·2ⁿ, dead-letter, replay ≤ 3 (F1), reconciler safe/scan checkpoint |
| TF-04 Content → Catalog | Catalog | `contentEffects` | trigger `consumeContentEffectV1` (consumer `catalog`) | версии в projection set | `catalogFactReceipts` + checkpoint set | checkpoint resume; `refused` останавливает feed; `conflict` — finding и пропуск; catalog reconciler / rebuild set |
| TF-05 Content → Booking handoff | Content | `contentEffects` | trigger `consumeContentEffectV1` (consumer `bookingHandoff`) | `eventBookingOutbox` fact | `eventBookingHandoffReceipts`, states, checkpoint | checkpoint, gap fill из истории, reconcile (`outbox_missing`, `projection_behind/ahead`, `delivery_dead_letter`), `repairContent` |
| TF-06 Content ↔ Media availability | Content | `contentEffects`, `mediaEffects` | triggers `consumeContentEffectV1` (`mediaVerification`), `consumeMediaEffectV1`; schedule R1 | подавление media в publication pointer | `contentMediaAvailabilityReceipts` + status checkpoint | checkpoint resume; stop на `receipt_conflict` / `media_unavailable`; sweep R1 |
| TF-07 Media orphan sweep R2 | Media | schedule `reconcileMediaReferencesV1` | orphan sweep | abandon attempt / удаление orphan | processing receipts, deletion status | без retention policy — `policy_unavailable`, эффектов нет (PB-14) |
| TF-08 Media deletion | Media | owner `deleteAsset`, DSR | `MediaDeletionService` | удаление Storage source/variants | `mediaDeletionStatuses` (`pending` → `completed`) | resumable `pending`; сбой удаления байтов оставляет `pending` |
| TF-09 Media processing attempt | Media | finalize upload | scan/process (local tools) | variants, lifecycle | `mediaProcessingReceipts` (immutable на попытку) | бюджет `maxProcessingAttempts` (3), `retryFromQuarantine`, orphan reconciler `abandon_attempt` |
| TF-10 DSR domain task | Privacy orchestration | intake | `PrivacyDomainTaskRunner` | owner handlers | outcome задачи + sweep checkpoint + финальная сверка | L1: lease + fencing, 5 попыток, `blocked` |
| TF-11 Find People exact-location purge | Content | schedule `purgeFindPeoplePrivateLocationsV1` | purge | редакция точной локации | ревизия черновика + audit без значений | идемпотентный повторный проход |
| TF-12 Booking retention TTL | Booking | `expiresAt` | provider TTL | физическое удаление | — | локального исполнителя нет (OB-05) |
| TF-13 K3 repair execution | Admin/Support | approved proposal | `AdminSupportService.execute` | Moderation decide → Content disposition | owner receipt на шаг | `unknown` → восстановление receipt; resumable |
| TF-14 Content local import (D4) | Content | client import session | import lifecycle | drafts | binding + lease | lease binding, rollback D4.1 |
| TF-15 Content translation (ADR 0022) | content_translation | запрос читателя; изменение pointer или T&S hold | вызов провайдера, очистка кэша | запись кэша или её удаление | запись кэша + строка ledger под lease token | lease fencing, идемпотентный sweep; incident switch `contentTranslation.onDemand.incidentDisable` |

## 3. Контракт каждой семьи

### 3.1 Состояния и переходы

| ID | Состояния | Переходы |
|---|---|---|
| TF-01 | `pending`, `processing`, `retryPending`, `delivered`, `deadLetter` | pending/retryPending/processing(lease истёк) → processing → delivered / retryPending / deadLetter; deadLetter → retryPending только operator replay |
| TF-02 | те же | то же; `delivered` несёт `outcome` `autoCancelled` / `superseded` |
| TF-03 | `claimed`, `retry_scheduled`, `dead_lettered`, `created`, `suppressed`, `expired`, `erased` | claimed → created / suppressed / expired / retry_scheduled / dead_lettered; dead_lettered → retry_scheduled только replay |
| TF-04…06 | checkpoint + receipt на факт | факт после checkpoint → receipt и checkpoint в одной транзакции; `refused` — остановка до факта |
| TF-10 | `pending`, `dispatched`, `blocked`, `succeeded`, `failed`, `cancelled` | по L1 |
| TF-13 | шаг `pending`, `unknown`, `completed`, `refused` | по K3 |

`unknown` в TF-01/02 выводится, а не хранится отдельно: `processing` с
истёкшим lease — попытка началась, результат не записан. Inspect показывает
такое состояние как `unknown`.

### 3.2 Semantic idempotency key и authoritative receipt

| ID | Ключ | Receipt | Изменённый payload |
|---|---|---|---|
| TF-01 | `outboxId` (детерминирован Content из effectId + fact) | проекция: revisions + `sourceEventDigest` | delivery хранит `eventDigest` источника при создании; replay сверяет его с текущим источником → `payload_changed` |
| TF-02 | `jobId` = hash(bookingId, materialRevision) | booking: `state`, `reconfirmationRequiredForRevision`, `reconfirmationDeadlineUtc` | другой deadline/revision → `superseded` без эффекта |
| TF-03 | `receiptId` = hash(eventId) | receipt + inbox item `notificationId` | `payloadSha256` ≠ → `payload_conflict` |
| TF-04…06 | `effectId` | receipt факта | факт immutable; конфликт → finding |
| TF-10 | `taskId` = hash(request, domain, market, targetRevision) | outcome + финальная сверка | L1 `idempotency_conflict` |
| TF-13 | `k3-{proposal}-{i}` | owner receipt | новая revision proposal требует нового approval |

### 3.3 Классы исходов

- **Permanent rejection** — повтор не изменит результат: TF-01 consumer
  `rejected` (`invalid_event`, `missing_occurrence`, `revision_conflict`),
  `invalid_source_record`; TF-02 `booking_inventory_inconsistent` и
  невалидная задача; TF-03 `invalid_effect`, `unsupported_effect`,
  `item_conflict`, `template_unavailable`, `policy_unavailable`. Сразу в
  dead-letter с классом `permanent`. Replay такой записи отказывает
  (`permanent_rejection`): исправление — K3 proposal на исходные данные, после
  которого источник порождает новый факт под новым ключом.
- **Transient failure** — ошибка хранилища до эффекта: ретрай по бюджету;
  после исчерпания — dead-letter `transient`, replay разрешён.
- **Unknown outcome** — исключение во время или после owner-транзакции, потеря
  lease, падение worker: класс `unknown`. Следующая попытка сначала читает
  owner receipt (TF-01: `ignoredDuplicate`; TF-02: изменённая бронь →
  `superseded`; TF-03: терминальный receipt) и не создаёт второй эффект.
  Отсутствие ответа не считается ни успехом, ни сбоем.

### 3.4 Retry budget и backoff

Числа — из принятых local contracts, L2 их не меняет: TF-01/02 — 5 попыток,
1/5/15/60 мин (BCK-05 v0.2.41); TF-03 — 5 попыток, 30 с·2ⁿ⁻¹, replay ≤ 3
(F1 §5); TF-09 — 3; TF-10 — 5 (L1). Jitter отсутствует во всех семьях —
отклонение от BCK-05 §13, фиксируется (OB-09), не изобретается.

L2 меняет учёт бюджета TF-01/02: `attempts` больше не обнуляется при replay;
replay выдаёт новый бюджет `attemptBudget = attempts + 5`. Отказ из-за
выключенного switch попыткой не считается.

### 3.5 Lease и fencing

TF-01/02: lease = (`leaseToken`, `leaseGeneration`, `leaseUntilUtc`);
checkpoint и финальная запись проверяют token + generation в транзакции;
потерявший lease получает `lease_lost` и ничего не пишет. Эффект TF-01
защищён owner-идемпотентностью проекции (digest + revisions), эффект TF-02 —
проверкой ревизии брони внутри той же транзакции, что и lease. TF-03:
`leaseId` в Tx2/Tx3. TF-10: L1. При потере worker запись остаётся
`processing`/`claimed` до истечения lease, затем следующий worker
перехватывает её и сверяется с receipt.

### 3.6 Кто может inspect / replay / reconcile / disable

Production-authority операций нет (OB-01). Локально — серверный тестовый
реестр `operationsOperatorAuthority` (источник
`test-only-emulator-stand-bootstrap`, как у moderation/hold authority):
`userId`, срок действия, список `{familyId, marketId: 'LV', actions}`.
Действия: `ops.inspect`, `ops.replay`, `ops.reconcile`, `ops.disable`,
`ops.enable`. Каждая проверка в транзакции перечитывает текущие Session
(`assertCurrentSession`: истечение, отзыв, статус аккаунта) и запись реестра;
клиентских claims нет, callable нет. Каждое разрешённое и запрещённое
действие пишет запись `operationsOperatorAudit` в той же транзакции; если
audit недоступен, действие не выполняется (fail-closed). Ремонт исходных
данных — только K3.

### 3.7 Что означает restore

| ID | Restore в существующей системе |
|---|---|
| TF-01 | deliveries пересоздаются discovery из immutable `eventBookingOutbox`; проекции — owner consumer из того же outbox (`rebuildBookingEventProjections`); дубликат игнорируется по digest |
| TF-02 | jobs пересоздаются discovery из `bookings`; эффект проверяет актуальную бронь |
| TF-03 | receipts — из `bookingOutbox` reconciler'ом; получатель erased/restricted → `suppressed`; восстановленный старый `created` receipt с `recipientId` — данные субъекта, подлежат re-deletion |
| TF-04…06 | rebuild из Content facts в новый set (Catalog) / повтор feed с checkpoint |
| TF-10 | задачи и fences — данные основной БД; переживают restore только если независимый ledger есть (нет, OB-04) |
| остальные | только owner-команды; backup отсутствует |

## 4. Правила L2 (реализуются в коде)

1. Dead-letter остаётся записью исходной задачи (тот же ID), а не копией:
   хранит `failureClass`, код, счётчик попыток и `failureHistory`
   (ограниченный список `{attempt, class, code, atUtc}`). Payload, тексты
   ошибок, секреты и персональные данные не копируются.
2. Replay — только `ops.replay` в scope семьи; в одной транзакции: audit,
   проверка класса (permanent → отказ), digest источника (TF-01), switch
   семьи (выключен → отказ `family_disabled`), запись replay в историю.
   Исходная ошибка и попытки сохраняются; replay не затирает их.
3. Ключ решения оператора `decisionId` идемпотентен: повтор того же решения
   возвращает прежний результат и не порождает второй requeue.
4. Replay не проверяет источник сам: актуальные revision, authority,
   restriction, DSR barrier и tombstone проверяет owner effect при
   выполнении (TF-01 stale/duplicate, TF-02 superseded, TF-03 recipient
   status). Replay записи субъекта, чей аккаунт restricted/erased, создаёт
   только `suppressed`/`superseded`, не эффект.
5. Switch семьи читается при dispatch (захват lease / claim) и перед эффектом
   (в транзакции эффекта для TF-01/02; непосредственно перед Tx2 для TF-03).
   Выключенный switch: задача остаётся в очереди, попытка не списывается.
6. Disable/enable — аудируемая команда `ops.disable`/`ops.enable`: новая
   immutable flag revision + CAS указателя в одной транзакции с audit. Очередь,
   receipts и audit не удаляются. Re-enable проверяет текущие полномочия.
7. Reconciliation TF-01 — bounded, paged по `(createdAt, id)` с собственным
   checkpoint; delivered без owner receipt (проекция ниже revision события) →
   finding `receipt_missing` и повторная доставка через owner; `processing`
   с истёкшим lease → `unknown`, повторная доставка; dead-letter → finding.
   Повторная сверка сходится: дубликаты игнорируются по digest.
8. Restore admission (§6) — проверка изолированной копии против deletion
   authority до открытия.

## 5. Emergency disable: scope и пределы

| ID | Switch (существующий flag) | Scope | Проверка | In-flight |
|---|---|---|---|---|
| TF-01 | `booking.eventProjection.delivery` | consumer семьи, env `local`, market LV | захват lease; транзакция проекции; между страницами lifecycle | одна уже начатая страница lifecycle (≤ 200 броней) завершается; результат сверяется reconciliation |
| TF-02 | `booking.reconfirmation.deadlineWorker` | consumer | захват lease; транзакция отмены | нет: проверка в транзакции эффекта |
| TF-03 | `notifications.consume.booking` (consumer), `booking.notification.effects` (producer) | consumer / producer | claim (Tx1) и перед Tx2 | Tx2, начатая до disable, может завершиться (окно между чтением и commit) |
| TF-04 | `catalog.delivery` | consumer | старт run | текущий bounded run завершается |
| TF-05 | `content.event.bookingHandoff` | consumer | старт run | то же |
| TF-06 | `content.mediaAvailability` | consumer | старт run | то же |
| TF-07 | `media.reconcile` | consumer | старт sweep | то же |
| TF-08, TF-10, TF-11 | нет — privacy-удаление по контракту не за flag | — | — | safe exit, не отключается |
| TF-13 | `moderation.staff` + статус case | consumer | каждый шаг | по K3 |

Подтверждённые эффекты не откатываются. Market-level switch шире семьи и
effect-level switch внутри семьи в принятых контрактах не определены.
Недоступный switch (ошибка чтения) — отказ (fail-closed), задача остаётся.

## 6. Restore

Принятого backup/restore runtime нет (BCK05-OD-05 Proposed): L2 не создаёт
backup, PITR или export. Независимого deletion ledger, который переживает
восстановление основной БД, тоже нет (PB-15, OB-04).

Локально реализуется только **restore admission gate** —
`src/platform/operations/restore_admission.ts`:

1. Копия изолирована: отдельная именованная БД Firestore (BCK05-REC-AC-23),
   функции её не слушают; запись в основную БД gate не делает.
2. Deletion authority — порт, который отдаёт снимок erasure/restriction
   решений и момент `asOfUtc`. Недоступность, ошибка или `asOfUtc` раньше
   момента начала restore → `closed: deletion_authority_unavailable`.
3. Для каждого субъекта authority gate считает остаток в копии по L1 writer
   registry (`subjectField`). Остаток → `closed: redeletion_required`;
   re-deletion выполняется тем же DSR runner, связанным с копией, под
   детерминированным ключом от исходного запроса.
4. Открытие (`admitted`) — только при нулевом остатке по всем субъектам
   authority, кроме записей, которые L1 оставляет `blocked`; при таких
   записях — `incomplete`. Решение и счётчики пишутся в operator audit без
   идентификаторов субъектов.

Проверка gate на синтетическом снимке — не восстановление production backup.

## 7. Blockers

| ID | Blocker | Чья policy | Что делается без неё |
|---|---|---|---|
| OB-01 | Production operator identity, MFA/JIT, two-person для ops-действий | BCK-05/BCK-19 | Тестовый серверный реестр authority |
| OB-02 | Число replay и replay window для TF-01/02 | BCK-05 + Booking owner | Без лимита не изобретается; только аудируемый operator replay, permanent — отказ |
| OB-03 | Poison policy feed-consumers TF-04/06 (`fact_invalid`, `set_not_writable`, `receipt_conflict` останавливают feed) | Catalog E1, Content D2 | Поведение не меняется; остановка видима в отчёте и логе |
| OB-04 | Backup/PITR runtime и deletion ledger вне основной БД | BCK05-OD-05, BCK04-OD-07, PB-15 | Restore — incomplete; только gate на синтетическом снимке |
| OB-05 | Локальный исполнитель TTL Booking и контроль 72 ч | BCK09-RETENTION-DEC-01 + BCK-05 | Нет сверки физического удаления |
| OB-06 | Cutover/reopen после restore, two-person | BCK05-OD-05 §11, §18 | Gate выдаёт решение, cutover не существует |
| OB-07 | Alerting по poison/dead-letter | BCK-05 §20 | Только structured log и findings |
| OB-08 | Атомарная проверка switch в Tx2 Notifications | F1 owner | Чтение перед Tx2; окно описано |
| OB-09 | Jitter в backoff | BCK-05 §13 | Детерминированный backoff остаётся |

## 8. Проверки → тесты

| № | Проверка | Тест |
|---|---|---|
| 1 | Нет capability, чужой scope, истёкшая/отозванная Session, отозванные права, audit недоступен | `L2-T-AUTH` |
| 2 | permanent / transient / unknown в правильных состояниях | `L2-T-CLASS` |
| 3 | Потерянный ответ после owner effect: replay находит receipt | `L2-T-LOST` |
| 4 | Сбой до effect, после effect до checkpoint, при записи dead-letter | `L2-T-CRASH` |
| 5 | Два workers, истечение lease, stale worker | `L2-T-LEASE` |
| 6 | Изменённый payload, stale revision, отозванная authority | `L2-T-REPLAY` |
| 7 | Partial cross-domain, повтор reconciliation, pagination | `L2-T-RECON` |
| 8 | Disable до dispatch, между dispatch и effect, in-flight; re-enable | `L2-T-DISABLE` |
| 9 | Удаление/анонимизация перед replay и rebuild | `L2-T-RESURRECT` |
| 10 | Restore старого снимка с более новыми tombstones; authority недоступна | `L2-T-RESTORE` |
| 11 | Исходная ошибка, operator audit, нет чувствительных данных | `L2-T-LEAK` |
| 12 | Registry coverage + положительный контроль | `L2-T-REG` (unit) |

## 9. Реализация (local/Emulator)

Второго runner и общей очереди нет: console вызывает только порты владельцев.

| Механизм | Где | Что делает |
|---|---|---|
| Registry | `modules/operations/operational_task_registry.ts` | 14 семей; coverage-тест сверяет с триггерами `index.ts` и файлами с признаками очереди; положительный контроль на фикстуре |
| Console | `modules/operations/operations_console.ts`, `operations_entry.ts` | inspect / replay / reconcile / disable / enable / restore admission; Session + реестр `operationsOperatorAuthority`; audit в той же транзакции; fail-closed |
| Emergency switch | `modules/operations/emergency_switch.ts`, `*.incidentDisable` в `feature_flags.ts` и manifest | нет pointer → открыт; битый pointer, ошибка чтения, не-Emulator → contained |
| TF-01 | `booking/event_projection_delivery.ts`, `event_projection_consumer.ts` | классы исходов, `firstFailure` + история, бюджет `attempts + 5` при replay, switch при захвате lease, в транзакции проекции и между страницами lifecycle; replay отказывает permanent / `payload_changed` / contained; inspect; bounded reconciliation с `repaired` |
| TF-02 | `booking/reconfirmation_deadline_worker.ts` | то же; невалидная задача сразу в dead-letter (раньше падала до try и повторялась каждым запуском); выключенный switch больше не списывает попытки |
| TF-03 | `consume_notification_effect.ts`, `notification_reconciler.ts`, `notifications_entry.ts` | switch перед claim и перед Tx2 с возвратом попытки; replay хранит `previousReason`, `invalid_effect`/`unsupported_effect` не переигрываются; port для console |
| Restore | `modules/operations/restore_admission.ts` | изоляция по имени БД, deletion authority, re-deletion L1 runner'ом под ключом от исходного запроса |

Найденные и исправленные дефекты: replay TF-01/02 обнулял `attempts` и
затирал причину; любой вызывающий код мог сделать replay без authority
(теперь только через console); disable TF-02 в транзакции считался сбоем и
вёл в dead-letter; невалидная задача TF-02 никогда не попадала в dead-letter.

## 10. Итог: семья → recovery path → тест → результат

Проверено на Firestore Emulator с синтетическими данными
(`test/emulator/operations_l2.test.ts`, группа `operations-l2`, и
`test/unit/operations/operational_task_registry.test.ts`). Это не проверка
production backup и не production operations.

| Семья | Recovery path | Тест | Результат |
|---|---|---|---|
| TF-01 | lease/fencing, бюджет, dead-letter, audited replay, receipt, reconciliation, switch | L2-T-AUTH, CLASS, LOST, CRASH, LEASE, REPLAY, RECON, DISABLE, LEAK | pass |
| TF-02 | lease/fencing, бюджет, dead-letter, audited replay, switch | L2-T-CLASS, DISABLE | pass |
| TF-03 | lease, бюджет, dead-letter, replay ≤ 3, reconciler, switch | L2-T-CLASS, DISABLE, RESURRECT, LEAK | pass |
| TF-04…07 | checkpoint resume, receipts, reconcile; activation flag на старте run | существующие группы content-media, handoff-notifications | без изменений; OB-03 |
| TF-08, TF-11 | resumable / idempotent rescan; switch нет по контракту | существующие privacy-l1, find-people | без изменений |
| TF-09 | бюджет 3, orphan reconcile | существующие content-media | без изменений; PB-14 |
| TF-10 | L1 runner; restore re-deletion | L2-T-RESTORE + privacy-l1 | pass |
| TF-12 | нет локального исполнителя | — | blocked OB-05 |
| TF-13 | K3 resumable + receipts | существующая admin-support-k3 | без изменений |
| TF-14 | lease binding, rollback D4.1 | существующая import | без изменений |
| Registry | coverage + положительный контроль | L2-T-REG | pass |

**Unknown / incomplete:** `processing`/`claimed` с истёкшим lease
показывается как `unknown` и разрешается только чтением owner receipt;
dead-letter класса `unknown` переигрывается и сверяется с receipt;
TF-01 delivery, остановленная switch посреди lifecycle, видна как
`retry_scheduled` до завершения owner. Restore с blocked-записями L1 —
`incomplete`; без доказуемой deletion authority — `closed`.

**Пределы emergency disable:** TF-01 завершает уже начатую страницу
lifecycle (≤ 200 броней); TF-03 — Tx2, начатую до чтения switch (OB-08);
TF-04…07 — текущий bounded run (switch для них — activation flag на старте).
Privacy-удаление (TF-08, TF-10, TF-11) не отключается. Market- и
effect-level switch контрактами не определены.

**Доказанная защита от resurrection (локально):** replay и повторное чтение
outbox для erased получателя встречают tombstone и не создают inbox
(L2-T-RESURRECT); изолированная копия со старыми данными субъекта не
допускается без deletion authority и допускается только после re-deletion
через L1 runner, повторный admission не создаёт второй запрос
(L2-T-RESTORE). Production backup, cutover и deletion ledger вне основной БД
не существуют (OB-04, OB-06).
