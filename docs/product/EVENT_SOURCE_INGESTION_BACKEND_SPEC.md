# Recharge Backend — Event Source Ingestion Specification

- ID: **BCK-23** (кандидат; регистрируется только ревизией BCK-02 как item **6E**)
- Version: **0.4**
- Date: **2026-09-28**
- Spec status: **Draft — пакет «Заход 6»; BCK23-D07 и D16 приняты владельцем 2026-09-27, остальные решения ждут; не Approved**
- Runtime status: **Absent** — нет схем, кода, коллекций, индексов, TTL, IAM, секретов, сети, exports и облачных ресурсов
- Accountable owner: **Content Platform owner**
- Review owners: **Identity, API, Security/Privacy, Operations, Reference Data, Content, Legal**
- Markets: **Latvia first; Estonia и Lithuania — отдельными решениями**
- Minimum compatible documentation baseline (нормативно): BCK-02 **v2.4.99** (§31.1 reservation),
  BCK-03 v0.3.22, BCK-04 v0.4.35, BCK-05 v0.2.41, BCK-06 **v0.8**, BCK-07 **v0.7**, BCK-16 v0.3.1,
  BCK-20 v0.2.29, BCK-22 v0.3.1; OD-07 Accepted. Более новые версии совместимы, пока сверка §23
  не нашла противоречий
- Last verified against (non-normative; обновляется только при переносе): ветка
  `codex/backend-stage8-critical-repair`, коммит `526f497`, 2026-09-28

**Нормативный комплект** (единственное, что переносится в ветку бэкенда):
[ADR 0020](../adr/0020-event-source-ingestion.md) (Proposed),
[продуктовая спецификация](EVENT_SOURCE_INGESTION_SPEC.md), этот файл и
[master roadmap](EVENT_SOURCE_INGESTION_BACKEND_IMPLEMENTATION_PLAN.md).
Этот файл — канонический backend-документ BCK-23 по структуре BCK-02 §14: по
backend-вопросам прав он, по продуктовым правилам Event — продуктовая
спецификация и Event spec. Бриф, краткий бриф, общий план E0–E9 и концепция —
non-normative, не переносятся и при расхождении не учитываются.

---

## 0. Changelog

### v0.4 — 2026-09-28

Поправки ревью:

- совместимость — по минимальным версиям BCK-документов; SHA коммита —
  только ненормативное «last verified against», обновляется при переносе;
- жалобы — только BCK-22: EVS получает типизированный сигнал со ссылкой на
  case и может своей командой приостановить источник; данные жалобы в
  `eventIngestionReviewItems` не копируются (§23);
- фоновые задачи — через общий port BCK-05 для leased jobs; импорт из
  `booking/event_projection_delivery` запрещён (BCK23-D09, §23);
- DoR: перед переносом обновить «last verified against» и пересобрать пакет.

### v0.3 — 2026-09-27

Решения владельца:

- BCK23-D07 принято в изменённой редакции: будущая дата, пропавшая из
  источника на двух успешных проверках подряд (без условия 24 ч),
  скрывается из показа без отмены и уведомлений и открывает
  `ReviewItem(missingFromSource)`; вернувшаяся в источник дата снова
  показывается; явная отмена в источнике применяется сразу,
  `.cancellation.auto` — аварийный выключатель;
- BCK23-D16 принято: излишек сверх `100/day` уходит в следующие окна,
  ближайшие по дате — первыми;
- решения сверки `hideOccurrence`/`restoreOccurrence`; кейсов `reconcile/` —
  33 (008 и 020 заменены, добавлены 031–033);
- новое требование к BCK-07: обратимое скрытие по причине `sourceMissing`
  (§7.2, §23);
- продуктовые решения D2, D3, D5–D9 и D15 приняты (продуктовая
  спецификация §26);
- baseline — коммит `6c54082` (все версии §23 закоммичены); ссылок на
  non-normative файлы нет.

### v0.2 — 2026-09-27

Поправки второго ревью:

- политика URL переформулирована: явные credentials и известные
  auth-параметры отклоняются, человек подтверждает публичность endpoint, полный
  URL — restricted operational data; утверждение «секретов нет» снято;
- пагинация list-callables по BCK-03 §19 и результат `connectEventSourceV1`
  (`sourceId` + `initialSyncOperationId`, первая синхронизация асинхронно);
- совместимость по BCK-03 §25.2: неизвестные поля команд отклоняются,
  неизвестная версия контракта — `unsupported_contract`, сохранение неизвестных
  additive-полей — только для обозначенных persisted/read DTO;
- запись `PagePlaceOperatorLink` (writer — BCK-06), Place остаётся за BCK-07;
- индексы приведены к запросам list-callables и scheduler;
- нормативный комплект сокращён до четырёх документов.

### v0.1 — 2026-09-27

- первый канонический BCK-23 по 22 пунктам BCK-02 §14;
- включает поправки ревью «Заход 6»: baseline v2.4.98/v0.8/v0.7, номер `6E`,
  граница JSON-LD, подмножество iCal V1, постоянная делегация вместо
  `grantorUserId`, права `event_sources.manage`/`event_sources.review_changes`
  + `content.submit`, retention до Firestore, политика публичных URL,
  идентичность `sourceId + externalUid + recurrenceKey`, пропажа →
  `missingFromSource`/`reviewRequired`, отсутствие default cover, зависимость
  от отдельного Content persistence slice, сокращённая callable-поверхность;
- фиксирует точную карту файлов `EVS-LOCAL-01a`.

---

## 1. ID, статусы и владелец

См. шапку. Статусы меняются только записанным решением владельца: этот файл
не объявляет ни себя Approved, ни ADR 0020 Accepted.

## 2. Родители, якоря и приоритет

1. Accepted ADR: 0011, 0013, 0015–0019; ADR 0020 — Proposed, должен быть
   принят до реализации.
2. EVENT_CLASSIFICATION_SPEC v2.2.3: §2 (инварианты 5, 6, 11, 12, 15, 16),
   §12.2 цена, §15 Publisher, §18 source/authority/дубли.
3. EVENT_CREATE_SPEC: §10.2 обязательные поля, §15 публикация, §16 pipeline,
   §17 ревизии.
4. BCK-02 v2.4.99 §31.1 — резерв Event Ingestion (идентичности модуля,
   коллекций, runtime identity, cost label, allowlisting, restore choreography).
5. BCK-07 v0.7 §7.4 — `ContentProvenance.kind = ownerImport`,
   `originBinding {kind: delegatedImport, delegatedActorRef, externalBindingRef}`,
   идемпотентность не-сессионного актора; AC-92…AC-97.
6. BCK-03 (envelopes, async operation, idempotency), BCK-04 (классы данных,
   retention, BCK04-OD-07), BCK-05 (транспорт, флаги, бюджет, сеть), BCK-06 v0.8
   (capabilities, membership), BCK-16 v0.3.1 §11/§25 (модель egress),
   BCK-20 (Category System, locale).

Конфликт: ADR → Event/Create specs → BCK-02/03/04 → BCK-07/06 → этот файл.

## 3. Результат и измеримые non-goals

**Результат:** официальный источник заведения (iCal или schema.org JSON-LD),
подключённый командой страницы по постоянной делегации, превращается в
события Recharge через обычные команды BCK-07: одно внешнее событие — один
Event, изменения — ревизии того же Event, неизвестное остаётся неизвестным.

Метрики — продуктовая спецификация §5 (0 дублей, 0 ложных отмен, ≤ 7 ч p95).

**Non-goals (измеримо отсутствуют в V1):** соцсети; DOM scraping и визуальный
разбор HTML; билетные площадки; секретные URL; сложные повторения iCal
(до 01c); availability/sold-out; default cover и hotlink изображений;
автоматическое объединение событий; публикация в обход модерации; действия от
имени пользовательской Session.

## 4. Scope

**Входит:** реестр источников Place; probe; синхронизация; нормализация;
sanity gate; сопоставление по идентичности (§11); очередь проверки оператора;
вызовы команд BCK-07 от делегированного актора; health; provenance.

**Не входит:** Event aggregate, ревизии, модерация (BCK-07/22); Place и связь
Place↔оператор (BCK-07/BCK-06); доставка уведомлений (BCK-13); изображения
(BCK-14); ticket providers (BCK-16); обнаружение источников.

### 4.1. Граница получения данных

**Политика URL (BCK23-D01).** Любой URL может нести случайный секрет в
неприметном пути или параметре, поэтому V1 не утверждает, что секретов нет.
Правила:

- схема `https`; `webcal://` приводится к `https://`;
- отклоняются явные credentials и известные auth-параметры: userinfo
  (`user:pass@`), query-параметры с именами `token`, `key`, `secret`, `sig`,
  `signature`, `auth`, `access_token`, `apikey`, `api_key`, `password`, `pwd`,
  `session`, `private` (без учёта регистра) и известные приватные пути
  (например, `/private-<ключ>/` у Google Calendar) → `url_not_public`;
- человек при подключении подтверждает, что endpoint предназначен для
  публичного получения (`authorization.publicEndpointConfirmed = true`),
  иначе — `public_endpoint_not_confirmed`;
- полный URL — **restricted operational data**: хранится только в
  `eventIngestionSources`; не попадает в projection, audit, ошибки и
  телеметрию; в логах и прочих записях — только хост и `sha256(canonicalUrl)`;
- credential-bearing и приватные фиды — вне V1 (хранение как secret reference
  потребует отдельного решения и Secret Manager по BCK05-OD-02).

**JSON-LD (BCK23-D02):** допустимо **только** ограниченное извлечение блоков
`<script type="application/ld+json">` (сравнение атрибута без учёта регистра;
≤ 50 блоков, ≤ 1 MB на блок, ≤ 2 MB на страницу) → `JSON.parse` → объекты
`Event` и подтипов, включая `@graph`. **Запрещены:** DOM scraping, визуальный
разбор HTML, извлечение из произвольной разметки (включая microdata и RDFa),
выполнение JavaScript, переход по ссылкам страницы.

**iCal V1 (BCK23-D03):**

| Поддерживается в V1 (01b) | Отложено в подэтап 01c (после conformance) |
|---|---|
| `VEVENT`, `UID` (обязателен), `DTSTART`/`DTEND`/`DURATION`, `VALUE=DATE` | `RRULE` с `FREQ=MONTHLY`/`YEARLY` |
| `TZID` (IANA; Windows-имена по таблице CLDR), UTC, floating → timezone Place | `BYMONTHDAY`, `BYSETPOS`, `BYMONTH`, `BYWEEKNO`, `BYYEARDAY`, `BYHOUR`/`BYMINUTE`/`BYSECOND`, порядковые `BYDAY` (`2MO`, `-1FR`) |
| `STATUS` (`CONFIRMED`/`TENTATIVE`/`CANCELLED`), `CLASS` (`PRIVATE`/`CONFIDENTIAL` → пропуск) | `RECURRENCE-ID` (изменённые экземпляры) |
| `RDATE` (`DATE`/`DATE-TIME`), `EXDATE` | Собственные правила `VTIMEZONE` при неизвестном `TZID` |
| Простое повторение: `RRULE` с `FREQ=DAILY`/`WEEKLY`, `INTERVAL`, `COUNT` или `UNTIL`, `BYDAY` без порядковых номеров (только для `WEEKLY`) | |
| `SUMMARY`, `DESCRIPTION`, `URL`, `LOCATION`, `LAST-MODIFIED` | |

Серия с неподдерживаемым правилом или с `RECURRENCE-ID` целиком получает
`ReviewItem(unsupportedRecurrence)` и автоматически не импортируется.
`VEVENT` без `UID` отклоняется (`missing_uid`).

**Egress (BCK23-D14, модель BCK-16 §11/§25):** на источник — точный allowlist
(`https`, хост, путь, `GET`), фиксируется при probe и одобрении; редирект
только внутри allowlist, иначе `redirect_not_allowlisted` + повторный probe;
SSRF/DNS-rebinding защита; лимиты времени и размера; robots.txt (RFC 9309).
Реализуется не раньше EVS-LOCAL-03; до EVS-DEV-01 сети нет вообще.

## 5. Владение записями

| Запись | Writer | Потребители |
|---|---|---|
| `EventSource`, `SyncRun`, `SourceEventRecord`, `ReviewItem`, async operation, lock-документы | `event-ingestion` | Mobile через callables; privacy-orchestration; audited-support |
| `EventIngestionDelegation` | **identity (BCK-06)** | `event-ingestion` (чтение и проверка) |
| `PagePlaceOperatorLink` (§9.3) | BCK-06 Identity/Publisher authority | `event-ingestion` (чтение); сам Place — BCK-07 Content |
| Event, ревизии, `ContentProvenance`, модерация | BCK-07 (и BCK-22) | `event-ingestion` через команды и запросы |
| `eventBookingOutbox`, Booking projections | Content / Booking | — (EVS не касается) |

## 6. Классы данных и проекции

| Коллекция (резерв BCK-02 §31.1) | `DataClassRegistry` id | Classification | Клиент |
|---|---|---|---|
| `eventIngestionSources` | `event-ingestion.source` | `restricted` (полный URL) | deny |
| `eventIngestionSourceUrlLocks` | `event-ingestion.source-lock` | `internal` | deny |
| `eventIngestionRuns` | `event-ingestion.run` | `internal` | deny |
| `eventIngestionRecords` | `event-ingestion.record` | `internal` | deny |
| `eventIngestionRecordKeys` | `event-ingestion.record-key` | `internal` | deny |
| `eventIngestionReviewItems` | `event-ingestion.review-item` | `personal` | deny |
| `eventIngestionOperations` | `event-ingestion.operation` | `internal` | deny |
| `eventIngestionRobotsCache` | `event-ingestion.robots-cache` | `internal` | deny |
| `eventIngestionIdempotency` | `event-ingestion.idempotency` | `internal` | deny |
| `eventIngestionAudit` | `event-ingestion.audit` | `personal` | deny |
| `eventIngestionOutbox` | `event-ingestion.outbox` | `internal` | deny |

Полный URL источника хранится только в `eventIngestionSources`; все прочие
записи (runs, операции, review items, audit, outbox) содержат хост и
`sha256(canonicalUrl)`. Публичная информация о происхождении — только
`content.getProvenanceDisclosure` (BCK-07); URL фида, делегация, ошибки и имена
сотрудников в неё не попадают.

## 7. Команды, запросы, события, ошибки

### 7.1. Начальная callable-поверхность (BCK23-D10)

Семь callables; окончательный список — после owner approval этой таблицы.
Стиль и опции — как в `functions/src/index.ts` (`<глагол><Сущность>V1`,
`europe-west1`, `timeoutSeconds: 30`, `decideAppCheck`, флаг-гейт,
`inspect*`, typed failures).

| Callable | Команда/запрос | Кто | Ключевые коды |
|---|---|---|---|
| `startEventSourceProbeV1` | `eventIngestion.startProbe` → async operation `eventIngestion.probeSource` | `event_sources.manage` | `url_not_public`, `not_https`, `source_already_connected`, `source_limit_reached`, `rate_limited` |
| `getEventIngestionOperationV1` | `eventIngestion.getOperation` | инициатор | `not_found` |
| `connectEventSourceV1` | `eventIngestion.connectSource` (`probeOperationId`, `delegationId`, `publishMode`, `fieldScope`, `syncIntervalMinutes`, `importProfile`, `venueFilter?`, `authorization` с `publicEndpointConfirmed`) → `{sourceId, status, sourceRevision, initialSyncOperationId?}` | `event_sources.manage` | `probe_expired`, `delegation_invalid`, `authorization_required`, `public_endpoint_not_confirmed`, `import_profile_invalid`, `place_not_eligible` |
| `listEventSourcesV1` | `eventIngestion.listSources` (`placeId`, `pageSize?`, `cursor?`; с кратким health) → cursor page | `event_sources.manage` или `event_sources.review_changes` | `cursor_invalid` |
| `changeEventSourceStateV1` | `eventIngestion.changeSourceState` (`pause \| resume \| revoke`; `approve` — staff) → `{sourceId, status, sourceRevision, initialSyncOperationId?}` | `event_sources.manage`; staff — `moderate.event_sources` | `stale_revision`, `transition_not_allowed` |
| `listEventIngestionReviewItemsV1` | `eventIngestion.listReviewItems` (`placeId` — для участников страницы; `marketId` — для staff; `status` по умолчанию `open`; `pageSize?`, `cursor?`) → cursor page | `event_sources.review_changes`; staff | `cursor_invalid` |
| `resolveEventIngestionReviewItemV1` | `eventIngestion.resolveReviewItem` (включая `applyRun`/`ignoreRun` для quarantine) | `event_sources.review_changes`; отправка — ещё `content.submit` | `resolution_not_allowed`, `stale_revision` |

Отложены до отдельного решения: изменение настроек источника, «проверить
сейчас», история runs, детали источника.

### 7.1.1. Результат подключения и пагинация (BCK23-D17)

- **Подключение.** `connectEventSourceV1` возвращает `sourceId`, `status`,
  `sourceRevision` и, если источник сразу `active`, `initialSyncOperationId` —
  async-операцию `eventIngestion.syncSource`; первая синхронизация идёт
  асинхронно, клиент следит за ней через `getEventIngestionOperationV1`. Если
  источник `pendingApproval`, операции нет — её возвращает
  `changeEventSourceStateV1(approve)`. До решения BCK-05 по транспорту
  операцию исполняет run-сервис, вызываемый тестом или Emulator-harness;
  облачный запуск — после транспорта.
- **Пагинация (BCK-03 §19).** Ответ — `platform/v1/cursor_page`; `pageSize`
  1…50, по умолчанию 20; `nextCursor = null` — конец списка; курсор
  непрозрачный и привязан к типу/версии запроса, актору, рынку, фильтрам и
  сортировке; изменённый запрос, чужой или просроченный курсор →
  `invalid_argument` с `domainCode: cursor_invalid`, без тихого перезапуска.
- **Сортировка:** источники — `createdAtUtc DESC, sourceId DESC`; review items
  — `createdAtUtc DESC, reviewItemId DESC`.

### 7.2. Команды BCK-07 (через `content_import_port`)

`content.createDraft` → `content.saveDraftRevision` → `content.bindPublisher`
(`originBinding.kind = delegatedImport`) → `content.submitForReview`; изменения
опубликованного — кандидат от текущей ревизии (BCK-07 §8.3) с классом
изменения. `delegatedActorRef = module:event-ingestion/<operation>`,
`externalBindingRef = bindingKey` (§11). EVS никогда не вызывает
`content.activateRevision`.

Скрытие по пропаже (BCK23-D07): `content.hide` с причиной `sourceMissing`,
если у Event нет других видимых будущих дат, иначе обратимое скрытие одной
даты `multiDate`; возврат — `content.restoreVisibility`. Это не санкция
модерации: скрытие снимает EVS без модератора, уведомлений нет. Сейчас в
BCK-07 `content.hide` — команда модерации, а скрытия одной даты нет: нужна
поправка BCK-07 (§23). Явная отмена — кандидат `operationalCancellation`
(продуктовая спецификация §12.7).

### 7.3. События

EVS — producer `event-ingestion` для `eventIngestion.sourceConnected`,
`eventIngestion.sourceStatusChanged`, `eventIngestion.runQuarantined`,
`eventIngestion.reviewItemCreated` — **только после OD-09 Accepted**. Переносы
и отмены пишет Content (`EventMateriallyRescheduled`,
`EventOccurrenceCancelled`).

### 7.4. Ошибки

Envelope BCK-03 §14; доменные коды — snake_case в
`event_ingestion_common.schema.json`: указанные в §7.1 + fetch/parse коды
продуктовой спецификации §12.9, `redirect_not_allowlisted`, `missing_uid`,
`unsupported_recurrence`, `jsonld_limit_exceeded`, `cursor_invalid`,
`public_endpoint_not_confirmed`.

## 8. Версии и эволюция

Схемы `https://recharge.app/schemas/event-ingestion/v1/...`; additive-поля —
minor; удаление/смена смысла — `v2` с окном миграции (BCK-03 §25). Minimum
client — по BCK-03 §26; mobile-клиент EVS появляется только с remote
datasource (продуктовый этап E5).

**Неизвестные поля и версии (BCK23-D18, BCK-03 §25.2):**

| Что | Поведение |
|---|---|
| Команда известной v1 с неизвестным полем или значением | Отклоняется: схема `additionalProperties: false` → `invalid_argument` |
| Неизвестная новая версия контракта или схемы | `unsupported_contract` / `unsupported_schema` до любых изменений |
| Обозначенные persisted/read DTO (`event_source`, `sync_run`, `source_event_record`, `review_item`, `normalized_event`, `event_ingestion_result`) | Неизвестные additive-поля сохраняются при round-trip; для ответов, влияющих на права, деньги или состояние, неизвестное значение enum — типизированное неподдерживаемое состояние, не молчаливое значение по умолчанию |

Сохранение неизвестных полей никогда не применяется к командам.

## 9. Авторизация, делегация, отзыв

### 9.1. Права (BCK23-D05)

| Capability | Кто получает (V1) | Что даёт |
|---|---|---|
| `event_sources.manage` | owner, manager | Подключать, ставить на паузу, возобновлять, отзывать источники; создавать делегацию |
| `event_sources.review_changes` | owner, manager | Разбирать очередь изменений (имя отделено от модерации Content) |
| `content.submit` | уже есть в каталоге | Обязателен для любой отправки события на модерацию — и человеком из очереди, и в scope делегации |
| `moderate.event_sources` | staff (где живут admin-capabilities — решает BCK-06/BCK-19) | Одобрять и приостанавливать источники; не отправлять события от имени страницы |

Ролей editor в бэкенде нет (owner, manager, analyst, bookingManager); отдельная
роль для очереди — решение BCK-06.

### 9.2. Постоянная делегация (BCK23-D04)

Worker никогда не действует от имени пользовательской Session. Он действует
по постоянной делегации страницы, которой владеет identity:

```text
EventIngestionDelegation (writer: identity)
  delegationId       ULID
  pageId             ULID                     // точная страница
  delegateActorRef   "module:event-ingestion"
  scope
    operations       [createDraft, saveDraftRevision, bindPublisher, submitForReview]
    contentTypes     [event]
    placeIds         ULID[]                   // только места оператора страницы
  revision           int
  status             active | suspended | revoked | expired
  grantedByUserId    ULID                     // только аудит, не источник прав
  grantedAtUtc, expiresAtUtc                  // срок ≤ 365 дней (предложение)
  suspendedAtUtc?, revokedAtUtc?, revokedByUserId?, reasonCode?
```

- Создание — командой identity человеком с `event_sources.manage` **и**
  `content.submit` на этой странице (обычная Session с проверкой прав).
- `EventSource` хранит `delegationId` и `delegationRevision`.
- Перед каждым эффектом worker проверяет: делегация `active`, не истекла,
  `revision` совпадает, операция и Place входят в scope, страница `active` и
  подтверждена, `PagePlaceOperatorLink` (§9.3) для этого Place — `active`. Иначе — эффект не выполняется,
  источник `paused` (`delegationInvalid`), `ReviewItem(ownershipChanged)`.
- Потеря членства у выдавшего → делегация `suspended` до подтверждения другим
  owner/manager; отзыв — немедленно, командой identity.
- Истечение — уведомление за 30 дней, продление новой ревизией.

### 9.3. PagePlaceOperatorLink (BCK23-D15)

Связь страницы оператора с местом — отдельная запись; Place не принадлежит
Identity.

```text
PagePlaceOperatorLink (writer: BCK-06 Identity/Publisher authority)
  linkId          ULID
  pageId          ULID            // ManagedPage оператора
  placeId         ULID            // опубликованный Place (writer Place — BCK-07)
  status          pendingVerification | active | suspended | revoked
  revision        int
  verifiedAtUtc?  UTC
  revokedAtUtc?   UTC
```

EVS только читает запись: подключение требует `active`; `suspended` или
`revoked` → источники Place `paused` (`pageInactive`). Изменения публикуются
фактами identity `identity.placeOperatorLinked` / `identity.placeOperatorUnlinked`
(после OD-09).

## 10. Хранение, индексы, транзакции

- Коллекции — §6; уникальность `canonicalUrl` и ключа идентичности —
  lock-документы в той же транзакции, что и запись.
- Индексы (7 составных, каждый с tie-breaker `__name__`):
  `eventIngestionSources(status, nextRunAtUtc)` — scheduler;
  `eventIngestionSources(placeId, createdAtUtc DESC)` — `listEventSourcesV1`;
  `eventIngestionRuns(sourceId, startedAtUtc DESC)`;
  `eventIngestionReviewItems(placeId, status, createdAtUtc DESC)` — очередь
  страницы; `eventIngestionReviewItems(marketId, status, createdAtUtc DESC)` —
  очередь staff по рынку; `eventIngestionRecords(sourceId, state)`;
  `eventIngestionRecords(eventId)`.
- Rules: явный `allow read, write: if false` на каждую коллекцию + catch-all.
- **TTL (BCK23-D08):** не добавляется, пока сроки не приняты в BCK04-OD-07.
  Предлагаемые сроки: runs 90 дней; review items 180 дней после решения;
  async operations и robots cache 24 ч; idempotency 30 дней; audit 180 дней;
  outbox 30 дней после доставки; sources — пока активны + срок доказательства
  согласия; records — пока жив Event. До принятия: политики `unresolved` в
  `RetentionRegistry`, поле `expiresAt` не объявляется готовым, TTL в
  `firestore.indexes.json` не включается. **Firestore-слайс EVS-LOCAL-02 не
  начинается до принятия сроков.**

## 11. ID, ссылки, время, reference data

- **Идентичность связи (BCK23-D06):** `bindingKey = sourceId + externalUid +
  recurrenceKey`; `externalUid` — `UID` iCal или `@id`/канонический `url`
  JSON-LD (иначе weak); `recurrenceKey` — `""` для одиночного события, исходное
  начало экземпляра (RFC 3339 UTC; для all-day — `YYYY-MM-DD`) для серии.
  Соответствие Event spec §18.2: `providerRef = feed.<kind>`,
  `externalTenantId = sourceId`, `externalEventId = externalUid`,
  `externalOccurrenceId = recurrenceKey`; в BCK-07 — `externalBindingRef`.
- Автоматически одним событием считаются **только** записи с одинаковым
  `bindingKey`. Похожесть и даже точные совпадения между разными источниками
  (тот же `UID`, та же ссылка на билеты) создают только `duplicateCandidate`
  для человека — никакого автоматического объединения в V1.
- ID — ULID (BCK-03 §10.1); время — RFC 3339 UTC, суффикс `AtUtc`; локальные
  даты + IANA (Europe/Riga и др.); Category System ID и locale — BCK-20.

## 12. Идемпотентность, конкуренция, неизвестный исход

- Callables — идемпотентность BCK-03 §16 (`eventIngestionIdempotency`).
- Run — lease на источник; эффекты идемпотентны по `(runId, bindingKey)`.
- **Неизвестный исход команды Content (BCK23-D11):**
  1. до вызова записать в `SourceEventRecord.pendingContentOperation`
     `{operationKey, logicalOperation, payloadHash, expectedRevision,
     attemptedAtUtc}`; `operationKey` детерминирован (BCK-07 §7.4: актор,
     binding, операция, hash, ревизия);
  2. таймаут или падение → следующий run повторяет **тот же** ключ; BCK-07
     возвращает исходный результат или выполняет впервые;
  3. при необходимости — поиск в Content по `externalBindingRef`
     (нужен запрос BCK-07, §21);
  4. тот же ключ с другим payload → `idempotency_conflict` → стоп и
     `ReviewItem(fieldConflict)`;
  5. новая логическая операция по той же связи не начинается, пока
     предыдущая не разрешена.

## 13. Кеш, свежесть, деградация

Свежесть: `fresh`, если `now − lastSuccessAtUtc ≤ max(3 × интервал, 24 ч)`
(`notModified` — успех), иначе `stale`; при `stale` цена и ссылка на билеты
отдаются с пометкой «уточняйте у организатора». Robots cache — 24 ч. HTTP cache —
`ETag`/`Last-Modified`.

## 14. Миграция и совместимость

Пустое начальное состояние; миграции данных нет. Mobile-демо (продуктовый E2)
не импортируется в backend. Изменения `import_profile` действуют только на
новые события.

## 15. Outbox и доставка

Нет до OD-09 Accepted (§7.3). После — envelope `platform/v1/event_envelope`,
at-least-once, дедупликация потребителем.

## 16. Privacy, согласие, хранение, Legal

- URL (§4.1): явные credentials и известные auth-параметры отклоняются,
  публичность endpoint подтверждает человек, полный URL — restricted и не
  покидает `eventIngestionSources`; это снижает, но не исключает риск
  случайного секрета в URL.
- Согласие: `authorization` источника (основание, версия и hash текста
  согласия, `delegationId`).
- Персональные данные организаторов из источника не сохраняются.
- Изображения: **без default cover и без hotlink (BCK23-D12)**; изображение
  источника — только через Media (BCK-14) при праве на изображения, после
  готовности соответствующих слайсов; иначе отсутствует и событие уходит в
  `needsCompletion` по обычной проверке. Описание не синтезируется: если его
  нет — оно отсутствует (краткое описание допускается только как дословная
  выдержка из текста источника, иначе дополняет оператор).
- Хранение — §10; Legal review — до staging-пилота (roadmap B8).

## 17. Abuse и лимиты

`startProbe` ≤ 20/час на актора; `connectSource` ≤ 10/сутки на актора;
≤ 5 источников на Place; интервал ≥ 60 мин; App Check — сигнал, не авторизация.

## 18. Наблюдаемость и стоимость

Метрики, алерты, логи — продуктовая спецификация §20; логи без тел ответов;
вместо URL — только хост и `sha256(canonicalUrl)`. Бюджет `event-ingestion` + kill switch (правило cost model);
метки `app`, `environment`, `managedBy`, `module=event-ingestion`.

## 19. Флаги, rollout, rollback

Флаги `FirestoreFeatureFlagGate` по рынкам, все выключены:
`event-ingestion.source.connect`, `.sync`, `.kind.ical`, `.kind.jsonld`,
`.auto-submit`, `.cancellation.auto`, `.staff-approval.skip`, `.notifications`.
`.cancellation.auto` включается вместе с `.sync` (BCK23-D07); его выключение —
аварийный режим: явные отмены — только через review. Аварийное отключение — `SecurityFlagRevision`. Rollback — флаги off; полный
откат — revoke источников и архивирование через Admin repair командами
Content. Coordinated restore — §19.1.

### 19.1. Coordinated restore

1. Выключить `event-ingestion.sync` и `event-ingestion.source.connect` на всех
   рынках.
2. Восстановить состояние EVS (sources, records, runs, делегации в identity) и
   Event authority из одной совместимой точки в изолированную базу.
3. Сверить `bindingKey` ↔ Event и незавершённые `pendingContentOperation`.
4. Только после сверки включить флаги.

## 20. Точная карта файлов

### 20.1. EVS-LOCAL-01a — схемы, fixtures, чистый domain (без сети)

Новые файлы (все):

```text
packages/api_contracts/schema/event_ingestion/v1/
  event_ingestion_common.schema.json
  event_source.schema.json
  sync_run.schema.json
  source_event_record.schema.json
  review_item.schema.json
  normalized_event.schema.json
  event_ingestion_command.schema.json
  event_ingestion_query.schema.json
  event_ingestion_result.schema.json
  fixtures/valid.json
  fixtures/invalid.json                 // команды с неизвестными полями; неподдерживаемая версия контракта;
                                        // URL с credentials/auth-параметрами; без publicEndpointConfirmed
  fixtures/forward.json                 // только persisted/read DTO §8: неизвестные additive-поля сохраняются
  fixtures/conformance/README.md
  fixtures/conformance/feeds/ical/{basic, simple_weekly_rrule, daily_count_rrule,
      rdate_exdate, cancelled_event, tentative, private_class, dst_gap_riga,
      dst_overlap_riga, windows_tzid, floating_time, all_day, series_time_shift,
      unsupported_monthly_rrule, recurrence_id_override, missing_uid}.ics
  fixtures/conformance/feeds/jsonld/{single_event, graph_multiple, no_price,
      price_range, free, cancelled, postponed, moved_online, subevent_program,
      age_range, microdata_only_ignored, script_type_case}.html
  fixtures/conformance/normalize/<feed>.expected.json      // по одному на фид (28)
  fixtures/conformance/reconcile/{001…033}_<case>.json     // §21.1

apps/backend/functions/src/contracts/event_ingestion_v1.ts
apps/backend/functions/src/contracts/event_ingestion_schema_registry.ts
apps/backend/functions/src/contracts/validate_event_ingestion_contract.ts

apps/backend/functions/src/modules/event_ingestion/domain/
  event_source.ts
  import_profile.ts
  delegation_ref.ts          // доменный вид делегации identity (§9.2)
  url_policy.ts              // §4.1
  binding_key.ts             // §11, канонизация URL
  sync_run.ts
  source_event_record.ts
  content_operation.ts       // pendingContentOperation, §12
  review_item.ts
  normalized_event.ts
  change_classifier.ts
  sanity_gate.ts
  reconciler.ts              // чистая функция: снимок + состояние → решения
  duplicate_detector.ts      // только кандидаты
  field_authority.ts
  local_time.ts              // Intl + DST, RFC 5545 §3.3.5
  failures.ts
  repositories.ts            // только интерфейсы

apps/backend/functions/test/unit/event_ingestion/event_ingestion_domain.test.ts
apps/backend/functions/test/unit/event_ingestion/url_policy.test.ts
apps/backend/functions/test/unit/event_ingestion/local_time.test.ts
apps/backend/functions/test/contract/event_ingestion_fixture_parity.test.ts
apps/backend/functions/test/contract/event_ingestion_reconcile_conformance.test.ts

apps/backend/scripts/verify-event-ingestion-layout.mjs
apps/backend/scripts/verify-event-ingestion-contracts.mjs
```

Изменяемые файлы (все):

| Файл | Изменение |
|---|---|
| `apps/backend/functions/package.json` | `verify:event-ingestion:layout`, `verify:event-ingestion:contracts`, `test:event-ingestion:unit`, `test:event-ingestion:contract`, `test:event-ingestion` |
| `.github/workflows/backend-r1.yml` | + `verify:event-ingestion:layout` в шаг layout; + `test:event-ingestion` в шаг тестов |

Не меняются: `index.ts`, `firestore.rules`, `firestore.indexes.json`,
реестры security, `feature_flags.ts`, `verify-r1-layout.mjs`,
`verify-r1-exports.mjs`, config, infra, mobile. Новые пути не попадают в
корни точной карты R1 (`src/security`, `src/platform`, `test/unit/{config,
security,platform}`, `test/rules`, `test/integration`, `config`, `infra/env`).
Зависимости не добавляются. Правило импорта: `domain/` не импортирует
Firebase, transport, Booking, Catalog и fixtures других доменов —
проверяется `verify-event-ingestion-layout.mjs`.

В 01a conformance `normalize/` — только данные и проверка формата; их
исполнение начинается с парсеров в 01b. `reconcile/` исполняется чистым
reconciler в 01a.

### 20.2. Следующие слайсы (индикативно; точные карты — в их решениях)

01b — парсеры iCal V1 и JSON-LD в `infrastructure/adapters/`, сервисы,
in-memory репозиторий, fake fetcher и fake content import;
01c — сложные повторения (§4.1); 02 — Firestore (после §10); 03 — fetcher,
callables §7.1 и workers в Emulator; 04 — связка с настоящими модулями
(требует отдельного Content persistence slice) — roadmap §5–§9.

## 21. Тестовая матрица

### 21.1. Кейсы `reconcile/` (01a)

```text
001_first_sync_owner_review                 018_rejected_until_material_change
002_first_sync_auto_submit_complete         019_not_modified_no_missing
003_auto_submit_incomplete_draft            020_explicit_cancel_applied
004_identical_resync_noop                   021_cancel_conflict_two_sources
005_reschedule_single_event                 022_series_cancel_archive
006_series_time_shift_rekey                 023_no_price_unknown
007_missing_once_no_action                  024_open_entry_unknown_payment
008_missing_twice_hidden_review             025_dst_gap_needs_confirmation
009_site_broken_20_to_0_quarantine          026_velocity_deferred_nearest_first
010_drop_20_to_8_quarantine                 027_unsupported_recurrence_review
011_cross_source_same_uid_review_candidate  028_content_outcome_unknown_same_key
012_cross_source_ticket_url_review_candidate 029_delegation_invalid_pauses_source
013_similar_manual_event_review_candidate   030_missing_image_stays_missing
014_content_lock_skipped                    031_hidden_returns_restored
015_operational_edit_rejected               032_cancel_flag_off_review
016_detached_ignored                        033_keep_active_not_hidden
017_weak_identity_owner_review
```

### 21.2. Прочее

| Уровень | Что | Слайс |
|---|---|---|
| Contract | valid/invalid/forward; parity TS ↔ JSON Schema | 01a |
| Conformance | 33 reconcile-кейса | 01a |
| Unit | URL policy, local time (DST 2026-03-29/2026-10-25), binding key, классы изменений, sanity gate, кандидаты | 01a |
| Conformance | 28 normalize-кейсов | 01b |
| Integration | Сервисы, делегация, cross-page deny, staff не отправляет | 01b |
| Rules/Emulator | Deny, lock-документы, lease, повтор run | 02 |
| Security | SSRF, redirect allowlist, лимиты, robots | 03 |

## 22. AC, DoR, DoD, нереализованное

### 22.1. AC (01a)

1. Только пути §20.1; ни одного изменения вне таблицы изменяемых файлов.
2. Схемы: `$id` event-ingestion/v1, `$ref` на platform/identity v1, команды с
   `additionalProperties: false`, границы `maxItems`/`maxLength`, list-запросы
   с `pageSize` 1…50 и cursor page.
3. `valid` принимается; в `invalid` команды с неизвестными полями отклоняются
   (`invalid_argument`), неизвестная версия контракта — `unsupported_contract`,
   URL с credentials/auth-параметрами — `url_not_public`; `forward` содержит
   только persisted/read DTO §8, и их неизвестные additive-поля сохраняются.
4. Все 33 кейса `reconcile/` дают ожидаемые решения чистым reconciler.
5. Ни одно решение не объединяет события автоматически, кроме одинакового
   `bindingKey`; пропажа только скрывает дату (`hideOccurrence`) и открывает
   проверку — никогда не отменяет; отмена — только по явному статусу
   источника или решению команды.
6. Отсутствующие цена, изображение и описание остаются отсутствующими.
7. `domain/` без Firebase, сети и чужих доменов; зависимости не добавлены.
8. `verify:event-ingestion:*`, `test:event-ingestion`, `test:r1` зелёные на
   точном toolchain (Node 22.23.2, npm 10.9.8).

### 22.2. Definition of Ready для 01a (итог «Захода 6»)

- [x] текущая незакоммиченная работа ветки бэкенда сохранена (2026-09-28,
      `526f497`);
- [x] во всех четырёх нормативных документах обновлено «last verified
      against» по ветке на момент переноса, пакет пересобран;
- [x] четыре нормативных документа (ADR 0020, продуктовая спецификация,
      BCK-23, master roadmap) перенесены в ветку бэкенда отдельным docs-only
      коммитом;
- [ ] перенесённые документы прочитаны полностью исполнителем бэкенда;
- [ ] сверка с BCK-02/03/04/05/06/07/16/20/22 (§23) без открытых
      противоречий;
- [ ] BCK-23 зарегистрирован в BCK-02 как item **6E**; отдельно обновлены
      BCK-05, BCK-06 и BCK-20;
- [ ] решения BCK23-D01…D18 (§24) приняты владельцем;
- [ ] execution manifest дополнен (§25);
- [ ] owner approval записан.

Тогда вердикт — **«Ready to implement EVS-LOCAL-01a»**; runtime, Firestore,
fetcher, сеть и облако по-прежнему не создаются.

### 22.3. Definition of Done (01a)

AC §22.1 + review кода + запись evidence в BCK-23 changelog и LAUNCH_STATUS.

### 22.4. Нереализованное

Всё runtime; `EventIngestionDelegation` и `PagePlaceOperatorLink` в identity; запрос Content по
`externalBindingRef`; Content persistence slice; retention (BCK04-OD-07);
транспорт workers и OD-09; облачные флаги.

## 23. Сверка с backend-документами

| Документ | Что использует EVS | Состояние |
|---|---|---|
| BCK-02 v2.4.99 §31.1 | Резерв модуля, коллекций, identity, label, allowlisting, restore | Совместимо; нужна регистрация **6E**, строка реестра и runtime-волна |
| BCK-03 v0.3.22 | Envelopes, async operation, пагинация §19, неизвестные поля §25.2, коды `unsupported_contract`/`unsupported_schema` | Совместимо; `cursor_invalid` регистрируется в домене EVS |
| BCK-04 v0.4.35 | Классы данных (`restricted` для URL), `CollectionAccessMatrix`, retention | Нужны решения BCK04-OD-07 до слайса 02 |
| BCK-05 v0.2.41 | Общий port leased jobs (fencing, повтор, dead-letter, replay), облачные флаги, бюджет, egress, restore | Нужны поправки: общий port leased jobs без доменных состояний Booking (EVS не импортирует `booking/event_projection_delivery`, записи задач у модулей свои), политика исходящей сети, строка бюджета, restore §19.1 |
| BCK-06 v0.8 | Capabilities, membership, eligibility | Нужны поправки: 2 capabilities, `EventIngestionDelegation`, `PagePlaceOperatorLink` |
| BCK-07 v0.7 | `ownerImport`, `originBinding`, change class, идемпотентность, `content.hide`/`content.restoreVisibility` | Совместимо; для слайса 04 нужны запрос по `externalBindingRef`, обратимое скрытие по `sourceMissing` командой делегированного импорта (Event целиком и одна дата `multiDate`, без уведомлений) и отдельный Content persistence slice |
| BCK-16 v0.3.1 | Модель egress §11/§25 | Совместимо; fetcher внутри EVS до выноса в платформу (BCK23-D14) |
| BCK-20 v0.2.29 | Category System ID, locale, `event_source_category_map` | Нужна регистрация набора до слайса 01b (маппинг категорий) |
| BCK-22 v0.3.1 | Report и EnforcementCase, типизированные effects владеющим доменам | Совместимо; нужен типизированный сигнал со ссылкой на case по импортированному Event. Данные жалобы в EVS не копируются; приостановка источника — командой EVS |

## 24. Решения «Захода 6»

| ID | Решение (предложение) | Статус |
|---|---|---|
| BCK23-D01 | V1 — без явных credentials и известных auth-параметров; подтверждение публичности endpoint; полный URL — restricted; приватные фиды вне V1 (§4.1) | Ждёт owner approval |
| BCK23-D02 | JSON-LD — только `<script type="application/ld+json">` (§4.1) | Ждёт |
| BCK23-D03 | iCal V1 — подмножество §4.1; сложное — 01c | Ждёт |
| BCK23-D04 | Постоянная делегация identity (§9.2) | Ждёт; требует поправки BCK-06 |
| BCK23-D05 | `event_sources.manage`, `event_sources.review_changes`, `content.submit` (§9.1) | Ждёт; поправка BCK-06 |
| BCK23-D06 | Идентичность `sourceId + externalUid + recurrenceKey`; без автообъединения (§11) | Ждёт |
| BCK23-D07 | Будущая дата пропала на 2 успешных проверках подряд → скрыть без отмены и уведомлений + `ReviewItem(missingFromSource)`; вернулась в источник → показать; явная отмена в источнике — сразу, `.cancellation.auto` — аварийный выключатель (§7.2; продуктовая спецификация §12.6–§12.7) | **Принято 2026-09-27** в изменённой редакции |
| BCK23-D08 | Retention до Firestore; TTL только после BCK04-OD-07 (§10) | Ждёт |
| BCK23-D09 | Транспорт: локальные слайсы без триггеров; workers — через общий port BCK-05 для leased jobs (без импорта из Booking, свои записи задач); outbox — после OD-09 | Ждёт |
| BCK23-D10 | 7 callables (§7.1) | Ждёт |
| BCK23-D11 | Provenance `ownerImport` + сверка неизвестного исхода (§12) | Ждёт |
| BCK23-D12 | Без default cover и hotlink; отсутствующее остаётся отсутствующим (§16) | Ждёт |
| BCK23-D13 | Свои ограниченные парсеры, без новых runtime-зависимостей | Ждёт |
| BCK23-D14 | Egress по модели BCK-16; fetcher внутри модуля до выноса в платформу | Ждёт |
| BCK23-D15 | `PagePlaceOperatorLink` — writer BCK-06; Place — BCK-07 (§9.3) | Ждёт; поправка BCK-06 |
| BCK23-D16 | Лимит `100/day` Create §15 сохраняется; излишек — в следующие окна, ближайшие по дате — первыми | **Принято 2026-09-27** |
| BCK23-D17 | Подключение возвращает `sourceId` + `initialSyncOperationId`; пагинация list-callables по BCK-03 §19 (§7.1.1) | Ждёт |
| BCK23-D18 | Неизвестные поля команд отклоняются; `unsupported_contract` для новых версий; сохранение — только persisted/read DTO (§8) | Ждёт |

## 25. Дополнение execution manifest

Без создания ресурсов:

| Пункт | Запись |
|---|---|
| Коллекции | 11 имён §6, префикс `eventIngestion*`, writer `event-ingestion`, клиент deny; `eventIngestionSources` — restricted (полный URL) |
| IAM | `runtime-event-ingestion` (не создаётся); будущие права — Firestore, постановка задач, логи/метрики; без Storage и Secret Manager |
| Budget | Отдельная строка `event-ingestion` + kill switch; метка `module=event-ingestion` |
| Outbound network | Разрешён только `runtime-event-ingestion`, только по allowlist источников (§4.1); до EVS-DEV-01 — никакого исходящего трафика |
| Coordinated restore | §19.1 |
