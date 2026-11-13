# Recharge Backend — Trust, Safety & Moderation Specification

- ID: **BCK-22**
- Version: **0.3.1**
- Date: **2026-09-21**
- Spec status: **Draft — Present; owner, independent Security/Privacy and Legal review pending**
- Runtime status: **Absent — local moderation previews are compatibility input only**
- Accountable owner: **Trust & Safety owner**
- Coordination baseline: [BCK-02 v2.4.81](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Delivery stage: **D3 / R8**

## 0. Changelog

### v0.3.1 — 2026-09-21

- normalized report, sanction and decision-outcome enum values to the BCK-03
  lowerCamelCase rule while retaining snake_case error/reason codes;
- preserved writers, Draft status, OD-06/OD-11 and all qualified/runtime gates.

### v0.3 — 2026-09-20

- completed the Stage 4 report-to-enforcement-to-appeal effect contract;
- fixed user block/mute, moderation case, sanction and source-domain
  enforcement acknowledgement boundaries;
- added compensating effects, reconciliation, retention/holds and privacy-safe
  audit while OD-06/OD-11 and qualified reviews remain gated.

### v0.2 — 2026-09-20

- added the Stage 2 normalized Trust & Safety entity inventory;
- separated confidential reports, user block/mute, enforcement and appeal from
  Content, Reviews and generic Admin case authority;
- normalized lifecycle, privacy, rollback, flags and evidence.

### v0.1 — 2026-09-20

- created the first canonical backend contract for reports, block/mute,
  sanctions, appeals and enforcement evidence;
- separated BCK-22 enforcement authority from BCK-19 staff workflow and from
  domain-owned content records;
- defined fail-closed UGC/market/age gates, confidentiality, audit, rollback and
  cross-domain projection reconciliation;
- preserved the requirement for qualified market-specific Legal review without
  making a legal classification claim.

## 1. Verdict and status semantics

This document is a technical/product design boundary. It is not qualified legal
advice, an independent Security/Privacy verdict, runtime evidence or permission
to enable UGC. `Draft` means unresolved OD-06, OD-11, retention, response,
staff-identity and market-policy decisions continue to block `Approved` and R8.

Current local Admin/moderation previews do not prove server authority,
confidentiality, enforcement, appeals, audit integrity, response operations or
production readiness.

## 2. Parents, priority and reconciliation

BCK-22 inherits without silently overriding:

1. Accepted ADRs and the frozen
   [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md);
2. [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md) architecture and
   [BCK-02](RECHARGE_BACKEND_DELIVERY_MAP.md) coordination;
3. [BCK-03](BACKEND_API_CONTRACT_STANDARD.md),
   [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md),
   [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md),
   [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md),
   [BCK-07](CONTENT_PUBLICATION_BACKEND_SPEC.md),
   [BCK-12](USER_LIBRARY_REVIEWS_BACKEND_SPEC.md),
   [BCK-13](NOTIFICATIONS_BACKEND_SPEC.md),
   [BCK-19](ADMIN_SUPPORT_BACKEND_SPEC.md) and
   [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md);
4. accepted product/domain specifications;
5. current local/mock UI and fixtures.

Once Approved, BCK-22 is the owning-domain specification for Trust & Safety
records and enforcement, but it still cannot override an Accepted ADR or an
Accepted cross-cutting policy. OD-06 and OD-11 remain explicit policy gates.

BCK-22 must not reinterpret legal duties. Applicable service classification,
notice/contact/response obligations, evidence retention, minor protections and
market-specific regulator/process requirements require qualified review for
the actual operating entity and enabled surface.

## 3. Outcome and non-goals

### 3.1 Outcome

BCK-22 defines one auditable lifecycle for:

- user reports against typed targets;
- user-owned block and mute relations;
- spam/rate/risk signals and bounded automated containment;
- human-reviewed enforcement decisions and sanctions;
- user notice, complaint and appeal;
- cross-domain visibility/effect instructions;
- evidence preservation, transparency metrics and emergency disable.

### 3.2 Non-goals

BCK-22 does not own:

- source content, account, Booking, payment or media records;
- generic Admin/Support cases, repair workflow or staff identity;
- publication/catalog persistence;
- qualified legal conclusions or law-enforcement disclosure decisions;
- client-only hiding as authoritative enforcement;
- unrestricted automated deletion, identity verification or age inference;
- Firebase, deployment, staffing or production activation.

## 4. Scope

### 4.1 In scope

- report intake, deduplication, triage and reporter receipt;
- block/mute create/revoke and server-side interaction filtering;
- typed target/reference resolution and evidence snapshots;
- spam/risk signals and reversible containment;
- enforcement proposal/decision/sanction lifecycle;
- notice, complaint, appeal and correction/reversal;
- confidentiality, access, retention, DSR and audit;
- cross-domain instructions and reconciliation;
- market/language routing, response tracking and transparency aggregates;
- flags, incident escalation, rollback and test evidence.

### 4.2 Disabled until later gates

- production UGC reports, sanctions and public enforcement;
- age-sensitive/Find People/review/public-planning surfaces without OD-11;
- automated permanent sanctions or content/account deletion;
- law-enforcement or regulator disclosure without approved process;
- biometric/identity inference, client-side authority and opaque scoring;
- public reporter identity or raw evidence exposure;
- market activation without OD-06 and applicable qualified review.

## 5. Ownership and single writers

| Record/projection | Authoritative writer | Consumers |
|---|---|---|
| `SafetyReport` | BCK-22 report service | T&S staff/reporting user/audit |
| `UserSafetyRelation` (block/mute) | BCK-22 relation service | Identity/Discover/interaction domains |
| `EnforcementDecision` | BCK-22 decision service | Domain enforcement adapters/audit |
| `Sanction` | BCK-22 sanction service | Authorization/projections/domains |
| `Appeal` / appeal decision | BCK-22 appeal service | Subject/T&S/audit |
| `EnforcementEvidenceRecord` | BCK-22 evidence service | Authorized reviewer/audit |
| Transparency aggregate | BCK-22 projection worker | Public/compliance owner |
| Source content/revision | Owning BCK domain | BCK-22 typed consumer |
| Generic support/admin case/access scope | BCK-19 | BCK-22 consumer/handoff |
| Staff identity/capabilities | BCK-06/BCK-19 boundary | BCK-22 consumer |
| User notice delivery | BCK-13 | BCK-22 emits minimized intent |

BCK-22 never edits another domain's source record directly. Enforcement is a
typed, revision-bound instruction consumed by the owner, followed by explicit
acknowledgement/reconciliation evidence.

## 6. Principals, capabilities and separation of duties

| Principal | Allowed | Denied |
|---|---|---|
| Authenticated reporter | Submit own report, read bounded receipt | View staff notes/reporter identities |
| User | Block/mute/unblock/unmute own relations | Global sanction authority |
| Subject | Read eligible notice, submit own appeal | Reporter/evidence identity |
| Triage reviewer | Classify/route within scope | High-impact final action without capability |
| Enforcement reviewer | Decide bounded policy action | Self-approve where dual control applies |
| Appeal reviewer | Review assigned appeal | Review own original decision where prohibited |
| Projection worker | Apply accepted instruction | Invent or widen sanction |
| Admin/Support | BCK-19 audited access/handoff | Direct BCK-22 persistence |

Capabilities are page/domain/action scoped and server resolved. High-impact or
irreversible actions require accepted dual-control policy. Break-glass follows
BCK-05/BCK-19, is time-bounded, audited and cannot erase evidence.

## 7. Data classification and confidentiality

| Data | Class | Exposure |
|---|---|---|
| Reporter identity/contact | Restricted | Need-to-know staff only |
| Report narrative/evidence | Restricted/Sensitive | Scoped review only |
| Target/subject identity | Protected | Scoped review/eligible notice |
| Block/mute relation | Private | Relation owner and enforcement services |
| Staff notes/risk signals | Restricted | No user/public projection by default |
| Sanction public effect | Public/Protected by target | Minimum necessary state only |
| Appeal content/decision | Restricted | Subject/scoped staff |
| Transparency metrics | Aggregate public | Thresholded/de-identified only |
| Audit/idempotency/outbox | Operational restricted | Audited services only |

Reporter identity is not included in subject notice, domain instructions,
analytics, general support notes or public metrics. Anti-enumeration applies to
report, evidence, sanction and appeal lookups.

## 8. Canonical model

```text
SafetyTargetRef {
  targetType, targetId, ownerDomain, sourceRevision?, marketRefs[]
}

SafetyReport {
  reportId, reporterUserId, targetRef, reasonCode, narrative?,
  evidenceRefs[], status, priority, routingMarket, routingLocale,
  dedupeGroupId?, submittedAtUtc, updatedAtUtc, revision
}

UserSafetyRelation {
  relationId, ownerUserId, subjectUserId, type, status,
  createdAtUtc, revokedAtUtc?, revision
}

EnforcementDecision {
  decisionId, reportRefs[], targetRef, policyRef, outcome,
  reasonCodes[], scope, startsAtUtc, endsAtUtc?,
  decidedByActorId, approvedByActorId?, sourceRevision,
  createdAtUtc, revision
}

Sanction {
  sanctionId, subjectRef, decisionId, type, scope, status,
  startsAtUtc, endsAtUtc?, revokedAtUtc?, revision
}

Appeal {
  appealId, appellantUserId, decisionId, groundsCode,
  statement?, evidenceRefs[], status, assignedActorId?,
  submittedAtUtc, decidedAtUtc?, revision
}

EnforcementEvidenceRecord {
  evidenceRecordId, decisionId, sourceRefs[], hashes[],
  collectionAuthority, accessClass, holdStatus,
  createdAtUtc, expiresAtUtc?
}
```

Target types and sanction/effect types are closed/versioned. Free text never
selects authority, target identity, policy or sanction scope.

## 9. Report lifecycle

```text
submitted -> acknowledged -> triaged
triaged -> investigating -> decisionPending -> resolved
triaged -> duplicate | outOfScope | rejected
resolved -> reopened (new attributable reason/evidence only)
```

Submission returns a bounded receipt without revealing enforcement details or
other reports. Duplicate grouping preserves every reporter's receipt and
original record. Withdrawal may update reporter intent but does not necessarily
erase independently required safety evidence; the applicable rule is explicit.

## 10. Block and mute semantics

`block` and `mute` are user-controlled relations, not sanctions:

- mute suppresses eligible presentation/notifications for the owner;
- block suppresses eligible bilateral discovery/contact/interaction according
  to an accepted surface matrix;
- neither silently deletes content or proves policy violation;
- create/revoke is idempotent and effective server-side for enabled surfaces;
- graph queries do not expose the blocker to unauthorized users;
- cached feeds/messages must reconcile after relation revision.

Exact effects for Discover, Find People, Reviews, Planning and Notifications are
documented in the implementation slice and default to the safer suppression.

## 11. Enforcement and sanction lifecycle

```text
proposed -> reviewRequired -> active
proposed -> rejected
active -> expired | revoked | replaced
active -> appealed -> upheld | modified | revoked
```

Allowed decision outcomes are typed: noAction, warning, visibilityLimit,
contentHide, interactionLimit, publicationSuspend, accountRestrict,
temporarySuspend, permanentActionCandidate and referral. Permanent or
legally sensitive action stays disabled until exact policy, authority,
dual-control, notice, appeal and qualified review are accepted.

Automated systems may only apply explicitly approved reversible containment
with threshold/model/rule version, expiry and human-review queue. They cannot
auto-delete source records or issue an unlimited permanent sanction.

## 12. Appeal, correction and reversal

An eligible subject receives a minimized notice with decision ID, reason
category, effect/scope, effective period, appeal path and applicable limitations.
Notice never reveals reporter identity or restricted evidence.

Appeal uses a separate record and assignment. Independence requirements are
policy-driven; a reviewer cannot decide their own appeal where prohibited.
Outcome is `upheld | modified | revoked | inadmissible` with reasons. Reversal
emits compensating instructions to every affected domain and verifies that
projections/access are reconciled. History is not rewritten.

## 13. Evidence and source snapshots

Evidence uses BCK-14 protected references or immutable bounded hashes/metadata,
not arbitrary external URLs. Intake validates type, size, malware policy,
ownership/authority and source revision. Staff views use BCK-19 scoped privileged
access and generate read audit.

A snapshot is evidence of what was reviewed, not a new source of domain truth.
Correction, deletion request, legal hold and retention conflict are represented
explicitly. No reviewer downloads or copies restricted evidence to local notes,
chat, analytics or general logs.

## 14. Commands, queries and typed outcomes

Commands:

- `SubmitSafetyReport`, `WithdrawReportIntent`, `TriageReport`;
- `CreateBlock`, `RevokeBlock`, `CreateMute`, `RevokeMute`;
- `ProposeEnforcement`, `ApproveEnforcement`, `RejectEnforcement`;
- `ActivateSanction`, `ExpireSanction`, `RevokeSanction`;
- `SubmitAppeal`, `AssignAppeal`, `DecideAppeal`;
- `AcknowledgeDomainEnforcement`, `ReconcileEnforcement`;
- registered emergency containment through BCK-05/BCK-19.

Queries:

- reporter's bounded report receipts;
- user's own block/mute relations;
- subject's eligible notices/appeals;
- capability-scoped staff queue, record and evidence access;
- enforcement status for owning domains;
- de-identified transparency aggregates.

Typed failures include:

```text
unauthenticated, permission_denied, not_found, target_unavailable,
invalid_target_type, invalid_transition, revision_conflict,
idempotency_conflict, duplicate_report, evidence_rejected,
scope_not_allowed, separation_of_duties_required, policy_unavailable,
market_disabled, age_policy_blocked, legal_review_required,
appeal_not_eligible, sanction_inactive, rate_limited,
temporarily_unavailable
```

## 15. Contract versions and compatibility

Commands carry contract/schema/policy version, operation ID and expected
revision. Report reason, target, decision, sanction, effect, notice and appeal
vocabularies are closed/versioned. Unknown values or newer policy versions fail
closed. A client must not infer a softer state from an unknown sanction.

Breaking meaning, authority, requiredness or effect changes require new version,
migration, fixtures, minimum-client policy and rollback. Historic decision
records retain the policy/version under which they were made.

## 16. Persistence, indexes and transaction boundaries

Reports, relations, decisions, sanctions, appeals, evidence records, privileged
read audit, idempotency, outbox and transparency projections are logically
separate. Required query dimensions are scoped actor/assignee, status, priority,
market, target type/ID, policy, updated time and stable cursor.

Atomic boundaries include:

- report plus reporter receipt/audit;
- relation change plus revision/outbox;
- decision plus sanction/evidence references/audit;
- appeal decision plus sanction transition/compensating outbox;
- owning-domain acknowledgement plus reconciliation state.

No transaction directly writes an owning domain's source collection.

## 17. IDs, time and reference data

- every record uses immutable server-issued ULID/UUID-style ID;
- target identity is typed ID plus owning domain and optional source revision;
- instants are UTC; deadlines/calendar obligations carry jurisdiction/timezone
  context where required;
- market, language, reason, policy and notice references are versioned BCK-20
  values or a dedicated approved policy registry;
- names, handles, email, titles and URLs never replace IDs;
- evidence hashes name algorithms and canonicalization.

## 18. Idempotency, concurrency and retries

Report, relation, enforcement, sanction and appeal mutations are idempotent by
actor/family/target. Key reuse with changed request hash fails. Optimistic
revision prevents concurrent reviewers from overwriting decisions.

High-impact approval uses explicit proposal revision/fencing. Worker retries
dedupe by event/instruction ID. Stale enforcement cannot widen or re-activate a
newer revoked/replaced sanction. Partial domain acknowledgements are visible and
reconciled; success is never reported before required atomic state commits.

## 19. Cross-domain enforcement contract

BCK-22 issues a minimized instruction containing decision/sanction ID, target,
exact effect, scope, policy revision, effective interval and instruction ID.
Owning services validate it, apply only supported effects and return an
acknowledgement with source/projection revision.

| Domain | BCK-22 effect boundary |
|---|---|
| BCK-06 Identity/Find People | interaction/account restrictions, no direct account edit |
| BCK-07 Content | publish/hide/withdraw command, no content mutation |
| BCK-08 Discover | projection suppression from accepted authority |
| BCK-09 Booking | eligibility restriction only through Booking command |
| BCK-10/11 Planning/Route | share/publication/visibility restriction |
| BCK-12 Reviews | review hide/restrict; rating projection rebuild |
| BCK-13 Notifications | minimized notice intent |
| BCK-19 Admin/Support | staff workflow/access/repair handoff |

Unsupported or stale instructions fail closed and produce reconciliation work.

## 20. Events, outbox and delivery

After Accepted OD-09 and runtime authorization, events may include:

- `safety.reportSubmitted`, `safety.reportTriaged`, `safety.reportResolved`;
- `safety.relationChanged`;
- `safety.enforcementDecided`, `safety.sanctionActivated`;
- `safety.sanctionChanged`, `safety.appealSubmitted`, `safety.appealDecided`;
- `safety.domainReconciliationRequired`.

Payloads exclude narrative, reporter identity and evidence. Outbox is atomic
with source state. Consumers dedupe, reject stale instructions and reconcile by
decision/sanction revision. Before OD-09 acceptance, async effects stay disabled
or use an explicitly approved bounded synchronous adapter.

## 21. Privacy, retention, DSR and disclosure

BCK-04 data inventory must classify each BCK-22 record and purpose. Collection
is minimized; reporter confidentiality, subject access limitations, evidence
integrity and staff need-to-know are explicit. DSR responses distinguish user
rights from restrictions necessary to protect others, investigations, security
or applicable legal duties; qualified review decides those limits.

Numeric retention for reports, evidence, sanctions, appeals, relations,
privileged reads and transparency source facts requires accepted policy before
production persistence. Legal hold is typed, scoped and audited, not an
indefinite generic flag. External disclosure requires approved authority,
verification, minimization and disclosure audit; it is disabled otherwise.

## 22. Minors and age-sensitive surfaces

OD-11 remains the source of region-versioned age/eligibility policy. BCK-22 does
not infer age from behavior or profile content. Until OD-11 and qualified review
are accepted, affected Find People, age-restricted content, Booking and UGC paths
remain disabled or constrained to a separately approved safe scope.

Minor-related reports receive restricted routing/access, minimized notice and
explicit escalation policy. Guardian/consent/verification requirements are not
invented by this document.

## 23. Market, language and response operations

Each enabled market declares operating entity, covered surfaces, policy/reason
catalog, supported notice/appeal languages, contact route, response ownership,
escalation and applicable qualified-review evidence. LV/EE/LT activate
independently; one market's decision never silently enables another.

Moderator routing supports accepted locales and typed fallback. Machine
translation may assist only under an approved privacy/provider contract and is
never the sole basis for high-impact decisions. Unresolved local requirement
disables the affected surface/market, not unrelated private product use.

## 24. Abuse, fraud and automated controls

Layered limits cover report spam, coordinated reporting, block/mute churn,
evidence upload, queue scraping, appeal abuse and staff misuse. Controls combine
actor/account/device/risk/rate signals without making App Check authority.

Automated detection records rule/model/version, inputs class, bounded reason,
confidence where applicable, expiry and review requirement. Sensitive raw input
does not enter general telemetry. False-positive monitoring and reversible
containment are mandatory before any automated effect.

## 25. Security and privileged access

Rules/IAM default deny. Staff access requires dedicated identity, least
privilege, environment separation, case/target scope, reason, TTL and immutable
read audit. Production data is not browsed through broad consoles as a normal
workflow. Exports/downloads are separately capability-gated and watermarked or
otherwise controlled according to accepted policy.

Break-glass requires registered incident, dual control where required,
time-bound access, alerting and post-review. Secrets and evidence encryption
follow BCK-04/BCK-05/BCK-14. Staff actions cannot be hidden or self-erased.

## 26. Observability, SLO, analytics and transparency

Operational metrics cover intake/triage/decision/appeal latency, queue age,
effect acknowledgement/reconciliation, duplicate/abuse rates, access failures,
privileged reads and notification failures. Logs use bounded codes and IDs; no
narrative, reporter identity, evidence or sensitive profile data.

Product analytics is separate under BCK-21. Transparency output is aggregated,
thresholded, revisioned and reviewed against re-identification risk. BCK-05 and
qualified policy owners accept numeric response/SLO/alert thresholds before R8.

## 27. Flags, rollout, rollback and emergency disable

Independent server flags cover report intake, block/mute effects, automated
containment, each sanction family, notices, appeals, transparency projection and
each surface/market. All default off until exact gates pass.

Rollback can stop intake or new enforcement, disable a faulty effect adapter,
revoke/replace policy, replay compensating instructions and rebuild projections.
It does not erase reports/decisions or silently restore unsafe content. Emergency
hide is reversible, scoped, expiring and followed by mandatory review.

## 28. Migration and compatibility

Local moderation/admin preview records are not production authority and are not
bulk imported as sanctions. Any eligible historical user block/mute import
requires explicit user/account binding, dry-run, mapping, dedupe, disclosure and
rollback. Unknown targets/policies remain blocked.

Policy migration preserves original decision evidence and creates replacement
records/instructions. Projection rebuild is deterministic from active accepted
sanctions/relations. Client caches invalidate by revision and cannot override a
server restriction.

## 29. Conditional implementation file map

No runtime file is authorized by this specification alone. An Approved slice
may create:

```text
packages/api_contracts/schemas/trust_safety/
packages/api_contracts/fixtures/trust_safety/
apps/backend/functions/src/modules/trust_safety/domain/
apps/backend/functions/src/modules/trust_safety/application/
apps/backend/functions/src/modules/trust_safety/data/
apps/backend/functions/src/modules/trust_safety/transport/
apps/backend/functions/src/modules/trust_safety/workers/
apps/backend/functions/test/contract/trust_safety/
apps/backend/functions/test/emulator/trust_safety/
apps/mobile/lib/features/reporting/data/remote/
```

BCK-19 owns staff-case/access tooling, BCK-14 owns evidence blobs and owning
domains own their effect adapters. Generated files are generator-only.

## 30. Test and evidence matrix

| Area | Required evidence |
|---|---|
| Domain | report/sanction/appeal/relation lifecycle and invariants |
| Contract | schemas, closed vocabularies, version/unknown-value failure |
| Authorization | reporter/subject/reviewer/appeal/staff/worker capabilities |
| Confidentiality | reporter/evidence/non-enumeration/log/notice allowlists |
| Separation | proposal/approval/appeal independence and break-glass |
| Concurrency | duplicate report, stale decision, sanction replacement/replay |
| Cross-domain | effect application, stale/unsupported, compensation/rebuild |
| Emulator | transactions, indexes, Rules/IAM, outbox and acknowledgements |
| Privacy/DSR | access/export/erasure/restriction/hold/disclosure |
| Abuse | coordinated reports, upload/rate attacks and staff misuse |
| Resilience | worker/notification outage, poison event, partial reconciliation |
| Baltic | LV/EE/LT flags, routing, locales and market isolation |
| Load/SLO | report bursts, queues, response thresholds and cost budgets |
| Tabletop | emergency containment, appeal reversal, breach/access incident |

Unrun, timed-out, unsigned or environment-blocked evidence is `Inconclusive`.

## 31. Dependency and delivery gates

BCK-22 Approval requires applicable BCK-03/04/06/07/12/19/20 boundaries,
Accepted OD-06, accepted OD-11 for age-sensitive scope, Trust & Safety owner
verdicts, independent Security/Privacy review and qualified Legal review for
enabled markets/surfaces.

R8 additionally requires dedicated staff identity, BCK-19 access/workflow,
BCK-13 notice path where required, green contract/emulator/security/load tests,
trained operational ownership, exercised rollback/incident procedures and
server flags default-off. Approval alone authorizes no runtime.

## 32. Definition of Ready

BCK-22 is ready for formal review when:

- target/effect/policy ownership and domain handoffs are reconciled;
- OD-06/OD-11 owners and qualified/independent reviewers are named;
- each market/surface has explicit disabled default;
- data inventory, retention, evidence and access classes are complete;
- every open decision has owner, fail-closed default and required gate.

## 33. Definition of Done

BCK-22 becomes `Approved` only after attributable current verdicts, accepted
blocking policy decisions, exact contracts/slices, traceable tests/evidence and
atomic BCK-01/BCK-02/LAUNCH_STATUS reconciliation. Runtime Done is separate and
requires implementation, operations, drills, rollback and activation authority.

## 34. Acceptance criteria

1. **BCK-22-AC-01:** BCK-22 owns reports, relations, sanctions and appeals.
2. **BCK-22-AC-02:** Source-domain records remain owned by their BCK modules.
3. **BCK-22-AC-03:** BCK-19 owns staff workflow, not enforcement truth.
4. **BCK-22-AC-04:** Enforcement uses typed revision-bound domain instructions.
5. **BCK-22-AC-05:** No console/client directly writes enforcement records.
6. **BCK-22-AC-06:** Reporter identity is restricted and never public.
7. **BCK-22-AC-07:** Subject notice never reveals reporter/restricted evidence.
8. **BCK-22-AC-08:** Anti-enumeration covers report/evidence/sanction/appeal.
9. **BCK-22-AC-09:** Target identity is typed ID plus owning domain.
10. **BCK-22-AC-10:** Names, handles, email and URLs never replace identity.
11. **BCK-22-AC-11:** Report submission returns a bounded receipt.
12. **BCK-22-AC-12:** Duplicate grouping preserves every original report.
13. **BCK-22-AC-13:** Reporter withdrawal does not silently destroy evidence.
14. **BCK-22-AC-14:** Block/mute are user relations, not sanctions.
15. **BCK-22-AC-15:** Block/mute effects are enforced server-side per matrix.
16. **BCK-22-AC-16:** Relation queries do not disclose unauthorized graph data.
17. **BCK-22-AC-17:** High-impact actions enforce accepted separation of duties.
18. **BCK-22-AC-18:** Staff capability/scope is server resolved and revocable.
19. **BCK-22-AC-19:** Automated action is bounded, reversible and expiring.
20. **BCK-22-AC-20:** Automation cannot permanently delete/sanction by default.
21. **BCK-22-AC-21:** Every decision pins policy and source revision.
22. **BCK-22-AC-22:** Published effects have exact scope and time bounds.
23. **BCK-22-AC-23:** Appeal is a separate immutable workflow.
24. **BCK-22-AC-24:** Prohibited self-review is enforced by policy/tests.
25. **BCK-22-AC-25:** Reversal emits compensating instructions everywhere.
26. **BCK-22-AC-26:** History is superseded, never silently rewritten.
27. **BCK-22-AC-27:** Evidence uses protected IDs/hashes, not arbitrary URLs.
28. **BCK-22-AC-28:** Evidence access creates immutable privileged-read audit.
29. **BCK-22-AC-29:** Restricted evidence never enters notes/logs/analytics.
30. **BCK-22-AC-30:** Contract/policy/reason/effect vocabularies are versioned.
31. **BCK-22-AC-31:** Unknown newer policy/effect fails closed.
32. **BCK-22-AC-32:** Breaking changes require migration/client evidence.
33. **BCK-22-AC-33:** Report/decision/appeal transactions are atomic.
34. **BCK-22-AC-34:** BCK-22 never writes owning-domain collections directly.
35. **BCK-22-AC-35:** Mutation idempotency detects changed request hashes.
36. **BCK-22-AC-36:** Stale instructions cannot widen/reactivate sanctions.
37. **BCK-22-AC-37:** Partial domain acknowledgements remain visible/reconciled.
38. **BCK-22-AC-38:** Outbox payload excludes narrative/reporter/evidence.
39. **BCK-22-AC-39:** Event consumers dedupe and validate source revision.
40. **BCK-22-AC-40:** Async effects remain disabled before OD-09.
41. **BCK-22-AC-41:** Retention is accepted before production persistence.
42. **BCK-22-AC-42:** Legal hold is scoped, typed, expiring/reviewable.
43. **BCK-22-AC-43:** External disclosure requires verified approved authority.
44. **BCK-22-AC-44:** OD-11 gates every age-sensitive enabled scope.
45. **BCK-22-AC-45:** BCK-22 never infers age from content/behavior.
46. **BCK-22-AC-46:** Markets activate independently with fail-closed defaults.
47. **BCK-22-AC-47:** Notice/appeal languages and fallback are explicit.
48. **BCK-22-AC-48:** Machine translation alone cannot decide high impact.
49. **BCK-22-AC-49:** App Check never replaces AuthN/AuthZ/abuse controls.
50. **BCK-22-AC-50:** Coordinated-report and staff-abuse controls are tested.
51. **BCK-22-AC-51:** Logs exclude narratives, reporter IDs and evidence.
52. **BCK-22-AC-52:** Product analytics is separate from operational telemetry.
53. **BCK-22-AC-53:** Transparency metrics are aggregate and de-identified.
54. **BCK-22-AC-54:** SLO/response thresholds require accepted owners/evidence.
55. **BCK-22-AC-55:** Each risky effect/surface/market has default-off flag.
56. **BCK-22-AC-56:** Emergency hide is scoped, reversible and reviewed.
57. **BCK-22-AC-57:** Rollback preserves records and compensates projections.
58. **BCK-22-AC-58:** Local preview data is never imported as authority.
59. **BCK-22-AC-59:** LV/EE/LT fixtures prove routing and market isolation.
60. **BCK-22-AC-60:** Documentation acceptance claims no legal/runtime authority.

## 35. Explicit unimplemented list

- API schemas, fixtures and generated clients;
- backend T&S domain, persistence, indexes, Rules/IAM and workers;
- staff identity/access, case handoff and privileged-read UI;
- report/block/mute/appeal mobile remote adapters;
- notification, evidence, domain enforcement and transparency integrations;
- OD-06/OD-11 policy, qualified review, staffing, SLO and market activation.

## 36. Owner decisions required

| Decision | Owner | Fail-closed default | Required before |
|---|---|---|---|
| OD-06 enforcement levels/appeal/response | T&S owner | UGC cohort disabled | Approval/R8 |
| OD-11 age/minors eligibility | Security/Privacy + qualified Legal | affected surface disabled | Age-sensitive scope |
| Report/evidence/sanction retention | Privacy/Legal | no production persistence | Persistent stage |
| Staff roles and dual-control matrix | T&S + Admin + Security | high-impact actions disabled | Runtime |
| Market/entity/contact/response policy | Market/Legal/Operations | market disabled | Activation |
| Block/mute effects per surface | Product/domain owners | safer suppression/no enablement | Runtime slice |
| Automated containment threshold/scope | T&S + Security | automation disabled | Automation slice |
| Transparency threshold/re-identification | Privacy/Legal/Data | no public output | Reporting |

## 37. Final statement

BCK-22 defines a complete technical Trust & Safety boundary: confidential
reports, user block/mute, accountable enforcement, appeal and cross-domain
reconciliation without taking ownership of source content or generic staff
workflow. It does not authorize Firebase, UGC activation, automated permanent
action or any legal/compliance claim.

## 38. Stage 2 normalized Trust and Safety entity contract

All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| Report | Trust & Safety / report intake handler | assigned reviewers and bounded reporter status | reportId + reporter/subject/resource IDs + policy revision; confidential |
| BlockRelation | Trust & Safety / user safety relation handler | interaction/discovery/message eligibility checks | blockerId + blockedId + revision; directional |
| MuteRelation | Trust & Safety / user preference safety handler | feed/notification filters | muterId + muted subject ID + revision; not enforcement |
| EnforcementCase | Trust & Safety / enforcement workflow | authorized reviewers/Admin integration | caseId + subject/resource/policy/evidence refs |
| Sanction | Trust & Safety / sanctioned decision handler | Identity/Content/Discover/Booking capability consumers | sanctionId + scope/effective/expiry/policy revision |
| Appeal | Trust & Safety / appeal handler | appellant status and independent reviewer | appealId + sanction/caseId + revision |
| ModerationEvidence | Trust & Safety / evidence vault metadata writer; Media owns blobs | case/appeal reviewer and audit | evidenceId + source/resource/media refs + integrity hash |

Reports move submitted → triaged → investigating → resolved/dismissed;
enforcement moves proposed → approved/applied → expired/revoked/superseded;
appeals are independent states. Reporter disclosure, client sanction, permanent
automatic action without policy, block-as-global-sanction and direct source
content rewrite are forbidden. Commands use actor/subject/resource/policy
idempotency and expected revision; case/sanction/outbox commit atomically while
owning domains apply typed effects. Classification, anti-enumeration, reviewer
capabilities, retention/holds/deletion and audit follow BCK-04/06. Telemetry
excludes report/evidence content. Migration preserves case chain/integrity;
rollback revokes/adjusts sanction and rebuilds projections without deleting
history. Report/enforcement/automation/market flags default off. Evidence covers
confidentiality, cross-scope denial, duplicate reports, block/mute behavior,
appeal independence, policy/version changes, age gates, rollback and audit.

## 39. Stage 4 safety effects, acknowledgements and appeals

### 39.1 User safety relations and cases

Block and mute are directional user-owned safety relations with distinct
effects; they are not sanctions, identity roles or public social graph. Reports
are confidential intake records and never expose reporter identity to the
subject. Duplicate grouping may share triage but preserves every original
report and receipt. Review/content/Booking/Admin records remain owned by their
source modules and are referenced by exact ID/revision.

### 39.2 Enforcement effect protocol

An approved sanction creates scoped, time-bounded, policy-versioned effect
instructions for named consumer domains. Each instruction carries effectId,
case/decision/sanction IDs, target ID/revision, scope, effective/expiry times,
reason code and required acknowledgement deadline. Consumers reauthorize,
apply idempotently and return `applied`, `already_applied`, `stale`, `unsupported`
or `denied`. Partial acknowledgement is visible reconciliation state; BCK-22
does not directly edit Content, Review, Identity, Booking or Discover storage.

Revocation, expiry or successful appeal emits a compensating instruction with
the original effect identity chain. It may restore eligible visibility/access
through the owning domain but never deletes decision history or bypasses a
newer independent restriction.

### 39.3 Appeal and separation of duties

Appeal is a separate immutable workflow with reviewer independence appropriate
to impact. The original decision maker cannot self-approve a required
independent appeal. High-impact or permanent action remains disabled until
OD-06, applicable OD-11, qualified Legal/Privacy and separation-of-duties policy
are Accepted. Automated signals may prioritize or apply only accepted bounded,
reversible and expiring measures; AI/analytics is never decision authority.

### 39.4 Retention and privacy

Report narrative, reporter mapping, evidence metadata/bytes, case work,
decision, sanction, appeal, consumer acknowledgement, privileged-read audit and
transparency aggregate are distinct classes. Legal/safety holds are scoped,
reviewable and expiring. Notices/outbox exclude reporter identity, narratives
and evidence. Deletion cannot erase required restricted evidence prematurely
or keep a public sanction active after lawful revocation.

### 39.5 Additional acceptance criteria

61. **BCK-22-AC-61:** Block and mute remain directional relations, not sanctions/roles.
62. **BCK-22-AC-62:** Duplicate triage preserves every original report and receipt.
63. **BCK-22-AC-63:** Source records are referenced by exact owning-domain ID/revision.
64. **BCK-22-AC-64:** Every sanction effect pins case, decision, policy, target, scope and time bounds.
65. **BCK-22-AC-65:** Consumers apply effects idempotently and return typed acknowledgements.
66. **BCK-22-AC-66:** Partial/stale/unsupported acknowledgements remain visible reconciliation state.
67. **BCK-22-AC-67:** BCK-22 never directly writes source-domain storage.
68. **BCK-22-AC-68:** Revocation/expiry/appeal uses compensating instructions.
69. **BCK-22-AC-69:** Compensation cannot bypass a newer independent restriction.
70. **BCK-22-AC-70:** Appeal is immutable and enforces required reviewer independence.
71. **BCK-22-AC-71:** High-impact/permanent action remains disabled until named policy/review gates.
72. **BCK-22-AC-72:** AI/analytics may signal or prioritize but never decide enforcement.
73. **BCK-22-AC-73:** Reports, evidence, sanctions, appeals, acknowledgements and audit have distinct retention classes.
74. **BCK-22-AC-74:** Notices/outbox exclude reporter identity, narratives and evidence.
75. **BCK-22-AC-75:** v0.3.1 authorizes no UGC activation, automation, Firebase or deployment.
