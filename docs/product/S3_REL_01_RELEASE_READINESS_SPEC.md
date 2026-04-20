# S3-REL-01 Hardening + Release Readiness Spec

Status: Done  
Date: 2026-04-20

## Scope

- Final release runbooks for MVP:
  - release checklist,
  - rollback procedure,
  - incident response.
- Stabilize architecture gate execution for current MVP baseline.
- Final go/no-go checklist and evidence capture rules.

## Implemented In This Slice

1. Runbooks:
   - `docs/runbooks/release.md`
   - `docs/runbooks/rollback.md`
   - `docs/runbooks/incident.md`
2. Boundary gate hardening:
   - `tools/scripts/check-boundaries.ps1` supports controlled allowlist.
   - `tools/scripts/boundaries-allowlist.txt` contains only legacy baseline violations.
3. Architecture policy update:
   - `docs/architecture/IMPORT_BOUNDARIES.md` updated with allowlist governance.

## Definition Of Done (Target)

- Runbooks exist and are actionable.
- Boundary check passes locally and remains blocking for new violations.
- Full analyzer/tests are green on current branch.
- Slice status is updated to `Done` in launch tracker and MVP plan.

## Out Of Scope

- Full refactor of all legacy cross-feature imports.
- New product features.
- Production monitoring infrastructure rollout.

## Verification Evidence (2026-04-20)

- `powershell -ExecutionPolicy Bypass -File tools/scripts/check-boundaries.ps1` -> passed (`suppressed by allowlist: 25`).
- `dart analyze lib test integration_test` -> no issues.
- `flutter test` -> pass (`+25`).
