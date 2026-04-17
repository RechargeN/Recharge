# Branch Protection Setup

Use this runbook after repository is initialized and pushed to GitHub.

## Preconditions

- local project is a git repository;
- GitHub remote exists;
- GitHub CLI (`gh`) is installed and authenticated;
- user has admin permission for the target repository.

## Steps

1. Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/scripts/setup-branch-protection.ps1 -Repository "<owner>/<repo>" -Branch "main"
```

2. Verify in GitHub branch protection settings:

- required status checks: `lint`, `boundaries`, `tests`, `codegen`;
- required PR reviews are enabled;
- direct push to protected branch is blocked.

## Notes

- If check names differ in GitHub UI, update contexts in `tools/scripts/setup-branch-protection.ps1`.
- Re-run script after renaming workflows/jobs.
