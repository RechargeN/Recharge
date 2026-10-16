# K2 — Trust & Safety (local backend)
Status: Review. Local owner policy accepted 2026-10-15.
Policy: [H/K2 owner decision](REVIEWS_TRUST_SAFETY_LOCAL_OWNER_POLICY.md).
This is bounded local/Emulator runtime, not production BCK-22 approval.

## Authority, state and commands
Default-off safetyCommandV1 / safetyQueryV1 use existing Auth/App Check/session
transport and independent trustSafety.runtime. Staff also requires moderation.staff
and a current exact market/type/action grant. issue/change/appeal decisions recheck
session/account/grant in the transaction. Permanent ban additionally requires the
trusted, server-only safetyOwnerAuthority/owner registry. Client roles and DOB have
no authority. No callable can grant staff/owner status.

T&S owns safetyRelations, safetySanctions, safetyAppeals, safetyReceipts, safetyAudit,
safetyNotices and safetyAttemptLimits. Relations and staff commands use strict
contracts, revisions and semantic receipts. User mutation budget is configured in
the server-only abusePolicy record with this policy revision; missing/invalid policy
fails closed. The Emulator fixture's 30/minute is evidence configuration, not a
production approved quota. A replay does not consume a second slot. K1 reports use
the same T&S budget when K2 is enabled. No automatic sanctions/containment.

Sanctions: human warning, exact-content hide, temporary user suspension (7/30 days),
owner-only permanent ban. Lifting a permanent ban (revoke or a revoking appeal decision)
also requires the trusted owner; other staff get owner_required. The ladder is not a
mandatory progression.
Local temporary/permanent effects prevent new authoring/reviews/Booking creation and
suppress the sanctioned publisher's Catalog content. Existing Booking records,
inventory, cancellation/refund state and service notification obligations are untouched.
A sanctioned user can still read notices and appeal; the Identity account itself is
not directly mutated.

## Owner commands and reconciliation
T&S dispatches fixed Content, Catalog and Booking owner commands. Each owner verifies
the full minimized instruction against the current T&S source inside its transaction,
writes only its own *SafetyHolds record, and returns a durable revision acknowledgement.
Sanctions remain pending until all three owner acknowledgements match the source revision.
An outage after some effects leaves visible partial acknowledgements and retries resume.
Stale instructions and changed semantic replay are refused.

Content eligibility uses Content-owned holds for new publication commands.
Catalog feed/search/map/details and exact-id Place/Collection link eligibility use
Catalog-owned holds. Booking checks Booking-owned holds inside the create transaction;
cancel/reconfirm/query are not blocked by these new safety checks.
A contentHide is a separate Content safety hold, not a destructive rewrite of the
publication pointer/body. Catalog and Booking apply their own supported effects.

Revocation, expiry and a successful appeal increment the source instruction revision
and dispatch compensation. Each sanction has an independent hold: removing one never
removes another. Read guards honor the deadline even before reconciliation; the trusted
reconcile method materializes expired source state and owner acknowledgements.
No scheduled cloud worker is added: local tooling/operator invokes reconciliation.
Issue, revoke, expire and appeal decisions only change the T&S source (status pending);
no Content/Catalog/Booking effect or reversal exists until reconcile has dispatched
the owner commands. Operators must run reconcile after every such change.

## Block, mute, notices and appeals
Directional user relations are separate from sanctions. Only the initiating user reads
their relation list. Both block directions deny the owner-facing interaction guard.
Catalog/Reviews reads enforce current relations; a blocked author's Event leaves the
feed but its public direct details remain readable unless a sanction hides it.
Mute filters eligible author rows from Catalog/Reviews. Neither relation changes Booking.
There are no backend person-search/message/invite/mention services in this checkout;
their owner-facing guard exists, but integration with those absent surfaces is not
claimed. Likewise no new-publication notification producer exists to connect the mute
policy to. Existing Booking/service/safety delivery is not filtered by relations.

T&S notices expose a closed reason category/label, effect, status, end time and appeal window to the subject,
without reporter identity or private staff narrative. Owner instructions also carry only the reason code. One appeal per decision; at least six calendar months from
issue, month-end safe. Seven-day response target is recorded, not called a legal SLA.
Independent review is required by this bounded runtime; self-review is refused.
Upheld/revoked outcomes are audited; successful reversal remains pending until owner
compensation completes. Own queries include minimized appeal status.
The appellant's statement stays in the appeal `reason` and in a server-only
appealSubmitted audit record; the staff decision narrative is stored separately as
`decisionReason` and never returned to the subject. Because the owner both issues and
alone may lift a permanent ban, an appeal against an owner-issued ban cannot be revoked
by an independent reviewer in this local slice (fails closed with owner_required).
Age-sensitive services remain disabled without accepted trusted server age authority.
16+ product intent and self-declared DOB do not enable them; organizer entry checks and
18+ labels are not substitutes for backend authority.

## Validation (2026-10-16, after review corrections)
Node 22.23.2 and JDK 21, worktree g-library-sync on base 8f26a98.
- Backend typecheck, ESLint on src and changed tests, Prettier on changed files: green.
- Full backend unit: 735 passed. r1 integration: 254 passed.
- reviews-safety group: 13/13 (12 original scenarios plus the review-query case:
  no authorId/evidence in rows, own flag, line feeds allowed, muted author filtered).
  The appeal case now asserts the preserved appellant statement and its audit record;
  the permanent-ban case asserts owner_required for non-owner revoke and appeal.
- Full `npm run test:emulator`: all 12 groups pass, 284 passed, 0 failed, 1 skipped
  (Library Flutter-adapter case that needs RECHARGE_G_MOBILE).
- Emulator runner self-test (`test:emulator:runner`): 6/6; it accounts for the G, H/K2
  and K1 groups added after its snapshot, whose original 40-task hash is unchanged.
- Boundary: exception budget 71/71, no stale or expired exceptions; git diff --check clean.
- Emulator indexes are declared, not deployed/index-readiness evidence.
- No Dart/mobile changes; Flutter suite not rerun for this backend-only pass.

Review corrections of 2026-10-16: reviews-safety and K1 suites now clear all Content,
Catalog, Media, Moderation, handoff and Booking state they create (shared
test/support/content_emulator_cleanup.ts), because every group shares one Firestore;
without it the full suite failed in booking and content-media. Both groups run after
the established ones. A pre-existing timing race remains in the booking test "discovery
repairs a source fact that never received a trigger delivery": it assumes the outbox
trigger has not yet fired, which a warm Functions Emulator can violate.

Race fixed (2026-10-16, test-only; the observed failure is explained by the test race and
no product change was needed): that test and "scheduler reaches
pending work after more than twenty delivered source facts" (same pattern) now run inside
test/support/functions_emulator_triggers.ts `withFunctionTriggersDisabled`, the Emulator
Hub disable/enable endpoints. The outbox write is acknowledged but never delivered to
consumeEventBookingOutboxV1, so the trigger is genuinely missed and only discovery can
create the delivery; `discovered === 1` no longer depends on trigger timing.

## Remaining scope and rollback
No mobile/staff UI, nonexistent contact/profile/message service integration, production
staff IAM, queue operations staffing/SLO, legal retention/DSR expansion, qualified
Security/Privacy/Legal verdict, cloud/staging/device gate or deployment is delivered.
K2 is not end-to-end product completion across these surfaces.
Disable runtime flags to stop new commands; existing holds are intentionally not erased
by a flag. Use owner compensation and reconciliation for reversal, preserving audit.
