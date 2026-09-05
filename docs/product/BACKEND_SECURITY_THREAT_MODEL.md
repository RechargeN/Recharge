# Recharge Backend — Security Threat Model

- Evidence ID: **BCK04-OD01-TM-01**
- Version: **0.1**
- Date: **2026-08-20**
- Decision served: **BCK04-OD-01 — full backend threat model**
- Decision status: **Proposed — owner verdict pending**
- Evidence status: **Draft — security review required**
- Accountable owner: **RechargeN / Product owner** (combined Security/Privacy role)
- Independence: **self-review; no independent security reviewer**
- Runtime status: **Absent**
- Parent specification: [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Architecture parent: [BCK-01](RECHARGE_BACKEND_MASTER_SPEC.md)
- API boundary: [BCK-03](BACKEND_API_CONTRACT_STANDARD.md)
- Runtime effect: **none**

---

## 1. Verdict and purpose

This document supplies the missing repository-wide, asset-oriented threat model
requested by `BCK04-OD-01`. It is a concrete **proposal**, not security approval
and not proof that controls exist in code or cloud configuration.

It covers the target Recharge backend for Latvia-first launch and the prepared,
independently disabled Estonia/Lithuania expansion. It uses STRIDE plus explicit
privacy, abuse, cost and operational-failure analysis.

Current verdict: the architecture has coherent fail-closed control boundaries,
but residual risks and executable evidence remain. `BCK04-OD-01` may move from
Open to Proposed; it cannot become Accepted until §13 passes.

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

- asset and trust boundary;
- attacker capability and misuse path;
- STRIDE category, with privacy/abuse/cost tags where relevant;
- target preventive/detective/recovery controls;
- required evidence and residual gate.

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

| Asset family | Examples | Required property |
|---|---|---|
| Session identity | provider identity, Firebase token, session/revocation state | authenticity, bounded lifetime, revocation |
| Authorization state | roles, capabilities, page membership, workspace, verification | server authority, scope integrity, freshness |
| Personal/private data | profile private fields, favorites, visits, private Scenario/Quick Plan | confidentiality, purpose limitation, rights support |
| Sensitive evidence | verification, abuse/support evidence, access codes | strict minimization, restricted service access |
| Published content | Event/Place/Route/Scenario projections, PublisherRef | provenance, lifecycle integrity, moderation state |
| Booking authority | booking, hold, inventory, usage, ledger, idempotency, audit | atomicity, consistency, non-repudiation |
| Location data | precise private position, route recordings, place/event coordinates | scope-aware disclosure and minimization |
| Media | uploads, protected originals, derived public variants | ownership, malware/content validation, access isolation |
| Operational state | outbox, leases, jobs, server flags, policy revisions | integrity, replay safety, rollback |
| Audit/evidence | security, admin, booking and privacy completion evidence | append-only integrity, access control, retention |
| Secrets/identity | service accounts, signing keys, provider secrets, CI credentials | confidentiality, least privilege, rotation |
| Availability/budget | quotas, compute, database, storage, notification/provider spend | bounded consumption, containment, recovery |

## 5. Actors and attacker capabilities

| Actor | Trust | Capabilities assumed |
|---|---|---|
| Anonymous network attacker | untrusted | send malformed/replayed traffic, enumerate identifiers, exhaust public surfaces |
| Authenticated User | untrusted for authority | valid own session, arbitrary payloads, automation and concurrency |
| Creator/page member | untrusted for scope | valid capabilities in one scope, attempts cross-page/publisher escalation |
| Compromised device/session | hostile authenticated | stolen token, cached data, automation until revocation propagates |
| Malicious/compromised provider | untrusted ingress | forged/replayed webhook or manipulated availability/booking response |
| Admin/support user | privileged but not omnipotent | access to bounded tools; may make mistakes or abuse granted scope |
| Developer/operator | privileged insider | code/config/log/backup access according to role |
| Supply-chain attacker | external/insider | dependency, build artifact, CI or release-channel compromise |
| Automated scraper/abuser | untrusted | high-rate discovery, account creation, content/report spam, cost amplification |
| Accidental system failure | non-malicious | duplicate delivery, partial commit, stale cache, clock/network/region failure |

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
5. Cross-user/scope reads use sanitized projections or explicit authorization.
6. Mutation success is returned only after durable authoritative commit.
7. Retry of an unknown mutation outcome uses the same logical idempotency key
   and semantic payload.
8. Unknown security/eligibility/money/capacity/policy versions fail closed.
9. Admin repair uses the owning domain command and immutable evidence.
10. Outbox delivery is at-least-once; consumers deduplicate and never infer
    authority from payload claims.
11. Logs, errors and analytics exclude secrets and unnecessary personal data.
12. Environment, market and workspace boundaries are independent.
13. Production data is prohibited in dev and unapproved stage workflows.
14. Every emergency bypass is narrower, time-bounded, audited and revocable.

## 8. Threat register

| ID | Priority | Threat / boundary | Required controls | Evidence and residual gate |
|---|---|---|---|---|
| TM-01 | Critical | forged/stolen token or session replay (`TB-01/02`) | provider verification, token audience/issuer/time checks, session registry, step-up, revoke and device/session limits | Auth emulator/integration/revocation tests before R2 |
| TM-02 | Critical | client-supplied role/capability/workspace/publisher accepted as authority (`TB-02/03`) | ignore authority claims; resolve current grants server-side per command/query | negative authorization fixtures and cross-scope tests |
| TM-03 | Critical | IDOR through guessed user/page/content/booking IDs (`TB-02/03`) | object + actor + scope authorization before read/mutation; anti-enumeration errors | per-surface access matrix and hostile-ID tests |
| TM-04 | Critical | confused deputy between personal and Professional Page workspaces | explicit active scope, page membership/capability revision, PublisherRef validation | workspace-switch/revocation/concurrency tests |
| TM-05 | Critical | Admin/support bypasses domain invariants (`TB-08`) | separate admin capability, case/reason, propose/approve/execute where high impact, owning command, audit | privilege and repair-workflow tests; BCK-19 gate |
| TM-06 | Critical | direct client write corrupts authoritative Firestore data (`TB-05`) | deny Rules, server-only authority, Rules tests for every protected family | emulator Rules suite before any production schema |
| TM-07 | Critical | Function/IAM access bypasses Rules without equivalent authorization (`TB-03/04`) | shared authorization middleware/port, least-privilege service identity, code review | IAM matrix and handler negative tests |
| TM-08 | High | mass assignment or unknown fields alter protected state (`TB-02/03`) | closed schemas, allowlisted mapping, bounded arrays/strings/maps | invalid/forward fixture suites |
| TM-09 | Critical | duplicate/concurrent mutation causes double booking or inventory drift (`TB-04`) | transaction, idempotency record, expected revision, immutable ledger/audit | Booking transaction/concurrency tests; ADR 0019 gate |
| TM-10 | High | request ID/idempotency key confusion enables replay/collision | distinct semantics, canonical payload hash, key scope/retention, conflict result | API-DEC-03 and mutation parity tests |
| TM-11 | High | forged/tampered event or unauthorized consumer effect (`TB-06`) | producer outbox, registry/schema, consumer authorization, minimized payload | OD-09 acceptance and duplicate/gap/poison tests |
| TM-12 | High | crash-after-effect, replay or poison message repeats external effect | effect idempotency, checkpoint, quarantine, bounded replay and audit | OD-09/D3 executable evidence |
| TM-13 | Critical | forged/replayed provider or payment webhook (`TB-07`) | signature/secret, timestamp window, replay key, exact provider/account binding | BCK-16/17-specific contract and integration tests |
| TM-14 | High | provider URL/metadata triggers SSRF or unsafe redirect | scheme/host allowlist, no arbitrary server fetch, redirect disclosure, egress policy | provider adapter security tests |
| TM-15 | High | malicious upload, path traversal or cross-owner media access | server-issued bounded upload intent, content/type/size checks, opaque paths, finalize validation, protected delivery | Storage Rules/emulator/scanner evidence; BCK-14 |
| TM-16 | High | personal/sensitive data leaks through logs, errors or analytics (`TB-09`) | structured allowlist, redaction before sink, no raw payload/token/free text, retention/access separation | log snapshot/redaction tests and privacy inventory |
| TM-17 | High | account/content/private-resource enumeration | uniform unauthorized/not-found policy, pagination/rate limits, no existence side channel | anti-enumeration timing/response tests |
| TM-18 | High | scraping, spam, report abuse or cost amplification | per-actor/device/IP/resource quotas, App Check signal, behavior controls, kill switch | abuse/load model and BCK05 budget thresholds |
| TM-19 | Critical | privacy request submitted/exported by wrong person | authenticated request, step-up when required, requester/resource eligibility, idempotency and scoped export | DSR contract/security tests; BCK04-OD-08 |
| TM-20 | High | deletion reported complete while copies remain in projections, media, logs or backups | per-domain tasks, monotonic status, reconciliation, backup propagation limit, exception evidence | deletion/export drill and Legal retention decisions |
| TM-21 | Critical | stale cached authorization survives membership/session revocation | server re-evaluation for mutation/sensitive query, grant revision/expiry, cache not authority | revoke-during-request and stale-cache tests |
| TM-22 | High | policy/config rollback or unknown revision weakens controls (`TB-12`) | immutable revision/hash, monotonic activation, compatibility window, fail-closed unknown, signed release evidence | rollback/newer/older policy fixtures |
| TM-23 | Critical | service secret/signing key exposed in repo, client, logs or CI | no client secrets, workload identity, secret manager, scoped access, rotation and leak response | secret scan/IAM/rotation evidence; BCK05-OD-02 |
| TM-24 | Critical | dependency/build/release supply-chain compromise (`TB-10`) | lockfiles, review, artifact provenance/signing, same verified artifact promotion, protected approvals | BCK05-OD-07 and CI evidence |
| TM-25 | Critical | dev/stage/prod mix-up or production data copied to non-prod | isolated projects/identities/billing, environment assertion, synthetic stage data, protected prod promotion | OD-07/environment isolation tests |
| TM-26 | Critical | backup/export theft, destructive restore or unreconciled recovery (`TB-11`) | encryption, isolated restore identity, approval, immutable evidence, reconciliation and deletion treatment | accepted RPO/RTO plus restore drill |
| TM-27 | High | quota exhaustion or unbounded query/function fan-out | bounded queries/batches/pages, indexes, deadlines, concurrency/queue limits, quotas and kill switches | load/cost tests and BCK05-OD-03/04 |
| TM-28 | High | precise location/route data exposed through public projection | separate protected source and sanitized public projection, explicit user action, precision minimization | projection/privacy tests per domain |
| TM-29 | High | unsafe localization fallback hides or changes legal/safety meaning | fallback-forbidden classes, required local revision, typed missing state, affected feature disabled | OD-10/BCK20-OD-05 plus locale fixtures |
| TM-30 | High | outdated client bypasses required security/policy behavior | server-enforced minimum client, contract/policy revision, typed rejection and safe read/cancel paths | API-DEC-04 and compatibility tests |
| TM-31 | High | AI prompt/tool injection accesses private data or mutates authority | provider-neutral gateway, redaction, read-tool allowlist, no authority, quotas/kill switch | BCK-15/AI executable gate; currently disabled |
| TM-32 | High | automated/profile decision materially affects user without safeguards | applicability assessment, explanation, contest/human review, child safeguards | BCK04-OD-11/14 and owning-domain gate |
| TM-33 | Medium | clock/timezone manipulation changes eligibility, expiry or local-date identity | server UTC time, object IANA timezone, client time only hint | DST/boundary/skew tests |
| TM-34 | High | overbroad export/admin query exposes unrelated tenants/workspaces | scoped query builder, least privilege, result size limits, export manifest/audit | cross-tenant export/admin tests |
| TM-35 | High | audit/evidence tampering or silent deletion | append-only writer, restricted reads, integrity/revision evidence, retention/hold policy | emulator/IAM and reconciliation tests |
| TM-36 | High | accidental feature activation before market/security readiness | server flags default off, environment+market gates, required policy revision, rollback | launch-gate and configuration tests |

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

A skipped, timed-out or non-reproducible test is inconclusive, never Pass.

## 12. Residual risks and fail-closed decisions

| Residual risk | Current treatment |
|---|---|
| no independent security review | disclose; owner verdict cannot claim independence |
| no qualified Legal/Privacy conclusion | OD-11 and applicable BCK-04/OD-07/OD-10 gates remain blocked |
| infrastructure topology not Accepted | no location-bound resource creation |
| IAM/secrets/release toolchain not selected | no executable backend scaffold |
| numerical SLO/cost/RPO/RTO proposals exist but owner/stage/restore acceptance evidence is absent | no production Approval/provisioning claim |
| Rules/handlers/tests absent | runtime remains Absent |
| AI/provider/Payments integrations undecided | surfaces remain disabled and directories/resources uncreated |

## 13. BCK04-OD-01 acceptance gate

`BCK04-OD-01` may become Accepted only when:

1. the combined owner records an explicit Security/Privacy verdict against this
   exact version and discloses the lack of independence;
2. API, Operations, Identity, Mobile and affected domain boundaries record no
   unresolved contradiction;
3. every Critical/High threat has an owner, blocking gate and target evidence;
4. BCK04-OD-09 supplies the actual incident severity/risk mapping;
5. OD-07/OD-11 and Legal decisions remain visibly separate and are not claimed
   closed by this technical model;
6. any required amendments are integrated and rechecked;
7. BCK-04, its coverage matrix, D1 ledger/review package, BCK-01/02 and
   LAUNCH_STATUS update atomically.

Acceptance of this threat model still does not authorize backend code,
Firebase, credentials, deployment or production processing.

## 14. Acceptance criteria

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
