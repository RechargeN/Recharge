# G — Favorites and explicit Visit History (заход 21)

Status: **Done — local/Emulator scope accepted by owner on 2026-10-15; local gates green**
Date: 2026-10-15
Base: `c5b1654`, worktree `g-library-sync`. User authorized implementation without further formal confirmations.

## Scope and boundaries

Complete the owner Library part of BCK-12 on the existing Identity, Content,
Firestore Emulator and Privacy orchestration foundations. Reviews, ratings,
cloud deployment, production activation and automatic import of local/demo
records are outside this slice. The broader BCK-12 contract remains Review;
this slice does not approve its remaining owner decisions.

## Runtime

- `libraryCommandV1`: addFavorite, removeFavorite, recordVisit, removeVisit.
- `libraryQueryV1`: bounded revision-pinned reads with tombstones.
- Both require the existing authenticated Session and local feature flag
  `library.self_service`. Actor/account/session and flag are read inside the
  Firestore transaction, including the account revocation/restriction fence.
- The persistence constructor itself requires the loopback `demo-recharge`
  Emulator and rejects cloud context. Direct Firestore client access stays denied.
- Client `ownerContext` is a mismatch guard, never authority: it must match
  the server-resolved subject. Unknown envelope/payload fields fail closed.

### Command contract

```text
{ schemaVersion: 1, requestId: UUID/ULID, ownerContext: subject UUID/ULID,
  idempotencyKey, commandType,
  payload: { objectId: UUID/ULID, objectType, expectedRevision,
             proposedEntryId: client UUID/ULID, visitedOn?: YYYY-MM-DD } }
```

The source reference is typed and ID-only. `addFavorite` and `recordVisit`
require a visible public immutable Content revision in the accepted local
market. `removeFavorite` and `removeVisit` deliberately skip the source and
date checks so that an initial remove can always write a tombstone, even for
an unpublished object or a day the Place clock has not reached yet.
Display snapshots contain only source-owned title/city/category; client text,
prices, distances and clocks never become backend facts.

The natural key is Favorite(type, objectId), or Visit(placeId, local calendar
day), within the Session owner. Entry IDs originate on the client and remain
stable across removal/re-add. Entry and receipt document keys are
`ownerId:` plus an internal hash of the natural key or idempotency key; the
owner control document is keyed by the server-resolved `ownerId` itself.

### Idempotency and conflict rules

A transaction atomically persists the entry/tombstone, owner revision and
command receipt. A repeated key with identical semantics returns its original
result; changed semantics gives `idempotency_conflict`. The request ID is not
part of command semantics. Terminal rejections (`revision_conflict`,
`object_unavailable`, `visit_date_future`, `place_timezone_invalid`) are
receipts too: the same key returns the same rejection, so a client retries a
new intent with a new key. `expectedRevision` is part of the semantics. A stale expected revision gives `revision_conflict`
and never silently rebases. A same-state command at the current revision is
a no-op. An initial remove creates a tombstone, preventing a delayed add at
revision zero from restoring it. Replaying an old successful add returns its
historical receipt and does not undo a later removal.

Owner revision increases only for actual entry changes. Entry deltas are
ordered by owner revision. Paging pins that revision; intervening writes cause
`snapshot_changed` and a bounded client restart, rather than skipped entries.
Tombstones are retained until an approved retention policy exists; no TTL is added.

### Visit invariant

Only `recordVisit`, explicitly selected by the user for a Place, creates
`selfReported` evidence. Booking, Favorite, Details view, GPS and provider
events have no Visit write path. Non-Place targets and impossible calendar
dates are rejected for both Visit commands; `recordVisit` also rejects dates
after today at the Place. Today is computed from backend time in the Place's stored IANA
timezone, not device time or a client timezone. The local Details date picker
uses the same existing TimezoneRepository and fails closed on unknown zones.

## Mobile binding and local persistence

The existing Functions transport allowlist includes the two Library callables.
`RECHARGE_TEST_LIBRARY=true`, a non-release build, testBackend binding and
the exact loopback demo endpoint are all required. Every network call rechecks
the binding. Disabled/failed remote operations never fall back to local success.

The existing Favorites and Visit History repositories are selected through DI;
the app-level adapters preserve feature boundaries. Explicit refresh actions
read changes from the other client. This is refresh-based synchronization, not
a background push subscription. Unknown remote prices, start times and
distances remain absent: `distanceKm` is nullable and an unknown distance is
not rendered (no `0.0 km`). An unknown start time keeps the existing
Favorites label `Any time`.

A pending command is written to secure storage before dispatch, scoped by the
server owner. After a lost response or a process restart, the same key and
payload are retried on the next explicit refresh or the next Library action,
whichever comes first; there is no background retry. A transport failure keeps
the command queued. A terminal answer resolves it, and an unrelated older
rejection does not block a new action. An expired or missing Session keeps the
queue for the same owner; only `processing_restricted` (restriction/erasure)
drops it. Account changes cannot replay that queue against another subject.
Snapshots are published to the UI only after all pages are complete.

Local-only Favorites uses collision-free owner-namespaced v2 storage; the old
unowned global list is preserved but not assigned to a user. User-visible
effect: favorites saved before G are no longer shown after upgrade until an
explicit migration is approved, and a signed-out user sees an empty list and
cannot add local favorites. Visit History uses
collision-free v3 keys and an exact-owner fallback from v2. An authoritative
empty v3 list prevents v2 records reappearing. Legacy v1 seeded visits remain
ignored. Local commands are serialized within the existing repository instance.

## DSR linkage

Privacy domain ID: `library`. `PrivacyDomainTaskRunner.runLibraryTask` uses
the existing request/task lifecycle, retries, completion evidence and reconcile
gate. An incomplete Library task prevents completion when Library is required.

Access reports the domain inventory count; authorized private records are read
through the bounded owner API. This slice does not add a new DSR export delivery
platform. Restriction writes the shared Library owner fence. Erasure first
restricts Identity through the existing runner, then fences Library, deletes
all owner entries (including tombstones) and command receipts in bounded pages.
A concurrent command must retry against the fence. Repeated tasks are safe.

A minimal server-only owner control marker remains to prevent stale commands
from resurrecting erased data; it contains no object refs, dates or snapshots.
Its cleanup needs the shared account/retention lifecycle. Other owners are
untouched. Device-local demo namespaces are not uploaded or treated as server
DSR records; legacy ownerless/colliding storage must not be deleted wholesale
under another owner's request.

## Verification

Backend code was not changed by the 2026-10-15 review corrections, so the
backend-only evidence below comes from the original G run.

- Backend Node 22.23.2: typecheck/build, scoped ESLint, bounded export gate.
- Backend existing unit suite: **731 passed**.
- Library Emulator, re-run on final code (Node 22.23.2, JDK 21) with real
  Flutter adapters: **9/9 passed**. Eight backend cases cover two HTTP callable
  clients, retries, stale revisions, paging, isolation, flags, explicit visits
  and Privacy runner erasure/replay; the ninth runs two independent Flutter
  adapters using separate server-issued Sessions.
- Full mobile run on final code: **1648 passed, 68 skipped, 0 failed**,
  including the Object/Offer and Route Create goldens. An earlier run before
  the final refinements had 8 golden failures in those renderers; G does not
  touch those renderers or baselines, so treat them as environment-sensitive
  if they reappear.
- Mobile Library tests include refresh UI, lost-response recovery after client
  restart, replay on a plain refresh, queue retention across an expired
  Session, a non-blocking unrelated rejection, a replay after removal by
  another client and an unknown route distance without a `km` value.
- Final full analyzer: no issues. Boundary: **passed, 0 stale/expired
  exceptions, budget 71/71**. Working and staged diff checks passed.
- No device, cloud, production or distributed production-load evidence is claimed.

Reproduce the backend group using `npm run test:emulator:library` from
`apps/backend/functions` with Node 22 and JDK 21 on PATH (`JAVA_HOME` set;
the Firestore Emulator needs Java). To include real Flutter adapters,
set `RECHARGE_G_MOBILE=1`, `RECHARGE_DART` to the Dart executable and
`RECHARGE_FLUTTER_TOOL` to the existing Flutter tool snapshot before the run.
The same group starts/stops only local demo Emulators, seeds synthetic inputs
and builds backend artifacts before starting them.

## Rollback

Disable `library.self_service` and the Library test define, then select the
existing localOnly binding/restart the app. No remote data is copied into local
namespaces. Local v3 edits are not read by older v2-only builds; preserve the
old keys until explicit migration/retention work. Do not drop server tombstones
or erasure fences while stale clients can retry.
