[CmdletBinding()]
param(
    [switch]$ResetAppData,
    [string]$PackageId = 'com.recharge.app.recharge',
    [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'

function Invoke-Adb {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $adbArguments = @()
    if ($DeviceId.Trim().Length -gt 0) {
        $adbArguments += @('-s', $DeviceId)
    }
    $adbArguments += $Arguments
    & adb @adbArguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed with exit code $LASTEXITCODE."
    }
}

if ($ResetAppData) {
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        throw 'adb is required for -ResetAppData.'
    }
    Write-Host "Clearing local demo data for $PackageId..."
    Invoke-Adb -Arguments @('shell', 'pm', 'clear', $PackageId)
    Write-Host 'Local drafts, publication index and preferences were removed.'
}

Write-Host ''
Write-Host 'RECHARGE Route investor replay'
Write-Host '1. Sign in as the authorized demo creator.'
Write-Host '2. Open Create, choose Route and build a track inside demo coverage.'
Write-Host '3. Complete Route details and publish directly with the trusted profile.'
Write-Host '4. Leave Create. Confirm that the default feed does not preload the Route.'
Write-Host '5. Open Search, enter the Route title or apply its category filter.'
Write-Host '6. Open the result. Confirm distance, duration, profile and attribution.'
Write-Host '7. Open Map. Select the Route and confirm the saved track is drawn.'
Write-Host '8. Restart the app and repeat Search; version and geometry must be unchanged.'
Write-Host '9. Repeat Details/Map viewing offline; no routing, elevation or Places call is allowed.'
Write-Host ''
Write-Host 'Optional destructive reset of this app only:'
Write-Host '  .\tools\scripts\route-investor-demo.ps1 -ResetAppData'
