# Recharge Backend — Security & Privacy Specification

- ID: **BCK-04**
- Version: **0.4.10**
- Date: **2026-08-20**
- Spec status: **Draft — architecture review required**
- Runtime status: **Absent**
- Accountable owner: **Security/Privacy owner** (per `BCK-02 §5` registry row `BCK-04`)
- Interim review coordinator: **RechargeN / Product owner**
- Markets: **Latvia first; Estonia and Lithuania prepared but disabled independently**
- Parent architecture: [BCK-01 v0.4.17](RECHARGE_BACKEND_MASTER_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.21](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Reconciles with: [BCK-03 v0.3.3](BACKEND_API_CONTRACT_STANDARD.md) (Draft),
  [BCK-09 v1.1](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md) (Review)
- Preparatory input: [BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md](BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md) v0.3.10
- Threat-model evidence: [BCK04-OD01-TM-01](BACKEND_SECURITY_THREAT_MODEL.md) v0.1 (Draft; OD-01 Proposed)
- Incident-response evidence: [BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) v0.1 (Draft; OD-09 Proposed)
- Tabletop package: [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) v0.1 (ready; not executed)
- Hard dependencies (per `BCK-02 §5`): `BCK-01`, `ADR 0013`, `ADR 0015`, environment policy, `OD-07`, `OD-11`
- Canonical repository path: `docs/product/BACKEND_SECURITY_PRIVACY_SPEC.md`
- Runtime effect of this revision: **none**

---

## 0. Changelog

### v0.4.10 — 2026-08-20

- added a versioned incident tabletop package with scenario injects, mandatory
  decisions, evaluator key, honest blank execution record and 30 AC;
- the exercise is ready but not executed, so `BCK04-OD-09` stays Proposed and
  no owner/Legal/tabletop/runtime gate is closed;
- security/privacy semantics, 45 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.4.9 — 2026-08-20

- added one incident-response proposal preserving the existing SEV-1/2/3
  vocabulary while separating operational severity from GDPR risk/high-risk;
- advanced `BCK04-OD-09` from Open to Proposed; owner, qualified Legal/Privacy
  verdict and tabletop evidence remain absent;
- security/privacy semantics, 45 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.4.8 — 2026-08-20

- added the full asset/actor/trust-boundary STRIDE and privacy/abuse threat model
  `BCK04-OD01-TM-01` with 36 threats and 20 stable AC;
- advanced `BCK04-OD-01` from Open to Proposed because a concrete evidence
  package now exists; owner verdict and independent security review remain absent;
- security/privacy semantics, 45 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.4.7 — 2026-08-20

- recorded the combined D1 Security/Privacy and Legal/Privacy assignment;
- retained Pending verdicts and explicitly preserved the missing qualified
  Legal/Privacy evidence boundary;
- security/privacy semantics, 45 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.4.6 — 2026-08-20

- added explicit D1 Security/Privacy and Legal sign-off assignments through
  BCK-D1-SIG-01 without fabricating reviewer names or verdicts;
- clarified current DoR state and retained OD-11 as Open;
- synchronized the Mobile boundary with BCK-03 v0.3.2 and current D1 versions;
- security/privacy semantics, 45 stable AC, Draft status and runtime Absent are
  unchanged.

### v0.4.5 — 2026-08-20

- linked the evidence-backed OD-07 infrastructure review and OD-11 Legal brief;
- the brief records the Latvia Article 8 consent threshold only within its
  legal scope and does not invent a Recharge minimum account/feature age;
- OD-07 remains Proposed, OD-11 remains Open, specialist blockers and 45 AC are
  unchanged; runtime remains Absent.

### v0.4.4 — 2026-08-20

- D1-DEC-01/ECL03-D11 closes the Booking request/idempotency fixture conflict;
  BCK-03 v0.3 and BCK-09 v1.1 now share one split-key contract;
- ECL03-D04 wording is reconciled as Accepted product policy with separate
  Privacy/Legal production-activation validation, not an Open decision;
- PRE-03 is resolved and PRE-04 is narrowed to legal activation/rights evidence;
  remaining OD-07/11 and specialist blockers are unchanged;
- runtime remains Absent and no security/privacy implementation is authorized.

### v0.4.3 — 2026-08-20

- BCK-05 v0.1 and BCK-20 v0.1 are now present Draft inputs for OD-07,
  backup/operations and non-residency market-reference boundaries;
- parent/API/coordination/coverage traceability updated to
  v0.4.2/v0.2.4/v2.4.6/v0.3.3;
- blockers, security/privacy semantics, 45 AC, 14 Open Decisions and runtime
  effect remain unchanged.

### v0.4.2 — 2026-08-20

- BCK-01 Review prerequisite and interim review-coordinator assignment are
  recorded; coordination baseline updated to BCK-02 v2.4.5;
- BCK-03 and coverage traceability updated to v0.2.3/v0.3.2;
- Legal/Privacy specialist ownership, Open Decisions and remaining blockers
  are unchanged, so BCK-04 remains Draft;
- security/privacy semantics, 45 AC, 14 Open Decisions and runtime effect are
  unchanged.

### v0.4.1 — 2026-08-20

- documentation-only traceability updated to BCK-01 v0.4.1,
  BCK-02 v2.4.4, BCK-03 v0.2.2 and coverage matrix v0.3.1;
- security/privacy semantics, 45 AC, 14 Open Decisions, Draft/Absent status
  and runtime effect are unchanged.

### v0.4 — 2026-08-16

- документ синхронизирован с tracked baseline активного репозитория:
  `IDENTITY_PUBLISHER_SLICE_SPEC.md v1.3`, `BCK-01 v0.4`, `BCK-02 v2.4.3`;
- Privacy Orchestration признан собственным bounded module BCK-04; для него
  определены ownership, API/versioning, persistence, retry, degraded-state и
  event-delivery границы вместо ложных `not applicable`;
- внутреннее расхождение статуса ECL03-D04 и Booking idempotency описано
  явно, без нового гибридного словаря `normative recommendation`;
- retention разделён по record family и lifecycle, а не назначается целому
  data class; soft delete удалён из abuse/rate-limit matrix;
- DSR contract уточнён по GDPR Articles 15–22: eligibility, restriction,
  statutory timing, recipient propagation, automated decisions, requester
  verification;
- добавлен platform security minimum: privileged MFA/IAM, encrypted transport,
  KMS/key separation, supply-chain evidence, webhook replay и SSRF controls;
- incident policy согласована с существующим `incident.md`, Article 33/34 и
  будущими RUN-01/RUN-06;
- artifact map стал exact target plan, включая Privacy Orchestration и тесты;
- AC/OD/test matrices и coverage matrix v0.3 согласованы с этой ревизией.

### v0.3 — 2026-08-16

- добавлены 22-section reconciliation, расширенный GDPR/DSR блок, incident
  path, ROPA/DPIA/processor/transfer decisions и Privacy Orchestration gap;
- runtime effect отсутствовал.

### v0.1–v0.2 — 2026-08-16

- создан единый Draft security/privacy standard;
- принята пяти-классная модель BCK-01, direct writes переведены в deny-by-
  default, analytics классифицируется по содержимому, а не по имени записи;
- runtime effect отсутствовал.

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
  расширять по структуре Booking input `D04` (registry помечает decision
  Accepted, но сам §6 оставляет точные числа Open до Legal/Privacy/Product
  approval — см. §19.1), а не
  изобретать заново с нуля;
- честный список того, что реально Accepted (`ADR 0013/0015/0019`, `D05`),
  где сам источник содержит status conflict (`D04`), что является Proposed-input
  (`FIREBASE_ARCHITECTURE.md`), и что Open (§27), без смешивания этих
  статусов и уровней доверия.

## 3. Источники истины и разрешение конфликтов

Приоритет — дословно порядок `BCK-01 §3`:

1. Accepted ADR побеждает при архитектурном конфликте (`ADR 0013`,
   `ADR 0015`, `ADR 0016` bounded, `ADR 0017` bounded, `ADR 0019`);
2. Approved spec применимого domain/runtime slice побеждает внутри своего
  bounded scope (`IDENTITY_PUBLISHER_SLICE_SPEC.md` v1.3, Approved bounded);
3. [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md) и
   cross-cutting policies владеют module/layer boundaries;
4. [LAUNCH_STATUS](../architecture/LAUNCH_STATUS.md) владеет фактическим
   implementation/runtime status, но не переписывает target architecture;
5. `BCK-02` владеет registry, accountable owners, dependencies, waves,
   OD/risks и gates;
6. `BCK-01` владеет shared backend target, layers, module boundaries и
   cross-domain invariants, которых нет в более высоком источнике;
7. Product vision и Draft/Review proposals не переопределяют пункты выше.

После Approval этот BCK-04 детализирует security/privacy только в собственном
scope и не повышает статус процитированного источника. В частности,
`FIREBASE_ARCHITECTURE.md v2.2` остаётся **Proposed input**; конфликт с peer
Draft/Review spec регистрируется и reconciled owners, а не решается порядком
упоминания.

Обязательные anchors:

| Область | Источник | Обязательство BCK-04 |
|---|---|---|
| Backend architecture/data classes | [`BCK-01`](RECHARGE_BACKEND_MASTER_SPEC.md) §12–14, §21 | Не вводить параллельную классификацию или authorization matrix |
| Registry/gates/OD governance | [`BCK-02`](RECHARGE_BACKEND_DELIVERY_MAP.md) §5, §14–18 | Соблюсти 22-пунктовую структуру §14 и reconciliation checklist §15 |
| Domain policy baseline | [`ADR 0013`](../adr/0013-domain-policy-baseline.md) | Использовать существующие numeric defaults (30 дней только для soft-deleted recoverable entity, auto-hide ≥5/24h, 3 сессии, 100 publish/day, EU opt-in/non-EU opt-out), не расширять их scope и не переопределять без нового ADR |
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
явная сверка текущей ревизии:

| № | Пункт `BCK-02 §14` | Статус в BCK-04 | Где |
|---|---|---|---|
| 1 | ID/version/status/owner | Покрыт | Header |
| 2 | Parent ADR/specs, anchors, conflict priority | Покрыт | §3, §3.1 |
| 3 | Product outcome и measurable non-goals | Покрыт | §2; §4.2 содержит проверяемые exclusions |
| 4 | Included/excluded scope | Покрыт | §4 |
| 5 | Aggregate, record writer и consumer ownership | Покрыт для собственного module | Privacy Orchestration владеет `PrivacyRequest`, `PrivacyDomainTask`, `PrivacyCompletionEvidence`; writers/consumers — §20.2 и §28 |
| 6 | Data classification и public/protected/private projections | Покрыт | §7 |
| 7 | Commands, queries, events и typed error envelope | Покрыт на semantic level | Privacy commands/queries/events — §20.2; envelope/error vocabulary наследуют `BCK-03` |
| 8 | Schema/API/event versions, evolution, minimum supported client | Покрыт границей | Privacy wire/event `v1`, additive evolution и minimum-client policy наследуют `BCK-03 §25–27`; artifact conditional до `API-DEC-05`, §28 |
| 9 | Authorization/capability matrix и revocation behavior | Покрыт | §9 |
| 10 | Persistence, indexes, source/projection, transaction boundaries | Покрыт | Privacy Orchestration source records и domain-owned handlers разделены; §20.2, §28 |
| 11 | IDs, references, UTC/IANA, reference-data semantics | Покрыт наследованием | ULID/UTC/IANA/market semantics — `BCK-01 §11`; Privacy records не создают альтернативные primitives, §20.2 |
| 12 | Idempotency, concurrency, retries, partial-failure behavior | Покрыт | DSR request dedupe, task retry, monotonic completion и typed partial outcome — §20.2; common semantics — `BCK-03 §16–17, §21` |
| 13 | Offline/cache/freshness, honest degraded states | Покрыт | Privacy command требует server authority; offline request не считается submitted; status имеет revision/freshness и explicit partial/unavailable, §20.2 |
| 14 | Migration, local-to-cloud import, backward/forward compatibility | Покрыт (security angle) | §24 |
| 15 | Outbox/event delivery, replay/deduplication | Покрыт на semantic level | Domain-task dispatch/completion идемпотентны; event envelope зависит от Accepted OD-09, §20.2 |
| 16 | Privacy, consent, retention, export/deletion, Legal review points | Покрыт | §17–20 |
| 17 | Abuse, rate limiting, App Check limitations, fraud controls | Покрыт | §14, §16 |
| 18 | Operational logs/SLO/alerts, product analytics separation, cost budget | Покрыт границей | Logging/redaction — §21; SLO/alerts/cost делегированы `BCK-05`; product analytics — `BCK-21`; security/privacy telemetry не становится product analytics |
| 19 | Server flags, rollout, rollback, emergency-disable | Покрыт | §25 |
| 20 | Exact implementation file map | Покрыт как target plan | §28; создание файлов требует отдельный Approved executable slice |
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
- `OD-11` minors/age Open-decision constraints and Legal review brief;
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

Non-goals измеримы: эта ревизия не создаёт `apps/backend`, Firebase/GCP
resources, credentials, deploy configuration, mobile adapters или runtime
schema; `git diff` документационного slice не должен содержать их. Она также
не переводит ни один Open decision в Accepted без отдельной owner record.

## 5. Threat model и trust boundaries

Полный proposal оформлен отдельно в
[BCK04-OD01-TM-01](BACKEND_SECURITY_THREAT_MODEL.md). Ниже сохранена его
обязательная trust-boundary основа, согласованная с Accepted ADR, BCK-01 и
явно отмеченным Proposed Firebase input. Наличие evidence переводит
`BCK04-OD-01` только в Proposed, не в Accepted.

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

**Proposed:** полный per-asset threat model с explicit attacker capabilities,
36 threat records, control ownership, evidence gates and residual risks —
[BCK04-OD01-TM-01](BACKEND_SECURITY_THREAT_MODEL.md). Owner verdict и
independent security review отсутствуют, поэтому `BCK04-OD-01` не Accepted.

## 6. Backend data inventory

`BCK-01 §12` требует, чтобы **каждый BCK-spec** классифицировал свои
record/field до schema approval; наличие Firestore collection не является
data inventory само по себе. BCK-04 не владеет чужими record families — он
задаёт формат инвентаря, который каждый domain-spec обязан заполнить.

### 6.1 Формат записи инвентаря (обязателен для каждого domain BCK-spec)

```text
recordFamily
owningSpec (BCK-XX)
authoritativeWriter
consumers
storage (Firestore collection | Storage path | derived index)
dataClass (см. §7)
dataSubjectCategories
purpose
legalBasis
accessPrincipals
recipients
processorSubprocessorRefs
internationalTransferRef
retentionClass (см. §19)
retentionTrigger
article17Exemption (none | exact legal reference)
exportable (yes/no)
deletable (yes/no, mechanism)
rectifiable (yes/no, mechanism)
restrictable (yes/no, mechanism)
portable (yes/no, eligibility)
backupTreatment
storageRegionRef
logExclusion (yes/no)
ropaEntryRef
dpiaRef (none | required | completed reference)
```

Это technical inventory и одновременно вход в ROPA, но не замена подписанного
legal register. Поля `ropaEntryRef`, processor/recipient/transfer и DPIA
заполняются до production processing; отсутствие применимого значения
фиксируется как `none` с owner evidence, а не пустым `TBD`.

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
operational/audit/analytics`). BCK-04 **не вводит дополнительные schema-level
классы**, а выражает эти понятия через уже принятые пять:

- `private` — уточнение `Protected` (actor-owned, не shared page/team scope);
  не отдельный класс, а атрибут `scopeKind: owner-only | team | page`
  внутри `Protected`;
- `audit` — поднабор `Operational` с обязательным `immutable: true` и
  собственным retention (`§19`); `audit` — purpose/record-kind метка, не
  class сама по себе, и не задаёт class автоматически;
- `analytics` — **purpose/record-kind метка, не class**. Её нельзя
  автоматически привязывать к `Derived`: raw или pseudonymous
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
- security-sensitive user actions требуют risk-based recent re-auth/step-up;
  human access к production admin/support/security surfaces требует отдельной
  privileged identity и MFA, а не только обычной consumer session;
- service identity (Functions/Scheduler) — отдельная категория principal,
  не пользовательская сессия; least-privilege IAM per task (`BCK-01 §13.1`
  row `Service identity`).

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
  API-границе, не опционально для security-sensitive команд;
- provider webhook/redirect callback считается untrusted input: signature или
  эквивалентная provider authenticity, timestamp/freshness, replay/dedupe,
  content-type/size и schema validation обязательны до domain command;
- outbound URL fetch никогда не принимает произвольный client URL: provider
  allowlist, redirect/IP/metadata-network guard, timeout и response-size bound
  обязательны для защиты от SSRF.

### 11.2 Anti-enumeration Matrix

| Ресурс | Правило | Источник |
|---|---|---|
| Чужой private Booking/Scenario | `not_found`, не `permission_denied` | `BCK-03 §14` |
| Чужая Page (не участник) | `not_found` для несуществующей и недоступной одинаково | `BCK-01 §13.1` (revocation "не раскрывая... существует ли") |
| Верификационные документы других пользователей | Недоступны через API вообще, не через error-differentiation | `IDENTITY_PUBLISHER_SLICE_SPEC.md §13` |
| Suspended/revoked access к ранее доступному ресурсу | Typed outcome без утечки причины конкурентам/атакующему | `BCK-01 §13.1` |

Точный per-resource mapping (какие ресурсы enumeration-sensitive) —
делегируется owning domain BCK-spec; здесь фиксируется только механизм.

### 11.3 Booking idempotency reconciliation

[BCK-D1-DEC-01](BACKEND_PLATFORM_D1_DECISION_PACKAGE.md) and ECL03-D11 resolve
the former Review-contract-vs-fixture contradiction. Booking v1 now has one
contract across BCK-03 v0.3.3, BCK-09 v1.1, ECL-03 v1.2 and ECL-03C v1.1:

- `requestId` correlates one request attempt;
- `idempotencyKey` identifies one logical mutation across retries;
- equality is valid but optional;
- effective scope is resolved actor/service identity + command type +
  idempotency key;
- same key/hash replays the stored result and same key/different hash fails
  without mutation.

Committed schema/fixtures remain unchanged and no data migration exists because
runtime is Absent. BCK-04 relies on the accepted semantic rule but still does
not define canonical hashing, persistence or retention; those remain owned by
BCK-03, BCK-05 and the Booking domain.

## 12. Firestore Rules и IAM (Firestore Rules/IAM Matrix)

### 12.1 Принципы (нормативно, `BCK-01 §13` п.4, §14)

- Firestore/Storage Rules — default-deny;
- authoritative mutation (submission, publication, moderation, capability
  changes, page membership, counters, audit, catalog projections) —
  server-only, никогда прямой client write;
- direct cross-module Firestore writes запрещены — aggregate transaction
  принадлежит одному module (`BCK-01 §14`);
- least-privilege service identities для privileged operations;
- dev/stage/prod IAM разделён; shared human/service principal между
  environments запрещён;
- workload identity/keyless service authentication предпочтительнее
  долгоживущего service-account key; исключение имеет owner, expiry и audit;
- production human access индивидуален, MFA-protected, time-bounded where
  practical и audited; orphan/shared accounts запрещены, а access review
  выполняется до каждого production cohort и затем по cadence BCK-05.

### 12.2 Detail-уровень — Proposed input, не settled

`FIREBASE_ARCHITECTURE.md §11` предлагает конкретные rule techniques (field
diff allowlists, exact membership lookup within bounded quota, deny broad
collection reads без provable rule) и required emulator test matrix
(unauthenticated denial, provider-authenticated с разными verification
состояниями, cross-page isolation, batch/transaction lookup limits). Это
**Proposed input**, полезное для будущего executable slice, но не Accepted
decision этой версии.

### 12.3 Matrix — direct client writes (safe default, не Accepted allowlist)

`BCK-03 AC-23` требует: "every mutation is a registered versioned command."
Любая прямая запись клиента в Firestore, минуя command/API-слой BCK-03, —
mutation без registered command и конфликтует с этим требованием. Поэтому
safe default — **запрет**; `FIREBASE_ARCHITECTURE.md §11.1` не переносится
как готовое решение:

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

### 12.4 Platform security control baseline

Это Draft cross-cutting minimum; BCK-05 выбирает exact cloud controls/tools и
доказывает их в CI/stage/production:

- весь внешний и межсервисный transport использует authenticated encrypted
  channel; plaintext endpoint/credential transport запрещён;
- provider-managed encryption at rest проверяется для каждого resource;
  необходимость field/object-level encryption для Sensitive family решается
  по §6 inventory и threat model, а не предполагается по названию класса;
- encryption/signing keys хранятся в managed KMS/secret store, разделены по
  environment/purpose, доступны least-privilege identities, имеют rotation,
  revocation и access audit; собственная криптография запрещена;
- build/release gate включает secret scan, static analysis, dependency and
  known-vulnerability scan, lockfile integrity и generated-artifact provenance;
  исключение имеет owner, severity rationale, expiry и compensating control;
- production release получает component/dependency inventory (SBOM или
  эквивалент), чтобы уязвимую версию можно было найти и отозвать;
- vulnerability intake/triage, patch target, emergency disable и verified
  redeploy принадлежат BCK-05/RUN-06; exact SLA устанавливается ими до G5;
- dynamic/API abuse tests, webhook replay/forgery и SSRF negative tests входят
  в pre-production evidence для затронутых surfaces;
- control selection документирует risk-proportionate privacy/security by
  design and default, resilience/restore и регулярную проверку эффективности
  мер (GDPR Articles 25 и 32), а не сводится к checklist наличия сервисов.

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

Источник: `BCK-01 §13` п.3, [ECL-03 Decision Package §4 / D02](EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md)
для Booking-scoped `monitor → enforce` proposal и
`FIREBASE_ARCHITECTURE.md §15.2/§19.2` как Proposed detail.

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
Encryption/signing keys следуют также §12.4 и не считаются обычными config
values.

## 16. Abuse, fraud и rate limiting (Abuse/Rate Limit Matrix)

### 16.1 Numeric defaults — Accepted, не Open

Часть чисел уже Accepted через `ADR 0013`, поэтому не является Open:

| Параметр | Значение | Источник |
|---|---:|---|
| Auto-hide threshold (reports) | ≥5 уникальных reporters / 24 часа | `ADR 0013` п.4 |
| Report uniqueness | По одному на пользователя на объект | `ADR 0013` п.4 |
| Creator publish velocity | 100 публикаций/день (baseline) | `ADR 0013` п.20 |
| Active sessions per account | До 3 | `ADR 0013` п.6 |

### 16.2 Принципы за пределами уже заданных чисел

- rate limits учитывают actor, device/app signal, command risk и global
  abuse protection; **точные пороги за пределами таблицы выше** принадлежат
  domain/`BCK-05` (`BCK-01 §13` п.8 — явно делегирует остальное);
- App Check failure не даёт rate-limit bypass (§14);
- idempotency abuse — см. §11.3, зависит от закрытия BCK-03 reconciliation;
- sanctions handoff принадлежит `BCK-22` (сейчас Planned/Absent); BCK-04
  фиксирует только typed `rate_limited`/`unavailable` outcome boundary
  (`BCK-03 §14`, §32).

**Open:** device/IP-level fingerprinting policy, scraping detection,
credential-stuffing specific control — ни один источник их не определяет
(`BCK04-OD-05`).

## 17. Privacy processing (Consent and Legal Review Matrix)

Источник: `ADR 0013` п.19, `IDENTITY_PUBLISHER_SLICE_SPEC.md §13`,
[GDPR Articles 6–7](https://eur-lex.europa.eu/eli/reg/2016/679/oj) (LV/EE/LT
— все три EU/EEA рынка, GDPR применяется напрямую).

### 17.1 Legal basis — не сводится к consent

GDPR Art. 6(1) перечисляет шесть lawful bases —
consent (a), contract necessity (b), legal obligation (c), vital interests
(d), public task (e), legitimate interests (f). Recharge, как большинство
product-платформ, скорее всего опирается на **разные** основания для разных
purposes (например, contract necessity для Booking fulfilment, legitimate
interests для fraud prevention после documented balancing test, consent —
только там, где действительно нужен opt-in, например marketing). BCK-04 не
назначает конкретное основание
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
  должен быть так же прост, как дача consent, и независим от erasure
  request). Withdrawal consent для конкретной processing purpose
  (например, marketing) не подразумевает автоматическое удаление аккаунта
  или всех данных — это разные запросы с разными последствиями.
- BCK-04 `Sensitive` — технический класс и **не равен автоматически** GDPR
  special categories Article 9. Если фактические поля содержат Art. 9 data,
  одного Art. 6 basis недостаточно: owning domain фиксирует отдельное Art. 9
  condition, minimization/DPIA gate и Legal approval до сбора; Article 10 data
  обрабатываются только под отдельной подтверждённой правовой границей;
- analytics SDK/device identifiers, push/marketing и device-storage access
  проходят отдельный per-market review применимых ePrivacy/direct-marketing
  rules; GDPR lawful basis сам по себе не закрывает эту проверку.

### 17.2 Transparency и automated-decision boundary

- privacy notice покрывает Articles 12–14: controller/contact, purposes,
  lawful bases, recipients, transfers, retention, rights и complaint path;
- изменение purpose/legal basis/recipient требует versioned notice review до
  активации, а не только обновления текста после релиза;
- solely automated decision, создающее legal или similarly significant
  effect, требует Article 22 assessment, применимого основания, safeguards,
  human-intervention/contest path и отдельного `BCK04-OD-14`;
- обычный ranking/recommendation не объявляется Article 22 processing
  автоматически, но owning domain обязан доказать boundary до significant
  eligibility, sanction, verification или access decision.

### 17.3 Open decisions за пределами уже принятых

**Open:** exact legal basis формулировка per processing purpose, consent
versioning schema, Article 9/10 и применимые ePrivacy/direct-marketing gates —
`BCK04-OD-06`, требует Legal/Privacy owner, blocking
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
- `BCK04-OD-14` — automated decision/profiling policy (Art. 22):
  applicability test, human review, explanation/contest и child safeguards.

Все пять — owner Security/Privacy + Legal, blocking для production
personal data обработки, не для Approved BCK-04 самого по себе (design
readiness не требует, чтобы ROPA/DPIA уже существовали, но требует, чтобы
эти gates были явно запланированы).

## 18. OD-11 — minors/age eligibility

`OD-11` уже зарегистрирован (`BCK-02 §16`, строка реестра `OD-11`) как
`Open`, owner
Security/Privacy, блокирует R2 production account creation, Find People,
age-restricted publication/discovery, applicable Booking paths, G6. BCK-04
не создаёт это решение с нуля — добавляет candidate constraints как материал
для решения владельца. Юридические источники, purpose-by-purpose вопросы и
fail-closed review contract собраны в
[BCK-D1-OD11-LGL-01](BACKEND_OD_11_AGE_POLICY_LEGAL_BRIEF.md).

### 18.1 Candidate constraints (decision remains Open)

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

`Open — no Recharge age policy selected`. Candidate constraints and the Legal
brief do not by themselves satisfy the `Open -> Proposed` transition. It
requires a qualified Legal/Privacy owner, one concrete per-market proposal and
the evidence named in the brief. Реализация (age-gate UI, guardian flow,
verification backend) не разрешается этой спецификацией — действует только
fail-closed поведение до Accepted.

## 19. Retention matrix (Retention/Deletion Matrix)

### 19.1 Booking-scoped ECL03-D04 — reconciled status and activation gate

[ECL-03 Decision Package](EVENT_CLASSIFICATION_ECL_03_DECISION_PACKAGE.md)
v1.2 однозначно фиксирует `ECL03-D04` как **Accepted product-policy baseline**.
Это не Legal approval и не разрешение обрабатывать production personal data:
Privacy/Legal validation exact values, backup propagation and exceptional holds
остаётся отдельным activation gate. Таблица ниже нормативна для продукта, но
неактивна до прохождения этого gate:

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

Data class определяет safeguards, но сам по себе не назначает срок хранения.
Retention задаётся для конкретной record family по purpose, legal basis,
lifecycle trigger и deletion/anonymization action. `ADR 0013` п.3 задаёт
30-дневный default только для soft-deleted recoverable entity lifecycle, а не
для каждого Public/Protected/Sensitive record.

| Data class (§7) | Retention default здесь | Кто решает |
|---|---|---|
| Public | **Нет class-wide default**; 30 дней применяются только к soft-deleted recoverable entity по ADR 0013 | Owning domain |
| Protected | **Нет числового default** | Domain-spec обязателен, PII-heavy families требуют Legal/Privacy review до production |
| Sensitive | **Нет default, no fallback** | Каждый domain-spec обязан предложить собственную Accepted таблицу с Legal/Privacy approval до production; молчание не означает "30 дней" |
| Operational (non-audit) | Может ориентироваться на D04 паттерн (idempotency/log ~30 дней) как **Proposed**, не Accepted generic rule | Domain-spec подтверждает явно |
| Operational (audit) | **Нет default** | Legal hold requirements различаются по типу audit — Security/Privacy owner решает per record family, не по аналогии с Booking |
| Derived | **Нет class-wide default**; срок определяется rebuild/freshness purpose, source deletion propagation и PII content | Owning domain |

**Draft cross-domain rules BCK-04** (основаны на D04, но принимаются здесь
отдельно и требуют Approval BCK-04):

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

Источник: `BCK-01 §8–9` (Privacy Orchestration module, owner BCK-04),
`BCK-01 §13` п.10, `IDENTITY_PUBLISHER_SLICE_SPEC.md §13` и
[GDPR Articles 12–22](https://eur-lex.europa.eu/eli/reg/2016/679/oj).

### 20.1 Поддерживаемые request families и eligibility

Ниже перечислены backend request families, а не утверждение, что ими
исчерпываются все права Chapter III. Transparency duties Articles 12–14
покрыты §17.2; recipient notification Article 19 и automated decisions
Article 22 являются отдельными обязательствами.

| Право | Request type | Eligibility/обязательная семантика |
|---|---|---|
| Access, Art. 15 | `access` | Состав personal data, purposes, recipients, retention и rights; учитывает права других лиц и применимые ограничения |
| Rectification, Art. 16 | `rectification` | Domain handler исправляет source record и инициирует projection/recipient propagation; immutable audit не переписывается, а получает correction link |
| Erasure, Art. 17 | `deletion` | Выполняется по record family; исключение возможно только по documented Art. 17(3) basis, §20.3 |
| Restriction, Art. 18 | `restriction` | Scoped state на применимые subject records/purposes; storage остаётся, иное processing разрешено только по допустимому основанию; пользователь уведомляется до снятия |
| Portability, Art. 20 | `portability` | Только data provided by subject, automated processing и consent/contract basis; structured/common/machine-readable format, права других лиц защищены |
| Objection, Art. 21 | `objection` | Для Art. 6(1)(e)/(f) — assessment overriding grounds; для direct marketing processing прекращается без balancing |

Statutory timing — не Open: по Article 12(3) ответ даётся без неоправданной
задержки и не позднее одного месяца; при сложности/множественности запросов
возможны ещё два месяца, но requester уведомляется о продлении и причинах в
первый месяц. Отказ/бездействие также сообщается не позднее одного месяца с
причинами и complaint/judicial-remedy path (Art. 12(4)). Дополнительная
проверка identity допустима при разумных сомнениях (Art. 12(6)); она не должна
использоваться как систематическая задержка. `BCK04-OD-08` задаёт более
строгий internal SLA, формат и channel, но не может ослабить эти внешние
пределы.

### 20.2 Privacy Orchestration contract

```text
verified request
  -> SubmitPrivacyRequest(requestId, requestType, scope, market)
    -> PrivacyRequest (authoritative coordinator source)
      -> PrivacyDomainTask per owning BCK module
        -> domain command executes only domain-owned records
        -> versioned completion/failure response or accepted OD-09 event
      -> PrivacyCompletionEvidence aggregates privacy-safe outcomes
  -> GetPrivacyRequestStatus(requestId) returns revisioned user-safe status
```

Ownership:

| Record | Authoritative writer | Consumers |
|---|---|---|
| `PrivacyRequest` | Privacy Orchestration | Requester projection, Privacy/Admin operations |
| `PrivacyDomainTask` | Privacy Orchestration | Exact owning domain handler |
| Domain completion evidence | Owning domain | Privacy Orchestration only |
| `PrivacyCompletionEvidence` | Privacy Orchestration | Requester projection, audited support |

Invariants:

- requester identity проверяется server-side; authenticated session может
  требовать recent re-auth/step-up, а manual support channel — эквивалентную
  documented identity verification; client-declared actor не принимается;
- existence/status другого пользователя не раскрывается; DSR endpoints
  наследуют anti-enumeration §11.2 и отдельные abuse limits;
- IDs — ULID, timestamps — backend UTC, market — versioned stable value по
  `BCK-01 §11`; local/offline intent не считается submitted request;
- повтор с тем же request ID и тем же canonical payload возвращает тот же
  result/status; payload mismatch даёт typed `idempotency_conflict`;
- status transitions monotonic:
  `received -> verificationRequired | accepted -> dispatching ->
  partiallyCompleted | completed | rejected`; user cancellation — отдельный
  `cancelled` outcome до irreversible execution, не failure/success;
- domain handlers исполняют только собственные record families; BCK-04 не
  пишет напрямую в чужие collections;
- timeout/retry дают revisioned `partiallyCompleted` или `unavailable`,
  owner escalation и safe resume, а не тихий success;
- cross-domain event delivery использует Accepted OD-09 contract; до этого
  применяется synchronous/queued adapter внутри bounded executable slice,
  без изобретения параллельного envelope;
- rectification/erasure/restriction propagates каждому известному recipient
  по Article 19, кроме documented impossible/disproportionate-effort case;
  requester может получить recipient information по применимому запросу;
- completion evidence — Operational/audit, без raw exported content.

### 20.3 Erasure (Art. 17) не абсолютно — но и retention не абсолютен

GDPR Art. 17(3) допускает исключения, когда processing необходим для
compliance with legal obligation, legal claims, public interest archiving
и других перечисленных случаях. Это applicable exemption, а не свойство
внутренней retention policy: запись "храним 180 дней" сама по себе не
является legal ground отказать в erasure.

Каждая retention-запись в §19, которая может пережить
DSR erasure request, обязана явно указывать применимый Art. 17(3)
exemption как часть своей domain-spec записи — не полагаться на факт
существования retention policy самой по себе.

**Open:** конкретный внутренний SLA в пределах Article 12, exact export/
portability format, UI/API contract, step-up policy и recipient-propagation evidence —
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

Evidence review is centralized in
[BCK-D1-OD07-EV-01](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md). It verifies
per-resource location semantics and enumerates measurements/sign-offs still
required; it does not accept OD-07 or authorize provisioning.

`OD-07` — Proposed, owner Platform (совместно `BCK-04`/`BCK-05` по `BCK-01
§21`), блокирует R1 provisioning. `FIREBASE_ARCHITECTURE.md §4.3`
предлагает (**Proposed, не Accepted**) `eur3`/`europe-west1`, но сам текст
источника прямо требует "a recorded data-residency, cost and latency review"
и запрещает "Creating the production database before that approval".
ECL-03 Decision Package D02 также содержит Booking-scoped location proposal;
он не закрывает cross-domain OD-07 и не разрешает irreversible provisioning.

BCK-04 фиксирует только boundary-требования:

- LV/EE/LT residency — единая политика для всех трёх, если Legal review не
  потребует разделения;
- итоговое решение о регионе — совместное Approval `BCK-04`+`BCK-05`, не
  односторонне ни одним из них;
- до Accepted `OD-07` и прохождения G1 — physical provisioning запрещён
  Approved coordination gate `BCK-02 §18`; отдельного ADR, уже выбравшего
  global Firebase location, нет.

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
Platform owner; статус Planned/Absent).

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

Источники: действующие [`incident.md`](../runbooks/incident.md) и
[`secret-leak-response.md`](../runbooks/secret-leak-response.md), а также
будущие RUN-01/RUN-06 из `BCK-02 §6`. `incident.md` задаёт SEV-1/2/3,
первые 15 минут, communication cadence и postmortem; secret runbook добавляет
credential containment. RUN-06 связывает их с personal-data breach triage,
Article 33 assessment и Legal/DPO escalation.

### 26.1 Personal-data breach — Article 33/34 GDPR (обязательное наследование)

Поскольку `RUN-06` (владеет Security owner, зависит от `BCK-04`) уже
кодирует это требование, BCK-04 обязан явно зафиксировать источник, а не
изобретать собственный incident timeline без ссылки на него:

- **Art. 33** — при personal data breach с риском для прав/свобод физлиц,
  controller уведомляет supervisory authority (для LV — Data State
  Inspectorate) **без неоправданной задержки, и где возможно, не позднее
  72 часов** после того, как breach стал known; если позже 72 часов —
  обязательно reasoned delay explanation; processor сообщает controller о
  breach без неоправданной задержки после обнаружения;
- **Art. 34** — при **high risk** для прав/свобод физлиц, controller
  дополнительно уведомляет **самих затронутых пользователей** without
  undue delay, в понятной, простой форме;
- breach record сохраняет факты, effects и remediation, достаточные для
  доказательства Art. 33 compliance; применимое authority notification
  содержит nature/categories/approximate scale, DPO/contact, likely
  consequences и taken/proposed measures;
- documented risk assessment обязателен для решения "нужно ли Art. 33/34
  уведомление" — не автоматическое решение по severity;
- Legal/DPO escalation — часть пути, не опциональный шаг.

### 26.2 Общая модель (за пределами GDPR-специфичного breach)

Общая security-модель расширяет существующий generic incident runbook:

```text
Detect -> Contain -> Assess scope/data classes affected (§7)
  -> Assess Art. 33/34 applicability (personal-data breach? risk level?)
  -> Notify accountable owner + affected domain owners + Legal/DPO if applicable
  -> [If applicable] Notify supervisory authority within 72h; notify users if high risk
  -> Remediate (revoke/patch/rotate/disable flag per §25)
  -> Audit trail (§21) -> Post-incident report -> Remediation tasks
```

- operational severity сохраняет `SEV-1/2/3` и cadence из `incident.md`;
- [BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) proposes
  incident-type mapping, roles, evidence, response targets and a separate
  `assessmentPending/unlikelyRisk/likelyRisk/highRisk` privacy vocabulary;
- [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) is the
  first repeatable exercise package; its execution/result record is blank;
- privacy-risk classification не выводится из SEV автоматически; exact
  `likelyRisk/highRisk` conclusion остаётся qualified Legal/Privacy decision;
- security tabletop/incident drill — упомянут в исходном запросе как
  обязательная проверка (§29); `RUN-01`/`RUN-06` уже требуют quarterly
  tabletop — periodичность для non-secret security incident наследует тот
  же квартальный ритм, если Security/Privacy owner не предложит иное.

**Proposed:** mapping security incident type → SEV, privacy assessment factors,
roles, evidence and response targets are in
[BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md). Owner and
qualified Legal/Privacy verdicts plus executed/passed tabletop evidence remain
absent, so
`BCK04-OD-09` is not Accepted. Сам факт
обязательности Art. 33/34
пути и 72-часового окна — **не Open**, это прямое следствие GDPR
применимости к LV/EE/LT и уже частично унаследованного `RUN-06`.

## 27. Open decisions

| ID | Вопрос | Owner | Блокирует | Deferrable без изменения scope? |
|---|---|---|---|:---:|
| `OD-07` (внешний, `BCK-02 §16`) | Firebase topology/edition/regions | Platform (`BCK-04`+`BCK-05`) | R1 provisioning, §22 | Нет (R1) |
| `OD-11` (внешний, `BCK-02 §16`) | Region-versioned minors/age policy | Security/Privacy | R2 account creation, Find People, age-restricted paths, applicable Booking, G6, §18 | Нет (R2/G6) |
| `BCK04-OD-01` | **Proposed:** полный threat model по каждому asset/trust boundary; owner verdict/independent review pending | Security/Privacy | **Approved BCK-04 напрямую** | **Нет** |
| `BCK04-OD-02` | Полный подписанный data inventory по каждому domain | Каждый domain owner + Security/Privacy | Production personal data для этого domain | Да, per-domain, до production |
| `BCK04-OD-03` | Session/token TTL, refresh cadence, deletion provider-revocation detail | Identity owner (`BCK-06`) | Executable Auth slice | Да, до executable slice |
| `BCK04-OD-04` | App Check recovery/emergency bypass policy | Platform Operations (`BCK-05`) | App Check enforce rollout | Да, до enforce rollout |
| `BCK04-OD-05` | Device/IP fingerprinting, scraping, credential-stuffing detail | Security/Privacy | Abuse control activation | Да, до activation |
| `BCK04-OD-06` | Exact legal basis per purpose, consent versioning, Article 9/10 and applicable ePrivacy/direct-marketing gates | Legal/Privacy | G1 (наравне с OD-07/OD-10) | Нет (G1) |
| `BCK04-OD-07` | Non-Booking retention Accepted values, backup RTO/RPO/encryption | Security/Privacy + `BCK-05` | Production personal data backup | Да, до production backup |
| `BCK04-OD-08` | Rights-request SLA/API/formats, requester verification/step-up, Article 19 propagation evidence | Security/Privacy + Identity + `BCK-18` | Production rights-request processing | Да, до production DSR |
| `BCK04-OD-09` | **Proposed:** incident type → SEV-1/2/3, separate privacy-risk path, roles/cadence/evidence and ready-but-unexecuted tabletop package; verdict/execution pending | Security/Privacy + qualified Legal/Privacy | **Approved BCK-04 напрямую** | **Нет** |
| `BCK04-OD-10` | ROPA / Records of Processing Activities (Art. 30) | Security/Privacy + Legal | Production personal data processing | Да, до production |
| `BCK04-OD-11` | DPIA gate — какие features требуют Data Protection Impact Assessment (Art. 35) | Security/Privacy + Legal | Активация high-risk features (age-verification, large-scale profiling) | Да, до соответствующей feature |
| `BCK04-OD-12` | Processor/subprocessor inventory + DPA (Art. 28) | Security/Privacy + Legal | Production использование любого third-party processor | Да, до production processor onboarding |
| `BCK04-OD-13` | International-transfer policy — adequacy/SCCs (Art. 44+) | Security/Privacy + Legal | Production данных вне EU/EEA processor | Да, до такого transfer; пересекается с OD-07, не идентичен |
| `BCK04-OD-14` | Automated decisions/profiling Article 22 applicability, safeguards, human review/contest | Security/Privacy + Legal + owning domain | Significant automated decision activation | Да, до соответствующей feature |

Формат соответствует `BCK-02 §16`: `Open -> Proposed -> Accepted | Deferred
| Superseded`; `Deferred` требует owner/причину/срок пересмотра. **Но**: OD,
блокирующие `Approved BCK-04` напрямую (`BCK04-OD-01`, `BCK04-OD-09`) или G1
(`BCK04-OD-06`, `OD-07`, `OD-11`), нельзя перевести в `Deferred` без **изменения их
собственного blocking scope** — Deferred с сохранением "блокирует Approved
BCK-04" логически противоречиво: если решение отложено, Approval не может
одновременно считаться готовым. Только OD с blocking scope ниже уровня самого
BCK-04 Approval (`BCK04-OD-02`–`BCK04-OD-05`, `BCK04-OD-07`–`08`,
`BCK04-OD-10`–`14`) можно deferred с owner, причиной, review date и
сохранённым более узким gate.

## 28. Exact future artifact map

Не создаётся этой версией. Это exact target plan для отдельного Approved
executable slice, согласованный с BCK-01 v0.4.17 Review:

```text
docs/runbooks/
  backend-privacy-deletion.md
  backend-security-abuse.md

apps/backend/
  firestore.rules
  firestore.indexes.json
  storage.rules
  functions/src/
    shared/
      auth/
        auth_guard.ts
        capability_check.ts
        step_up_guard.ts
      observability/
        security_audit_logger.ts
        security_redaction_policy.ts
    modules/
      privacy_orchestration/
        domain/
          privacy_request.ts
          privacy_request_type.ts
          privacy_request_status.ts
        application/
          submit_privacy_request.ts
          dispatch_privacy_domain_tasks.ts
          reconcile_privacy_request.ts
          get_privacy_request_status.ts
        infrastructure/
          privacy_request_repository.ts
          privacy_domain_task_repository.ts
        transport/
          privacy_callable_handlers.ts
    transport/
      middleware/
        app_check_guard.ts
        rate_limit_guard.ts
      callable/
      http/
  functions/test/
    unit/security/
    unit/privacy_orchestration/
    contract/privacy/
    emulator/privacy/
    rules/firestore_security_rules_test.ts
    rules/storage_security_rules_test.ts
    integration/privacy_dsr_test.ts

packages/api_contracts/
  schema/privacy/v1/               # conditional: only after Accepted API-DEC-05
    privacy_request.schema.json
    privacy_request_status.schema.json
    fixtures/
```

`RUN-04`/`RUN-06` пока существуют только в реестре BCK-02. Contract schemas
остаются conditional до Accepted `API-DEC-05`; наличие пути в target plan не
разрешает создать его раньше. Generated files вручную не редактируются.

### 28.1 Server-resolved actor context

Client input schema для `actorContext` намеренно отсутствует:

1. **Неверное имя пути.** Реальный BCK-03 target для платформенных схем —
   `schema/platform/v1/`, не `schema/common/v1/`; последний вообще не
   существует ни как Accepted, ни как conditional target в BCK-03 v0.3.
2. **Концептуальная ошибка.** `schema/platform/v1` и любой non-Booking
   `schema/<domain>/vN` прямо запрещены до Accepted `API-DEC-05`
   (`BCK-03 §35`). Даже после его принятия, `actorContext` — server-resolved
   (`BCK-03 §12`: "акторContext клиент не заполняет") и никогда не является
   client wire payload — значит ему в принципе не место в списке *input*
   wire-схем. Если понадобится типизировать server-internal actor context
   для межсервисного использования, это отдельное решение domain/BCK-05, не
   часть публичного api_contracts schema surface.

## 29. Test/evidence matrix (Test and Evidence Matrix)

| Категория | Обязательные проверки | Gate |
|---|---|---|
| Contract tests | `actorContext` server-only, typed error codes | После executable API slice |
| Negative authorization | Каждая строка §9.2 matrix — allow и deny случай | После executable slice |
| Firestore/Storage Rules emulator | Unauthenticated denial, verification states, cross-page isolation, batch/transaction limits | После Approved `.rules` (не эта версия) |
| Cross-user/cross-page isolation | Page A capability никогда не авторизует Page B | То же |
| Revoked-session/capability | Устаревший snapshot не авторизует mutation | То же |
| App Check monitor/enforce | Missing/invalid token metrics, затем enforced rejection | После rollout начала |
| Anti-enumeration | §11.2 matrix — одинаковый response для missing/forbidden | После executable slice |
| Malformed/oversized payload | Соответствует `BCK-03 §20` bounds | Переиспользует BCK-03 fixtures |
| Accepted abuse baselines | §16.1 report/publish/session значения | Domain executable slice |
| Additional rate limits | Actor/device/global thresholds, retry and bypass denial | После `BCK-05`/domain policy |
| Redaction | §21 запрещённые поля отсутствуют в логах | После logging pipeline |
| Rights request auth | Re-auth/step-up/manual verification, anti-enumeration, abuse denial | До production rights API |
| Rights eligibility | Art. 15–21 request-type eligibility, exemptions, rights of others | Legal-approved fixtures |
| DSR orchestration | Dedupe, retry, partial completion, cancellation, resume, evidence | После first two domain handlers |
| Restriction/rectification | Allowed processing while restricted; lift notice; source/projection/recipient propagation | До этих request types |
| Article 19 propagation | Recipient notify or documented impossible/disproportionate exception | До rectification/erasure/restriction |
| Article 22 | Applicability, human intervention, explanation/contest, child safeguards | До significant automated decision |
| ROPA/DPIA | Inventory completeness and feature activation blocked without required evidence | До production personal data/high-risk feature |
| Processor/transfer | DPA, subprocessor approval, location/transfer mechanism and onward-transfer evidence | До processor onboarding |
| Statutory rights timing | One-month response, valid extension notice/reason, refusal remedy path, no artificial identity delay | До production rights API |
| Transport/crypto/IAM | Encrypted transport, encryption-at-rest inventory, KMS separation/rotation, MFA and least-privilege access review | BCK-05 evidence before G5 |
| Supply chain | Secret/SAST/dependency/vulnerability scans, lock integrity, provenance and SBOM/equivalent lookup | CI/release gate before G5 |
| Webhook/SSRF | Forged/stale/replayed callback denial; redirect/private-metadata network denial | Per external integration before activation |
| Backup/restore privacy | §23 propagation limit соблюдён | После `BCK-05` backup slice |
| Security tabletop/incident drill | SEV path, Article 33/34 assessment, contacts, clocks, evidence | Quarterly по RUN-01/RUN-06 registry |
| Legal/Privacy review | §17 per-market review завершён до release | Per market, до G1/G3 |

Ни одна строка этой таблицы не имеет пройденного runtime evidence в v0.4.9 —
таблица
фиксирует **что** будет проверяться, не заявляет прохождение.

## 30. Definition of Ready, Definition of Done, Acceptance Criteria, unimplemented list

### 30.1 Definition of Ready для BCK-04 Review

- `BCK-01` переведён в `Review` — выполнено 2026-08-20;
- coverage matrix подтверждена актуальной;
- interim coordination назначена `RechargeN / Product owner`; до Review
  остаётся назначить независимого Security/Privacy или Legal/Privacy
  specialist owner для решений, требующих профессионального sign-off;
- Legal/Privacy owner назначен для `OD-11`/`BCK04-OD-06`.
- OD-11 questions and verified legal-source boundaries are reviewable through
  [BCK-D1-OD11-LGL-01](BACKEND_OD_11_AGE_POLICY_LEGAL_BRIEF.md), but the
  decision remains Open until a qualified owner selects a policy.

Current readiness: the BCK-01 and coverage prerequisites plus interim
coordination are evidenced. D1-SIG-SEC and D1-SIG-LEGAL are assigned to the
combined owner in
[BCK-D1-SIG-01](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md), but both verdicts
remain Pending and qualified Legal/Privacy evidence is not established. BCK-04
therefore remains Draft and cannot enter Review yet.

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
- `BCK04-OD-02`, `03`, `04`, `05`, `07`, `08`, `10`, `11`, `12`, `13`, `14`
  (deferrable по §27) — имеют owner и либо закрыты, либо явно перенесены с
  датой пересмотра и сохранённым (более узким) blocking scope;
- reconciliation с `BCK-03`/`BCK-09` подтверждена через
  BCK-D1-DEC-01/ECL03-D11; executable parity evidence остаётся runtime gate;
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
8. **BCK-04-AC-08:** retention matrix покрывает Booking (ECL03-D04 registry
   status Accepted, но exact values по §6 ожидают Legal/Privacy/Product approval)
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
16. **BCK-04-AC-16:** §5 links the full Proposed `BCK04-OD01-TM-01` evidence
    and does not present its bounded trust-boundary summary as independent
    acceptance or runtime proof.
17. **BCK-04-AC-17:** §12 Firestore Rules/IAM не содержит ни одного
    разрешённого direct client write без явной пометки "делегировано
    domain-spec, safe default — запрещено" (§12.3).
18. **BCK-04-AC-18:** §9–10 cross-page isolation правило (`Page A membership
    никогда не авторизует Page B`) присутствует явно, не подразумевается.
19. **BCK-04-AC-19:** §22 не выбирает конкретный регион/edition за `OD-07`;
    фиксирует только совместный `BCK-04`+`BCK-05` Approval boundary.
20. **BCK-04-AC-20:** §20 не изобретает внутренний SLA/формат экспорта:
    statutory Article 12 пределы обязательны, а более строгие operational
    детали остаются `BCK04-OD-08`.
21. **BCK-04-AC-21:** §19 retention activation (когда именно generic/D04-like
    правило становится действующим для конкретного domain) явно требует
    domain-spec Approval, не наступает автоматически по факту существования
    этой таблицы.
22. **BCK-04-AC-22:** §26 наследует общий `incident.md`, secret-leak
    runbook и Article 33/34; Open остаются security-type→SEV mapping и
    privacy-risk criteria, но не statutory notification clocks.
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
30. **BCK-04-AC-30:** backend поддерживает шесть rights-request families
    (access, rectification, erasure, restriction, portability, objection) с
    per-type eligibility; Articles 12–14, 19 и 22 не объявлены частью этого
    списка и покрыты отдельно.
31. **BCK-04-AC-31:** ни одна retention-запись не представлена как
    достаточное основание отказать в erasure request без явной ссылки на
    применимый Art. 17(3) exemption.
32. **BCK-04-AC-32:** incident response явно наследует Art. 33 (72-часовое
    окно) и Art. 34 (user notification при high risk), не изобретает
    отдельный от `RUN-06` путь эскалации.
33. **BCK-04-AC-33:** Privacy Orchestration имеет одного authoritative
    writer для request/task/status records; domain handlers изменяют только
    собственные records и возвращают versioned completion evidence.
34. **BCK-04-AC-34:** offline/local DSR intent не считается submitted;
    retry, partial completion, cancellation и resume имеют typed states.
35. **BCK-04-AC-35:** portability исполняется только при применимых Art. 20
    условиях; objection различает Art. 6(1)(e)/(f) и direct marketing.
36. **BCK-04-AC-36:** restriction не моделируется как безусловный global
    freeze; разрешённая обработка и уведомление перед lift проверяемы.
37. **BCK-04-AC-37:** rectification/erasure/restriction имеют Article 19
    recipient propagation либо documented exception.
38. **BCK-04-AC-38:** rights endpoints требуют server-side requester
    verification, anti-enumeration и risk-based re-auth/step-up.
39. **BCK-04-AC-39:** significant solely automated decisions не активируются
    без Article 22 applicability, safeguards и human contest path.
40. **BCK-04-AC-40:** technical inventory содержит ROPA/DPIA/processor/
    transfer/retention-trigger fields и не выдаётся за подписанный legal ROPA.
41. **BCK-04-AC-41:** rights workflow соблюдает Article 12 one-month outer
    response period, extension/refusal notice и remedy path; внутренний SLA
    не может ослабить statutory deadline.
42. **BCK-04-AC-42:** BCK-04 technical class `Sensitive` не подменяет Article
    9/10 assessment; применимый special-category/criminal-data processing
    fail-closed до отдельного condition/Legal evidence.
43. **BCK-04-AC-43:** external callbacks проверяют authenticity, freshness,
    replay и bounds; outbound URL access имеет SSRF fail-closed controls.
44. **BCK-04-AC-44:** production IAM исключает shared/orphan principals,
    требует MFA для human privileged access и evidence access review.
45. **BCK-04-AC-45:** release evidence включает transport/encryption/key,
    secret/static/dependency/vulnerability/provenance и SBOM-equivalent gates;
    exception всегда bounded owner/expiry/compensating control.

### 30.4 Unimplemented list (честно)

На момент v0.4.10 отсутствует:

- любой `.rules`/`firestore.indexes.json`/Cloud Function файл;
- data inventory за пределами формата §6.1 (сам инвентарь — предмет
  domain-specs);
- Accepted owner/security verdict for the Proposed threat model
  (`BCK04-OD-01`); the Draft evidence document is Present;
- DSR orchestration runtime (request families §20.1);
- backend-specific RUN-01/RUN-06, accepted owner/Legal verdict and executed,
  passed tabletop evidence for the Proposed security-type→SEV/privacy-risk model
  (`BCK04-OD-09`);
- Legal/Privacy review по любому рынку;
- App Check emergency bypass policy;
- physical IAM/MFA/KMS, encrypted-resource inventory, security scans,
  vulnerability/SBOM evidence, webhook/SSRF controls;
- Accepted non-Booking retention (Sensitive/audit намеренно без default,
  §19.2);
- ROPA, DPIA gate, processor/subprocessor inventory, international-transfer
  и automated-decision policies (`BCK04-OD-10`…`OD-14`).

Runtime status остаётся **Absent** по всему документу.
