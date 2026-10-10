# ADR 0021: Unified Personal Profile

- Status: Accepted
- Date: 2026-10-10
- Slice: PVR-01 (local UI, documentation, archive and regression only)
- Deciders: Recharge product owner; explicit acceptance on 2026-10-10
- Supersedes: ADR 0015 section 2 only for personal UI terminology;
  ADR 0017 Admin experience preview only for the available presentation values
- Related: [ADR 0013](0013-domain-policy-baseline.md),
  [ADR 0015](0015-authenticated-viewer-verified-creator-professional-page.md),
  [ADR 0016](0016-bounded-identity-workspace-during-stabilization.md),
  [ADR 0017](0017-admin-experience-preview-and-user-created-pages.md),
  [Identity Publisher slice](../product/IDENTITY_PUBLISHER_SLICE_SPEC.md),
  [bounded PVR plan](../product/VIEWER_PROFILE_RETIREMENT_PLAN.md)

## Context

The product owner has chosen to retain all existing personal functions and
remove the separate Viewer presentation. The personal profile is called
Creator; Professional Pages remain distinct owner/manager work contexts.
The chosen product outcome does not by itself accept this particular ADR text.

Baseline 00 confirms that Viewer is a branch of the shared profile_page.dart,
not a separate URL. Admin preview and fallback choose that branch. The same
file contains Creator layout, private helpers and shared action handoffs;
deleting or archiving it wholesale would lose required behavior.

## Decision

### 1. One personal Creator Profile

Every authenticated account uses one personal profile UI called Creator,
independent of whether the account has the technical Creator role or publishing
verification/grants. Settings has one personal row labelled Creator and the
existing list of authorized Professional Pages. There is no separate Viewer
profile, Viewer preview, Viewer-to-Creator upgrade row or legacy profile-mode
selector, including the /profile/workspace fallback.

Existing personal navigation stays Home / Favorites / Smart Search /
Notifications / Profile. Professional Page navigation stays Page / Content /
Create / Notifications / Account. Page Account retains personal account,
Settings/switcher/logout actions and return to personal context.

Favorites/Saved, self-reported Visit History, owned personal Scenario library,
Quick Plan, personal edits/settings and existing eligible Creator tools,
Created/listing/search/map/draft/route handoffs are retained. Creator eligibility
still controls the relevant tools and operations; it never selects another
kind of personal profile. A protected operation's refusal leaves the person
in the same personal UI and preserves their work.

### 2. Display name does not grant authority

Persisted system roles remain User / Creator / Admin. The technical Creator
role still requires the accepted separate identity verification and grants.
Authentication, opening Creator Profile or selecting a preview never grants
Creator role, verified status, capabilities, page membership or mutation rights.
Unknown/loading/error access stays fail-closed for protected operations.

Mandatory authentication remains ADR 0015 policy. Existing account status,
resource ownership/lifecycle, type-specific capabilities and application
mutation guards remain effective. Personal libraries and owned personal
planning have their existing authentication/ownership/account conditions;
publishing verification is not a new gate on opening the profile, browsing
Saved/Visits or creating/editing/saving an owned personal Scenario.
Catalog publication, submit/moderation entry and other protected operations
keep their accepted operation-specific verification and capability conditions.
This ADR does not add operations that are absent from the current runtime.

WorkspaceRef remains personal/page with exact userId/pageId. PublisherRef
remains user/page with stable IDs. Active workspace supplies only the default
publisher of a new eligible draft; existing draft publishers are not rewritten.
Page access requires active membership and grants for that exact page. Owner,
manager, quota, pending-request and local notification behavior stays unchanged.
Admin tools remain a separate protected surface, not a workspace or publisher.

### 3. Admin preview

The presentation set in ADR 0017 becomes creator / professionalPage.
Creator here names the unified personal UI, not an impersonated technical role.
Preview remains session-scoped, requires authenticated Admin and
admin.experience.preview, and never changes access/verification/PublisherRef.
Professional Page preview without a real page retains empty onboarding and
never invents a page or membership. Existing preview reset rules stay effective.

Removing a Viewer preview does not remove negative test coverage: ordinary
User, all existing verification states, missing/revoked capabilities, unknown
access and exact-page membership are tested as distinct access conditions
within the same personal UI. Changing preview value does not spoof those facts.

### 4. Privacy and terminology boundaries

The personal UI name does not make any account public, searchable, followed
or eligible for an extended public Creator card. Existing public projection,
privacy, account-status and visibility rules remain with their owning contracts.
Personal libraries are not exposed through public identity by a label change.

Scenario collaboration viewer/unlistedViewer and PublicPageViewerContext
are unrelated meanings and remain intact. Route, Scenario and Quick Plan remain
distinct aggregates. Moving common rules to Creator documentation preserves
source IDs, owners and Draft/Open/Approved/Accepted maturity; it does not accept
all unresolved decisions in the larger Draft profile specifications.

## Bounded implementation contract

Upon explicit acceptance, this ADR supplies only the architecture basis for
the bounded local PVR-01 plan sections 1, 6, 13, 15 and 16. Primary runtime files
are F01–F07; conditional consumers and existing tests remain the exact set in
plan section 13. The shared profile file stays in app, with targeted removal
of obsolete presentation after transferring required actions.

Cross-layer changes use existing application/presentation/config mechanisms.
No domain/access rewrite, new dependency, parallel profile engine, new Create
type, backend/cloud/provider integration, real verification, Follow, Payments,
new public identity delivery or wholesale Draft feature implementation is
included. Identity quota/membership/authority and current data stores are
preserved. Each later stage is dispatched separately by the user; acceptance
here does not start another stage or authorize commit/push/merge/deployment.
If a concrete consumer or storage finding expands scope, record it and obtain
the required bounded plan decision before that dependent implementation.

## Archive and data compatibility

[Verified pre-edit archive](../archive/viewer-profile/2026-10-10/README.md) and
[manifest](../archive/viewer-profile/2026-10-10/MANIFEST.md) preserve full source,
tests/specs/context and selective restore instructions. Keep it immutable and
outside runtime/package/assets/test discovery. It is not a standalone package.

Baseline 00 finds persisted workspace personal/page and publisher user/page,
with session-only preview. Expected data migration is zero: retain storage
keys/schema and account/page/favorites/visits/plans/draft records. Do not rename
WorkspaceType.personal or PublisherType.user to creator, change persisted roles,
clear user data or mass-rewrite publishers. Removing enum ordinals is safe
only while they have no persisted readers. Recheck before cutover; a newly
found persisted experience name/ordinal requires a separately documented narrow
compatibility reader and tests, preserving authority and records.

## Gates and rollback

Keep the archive before runtime edits; transfer active common requirements
with section/decision ownership evidence before retiring Viewer specs. Validate
actual access separately from display, then perform a coherent UI/enum/preview
cutover and behavior regression. Preserve all A01–A12/U01–U16 plan scenarios.

Local final gates: flutter analyze and full flutter test from apps/mobile;
repository boundary and diff checks from root; archive isolation and selective
restore exercise. Targeted tests are preparation evidence, not final acceptance.
Device/cloud/production readiness is not inferred from local results.

While Proposed, revise/revert only the document delta. After acceptance,
architecture changes require a new superseding ADR under repository rules.
An implementation rollback reverses only the coordinated PVR UI/enum/consumer/
test/doc delta, preserving unrelated WIP, user data and stored publishers.
Retain the immutable archive; do not restore an old common file over newer work.
A future return of a separate Viewer presentation requires a new explicit
decision and adaptation against then-current contracts.

## Acceptance record

Accepted explicitly by the product owner in this chat on 2026-10-10:
“Принимаю конкретный текст ADR 0021 и связанный bounded scope плана §6.1/§13”.
The accepted Proposed text had SHA-256
9444AE1F0F7C110D30F491C1991792550D59EB9F734B134B72D473D2A144D2C9.
This update records acceptance/status only; the decision and bounded scope
are unchanged. Earlier Accepted ADR files and immutable archive are preserved.
Acceptance does not dispatch another stage or authorize commit/push/deployment.