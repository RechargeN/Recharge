# E2.0 — поправка контракта: Event internal registration v1

Статус: **Accepted (2026-10-06)** с корректировками владельца; реализация идёт
в порядке E2a → E2.0 → E2b.

Область: только локальный стенд `demo-recharge` (Emulator, loopback). Не
production-контракт, не cloud, не deployment. Дополняет CONTENT_PUBLICATION
§35 (Event → Booking handoff) и EVENT_BOOKING D07 / BCK-09 §12.6; ни одно
существующее правило не ослабляется.

## 0. Что меняется

1. Content принимает `registration.mode = 'internal'` в узком подмножестве (§1).
2. Content-сторона (Event — единственный писатель `eventBookingOutbox`, §35)
   выводит из опубликованной истории факты Booking по каждому occurrence
   (§3–§5).
3. Booking-ответ `getEventAvailability` получает аддитивное поле `terms` (§7).
4. Мобильный Create получает одно новое поле — дедлайн отмены (§8).

Booking lifecycle, его консьюмер, проекция, ledger и правила отмены не
меняются.

## 1. Тело Event: `registration` для internal

```text
registration: {
  mode: 'internal',
  confirmationMode: 'instant',
  maxPartySize: int,                         // включает владельца брони
  opensMinutesBeforeStart: int,
  closesMinutesBeforeStart: int,
  cancellationClosesMinutesBeforeStart: int,
}
```

Все поля обязательны. Значений по умолчанию нет: отсутствующее поле — отказ, а
не подстановка. `externalBookingUrl` запрещён. Окно задаётся только
относительно начала occurrence; абсолютное окно отклоняется с причиной
`event.internal_registration.window_absolute_unsupported`.

### 1.1 Числовые границы (E2.0, test-only; не product defaults)

| Поле | Диапазон |
|---|---|
| `maxPartySize` | 1..21 (верхняя граница = текущий предел Booking guest policy) |
| `opensMinutesBeforeStart` | 1..525600 (365 дней) |
| `closesMinutesBeforeStart` | 0..10080 (7 дней) |
| `cancellationClosesMinutesBeforeStart` | 0..10080 |
| число occurrences с internal registration | 1..50 |

Границы собраны в одном объекте `eventInternalRegistrationConfig`; они не
закрывают продуктовые OD и не становятся production defaults.

### 1.2 Обязательные соотношения

Все значения — минуты **до** начала occurrence, поэтому меньшее число — более
позднее время.

- `closesMinutesBeforeStart < opensMinutesBeforeStart`: по времени регистрация
  закрывается позже, чем открывается;
- `cancellationClosesMinutesBeforeStart < opensMinutesBeforeStart`: по времени
  возможность отмены заканчивается позже открытия регистрации (иначе отмена
  была бы закрыта ещё до первой брони);
- при `capacityMode = known`: `maxPartySize <= participants.capacity`;
- закрытие регистрации и дедлайн отмены друг от друга не зависят.

### 1.3 Допустимые сочетания

| Условие | Требование | Код отказа |
|---|---|---|
| вместимость | `participants.capacityMode` ∈ `known`, `unlimited` | `event.internal_registration.capacity_required`, `…capacity_unknown` |
| цена | `pricing.mode = 'free'` (а значит `paymentCollectionMode = 'none'`) | `…paid_unsupported` |
| подтверждение | `confirmationMode = 'instant'` | `…confirmation_unsupported` |
| формат | `format = 'offline'` → канал `onsite` | `…format_unsupported` (online/hybrid) |
| поля Booking верхнего уровня | `guestPolicy`, `confirmationMode`, `inventory*`, `waitlistPolicy`, `registrationDeadlineRule`, `admission*` по-прежнему отклоняются по имени | `event.unsupported_capability:*` |
| границы/соотношения §1.1–1.2 | — | `…party_size_invalid`, `…party_exceeds_capacity`, `…window_invalid`, `…cancellation_invalid`, `…too_many_occurrences` |

`minParticipants` остаётся информационным и в Booking не проецируется.

## 2. Запрещённые переходы у опубликованного объекта

Сравнение идёт с ревизией, на которую указывает publication pointer (с любым
hold), и с ревизией, на которую он переключается. Код отказа один:
`event.internal_registration.transition_unsupported`.

| Изменение | E2.0 |
|---|---|
| internal → none/external | запрещено |
| `capacityMode` finite ↔ unlimited | запрещено |
| `format` (venue mode) | запрещено |
| место проведения: `location` (`marketCityId`, `countryCode`, `city`, `venueName`, `formattedAddress`, `meetingPoint`, `latitude`, `longitude`, `pinConfirmed`, `accuracy`) | запрещено, пока lifecycle смены места не поддержан (D07 / BCK-09 §12.6 «material venue-mode change» не исключается молча) |
| none/external → internal | разрешено (новая проекция) |
| число мест (finite), `maxPartySize`, окна, дедлайн отмены | разрешено, существующий Booking lifecycle (§5) |
| время occurrence (перенос) | разрешено, D07 (§5.1) |
| добавление/удаление occurrence | разрешено (§5) |

**Где проверяется.** Обязательная проверка — в той же транзакции, где
фактически переключается publication pointer: `publishApprovedRevision` и
`activatePublishedRevision`, включая rollback к старой ревизии. Проверка при
`submitForPublication` остаётся только ранней обратной связью. Restore после
moderation hold ревизию не меняет и проверку не требует.

## 3. Серверные производные (никогда не от клиента)

| Поле Booking projection | Источник |
|---|---|
| `eventId` | `contentId` |
| `occurrenceId` | `eventSlots[i].id` (стабилен при обычном редактировании) |
| `poolId` | только finite: `pool_` + первые 32 hex `sha256("event-internal-pool-v1|<contentId>|<occurrenceId>")`. Генерирует сервер, в теле его нет, пользователь не вводит. Стабилен при любых правках и при rebuild; меняется только вместе с `occurrenceId` |
| `channel` | finite: `onsite`; unlimited: отсутствует (Booking требует pool и channel вместе) |
| `capacityMode`, `totalCapacity` | `known` → `finite` + `participants.capacity`; `unlimited` → `unlimited` |
| `guestPolicy` | `maxPartySize = 1` → `selfOnly`; `>= 2` → `partyWithoutNames`; `maximumParticipantUnits = maxPartySize` |
| `registrationWindow.opensAt` / `closesAt` | `startAtUtc` occurrence − соответствующие минуты |
| `cancellationDeadline` | `startAtUtc` occurrence − `cancellationClosesMinutesBeforeStart` |
| `occurrenceStartsAt` / `EndsAt` | слот occurrence |
| `marketId`, `publisherRef` | опубликованная ревизия |
| `publicationRevision` | `pointerRevision` эффекта Content (монотонен по объекту) |
| `materialRevision` | по occurrence, §5.1 |
| фиксированные | `registrationMode internal`, `pricingMode free`, `paymentCollectionMode none`, `confirmationMode instant`, `inventoryAuthority internal`, `inventoryShape general`, `eligibilityMode open`, `lifecycle published`, `bookingEnabled true` |

Деривация — одна чистая функция в Content domain; её же использует Catalog
для `bookingRef` (§7), поэтому клиент ничего не вычисляет.

## 4. История handoff

Handoff не работает по правилу «последняя ревизия побеждает». Он проходит
каждый эффект каждого объекта по порядку и хранит историю переходов.

- **Порядок.** Глобальный поток эффектов Content (`occurredAtUtc`, `effectId`)
  только сообщает, у каких объектов есть новое. Обработка идёт по объекту
  строго по `pointerRevision`; источник — сохранённая история
  `effectsForContent` (индекс `contentEffects: contentId, pointerRevision`).
- **Восстановление пропусков.** Если у объекта обработан `pointerRevision` N, а
  следующим пришёл N+k, сначала из сохранённой истории проходятся N+1…N+k−1.
  Если промежуточного эффекта в истории нет, это находка `source_effect_missing`,
  объект останавливается, ничего не выдумывается.
- **Checkpoint.** Глобальный checkpoint сдвигается только за эффект, у которого
  есть receipt; на первом необработанном он останавливается (`stoppedAt`) и не
  перепрыгивает его.
- **Terminal-маркер.** Удалённый occurrence получает в состоянии handoff
  `terminal: cancelled` (или `terminal: past`). Поздняя публикация с тем же
  `occurrenceId` его не воскрешает: это находка `occurrence_terminal`, проекция
  Booking остаётся tombstone.
- **Время решения.** «Удалён до начала» оценивается по `occurredAtUtc`
  исходного эффекта Content, а не по времени запоздавшей обработки: удалён до
  старта — `EventOccurrenceCancelled`, удалён после старта — `terminal: past`
  без отмены.
- **Сбой без новых эффектов.** Сбой фиксируется надёжно: checkpoint не
  сдвинут, в статусе handoff записан `pendingSince` и причина. Сверка (§6) видит
  отставание по pointers Content независимо от новых эффектов; стендовая
  команда `handoff deliver` доделывает работу. Сбой доставки в Booking остаётся
  `retryPending` в `bookingProjectionDeliveries` и доделывается командой
  `booking-deliver`.

## 5. Факты по эффектам Content

| Эффект Content | Факт Booking по occurrence |
|---|---|
| `ContentPublished` / `ContentRevisionActivated`, объект видим, internal | новый occurrence → `EventRevisionPublished` (material 1); без изменений или нематериальное изменение → `EventRevisionPublished` (тот же material, новый publication); материальное изменение → `EventMateriallyRescheduled` (material + 1) |
| то же, occurrence исчез, `occurredAtUtc` эффекта раньше его старта | `EventOccurrenceCancelled` + terminal-маркер (существующий lifecycle: отмена броней, освобождение ledger/usage) |
| то же, occurrence исчез после своего старта | terminal-маркер `past`, факта нет |
| `ContentVisibilityChanged` → невидим (owner withdraw, moderation restrict/withdraw) | `EventUnpublished` по всем нетерминальным occurrences: новые брони закрываются после применения в Booking (§5.2); существующие остаются `confirmed`, отмена доступна по их собственному дедлайну |
| `ContentVisibilityChanged` → снова видим (restore/activate) | `EventRevisionPublished` с новым publication |
| ревизия без internal registration | ничего |

### 5.1 Материальность (D07 / BCK-09 §12.6)

Материальное изменение occurrence — смена локальной даты старта в часовом поясе
события или сдвиг старта на 120 минут и больше. Меньший сдвиг в ту же дату и
смена окончания нематериальны. Material venue-mode change и смена места
проведения в E2.0 невозможны: §2 запрещает их до публикации. Изменение числа
мест нематериально: ledger сверяет `totalCapacity` при следующей брони
(существующий `reconcileCapacity`), уменьшение ниже занятого не отменяет
существующие брони, новые получают `sold_out`.

### 5.2 Гонка hide → Booking: eventual consistency

Цепочка Content → handoff → outbox → Booking асинхронна. Между фиксацией hide
в Content и применением `EventUnpublished` в проекции Booking бронь ещё может
пройти. Для локального E2 принята **eventual consistency**: запрет новых броней
гарантируется после того, как hide применён в Booking (delivery `delivered`,
проекция `lifecycle: unpublished`). Немедленный запрет при коммите Content
потребовал бы атомарной проверки или fence на стороне Booking; это отдельное
расширение, в E2 не входит.

Тест проверяет отдельно: после подтверждённого применения hide в Booking новая
бронь отклоняется (`event_unavailable`).

## 6. Доставка, независимые отметки, сверка

- Один новый триггер `consumeContentEffectV1` (`onDocumentCreated`
  `contentEffects/{effectId}`), только при проверенном Emulator-контексте и
  включённых флагах. Он запускает независимые обработчики:
  1. **Catalog** — `deliverFromContent` из E1 (свой checkpoint и receipts в одной
     транзакции с обработкой). Флаг `catalog.delivery`.
  2. **Event → Booking handoff** (Content-owned) — свой checkpoint, receipts
     (effectId + payload hash) и состояние по объекту (§4). Пишет
     `eventBookingOutbox` create-only с детерминированным id
     `sha256(effectId|occurrenceId|kind)` в той же транзакции, что receipt,
     состояние и checkpoint. Флаг `content.event.bookingHandoff`.
- **Booking** потребляет outbox существующим `consumeEventBookingOutboxV1`
  (deliveries с lease, retry, dead-letter) — третья независимая отметка. Флаг —
  существующий `booking.eventProjection.delivery`.
- Сбой одного обработчика не помечает и не блокирует другой: общего флага
  «обработано» нет.
- **Сверка handoff**: Content pointers и опубликованная история против состояния
  handoff и проекций Booking (только чтение). Находки: `handoff_gap`,
  `source_effect_missing`, `occurrence_terminal`, `outbox_missing`,
  `delivery_dead_letter`, `projection_behind`, `projection_ahead`.
  Восстановление — повтор из сохранённых фактов, никогда не выдумывание.
- Флаги, все default-off, включает только bootstrap стенда:
  `catalog.discover.read`, `catalog.delivery`, `content.event.bookingHandoff`.

## 7. Чтение условий бронирования

- **Catalog** проецирует только ссылку: у occurrence с internal registration —
  `bookingRef { eventId, occurrenceId, channel? }`. Условия, доступность и цены
  бронирования Catalog не показывает; `availability` остаётся `not_connected`,
  `onlyAvailable` — typed unsupported, как в E1.
- **Booking**: успешный ответ `getEventAvailability` в формах `notOpen`,
  `finiteAvailable`, `finiteLimited`, `finiteSoldOut`, `unlimitedAvailable`,
  `closed` получает необязательное `terms { inventoryPoolId?, channel?,
  partyMode, maxParticipantUnits, registrationOpensAt?, registrationClosesAt?,
  cancellationDeadline? }` — копию из проекции Booking. Формы `stale`,
  `unknown` и `unsupported` его не получают. Существующие поля и отказы не
  меняются, новых экспортов нет.
- Клиент бронирует ровно тот occurrence, что показан в Details, с `poolId`,
  `channel` и `eventRevision` из ответа Booking.

## 8. Мобильный Create

Маппер отправляет internal registration, только если в черновике пользователя:

- `registrationMode = internal` в оси Admission (в черновике схемы v3 это
  единственный источник: верхнеуровневое поле рядом с Admission не
  хранится; без Admission — верхнеуровневое поле, и тогда отказ
  `admission.unset`);
- `admissionMode = booking`, `confirmationMode = instant`;
- правила допуска пусты; interest, onsite, waitlist и application window
  выключены;
- `registrationWindow` типа `occurrenceRelative` с обоими значениями;
  `absolute` → `unsupported: registrationWindow.absolute`;
- guest policy **выбрана явно**: `none` → 1, `plusOne` → 2, `plusN(m)` → m + 1
  (m от 1 до 20); `namedGuestsOnly` не поддерживается; не выбрана →
  `unsupported: guestPolicy.unset` (отсутствие выбора не равно запрету гостей);
- `inventory` не задан (pool ID генерирует сервер);
- `format = offline`, цена бесплатная;
- заполнено новое поле дедлайна отмены.

Иначе черновик не отправляется: `unsupported` с конкретной причиной, как в C3.

UI: новое поле в разделе Admission (только при internal) — «Отмена закрывается
за N минут до начала», без предзаполнения. Выпадающий список guest policy
перестаёт показывать `none`, пока политика не выбрана. Значения окна
регистрации, которые форма показывает при его включении, видны пользователю и
редактируемы; сервер ничего не подставляет.

## 9. Не входит в E2

Оплата, online/hybrid, absolute-окно, именованные гости, waitlist, ручное
подтверждение, eligibility, пользовательские pools/shapes, смена режима или
места у опубликованного объекта, немедленный fence hide → Booking, уведомления
(остаются suppressed), auto-release, Media read URL (обложки в Discover не
показываются), физические устройства (B1-device).

## 10. Закрытая карта файлов

Пути от корня репозитория. Новые файлы помечены «нов.». Composite indexes:
**ноль новых** — handoff читает документы по id, история объекта идёт по
существующему индексу `contentEffects (contentId, pointerRevision)`.

### 10.0 Предварительное исправление (до E2a)

- `apps/backend/scripts/verify-content-persistence-layout.mjs` — gate устарел
  после одобренных C1–C3 и E1 (Media, Moderation, Catalog и два Content
  callable). Вместо `/content/i` и «никаких внешних пользователей» — явный
  allowlist: какие файлы вне модуля Content и какие именно символы
  импортируют из его хранилища, какие экспорты Functions разрешены и какие
  Emulator-only файлы Content могут импортировать Firebase.

### 10.1 E2a — путь чтения (цепочка до Details)

Backend:

- `apps/backend/functions/src/shared/feature_flags.ts` — `catalogFlagIds`
  (`catalog.discover.read`, `catalog.delivery`).
- `apps/backend/functions/src/modules/catalog/domain/catalog_config.ts` —
  `projectionSchema` → `catalog-event-projection-v2`.
- `apps/backend/functions/src/modules/catalog/domain/catalog_item.ts` — v2:
  `fullDescription`, `scheduleMode`, `publishedAtUtc` (полное описание — только
  в Details-элементе, карточки Feed/Search/Map его не несут).
- `apps/backend/functions/src/modules/catalog/infrastructure/content_catalog_source.ts`
  — `publishedAtUtc` опубликованной ревизии *(добавлено при реализации)*.
- `apps/backend/functions/src/modules/catalog/application/discover_query_handler.ts`
  (нов.) — конверт `discoverQuery` и wire-результаты.
- `apps/backend/functions/src/catalog_entry.ts` (нов.) — `handleDiscoverQuery`.
- `apps/backend/functions/src/content_effects_entry.ts` (нов.) — тело триггера,
  независимые обработчики.
- `apps/backend/functions/src/index.ts` — `discoverQueryV1`,
  `consumeContentEffectV1`.
- `apps/backend/scripts/verify-r1-exports.mjs`,
  `apps/backend/scripts/run-emulator-tests.mjs` — ровно +2 экспорта.
- `apps/backend/functions/test/stand/stand_flags.ts`,
  `apps/backend/functions/test/stand/stand_seed.test.ts` — флаги стенда;
  digest A2 меняется явно.
- `apps/backend/functions/test/unit/catalog/discover_query_handler.test.ts`
  (нов.), `apps/backend/functions/test/unit/catalog/catalog_domain.test.ts` (v2).
- `apps/backend/functions/test/emulator/discover_query_emulator_flow.test.ts`
  (нов.), `apps/backend/functions/test/emulator/content_effect_delivery_emulator.test.ts`
  (нов.).
- `apps/backend/functions/test/support/content_event_world.ts` (нов.) — общий
  помощник публикации для двух новых emulator-тестов *(добавлено при
  реализации, чтобы не дублировать ~150 строк)*.
- `apps/backend/functions/package.json` — `test:emulator:inside`,
  `stand:discover-gate`.
- `apps/backend/scripts/stand-e2a-gate.mjs` (нов.).
- `apps/backend/scripts/stand-e1-gate.mjs` — проверка «ручная доставка
  применила ≥ 1 факт» заменена проверкой результата: рядом с триггером она
  была бы гонкой *(добавлено при реализации)*.

Mobile (Firebase только в `app/di` и транспорте Booking):

- `apps/mobile/lib/features/discover/data/datasources/catalog_query_port.dart`
  (нов.).
- `apps/mobile/lib/features/discover/data/models/catalog_wire_models.dart` (нов.).
- `apps/mobile/lib/features/discover/data/repositories/catalog_snapshot_session.dart`
  (нов.).
- `apps/mobile/lib/features/discover/data/repositories/catalog_discover_repository.dart`
  (нов.).
- `apps/mobile/lib/features/discover/data/repositories/catalog_published_event_discovery.dart`
  (нов.).
- `apps/mobile/lib/features/discover/domain/entities/discover_item_entity.dart`,
  `apps/mobile/lib/features/discover/domain/entities/published_event_discovery_entity.dart`
  — `revisionRef`, `changedSinceListing`.
- `apps/mobile/lib/app/di/discover_catalog_composition.dart` (нов.) — guard,
  capability `discover.catalog` в `BackendBindingManifest`, адаптер транспорта.
- `apps/mobile/lib/app/di/service_locator.dart` — выбор адаптеров.
- `apps/mobile/lib/features/discover/presentation/pages/discover_map_page.dart`
  — объект без публичной точки не получает маркер и не двигает камеру
  *(добавлено при реализации: Catalog не выдумывает координаты)*.
- `apps/mobile/lib/features/booking/data/booking_callable_adapter.dart` —
  allowlist `discoverQueryV1`.
- `apps/mobile/test/unit/catalog_wire_models_test.dart` (нов.),
  `apps/mobile/test/unit/catalog_discover_repository_test.dart` (нов.),
  `apps/mobile/test/unit/discover_catalog_composition_test.dart` (нов.).
- `apps/mobile/test/backend_local/discover_catalog_stand_test.dart` (нов.).

### 10.2 E2.0 — контракт и handoff

Backend:

- `apps/backend/functions/src/modules/content/domain/event_internal_registration.ts`
  (нов.) — config §1.1, деривация §3, D07, переходы §2, diff фактов §5.
- `apps/backend/functions/src/modules/content/domain/type_rules/event_rules.ts`
  — internal-подмножество, коды §1.3.
- `apps/backend/functions/src/modules/content/domain/content_type_registry.ts` —
  хук `validateTransition` для Event.
- `apps/backend/functions/src/modules/content/application/content_publication_service.ts`
  — проверка переходов в транзакции переключения pointer (§2).
- `apps/backend/functions/src/modules/content/application/event_booking_handoff.ts`
  (нов.) — обработчик и сверка (§4, §6).
- `apps/backend/functions/src/modules/content/infrastructure/firestore_event_booking_handoff_repository.ts`
  (нов.) — хранилища и create-only outbox.
- `apps/backend/functions/src/shared/feature_flags.ts` —
  `contentFlagIds.eventBookingHandoff`.
- `apps/backend/functions/src/content_effects_entry.ts` — второй обработчик.
- `apps/backend/functions/src/modules/catalog/domain/catalog_item.ts`,
  `catalog_config.ts` — `bookingRef`, `catalog-event-projection-v3`.
- `apps/backend/functions/src/booking/availability_query.ts` — `terms`.
- `apps/backend/firestore.rules` — явные deny: `eventBookingHandoffCheckpoints`,
  `eventBookingHandoffReceipts`, `eventBookingHandoffStates`.
- `apps/backend/config/manifests/execution-manifest.json` — те же три
  коллекции (`clientAccess: deny`, без TTL и индексов).
- `apps/backend/scripts/verify-content-persistence-layout.mjs` — новые
  Emulator-only файлы Content в allowlist.
- `packages/api_contracts/schema/booking/v1/booking_availability.schema.json` —
  `$defs/terms` в шести формах.
- `packages/api_contracts/schema/booking/v1/fixtures/query_valid.json`,
  `packages/api_contracts/schema/booking/v1/fixtures/query_invalid.json` —
  случаи `terms`.
- `apps/backend/functions/test/unit/content/event_internal_registration.test.ts`
  (нов.), `apps/backend/functions/test/unit/content/event_rules_internal_registration.test.ts`
  (нов.).
- `apps/backend/functions/test/emulator/content_transition_guard.test.ts` (нов.)
  — publish и rollback.
- `apps/backend/functions/test/emulator/event_booking_handoff_emulator.test.ts`
  (нов.) — публикация, повтор, перестановка, пропуск, terminal, hide/restore,
  D07, удаление до/после старта, сбой без новых эффектов, сверка.
- `apps/backend/functions/test/emulator/booking_queries.test.ts` — `terms`.
- `apps/backend/functions/test/contract/booking_fixture_parity.test.ts` —
  прогон новых fixtures.
- `apps/backend/functions/test/stand/stand_handoff.ts` (нов.),
  `apps/backend/functions/test/stand/stand_main.ts`,
  `apps/backend/scripts/stand-seed.mjs` — команды `handoff
  deliver|reconcile|status`, `booking-deliver`.
- `apps/backend/functions/test/stand/stand_flags.ts` — флаг handoff.
- `apps/backend/functions/test/support/content_event_world.ts` — `revise`,
  `activate`, стабильные id occurrence *(добавлено при реализации)*.
- `apps/backend/functions/test/stand/stand_creator_fixture.ts` (нов.),
  `stand_main.ts`, `apps/backend/scripts/stand-seed.mjs` — команда
  `creator-fixture`: второй верифицированный Creator со своей Page для клиента
  B, вне seed A2 (digest не меняется) *(добавлено при реализации: в seed только
  один Creator)*.
- `apps/backend/scripts/emulator-stand.mjs` — отказ «Foreign executable»
  теперь называет PID, путь и команду процесса; логика проверки не изменена
  *(добавлено при реализации после нестабильного отказа остановки)*.

Mobile:

- `packages/api_contracts/lib/src/dto/response/booking_availability_terms_dto.dart`
  (нов.), `packages/api_contracts/lib/api_contracts.dart` — экспорт.
- `packages/api_contracts/test/booking_availability_terms_dto_test.dart` (нов.),
  `packages/api_contracts/test/booking_query_fixture_test.dart` — новые
  fixtures.
- `apps/mobile/lib/features/create/domain/entities/event_admission.dart` —
  дедлайн отмены.
- `apps/mobile/lib/features/create/data/models/event_draft_mapper.dart` —
  сериализация.
- `apps/mobile/lib/features/create/application/controllers/create_controller.dart`
  — метод обновления.
- `apps/mobile/lib/features/create/presentation/widgets/event_admission_section.dart`
  — поле и явный выбор guest policy.
- `apps/mobile/lib/features/create/domain/usecases/validate_event_access_configuration_usecase.dart`
  — локальная проверка границ.
- `apps/mobile/lib/features/create/domain/usecases/build_event_content_body.dart`
  — маппинг §8.
- `apps/mobile/test/unit/event_content_body_mapper_test.dart`,
  `apps/mobile/test/unit/event_admission_test.dart`.
- `apps/mobile/test/fixtures/create/user_event_draft.dart` —
  `withInternalRegistration` *(добавлено при реализации)*.
- Не сделано, открытый пункт: локальная проверка Create по-прежнему считает
  internal registration «not ready» (`EventAccessReadiness` никто не
  передаёт); путь публикации тестового входа её не использует. Включение
  readiness в Create — отдельная правка DI.

### 10.3 E2b — Details → Booking → cancel и итоговый gate

- `apps/mobile/lib/features/booking/domain/repositories/event_booking_gateway.dart`
  — чтение условий.
- `apps/mobile/lib/features/booking/data/booking_transport_event_booking_gateway.dart`
  — `getEventAvailability` и `terms` через DTO.
- `apps/mobile/lib/features/booking/application/event_booking_controller.dart` —
  цель из Details.
- `apps/mobile/lib/features/discover/domain/entities/event_occurrence.dart` —
  `bookingRef`.
- `apps/mobile/lib/features/discover/data/repositories/catalog_published_event_discovery.dart`
  — разбор `bookingRef`.
- `apps/mobile/lib/app/di/event_booking_composition.dart` — контроллер для цели
  из Details (fixture B2 остаётся отдельным путём).
- `apps/mobile/lib/app/presentation/event_booking_panel.dart`,
  `apps/mobile/lib/app/presentation/event_details_page.dart` — панель для
  Content-событий с `bookingRef` под тем же guard.
- `apps/mobile/test/unit/event_booking_controller_test.dart`.
- `apps/mobile/test/backend_local/e2_client_test.dart` (нов.) — один файл, роль
  A или B через define.
- `apps/mobile/test/backend_local/support/e2_rendezvous.dart` (нов.) —
  файловые барьеры с таймаутом.
- `apps/mobile/test/backend_local/support/stand_backend.dart` — команды handoff
  и `booking-deliver`.
- `apps/backend/scripts/stand-e2-gate.mjs` (нов.), `apps/backend/functions/package.json`
  (`stand:e2-gate`).

### 10.4 Документы

- `docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md` (BCK-07 §35: internal
  registration v1, переходы, история handoff).
- `docs/product/DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md` (BCK-08: локальный
  `discoverQueryV1`, projection v2/v3, `bookingRef`).
- `docs/product/EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md` (BCK-09: `terms`,
  eventual consistency hide).
- `docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md`, `docs/architecture/LAUNCH_STATUS.md`,
  `apps/backend/README.md`.
- Этот документ.

## 11. Порядок и gate'ы

1. **10.0**: исправленный content layout gate зелёный.
2. **E2a**: Create → moderation → публикация → Catalog через триггер → Feed,
   Search и Map из одного снимка → Details той же ревизии; после hide объект
   исчезает из Feed, Map и Details. Ручного шага доставки нет.
3. **E2.0**: контракт, переходы, handoff, `terms`, поле Create; emulator-тесты
   §2, §4–§6.
4. **E2b**: два параллельных процесса `flutter test` на общем стенде без reset
   между ними, с разными пользователями, Session, installation ID и каталогами
   журналов; ожидание — по барьерам и опросу состояния с таймаутом, без
   фиксированных задержек.
   - A и B одновременно создают и отправляют по событию; staff одобряет на
     барьере; каждый публикует своё.
   - Каждый находит событие другого в Feed, Search и Map, открывает Details
     той же ревизии, бронирует, повторяет команду без дубля и отменяет:
     `Create → moderation → Catalog → Details → Booking → cancel`.
   - Конкурентный шаг: A скрывает своё событие, пока B его бронирует; оба
     действия стартуют по общему барьеру и пересекаются по времени. Допустимые
     исходы — бронь (`confirmed`) или отказ `event_unavailable`. После
     подтверждённого применения hide в Booking новая бронь B отклоняется, а
     событие исчезает у B из Feed, Map и Details.
5. Регрессия: B2 (изолированный набор), B1, C1–C3, E1, A2, `test:emulator`,
   все `verify-*`, `flutter analyze`, `flutter test`, boundary 71/71.

Это evidence двух независимых тестовых клиентов на ПК, не проверка физических
телефонов.

## 12. Риски

### Owner-authorized closure follow-up (2026-10-07)

Изменение закрытой карты: `service_locator.dart`,
`event_create_coordinator.dart`, `validate_event_draft_usecase.dart` и новый
`test/unit/event_access_readiness_test.dart` подключают динамический
`EventAccessReadiness` через существующие publication/Booking guards.
В localOnly, disabled, release, вне loopback/demo и без обоих test-entry
разрешений internal registration остаётся недоступна. В разрешённом режиме
Create явно сообщает local/testBackend scope; неподдержанные поля узкого v1
блокируются существующим Content mapper. Переключение binding повторно
проверяется, а не сохраняется как постоянное разрешение.

Явное расширение E1 scope в E2: Catalog projection v2 и Details несут полное
описание именно опубликованной ревизии. Feed/Search/Map cards по-прежнему
используют краткое описание. Это не обратное объявление E1 полным: E1 исключал
полное описание, расширение относится к E2a. Карта не рисует и не использует
для камеры объект с `notMappable`/без публичной точки, сохраняя его в Feed.

Дополнительные acceptance criteria:

1. Create не показывает `internal_registration_not_ready` и blocking
   disclosure для разрешённого local/testBackend v1; без разрешения оба
   ограничения возвращаются.
2. Online/hybrid, paid, named guests, absolute window, waitlist и manual
   confirmation не становятся доступными от readiness; настройки не
   создают бронь и не резервируют inventory.
3. Details получает full description из той же revisionRef, что и выбранный
   Catalog item; cards не получают full description. Hide исключает Details.
4. No-public-geo и online-only остаются в Feed по остальным фильтрам, но не
   получают map marker или camera position; фиктивные координаты запрещены.
5. Content allowlist принимает только проверенные пути и символы; отдельный
   отрицательный тест отклоняет чужой файл и лишний символ в разрешённом пути.

Rollback: убрать readiness wiring и восстановить default-deny disclosure;
откат Details-проекции требует согласованного отката projection version и
wire reader. Данные стенда не переносить в production.

Дополнительные файлы: `verify-content-persistence-layout.test.mjs` (отрицательные
проверки на временной копии), `C1_E2_CLOSURE_REVIEW.md` (аудит, план и checklist).

Дополнительно согласовано владельцем 2026-10-07 при условии видимости и
документирования изменений: `functions/test/integration/content_publication_security.test.ts`
и `functions/test/integration/media_security.test.ts` внутри `apps/backend/`.
Пять прежних статических запретов согласованы с уже принятыми C1–E2 adapters;
новый runtime scope не добавлен. Точные изменения и отрицательные controls
перечислены в closure review. Это новая проверка текущей реализации, а не
исправление исторических отчётов на «green».

Продолжение 2026-10-08: владелец поручил завершить доступные локальные gates и
условные коммиты. Диагностическое дополнение `emulator-stand.mjs` сохраняет
идентичности проверенных PID после успешной остановки вне Git; прежние проверки
не изменены. README описывает локальный `FUNCTIONS_DISCOVERY_TIMEOUT=60` для
холодного запуска, после фактического отказа стандартного 10-секундного
discovery; критерий загруженных Functions и startup deadline сохраняются.

Аудит allowlist 2026-10-08 дополнительно закрыл обход по префиксу каталога:
`content_foreign`/`media_foreign` не считаются внутренними модулями. Content
layout отклоняет также динамический import рядом с разрешённым статическим
import. Отрицательные проверки выполняются на временной копии, runtime scope
не расширяется; оба security-test файла сохраняют точные границы каталогов.
Существующая команда `verify:content-persistence:layout` в
`apps/backend/functions/package.json` теперь запускает и этот отрицательный
тест, чтобы обычный gate проверял принятую границу вместе с allowlist.

- Два одновременных `flutter test` в одном проекте могут упереться в startup
  lock Flutter. Первым шагом E2b — короткая проверка; запасной путь будет
  предложен отдельно, без смены доказательной модели.
- Цепочка триггеров (`contentEffects` → outbox → Booking) в Emulator
  асинхронна: клиенты ждут состояния опросом с таймаутом.
