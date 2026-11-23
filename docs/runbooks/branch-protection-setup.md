# Branch protection

Status: owner-approved 2026-11-23 (O1 blocker B-02, gap plan round 1, item 1.2).

## What is protected and how

One repository ruleset, `protect-main-and-integration`, applies to `main` and
`codex/recharge-integration`:

| Rule | Value | Why |
|---|---|---|
| Changes only through a pull request | yes | no direct push to either branch |
| Approvals | 1 | the owner reviews; `.github/CODEOWNERS` names the owner for every path |
| Stale approvals dismissed on new commits | yes | an approval covers the reviewed SHA only |
| Required checks | `lint`, `boundaries`, `tests`, `codegen`, `Backend R0 gate`, `Backend R1 gate`, `Backend IaC gate` | mobile and backend both gate a merge |
| Branch must be up to date | no | avoids forced rebases; CI runs on the PR merge commit anyway |
| Force push | blocked | history of protected branches is never rewritten |
| Deletion | blocked | both branches are permanent |
| Bypass | Admin role, PR merges only | the owner is the only reviewer; admins still cannot push directly |

Honest limit: until a second reviewer exists (decision D-01), the bypass lets
the owner merge their own PR without an independent review, and technically
also with a red check. The working rule stays: merge only after green CI and the
owner's "yes".

## Backend checks and path filters

The backend workflows (`backend-r0.yml`, `backend-r1.yml`,
`backend-iac-validate.yml`) used to start only when a PR touched backend paths.
A required check from a workflow that never starts stays "Expected" and blocks
the PR forever. Now each workflow always starts and has three jobs:

1. `changes` — runs `.github/scripts/pr-touches.sh` with the former path list
   (and its tests `pr-touches.test.sh`); outputs whether the PR touches them.
2. the heavy job (`verify` / `validate`) — runs only when it does.
3. `gate` (`Backend … gate`) — the required check: success when the heavy job
   passed or was skipped, failure when it failed, was cancelled or timed out.

When a path list changes, edit the arguments of `pr-touches.sh` in that
workflow; the gate name must stay the same, or update the ruleset.

## Apply or update

Run from a checkout that contains this runbook, as the repository admin:

```powershell
powershell -ExecutionPolicy Bypass -File tools/scripts/setup-branch-protection.ps1
powershell -ExecutionPolicy Bypass -File tools/scripts/setup-branch-protection.ps1 -Apply
```

The first command is a dry run and prints the ruleset. The second creates it, or
updates the existing ruleset with the same name.

Apply only after the workflow change above is merged into the integration
branch: older PR branches without the gate jobs would otherwise wait for checks
they cannot produce (merge the integration branch into them first).

## Verify

- GitHub → Settings → Rules → Rulesets: `protect-main-and-integration`, Active.
- A docs-only PR shows the three `Backend … gate` checks green with the heavy
  jobs skipped.
- `git push origin HEAD:main` from any branch is rejected.

## Emergency

Disabling protection is a security setting change: only with the owner's
explicit "yes", recorded with the reason. Set the ruleset's enforcement to
`disabled` (not deleted), do the emergency change through a PR anyway when
possible, then set it back to `active`.

## Related repository settings (owner decisions)

- Dependabot alerts and security updates; `.github/dependabot.yml` keeps
  routine version-update PRs off. Security-update PRs open against `main`;
  change their base to `codex/recharge-integration` before review.
- Private vulnerability reporting.
- Collaborator roles: a collaborator with `write` can still open PRs and push
  feature branches; the ruleset keeps them out of both protected branches.
