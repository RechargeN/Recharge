# Launch Status

Status legend: `Planned` | `In progress` | `Review` | `Done`  
Last updated: 2026-04-18  
Owner: Recharge team (execution tracking by Codex)

## Stage Tracker

| # | Stage | Status | Owner | Started | Updated | DoD (short) | Links | Risks/Blockers |
|---|-------|--------|-------|---------|---------|-------------|-------|----------------|
| 1 | ADR: Tech Stack Defaults | Done | Recharge team | 2026-04-17 | 2026-04-17 | Accepted ADR for state/DI/router/http/storage/errors/telemetry + deviation rules | docs/adr/0012-tech-stack-defaults.md | - |
| 2 | Repo Process / Merge Governance | Done | Recharge team | 2026-04-17 | 2026-04-17 | CONTRIBUTING + review/merge rules + PR size policy | CONTRIBUTING.md, docs/architecture/REPO_GOVERNANCE.md | - |
| 3 | CI Blocking Gates | Done | Recharge team | 2026-04-17 | 2026-04-17 | lint/tests/codegen/boundary are blocking; override policy with TTL | .github/workflows, docs/architecture/CI_GATES_POLICY.md | - |
| 4 | Import Boundaries Enforcement | Done | Recharge team | 2026-04-17 | 2026-04-17 | Layer/feature dependency matrix + automatic checks local/CI | docs/architecture/IMPORT_BOUNDARIES.md, tools/scripts/check-boundaries.ps1 | - |
| 5 | Env / Flavors / Secrets | Done | Recharge team | 2026-04-17 | 2026-04-17 | env matrix + no-secrets-in-git + rotation + leak runbook | docs/architecture/ENV_FLAVORS_SECRETS.md, docs/runbooks | - |
| 6 | API Contracts Workflow | Done | Recharge team | 2026-04-17 | 2026-04-17 | codegen flow, breaking-change policy, consumer update ownership | docs/api/API_CONTRACTS_WORKFLOW.md, docs/api/CONTRACT_CHANGE_TEMPLATE.md | - |
| 7 | Testing Strategy | Done | Recharge team | 2026-04-17 | 2026-04-17 | change-type -> required tests + critical flows + integration requirements | docs/architecture/TESTING_STRATEGY.md, .github templates | - |
| 8 | Analytics Taxonomy | Done | Recharge team | 2026-04-17 | 2026-04-17 | naming + required params + event owner + deprecate policy | docs/analytics/ANALYTICS_TAXONOMY.md, docs/analytics/EVENT_CATALOG.md | - |
| 9 | UI Baseline / Design System Governance | Done | Recharge team | 2026-04-17 | 2026-04-17 | reusable UI only in design_system; feature UI stays in features | docs/architecture/UI_BASELINE_DESIGN_SYSTEM.md, docs/architecture/DS_COMPONENT_INTAKE.md | - |
| 10 | MVP Plan (2–3 sprints) | Done | Recharge team | 2026-04-17 | 2026-04-17 | scope/dependencies/DoD/out-of-scope/release/rollback per slice | docs/product/MVP_PLAN_3_SPRINTS.md, docs/product/MVP_SLICE_TEMPLATE.md | - |

## Slice Tracker

| Slice ID | Sprint | Status | Updated | DoD Evidence |
|---|---|---|---|---|
| S1-AUTH-01 | Sprint 1 | Done | 2026-04-17 | `flutter test .\test\widget\sign_in_page_test.dart` (pass), `flutter test .\test\unit\auth_controller_test.dart` (pass), `dart analyze test\widget\sign_in_page_test.dart` (no issues) |
| S1-DISC-01 | Sprint 1 | Done | 2026-04-17 | `dart analyze lib test integration_test` (no issues), `flutter test .\test\unit\discover_feed_controller_test.dart` (pass `+3`), `flutter test .\test\widget\discover_feed_section_test.dart` (pass `+1`), `flutter test` (pass `+8`) |
| S1-CORE-01 | Sprint 1 | Done | 2026-04-17 | `dart analyze lib test integration_test` (no issues), `flutter test .\test\unit\discover_feed_controller_test.dart` (pass `+3`), `flutter test .\test\widget\discover_feed_section_test.dart` (pass `+1`), `flutter test` (pass `+8`) |
| S2-DISC-02 | Sprint 2 | Done | 2026-04-18 | `dart analyze lib test integration_test` (no issues), `flutter test .\test\unit\discover_feed_controller_test.dart` (pass `+4`), `flutter test .\test\widget\discover_feed_section_test.dart` (pass `+1`), `flutter test` (pass `+9`) |
| S2-EXP-01 | Sprint 2 | Done | 2026-04-18 | `dart analyze lib\features\explore\application\controllers\explore_controller.dart` (no issues), `dart analyze lib\features\explore\presentation\pages\profile_page.dart` (no issues), `dart analyze lib\features\explore\presentation\pages\settings_page.dart` (no issues), `dart analyze lib\app\router\app_router.dart` (no issues), `dart analyze lib\app\di\service_locator.dart` (no issues), `flutter test .\test\unit\explore_controller_test.dart` (pass `+3`), `flutter test .\test\widget\settings_page_test.dart` (pass `+1`) |
| S2-FAV-01 | Sprint 2 | Done | 2026-04-18 | `dart analyze lib\features\favorites` (no issues), `dart analyze lib\features\discover\presentation\pages\discover_details_page.dart` (no issues), `dart analyze lib\features\discover\presentation\pages\discover_map_page.dart` (no issues), `dart analyze lib\features\auth\presentation\pages\sign_in_page.dart` (no issues), `dart analyze lib\app\router` (no issues), `flutter test .\test\unit\favorites_controller_test.dart` (pass `+3`), `flutter test .\test\widget\favorites_page_test.dart` (pass `+2`) |
| S3-CRT-01 | Sprint 3 | Done | 2026-04-20 | `dart analyze lib test integration_test` (no issues), `flutter test .\test\unit\create_controller_test.dart` (pass `+3`), `flutter test .\test\widget\create_page_test.dart` (pass `+1`), `flutter test` (pass `+22`) |
| S3-NOTIF-01 | Sprint 3 | Planned | 2026-04-17 | - |
| S3-REL-01 | Sprint 3 | Planned | 2026-04-17 | - |

## Update Rules

1. Before implementation of any task, map it to one (or more) stage IDs from the table.
2. While implementing, move status to `In progress`.
3. After PR is open and checks pass, move to `Review`.
4. Move to `Done` only when DoD is satisfied and required gates are green.
5. Any architecture deviation must follow `docs/architecture/CHANGE_POLICY.md`.

## Execution Log

Use this section as a running log (newest first).

- 2026-04-19: Slice `S3-CRT-01` moved to In progress. Create spec fixed (`S3_CRT_01_CREATE_SPEC.md`) for `event + place`, required `coverImage`, and publish happy path to `pending_review`.
- 2026-04-20: Slice `S3-CRT-01` fixed as Done checkpoint. Implemented create draft + publish happy path for `event/place`, required `coverImage` validation, success route, and create controller/unit+widget coverage. Verification passed (analyze clean, targeted tests green, full suite `+22`).
- 2026-04-18: Slice `S2-EXP-01` fixed as Done checkpoint. Implemented local profile/settings module (`explore`) with editable profile fields, settings controls, protected routes (`/profile`, `/settings`), and unit/widget tests. Verification passed on touched analyze scopes and tests.
- 2026-04-18: Slice `S2-EXP-01` moved to In progress. Baseline spec fixed (`S2_EXP_01_PROFILE_SETTINGS_SPEC.md`) with agreed profile/settings scope, auth-gate behavior, and storage model.
- 2026-04-18: Slice `S2-FAV-01` fixed as Done checkpoint. Implemented favorites module (domain/data/application/presentation), discover details/map favorite actions (with auth-gate + post-login auto-apply), protected `/favorites` route, and added unit/widget tests. Verification passed (analyze clean on touched areas, favorites tests green).
- 2026-04-18: Slice `S2-DISC-02` fixed as Done checkpoint. Verification passed: analyze clean, unit map/discover test (`+4`), widget discover test (`+1`), full test suite (`+9`).
- 2026-04-18: Slice `S2-DISC-02` moved to In progress. Map spec fixed (`S2_DISC_02_MAP_SPEC.md`) and implementation started with unified `DiscoverQuery`, map area draft/apply flow, and list-sync.
- 2026-04-17: Slice `S1-CORE-01` fixed as Done checkpoint. Verification passed: analyze clean and discover/core smoke tests green.
- 2026-04-17: Slice `S1-DISC-01` fixed as Done checkpoint. Verification passed: analyze clean, unit discover test (`+3`), widget discover test (`+1`), full test suite (`+8`).
- 2026-04-17: Slice `S1-AUTH-01` fixed as Done checkpoint. Verification passed: widget auth test (`+1`), unit auth controller test (`+3`), widget test analyzer clean.
- 2026-04-17: Stage tracker created and frozen for execution control.
- 2026-04-17: Stage #1 marked Done via ADR 0012 (`docs/adr/0012-tech-stack-defaults.md`).
- 2026-04-17: Stage #2 marked Done via `CONTRIBUTING.md` and `docs/architecture/REPO_GOVERNANCE.md`.
- 2026-04-17: Stage #3 marked Done via `.github/workflows/*` and `docs/architecture/CI_GATES_POLICY.md`.
- 2026-04-17: Stage #4 marked Done via `docs/architecture/IMPORT_BOUNDARIES.md` and `tools/scripts/check-boundaries.ps1`.
- 2026-04-17: Stage #5 marked Done via env/secrets policy and runbooks (`ENV_FLAVORS_SECRETS.md`, `docs/runbooks/*`).
- 2026-04-17: Stage #6 marked Done via API contracts workflow docs and change template.
- 2026-04-17: Stage #7 marked Done via testing strategy matrix, critical flows, and template updates.
- 2026-04-17: Stage #8 marked Done via analytics taxonomy and event catalog with ownership/lifecycle policy.
- 2026-04-17: Stage #9 marked Done via UI baseline governance and DS component intake process.
- 2026-04-17: Stage #10 marked Done via 3-sprint MVP plan and slice template.
- 2026-04-17: Physical structure synced to monorepo (`apps/mobile`, `packages/design_system`, `packages/api_contracts`) with Melos config.
- 2026-04-17: Branch protection automation prepared (`tools/scripts/setup-branch-protection.ps1` + runbook), pending git remote initialization.
- 2026-04-17: Domain/product policy decisions (21 points) fixed in ADR 0013 (`docs/adr/0013-domain-policy-baseline.md`).
- 2026-04-17: S1 auth confirmations fixed (`pending_review`, password min 8, offline logout success, post-login target behavior, 5 unique reports/24h, `auth_sign_in_*`) in ADR/product/analytics docs.
