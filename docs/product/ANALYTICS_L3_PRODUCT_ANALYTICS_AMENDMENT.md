# L3 — минимизированная продуктовая аналитика

- ID: **ANALYTICS-L3**
- Версия: **0.2 (реализация в local/Emulator и mobile unit объёме)**
- Дата: **2026-10-25**
- Статус: **Review — локальная реализация §13; production collection выключен**
- База: `claude/l2-operational-recovery` @ `e3ad2f3` (поверх L1 `c880f08` и
  `codex/recharge-integration` @ `bcebd60`), ветка `claude/l3-product-analytics`
- Расширяет: [BCK-21](ANALYTICS_TELEMETRY_BACKEND_SPEC.md) v0.3 (Review),
  [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md), [L1](PRIVACY_L1_DSR_RETENTION_HOLD_AMENDMENT.md),
  [L2](OPERATIONS_L2_RECOVERY_AMENDMENT.md)
- Runtime-эффект: только local/Emulator и unit-тесты mobile. Внешнего
  provider, SDK, сетевой доставки, cloud и реальных данных нет.

Документ фиксирует фактическое состояние кода на базе и контракт L3 до
реализации. Локальные тесты не являются юридическим подтверждением и не
являются production evidence.

## 1. Принятая база и её пределы

| Источник | Что есть | Чего нет |
|---|---|---|
| BCK-21 v0.3 | Review-контракт: typed registry, ingress-валидация, dedupe по `eventId`, suppression, раздельные flags, отделение от BCK-05 и domain audit, AC-01…AC-75 | Не Approved; BCK21-OD-01…OD-10 открыты: destination, legal basis/consent, subject keys, retention, каталог и owners, batching, access thresholds, experiments, client queue, SLO |
| BCK-04 | Классы данных, запрет default retention вне Booking (§19.2) | Analytics retention не задана |
| L1 | Единственный DSR runner, writer registry с coverage-тестом, erasure и restriction ставят аккаунт в `restricted` и отзывают Sessions | Обработчика analytics нет (данных нет) |
| L2 | Registry task families с coverage-тестом, audited console, emergency switches | Analytics-семьи нет |
| BCK21-OD-03 (fail-closed default) | «No stable/pre-auth identity» | Ключ субъекта и его ротация не приняты |
| BCK21-OD-04 (fail-closed default) | «Persistence off» без принятой retention | — |

Следствие: L3 реализует только независимые контракты и синтетический
локальный путь. Всё, что зависит от OD-01…OD-04 и OD-07…OD-10, остаётся
выключенным (§10).

## 2. Inventory: producers, SDK, sinks, queues (по коду)

Классификация — по фактическому назначению и sink, а не по названию.

| # | Где | Что делает | Sink / queue | Классификация |
|---|---|---|---|---|
| M-1 | mobile `core/telemetry/analytics_service.dart` — `AnalyticsService` / `ConsoleAnalyticsService` | 72 литеральных имени событий и 2 вычисляемых (`app_route_observer`, `class_workshop_details_page`); вызовы `.track(` в 21 файле, включая обёртки M-2; параметры содержат сырые `user_id`, `item_id`, `notification_id`, `visit_id`, `request_id`, `rental_id`, `object_id`, город и категорию | только `dart:developer` log; нет очереди, persistence, сети | Legacy developer console diagnostics. **Не** product analytics: не импортируется, не backfill, не мост в L3 (BCK-21 §23, AC-51/52/54) |
| M-2 | mobile `collection_create_telemetry`, `scenario_transit_telemetry`, `scenario_object_intake_telemetry` | Типизированные обёртки над M-1 | тот же console log | Как M-1 |
| M-3 | mobile `core/telemetry/provider_cost_ledger.dart` | Учёт стоимости вызовов AI provider | in-memory | Operational cost control |
| M-4 | mobile `file_*_publication_journal`, import journal, Booking operation journal, RTE-11 GPS journal | Состояние синхронизации домена | файлы на устройстве | Domain state |
| B-1 | backend `platform/observability/structured_logger.ts` | Operational log records с запретом чувствительных полей | in-memory | BCK-05 operational telemetry |
| B-2 | backend `platform/observability/metrics.ts` | 4 platform-метрики | in-memory | BCK-05 operational telemetry |
| B-3 | backend `security/security_audit_port.ts`, `securityAuditEvents` | Security audit | in-memory / Firestore | BCK-04 security audit |
| B-4 | backend domain audits (`bookingAudit`, `contentAudit`, `mediaAudit`, `moderationAudit`, `reviewAudit`, `safetyAudit`, `adminReadAudit`, `operationsOperatorAudit`, `privacyLegalHoldAudit`, …) | Доказательство действий владельца | Firestore | Domain / operator audit |
| B-5 | backend outboxes и очереди TF-01…TF-14 (L2) | Доставка domain effects | Firestore | Operational / domain queues |
| SDK | `apps/mobile/pubspec.yaml`, `apps/backend/functions/package.json` | Analytics SDK нет (Firebase — только core/auth/admin) | — | — |

Вывод: product analytics в коде отсутствует. L3 создаёт единственную
product analytics boundary; M-1…B-5 в неё не входят и не копируются.

## 3. Минимальный набор событий v1

Каждое событие — клиентский UX-факт. Ни одно не является authoritative
business fact и не используется как доказательство публикации, сохранения,
брони, участия, оплаты или санкции: эти факты остаются у Content, Library,
Booking и T&S.

| Событие | Версия | Вопрос, на который отвечает | Producer (единственный) | Поля (allowlist) |
|---|---|---|---|---|
| `details_opened` | 1 | Объекты каких типов открывают в Details? | mobile `DiscoverDetailsPage` при первом успешном показе | `object_kind` |
| `favorite_added` | 1 | Объекты каких типов сохраняют в Favorites и с какой поверхности? | mobile `FavoritesController.addFavorite` после успешного добавления | `object_kind`, `entry_surface` |
| `create_publish_finished` | 1 | Для каких Create-типов отправка на публикацию заканчивается отказом? | mobile `CreateController` по итогу publish | `create_type`, `outcome` |

Значения полей — только перечисления:

- `object_kind`, `create_type`: `event`, `activity`, `route`, `place`,
  `session`, `scenario`, `find_people`, `class_workshop`, `rental`,
  `collection` (10 принятых типов; legacy `quick_plan` не отправляется);
- `entry_surface`: `details`, `map`, `planner`, `other`;
- `outcome`: `published`, `submitted`, `denied`, `failed`.

Владельцы (роли из BCK-21; персональное назначение — BCK21-OD-05, открыт):

| Событие | Владелец события (вопрос) | Владелец обработки |
|---|---|---|
| `details_opened` | Product — Discover | Data Platform (BCK-21) |
| `favorite_added` | Product — Library | Data Platform (BCK-21) |
| `create_publish_finished` | Product — Create | Data Platform (BCK-21) |

## 4. Envelope, schema/version, allowlist

Каноническое определение — `packages/api_contracts/schema/product_analytics/v1/
product_analytics_event_registry.v1.json`; backend и mobile держат typed
registry и проверяют его равенство этому файлу; общий синтетический корпус —
`fixtures/product_analytics_corpus.v1.json`.

Batch (client → ingress): `{ schemaVersion: 1, events: [...] }`.

Событие:

| Поле | Тип | Правило |
|---|---|---|
| `eventId` | UUID v4, lowercase | Генерирует клиент; случайный, без времени; ключ dedupe |
| `eventName` | enum | Только §3 |
| `eventVersion` | int | Только зарегистрированная версия; иначе отказ |
| `occurredAtUtc` | ISO-8601, ровно час (`…T13:00:00.000Z`) | Клиент округляет вниз до часа |
| `policyRevision` | string | Ревизия policy, при которой событие собрано |
| `fields` | object | Ровно поля события из §3, только значения enum |

Неизвестные ключи на любом уровне, неизвестные события, версии и значения,
строки вне enum, вложенные объекты и массивы — отказ (`rejected_schema` для
события или `batch_invalid` для batch). Ничего «про запас» не сохраняется:
отвергнутое не пишется ни в storage, ни в логи. Изменение смысла, типа,
обязательности или enum создаёт новую версию (BCK-21 AC-09).

Запрещено во всех полях по построению (allowlist не имеет мест для них):
free text, поисковые запросы, тексты отзывов и жалоб, invitation tokens,
Session handles, секреты, URL, координаты, Route geometry, GPX, account,
page, workspace, object, device, installation ID.

## 5. Data class, purpose, основание и consent

| Запись | Data class (BCK-04) | Purpose (заявленный) | Основание / consent |
|---|---|---|---|
| Событие в клиентской очереди | `personal` | `product_usage_measurement` | **не принято** (BCK21-OD-02) |
| Принятое событие (raw zone) | `personal` | `product_usage_measurement` | **не принято** |
| Дневной агрегат | `personal` — не объявляется анонимным (нет методики, OD-07) | `product_usage_measurement` | **не принято** |
| Access authority и access audit | `personal` (staff) | контроль доступа | test-only registry |

Purpose заявлен, но не принят; legal basis в registry — `null`. Поэтому
активная `CollectionPolicy` в production не существует, и сбор выключен.
Механизм политики реализуется полностью и проверяется синтетической
политикой с `source: synthetic-test-only`:

- policy читается сервером; клиентская копия — только для планирования
  (BCK-21 §11), сервер проверяет заново;
- если policy требует consent, сервер читает состояние consent из
  серверного порта; client claim о consent отвергается как неизвестный ключ;
- в production порт consent отсутствует (`unknown`), что равно отказу.

Client DOB, возраст и признаки несовершеннолетия в события не входят и
ничего не разблокируют; profiling, experiments и age-sensitive analytics
отсутствуют (OD-08).

## 6. Идентификаторы и корреляция

- Вопросы §3 отвечаются счётчиками по типу и дню; связь с субъектом им не
  нужна. Поэтому событие и его серверная запись **не содержат** account,
  Session, device, installation и pseudonymous subject key (BCK21-OD-03
  fail-closed). Хеш account ID также не используется.
- `eventId` — случайный UUID v4; клиент удаляет его после подтверждённого
  ответа; сервер хранит его только как ключ dedupe на срок raw retention.
- Сервер хранит день (`occurredDayUtc`), а не время.
- Сессия на ingress нужна только для проверки, что отправитель — текущий
  активный аккаунт с принятой policy и consent; её ID в запись не попадает.
- Корреляции между событиями, сессиями, устройствами и доменами нет;
  fingerprinting и cross-context identifier не вводятся.
- Клиентская очередь изолирована по аккаунту: ключ namespace — SHA-256 от
  account ID (только на устройстве); смена или выход аккаунта удаляет
  буферы всех других аккаунтов до любой отправки. Любое неаутентифицированное
  состояние, включая промежуточное `loading`, отвязывает аккаунт: события
  не собираются, очередь удаляется (потеря событий допустима, смешение — нет).

Отсутствие идентификатора — не заявление об анонимности (§11, PA-B05).

## 7. Retention, DSR, агрегирование и доступ

**Retention.** Числовых сроков нет (BCK21-OD-04). Policy несёт
`rawRetentionHours`, `aggregateRetentionHours`, `acceptanceWindowHours`,
`queueMaxAgeHours`; без принятой policy сервер ничего не сохраняет
(`policy_unavailable`), клиент ничего не ставит в очередь. Инварианты,
проверяемые при чтении policy: `acceptanceWindowHours < rawRetentionHours`,
`queueMaxAgeHours ≤ acceptanceWindowHours`. Срок записи (`expiresAtUtc`)
считается от начала дня события, поэтому все события дня истекают вместе.
Проверка сроков: клиентская очередь (возраст при записи и отправке), raw
zone и агрегаты (sweep по `expiresAtUtc`, работает и при выключенном сборе).

**Агрегирование.** Один документ на день с отсортированными строками
`(eventName, eventVersion, поля, count)` и детерминированным fingerprint.
Пересборка — полный пересчёт дня из raw zone одной записью; повтор даёт тот
же результат. Счётчик — число уникальных `eventId`, поэтому повторы и
retry его не увеличивают. День, чьи raw-события начали истекать, не
пересобирается (`window_expired`): удалённое не возвращается и частичный
агрегат не публикуется. Порог малых групп не принят (OD-07): агрегаты не
публикуются и не объявляются анонимными.

**DSR.** Серверные записи аналитики по контракту не связаны с субъектом,
поэтому DSR их найти не может; это фиксируется в writer registry L1 как
`not_subject_data` с явной оговоркой, а не как удаление. Действия DSR:

- erasure и restriction ставят аккаунт в `restricted` и отзывают Sessions
  (L1) → ingress отказывает (`unauthenticated`), повтор и replay старого
  буфера ничего не сохраняют;
- клиент при выходе, смене аккаунта, opt-out и отказе Session удаляет
  очередь аккаунта;
- достаточность этого для DSR — PA-B05.

**Доступ.** Клиентского чтения нет (Rules: deny). Сырые события и export —
не реализованы как операции чтения: запрос всегда `policy_unavailable`
и аудируется как отказ. Чтение дневных агрегатов — только staff Session с
capability `product_analytics.aggregate.read` из test-only registry, с
ограничением диапазона (≤ 31 день), аудит в той же транзакции; ответ
содержит только строки агрегата и fingerprint. Production authority — PA-B07.

## 8. Лимиты buffers, batches, payload, retries

Технические локальные границы L3; production-значения — OD-09/OD-10.

| Граница | Значение | Поведение при нарушении |
|---|---|---|
| Очередь на аккаунт | ≤ 100 событий и ≤ 32 768 байт | Новое событие отбрасывается (drop newest), счётчик `overflow` |
| Событие (canonical JSON) | ≤ 512 байт | Отбрасывается до очереди, счётчик `oversized` |
| Возраст в очереди | ≤ `queueMaxAgeHours` policy | Удаляется при записи и перед отправкой, счётчик `expired` |
| Batch | ≤ 20 событий и ≤ 8 192 байт | Клиент режет; сервер отвергает весь batch (`batch_invalid`) |
| Попытки | ≤ 5 на событие | После пятой неуспешной — удаление, счётчик `attempts_exhausted` |
| Таймаут отправки | 10 с | Исход `unknown`: событие остаётся, попытка засчитана |
| Сдвиг часов | будущее ≤ 5 мин; прошлое ≤ `acceptanceWindowHours` | `rejected_late`, не сохраняется |

Диагностика — только счётчики по коду причины; без имён полей, значений и
ID. Recorder синхронный, никогда не бросает исключение и не ждёт доставки.

## 9. Разделение потоков

- Product analytics (L3) отвечает только на вопросы §3.
- Security audit (B-3) и domain/operator audit (B-4) не читают и не
  получают события L3; L3 не пишет в них, кроме собственного access audit.
- Operational telemetry (B-1, B-2) не получает payload L3; ingress не
  пишет логов с содержимым событий.
- Флаги `productAnalytics.collection` и `productAnalytics.aggregation`
  (default off) выключают только L3; security audit, operations console L2
  и пользовательские команды от них не зависят.
- Отказ любой части L3 (очередь, sink, ingress) не меняет результат
  пользовательского действия.
- L3 пишет только в собственные коллекции `productAnalytics*`.

## 10. Выключенные paths

| Path | Почему выключен | Кто включает |
|---|---|---|
| Production collection (policy, legal basis, consent source) | OD-02 | Legal/Privacy + Product |
| Сетевая доставка mobile → backend, callable ingress | OD-01, OD-09 | Data Platform + Mobile Platform + Ops |
| Внешний provider / SDK / destination | OD-01 | Data Platform + Security + Legal |
| Persistent (файловая, зашифрованная) клиентская очередь | OD-09 | Mobile Platform |
| Расписание retention sweep и aggregation | OD-10 | Ops + Data Platform |
| Raw read, export, публикация агрегатов, dashboards | OD-07 | Data governance + Security |
| Subject key, pre-auth события, distinct-user метрики | OD-03 | Identity + Security |
| Experiments, personalization, age-sensitive analytics | OD-08 | Product + Legal + Security |
| Backfill legacy console (M-1) | BCK-21 AC-52 | — (запрещено) |

## 11. Policy blockers

| ID | Blocker | Чья policy | Что блокирует |
|---|---|---|---|
| PA-B01 | Purpose и legal basis `product_usage_measurement`; нужен ли consent | BCK21-OD-02 | Production collection |
| PA-B02 | Источник consent и правило для уже собранного буфера при opt-out (L3 удаляет его — BCK-21 §15/AC-29) | BCK21-OD-02, OD-09 | Consent source |
| PA-B03 | Сроки: client queue, raw, aggregates, access audit | BCK21-OD-04 | Persistence |
| PA-B04 | Destination, transport, residency | BCK21-OD-01 | Delivery |
| PA-B05 | Являются ли несвязанные события (enum, день, случайный `eventId`) персональными данными и обязан ли DSR их достигать | Legal/Privacy (BCK-04) | Признание DSR достаточным |
| PA-B06 | Методика анонимизации и порог малых групп | BCK21-OD-07 | Публикация агрегатов |
| PA-B07 | Production authority доступа к агрегатам, raw и export, сроки access audit | BCK21-OD-07, BCK19 | Staff access |
| PA-B08 | Персональные владельцы событий и lifecycle каталога | BCK21-OD-05 | Активация каталога |
| PA-B09 | Production лимиты очереди, batching, retry/backoff, battery/network | BCK21-OD-06, OD-09 | Mobile delivery |
| PA-B10 | SLO, rate limit ingress, quarantine, cost | BCK21-OD-10 | Cohort |

## 12. Обязательные проверки → тесты

| № | Проверка | Тест |
|---|---|---|
| 1 | producer → validation/minimization → queue → sink/aggregate для каждого события | mobile `PA-T01`, Emulator `L3-T-FLOW` |
| 2 | Запрещённые и неизвестные поля, free text, secrets, location/GPX, неверная версия | `PA-T02`, `L3-T-REJECT`, unit-корпус |
| 3 | Disable, opt-out, смена consent во время retry, restart, replay после DSR | `PA-T03`, `L3-T-CONSENT`, `L3-T-DSR` |
| 4 | Logout/login другим пользователем | `PA-T04` |
| 5 | Потерянный ответ, duplicate, retries | `PA-T05`, `L3-T-DEDUPE` |
| 6 | Overflow, oversized, unavailable sink, timeout — flow продолжается | `PA-T06`, controller-тесты |
| 7 | Чужая capability/scope, raw read, export, состав ответа | `L3-T-ACCESS` |
| 8 | Retention на queue, raw, aggregates; rebuild не возвращает удалённое | `PA-T03`, `L3-T-RETENTION` |
| 9 | Синтетический provider-neutral путь без сети и SDK | `L3-T-FLOW`, inventory-тесты |
| 10 | Disable аналитики не выключает security audit и operations | `L3-T-ISOLATION` |
| 11 | Inventory/contract ловит новый producer/sink без регистрации; положительный контроль | `L3-T-INV` (backend unit), `PA-T11` (mobile) |

## 13. Реализация (v0.2, local/Emulator и mobile unit)

Второго security audit, operational pipeline, runner или очереди L3 не
создаёт. Production composition mobile регистрирует recorder без policy и
без destination; backend-сервис не имеет callable, trigger и scheduler.

| Механизм | Где | Что делает |
|---|---|---|
| Канонический контракт | `packages/api_contracts/schema/product_analytics/v1/` | Registry v1 (события, поля, enum, лимиты, purpose, `legalBasisRef: null`, `subjectMode: none`) и общий синтетический корпус |
| Mobile contract | `apps/mobile/lib/core/product_analytics/product_analytics_contract.dart` | Sealed typed events, registry, строгая проверка envelope и batch |
| Mobile recorder | `…/product_analytics_recorder.dart`, `…/product_analytics_queue.dart` | Policy и consent только из server-provided snapshot; namespace очереди — SHA-256 от account ID; лимиты §8; unknown ≠ success; результат отправки применяется, только если тот же аккаунт ещё привязан и policy разрешает сбор; production — `NoProductAnalyticsPolicy` + `DisabledProductAnalyticsSink` |
| Producers | `DiscoverDetailsPage`, `FavoritesController`, `CreateController`; привязка аккаунта — `AuthController._setState` | По одному событию на producer, рядом с legacy console-вызовом, без связи с ним |
| Backend contract и policy | `apps/backend/functions/src/modules/product_analytics/product_analytics_contract.ts`, `product_analytics_policy.ts` | Тот же registry; допускается только policy с `source: synthetic-test-only`; production default — нет policy и нет источника consent |
| Ingress | `firestore_product_analytics_service.ts` `ingest` | Batch проверяется до любого чтения; затем policy, flag `productAnalytics.collection`, текущая Session (аккаунт `restricted` отказывает), consent из серверного порта; запись — день, enum-поля, ревизия policy, `expiresAtUtc`; dedupe по `eventId` (`duplicate` / `conflict`) |
| Aggregation | `rebuildDailyAggregate` | Полный детерминированный пересчёт дня одной записью под flag `productAnalytics.aggregation`; день с начавшимся истечением raw — `window_expired` |
| Retention | `expire` | Sweep raw и агрегатов по `expiresAtUtc`; не зависит от flags и policy |
| Access | `readDailyAggregates`, `requestRestricted` | Staff Session + capability `aggregate.read` из test-only registry, аудит в той же транзакции; raw read и export — всегда `policy_unavailable` с аудитом |
| Registries | L1 writer registry (W21), Rules deny, execution manifest, feature flags | Новые коллекции учтены в DSR coverage и закрыты для клиентов |
| Inventory | backend `L3-T-INV`, mobile `PA-T11` | Незарегистрированный producer, sink, queue store, SDK, сетевой путь, смешение с telemetry, новое legacy-имя — падение; положительные контроли |

Остаточные окна (названы, не закрыты):
- consent читается через порт в начале транзакции, а не как документ в ней:
  отзыв в ту же миллисекунду может не остановить один batch;
- сравнение `duplicate` / `conflict` идёт по сохранённым полям (день, а не
  час): разный час одного дня под тем же `eventId` считается повтором;
- сервер не может проверить, что batch собран тем же аккаунтом, который
  его отправляет (связи нет по контракту); защита — изоляция очередей на
  клиенте и проверка Session и consent отправителя;
- persistent-очередь не реализована, поэтому «рестарт» проверяется
  новым recorder над тем же store в процессе.

## 14. Итог: event → purpose → fields → retention → DSR → access

Проверено локально (Firestore Emulator, mobile unit/widget) на синтетических
данных. Это техническая проверка, а не юридическое подтверждение и не
production evidence.

| Event | Purpose | Fields | Retention | DSR | Access |
|---|---|---|---|---|---|
| `details_opened` v1 | `product_usage_measurement` (не принят) | `object_kind` | queue/raw/aggregate — из policy; принятых значений нет | нет связи с субъектом; после erasure/restriction приём от аккаунта закрыт; очередь удаляется при выходе и смене аккаунта | агрегат дня — staff capability `aggregate.read` с аудитом; raw/export — отказ |
| `favorite_added` v1 | то же | `object_kind`, `entry_surface` | то же | то же | то же |
| `create_publish_finished` v1 | то же | `create_type`, `outcome` | то же | то же | то же |

### 14.1 Проверка → тест → результат

| № | Проверка | Тест | Результат |
|---|---|---|---|
| 1 | producer → validation → queue → sink/aggregate | PA-T01 (Favorites, Create, Details), L3-T-FLOW | Каждое событие проходит путь; запись — день и enum-поля, без данных отправителя; посторонние коллекции не меняются |
| 2 | Запрещённые/неизвестные поля, версии, free text, secrets, location/GPX | PA-T02, корпус в обоих runtime, L3-T-REJECT | 28 событийных и 5 batch-случаев отвергнуты; маркеры не найдены ни в storage, ни в выводе консоли; некорректный `eventId` не возвращается |
| 3 | Disable, opt-out, consent во время retry, restart, replay после DSR | PA-T03, L3-T-CONSENT, L3-T-LATE, L3-T-DSR | Без policy/consent/flag ничего не хранится; повтор после opt-out отвергнут; после erasure и restriction replay — `unauthenticated`, rebuild неизменен |
| 4 | Logout/login другим пользователем | PA-T04 (recorder и `AuthController`) | Очередь прежнего аккаунта удаляется до отправки, в том числе во время in-flight отправки и после рестарта |
| 5 | Потерянный ответ, duplicate, retries | PA-T05, L3-T-DEDUPE | Повтор — `duplicate`, счётчик 1; другой payload — `conflict`; unknown ≠ success; попытки ограничены |
| 6 | Overflow, oversized, unavailable sink, timeout | PA-T06 | Лимиты соблюдены, recorder не бросает, Favorites flow завершается |
| 7 | Чужая capability/scope, raw, export, состав ответа | L3-T-ACCESS | Отказ без grant, с чужим action, истёкшим grant, отозванной Session; raw/export — `policy_unavailable`; всё аудировано; ответ — только строки агрегата |
| 8 | Retention и rebuild | PA-T03 (queue), L3-T-RETENTION | Raw и агрегаты удаляются по сроку при выключенных flags; rebuild — `window_expired`, удалённое не возвращается |
| 9 | Provider-neutral путь без сети и SDK | L3-T-FLOW, L3-T-INV, PA-T11 | Только Emulator и in-process sink; сетевых путей и SDK нет |
| 10 | Disable не выключает security audit и operations | L3-T-ISOLATION | Abuse limiter и L2 console работают и пишут свои записи |
| 11 | Inventory ловит новый producer/sink | L3-T-INV, PA-T11 + положительные контроли | Пустой список пробелов на дереве; синтетические нарушения дают ожидаемые коды |

Проверки 2026-10-25, Windows-local, точный toolchain (Node 22.23.2, Temurin
21.0.12+8, Flutter 3.44.9): полный Emulator-набор одной сессией — 24 группы,
включая новую `analytics-l3`, все зелёные; typecheck, lint, format, unit,
contract, security/privacy, identity/publisher, layout, manifest, toolchain,
самотесты runner, boundary и `git diff --check` зелёные; `flutter analyze`
без замечаний, полный `flutter test` зелёный. В integration пять падений,
идентичных базе L2 `e3ad2f3` (Create без валидатора и inventory Content), к
L3 не относятся. CI-лимит задачи не менялся: бюджет набора помещается в
действующие 118 минут.
