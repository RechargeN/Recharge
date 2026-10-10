# Symbols, shared code and entrypoints

This describes the pre-cutover source preserved by [MANIFEST](MANIFEST.md).
It does not implement or authorize retirement. System roles/access remain.

| Symbol / consumer | Historical purpose | Later treatment under PVR plan |
|---|---|---|
| _ViewerProfileBody | Viewer composition inside common profile_page.dart | Remove only after Saved/Visited transferred |
| _ViewerUpgradeRow | Settings upgrade affordance | Remove separate Viewer-to-Creator presentation |
| _RoleTrack/_RoleCard/_RoleStatusBadge | Legacy selector without experience scope | Remove obsolete selector, retain actual access checks |
| ProfileRoleTier.user | Actual access classification and UI branch | Preserve actual access semantics, change display use |
| _profilePresentationSummary/_profileBadgeLabel/_profilePageTitle/_profileContextLine | Display derived from experience | Change display without mutation grant |
| AccountExperience/AccountExperienceScope | viewer/creator/professionalPage presentation | Coordinate enum/consumers in later approved cutover |
| effectiveExperience/preview mapper | Verification-driven personal display; page wins | Presentation change only |
| AdminExperiencePreview/selectAdminPreview | Session preview; admin capability guard | Viewer preview removal requires new decision; preserve guard/reset |
| WorkspaceSection/WorkspaceSectionHost | Inline Settings personal/page selection | Keep exact membership/quota/navigation |

The complete common profile_page.dart is included. _ViewerProfileBody alone
cannot run: private helpers, shared state, imports and routed callbacks live
in that same file. Shared code remains in app; the archive is a copy only.

| External dependency | Source location / relationship |
|---|---|
| ScenarioLibraryPanel | features/explore/presentation/widgets; ownerId library before role branch |
| Scenario library facade / planning resolver | app/application; typed openScenario intent, owned draft lookup |
| VisitHistory | app/application/visit_history_facade.dart, visit_history_providers.dart; self-reported data and canonical Details |
| Favorites | features/favorites/application/favorites_providers.dart and repository/entities; Saved state |
| Create | create_providers.dart, CreateController/domain drafts, form/config engine and type-specific gates |
| Discover | discover_providers, saved search/smart search state, query handoff |
| Auth | auth_providers.dart/AuthUserEntity; authenticated user, role/capability inputs |
| Explore | explore_controller/explore_providers/state; personal edits/settings |
| Routing | app/router/app_router.dart and route_names.dart; GoRouter |
| Identity | workspace controller/access snapshot/local datasource; exact-ID page access |
| Design system | package:design_system/design_system.dart; RechargeTheme profile tokens in packages/design_system |
| Widget regression support | widget_test_viewport.dart and event_create_test_support.dart |

Import declarations are preserved in full raw files. This inventory gives
key relationships, not a transitive dependency closure. The full repo at the
recorded HEAD and compatible SDK/dependency resolution are needed to run code.

Entrypoints: /profile and /profile/workspace; /profile/visited, /favorites,
/settings, /create and Professional Page routes. There is no separate Viewer
URL. Router injects WorkspaceSectionHost into SettingsPage.workspaceSectionBuilder.
The older 012d workspace_switcher_page.dart is another baseline and is not
copied. Replacement personal Creator display belongs to later stages 04/05;
this snapshot records the original branches and keeps all actions intact.

WorkspaceRef personal/page and PublisherRef user/page are distinct from
presentation preview. Existing Event draft publisher is not rewritten by
switching defaults. Scenario viewer/unlistedViewer and PublicPageViewerContext
are unrelated meanings of viewer and are not retirement targets.

## Current treatment checked in 07 (2026-10-10)

Accepted ADR 0021 and stages 04–05 removed the Viewer body/upgrade/selector,
Viewer experience and Viewer Admin preview. The current single personal Creator
layout retains shared actions. ProfileRoleTier.user remains an internal access
input; profileRoleSummaryForPresentation is referenced by regression tests and
is not deleted as unproven dead code. Scenario viewer/unlistedViewer,
PublicPageViewerContext and historical terms remain valid distinct concepts.
No Dart cleanup was necessary in 07. The import inventory and restore drill
are recorded in 07-retirement-restore.md; runtime matrix gaps remain in 06.
