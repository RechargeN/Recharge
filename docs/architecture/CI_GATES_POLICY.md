# CI Gates Policy

## Required Blocking Checks

The following checks are required before merge:

1. Lint / static analysis
2. Test suite
3. Code generation consistency check
4. Architecture boundary check

Boundary gate note:

- Canonical command is
  `dart tools/scripts/check_boundaries.dart --repo-root . --format text`.
- Windows may use the thin `tools/scripts/check-boundaries.ps1` wrapper.
- Legacy exceptions are permitted only via the exact structured
  `tools/scripts/boundary-exceptions.json` registry.
- Exception budget is 106 and cannot increase without the approved
  RFC/ADR/owner path; stale or expired entries fail CI.
- New violations must fail CI unless approved through RFC+ADR process.
- Missing Dart/runtime/root, config errors and timeouts are inconclusive and
  therefore blocking, never a pass.

## Override Policy (Temporary Only)

Override is allowed only for production-impacting incidents and only when all conditions are met:

- incident/hotfix ticket is linked in PR;
- explicit risk acceptance is documented;
- override has TTL (maximum 24 hours);
- follow-up remediation task is created before merge.

## Override Prohibited Cases

Override is prohibited when:

- security checks fail;
- boundary violations are introduced intentionally;
- generated code is manually edited;
- test failures are unrelated to incident scope.

## Approval Matrix For Override

- One maintainer + one tech lead approval required.
- Product owner approval required if user-facing behavior changes.

## Audit

Every override entry must include:

- ticket link;
- approvers;
- expiry time;
- remediation owner and due date.
