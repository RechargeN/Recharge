# K1 — Moderation queues and reports (local Emulator slice)

Status: Done — bounded local/Emulator backend only; owner requested completion on 2026-10-16. Implementation authorized by owner on 2026-10-15.
Scope: backend commands and queries in the local Firebase Emulator only.
This is partial BCK-22 runtime evidence; the canonical Trust & Safety specification remains Draft.

## Authority and commands

Four default-off callable surfaces: moderationCommandV1, moderationQueryV1,
reportCommandV1 and reportQueryV1. Existing authenticated transport requires
App Check and server-resolved session authority. Client role claims confer no authority.

Staff operations require a trusted bootstrap grant with an unexpired server time,
marketId, typeId and exact action. Legacy broad fixture grants cannot authorize K1.
The moderation.staff switch and current session are checked; enforcement rechecks
the current grant. Production staff IAM and grant administration are outside this slice.

Queries require explicit market/type scope and use bounded document-ID pagination.
Content determines authoritative target scope. Decisions pin expectedRevision;
Content checks the pinned revision inside its owner transaction.
approve/reject, restrict (hide), withdraw and restore use the existing moderation
decision and Content owner-service command path. Staff code writes its own moderation
records and receipts only, never Content domain collections.
Existing Media owner-service integration is retained; no new Media workflow is claimed.

## Remoderation

requestRemoderation pins the current publication revision into a moderation-owned queue.
reviewRemoderation supports noAction, restrict and withdraw with an expected queue revision.
Domain effects pass through ModerationService and Content.applyModerationDisposition.
Semantic idempotency keys reject conflicting reuse; retries resume an interrupted
owner command and recheck authority. noAction refuses a changed publication.
If concurrent reviews race, the queue can return revision_conflict after an independently
accepted owner decision: domain receipts/audit remain authoritative; there is no silent rollback.

## Reports and T&S ownership

Authenticated report intake pins contentId and publishedRevisionId. It accepts a bounded
reason vocabulary and optional narrative up to 2000 characters. Report ID, request ID
and semantic idempotency receipt preserve distinct reporter submissions.
An atomic transaction creates T&S-owned report, receipt and trustSafetyInbox route.
Report creation never hides content automatically.

A reporter can read only their minimal received receipt, including on a retry after
the source publication changes. Staff report queues require the target scope.
Scoped triage (accepted, duplicate, outOfScope) routes classification to the T&S
investigation inbox and preserves the original report. It does not itself issue sanctions.
Domain enforcement remains a separate scoped owner command.

## Acceptance evidence (2026-10-15)

- Backend typecheck and scoped ESLint: green on final source.
- Existing backend unit suite: 731 passed.
- moderation-k1 Emulator group: 8 K1 tests and 5 existing moderation flow tests passed.
- K1 tests cover expired/wrong-scope/legacy grants, stale revisions, hide/restore,
  remoderation retry, revocation before enforcement retry, report privacy/idempotency,
  T&S routing, authenticated HTTP surfaces, default-off flags and direct domain-write denial.
- Emulator indexes are declarations only; Emulator success does not prove deployed indexes.
- No Flutter source changes in K1; accepted G mobile gates are separate evidence.
- 2026-10-16 recheck with H/K2 in the same tree: unit 735, moderation-k1 group 13/13 and
  the full Emulator suite green (see the K2 validation section). The K1 suite now cleans
  the shared Content state it publishes; its npm script is `test:emulator:moderation-k1`.

## Rollback and remaining gates

Disable moderation.staff and trustSafety.reports to stop entry. Preserve audit/receipts;
do not delete domain state to roll back moderation. Restore requires an explicit owner command
against the current revision. Revert K1 code/index declarations for source rollback.

No deploy, production processing, staff UI, mobile report UI, production IAM, appeal
workflow, legal retention policy or new DSR workflow is delivered here.
Canonical BCK-22 owner decisions, Security/Privacy/Legal review and cloud activation remain open.

Backlog (not in this slice): the scoped moderation `queue` reads the 100 most recent
decisions across all scopes before filtering, so its `recent` list can be incomplete,
and it returns no `nextCursor`; the K2 `staffQueue` has the same 50-item limit.

## Local backend closure (2026-10-16)

Owner instruction: «закончи тогда.» after the distinction between local backend acceptance and end-to-end product completion. This closes only the delivered default-off Emulator backend scope. Integration includes source revision `2e698f733144c6cafaf56103e75e0e6b96b3d2bc`; see [closure evidence](../verification/H_K1_K2_LOCAL_CLOSURE_2026_10_16.md). All remaining UI, external-service, privacy/legal, operations, device/cloud and production gates stated above remain open.
