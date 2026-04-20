# Rollback Runbook (MVP)

## Purpose

Fast and safe rollback when release causes critical regression.

## Rollback Triggers

- P0 functional regression in core flows (auth/discover/create).
- Crash spike after release.
- Data corruption risk.
- Security/privacy critical issue.

## Rollback Owner Roles

- Incident commander
- Release engineer
- Product approver

## Rollback Procedure

1. Freeze new deploys.
2. Identify last stable release tag.
3. Re-point deployment to last stable tag/build.
4. Validate smoke flows on rolled-back version:
   - sign in / restore session
   - discover feed/details/map
   - create draft / publish
   - notifications list
5. Announce rollback complete in incident channel.

## Git-Level Recovery (if needed)

- Preferred: deploy previous known-good tag.
- Avoid destructive history rewrites.
- For hotfix branch:
  - create new branch from stable tag,
  - apply minimal fix,
  - run gates,
  - release hotfix.

## After Rollback

1. Open incident report (`incident.md` template).
2. Record root cause and remediation tasks.
3. Define preventive check before next release.
