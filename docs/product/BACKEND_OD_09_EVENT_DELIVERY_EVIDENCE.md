# BCK-D1 — OD-09 Event and Outbox Review Evidence

- Evidence ID: **BCK-D1-OD09-EV-01**
- Version: **0.1**
- Date: **2026-08-20**
- Decision status: **Proposed — not Accepted**
- Evidence status: **Draft — cross-owner review required**
- Runtime status: **Absent**
- Accountable owner: **API Platform owner**
- Required co-owners: **Platform Operations, Security/Privacy, Notifications and producing domain owners**
- Canonical proposal: [BCK-03 §27](BACKEND_API_CONTRACT_STANDARD.md)
- Runtime effect: **none**

---

## 1. Purpose and verdict

This is the review worksheet for OD-09. It does not create a competing event
model. BCK-03 remains the normative proposal; this file supplies compatibility,
failure and owner evidence required to decide it.

The proposal is coherent enough to remain `Proposed`, but not enough to become
`Accepted`: transport, retention, registry ownership, replay authorization,
poison handling and executable duplicate/gap evidence are unresolved.

## 2. Canonical proposed contract

The required envelope remains:

```text
eventId, eventType, eventVersion, producer,
aggregateType, aggregateId, aggregateRevision,
occurredAt, correlationId, causationId?, marketId?,
dataClass, payload
```

Normative proposed semantics inherited from BCK-03:

- immutable past-tense fact;
- authoritative transition and outbox obligation are atomic where required;
- at-least-once delivery, never exactly-once marketing language;
- consumer dedupe key is `(consumerName, consumerVersion, eventId)`;
- no global ordering guarantee;
- per-aggregate order is checked by `aggregateRevision`;
- gap/out-of-order causes bounded recovery, never blind apply;
- handler result/checkpoint is idempotent;
- payload is minimal and schema-versioned;
- bounded audited replay; poison events are quarantined after bounded attempts;
- consumers do not mutate another module's aggregate directly.

## 3. Booking compatibility reconciliation

| Existing Booking contract | OD-09 interpretation | Result |
|---|---|---|
| Transaction creates Booking, ledger, usage, audit, outbox and idempotency atomically | Booking outbox is a producer-owned obligation written with the transition | Compatible |
| Deterministic notification delivery key | Domain delivery dedupe may remain narrower than platform `eventId`; mapping must be explicit | Compatible with mapping evidence |
| Outbox is obligation only; dispatcher/FCM excluded from ECL-03C | OD-09 does not authorize dispatcher or delivery | Compatible |
| FCM attempt is not proof of read | Transport attempt and user-visible receipt/read are separate facts | Compatible |
| Timeout/retry must not create second transition/outbox | Producer idempotency precedes consumer dedupe | Compatible |
| Booking request/correlation IDs follow BCK-D1-DEC-01 | Event correlation may link the command attempt; event identity remains `eventId` | Compatible |

Required fixture mapping before Acceptance:

```text
Booking transition
  -> exactly one producer outbox obligation per committed semantic transition
  -> one stable eventId and aggregateRevision
  -> zero or more delivery attempts
  -> one idempotent consumer checkpoint per consumer version
```

## 4. Failure/recovery evidence matrix

| Scenario | Required outcome | Missing evidence |
|---|---|---|
| producer transaction aborts | no aggregate transition and no visible outbox | emulator transaction test |
| producer commits, worker unavailable | obligation remains discoverable; alert after owned threshold | transport/SLO decision |
| duplicate delivery | one semantic consumer effect; duplicate observable | consumer fixture/test |
| out-of-order same aggregate | do not apply newer effect blindly; bounded gap recovery | revision/checkpoint test |
| permanent version incompatibility | typed quarantine, no infinite retry | registry/poison policy |
| transient dependency failure | bounded retry with jitter and attempt record | BCK-05 values |
| handler crashes after side effect | idempotent effect/checkpoint prevents duplication | integration test |
| replay requested | least-privilege approval, bounded filter, audit, kill switch | Security/Operations review |
| source later deleted/redacted | approved reference/redaction policy, no payload resurrection | BCK-04 decision |
| effect loop | correlation/causation guard detects and stops chain | loop fixture/test |

## 5. Event registry evidence required

OD-09 Acceptance requires a registry template with, for every event version:

- event type/version and owning producer;
- business meaning and the authoritative transition that emits it;
- aggregate type/revision semantics;
- payload schema owner and data classification;
- required/optional market and correlation fields;
- intended consumers without granting them producer write authority;
- compatibility policy and minimum retention/replay window;
- deprecation/sunset owner;
- privacy deletion/redaction behavior;
- test fixture and operational dashboard/alert link.

No registry entry may use an event as an unaudited command. A requested effect
must have its own command/authorization boundary or an explicitly owned,
idempotent consumer policy.

## 6. Decisions still required

| Decision | Accountable owner | Blocks |
|---|---|---|
| exact transport and per-environment resource topology | Platform Operations | any worker |
| retry count/backoff/lease/checkpoint values | Platform Operations | delivery activation |
| quarantine/dead-letter access and repair | Operations + Security | production poison handling |
| event/outbox/delivery retention | Security/Privacy + domain | production records |
| payload classification and deletion propagation | Security/Privacy | personal-data events |
| registry/change authority | API Platform | non-Booking producers |
| replay approval, scope and audit | Security + Operations | replay tooling |
| notification receipt/read semantics | Notifications | user-facing effects |

## 7. Acceptance and runtime gates

OD-09 becomes `Accepted` only after:

1. BCK-03 proposal and this matrix are approved by all required owners;
2. Booking compatibility fixtures cover create/cancel, duplicate and rollback;
3. one candidate notification consumer is specified without enabling it;
4. exact transport/retry/quarantine/retention decisions are recorded;
5. registry/change/deprecation ownership is assigned;
6. privacy deletion/redaction and replay access are approved;
7. duplicate, gap, poison, crash-after-effect and replay tests are defined;
8. BCK-01/02/03/04/05/13 and LAUNCH_STATUS update atomically.

Acceptance still does not authorize runtime. D3 effects/workers require an
Approved executable slice, OD-07 where resources are provisioned, and all
applicable security/operations gates.

## 8. Fail-closed state now

- cross-domain workers and notification delivery remain disabled;
- no Pub/Sub, task, trigger, dispatcher, dead-letter or replay resource exists;
- Booking transactional outbox remains a documented obligation target only;
- no event is considered delivered because it was written to an outbox;
- no consumer may infer authority from event payload identity or capabilities.

## 9. Evidence acceptance criteria

1. **OD09-EV-AC-01:** this file extends BCK-03 evidence, not its semantics.
2. **OD09-EV-AC-02:** delivery is explicitly at-least-once.
3. **OD09-EV-AC-03:** dedupe and producer idempotency are separate.
4. **OD09-EV-AC-04:** no global ordering is promised.
5. **OD09-EV-AC-05:** aggregate gaps fail closed and recover boundedly.
6. **OD09-EV-AC-06:** Booking outbox maps without changing Booking invariants.
7. **OD09-EV-AC-07:** transport, retention and poison values have owners.
8. **OD09-EV-AC-08:** replay is bounded, authorized and audited.
9. **OD09-EV-AC-09:** FCM attempt is not user receipt/read proof.
10. **OD09-EV-AC-10:** Acceptance is separate from worker activation.
11. **OD09-EV-AC-11:** no cross-domain runtime is created.
12. **OD09-EV-AC-12:** OD-09 remains Proposed until evidence is signed.
