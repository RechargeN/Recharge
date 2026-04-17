# ADR 0013: Domain And Product Policy Baseline

- Status: Accepted
- Date: 2026-04-17
- Review date: 2026-07-17
- Deciders: Recharge team
- Related: [Architecture Baseline](../architecture/ARCHITECTURE_BASELINE.md)

## Context

Before coding MVP slices, we need fixed product/domain policies for ownership, lifecycle, permissions, moderation, session behavior, geo/time/search, offline/sync, privacy, abuse controls, and audit.

## Decision

The following baseline is mandatory for MVP unless superseded by a later ADR.

## Policies

1. Ownership / entity rights
   - Every major entity (`event`, `place`, `profile`, `page`) has `owner_type` and `owner_id`.
   - Action permissions are capability-based (not role-only): create/edit/publish/archive/delete are checked explicitly.

2. Entity lifecycle
   - Standard states: `draft`, `pending_review`, `published`, `archived`, `hidden`, `deleted`.
   - `hidden` is moderation/system-driven visibility restriction.

3. Soft delete / archive policy
   - Default soft-delete retention: **30 days**.
   - Archive keeps entity recoverable and non-public.
   - Hard delete is final after retention or legal request.

4. Moderation / report system
   - Auto-hide threshold: **>= 5 unique reporters per object within 24 hours**.
   - Uniqueness is per user per object.
   - Reports still require moderation review workflow.

5. Permission model
   - Starting roles: **User, Creator, Admin**.
   - `Moderator` is deferred beyond MVP unless load requires.
   - Capabilities gate privileged actions (publish, manage, moderation actions).

6. Session / auth edge cases
   - Support token refresh, revoked sessions, forced logout, and session restore.
   - Multi-device baseline: **up to 3 active sessions per account**.
   - Guest mode is allowed for read-only access where applicable.

7. ID strategy
   - Server IDs: UUID/ULID-style immutable IDs.
   - Local drafts can use temporary local IDs (`loc_*`), mapped to server IDs after sync.

8. Booking / reservation model
   - MVP baseline: **no payment processing**.
   - Reservation states: `pending`, `confirmed`, `cancelled`, `expired`, `waitlisted`.

9. Time model
   - Persist timestamps in UTC and store IANA timezone for local interpretation.
   - Event model supports start/end, duration, deadlines, recurrence where applicable.

10. Geo model
   - Core fields: `lat`, `lng`, address components, area/city metadata, accuracy.
   - Radius-based search from explicit map/search center.

11. Search / ranking / recommendations
   - MVP ranking baseline: **geo + freshness**.
   - Popularity is a secondary signal, not primary.
   - Zero-result fallback must provide relaxation/suggestion behavior.

12. Taxonomy / categories governance
   - System categories/tags are platform-managed.
   - User-generated tags are constrained and subject to moderation policy.

13. Offline / cache / sync strategy
   - Offline drafts are supported.
   - Conflict policy baseline: **last-write-wins + user warning**.

14. Data migrations
   - Local schema changes are versioned and migrated forward.
   - Incompatible version handling requires guarded fallback and migration path.

15. Media pipeline
   - Client preprocessing (compression/preview), retry policy, and orphan cleanup are required.
   - Media references are decoupled from draft finalization.

16. Deep links / navigation contracts
   - Stable deep-link contracts for entity pages (`event/place/profile`).
   - Push and external links must resolve through the same route guard rules.

17. Feature flags / remote config
   - Critical features must have kill switches.
   - Rollback without app release is required for high-risk features.

18. Observability
   - Capture errors, structured logs, key product events, and performance signals.
   - Correlate by user/session/build identifiers where permitted.

19. Privacy / consent
   - Baseline: **opt-in in EU, opt-out in non-EU**.
   - Mandatory legal/privacy review per market before release.
   - Consent withdrawal and user data handling flows are required.

20. Abuse / anti-spam / fraud
   - Creator publish velocity limit baseline: **100/day**.
   - Add duplicate and suspicious activity checks in moderation pipeline.

21. Audit trail
   - Full audit trail visibility is **admin/moderation only**.
   - Immutable history for create/edit/publish/archive/moderation actions.

## Consequences

- Positive: removes ambiguity and unblocks implementation of MVP slices.
- Trade-off: some defaults may be revisited after real usage data.

## Change Management

Any policy change above requires:

1. Mini-RFC,
2. approval,
3. ADR update/new ADR,
4. rollout and rollback notes.
