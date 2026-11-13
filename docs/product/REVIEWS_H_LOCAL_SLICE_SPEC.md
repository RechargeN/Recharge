# H — Reviews and rating projection (local backend)
Status: Done — bounded local/Emulator backend only; owner requested completion on 2026-10-16. Local owner policy accepted 2026-10-15.
Policy: [local H/K2 owner decision](REVIEWS_TRUST_SAFETY_LOCAL_OWNER_POLICY.md).
Supersedes the eligibility blocker for this bounded slice, not the canonical BCK-12
production/privacy/legal gates.

## Delivered
Default-off reviewCommandV1 / reviewQueryV1 use existing Auth, App Check and
server-resolved personal sessions. The independent flag is reviews.runtime.
Strict unknown fields, revision preconditions, actor-scoped semantic idempotency
(requestId excluded), immutable review ID and author/target uniqueness are enforced
inside Firestore transactions. Concurrent submissions cannot create two active reviews.
Deletion retains the uniqueness tombstone; resubmission uses the same review ID.

Only public LV Place/Event/Activity Content revisions with a valid body hash are
accepted. Content provenance and Identity Page ownership/active membership exclude
own/administered objects. Places need no attendance evidence.
Booking's review_eligibility owner adapter accepts confirmed, noncancelled Event
Booking only after the owner projection occurrence start and with no missed
reconfirmation. It returns permission evidence, never verified attendance.
The current Booking model supports Event only: Activity without supported owner
Booking evidence returns eligibility_unavailable. No self-reported Visit, booking
creation alone, client role, title or GPS input confers eligibility or a badge.
Every row is verified:false.

Commands: submit/edit/delete; rating integer 1–5, optional text <=1000 Unicode code
points (line feeds allowed; every other control character is refused), edited marker,
arbitrary edit/delete time.
Delete remains possible when the source is hidden/unavailable; edit does not require
the source still be visible, but ownership is rechecked. Safety restrictions can
refuse new writing. Editing never removes a moderator hold.

## Projection and moderation
Review mutation and rating delta commit atomically. Current visible/nondeleted rows
contribute to integer distribution, count and sum. Average is fixed-point scale 1000,
rounded down and absent below three reviews. Personal block/mute filters review rows,
not the global aggregate.
The trusted Reviews.rebuild(contentId) owner method runs in a transaction and shares
the projection serialization point with writes. Repeated rebuild is identical, keeps
sourceWatermark and never imports client ratings. This local rebuild is bounded at
2000 rows; larger sources explicitly return rebuild_capacity_exceeded.
Query rows omit the internal authorId and eligibility evidence; each row carries
own=true only for the viewer's own review.
Query pages contain 50 rows with an expected source watermark for continuation;
projection_changed requires refresh, preventing mixed-revision paging.

K1 report targets may be {reviewId,reviewRevision}; invalid/stale/deleted targets
are refused. Reports atomically route to T&S and never hide a review.
moderationCommandV1/moderateReview invokes the Reviews owner service, checks a current
market/type moderateReview grant inside the write transaction, pins the review
revision and records the decision/audit/receipt. Hide/restore changes only that review;
restore must name its hold decision. Rating delta commits in the same transaction.

## Evidence and limits
See the H/K2 combined evidence below in TRUST_SAFETY_K2_LOCAL_SLICE_SPEC.md.
No mobile reviews form, production adapter, real attendance/check-in or badge,
production processing, Legal review or cloud deployment is claimed.
Rollback: disable entry flag; preserve receipts/tombstones/audit. Restore through
Reviews commands and rebuild through the owner, not direct collection edits.

## Local backend closure (2026-10-16)

Owner instruction: «закончи тогда.» after the distinction between local backend acceptance and end-to-end product completion. This closes only the delivered default-off Emulator backend scope. Integration includes source revision `2e698f733144c6cafaf56103e75e0e6b96b3d2bc`; see [closure evidence](../verification/H_K1_K2_LOCAL_CLOSURE_2026_10_16.md). All remaining UI, external-service, privacy/legal, operations, device/cloud and production gates stated above remain open.
