param(
  [Parameter(Mandatory = $true)]
  [string]$Repository, # owner/repo
  [string]$Branch = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI (gh) is required. Install gh and authenticate first."
}

# Ensure workflow checks are required before merge.
$body = @{
  required_status_checks = @{
    strict   = $true
    contexts = @("lint", "boundaries", "tests", "codegen")
  }
  enforce_admins = $true
  required_pull_request_reviews = @{
    dismiss_stale_reviews           = $true
    require_code_owner_reviews      = $false
    required_approving_review_count = 1
  }
  restrictions = $null
  allow_force_pushes = $false
  allow_deletions = $false
  block_creations = $false
  required_linear_history = $false
  required_conversation_resolution = $true
  lock_branch = $false
  allow_fork_syncing = $false
}

$json = $body | ConvertTo-Json -Depth 10
$tmp = [System.IO.Path]::GetTempFileName()
Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8
try {
  gh api `
   --method PUT `
   -H "Accept: application/vnd.github+json" `
   "/repos/$Repository/branches/$Branch/protection" `
   --input $tmp
} finally {
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}

Write-Host "Branch protection configured for $Repository:$Branch"
