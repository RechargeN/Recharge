# MVP Plan (3 Sprints)

Planning horizon: 3 sprints (recommended 2 weeks each)  
Goal: reach releasable MVP with core user value and controlled risk.

## 1) Global Rules

- Work is executed by vertical slices (end-to-end behavior, not isolated layers).
- Every slice defines:
  - scope,
  - dependencies,
  - definition of done,
  - out of scope,
  - release criteria,
  - rollback criteria.
- Every task/PR must reference a slice ID.

## 2) Slice Index

| Slice ID | Sprint | Name | Priority | Status | Owner |
|---|---|---|---|---|---|
| S1-AUTH-01 | Sprint 1 | Auth Core Session | P0 | Done (checkpoint 2026-04-17) | Recharge team |
| S1-DISC-01 | Sprint 1 | Discover Feed + Details (Read) | P0 | Done (checkpoint 2026-04-17) | Recharge team |
| S1-CORE-01 | Sprint 1 | Core App Shell + Telemetry Wiring | P0 | Done (checkpoint 2026-04-17) | Recharge team |
| S2-DISC-02 | Sprint 2 | Discover Search + Filters + Map Radius | P0 | Done (checkpoint 2026-04-18) | Recharge team |
| S2-EXP-01 | Sprint 2 | Profile + Settings Basic | P1 | Done (checkpoint 2026-04-18) | Recharge team |
| S2-FAV-01 | Sprint 2 | Favorites Basic | P1 | Done (checkpoint 2026-04-18) | Recharge team |
| S3-CRT-01 | Sprint 3 | Create Draft + Publish Happy Path | P0 | Done (checkpoint 2026-04-20) | Recharge team |
| S3-NOTIF-01 | Sprint 3 | Notifications List + Mark Read | P1 | Done (checkpoint 2026-04-20) | Recharge team |
| S3-REL-01 | Sprint 3 | Hardening + Release Readiness | P0 | Done (checkpoint 2026-04-20) | Recharge team |

## 3) Sprint 1 (MVP Alpha Internal)

### Slice `S1-AUTH-01` - Auth Core Session

Scope:
- sign in screen + validation + submit;
- restore session on app start;
- sign out flow.

Dependencies:
- routing + guards baseline;
- secure storage;
- auth API contract.

Definition of done:
- auth happy-path works end-to-end;
- failed sign-in surfaces mapped user error;
- required tests by matrix (unit + widget + integration).

Out of scope:
- social login providers;
- multi-factor auth;
- advanced account recovery.

Release criteria:
- session restore success rate meets internal acceptance target;
- no blocker defects in auth critical flow.

Rollback criteria:
- if auth failure spike is detected, disable new auth flow flag and restore previous stable flow.

### Slice `S1-DISC-01` - Discover Feed + Details (Read)

Scope:
- load discover feed;
- open details page from feed item;
- basic empty/error states.

Dependencies:
- discover API contracts;
- shared loading/error UI;
- telemetry event catalog entries.

Definition of done:
- feed and details load for valid data;
- graceful behavior for empty/error responses;
- required tests by matrix (unit + widget + integration for critical path).

Out of scope:
- filters/search/map interactions;
- personalization ranking logic.

Release criteria:
- feed load and details open pass integration smoke in CI;
- no crash in primary read flow.

Rollback criteria:
- fallback to safe read-only cached/mocked feed provider if remote integration is unstable.

### Slice `S1-CORE-01` - Core App Shell + Telemetry Wiring

Scope:
- app bootstrap, route observers, lifecycle hooks;
- analytics/crash/logger adapters wired for active flows.

Dependencies:
- tech stack ADR defaults;
- analytics taxonomy and event catalog.

Definition of done:
- core events emitted for auth/discover critical actions;
- app starts cleanly in dev/stage flavors;
- CI gates remain green.

Out of scope:
- full dashboard setup automation;
- non-critical low-level instrumentation.

Release criteria:
- observability visibility for Sprint 1 slices is available.

Rollback criteria:
- if telemetry adapter breaks app stability, switch to no-op adapter under controlled flag.

## 4) Sprint 2 (MVP Beta)

### Slice `S2-DISC-02` - Discover Search + Filters + Map Radius

Scope:
- search input -> result list;
- apply/reset filters;
- map radius update affecting result set.

Dependencies:
- discover domain/usecases;
- map/location permissions flow;
- filter-related contracts.

Definition of done:
- user can search, filter, and see consistent results;
- radius changes update results deterministically;
- required tests by matrix (includes mandatory integration).

Out of scope:
- advanced ranking/recommendation tuning;
- offline geosearch optimization.

Release criteria:
- integration scenario for search/filter/map passes in CI and staging smoke.

Rollback criteria:
- disable filter/radius feature flags and keep basic discover feed read path.

### Slice `S2-EXP-01` - Profile + Settings Basic

Scope:
- profile view/edit basic fields;
- settings page with key toggles (language/currency placeholders if needed).

Dependencies:
- explore contracts;
- local settings storage.

Definition of done:
- profile/settings updates persist and rehydrate correctly;
- error handling and validation covered;
- required tests by matrix.

Out of scope:
- advanced role upgrade onboarding;
- full account management suite.

Release criteria:
- settings persistence stable across app restart.

Rollback criteria:
- hide editable controls and keep read-only profile if persistence defects appear.

### Slice `S2-FAV-01` - Favorites Basic

Scope:
- add/remove favorites from discover details;
- favorites list screen.

Dependencies:
- favorites repository contracts;
- discover details integration.

Definition of done:
- add/remove/list behavior consistent across app session;
- sync conflicts handled with clear user feedback;
- required tests by matrix.

Out of scope:
- multi-list collections;
- recommendation ranking based on favorites.

Release criteria:
- favorites state remains consistent in staging regression pass.

Rollback criteria:
- disable write operations and keep read-only fallback.

## 5) Sprint 3 (MVP RC)

### Slice `S3-CRT-01` - Create Draft + Publish Happy Path

Scope:
- create draft for event/place;
- load existing draft;
- publish happy path with success/failure states.

Dependencies:
- create API contracts;
- media/upload baseline;
- auth role permissions baseline.

Definition of done:
- draft save/load is stable across app restart;
- publish happy path works on staging;
- mandatory integration tests in place.

Out of scope:
- advanced moderation workflow;
- bulk publish and advanced scheduling.

Release criteria:
- create critical flow passes integration and staging smoke without blocker defects.

Rollback criteria:
- disable publish action via feature flag; retain draft-only mode.

### Slice `S3-NOTIF-01` - Notifications List + Mark Read

Scope:
- notifications list;
- mark-as-read action and visual state update.

Dependencies:
- notifications contracts;
- basic in-app navigation integration.

Definition of done:
- unread/read state consistent after refresh;
- empty/error states handled;
- required tests by matrix.

Out of scope:
- push token lifecycle management depth;
- complex notification preferences.

Release criteria:
- notification read-state behavior is stable in regression pass.

Rollback criteria:
- disable mark-read mutation and keep read-only listing.

### Slice `S3-REL-01` - Hardening + Release Readiness

Scope:
- defect burn-down for P0/P1;
- performance and crash sanity checks;
- release checklists and rollback rehearsal.

Dependencies:
- completion of all P0 slices;
- CI and runbook readiness.

Definition of done:
- no open P0 defects;
- release checklist complete;
- rollback drill documented.

Out of scope:
- post-MVP growth features.

Release criteria:
- go/no-go review approved by product + engineering.

Rollback criteria:
- release halted if any critical flow regression or severe incident remains unresolved.

## 6) Exit Criteria For MVP

- Slices `S1-AUTH-01`, `S1-DISC-01`, `S2-DISC-02`, `S3-CRT-01`, `S3-REL-01` are done.
- Critical integration suite is green in CI.
- Observability and rollback runbooks are operational.
- No open P0 issues.
