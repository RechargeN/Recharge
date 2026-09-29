# RECHARGE — Team Invitation Local Slice Specification

Status: **Approved**

Version: **1.0**

Date: **2026-08-19**

Slice: **PP-03A — bounded local/mock TeamInvitation send, list and revoke**

## 0. Authority and intent

This is the Approved current-slice specification for the first application
integration of `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.34 §22.1
(`PP-D14`) and §22.9 (`PP-D28`). Accepted ADRs and
`PUBLIC_PROFESSIONAL_PAGE_LOCAL_SLICE_SPEC.md`'s own precedent for a
bounded local/mock exception remain higher authority; this spec follows
that document's structure and discipline.

The slice proves the sending side of the `TeamInvitation` contract —
create, idempotent resend, list and revoke — entirely on local storage. It
does not authorize Firebase, a production backend, acceptance by an
invited person, delivery (email/SMS), or any enumeration-safe
existence-disclosure guarantee. `PP-03` itself (the production Team
roadmap slice) additionally requires backend authority and negative
tests that are out of reach for a local/mock exception and are not
claimed here.

## 1. Scope

PP-03A implements:

- a typed `TeamInvitationEntity` matching §22.1's `TeamInvitation` shape
  (`pageId`, `target`, `proposedRelationship`, `proposedCapabilities`,
  `sentAtUtc`, `expiresAtUtc`, `resendCount`, `status`,
  `invitedByUserId`), scoped to the statuses reachable without a second
  authenticated device: `pending`, `revoked`, `expired`;
- `SendTeamInvitationUseCase` — creates a new invitation or, for an
  already-pending target, idempotently resends it (7-day expiry, 24h
  resend cooldown per `PP-D14`'s Accepted parameters);
- capability-gated authorization: only an active member holding
  `page.team.manage` may send or revoke, and per `PP-D28` an inviter may
  delegate only capabilities they themselves hold;
- `RevokeTeamInvitationUseCase` — idempotent revoke of a pending
  invitation; revoking an already-revoked or expired record is a
  no-op, never an error;
- a page-scoped local datasource/repository pair persisting the list of
  invitations for a page, following the same schema-versioned
  fail-closed JSON convention as `IdentityWorkspaceLocalDataSource`.

## 2. Explicitly out of scope

- acceptance of an invitation by the invited person — this requires
  their own authenticated session (a second real device or account) and
  is forbidden by ADR 0016/0017's bounded local/mock exception, exactly
  as `PPP-01A` deferred Follow/Contact/Report/Block/Mute for the same
  reason;
- creating a `ManagedPageMembership` from an accepted invitation — with
  acceptance out of scope, this never happens in this slice;
- email/SMS delivery of the invitation;
- single-use acceptance token, replay protection and accept/revoke/expire
  atomicity (`PP-D28`) — all meaningless without acceptance;
- enumeration-safe existence disclosure for an unknown/foreign target,
  contact normalization, encryption or retention policy (`PP-D28`) —
  local storage keeps the raw target value plaintext-in-place, matching
  every other locally persisted identity record in this codebase; no
  claim of production-grade contact handling is made;
- server-side or cross-device invitation rate limiting beyond the local
  24h resend cooldown already in §1;
- migration of legacy `ManagedPageMembership.status == invited` rows into
  `TeamInvitation` records (§22.1 notes `invited` stays legacy-read-only;
  this slice only stops new writes from using it — it does not touch
  existing rows);
- any UI or usecase for the invited person's side (accept/decline/view
  pending invite) — presentation in this slice covers the inviting
  member only;
- Firebase, network, backend, deployment or production data processing.

Out-of-scope actions are hidden rather than rendered as working buttons.
Their target contracts remain in the full functional specification.

## 3. Runtime rules

1. Sending and revoking both require the acting user to hold an active
   `ManagedPageMembership` on the target page with `page.team.manage`.
2. An invitation may never propose `ManagedPageRelationship.owner` —
   ownership is transferred, never granted by invitation.
3. `proposedCapabilities` must be a subset of the inviter's own
   capabilities (`PP-D28`); a superset request fails closed.
4. Sending to a target with an existing `pending` invitation never
   creates a duplicate record — it resends idempotently, subject to the
   24h cooldown; within cooldown, resend is a same-state no-op.
5. Revoking a `pending` invitation sets `status = revoked` and
   increments `revision`. Revoking anything else already terminal is a
   no-op that returns the existing record unchanged.
6. `effectiveStatusAt(now)` derives `expired` from `pending` plus
   `expiresAtUtc` without a background job or write; expiry is computed,
   not scheduled.
7. Unknown schema, status or target type fails closed on load.

## 4. File boundary

Runtime changes stay inside `features/identity` plus app composition:

- `features/identity/domain/entities/team_invitation_entity.dart`;
- `features/identity/domain/repositories/team_invitation_repository.dart`;
- `features/identity/domain/usecases/send_team_invitation_usecase.dart`,
  `revoke_team_invitation_usecase.dart`;
- `features/identity/data/datasources/team_invitation_local_datasource.dart`;
- `features/identity/data/repositories/team_invitation_repository_impl.dart`;
- `features/identity/application/state/team_invitation_state.dart`,
  `application/controllers/team_invitation_controller.dart` — presentation
  state, driven only by the two use cases and the repository;
- `features/identity/presentation/widgets/team_invitations_card.dart` —
  sending member's list/send/revoke card, surfaced in the Professional Page
  workspace's Account section for an active member only;
- `app/di/` — dependency wiring only.

No new cross-feature import is permitted.

## 5. Persistence and migration

- Invitations persist per-page under a dedicated secure-storage key
  (`identity_team_invitations_<pageId>`), separate from the
  `IdentityWorkspaceLocalDataSource` owner-namespaced key — sending-side
  invitation state is not workspace state.
- Schema is versioned (`schemaVersion = 1`); a future field addition
  must migrate without loss, matching the existing identity datasource
  convention.
- Rollback removes the DI registrations and any UI entry point; it does
  not delete or rewrite existing page/membership records.

## 6. Acceptance criteria

- **PP-03A-AC01:** An active member holding `page.team.manage` can send
  an invitation to a `userId`, `email` or `phone` target that is not
  currently pending for that page.
- **PP-03A-AC02:** Sending to an already-pending target within the 24h
  cooldown returns the unchanged existing record; sending after cooldown
  resends (increments `resendCount`, refreshes `expiresAtUtc`).
- **PP-03A-AC03:** An inviter cannot propose a capability they do not
  themselves hold, and cannot propose `owner` relationship.
- **PP-03A-AC04:** A non-member, a suspended/revoked member, or a member
  lacking `page.team.manage` cannot send or revoke an invitation for that
  page.
- **PP-03A-AC05:** Revoking a pending invitation marks it `revoked` and
  increments `revision`; revoking an already-revoked or expired
  invitation is a no-op, never an error.
- **PP-03A-AC06:** `effectiveStatusAt` reports `expired` for a pending
  invitation past `expiresAtUtc` without any explicit write.
- **PP-03A-AC07:** Invitations are stored per-page, independent of
  `ManagedPageMembership`, and never produce a membership record in this
  slice (acceptance stays out of scope).
- **PP-03A-AC08:** Analyzer, focused and full test suites are recorded
  as evidence before this slice is claimed Review in `LAUNCH_STATUS.md`.

## 7. Required tests

- send: happy path, missing actor/page, invalid target (empty, malformed
  email, malformed phone), owner-relationship rejection, capability
  delegation rejection, inactive/missing membership rejection;
- resend idempotency: within cooldown (no-op) and after cooldown
  (resend with incremented count);
- revoke: happy path, idempotent no-op on already-terminal status,
  not-found, unauthorized actor;
- persistence round-trip through the local datasource including a
  multi-invitation page list;
- existing identity/workspace regression suites.

## 8. Rollback and completion

Rollback removes the DI registrations and any presentation entry point.
It does not delete local pages, memberships, drafts or already-persisted
invitation records.

PP-03A may reach **Review** when all ACs are implemented and scoped
gates are green. It cannot make Team production Done (`PP-03`); that
still requires backend authority, negative tests, acceptance, delivery
and the full functional specification's DoD.
