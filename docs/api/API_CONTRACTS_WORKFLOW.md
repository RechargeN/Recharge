# API Contracts Workflow

This document defines how API contracts are changed, generated, and consumed.

## 1) Source Of Truth

- Canonical contracts live in `packages/api_contracts/lib/src/contracts/`.
- DTOs and clients are generated from contracts.
- Generated output is committed only from codegen, never manually edited.

## 2) Change Types

Contract changes are classified as:

- Non-breaking:
  - adding optional fields;
  - adding new endpoints;
  - broadening accepted values safely.
- Breaking:
  - removing/renaming fields;
  - changing required/optional status incompatibly;
  - changing response semantics or endpoint behavior incompatibly.

## 3) Breaking Change Rules

For every breaking change:

1. Add `BREAKING CHANGE` note in PR.
2. Link migration notes for consumers.
3. Assign a consumer-update owner.
4. Do not merge until impacted consumers have migration plan.

## 4) Required Flow

1. Update contract source.
2. Run code generation.
3. Verify no manual generated edits.
4. Update consumer code in app/features.
5. Run tests and CI checks.
6. Merge with explicit change classification.

## 5) Ownership

- Contract owner: API/contracts maintainer.
- Consumer owner: feature owner of impacted module(s).
- Merge requires both perspectives for breaking changes.

## 6) Generated Code Policy

- Files under `generated/` are read-only for manual editing.
- Any manual edit in generated files is a policy violation.
- CI codegen check is required before merge.

## 7) Versioning

- Use semantic versioning for `api_contracts` package:
  - `MAJOR` for breaking changes,
  - `MINOR` for backward-compatible additions,
  - `PATCH` for fixes that do not alter contract behavior.

## 8) Release Notes Requirement

PR must include:

- change type (`non-breaking` / `breaking`);
- affected endpoints/DTOs;
- migration impact;
- consumer owner confirmation.

## 9) Fast Rollback Guidance

- Keep previous compatible contract artifacts available for one rollback window.
- If consumer migration fails in production, revert contract package version and redeploy.
