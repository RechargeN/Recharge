# Recharge Backend — Event Booking Specialist Review Package

- ID: **BCK09-REV-01**
- Version: **0.3**
- Date: **2026-08-26**
- Status: **Specialist review in progress — API technical Hold; all signatures Pending**
- Target: **BCK-09 v1.4**
- Product baseline: **BCK09-A1-STAGED-FREE-BOOKING-v1 — Accepted with controls**
- Product decision:
  [BCK09-DEC-01 v0.2](BACKEND_EVENT_BOOKING_OWNER_DECISION.md)
- Coverage evidence:
  [BCK-09-PRE v1.3](BACKEND_EVENT_BOOKING_COVERAGE_MATRIX.md)
- Target specification:
  [EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md)
- API Platform pre-review:
  [BCK09-API-REV-01 v0.1 — Hold](BACKEND_EVENT_BOOKING_API_PLATFORM_REVIEW.md)
- Frozen source hashes:
  - convention: SHA-256 of UTF-8 text normalized to LF line endings
  - BCK-09 v1.4 SHA-256: `7c97ccb22200c9e5d0b7ef54dbbc17557df3e4d0ad3b73f14e2d21d3496c3d14`
  - ECL-03C v1.2 SHA-256: `f0a307e2d6419a40bf397de7948d495e7bd803387cb79ee897d1c62b9ea39b3c`
  - BCK-09-PRE v1.3 SHA-256: `72bd8128d85d21511eb7b19e931376e2219b6b2bf7b6cd048c25d959f9eb03f2`
- Runtime effect: **none**

---

## 0. Verdict

**Specialist review opened; API technical pre-review is Hold.**

BCK-09 v1.4 and ECL-03C v1.2 incorporate TR-09..11 without changing the
Product-selected callable/product scope. The review surface is internally
reconcilable at the previously reviewed boundaries, but BCK09-API-REV-01 now
records two hidden contract gaps, two blocking API decisions, one ID-format
owner conflict and missing executable parity evidence. This verdict does not
approve BCK-09, sign any specialist row, approve ECL-03C, create a Firebase
resource or authorize implementation. All nine specialist verdicts below
remain `Pending`.

## 1. Purpose

This package is the single review surface between the Product decision and a
possible BCK-09 documentation Approval. It:

1. freezes the exact input versions reviewed;
2. assigns one bounded question to each specialist role;
3. separates design acceptance from later runtime proof;
4. records amendments, conflicts, evidence and signatures without silently
   editing the accepted Product decision;
5. prevents a combined bootstrap owner or Codex review from being represented
   as independent Security, API, Operations or qualified Legal advice.

It is not an implementation plan. The only first executable candidate remains
ECL-03C v1.2, still in Review and not authorized.

## 2. Authority and frozen inputs

| Input | Version/status used | Review meaning |
|---|---|---|
| ADR 0019 | Accepted | Authoritative internal Booking ledger invariants |
| Event Classification | v2.2.3 Accepted | Canonical Event/admission semantics |
| ECL-03 | v1.2 Approved; activation gated | Parent staged delivery contract |
| ECL03-D01–D11 | Accepted | Normative product/architecture decisions |
| ECL-03B | v1.1 Done; contracts/domain only | Booking v1 wire and pure-domain evidence |
| ECL-03C | v1.2 Review; runtime not authorized | Only first executable candidate; deterministic active key added |
| BCK-09 | v1.4 Review; runtime Absent | Target under review |
| BCK-09-PRE | v1.3 Review | 22/22 reconciliation plus API technical Hold evidence |
| BCK09-DEC-01 | v0.2 Accepted with controls | Product baseline and ten dispositions |
| BCK09-API-REV-01 | v0.1 Technical Hold | API evidence/findings only; not a named signature |
| BCK-03/04/05/06/07/13/18/19 | Current repository statuses | Parent/peer proposals and blockers; no inherited Approval |
| OD-09 | Proposed | Required before cross-domain effects |
| OD-11 | Open | Required before applicable age-sensitive paths |

If any listed major contract, single-writer boundary, Booking v1 schema or
BCK09 disposition changes, this package becomes stale and must be revised
before a signature is recorded.

## 3. Gate split: what can be reviewed now

### 3.1. Design sign-off available now

A named specialist may review and accept:

- responsibility and single-writer boundaries;
- fail-closed defaults and prohibited shortcuts;
- target API, authorization, privacy and operational semantics;
- evidence requirements and activation gates;
- staged ownership of ECL-03C–H.

An `Accept with runtime controls` verdict accepts only that design boundary.
It does not claim that later runtime evidence already exists.

### 3.2. Runtime proof unavailable now

The following cannot be signed as passed from documentation:

- deployed callable endpoints, Rules, IAM or App Check enforcement;
- TypeScript fixture parity and executable canonical hashing;
- emulator concurrency/idempotency/security results;
- production Identity/capability/revocation authority;
- revision-safe published Event projection handoff;
- notification delivery workers or accepted OD-09 transport;
- load, cost, backup, restore or disaster-recovery evidence;
- production retention/deletion execution;
- production mobile adapter/cutover evidence.

These stay explicit later gates even if all design reviews are accepted.

## 4. Technical pre-review findings

| ID | Result | Finding | Required treatment |
|---|---|---|---|
| BCK09-TR-01 | Pass | ADR 0019, ECL-03 and BCK-09 authority order is explicit | Preserve hierarchy |
| BCK09-TR-02 | Pass | ECL-03C is separated from target ECL-03D–H behavior | No inherited authorization |
| BCK09-TR-03 | Pass | Booking v1 and D11 split request/idempotency identity are preserved | Require fixture parity before endpoint runtime |
| BCK09-TR-04 | Pass | Booking, Event, availability, notification and repair writers are distinct | Do not add cross-domain direct writes |
| BCK09-TR-05 | Pass | Finite and explicit-unlimited paths fail closed for unknown capacity | Preserve atomic invariant tests |
| BCK09-TR-06 | Pass | Timeout remains unknown and local/mock state cannot confirm Booking | Preserve typed mobile recovery |
| BCK09-TR-07 | Pass | Waitlist/holds are excluded from ECL-03C | Keep sold-out result non-mutating |
| BCK09-TR-08 | Pass | Personal data, age policy and market activation remain gated | Qualified Legal/Privacy input still required |
| BCK09-TR-09 | Resolved in BCK-09 v1.4 / ECL-03C v1.2 | Exact versioned tuple and deterministic `bookingActiveKeys` record are atomic for finite/unlimited create/cancel | API specialist must still validate hash/contract implementation and emulator contention proof before runtime |
| BCK09-TR-09A | Pass | Booking v1 create has no client `bookingId`; one server candidate ULID is generated before the transaction callback, reused across internal retries and returned only after commit | Preserve Booking v1 wire/fixture parity and callback-retry ID test; a client-ID variant requires a separately versioned contract |
| BCK09-TR-10 | Resolved in BCK-09 v1.4 | BCK-19 exclusively owns proposal/approval; BCK-09 exposes only `ExecuteApprovedBookingRepair` | Admin/Security specialist verdict and later runtime proof remain required |
| BCK09-TR-11 | Resolved in BCK-09 v1.4 / ECL-03C v1.2 | Immutable `suppressedPreActivation` versus `handoffRequired` disposition distinguishes no-effect records from BCK-13 obligations; C writes only terminal suppressed evidence | Notifications/API specialist verdict and Accepted OD-09 remain required |
| BCK09-TR-12 | Pending evidence | Production Identity and Event projection authority do not exist | Keep all commands disabled |
| BCK09-TR-13 | Pending evidence | Notification, repair and operational proof do not exist | Keep effects/repair/cohort disabled |
| BCK09-TR-14 | Pending evidence | No qualified per-market Legal/Privacy verdict is recorded | Do not process production personal data |
| BCK09-TR-15 | API technical Hold | Booking v1 schema/DTO command matrix, atomic request-attempt binding, API-DEC-01/03 and request-ID format require closure | Apply BCK09-API-REV-01 required amendments/owner decisions; keep `BCK09-SIG-API` Pending |

The three amendments do not reopen the Product-selected staged free-Booking
baseline. TR-10/11 implement its accepted single-writer/fail-closed controls;
TR-09 freezes the missing physical invariant under Deferred/Open BCK09-OD-02.

Firestore guarantees serializable transaction isolation by commit time and
retries transactions when read data is concurrently changed, but those
platform guarantees do not choose Recharge's physical uniqueness predicate,
record or index strategy. The executable contract must make that application
invariant explicit and contention-test it:
[transaction isolation](https://firebase.google.com/docs/firestore/transaction-data-contention),
[transactions](https://firebase.google.com/docs/firestore/manage-data/transactions).

## 5. Specialist signature matrix

| Sign-off ID | Reviewer role | Design scope | Current verdict | Runtime/activation gate retained |
|---|---|---|---|---|
| BCK09-SIG-API | API Platform | Booking v1 adapter, callable profile, deadlines, canonical request hash, compatibility | Pending — technical Hold in BCK09-API-REV-01 v0.1 | No mutation endpoint before TR-01..06 closure, API-DEC-01/03 and Dart/TypeScript fixture parity |
| BCK09-SIG-SEC | Security/Privacy | AuthZ, Rules/IAM, App Check, abuse, logs, fail-closed OD-11 posture | Pending | No production commands/data before executable controls and security evidence |
| BCK09-SIG-ID | Identity | Account state, revocation, Viewer and exact-page capabilities | Pending | Deny commands until BCK-06/BCK-18 production authority evidence |
| BCK09-SIG-CONTENT | Content Platform | Pinned published Event projection writer, revision and barrier handoff | Pending | Mutations off until BCK-07 runtime handoff is revision-safe |
| BCK09-SIG-NOTIF | Notifications | Booking obligation versus inbox/delivery ownership, dedupe and minimized push | Pending | No delivery worker/effect before Accepted OD-09 and BCK-13 executable approval |
| BCK09-SIG-OPS | Platform Operations | Environment, flags, SLO, cost, backup/RPO/RTO, rollout and rollback | Pending | No cohort/GA before staging/load/cost/restore evidence |
| BCK09-SIG-MOBILE | Mobile Platform | Typed adapter, unknown outcome, cache/freshness and no offline authority | Pending | No remote adapter/cutover before separately Approved ECL-03G |
| BCK09-SIG-ADMIN | Admin Operations | Case/proposal/approval and exact owning-domain repair command | Pending | No direct/manual repair; drifted pools remain blocked |
| BCK09-SIG-LEGAL | Qualified Legal/Privacy | Per-market legal basis, rights, retention/deletion and age policy | Pending; qualification not evidenced | No production personal data or applicable age-sensitive path |

The Product owner may coordinate these reviews but cannot count one Product
decision as nine independent signatures. Legal/Privacy is never inferred from
technical or product approval.

## 6. Role review checklists

### 6.1. API Platform — BCK09-SIG-API

Review BCK-09 §§10, 13, 20–21 and AC-28..30, AC-50, AC-63..65:

Use [BCK09-API-REV-01](BACKEND_EVENT_BOOKING_API_PLATFORM_REVIEW.md) as the
bounded evidence/findings package; it is not a substitute for the named verdict.

- Booking v1 remains the wire source without a second incompatible envelope;
- callable/HTTPS mapping and deadlines have one future executable owner;
- canonical hash input, algorithm and version will be fixture-tested;
- retry keeps semantic payload/key and creates a fresh request ID;
- unknown schema/enum fails before mutation.

### 6.2. Security/Privacy — BCK09-SIG-SEC

Review BCK-09 §§7, 16–17 and AC-6..8, AC-41..43, AC-46, AC-74:

- server context is the only actor/capability authority;
- Admin SDK bypass of Rules is controlled by least-privilege IAM;
- App Check is defense in depth, never authorization;
- logs/metrics exclude PII, secrets, free text and access codes;
- OD-11-sensitive paths remain disabled per market.

### 6.3. Identity — BCK09-SIG-ID

Review BCK-09 §§7, 11, 16 and AC-6..7, AC-74:

- account status, auth revision and revocation are checked server-side;
- Creator status never implies page-scoped `manage_bookings`;
- personal and Professional Page authority use exact IDs;
- cached/mobile claims cannot grant authority;
- deleted/suspended/revoked accounts fail closed.

### 6.4. Content Platform — BCK09-SIG-CONTENT

Review BCK-09 §§9, 12.6 and AC-32..33, AC-68:

- BCK-07 alone writes published Event lifecycle/configuration;
- BCK-09 consumes a pinned, revisioned operational input;
- material occurrence change uses a write barrier and bounded processing;
- local drafts/mock participant counters never seed capacity;
- cutover/rollback preserves one writer at every moment.

### 6.5. Notifications — BCK09-SIG-NOTIF

Review BCK-09 §§14–15 and AC-34..37, AC-70..71:

- BCK-09 transaction writes only the delivery obligation;
- BCK-13 owns inbox, preferences, registrations and attempts;
- FCM is a minimized hint and not proof of reading;
- retry/dedupe/dead-letter semantics require Accepted OD-09;
- no notification failure rolls back committed capacity state.

### 6.6. Platform Operations — BCK09-SIG-OPS

Review BCK-09 §§6, 14, 18, 22–24, 26 and AC-44..60:

- dev/staging/prod isolation and region choices match accepted controls;
- all flags are server-owned, environment-scoped and default-off;
- zero-tolerance invariants stop rollout automatically;
- cost/load/SLO evidence is required before cohort growth;
- backup/PITR and isolated restore do not bypass Privacy retention/deletion.

### 6.7. Mobile Platform — BCK09-SIG-MOBILE

Review BCK-09 §§10, 20–22 and AC-4, AC-30, AC-35..36, AC-47..50, AC-57, AC-75:

- Flutter uses typed API contracts and never operational Firestore;
- timeout is an unknown outcome resolved by same-key retry/query;
- stale/unknown availability is displayed honestly;
- offline/local/mock state never confirms Booking;
- deep links re-authorize and ECL-03G owns cutover.

### 6.8. Admin Operations — BCK09-SIG-ADMIN

Review BCK-09 §19 and AC-38..40, AC-73:

- reconciliation detects and blocks but does not silently repair;
- BCK-19 owns case, dry-run proposal and second approval;
- BCK-09 alone executes the versioned invariant-safe repair command;
- the command is idempotent, audited and post-checked;
- Firestore Console editing is not an operating procedure.

### 6.9. Qualified Legal/Privacy — BCK09-SIG-LEGAL

Review BCK-09 §§17, 24 and AC-41..43, AC-59..61, AC-74:

- legal basis and data-subject rights are stated per enabled market;
- retention/deletion/pseudonymization classes and backup behavior are lawful;
- access blocking and deletion completion semantics are sufficient;
- Latvia approval does not activate Estonia or Lithuania;
- OD-11 supplies a qualified, market-versioned answer before applicable paths.

This checklist is an engineering briefing, not legal advice.

## 7. Allowed verdict vocabulary

Each row accepts exactly one of:

| Verdict | Meaning |
|---|---|
| `Accept design boundary with runtime controls` | The named design scope is accepted; later evidence and activation gates remain |
| `Accept with amendments` | Not effective until exact amendments are incorporated and re-reviewed |
| `Reject` | The conflicting requirement and replacement direction are recorded |
| `Inconclusive` | Missing evidence, authority or qualification is named; row remains open |

`Pass`, `looks good`, generic continuation, a Product-owner verdict, a Codex
technical review or document presence is not a specialist signature.

## 8. Required signature record

Every effective review entry must contain:

```text
Sign-off ID:
Reviewer role:
Named reviewer identity:
Organization/team:
Qualification or authority basis:
Target: BCK-09 v1.4 / BCK09-REV-01 v0.3
Verdict:
Accepted scope:
Required amendments:
Evidence links:
Residual risks:
Runtime gates retained:
Signed UTC:
Review-by / expiry:
```

Missing identity, scope, verdict, evidence or timestamp makes the row
`Inconclusive`. A reviewer signs only their own accountable scope.

## 9. Status transition contract

BCK-09 can move from `Review` to documentation `Approved` only when:

1. all nine required rows have effective verdicts;
2. every required amendment is incorporated and re-reviewed;
3. BCK09-OD-01/02/03/07 status is reconciled without inventing runtime proof;
4. hard parent dependencies required for documentation Approval have compatible
   accepted boundaries;
5. the coverage matrix is refreshed against the signed version;
6. no Accepted ADR/ECL invariant is changed silently.

Documentation Approval still does not authorize ECL-03C, Firebase, production
data, credentials, billing, deployment, push or merge to `main`.

## 10. Current blockers after this package

- all nine specialist signatures are Pending;
- API-DEC-01/03 remain unresolved for executable mutation transport/hash;
- BCK-06/BCK-18 production Identity authority is absent;
- BCK-07 revision-safe Event projection runtime is absent;
- BCK-13/OD-09 executable effect handoff is absent;
- BCK-19 repair execution integration is absent;
- OD-11 and qualified per-market Legal/Privacy evidence are absent where needed;
- ECL-03C remains Review and has no post-stabilization runtime authorization;
- Firebase/product backend and production evidence remain Absent.

## 11. Package acceptance criteria

1. **BCK09-REV-AC-01:** exact target and source snapshot are recorded.
2. **BCK09-REV-AC-02:** Product acceptance is not represented as specialist approval.
3. **BCK09-REV-AC-03:** all nine required roles have unique sign-off IDs.
4. **BCK09-REV-AC-04:** every role has a bounded review scope.
5. **BCK09-REV-AC-05:** design sign-off and runtime proof are separate.
6. **BCK09-REV-AC-06:** qualified Legal/Privacy cannot be inferred.
7. **BCK09-REV-AC-07:** BCK-09 remains Review while signatures are Pending.
8. **BCK09-REV-AC-08:** ECL-03C remains the only first executable candidate.
9. **BCK09-REV-AC-09:** ECL-03C runtime remains separately gated.
10. **BCK09-REV-AC-10:** ECL-03D–H inherit no authorization.
11. **BCK09-REV-AC-11:** Booking v1 and D11 semantics remain unchanged.
12. **BCK09-REV-AC-12:** every authoritative writer remains unique.
13. **BCK09-REV-AC-13:** OD-09 effects remain disabled.
14. **BCK09-REV-AC-14:** OD-11-sensitive paths remain disabled per market.
15. **BCK09-REV-AC-15:** local/mock state never becomes confirmed Booking.
16. **BCK09-REV-AC-16:** runtime evidence is never fabricated from target prose.
17. **BCK09-REV-AC-17:** amendments require incorporation and re-review.
18. **BCK09-REV-AC-18:** signatures include identity, scope, evidence and UTC.
19. **BCK09-REV-AC-19:** stale inputs force package revision.
20. **BCK09-REV-AC-20:** documentation Approval creates no runtime authority.
21. **BCK09-REV-AC-21:** no application/backend/Firebase file is changed.
22. **BCK09-REV-AC-22:** push and `main` merge remain separately authorized.

---

**Current conclusion:** BCK09-REV-01 v0.3 has started the specialist phase.
BCK09-API-REV-01 v0.1 records a technical Hold without impersonating a named
reviewer; the other eight review rows have not started. The Product baseline
remains accepted, all nine signatures remain Pending, and every
runtime/activation gate remains open. Runtime effect is none.
