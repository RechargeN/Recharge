# Recharge Backend — Security & Privacy Specification

- ID: **BCK-04**
- Version: **0.3**
- Date: **2026-08-16**
- Spec status: **Draft — architecture review required**
- Runtime status: **Absent**
- Accountable owner: **Security/Privacy owner** (per `BCK-02 §5` registry row `BCK-04`)
- Markets: **Latvia first; Estonia and Lithuania prepared but disabled independently**
- Parent architecture: [BCK-01 v0.3](RECHARGE_BACKEND_MASTER_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.2](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Reconciles with: [BCK-03 v0.2](BACKEND_API_CONTRACT_STANDARD.md) (Draft),
  [BCK-09 v1.0](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md) (Review)
- Preparatory input: [BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md](BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md) v0.2
- Hard dependencies (per `BCK-02 §5`): `BCK-01`, `ADR 0013`, `ADR 0015`, environment policy, `OD-07`, `OD-11`
- Canonical repository path: `docs/product/BACKEND_SECURITY_PRIVACY_SPEC.md`
- Runtime effect of this revision: **none**

---

## 0. Changelog

### v0.3 — 2026-08-16

Второй owner review нашёл 8 подтверждённых проблем (из 10 заявленных),
исправлено:

- §19.1 D04 больше не называется безусловно `Accepted` retention-таблицей —
  источник (`EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md`, после rules
  списка в §6) прямо говорит "these values are product recommendations, not
  legal advice; D04 remains open until Privacy/Legal/Product approve the
  exact table and backup behavior" — переформулировано как normative
  recommendation, не как settled policy;
- §30.2 DoD: `OD-07` требует `Accepted` (не `Proposed`) для прохождения
  `G1` — исправлено вслед за реальным текстом `BCK-02` секции G1
  ("OD-07 и OD-10 Accepted; OD-09 и OD-11 минимум Proposed");
- добавлена §3.1 reconciliation-таблица по всем 22 пунктам `BCK-02 §14`, с
  явным `not applicable`/delegation там, где раздел не относится к BCK-04;
- §17/§20 privacy/DSR блок расширен: legal basis не сведён к consent
  (Art. 6–7 GDPR), consent withdrawal отделён от deletion/DSR, DSR теперь
  явно включает access/rectification/restriction/objection/portability, не
  только export/delete; explicit правило, что internal retention сам по
  себе не отменяет erasure right без applicable exemption;
- §26 incident response явно наследует Article 33 GDPR 72-часовое окно
  уведомления supervisory authority и notification without undue delay при
  high risk — то же обязательство, что уже фиксирует `RUN-06` в `BCK-02 §6`
  для зависящего от BCK-04 runbook;
- добавлены `BCK04-OD-10` (ROPA/data-processing register), `BCK04-OD-11`
  (DPIA gate), `BCK04-OD-12` (processor/subprocessor inventory),
  `BCK04-OD-13` (international-transfer policy);
- §28 artifact map выровнен с реальным `BCK-01 §17` target layout:
  `functions/src/security/` (несуществующая директория) заменена на
  `shared/auth/`, `transport/*` middleware и `shared/observability/`;
  добавлен отсутствовавший `storage.rules`; добавлена явная привязка к
  Privacy Orchestration capability (`BCK-02` таблица §7, owner `BCK-04`);
- AC-23 исправлена ссылка `§39` (не существует в этом документе) → `§25`;
- исправлена опечатка `conкретный` → `конкретный` (§18.1);
- §15 больше не называет `ENV_FLAVORS_SECRETS.md`/runbooks "Accepted-уровня"
  на основании LAUNCH_STATUS `Done` — `Done` в LAUNCH_STATUS означает
  завершённость документации/процесса, не формальный ADR-уровня `Accepted`
  статус; переформулировано как "существующая repository policy";
- §30.1 убрано неподтверждённое "API Platform как placeholder owner" —
  заменено на честное "формальное назначение конкретного человека/команды
  остаётся Open";
- хрупкие ссылки на номера строк других документов (`BCK-09 строка 569`,
  `BCK-02 §16, строка 612`) заменены на ссылки по разделу/содержанию, где
  возможно.

Два заявленных пункта не подтвердились при повторной проверке (см. ответ в
разговоре): версия `IDENTITY_PUBLISHER_SLICE_SPEC.md` — файл в этой рабочей
копии по-прежнему буквально показывает `1.3.1`, не `1.3`; coverage matrix
физически существует на диске в этой рабочей копии (untracked в git, что и
объясняет расхождение, если проверка шла по git-tracked содержимому).

### v0.2 — 2026-08-16

Owner review нашёл 10 подтверждённых проблем (из 12 заявленных), исправлено:

- §3 порядок источников выровнен с реальным `BCK-01 §3` (Architecture
  Baseline и LAUNCH_STATUS теперь корректно выше BCK-01/BCK-02, не ниже);
- §11.3 idempotency: зарегистрирован как **fixture-vs-normative-spec
  conflict** (BCK-09 §13 Idempotency и ECL-03C требуют `idempotencyKey ==
  requestId` для client v1; committed fixture это нарушает), а не как
  "фактическое поведение", которое BCK-04 будто бы обязан принять;
- §28 artifact map: `schema/common/v1/actor_context.schema.json` удалён —
  неверное имя пути (реальный BCK-03 target — `schema/platform/v1`,
  запрещённый до Accepted `API-DEC-05`), и concept ошибочен — server-resolved
  actor context не должен становиться client wire payload;
- §12.3: direct Firestore writes (favorites/preferences/notification
  `isRead`) переведены с "Да" на safe default "Нет — запрещено", делегировано
  `BCK-12`/`BCK-13`/`BCK-18` как отдельное решение (конфликтовало с `BCK-03
  AC-23`: "every mutation is a registered versioned command");
- §19.2: удалены конкретные numeric fallback для Sensitive/Operational
  audit — заменено на explicit "no default, Legal/Privacy Proposed policy
  required" без экстраполированных чисел;
- исправлены несуществующие ссылки: `BCK-03 §14.1/§14.2` → `§14`;
  `BCK-03 §32–33` как "logging" → только `§32` (§33 — persistence, не
  logging); `BCK-02 §22` (не существует, BCK-02 заканчивается §20) →
  `BCK-01 §22`;
- §30.2 DoD: OD, помеченные как blocking для Approval (`BCK04-OD-01`,
  `BCK04-OD-09`), больше не могут быть "просто перенесены с датой" — deferred
  blocking OD теперь явно означает, что Approval не может быть Done;
- §30.1 owner-конфликт устранён: DoR больше не говорит "API Platform
  временно" при header, утверждающем Security/Privacy owner;
- §7.1: analytics больше не назначается `Derived` автоматически — data
  class определяется по содержимому записи, `analytics`/`audit` остаются
  purpose/record-kind метками, не классом;
- §30.3 AC расширен с 15 до 28 пунктов — добавлено покрытие threat model,
  Rules/IAM, cross-page isolation, OD-07, DSR, retention activation,
  incident response, rollback, market gates.

Два заявленных пункта не подтвердились при проверке (см. ответ в разговоре):
версия `IDENTITY_PUBLISHER_SLICE_SPEC.md` — реально `1.3.1`, не `1.3`; сама
coverage matrix физически существует в этой рабочей копии (отсутствует
только на `origin/main`, что уже было раскрыто в её собственном тексте).

### v0.1 — 2026-08-16

- первая версия единого security/privacy standard для всего Recharge backend;
- построена на реально существующих источниках (`BCK-01 §12–14, §21`,
  `BCK-02 §5, §14–18`, `ADR 0013/0015/0016/0017/0019`,
  `IDENTITY_PUBLISHER_SLICE_SPEC.md v1.3.1`, `ENV_FLAVORS_SECRETS.md`,
  `EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md` D04/D05), без домысливания
  структуры несуществующих документов;
- `FIREBASE_ARCHITECTURE.md v2.2` учтён только как `Proposed input` — ни одно
  положение из него не наследуется как Accepted;
- принята 5-классная data classification (`Public/Protected/Sensitive/
  Operational/Derived`) из `BCK-01 §12`, а не параллельный 7-классный словарь;
- `OD-11` (minors/age) получает Draft recommendation-policy поверх уже
  зарегистрированного в `BCK-02 §16` decision, без назначения числового
  возраста;
- зафиксировано расхождение `idempotencyKey`/`requestId` в Booking v1
  как известный reconciliation item, не как решённое правило;
- 13 обязательных матриц построены там, где есть источник, и явно помечены
  Open там, где источника нет;
- backend/mobile/Firebase/schema runtime не создан.

---

## 1. Verdict

Recharge использует **один security & privacy standard** для User, Creator,
Professional Page и Admin/service principals, для всех рынков LV/EE/LT и для
всех backend-доменов (`BCK-06`–`BCK-22`). Domain-спецификации не создают
собственную модель аутентификации, авторизации, классификации данных или
retention — они наследуют этот документ и добавляют domain-специфичные
capability-коды, data families и exact numeric limits там, где сам BCK-04
явно делегирует решение (rate-limit числа — `BCK-05`; age policy — Legal/
Privacy per market; conflict — см. §3).

Физический backend этим документом не разрешается. Approval BCK-04 — это
architecture design readiness, не production authorization; отдельный
executable slice и post-stabilization authorization остаются обязательны
(соответствует `BCK-01 §22`, `BCK-02 §18` G1).

## 2. Назначение и продуктовый результат

После Approved BCK-04 команда получает:

- один источник истины для того, что «authenticated» не равно «authorized»,
  а «App Check enabled» не равно «rate limit enforced» (`BCK-01 §13`);
- единую 5-классную data classification, применимую к любому будущему
  collection/field без повторного изобретения словаря;
- единую Master authorization matrix (унаследованную от `BCK-01 §13.1`),
  которую domain-специфичные capability-таблицы детализируют, а не заменяют;
- явный, versioned per-market путь принятия `OD-11` (minors/age), вместо
  тихого умолчания или произвольного возраста в каждом domain отдельно;
- retention-таблицу, которую остальные domains (`BCK-07`–`BCK-22`) обязаны
  расширять по образцу normative-recommendation `D04` (числа которого сами
  остаются Open до Legal/Privacy/Product approval — см. §19.1), а не
  изобретать заново с нуля;
- честный список того, что реально Accepted (`ADR 0013/0015/0019`, `D05`),
  что normative recommendation с Open числами (`D04`), что Proposed-input
  (`FIREBASE_ARCHITECTURE.md`), и что Open (§27), без смешивания этих
  четырёх уровней доверия.

## 3. Источники истины и разрешение конфликтов

Приоритет — дословно порядок `BCK-01 §3` (не переизобретается заново):

1. Accepted ADR побеждает при архитектурном конфликте (`ADR 0013`,
   `ADR 0015`, `ADR 0016` bounded, `ADR 0017` bounded, `ADR 0019`);
2. Approved spec применимого domain/runtime slice побеждает внутри своего
   bounded scope (`IDENTITY_PUBLISHER_SLICE_SPEC.md` v1.3.1, Approved bounded);
3. [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md) и
   cross-cutting policies владеют module/layer boundaries;
4. [LAUNCH_STATUS](../architecture/LAUNCH_STATUS.md) владеет фактическим
   implementation/runtime status, но не переписывает target architecture;
5. `BCK-02` (registry, accountable owners, dependencies, waves, OD/risks,
   gates);
6. `BCK-01` (shared backend target, layers, module boundaries, cross-domain
   invariants, включая §12–14, §21);
7. этот `BCK-04` для security/privacy detail, где источники выше не решают;
8. `FIREBASE_ARCHITECTURE.md v2.2` — **только Proposed input**, никогда не
   normative само по себе (см. §6, §12, §13, §14 ниже — каждое заимствование
   помечено явно). Product vision и другие Draft/Review proposals не
   переопределяют пункты выше.

Обязательные anchors:

| Область | Источник | Обязательство BCK-04 |
|---|---|---|
| Backend architecture/data classes | [`BCK-01`](RECHARGE_BACKEND_MASTER_SPEC.md) §12–14, §21 | Не вводить параллельную классификацию или authorization matrix |
| Registry/gates/OD governance | [`BCK-02`](RECHARGE_BACKEND_DELIVERY_MAP.md) §5, §14–18 | Соблюсти 22-пунктовую структуру §14 и reconciliation checklist §15 |
| Domain policy baseline | [`ADR 0013`](../adr/0013-domain-policy-baseline.md) | Использовать существующие numeric defaults (retention 30 дней, auto-hide ≥5/24h, 3 сессии, 100 publish/day, EU opt-in/non-EU opt-out), не переопределять их без нового ADR |
| Identity mandatory auth | [`ADR 0015`](../adr/0015-authenticated-viewer-verified-creator-professional-page.md) | Нет unauthenticated режима; Google/Apple — единственные production providers |
| Bounded local/mock identity | [`ADR 0016`](../adr/0016-bounded-identity-workspace-during-stabilization.md), [`ADR 0017`](../adr/0017-admin-experience-preview-and-user-created-pages.md) | Admin — capability-gated preview, не superuser; local/mock scope не выдаётся за production authority |
| Booking authoritative ledger | [`ADR 0019`](../adr/0019-authoritative-internal-booking-ledger.md), [`BCK-09`](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md) | Booking сохраняет более строгие transaction/idempotency правила, BCK-04 их не ослабляет |
| API wire contract | [`BCK-03`](BACKEND_API_CONTRACT_STANDARD.md) | Envelope/error/idempotency semantics не дублируются здесь — только security overlay |
| Firebase target architecture | [`FIREBASE_ARCHITECTURE.md`](../architecture/FIREBASE_ARCHITECTURE.md) v2.2 | Cited `Proposed input` only; §8/§11 не settled |
| Environment/secrets policy | [`ENV_FLAVORS_SECRETS.md`](../architecture/ENV_FLAVORS_SECRETS.md), runbooks | Нормативно для §15 |

Конфликт между этим документом и Accepted ADR блокирует Approved BCK-04 до
принятого решения; Accepted ADR не переписывается нижестоящим документом
(`BCK-02 §15`).

### 3.1 Покрытие 22 обязательных пунктов `BCK-02 §14`

`BCK-02 §14` требует, чтобы каждый BCK-spec явно покрывал все 22 пункта или
помечал их `not applicable` с причиной — иначе Approved блокируется. Ниже —
явная сверка (отсутствовала в v0.1/v0.2, что само по себе было находкой
review):

| № | Пункт `BCK-02 §14` | Статус в BCK-04 | Где |
|---|---|---|---|
| 1 | ID/version/status/owner | Покрыт | Header |
| 2 | Parent ADR/specs, anchors, conflict priority | Покрыт | §3, §3.1 |
| 3 | Product outcome и measurable non-goals | Покрыт | §2, §4.2 |
| 4 | Included/excluded scope | Покрыт | §4 |
| 5 | Aggregate, record writer и consumer ownership | **Not applicable для BCK-04 напрямую** | BCK-04 не владеет product-агрегатами; единственный record family в его собственности — Privacy Orchestration (DSR coordination, §20; см. §28.0 про gap BCK-01 §8/§17). Ownership остальных record families принадлежит `BCK-01 §9` |
| 6 | Data classification и public/protected/private projections | Покрыт | §7 |
| 7 | Commands, queries, events и typed error envelope | **Delegated to BCK-03** | BCK-04 не определяет собственный envelope; §11 — только security overlay поверх `BCK-03` |
| 8 | Schema/API/event versions, evolution, minimum supported client | **Not applicable** | Полностью в scope `BCK-03 §25–26`; BCK-04 не версионирует wire contract |
| 9 | Authorization/capability matrix и revocation behavior | Покрыт | §9 |
| 10 | Persistence, indexes, source/projection, transaction boundaries | **Delegated** | `BCK-01 §14` нормативен; BCK-04 добавляет только security invariant (§12) поверх этого, не собственную persistence-модель |
| 11 | IDs, references, UTC/IANA, reference-data semantics | **Not applicable** | Owned by `BCK-01 §11`/`BCK-20`; BCK-04 не переопределяет примитивы |
| 12 | Idempotency, concurrency, retries, partial-failure behavior | **Partial** | Только в разрезе abuse-prevention (§16.2) и известного fixture-конфликта (§11.3); полная семантика — `BCK-03 §16–17, §21` |
| 13 | Offline/cache/freshness, honest degraded states | **Not applicable** | Owned by `BCK-01 §15`, `BCK-03 §29`; BCK-04 не добавляет собственную offline-модель |
| 14 | Migration, local-to-cloud import, backward/forward compatibility | Покрыт (security angle) | §24 |
| 15 | Outbox/event delivery, replay/deduplication | **Not applicable для BCK-04 напрямую** | Owned by `BCK-03 §27` (Proposed OD-09); BCK-04 не определяет delivery semantics |
| 16 | Privacy, consent, retention, export/deletion, Legal review points | Покрыт | §17–20 |
| 17 | Abuse, rate limiting, App Check limitations, fraud controls | Покрыт | §14, §16 |
| 18 | Operational logs/SLO/alerts, product analytics separation, cost budget | **Partial** | Logging/redaction покрыты (§21); SLO/alerts/cost — **delegated to `BCK-05`**, product analytics separation — **delegated to `BCK-21`**; BCK-04 фиксирует только границу (§21, §32 источник) |
| 19 | Server flags, rollout, rollback, emergency-disable | Покрыт | §25 |
| 20 | Exact implementation file map | Покрыт | §28 |
| 21 | Test matrix (unit/contract/fixture/emulator/Rules/security/load/DR) | Покрыт | §29 |
| 22 | Sequential AC, DoR/DoD, unimplemented list | Покрыт | §30 |

## 4. Included/excluded scope

### 4.1 Входит

- authentication/session/token model поверх Firebase Auth;
- authorization: roles, capabilities, verification, page membership,
  revocation;
- data classification и её применение к inventory/projections;
- App Check, Firestore/Storage Rules стратегия (уровень принципов, не
  конкретные `.rules`-файлы);
- secrets/crypto material policy;
- abuse/rate limiting принципы и numeric defaults, унаследованные из ADR 0013;
- privacy processing: purpose, legal basis, consent, minimization;
- `OD-11` minors/age Draft recommendation;
- retention/deletion/export/DSR модель;
- logging/audit redaction правила;
- data residency принципы (`OD-07` boundary, без выбора конкретного региона);
- backup/restore privacy требования;
- migration/import security инварианты;
- rollout/rollback/emergency-disable для security-relevant флагов;
- incident response модель.

### 4.2 Не входит

- конкретные `.rules`/`firestore.indexes.json`/Cloud Functions код — это
  реализация после Approved executable slice;
- Firebase projects, regions, CI/CD, SLO, cost budgets — `BCK-05`;
- domain-specific identity/capability lifecycle deep detail — `BCK-06`;
- payment authority, PCI scope — `BCK-17` после отдельного ADR;
- Trust & Safety enforcement levels, appeal workflow detail — `BCK-22`;
- market reference data (`MarketConfig`, `LocalizedText`) — `BCK-20`;
- mobile adapter/import orchestration detail — `BCK-18`;
- конкретный юридический возраст согласия или legal basis per market —
  Legal/Privacy review, не эта спецификация;
- domain lifecycle Booking/Content/Discover — их собственные BCK-specs.

## 5. Threat model и trust boundaries

Формального STRIDE-style документа в репозитории нет — это признанный Open
gap (§27, `BCK04-OD-01`). Ниже — модель доверия, выводимая из уже Accepted
источников, а не изобретённая заново.

```text
Untrusted:  мобильный клиент, любой сетевой ввод, provider webhook payload
Semi-trusted: authenticated session (доказывает identity, не authority)
Trusted:    backend Functions/callable handlers, service identities
Authoritative: Firestore authoritative collections через trusted transaction
```

Инварианты (`BCK-01 §13` п.1, п.4, п.12):

1. Firebase Auth подтверждает identity сессии, но capability решает backend
   — client-side guard никогда не является access-control границей.
2. Firestore/Storage Rules по умолчанию deny direct authoritative writes и
   cross-user/scope reads.
3. Server SDKs (Cloud Functions) обходят Security Rules — поэтому Functions
   обязаны повторять authorization/validation самостоятельно, Rules не
   заменяют Function-level проверку (тот же принцип независимо подтверждён
   `FIREBASE_ARCHITECTURE.md §10`, помечено как Proposed input).
4. Client-declared identity/capability/age/role — никогда не authority
   (сквозной принцип, унаследован `BCK-01 §13` п.12, `IDENTITY_PUBLISHER_SLICE_SPEC.md §11.3`).

Trust boundary diagram (текстовый, без mermaid — репозиторий пока не
использует диаграммный формат в `docs/product/`):

```text
Mobile client (untrusted)
  -> Firebase Auth token + App Check token (transport, semi-trusted signal)
    -> trusted Function/callable handler (validates Auth, App Check, capability, payload)
      -> Firestore authoritative transaction (server-only)
        -> Security Rules (defense-in-depth, deny-by-default for direct access)
```

**Open:** полный per-asset threat model (STRIDE или аналог) с explicit
attacker capabilities по каждому trust boundary — `BCK04-OD-01`, owner
Security/Privacy, до Approved.

## 6. Backend data inventory

`BCK-01 §12` требует, чтобы **каждый BCK-spec** классифицировал свои
record/field до schema approval; наличие Firestore collection не является
data inventory само по себе. BCK-04 не владеет чужими record families — он
задаёт формат инвентаря, который каждый domain-spec обязан заполнить.

### 6.1 Формат записи инвентаря (обязателен для каждого domain BCK-spec)

```text
recordFamily
owningSpec (BCK-XX)
storage (Firestore collection | Storage path | derived index)
dataClass (см. §7)
purpose
legalBasis
accessPrincipals
retentionClass (см. §19)
exportable (yes/no)
deletable (yes/no, mechanism)
backupTreatment
logExclusion (yes/no)
```

### 6.2 Предварительный (non-authoritative) seed из Proposed input

`FIREBASE_ARCHITECTURE.md §8` (Proposed, не Accepted) предлагает aggregate
map: `users`, `userPrivate`, `authLinks`, `managedPages` + `members`,
`content`, `contentPrivate`, `catalogItems`, `mediaAssets`, `auditLogs`,
`reviews`, `reports`, `bookmarks`, `notifications`, `quickPlans`. Это
**черновой список для примера формата**, не Accepted collection topology —
финальный inventory собирается каждым владеющим domain-spec по формату §6.1
и Approved только вместе с этим доменом.

**Open:** полный подписанный data inventory по каждому объявленному в
`BCK-02 §5` domain — `BCK04-OD-02`, поэтапно закрывается по мере Approval
`BCK-06`–`BCK-22`, не единовременно.

## 7. Классификация данных (Data Classification Matrix)

Принята существующая 5-классная модель `BCK-01 §12` — без параллельного
словаря:

| Class | Примеры | Базовое обращение |
|---|---|---|
| **Public** | Published title, public geo/category, approved publisher snapshot | Только через sanitized public projection |
| **Protected** | User Booking, private Scenario, page membership, precise private location | Actor/scope authorization required |
| **Sensitive** | Verification evidence, access code, support evidence, abuse report | Minimized, encrypted/service-restricted, никогда public |
| **Operational** | Idempotency, lease, outbox, job state, audit | Backend-only кроме bounded admin projection |
| **Derived** | Search index, availability/rating counters, feed/map projection | Rebuildable, revisioned, freshness-labelled |

### 7.1 Reconciliation с исходным запросом на BCK-04

Исходный запрос перечислял 7 классов (`public/protected/private/sensitive/
operational/audit/analytics`). Решение v0.1: **не вводить два дополнительных
класса**, а выразить их как поднаборы уже принятых пяти:

- `private` — уточнение `Protected` (actor-owned, не shared page/team scope);
  не отдельный класс, а атрибут `scopeKind: owner-only | team | page`
  внутри `Protected`;
- `audit` — поднабор `Operational` с обязательным `immutable: true` и
  собственным retention (`§19`); `audit` — purpose/record-kind метка, не
  class сама по себе, и не задаёт class автоматически;
- `analytics` — **purpose/record-kind метка, не class**. v0.1 ошибочно
  привязывал её к `Derived` автоматически ("поднабор Derived, если
  построено из product-событий"). Это неверно: raw или pseudonymous
  analytics event до агрегации/анонимизации может содержать данные,
  которые по содержимому относятся к `Protected` или даже `Sensitive`
  (например, precise event location, device/session identifiers,
  free-text). Только по-настоящему aggregated/anonymized analytics
  projection, для которой `piiExcluded: true` доказано, а не просто
  заявлено, классифицируется как `Derived`. Класс конкретной analytics
  record family назначает owning domain-spec **по фактическому
  содержимому этой записи**, а не по факту, что она называется
  "analytics".

Это не блокирует domain-specs от использования слов «private»/«audit»/
«analytics» в прозе как purpose/record-kind меток — но schema-level
classification field остаётся одним из пяти значений `BCK-01 §12`,
назначаемым по содержимому конкретной record family, а не по её метке.

## 8. Authentication

Источник: `BCK-01 §13` п.1, `ADR 0015`, `IDENTITY_PUBLISHER_SLICE_SPEC.md
§5`.

- Providers: Google и Apple (production); email/password не добавляется —
  расширяет account recovery/abuse/support scope без утверждённой
  необходимости (тот же вывод независимо подтверждён `FIREBASE_ARCHITECTURE.md
  §9.1`, Proposed input);
- нет unauthenticated guest-режима (`ADR 0015`); cold start/logout/expired
  session/deep link без валидной сессии открывает auth flow;
- Firebase Auth token подтверждает session identity; capability и role
  решает backend (`BCK-01 §13` п.1) — Auth token сам по себе не есть
  authorization;
- multi-device baseline: до **3 активных сессий на аккаунт** (`ADR 0013`
  п.6) — revoke сверх лимита не product-специфичен, задаётся этой
  политикой для всех domain;
- token refresh, revoked session, forced logout, provider/account
  collision — обязательные edge cases (унаследовано из `ADR 0013` п.6 и
  `IDENTITY_PUBLISHER_SLICE_SPEC.md §5`);
- service identity (Functions/Scheduler) — отдельная категория principal,
  не пользовательская сессия; least-privilege IAM per task (`BCK-01 §13.1`
  строка Service identity).

**Open:** точный session/token TTL, refresh-cadence и account-deletion
provider-revocation edge cases на уровне Firebase — принадлежит exact
executable slice после Approved architecture (`BCK04-OD-03`).

## 9. Authorization

### 9.1 Принцип

`session + verification + role + global capabilities + publisher membership
+ ownership + entity state` (дословно из `BCK-01 §9`/`FIREBASE_ARCHITECTURE.md
§3.2`, согласовано между обоими источниками).

Роль не авторизует операцию сама по себе. Admin role или `admin.*`
capability не подразумевает Creator verification, page membership или
publisher eligibility (`ADR 0017`, `BCK-01 §13.1`).

### 9.2 Master authorization matrix (Authorization/Capability Matrix)

Прямая цитата `BCK-01 §13.1` — единственная нормативная версия, domain-specs
детализируют её, но не заменяют:

| Principal/context | Базово разрешено | Всегда требуется дополнительно | Запрещено |
|---|---|---|---|
| No valid session | Auth bootstrap only | Approved provider flow | Product queries, profile, mutation |
| Authenticated active User | Authorized consumer reads; own library/profile commands | Exact actor/resource checks | Creator/page/admin authority |
| Verified Creator personal context | Personal create/submit/publish где capability существует | Active account, verification, type/action capability, lifecycle | Page publication без membership |
| ManagedPage member | Exact-page actions в granted scope | Active membership, exact page ID, page capability, market eligibility | Cross-page access или global grant |
| Admin/support principal | Explicit tool/case action only | Dedicated capability, reason/case, audit; two-person repair где требуется | Publisher/workspace impersonation и silent direct writes |
| Service identity/worker | Exact scheduled/event task | Least-privilege IAM, accepted event/lease/idempotency contract | General user/domain access вне task |

Revocation — fail-closed: любая authoritative mutation оценивает текущий
server-owned access; устаревший mobile-снапшот роли/workspace никогда не
авторизует команду. Суспензия session/verification/membership/capability/
market делает связанный cached access недействительным и производит typed
outcome, не раскрывая, существует ли недоступный ресурс (anti-enumeration,
см. §11.2).

### 9.3 Capability baseline (наследуется, не переопределяется)

`IDENTITY_PUBLISHER_SLICE_SPEC.md §10` уже задаёт минимальную семантическую
матрицу Personal vs Page publisher (`create.<type>`, `submit.<type>`,
`publish.<type>.direct`, `manage_page`, `view_insights`, `manage_bookings`).
BCK-04 не дублирует эту таблицу — domain BCK-specs расширяют её точными
кодами per Create type.

## 10. Publisher/workspace isolation

Источник: `FIREBASE_ARCHITECTURE.md §8.2, §8.2.1` (Proposed input),
`IDENTITY_PUBLISHER_SLICE_SPEC.md §4, §7`.

- Personal profile и Professional Page — разные workspace, не разные роли;
- membership хранится как bounded document lookup на конкретную page —
  Rules не используются как query engine для списка страниц пользователя;
- Page A membership или cached selection никогда не авторизует Page B;
- активная workspace preference — owner-only, никогда не evidence
  авторизации (`IDENTITY_PUBLISHER_SLICE_SPEC.md §13`);
- suspended/revoked/missing page access откатывается на personal workspace
  с stable reason code; существующий draft сохраняет свой publisher и
  fail-closed, пока пользователь явно не разрешит конфликт;
- Page IDs не упаковываются в Firebase custom claims (claim size limited,
  membership динамична) — авторизация page-scope читается по exact
  membership lookup или проверяется внутри callable Function.

## 11. API security (интеграция с BCK-03)

BCK-04 не дублирует wire-контракт — он задаёт security overlay поверх
`BCK-03`:

### 11.1 Обязательные требования к каждому API-endpoint

- `actorContext` — только server-resolved (`BCK-03 §12` уже это фиксирует;
  BCK-04 требует, чтобы ни один domain command не принимал capability/role/
  verification claim из client payload — см. §9.1);
- typed failure envelope (`BCK-03 §14`) используется для всех
  security-related отказов — `unauthenticated`, `permission_denied`,
  `not_found` (anti-enumeration), `rate_limited`;
- payload bounds (`BCK-03 §20`) — обязательное условие защиты от abuse на
  API-границе, не опционально для security-sensitive команд.

### 11.2 Anti-enumeration Matrix

| Ресурс | Правило | Источник |
|---|---|---|
| Чужой private Booking/Scenario | `not_found`, не `permission_denied` | `BCK-03 §14` |
| Чужая Page (не участник) | `not_found` для несуществующей и недоступной одинаково | `BCK-01 §13.1` (revocation "не раскрывая... существует ли") |
| Верификационные документы других пользователей | Недоступны через API вообще, не через error-differentiation | `IDENTITY_PUBLISHER_SLICE_SPEC.md §13` |
| Suspended/revoked access к ранее доступному ресурсу | Typed outcome без утечки причины конкурентам/атакующему | `BCK-01 §13.1` |

Точный per-resource mapping (какие ресурсы enumeration-sensitive) —
делегируется owning domain BCK-spec; здесь фиксируется только механизм.

### 11.3 Зарегистрированный fixture-vs-normative-spec конфликт (не решается здесь)

Нормативное правило **подтверждено на уровне двух документов**, не только
"Draft rule" в BCK-03:

- [`BCK-09` §13 Idempotency](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md):
  "Для client v1: `idempotencyKey == requestId`. Mismatch — invalid
  command.";
- [`EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md` строки
  263–264](EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md): "In
  v1 the explicit derivation is `idempotencyKey == requestId`; a mismatch is
  an invalid command."

Committed fixture (`packages/api_contracts/schema/booking/v1/fixtures/
valid.json`) **нарушает это правило**: `requestId` и `idempotencyKey`
командных записей там — два разных значения. Это не два равнозначных
источника истины, между которыми можно выбирать — это **fixture,
противоречащий уже нормативному (BCK-09 Review + ECL-03C) правилу**. Сам
BCK-03 v0.2 при этом содержит собственную ошибку: строка delta-таблицы §34
"`requestId` and idempotency semantics are fixture-verified" фактически
неверна — committed fixture эту семантику не подтверждает, а нарушает.

BCK-04 **не разрешает** этот конфликт самостоятельно (не его scope) и не
трактует нарушающий fixture как новую фактическую норму. Регистрируется как
блокер: **BCK-03 требует v0.3 reconciliation** (исправить fixture под
`idempotencyKey == requestId`, либо получить новое ADR-level решение,
меняющее правило BCK-09/ECL-03C) до BCK-03 Review. До этой reconciliation
BCK-04 использует idempotency (§16) только по принципу — "ключ должен быть
проверяемо стабильным между повторами", не полагаясь на то, равен он
`requestId` или нет.

## 12. Firestore Rules и IAM (Firestore Rules/IAM Matrix)

### 12.1 Принципы (нормативно, `BCK-01 §13` п.4, §14)

- Firestore/Storage Rules — default-deny;
- authoritative mutation (submission, publication, moderation, capability
  changes, page membership, counters, audit, catalog projections) —
  server-only, никогда прямой client write;
- direct cross-module Firestore writes запрещены — aggregate transaction
  принадлежит одному module (`BCK-01 §14`);
- least-privilege service identities для privileged operations.

### 12.2 Detail-уровень — Proposed input, не settled

`FIREBASE_ARCHITECTURE.md §11` предлагает конкретные rule techniques (field
diff allowlists, exact membership lookup within bounded quota, deny broad
collection reads без provable rule) и required emulator test matrix
(unauthenticated denial, provider-authenticated с разными verification
состояниями, cross-page isolation, batch/transaction lookup limits). Это
**Proposed input**, полезное как starting point для BCK-04 v0.3+ или для
executable slice, но не Accepted decision этой версии.

### 12.3 Matrix — direct client writes (safe default, не Accepted allowlist)

`BCK-03 AC-23` требует: "every mutation is a registered versioned command."
Любая прямая запись клиента в Firestore, минуя command/API-слой BCK-03, —
mutation без registered command и конфликтует с этим требованием. Поэтому
v0.2 меняет safe default на **запрет**, а не переносит `FIREBASE_ARCHITECTURE.md
§11.1` предложение как готовое решение:

| Прямая запись клиента | Разрешено? | Условие |
|---|:---:|---|
| Owner-only preference с allowlist полей | **Нет — запрещено до отдельного решения** | Делегировано owning domain (`BCK-18`) |
| Bookmarks/favorites под authenticated user | **Нет — запрещено до отдельного решения** | Делегировано `BCK-12` |
| Notification `isRead` | **Нет — запрещено до отдельного решения** | Делегировано `BCK-13` |
| Page membership, capability, verification | Нет | Server-only, без исключений |
| Counters, audit, catalog projection | Нет | Server-only, без исключений |
| Booking/hold/ledger (любое поле) | Нет | ADR 0019 authoritative transaction only |

Если `BCK-12`/`BCK-13`/`BCK-18` после Approval `BCK-03`/`BCK-04` захотят
явно разрешить bounded direct-write исключение (например, ради задержки
записи для offline-first UX) — это их собственное, явно обоснованное
решение с fixture/Rules evidence, а не наследуемый по умолчанию список.

**Open:** физические `.rules` файлы и их emulator test suite — не создаются
этой спецификацией (`§28`), реализация после Approved executable slice.

## 13. Storage и media security

Источник: `FIREBASE_ARCHITECTURE.md §12` — **Proposed input**, не Accepted.
Принципы, которые BCK-04 принимает как Draft rule (не наследует статус
источника):

- upload session — bounded, привязана к user/publisher/entity/asset ID,
  allowed MIME types, max size, expiry;
- authenticated не равно authorized — ownership или exact page membership
  проверяется для каждой private записи;
- declared MIME недостаточен — file signature validation обязательна;
- public derived variants — server-written only;
- публичная выдача никогда не раскрывает private original;
- удаление/замена — audited и уважает content lifecycle.

**Open:** конкретный path model, variant sizes, retention media originals —
делегируется `BCK-14` (Media Platform owner) как owning domain-spec;
BCK-04 задаёт только security-инвариант выше.

## 14. App Check

Источник: `BCK-01 §13` п.3 (нормативно), `ADR 0019` D02 rollout
(`monitor → enforce`), `FIREBASE_ARCHITECTURE.md §15.2/§19.2` (Proposed
detail).

- App Check — дополнительный сигнал, **не замена** AuthZ, Rules или rate
  limits (`BCK-01 §13` п.3 — нормативно, не Proposed);
- rollout: integrate SDK → monitor missing/invalid metrics в dev/stage →
  verify legitimate traffic → enforce на mutation functions в production;
- App Check failure никогда не даёт bypass другим security-контролям (§16);
- recovery/emergency bypass policy — **Open**, не решено ни в одном
  найденном источнике (`BCK04-OD-04`).

## 15. Secrets и cryptographic material

Источник: [`ENV_FLAVORS_SECRETS.md`](../architecture/ENV_FLAVORS_SECRETS.md),
[`secrets-rotation.md`](../runbooks/secrets-rotation.md),
[`secret-leak-response.md`](../runbooks/secret-leak-response.md) — все три
реально существуют как действующая repository policy. `LAUNCH_STATUS`
отмечает "Env / Flavors / Secrets" как `Done` — это статус завершённости
документации/процесса в стадийном трекере, не формальный ADR-уровня
`Accepted` статус; смешивать эти два словаря статусов не следует (см.
`BCK-01 §3` п.4: LAUNCH_STATUS владеет implementation/runtime status, но не
заменяет архитектурное Accepted/Approved).

- Secrets — только в secret managers или CI protected secrets; никогда в
  Flutter-коде, репозитории, тестах, логах или PR/issue-описаниях;
- три изолированных environment: `dev`/`stage`/`prod`, раздельные Firebase
  projects, credentials, billing alerts;
- rotation: high-risk secrets — каждые 90 дней или немедленно при утечке/
  смене персонала; процедура revoke → issue new → deploy → verify → remove
  fallback;
- leak response: contain/revoke → rotate → audit access/deploy logs →
  notify stakeholders → remediation tasks + post-incident summary
  (`secret-leak-response.md`, применимо напрямую, без изменений);
- production credentials — только approved maintainers/CI context.

BCK-04 не вводит отдельную secrets-политику — наследует существующую as-is
и требует, чтобы каждый domain BCK-spec, работающий с provider credentials
(Payments, AI, provider integrations), ссылался сюда, а не изобретал свою.

## 16. Abuse, fraud и rate limiting (Abuse/Rate Limit Matrix)

### 16.1 Numeric defaults — Accepted, не Open

В отличие от v0.1 coverage matrix, часть чисел здесь уже Accepted через
`ADR 0013`, а не Open:

| Параметр | Значение | Источник |
|---|---:|---|
| Auto-hide threshold (reports) | ≥5 уникальных reporters / 24 часа | `ADR 0013` п.4 |
| Report uniqueness | По одному на пользователя на объект | `ADR 0013` п.4 |
| Creator publish velocity | 100 публикаций/день (baseline) | `ADR 0013` п.20 |
| Active sessions per account | До 3 | `ADR 0013` п.6 |
| Soft-delete retention | 30 дней | `ADR 0013` п.3 |

### 16.2 Принципы за пределами уже заданных чисел

- rate limits учитывают actor, device/app signal, command risk и global
  abuse protection; **точные пороги за пределами таблицы выше** принадлежат
  domain/`BCK-05` (`BCK-01 §13` п.8 — явно делегирует остальное);
- App Check failure не даёт rate-limit bypass (§14);
- idempotency abuse — см. §11.3, зависит от закрытия BCK-03 reconciliation;
- sanctions handoff — `BCK-22` (Trust & Safety), пока `RA` (§3 coverage
  matrix), BCK-04 фиксирует только typed `rate_limited`/`unavailable` outcome
  boundary (`BCK-03 §14`, §32).

**Open:** device/IP-level fingerprinting policy, scraping detection,
credential-stuffing specific control — ни один источник их не определяет
(`BCK04-OD-05`).

## 17. Privacy processing (Consent and Legal Review Matrix)

Источник: `ADR 0013` п.19, `IDENTITY_PUBLISHER_SLICE_SPEC.md §13`,
[GDPR Articles 6–7](https://eur-lex.europa.eu/eli/reg/2016/679/oj) (LV/EE/LT
— все три EU/EEA рынка, GDPR применяется напрямую).

### 17.1 Legal basis — не сводится к consent

v0.2 трактовал consent как фактически единственное основание обработки. Это
неверно: GDPR Art. 6(1) перечисляет **шесть** равноправных оснований —
consent (a), contract necessity (b), legal obligation (c), vital interests
(d), public task (e), legitimate interests (f). Recharge, как большинство
product-платформ, скорее всего опирается на **разные** основания для разных
purposes (например, contract necessity для Booking fulfilment, legitimate
interests для fraud prevention, consent — только там, где действительно
нужен opt-in, например marketing). BCK-04 не назначает конкретное основание
per purpose — это `BCK04-OD-06`, но фиксирует: ни один domain-spec не
вправе объявить "у нас всё на consent" по умолчанию, не проверив Art. 6(1)
применимость.

- consent baseline: **opt-in в EU, opt-out в non-EU** (`ADR 0013` п.19,
  Accepted) — применимо конкретно к consent-based processing (например,
  marketing communications), не ко всем видам обработки данных;
- обязательный legal/privacy review per market до release (`ADR 0013`
  п.19) — до этого market-specific processing не активируется;
- verification evidence — private, шифруется по platform policy, исключена
  из public profile и analytics payload (`IDENTITY_PUBLISHER_SLICE_SPEC.md
  §13`);
- **consent withdrawal отделён от deletion/DSR** (Art. 7(3): withdrawal
  должен быть так же просто, как and independent of a data-subject erasure
  request). Withdrawal consent для конкретной processing purpose
  (например, marketing) не подразумевает автоматическое удаление аккаунта
  или всех данных — это два разных запроса с разными последствиями,
  которые BCK-04 v0.2 ошибочно объединял в одну строку.

### 17.2 Open decisions за пределами уже принятых

**Open:** exact legal basis формулировка per processing purpose, consent
versioning schema — `BCK04-OD-06`, требует Legal/Privacy owner, blocking
для G1 наравне с `OD-07`/`OD-10`.

**Open (новые, GDPR-обусловленные, не покрыты ни одним существующим
источником):**

- `BCK04-OD-10` — Records of Processing Activities (ROPA, Art. 30): реестр
  processing activities с purpose/legal basis/categories/recipients/
  retention/transfers;
- `BCK04-OD-11` — Data Protection Impact Assessment (DPIA, Art. 35) gate:
  когда конкретная feature (например, age-verification для OD-11,
  large-scale profiling) требует DPIA до активации;
- `BCK04-OD-12` — processor/subprocessor inventory (Art. 28): какие
  third-party сервисы (Firebase/Google Cloud как processor, любой
  analytics/notification provider) обрабатывают данные от имени Recharge,
  с обязательным Data Processing Agreement;
- `BCK04-OD-13` — international-transfer policy (Art. 44 и далее): если
  какой-либо processor хранит/обрабатывает данные вне EU/EEA, требуется
  adequacy decision или appropriate safeguards (SCCs); связано с `OD-07`
  data residency, но не идентично ему — OD-07 про то, где Recharge сам
  хранит данные, OD-13 про то, где processors данные обрабатывают.

Все четыре — owner Security/Privacy + Legal, blocking для production
personal data обработки, не для Approved BCK-04 самого по себе (design
readiness не требует, чтобы ROPA/DPIA уже существовали, но требует, чтобы
эти gates были явно запланированы).

## 18. OD-11 — minors/age eligibility

`OD-11` уже зарегистрирован (`BCK-02 §16`, строка реестра `OD-11`) как
`Open`, owner
Security/Privacy, блокирует R2 production account creation, Find People,
age-restricted publication/discovery, applicable Booking paths, G6. BCK-04
не создаёт это решение с нуля — добавляет Draft recommendation-policy
поверх него, по решению владельца (см. `BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX_OPEN_QUESTIONS.md`
вопрос 2):

### 18.1 Draft policy (Proposed — not Accepted)

- политика версионируется **отдельно для LV, EE и LT** — единого глобального
  возраста нет;
- BCK-04 **не назначает** конкретный минимальный возраст или legal basis —
  это Legal/Privacy review per market;
- guardian consent, verification requirements принимаются только после
  такого review;
- **client-declared age не является authority** — совпадает со сквозным
  принципом §8/§9;
- до Accepted решения по конкретному рынку: production account creation,
  Find People, age-restricted публикация/discovery, applicable Booking paths
  — **server-disabled и fail-closed** для этого рынка;
- disabled Booking Emulator core (`BCK-09`/`G4`) **не блокируется
  глобально** — age-sensitive paths внутри него остаются server-disabled
  индивидуально, пока их конкретный scope не Accepted;
- каждое per-market решение фиксирует: `market`, `productScope`, `owner`,
  `legalReviewDate`, `effectiveDate`.

### 18.2 Статус

`Proposed — not Accepted`. Реализация (age-gate UI, guardian flow,
verification backend) не разрешается этой спецификацией — только контракт
fail-closed поведения до Accepted.

## 19. Retention matrix (Retention/Deletion Matrix)

### 19.1 Best-available recommendation — Booking-scoped (D04), не "Accepted" таблица

v0.2 называл эту таблицу "единственной реально Accepted retention-таблицей".
Это неточно: сам источник, сразу после таблицы и списка правил, прямо
говорит — "these values are product recommendations, not legal advice...
D04 remains open until Privacy/Legal/Product approve the exact table and
backup behavior." Статус decision package в целом — Accepted как
*normative recommendation* (Booking-домен обязан строить retention вокруг
именно этих классов и порядка величины, не изобретать параллельную схему),
но **конкретные числа остаются Open** до отдельного Privacy/Legal/Product
approval. BCK-04 наследует её как лучший доступный, уже проработанный
seed — не как решённую policy, которую можно process освободить от
Legal review:

| Data class | Active retention | Terminal retention | Terminal action |
|---|---:|---:|---|
| Booking core IDs/state | До occurrence/obligation | 90 дней | Удалить user linkage |
| Named guest identity | До occurrence | 30 дней | Удалить |
| Application form fields | До decision/occurrence | 30 дней | Удалить content; сохранить decision code |
| Eligibility evidence ref | До final decision/occurrence | 30 дней | Удалить/отозвать protected ref |
| Active hold | До resolution | 30 дней | Удалить payload; сохранить audit event |
| Idempotency key/result | Command lifecycle | 30 дней | Удалить после retry window |
| Notification payload/outbox | До delivered/dead-letter | 30 дней | Удалить rendered/private аргументы |
| Delivery metadata | От delivery attempt | 90 дней | Aggregate/anonymize |
| Booking audit | От occurrence/terminal state | 180 дней | Псевдонимизация или удаление по policy |
| Security/support repair audit | От action | 180 дней | Restricted archive/delete по policy |
| Ordinary operational logs | От emission | 30 дней | Удалить |
| Dead-letter diagnostic payload | До resolved | Максимум 30 дней | Удалить после resolution |

Эти числа не активируются для production personal data автоматически —
`BCK-09`/Booking owner обязан получить отдельное Privacy/Legal/Product
approval именно этой таблицы (или её обоснованной модификации) до
production Booking с реальными пользовательскими данными, что уже требует
и сам источник D04.

### 19.2 Non-Booking classes — нет generic numeric default

v0.1 предлагал экстраполировать `ADR 0013` п.3 (soft-delete 30 дней,
established для entity lifecycle, не для Sensitive/audit data) на все
классы, включая жёсткий "максимум 30 дней" для `Sensitive` и "180 дней" для
`Operational (audit)`. Это отозвано: автоматическое присвоение числового
retention для Sensitive-данных (verification evidence, access codes,
support evidence) и для audit без per-domain Legal/Privacy review создаёт
риск либо преждевременного удаления нужной evidence, либо избыточного
хранения PII дольше необходимого — в обоих случаях решение не должно
приниматься этой спецификацией по аналогии.

| Data class (§7) | Retention default здесь | Кто решает |
|---|---|---|
| Public | Соответствует `ADR 0013` п.3 (soft-delete 30 дней) — применимо, это entity lifecycle, не PII-специфичная политика | Уже Accepted, применяется как есть |
| Protected | **Нет числового default** | Domain-spec обязателен, PII-heavy families требуют Legal/Privacy review до production |
| Sensitive | **Нет default, no fallback** | Каждый domain-spec обязан предложить собственную Accepted таблицу с Legal/Privacy approval до production; молчание не означает "30 дней" |
| Operational (non-audit) | Может ориентироваться на D04 паттерн (idempotency/log ~30 дней) как **Proposed**, не Accepted generic rule | Domain-spec подтверждает явно |
| Operational (audit) | **Нет default** | Legal hold requirements различаются по типу audit — Security/Privacy owner решает per record family, не по аналогии с Booking |
| Derived | Rebuild cycle, без независимого retention (rebuildable) | Применимо как есть, если содержит PII после агрегации — см. §7.1 |

**Правила** (унаследовано из D04 rules, применяется ко всем классам):

- retention считается по backend time и versioned policy, не по console
  edit;
- deletion workers идемпотентны и производят privacy-safe completion audit;
- user deletion немедленно блокирует access и запускает approved deletion/
  pseudonymization workflow;
- нет indefinite ordinary retention;
- analytics copy PII/free text/access evidence запрещена;
- backup propagation limit и exceptional legal/security hold — Privacy/
  Legal обязаны зафиксировать до production (`BCK04-OD-07`, пересекается с
  §23).

**Open:** Sensitive и Operational (audit) retention для non-Booking классов
не имеют default вообще (§19.2) — каждый domain BCK-spec обязан предложить
собственную Accepted таблицу с Legal/Privacy approval перед production
personal data; отсутствие таблицы не разрешается трактовать как "30/180
дней по умолчанию".

## 20. Export/deletion/DSR (DSR Orchestration Matrix)

Источник: `BCK-01 §8–9` (Privacy Orchestration module, owner BCK-04;
"Domain-owned handlers execute scoped export/deletion work"), `BCK-01 §13`
п.10, `IDENTITY_PUBLISHER_SLICE_SPEC.md §13`, [GDPR Chapter III, Articles
15–20](https://eur-lex.europa.eu/eli/reg/2016/679/oj).

### 20.1 Полный набор data subject rights, не только export/delete

v0.2 покрывал только export (Art. 15/20) и deletion (Art. 17). GDPR Chapter
III определяет шесть прав, и orchestration contract обязан поддерживать
все шесть типов запроса, даже если некоторые сначала реализуются как
"contact support" вручную, а не self-service API:

| Право | Article | Request type | v0.3 контракт |
|---|---|---|---|
| Access | Art. 15 | `access` | То же, что export, но может не включать machine-readable format |
| Rectification | Art. 16 | `rectification` | Роутится в owning domain как update command, не DSR-specific handler |
| Erasure ("right to be forgotten") | Art. 17 | `deletion` | §20.2, с учётом §20.3 exemptions |
| Restriction of processing | Art. 18 | `restriction` | Помечает record family как "frozen" (read-only, no further processing) без удаления — новый request type, ранее отсутствовал полностью |
| Data portability | Art. 20 | `portability` | Export в structured, commonly used, machine-readable format — не то же самое, что access |
| Objection | Art. 21 | `objection` | Применимо к processing на основании legitimate interests (Art. 6(1)(f)) — останавливает конкретную purpose, не весь аккаунт |

### 20.2 Orchestration contract

```text
DSR request (access | rectification | deletion | restriction | portability | objection)
  -> BCK-04 orchestration entry point (authoritative coordinator)
    -> fan-out to domain-owned handlers (BCK-06..BCK-22, по applicable data)
      -> each handler executes scoped action per §19 class and request type
    -> completion evidence aggregated
  -> user-visible completion status
```

- domain handlers исполняют **только собственные** record families — BCK-04
  не пишет напрямую в чужие collections;
- completion evidence — audit record (Operational/audit class, §19.2), не
  raw content;
- retry/reconciliation — незавершённый handler не блокирует остальные
  бессрочно; timeout производит typed incomplete-status с owner escalation.

### 20.3 Erasure (Art. 17) не абсолютно — но и retention не абсолютен

v0.2 формулировал: "legally retained audit не удаляется по DSR раньше
своего retention." Это верно только как частный случай общего правила GDPR
Art. 17(3): erasure не применяется, если обработка необходима для
compliance with legal obligation, legal claims, public interest archiving
и т.д. — **это применимое исключение (exemption), не то, что internal
retention policy сама по себе отменяет erasure right**. BCK-04 v0.2 неявно
представлял внутренний retention как достаточное основание для отказа в
удалении — это неточно и потенциально невыполнимо: без явного mapping на
конкретный Art. 17(3) exemption (например, "180-дневный security audit
удерживается под Art. 17(3)(e) — establishment/exercise/defence of legal
claims"), просто "у нас retention 180 дней" не является valid legal ground
отказать в erasure request.

**Правило v0.3:** каждая retention-запись в §19, которая может пережить
DSR erasure request, обязана явно указывать применимый Art. 17(3)
exemption как часть своей domain-spec записи — не полагаться на факт
существования retention policy самой по себе.

**Open:** конкретный SLA на DSR completion, exact export/portability
format, UI/API contract для запроса каждого из шести типов —
`BCK04-OD-08`.

## 21. Logging и audit (Security Logging Matrix)

Источник: `BCK-01 §13` п.7, `BCK-03 §32` (Observability and diagnostics —
единственный logging-раздел BCK-03; `§33` — Persistence, transaction and
index applicability, к logging не относится и здесь не цитируется),
`FIREBASE_ARCHITECTURE.md §15.3/§16.1` (Proposed detail).

- Logs, analytics, events и errors проходят redaction/minimization
  (`BCK-01 §13` п.7 — нормативно);
- audit — append-only, server-written, immutable в пределах retention
  (`BCK-01 §14`);
- correlation/causation ID для трассировки, без raw payload по умолчанию
  (`BCK-03 §32`);
- запрещено в обычных логах: секреты/токены, verification evidence, precise
  private location, named guest/application free text, provider/payment
  sensitive material, полный stack trace клиенту (`BCK-03 §32`, согласовано
  с `BCK-01 §13` п.7);
- privileged read audit — доступ к Sensitive/Protected данным через
  admin/moderation инструмент сам по себе аудируется, не только запись.

### 21.1 Security Logging Matrix (seed)

| Событие | Логируется? | Redaction |
|---|:---:|---|
| Auth success/failure | Да | Без credentials/tokens |
| Privileged admin read (verification evidence) | Да | Actor + resource ID + reason code, не содержимое |
| Rate-limited/abuse decision | Да | Actor/device signal, не raw fingerprint |
| Rejected mutation (`permission_denied`, `invalid_argument`) | Да | Typed code + correlation ID, не payload |
| Successful ordinary read | Опционально, aggregated | Без per-request PII |
| Search query text | Нет по умолчанию | — |

## 22. Data residency и OD-07

`OD-07` — Open, owner Platform (совместно `BCK-04`/`BCK-05` по `BCK-01
§21`), блокирует R1 provisioning. `FIREBASE_ARCHITECTURE.md §4.3`
предлагает (**Proposed, не Accepted**) `eur3`/`europe-west1`, но сам текст
источника прямо требует "a recorded data-residency, cost and latency review"
и запрещает "Creating the production database before that approval".

BCK-04 фиксирует только boundary-требования:

- LV/EE/LT residency — единая политика для всех трёх, если Legal review не
  потребует разделения;
- итоговое решение о регионе — совместное Approval `BCK-04`+`BCK-05`, не
  односторонне ни одним из них;
- до Accepted `OD-07` — physical provisioning запрещён (`ADR`-уровня
  запрет, не рекомендация).

**Open:** сам `OD-07` (region/edition), и связанный LV/EE/LT-специфичный
market policy detail — принадлежит `BCK-20` для non-residency частей.

## 23. Backup/restore privacy

Источник: `BCK-01 §14` ("backups не заменяют domain reconciliation и
restore tests"), `FIREBASE_ARCHITECTURE.md §22` п.10 (Proposed, явно
перечисляет "Backup schedule, retention and restore RTO/RPO" как
нерешённое).

Принципы:

- backup — не заменяет DSR deletion; если deletion произошёл, backup
  propagation limit обязателен (пересекается с §19.1 D04 rule);
- restore access — так же принципиально least-privilege, как production
  access, не отдельная более широкая категория;
- post-restore reconciliation обязательна для authoritative Booking/ledger
  данных (`BCK-01 §14` Booking-специфичное правило).

**Open:** backup schedule, encryption-at-rest detail, exact RTO/RPO —
принадлежит `BCK-05`; BCK-04 фиксирует только privacy-инвариант выше
(`BCK04-OD-07`, тот же item, что в §19).

## 24. Migration и local-to-cloud import security

Источник: `FIREBASE_ARCHITECTURE.md §18.2` (Proposed), `BCK-18` (Mobile
Platform owner, `RA` — ещё не существует).

Принципы, применимые независимо от статуса `FIREBASE_ARCHITECTURE.md`:

- private fields и secrets никогда не копируются в public projection во
  время миграции;
- permanent ID сохраняется через seed/projection;
- dry-run report обязателен перед destructive migration;
- rerun миграции — идемпотентен;
- backup/export — перед любым destructive шагом.

Import identity mapping, conflict policy, checkpoint/retry/dedupe/rollback и
user disclosure — это `OD-04`, owner Mobile Platform, закрывается `BCK-18`,
не этим документом (`BCK-01 §21`).

## 25. Server flags, rollout, rollback, emergency disable

Источник: `BCK-01 §22`, `ADR 0019` ("Disabling a switch блокирует new work,
но никогда не удаляет Booking, holds, audit или history").

- feature rollback: server flag блокирует новые mutations, safe exits
  остаются;
- deployment rollback: предыдущий verified artifact/config восстанавливается;
- data reconciliation: owning domain detect/propose/execute repair с
  immutable audit; blind database restore не заменяет reconciliation;
- security-relevant флаг (App Check enforce, rate-limit threshold,
  age-gate per market) — emergency disable доступен, но каждое отключение
  само аудируется как privileged action (§21).

## 26. Incident response и security-event escalation

Источники: [`secret-leak-response.md`](../runbooks/secret-leak-response.md)
— реален, но покрывает только secret leak; `BCK-02 §6` строка `RUN-06`
(зависит от `BCK-04`) — реально уже фиксирует "Уведомление supervisory
authority в течение 72 часов применяется только при условиях Article 33
GDPR... поэтому runbook требует documented risk assessment и Legal/DPO
escalation." v0.2 не унаследовал это обязательство явно — исправлено.

### 26.1 Personal-data breach — Article 33/34 GDPR (обязательное наследование)

Поскольку `RUN-06` (владеет Security owner, зависит от `BCK-04`) уже
кодирует это требование, BCK-04 обязан явно зафиксировать источник, а не
изобретать собственный incident timeline без ссылки на него:

- **Art. 33** — при personal data breach с риском для прав/свобод физлиц,
  controller уведомляет supervisory authority (для LV — Data State
  Inspectorate) **без неоправданной задержки, и где возможно, не позднее
  72 часов** после того, как breach стал known; если позже 72 часов —
  обязательно reasoned delay explanation;
- **Art. 34** — при **high risk** для прав/свобод физлиц, controller
  дополнительно уведомляет **самих затронутых пользователей** without
  undue delay, в понятной, простой форме;
- documented risk assessment обязателен для решения "нужно ли Art. 33/34
  уведомление" — не автоматическое решение по severity;
- Legal/DPO escalation — часть пути, не опциональный шаг.

### 26.2 Общая модель (за пределами GDPR-специфичного breach)

Общая модель (Draft, экстраполирована из secret-leak паттерна на общий
security incident, поскольку отдельного generic-incident источника нет):

```text
Detect -> Contain -> Assess scope/data classes affected (§7)
  -> Assess Art. 33/34 applicability (personal-data breach? risk level?)
  -> Notify accountable owner + affected domain owners + Legal/DPO if applicable
  -> [If applicable] Notify supervisory authority within 72h; notify users if high risk
  -> Remediate (revoke/patch/rotate/disable flag per §25)
  -> Audit trail (§21) -> Post-incident report -> Remediation tasks
```

- severity classification (P0–P3 или аналог) — **Open**, ни один источник
  не задаёт;
- exact risk-assessment criteria (что считается "high risk" для Art. 34) —
  **Open**, требует Legal/Privacy;
- security tabletop/incident drill — упомянут в исходном запросе как
  обязательная проверка (§29); `RUN-01`/`RUN-06` уже требуют quarterly
  tabletop — periodичность для non-secret security incident наследует тот
  же квартальный ритм, если Security/Privacy owner не предложит иное.

**Open:** severity classification, exact "high risk" criteria — `BCK04-OD-09`,
owner Security/Privacy, до Approved. Сам факт обязательности Art. 33/34
пути и 72-часового окна — **не Open**, это прямое следствие GDPR
применимости к LV/EE/LT и уже частично унаследованного `RUN-06`.

## 27. Open decisions

| ID | Вопрос | Owner | Блокирует | Deferrable без изменения scope? |
|---|---|---|---|:---:|
| `OD-07` (внешний, `BCK-02 §16`) | Firebase topology/edition/regions | Platform (`BCK-04`+`BCK-05`) | R1 provisioning, §22 | Нет (R1) |
| `OD-11` (внешний, `BCK-02 §16`) | Region-versioned minors/age policy | Security/Privacy | R2 account creation, Find People, age-restricted paths, applicable Booking, G6, §18 | Нет (R2/G6) |
| `BCK04-OD-01` | Полный threat model (STRIDE или аналог) по каждому trust boundary | Security/Privacy | **Approved BCK-04 напрямую** | **Нет** |
| `BCK04-OD-02` | Полный подписанный data inventory по каждому domain | Каждый domain owner + Security/Privacy | Production personal data для этого domain | Да, per-domain, до production |
| `BCK04-OD-03` | Session/token TTL, refresh cadence, deletion provider-revocation detail | Identity owner (`BCK-06`) | Executable Auth slice | Да, до executable slice |
| `BCK04-OD-04` | App Check recovery/emergency bypass policy | Platform Operations (`BCK-05`) | App Check enforce rollout | Да, до enforce rollout |
| `BCK04-OD-05` | Device/IP fingerprinting, scraping, credential-stuffing detail | Security/Privacy | Abuse control activation | Да, до activation |
| `BCK04-OD-06` | Exact legal basis per processing purpose, consent versioning | Legal/Privacy | G1 (наравне с OD-07/OD-10) | Нет (G1) |
| `BCK04-OD-07` | Non-Booking retention Accepted values, backup RTO/RPO/encryption | Security/Privacy + `BCK-05` | Production personal data backup | Да, до production backup |
| `BCK04-OD-08` | DSR SLA, export format, request UI/API contract | Security/Privacy + `BCK-18` | Production account deletion/export | Да, до production DSR |
| `BCK04-OD-09` | Полная incident response policy (severity, "high risk" criteria для Art. 34) | Security/Privacy | **Approved BCK-04 напрямую** | **Нет** |
| `BCK04-OD-10` | ROPA / Records of Processing Activities (Art. 30) | Security/Privacy + Legal | Production personal data processing | Да, до production |
| `BCK04-OD-11` | DPIA gate — какие features требуют Data Protection Impact Assessment (Art. 35) | Security/Privacy + Legal | Активация high-risk features (age-verification, large-scale profiling) | Да, до соответствующей feature |
| `BCK04-OD-12` | Processor/subprocessor inventory + DPA (Art. 28) | Security/Privacy + Legal | Production использование любого third-party processor | Да, до production processor onboarding |
| `BCK04-OD-13` | International-transfer policy — adequacy/SCCs (Art. 44+) | Security/Privacy + Legal | Production данных вне EU/EEA processor | Да, до такого transfer; пересекается с OD-07, не идентичен |

Формат соответствует `BCK-02 §16`: `Open -> Proposed -> Accepted | Deferred
| Superseded`; `Deferred` требует owner/причину/срок пересмотра. **Но**: OD,
блокирующие `Approved BCK-04` напрямую (`BCK04-OD-01`, `BCK04-OD-09`) или G1
(`OD-06`, `OD-07`, `OD-11`), нельзя перевести в `Deferred` без **изменения их
собственного blocking scope** — Deferred с сохранением "блокирует Approved
BCK-04" логически противоречиво: если решение отложено, Approval не может
одновременно считаться готовым. Только OD с blocking scope ниже уровня самого
BCK-04 Approval (`OD-02`–`OD-05`, `OD-08`) можно deferred без такого
противоречия.

## 28. Exact future artifact map

Не создаётся этой версией — целевая структура для будущего executable
slice:

v0.2 предлагал собственную `functions/src/security/` директорию —
несуществующую в утверждённом `BCK-01 §17` target layout. v0.3 выравнивает
artifact map с реальной структурой вместо изобретения параллельной:

```text
docs/runbooks/
  backend-privacy-deletion.md      # уже зарегистрирован как RUN-04 в BCK-02 §6
  backend-security-abuse.md        # уже зарегистрирован как RUN-06 в BCK-02 §6

apps/backend/
  firestore.rules                  # не создаётся; после Approved executable slice
  firestore.indexes.json
  storage.rules                    # пропущен в v0.2; часть BCK-01 §17 target layout
  functions/src/
    shared/
      auth/                        # authGuard/session-context resolution (§8–9)
      observability/               # audit/security logging (§21), redaction (§23)
    transport/
      callable/                    # App Check (§14) и capability enforcement (§9) middleware
      http/                        # то же для HTTP-triggered endpoints
```

`RUN-04`/`RUN-06` уже существуют как строки реестра в `BCK-02 §6` (не как
файлы) — BCK-04 v0.3 не создаёт их содержимое, только подтверждает, что они
будут написаны с опорой на §19–21, §26 этого документа. Rate limiting (§16)
и capability-check (§9) логика распределяется между `shared/` и
`transport/*` по тому же принципу — конкретное разбиение решает executable
slice, не эта спецификация.

### 28.0 Privacy Orchestration — реконсиляция BCK-01 §8 vs §17

`BCK-01 §8` (Bounded module map) определяет **Privacy Orchestration** как
отдельный bounded module, owner `BCK-04`: "DSR/export/deletion request
coordination and completion evidence." `BCK-01 §9` (Authoritative ownership
contract) подтверждает то же: "Privacy request/deletion orchestration |
Privacy Orchestration | Domain-owned handlers execute scoped export/
deletion work." Это прямо соответствует DSR orchestration contract §20
этого документа.

Однако `BCK-01 §17` (Target repository map) **не включает** `privacy_orchestration`
в список `modules/` (там только `identity`, `reference_data`, `content`,
`discover`, `booking`, `planning`, `route`, `library_reviews`,
`notifications`, `media`, `admin_support`, `trust_safety`, `analytics`).
Это несогласованность внутри самого `BCK-01` между §8 и §17, не что-то,
что BCK-04 может тихо разрешить в одностороннем порядке. BCK-04
фиксирует наблюдение и предлагает естественный target
(`functions/src/modules/privacy_orchestration/`, по аналогии с остальными
записями `modules/`), но это — **предложение для BCK-01 reconciliation**,
не подтверждённый artifact map.

### 28.1 Что намеренно исключено из artifact map

v0.1 включал `packages/api_contracts/schema/common/v1/actor_context.schema.json`
как будущий артефакт. Отозвано по двум причинам:

1. **Неверное имя пути.** Реальный BCK-03 target для платформенных схем —
   `schema/platform/v1/`, не `schema/common/v1/`; последний вообще не
   существует ни как Accepted, ни как conditional target в BCK-03 v0.2.
2. **Концептуальная ошибка.** `schema/platform/v1` и любой non-Booking
   `schema/<domain>/vN` прямо запрещены до Accepted `API-DEC-05`
   (`BCK-03 §35`). Даже после его принятия, `actorContext` — server-resolved
   (`BCK-03 §12`: "акторContext клиент не заполняет") и никогда не является
   client wire payload — значит ему в принципе не место в списке *input*
   wire-схем. Если понадобится типизировать server-internal actor context
   для межсервисного использования, это отдельное решение domain/BCK-05, не
   часть публичного api_contracts schema surface.

## 29. Test/evidence matrix (Test and Evidence Matrix)

| Категория | Обязательные проверки | Применимость к v0.3 |
|---|---|---|
| Contract tests | `actorContext` server-only, typed error codes | После executable API slice |
| Negative authorization | Каждая строка §9.2 matrix — allow и deny случай | После executable slice |
| Firestore/Storage Rules emulator | Unauthenticated denial, verification states, cross-page isolation, batch/transaction limits | После Approved `.rules` (не эта версия) |
| Cross-user/cross-page isolation | Page A capability никогда не авторизует Page B | То же |
| Revoked-session/capability | Устаревший snapshot не авторизует mutation | То же |
| App Check monitor/enforce | Missing/invalid token metrics, затем enforced rejection | После rollout начала |
| Anti-enumeration | §11.2 matrix — одинаковый response для missing/forbidden | После executable slice |
| Malformed/oversized payload | Соответствует `BCK-03 §20` bounds | Переиспользует BCK-03 fixtures |
| Rate-limit/abuse | §16.1 numeric defaults, соблюдены ли пороги | После `BCK-05` numeric thresholds |
| Redaction | §21 запрещённые поля отсутствуют в логах | После logging pipeline |
| Deletion/export/DSR | §20 orchestration завершает fan-out корректно | После `BCK-06`+ handlers |
| Backup/restore privacy | §23 propagation limit соблюдён | После `BCK-05` backup slice |
| Security tabletop/incident drill | §26 escalation path проверен end-to-end | Периодичность — Open (`BCK04-OD-09`) |
| Legal/Privacy review | §17 per-market review завершён до release | Per market, до G1/G3 |

Ни одна строка этой таблицы не имеет пройденного evidence в v0.3 — таблица
фиксирует **что** будет проверяться, не заявляет прохождение.

## 30. Definition of Ready, Definition of Done, Acceptance Criteria, unimplemented list

### 30.1 Definition of Ready для BCK-04 Review

- `BCK-01` переведён в `Review` (шаг 1 формальной последовательности,
  зафиксированной владельцем — на момент v0.3 ещё не выполнен);
- coverage matrix подтверждена актуальной;
- Security/Privacy owner — конкретный человек или команда, формально
  назначенный на роль accountable owner этого документа. Header уже
  фиксирует саму роль (`Security/Privacy owner`, per `BCK-02 §5`), но кто
  именно её исполняет — **Open**, не решено этим документом и не
  подразумевается никаким временным placeholder;
- Legal/Privacy owner назначен для `OD-11`/`BCK04-OD-06`.

### 30.2 Definition of Done Approved BCK-04

- все 22 канонических пункта `BCK-02 §14` покрыты или явно `not
  applicable` с причиной;
- reconciliation checklist `BCK-02 §15` пройден без конфликта с Accepted
  ADR;
- `OD-07` — **`Accepted`** (не только Proposed — `BCK-02` секция G1 требует
  именно Accepted для OD-07 и OD-10; только OD-09 и OD-11 допускают минимум
  `Proposed`); `OD-11` — минимум `Proposed`; `BCK04-OD-06` — минимум
  `Proposed` (условие `G1`);
- `BCK04-OD-01` и `BCK04-OD-09` (блокируют `Approved BCK-04` напрямую, §27)
  — **закрыты, не deferred**; перенос любого из них на потом требует
  сначала явно снять пометку "блокирует Approved BCK-04" в §27, что само по
  себе отдельное решение, а не техническая формальность;
- `BCK04-OD-02`, `03`, `04`, `05`, `07`, `08`, `10`, `11`, `12`, `13`
  (deferrable по §27) — имеют owner и либо закрыты, либо явно перенесены с
  датой пересмотра и сохранённым (более узким) blocking scope;
- reconciliation с `BCK-03` (idempotency fixture-conflict, §11.3 — требует
  BCK-03 v0.3 reconciliation до этого пункта) и `BCK-09` (Booking-специфичные
  правила) подтверждена соответствующими owners;
- runtime остаётся Absent.

### 30.3 Acceptance criteria

1. **BCK-04-AC-01:** документ не вводит authorization matrix, отличную от
   `BCK-01 §13.1`.
2. **BCK-04-AC-02:** документ использует 5-классную data classification из
   `BCK-01 §12`, не параллельный словарь.
3. **BCK-04-AC-03:** каждое заимствование из `FIREBASE_ARCHITECTURE.md`
   помечено `Proposed input`.
4. **BCK-04-AC-04:** numeric abuse/retention defaults из `ADR 0013`
   процитированы без изменения значения.
5. **BCK-04-AC-05:** `OD-11` не получает числового возраста в этой
   спецификации.
6. **BCK-04-AC-06:** `idempotencyKey`/`requestId` расхождение не
   представлено как решённое.
7. **BCK-04-AC-07:** anti-enumeration правило одинаково применяется к
   Booking, Page и verification-ресурсам.
8. **BCK-04-AC-08:** retention matrix покрывает Booking (D04, normative
   recommendation с числами, ожидающими Legal/Privacy/Product approval)
   отдельно от non-Booking классов; Sensitive и Operational (audit) не
   получают numeric default без Legal/Privacy approval.
9. **BCK-04-AC-09:** DSR orchestration не пишет напрямую в чужие record
   families.
10. **BCK-04-AC-10:** App Check нигде не описан как замена AuthZ/Rules/rate
    limits.
11. **BCK-04-AC-11:** secrets policy совпадает с `ENV_FLAVORS_SECRETS.md`
    без противоречий.
12. **BCK-04-AC-12:** ни один `.rules`/Function/backend файл не создан этой
    версией.
13. **BCK-04-AC-13:** каждый Open decision имеет owner и явный blocking
    scope.
14. **BCK-04-AC-14:** документ ссылается на точное имя файла и owner из
    `BCK-02 §5`, не переопределяет их.
15. **BCK-04-AC-15:** reconciliation с `BCK-03`/`BCK-09` не переписывает их
    содержимое, только фиксирует расхождения.
16. **BCK-04-AC-16:** §5 threat model явно помечает отсутствие полного
    STRIDE-анализа как `BCK04-OD-01`, не выдаёт частичную модель за полную.
17. **BCK-04-AC-17:** §12 Firestore Rules/IAM не содержит ни одного
    разрешённого direct client write без явной пометки "делегировано
    domain-spec, safe default — запрещено" (§12.3).
18. **BCK-04-AC-18:** §9–10 cross-page isolation правило (`Page A membership
    никогда не авторизует Page B`) присутствует явно, не подразумевается.
19. **BCK-04-AC-19:** §22 не выбирает конкретный регион/edition за `OD-07`;
    фиксирует только совместный `BCK-04`+`BCK-05` Approval boundary.
20. **BCK-04-AC-20:** §20 DSR orchestration не назначает SLA/формат экспорта
    самостоятельно — эти детали остаются `BCK04-OD-08`.
21. **BCK-04-AC-21:** §19 retention activation (когда именно generic/D04-like
    правило становится действующим для конкретного domain) явно требует
    domain-spec Approval, не наступает автоматически по факту существования
    этой таблицы.
22. **BCK-04-AC-22:** §26 incident response покрывает не только secret leak
    (существующий runbook), но и общий security incident, с явным `Open`
    там, где severity/notification timeline не определены.
23. **BCK-04-AC-23:** §25 rollback поведение для security-relevant флагов
    (App Check enforce, rate-limit threshold, age-gate) описано и
    аудируется само по себе, не только упомянуто.
24. **BCK-04-AC-24:** §18/§30 market gates (LV/EE/LT независимая активация
    OD-11) явно связаны с `G6`/`R2`, не описаны абстрактно.
25. **BCK-04-AC-25:** §3 порядок источников истины дословно совпадает с
    `BCK-01 §3`, без переупорядочивания.
26. **BCK-04-AC-26:** ни одна ссылка на раздел другого документа (`BCK-01`,
    `BCK-02`, `BCK-03`, `BCK-09`) не указывает на несуществующий номер
    раздела.
27. **BCK-04-AC-27:** ни один Open decision, блокирующий `Approved BCK-04`
    напрямую (`BCK04-OD-01`, `BCK04-OD-09`), не может быть переведён в
    `Deferred` без явного изменения его blocking scope (§27).
28. **BCK-04-AC-28:** header `Accountable owner` и текст DoR/DoD не
    противоречат друг другу по вопросу владения документом.
29. **BCK-04-AC-29:** ни один processing purpose не описан как основанный
    только на consent без проверки применимости остальных пяти оснований
    Art. 6(1) GDPR.
30. **BCK-04-AC-30:** DSR orchestration поддерживает все шесть data subject
    rights (access, rectification, erasure, restriction, portability,
    objection), не только export/delete.
31. **BCK-04-AC-31:** ни одна retention-запись не представлена как
    достаточное основание отказать в erasure request без явной ссылки на
    применимый Art. 17(3) exemption.
32. **BCK-04-AC-32:** incident response явно наследует Art. 33 (72-часовое
    окно) и Art. 34 (user notification при high risk), не изобретает
    отдельный от `RUN-06` путь эскалации.

### 30.4 Unimplemented list (честно)

На момент v0.3 отсутствует:

- любой `.rules`/`firestore.indexes.json`/Cloud Function файл;
- data inventory за пределами формата §6.1 (сам инвентарь — предмет
  domain-specs);
- threat model документ (`BCK04-OD-01`);
- DSR orchestration runtime (все шесть типов запроса, §20.1);
- incident response policy за пределами secret leak и за пределами
  зафиксированного здесь Art. 33/34 обязательства (severity/`BCK04-OD-09`);
- Legal/Privacy review по любому рынку;
- App Check emergency bypass policy;
- Accepted non-Booking retention (Sensitive/audit намеренно без default,
  §19.2);
- ROPA, DPIA gate, processor/subprocessor inventory, international-transfer
  policy (`BCK04-OD-10`…`OD-13`);
- reconciliation `BCK-01 §8` vs `§17` по Privacy Orchestration module
  (§28.0).

Runtime status остаётся **Absent** по всему документу.
