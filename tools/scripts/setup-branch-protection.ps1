param(
  [string]$Repository = "RechargeN/Recharge", # owner/repo
  [string]$RulesetName = "protect-main-and-integration",
  # Without -Apply the script only prints the ruleset it would send.
  [switch]$Apply
)

# Branch rules for `main` and `codex/recharge-integration` (O1 B-02, owner
# approval 2026-11-23). See docs/runbooks/branch-protection-setup.md.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI (gh) is required. Install gh and authenticate first."
}

# Check names exactly as GitHub reports them. The three backend gates always
# run (the heavy jobs inside them are skipped when a PR does not touch backend
# paths), so requiring them never leaves a PR waiting.
$requiredChecks = @(
  "lint",
  "boundaries",
  "tests",
  "codegen",
  "Backend R0 gate",
  "Backend R1 gate",
  "Backend IaC gate"
)

$ruleset = [ordered]@{
  name        = $RulesetName
  target      = "branch"
  enforcement = "active"
  conditions  = @{
    ref_name = @{
      include = @("refs/heads/main", "refs/heads/codex/recharge-integration")
      exclude = @()
    }
  }
  # Repository role 5 = Admin. "pull_request" mode: admins may merge a PR
  # without a second approval (there is no second reviewer yet), but cannot
  # push to the protected branches directly.
  bypass_actors = @(
    @{ actor_id = 5; actor_type = "RepositoryRole"; bypass_mode = "pull_request" }
  )
  rules = @(
    @{ type = "deletion" },
    @{ type = "non_fast_forward" },
    @{
      type       = "pull_request"
      parameters = @{
        required_approving_review_count   = 1
        dismiss_stale_reviews_on_push     = $true
        require_code_owner_review         = $false
        require_last_push_approval        = $false
        required_review_thread_resolution = $false
      }
    },
    @{
      type       = "required_status_checks"
      parameters = @{
        strict_required_status_checks_policy = $false
        required_status_checks               = @($requiredChecks | ForEach-Object { @{ context = $_ } })
      }
    }
  )
}

$json = $ruleset | ConvertTo-Json -Depth 10

if (-not $Apply) {
  Write-Host "Dry run. Ruleset that -Apply would send to $Repository :"
  Write-Host $json
  return
}

$existing = gh api "/repos/$Repository/rulesets" --jq ".[] | select(.name == `"$RulesetName`") | .id"
$tmp = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
try {
  if ($existing) {
    gh api --method PUT -H "Accept: application/vnd.github+json" "/repos/$Repository/rulesets/$existing" --input $tmp | Out-Null
    Write-Host "Ruleset '$RulesetName' (id $existing) updated on $Repository"
  } else {
    gh api --method POST -H "Accept: application/vnd.github+json" "/repos/$Repository/rulesets" --input $tmp | Out-Null
    Write-Host "Ruleset '$RulesetName' created on $Repository"
  }
} finally {
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}
