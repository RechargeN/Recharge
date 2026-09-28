# RECHARGE — Event Source Ingestion (EVS) — Implementation Spec

Версия: v1.7-draft (2026-09-28). **Статус: Draft for owner review; часть решений §26 принята владельцем 2026-09-27.**
Runtime: **Absent.** Accountable owner: Content Platform / Product owner.

Документ — нормативная спецификация системы автоматического сбора событий
из официальных источников, подключённых к заведению (Place).

| Документ | Для кого | Роль |
|---|---|---|
| **Этот документ** | Все исполнители | Нормативная продуктовая спецификация; при расхождении прав он (backend-вопросы — BCK-23) |
| [ADR 0020](../adr/0020-event-source-ingestion.md) | Архитектура | Решения, требующие статуса Accepted |
| [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) | Backend | Канонический backend-документ: решения BCK23-D01…D18, API, делегация, retention, conformance, точная карта EVS-LOCAL-01a |
| [EVENT_SOURCE_INGESTION_BACKEND_IMPLEMENTATION_PLAN.md](EVENT_SOURCE_INGESTION_BACKEND_IMPLEMENTATION_PLAN.md) | Backend | Master roadmap B0–B10 |

Что документ **разрешает после перевода в Approved**: ничего, кроме
документов (этап E0). Этапы E1 (контракты) и E2 (mobile UI на демо-данных)
дополнительно требуют **ADR 0020 Accepted** (новая фича и новый
cross-language контракт — изменения baseline по ADR 0011 и
`docs/api/API_CONTRACTS_WORKFLOW.md` §1) и собственных Approved slice specs.
Этапы E3+ требуют post-stabilization backend authorization и gates BCK-02.

---

## 0. Changelog

| Версия | Дата | Изменения |
|---|---|---|
| v1.7-draft | 2026-09-28 | Поправки ревью: совместимость — по минимальным версиям BCK-документов (шапка [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md)), SHA коммита — только ненормативное «last verified against»; жалобы — только BCK-22: `ReviewItem(userReport)` и `reportId` убраны, EVS получает типизированный сигнал со ссылкой на case и может приостановить источник (`pauseReason: moderationCase`, §18.4) |
| v1.6-draft | 2026-09-27 | Решения владельца (§26): приняты D2, D3, D5, D6, D7, D9, D15; D4 и D8 — в изменённой редакции. Пропажа будущей даты на двух успешных проверках подряд (без условия 24 ч) скрывает её из показа без отмены и уведомлений и открывает проверку командой; вернувшаяся в источник дата снова показывается (§12.6). Явная отмена в источнике применяется сразу, с пилота; `event-ingestion.cancellation.auto` — аварийный выключатель (§12.7). Решения сверки `hideOccurrence`/`restoreOccurrence` вместо `markMissing`; 33 сценария сверки; новое требование к BCK-07 — обратимое скрытие по `sourceMissing` (§17.3); излишек сверх `100/day` — ближайшие по дате первыми; baseline — коммит `6c54082`; ссылок на non-normative файлы нет — комплект самодостаточен в ветке бэкенда |
| v1.5-draft | 2026-09-27 | Поправки второго ревью: политика URL без утверждения «секретов нет» (`publicEndpointConfirmed`, полный URL — restricted); результат подключения и пагинация ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §7.1.1); неизвестные поля команд отклоняются, сохранение — только persisted/read DTO ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §8); `PagePlaceOperatorLink` ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §9.3); §22 больше не дублирует списки фидов и кейсов — они только в [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §20.1/§21.1; enum решений без автоприкрепления; нормативный комплект — ADR 0020, эта спецификация, BCK-23, master roadmap |
| v1.4-draft | 2026-09-27 | Поправки ревью «Заход 6» и канонический [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md): baseline BCK-02 v2.4.98 / BCK-06 v0.8 / BCK-07 v0.7 (входы delegated import уже в BCK-07 §7.4); только публичные URL; граница JSON-LD — только `<script type="application/ld+json">`; iCal V1 — подмножество, сложные повторения и `RECURRENCE-ID` — подэтап 01c; постоянная делегация вместо `grantedByUserId`; `event_sources.review_changes`; идентичность `sourceId + externalUid + recurrenceKey`, без автоматического объединения между источниками; пропажа → `missingFromSource` + `reviewRequired`; без default cover; сверка неизвестного исхода команд Content; 7 callables |
| v1.3-draft | 2026-09-27 | Сверка с фактическим бэкендом (ветка `codex/backend-local-foundation-stage8`, BCK-07 v0.6): capabilities из закрытого каталога BCK-06 (`event_sources.manage`/`event_sources.review`; отправка требует `content.submit`); runtime identity `runtime-event-ingestion`; флаги `event-ingestion.*` по рынкам (`FirestoreFeatureFlagGate`); probe без подписанного токена (`platform/v1/async_operation`, `probeOperationId`); quarantine без Storage (`diffHash`/`approvedDiffHash`); команды Content — существующий набор BCK-07 с делегированным import-актором и `ContentProvenance.kind = ownerImport`; события — существующие факты `EventMateriallyRescheduled`/`EventOccurrenceCancelled` и envelope `eventIngestion.*`; `$id`/`$ref` схем по образцу identity/platform; классы данных по `DataClassRegistry`; точная карта файлов бэкенда — бриф v1.3 §4.1 (с v1.4 — BCK-23 §20); P7 закрыт Ajv-реестрами |
| v1.2-draft | 2026-09-26 | Точная сверка с EVENT_CLASSIFICATION_SPEC, EVENT_CREATE_SPEC, BCK-01/02/03, ADR 0011/0016, API Contracts Workflow и кодом. Исправлены конфликты: (1) ручная правка operational-полей импортированного Event запрещена (Event spec §18.3, Create §15 п.18) — FieldLock только для content-полей, иначе detach; (2) архетип не выводится из категории (Create §10.3 п.8) — берётся из профиля импорта, выбранного человеком; (3) «autoPublish» заменён на `autoSubmit` в стандартную модерацию (Create §16), прямая публикация — только при отдельной trust-capability (D15); (4) Publisher — только подтверждённая страница оператора Place; служебная staff-страница исключена из V1 (Event spec §15.1, ADR 0016); (5) `subEvent` schema.org — это Program Items, а не occurrences; (6) content-изменения публикуются по revision policy Create §17.2, а не «тихо». Добавлены: профиль импорта (§8.2) и отображение на все обязательные оси Event (§11), обязательные поля публикации и `needsCompletion` (§13.2), цена по Event spec §12.2, DST по RFC 5545 + подтверждение (§9.8), сдвиг серии (§10.3), классы данных (§8.7), зависимость от OD-03/OD-09/OD-10/OD-11, async probe (BCK-03 §28), жалобы через BCK-22, snapshots в Storage (BCK-01 §14), fixtures внутри `schema/event_ingestion/v1/` (BCK-03 §9). V1 сужен до `ical` и `jsonLd`; availability/sold-out убраны (владелец — BCK-16) |
| v1.1-draft | 2026-09-26 | Сверка с фактической базой, логика только на backend, предпосылки P1–P7, план реализации |
| v1.0-draft | 2026-09-26 | Первая редакция |

---

## 1. Источники истины, приоритет, внешние решения

Приоритет (AGENTS.md): Accepted ADR → spec текущего slice → LAUNCH_STATUS →
product vision.

1. Accepted ADR: 0011 (architecture freeze), 0013, 0015–0019.
2. [EVENT_CLASSIFICATION_SPEC.md](EVENT_CLASSIFICATION_SPEC.md) v2.2.3 —
   инварианты §2 (№3, 5, 6, 7, 11, 12, 13, 15, 16), §8 расписание, §9
   локация, §10 admission, §12 цена, §13 inventory/availability, §15
   Publisher и relations, §17 lifecycle, **§18 source/authority/дубли**,
   §19 кросс-валидация, §20.4 пример импортированного концерта, §21.2 presets.
   **Этот документ расширяет §18 и ничего в Event spec не переопределяет.**
3. [EVENT_CREATE_SPEC.md](EVENT_CREATE_SPEC.md) — §10.2 обязательные поля,
   §11 расписание, §15 publish-валидация, §16 publish pipeline, §17
   редактирование после публикации, §20 уведомления.
4. BCK-01 (module map, ownership, data classes), BCK-02 (registry, waves,
   gates, open decisions), BCK-03 (wire primitives, envelopes, idempotency,
   outbox OD-09, async operations).
5. Этот документ.
6. Концепция.

Соответствие Event spec §18:

| Event spec §18 | Здесь |
|---|---|
| `EventSourceRecord` | `SourceEventRecord` (§8.5) — та же запись с полями ingestion; в Event provenance она видна как элемент `sourceRecords[]` |
| `origin: manual \| providerImported \| apiSynced` | `apiSynced` — машиночитаемые интерфейсы, опубликованные источником для автоматического чтения (`ical`, `jsonLd`, позже `rss`, `jsonFeed`); `providerImported` — `ticketPlatform`. Новое значение не вводится |
| Уникальность `(providerRef, externalTenantId, externalEventId, externalOccurrenceId)` | §10.2 |
| `scraped` запрещён как production origin | Эвристический разбор HTML (`htmlPage`) не имеет честного значения origin → вне V1, требует отдельного решения (§6.3) |
| providerOwned / rechargeOverlay | §14 |
| DuplicateCandidate, запрет fuzzy merge | §15 |

Внешние открытые решения BCK-02 §16, от которых зависит EVS:

| OD | Суть | Влияние на EVS |
|---|---|---|
| **OD-03** | Cold-start catalog source, license, provenance, refresh, correction, removal | EVS — частный случай источника каталога; решения §8.1 `authorization`, §12, §21 подаются как вход в OD-03. **OD-03 Accepted — вход в E4** |
| OD-09 | Outbox envelope, delivery, dedupe | События §17.5 и уведомления работают только после OD-09 Accepted |
| OD-10 | LocalizedText, content-language policy | Язык контента импорта (`importProfile.contentLocale`) |
| OD-11 | Возрастные ограничения | События с признаками 18+ не отправляются автоматически (§11.2) до OD-11 Accepted |

---

## 2. Фактическая база (проверено по коду 2026-09-26)

| Область | Что есть | Чего нет | Следствие |
|---|---|---|---|
| Event (mobile) | `EventDraftData` (`features/create/domain/entities/event_draft_data.dart`): `publisherRef`, `timezoneId`, `scheduleMode` (`oneTime/multiDate/recurring`), `recurrence`, `occurrences` с `id`, `occurrenceOverrides` (`cancelled`), `location` (`venueName`, `formattedAddress`, `latitude`, `longitude`), `pricingMode` (`free/fixed/ticketTypes/donation`), `price`, `externalBookingUrl`, `unknownFields` | `placeId` в location; `provenance`, `sourceRecords`, `origin`, field locks | P1, P2 |
| Occurrence ID | Локальные `loc_occ_<yyyymmdd>_<minute>` (`materialize_event_schedule_usecase.dart`), при публикации заменяются постоянными ID (`create_repository_impl.dart`, `occurrenceIdMap`) | — | `externalOccurrenceId` ссылается на постоянный ID |
| Place (mobile) | `PlaceDraftData`: `PlaceKind {managedVenue, publicSpace, pointOfInterest}`, `relationshipToPlace` (`PlaceRelationship {owner, staff, visitor, curator}`, самозаявленное), `publisherRef`, `location.timezoneId`, geo, `contacts.websiteUrl`, `PlaceDataProvenance`; `PlaceDuplicateCandidate` | Опубликованный Place в Discover; проверенная связь Place↔ManagedPage | P3, P4 |
| Identity | `ManagedPageEntity` (`kind: venueOperator` и др., `verificationStatus`, `lifecycle`), membership `ManagedPageRelationship {owner, manager, editor}` с `capabilities: Set<String>`; строки `page.manage`, `page.content.create`, `page.content.submit`, `moderate.route`, `moderate.collection`, `publish.route.direct`, `publish.rental.direct`, `publish.collection.direct`, `create.event` | Централизованный реестр capabilities; строка `publish.event` (Create §5.2) | P5 |
| Публикация | Generic publish → `pendingReview`; Create→Discover sink только у Rental/Route/Collection (`app/adapters/*_publication_discovery_adapter.dart`) | Event pipeline (Discover читает mock `published_event_discovery_local_datasource.dart`) | P6 |
| Модерация | `RouteModerationPage` (`moderate.route`), логика модерации Collection, moderator inbox `__moderators__` | Общей очереди | Очередь EVS — не модерация (§13.1) |
| Notifications | Локальный inbox | Push, серверная доставка | BCK-13 |
| Contracts | Основная копия: `schema/booking/v1` + fixtures, ручные Dart DTO. Ветка бэкенда: ещё `platform/v1`, `identity/v1`, `privacy/v1`, `reference_data/v1`; TS-валидация — Ajv 2020 реестры (`functions/src/contracts/*_schema_registry.ts`) | Зависимость mobile → api_contracts | P7 закрыт шаблоном Ajv-реестров |
| Mobile flags | Const `*RuntimeConfig` в GetIt | Server/remote flags | `EventSourcesRuntimeConfig` |
| Mobile данные демо | Dart-фикстуры (`mock_identity_fixture.dart` и др.), JSON только `assets/route_demo/` | `assets/mock/` из baseline физически нет | Демо EVS — Dart-фикстуры |
| Backend | Минимальные совместимые версии документов — шапка [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md); last verified against `codex/backend-stage8-critical-repair` @ `526f497` (2026-09-28, non-normative): локальная R1-платформа, BCK-04/06/09/20 local и Emulator, модули `functions/src/modules/<m>/{domain,application,infrastructure}`, реестры доступа/классов данных/хранения, market-scoped флаги, точные проверки layout и exports; BCK-02 v2.4.99 §31.1 резервирует Event Ingestion без номера; BCK-06 v0.8; BCK-07 v0.7 — входы delegated import, следующий слайс `BCK07-LOCAL-01` (без Firestore-хранения Content); dev cloud — Not Ready. В основной рабочей копии `apps/backend/` нет | Модуль Content persistence, связь Place↔страница, делегация, EVS | Встраивание — [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) и [master roadmap](EVENT_SOURCE_INGESTION_BACKEND_IMPLEMENTATION_PLAN.md) |
| Boundary | `tools/scripts/check_boundaries.dart`, `exceptionBudget: 71` | — | 0 новых исключений |
| ADR | 0011–0019 | — | ADR 0020 Proposed |

---

## 3. Где живёт логика

**Чтение источников, разбор форматов, нормализация, sanity gate,
сопоставление и дубли выполняются только в backend-модуле BCK-23 (TypeScript).**
Mobile не содержит ни разбора iCal/JSON-LD, ни reconciler.

1. Fetch к сайтам с клиента запрещён (SSRF, robots, нагрузка, секреты —
   инвариант №16) — клиентская копия логики никогда не стала бы
   production-путём.
2. Две реализации одной логики — параллельная модель (AGENTS.md, правило
   стабилизации п. 2; BCK-02 §13).
3. Совпадение поведения обеспечивают **общие данные**: JSON schemas и
   language-neutral conformance fixtures (§22) — приёмочный тест backend.

| Слой | Что | Где |
|---|---|---|
| Контракт | Schemas, fixtures, conformance | `packages/api_contracts/schema/event_ingestion/v1/` |
| Backend | Pipeline, хранение, команды | `apps/backend/functions/src/modules/event_ingestion/` |
| Content | Event, ревизии, provenance, locks | `apps/backend/functions/src/modules/content/` (BCK-07) |
| Mobile | Управление источниками, очередь, provenance в Details | `apps/mobile/lib/features/event_sources/` + `app/adapters` |

---

## 4. Предпосылки и внешние зависимости

| ID | Предпосылка | Владелец | Этап |
|---|---|---|---|
| P1 | `Event.location.placeId?` + `eventRelations` роль `venue` → Place (Event spec §9, §15.2) — для всех Event, additive | BCK-07 + mobile Create | E3 |
| P2 | Content: `ContentProvenance.kind = ownerImport` (BCK-07 §7.4) и делегированный import-актор (BCK-07 §6). Event-источник (Event spec §3): `sourceRecords[]`, `fieldAuthority`, `fieldLocks[]` (только content-группа), `estimatedFields[]`, `freshness`, `verification`, `detachedAt?`, `mergedIntoEventId?`; валидатор отвергает правку operational-полей прикреплённого импорта | BCK-07 + Create UI | Входы delegated import уже в BCK-07 v0.7 §7.4 (`originBinding`); запрос по `externalBindingRef` и Content persistence slice — E3 |
| P3 | Опубликованный Place со стабильным ID | BCK-07 / BCK-08 | E3 |
| P4 | Запись `PagePlaceOperatorLink` ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §9.3: writer — BCK-06, сам Place — BCK-07), отдельно от самозаявленного `relationshipToPlace`, + события `identity.placeOperatorLinked`/`identity.placeOperatorUnlinked` | BCK-06 | E3 |
| P5 | Закрытый каталог BCK-06 (`capability.ts`): добавить `event_sources.manage`, `event_sources.review_changes`; staff — `moderate.event_sources`; отправка требует `content.submit`; постоянная делегация `EventIngestionDelegation` ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §9.2) вместо действий от Session | BCK-06 | E2 (mock), E3 |
| P6 | Event publication pipeline: Create §16 (`pendingReview` → moderation → `published`) + Discover projection с provenance-полями | BCK-07 / BCK-08 | E3 |
| P7 | Валидация JSON Schema в TS — **закрыто**: Ajv 2020 реестры по образцу `identity_schema_registry.ts` | BCK-03 | — |
| P8 | Media: серверный импорт внешнего изображения в обработанный asset с rights metadata; загрузка обложки по умолчанию | BCK-14 | E5 |

Зависимости без которых отдельные функции выключены: BCK-13 (уведомления),
BCK-22 (жалобы пользователей), OD-03, OD-09, OD-10, OD-11 (§1).

---

## 5. Product outcome

**Цель:** оператор заведения подключает официальный источник один раз;
события появляются, обновляются, переносятся и отменяются в Recharge без
ручного ввода, без дублей и без затирания данных Recharge.

Метрики (измеряются в production-когорте E7):

| Метрика | Цель |
|---|---|
| Дубли в ленте на одно реальное событие | 0 |
| Задержка «изменение времени на сайте → Recharge» при интервале 6 ч | ≤ 7 ч p95 |
| Ложные отмены | 0 |
| Доля импортированных событий, отправленных на модерацию без ручного дополнения полей | ≥ 80 % |
| Время подключения источника | ≤ 3 мин медиана |

**Non-goals V1:** обход интернета; соцсети; разбор HTML-вёрстки;
availability/sold-out и билетный inventory (владелец — BCK-16, Event spec
инвариант №11); Place-импорт; анонсы без даты (Event spec §1.3); Program
Items (ECL-06); платные сторонние сервисы; публикация без модерации.

---

## 6. Scope и версии источников

### 6.1. V1

- Реестр источников Place, мастер подключения, профиль импорта.
- Виды: **`ical`** и **`jsonLd`**.
- Плановая синхронизация, нормализация, sanity gate, сопоставление.
- Создание/обновление Event только через команды Content.
- Очередь проверки оператора и staff.
- Владение полями, content locks, detach, объединение источников.
- Health, история запусков, уведомления оператору.
- Provenance для пользователя: источник, свежесть, «Перенесено», «Отменено».

### 6.2. Позже (каждое — отдельный Approved slice)

| Вид | Условие |
|---|---|
| `rss` | Только ленты с датами события (модуль `ev:` RSS 1.0 или профиль сопоставления); обычный RSS несёт дату публикации, не события |
| `jsonFeed` | Документированный фид заведения + staff-настроенный профиль сопоставления |
| `ticketPlatform` | Это scope ECL-04/ECL-05 Event spec §23: provider ADR, коммерческий/юридический контракт, адаптер BCK-16; `origin = providerImported`; availability — BCK-16 |
| `htmlPage` | Требует решения по origin (Event spec §18.1 запрещает `scraped`) и Legal; только проверка человеком |
| `social` | D6; только официально разрешённый API |

### 6.3. Не входит

Импорт Place; перевод описаний (overlay или AI по ADR 0018 отдельно);
public API; синхронизация Booking.

---

## 7. Роли, capabilities, отзыв прав

| Роль | Capability | Может |
|---|---|---|
| `owner` / `manager` страницы оператора | `event_sources.manage` (exact page) | Подключать, настраивать, ставить на паузу, отключать источники своего Place; разбирать очередь; отправлять события |
| Роль для разбора очереди (в mobile — `editor`) | `event_sources.review_changes` (exact page) | Разбирать очередь, дополнять события; не управляет источниками. В бэкенде ролей editor нет (owner, manager, analyst, bookingManager) — в V1 capability получают owner и manager, отдельная роль — решение BCK-06 |
| Модератор Recharge | `moderate.event_sources` | Одобрять источники, ставить на паузу/отключать любой источник, видеть все очереди; **не** отправляет события от имени страницы (ADR 0016: Admin не является publisher/workspace) |
| Система | runtime identity `runtime-event-ingestion` | Только задачи §12 и команды §17.3 из allowlist; действует по постоянной делегации страницы, никогда от пользовательской Session |
| Пользователь | — | Видеть provenance, пожаловаться на неточность (BCK-22) |

Имена — по закрытому каталогу capabilities бэкенда BCK-06 (`content.create`,
`content.submit`, `content.publish`, `manage_page`; формат
`^[a-z][a-z0-9._-]{0,95}$`); mobile mock (E2) использует те же ID. Отправка
события от имени страницы требует у согласившегося участника
`event_sources.manage` **и** `content.submit` (право публикации Event,
Create §5.2).

**Делегация и отзыв (fail-closed, BCK-01 §13.1):** источник действует по
постоянной делегации страницы `EventIngestionDelegation` (writer — identity;
`delegationId`, точная страница, scope, `revision`, `expiresAtUtc`, отзыв —
[BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §9.2). Перед каждым эффектом worker проверяет: делегация
`active`, не истекла, ревизия совпадает, операция и Place входят в scope,
страница `active`, связь P4 активна, источник не `revoked`. Иначе источник
`paused` (`pauseReason: delegationInvalid`), `owner/manager` получают
`ReviewItem(ownershipChanged)`. Потеря членства у выдавшего делегацию →
делегация `suspended` до подтверждения другим owner/manager.

---

## 8. Модель данных

Идентификаторы — BCK-03 §10.1 (ULID); время — RFC 3339 UTC `Z` (§10.2);
локальные даты `YYYY-MM-DD` + IANA (§10.3); деньги `{minorUnits, currency}`
(§10.5). Enum закрытые и versioned; неизвестное значение — fail-closed.
Поля и enum — lowerCamelCase (BCK-03 §9 п.6); коды ошибок — snake_case как
`domainCode` (BCK-03 §14). В реализации поля времени получают суффикс `AtUtc`
(`createdAtUtc`, `nextRunAtUtc`), TTL — поле `expiresAt` (конвенция бэкенда).

### 8.1. EventSource

```text
EventSource
  id                   ULID
  placeId              ULID            // опубликованный Place (P3), D13
  marketId             LV | EE | LT    // рынок Place; флаги и capability — по рынку
  publisherRef         {type: page, id}// страница оператора по связи P4, фиксируется при подключении
  kind                 ical | jsonLd | rss | jsonFeed | ticketPlatform | htmlPage   // V1: ical, jsonLd
  url                  https URL, как ввёл человек (≤ 2048)
  canonicalUrl         §10.1
  status               pendingApproval | active | paused | failing | quarantined | revoked
  pauseReason?         manual | robotsDisallowed | accessDenied | delegationInvalid | pageInactive |
                       moderationCase
  moderationCaseRef?   string ≤ 128        // caseId BCK-22 при moderationCase; только ссылка, без данных жалобы
  publishMode          ownerReview | autoSubmit
  fieldScope           all | scheduleAndContent | commerceOnly
  syncIntervalMinutes  60 | 180 | 360 | 720 | 1440          // default 360
  importProfile        ImportProfile (§8.2)
  venueFilter?         {externalVenueId, label}
  authorization
    basis              ownerConsent | publicFeedTerms | partnerAgreement
    note               string ≤ 500
    imageRights        bool            // разрешено ли использовать изображения источника
    publicEndpointConfirmed bool       // человек подтвердил, что endpoint для публичного получения
    evidenceRevision   string          // версия текста согласия/условий, показанного человеку
    evidenceSha256     hex             // hash этого текста (как в reference-data source record)
    delegationId       ULID            // постоянная делегация страницы (identity)
    delegationRevision int
    grantedByUserId    ULID            // только аудит, не источник прав
    grantedAt          UTC
    approvedByStaffId? ULID
    approvedAt?        UTC
  health
    lastRunId?, lastSuccessAt?, lastAttemptAt?
    consecutiveFailures int
    lastErrorCode?      FetchErrorCode | ParseErrorCode (§12.9)
    baselineFutureCount? int           // медиана seenFuture 5 последних успешных runs
    nextRunAt           UTC
  httpCache            {etag?, lastModified?}
  lease                {owner?, until?}
  createdAt, updatedAt UTC
  revision             int
```

Инварианты:

1. `canonicalUrl` уникален среди не-`revoked` источников. Подключение уже
   подключённого фида к другому Place — `conflict / source_already_connected`.
2. Повторное подключение `revoked` источника с тем же `canonicalUrl` к тому
   же Place **реактивирует ту же запись** (тот же `id`) — идентичность
   записей §10.2 сохраняется.
3. Смена URL (фид переехал) — `eventIngestion.updateSource` с новым probe;
   `id` не меняется.
4. `status = active` требует: связь P4 активна, страница `active`,
   `authorization` заполнен; при `basis ≠ ownerConsent` — `approvedByStaffId`.
5. `pendingApproval` — если `basis ≠ ownerConsent` или выключен флаг
   `event-ingestion.staff-approval.skip` (по умолчанию выключен: staff
   одобряет каждое подключение).
6. `htmlPage` ⇒ `publishMode = ownerReview` (не настраивается).
7. Не более **5** не-`revoked` источников на Place (D2).
8. `syncIntervalMinutes ≥ 60`; сервер вправе увеличить фактический интервал
   (`Retry-After`, `Crawl-delay`, backoff).

### 8.2. ImportProfile — значения, выбранные человеком при подключении

Профиль — явное решение человека, поэтому значения из него не являются
«молчаливым выводом» (Create §10.3a, Event spec §22.2).

```text
ImportProfile
  contentLocale          BCP 47                    // OD-10
  eventArchetype         одно из 34 (Event spec §4)
  primaryParticipation   Event spec §5
  mainCategoryId         Category System ID
  subcategoryId          Category System ID
  criteriaDefaults?      значения required dynamic criteria подкатегории (Create §10.3)
  admissionPreset        openEntry | externalTickets | externalRegistration   // Event spec §21.2
  defaultDurationMinutes? int 15..1440             // обязателен, если probe нашёл события без окончания
  useSourceImages        bool                      // true только при authorization.imageRights
  altTextTemplate        string, подтверждён человеком, напр. «Афиша: {title}»
  shortDescriptionPolicy fromSourceText | ownerWrites   // D17: только дословная выдержка
```

Обложки по умолчанию нет: отсутствующее изображение остаётся отсутствующим
([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) BCK23-D12).

Изменение профиля действует только на **новые** события; уже созданные
меняются через обычное редактирование Event.

### 8.3. Переходы статуса EventSource

```text
(connect, basis=ownerConsent, без требования staff) ─────▶ active
(connect, иначе) ─────────────────────────────────────────▶ pendingApproval ──approve──▶ active
active ──pause──▶ paused ──resume──▶ active
active ──failures (§12.9)──▶ failing ──success──▶ active
active ──sanity gate (§12.8)──▶ quarantined ──releaseQuarantine──▶ active
active ──robots/401/403/410 ×3, delegationInvalid, pageInactive──▶ paused
любой ──revoke──▶ revoked (терминальный; кроме реактивации по инв. 2)
```

### 8.4. SyncRun

```text
SyncRun
  id, sourceId
  trigger        schedule | manual | connect | retry | quarantineReplay
  startedAt, finishedAt
  outcome        succeeded | notModified | failed | quarantined
  errorCode?
  http           {status, bytes, durationMs}
  counts         {seenFuture, created, updated, unchanged, cancelled, missing,
                  queuedForReview, rejectedInvalid, deferredByVelocity}
  adapterVersion string
  diffHash?      hash сводки отличий (только для quarantined, §12.8)
```

### 8.5. SourceEventRecord

```text
SourceEventRecord
  id                    ULID
  sourceId              ULID
  origin                apiSynced | providerImported
  providerRef           §10.2
  externalTenantId      §10.2
  externalEventId       string ≤ 512
  externalOccurrenceId  string ≤ 64    // "" для не-серийного события
  identityStrength      strong | weak
  eventId?              ULID            // присваивает Content
  occurrenceId?         ULID            // присваивает Content (BCK-02 §13: один набор ID)
  state                 pendingReview | tracked | rejected | missingFromSource |
                        cancelledAtSource | detached
  reviewRequired        bool            // открыт ReviewItem по этой связи
  pendingContentOperation? {operationKey, logicalOperation, payloadHash,
                        expectedRevision, attemptedAtUtc}   // сверка неизвестного исхода, BCK-23 §12
  lastPayloadHash       sha256 hex
  lastSnapshot          NormalizedEvent
  firstSeenAt, lastSeenAt, lastSeenRunId
  missingSinceAt?, consecutiveMissing int
  hiddenAsMissing       bool            // дата скрыта из-за пропажи (D4); это не отмена
  keepActive            bool            // команда выбрала «Не отменено»: не скрывать, пока запись не вернётся
  verificationStatus    unverified | providerVerified | organizerClaimed | staffVerified
  fetchedAt             UTC
```

`rejected` — оператор отклонил; повторно в очередь попадает только при
материальном изменении (§12.4) как `ReviewItem(previouslyRejectedChanged)`.

### 8.6. ReviewItem

```text
ReviewItem
  id, placeId, sourceId?
  kind        newEvent | needsCompletion | duplicateCandidate | missingFromSource |
              cancellationConflict | venueMismatch | fieldConflict | sourceQuarantined |
              ownershipChanged | previouslyRejectedChanged
  reasons[]   для needsCompletion: missingShortDescription | missingFullDescription |
              titleTooLong | missingCover | missingCriteria | dstConfirmation |
              ageRestricted | unknownPaymentCollection | tentativeStatus | onlineOrHybrid
  status      open | resolved | dismissed | superseded
  subject     {sourceEventRecordIds[], eventIds[]}
  evidence    типизирован по kind
  confidence? 0..1 (только duplicateCandidate)
  createdAt, resolvedAt?, resolvedBy?
  resolution? submit | completeInEditor | reject | merge | keepSeparate |
              confirmCancel | keepActive | applyRun | ignoreRun | reconfirmConsent
  revision
```

Одна открытая запись на `(kind, subject)`; повторные runs обновляют
evidence. `superseded` — ситуация разрешилась сама.

Кто разрешает: всё, что меняет Event (отправка, дополнение, объединение,
подтверждение отмены), — только участники страницы (`review`/`manage`).
Staff разрешает только `sourceQuarantined` и `ownershipChanged` и может
поставить источник на паузу; от имени страницы staff ничего не отправляет
(ADR 0016).

Очередь EVS — **не модерация**. Это шаг оператора до отправки; модерация
Recharge (Create §16.2, BCK-22) остаётся отдельной.

### 8.7. Классы данных (BCK-01 §12; сроки — предложения для BCK-04)

| Запись | Класс BCK-01 §12 | `DataClassRegistry` (id → classification) | Доступ | Хранение |
|---|---|---|---|---|
| EventSource | Protected | `event-ingestion.source` → `personal` | Участники страницы с capability, staff | Пока источник не revoked + срок доказательства согласия (BCK-04) |
| SyncRun | Operational | `event-ingestion.run` → `internal` | Сводка — участники, детали — staff | 90 дней, затем дневная статистика |
| SourceEventRecord | Operational | `event-ingestion.record` → `internal` | Backend; оператор — через projection | Пока существует Event |
| ReviewItem | Protected | `event-ingestion.review-item` → `personal` | Участники страницы, staff | 180 дней после resolve |
| Async-операция probe/sync | Operational | `event-ingestion.operation` → `internal` | Инициатор | 24 ч |
| Provenance в Event projection | Public / Derived | Content (BCK-07) | Все | Projection |

Полный список коллекций, классов и политик хранения — [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §6 и §10; политики
остаются `unresolved` в `RetentionRegistry` до решения BCK-04.

Сырые HTTP-ответы не хранятся. Логи — без тела ответа и без query-параметров
URL.

---

## 9. Адаптеры и нормализация

### 9.1. Контракт адаптера

Адаптер — чистая функция `bytes + AdapterContext → AdapterResult`, без сети.

```text
AdapterContext  {sourceKind, placeTimezone, horizonEnd, now}
AdapterResult
  events[]      NormalizedEvent  (≤ 1000 после горизонта)
  warnings[]    {externalEventId?, code}
  venues[]      {externalVenueId, label}
  feedMeta      {title?, timezone?, generator?}
```

### 9.2. `ical` (RFC 5545)

| Элемент | Правило |
|---|---|
| `UID` | `externalEventId` |
| `DTSTART` / `DTEND` / `DURATION` | Время; для all-day (`VALUE=DATE`) `DTEND` не включается |
| `RDATE`, `EXDATE`; простое `RRULE` (`FREQ=DAILY`/`WEEKLY`, `INTERVAL`, `COUNT`/`UNTIL`, `BYDAY` без номеров) | Развёртывание в экземпляры в пределах горизонта (§9.7) — V1 |
| Прочие `RRULE` (`MONTHLY`/`YEARLY`, `BYMONTHDAY`, `BYSETPOS`, `BYMONTH`, порядковые `BYDAY` и др.), `RECURRENCE-ID` | V1: вся серия → `ReviewItem(unsupportedRecurrence)`, автоматически не импортируется; поддержка — подэтап EVS-LOCAL-01c ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §4.1) |
| `VEVENT` без `UID` | Отклоняется (`missing_uid`) |
| `STATUS:CANCELLED` | Отмена события/экземпляра |
| `STATUS:TENTATIVE` | Событие не отправляется автоматически → `needsCompletion(tentativeStatus)` |
| `CLASS:PRIVATE` / `CONFIDENTIAL` | Событие пропускается |
| `TZID` + `VTIMEZONE` | IANA; Windows-имена → IANA по CLDR windowsZones |
| Floating time (без `TZID` и `Z`) | Часовой пояс Place |
| `LAST-MODIFIED` | `sourceUpdatedAt` |
| `URL`, `LOCATION`, `DESCRIPTION`, `SUMMARY`, `ATTACH` (image) | Ссылки, место, описание, название, изображение |

### 9.3. `jsonLd` (schema.org)

Источник — **только** блоки `<script type="application/ld+json">` (≤ 50 блоков,
≤ 1 MB на блок, ≤ 2 MB на страницу), объекты `Event` и подтипы (`MusicEvent`,
`TheaterEvent`, …), включая `@graph`. **Запрещены:** DOM scraping, визуальный
разбор HTML, извлечение из произвольной разметки (microdata, RDFa, видимый
текст), выполнение JavaScript, переход по ссылкам страницы.

| Свойство | Правило |
|---|---|
| `@id` → иначе `url` → иначе weak | `externalEventId` (§10.4) |
| `startDate`, `endDate` | Без смещения — часовой пояс Place |
| `eventStatus` | `EventScheduled`/`EventRescheduled` → scheduled; `EventPostponed` → postponed; `EventCancelled` → cancelled; `EventMovedOnline` → review `onlineOrHybrid` |
| `eventAttendanceMode` | `Online`/`Mixed` → review `onlineOrHybrid` |
| `offers` (`Offer`, `AggregateOffer`), `isAccessibleForFree` | Цена §11.3 |
| `performer` | Имена → `unlinkedCredits` (§11.2) |
| `organizer` | Не сохраняется (персональные данные) |
| `image` | Кандидат обложки (§11.5) |
| `typicalAgeRange` | Признак возраста → review `ageRestricted` (OD-11) |
| `subEvent` | **Program Items**, не occurrences (schema.org; Event spec §16, ECL-06) → V1 не импортируется, warning `program_items_not_supported`; родитель импортируется как одно событие |
| `eventSchedule` | V1 не поддерживается, warning `schedule_not_supported` |

### 9.4. Будущие виды

Правила `rss`, `jsonFeed`, `ticketPlatform`, `htmlPage` — в их собственных
slice specs (§6.2).

### 9.5. Probe — асинхронная операция (BCK-03 §28)

1. Канонизировать URL (§10.1), проверить политику URL ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §4.1:
   явные credentials и известные auth-параметры → `url_not_public`),
   уникальность и лимит.
2. robots.txt (RFC 9309) для `RechargeEventBot`.
3. GET по правилам §12.2.
4. Определить вид: `BEGIN:VCALENDAR` / `text/calendar` → `ical`; HTML с
   `application/ld+json` Event → `jsonLd`.
5. HTML без Event-разметки: искать `<link rel="alternate"
   type="text/calendar">`, ссылки `.ics`/`webcal://` → `betterSourceSuggestion`.
6. Прогнать адаптер: до 5 ближайших будущих событий в виде карточек Event,
   warnings, `venues[]`, доля событий без окончания, без цены, без
   изображения, без описания — чтобы человек заполнил профиль импорта.

Probe — async-операция `platform/v1/async_operation` (`operationType:
eventIngestion.probeSource`). Результат хранится на сервере 30 минут;
`connectSource` принимает только `probeOperationId` инициатора и сам читает
результат — `kind`/preview от клиента не принимаются, подписывать нечего
(ключ подписи не нужен).

### 9.6. NormalizedEvent

```text
NormalizedEvent
  externalEventId, externalOccurrenceId
  title               string ≤ 300               // ограничения Event — §11.4
  descriptionRich?    allowlist-блоки (абзац, список, ссылка https, выделение) ≤ 50 000 символов
  startLocal          YYYY-MM-DDTHH:mm или YYYY-MM-DD при allDay
  endLocal?
  allDay              bool
  sourceTimezone?     IANA | null (floating)
  startUtc, endUtc?   RFC 3339 Z
  dstResolution       none | gapShiftedForward | overlapEarlierOffset
  status              scheduled | tentative | cancelled | postponed | unknown
  attendance          offline | online | mixed | unknown
  location            {externalVenueId?, name?, address?, geo?}
  price               {knowledge: known | unknown,
                       kind?: free | exact | from,
                       amount?: {minorUnits, currency}}
  ticketUrl?, eventUrl?, imageUrl?   https
  performers[]        {name ≤ 200} (≤ 20)
  categoryHint?       ≤ 200
  ageHint?            ≤ 50
  sourceUpdatedAt?    UTC
```

### 9.7. Правила нормализации (fail-closed; инвариант №12)

- Нет цены → `knowledge = unknown`. `free` — только при явном признаке
  (`isAccessibleForFree: true` или цена 0 с валютой).
- Нет даты → событие отбрасывается (`missing_start`); анонс без даты не
  является Event (Event spec §1.3, Create §11.4).
- Нет времени начала → `allDay = true`.
- Прошедшие экземпляры (начало ≤ now) не импортируются (Create §11.4:
  start в будущем на момент Publish).
- Горизонт развёртывания серий — **тот же server config rolling horizon**,
  что у серий Event (Create §11.6); предлагаемое значение по умолчанию —
  180 дней. Лимит экземпляров на одну команду Content защищает
  инфраструктуру и не обрезает серию: остаток приходит в следующих runs по
  мере движения горизонта.
- URL не-https отбрасывается с warning; `javascript:`/`data:` — всегда.
- HTML описания санитизируется в allowlist; скрипты, стили, iframe
  удаляются.

### 9.8. Время и часовые пояса

- UTC вычисляется по часовому поясу источника (`TZID`/`VTIMEZONE`/смещение);
  floating и JSON-LD без смещения — по часовому поясу Place.
- `Event.timezoneId = Place.timezoneId`. Если смещение источника в момент
  события отличается от смещения Place — `ReviewItem(venueMismatch)`.
- Несуществующее локальное время (DST gap) и двусмысленное (overlap)
  интерпретируются по RFC 5545 §3.3.5 (gap — смещение до перехода, overlap —
  первое наступление; это совпадает с `shiftForward`/`earlierOffset` Create),
  но Create §11.6 требует подтверждения человеком → событие не отправляется
  автоматически, `needsCompletion(dstConfirmation)`.

---

## 10. Идентичность

### 10.1. Канонизация URL источника

Lowercase scheme/host; `webcal://` → `https://`; удалить порт 443, fragment,
`utm_*`, `fbclid`, `gclid`; отсортировать query; нормализовать завершающий
`/`. Только `https`.

### 10.2. Ключ Event spec §18.2

| kind | providerRef | externalTenantId | externalEventId | externalOccurrenceId |
|---|---|---|---|---|
| ical | `feed.ical` | `EventSource.id` | `UID` | §10.3 |
| jsonLd | `feed.jsonLd` | `EventSource.id` | `@id` / канонический `url` / weak | `""` |
| ticketPlatform (позже) | `ticket.<providerId>` | ID площадки/организации у провайдера | ID события провайдера | ID показа провайдера |

`externalTenantId = EventSource.id` делает ключ устойчивым к смене URL и
домена (инв. 2–3 §8.1).

`jsonLd`: если в одном ответе один `@id`/`url` встречается у нескольких
объектов с разными датами, эти записи получают `externalOccurrenceId =
startUtc` и `identityStrength = weak` (без автоматической отправки), warning
`duplicate_id_in_feed`.

### 10.3. Экземпляры серий

- Не-серийное событие: `externalOccurrenceId = ""`.
- Экземпляр серии: исходное начало экземпляра — значение, которое имел бы
  `RECURRENCE-ID` (RFC 5545): RFC 3339 UTC, для all-day — `YYYY-MM-DD`.
  Изменённый экземпляр (`RECURRENCE-ID`) сохраняет ключ → перенос одного
  показа — это обновление, а не новое событие (поддержка `RECURRENCE-ID` —
  подэтап 01c; в V1 такая серия уходит в review).
- Ключ идентичности связи: `bindingKey = sourceId + externalUid +
  recurrenceKey` (`recurrenceKey` = `externalOccurrenceId`); автоматически
  одним событием считаются только записи с одинаковым `bindingKey`.
- **Сдвиг серии** (изменились `DTSTART`/`RRULE`, ключи всех экземпляров
  изменились): внутри одного `UID` непарный «исчезнувший» и непарный «новый»
  экземпляр с **той же локальной датой** считаются одним показом →
  `reschedule` с переключением ключа записи (Create §17.3: ID не
  переиспользуются для семантически других occurrences). Несколько
  кандидатов на одну дату → `ReviewItem(fieldConflict)`.

### 10.4. Weak identity

Без стабильного ID: `"w:" + sha256(канонический eventUrl)`, иначе
`"w:" + sha256(localDate + "|" + normalizedTitle)`. `weak` ⇒ событие не
отправляется автоматически (`ownerReview` для этого события). Исчезновение
weak-записи при появлении похожей в тот же день (title similarity ≥ 0.8) →
`duplicateCandidate`, а не missing + new.

### 10.5. Хранение уникальности

`SourceEventRecord.id` — ULID. Уникальность ключа §10.2 — отдельный
lock-документ с ID `sha256(ключ)`, создаваемый в одной транзакции с записью
(тот же приём, что для `canonicalUrl`).

---

## 11. Отображение в Event

### 11.1. Принцип

Импортированное Event проходит **ту же publish-валидацию**, что и созданное
вручную (Create §15). Значения берутся: из источника — только operational и
content (§14.1); из профиля импорта — классификация и admission; из Place —
локация. Если обязательное значение нельзя получить честно — Event создаётся
как `draft` для дополнения (§13.2), ничего не выдумывается.

### 11.2. Оси Event

| Ось (Event spec) | Значение |
|---|---|
| `eventArchetype`, `participationModes` | Профиль (§8.2); не выводятся из категории |
| `mainCategoryId`/`subcategoryId` | Профиль; `categoryHint` может выбрать другую подкатегорию только через staff-таблицу `event_source_category_map` (BCK-20), где каждая строка — явное решение |
| Required dynamic criteria | `criteriaDefaults` профиля; иначе `needsCompletion(missingCriteria)` |
| `eventFormat` | `offline`; `online`/`mixed` → `needsCompletion(onlineOrHybrid)` |
| `physicalLocation` | `{kind: placeRef, placeId}`; адрес и geo из Place |
| `eventRelations` | `venue` → Place (создаётся один раз) |
| `unlinkedCredits` | Исполнители: `{displayName, role: performer, claimStatus: unclaimed}` (Event spec §15.2) |
| `scheduleMode` | `oneTime` или `multiDate` (D14, §11.6) |
| `admissionMode`/`registrationMode`/`confirmationMode` | Preset профиля: `openEntry` → openEntry + none + none; `externalTickets` → ticket + external + providerManaged; `externalRegistration` → rsvp + external + providerManaged |
| handoff URL | `ticketUrl`, иначе `eventUrl`; https обязателен (Event spec §19 п.4); для `external*` без URL → `needsCompletion` |
| `capacityMode` / `inventoryAuthority` | `unknown` / `none` (Event spec §13; `externalProvider` — только ticketPlatform через BCK-16) |
| `visibility` | `public` |
| Аудитория | `ageHint` или признак 18+ → `needsCompletion(ageRestricted)` до OD-11 |
| Язык | `importProfile.contentLocale` |
| `hostingModel` | Не задаётся (опциональная аналитическая projection, Event spec §15.4) |

### 11.3. Цена (Event spec §12.2 и §19)

| Источник | `pricingMode` | `price` | `priceKnowledge` | `priceDisplay` | `paymentCollectionMode` |
|---|---|---|---|---|---|
| Явно бесплатно | `free` | null | known | — | `none` (Event spec §19 п.11) |
| Одна цена | `fixed` | Money > 0 | known | `exact` | `external` при preset `external*`; `onsite` при `openEntry` |
| Диапазон / «от» | `fixed` | нижняя цена | known | `from` | как выше |
| Нет цены | **отсутствует** (§12.2: до подтверждения) | null | unknown | — | `external` при preset `external*`; при `openEntry` → `needsCompletion(unknownPaymentCollection)` |

`externalPricePolicy = informational` для всех видов V1 (`providerSynced` —
только ticketPlatform). `ticketTypes` не используется (Event spec §19 п.13 требует
inventory). Цена, ссылка на билеты — provider-owned (Event spec §18.3).

### 11.4. Обязательные поля публикации (Create §10.2)

| Поле | Требование | Импорт |
|---|---|---|
| Title | 3–100 символов | > 100 → `needsCompletion(titleTooLong)`; < 3 → событие невалидно |
| Short description | 20–240 | `fromSourceText`: первые целые предложения описания ≤ 240; < 20 → `missingShortDescription`; `ownerWrites` → всегда дополнение |
| Full description | 50–20 000, allowlist rich text | Из `descriptionRich`; < 50 → `missingFullDescription` |
| Cover | Обработан, alt text, rights | §11.5 |
| Archetype, participation, category, criteria | Обязательны | Профиль |

### 11.5. Изображения

- Изображение источника используется, только если `useSourceImages` и
  `authorization.imageRights`: backend скачивает его и передаёт в Media
  (BCK-14, P8) как обработанный asset с rights metadata
  (`source = eventSource`, `basis`); alt text — `altTextTemplate`.
- Иначе изображения нет: оно остаётся отсутствующим, событие получает
  `needsCompletion(missingCover)` и проходит обычную проверку (обложки по
  умолчанию нет).
- Hotlink внешних изображений запрещён: он раскрывает IP пользователей
  третьим сторонам и не проходит обработку/модерацию Media (Create §10.4).

### 11.6. Серии (D14)

Серия источника импортируется как **один Event `multiDate`**, экземпляры
которого материализует источник; своё recurrence rule Recharge не выводит.
Причина: расписание — provider-owned (Event spec §18.3), а пересчёт чужого
`RRULE` правилами Recharge дал бы расхождения. Одна запись §8.5 на
экземпляр; все записи одного `UID` ссылаются на один `eventId`. Появление
нового экземпляра при движении горизонта — добавление occurrence, т.е.
material revision (Create §11.6, Event spec §13.5).

---

## 12. Pipeline синхронизации

### 12.1. Схема

```text
scheduler ─▶ источники status ∈ {active, failing}, nextRunAt ≤ now ─▶ task per source
task: lease ─▶ revocation re-check (§7) ─▶ fetch ─▶ adapter ─▶ normalize/validate
      ─▶ sanity gate ─┬─ fail ─▶ quarantine (diffHash, ничего не применяется)
                      └─ pass ─▶ reconcile per record ─▶ Content commands / ReviewItem / record update
      ─▶ finish run (SyncRun, health, nextRunAt)
```

### 12.2. Fetch

- Только `https`, порт 443. На источник — точный allowlist (хост, путь,
  `GET`), фиксируется при probe и одобрении (модель BCK-16 §11/§25);
  редирект только на адрес из allowlist, иначе `redirect_not_allowlisted` и
  `ReviewItem` «адрес источника изменился» с повторным probe.
- SSRF: после DNS-резолва запрет private, loopback, link-local, CGNAT,
  multicast, metadata-адресов (IPv4 и IPv6); соединение — на проверенный IP
  (защита от DNS rebinding).
- Таймауты: 10 с соединение, 30 с всего; тело ≤ 5 MB (`ical`), ≤ 2 MB (HTML).
- `User-Agent: RechargeEventBot/1.0 (+https://<домен Recharge>/bot)`.
- Conditional GET (`If-None-Match`, `If-Modified-Since`); `304` ⇒
  `notModified`: сопоставление не выполняется, счётчики пропажи не растут.
- robots.txt (RFC 9309), кеш 24 ч; нестандартный `Crawl-delay` учитывается,
  если указан.
- `429`/`503` + `Retry-After` — следующий run не раньше указанного.
- Не более одного одновременного запроса на host.

### 12.3. Разбор и валидация

Невалидные события отбрасываются поштучно (`rejectedInvalid`) и не валят
run. Если невалидны > 50 % — `parse_mostly_invalid`, run `failed`.

### 12.4. Классы изменений

`lastPayloadHash` — sha256 канонической сериализации NormalizedEvent
(сортированные ключи, нормализованные деньги и время). Совпадение ⇒
`unchanged`.

| Изменение | Класс | Материальное |
|---|---|---|
| `startUtc`, `endUtc`, `allDay`, часовой пояс | `operationalSchedule` | да |
| Место (другое venue/адрес, online) | `venueChange` → только review (§16.2) | да |
| `status → cancelled` | `operationalCancellation` | да |
| `status → postponed` | `operationalPostponement` → review | да |
| Цена, ссылка на билеты | `commercial` | да (Create §17.2: «цена и условия регистрации») |
| Title, описание, изображение | `contentMinor` / `contentMajor` (§13.3) | `contentMajor` — да |
| Исполнители | `contentMinor` | нет |
| Новый экземпляр серии | `occurrenceAdded` | да |

### 12.5. Сопоставление — таблица решений

Для каждого события ответа (после `venueFilter`, только будущие экземпляры).
Строки проверяются сверху вниз; применяется первая совпавшая.

| Состояние записи | Условие | Действие |
|---|---|---|
| нет | точное совпадение с записью другого источника (§15.1) | Запись `pendingReview`, `ReviewItem(duplicateCandidate)` с evidence `exact`; автоматического прикрепления нет |
| нет | кандидат в дубли (§15.2) | Запись `pendingReview`, `ReviewItem(duplicateCandidate)`; Event не создаётся |
| нет | место не совпадает (§16.2) | Запись `pendingReview`, `ReviewItem(venueMismatch)` |
| нет | `ownerReview` или weak identity | Запись `pendingReview`, `ReviewItem(newEvent)` (с причинами `needsCompletion`, если есть); Event не создаётся до решения оператора: «Отправить» → черновик + `submitForReview`, «Дополнить» → черновик без отправки (§17.3) |
| нет | `autoSubmit`, strong, все поля §11.4 есть | Черновик и отправка на модерацию: `content.createDraft` → `saveDraftRevision` → `bindPublisher` → `submitForReview` (§17.3) |
| нет | `autoSubmit`, не хватает полей | Черновик без отправки (`createDraft` → `saveDraftRevision` → `bindPublisher`) + `ReviewItem(needsCompletion)` |
| tracked | hash не изменился | `unchanged` |
| tracked | изменения только в группах без authority источника (§14.2) | Обновить snapshot |
| tracked | изменение | Кандидат от текущей публичной ревизии (`content.saveDraftRevision` + `submitForReview`) с классом §12.4 (§17.3) |
| tracked | `status → cancelled` | §12.7 |
| pendingReview | изменился | Обновить evidence открытого ReviewItem |
| rejected | материальное изменение | `ReviewItem(previouslyRejectedChanged)` |
| rejected | иначе | Игнорировать |
| missingFromSource | снова в ответе | `tracked`, `reviewRequired = false`, `consecutiveMissing = 0`, `keepActive = false`; если дата скрыта — `restoreOccurrence`, она снова видна (§12.6); ReviewItem(missingFromSource) → `superseded` |
| cancelledAtSource | снова scheduled | `ReviewItem(fieldConflict)`; автоматическая «отмена отмены» запрещена |
| detached | любое | Обновить snapshot; Event не трогается |

### 12.6. Отсутствующие записи

Только при `outcome = succeeded` (не `notModified`) и только для будущих
экземпляров; строки проверяются сверху вниз:

| Условие | Действие |
|---|---|
| Экземпляр уже прошёл | Ничего: прошедшие даты уходят из источника штатно |
| `keepActive = true` | `consecutiveMissing++`; дата остаётся видимой |
| Отсутствует в 1 успешном run | `consecutiveMissing++`, `missingSinceAt`; Event не трогается |
| Отсутствует во 2-м успешном run подряд (D4) | `missingFromSource`, `hiddenAsMissing = true`, `reviewRequired = true`, `ReviewItem(missingFromSource)`; дата скрывается из показа (`hideOccurrence`) — **без** отмены и без уведомлений |

Условия «24 ч» нет: скрытие обратимо. Массовую пропажу раньше ловит sanity
gate (§12.8): run уходит в quarantine, ничего не скрывается.

Разбор `ReviewItem(missingFromSource)` командой заведения:

- «Подтвердить отмену» (`confirmCancel`) → отмена через Content, как в §12.7:
  пометка «Отменено», уведомления отметившим (D7);
- «Не отменено — показывать» (`keepActive`) → `restoreOccurrence`,
  `keepActive = true`: дата снова видна и больше не скрывается, пока запись
  не вернётся в источник;
- дата вернулась в источник → `restoreOccurrence` автоматически (§12.5),
  ReviewItem → `superseded`.

Скрытие в Content — `content.hide` с причиной `sourceMissing`, если у Event
нет других видимых будущих дат, иначе обратимое скрытие одной даты
`multiDate`; возврат — `content.restoreVisibility` (§17.3). Это не санкция
модерации: скрытие снимает EVS без модератора.

Исчезновение **никогда** не отменяет событие: отменяют только явный статус
источника (§12.7) или команда заведения.

### 12.7. Отмена

- Явная отмена (D8): единственный источник с authority на schedule явно
  отменил (`STATUS:CANCELLED` §9.2, `EventCancelled` §9.3) → кандидат с
  отменённым показом (класс `operationalCancellation`, §17.3); применяется
  сразу с post-moderation и уведомлениями отметившим (D7, Create §17.2 п.3);
  Content порождает факт `EventOccurrenceCancelled` (BCK-07 §35). Действует
  с пилота (E6), а не с E8.
- Флаг `event-ingestion.cancellation.auto` включается вместе с
  `event-ingestion.sync`. Его выключение — аварийный режим: любая отмена из
  источника → `ReviewItem` с действием «Подтвердить отмену».
- Массовые отмены ловит sanity gate (§12.8 п.4): run уходит в quarantine.
- Другой источник с authority на schedule показывает `scheduled` →
  `ReviewItem(cancellationConflict)`, Event не отменяется.
- Отмена всей серии: будущие экземпляры отменяются, Event архивируется
  (Create §17.3) — выполняет Content.

### 12.8. Sanity gate (D5)

Run → `quarantined`, **ничего не применяется**, если (`seenFuture` — число
будущих экземпляров после `venueFilter`; `baseline` — медиана `seenFuture`
пяти последних `succeeded` runs):

1. `baseline ≥ 4` и `seenFuture < 0.5 × baseline`;
2. `seenFuture = 0` и `baseline ≥ 1`;
3. ≥ 4 отслеживаемых будущих экземпляров и > 50 % из них получили
   `operationalSchedule` в одном run;
4. ≥ 4 отслеживаемых будущих экземпляров и > 3 отмен в одном run.

Run сохраняет сводку отличий и её hash (`diffHash`); сами данные не
хранятся — Storage не нужен. `ReviewItem(sourceQuarantined)` показывает
сводку; «Применить» запускает повторный run с `approvedDiffHash`: изменения
применяются, только если новая сводка совпадает с одобренной, иначе — новый
quarantine. «Игнорировать» закрывает run. Три quarantined runs подряд —
уведомление модератору.

### 12.9. Ошибки, backoff, свежесть

```text
FetchErrorCode: dns_failed | connect_timeout | tls_error | http_4xx | http_5xx |
                too_large | robots_disallowed | ssrf_blocked | redirect_limit |
                redirect_not_allowlisted |
                rate_limited | not_https
ParseErrorCode: unsupported_format | parse_failed | parse_mostly_invalid |
                venue_filter_empty
```

- Backoff: 15 мин → 1 ч → 3 ч → 6 ч → интервал источника; максимум 24 ч.
- `consecutiveFailures ≥ 4` и ≥ 24 ч без успеха → `failing` + уведомление.
- `robots_disallowed`, `http 401/403/410` три раза подряд → `paused`
  (`robotsDisallowed`/`accessDenied`), без автоматического возобновления.
- **Свежесть:** `fresh`, если `now − lastSuccessAt ≤ max(3 × интервал, 24 ч)`
  (`notModified` — тоже успех); иначе `stale`. При `stale` цена и ссылка на
  билеты показываются с пометкой «уточняйте у организатора» (Event spec
  §13.4, RSK-04).
- `failing` > 30 дней → `ReviewItem` модератору «Отключить источник?».

### 12.10. Планирование и конкуренция

- Scheduler раз в 5 мин, порции ≤ 50 источников; jitter ±10 %.
- Lease 10 мин — один run на источник.
- `syncSourceNow` — не чаще раза в 10 мин на источник.
- Эффекты идемпотентны по `(runId, recordKey)`; повтор run после сбоя
  безопасен.
- Лимит скорости публикации Create §15 (`100/day`) применяется к Publisher
  источника (BCK23-D16 принято; механизм лимита — BCK-07): превышение
  переносится в следующие окна (`deferredByVelocity`), ближайшие по дате —
  первыми.

---

## 13. Публикация и ревизии

### 13.1. Режимы

| Режим | Новое событие |
|---|---|
| `ownerReview` (по умолчанию) | Ждёт в очереди EVS; оператор нажимает «Отправить» → стандартная модерация Recharge |
| `autoSubmit` | Отправляется в стандартную модерацию без участия оператора (`pendingReview`, Create §16) |

Прямая публикация без модерации (`published` сразу) — только по политике
BCK-07 §8.4: принятая политика type/market/publisher, серверный флаг, точная
capability (в каталоге BCK-06 — `content.publish`) и свежий access (D15,
решение владельца и Trust & Safety); сейчас выключено.

### 13.2. Дополнение (`needsCompletion`)

Если не хватает обязательного значения (§11.4, причины §8.6), Event
создаётся как `draft` от имени страницы; оператор открывает его в обычном
редакторе Event, дополняет и отправляет по Create §16. Operational-поля в
редакторе read-only (§14.1).

### 13.3. Изменения уже опубликованного события (Create §17.2)

EVS только присваивает класс (§12.4); политику применяет Content:

| Класс | Политика |
|---|---|
| `operationalSchedule`, `operationalCancellation` | Сразу, post-moderation, уведомления подписчикам (§17.2 п.3) |
| `contentMinor` | Сразу с audit (§17.2 п.2) |
| `contentMajor` | Pre-moderation; до одобрения видна прежняя revision (§17.2 п.4) |
| `commercial` | По revision policy Content для «цены и условий регистрации»; на Booking не влияет (внешняя продажа) |
| `occurrenceAdded` | Material revision (Create §11.6); возврат в Discover — по revision/moderation policy |
| `venueChange`, `operationalPostponement` | Не применяется автоматически — review |

`contentMajor`: изменение title (нормализованное расстояние
Левенштейна > 20 % длины), замена изображения, изменение описания > 20 %
символов; иначе `contentMinor`. Пороги — предложение, подтверждает владелец
модерации.

### 13.4. Отправка от имени страницы

Service actor вызывает команды Content от имени `EventSource.publisherRef`
только после проверки отзыва (§7). Publisher никогда не меняется
автоматически (Event spec §15.1).

---

## 14. Владение полями и правки человека

### 14.1. Группы полей

| Группа | Поля | Владелец | Правка в Recharge |
|---|---|---|---|
| **operational** | Расписание экземпляров, статус отмены, цена/`priceKnowledge`/`priceDisplay`, ссылка на билеты | Источник (Event spec §18.3 providerOwned) | **Запрещена**, пока событие прикреплено (Create §15 п.18). Исправить — в источнике или отвязать событие (§14.5) |
| **content** | Title, short/full description, обложка, `unlinkedCredits` | Источник по умолчанию | Разрешена; правка закрепляет поле (FieldLock), синхронизация его пропускает и показывает «В источнике: …» |
| **overlay** | Категория, подкатегория, теги, criteria, archetype, participation, localized editorial summary, recommendation facets, Scenario suitability, аудитория | Recharge | Разрешена всегда; синхронизация не трогает (Event spec §18.3 rechargeOverlay) |
| **location** | `placeId`, адрес, geo | Place | Через Place |

### 14.2. Authority по `fieldScope`

| fieldScope | operational: расписание/отмена | operational: цена/ссылка | content |
|---|---|---|---|
| `all` | ✔ | ✔ | ✔ |
| `scheduleAndContent` | ✔ | — | ✔ |
| `commerceOnly` | — | ✔ | — |

### 14.3. Несколько источников

Для поля с несколькими претендентами: `ical > jsonLd` (расписание, content);
для цены/ссылки — `ticketPlatform > ical > jsonLd`. Равные по рангу и
расходящиеся два run подряд → `ReviewItem(fieldConflict)`; до решения
действует значение источника, подключённого раньше.

### 14.4. Content locks

Снять закрепление может участник с `event_sources.review_changes` или
`content.create`/`content.submit`; после снятия следующий run применяет значение источника.

### 14.5. Detach

«Отвязать от источника» (подтверждение: «событие больше не будет
обновляться»): все группы переходят человеку, записи → `detached`,
`provenance.detachedAt` заполнен, `origin` не меняется (неизменяем).
Повторная привязка — только через объединение (§15.3).

---

## 15. Дубли и объединение

### 15.1. Точные совпадения между источниками — только кандидаты (V1)

Автоматически одним событием считаются только записи с одинаковым
`bindingKey` (`sourceId + externalUid + recurrenceKey`). Совпадения между
**разными** источниками того же Place в ту же локальную дату — тот же `UID`
(RFC 5545), канонический `ticketUrl` равен `externalBookingUrl` Event,
канонический `eventUrl` равен `eventUrl` другой записи — создают только
`ReviewItem(duplicateCandidate)` с evidence `exact` и объединяются одним
нажатием человека. Автоматическое объединение в V1 выключено.

### 15.2. Кандидат в дубли (только человек)

Сравнение со **всеми** Event того же Place, включая созданные вручную (для
Event без `placeId` — geo ≤ 150 м от Place): |Δ начала| ≤ 90 мин **и**
(title similarity ≥ 0.6 по нормализованным триграммам **или** общий
исполнитель). `confidence = 0.4·время + 0.4·title + 0.2·исполнитель`.
Новый Event не создаётся до решения.

### 15.3. Решения

- `merge` — запись прикрепляется к выбранному Event; provenance и все
  source records сохраняются; PublisherRef не меняется. Если оба Event уже
  существовали — второй архивируется с `mergedIntoEventId` и redirect
  deep link (новая команда Content «объединить», [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §7.2).
- `keepSeparate` — создаётся новый Event; пара запоминается, повторный
  кандидат для неё не создаётся.

---

## 16. Publisher и привязка к Place

### 16.1. Publisher (D1)

- V1: источник подключается **только** к Place с проверенной связью P4 со
  страницей оператора. `publisherRef` = эта страница, выбирается явно при
  подключении человеком с `event_sources.manage`; это не
  автоматическое присвоение по роли venue (Event spec §15.1).
- Place без страницы оператора в V1 не поддерживается. Вариант «служебная
  страница Recharge» отложен: Event spec §15.1 запрещает Admin становиться
  publisher автоматически, ADR 0016 — Admin как publisher/workspace; нужен
  отдельный ADR.
- Самозаявленное `relationshipToPlace` и `publisherRef` Place-черновика
  владения не доказывают.

### 16.2. Место

- `location.placeId = source.placeId` (P1); адрес и geo — из Place (P3).
- `venueFilter` обязателен, если probe нашёл > 1 площадки.
- Событие явно в другом месте (другой `externalVenueId` или geo дальше 300 м
  от Place) → `ReviewItem(venueMismatch)`.

### 16.3. Смена оператора

- Связь P4 деактивирована → все источники Place `paused` (`pageInactive`).
- У Place подтверждена другая страница → новые источники подключает она;
  старые остаются `paused` до `revoke`/передачи; PublisherRef существующих
  Event не меняется (явная `content.transferPublisher` с audit — только по
  решению обеих сторон и staff).

---

## 17. Команды, запросы, события

Envelope, ошибки, идемпотентность — BCK-03 §12–§17. Префикс команд —
домен `eventIngestion` (BCK-03 §15: тип команды принадлежит одному домену).

### 17.1. Команды EVS

| Команда | Actor | Payload | Коды домена |
|---|---|---|---|
| `eventIngestion.startProbe` | manage | `placeId`, `url` | `invalid_url`, `not_https`, `source_already_connected`, `source_limit_reached`, `rate_limited` |
| `eventIngestion.connectSource` | manage | `probeOperationId`, `delegationId`, `publishMode`, `fieldScope`, `syncIntervalMinutes`, `importProfile`, `venueFilter?`, `authorization{basis, note, imageRights, publicEndpointConfirmed}` → `{sourceId, status, sourceRevision, initialSyncOperationId?}` (первая синхронизация асинхронно, [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §7.1.1) | `probe_expired`, `delegation_invalid`, `authorization_required`, `public_endpoint_not_confirmed`, `import_profile_invalid`, `place_not_eligible`, `page_link_required` |
| `eventIngestion.updateSource` | manage | `sourceId`, `expectedRevision`, изменения; новый URL — только с `probeOperationId` | `stale_revision`, `probe_expired` |
| `eventIngestion.pauseSource` / `resumeSource` | manage, staff | `sourceId`, `expectedRevision` | `stale_revision` |
| `eventIngestion.revokeSource` | manage, staff | `sourceId`, `expectedRevision`, `reason` | |
| `eventIngestion.approveSource` | staff | `sourceId`, `expectedRevision` | |
| `eventIngestion.syncSourceNow` | manage | `sourceId` | `rate_limited` |
| `eventIngestion.releaseQuarantine` | manage, staff | `sourceId`, `runId`, `apply` | `quarantine_expired` |
| `eventIngestion.resolveReviewItem` | review, manage, staff (по kind) | `reviewItemId`, `expectedRevision`, `resolution`, `targetEventId?` | `resolution_not_allowed`, `stale_revision` |

Начальная callable-поверхность сокращена до 7 функций ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §7.1):
pause/resume/revoke/approve — одна команда `changeEventSourceStateV1`,
quarantine — через `resolveEventIngestionReviewItemV1`; изменение настроек,
«проверить сейчас» и история runs отложены. Окончательный список — после
owner approval таблицы BCK-23.

### 17.2. Асинхронные операции (BCK-03 §28)

`startProbe` и `syncSourceNow` возвращают `operationId`; состояние —
`accepted | running | succeeded | failed | cancelled`; результат probe —
`resultRef` на серверный результат с preview. Схема —
`platform/v1/async_operation.schema.json`, `operationType`:
`eventIngestion.probeSource`, `eventIngestion.syncSource`. `accepted` не
означает успех.

### 17.3. Команды Content (BCK-07 v0.7) от делегированного import-актора

Новых «импортных» команд Content не вводится: EVS вызывает существующий набор
BCK-07 §9 от нового актора «делегированный import за точную страницу по
записанному согласию» (добавляется в BCK-07 §6) с
`ContentProvenance.kind = ownerImport` (BCK-07 §7.4).

| Действие EVS | Команды BCK-07 |
|---|---|
| Новое событие | `content.createDraft` → `content.saveDraftRevision` → `content.bindPublisher` (origin `delegatedImport`) → `content.submitForReview` (для `autoSubmit` или по кнопке оператора) |
| Скрыть пропавшую дату и вернуть её (§12.6) | `content.hide` с причиной `sourceMissing` (у Event нет других видимых будущих дат) или обратимое скрытие одной даты `multiDate`; возврат — `content.restoreVisibility`. Сейчас в BCK-07 `content.hide` — команда модерации, скрытия одной даты нет: нужна поправка BCK-07 ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §7.2, §23) |
| Изменение опубликованного (перенос, отмена, цена, текст, новый показ) | `content.saveDraftRevision` кандидата от текущей публичной ревизии (BCK-07 §8.3) + `content.submitForReview`; review policy получает класс изменения §12.4 |
| Активация | `content.activateRevision` — только review/direct policy BCK-07, не EVS |
| Отвязать от источника | `content.correctProvenance` или новая мелкая команда ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §7.2) |
| Объединить дубли | Новая мелкая команда Content: архив второго + `mergedInto` + redirect |

Идемпотентность — ключ записи источника и `runId + recordKey`. Переносы и
отмены порождают существующие факты Event → Booking (BCK-07 §35):
`EventMateriallyRescheduled`, `EventOccurrenceCancelled`. Закрепление
content-полей и отказ править operational-поля выполняет валидатор
Event-источника (P2).

Команды человека: закрепление/снятие закрепления content-поля, отвязка,
передача publisher — через редактор Event и BCK-07.

### 17.4. Запросы

| Запрос | Кто | Возвращает |
|---|---|---|
| `eventIngestion.listSources` | review, manage, staff | Источники Place + health |
| `eventIngestion.getSource` | review, manage, staff | Детали + 20 последних runs |
| `eventIngestion.listRuns` | manage, staff | Runs, cursor |
| `eventIngestion.listReviewItems` | review/manage (свой Place), staff (все) | Фильтры `placeId`, `kind`, `status` |
| `eventIngestion.getOperation` | инициатор | Состояние async-операции |

Списки — cursor page по BCK-03 §19 ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §7.1.1): `pageSize` 1…50 (по
умолчанию 20), стабильная сортировка с tie-breaker по ID, изменённый или
просроченный курсор → `cursor_invalid`. В начальной поверхности — только
`listSources` и `listReviewItems`; `getSource` и `listRuns` отложены.

Provenance для пользователя — `content.getProvenanceDisclosure` (BCK-07
§10) в деталях Event (BCK-08): источник, `checkedAt` → свежесть,
`rescheduledFrom?`, статус отмены. Без URL фида, authorization, ошибок и имён
сотрудников.

### 17.5. События

| Факт | Кто пишет | Где |
|---|---|---|
| `EventRevisionPublished`, `EventMateriallyRescheduled`, `EventOccurrenceCancelled`, `EventUnpublished` | Content/Event (уже есть, BCK-07 §35) | `eventBookingOutbox` |
| `content.revisionActivated`, `content.submitted` и др. (BCK-07 §11.1) | Content | Envelope после OD-09 |
| `eventIngestion.sourceConnected`, `eventIngestion.sourceStatusChanged`, `eventIngestion.runQuarantined`, `eventIngestion.reviewItemCreated` (`producer: event-ingestion`) | EVS | `eventIngestionOutbox`, envelope `platform/v1/event_envelope` после OD-09 |
| `identity.placeOperatorLinked`, `identity.placeOperatorUnlinked` | Identity (P4) | Envelope после OD-09 |

Переносы и отмены одинаковы для ручных и импортированных изменений — их
пишет Content, не EVS. Consumers: Booking (projection), Notifications
(BCK-13), Discover (BCK-08), Analytics (BCK-21).

---

## 18. UX

Поведение — концепция §4–§6, §9. Обязательные требования:

### 18.1. Экраны

| Экран | Где | Содержимое |
|---|---|---|
| `EventSourcesPage` | Workspace страницы оператора → «Источники событий» | Источники с health-бейджем, счётчик очереди, «+ Добавить» |
| `ConnectEventSourceFlow` | Полноэкранный, 5 шагов | Ссылка → результат проверки (+ более надёжный источник) → предпросмотр карточек → профиль импорта и режим → основание и согласие |
| `EventSourceDetailsPage` | Тап по источнику | Настройки, профиль, основание, история runs, события источника, действия |
| `EventSourceReviewQueuePage` | Из списка и уведомления | Вкладки по kind; действия §8.6 |
| `DuplicateCompareSheet` | Из очереди | Две карточки, совпадения/различия |
| Staff-вход | Существующая Admin-поверхность (IDP-05A), `moderate.event_sources` | Все очереди, одобрение, пауза/отключение |
| Event Details (существующий, E5) | Для всех | Строка provenance, «Перенесено»/«Отменено», «Сообщить о неточности» |
| Event Edit (существующий, E5) | Для оператора | Operational read-only с пояснением; замок на content; «Отвязать от источника» |

### 18.2. Состояния и тексты

- l10n-ключи `eventSources.*` (repo-wide l10n отсутствует — ключи
  вводятся сразу).
- Честные состояния: loading, empty, error по коду §12.9, offline (действия
  недоступны, данные из кеша с меткой свежести).
- 360 dp / 150 % без overflow; бейджи с текстом, не только цвет.

### 18.3. Уведомления

| Кому | Когда |
|---|---|
| `owner`/`manager` страницы, staff | Источник → `failing`, `paused` (robots/доступ/согласие), `quarantined` |
| Участники с `event_sources.review_changes` | Новые ReviewItem — дайджест раз в сутки |
| Пользователи, сохранившие событие, добавившие его в Scenario/Quick Plan или подписанные на напоминание (`interestPolicy`) | Перенос, смена места, отмена (Create §20) |

Внутренних Booking у импортированных событий нет (регистрация внешняя) —
Recharge уведомляет доступных подписчиков (Create §17.2 п.8). Канал, согласие
и время — notification policy BCK-13 (D7).

### 18.4. Сообщение о неточности

Кнопка создаёт жалобу через Trust & Safety (BCK-22) с причиной «неточная
информация о событии». BCK-22 — единственный владелец Report и
EnforcementCase: данные жалобы в EVS не копируются, `ReviewItem` по жалобам не
создаётся. По импортированному Event EVS получает только типизированный
сигнал со ссылкой на case (`caseId`) и может своей командой приостановить
источник (`pauseReason: moderationCase`, `moderationCaseRef`); решение по
самому Event BCK-22 применяет через команды Content. До BCK-22 кнопка скрыта.

---

## 19. Безопасность, privacy, legal

1. Подключение без `authorization.basis` и действующей делегации невозможно
   (проверка на сервере). URL ([BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §4.1): явные credentials и
   известные auth-параметры отклоняются, публичность endpoint подтверждает
   человек, полный URL — restricted и не попадает в projection, audit, ошибки
   и телеметрию (только хост и hash). Это снижает, но не исключает риск
   случайного секрета в URL; приватные фиды — вне V1.
2. robots.txt, `Retry-After` соблюдаются; запрет → `paused`.
3. SSRF-защита §12.2 обязательна и покрыта тестами.
4. Секретов в V1 нет: probe не подписывается (результат — серверная
   async-операция). Ключи провайдеров — только Secret Manager (инвариант №16),
   в ECL-04/05.
5. Снимки quarantine — Operational, 14 дней, доступ сервис/staff.
6. Изображения — только через Media при `imageRights`; hotlink запрещён (§11.5).
7. `organizer.email/telephone` и иные персональные данные из источника не
   сохраняются.
8. Legal review до E6: текст согласия, основания `publicFeedTerms`/
   `partnerAgreement`, страница `/bot`, права на изображения и тексты.
9. Abuse: `startProbe` ≤ 20/час на actor, `connectSource` ≤ 10/сутки на
   actor.
10. Каждое отправленное событие проходит ту же модерацию и
    duplicate/spam-проверки (Create §15 п.21), что и ручное.

---

## 20. Observability и стоимость

- Метрики: runs по outcome, латентность fetch p50/p95, создано/обновлено/
  отменено в сутки, доля quarantine, размер и возраст очереди, источники по
  статусам, `deferredByVelocity`.
- Алерты: quarantine > 10 % источников за сутки; очередь старше 72 ч > 100;
  ошибки worker > 5 %.
- Логи структурированные, без тела ответа и query-параметров URL.
- Бюджет пилота: ≤ 50 источников × 4 runs/сутки ≈ 200 fetch/сутки;
  conditional GET; без платных сторонних сервисов (RSK-10).

---

## 21. Flags и rollback

Флаги бэкенда — `FirestoreFeatureFlagGate(firestore, environmentId,
marketId)`: ключ `(environment, market, capabilityId)`, по умолчанию
выключены, включаются по рынкам независимо (LV первым).

| Флаг (`capabilityId`) | Default | Выключен |
|---|---|---|
| `event-ingestion.source.connect` | off | Подключение источников недоступно, раздел в mobile скрыт |
| `event-ingestion.sync` | off | Runs не запускаются |
| `event-ingestion.kind.ical`, `event-ingestion.kind.jsonld` | off | Вид недоступен, runs пропускаются |
| `event-ingestion.auto-submit` | off | Все источники работают как `ownerReview` |
| `event-ingestion.cancellation.auto` | off; включается вместе с `event-ingestion.sync` (D8) | Аварийный режим: явные отмены — только через review |
| `event-ingestion.staff-approval.skip` | off | Staff одобряет каждое подключение |
| `event-ingestion.notifications` | off | Outbox пишется, доставки нет |

Прямая публикация (D15) — не флаг EVS, а политика BCK-07 §8.4. Аварийное
отключение — `SecurityFlagRevision` (`emergencyDisabled: true`) для
`event-ingestion.sync` и `event-ingestion.source.connect`. Market capability
`event-ingestion` — `status: disabled` для LV, EE, LT.

Mobile: `EventSourcesRuntimeConfig.enabled = false` по умолчанию.

Rollback: `event-ingestion.sync = off` останавливает синхронизацию; импортированные
Event остаются, свежесть деградирует до `stale` (Event spec §22.3). Полный
откат — `revoke` источников и архивирование Event с `origin ∈ {apiSynced,
providerImported}` источника через Admin repair (propose/approve/execute,
BCK-01 §13; RUN-03) командами Content.

---

## 22. Contracts и conformance fixtures (этап E1)

Раскладка — BCK-03 §9 и BCK-01 §17 (второй источник контракта вне
`schema/<domain>/vN/` запрещён). Cross-language контракт авторизуется
ADR 0020 (API Contracts Workflow §1).

Точные файлы схем и fixtures, 28 фидов и 33 сценария сверки — только в
[BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §20.1 и §21.1; здесь их списки не повторяются.

Правила схем: JSON Schema 2020-12, стабильный `$id`
`https://recharge.app/schemas/event-ingestion/v1/...` (дефис в URL, как у
`reference-data`); ID, время, ревизии, ошибки, cursor и async-операции —
`$ref` на `platform/v1`, `marketId`/`publisherRef`/`capabilityId` — на
`identity/v1`. Проверка на стороне TS — Ajv 2020 в тестах и verify-скриптах
(как `identity_schema_registry.ts`) и `inspect*`-валидаторы в runtime (как у
booking). Команды — `additionalProperties: false`, у массивов `maxItems`, у
строк `maxLength` (BCK-03 §9). Неизвестные поля и версии — [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §8:
команды отклоняют неизвестные поля, новая версия контракта —
`unsupported_contract`, неизвестные additive-поля сохраняются только в
обозначенных persisted/read DTO.

Формат кейса `reconcile/` — исполняется чистым reconciler без парсеров, поэтому
шаг содержит уже нормализованные события; `feed` — только ссылка для
понимания:

```json
{
  "case": "005_reschedule_single_event",
  "source": { "sourceId": "01J…", "kind": "ical", "publishMode": "autoSubmit",
              "fieldScope": "all" },
  "initialState": { "records": [], "events": [], "locks": [], "flags": {},
                    "delegation": { "status": "active", "revision": 1 } },
  "steps": [
    { "at": "2026-10-01T10:00:00Z", "http": 200,
      "feed": "feeds/ical/basic.ics",
      "normalized": [ { "externalUid": "uid-1", "recurrenceKey": "", "…": "…" } ],
      "expect": { "runOutcome": "succeeded",
                  "decisions": [ { "type": "createEvent",
                                   "bindingKey": { "externalUid": "uid-1", "recurrenceKey": "" },
                                   "targetLifecycle": "pendingReview" } ] } }
  ]
}
```

`decisions[].type` — закрытый enum: `createEvent`, `applySnapshot`,
`addOccurrence`, `setOccurrenceCancelled`, `queueReview` (+ `reviewKind`,
`reasons`), `hideOccurrence`, `restoreOccurrence`, `supersedeReview`,
`rekeyRecord`, `quarantineRun`, `deferVelocity`, `retryContentOperation`,
`pauseSource`, `noop`.
Автоматического прикрепления к другому Event нет: совпадения между
источниками — только `queueReview` с `reviewKind: duplicateCandidate`.

Conformance — приёмочный тест backend (E4). Mobile эти кейсы не исполняет.

---

## 23. Файловые карты

### 23.1. Mobile (E2 — только UI на демо-данных)

Новая фича (ADR 0020), без cross-feature import; связи — через
`app/adapters`.

```text
apps/mobile/lib/features/event_sources/
  domain/
    entities/{event_source_summary, sync_run_summary, review_item_view,
              probe_preview, import_profile_draft}.dart
    repositories/{event_source_repository, review_queue_repository}.dart   // порты
  data/
    datasources/event_sources_demo_datasource.dart   // Dart-фикстуры, без сети
    repositories/{event_source_repository_impl, review_queue_repository_impl}.dart
  application/
    event_sources_runtime_config.dart                // enabled = false
    event_sources_providers.dart
    {connect_event_source_controller, review_queue_controller}.dart
  presentation/
    pages/{event_sources_page, event_source_details_page,
           event_source_review_queue_page}.dart
    widgets/{connect_event_source_flow, source_health_badge,
             duplicate_compare_sheet, import_profile_form}.dart
apps/mobile/lib/app/adapters/event_source_workspace_adapter.dart  // вход из workspace страницы, mock-права
apps/mobile/lib/app/router/app_router.dart                        // изменение: маршруты
apps/mobile/lib/app/di/service_locator.dart                       // изменение: регистрация
```

Нет: сети, разбора форматов, reconciler, фоновых задач, изменений Event
Details/Event Edit (это E5).

### 23.2. Backend (E4)

Точная карта файлов — [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §20,
по образцу модуля `identity_publisher` фактического бэкенда:

```text
apps/backend/functions/src/contracts/event_ingestion_{v1,schema_registry}.ts, validate_event_ingestion_contract.ts
apps/backend/functions/src/modules/event_ingestion/{domain, application, application/ports, infrastructure}/
apps/backend/functions/src/platform/bootstrap/event_ingestion_composition_root.ts
apps/backend/functions/src/index.ts                          // callables и workers — слайс EVS-LOCAL-03
apps/backend/functions/test/{unit/event_ingestion, contract, integration, rules, emulator}/
apps/backend/scripts/verify-event-ingestion-{layout,contracts}.mjs
```

Реестры (`collection_access_matrix.ts`, `data_class_registry.ts`,
`retention_registry.ts`), `firestore.rules`, `firestore.indexes.json`,
`shared/feature_flags.ts` меняются точечно. Изменения других модулей —
[master roadmap](EVENT_SOURCE_INGESTION_BACKEND_IMPLEMENTATION_PLAN.md) §3 и
[BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §23.

---

## 24. Тестовая матрица

| Уровень | Что | Этап |
|---|---|---|
| Schema/fixture | valid/invalid/forward всех схем §22 | E1 |
| Conformance structure | Все файлы `conformance/` валидны по формату | E1 |
| Widget (mobile) | Экраны §18.1 (кроме Details/Edit), 360 dp / 150 %, скрытие при выключенном флаге | E2 |
| Unit (backend) | Канонизация, ключ, классы изменений, sanity gate, authority, дубли | E4 |
| Contract (backend) | Все `feeds/` → `normalize/*.expected.json`; все `reconcile/` → ожидаемые decisions | E4 |
| Security | SSRF (IPv4/IPv6, rebinding, редирект на внутренний адрес), лимиты, robots, не-https | E4 |
| Emulator/Rules | Прямые записи запрещены; Content отвергает правку operational и overlay; идемпотентность | E4 |
| Integration | Staging: тестовый календарь → создание, перенос, отмена, пропажа, quarantine | E5 |

---

## 25. Этапы

Нормативно: backend — [master roadmap](EVENT_SOURCE_INGESTION_BACKEND_IMPLEMENTATION_PLAN.md);
mobile E2 — §23.1 и §27 E2 этой спецификации. Обзор всех этапов:
E0 документы → E1 контракты → E2 mobile UI (демо) → E3 предпосылки в ядре →
E4 backend-модуль → E5 интеграция в staging → E6 staging-пилот на реальных
фидах → E7 production-когорта → E8 (при D15) прямая публикация →
E9 расширения.

---

## 26. Решения (предложения — подтверждает владелец)

| ID | Вопрос | Решение / предложение | Статус |
|---|---|---|---|
| D1 | Publisher для Place без страницы оператора | V1: не поддерживается. Служебная страница Recharge — только отдельным ADR (Event spec §15.1, ADR 0016) | Ждёт |
| D2 | Лимиты | ≤ 5 источников на Place; интервал ≥ 60 мин, по умолчанию 360 | Принято 2026-09-27 |
| D3 | Права команды | `owner`/`manager` — управление и очередь; отдельная роль для очереди (в mobile — `editor`) — решение BCK-06 | Принято 2026-09-27 |
| D4 | Пропажа из источника | 2 успешных runs подряд (без условия 24 ч), только будущие даты → дата скрывается из показа без отмены и уведомлений + `ReviewItem(missingFromSource)`; вернулась в источник → снова видна (§12.6) | Принято 2026-09-27 в изменённой редакции |
| D5 | Sanity gate | §12.8 | Принято 2026-09-27 |
| D6 | Соцсети | Не в V1; отдельное решение после Legal | Принято 2026-09-27 |
| D7 | Уведомления о переносе/отмене | Подписчики (Favorites, Scenario/Quick Plan, напоминания); канал — policy BCK-13 | Принято 2026-09-27 |
| D8 | Явная отмена в источнике | Явная отмена в источнике применяется сразу, с пилота E6; `event-ingestion.cancellation.auto` — аварийный выключатель (§12.7) | Принято 2026-09-27 в изменённой редакции |
| D9 | Модуль backend | Новый BCK-23 с ревизией BCK-02: item **6E** (6D занят Planning/AI/Providers/Payments), после 6A (BCK-07) и 6B (BCK-08); альтернатива — расширение BCK-16 (решают владельцы BCK-02) | Принято 2026-09-27 |
| D10 | Где логика | Только backend; общий артефакт — schemas + conformance | Ждёт |
| D11 | Event ↔ Place | Additive `location.placeId` для всех Event | Ждёт |
| D12 | Доказательство оператора | Только связь P4 | Ждёт |
| D13 | Какие Place | Опубликованные, `placeKind = managedVenue` | Ждёт |
| D14 | Серии | `multiDate` с экземплярами источника (§11.6) | Ждёт |
| D15 | Прямая публикация | Только по политике BCK-07 §8.4 (`content.publish` + принятая политика type/market/publisher + серверный флаг); по умолчанию — стандартная модерация | Принято 2026-09-27 |
| D16 | Профиль импорта | Обязателен при подключении (§8.2) | Ждёт |
| D17 | Краткое описание | `fromSourceText` — только дословная выдержка целых предложений исходного текста; нет текста — поле отсутствует | Ждёт |
| D18 | Где делать E1 | В backend-треке как слайс EVS-LOCAL-01: у `packages/api_contracts` один автор | Ждёт |
| D19 | Хранение данных quarantine | Без Storage: повторный run с `approvedDiffHash` (§12.8) | Ждёт |
| D20 | Backend-решения «Захода 6» | [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §24 (BCK23-D01…D18): публичные URL, граница JSON-LD, iCal V1, делегация, права, идентичность, пропажа, retention, транспорт, callables, неизвестный исход, изображения | Приняты BCK23-D07 (в изменённой редакции) и D16; остальные ждут |

---

## 27. Acceptance criteria

### E0

1. Spec, concept, brief, plan, ADR 0020 согласованы между собой, с Event spec
   §18 и Create §15–§17; ссылки на отсутствующие в коде сущности помечены
   P1–P8.
2. Владелец подтвердил или изменил D1–D17.
3. Подготовлены: предложение ревизии BCK-02 (BCK-23, волны), вход в OD-03.

### E1

E1 = backend-слайс EVS-LOCAL-01a; его критерии приёмки нормативно заданы
только в [BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) §22.1 (33 кейса `reconcile/`, правила неизвестных полей,
отсутствующая цена остаётся `unknown`, проверки `verify:event-ingestion:*`,
`test:event-ingestion`, `test:r1`). Здесь они не повторяются.

### E2

1. Экраны §18.1 (без Details/Edit) видны только при
   `EventSourcesRuntimeConfig.enabled = true` и mock-capability.
2. В фиче нет сетевых вызовов и импортов других features.
3. Boundary: 0 новых нарушений, бюджет 71 не увеличен.
4. Widget-тесты 360 dp / 150 % без overflow.
5. `flutter analyze` 0 issues, `flutter test` зелёный.

E3+ — AC в плане и в BCK-23 spec.

---

## 28. Unimplemented list

- P1–P8 не выполнены.
- Backend целиком — E4.
- Команды Content §17.3 — будущая BCK-07.
- Уведомления — BCK-13 и OD-09; жалобы — BCK-22.
- `rss`, `jsonFeed`, `ticketPlatform`, `htmlPage`, соцсети — E9.
- Прямая публикация — D15.
- Локализация `eventSources.*` — repo-wide l10n slice.
