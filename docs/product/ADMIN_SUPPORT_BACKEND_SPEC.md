# Recharge Backend — Admin & Support Specification

- ID: **BCK-19**
- Version: **0.2**
- Date: **2026-08-26**
- Spec status: **Review — documentation only; approval pending**
- Runtime status: **Absent**
- Accountable owner: **Admin Operations owner**
- Review owners: **Security/Privacy, Platform Operations, Identity, API
  Platform, owning-domain owners, Trust & Safety, Mobile, Support and Legal/Privacy**
- Markets: **Latvia first; Estonia and Lithuania prepared but independently gated**
- Coordination baseline: [BCK-02 v2.4.39](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Coverage evidence: [BCK-19-PRE v0.2](BACKEND_ADMIN_SUPPORT_COVERAGE_MATRIX.md)
- Canonical path: `docs/product/ADMIN_SUPPORT_BACKEND_SPEC.md`
- Runtime effect of this revision: **none**

## 0. Changelog

### v0.2 — 2026-08-26

- completed all 22 mandatory BCK-02 design categories and promoted the document
  to Review;
- established one Admin/Support owner for cases, case-scoped privileged-read
  audit and propose/approve/execute repair orchestration;
- preserved Identity/IAM, owning-domain, Privacy, Trust & Safety, Notifications
  and Platform Operations single writers;
- recorded 60 acceptance criteria and ten owner decisions without authorizing
  Firebase, production access, direct data writes, deployment or runtime.

### v0.1 — 2026-08-26

- created a documentation-only draft from BCK-01/02/03/04/05/06/13, Accepted
  IAM controls and current local Admin-preview/Route-moderation evidence;
- separated support tooling from publisher/workspace impersonation, moderation
  authority, break-glass IAM and domain record ownership.

## 1. Verdict and status semantics

BCK-19 defines the target Admin & Support authority for Recharge. It is ready
for cross-owner Review, not Approval or implementation. Runtime is **Absent**.

The current Flutter application contains a local/mock Admin experience preview,
mock Admin capabilities and local/in-memory Route moderation and safety queues.
Those are useful UX and compatibility evidence only. They are not privileged
identity, production Support access, immutable audit, two-person repair,
Trust & Safety authority or backend implementation.

Review, Approval, executable slice, emulator proof, stage access, production
access and market enablement are independent. Nothing here creates a staff
account, assigns IAM, provisions Firebase/GCP, exposes user data, changes mobile
code, deploys a handler, pushes a branch or merges `main`.

## 2. Parents, priority and reconciliation

Priority is:

1. Accepted ADR;
2. Approved owning-domain specification;
3. BCK-02 coordination and BCK-01 architecture;
4. this BCK-19 contract;
5. Proposed architecture and implementation notes.

Normative inputs:

- [BCK-03](BACKEND_API_CONTRACT_STANDARD.md): registered commands, typed
  failures, versions, split request/idempotency keys and bounded payloads;
- [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md): dedicated privileged identity,
  MFA, case/reason, anti-enumeration, data classes, read audit, DSR and retention;
- [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md): environment isolation,
  operations registry, flags, incident, recovery and emergency containment;
- [IAM model](BACKEND_IAM_WORKLOAD_IDENTITY_MODEL.md): Accepted policy for
  environment-local identities, no blanket impersonation, JIT/break-glass and
  two-person production controls, while executable IAM remains absent;
- [BCK-06](IDENTITY_PUBLISHER_BACKEND_SPEC.md): staff principal/capability,
  session/revocation and privileged domain-review boundaries;
- [BCK-13](NOTIFICATIONS_BACKEND_SPEC.md): inbox/delivery authority for
  notifications produced after accepted case/domain facts;
- [BCK-18](MOBILE_BACKEND_INTEGRATION_STANDARD.md): typed client seam and no
  direct Firestore authority.

BCK-22 remains Planned and owns reports, sanctions, block/mute, appeals and
moderation enforcement. BCK-19 may host a staff-facing navigation shell or
reference a BCK-22 case, but cannot decide or duplicate Trust & Safety state.

RUN-03 is a downstream runbook built from BCK-19 and implemented domain repair
commands. BCK-19 does not depend on a runbook that cannot yet exist. Conversely,
BCK-19 Review does not satisfy the G5 requirement for an executed RUN-03 drill.

## 3. Outcome and non-goals

### 3.1 Outcome

Provide one provider-neutral contract that:

- records bounded Support/Admin cases and assignments;
- authorizes privileged reads only through case-, purpose- and field-scoped views;
- audits every sensitive/protected reveal and privileged mutation attempt;
- prepares immutable repair proposals with dry-run and precondition evidence;
- enforces distinct approval and trusted domain execution;
- records exact execution receipts and reconciliation outcomes;
- invokes server flags/emergency containment without owning the flags;
- supports revocation, retention, DSR, recovery, abuse detection and review.

### 3.2 Non-goals

BCK-19 does not own:

- account/session/capability/IAM authority;
- Content, Booking, Route, Identity, Library, Media or other domain records;
- reports, sanctions, block/mute, appeals or moderation verdicts;
- PrivacyRequest/DSR orchestration;
- notification inbox/delivery, analytics or operational alert authority;
- production database consoles, arbitrary queries or direct record editing;
- publisher/workspace impersonation or minting a user session;
- deployment, backup restore, secrets or break-glass IAM policy;
- payment adjustment, refund or ledger authority;
- legal advice or unapproved support/retention promises.

## 4. Scope

### 4.1 In scope

- Admin/support case lifecycle, assignment and safe collaboration notes;
- dedicated tool context and case-scoped authorization receipt;
- minimized user/resource lookup and privileged field reveal;
- privileged read and action audit;
- repair detection/reference, proposal, simulation, approval and execution receipt;
- bounded bulk repair with per-target outcomes and safe resume;
- emergency-disable request/handoff to BCK-05 flags;
- domain/Privacy/T&S/incident referral without ownership transfer;
- migration boundary for current local Admin/moderation demonstrations;
- security, privacy, retention, recovery, SLO, cost and abuse controls.

### 4.2 Explicitly disabled until later gates

- production staff access and real personal-data viewing;
- direct Firestore/Storage mutation or ad hoc production scripts;
- arbitrary export/download and mass user lookup;
- user-session impersonation or “login as user”;
- high-risk repair without accepted dual-control policy;
- BCK-22 moderation/enforcement decisions;
- payment/refund/ledger operations before BCK-17 and its ADR;
- production emergency action before JIT/roster/tabletop evidence.

## 5. Ownership and single writers

| Aggregate/decision | Single writer | BCK-19 boundary |
|---|---|---|
| `AdminSupportCase` | BCK-19 | Lifecycle, assignment, notes and references |
| `PrivilegedReadAudit` | BCK-19/audit service | Immutable access evidence, never raw viewed data |
| `RepairProposal/Approval/ExecutionReceipt` | BCK-19 | Workflow truth, not domain record truth |
| Account/session/capabilities | BCK-06 | BCK-19 consumes current dedicated staff access decision |
| Cloud IAM/JIT/break-glass | BCK-05/IAM policy | BCK-19 requires an access receipt; cannot grant IAM |
| Domain state and repair command | Owning domain | Validates invariants and atomically writes its records |
| Reports/sanctions/appeals | BCK-22 | BCK-19 only links or routes to owning case |
| PrivacyRequest/directive | BCK-04 | BCK-19 may support verified handling, not become coordinator |
| Server flags/emergency disable | BCK-05 | BCK-19 requests/invokes registered action under policy |
| Notifications | BCK-13 | Consumes accepted case/domain facts; no inline push/email |
| Product analytics | BCK-21 | Admin audit is not analytics |

An Admin/Support user does not receive cross-domain writer rights. “Admin” is
not a wildcard capability, Professional Page, publisher or workspace. A staff
surface can compose bounded projections from many domains while every mutation
still calls one owning-domain command.

## 6. Principals and trust boundaries

Principals:

- authenticated end user opening or replying to an eligible support case;
- dedicated human Admin/Support principal with separate privileged identity;
- case assignee/reviewer/approver with stable allowlisted capabilities;
- owning-domain repair service identity;
- BCK-05 incident/flag service;
- privacy, security and audit/reconciliation workers.

Production human access requires separate privileged identity, MFA, current
roster/access review and JIT/time-bounded scope where defined. An ordinary
consumer session, mock `isAdmin`, `admin.experience.preview`, page membership or
client capability list is never sufficient.

The backend derives actor, staff identity, tool context, capability, environment,
case scope and access expiry. Client-supplied `isAdmin`, approver ID, risk tier,
case ownership, target revision, before/after state or execution outcome is
ignored or rejected as authority.

## 7. Domain model

### 7.1 AdminSupportCase

Required fields:

- permanent case ID, case schema/type and environment/market;
- requester/subject references where applicable, separately classified;
- safe summary, category, severity and purpose code;
- owning team, assignee refs, status and revision;
- linked incident/privacy/T&S/domain case refs without copied authority;
- created/updated/resolved/closed instants and policy revisions;
- evidence references, notes and attachments under approved family policies;
- disclosure/visibility profile and retention class.

Case states are monotonic:

```text
received -> triaged -> active -> waitingForUser | waitingForOwner
  -> resolved -> closed
  -> rejected | duplicate | cancelled
```

`closed` is terminal. Continued work creates a new case linked by
`reopensCaseId` and a bounded reason; it never rewrites the closed timeline. A
case status is not a domain outcome: closing a case cannot mark a Booking
refunded, Content restored, identity verified or report resolved.

### 7.2 CaseAccessScope

An access scope contains case ID/revision, staff principal, capability, purpose,
allowed resource refs, field-mask profile, environment, the approval reference
when policy requires one, issued/expiry time and revocation state. It is an
application authorization receipt, not IAM or a user session.

Scope is least privilege and deny-by-default. New resource, new field class,
expired session, reassignment, case closure, capability revoke or purpose change
requires a new decision. It cannot be copied between dev/stage/prod or users.

### 7.3 PrivilegedReadAudit

Every Protected/Sensitive reveal records:

- staff/service opaque ID and dedicated session/access-scope reference;
- case, purpose, resource type/opaque ID and field-mask class;
- request/correlation ID, policy revision, environment and UTC time;
- allow/deny/outcome and bounded reason code;
- export/reveal mode without raw content.

Audit is append-only within its Accepted retention and is not a product
analytics stream. Ordinary operational list metadata may use bounded aggregate
telemetry; raw user content is never copied into the audit entry.

### 7.4 RepairProposal

A proposal contains:

- permanent proposal ID, case and owning domain;
- registered repair command name/version;
- exact target IDs and expected revisions;
- canonical typed repair input and payload hash;
- invariant/problem evidence references and safe diagnosis code;
- dry-run/simulation result with source snapshot revision and expiry;
- risk tier, blast-radius estimate and required approval policy revision;
- proposer, created/expires times and immutable proposal revision.

Proposal data cannot contain a generic patch, arbitrary Firestore path, SQL,
script, function name, user-supplied executable content or unbounded query.

### 7.5 RepairApproval

Approval binds exact proposal ID, proposal revision/hash, risk/policy revision,
approver principal, decision, bounded reason, approved scope and expiry. Any
change to target, command, expected revision, input, risk or simulation
invalidates prior approval.

Where dual control applies, the required human approver is distinct from the
proposer; executor is a narrow service identity. Exact risk tiers and whether a
second independent approver is required are BCK19-OD-05. No fallback silently
reduces the required number of qualified people.

### 7.6 RepairExecutionReceipt

The receipt records execution ID, proposal/approval/command versions, service
identity, attempt request ID, stable idempotency key, start/end time, per-target
typed result, before/after revisions or hashes, emitted audit/outbox refs and
reconciliation requirement.

The receipt reports the owning domain's result; BCK-19 does not fabricate
success. A single-aggregate repair is atomic. A bounded multi-target repair may
be `partiallyCompleted` only with explicit per-target receipts, resumable
checkpoint and no hidden global success.

## 8. Commands

| Command | Caller | Authoritative result |
|---|---|---|
| `admin.createSupportCase` | Eligible user/staff integration | New or deduped bounded case |
| `admin.triageCase` | Case-capable staff | Owner/severity/status revision |
| `admin.assignCase` | Authorized coordinator | Exact assignee/team and revision |
| `admin.addCaseNote` | Eligible participant | Classified bounded note/evidence ref |
| `admin.resolveCase` | Assignee/reviewer | Case-only resolution and reason |
| `admin.requestAccessScope` | Dedicated staff tool | Denied/pending/issued case scope |
| `admin.revokeAccessScope` | Security/system/owner | Immediate terminal revocation |
| `admin.revealProtectedFields` | Scoped staff principal | Bounded view + privileged-read audit |
| `admin.createRepairProposal` | Repair-capable staff/service | Immutable draft proposal |
| `admin.simulateRepair` | Trusted domain adapter | Dry-run receipt; no domain mutation |
| `admin.submitRepairProposal` | Proposer | Frozen proposal awaiting approval |
| `admin.decideRepairProposal` | Distinct qualified approver(s) | Approved/rejected/expired revision |
| `admin.executeApprovedRepair` | Narrow orchestrator | Owning-domain command receipt |
| `admin.reconcileRepair` | Domain/reconciliation worker | Verified terminal or resume state |
| `admin.requestEmergencyDisable` | Incident-capable staff | BCK-05 flag/action handoff receipt |

All mutations use BCK-03 envelopes. Request ID identifies an attempt; stable
idempotency key identifies the logical action. Current actor/access/case/policy
and expected revisions are evaluated at execution time.

## 9. Queries and search

Queries include:

- `admin.listCases` with bounded filters, opaque cursor and snapshot revision;
- `admin.getCase` with role/field-mask-specific projection;
- `admin.lookupResourceForCase` using exact approved identifier;
- `admin.listRepairProposals` and `admin.getRepairExecution`;
- `admin.getAccessHistory` for authorized audit/review;
- `support.getOwnCaseStatus` with user-safe projection.

Search is not a general production-data console. Default lookup uses case ID,
canonical ULID/UUID or exact approved source reference. Email/phone/name search,
substring scans, arbitrary collection queries and bulk export remain disabled
until an Accepted purpose, anti-enumeration, indexing, access and retention
profile exists. Email equality never proves identity or account ownership.

Cursors bind tool principal, case/team scope, filters, projection version,
environment and snapshot. A cursor from another scope fails closed. List results
show minimized summary data; revealing sensitive fields is a separate audited
action.

## 10. Authorization and privileged access

Every staff action requires:

```text
dedicated privileged identity + MFA/session/step-up
+ active staff capability + environment
+ case/purpose + exact resource scope
+ current policy/case/resource revision
+ JIT/approval where required
+ immutable audit
```

Role alone never authorizes. Publisher or workspace context is irrelevant.
Support never “logs in as” a user, receives a user's token, changes active
workspace or performs an action under the user's actor ID.

A diagnostic “view as” may render a sanitized projection only if accepted by
BCK19-OD-04. It keeps the staff actor visibly attributed, prohibits mutation,
uses current server authorization and records the reveal; it is not impersonation.

Revocation is evaluated before each reveal, proposal, approval and execution.
Long-running execution rechecks the policy defined by the owning domain before
each new target. Cached staff role or stale case assignment never grants access.

## 11. Repair lifecycle and domain execution

Required flow:

1. detect/report a concrete inconsistency and open/link a case;
2. select an allowlisted domain repair command and exact targets;
3. obtain current source revisions and run a non-mutating simulation;
4. freeze proposal input/hash, risk, blast radius and expiry;
5. collect required distinct approval(s) bound to that exact proposal;
6. orchestrator revalidates actor, approval, case, policy and target revisions;
7. owning domain executes its typed command and invariants atomically;
8. domain returns typed receipt and produces its own audit/outbox where needed;
9. BCK-19 records execution/reconciliation evidence and case status;
10. RUN-03 verifies the implemented flow before persistent staging access.

Admin/Support never writes another module's collection, counter, projection,
ledger or audit record. A repair command must be part of the owning domain's
registered API, not a special bypass with weaker invariants.

If simulation or expected revision becomes stale, approval is invalidated and
the proposal returns to diagnosis. Unknown outcome is reconciled using command
receipt/idempotency before any retry. Rollback is a new approved domain command
or reconciliation plan; it is never silent restoration of old bytes.

## 12. Emergency disable and break-glass boundary

BCK-05 owns flags, incident operations and break-glass IAM. BCK-19 may offer a
case-bound UI for a registered containment action, but:

- the action calls BCK-05's typed flag/emergency command;
- incident reference, scope, TTL, approver and audit are mandatory;
- no permanent elevation or static-key fallback exists;
- emergency disable cannot delete evidence, relax Rules or bypass safe exits;
- break-glass cannot be repurposed for routine Support or data repair;
- post-action revocation and review are required.

Direct console/database work is not normalized by calling it “repair”. If a
separately governed incident action occurs outside normal tooling, it remains a
break-glass incident requiring exact evidence and subsequent domain
reconciliation; it does not create precedent or BCK-19 Done evidence.

## 13. Cross-domain referrals

| Need | Owning handoff | BCK-19 behavior |
|---|---|---|
| Account/session/recovery | BCK-06 | Invoke registered privileged command; no email-based merge |
| Privacy request | BCK-04 | Link verified PrivacyRequest/directive; no duplicate DSR case authority |
| Content publication correction | BCK-07 | Domain repair/moderation command only |
| Booking repair | BCK-09 | Exact ledger-safe command; no direct Booking/ledger write |
| Notification to user/staff | BCK-13 | Accepted minimized intent after commit |
| Media evidence | BCK-14 | Protected approved family/ref only; no attachment-by-URL |
| Trust & Safety | BCK-22 | Route to report/sanction/appeal owner |
| Server flag/incident | BCK-05 | Registered action and incident receipt |
| Payment/refund | BCK-17 after ADR | No action before separate authority |

Case linking preserves IDs, source revision, data class and ownership. Copying
raw records into Support notes to avoid the owning API is forbidden.

## 14. Events and typed failures

### 14.1 Events

BCK-19 may emit minimized facts after commit:

- `admin.caseCreated`, `admin.caseAssigned`, `admin.caseResolved`;
- `admin.accessScopeIssued`, `admin.accessScopeRevoked`;
- `admin.repairProposed`, `admin.repairApproved`, `admin.repairRejected`;
- `admin.repairExecutionCompleted`, `admin.repairReconciliationRequired`;
- `admin.emergencyDisableRequested`.

Cross-domain event delivery uses Accepted OD-09. Until then, effects/workers
remain disabled or inside a separately approved bounded synchronous adapter;
BCK-19 does not invent a second envelope.

### 14.2 Failure vocabulary

```text
unauthenticated
permission_denied
not_found
case_closed
case_scope_required
purpose_required
step_up_required
access_expired
access_revoked
approval_required
approval_conflict
separation_of_duties_violation
proposal_expired
simulation_stale
stale_revision
unsupported_command
unsupported_contract
idempotency_conflict
rate_limited
cancelled
temporarily_unavailable
reconciliation_required
```

Errors reveal no user/resource existence, raw evidence, staff roster, policy
bypass detail or sensitive before/after values. `cancelled` is a typed neutral
non-success outcome where irreversible execution has not started.

## 15. Contract versioning and compatibility

Case, access-scope, repair command, proposal, approval, receipt, event, failure
and projection contracts are independently versioned under BCK-03. Unknown
critical fields, risk/policy revisions, commands or capabilities fail closed.

Generated schemas/DTOs require the Accepted API contracts workflow and fixtures.
Admin tooling may support the current and explicitly listed previous version;
it never partially executes a newer repair contract. Stored proposal approval
remains bound to its exact immutable versions and is not upgraded in place.

## 16. Persistence, indexes and atomicity

Logical record families:

- cases, participant/assignment refs and classified notes;
- case access scopes and revocation;
- privileged read audit;
- repair proposals, simulations, approvals and execution receipts;
- bounded checkpoints/dead letters for reconciliation;
- emergency/incident handoff references.

Required indexes support exact case/team/status/time, exact subject/resource
reference under approved purpose, expiring access scopes, proposal/risk/status,
due reconciliation and audit review. Exact Firestore paths/indexes are a future
Approved slice; clients never write these authority records directly.

Case transition + Admin audit + idempotency receipt are atomic where required.
Owning-domain repair mutation + domain audit/outbox are atomic in that domain.
BCK-19 cannot create a cross-module transaction by sharing a batch. Handoff and
execution use durable receipts/reconciliation.

## 17. IDs, time, idempotency and concurrency

- persistent IDs are ULID/UUID; `loc_*` is unsaved-local only;
- all references use IDs, never email/name/title as authority;
- authoritative times use backend UTC;
- local calendar/display uses explicit IANA zone and locale policy;
- expiry, JIT and approval windows use backend time;
- same idempotency key/same canonical hash replays the stored result;
- same key/different hash yields `idempotency_conflict` without mutation;
- each retry has a fresh request ID and stable logical key;
- expected revision/precondition hash prevents stale overwrite;
- approval consumes exact proposal revision and cannot be reused after terminal
  execution, expiry or scope change.

## 18. Notes, evidence and attachments

Notes are bounded, classified and sanitized. They are not a dumping ground for
raw tokens, credentials, verification documents, access codes, private location,
application text or full database payloads. Structured reason/evidence codes and
opaque references are preferred over free text.

Attachments are disabled until a protected BCK-14 support-evidence family,
malware/safety checks, access, consent/legal basis, retention and deletion are
Approved. External arbitrary URLs and personal cloud-drive links are rejected.

User-visible messages are separate safe projections. Internal diagnosis, staff
identity and security details do not leak into notifications or case status.

## 19. Privacy, retention, DSR and user transparency

Every case/note/reveal/audit/proposal/receipt family declares purpose, class,
access, retention trigger, terminal action, backup propagation and legal/security
hold rules. Support evidence may be Sensitive; audit is Operational with a
separate purpose. Provider defaults and “we may need it later” are not policy.

DSR orchestration remains BCK-04-owned. BCK-19:

- returns domain-specific inventory/completion evidence to Privacy orchestration;
- restricts/deletes eligible case notes/evidence under an exact directive;
- preserves only lawfully required minimized audit with documented basis;
- prevents restore from resurrecting revoked access or deleted evidence;
- does not let staff notes silently defeat correction/erasure rights.

Whether and when users see privileged-access history, repair notifications,
support transcripts or staff identity is BCK19-OD-04/08 with Legal/Privacy.
Security investigations may require delayed disclosure under applicable policy;
this document does not invent an exemption.

## 20. Security and abuse controls

- dedicated individual staff identities; no shared/orphan account;
- MFA, current roster, JIT/step-up and environment binding;
- capability + case + purpose + exact resource + field mask;
- distinct proposer/approver and service executor where required;
- no blanket Owner/Editor, service-account impersonation or static key;
- no user-session impersonation or publisher/workspace switching;
- read audit, tamper-evident/immutable retention controls and export restriction;
- anti-enumeration and exact-ID lookup;
- payload/note/export bounds and per-staff/case/target rate limits;
- anomaly detection for bulk lookup, reveal spikes, denied access and approval
  self-dealing;
- immediate revocation and incident escalation;
- App Check only where relevant to a client surface, never staff authority.

Production screenshots, copy/paste, local downloads and external sharing cannot
be made safe by prose alone. Exact technical/organizational controls, managed
device policy and evidence belong to BCK19-OD-02/04 and production approval.

## 21. Observability, SLO, cost and review

Operational indicators:

- cases by status/category/age and safe workload dimension;
- access-scope request/deny/issue/expiry/revoke;
- privileged reveal count, denied attempts and anomalous patterns;
- repair proposal/simulation/approval/expiry/execution outcomes;
- stale/conflict/reconciliation-required and retry age;
- emergency action request/approval/revocation/review;
- audit export/retention/deletion and restore verification;
- staff access review completion and orphan-principal findings;
- query/read/write/storage/worker and support-operation cost.

Metrics contain no raw case note, evidence, search value or target payload.
Operational telemetry belongs to BCK-05; product analytics needs BCK-21 and is
not a substitute for audit.

Exact support response targets, access TTL, approval expiry, repair batch size,
rate/anomaly thresholds, retention, SLO and EUR cost guardrails are
BCK19-OD-10. Until Accepted and measured, no production readiness or staffing
capacity claim exists.

## 22. Flags, rollout and rollback

Server-owned flags are scoped by environment, market, tool surface, case type,
read profile, domain repair command, risk tier and cohort:

- case intake and staff assignment;
- protected-field reveal;
- repair proposal/simulation/approval;
- each domain repair command;
- bounded batch execution;
- emergency-disable handoff;
- user transcript/disclosure features.

Rollout proceeds documentation → contracts/fixtures → unit → emulator →
synthetic stage → staff-only non-production → bounded persistent staging after
G5/RUN-03 → separately approved production. Staff read and repair activation
are separate flags and gates.

Rollback revokes access, stops new reveals/proposals/executions, safely finishes
or reconciles in-flight domain commands and preserves case/audit/privacy duties.
It never restores mock Admin grants, bypasses a domain invariant, erases evidence
or reverses a committed repair by editing database bytes.

## 23. Migration and current-runtime compatibility

Current local artifacts are classified as follows:

| Artifact | Treatment |
|---|---|
| `admin.experience.preview` | Presentation-only compatibility; never staff grant |
| Mock `isAdmin`/capabilities | Demo fixture; never imported or mapped to production privilege |
| Local Route moderation requests/decisions | Domain UX evidence; not Admin cases or trusted production decisions |
| Local Route safety reports | BCK-22/T&S input debt; not BCK-19 sanction authority |
| Local moderator notification inbox | BCK-13 demo evidence; not case queue or staff identity |

Default migration imports **none** of these as authority. A future compatibility
slice may retain UI labels/routes behind a remote adapter, but production staff
must re-authenticate through dedicated identity and all actionable state must
come from accepted server records. No historical local approval becomes a
production publication, sanction, capability or repair approval.

## 24. Dependency and delivery gates

Before Approval:

- BCK-03/04/05/06 and applicable owning-domain specifications Approved or an
  explicit accepted compatibility disposition;
- BCK05 IAM/JIT/roster and privileged-access controls accepted for target stage;
- BCK-22 boundary accepted before any moderation/enforcement surface;
- all ten BCK19 decisions Accepted or Deferred with bounded controls;
- Security/Privacy, Operations, Identity, domain, Support and Legal verdicts.

Before executable work:

- separately Approved bounded slice with exact files/resources/capabilities;
- accepted Admin contracts, repair registry and fixtures;
- G1/R1 environment/IAM prerequisites and synthetic data only;
- exact domain commands, dry-run and rollback/repair semantics;
- server flags, kill switches, quotas and audit destination predeclared.

Before persistent staging:

- BCK-19 Approved and implemented for chosen commands;
- G5 prerequisites and production-like Identity/access in stage;
- RUN-03 generated from actual commands and successfully drilled;
- negative AuthZ, dual-control, idempotency, reconciliation and audit evidence;
- no production personal data copied to stage.

Before production:

- individual privileged identities, MFA, JIT/roster/revocation and access review;
- approved case/read/repair/retention/user-transparency policy;
- incident, DSR, backup-resurrection and emergency drills;
- load/rate/exfiltration/cost/SLO evidence;
- signed Security/Privacy/Operations/Legal/domain owner decision.

## 25. Conditional exact file map

No file below is authorized by this Review. A future Approved slice may create:

```text
packages/api_contracts/admin_support/       # after BCK19-OD-01
  schemas/
  fixtures/

apps/backend/src/admin_support/
  domain/
    admin_support_case.*
    case_access_scope.*
    privileged_read_audit.*
    repair_proposal.*
    repair_approval.*
    repair_execution_receipt.*
  application/
    create_case.*
    request_case_access.*
    reveal_protected_fields.*
    propose_repair.*
    simulate_repair.*
    approve_repair.*
    execute_repair.*
    reconcile_repair.*
    request_emergency_disable.*
  infrastructure/
    admin_case_repository.*
    admin_audit_repository.*
    privileged_access_gateway.*
    domain_repair_registry.*
  presentation/
    admin_support_handlers.*
  workers/
    expire_access_scopes.*
    reconcile_repairs.*
    retain_delete_admin_data.*

apps/backend/test/admin_support/
  unit/
  contract/
  integration/
  security/
  privacy/
  recovery/

apps/admin/                                 # only after separate surface decision
  src/
  test/

docs/runbooks/backend-reconciliation-repair.md  # RUN-03 after real commands
```

Owning-domain repair handlers stay inside their domain modules. IAM/flags stay
under BCK-05 ownership. T&S handlers stay under BCK-22. Generated files are
never edited manually.

## 26. Test and evidence matrix

| Layer | Required evidence |
|---|---|
| Domain/unit | case, access, proposal, approval and receipt state machines |
| Contract | commands/queries/events/errors, forward/backward and hash fixtures |
| Authorization | role-only denial, case/purpose/scope/field mask, expiry/revoke |
| Separation of duties | proposer/approver/executor conflicts and roster shortage |
| Privileged read | reveal audit, anti-enumeration, no raw content in logs |
| Domain integration | dry-run, stale proposal, invariant rejection, atomic command receipt |
| Idempotency/fault | duplicate, timeout, unknown outcome, partial bounded batch/resume |
| Emergency | flag handoff, TTL, approval, safe exits, revoke and post-review |
| Privacy | note/evidence minimization, DSR, retention, legal hold and no resurrection |
| Abuse/load/cost | bulk lookup/export denial, rate/anomaly, queue and repair batch bounds |
| Migration | mock Admin/local moderation exclusion and typed route compatibility |
| Runbook | actual RUN-03 command inventory, drill and evidence before persistent stage |

Documentation checks prove only structure, links and reconciliation. Emulator
cannot prove production identity, staff device policy, IAM, legal basis,
two-person availability, incident response or data-access behavior.

## 27. Definition of Ready

For Approval review:

1. 22/22 coverage remains reconciled;
2. ten owner decisions have dated verdicts;
3. domain/T&S/Privacy/IAM ownership conflicts are closed;
4. repair registry and risk/approval policy are reviewable;
5. Security/Privacy, Operations, Identity, Support, Legal and domain owners sign;
6. runtime and production staff access remain absent unless separately approved.

For an executable slice:

1. BCK-19 is Approved;
2. exact bounded cases/read profiles/domain commands/files are approved;
3. contracts, failures, simulation and approval fixtures are frozen;
4. environment/IAM and synthetic-data prerequisites pass;
5. rollback/kill-switch/rate/audit controls are predeclared;
6. no unresolved privilege or repair choice is implemented by assumption.

## 28. Definition of Done

BCK-19 runtime is Done only when:

- approved case, access-scope, read-audit and repair workflow exist in owned layers;
- every mutation calls a registered owning-domain command;
- dedicated identity, MFA, JIT/revocation and separation controls are active;
- contract, security, privacy, integration, fault and recovery gates pass;
- mock Admin/local decisions are excluded from production authority;
- observability, access review, runbooks, on-call and cost controls are active;
- LAUNCH_STATUS links measured evidence without conflating documentation,
  deployment, staff access, execution or market enablement.

Persistent staging additionally requires G5 and a successful RUN-03 drill.
Production Enabled requires separate owner/Legal/Security/Operations approval.

## 29. Acceptance criteria

1. **BCK-19-AC-01:** BCK-19 alone writes Admin/Support case workflow records.
2. **BCK-19-AC-02:** BCK-19 owns repair proposals/approvals/receipts, not domain state.
3. **BCK-19-AC-03:** Owning domains alone execute state-changing repair commands.
4. **BCK-19-AC-04:** BCK-22 owns reports, sanctions, block/mute and appeals.
5. **BCK-19-AC-05:** BCK-04 owns PrivacyRequest and DSR orchestration.
6. **BCK-19-AC-06:** BCK-05/IAM owns flags, JIT and break-glass authority.
7. **BCK-19-AC-07:** Admin role alone never authorizes a privileged action.
8. **BCK-19-AC-08:** Production staff uses dedicated privileged identity and MFA.
9. **BCK-19-AC-09:** Admin is never publisher, workspace or user impersonation.
10. **BCK-19-AC-10:** Client actor/capability/approver assertions are rejected.
11. **BCK-19-AC-11:** Every privileged action has case, purpose, scope and audit.
12. **BCK-19-AC-12:** Protected/Sensitive reveal uses an exact field-mask profile.
13. **BCK-19-AC-13:** Every privileged reveal, including denied attempts, is audited.
14. **BCK-19-AC-14:** Audit stores no raw viewed content, token or unrestricted note.
15. **BCK-19-AC-15:** Search is bounded and not an arbitrary production query console.
16. **BCK-19-AC-16:** Email/name/device never proves identity or resource ownership.
17. **BCK-19-AC-17:** Case closure never fabricates a domain lifecycle outcome.
18. **BCK-19-AC-18:** Cross-domain references preserve ownership and revision.
19. **BCK-19-AC-19:** Support notes cannot duplicate raw domain records.
20. **BCK-19-AC-20:** Attachments stay disabled before an approved protected-media profile.
21. **BCK-19-AC-21:** Repair proposals use registered typed commands, never generic patches.
22. **BCK-19-AC-22:** Proposal pins exact targets, expected revisions, input hash and expiry.
23. **BCK-19-AC-23:** Simulation is non-mutating and reports source revision.
24. **BCK-19-AC-24:** Any proposal change invalidates its approvals.
25. **BCK-19-AC-25:** Required approver is distinct from proposer.
26. **BCK-19-AC-26:** Executor is a least-privilege service identity.
27. **BCK-19-AC-27:** Roster shortage never silently weakens dual control.
28. **BCK-19-AC-28:** Domain invariants are revalidated at execution time.
29. **BCK-19-AC-29:** Stale simulation/proposal creates no mutation.
30. **BCK-19-AC-30:** Single-aggregate repair is atomic.
31. **BCK-19-AC-31:** Bounded batch partial completion has per-target receipts and resume.
32. **BCK-19-AC-32:** Unknown outcome reconciles before a new logical execution.
33. **BCK-19-AC-33:** Request ID and logical idempotency key remain separate.
34. **BCK-19-AC-34:** Same key/different payload hash creates no mutation.
35. **BCK-19-AC-35:** Rollback is a new approved domain command/reconciliation plan.
36. **BCK-19-AC-36:** Direct cross-module Firestore/Storage writes are forbidden.
37. **BCK-19-AC-37:** Break-glass is never routine Support or repair tooling.
38. **BCK-19-AC-38:** Emergency disable calls BCK-05 typed authority.
39. **BCK-19-AC-39:** Emergency action cannot erase audit or weaken safe exits.
40. **BCK-19-AC-40:** Revocation is checked before every reveal/approval/execution.
41. **BCK-19-AC-41:** Environment, market, case and subject scopes never mix.
42. **BCK-19-AC-42:** Unknown critical contract/policy/capability fails closed.
43. **BCK-19-AC-43:** Events remain disabled until applicable OD-09 acceptance.
44. **BCK-19-AC-44:** Notifications are post-commit BCK-13 effects only.
45. **BCK-19-AC-45:** Privacy retention is per record family/purpose, not convenience.
46. **BCK-19-AC-46:** DSR cannot be defeated by Support notes or backups.
47. **BCK-19-AC-47:** Product analytics never substitutes for Admin audit.
48. **BCK-19-AC-48:** Mock Admin grants never migrate to production privilege.
49. **BCK-19-AC-49:** Local moderation decisions never become trusted production decisions.
50. **BCK-19-AC-50:** Local moderator inbox never becomes a Support case queue.
51. **BCK-19-AC-51:** Numeric access/SLO/rate/cost claims require owner evidence.
52. **BCK-19-AC-52:** Anomaly controls cover bulk lookup/reveal and self-approval.
53. **BCK-19-AC-53:** Degradation fails closed without bypassing domain invariants.
54. **BCK-19-AC-54:** Every reveal/repair/emergency surface has a kill switch.
55. **BCK-19-AC-55:** Rollback preserves committed domain truth and audit.
56. **BCK-19-AC-56:** RUN-03 follows implemented commands and is not a BCK-19 prerequisite.
57. **BCK-19-AC-57:** BCK-19 Review does not satisfy G5 or persistent staging.
58. **BCK-19-AC-58:** No new boundary suppression is introduced by this revision.
59. **BCK-19-AC-59:** Executable files require a separate Approved slice.
60. **BCK-19-AC-60:** Runtime remains Absent until measured implementation evidence exists.

## 30. Explicit unimplemented list

- Admin/Support API schemas, fixtures, clients or generated DTOs;
- dedicated production staff identity, MFA/JIT/roster or tool session;
- server case repository, assignments, notes or user transcript;
- case-scoped privileged query/read/reveal and immutable read audit;
- repair registry, simulation, approval, execution or reconciliation handlers;
- any owning-domain production repair command;
- BCK-05 emergency-disable tool integration or break-glass runtime;
- BCK-22 moderation/report/sanction/appeal backend;
- protected support-evidence media family;
- local Admin/moderation migration or production admin application;
- DSR/retention/recovery/access-review workers and runbooks;
- accepted numeric limits, SLO, rates, retention or cost guardrails;
- RUN-03 implementation or drill;
- Firebase/GCP resources, Rules/IAM, credentials, deployment or production data.

## 31. Owner decisions required

| ID | Required decision | Owners | Fail-closed default |
|---|---|---|---|
| BCK19-OD-01 | API/schema/codegen source, case/repair registry and compatibility fixtures | Admin Ops + API + domains | No remote tool/runtime |
| BCK19-OD-02 | Dedicated staff identity, MFA/JIT/tool session, managed-device and roster policy | Security + Identity + Operations | No production staff access |
| BCK19-OD-03 | Case taxonomy, severity, assignment, status, participant and transcript rules | Support + Admin Ops + Product | Bounded internal synthetic cases only |
| BCK19-OD-04 | Privileged lookup/reveal field masks, purpose, “view as”, disclosure and export | Privacy/Legal + Security + Support | Sensitive reveal/export disabled |
| BCK19-OD-05 | Repair risk tiers, proposer/approver count, separation and expiry matrix | Security + Admin Ops + domains | High-risk repair disabled |
| BCK19-OD-06 | Domain repair command registry, simulation, batch, receipt and rollback contract | Domain owners + Admin Ops + API | No state-changing repair |
| BCK19-OD-07 | Emergency-disable tool actions and break-glass/incident boundary | Operations + Security + Admin Ops | Emergency UI/action disabled |
| BCK19-OD-08 | Case/note/evidence/read-audit/repair retention, DSR, hold and user transparency | Privacy/Legal + Support + Security | No production personal data |
| BCK19-OD-09 | Local Admin/moderation compatibility, routing, cutover and rollback | Mobile + Content/Route + T&S + Admin Ops | No import; preview remains local-only |
| BCK19-OD-10 | Numeric response/access/approval/SLO/rate/batch/cost and review cadence | Operations + Support + Security + Product | No scale/production claim |

## 32. Final statement

BCK-19 v0.2 is a complete Review contract for a production-grade Admin &
Support subsystem design. It provides tools and evidence without creating a
superuser or bypassing any owning domain. It is deliberately fail-closed and
neither claims nor authorizes implementation, staff access or persistent data.
