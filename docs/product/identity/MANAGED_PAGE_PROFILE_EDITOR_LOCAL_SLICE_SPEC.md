# RECHARGE — Managed Page Profile Editor Local Slice Specification

Status: **Approved**

Version: **1.0**

Date: **2026-08-19**

Slice: **PP-01A — bounded local/mock profile field editor (mock auto-approve)**

## 0. Authority and intent

This is the Approved current-slice specification for the first application
integration of `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.34 §4.5
(`ManagedPageFieldModerationOverlay`, `PP-D48`, Accepted). It follows
`PUBLIC_PROFESSIONAL_PAGE_LOCAL_SLICE_SPEC.md` and
`TEAM_INVITATION_LOCAL_SLICE_SPEC.md`'s own bounded local/mock precedent and
structure. Accepted ADRs 0016/0017 remain higher authority.

The slice proves the owner/team side of the field-moderation overlay
contract — submit an edit and read it back through the public projection —
entirely on local storage. It does not authorize Firebase, a production
backend, a real moderation queue/reviewer, media upload/quarantine, or any
of `PP-D48`'s explicitly backend-dependent guarantees (enumeration-safe
existence disclosure, 30-day raw-value retention/purge, Trust & Safety
restriction interaction).

**Product decision (this session, recorded for traceability):** local
`pendingSubmission` resolution is **mock auto-approve** — a submitted edit
is resolved to `lastApprovedValue` in the same call, with no persisted
pending/review state. This is a deliberate simplification, not a claim
about how production moderation will behave; a future real-moderation slice
replaces only the resolution step, not the overlay's stored shape.

## 1. Scope

PP-01A implements:

- `ManagedPageEntity.verificationRevision` (new field, default `1`) —
  separate from `revision` by design, per `PP-D48`'s explicit rule that an
  approved value's `approvedForVerificationRevision` must match the page's
  own verification revision, not its ordinary edit revision. Nothing in the
  current bounded local runtime moves `verificationStatus`, so this stays
  `1` for every page today;
- `ManagedPageFieldModerationRepository` (new port) and a local/mock
  adapter, page-scoped, schema-versioned, fail-closed;
- `SubmitManagedPageFieldEditUseCase` — capability-gated (`page.manage`),
  field/value-type-checked against `ManagedPageFieldModerationOverlay.accepts`,
  locale-bounded and length-bounded (this slice's own placeholder limits,
  §3), optimistic-concurrency-checked (`basedOnOverlayRevision`), resolved
  to approved in the same call (mock auto-approve);
- `ResolvePublicProfessionalPageUseCase` now sources `shortDescription` and
  `description` from the approved overlay via `effectiveValue`, instead of
  leaving them permanently `null`;
- an owner/team editor card in the Professional Page workspace (Overview
  section) for the three fields reachable without a media subsystem: short
  description, long description, custom activity label — edited for the
  page's `defaultLocale` only;
- the public page view rendering `description` alongside the existing
  `shortDescription` render.

## 2. Explicitly out of scope

- `avatarMediaRef`/`coverMediaRef` editing — no media picker/upload/storage
  subsystem exists in this app; `MediaValue` stays supported by the domain
  model for a future slice, but no UI submits it;
- multi-locale editing UI — the editor writes only the page's own
  `defaultLocale` key; a `ManagedPageLocalizedTextValue` with other locales
  can exist (e.g. migrated data) but this slice's UI never authors one;
- a real moderation queue, reviewer UI, approve/reject as separate actions,
  or any persisted `pendingSubmission`/`latestRejection` — `latestRejection`
  is always cleared to `null` on a successful mock-approve in this slice;
- `displayName` and avatar editing through the overlay — the resolver
  continues to read these directly from `ManagedPageEntity`, unchanged;
- enumeration-safe existence disclosure, contact-style abuse/rate limits on
  edits, 30-day raw-value retention/purge after rejection, and Trust &
  Safety restriction interaction (`PP-D48`) — all meaningless or
  unenforceable without a real moderation backend;
- verification-revision transitions — nothing in this slice or its
  dependencies moves `verificationStatus`, so `verificationRevision` is
  never incremented by any code path yet;
- Firebase, network, backend, deployment or production data processing.

Out-of-scope actions are hidden rather than rendered as working buttons.
Their target contracts remain in the full functional specification.

## 3. Runtime rules

1. Only an active member holding `page.manage` may submit a field edit.
2. A submitted value must match its field key's registered variant
   (`ManagedPageFieldModerationOverlay.accepts`); a mismatch fails closed.
3. A `ManagedPageLocalizedTextValue` must include the page's own
   `defaultLocale` key and only keys drawn from `supportedLocales`.
4. Bounded local length limits (placeholders pending the Approved delivery
   slice's real numbers): short description ≤160 chars, description
   ≤2000 chars, custom activity label ≤60 chars, all after trimming; an
   empty trimmed value is rejected as a submission (use a clear instead).
5. Each submission carries `basedOnOverlayRevision`; a mismatch against the
   currently stored overlay revision fails closed as stale, never merges.
6. A clear (`value: null`) removes `lastApprovedValue` and sets
   `clearedAtUtc`, leaving `approvedForVerificationRevision` at its last
   value for audit only — `effectiveValue` already treats a cleared
   overlay as absent regardless.
7. `effectiveValue` requires `approvedForVerificationRevision` to equal the
   page's current `verificationRevision`; the public resolver enforces this
   through the overlay entity's own method, not a duplicate check.
8. Unknown schema, field key, overlay value type, or locale fails closed.

## 4. File boundary

Runtime changes stay inside `features/identity` plus app composition:

- `features/identity/domain/entities/managed_page_entity.dart` —
  `verificationRevision` field only, additive and defaulted;
- `features/identity/domain/repositories/managed_page_field_moderation_repository.dart`;
- `features/identity/domain/usecases/submit_managed_page_field_edit_usecase.dart`;
- `features/identity/domain/usecases/resolve_public_professional_page_usecase.dart`
  — extended to read the overlay, no other behavior changed;
- `features/identity/data/` — local/mock adapter for the moderation port;
- `features/identity/application/state/managed_page_profile_editor_state.dart`,
  `application/controllers/managed_page_profile_editor_controller.dart`;
- `features/identity/presentation/widgets/managed_page_profile_editor_card.dart`;
- `app/di/` — dependency wiring only.

No new cross-feature import is permitted.

## 5. Persistence and migration

- `IdentityWorkspaceLocalDataSource.schemaVersion` moves 2 → 3 to persist
  `verificationRevision`; v1 and v2 records still load, defaulting the new
  field to `1`.
- Field overlays persist per-page under a dedicated secure-storage key
  (`identity_field_moderation_<pageId>`), independent of both the
  workspace/page record and the Team Invitation record.
- Rollback removes the DI registrations, the editor UI entry point and the
  resolver's overlay read (reverting `shortDescription`/`description` to
  always-`null`); it does not delete or rewrite existing page/membership
  records, and leaves any already-persisted overlay data in place, unread.

## 6. Acceptance criteria

- **PP-01A-AC01:** An active member holding `page.manage` can submit a
  short description, description or custom activity label for the page's
  default locale; the resolved overlay's `lastApprovedValue` reflects it
  immediately.
- **PP-01A-AC02:** A member lacking `page.manage`, or not an active member,
  cannot submit an edit.
- **PP-01A-AC03:** A value not matching its field key's registered variant
  is rejected before any capability check consequence is observable.
- **PP-01A-AC04:** A locale outside `supportedLocales`, or a value missing
  the page's `defaultLocale` key, is rejected.
- **PP-01A-AC05:** A value exceeding its field's bounded length limit is
  rejected.
- **PP-01A-AC06:** A stale `basedOnOverlayRevision` is rejected rather than
  silently merged or overwritten.
- **PP-01A-AC07:** A clear request removes the effective value and sets
  `clearedAtUtc`; `effectiveValue` returns null immediately after.
- **PP-01A-AC08:** An overlay approved under a different
  `verificationRevision` than the page's current one is not exposed by
  `effectiveValue`, and the public resolver reflects that (returns `null`
  for that field, not the stale value).
- **PP-01A-AC09:** The public resolver's `shortDescription`/`description`
  match what an authorized editor most recently approved, at the requested
  locale, falling back to the default locale only if the requested locale
  has no value.
- **PP-01A-AC10:** A v1 or v2 `ManagedPage` record migrates with
  `verificationRevision == 1`; a v3 round-trip preserves an explicit value.
- **PP-01A-AC11:** Analyzer, focused and full test suites are recorded as
  evidence before this slice is claimed Review in `LAUNCH_STATUS.md`.

## 7. Required tests

- submit: happy path per field key, missing-capability rejection,
  field/value-type mismatch, unsupported locale, missing default-locale
  value, over-length value, stale revision, clear request;
- overlay `effectiveValue` verification-revision scoping (already covered
  by the pre-existing entity unit tests, re-verified here through the
  use case);
- resolver: approved overlay content surfaces at the requested/default
  locale; an overlay approved under a stale verification revision is
  hidden;
- `ManagedPageEntity`/datasource migration: v1/v2 records default
  `verificationRevision` to `1`; v3 round-trip preserves an explicit value;
- widget: capability-gated edit affordance visibility, empty-state
  rendering, an edit round-trip updating the displayed value;
- existing identity/workspace/public-page regression suites.

## 8. Rollback and completion

Rollback removes the DI registrations and the editor UI entry point, and
reverts the resolver's overlay read. It does not delete local pages,
memberships, drafts, Team Invitation records or already-persisted overlay
data.

PP-01A may reach **Review** when all ACs are implemented and scoped gates
are green. It cannot make Page profile production Done (`PP-01`); that
still requires production Identity, a real moderation authority replacing
mock auto-approve, media upload/quarantine, and the full functional
specification's DoD.
