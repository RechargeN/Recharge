# K2 — Trust & Safety: implementation blockers

Current status: Superseded for the bounded local slice by the owner decision of 2026-10-15.
See [TRUST_SAFETY_K2_LOCAL_SLICE_SPEC.md](TRUST_SAFETY_K2_LOCAL_SLICE_SPEC.md) and [accepted local policy](REVIEWS_TRUST_SAFETY_LOCAL_OWNER_POLICY.md).
The text below is the historical pre-decision blocker snapshot, not current runtime status.


Status: Blocked (policy and owner integrations), 2026-10-15.
Task 24 requested after H. K1 is a separate local moderation/report slice and
does not constitute K2 completion.

## Current evidence

TRUST_SAFETY_MODERATION_BACKEND_SPEC.md remains Draft:
- §10 requires an accepted block/mute surface matrix;
- §11–12 require sanction, authority, notice and appeal policy;
- §19 requires owner-domain commands and acknowledgements;
- §22 and §37 retain OD-11 age policy and OD-06 enforcement/appeal blockers.
The blocker table explicitly defaults block/mute to safer suppression/no enablement.
No accepted replacing owner decision was found in the current repository.

K1 provides scoped Content decisions through Content owner commands.
Catalog already consumes Content visibility/projection state, but that is not a
general K2 sanction acknowledgement. Booking has no K2 sanction owner-command
integration. There is no implemented shared K2 block/mute/sanction/appeal lifecycle.
Existing Booking-specific abuse controls do not cover T&S operations.

## Required implementation boundary

T&S alone owns relations, cases, sanctions, appeals, audit, idempotency receipts
and instruction/reconciliation state. It must not mutate Content, Catalog or
Booking storage. Each owner validates a versioned, minimized instruction and
atomically applies supported effects with a durable acknowledgement.
Partial enforcement must remain visible and cannot be reported as complete.

Expiry, revocation and successful appeal send compensating owner commands to
every affected domain. A stale instruction cannot reactivate a newer revoked
sanction. Restoration must preserve other active holds and current source state.

Block/mute are directional user relations, not sanctions; create/revoke must be
owner-scoped and idempotent. Client roles, age claims and self-reported facts
cannot establish enforcement authority.

## Concrete blockers before activation

1. Product/domain owners: exact block/mute effects for Content/Catalog/Booking,
   including existing bookings, cancellation/refund boundaries, caches and notices.
2. T&S owner (OD-06): allowed sanction families, duration/expiry, staff scopes,
   separation of duties, appeal eligibility/independence and reversal behavior.
3. Security/Privacy and applicable qualified review: trusted authority, bounded
   abuse/rate limits and retention. No arbitrary quota or auto-sanction threshold.
4. Accepted OD-11 only for age-sensitive paths: trusted server evidence and
   market-versioned eligibility. It does not block unrelated non-age core work.
5. Executable owner commands and acknowledgement/reconciliation tests across
   Content, Catalog and Booking, including outages, reordered retries, concurrent
   sanctions and appeal compensation.

No K2 callable, sanctions, block/mute or age enforcement was enabled. No placeholder
sanction store or no-op domain adapter was introduced. No client age claim is used.
No new production processing or deployment.

## Continuation and rollback

First accept the bounded local surface/effect policy, then implement T&S persistence,
owner adapters and cross-domain reconciliation with Emulator evidence.
K1 remains available behind its independent default-off flags.
This pass changes documentation only and is not K2 runtime acceptance.
