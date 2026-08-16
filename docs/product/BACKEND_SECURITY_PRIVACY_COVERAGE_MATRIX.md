# BCK-04 — Security & Privacy: coverage matrix and reconciliation contract

- ID: `BCK-04-PRE` (готовит `BCK-04 v0.1`, не заменяет его)
- Версия: 0.2
- Дата: 2026-08-16
- Статус: **Draft — preparatory artifact, не Review и не Approval**
- Runtime status: **Absent**
- Owner: API Platform (secondary: Security/Privacy owner — по реестру BCK-02
  §5, именно он owner будущего BCK-04)
- Target document: `docs/product/BACKEND_SECURITY_PRIVACY_SPEC.md` (BCK-04
  v0.1 — ещё не создан; точное имя файла подтверждено BCK-02 §5, строка
  реестра `BCK-04`)
- Runtime effect: none

## 0. Назначение и что изменилось в v0.2

v0.1 этого документа был построен на устаревшей локальной ветке, в которой
`BCK-01`, `BCK-02` (в актуальной версии), `BCK-09` и `BCK-03 v0.2` физически
отсутствовали — хотя на `origin/main` (реальный GitHub-репозиторий) они уже
существовали через смерженный PR другой агентской сессии. v0.2 переписан
после того, как эти файлы подтянуты в рабочую копию (`git checkout
origin/main -- docs/product/RECHARGE_BACKEND_MASTER_SPEC.md
docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md
docs/product/EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md
docs/product/BACKEND_API_CONTRACT_STANDARD.md
docs/product/RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md`).

### 0.1 Явное исправление ошибки v0.1

v0.1 (и отдельно — review `BCK-03 v0.2` в этом же разговоре) утверждал, что
таблица «BCK-02 §14 requirement» в `BCK-03 v0.2 §3.1` **приписывает
структуру несуществующему документу** и является integrity-проблемой. Это
было неверно. Реальный `BCK-02 §14 "Обязательная структура каждого
BCK-spec"` действительно существует и действительно содержит ровно 22
пронумерованных пункта, почти дословно совпадающих с тем, что цитировал
`BCK-03 v0.2`. Претензия снимается: `BCK-03 v0.2 §3.1` был точен, ошибался
я, потому что сверял его с несуществующей у меня локально копией `BCK-02`.

Остальные находки того review (недоказанное `idempotencyKey == requestId`
против реальных `booking_command.schema.json`/`fixtures/valid.json`;
`FIREBASE_ARCHITECTURE.md` как Proposed, а не Accepted, источник) остаются в
силе — они проверялись по файлам, которые физически существовали и в старой
локальной копии, и в `BACKEND_API_CONTRACT_STANDARD.md v0.2`, который теперь
подтянут из `origin/main` без изменений.

## 1. Правила оценки источников

| Метка | Значение |
|---|---|
| **EA** — Existing Accepted | Accepted ADR или Approved spec; нормативно |
| **EP** — Existing Proposed/Draft | Существует, но сам Draft/Proposed — input, не authority |
| **EAB** — Existing Approved-bounded | Approved, но только для local/mock stabilization scope |
| **RA** — Referenced, Absent | Должен существовать по реестру BCK-02, но физически отсутствует |
| **NS** — No source | Ни одного документа; требуется Open decision |

## 2. Формальная последовательность — фактическая сверка (исправлено)

| Шаг | Требование | Фактический статус |
|---|---|---|
| 1 | Перевести `BCK-01` в `Review` | `BCK-01` **физически существует**: [`RECHARGE_BACKEND_MASTER_SPEC.md`](RECHARGE_BACKEND_MASTER_SPEC.md), v0.3, статус `Draft — architecture review required`. Шаг 1 — это перевод его статуса в `Review`, а не создание файла. Пока не выполнен: файл остаётся Draft |
| 2 | Провести Review `BCK-03` | `BCK-03 v0.2` существует ([`BACKEND_API_CONTRACT_STANDARD.md`](BACKEND_API_CONTRACT_STANDARD.md)), статус Draft. Review этого разговора нашёл 1 подтверждённую проблему (idempotency-утверждение против Booking v1 fixtures) и снял 1 ранее заявленную (см. §0.1) |
| 3 | Создать `BCK-04 v0.1` как `Draft / runtime Absent` | Не создан; этот coverage-matrix — подготовка |
| 4 | Согласовать `BCK-04` с `BCK-03`, `BCK-05`, `BCK-06` и Booking | `BCK-03` — существует (Draft). `BCK-05` (`BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md`) и `BCK-06` (`IDENTITY_PUBLISHER_BACKEND_SPEC.md`) — подтверждённо **отсутствуют** и на `origin/main` тоже (реестр BCK-02 §5 маркирует их `Planned / Absent`, файлов нет). Booking представлен `BCK-09` = [`EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md`](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md) v1.0, статус Review — этот файл реально существует |
| 5 | G1 только после Approval всего D1-набора | Подтверждено буквально: `RECHARGE_BACKEND_DELIVERY_MAP.md §18` определяет `G1` как "BCK-01, BCK-03, BCK-04, BCK-05 и BCK-20 Approved и reconciled". `G0` уже `Passed — 2026-08-10`. `G1` не может быть пройден, пока `BCK-05`/`BCK-20` не существуют |

**Вывод v0.2:** формальная последовательность не просто корректна как
процесс — она уже буквально закодирована в `BCK-02 §18` как `G0`/`G1`.
Единственный реальный блокер — `BCK-05` и `BCK-20` физически отсутствуют, и
`BCK-01` ещё не переведён в `Review`.

## 3. Проверенная фактическая база (обновлено)

| Тема BCK-04 | Источник | Метка | Что подтверждено |
|---|---|---|---|
| Точное имя, owner и обязательные зависимости BCK-04 | [`RECHARGE_BACKEND_DELIVERY_MAP.md`](RECHARGE_BACKEND_DELIVERY_MAP.md) §5, строка `BCK-04` | **EA** | Файл `BACKEND_SECURITY_PRIVACY_SPEC.md`; owner Security/Privacy; scope "AuthN/Z controls, App Check, Rules/IAM, data classes, consent, retention/deletion, rate limits"; hard-зависимости `BCK-01, ADR 0013, ADR 0015, environment policy, OD-07, OD-11` |
| Обязательная 22-пунктовая структура каждого BCK-spec | `RECHARGE_BACKEND_DELIVERY_MAP.md` §14 | **EA** | `not applicable`/`TBD` без owner блокируют Approved; список 22 пунктов — прямая основа для §4 этого документа |
| Cross-document reconciliation checklist | `RECHARGE_BACKEND_DELIVERY_MAP.md` §15 | **EA** | Отдельная проверка перед Approved: единый writer на authoritative record, единая retention-классификация, OD-11 fail-closed, security = Auth+App Check+Rules/IAM+rate limits вместе |
| Open decision governance и статусы OD | `RECHARGE_BACKEND_DELIVERY_MAP.md` §16 | **EA** | `Open -> Proposed -> Accepted \| Deferred \| Superseded`; `Deferred` требует owner/причину/срок |
| Gates G0–G4 (и далее) | `RECHARGE_BACKEND_DELIVERY_MAP.md` §18 | **EA** | G0 `Passed 2026-08-10`; G1 требует Approved BCK-01/03/04/05/20 + Accepted OD-07/OD-10 + Proposed минимум OD-09/OD-11 |
| Data classes (5-классная модель) | `RECHARGE_BACKEND_MASTER_SPEC.md` §12 | **EA** | `Public / Protected / Sensitive / Operational / Derived` — та же модель, что уже использует `BCK-03 §23` |
| Security/privacy/abuse baseline + Master authorization matrix | `RECHARGE_BACKEND_MASTER_SPEC.md` §13, §13.1 | **EA** | Готовый baseline: Auth подтверждает identity, capability решает backend; App Check — доп. сигнал, не замена AuthZ; Rules deny direct authoritative writes; revocation fail-closed; таблица principal→allowed/required/forbidden уже существует для No session / User / Creator / Page member / Admin / Service identity |
| Persistence/transaction boundary для security | `RECHARGE_BACKEND_MASTER_SPEC.md` §14 | **EA** | Aggregate transaction принадлежит одному module; cross-module прямые записи запрещены; Booking сохраняет более строгие правила ADR 0019 |
| Open decisions и fail-closed default по каждому OD | `RECHARGE_BACKEND_MASTER_SPEC.md` §21 | **EA** | OD-07 (topology) и OD-11 (minors) явно закреплены за `BCK-04` (совместно с `BCK-05`/`BCK-06`/`BCK-07`/`BCK-09`/`BCK-22` для OD-11) |
| OD-11 — полный текст решения | `RECHARGE_BACKEND_DELIVERY_MAP.md` §16, строка `OD-11` (line 612) | **EA** | Region-versioned minors/age policy; owner Security/Privacy; блокирует R2 production account creation, Find People, age-restricted publication/discovery, applicable Booking paths, G6; explicitly "не устанавливает юридический возраст... до Accepted — server-disabled и fail-closed" |
| Backend topology target (Auth/Firestore/Storage/Functions/App Check) | [`FIREBASE_ARCHITECTURE.md`](../architecture/FIREBASE_ARCHITECTURE.md) v2.2 | **EP** (Proposed, не Accepted) | Полная целевая модель — используется только как cited input, не authority (см. §6 п.1 ниже) |
| Исполняемый identity/capability/publisher контракт (local/mock) | [`IDENTITY_PUBLISHER_SLICE_SPEC.md`](IDENTITY_PUBLISHER_SLICE_SPEC.md) v1.3.1 | **EAB** | §10 Capability baseline, §13 Security and privacy |
| Booking authoritative ledger, audit, idempotency | [`ADR 0019`](../adr/0019-authoritative-internal-booking-ledger.md) | **EA** | D01–D10 Accepted |
| Retention/deletion table (Booking-scoped) | [`EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md`](EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md) §6 (D04) | **EA** | Единственная реально Accepted retention-таблица, 30/90/180 дней по классам |
| Env/flavor/secret separation, rotation, leak response | [`ENV_FLAVORS_SECRETS.md`](../architecture/ENV_FLAVORS_SECRETS.md), `secrets-rotation.md`, `secret-leak-response.md` | **EA** | dev/stage/prod separation, rotation policy, leak runbook |
| API envelope/error/idempotency семантика | `BACKEND_API_CONTRACT_STANDARD.md` (BCK-03 v0.2) | **EP** (Draft) | anti-enumeration, typed error dictionary; §34 честно фиксирует расхождение `idempotencyKey`/`requestId` с реальной Booking v1 схемой |
| Booking v1 wire schema (факт) | `packages/api_contracts/schema/booking/v1/*.schema.json` + `fixtures/valid.json` | **EA** (implemented artifact) | `requestId` и `idempotencyKey` — независимые обязательные поля; в валидном fixture имеют разные значения |
| `BCK-05` (Operations) | — | **RA** | Реестр `BCK-02 §5` подтверждает `Planned/Absent`; файла `BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md` нет |
| `BCK-06` (Identity/capability backend lifecycle) | — | **RA** | `IDENTITY_PUBLISHER_BACKEND_SPEC.md`, `Planned/Absent` по реестру |
| `BCK-20` (MarketConfig/LocalizedText) | — | **RA** | `Planned/Absent`, нужен для G1 наравне с BCK-04 |
| `BCK-22` (Trust & Safety) | — | **RA** | `TRUST_SAFETY_MODERATION_BACKEND_SPEC.md`, `Planned/Absent`, совладелец OD-11 и OD-06 |
| `apps/backend`, Firebase projects, Rules, Functions | — | **NS** | Каталог `apps/backend` не существует; production runtime подтверждённо Absent |

## 4. Section-by-section coverage — 30 разделов запроса ↔ 22 канонических пункта BCK-02 §14

Важное отличие от v0.1: раздел `BCK-02 §14` устанавливает **обязательный
минимум** из 22 пунктов для *любого* BCK-spec, а исходный запрос на BCK-04
перечисляет 30 разделов. Это не конфликт — 30-пунктовый список детальнее и
security/privacy-специфичен, но каждый из 22 канонических пунктов обязан
быть узнаваем внутри итоговой структуры BCK-04 v0.1 (см. reconciliation
checklist `BCK-02 §15`). Ниже — статус источника по каждому из 30 разделов,
плюс отметка, какому канонический пункту §14 он соответствует.

Легенда: **I** — прямой реальный источник; **P** — частичный; **O** — Open,
источника нет.

| § запроса | Раздел BCK-04 | §14 канон | Статус | Источник |
|---|---|:---:|:---:|---|
| 1 | Метаданные/версия/owner/runtime boundary | 1 | I | Формат BCK-01/BCK-03 |
| 2 | Verdict и продуктовый результат | 3 | I | `BCK-01 §2`, `BCK-02 §5` строка BCK-04 |
| 3 | Источники истины и приоритет конфликтов | 2 | I | `BCK-01 §3`, `BCK-03 §3` (уже цитирует "BCK-01 §3") |
| 4 | Included/excluded scope | 4 | I | `BCK-02 §5` scope-колонка + explicit non-goals по аналогии с BCK-03 §4–5 |
| 5 | Threat model и trust boundaries | — (новый, не в §14 явно) | P | `BCK-01 §13.1` (master authorization matrix) даёт частичную модель; формального STRIDE-анализа нет — **O** для полного threat model |
| 6 | Полный backend data inventory | 5, 10 | P | `FIREBASE_ARCHITECTURE.md §8` (Proposed input); `BCK-01 §12` требует, чтобы **BCK-04** сам зафиксировал purpose/legal basis/retention по record family — то есть инвентарь пишет сам BCK-04, не наследует готовым |
| 7 | Классификация данных (7 классов из запроса) | 6 | P | **Reconciliation needed**: `BCK-01 §12` и `BCK-03 §23` уже согласованно используют 5 классов (`Public/Protected/Sensitive/Operational/Derived`); запрос на BCK-04 предполагает 7 (добавляет `private`, `audit`, `analytics`). Рекомендация: расширять существующие 5, не вводить параллельный словарь — но это решение принимает BCK-04 v0.1, не эта матрица |
| 8 | Authentication | 9 (частично) | I | `BCK-01 §13.1`, `IDENTITY_PUBLISHER_SLICE_SPEC.md §5`, `FIREBASE_ARCHITECTURE.md §9` (Proposed) |
| 9 | Authorization | 9 | I | `BCK-01 §13.1` master matrix — прямая нормативная основа |
| 10 | Publisher/workspace isolation | 9 | I | `IDENTITY_PUBLISHER_SLICE_SPEC.md §4, §7` |
| 11 | API security (BCK-03 integration) | 7 | I | `BACKEND_API_CONTRACT_STANDARD.md §14, §25` |
| 12 | Firestore Rules и IAM | 9, 10 | P | `BCK-01 §13` п.4 (Rules deny direct writes) — нормативно; `FIREBASE_ARCHITECTURE.md §11` — Proposed detail; физических `.rules` нет — **O** |
| 13 | Storage и media security | 10 | P | `FIREBASE_ARCHITECTURE.md §12` — Proposed only, нет Accepted источника |
| 14 | App Check | 17 | I | `BCK-01 §13` п.3 (App Check — доп. сигнал, не замена AuthZ) — нормативно |
| 15 | Secrets и cryptographic material | 18 (частично) | I | `ENV_FLAVORS_SECRETS.md`, `secrets-rotation.md` |
| 16 | Abuse, fraud, rate limiting | 17 | P | `BCK-01 §13` п.8 задаёт принцип (actor/device/risk), но "exact thresholds принадлежат domain/security specs" — числа Open, зависят от `BCK-05` |
| 17 | Privacy processing | 16 | P | `IDENTITY_PUBLISHER_SLICE_SPEC.md §13`; legal basis/consent versioning нигде не решены — **O** |
| 18 | OD-11 — minors/age eligibility | 16, 21 | I | `BCK-02 §16` OD-11 полный текст + `BCK-01 §21` fail-closed default — уже Proposed-уровня решение, **не Open с нуля** (исправлено относительно v0.1) |
| 19 | Retention matrix | 16 | P | D04 (Booking-scoped) Accepted; для остальных классов — **O** |
| 20 | Export/deletion/DSR | 16 | P | `BCK-01 §13` п.10 закрепляет координацию за BCK-04, но сам DSR-процесс не описан — **O** |
| 21 | Logging и audit | 18 | I | `BCK-01 §13` п.7, `BCK-03 §32–33` |
| 22 | Data residency и OD-07 | — (входит в 10) | P | `FIREBASE_ARCHITECTURE.md §4.3` — Proposed, explicitly "review required"; `BCK-01 §21` подтверждает OD-07 = `BCK-04/05` совместно |
| 23 | Backup/restore privacy | 18 | P | `BCK-01 §14` п. "backups не заменяют domain reconciliation" — принцип есть, RTO/RPO — **O**, зависит от `BCK-05` |
| 24 | Migration и local-to-cloud import security | 14 | P | `FIREBASE_ARCHITECTURE.md §18.2`; `BCK-18` (import orchestration) — **RA** |
| 25 | Server flags, rollout, rollback, emergency disable | 19 | I | `BCK-02 §22`, `ADR 0019` |
| 26 | Incident response и security-event escalation | — (новый) | P | `secret-leak-response.md` — только для leak; общий security incident response — **O** |
| 27 | Open decisions | 22 (частично) | I | Собирается из P/O строк + `BCK-01 §21`/`BCK-02 §16` уже дают половину состава |
| 28 | Exact future artifact map | 20 | I | По аналогии с `BCK-03 §36`, `BCK-01 §17` |
| 29 | Test/evidence matrix | 21 | I | `BCK-01 §19`, `FIREBASE_ARCHITECTURE.md §11.3/§19.1` (Proposed) |
| 30 | DoR/DoD/AC/unimplemented list | 22 | I | По аналогии с `BCK-01 §24–27`, `BCK-03 §40–44` |

Итог v0.2: **17 из 30** разделов теперь имеют прямой источник (было 13),
**12** частичный, **1** Open без изменений (объединено в §18 через OD-11,
которое на самом деле уже не голый Open, а Proposed-уровня решение — строка
18 переклассифицирована в **I** относительно v0.1).

## 5. Обязательные матрицы — обновлённые seed rows

### 5.1 Authentication/Principal Matrix и Authorization/Capability Matrix

Заменяются на прямую цитату `RECHARGE_BACKEND_MASTER_SPEC.md §13.1` (Master
authorization matrix) — это уже готовая, нормативная (Draft, ожидает Review)
таблица `No session / Authenticated User / Verified Creator / ManagedPage
member / Admin-support / Service identity` × `Базово разрешено / Требуется
дополнительно / Запрещено`. BCK-04 v0.1 не должен изобретать параллельную
матрицу — должен сослаться и детализировать её под security/privacy углом
(App Check, Rules, конкретные capability-коды).

### 5.2 Retention/Deletion Matrix (не изменилось)

Прямая перепечатка Accepted D04 остаётся единственной полностью Accepted
строкой — см. v0.1 §5.3, без изменений.

### 5.3 Data Classification Matrix

Обновлено: seed — не `FIREBASE_ARCHITECTURE.md §8` (Proposed collections),
а `RECHARGE_BACKEND_MASTER_SPEC.md §12` (Accepted-уровня 5 классов с
примерами и base handling). Коллекции из `FIREBASE_ARCHITECTURE.md`
используются только чтобы предложить, к какому из 5 классов отнести
конкретный collection/field — сама 5-классная ось уже установлена BCK-01, не
предлагается заново.

### 5.4 Остальные 10 матриц

Firestore Rules/IAM, Anti-enumeration, Consent and Legal Review, DSR
Orchestration, Abuse/Rate Limit, Security Logging, LV/EE/LT Market Policy,
Test and Evidence, Data Inventory, Threat model/trust boundary — как и в
v0.1, оформленных таблиц нигде нет; частичные текстовые источники
перечислены в §3–4. Их первое построение — работа `BCK-04 v0.1`.

## 6. Конфликты/несогласованности, которые BCK-04 обязан унаследовать (обновлено)

1. ~~Таблица «BCK-02 §14» в BCK-03 v0.2 §3.1 фабрикует структуру
   несуществующего документа~~ — **снято**, см. §0.1. `BCK-02 §14`
   реален и содержит именно то, что цитировалось.
2. **`FIREBASE_ARCHITECTURE.md` — Proposed, не Accepted.** Подтверждено
   владельцем (Вопрос 3, ответ A): использовать только как `Proposed
   architecture input`, ничего не наследовать тихо, §8 и §11 не считать
   settled. Каждое заимствованное положение помечается явно.
3. **Классификация данных.** Уточнено в §4 строке 7 этого документа:
   конфликта между `BCK-01` и `BCK-03` нет — оба используют одну 5-классную
   модель. Расхождение — только с исходным запросом на BCK-04 (7 классов).
   Рекомендация: расширять принятую 5-классную ось именованными
   подкатегориями (`audit`/`analytics` как срезы `Operational`/`Derived`,
   `private` как уточнение `Protected`), а не вводить параллельный словарь —
   решение остаётся за BCK-04 v0.1.
4. **`idempotencyKey` vs `requestId` в Booking v1** — не снято. `BCK-03
   v0.2 §34` сам честно фиксирует это расхождение как reconciliation item;
   BCK-04, если пишет про idempotency-based abuse prevention (§16), должен
   опираться на факт "два независимых поля", а не на "Draft mobile v1 rule"
   из `BCK-03 §1.1 RQ-03`, которая всё ещё не подтверждена fixtures.
5. **`Admin` — не superuser.** `ADR 0017` + `BCK-01 §13.1` (Admin/support
   principal: "Explicit tool/case action only", "Publisher/workspace
   impersonation... запрещены") — согласованы между собой, без конфликта.
   BCK-04 §9 должен унаследовать именно эту формулировку.

## 7. Ответы owner на вопросы v0.1 — зафиксировано

Из [`BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX_OPEN_QUESTIONS.md`](BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX_OPEN_QUESTIONS.md):

1. **BCK-01** — существует, `v0.3`, `Draft — architecture review required`.
   Матрица исправлена по всему документу (§2, §3). Переход в `Review`
   остаётся отдельным, ещё не выполненным шагом.
2. **OD-11** — Recommendation-style, без числового возраста; источник —
   `BCK-02 §16` строка OD-11 (уже существует, Open) + `BCK-01 §21` (fail-closed
   default). BCK-04 v0.1 добавляет Draft policy поверх уже зарегистрированного
   OD, не создаёт OD-11 заново. Статус предложения — `Proposed — not
   Accepted`, с версионированием по LV/EE/LT, owner/датой Legal/Privacy review
   на каждое рыночное решение отдельно, disabled Booking Emulator core не
   блокируется глобально.
3. **`FIREBASE_ARCHITECTURE.md`** — только `Proposed input`, §8 и §11 не
   settled, проверяется против Accepted ADR/BCK-01/BCK-02/BCK-03 — учтено в
   §3 и §6 этого документа.

## 8. Рекомендация — следующий шаг

**Статус: выполнено, BCK-04 v0.3 после двух раундов owner review.** Второй
раунд нашёл: D04 нельзя называть безусловно Accepted (источник сам говорит
"remains open until Privacy/Legal/Product approve"); G1 требует OD-07
`Accepted`, не `Proposed`; отсутствовала явная reconciliation-таблица по 22
пунктам `BCK-02 §14`; privacy/DSR блок был GDPR-неполным (consent — не
единственное legal basis, DSR — не только export/delete, retention не
отменяет erasure без exemption, Art. 33/34 breach notification не
унаследован из `RUN-06`); artifact map предлагал несуществующую
`functions/src/security/` вместо `BCK-01 §17` layout. Всё исправлено в
`BCK-04 v0.3`. [`BACKEND_SECURITY_PRIVACY_SPEC.md`](BACKEND_SECURITY_PRIVACY_SPEC.md)
(`BCK-04 v0.1`, Draft, runtime Absent) написан по структуре §4 этого
документа, с 11 Open decisions (`BCK04-OD-01`…`OD-09` плюс унаследованные
`OD-07`/`OD-11`), 15 acceptance criteria и явным разделением Accepted/
Proposed input/Open в каждом разделе.

Следующий шаг по формальной последовательности (не эта матрица): перевод
`BCK-01` в `Review`, затем reconciliation `BCK-04` с `BCK-05`/`BCK-06`
после того, как эти документы физически появятся. До тех пор `BCK-04`
остаётся Draft, а `G1` не может быть пройден (`BCK-02 §18`).

Этот файл, его pair (`BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX_OPEN_QUESTIONS.md`)
и теперь `BACKEND_SECURITY_PRIVACY_SPEC.md` сами пока не существуют на
`origin/main` — появятся там только через отдельный docs-only PR.
