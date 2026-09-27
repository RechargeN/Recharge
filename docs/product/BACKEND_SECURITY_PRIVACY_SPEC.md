# Recharge Backend — Security & Privacy Specification

- ID: **BCK-04**
- Version: **0.4.35**
- Date: **2026-09-27**
- Spec status: **Review — D1 security/privacy technical baseline closed; independent/qualified/production gates retained**
- Runtime status: **Local R1 security/privacy ports, default-deny Rules and disposable Emulator evidence Present; product/cloud security runtime Absent**
- Accountable owner: **Security/Privacy owner** (per `BCK-02 §5` registry row `BCK-04`)
- Interim review coordinator: **RechargeN / Product owner**
- Local R1 technical decision: **Accepted and verified locally — independent/qualified and cloud gates retained**
- Production Security/Privacy/Legal approval: **Pending**
- Markets: **Latvia first; Estonia and Lithuania prepared but disabled independently**
- Parent architecture: [BCK-01 v0.4.84](RECHARGE_BACKEND_MASTER_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.99](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Reconciles with: [BCK-03 v0.3.21](BACKEND_API_CONTRACT_STANDARD.md) (Review; local-R1 verified),
  [BCK-09 v1.23](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md) (Review)
- Preparatory input: [BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md](BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md) v0.3.25
- Technical owner review: [BCK04-SEC-REV-01 v0.2](BACKEND_SECURITY_PRIVACY_OWNER_REVIEW.md)
- Technical owner decision: [BCK04-SEC-DEC-01 v0.1](BACKEND_SECURITY_PRIVACY_OWNER_DECISION.md)
- API security boundary decision: [BCK03-SEC-DEC-01 v0.1](BACKEND_API_SECURITY_PRIVACY_OWNER_DECISION.md)
- Infrastructure evidence: [BCK-D1-OD07-EV-01](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md) v0.6 (OD-07 Accepted with controls)
- Infrastructure decision: [OD07-DEC-01](BACKEND_OD_07_INFRASTRUCTURE_OWNER_DECISION.md) v0.2 (Accepted)
- IAM boundary evidence: [BCK05-OD02-IAM-01](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md) v0.2.1 (BCK05-OD-02 Accepted with controls)
- Threat-model evidence: [BCK04-OD01-TM-01](BACKEND_SECURITY_THREAT_MODEL.md) v0.2 (Draft; combined-owner technical verdict recorded; OD-01 Proposed)
- Threat-model owner decision: [BCK04-OD01-DEC-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_OWNER_DECISION.md)
- Incident-response evidence: [BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md) v0.1 (Draft; OD-09 Proposed)
- Tabletop package: [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) v0.1 (ready; not executed)
- OD-11 Product review: [BCK-D1-OD11-PROD-REV-01 v0.1](BACKEND_OD_11_PRODUCT_POLICY_REVIEW.md) (prepared; Product verdict Pending)
- D1 Owner Batch D: [BCK-D1-OWN-D-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_D_REVIEW_PACKAGE.md) (prepared; all verdicts Pending)
- Cross-boundary assignment manifest: [BCK04-OD01-XASSIGN-01 v0.1](BACKEND_SECURITY_CROSS_BOUNDARY_ASSIGNMENT_MANIFEST.md) (0/14 assigned; 0/14 verdicts)
- D1 Owner Batch E: [BCK-D1-OWN-E-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_E_REVIEW_PACKAGE.md) (prepared; all verdicts Pending)
- Hard dependencies (per `BCK-02 §5`): `BCK-01`, `ADR 0013`, `ADR 0015`, environment policy, `OD-07`, `OD-11`
- Canonical repository path: `docs/product/BACKEND_SECURITY_PRIVACY_SPEC.md`
- Runtime effect of this revision: **local/Emulator-only abuse-policy,
  App Check and rate-limit mechanisms; no cloud or activation**

---

## 0. Changelog

### v0.4.35 — 2026-09-27

- requires domain erasure to advance around legally held records and preserve
  an exact retained count instead of stalling or falsely reporting complete
  deletion;
- adds `completedWithRetention` and an idempotent linked follow-up erasure after
  legal-hold release; release alone never restores TTL eligibility;
- records green local contract, integration and disposable Emulator evidence
  without claiming qualified Legal/Privacy, cloud or production approval.

### v0.4.34 — 2026-09-26

- integrates the owner-approved BCK-09 numeric abuse policy as a bounded local
  implementation: layered actor/account/installation limits, secondary
  day-rotated network hash, request dedupe and minimized audit;
- makes App Check bypass exact to the local demo Emulator and fail-closed in
  every non-local environment;
- registers all new security collections as direct-client deny and retains
  independent Security/Privacy, qualified Legal and production evidence.

### v0.4.32 — 2026-09-24

- forbids per-Session authority, Session IDs, opaque handles and mutable
  AccessSnapshot revisions in Firebase custom claims;
- requires server-side handle hashing, UID/installation/Session binding and
  revision-aware source reads for protected Booking mutations;
- changes no independent/qualified review, cloud, deployment or market gate.

### v0.4.31 — 2026-09-23

- records the completed local R1 security/privacy foundation: typed guards
  and ports, fail-closed policy decisions, default-deny Rules and disposable
  Emulator negative evidence are present and verified;
- removes stale owner-approval-pending wording without claiming independent
  Security/Privacy, qualified Legal, cloud or production approval;
- aligns BCK-01/BCK-02/BCK-03 references with the Stage 8 reconciliation and
  changes no policy, data-class or acceptance-criteria semantics.

### v0.4.30 — 2026-09-21

- reconciles the security boundary to BCK-01 v0.4.81, BCK-03 v0.3.19 and the
  sole BCK-02 v2.4.87 exact R1 manifest;
- separates local default-deny technical acceptance from production,
  independent Security/Privacy and qualified Legal approval;
- preserves logical IAM, secret references, App Check, data classes,
  retention/DSR, age fail-closed policy and exact European location controls;
- delegates exact owner approval to BCK-02 §29 and changes no Rules/IAM/runtime.

### v0.4.29 — 2026-09-21

- added the Stage 7 exact R1 security/Rules/IAM file and ownership map;
- fixed default-deny ports, direct-client collection posture, logical identities
  and negative test locations without inventing grants or cloud principals;
- kept Identity, DSR, T&S and product authorization outside R1;
- created no Rules/source/IAM/runtime/Firebase/deployment authority.

### v0.4.28 — 2026-09-21

- added the Stage 6 per-market/per-capability compliance evidence contract;
- separated processing/Legal, residency/transfer, age, UGC/DSA,
  retention/DSR and support evidence from MarketConfig and deployment state;
- required subject-wide DSR scope and smallest-safe capability containment;
- retained every independent Security/Privacy and qualified Legal gate and
  added no runtime, Firebase, deployment or market activation authority.

### v0.4.27 — 2026-09-20

- added the Stage 2 normalized security/privacy entity inventory;
- separated Privacy Orchestration authority from domain deletion handlers,
  Identity authority and Operations incident/deployment records;
- aligned authorization, retention, audit and evidence semantics with BCK-01
  §30 and the BCK-02 writer ledger without claiming qualified approval.

### v0.4.26 — 2026-09-20

- closed the D1 technical security/privacy boundary for R1 planning without
  claiming independent Security/Privacy or qualified Legal conclusions;
- aligned data classes, server-resolved actor context, Rules/IAM, secrets,
  retention/deletion orchestration and incident/rollback boundaries with the
  closed BCK-03/05 technical contracts;
- recorded OD-11 as Proposed without selecting a numeric age: only the exact
  age-sensitive market/surface remains disabled until an Accepted policy;
- retained non-Booking retention values, DPIA, ROPA, transfers, qualified
  legal basis and production personal-data processing as later fail-closed gates;
- advanced the specification to Review for exact R1 planning only; no Auth,
  App Check, Rules/IAM deployment, secrets, Firebase or personal-data runtime
  is authorized.

### v0.4.25 — 2026-09-20

- prepared a hash-pinned assignment manifest for all fourteen independent and
  cross-boundary threat-model sign-offs;
- recorded the factual initial state as 0/14 assigned and 0/14 verdicts,
  without fabricating reviewer identity, authority or independence;
- prepared Batch E and the four-parent preflight while retaining
  BCK04-OD-01 Proposed and BCK-04 Draft;
- created no runtime, Firebase, credential, deployment, push or merge authority.

### v0.4.24 — 2026-09-20

- prepared a hash-pinned OD-11 Product boundary covering separate account,
  feature, content, transaction, admission and Creator/Page eligibility;
- prepared Batch D and the internal blocker matrix without selecting a numeric
  age, guardian model or qualified Legal/Privacy conclusion;
- retained OD-11 Open, age-sensitive surfaces fail-closed, BCK-04 Draft and
  every independent/cross-boundary/Legal/runtime gate;
- created no schema, data collection, Firebase resource, deployment, push or
  merge authority.

### v0.4.23 — 2026-09-15

- recorded BCK04-OD01-DEC-01 for the combined-owner technical threat-model
  boundary and integrated all twenty amendments in threat-model v0.2;
- added explicit per-threat classification, ownership, evidence gates,
  residual disposition, DSR/read/App Check/identity/ingress/supply-chain/
  restore/market coverage and revision checksum;
- retained BCK04-OD-01 Proposed pending independent Security/Privacy and
  required cross-boundary confirmations;
- retained BCK-04 Draft, BCK04-OD-09 Proposed, OD-11 Open and all Legal,
  D1/G1 and executable/runtime blockers;
- created no code, Firebase resource, credential, deployment, push or merge
  authority.

### v0.4.22 — 2026-09-12

- recorded BCK04-SEC-DEC-01 `Accept with required amendments` for the combined-
  owner technical documentation boundary only;
- separated DSR attempt `requestId`, logical `idempotencyKey` and server-issued
  `privacyRequestId`, and added current-read authorization, safe export,
  monotonic state, cancellation and anti-resurrection controls;
- superseded the stale BCK-04-AC-06 wording in place and appended AC-46–AC-59;
- retained Draft status, independent/qualified Legal evidence, BCK04-OD-01/09,
  OD-11, D1/G1 and every executable/runtime gate as unresolved;
- created no runtime, Firebase resource, deployment, push or merge authority.

### v0.4.21 — 2026-09-09

- reconciled BCK03-MOB-DEC-01 and BCK-03 v0.3.12 without accepting BCK-04;
- retained BCK-04 owner/independent/Legal blockers, OD-01/09 Proposed and
  product/cloud runtime Absent;
- changed no security runtime, Firebase, deployment, push or merge state.

### v0.4.20 — 2026-09-08

- recorded bounded D1-SIG-SEC acceptance for the BCK-03 boundary and the ten
  required API amendments through BCK03-SEC-DEC-01;
- retained BCK-04 Draft, BCK04-OD-01/09 and OD-09 Proposed, OD-11 Open,
  D1-SIG-LEGAL/Mobile/independent verdicts pending and runtime Absent;
- reconciled BCK-01 v0.4.54, BCK-02 v2.4.58 and BCK-03 v0.3.11 without
  claiming BCK-04, Legal or runtime approval.

### v0.4.19 — 2026-09-08

- reconciled BCK-01 v0.4.53, BCK-02 v2.4.57 and BCK-03 v0.3.10 after the
  bounded Operations verdict;
- retained BCK-04 Draft and every Security/Privacy, Legal and runtime blocker.

### v0.4.18 — 2026-09-08

- reconciled BCK-01 v0.4.52, BCK-02 v2.4.56 and BCK-03 v0.3.9 after Owner
  Batch A without treating the BCK-03 combined-owner verdict as a Security or
  independent signature;
- retained BCK-04 Draft, OD-11 Open, BCK04-OD-01/09 Proposed and all qualified
  Legal/Privacy, tabletop, IAM/cloud and runtime blockers;
- changed no policy, Firebase resource, credential, deployment or runtime.

### v0.4.17 — 2026-09-07

- reconciled current anchors to BCK-01 v0.4.51, BCK-02 v2.4.55,
  BCK-03 v0.3.8, BCK-09 v1.13 and coverage v0.3.17;
- recorded bounded default-deny and RAW-C Emulator security evidence without
  claiming cloud IAM, Rules, App Check, deployment or production processing;
- retained Draft status, OD-11 Open, BCK04-OD-01/09 Proposed and every
  Security/Privacy/qualified-Legal review blocker;
- changed no runtime, Firebase resource, policy decision or Accepted ADR.

### v0.4.16 — 2026-08-25

- recorded BCK05-OD-07 Acceptance at `BCK05-REL-A1-DUAL-PROV-v1` with
  controls through exact BCK05-OD07-DEC-01 v0.2 owner evidence;
- retained BCK-04 Draft, qualified Legal/Privacy, threat/incident, retention,
  executable IAM/release and production gates;
- created no workflow, repository/cloud mutation, credential, deployment,
  production processing or `main` merge authority.

### v0.4.15 — 2026-08-25

- reconciled supply-chain boundaries with decision-ready
  `BCK05-REL-A1-DUAL-PROV-v1`: caller attestations remain distinct from
  provider receipts and unknown/partial outcomes fail closed;
- preserved BCK-04 Draft, qualified Legal/Privacy, threat/incident, retention,
  executable IAM and production gates;
- created no workflow, repository/cloud mutation, credential, deployment,
  production processing or `main` merge authority.

### v0.4.14 — 2026-08-24

- recorded BCK05-OD-02 Acceptance at `BCK05-IAM-A1-ENV-WIF-v1` with controls
  through the exact BCK05-OD02-DEC-01 v0.2 owner verdict;
- retained BCK-04 Draft, qualified Legal/Privacy review, executable IAM/
  secrets evidence, BCK04-OD-01/09 and all cloud/runtime gates;
- created no Rules, GitHub/GCP mutation, credential, production processing or
  `main` merge authority.

### v0.4.13 — 2026-08-24

- reconciled the security boundary with decision-ready IAM candidate
  `BCK05-IAM-A1-ENV-WIF-v1`, including immutable repository identity,
  keyless WIF, least privilege and fail-closed production separation;
- retained BCK05-OD-02 as Proposed pending its exact owner verdict and kept
  every executable IAM, secret, cloud and product-runtime gate blocked;
- advanced parent/coordination/coverage traceability without changing BCK-04
  Draft status or qualified Legal/Privacy requirements.

### v0.4.12 — 2026-08-24

- recorded OD-07 Acceptance at `OD07-A1-EU-MR-v1` through the exact
  OD07-DEC-01 v0.2 owner verdict;
- preserved the distinction between controlled European resource placement and
  Firebase Authentication/global processing, plus the qualified production
  Legal/Privacy gate;
- kept BCK-04 Draft, OD-01/09 and all other specialist decisions unresolved,
  with production processing and cloud runtime disabled.

### v0.4.11 — 2026-08-24

- reconciled the exact OD-07 candidate with per-resource European locations and
  explicitly disclosed Firebase Authentication US processing plus global
  service/logging boundaries;
- separated architecture location Acceptance from the still-mandatory qualified
  processor/transfer/legal production verdict;
- retained OD-07 Proposed, BCK-04 Draft and all production processing disabled.

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
| 8 | Schema/API/event versions, evolution, minimum supported client | Покрыт границей | Privacy wire/event `v1`, additive evolution и minimum-client policy наследуют `BCK-03 §25–27`; canonical schema path follows Accepted `API-DEC-05`, physical artifacts remain slice-gated, §28 |
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
- `OD-11` Proposed technical minors/age constraints and Legal review brief;
- retention/deletion/export/DSR модель;
- logging/audit redaction правила;
- data residency принципы (`OD-07` boundary, без самостоятельного выбора или
  принятия региона вне единого owner-decision contract);
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
49 classified threat records, per-threat ownership, evidence gates, residual
dispositions and revision checksum —
[BCK04-OD01-TM-01 v0.2](BACKEND_SECURITY_THREAT_MODEL.md). Combined-owner
technical verdict is recorded through BCK04-OD01-DEC-01. Independent
Security/Privacy review and required API/Operations/Identity/Mobile/domain
confirmations remain absent, поэтому `BCK04-OD-01` не Accepted.

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

Revocation — fail-closed: любая authoritative mutation, protected/sensitive
query и раскрытие защищённого результата оценивают текущий server-owned access;
устаревший mobile-снапшот роли/workspace, ранее выданная export capability или
cache никогда не авторизуют операцию. Суспензия session/verification/
membership/capability/market делает связанный cached access недействительным и
производит typed outcome, не раскрывая, существует ли недоступный ресурс
(anti-enumeration, см. §11.2).

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
contract across BCK-03 v0.3.19, BCK-09 v1.15, ECL-03 v1.3 and ECL-03C v1.11:

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

До принятия `BCK04-OD-04` emergency degradation может только оставить App
Check в monitor/disabled состоянии. Она никогда не отключает AuthN, current
AuthZ, schema/domain validation, rate limits или audit. Будущее исключение
обязано быть узким по environment/surface, иметь owner, reason, start/expiry,
monitoring, approval и revocation evidence; молчаливый permanent bypass
запрещён.

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

`OD-11` зарегистрирован (`BCK-02 §16`, строка реестра `OD-11`) как
`Proposed`, owner Security/Privacy. Proposal намеренно не выбирает числовой
возраст: он задаёт versioned policy contract и fail-closed поведение для
R2 production account creation, Find People, age-restricted
publication/discovery, applicable Booking paths и G6. Юридические источники,
purpose-by-purpose вопросы и qualified-review contract собраны в
[BCK-D1-OD11-LGL-01](BACKEND_OD_11_AGE_POLICY_LEGAL_BRIEF.md).

### 18.1 Proposed constraints

- политика версионируется **отдельно для LV, EE и LT** — единого глобального
  возраста нет;
- BCK-04 **не назначает** конкретный минимальный возраст или legal basis —
  это Legal/Privacy review per market;
- guardian consent, verification requirements принимаются только после
  такого review;
- **client-declared age не является authority** — совпадает со сквозным
  принципом §8/§9;
- policy key is `(market, surface, purpose, policyRevision)`; missing, stale,
  unsupported or non-Accepted policy disables only the affected age-sensitive
  surface for that market;
- до Accepted решения по конкретному рынку: Find People, age-restricted
  публикация/discovery и applicable Booking paths — **server-disabled и
  fail-closed**; general local/dev backend work and non-age-sensitive surfaces
  are not globally blocked;
- production account creation may proceed only if the Accepted Identity/Legal
  policy explicitly declares the account path age-neutral or defines its
  compliant eligibility flow; otherwise that path is disabled;
- disabled Booking Emulator core (`BCK-09`/`G4`) **не блокируется
  глобально** — age-sensitive paths внутри него остаются server-disabled
  индивидуально, пока их конкретный scope не Accepted;
- каждое per-market решение фиксирует: `market`, `productScope`, `owner`,
  `legalReviewDate`, `effectiveDate`.

### 18.2 Статус

`Proposed — no numeric Recharge age selected`. D1 accepts only the technical
policy shape and scoped fail-closed behavior. `Proposed -> Accepted` requires
qualified Legal/Privacy evidence and a concrete per-market/per-surface policy.
Age-gate UI, guardian flow and verification backend are not authorized by this
specification.

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

Каждый legal/security hold или Art. 17(3) exception имеет exact authorized/
lawful basis reference, record-family scope, owner, start, review/expiry
condition и release evidence. Hold не наследуется всей data class, не
продлевается бессрочно по умолчанию и не выводится только из внутреннего срока
retention.

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
  -> SubmitPrivacyRequest(requestId, idempotencyKey, requestType, scope, market)
    -> PrivacyRequest privacyRequestId (authoritative coordinator source)
      -> PrivacyDomainTask per owning BCK module
        -> domain command executes only domain-owned records
        -> versioned completion/failure response or accepted OD-09 event
      -> PrivacyCompletionEvidence aggregates privacy-safe outcomes
  -> GetPrivacyRequestStatus(privacyRequestId) returns revisioned user-safe status
```

Ownership:

| Record | Authoritative writer | Consumers |
|---|---|---|
| `PrivacyRequest` | Privacy Orchestration | Requester projection, Privacy/Admin operations |
| `PrivacyDomainTask` | Privacy Orchestration | Exact owning domain handler |
| Domain completion evidence | Owning domain | Privacy Orchestration only |
| `PrivacyCompletionEvidence` | Privacy Orchestration | Requester projection, audited support |

Invariants:

- каждый physical attempt получает новый `requestId`; retry той же logical
  submission сохраняет `idempotencyKey` и canonical normalized payload;
  successful submission возвращает отдельный server-issued
  `privacyRequestId`, которым адресуются status/cancel/export operations;
- requester identity проверяется server-side; authenticated session может
  требовать recent re-auth/step-up, а manual support channel — эквивалентную
  documented identity verification; client-declared actor не принимается;
- client-supplied subject, publisher, workspace, domain и resource references
  являются только untrusted filters: backend связывает scope с verified data
  subject и никогда не расширяет его на чужие records;
- existence/status другого пользователя не раскрывается; DSR endpoints
  наследуют anti-enumeration §11.2 и отдельные abuse limits;
- IDs — ULID, timestamps — backend UTC, market — versioned stable value по
  `BCK-01 §11`; local/offline intent не считается submitted request;
- повтор logical submission с тем же idempotency key и canonical payload
  возвращает тот же receipt/result с текущим attempt request ID; key reuse с
  другим payload даёт typed `idempotency_conflict`;
- status transitions monotonic:
  `received -> verificationRequired | accepted -> dispatching ->
  partiallyCompleted | completed | rejected`; local cancel до send означает,
  что request не submitted; timeout после send даёт `unknownOutcome` и
  reconciles через тот же idempotency key/receipt; authoritative cancellation
  — отдельный `cancelled` outcome только до declared irreversible boundary;
  после неё cancel возвращает typed state conflict и не делает вид, что
  committed work отменено;
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
- completion evidence — Operational/audit, без raw exported content;
- status/result содержит server revision/freshness; terminal state не
  регрессирует, а late/cache/offline response не перезаписывает более новую
  revision и не продлевает freshness.

Export retrieval использует authenticated, short-lived, single-purpose,
owner-bound capability с risk-based step-up, bounds, audit и revocation.
Обычное письмо не содержит raw export attachment. Exact transport, lifetime и
delivery channel остаются `BCK04-OD-08`, но не могут ослабить эти инварианты.

Erasure/restriction completion evidence обязано предотвращать silent
resurrection через late domain task, projection rebuild, local import или
backup restore. Identity teardown выполняется после достаточного dispatch/
reconciliation evidence, чтобы оставшиеся domain handlers могли завершить
работу без восстановления пользовательской authority.

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
[BCK-D1-OD07-EV-01 v0.6](BACKEND_OD_07_INFRASTRUCTURE_EVIDENCE.md), with the
exact recorded owner verdict in
[OD07-DEC-01 v0.2](BACKEND_OD_07_INFRASTRUCTURE_OWNER_DECISION.md). The package
accepts the controlled engineering location baseline but does not authorize
provisioning or production processing.

`OD-07` — Accepted at `OD07-A1-EU-MR-v1` with controls, owner Platform
(совместно `BCK-04`/`BCK-05` по `BCK-01 §21`). `FIREBASE_ARCHITECTURE.md §4.3`
предлагает (**Proposed, не Accepted**) `eur3`/`europe-west1`, но сам текст
источника прямо требует "a recorded data-residency, cost and latency review"
и запрещает "Creating the production database before that approval".
ECL-03 Decision Package D02 также содержит Booking-scoped location proposal;
он не закрывает cross-domain OD-07 и не разрешает irreversible provisioning.

BCK-04 фиксирует boundary-требования:

- LV/EE/LT residency — единая политика для всех трёх, если Legal review не
  потребует разделения;
- принятое решение о регионе наследуется только из OD07-DEC-01 v0.2 и не
  изменяется односторонне BCK-04 или BCK-05;
- несмотря на Accepted `OD-07`, до прохождения G1 и отдельного exact Approved
  R1 slice physical provisioning запрещён coordination gate `BCK-02 §18`;
- European Firestore/Storage/Functions placement is not a claim that all
  Firebase processing is EU-only. Firebase Authentication's documented US
  processing and every global service remain disabled for production until
  processor/subprocessor, DPA/transfer, legal-basis, transparency and retention
  review is complete.
- OD-07 may accept the engineering topology without pretending to supply legal
  advice; qualified Legal/Privacy approval remains a separate production
  activation gate and cannot be replaced by the combined Product owner.

**Open:** qualified production Legal/Privacy conclusions and the related
LV/EE/LT-specific market-policy detail, which belongs to `BCK-20` for
non-residency parts. The OD-07 engineering verdict itself is closed.

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
- restore/import/projection rebuild проверяет актуальные erasure/restriction
  markers и privacy completion revisions; восстановленная старая копия не
  становится снова видимой или authoritative без повторной reconciliation.

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
| `OD-11` (внешний, `BCK-02 §16`) | **Proposed:** market/surface/purpose-versioned minors/age policy without numeric age | Security/Privacy + qualified Legal | affected R2 account, Find People, age-restricted and applicable Booking paths, G6, §18 | Нет для affected production surface; не блокирует D1/R1 design |
| `BCK04-OD-01` | **Proposed:** v0.2 has 49 classified threats, per-threat ownership/gates/residual state and combined-owner technical verdict; independent review and cross-boundary confirmations pending | Security/Privacy | **Approved BCK-04 напрямую** | **Нет** |
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
(`BCK04-OD-06`, `OD-07`), нельзя перевести в `Deferred` без **изменения их
собственного blocking scope** — Deferred с сохранением "блокирует Approved
BCK-04" логически противоречиво: если решение отложено, Approval не может
одновременно считаться готовым. Только OD с blocking scope ниже уровня самого
BCK-04 Approval (`BCK04-OD-02`–`BCK04-OD-05`, `BCK04-OD-07`–`08`,
`BCK04-OD-10`–`14`) можно deferred с owner, причиной, review date и
сохранённым более узким gate.

## 28. Exact future artifact map

Не создаётся этой версией. Это exact target plan для отдельного Approved
executable slice, согласованный с BCK-01 v0.4.78 Review:

```text
docs/runbooks/
  backend-privacy-deletion.md
  backend-security-abuse.md

apps/backend/
  firestore.rules
  firestore.indexes.json
  storage.rules
  functions/src/
    platform/
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
  schema/privacy/v1/               # canonical under Accepted API-DEC-05;
                                   # physical files require Approved slice
    privacy_request.schema.json
    privacy_request_status.schema.json
    fixtures/
```

`RUN-04`/`RUN-06` пока существуют только в реестре BCK-02. Contract schemas
use the Accepted `API-DEC-05` canonical location; наличие пути в target plan не
разрешает создать их до exact Approved executable slice. Generated files
вручную не редактируются.

### 28.1 Server-resolved actor context

Client input schema для `actorContext` намеренно отсутствует:

1. **Неверное имя пути.** Реальный BCK-03 target для платформенных схем —
   `schema/platform/v1/`, не `schema/common/v1/`; последний вообще не
   существует ни как Accepted, ни как conditional target в BCK-03 v0.3.19.
2. **Концептуальная ошибка.** Accepted `API-DEC-05` задаёт
   `schema/<domain>/vN` как canonical wire location, но physical artifacts
   remain executable-slice gated. Кроме того, `actorContext` — server-resolved
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

Ни одна строка этой таблицы не имеет пройденного runtime evidence в текущей
ревизии — таблица
фиксирует **что** будет проверяться, не заявляет прохождение.

## 30. Definition of Ready, Definition of Done, Acceptance Criteria, unimplemented list

### 30.1 Definition of Ready для BCK-04 Review

- `BCK-01` переведён в `Review` — выполнено 2026-08-20;
- coverage matrix подтверждена актуальной;
- interim coordination назначена `RechargeN / Product owner`; до Review
  остаётся назначить независимого Security/Privacy и qualified Legal/Privacy
  specialist owner для решений, требующих профессионального sign-off;
- qualified Legal/Privacy ownership remains required for `OD-11` Acceptance
  and `BCK04-OD-06`; combined Product-owner coordination is disclosed;
- OD-11 questions and verified legal-source boundaries are reviewable through
  [BCK-D1-OD11-LGL-01](BACKEND_OD_11_AGE_POLICY_LEGAL_BRIEF.md); the technical
  proposal is fixed, while numeric/per-market policy remains unaccepted.

Current readiness: the BCK-01 and coverage prerequisites plus interim
coordination are evidenced. The combined owner accepted the technical BCK-03,
BCK-04 and BCK04-OD01 threat-model boundaries with required amendments through
BCK03-SEC-DEC-01, BCK04-SEC-DEC-01 and BCK04-OD01-DEC-01. This is not
independent Security/Privacy evidence, OD-01 Acceptance or qualified Legal
judgment. BCK04-OD-01/09, independent assessment, cross-boundary confirmations,
D1-SIG-LEGAL and qualified Legal/Privacy evidence remain absent. The D1
technical boundary is nevertheless closed and BCK-04 is Review; those retained
gates still block Approved/production status.

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
- 90 AC are unique and sequential;
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
6. **BCK-04-AC-06:** `requestId` per attempt, logical `idempotencyKey` и
   server-issued `privacyRequestId` имеют разные роли и согласованы с
    BCK-03 v0.3.19; это wording supersedes AC-06 revision v0.4.21 без
   перенумерации stable ID.
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
16. **BCK-04-AC-16:** §5 links exact Proposed `BCK04-OD01-TM-01 v0.2`, records
    only its combined-owner technical verdict and does not present it as
    independent acceptance or runtime proof.
17. **BCK-04-AC-17:** §12 Firestore Rules/IAM не содержит ни одного
    разрешённого direct client write без явной пометки "делегировано
    domain-spec, safe default — запрещено" (§12.3).
18. **BCK-04-AC-18:** §9–10 cross-page isolation правило (`Page A membership
    никогда не авторизует Page B`) присутствует явно, не подразумевается.
19. **BCK-04-AC-19:** §22 может ссылаться на точный единый кандидат `OD-07`,
    но не выбирает, не меняет и не принимает region/edition самостоятельно;
    owner verdict остаётся совместным `BCK-04`+`BCK-05` boundary.
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
46. **BCK-04-AC-46:** protected/sensitive read and result disclosure
    re-evaluate current server-owned authority.
47. **BCK-04-AC-47:** client DSR scope cannot widen the verified data subject's
    server-resolved record scope.
48. **BCK-04-AC-48:** local pre-send cancellation, post-send unknown outcome
    and authoritative cancellation remain distinct.
49. **BCK-04-AC-49:** authoritative cancellation is rejected after the
    declared irreversible boundary without fabricating rollback.
50. **BCK-04-AC-50:** DSR state is monotonic, revisioned and server-fresh;
    response arrival order is not authority.
51. **BCK-04-AC-51:** export retrieval is authenticated, short-lived,
    purpose-bound, owner-bound, bounded, audited and revocable.
52. **BCK-04-AC-52:** ordinary email never carries a raw privacy export
    attachment.
53. **BCK-04-AC-53:** late tasks, projection rebuilds, imports and restores
    cannot silently resurrect erased or restricted data.
54. **BCK-04-AC-54:** identity teardown preserves enough orchestration
    authority to finish or honestly fail remaining domain tasks.
55. **BCK-04-AC-55:** every legal/security hold records basis, scope, owner,
    review/expiry and release evidence.
56. **BCK-04-AC-56:** App Check recovery cannot bypass AuthN, AuthZ,
    validation, rate limits or audit.
57. **BCK-04-AC-57:** BCK04-SEC-DEC-01 does not accept BCK04-OD-01/09,
    OD-11, independent review or qualified Legal evidence.
58. **BCK-04-AC-58:** BCK-04 may be Review after D1 technical closure, but
    remains unapproved until its full DoD and retained independent/qualified gates pass.
59. **BCK-04-AC-59:** this revision creates no code, Firebase resource,
    deployment, push or merge authority.
60. **BCK-04-AC-60:** threat-model v0.2 gives every threat explicit
    classification, accountable owner, evidence gate and residual disposition.
61. **BCK-04-AC-61:** protected-read, DSR, App Check, identity-lifecycle,
    hostile-ingress, supply-chain, restore and market-isolation threats are
    reconciled with this specification.
62. **BCK-04-AC-62:** threat-model target controls are not presented as
    implemented or verified product/cloud controls.
63. **BCK-04-AC-63:** BCK04-OD01-DEC-01 does not accept BCK04-OD-01 or replace
    independent/cross-boundary evidence.
64. **BCK-04-AC-64:** OD-01 and OD-09 remain independently gated; neither
    decision is inferred from the other.
65. **BCK-04-AC-65:** BCK-D1-OD11-PROD-REV-01 prepares only an unsigned
    Product boundary; it selects no numeric age, supplies no qualified verdict
    and leaves numeric/per-market OD-11 policy unaccepted and every dependent
    high-risk surface fail-closed.
66. **BCK-04-AC-66:** BCK04-OD01-XASSIGN-01 and Batch E prepare assignment
    routing only; all fourteen reviewers/verdicts remain unrecorded, OD-01
    remains Proposed and no independent/cross-boundary evidence is inferred.
67. **BCK-04-AC-67:** OD-11 is Proposed only as a versioned
    market/surface/purpose policy shape; no numeric age is selected.
68. **BCK-04-AC-68:** an absent, stale, unsupported or non-Accepted age policy
    disables the affected age-sensitive surface, not unrelated backend work.
69. **BCK-04-AC-69:** D1 technical closure does not claim independent
    Security/Privacy or qualified Legal approval.
70. **BCK-04-AC-70:** Accepted API-DEC-05 supplies the canonical schema
    location, while physical schema and generated files remain slice-gated.
71. **BCK-04-AC-71:** BCK-04 Review permits exact R1 design only and grants no
    IAM, Rules, secret, Firebase, deployment or production-data authority.
72. **BCK-04-AC-72:** retention, deletion, incident and backup controls keep
    their narrower production gates even when the technical boundary is closed.
73. **BCK-04-AC-73:** compliance readiness is evaluated for an exact
    environment, market, capability, purpose and policy revision tuple.
74. **BCK-04-AC-74:** MarketConfig and a server feature flag cannot substitute
    for accepted Security/Privacy and applicable qualified Legal evidence.
75. **BCK-04-AC-75:** residency and transfer evidence inventories every
    applicable resource/processor/location; an EU-labelled primary resource is
    not proof about backups, logs, support access or subprocessors.
76. **BCK-04-AC-76:** missing age or UGC/DSA evidence disables only affected
    surfaces unless a shared protection defect requires broader containment.
77. **BCK-04-AC-77:** mandatory privacy, age and safety copy is bound to exact
    market/locale/revision and cannot use an unapproved localization fallback.
78. **BCK-04-AC-78:** DSR verification and dispatch cover the data subject
    across every applicable market and owning handler, independent of
    home/current market or device locale.
79. **BCK-04-AC-79:** every enabled capability has explicit retention,
    deletion/export handler, hold behavior, support/escalation route and audit
    evidence, or a reviewed not-applicable decision.
80. **BCK-04-AC-80:** current official authority/contact references are
    evidence inputs only and never represent a qualified legal conclusion.
81. **BCK-04-AC-81:** v0.4.28 is documentation-only and grants no independent
    verdict, runtime, IAM, Rules, Firebase, deployment or market activation.
82. **BCK-04-AC-82:** BCK-02 §26 enumerates every R1 security/config/Rules and
    negative-test path; no alternative middleware or policy file is allowed.
83. **BCK-04-AC-83:** R1 security files define ports and default-deny behavior,
    not Identity records, grants, verification or product authorization.
84. **BCK-04-AC-84:** every R1 platform/reference collection denies direct
    client read/write and has one server writer plus exact reader scope.
85. **BCK-04-AC-85:** App Check and rate-limit ports cannot authorize a request
    or replace fresh actor/capability/market policy evaluation.
86. **BCK-04-AC-86:** secret config contains identifiers/references only and
    tests reject secret values, tokens, credentials and key material.
87. **BCK-04-AC-87:** R1 uses logical identities only; real service accounts,
    IAM bindings and break-glass grants remain execution/provisioning-gated.
88. **BCK-04-AC-88:** structured logs, metrics and security audit ports use
    allowlisted low-cardinality metadata and reject payload/PII/secret leakage.
89. **BCK-04-AC-89:** R1 rollback cannot relax Rules, resurrect grants/data or
    remove RAW-C deny coverage; unsafe state remains disabled.
90. **BCK-04-AC-90:** v0.4.29 is documentation-only and creates no security
    source, Rules change, IAM binding, secret, Firebase resource or deployment.
91. **BCK-04-AC-91:** v0.4.30 is reconciled to the sole BCK-02 v2.4.87 §26
    path/action manifest and cannot introduce an alternate security path.
92. **BCK-04-AC-92:** local-R1 acceptance covers only fail-closed ports,
    synthetic negative evidence and default-deny Rules intent.
93. **BCK-04-AC-93:** logical IAM identities and secret references create no
    account, binding, credential, secret value or standing privilege.
94. **BCK-04-AC-94:** retention/DSR and age-policy contracts remain technical;
    numeric age and qualified production policy stay Pending and fail closed.
95. **BCK-04-AC-95:** accepted location architecture is revalidated before
    provisioning and does not constitute a residency or Legal conclusion.
96. **BCK-04-AC-96:** this preflight creates no Rules/IAM change, Emulator run,
    Firebase resource, deployment, activation, push or merge.

### 30.4 Unimplemented list (честно)

На момент v0.4.30 отсутствует:

- любой `.rules`/`firestore.indexes.json`/Cloud Function файл;
- data inventory за пределами формата §6.1 (сам инвентарь — предмет
  domain-specs);
- Accepted `BCK04-OD-01`; the combined-owner technical verdict and amended
  Draft v0.2 evidence are Present, while independent Security/Privacy and
  cross-boundary confirmations are absent;
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

### 30.5 Next executable step

Prepare one exact R1 security/platform slice that enumerates files, default-deny
Rules, workload identities, secret references, negative tests, rollback and
evidence commands. It must use synthetic data and keep production projects,
credentials, personal data, age-sensitive surfaces and retained Legal gates
disabled. No target artifact is authorized until that slice and G1 are
separately approved.

### 30.6 Stage 2 normalized security/privacy entity contract

All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| PrivacyRequest | Privacy owner / Privacy Orchestration | requester status projection, domain task coordinators, audited Support | immutable requestId; verified subjectId and server-resolved scope references |
| PrivacyDomainTask | Privacy owner / Privacy Orchestration task handler; owning domain mutates only its own separate records | orchestration/reconciliation projection | taskId, requestId, domain, target revision; never raw client scope |
| SecurityPolicyRevision | Security/Privacy / policy registry | Rules/IAM/config evaluators and Operations | immutable policyId/revision/hash; market/purpose/surface references where applicable |
| Consent/LegalPolicyReference | policy owner named by BCK-04 / that policy registry; Identity writes separate subject acceptance evidence | authorized product/domain checks | policyId/revision/locale/acceptedAt evidence; consent is not the only legal basis |
| SecurityAuditEvent | Security/Privacy / append-only security audit store; source controls only emit inputs | Security/Privacy and authorized incident response | eventId, actor/subject/resource IDs, UTC instant; no secret/raw payload |
| SecurityIncidentPrivacyAssessment | Platform Operations / BCK-05 incident handler records qualified Privacy input | incident timeline and statutory workflow | incidentId and assessment revision; BCK-04 defines criteria, not a second incident ledger |

Privacy requests are submitted → verified → dispatched → partially/fully
completed or honestly failed/cancelled; terminal evidence is immutable.
Forbidden transitions include client-scoped widening, resurrection after
erasure and completion before all required task evidence. Command idempotency is
subject/request-type scoped; task concurrency uses expected revision; each
domain mutation is its own transaction and orchestration never performs a
distributed write. Classification, capability matrix, holds, retention and
deletion follow §§7–20. Migration is dry-run/reconcilable; rollback never
reopens access or restores erased data without re-deletion. Security-relevant
flags fail closed. Tests include negative Rules/IAM, DSR retry/partial failure,
retention/hold, restore-resurrection, audit redaction and incident evidence.
Telemetry is privacy-safe control metadata only and is never a shadow audit or
payload store.

## 31. Stage 6 per-market compliance evidence

### 31.1 Evidence key and ownership

Compliance evidence is immutable and keyed by:

```text
environmentId
marketId: LV | EE | LT
capabilityId
purposeId
dataInventoryRevision
securityPrivacyPolicyRevision
legalDecisionRevision?
effectiveAtUtc
supersedesRevisionId?
status: pending | accepted | rejected | expired | suspended
```

BCK-04 owns the evidence format and Security/Privacy disposition. Qualified
Legal owns legal conclusions; BCK-22 owns T&S enforcement meaning; BCK-05 owns
traffic and deployment state; BCK-20 only publishes exact pointers. Missing or
expired evidence is not equivalent to `not_applicable`. A not-applicable result
must name reviewer, scope, rationale, revision and review/expiry trigger.

### 31.2 Required evidence lanes

For each enabled `market × capability`, record or explicitly disposition:

| Lane | Minimum evidence | Safe default |
|---|---|---|
| Processing | purpose, data classes, lawful-basis/consent decision, notices and processors | processing disabled |
| Residency/transfer | primary/replica/backup/log/support/subprocessor locations and transfer mechanism where applicable | personal-data path disabled |
| Age | OD-11 market/surface/purpose revision, guardian/verification decision and age-copy revision where applicable | age-sensitive surface disabled |
| UGC/DSA | qualified service-scope decision; reporting/contact/language/reason/appeal/transparency obligations mapped to BCK-22 | affected UGC create/publication disabled |
| Retention/DSR | retention/hold schedule, export/delete/restrict/rectify handlers, restore re-deletion and completion evidence | mutation disabled or data minimized until resolved |
| Support/regulatory | localized user contact, privacy/security/T&S escalation and current authority-reference source | cohort/feature disabled |
| Incident | market impact, notification/communication decision owners, evidence retention and exercised route | cohort stopped |

The matrix does not choose a numeric minimum age, declare DSA service
classification, or provide national legal advice. Those decisions remain
versioned and owner-gated. Current authority-reference discovery uses primary
sources such as the [EDPB national authority directory](https://www.edpb.europa.eu/about-edpb/our-members_en),
the [European Commission Digital Services Coordinator directory](https://digital-strategy.ec.europa.eu/en/policies/dsa-dscs)
and the [official DSA text](https://eur-lex.europa.eu/eli/reg/2022/2065); copied
names/contacts require checked-at evidence and revalidation before cohort.

### 31.3 DSR and cross-market subjects

A verified subject's request is not partitioned by `homeMarketId`, active
market, content locale or current location. Privacy Orchestration discovers all
applicable owning handlers and returns typed per-handler/per-market receipts.
Market-specific policy controls notice language, support route and lawful
exceptions; it cannot hide records from discovery or mark a partial operation
complete. Legal holds and statutory exceptions remain record-specific and
evidenced.

### 31.4 Isolation and containment

An absent/stale/non-Accepted market policy disables the smallest affected
capability. A shared IAM/Rules defect, credential exposure, schema confusion,
cross-market authorization leak, restore-resurrection risk or integrity defect
requires all affected markets to stop. BCK-05 records the actual containment
scope and rollback evidence. Security rollback never weakens Rules, restores
erased data or revives revoked grants.

This section defines reviewable controls only. It creates no qualified verdict,
production contact, account policy, processor agreement, runtime, Rules/IAM,
Firebase resource, deployment or activation.

## 32. Stage 7 exact R1 security, Rules and IAM map

### 32.1 Exact source ownership

BCK-02 §26.3 is authoritative for R1 paths. `security/actor_context.ts` defines
the server-resolved evidence shape; `authorizer.ts` is the decision port;
`default_deny_authorizer.ts` is the only R1 implementation and rejects absent,
stale, unsupported or unaccepted evidence. `app_check_port.ts`,
`rate_limit_port.ts` and `security_audit_port.ts` are supplementary ports and
cannot return product authorization.

No R1 file creates User, session, capability, verification, ManagedPage,
membership, age, consent, DSR, T&S or Admin authority. Those remain with their
owning BCKs and later exact implementation maps.

### 32.2 Rules and collection posture

`firestore.rules` retains the nine explicit RAW-C denies and the final recursive
deny. It adds explicit deny entries for the five R1 collections only to make
intent reviewable; Admin SDK access remains IAM-controlled and is not a Rules
exception. `storage.rules` remains deny-all because R1 creates no media path.

| Record family | Writer | Authorized server readers | Client |
|---|---|---|---|
| release manifests/active pointers/flag revisions | logical release/config publisher | runtime platform config reader, authorized audit/rollback | deny read/write |
| market-config revisions/activation pointers | logical reference publisher | runtime platform config reader, authorized audit/rollback | deny read/write |

No R1 collection stores end-user personal data, payload narratives, provider
credentials or secret values. Config and manifest records are Protected
operational metadata; audit/log fields are separately minimized.

### 32.3 Logical IAM ownership

The documentation names roles, not real accounts:

| Logical identity | Allowed future R1 action | Explicitly forbidden |
|---|---|---|
| `ci-build` | install, lint, typecheck, schema/test/plan validation | deploy, secret access, Firestore write |
| `ci-deploy` | later promote approved immutable artifact/config | runtime data access, secret read beyond deploy references |
| `runtime-platform` | read exact active config/manifest; emit minimized operations signals | publish config, grant capability, access product collections |
| `config-publisher` | write release/flag revision and expected pointer transaction | domain, Identity, Reference Data writes |
| `reference-publisher` | write MarketConfig revision and expected activation pointer transaction | release/flag/domain writes |
| `break-glass` | no standing access; later TTL incident grant only | permanent/wildcard grant |

Actual principal IDs, Workload Identity Federation bindings and project IAM are
absent until G1/R1 execution with real environment inputs. Human console edits
and shared dev/stage/prod principals are prohibited.

### 32.4 Exact negative evidence

The exact tests in BCK-02 §26.5 cover unauthenticated/direct client denial,
cross-environment and cross-market config reads, stale actor/config revisions,
unsupported schema, App Check without AuthZ, secret-value injection, log
redaction and storage deny-all. Emulator Admin access used by tests is scoped to
`demo-recharge` and is not production IAM evidence.

Rollback restores only a previously verified Rules/config/artifact set and
reruns all negative tests. A rollback that would reopen access, remove an
explicit RAW-C deny or restore erased/revoked authority is rejected; the
capability remains disabled.

This section adds no qualified Security/Privacy/Legal verdict and no physical
Rules, IAM, secret, source, Firebase or deployment change.

## 33. Local R1 technical-approval preflight

BCK-04 is technically consistent with the security, Rules, collection and
logical-IAM rows in BCK-02 v2.4.87 §26. Local R1 may implement only typed
security ports, fail-closed in-memory decisions, explicit deny Rules entries
and synthetic negative tests. It may not create a principal, grant, secret,
provider configuration, personal-data flow or production policy.

The owner subsequently accepted `BCK-R1-FOUNDATION-TECH-DEC-01`; Stage 8
verified the bounded local security ports, policy decisions, Rules and
disposable Emulator evidence. This closes only the local technical boundary.
Independent Security/Privacy, qualified Legal, OD-11 numeric policy,
residency/processor, real IAM/secrets and production gates remain Pending.
BCK-02 §30 is the evidence record and §31 requires every product domain to
reapply this boundary in its own exact slice.

97. **BCK-04-AC-97:** Firebase UID, opaque Session handle and internal User ID
    are separate identifiers; Booking authorization resolves the User only
    from the persisted Session bound to exact UID and installation.
98. **BCK-04-AC-98:** `privacyRequests` and `privacyDomainTasks` have one
    Firestore orchestration writer with revision CAS and atomic dispatch.
99. **BCK-04-AC-99:** Booking DSR access/restriction/erasure is executed by a
    domain handler; active future Booking blocks erasure until the cancellation
    workflow completes, and terminal records are pseudonymized atomically.
100. **BCK-04-AC-100:** Privacy tasks remain bounded to five attempts; terminal
     tasks reject later outcomes and request reconciliation requires all domain
     tasks to be terminal.
101. **BCK-04-AC-101:** all new Identity, Event-delivery and Privacy collections
     remain explicit client default-deny; this local evidence is not a
     qualified Legal/Privacy or production Security verdict.
102. **BCK-04-AC-102:** a domain erasure handler skips held records, advances its
     durable cursor, processes all eligible records and reports terminal
     `completedWithRetention` with a retained count; it may not claim full
     erasure while data remains under hold.
103. **BCK-04-AC-103:** releasing a legal/security hold leaves deletion TTL
     disabled until one linked idempotent follow-up request completes; duplicate
     release processing cannot create parallel erasure work.
