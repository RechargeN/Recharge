# Recharge Backend — Event Booking Owner Decision

- ID: **BCK09-DEC-01**
- Version: **0.1**
- Date: **2026-08-26**
- Status: **Ready for owner verdict — not Accepted**
- Decision target: **BCK-09 v1.2 / BCK09-OD-01..10**
- Candidate baseline: **BCK09-A1-STAGED-FREE-BOOKING-v1**
- Target specification:
  [EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md](EVENT_BOOKING_BACKEND_FIREBASE_FULL_SPEC.md)
- Coverage evidence:
  [BACKEND_EVENT_BOOKING_COVERAGE_MATRIX.md](BACKEND_EVENT_BOOKING_COVERAGE_MATRIX.md)
- Architecture: [ADR 0019](../adr/0019-authoritative-internal-booking-ledger.md)
- Parent contract:
  [ECL-03 v1.2](EVENT_CLASSIFICATION_ECL_03_SLICE_SPEC.md)
- First executable plan:
  [ECL-03C v1.1](EVENT_CLASSIFICATION_ECL_03C_TRANSACTION_CORE_SLICE_SPEC.md)
- Accountable product verdict: **RechargeN / Product owner**
- Required independent verdicts: **API Platform, Security/Privacy, Identity,
  Content, Notifications, Operations, Mobile Platform, Admin Operations and
  qualified Legal/Privacy where applicable**
- Runtime effect: **none**

---

## 0. Current verdict state

No effective owner verdict is recorded yet. Generic continuation, approval of
documentation work, silence or file presence does not accept this decision.

## 1. Purpose

This record asks one bounded product/architecture question:

> May Recharge select `BCK09-A1-STAGED-FREE-BOOKING-v1` as the single design
> baseline for internal free Event Booking, with the dispositions and controls
> below, while keeping every executable and production gate independent?

Acceptance chooses the baseline and resolves the Product-owner part of
`BCK09-OD-01..10`. It does not approve BCK-09 as executable, authorize
ECL-03C, create Firebase resources, deploy a Function, process personal data,
enable a flag, connect mobile or merge to `main`.

## 2. Candidate baseline

`BCK09-A1-STAGED-FREE-BOOKING-v1` means exactly:

1. one provider-neutral internal **free/no-payment** Booking authority;
2. Booking remains separate from Event, provider inventory and Payments;
3. all capacity mutations use trusted online transactions and server time;
4. committed Booking v1 schemas/fixtures remain the current wire source;
5. `requestId` identifies one attempt and `idempotencyKey` one logical mutation;
6. ECL-03C is the only first executable candidate and remains separately gated;
7. ECL-03C includes only instant finite/explicit unlimited create, owner cancel
   and its five callable read/command surfaces;
8. sold out in ECL-03C creates no waitlisted Booking;
9. applications, waitlist/holds, notifications/reconfirmation, extensions,
   mobile cutover and production proof proceed only as ECL-03D–H;
10. Content, Discover, Notifications, Operations and Admin retain their
    single-writer boundaries;
11. all production mutations and age-sensitive paths remain disabled until
    their exact dependencies and evidence are accepted;
12. Latvia is the first possible cohort; Estonia and Lithuania remain
    independently disabled.

## 3. Proposed dispositions

The verdict accepts or defers each decision explicitly. A deferred decision is
not a hidden acceptance: its fail-closed default remains binding.

| Decision | Proposed disposition | Exact effect | Remaining gate/default |
|---|---|---|---|
| BCK09-OD-01 | **Defer executable authorization** | Select ECL-03C v1.1 as the only first candidate | No product backend until separate explicit post-stabilization approval |
| BCK09-OD-02 | **Defer implementation details** | Preserve Booking v1 and D11 semantics | No endpoint until API-DEC-01/03 accepted and fixture parity proved |
| BCK09-OD-03 | **Defer runtime readiness** | Accept server-owned actor/capability boundary | Deny production commands until BCK-06/18 authority evidence exists |
| BCK09-OD-04 | **Accept ownership boundary** | BCK-07 alone writes pinned published Event input | Mutations off until revision-safe runtime handoff is proved |
| BCK09-OD-05 | **Accept ownership boundary; defer effects** | BCK-09 owns obligation; BCK-13 owns inbox/delivery | No dispatcher/FCM until OD-09 and BCK-13 executable approval |
| BCK09-OD-06 | **Accept D04 product baseline with legal gate** | Retention classes/targets remain the design baseline | No production personal data until qualified per-market Legal/Privacy validation |
| BCK09-OD-07 | **Defer age policy** | Preserve OD-11 ownership and market versioning | Applicable paths server-disabled; no guessed threshold/checkbox |
| BCK09-OD-08 | **Accept D09 thresholds; defer proof** | SLO/zero-tolerance/automatic-stop values remain test targets | No cohort/GA until BCK-05 cost/DR/load/restore evidence |
| BCK09-OD-09 | **Accept repair seam; defer runtime** | BCK-19 owns case/proposal/approval; BCK-09 executes invariant-safe command | Drifted pool blocked; no console/manual repair |
| BCK09-OD-10 | **Accept staged sequence** | ECL-03C → D → E → F → G → H, each bounded | No stage inherits authority from a previous documentation verdict |

## 4. Mandatory controls

Acceptance includes all controls below:

1. BCK-09 stays `Review / Present / runtime Absent` until every required
   specialist verdict for Approval is recorded;
2. ECL-03C stays `Review / runtime not authorized` until a separate exact
   executable approval names files, commands, environment and evidence;
3. ECL-03D–H each require their own spec, file map, AC, rollback and approval;
4. no production Event projection may be seeded manually or from ECL-02 mock
   participant counters;
5. no local/offline/mock result may be displayed as confirmed Booking;
6. Booking v1 cannot be silently renamed, double-wrapped or extended with an
   unverified enum;
7. every retry preserves semantic payload/idempotency key and uses a fresh
   request-attempt ID;
8. unknown/stale capacity, identity, revision, policy, contract or flag fails closed;
9. no oversell, duplicate allocation, partial ledger/usage/audit/outbox write
   or Creator override is tolerated;
10. BCK-05 owns server flags and deployment controls; BCK-09 only consumes them;
11. BCK-13 owns notification inbox/device/delivery state after an Accepted handoff;
12. BCK-19 never writes Booking/ledger directly;
13. OD-09 remains required before cross-domain effects;
14. OD-11 remains required before applicable age-sensitive paths;
15. qualified Legal/Privacy review is not replaced by the Product verdict;
16. Latvia cohort, Estonia/Lithuania activation and general availability are
    separate decisions with their own evidence;
17. runtime success requires authoritative commit; timeout remains unknown outcome;
18. disabling creation preserves safe read/cancel/release and existing obligations;
19. no service account, credential, secret, billing or cloud resource is created;
20. push and merge to `main` are outside this decision.

## 5. Preserved blockers

The candidate remains non-executable while any applicable item is absent:

- BCK-03 API-DEC-01/03 and executable Dart/TypeScript fixture parity;
- BCK-04 security/privacy controls and qualified Legal/Privacy validation;
- BCK-05 exact environment, release, cost, monitoring, backup and DR evidence;
- BCK-06 production account/capability/revocation authority;
- BCK-07 revision-safe published Event projection writer;
- BCK-13 plus Accepted OD-09 for notification effects;
- BCK-18 mobile adapter/cutover contract;
- BCK-19 repair command integration before privileged repair;
- Accepted OD-11 before applicable age-sensitive Booking;
- explicit ECL-03C executable approval and post-stabilization backend authority;
- emulator transaction/Rules/contention/idempotency/invariant evidence;
- staging load/security/cost/restore evidence before any cohort.

## 6. Required specialist verdicts

Product acceptance of this record selects the common baseline. BCK-09 remains
Review until the following independent reviews are evidence-backed:

| Reviewer | Required verdict scope |
|---|---|
| API Platform | Booking v1 adapter/version, callable profile, deadlines, canonical hash |
| Security/Privacy | AuthZ, App Check, Rules/IAM, abuse, OD-11 posture |
| Identity | Account state, revocation, Viewer and exact-page capabilities |
| Content | Published Event projection writer/revision/barrier handoff |
| Notifications | OD-09, obligation/inbox boundary, dedupe, push minimization |
| Operations | Environments, flags, SLO, cost, backup/RPO/RTO, rollout/rollback |
| Mobile Platform | Typed adapter, unknown outcome, cache/freshness, no offline authority |
| Admin Operations | Case/proposal/approval and exact domain repair command seam |
| Legal/Privacy | Per-market legal basis, rights, retention/deletion and age policy |

A combined bootstrap role may coordinate documents but cannot be reported as
an independent specialist or qualified Legal/Privacy approval.

## 7. Owner verdict

Allowed verdicts:

| Verdict | Result |
|---|---|
| `Accept BCK09-A1-STAGED-FREE-BOOKING-v1 with controls` | selects §§2–4 and the §3 dispositions; no runtime authority |
| `Accept with amendments` | remains Ready until amendments are incorporated and re-reviewed |
| `Reject` | BCK-09 remains Review; replacement direction is recorded |
| `Inconclusive` | BCK-09 remains Review; missing decision/evidence is named |

Recommended verdict:
**Accept `BCK09-A1-STAGED-FREE-BOOKING-v1` with controls.**

The only effective Product-owner phrase is:

```text
Одобряю BCK09-DEC-01: Accept BCK09-A1-STAGED-FREE-BOOKING-v1 with controls.
```

Generic `да`, `дальше`, approval of previous BCK-09 editing, silence or
document presence is not this verdict.

## 8. Status after exact Product acceptance

| Item | Resulting status |
|---|---|
| Candidate baseline | Product-selected with §4 controls |
| BCK09-OD-04/05/06/08/09/10 | Accepted only at the design boundary stated in §3 |
| BCK09-OD-01/02/03/07 | Deferred/Open with their fail-closed defaults |
| BCK-09 | Review; specialist Approval still pending |
| ECL-03C | Review; runtime not authorized |
| ECL-03D–H | Target only; no inherited authorization |
| BCK-03/04/05/06/07/13/18/19 | Unchanged |
| OD-09 | Proposed; unchanged |
| OD-11 | Open; unchanged |
| Firebase/product backend | Absent |
| Production data/deployment | Absent |
| `main` | Untouched |

## 9. Revalidation and supersession

Re-review is mandatory if the Booking v1 major, D01–D11, ADR 0019, ECL-03C
scope, Firebase topology, single-writer ownership, concurrency policy,
retention baseline, age policy or stage order changes. A replacement records
the old/new baseline, compatibility, migration, security/privacy impact,
rollback and effective date. No silent reinterpretation is allowed.

## 10. Acceptance criteria

1. **BCK09-DEC-AC-01:** one exact candidate baseline is named.
2. **BCK09-DEC-AC-02:** all ten BCK09 decisions receive an explicit disposition.
3. **BCK09-DEC-AC-03:** deferred is not represented as Accepted.
4. **BCK09-DEC-AC-04:** Product acceptance is separate from specialist approval.
5. **BCK09-DEC-AC-05:** qualified Legal/Privacy review is not impersonated.
6. **BCK09-DEC-AC-06:** ECL-03C is the only first executable candidate.
7. **BCK09-DEC-AC-07:** ECL-03C runtime remains separately gated.
8. **BCK09-DEC-AC-08:** ECL-03D–H require independent approvals.
9. **BCK09-DEC-AC-09:** committed Booking v1 remains the current wire source.
10. **BCK09-DEC-AC-10:** D11 split-key semantics remain normative.
11. **BCK09-DEC-AC-11:** ECL-03C sold out creates no waitlist.
12. **BCK09-DEC-AC-12:** every record/effect has one writer.
13. **BCK09-DEC-AC-13:** OD-09 effects remain disabled.
14. **BCK09-DEC-AC-14:** OD-11-sensitive paths remain disabled.
15. **BCK09-DEC-AC-15:** production personal data remains blocked.
16. **BCK09-DEC-AC-16:** no cloud, credential, billing or deployment effect exists.
17. **BCK09-DEC-AC-17:** generic continuation is not an owner verdict.
18. **BCK09-DEC-AC-18:** only the exact phrase changes Product decision status.
19. **BCK09-DEC-AC-19:** acceptance does not authorize push or `main` merge.
20. **BCK09-DEC-AC-20:** supersession is versioned and evidence-backed.

---

**Current conclusion:** `BCK09-DEC-01` is ready for the exact Product-owner
verdict. No acceptance, BCK-09 Approval, ECL-03C authorization, Firebase
runtime, deployment, production data, push or `main` merge is recorded.
