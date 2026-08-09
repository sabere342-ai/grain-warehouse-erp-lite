[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ReleaseRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$verifier = Join-Path $projectRoot 'scripts\phase-107d\Verify-GovernedWindowsPackage.ps1'
$ReleaseRoot = (Resolve-Path -LiteralPath $ReleaseRoot).Path
$manifest = Get-Content -LiteralPath (Join-Path $ReleaseRoot 'release-manifest.json') -Raw | ConvertFrom-Json
$firstRelativePath = [string]$manifest.files[0].path

function Invoke-ExpectedFailure([string]$Name, [scriptblock]$Tamper) {
  $caseRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("phase107d-" + [Guid]::NewGuid().ToString('N'))
  try {
    Copy-Item -LiteralPath $ReleaseRoot -Destination $caseRoot -Recurse -Force
    & $Tamper $caseRoot
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verifier -ReleaseRoot $caseRoot *> $null
    if ($LASTEXITCODE -eq 0) { throw "$Name unexpectedly passed verification." }
    Write-Host "PASS: $Name was rejected." -ForegroundColor Green
  } finally {
    if (Test-Path -LiteralPath $caseRoot) { Remove-Item -LiteralPath $caseRoot -Recurse -Force }
  }
}

Invoke-ExpectedFailure 'Tamper A (payload byte changed)' {
  param($root)
  $target = Join-Path (Join-Path $root 'payload') $firstRelativePath.Replace('/', '\')
  $bytes = [System.IO.File]::ReadAllBytes($target)
  if ($bytes.Length -eq 0) { throw 'Cannot tamper with an empty payload file.' }
  $bytes[0] = $bytes[0] -bxor 1
  [System.IO.File]::WriteAllBytes($target, $bytes)
}

Invoke-ExpectedFailure 'Tamper B (manifest hash changed)' {
  param($root)
  $path = Join-Path $root 'release-manifest.json'
  $text = Get-Content -LiteralPath $path -Raw
  $text = [regex]::Replace($text, '"sha256"\s*:\s*"[0-9a-f]{64}"', '"sha256": "0000000000000000000000000000000000000000000000000000000000000000"', 1)
  [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

Invoke-ExpectedFailure 'Tamper C (payload file removed)' {
  param($root)
  $target = Join-Path (Join-Path $root 'payload') $firstRelativePath.Replace('/', '\')
  Remove-Item -LiteralPath $target -Force
}

Write-Host 'PASS: all Phase 107D negative controls behaved as required.' -ForegroundColor Green
