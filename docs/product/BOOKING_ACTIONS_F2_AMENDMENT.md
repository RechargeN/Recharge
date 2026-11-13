# F2 — поправка контракта: пользовательские действия Booking

Статус: **Accepted (2026-10-08)** с уточнениями владельца; реализация после
этой поправки.

Область: только локальный стенд `demo-recharge` (Emulator, loopback, PC).
Физические устройства не являются зависимостью; клиентские действия и доставка
проверяются через реальные adapters. Не production, не cloud, не push, не
Payments/escrow. Числа — тестовые константы стенда. Дополняет BCK-09
(`EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md`), E2.0 и F1; ни одно правило не
ослабляется.

## 0. Разделение со срезом F1

F1 не закоммичен. Его проверенный состав зафиксирован **до первой правки F2**
(приложение A): 87 путей с git blob-хэшами рабочего дерева на базе
`2529a545fe484da9810263e0f81362a3395efd8d`, полная копия изменений —
`%LOCALAPPDATA%\Recharge\slice-baselines\f1-2026-10-08\`
(`f1_tracked.patch` sha256 `975c3f67…7df2`, `f1_untracked.tar` sha256
`1a1c30e9…6b92`, `f1_blobs.txt` sha256 `85f75ebd…d1e7`). Файлы, которые меняют
оба среза, перечислены в §9.3: дельта F2 по ним — diff от blob F1 из
приложения A.

## 1. Принятый scope (из таблицы F2)

| Делаем в F2 | Остаётся вне F2 |
|---|---|
| reconfirm с журналом и идемпотентностью; показ required/deadline/confirmed/missed | изменение числа мест в существующей брони, отмена конкретного участника организатором — **Deferred** |
| понятные отказы (коды → сообщения), `rate_limited` с retry-after | уведомление о нематериальном изменении и срочное уведомление при старте < 24 ч — **открытая часть D07** (§4) |
| выбор числа мест 1…`maxParticipantUnits` | waitlist/hold/pending, named guests, Payments, escrow, массовые пулы, push — **Deferred** (кроме граничных проверок) |
| явное «обновить» вместо push | |
| перенос через настоящий Create с сохранением `occurrenceId` (§2) | |
| отмена occurrence организатором — там, где есть мобильный путь (§3) | |
| дедлайны с управляемыми серверными часами (§5) | |
| гонки с проверкой итоговых инвариантов (§6) | |
| два локальных клиента: организатор и участник (§8) | |
| починка keep-alive в тестовом клиенте B2 (§7) | |

## 2. Перенос: идентичность occurrence через Create

Факт до F2: `MaterializeEventScheduleUseCase` сопоставляет существующие
occurrences **по локальной дате**. Смена даты одноразового события давала новый
локальный id → новый серверный `occurrenceId` (`EventContentBodyMapper`
выводит его из локального id) → Content видел «occurrence исчез + новый»,
handoff выдавал `EventOccurrenceCancelled` и отменял брони вместо переноса.
Это противоречит D07 («stable occurrence and Booking IDs remain unchanged on
reschedule»).

F2:

- **one-time:** единственный occurrence сохраняет свой id при смене даты,
  времени или длительности. Серверный `occurrenceId`, `bookingId` и allocation
  сохраняются; материальное изменение (дата или сдвиг ≥ 2 ч) переводит бронь в
  `reconfirmation required` (существующий lifecycle 2A);
- **multi-date:** дата — идентичность occurrence. Удаление даты — отмена этого
  occurrence; замена даты другой — отмена + новый occurrence (явное поведение,
  не перенос). Явный «перенос даты» multi-date — Deferred;
- **recurring:** без изменений.

Проверка — только через настоящий путь: `EventCreateCoordinator.apply` (тот же,
что вызывает `CreateController` при смене даты) → `MaterializeEventScheduleUseCase`
→ `EventContentBodyMapper` → `EventPublicationController` → Content →
модерация → публикация → handoff → Booking. Правка backend-фикстуры вместо
этого пути не используется.

## 3. Скрытие и отмена — разные действия

| Действие организатора | Факт Booking | Существующие брони | Мобильный путь |
|---|---|---|---|
| hide / withdraw (`ContentVisibilityChanged` → невидим) | `EventUnpublished` | **сохраняются** `confirmed`, отмена по собственному дедлайну; новые закрыты после применения в Booking (E2 §5.2) | есть (`EventPublicationController.hide`) |
| удалить дату у опубликованного multi-date события | `EventOccurrenceCancelled` для этого occurrence | **отменяются**, allocation/usage освобождаются один раз | есть: Create → удалить дату → submit → модерация → publish (проверяется в F2 gate) |
| отменить occurrence одноразового события | `EventOccurrenceCancelled` | — | **мобильного пути нет**: one-time в Create всегда имеет ровно одну дату, а hide — не отмена. Backend lifecycle существует, но это не готовый пользовательский сценарий |
| отменить всё событие | — | — | **мобильного пути нет** (отдельной команды нет) |

## 4. Границы локальной модели: 2A, 2B и D05/D07

| Требование | Локальная модель | Статус |
|---|---|---|
| D07: перенос сохраняет occurrence/Booking id | F2 §2 (one-time) | **закрывается в F2** |
| D07: дата или сдвиг ≥ 2 ч → reconfirmation required | 2A lifecycle | есть |
| D07: сдвиг < 2 ч в ту же дату → бронь остаётся, **уведомление** | бронь остаётся; уведомления нет (у Booking нет перехода, нет producer) | **открыто** (кандидат: запись inbox F1 от нового producer) |
| D07: дедлайн ≥ 12 ч после проверенного уведомления и ≥ 6 ч до старта; без валидного окна бронь остаётся confirmed | 2A: дедлайн = новый старт; окно не проверяется | **расхождение, открыто** |
| D07: новый старт < 24 ч → allocation сохраняется, **срочное уведомление**, без auto-release | 2A не освобождает; срочного уведомления нет; локальный 2B освобождает после дедлайна независимо от 24 ч | **открыто** (уведомление может быть в inbox) |
| 2A: дедлайн запрещает позднее переподтверждение | `reconfirmation_deadline_passed` при `now ≥ deadline`; место **не** освобождается | есть, проверяется §5 |
| 2A: отмена пользователем доступна при required, в обход обычного дедлайна отмены | есть | проверяется §5 |
| D05: auto-release выключен до утверждённой политики доставки | локальный 2B (default-off воркер) освобождает место после дедлайна; доставка не доказана | **2B — локальная проверка механики, не выполнение D05** |
| D05: in-app inbox как authoritative поверхность | F1: `booking.reconfirmationRequired` (категория `booking.changes`, закреплена) | есть локально |
| D05: FCM push | — | Deferred |

Итого: F2 проверяет механику 2A и локального 2B, но **не закрывает** D05
(auto-release по доказанной доставке) и D07 (окно дедлайна, < 24 ч, срочное и
нематериальное уведомления). Это явная незакрытая часть, а не допущение.

## 5. Дедлайны: управляемые серверные часы

Основные проверки — Emulator-тесты в одном процессе, где **все участники
используют одни и те же серверные часы** (`FakeClock`): команды Booking
(create, cancel, reconfirm), lifecycle переноса (время события), deadline
worker (`nowUtc` из тех же часов) и consumer Notifications. Подстановка времени
только одному воркеру не используется.

Границы (дедлайн `D` = новый старт по 2A):

| Момент | reconfirm | cancel при required | 2B worker | запись inbox `reconfirmationRequired` |
|---|---|---|---|---|
| `D − 1 мс` | принят | принят | не трогает | создаётся |
| `D` | `reconfirmation_deadline_passed` | принят | отменяет (`missedReconfirmation`), освобождает один раз | создаётся (`deliverUntil = min(+7 сут, D)`, условие истечения `now > deliverUntil` ещё ложно) |
| `D + 1 мс` | `reconfirmation_deadline_passed` | принят (если не отменена воркером) | отменяет, если ещё нет | `expired` |

Точные ожидания для строки «`D`» берутся из кода: reconfirm отказывает при
`now ≥ D`, воркер пропускает при `D > now`, consumer истекает при
`now > deliverUntil`. Тест фиксирует их явно.

Отдельный smoke на реальном времени не входит в gate F2 (не основа проверки).

## 6. Гонки: проверка по итоговым инвариантам

Каждая гонка запускается с реальным перекрытием во времени, затем
проверяются инварианты, а не только ответы:

1. **allocation/usage:** `allocatedUnits` ledger = сумма мест активных броней;
   счётчики usage = число активных броней пользователя; ни одно значение не
   отрицательное; освобождение не больше одного раза на бронь.
2. **ревизии:** reconfirm с `materialRevision = N` после переноса `N+1` →
   `material_revision_mismatch`; бронь остаётся `required` для `N+1`.
3. **уведомления:** на каждую зафиксированную ревизию брони ровно одна запись
   outbox; на каждую запись outbox — не больше одной записи inbox; сверка
   Notifications `complete`, dead letter нет.

Набор: reconfirm ∥ cancel; reconfirm ∥ новый перенос; cancel ∥ перенос;
create ∥ перенос; два reconfirm с разными ключами; reconfirm ∥ worker ∥ cancel;
cancel ∥ отмена occurrence.

## 7. Мобильный клиент

- `EventBookingView`: `reconfirmationState`, `reconfirmationRequiredForRevision`,
  `reconfirmationDeadlineUtc`, `terminalReason`.
- Операция `reconfirm` в журнале (`expectedBookingRevision`, `materialRevision`,
  ключ идемпотентности сохраняется до отправки): потерянный ответ, офлайн и
  перезапуск ведут себя как у create/cancel.
- Отказы: коды → сообщения на английском (`sold_out`,
  `active_booking_limit_reached`, `registration_not_open`, `registration_closed`,
  `cancellation_deadline_passed`, `reconfirmation_deadline_passed`,
  `material_revision_mismatch`, `revision_conflict`, `already_active`,
  `event_unavailable`, `rate_limited` с retry-after); неизвестный код — общий
  отказ.
- Выбор мест 1…`maxParticipantUnits` из условий Booking.
- Кнопка «Refresh» — повторное чтение с сервера (push нет).
- Тестовый клиент B2 отправляет каждый запрос на новом соединении
  (`persistentConnection = false`): проверки потерянного ответа, офлайна и
  восстановления после перезапуска сохраняются без изменений.

## 8. Gate на двух клиентах

`stand-f2-gate.mjs`: свежий стенд, флаги F1 и `booking.reconfirm` включает
только gate (seed не меняется — B-gates прежние). Два независимых процесса
`flutter test` с разными пользователями, Session, installation id и журналами;
точки встречи с дедлайнами, без фиксированных пауз:

1. организатор (`creator`) создаёт через Create одноразовое событие E1 и
   multi-date событие E2 (две даты); staff одобряет; публикация;
2. участник (`viewer`) бронирует E1 (два места через выбор) и одну дату E2;
3. организатор переносит дату E1 через Create → бронь участника `required`,
   тот же `occurrenceId` и `bookingId`; участник по «Refresh» видит
   required/deadline и запись inbox; reconfirm → `confirmed`;
4. организатор переносит E1 ещё раз → участник видит новый required; ответ на
   старую ревизию отклоняется; reconfirm новой ревизии;
5. организатор удаляет забронированную дату E2 → бронь отменена, запись inbox;
6. gate: сверки handoff и Notifications `complete`, dead letter нет,
   инварианты ledger/usage.

Выход любого клиента с ошибкой (или до последнего одобрения) сразу прерывает
ожидания gate; стенд останавливается с проверкой. Участник запрашивает terms
с каналом `onsite`, как приложение берёт его из booking ref Catalog (этот путь
проверяет E2-gate).

## 9. Закрытая карта файлов

### 9.1 Новые

```text
docs/product/BOOKING_ACTIONS_F2_AMENDMENT.md
apps/backend/functions/test/support/booking_invariants.ts
apps/backend/functions/test/emulator/booking_reconfirmation_deadline_clock.test.ts
apps/backend/functions/test/emulator/booking_action_races.test.ts
apps/backend/functions/test/stand/stand_booking_actions.ts
apps/backend/scripts/stand-f2-gate.mjs
apps/mobile/test/unit/booking_transport_event_booking_gateway_test.dart
apps/mobile/test/widget/event_booking_section_test.dart
apps/mobile/test/backend_local/f2_client_test.dart
```

### 9.2 Изменяемые, только в F2

```text
apps/mobile/lib/features/create/domain/usecases/materialize_event_schedule_usecase.dart
apps/mobile/lib/features/booking/domain/repositories/event_booking_gateway.dart
apps/mobile/lib/features/booking/data/booking_transport_event_booking_gateway.dart
apps/mobile/lib/features/booking/application/event_booking_controller.dart
apps/mobile/lib/features/booking/presentation/event_booking_section.dart
apps/mobile/lib/app/di/event_booking_composition.dart
apps/mobile/test/unit/event_schedule_test.dart                 (новые случаи)
apps/mobile/test/unit/event_booking_controller_test.dart       (reconfirm, отказы, места, refresh)
apps/mobile/test/backend_local/event_booking_ui_stand_test.dart (только keep-alive в FaultClient)
```

### 9.3 Изменяемые обоими срезами (дельта F2 — от blob F1 из приложения A)

```text
apps/mobile/lib/features/booking/data/booking_callable_adapter.dart   (+reconfirmInternalBookingV1)
apps/backend/functions/test/stand/stand_main.ts                        (команды F2, ленивая загрузка)
apps/backend/scripts/stand-seed.mjs                                    (команды F2)
apps/backend/functions/package.json                                    (тесты, stand:f2-gate)
apps/backend/README.md                                                 (раздел F2)
docs/product/EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md               (§37)
docs/architecture/LAUNCH_STATUS.md                                     (строка F2)
docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md                          (поправка, changelog)
```

Backend `src/` в F2 не меняется. Если реализация выявит дефект backend, правка
дописывается в §9.4 с пометкой «добавлено при реализации».

### 9.4 Добавлено при реализации

- `apps/mobile/lib/core/network/backend_contract.dart` — `BackendFailure.reason`:
  исходный типизированный код отказа сервера. Без него адаптер сводил
  `sold_out`, `active_booking_limit_reached` и др. к `invalidArgument`, а
  `rate_limited` — к «нет связи». Классификация `code` не меняется.
- Тестовая ожидаемость «ручная отмена после воркера»: повторная отмена
  отменённой брони — идемпотентный успех без изменений (существующее поведение
  Booking); тест проверяет неизменность ревизии, причины и ledger.
- Точечные Emulator-прогоны F2 идут без Pub/Sub: первый такой прогон оставил
  осиротевший Pub/Sub-процесс на 8085; с согласия владельца остановлен ровно он
  (PID 7820, проверены имя, время запуска и команда).

## 10. Порядок и Done

1. **F2a** — Create identity (§2), Emulator-тесты часов (§5) и гонок (§6),
   стенд.
2. **F2b** — мобильные adapters и UI (§7), unit/widget-тесты, keep-alive B2.
3. **F2c** — gate на двух клиентах (§8), полный регресс: все backend-проверки,
   `test:emulator`, gates F2, F1, E2, E2a, E1, C3, C2, C1, B2, B1, acceptance,
   `api_contracts`, `flutter analyze`/`test`, границы 71/71, `git diff --check`.

## Приложение A. Проверенный состав F1 (до первой правки F2)

База `2529a545fe484da9810263e0f81362a3395efd8d`; `git hash-object` рабочего
дерева на 2026-10-08, после полного регресса F1, повторов F1 и B2 (3/3).

```text
b309e771a4826cac17533a272360144bb49b6153 apps/backend/README.md
4466ca00f2c23dde27470eb9e72b1530573bc37c apps/backend/config/manifests/execution-manifest.json
38cc674cbe7d19b6ca440a51b88788bd34c7e6e3 apps/backend/firestore.indexes.json
85685d30b4e1f119c4cb30694f29448aeb13e111 apps/backend/firestore.rules
cecfa55124f028c0fb4d4c2b4a293d71985f7375 apps/backend/functions/package.json
810cc63fcabdffd3da181d0800ae6891f603fe8d apps/backend/functions/src/booking/cancel_internal_booking.ts
9b377f9000a34356f1a03aa7436e2e66fa224750 apps/backend/functions/src/booking/create_internal_booking.ts
95a114a207ab43da69c74f46c78d6e4da8997403 apps/backend/functions/src/booking/notification_effects.ts
fe99e603620081562e3e71a9e50227593b2b87d4 apps/backend/functions/src/booking/occurrence_lifecycle.ts
84331fcaa26c5631ef3f6df7b5c675ff720ecbf2 apps/backend/functions/src/booking/privacy.ts
94e85424f57e7e68ede37ced01531576b526dd0d apps/backend/functions/src/booking/reconfirm_internal_booking.ts
05c98c293a804ba823f10d977c860b2f2a999609 apps/backend/functions/src/booking/reconfirmation_deadline_worker.ts
899cf4503e5d540528a673ed724603d099243e67 apps/backend/functions/src/booking/retention.ts
ddbbce87191c51ef0345e5c14b1ac75ef6f05b65 apps/backend/functions/src/index.ts
bb323c51360d4185dd94a133b195d089c469da76 apps/backend/functions/src/modules/notifications/application/consume_notification_effect.ts
fd75e4c23d5ffb5d10b320465f306ec615e69b4a apps/backend/functions/src/modules/notifications/application/notification_reconciler.ts
0515bf6c7161149aeed3b934bfb3e1201f734b2d apps/backend/functions/src/modules/notifications/application/notifications_command_handler.ts
985ddd49e50401e3f3be03059c175bba95c23882 apps/backend/functions/src/modules/notifications/application/notifications_privacy_task_handler.ts
e93b05163163da1e567e50dfc06e15c9155a9d63 apps/backend/functions/src/modules/notifications/application/notifications_query_handler.ts
32db3eb879874265d8c7f604a3b6c2848523e946 apps/backend/functions/src/modules/notifications/domain/delivery_attempt.ts
d39df977524d7fda1e5cf3705c9b20bb46bdb3fe apps/backend/functions/src/modules/notifications/domain/inbox_item.ts
53b1fecde5361ee972769cdee8a74a7e1ab1f1dc apps/backend/functions/src/modules/notifications/domain/notification_effect.ts
cf6e4e2f612b23659af4695c5480a5fd31315b37 apps/backend/functions/src/modules/notifications/domain/notification_policy.ts
c883d6abb9d9804634383181540be7d23a2f6453 apps/backend/functions/src/modules/notifications/domain/notification_templates.ts
aaa0a6d60ae1f71a7174a1207d7d6df1059a0082 apps/backend/functions/src/modules/notifications/domain/repositories.ts
2bd7c267f4b621508ee419724f1d578456e1b4d3 apps/backend/functions/src/modules/notifications/infrastructure/firestore_notification_sources.ts
53c3ffa6db5988812426f92b137b6e54f019311c apps/backend/functions/src/modules/notifications/infrastructure/firestore_notifications_repository.ts
0a533de3381ab9c97a6b24e5d223411e358ce2da apps/backend/functions/src/modules/notifications/infrastructure/in_memory_notifications_repository.ts
017edf3ca0eef4e57c35f2e0f3851bd49421d5b3 apps/backend/functions/src/modules/privacy_orchestration/application/privacy_domain_task_runner.ts
fa1ff60be0f5e3ec74bc9e08f803fe68f4883bfb apps/backend/functions/src/notifications/outbox.ts
ed29a203ab5fc1d5f17244d7fb3855fd966a6b87 apps/backend/functions/src/notifications_entry.ts
030f249e7634a38f4197ef64f13c692667bb3983 apps/backend/functions/src/shared/feature_flags.ts
ba4373e0cf0ed6941b07bc19c4d352efb6330b1a apps/backend/functions/test/contract/notifications_fixture_parity.test.ts
2782b7f48e350147b751a5a1e520d4e4aff054e9 apps/backend/functions/test/emulator/booking_notification_effects.test.ts
9e45d6f5cc26a615de3a4d79c33685e007dd0720 apps/backend/functions/test/emulator/notifications_inbox_emulator_flow.test.ts
3ad516150c5c0940c69d6dcc93ab50aed67dccd8 apps/backend/functions/test/emulator/notifications_privacy_emulator.test.ts
a7d351e6ee060e179fb93cb0693db3ea92f1d2e9 apps/backend/functions/test/emulator/notifications_rules_default_deny.test.ts
eda7ca3835f31bae36ad21159a75859b10b0c876 apps/backend/functions/test/emulator/notifications_unavailability.test.ts
5b92de3396596b09358cb28a5849a465c4a5dd2a apps/backend/functions/test/stand/stand_main.ts
c5227c7c1c83fb9dc540d83a27daaa750f695cf8 apps/backend/functions/test/stand/stand_notifications.ts
f8a212dd422fb556a2daf727afcbe7b384d8bedb apps/backend/functions/test/support/notifications_world.ts
5b03780b370d7a64b3755c7fd45ebe0542c16f82 apps/backend/functions/test/unit/booking_notification_effects.test.ts
75dd97fbb7b78d4806287b9dffa2fb89ebb3346d apps/backend/functions/test/unit/booking_retention.test.ts
c5fb6c798b662478b057b600f977ffb2d8f0acd7 apps/backend/functions/test/unit/notifications/consume_notification_effect.test.ts
29cfe0c7a25a742d31f00319899f8bf74b6a2d6b apps/backend/functions/test/unit/notifications/delivery_attempt.test.ts
c0ca2fe43163e4e6927825f9c3237fbee36d74a5 apps/backend/functions/test/unit/notifications/inbox_item.test.ts
f6d0a323e4b30e61822fcc84aaa96ec285d2c3a6 apps/backend/functions/test/unit/notifications/notification_effect.test.ts
0b1446b82f65b1d20025b93c97712a8b7696c9f3 apps/backend/functions/test/unit/notifications/notification_policy.test.ts
39bb7854938376cec4f9bd34b59093a59ac01f58 apps/backend/functions/test/unit/notifications/notification_reconciler.test.ts
79ad69eaaddca8383d96460cc5b60a7f4627b073 apps/backend/functions/test/unit/notifications/notification_templates.test.ts
139fcdc51cc729f892ce916b16454c2510f2c223 apps/backend/functions/test/unit/notifications/notifications_command_handler.test.ts
36e36d79cce73f87f6ebf8caa98f637568945f2e apps/backend/functions/test/unit/notifications/notifications_privacy.test.ts
a3f7c6626f9fd08ce8b854266937a777aeabadfc apps/backend/functions/test/unit/notifications/notifications_query_handler.test.ts
85799e82dde1156d216a8516ae4b9f664fe9d6f2 apps/backend/scripts/run-emulator-tests.mjs
c88f5a125cbe8d7f62c3638687d14646e9f7e09f apps/backend/scripts/stand-f1-gate.mjs
8a8e0ef3ec8ff15eee92a7019e4da7ba1951850f apps/backend/scripts/stand-seed.mjs
ab02ac916c7e7b69c622e562b0da6a7af6511d33 apps/backend/scripts/verify-notifications-layout.mjs
145235bdd52d7a956118dccd457a2c080c1c47b4 apps/backend/scripts/verify-r1-exports.mjs
303fa0bac4d25de5a2357dd429413911c2597ea2 apps/mobile/lib/app/di/notifications_inbox_composition.dart
b8096da0d959496dcf996d09f2856c5d4494a746 apps/mobile/lib/app/di/service_locator.dart
96290c6a823aeedd2366ab0c46d74a58efc44504 apps/mobile/lib/features/booking/data/booking_callable_adapter.dart
bfb5de42f9e19c45311c3c34f55214f9d3c5c934 apps/mobile/lib/features/notifications/data/remote/notifications_inbox_port.dart
84f03c075c84a4d4895dffb56ff434a578057079 apps/mobile/lib/features/notifications/data/remote/server_notifications_repository.dart
676a1d7570979fc64ced0724aa974e1402d34b57 apps/mobile/test/backend_local/notifications_inbox_client_test.dart
d512d48d9d627d2842ff66025c4dbae57cf2fb99 apps/mobile/test/backend_local/support/stand_backend.dart
ebcefa353f51c1ca0a2b144038b23a6cc332adc8 apps/mobile/test/unit/notifications_inbox_composition_test.dart
d8e22a0322b76149d2f8f97086953b85bde996f2 apps/mobile/test/unit/server_notifications_repository_test.dart
2c0085f65edc2e25bfc7f0aeb555eeee6d928c40 docs/architecture/LAUNCH_STATUS.md
efb646ace7906ec39f84cde65a228569a3512bb0 docs/product/C1_E2_CLOSURE_REVIEW.md
ebfa8918a0834b460da4e0ae45cbf1128cd36ad6 docs/product/EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md
0a8eeb8a5c9ea29b5a5caf7b1e9adeabc01b68c1 docs/product/NOTIFICATIONS_BACKEND_SPEC.md
0b9ac882591c575f6390845e1aabc9ecf0b326f4 docs/product/NOTIFICATIONS_F1_INBOX_AMENDMENT.md
f4bc689bc6d4b408b02a04452a36ad7b0a0ea454 docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md
fa776bb06f368dfea7f2af5f48d1f6e664a8272a packages/api_contracts/lib/api_contracts.dart
8d654ffbb4507e3b80232840c6f98fc6e549201e packages/api_contracts/lib/src/dto/response/notification_inbox_dto.dart
f25ac6cec064be392c63ede557e2949b1e523bee packages/api_contracts/schema/notifications/v1/fixtures/command_invalid.json
75ef7a24be48fd488fa230246c3d2b7fbe782000 packages/api_contracts/schema/notifications/v1/fixtures/command_valid.json
5315ae9b092f8d8b365f0ef99e03d90d65fe66a0 packages/api_contracts/schema/notifications/v1/fixtures/effect_invalid.json
07dccfbbbc416381f6592557083c26e25cdd3e29 packages/api_contracts/schema/notifications/v1/fixtures/effect_valid.json
d155a875aeb2a6db8cf31aa914caa740a74708ee packages/api_contracts/schema/notifications/v1/fixtures/query_invalid.json
920fb269cbdcae65c3a405c6991198cf0262b9a5 packages/api_contracts/schema/notifications/v1/fixtures/query_valid.json
fc6d14922689c32a60bf390c43ee9dad16835c03 packages/api_contracts/schema/notifications/v1/fixtures/result_valid.json
3a8dbed1d655a62e76eaa63916dd8b0b2ebfa28c packages/api_contracts/schema/notifications/v1/notification_effect.schema.json
aad4e8f5895c4746254c607f5685ce4b36b089a4 packages/api_contracts/schema/notifications/v1/notifications_command.schema.json
d3674afc771588010c77aecacb846807fb96ee4e packages/api_contracts/schema/notifications/v1/notifications_query.schema.json
752dd7de61042eed4ff460d7686cb368208a832e packages/api_contracts/schema/notifications/v1/notifications_result.schema.json
31a9607bd2e024d9d72c3f4e7e2da6079282d8cf packages/api_contracts/test/notification_inbox_dto_test.dart
```
