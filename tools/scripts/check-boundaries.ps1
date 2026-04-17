Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LibRoot {
  if (Test-Path "apps/mobile/lib") { return "apps/mobile/lib" }
  if (Test-Path "lib") { return "lib" }
  return $null
}

$libRoot = Get-LibRoot
if (-not $libRoot) {
  Write-Host "No lib root found. Skipping boundaries check."
  exit 0
}

$featureRoot = Join-Path $libRoot "features"
if (-not (Test-Path $featureRoot)) {
  Write-Host "No features directory found. Skipping boundaries check."
  exit 0
}

$violations = New-Object System.Collections.Generic.List[string]
$featureDirs = Get-ChildItem -Path $featureRoot -Directory
$allowedLayers = @("domain", "data", "application", "presentation")

function Normalize-PathForMatch([string]$value) {
  return $value.Replace('\', '/')
}

function Get-FeatureAndLayer([string]$normalizedPath) {
  if ($normalizedPath -notmatch "/features/([a-zA-Z0-9_]+)/") { return $null }
  $featureName = $Matches[1]
  $layerName = $null

  foreach ($layer in $allowedLayers) {
    if ($normalizedPath -match "/features/$featureName/$layer/") {
      $layerName = $layer
      break
    }
  }

  return @{
    Feature = $featureName
    Layer   = $layerName
  }
}

function Resolve-ImportTarget([string]$importPath, [string]$currentDir) {
  if ($importPath.StartsWith("dart:")) { return $null }

  if ($importPath.StartsWith("package:")) {
    return Get-FeatureAndLayer -normalizedPath (Normalize-PathForMatch $importPath)
  }

  if ($importPath.StartsWith(".")) {
    $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $currentDir $importPath))
    return Get-FeatureAndLayer -normalizedPath (Normalize-PathForMatch $resolvedPath)
  }

  return $null
}

function Is-ForbiddenLayerImport([string]$fromLayer, [string]$toLayer) {
  if (-not $fromLayer -or -not $toLayer) { return $false }

  switch ($fromLayer) {
    "domain" { return $toLayer -ne "domain" }
    "application" { return @("data", "presentation") -contains $toLayer }
    "data" { return @("application", "presentation") -contains $toLayer }
    "presentation" { return $toLayer -eq "data" }
    default { return $false }
  }
}

foreach ($featureDir in $featureDirs) {
  $dartFiles = Get-ChildItem -Path $featureDir.FullName -Recurse -Filter *.dart -File

  foreach ($file in $dartFiles) {
    $currentMeta = Get-FeatureAndLayer -normalizedPath (Normalize-PathForMatch $file.FullName)
    $currentFeature = $currentMeta.Feature
    $fromLayer = $currentMeta.Layer
    $lines = Get-Content $file.FullName

    foreach ($line in $lines) {
      if ($line -match "^\s*(import|export)\s+['""]([^'""]+)['""]") {
        $importPath = $Matches[2]
        $targetMeta = Resolve-ImportTarget -importPath $importPath -currentDir $file.DirectoryName
        if (-not $targetMeta) { continue }

        $targetFeature = $targetMeta.Feature
        $toLayer = $targetMeta.Layer

        if ($targetFeature -and $currentFeature -and $targetFeature -ne $currentFeature) {
          $message = "Cross-feature import: $($file.FullName) -> $importPath"
          if (-not $violations.Contains($message)) { $violations.Add($message) | Out-Null }
          continue
        }

        if (Is-ForbiddenLayerImport -fromLayer $fromLayer -toLayer $toLayer) {
          $message = "Layer direction violation: $($file.FullName) [$fromLayer] -> $importPath [$toLayer]"
          if (-not $violations.Contains($message)) { $violations.Add($message) | Out-Null }
        }
      }
    }
  }
}

if ($violations.Count -gt 0) {
  Write-Host "Boundary violations found:"
  $violations | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host "Boundary checks passed."
