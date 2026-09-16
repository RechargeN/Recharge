# BCK-04 — Security & Privacy Coverage Matrix

- ID: **BCK-04-PRE**
- Version: **0.3.23**
- Date: **2026-09-15**
- Status: **Draft — preparatory audit artifact**
- Runtime status: **N/A; no runtime authority**
- Accountable owner: **Security/Privacy owner**
- Target document: [BCK-04 v0.4.23](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.61](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical repository path: `docs/product/BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md`

---

## 0. Назначение

### v0.3.23 threat-model technical-verdict reconciliation

Current anchors are BCK-01 v0.4.57, BCK-02 v2.4.61, BCK-03 v0.3.14,
BCK-04 v0.4.23, BCK-05 v0.2.30 and BCK-20 v0.2.9.
BCK04-OD01-DEC-01 records the combined-owner technical verdict and amended
threat-model v0.2. BCK04-OD-01 remains Proposed pending independent
Security/Privacy review and required cross-boundary confirmations.

### v0.3.22 BCK-04 technical owner-verdict reconciliation

Current anchors are BCK-01 v0.4.56, BCK-02 v2.4.60, BCK-03 v0.3.13 and
BCK-04 v0.4.22. BCK04-SEC-DEC-01 records the combined-owner technical verdict
and its fourteen amendments. BCK-04 remains Draft; BCK04-OD-01/09,
independent Security/Privacy, qualified Legal, OD-11 and runtime gates remain
unresolved.

### v0.3.21 API Mobile-boundary reconciliation

Current anchors are BCK-01 v0.4.55, BCK-02 v2.4.59, BCK-03 v0.3.12 and
BCK-04 v0.4.21. BCK03-MOB-DEC-01 accepts only the BCK-03 Mobile boundary;
BCK-04 owner/independent/Legal verdicts and runtime remain unchanged.

### v0.3.20 API Security-boundary reconciliation

Current anchors are BCK-01 v0.4.54, BCK-02 v2.4.58, BCK-03 v0.3.11,
BCK-04 v0.4.20 and BCK-09 v1.13. BCK03-SEC-DEC-01 accepts only the BCK-03
Security/Privacy boundary amendments. It does not accept BCK-04, its threat or
incident decisions, independent review or qualified Legal evidence.
Product/cloud Security runtime remains Absent and no BCK-04 status is promoted.

Эта матрица доказывает полноту BCK-04 относительно обязательной структуры
`BCK-02 §14` и фиксирует reconciliation до перевода BCK-04 в Review. Она не
является альтернативной security/privacy specification, не принимает Open
решения и не разрешает создание `apps/backend`, Firebase resources,
credentials, production data processing или любой runtime-код.

Revision v0.3.16 records BCK05-OD-07 Acceptance at
`BCK05-REL-A1-DUAL-PROV-v1` with controls without treating provenance policy
as executable evidence. It retains the Authentication US/global-service disclosure and
preserves qualified Legal/Privacy production review as a separate gate. BCK-04
remains Draft; executable IAM/cloud, owner, qualified Legal/Privacy and
executed/passed tabletop evidence remain blocked.

## 1. Проверенный baseline

| Источник | Фактический статус в tracked checkout | Роль в reconciliation |
|---|---|---|
| Accepted ADR 0013, 0015, 0019 | Accepted | Непереопределяемые identity, capability и Booking authority invariants |
| BCK-01 | Review v0.4.57, Present; bounded R0/RAW-C local source, product/cloud runtime Absent | Parent backend architecture и cross-cutting invariants |
| BCK-02 | Approved v2.4.61; runtime N/A | Registry, owners, dependencies, gates и обязательная структура |
| BCK-03 | Draft v0.3.14, Present; API/Operations/Security/Mobile boundary reviews Accept with required amendments; independent reviews Pending | API envelope/versioning/idempotency input; Booking-v1 accepted scope preserved, broader decisions Deferred |
| BCK-05 | Draft v0.2.30, Present; local R0 plus disabled RAW-C evidence boundary; BCK05-OD-01/02/07 and cross-domain OD-07 Accepted | Operations/IAM/release/OD-07/SLO/cost/recovery/numeric-review/incident evidence input, ещё не Approved |
| BCK-20 | Draft v0.2.9, Present; BCK-03 Mobile and BCK-04/threat-model technical verdicts do not accept BCK-20; runtime Absent | Market/reference/localization input, ещё не Accepted |
| BCK-09 | Review v1.13; disabled Emulator-only RAW-C Present, cloud/mobile runtime Absent | Booking-specific transaction/security input, ещё не Approved |
| Identity/Publisher spec | Approved v1.3, bounded local/mock scope | Identity semantics; не production authority |
| Firebase Architecture | Proposed v2.2 | Proposed input only; не наследуется как settled решение |
| BCK-04 | Draft v0.4.23; BCK-04 and threat-model combined-owner technical verdicts recorded; bounded local evidence Present, product/cloud runtime Absent; BCK04-OD-01/09 Proposed | Единственный target security/privacy contract; owner verdict is not independent/Legal/OD acceptance |
| BCK04-OD01-TM-01 | Draft v0.2; runtime N/A | 49 classified threats with owners/gates/residual states; combined-owner technical verdict Present; OD-01 Proposed pending independent/cross-boundary evidence |
| BCK04-OD09-IR-01 | Draft v0.1; runtime N/A | Incident/severity/privacy-risk evidence; OD-09/BCK05-OD-08 Proposed |
| BCK04-OD09-TTX-01 | Ready v0.1; not executed; runtime N/A | Repeatable tabletop package; no result or gate closure |

Версии в этой таблице являются repository facts на дату ревизии. Изменение
статуса источника требует обновить BCK-02 и перепроверить BCK-04; оно не
происходит автоматически по ссылке из этой матрицы.

## 2. Coverage matrix — 22 обязательных пункта

| № | Требование `BCK-02 §14` | Покрытие BCK-04 v0.4.23 | Evidence / остаток |
|---:|---|---|---|
| 1 | ID/version/date/status/runtime/owner | Полное | Header |
| 2 | Parent sources, anchors, conflict priority | Полное | §3; Accepted ADR выше Draft/Proposed inputs |
| 3 | Product outcome, measurable non-goals | Полное | §2, §4.2 |
| 4 | Included/excluded scope | Полное | §4 |
| 5 | Aggregate, writer, consumer ownership | Полное на design level | §20.2, §28: Privacy Orchestration — один writer собственных records; domain handlers владеют domain data |
| 6 | Data classes and projections | Полное | §7; пять canonical classes; analytics/audit — record-kind/purpose labels |
| 7 | Commands, queries, events, typed errors | Полное на semantic level | §20.2; shared envelope наследуется от BCK-03 и блокируется его reconciliation |
| 8 | Schema/API/event versions and compatibility | Полное на policy level | §20.2, §28; exact transport format остаётся `BCK04-OD-08` |
| 9 | Authorization/capabilities/revocation | Полное | §8–§11 |
| 10 | Persistence/index/source/transaction boundaries | Полное на target level | §12, §20.2, §28; physical resources отсутствуют |
| 11 | IDs/references/time/reference data | Полное | §20.2: ULID, UTC, IANA, market; Accepted shared invariants не переопределяются |
| 12 | Idempotency/concurrency/retries/partial failure | Полное на semantic level | §11.3, §20.2; split-key conflict closed by BCK-D1-DEC-01, executable evidence remains gated |
| 13 | Offline/cache/freshness/degraded state | Полное | §20.2: offline intent не submitted; partial/cancelled typed states |
| 14 | Migration/import/compatibility | Полное как policy boundary | §4, §20.2, §28; no migration runtime in this slice |
| 15 | Outbox/delivery/replay/deduplication | Полное на semantic level | §20.2; cross-domain notification follows Accepted future OD-09 |
| 16 | Privacy/consent/retention/rights/Legal | Полное на Draft-contract level | §17–§21; Open Legal decisions listed in §27 |
| 17 | Abuse/rate limit/App Check/fraud | Полное | §13, §16; additional numeric limits delegated to BCK-05 |
| 18 | Logs/SLO/alerts/analytics/cost | Полное по границе ответственности | §14, §23–§26; BCK-05 owns operational SLO/cost, BCK-21 product analytics |
| 19 | Flags/rollout/rollback/emergency disable | Полное | §22, §24–§26; no runtime enablement |
| 20 | Exact implementation file map | Полное как target plan | §28; every path is future/conditional, not present-runtime evidence |
| 21 | Test matrix | Полное как future evidence plan | §29 |
| 22 | Sequential AC, DoR/DoD, unimplemented list | Полное | §30; AC-01…AC-64 sequential |

**Coverage verdict:** 22/22 sections are addressed. This means the Draft is
structurally complete; it does **not** mean its Open decisions are Accepted or
its runtime exists.

## 3. Reconciliation contract

Перед Review и повторно перед Approved должны выполняться все условия:

1. Каждая ссылка указывает на существующий tracked file и честно называет его
   spec/runtime status.
2. Accepted ADR нельзя ослабить BCK-04, BCK-03, BCK-09 или Proposed Firebase
   design.
3. Для каждого authoritative record type существует ровно один writer;
   Privacy Orchestration координирует права субъекта, но не становится writer
   Booking, Identity, Content, Media, Analytics или Audit данных.
4. Auth identity, active workspace и server-resolved capabilities не принимаются
   из client payload.
5. Public, Protected, Sensitive, Operational и Derived records не смешиваются;
   classification назначается по фактическому содержимому record family.
6. Retention задаётся по record family и lifecycle trigger, а не одной цифрой
   на весь data class.
7. Unknown/newer policy/schema fails closed; silent downgrade запрещён.
8. Privacy requests имеют requester verification, idempotency, per-domain task
   evidence, typed partial/degraded outcome и immutable completion evidence.
9. Rights eligibility не обобщается: access, rectification, erasure,
   restriction, portability и objection проверяются отдельно.
10. Article 19 recipient propagation и применимые Article 22 decisions имеют
    собственное evidence; client-side acknowledgement не является completion.
11. Cross-domain effects используют единый будущий event/outbox contract;
    dual write и fire-and-forget не допускаются.
12. OD-07/OD-11 и BCK04-OD decisions остаются fail-closed до принятия owner.
13. Runtime status подтверждается только файлами, deployed resources и test/
    operational evidence; наличие target path в §28 не является реализацией.
14. LAUNCH_STATUS обновляется по факту и не повышает spec status.

Нарушение writer authority, privacy eligibility, retention, idempotency,
irreversible infrastructure или Accepted ADR является блокером Review/Approved,
а не редакционным замечанием.

## 4. Decision/status reconciliation

| Объект | Статус для BCK-04 v0.4.23 | Что запрещено утверждать |
|---|---|---|
| ADR 0013/0015/0019 | Accepted | Что BCK-04 может изменить их инварианты |
| D05 Booking authoritative source | Accepted decision package input | Что BCK-04 создаёт новую Booking authority |
| ECL03-D04 Booking retention | Accepted product policy; Privacy/Legal production validation remains open | Что числа уже Legal-approved, active или cross-domain normative |
| BCK-03 API rules | Draft input; D1 split-key conflict resolved | Что весь BCK-03 уже Approved или implemented |
| BCK-09 transaction plan | Review input | Что Booking runtime/Firebase существует |
| Firebase Architecture §8/§11 | Proposed input | Что Rules/IAM detail settled |
| BCK04-OD-01 | Proposed; amended v0.2 and combined-owner technical verdict Present; independent/cross-boundary confirmations pending | Что технический owner verdict автоматически Accepted OD или independent evidence |
| BCK04-OD-09 | Proposed incident model and ready tabletop package; owner/qualified Legal/executed-result verdict pending | Что readiness package автоматически является проведённым учением, Accepted или operationally ready |
| BCK04-OD-02…08, 10…14 | Open until recorded owner decision | Что recommendation или default автоматически Accepted |

## 5. Блокеры до Review

Resolved prerequisites:

- `PRE-01`: BCK-01 v0.4.57 remains in Review and BCK-02 v2.4.61 records the status;
- `PRE-02`: `RechargeN / Product owner` is recorded as interim review
  coordinator. This does not resolve the independent specialist ownership
  required for Legal/Privacy decisions or Approval/G1.
- `PRE-03`: BCK-D1-DEC-01/ECL03-D11 reconciles BCK-03, BCK-09 and committed
  Booking fixtures on one split-key contract.
- `PRE-03A`: OD-07 is Accepted through its exact decision record and OD-11 has
  a reviewable Legal package; OD-11 remains Open and neither artifact satisfies
  the missing qualified production decisions.

| ID | Блокер | Owner | Exit evidence |
|---|---|---|---|
| PRE-03B | Combined-owner technical BCK-03 and BCK-04 verdicts recorded; independent Security/Privacy and qualified Legal verdicts absent | Independent Security/Privacy + qualified Legal/Privacy reviewers where required | Completed independent BCK-04 and D1-SIG-LEGAL review records in [BCK-D1-SIG-01](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md) |
| PRE-03C | Amended threat-model v0.2 and combined-owner technical verdict are Present; OD-01 remains Proposed because independent Security/Privacy and API/Operations/Identity/Mobile/domain confirmations are absent | Independent Security/Privacy plus named boundary owners | Exact independent review and cross-boundary confirmation records against [BCK04-OD01-TM-01 v0.2](BACKEND_SECURITY_THREAT_MODEL.md) |
| PRE-03D | Incident-response evidence and tabletop package are Present; OD-09 is Proposed, but owner/qualified Legal verdict and executed/passed result remain absent | Security/Privacy + Legal/Privacy + Operations | Accepted review plus completed [BCK04-OD09-TTX-01](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md) record against exact versions |
| PRE-04 | ECL03-D04 product status reconciled; exact production retention/backup validation and rights interface remain open | Booking + Security/Privacy + Legal + API Platform | BCK04-OD-07/BCK04-OD-08 decisions and Legal/Privacy evidence |
| PRE-05 | OD-07 engineering topology is Accepted; age policy and qualified production residency/transfer conclusions are not | Platform + Security/Privacy + Legal | Preserve OD-07 controls; move OD-11 to the gate-required status and record qualified Legal/Privacy evidence |
| PRE-06 | Incident model Proposed; owner/Legal/tabletop evidence plus ROPA/DPIA and processor/transfer policy remain open | Security/Privacy + Legal + Operations | BCK04-OD-09…14 decisions and evidence templates |

## 6. Acceptance criteria матрицы

1. Все 22 пункта `BCK-02 §14` имеют одну строку и проверяемую ссылку.
2. Нет `N/A` для обязанностей собственного Privacy Orchestration module.
3. Все source statuses совпадают с tracked checkout и BCK-02 registry.
4. Ни Draft, ни Review, ни Proposed input не назван Accepted.
5. У каждого blocker есть accountable role и exit evidence.
6. Runtime status явно остаётся Absent/N/A; target paths не считаются файлами.
7. AC и Open Decisions BCK-04 проверены на последовательность и уникальность.
8. Матрица не создаёт отдельные privacy entities или rules вне BCK-04.
9. Проверка local links и `git diff --check` проходит.
10. Любое последующее изменение BCK-04 обновляет эту матрицу в той же ревизии
    либо явно фиксирует, почему coverage не изменилось.

## 7. Итог

BCK-04 v0.4.23 структурно покрывает обязательный template и готов к предметному
architecture/legal review после устранения §5 blockers. Физическая реализация,
provisioning и production processing по-прежнему не разрешены.
