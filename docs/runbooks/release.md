# Release Runbook (MVP)

## Purpose

Standard checklist to publish a stable MVP build with rollback readiness.

## Pre-Release Inputs

- Target branch: `main`
- Release owner assigned
- Go/No-Go meeting scheduled
- Release notes draft prepared

## Blocking Gates (must be green)

From repo root:

```powershell
powershell -ExecutionPolicy Bypass -File tools/scripts/check-boundaries.ps1
```

From `apps/mobile`:

```powershell
flutter pub get
dart analyze lib test integration_test
flutter test
```

## Release Checklist

1. Confirm no open P0 defects.
2. Confirm all MVP P0 slices are `Done` in `docs/architecture/LAUNCH_STATUS.md`.
3. Confirm runbooks are up to date:
   - `release.md`
   - `rollback.md`
   - `incident.md`
4. Confirm CI checks are green on latest commit.
5. Tag release commit:
   - `vX.Y.Z-mvp`
6. Publish release notes.

## Go / No-Go Decision

Go only if all are true:

- Gates are green.
- No unresolved critical incident.
- Rollback owner is available.
- Product + Engineering approve release.

## Post-Release (first 24h)

1. Monitor crash/error trends and user-reported blockers.
2. If severe regression appears:
   - execute `rollback.md`,
   - open incident using `incident.md`.
