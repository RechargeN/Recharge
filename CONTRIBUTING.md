# Contributing To Recharge

This document defines the default development process and merge governance for the repository.

## 1) Branching Strategy

- Protected branch: `main`.
- Feature work: `feature/<short-scope>` (example: `feature/auth-sign-in`).
- Fixes: `fix/<short-scope>`.
- Chores/infra/docs: `chore/<short-scope>`, `docs/<short-scope>`.
- Keep branches short-lived; rebase on `main` before requesting review.

## 2) Commit Conventions

- Prefer small, atomic commits.
- Recommended prefix format: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- Do not mix refactor and behavior changes in one commit unless required.

## 3) Pull Request Size Rule

- Target PR size: up to 400 changed lines (excluding generated files, lockfiles, and snapshots).
- 401-800 lines: allowed only with explicit split rationale in PR description.
- >800 lines: should be split into smaller PRs unless incident/hotfix.

## 4) Mandatory Review Rules

PR cannot be merged without review in these cases:

- changes in `core`, `app/di`, routing, security, telemetry, or CI workflows;
- architectural changes or dependency-boundary changes;
- schema/API contract changes;
- deletion or weakening of tests.

Minimum approvals:

- Standard feature PR: at least 1 approval.
- Critical area PR (core/security/CI/architecture): at least 2 approvals.

Self-approval is not valid.

## 5) Merge Rights And Strategy

- Merge is performed by maintainers only.
- Default merge strategy: `Squash and merge`.
- `Rebase and merge` is allowed for clean, intentionally structured commit history.
- Direct merge to `main` is forbidden (except emergency policy, documented in PR).

## 6) PR Requirements

Before requesting merge, PR must include:

- linked task/issue;
- completed architecture/test checklist;
- green required CI checks;
- migration/rollback note when relevant.

## 7) Temporary Exceptions

- Any temporary process exception must reference a ticket and include an expiry date.
- Expired exceptions are treated as violations and must be removed immediately.
