# Event Source Ingestion (BCK-23) — master roadmap реализации в backend

Версия: v1.5 (2026-09-28). Статус: **Draft — поправки двух ревью внесены; часть решений владельца записана.**
Рекомендация ревью: принять как master roadmap (`Accepted with amendments`);
статус меняется только записанным решением владельца. Runtime: Absent.

Роль документа: **master roadmap** всей программы BCK-23 — от документов до
production. Нормативный комплект — [ADR 0020](../adr/0020-event-source-ingestion.md),
[продуктовая спецификация](EVENT_SOURCE_INGESTION_SPEC.md),
[BCK-23](EVENT_SOURCE_INGESTION_BACKEND_SPEC.md) (backend-решения и точная карта
файлов первого слайса) и этот roadmap. Бриф, краткий бриф, общий план E0–E9
и концепция — non-normative и в ветку бэкенда не переносятся.

**Minimum compatible documentation baseline** (нормативно): BCK-02 **v2.4.99**,
BCK-03 v0.3.22, BCK-04 v0.4.35, BCK-05 v0.2.41, BCK-06 **v0.8**, BCK-07 **v0.7** (входы
delegated import уже добавлены: `originBinding {directAuthoring |
delegatedImport}`, класс изменения, идемпотентность не-сессионного актора,
AC-92…AC-97), BCK-16 v0.3.1, BCK-20 v0.2.29, BCK-22 v0.3.1, OD-07 Accepted. BCK-02 §31.1
резервирует Event Ingestion без номера; программа предлагает номер **6E**
(6D занят Planning/AI/Providers/Payments).

_Last verified against_ (non-normative; обновляется только при переносе, B0
п.1): ветка `codex/backend-stage8-critical-repair`, коммит `526f497`,
2026-09-28.

Changelog: **v1.5** — поправки ревью: совместимость по минимальным версиям
BCK-документов, SHA — только «last verified against»; общий port BCK-05 для
leased jobs без импорта из Booking; жалобы — только BCK-22; два вердикта
этапа 1. **v1.4** — готовность бэкенда в два этапа, встроенных в его
собственный план (LV roadmap §37): этап 1 (B0 + B1-L) — локально, в слайсах 6A,
6B и малых слайсах BCK-04/05/06/20; этап 2 (B1-C) — dev cloud и платформенные
сервисы; правила «не закрыть дверь»; таблица «что какой EVS-слайс ждёт».
**v1.3** — решения владельца 2026-09-27: пропажа → скрыть без
отмены + проверка, явная отмена — сразу (автоотмена больше не ждёт B10);
требование к BCK-07 — обратимое скрытие; 33 кейса `reconcile`;
baseline — коммит `6c54082`; ссылок на non-normative файлы нет. **v1.2** —
поправки второго ревью: нормативный комплект из
четырёх документов; перенос в ветку бэкенда только после сохранения её
незакоммиченной работы и отдельным docs-only коммитом; `PagePlaceOperatorLink`;
результат подключения и пагинация; правила неизвестных полей; политика URL без
утверждения «секретов нет». **v1.1** — поправки ревью: baseline v2.4.98/v0.8/v0.7; `6E`; этап B0
ограничен «Заходом 6» (только документы и решения, выход — «Ready to
implement EVS-LOCAL-01a»); ADR 0020/BCK-23 не объявляются принятыми до
физического добавления и утверждения; граница JSON-LD; подмножество iCal V1 и
отдельный подэтап 01c; постоянная делегация вместо `grantorUserId`;
`event_sources.review_changes`; retention до Firestore; только публичные URL;
идентичность `sourceId + externalUid + recurrenceKey` без автообъединения;
пропажа → `missingFromSource`/`reviewRequired`; без default cover; отдельный
Content persistence slice; 7 callables вместо 15. **v1.0** — первая версия.

---

## 0. Правила исполнения

1. Каждый этап с кодом — отдельный точный слайс: своя карта файлов, свои AC,
   отдельный коммит; без push/merge, облака и сети без отдельного разрешения.
   Путь вне карты — стоп и поправка BCK-23.
2. Всё выключено по умолчанию: флаги `FirestoreFeatureFlagGate` вне Emulator
   дают `false`; composition root EVS — только при `FUNCTIONS_EMULATOR=true` и
   `GCLOUD_PROJECT=demo-recharge`.
3. Точные поверхности (`verify-r1-layout.mjs`, `verify-r1-exports.mjs`,
   `backend-r1.yml`, список `test:emulator:inside`) меняются только решением
   слайса.
4. Новые зависимости — через `verify-toolchain.mjs` (allowlist лицензий);
   программа планирует **без новых runtime-зависимостей** (BCK23-D13).
5. Тесты не ходят в сеть.
6. EVS не пишет чужие коллекции и не создаёт чужие ID; worker не действует от
   имени пользовательской Session — только по постоянной делегации (BCK23-D04).
7. Статусы документов меняет только владелец.

---

## 1. Карта этапов

| Этап | Слайс | Суть | Код |
|---|---|---|---|
| **B0 — этап 1** | — | Документы и решения («Заход 6»); выход «Ready to implement EVS-LOCAL-01a» (§2.1) | Нет |
| **B1-L — этап 1** | слайсы ядра 6A, 6B, BCK-04/05/06/20 | Зацепки в ядре, локально: Content (импорт, `externalBindingRef`, скрытие `sourceMissing`, `placeId`), identity (права, делегация, связь Place↔оператор), Catalog, Place, retention, общий port leased jobs (§2.2) | Не EVS |
| **B1-C — этап 2** | dev cloud, BCK-05, 6C | Облачная платформа: workers, флаги, исходящая сеть, outbox и уведомления, retention, staff, жалобы, restore, Legal (§3) | Не EVS |
| **B2** | EVS-LOCAL-01a | Схемы, fixtures, conformance, чистый domain | Без сети и Firebase |
| **B3** | EVS-LOCAL-01b | Парсеры iCal V1 и JSON-LD, сервисы, in-memory, fakes | Без сети и Firebase |
| **B3c** | EVS-LOCAL-01c | Сложные повторения iCal (после conformance 01b) | Без сети и Firebase |
| **B4** | EVS-LOCAL-02 | Firestore Emulator, Rules, индексы, реестры (TTL — только после retention) | Emulator |
| **B5** | EVS-LOCAL-03 | Fetcher, 7 callables, workers (при решении транспорта) | Emulator |
| **B6** | EVS-LOCAL-04 | Связка с настоящими Identity, Content persistence, Place | Emulator |
| **B7** | EVS-DEV-01 | Dev cloud | Облако |
| **B8** | EVS-STAGE-01 | Staging-пилот на реальных публичных фидах, только staff | Конфигурация |
| **B9** | EVS-PROD-01 | Production-когорта LV | Конфигурация |
| **B10** | отдельные | Прямая публикация, новые виды, EE/LT | По слайсам |

```text
B0 «Заход 6» ─▶ B2 (01a) ─▶ B3 (01b) ─▶ B3c (01c)
                                  │
   BCK04-OD-07 retention ─────────▶ B4 (02) ─▶ B5 (03) ─▶ B6 (04) ─▶ B7 ─▶ B8 ─▶ B9 ─▶ B10
   транспорт BCK-05 (для workers) ──────────────▲          ▲          ▲     ▲     ▲
   B1-L: identity, Content, Catalog, Place ────────────────┘          │     │     │
   B1-C: dev cloud, workers, сеть + OD-03 ────────────────────────────┘     │     │
   B1-C: уведомления, staff + G5 + Legal ───────────────────────────────────┘     │
   G6 + OD-11 (18+) ──────────────────────────────────────────────────────────────┘
```

---

## 2. Этап 1 готовности — локально, в ходе пункта 6 бэкенда (B0 + B1-L)

**Цель:** к началу EVS в ядре бэкенда уже есть всё, к чему модуль
подключается, и EVS добавляется отдельным модулем без переделки чужих.
Этап встраивается в собственный план бэкенда — пункт 6
([LV roadmap](RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md) §37: 6A Content →
6B Catalog → 6C домены) — и не требует ни облака, ни кода EVS.

### 2.1. B0 — «Заход 6»: документы и решения (без кода EVS)

**Вход:** этот пакет документов. **Код, схемы, runtime, Firestore, fetcher,
сеть и облако не создаются.**

| # | Работа | Результат |
|---|---|---|
| 1 | Не трогать ветку бэкенда, пока её текущая незакоммиченная работа не сохранена. После этого обновить «last verified against» во всех четырёх документах, пересобрать пакет и перенести **четыре нормативных документа** (ADR 0020, спецификация, BCK-23, этот roadmap) отдельным docs-only коммитом и прочитать полностью; бриф, краткий бриф, общий план и концепцию не переносить | Файлы физически в ветке |
| 2 | Сверить с BCK-02/03/04/05/06/07/16/20/22 (BCK-23 §23) | Нет открытых противоречий |
| 3 | Зарегистрировать BCK-23 в BCK-02 как item **6E** (строка реестра, зависимости, runtime-волна); отдельно обновить BCK-05 (сеть, бюджет, restore), BCK-06 (права, делегация, `PagePlaceOperatorLink`) и BCK-20 (набор маппинга категорий) | Ревизии BCK-02/05/06/20 |
| 4 | Записать owner decision по BCK23-D01…D18 (BCK-23 §24): политика URL; граница JSON-LD; подмножество iCal V1; контракт делегации; retention; транспорт/OD-09; список callables; политика пропажи; provenance и сверка неизвестного исхода Content | Решения записаны |
| 5 | Дополнить execution manifest (BCK-23 §25): коллекции, IAM, бюджет, исходящая сеть, coordinated restore | Раздел манифеста |
| 6 | Точная карта файлов EVS-LOCAL-01a (BCK-23 §20.1) | В BCK-23 |
| 7 | Owner approval ADR 0020, BCK-23 и решений | Записанное решение |

**Выход B0:** вердикт **«Ready to implement EVS-LOCAL-01a»**. Больше ничего
B0 не разрешает.

### 2.2. B1-L — зацепки в локальных слайсах ядра (делают владельцы модулей)

Каждая зацепка — часть слайса, который бэкенд делает и так; кода EVS в нём
нет. Не попала в сам слайс — идёт следующим малым слайсом того же модуля,
но до EVS-слайса из колонки «Нужно к». Предпосылка каждой зацепки — ревизия
документа её модуля (BCK-23 §23).

| # | Где в бэкенде | Что добавить | Готово, когда | Нужно к |
|---|---|---|---|---|
| 1 | **6A — `BCK07-LOCAL-01`**, `functions/src/modules/content/`. Слайс ещё не начат: ревизию BCK-07 внести **до его старта** | Реализовать BCK-07-AC-92…AC-97: provenance `ownerImport`, `originBinding.kind = delegatedImport` с `delegatedActorRef` и `externalBindingRef`, идемпотентность не-сессионного актора, класс изменения. Добавить: порт поиска черновика и публикации по `externalBindingRef` с in-memory адаптером (BCK-23 §12); `hidden` с причиной `sourceMissing` — скрытие и возврат делегированным импортом, Event целиком и одна дата `multiDate`, без уведомлений (BCK-23 §7.2); additive `location.placeId` у Event (D11) | Тесты модуля content: импорт проходит ту же валидацию и модерацию; повтор с тем же ключом не создаёт дубль; поиск по `externalBindingRef` находит черновик и публикацию; скрытие `sourceMissing` обратимо и не даёт фактов отмены; модерационное `hidden` импорт снять не может | EVS-LOCAL-04 (B6) |
| 2 | **BCK-06**, `functions/src/modules/identity_publisher/` — малый слайс после ревизии BCK-06 | Capabilities `event_sources.manage` и `event_sources.review_changes` в `domain/capability.ts` и grant policy (owner, manager), выключены флагами; `EventIngestionDelegation` (BCK-23 §9.2): создание, приостановка, отзыв, проверка без Session в `publisher_eligibility_service`; `PagePlaceOperatorLink` (BCK-23 §9.3) с фактами `identity.placeOperatorLinked` и `identity.placeOperatorUnlinked` | Тесты: отзыв делегации или потеря членства выдавшего → проверка без Session отказывает; чужая страница — отказ; связь в `pendingVerification` не даёт публиковать от имени Place | Делегация — EVS-LOCAL-03 (B5); связь — EVS-LOCAL-04 (B6) |
| 3 | **6B — BCK-08**, локальный Catalog | Проекции не показывают `hidden` (в том числе `sourceMissing`) в ленте, поиске, на карте и в Details; Details показывает provenance через `content.getProvenanceDisclosure` (источник, `checkedAt`, `rescheduledFrom`, отмена) | Тесты проекций: скрытое не видно, возвращённое видно; URL фида в проекции нет | EVS-LOCAL-04 (B6) |
| 4 | **BCK-07/08 — Place** | Опубликованный Place (тип `place`, `placeKind = managedVenue`) и запрос Place по ID | Place создаётся и читается локально | EVS-LOCAL-04 (B6) |
| 5 | **BCK-07 — Content persistence slice** (после `BCK07-LOCAL-01`, который только in-memory) | Firestore-репозиторий Content в Emulator, включая поиск по `externalBindingRef` | Emulator-тесты репозитория | EVS-LOCAL-04 (B6) |
| 6 | **BCK-20** | Набор `event_source_category_map` | Набор зарегистрирован, версия закреплена | EVS-LOCAL-01b (B3) |
| 7 | **BCK-04** | Сроки хранения данных EVS в рамках BCK04-OD-07 | Решение записано | EVS-LOCAL-02 (B4) |
| 8 | **BCK-05, локально** | Общий платформенный port/helper для leased jobs: аренда с fencing, повтор, dead-letter, replay — выделяется из механизма доставки Event, но без доменных состояний Booking. Booking и EVS пользуются им с независимыми записями задач; EVS не импортирует `booking/event_projection_delivery` | Port и helper в платформенном слое с тестами на fencing, повтор, dead-letter и replay; зависимость EVS — только на port | EVS-LOCAL-03 (B5) |

### 2.3. Правила «не закрыть дверь» (на всю разработку бэкенда)

Сейчас ничего не стоят, потом избавляют от переделки:

1. Не занимать зарезервированное BCK-02 §31.1: путь
   `functions/src/modules/event_ingestion/`, префикс `eventIngestion*`, writer
   `event-ingestion`, workload identity `runtime-event-ingestion`, label
   `event-ingestion`, флаги `event-ingestion.*` и номер **6E**.
2. Не зашивать «актор = пользовательская Session» в Content и Identity:
   команды принимают делегированного актора (`delegatedActorRef`), права
   проверяются через порт, а не через Session напрямую.
3. `hidden` в Content — с причиной, а не «только модерация».
4. Перенос и отмена — только командами Content с классом изменения.
   Уведомления (BCK-13) и Booking строятся на фактах
   `EventMateriallyRescheduled` и `EventOccurrenceCancelled`, а не на действиях
   редактора: тогда импорт получит их без доработки.
5. Лимит `100/day` считается на Publisher, а не на Session.
6. `location.placeId` — additive: Event без Place остаются валидными.
7. Исходящая сеть закрыта по умолчанию через allowlist модулей (BCK-02
   §31.1), а не запрещена в коде платформы навсегда.
8. Реестры (флаги, классы данных, retention, `CollectionAccessMatrix`,
   capabilities) расширяются записями, без переписывания; класс `restricted`
   доступен модулям.
9. Для разбора календарей не добавлять runtime-зависимости: `ical.js`
   (MPL-2.0) не проходит allowlist `verify-toolchain` (BCK23-D13).
10. Общие механизмы — только через платформенные port: модуль не
    импортирует код других доменов (в том числе
    `booking/event_projection_delivery`), записи задач у каждого модуля свои.
11. Жалобы остаются в BCK-22: другие домены получают только типизированные
    сигналы и ссылки на case и данные жалоб не копируют.

Соблюдение проверяет ревью каждого слайса ядра.

### 2.4. Два результата этапа 1

| Когда | Вердикт | Что открывает |
|---|---|---|
| B0 закрыт (§2.1) | **«Ready to implement EVS-LOCAL-01a»** | B2; B3–B5 — по мере готовности своих зацепок (§3.1) |
| B1-L выполнен полностью: §2.2 п.1–8 реализованы в своих слайсах и покрыты тестами, правила §2.3 соблюдены | **«Ready to integrate EVS with local core modules»** | B6 (EVS-LOCAL-04): EVS в Emulator работает с настоящими модулями ядра, не меняя их |

B2 не ждёт B1-L: первому EVS-слайсу нужен только B0.

---

## 3. Этап 2 готовности — dev cloud и платформенные сервисы (B1-C)

**Цель:** когда бэкенд выходит в dev cloud и staging, платформа уже умеет то,
что нужно EVS в облаке, и EVS-DEV-01 добавляет только свой модуль и
конфигурацию. Этап встраивается в подготовку dev cloud (шесть решений
владельца, [LV roadmap](RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md)
§36.B) и в домены 6C.

| # | Где в бэкенде | Что добавить | Готово, когда | Нужно к |
|---|---|---|---|---|
| 1 | **Dev cloud**: проект, billing, IAM, секреты, Auth, деплой | В план IAM — workload identity `runtime-event-ingestion` (без прав до B7); в бюджет — label `event-ingestion` с порогом | Записано в решениях dev cloud | EVS-DEV-01 (B7) |
| 2 | **BCK-05 — фоновые задачи в облаке** | Облачная реализация того же общего port для leased jobs (§2.2 п.8): планировщик и очередь для периодических runs, fencing, повтор, dead-letter, ручной replay; доменных состояний Booking в нём нет | Port работает в dev для другого модуля с его собственными записями задач | EVS-DEV-01 (B7) |
| 3 | **BCK-05 — облачные флаги** | `FirestoreFeatureFlagGate` по рынкам в облаке и `SecurityFlagRevision` для аварийного выключения | Флаг другого модуля включается и выключается в dev | EVS-DEV-01 (B7) |
| 4 | **BCK-05 — исходящая сеть** | Политика: какие модули ходят наружу (BCK-02 §31.1) и обязательные защиты — только HTTPS GET, без неодобренных редиректов, запрет частных адресов и DNS rebinding, лимиты размера и времени, User-Agent и страница `/bot` (модель BCK-16 §11/§25). Сам fetcher — внутри EVS до выноса в платформу (BCK23-D14) | Политика записана в BCK-05 и применена в dev: наружу ходят только разрешённые workload identity | EVS-DEV-01 (B7) |
| 5 | **OD-09 — outbox** (контракт принят, runtime нет) и **BCK-13** | Доставка envelope; BCK-13 подписан на `EventMateriallyRescheduled` и `EventOccurrenceCancelled` и уведомляет отметивших: избранное, план, напоминание (D7) | Уведомление о переносе ручного Event доходит в dev | EVS-STAGE-01 (B8) |
| 6 | **BCK-04 — retention в облаке** | TTL по срокам §2.2 п.7; DSR — экспорт и удаление данных EVS (полный URL — `restricted`) | TTL и DSR проверены в dev | EVS-DEV-01 (B7) |
| 7 | **6C — Admin/Support** | Staff: одобрение источников (`moderate.event_sources`), подтверждение `PagePlaceOperatorLink`, repair-команды (архив, отзыв) | Staff-поверхность работает в dev | EVS-STAGE-01 (B8) |
| 8 | **6C — Trust & Safety (BCK-22)** | BCK-22 остаётся единственным владельцем Report и EnforcementCase. По импортированному Event EVS получает только типизированный сигнал или ссылку на moderation case (`caseId`) и может своей командой приостановить источник; данные жалобы в `eventIngestionReviewItems` не копируются | Сигнал со ссылкой на case доходит до порта EVS; в данных EVS нет текста, доказательств и данных заявителя | EVS-STAGE-01 (B8) |
| 9 | **Наблюдаемость и restore** | Метрики и алерты по label модуля; coordinated restore из одной точки (BCK-23 §19.1) | Restore drill пройден | EVS-STAGE-01 (B8) |
| 10 | **Legal** | Текст согласия и делегации, страница `/bot`, права на изображения | Legal review записан | EVS-STAGE-01 (B8) |

**Выход этапа 2:** **бэкенд готов принять EVS в облаке** — EVS-DEV-01
разворачивает только свой модуль и конфигурацию; staging-пилот — после G5 и
Legal.

### 3.1. Что какой EVS-слайс ждёт

EVS-слайсы не ждут этап целиком: каждый стартует, как только готово то, что
нужно именно ему.

| EVS-слайс | Нужно готовым |
|---|---|
| EVS-LOCAL-01a (B2) | B0 (§2.1) |
| EVS-LOCAL-01b (B3) | §2.2 п.6 |
| EVS-LOCAL-01c (B3c) | Conformance 01b |
| EVS-LOCAL-02 (B4) | §2.2 п.7 |
| EVS-LOCAL-03 (B5) | §2.2 п.2 (делегация) и п.8 |
| EVS-LOCAL-04 (B6) | §2.2 п.1–5 |
| EVS-DEV-01 (B7) | §3 п.1–4 и п.6; OD-03 Accepted |
| EVS-STAGE-01 (B8) | §3 п.5 и п.7–10; G5 |
| EVS-PROD-01 (B9) | G6; OD-11 при событиях 18+ |

---

## 4. B2 — EVS-LOCAL-01a: схемы, fixtures, чистый domain

**Вход:** вердикт «Ready to implement EVS-LOCAL-01a».

**Файлы:** ровно карта BCK-23 §20.1 — схемы `event_ingestion/v1` (9), fixtures
valid/invalid/forward, conformance (28 фидов, 28 `normalize`, 33 `reconcile`),
три TS-файла контрактов, 18 файлов `domain/`, 5 тестов, 2 verify-скрипта;
изменения — только `functions/package.json` и `.github/workflows/backend-r1.yml`.

**Задачи:**

1. Схемы с `$ref` на `platform/v1` и `identity/v1`; `fixtures/invalid.json` —
   команды с неизвестными полями, неподдерживаемая версия контракта, URL с
   явными credentials/auth-параметрами; `fixtures/forward.json` — только
   persisted/read DTO (BCK23-D01, D18).
2. Чистый domain: `url_policy`, `binding_key` (`sourceId + externalUid +
   recurrenceKey`), `reconciler`, `change_classifier`, `sanity_gate`,
   `duplicate_detector` (только кандидаты), `field_authority`,
   `content_operation` (`pendingContentOperation`), `local_time`
   (Intl, DST по RFC 5545 §3.3.5), `delegation_ref`.
3. Conformance `reconcile/` исполняется чистым reconciler; `normalize/` —
   пока только данные с проверкой формата.

**Выход:** AC BCK-23 §22.1 — 33 кейса `reconcile/` зелёные; нет
автообъединения, кроме одинакового `bindingKey`; пропажа только скрывает
дату и открывает проверку, никогда не отменяет; отсутствующие цена,
изображение и
описание остаются отсутствующими; `domain/` без Firebase и сети.
**Rollback:** откат коммита.

---

## 5. B3 — EVS-LOCAL-01b: парсеры, сервисы, in-memory

**Вход:** B2; BCK-20 набор маппинга категорий (или профиль импорта без
маппинга — только явные значения человека).

**Новые файлы (точная карта — решение слайса):**
`infrastructure/adapters/{ical_adapter, jsonld_adapter, windows_timezones}.ts`,
`infrastructure/{fake_source_fetcher, fake_content_import,
in_memory_event_ingestion_repository}.ts`,
`application/{event_source_service, sync_run_service, review_queue_service}.ts`,
`application/ports/*`, тесты адаптеров, `test/contract/…normalize_conformance`,
`test/integration/event_ingestion_{service,security}.test.ts`.

**Изменения:** `scripts/verify-r1-layout.mjs` — интеграционные тесты в список
одобренных расширений (`test/integration` — корень точной карты R1);
скрипты `package.json`.

**Задачи:**

1. iCal — **только подмножество V1** (BCK-23 §4.1): `UID`,
   `DTSTART`/`DTEND`/`DURATION`, `TZID`, `STATUS`, `CLASS`, `RDATE`/`EXDATE`,
   простое `RRULE` (`DAILY`/`WEEKLY`, `INTERVAL`, `COUNT`/`UNTIL`, `BYDAY` без
   номеров). Всё остальное и `RECURRENCE-ID` → `unsupportedRecurrence` в review.
2. JSON-LD — только блоки `<script type="application/ld+json">`; microdata,
   RDFa, видимый текст и ссылки не читаются.
3. Сервисы на портах; делегация — через `delegated_grant_port` (fake до B6);
   content — `fake_content_import` с проверкой идемпотентного ключа и сценария
   неизвестного исхода.

**Выход:** 28 кейсов `normalize/` зелёные; integration зелёный, включая
cross-page deny, отказ staff отправлять от имени страницы, паузу при
недействительной делегации.

---

## 6. B3c — EVS-LOCAL-01c: сложные повторения

**Вход:** B3 с зелёным conformance.

Добавляет `FREQ=MONTHLY`/`YEARLY`, `BYMONTHDAY`, `BYSETPOS`, `BYMONTH`,
порядковые `BYDAY`, `RECURRENCE-ID` (изменённые экземпляры) с новыми
conformance-фидами; каждое правило — сначала эталон, потом код. Неподдержанное
по-прежнему → review.

---

## 7. B4 — EVS-LOCAL-02: Firestore Emulator

**Вход:** B3; **сроки хранения EVS приняты в BCK04-OD-07**.

**Новые файлы:** `infrastructure/firestore_event_ingestion_repository.ts`,
`test/rules/firestore_event_ingestion_rules.test.ts`,
`test/emulator/event_ingestion_repository.test.ts`.

**Изменения:** `firestore.rules` (11 явных deny); `firestore.indexes.json`
(7 индексов; TTL `expiresAt` — только для коллекций с принятыми сроками);
`collection_access_matrix.ts`, `data_class_registry.ts`,
`retention_registry.ts` (принятые значения); `test:emulator:inside`;
`verify-r1-layout.mjs` (Rules-тест); config fixtures — capability
`event-ingestion` disabled, если допускает `verify-r1-config`.

**Выход:** 0 клиентского доступа; уникальность через lock-документы; lease;
повтор run без дублей.

---

## 8. B5 — EVS-LOCAL-03: fetcher, callables, workers (Emulator)

**Вход:** B4; делегация в identity (B1-L, §2.2 п.2) хотя бы локально; общий port
BCK-05 для leased jobs (§2.2 п.8) — для workers (иначе run остаётся сервисом без
триггера).

**Новые файлы:** `infrastructure/safe_http_fetcher.ts`,
`platform/bootstrap/event_ingestion_composition_root.ts` (только Emulator),
тесты fetcher и сквозного Emulator-сценария.

**Изменения:** `shared/feature_flags.ts` (8 ID); `index.ts` — **7 callables**
BCK-23 §7.1 (подключение возвращает `sourceId` + `initialSyncOperationId`,
списки — cursor page по BCK-03 §19, BCK-23 §7.1.1); `verify-r1-exports.mjs` — новый точный список; `verify-r1-layout.mjs`
— composition root; `test:emulator:inside`.

**Fetcher:** allowlist источника (хост, путь, `GET`), редирект только внутри
allowlist (`redirect_not_allowlisted`), SSRF/DNS-rebinding, лимиты, robots,
conditional GET; в Emulator — fake fetcher; настоящий — unit-тестами с
подменой DNS/сокетов.

**Выход:** сквозной Emulator-сценарий: probe → подключение с делегацией →
run → черновик → перенос → отмена → пропажа → quarantine; флаги по умолчанию
выключены.

---

## 9. B6 — EVS-LOCAL-04: настоящие модули

**Вход:** B5 и вердикт **«Ready to integrate EVS with local core modules»**
(§2.4): Content persistence slice, запрос BCK-07 по `externalBindingRef`,
делегация и связь Place↔оператор в identity, Place.

Замена fakes адаптерами: `content_import_port` → сервис BCK-07 в процессе
(`originBinding.kind = delegatedImport`); `delegated_grant_port` → identity;
`place_operator_port` → identity; `event_candidate_port` → Content/Catalog.

**Сценарий:** импорт → черновик Content с `ownerImport` → отправка → (fake
модерация) → публикация → перенос → Content пишет `EventMateriallyRescheduled` →
отмена → `EventOccurrenceCancelled`; таймаут команды Content → повтор тем же
ключом без дубля; EVS не записал ничего вне `eventIngestion*` и не связался с
событием с внутренней регистрацией.

---

## 10. B7 — EVS-DEV-01: dev cloud

**Вход:** dev-проект создан отдельным разрешением; облачные флаги и транспорт
(BCK-05); разрешение «network/downloads» только для `runtime-event-ingestion`;
бюджет `event-ingestion` + kill switch; OD-03 Accepted; `deploy-dev` через WIF.

Шаги: Terraform (`runtime-event-ingestion`, минимальные роли, расписание в
paused, очередь) → Rules/индексы/TTL → deploy группы функций (флаги off) →
**публичный** синтетический `.ics` на собственном https-адресе в allowlist →
smoke (создание, перенос, отмена, пропажа, quarantine) → rollback-проверка →
cleanup-проверка.

---

## 11. B8 — EVS-STAGE-01: staging-пилот, только staff

**Вход:** G5; Legal review (текст согласия и делегации, основания, страница
`/bot`, права на изображения); runbooks; restore drill по BCK-23 §19.1; Admin
repair (BCK-19, RUN-03).

3–5 реальных **публичных** фидов с делегацией страниц; видимость только staff;
метрики ≥ 2 недель. `event-ingestion.cancellation.auto` включается вместе с
`event-ingestion.sync` (BCK23-D07); отслеживаются ложные скрытия и отмены.

---

## 12. B9 — EVS-PROD-01: когорта LV

**Вход:** G6; OD-11 при событиях 18+; уведомления (BCK-13 + OD-09) или они
выключены.

Флаги только для LV; staff одобряет только пилотные заведения; `ownerReview`;
решение по `auto-submit` через 2 недели; метрики ≥ 4 недель.
**Rollback:** `event-ingestion.sync`, `event-ingestion.source.connect` = off.

---

## 13. B10 — после когорты

Прямая публикация — D15 через BCK-07 §8.4 (явные отмены применяются сразу
уже с B8 — BCK23-D07); `rss`/`jsonFeed`; билетные площадки —
ECL-04/05 через BCK-16; секретные URL как secret reference — отдельное
решение; EE/LT — отдельно по рынку; вынос fetcher в платформу — когда нужен
BCK-16.

---

## 14. Сквозные изменения по этапам

| Существующий файл | B2 | B3 | B4 | B5 | B6 |
|---|---|---|---|---|---|
| `functions/package.json` (скрипты) | ✔ | ✔ | ✔ | ✔ | |
| `.github/workflows/backend-r1.yml` | ✔ | | | | |
| `scripts/verify-r1-layout.mjs` | | ✔ | ✔ | ✔ | |
| `scripts/verify-r1-exports.mjs` | | | | ✔ | |
| `firestore.rules`, `firestore.indexes.json` | | | ✔ | | |
| `src/security/*` реестры | | | ✔ | | |
| `src/shared/feature_flags.ts`, `src/index.ts` | | | | ✔ | |
| `config/fixtures/*.json` | | | ✔ | | |
| identity/content (чужие модули) | | | | через B1-L | через B1-L |

## 15. Стоп-условия

Путь вне карты; зависимость не проходит `verify-toolchain`; кейс conformance
не совпадает; тест выходит в сеть; запись вне `eventIngestion*`;
импорт кода другого домена (в том числе `booking/event_projection_delivery`);
данные жалоб BCK-22 в коллекциях EVS; автообъединение без одинакового `bindingKey`; отмена из-за пропажи; действие
worker без действующей делегации; принят URL с явными credentials или
auth-параметрами; полный URL попал в лог, audit, ошибку или projection;
команда приняла неизвестное поле; красный SSRF-,
redirect- или Rules-тест; TTL до принятия сроков; облако до B7; реальные данные
до B8.

## 16. Риски

| Риск | Мера |
|---|---|
| 6A стартует раньше ревизии BCK-07, и зацепки §2.2 п.1 в него не попадут | Сразу после 6A — малый слайс BCK-07 с этими зацепками; до B6 обязательно |
| Облачная политика исходящей сети не готова к B7 | B7 ждёт; локальные B2–B6 от неё не зависят |
| Делегация в BCK-06 задерживается | B2–B4 от неё не зависят; B5 работает с fake-портом до B6 |
| Content persistence slice не запланирован | Явный пункт B1-L (§2.2 п.5); B6 заблокирован до него |
| Свой парсер iCal ошибается | Подмножество V1, эталоны до кода, 01c отдельно |
| Много событий без обложки/описания | Это честное состояние: `needsCompletion`, дополняет оператор |
| Заведения дают секретные ссылки календаря | Probe отклоняет явные credentials и auth-параметры; человек подтверждает публичность; полный URL — restricted; приватные фиды вне V1 |
| Retention затягивается | B4 ждёт; B2–B3 не зависят |
