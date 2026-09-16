# Recharge Backend — Security Threat Model

- Evidence ID: **BCK04-OD01-TM-01**
- Version: **0.2**
- Date: **2026-09-15**
- Decision served: **BCK04-OD-01 — full backend threat model**
- Decision status: **Proposed — combined-owner technical verdict recorded; independent/cross-boundary evidence pending**
- Evidence status: **Draft — required amendments integrated; independent security review required**
- Accountable owner: **RechargeN / Product owner** (combined Security/Privacy role)
- Independence: **self-review; no independent security reviewer**
- Runtime status: **Bounded local RAW-C evidence Present; product/cloud security runtime Absent**
- Parent specification: [BCK-04 v0.4.23](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Architecture parent: [BCK-01 v0.4.57](RECHARGE_BACKEND_MASTER_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.61](RECHARGE_BACKEND_DELIVERY_MAP.md)
- API boundary: [BCK-03 v0.3.14](BACKEND_API_CONTRACT_STANDARD.md)
- Operations boundary: [BCK-05 v0.2.30](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Reference-data boundary: [BCK-20 v0.2.9](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Owner review: [BCK04-OD01-REV-01 v0.2](BACKEND_SECURITY_THREAT_MODEL_OWNER_REVIEW.md)
- Owner decision: [BCK04-OD01-DEC-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_OWNER_DECISION.md)
- Runtime effect: **none**

---

## 0. Changelog

### v0.2 — 2026-09-15

- recorded the combined-owner technical verdict and integrated all twenty
  amendments from `BCK04-OD01-REV-01`;
- added stable asset/actor IDs, explicit STRIDE and privacy/abuse/cost/safety/
  operations tags, per-threat ownership, evidence gate and residual state;
- reconciled DSR, App Check recovery, protected reads, identity lifecycle,
  hostile ingress, supply chain, restore, market isolation and future-surface
  addendum requirements with BCK-04 v0.4.23;
- retained BCK04-OD-01 Proposed pending independent Security/Privacy and
  required cross-boundary confirmations;
- created no runtime, Firebase, credential, deployment, push or merge
  authority.

## 1. Verdict and purpose

This document supplies the missing repository-wide, asset-oriented threat model
requested by `BCK04-OD-01`. It is a concrete **proposal**, not security approval
and not proof that controls exist in code or cloud configuration.

It covers the target Recharge backend for Latvia-first launch and the prepared,
independently disabled Estonia/Lithuania expansion. It uses STRIDE plus explicit
privacy, abuse, cost and operational-failure analysis.

Current verdict: the architecture has coherent fail-closed control boundaries,
and the combined owner accepted the technical direction with required
amendments. Those amendments are integrated in v0.2, but independent review,
cross-boundary confirmations and executable evidence remain. `BCK04-OD-01`
therefore stays Proposed and cannot become Accepted until §13 passes.

## 2. Scope and exclusions

Included:

- mobile-to-backend authentication and API calls;
- capability, workspace, publisher and admin authorization;
- authoritative domain commands, queries and transactions;
- Firestore, Storage, event/outbox and scheduled-worker boundaries;
- provider/webhook and future AI/Payments ingress boundaries;
- privacy requests, export, deletion and retention orchestration;
- logs, metrics, audit, server policy/config and minimum-client controls;
- deployment identity, supply chain, environment isolation, backup and restore;
- denial-of-service, quota and cost-amplification threats.

Excluded from acceptance evidence:

- actual `.rules`, IAM, Functions, schemas, indexes or cloud resources;
- penetration/load/restore tests that require an Approved executable slice;
- a qualified legal conclusion, DPIA, ROPA or processor assessment;
- implementation-specific threats for an unselected provider/toolchain;
- production risk acceptance.

An excluded item remains gated; exclusion never means safe by default.

## 3. Method and rating

Each threat records:

- stable actor, asset and trust-boundary IDs;
- attacker capability and misuse path;
- one or more STRIDE categories plus privacy/abuse/cost/safety/operations tags;
- inherent priority and target preventive/detective/recovery controls;
- one accountable owner, collaborators, required evidence and blocking gate;
- explicit residual disposition.

Classification codes:

| Code | Meaning |
|---|---|
| `S` | spoofing identity |
| `T` | tampering with data or state |
| `R` | repudiation or missing attributable evidence |
| `I` | information disclosure or inference |
| `D` | denial of service or resource exhaustion |
| `E` | elevation of privilege |
| `privacy`, `abuse`, `cost`, `safety`, `operations` | additional impact/misuse tags; multiple tags may apply |

Control evidence state is one of `target`, `implemented`, `verified` or
`exception`. A target control is design intent only. This revision contains no
product/cloud `implemented` or `verified` claim; bounded RAW-C evidence is
local/emulator-only and does not change target threat disposition.

Residual disposition is one of `blocked`, `mitigatedPendingProof`,
`acceptedResidual`, `transferred` or `notApplicable`. `acceptedResidual`
requires owner, rationale, exact scope, compensating controls and review/expiry
date. Critical residual risk cannot be silently accepted.

Risk labels are qualitative because workload, topology and numeric incident
criteria are not yet accepted:

| Priority | Meaning |
|---|---|
| Critical | could create cross-user authority, booking/inventory corruption, credential compromise, large sensitive-data disclosure or irreversible production impact |
| High | could expose protected data, bypass material policy, cause persistent abuse or major operational/cost impact |
| Medium | bounded disclosure/disruption requiring conditions or limited scope |
| Low | limited impact with straightforward detection/recovery |

These are remediation priorities, not accepted incident severity values.
Production severity mapping remains `BCK04-OD-09`/`BCK05-OD-08`.

## 4. Assets requiring protection

| ID | Asset family | Examples | Required property |
|---|---|---|---|
| A-01 | Session identity | provider identity, Firebase token, session/revocation state | authenticity, bounded lifetime, revocation |
| A-02 | Authorization state | roles, capabilities, page membership, workspace, verification | server authority, scope integrity, freshness |
| A-03 | Personal/private data | profile private fields, favorites, visits, private Scenario/Quick Plan | confidentiality, purpose limitation, rights support |
| A-04 | Sensitive evidence | verification, abuse/support evidence, access codes | strict minimization, restricted service access |
| A-05 | Published content | Event/Place/Route/Scenario projections, PublisherRef | provenance, lifecycle integrity, moderation state |
| A-06 | Booking authority | booking, hold, inventory, usage, ledger, idempotency, audit | atomicity, consistency, non-repudiation |
| A-07 | Location data | precise private position, route recordings, place/event coordinates | scope-aware disclosure and minimization |
| A-08 | Media | uploads, protected originals, derived public variants | ownership, malware/content validation, access isolation |
| A-09 | Operational state | outbox, leases, jobs, server flags, policy revisions | integrity, replay safety, rollback |
| A-10 | Audit/evidence | security, admin, booking and privacy completion evidence | append-only integrity, access control, retention |
| A-11 | Secrets/identity | service accounts, signing keys, provider secrets, CI credentials | confidentiality, least privilege, rotation |
| A-12 | Availability/budget | quotas, compute, database, storage, notification/provider spend | bounded consumption, containment, recovery |

## 5. Actors and attacker capabilities

| ID | Actor | Trust | Capabilities assumed |
|---|---|---|---|
| ACT-01 | Anonymous network attacker | untrusted | send malformed/replayed traffic, enumerate identifiers, exhaust public surfaces |
| ACT-02 | Authenticated User | untrusted for authority | valid own session, arbitrary payloads, automation and concurrency |
| ACT-03 | Creator/page member | untrusted for scope | valid capabilities in one scope, attempts cross-page/publisher escalation |
| ACT-04 | Compromised device/session | hostile authenticated | stolen token, cached data, automation until revocation propagates |
| ACT-05 | Malicious/compromised provider | untrusted ingress | forged/replayed webhook or manipulated availability/booking response |
| ACT-06 | Admin/support user | privileged but not omnipotent | access to bounded tools; may make mistakes or abuse granted scope |
| ACT-07 | Developer/operator | privileged insider | code/config/log/backup access according to role |
| ACT-08 | Supply-chain attacker | external/insider | dependency, build artifact, CI or release-channel compromise |
| ACT-09 | Automated scraper/abuser | untrusted | high-rate discovery, account creation, content/report spam, cost amplification |
| ACT-10 | Accidental system failure | non-malicious | duplicate delivery, partial commit, stale cache, clock/network/region failure |

Authentication proves an identity claim; it never promotes an actor to trusted
authorization input.

## 6. Components and trust boundaries

| Boundary | From → to | Required validation |
|---|---|---|
| TB-01 | mobile/device → Auth provider | provider-native authentication, anti-replay and safe redirect/deep-link handling |
| TB-02 | mobile → API ingress | TLS, Auth, App Check signal, contract version, size/rate/deadline limits |
| TB-03 | transport → application/domain | typed decode, server-resolved actor/workspace/capabilities, domain validation |
| TB-04 | application → persistence | owning-writer enforcement, transaction/revision/idempotency rules |
| TB-05 | direct client → Firestore/Storage | deny-by-default Rules; no authoritative direct writes |
| TB-06 | authoritative transition → outbox/worker | atomic fact creation, at-least-once dedupe, bounded replay/quarantine |
| TB-07 | external provider/webhook → integration adapter | signature/secret, timestamp, replay key, allowlist and schema validation |
| TB-08 | admin/support → privileged command | capability, case/reason, step-up, approval and immutable audit |
| TB-09 | runtime → logs/analytics/monitoring | minimization/redaction, purpose and access separation |
| TB-10 | CI/operator → cloud/runtime | workload identity, protected environment, artifact provenance, approval |
| TB-11 | production → backup/export/restore | encryption, isolated access, evidence, deletion propagation, reconciliation |
| TB-12 | server policy/reference data → consumers | signed/versioned revision, fail-closed unknown values, rollback protection |

## 7. Non-negotiable control invariants

1. Client identity, role, capability, workspace, publisher, age and verification
   claims are never authority.
2. Every authoritative record family has one owning writer.
3. Direct authoritative Firestore/Storage writes are denied by default.
4. Server SDK access bypassing Rules repeats authorization and validation.
5. Every protected/sensitive read, query, pagination continuation, export and
   result disclosure re-evaluates current server-owned authorization; sanitized
   public projections remain separate.
6. Mutation success is returned only after durable authoritative commit.
7. Retry of an unknown mutation outcome uses a fresh attempt `requestId` with
   the same logical `idempotencyKey` and canonical semantic payload.
8. Unknown security/eligibility/money/capacity/policy versions fail closed.
9. Admin repair uses the owning domain command and immutable evidence.
10. Outbox delivery is at-least-once; consumers deduplicate and never infer
    authority from payload claims.
11. Logs, errors and analytics exclude secrets and unnecessary personal data.
12. Environment, market and workspace boundaries are independent.
13. Production data is prohibited in dev and unapproved stage workflows.
14. Every emergency bypass is narrower, time-bounded, audited and revocable;
    App Check recovery never bypasses AuthN, current AuthZ, validation, rate
    limits or audit.
15. A DSR receipt uses a server-issued `privacyRequestId`; client scope is
    untrusted and server-bound to the verified data subject.
16. Erasure/restriction markers survive late work, projection rebuild, import,
    backup restore and identity teardown.

## 8. Threat register

| ID | Class/tags | Inherent | Actor | Assets / boundary | Threat scenario | Target controls | Accountable owner | Required evidence / gate | Residual |
|---|---|---|---|---|---|---|---|---|---|
| TM-01 | S/I; privacy | Critical | ACT-01/04 | A-01; TB-01/02 | forged/stolen token or session replay | provider verification, audience/issuer/time checks, session registry, step-up, revoke and device/session limits | Identity owner | Auth integration/revocation tests before R2 | blocked |
| TM-02 | S/T/E | Critical | ACT-02/03 | A-02; TB-02/03 | client role/capability/workspace/publisher accepted as authority | ignore authority claims; resolve current grants per command/query/result | Identity owner | negative authorization and cross-scope tests before R2 | blocked |
| TM-03 | I/E; privacy | Critical | ACT-01/02 | A-02/03/06; TB-02/03 | IDOR through guessed user/page/content/booking IDs | object + actor + scope authorization; anti-enumeration result | Security/Privacy owner | per-surface hostile-ID matrix before owning runtime | blocked |
| TM-04 | S/T/E | Critical | ACT-03/04 | A-02/05; TB-03/04 | confused deputy between personal and Professional Page workspaces | explicit scope, current membership/capability revision, PublisherRef validation | Identity owner | workspace-switch/revocation/concurrency tests before R2 | blocked |
| TM-05 | T/R/E; abuse | Critical | ACT-06 | A-02/05/06/10; TB-08 | Admin/support bypasses domain invariants | bounded capability, case/reason, dual control where required, owning command, audit | Admin Operations owner | privilege and repair-workflow tests; BCK-19 gate | blocked |
| TM-06 | T/E | Critical | ACT-02/03 | A-05/06/09; TB-05 | direct client write corrupts authoritative Firestore data | deny Rules, server-only authority, protected-family Rules tests | Security/Privacy owner | Emulator Rules suite before production schema | blocked |
| TM-07 | T/E | Critical | ACT-07/10 | A-02/05/06; TB-03/04 | Function/IAM bypasses Rules without equivalent authorization | shared authorization port, least-privilege identity, handler review | Platform Operations owner | IAM matrix and handler negative tests before R1/R2 | blocked |
| TM-08 | T/E | High | ACT-02/03 | A-05/06; TB-02/03 | mass assignment or unknown fields alter protected state | closed schemas, allowlisted mapping, bounded collections | API Platform owner | invalid/forward fixtures before domain runtime | blocked |
| TM-09 | T/R; operations | Critical | ACT-02/10 | A-06; TB-04 | duplicate/concurrent mutation causes double booking or inventory drift | transaction, logical idempotency, expected revision, immutable ledger/audit | Booking owner | concurrency/reconciliation tests; ADR 0019 and ECL-03 gates | blocked |
| TM-10 | S/T/R | High | ACT-02/10 | A-06/09; TB-02/03 | request-attempt and logical-idempotency confusion enables replay/collision | fresh request ID, stable logical key, canonical payload hash, scoped retention/conflict | API Platform owner | API-DEC-03 and parity tests before mutation runtime | blocked |
| TM-11 | S/T/E | High | ACT-05/10 | A-09; TB-06 | forged/tampered event or unauthorized consumer effect | transactional outbox, registry/schema, consumer authorization, minimized payload | API Platform owner | OD-09 plus duplicate/gap/poison tests before effects | blocked |
| TM-12 | T/R; operations | High | ACT-10 | A-09/10; TB-06 | crash-after-effect, replay or poison message repeats external effect | effect idempotency, checkpoint, quarantine, bounded replay and audit | API Platform owner | OD-09/D3 executable evidence before effects | blocked |
| TM-13 | S/T/E | Critical | ACT-05 | A-06/09/11; TB-07 | forged/replayed provider or payment webhook | signature, timestamp, replay key, exact provider/account binding | Integrations owner | BCK-16/17-specific contract and tests before activation | blocked |
| TM-14 | I/D; abuse | High | ACT-02/05 | A-03/11/12; TB-07 | provider URL/metadata triggers SSRF or unsafe redirect | canonical URL policy, destination validation, no arbitrary fetch, egress deny | Integrations owner | provider adapter security tests before activation | blocked |
| TM-15 | T/I/D; abuse | High | ACT-02/03 | A-08/12; TB-05 | malicious upload, path traversal or cross-owner media access | bounded upload intent, opaque path, type/size validation, protected finalize/delivery | Media Platform owner | Storage Rules/scanner evidence; BCK-14 gate | blocked |
| TM-16 | I; privacy | High | ACT-07/10 | A-03/04/07/11; TB-09 | personal/sensitive data leaks through logs, errors or analytics | allowlist, pre-sink redaction, no raw payload/token/free text, separated access/retention | Security/Privacy owner | log snapshot/redaction and data-inventory tests before R2 | blocked |
| TM-17 | I; privacy/abuse | High | ACT-01/09 | A-02/03/05; TB-02/03 | account/content/private-resource enumeration | uniform responses, bounded pagination/rates and timing-safe behavior | Security/Privacy owner | response/timing/volume anti-enumeration tests before public API | blocked |
| TM-18 | D; abuse/cost | High | ACT-01/09 | A-12; TB-02 | scraping, spam, report abuse or cost amplification | layered actor/device/IP/resource quotas, App Check signal, behavior controls, kill switch | Trust & Safety owner | abuse/load model and BCK05 cost gates before public cohort | blocked |
| TM-19 | S/I/E; privacy | Critical | ACT-01/02/04 | A-03/04; TB-02/03 | privacy request submitted/exported by wrong person | authenticated request, step-up, server-bound subject/scope, owner-bound export capability | Security/Privacy owner | DSR contract/security tests; BCK04-OD-08 | blocked |
| TM-20 | T/R; privacy | High | ACT-10 | A-03/04/08/10; TB-04/11 | deletion reported complete while copies remain | per-domain tasks, monotonic revision, reconciliation, exception evidence | Security/Privacy owner | deletion/export/restore drill and retention decisions | blocked |
| TM-21 | S/E; privacy | Critical | ACT-04/10 | A-01/02; TB-02/03 | stale cached authorization survives revocation | current-grant evaluation for mutations/reads/results, revision/expiry, cache not authority | Identity owner | revoke-during-query/request and stale-cache tests before R2 | blocked |
| TM-22 | T/E; operations | High | ACT-07/10 | A-09; TB-12 | policy/config rollback or unknown revision weakens controls | immutable revision/hash, monotonic activation, fail-closed unknown, signed release evidence | Platform Operations owner | older/newer/rollback fixtures before configuration activation | blocked |
| TM-23 | I/E; operations | Critical | ACT-07/08 | A-11; TB-10 | service secret/signing key exposed in repo, client, logs or CI | workload identity, secret manager, scoped access, rotation and leak response | Platform Operations owner | secret scan/IAM/rotation evidence; BCK05-OD-02 | blocked |
| TM-24 | S/T/E; operations | Critical | ACT-08 | A-09/11; TB-10 | dependency/build/release supply-chain compromise | lockfiles, review, provenance/signing, same-artifact promotion, protected approvals | Release Operations owner | BCK05-OD-07 and hosted CI evidence before R1+ | blocked |
| TM-25 | I/T/E; privacy/operations | Critical | ACT-07/10 | A-03/04/09/11; TB-10/11 | environment mix-up or production data copied to non-prod | isolated projects/identities/billing, environment assertion, synthetic stage data | Platform Operations owner | OD-07 and isolation tests before provisioning | blocked |
| TM-26 | I/T/D; privacy/operations | Critical | ACT-07/08/10 | A-03/04/06/10/11; TB-11 | backup/export theft, destructive restore or unreconciled recovery | encryption, isolated restore identity, approval, immutable evidence, quarantine/reconciliation | Platform Operations owner | accepted RPO/RTO and passed restore drill before production backup | blocked |
| TM-27 | D; abuse/cost | High | ACT-01/02/09 | A-12; TB-02/04 | quota exhaustion or unbounded query/function fan-out | bounded pages/batches, indexes, deadlines, concurrency/queue caps, quotas, kill switches | Platform Operations owner | BCK05-OD-03/04 load/cost evidence before cohort | blocked |
| TM-28 | I; privacy/safety | High | ACT-02/03/10 | A-03/07; TB-03/04 | precise location/route data exposed through public projection | protected source, sanitized projection, explicit action, precision minimization | Security/Privacy owner | affected-domain projection/privacy tests before publication | blocked |
| TM-29 | T/I; safety | High | ACT-10 | A-05/09; TB-12 | unsafe localization fallback changes legal/safety meaning | fallback-forbidden classes, required local revision, typed missing and disabled feature | Reference Data owner | OD-10/BCK20 locale fixtures before market activation | blocked |
| TM-30 | T/E; operations | High | ACT-02/04 | A-02/09; TB-02/12 | outdated client bypasses required security/policy behavior | server minimum client, contract/policy revision, typed rejection, safe read/cancel | API Platform owner | API-DEC-04 compatibility tests before enforcement | blocked |
| TM-31 | S/I/E; privacy/abuse | High | ACT-02/05 | A-03/04/11/12; TB-07 | AI prompt/tool injection accesses private data or mutates authority | redaction, read-tool allowlist, no authority, quotas and kill switch | AI Platform owner | BCK-15 provider-specific addendum and executable gate | blocked |
| TM-32 | T/I; privacy/safety | High | ACT-07/10 | A-02/03/10; TB-03/09 | automated/profile decision materially affects user without safeguards | applicability assessment, explanation, contest/human review, child safeguards | Security/Privacy owner | BCK04-OD-11/14 and affected-domain qualified review before activation | blocked |
| TM-33 | T; operations | Medium | ACT-02/10 | A-02/06/09; TB-02/04 | clock/timezone manipulation changes eligibility, expiry or local-date identity | server UTC, object IANA zone, client time as hint only | API Platform owner | DST/boundary/skew tests before affected runtime | blocked |
| TM-34 | I/E; privacy | High | ACT-06/07 | A-03/04/10; TB-08/09 | overbroad export/admin query exposes unrelated users/workspaces | scoped query builder, least privilege, size bounds, manifest and audit | Admin Operations owner | cross-scope export/admin tests before BCK-19 runtime | blocked |
| TM-35 | T/R; operations | High | ACT-06/07/10 | A-10; TB-04/09 | audit/evidence tampering or silent deletion | append-only writer, restricted reads, integrity/revision evidence, hold policy | Security/Privacy owner | IAM/integrity/reconciliation tests before evidence authority | blocked |
| TM-36 | T/E; operations | High | ACT-07/10 | A-09; TB-10/12 | accidental feature activation before market/security readiness | default-off server flags, environment+market gates, policy revision and rollback | Release Operations owner | launch-gate/configuration tests before activation | blocked |
| TM-37 | S/E; abuse | Critical | ACT-01/09 | A-01/02; TB-01/02 | credential stuffing, unsafe account linking/recovery or session fixation takes over account | provider-safe linking, verified recovery, rotation, anti-automation, recent-auth/step-up | Identity owner | BCK-06 identity lifecycle and hostile recovery tests before R2 | blocked |
| TM-38 | I; privacy/abuse | High | ACT-01/02/09 | A-02/03/05; TB-02/03 | list/search/count/timing response leaks protected population or state | authorization before query/result, uniform bounds, minimized counts, timing/volume controls | Security/Privacy owner | query-shape and statistical inference tests before protected reads | blocked |
| TM-39 | E; abuse/operations | Critical | ACT-07/10 | A-02/09/12; TB-02/10 | App Check recovery disables another mandatory control or becomes permanent bypass | explicit monitor/disabled state; AuthN/AuthZ/validation/rate/audit never bypassed; expiry/revoke | Security/Privacy owner | BCK04-OD-04 decision and degraded-mode tests before enforcement | blocked |
| TM-40 | S/T/R; operations | High | ACT-05/10 | A-09/10/11; TB-06/07 | webhook/event key rotation, ordering or replay-window defect accepts forged or stale work | canonical signing input, overlap-safe rotation, timestamp/order policy, replay store, quarantine | Integrations owner | provider/event-specific rotation/order/replay tests before effects | blocked |
| TM-41 | I/D; abuse | High | ACT-02/05 | A-03/11/12; TB-07 | DNS rebinding, redirect chain or address normalization reaches private/internal target | resolve and revalidate every hop, deny private/link-local/metadata ranges, bounded egress | Integrations owner | SSRF/DNS-rebinding suite before server-side fetch | blocked |
| TM-42 | T/I/D; privacy/abuse | High | ACT-02/03 | A-08/12; TB-05 | MIME/polyglot spoofing, decompression bomb or metadata leaks private data | signature sniffing, decode bounds, re-encode/scan, metadata strip, isolated processing | Media Platform owner | hostile corpus, memory/time and metadata tests; BCK-14 gate | blocked |
| TM-43 | S/T/I/E; operations | High | ACT-08 | A-09/11; TB-10 | dependency confusion or compromised builder produces unverifiable artifact or exfiltrates secret | pinned source, isolated builder identity, SBOM/provenance, policy verification, no long-lived secret | Release Operations owner | provenance/dependency-confusion/secret tests before R1+ | blocked |
| TM-44 | D; abuse/cost | High | ACT-01/02/09/10 | A-09/12; TB-02/04 | hot document, cache stampede or noisy tenant starves others and amplifies spend | partitioning, request coalescing, bounded freshness, per-actor/tenant fairness and budgets | Platform Operations owner | contention/load/fairness/cost tests before cohort | blocked |
| TM-45 | T/I; privacy | Critical | ACT-07/10 | A-03/04/08/10; TB-04/11/12 | late job, import, projection rebuild or restore silently resurrects erased/restricted data | monotonic privacy markers/revisions, pre-write checks, quarantine and reconciliation | Security/Privacy owner | late-work/import/rebuild/restore DSR drill before production data | blocked |
| TM-46 | I/T; privacy/operations | High | ACT-07/10 | A-03/05/09; TB-10/12 | disabled EE/LT market receives LV data, flags or processing through fallback | independent market gates, explicit dataset/config identity, no cross-market fallback | Platform Operations owner | LV/EE/LT isolation and disabled-market tests before expansion | blocked |
| TM-47 | S/T/R; privacy | Critical | ACT-02/04/10 | A-03/10; TB-02/03/04 | DSR attempt/logical/receipt identities or cancel/unknown outcome are conflated | fresh request ID, stable idempotency key/payload, server privacy ID, monotonic state and boundary-aware cancel | Security/Privacy owner | DSR retry/cancel/reconciliation tests; BCK04-OD-08 | blocked |
| TM-48 | S/I/E; privacy | Critical | ACT-01/04 | A-03/04/11; TB-02/03 | stolen/replayed export link or raw email attachment discloses privacy export | authenticated owner-bound short-lived purpose capability, step-up, single use, audit/revoke; no raw attachment | Security/Privacy owner | export capability theft/replay/delivery tests; BCK04-OD-08 | blocked |
| TM-49 | I/E; privacy | High | ACT-02/04/10 | A-02/03; TB-02/03 | stale authorization or out-of-order page/result reveals data after revocation | current-grant check per continuation/result, revision/freshness, monotonic client reconciliation | Identity owner | revoke-during-pagination/stream and out-of-order tests before protected query | blocked |

## 9. Privacy-specific misuse cases

1. A user views another person's Booking/private Scenario by changing an ID.
2. A page member publishes as a different page after membership revocation.
3. A support operator searches private data without a case or business reason.
4. Precise location enters analytics or logs despite public-coordinate intent.
5. A deletion request removes the source but leaves a discoverable projection.
6. A localization fallback displays non-local legal copy where local copy is
   mandatory.
7. Age/guardian claims from the client unlock a restricted function.
8. An export bundles another workspace because ownership and publisher scope
   were conflated.
9. A stale pagination token continues returning protected rows after access is
   revoked.
10. A retry creates a second privacy request because attempt, logical and
    server receipt identities were conflated.
11. Erased data returns through a late worker, import, projection rebuild or
    restored backup.
12. A disabled Baltic market inherits another market's data or activation flag
    through fallback.

Each case requires a named negative test before its production surface opens.

## 10. Control ownership

| Control family | Primary owner | Required collaborators |
|---|---|---|
| Auth/session/capability/revocation | BCK-06 Identity | BCK-04, Mobile |
| API schemas/errors/idempotency/minimum client | BCK-03 API Platform | domains, Security, Mobile |
| Rules/IAM/secrets/privacy/incident policy | BCK-04 Security/Privacy | BCK-05, Legal, domains |
| Environment/release/SLO/cost/backup | BCK-05 Operations | Security, Finance, domains |
| Booking atomicity/ledger/audit | BCK-09 Booking | API, Security, Operations |
| Content/public projections/moderation | BCK-07/08/22 | Identity, Media, Security |
| Media upload/delivery | BCK-14 Media | Content, Security, Operations |
| Provider/webhook boundary | BCK-16; BCK-17 if Payments accepted | Booking, Security, Operations |
| Reference/localization policy | BCK-20 | API, Mobile, Content, Legal |
| Privacy request orchestration | BCK-04 | every authoritative domain |

No control owner gains write authority over another domain's source records.

## 11. Required verification matrix

| Evidence family | Minimum proof |
|---|---|
| Contract | valid/invalid/forward fixtures, closed fields, bounds, typed errors |
| Authorization | unauthenticated, wrong user/page/workspace, revoked, stale and admin-negative cases |
| Rules/IAM | deny-by-default, cross-user/scope denial, service least privilege |
| Transaction | duplicates, concurrency, timeout/unknown outcome, rollback and ledger reconciliation |
| Events | duplicate, gap, poison, crash-after-effect, replay and quarantine |
| Privacy | export scope, deletion propagation, exception/partial completion and audit |
| Operations | environment isolation, secret scan, provenance, rollback, load/cost and restore drill |
| Market/policy | unknown/newer/older revision, LV exact policy and EE/LT disabled state |
| Incident | detection, triage, containment, evidence preservation and notification decision exercise |
| Identity lifecycle | credential stuffing, linking/recovery takeover, fixation, revocation and recent-auth bypass |
| Protected reads | list/search/count/timing, revoke-during-page/stream and out-of-order result disclosure |
| DSR lifecycle | split identities, payload/key conflict, pre-send cancel, unknown outcome, irreversible boundary and export replay |
| Hostile ingress | webhook rotation/order/replay, DNS rebinding/redirect and hostile media corpus |
| Supply chain | dependency confusion, isolated builder identity, provenance mismatch and secret exfiltration |
| Resilience/cost | hot-key, fan-out, cache stampede, fairness, budget containment and disabled-market isolation |

A skipped, timed-out or non-reproducible test is inconclusive, never Pass.

## 12. Residual risks and fail-closed decisions

| Residual risk | Current treatment |
|---|---|
| no independent security review | disclose; owner verdict cannot claim independence |
| no qualified Legal/Privacy conclusion | OD-11 and applicable BCK-04/OD-07/OD-10 gates remain blocked |
| infrastructure topology not Accepted | no location-bound resource creation |
| IAM/secrets/release toolchain not selected | no executable backend scaffold |
| numerical SLO/cost/RPO/RTO proposals exist but owner/stage/restore acceptance evidence is absent | no production Approval/provisioning claim |
| product/cloud Rules/handlers/tests absent | product/cloud runtime remains Absent; bounded RAW-C local evidence does not close target gates |
| AI/provider/Payments integrations undecided | surfaces remain disabled and directories/resources uncreated |
| all Critical/High residual states are blocked | no production surface opens until its named evidence/gate changes the exact threat disposition |

## 13. BCK04-OD-01 acceptance gate

`BCK04-OD-01` may become Accepted only when:

1. the combined-owner technical verdict is recorded against the exact amended
   version and explicitly does not claim independence;
2. an independent Security/Privacy review and API, Operations, Identity,
   Mobile and affected-domain confirmations record no unresolved contradiction;
3. every Critical/High threat has an accountable owner, blocking gate, target
   evidence and explicit residual disposition;
4. every Critical/High threat maps to a current incident response-path ID;
   exact severity/privacy-risk judgment and passed tabletop remain independent
   `BCK04-OD-09` gates and are not inferred from OD-01;
5. OD-07/OD-11 and Legal decisions remain visibly separate and are not claimed
   closed by this technical model;
6. any required amendments are integrated and rechecked;
7. BCK-04, its coverage matrix, D1 ledger/review package, BCK-01/02 and
   LAUNCH_STATUS update atomically.

Acceptance of this threat model still does not authorize backend code,
Firebase, credentials, deployment or production processing.

## 14. Revision checksum and traceability gate

Counts below are a checksum for v0.2, not permanent product limits:

| Dimension | v0.2 checksum |
|---|---:|
| Assets | 12 |
| Actors | 10 |
| Trust boundaries | 12 |
| Threats | 49 |
| Critical / High / Medium | 20 / 28 / 1 |
| STRIDE S / T / R / I / D / E references | 15 / 29 / 8 / 23 / 8 / 24 |
| privacy / abuse / cost / safety / operations tags | 20 / 13 / 3 / 3 / 15 |
| Threats missing accountable owner | 0 |
| Threats missing evidence/gate | 0 |
| Threats missing residual disposition | 0 |
| Current `acceptedResidual` threats | 0 |

Any change to a stable asset, actor, boundary or threat ID updates this summary
and every affected cross-reference in the same revision. CI may mechanically
verify counts and required cells later; this documentation adds no executable
gate or runtime authority.

## 15. Acceptance criteria

1. **BCK04-TM-AC-01:** assets, actors and trust boundaries are explicit.
2. **BCK04-TM-AC-02:** authenticated sessions are not treated as authority.
3. **BCK04-TM-AC-03:** client-supplied capability/workspace/publisher is untrusted.
4. **BCK04-TM-AC-04:** direct authoritative writes are denied by default.
5. **BCK04-TM-AC-05:** Function authorization is not delegated to Rules.
6. **BCK04-TM-AC-06:** Booking atomicity and idempotency remain domain-owned.
7. **BCK04-TM-AC-07:** events are at-least-once and authority-free.
8. **BCK04-TM-AC-08:** admin actions preserve owning-domain invariants.
9. **BCK04-TM-AC-09:** logs/analytics cannot silently receive sensitive data.
10. **BCK04-TM-AC-10:** privacy export/deletion has cross-domain evidence.
11. **BCK04-TM-AC-11:** environment and market isolation are distinct.
12. **BCK04-TM-AC-12:** unknown critical policy/version fails closed.
13. **BCK04-TM-AC-13:** every Critical/High threat has an owner/gate/evidence path.
14. **BCK04-TM-AC-14:** qualitative priority is not called incident severity.
15. **BCK04-TM-AC-15:** Legal/DPIA/ROPA conclusions are not invented.
16. **BCK04-TM-AC-16:** self-review is disclosed and not called independent.
17. **BCK04-TM-AC-17:** future AI/provider/Payments surfaces remain gated.
18. **BCK04-TM-AC-18:** skipped/timeout evidence is not Pass.
19. **BCK04-TM-AC-19:** threat-model acceptance is separate from runtime.
20. **BCK04-TM-AC-20:** this document creates no code or cloud resource.
21. **BCK04-TM-AC-21:** asset, actor, boundary and threat IDs are stable.
22. **BCK04-TM-AC-22:** every threat records STRIDE class and applicable
    privacy/abuse/cost/safety/operations tags.
23. **BCK04-TM-AC-23:** target control prose is not implementation evidence.
24. **BCK04-TM-AC-24:** every threat has one accountable owner, evidence gate
    and residual disposition.
25. **BCK04-TM-AC-25:** Critical residual risk cannot be silently accepted.
26. **BCK04-TM-AC-26:** accepted residual risk requires bounded owner/expiry
    and compensating-control evidence.
27. **BCK04-TM-AC-27:** DSR attempt, logical and server receipt identities are
    distinct.
28. **BCK04-TM-AC-28:** DSR scope is server-bound and cancellation/unknown
    outcome semantics are not conflated.
29. **BCK04-TM-AC-29:** protected reads and result disclosure re-evaluate
    current authority.
30. **BCK04-TM-AC-30:** privacy export is owner-bound, short-lived and never a
    raw ordinary-email attachment.
31. **BCK04-TM-AC-31:** late work/import/rebuild/restore cannot silently
    resurrect erased or restricted data.
32. **BCK04-TM-AC-32:** identity linking/recovery/fixation and credential
    stuffing have explicit threat coverage.
33. **BCK04-TM-AC-33:** App Check degraded recovery cannot bypass mandatory
    security controls.
34. **BCK04-TM-AC-34:** query inference, hostile webhook/URL/media and supply-
    chain cases have named gates.
35. **BCK04-TM-AC-35:** availability/cost controls include contention,
    stampede and per-actor/tenant fairness.
36. **BCK04-TM-AC-36:** disabled markets cannot inherit another market's data
    or activation through fallback.
37. **BCK04-TM-AC-37:** future AI/provider/Payments activation requires an
    exact provider/data-flow threat-model addendum.
38. **BCK04-TM-AC-38:** OD-01 and OD-09 are independently decidable and neither
    is inferred from the other.
39. **BCK04-TM-AC-39:** checksum mismatches or missing required cells are
    inconclusive, never Pass.
40. **BCK04-TM-AC-40:** combined-owner technical acceptance does not accept
    BCK04-OD-01, replace independent review or authorize runtime, Firebase,
    credentials, deployment, push or merge.
