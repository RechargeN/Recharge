Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$checkerPath = Join-Path $PSScriptRoot "check_boundaries.dart"
$dartCommand = Get-Command dart -ErrorAction SilentlyContinue

if (-not $dartCommand) {
  Write-Error "Dart runtime is required for the boundary gate."
  exit 2
}

if (-not (Test-Path -LiteralPath $checkerPath)) {
  Write-Error "Canonical boundary checker is missing: $checkerPath"
  exit 2
}

$dartExecutable = $dartCommand.Source
if ([System.IO.Path]::GetExtension($dartExecutable) -eq ".bat") {
  $flutterBin = Split-Path -Parent $dartExecutable
  $flutterDart = Join-Path $flutterBin "cache/dart-sdk/bin/dart.exe"
  if (Test-Path -LiteralPath $flutterDart) {
    $dartExecutable = $flutterDart
  }
}

& $dartExecutable $checkerPath --repo-root $repoRoot --format text
exit [int]$LASTEXITCODE
