param(
  [Parameter(Mandatory=$true)]
  [string]$PackagePath
)

$ErrorActionPreference = 'Stop'

Write-Host '=== Phase 98 — Checksum Verification ===' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path -LiteralPath $PackagePath -PathType Container)) {
  Write-Host "FAIL: Package path does not exist: $PackagePath" -ForegroundColor Red
  exit 1
}

$packageRoot = (Resolve-Path -LiteralPath $PackagePath).Path
$checksumFile = Join-Path $packageRoot 'checksums.sha256'

if (-not (Test-Path -LiteralPath $checksumFile)) {
  Write-Host 'FAIL: checksums.sha256 not found in package.' -ForegroundColor Red
  exit 1
}

$checksumEntries = Get-Content -LiteralPath $checksumFile | Where-Object { $_.Trim() -ne '' }
$passCount = 0
$failCount = 0
$missingCount = 0
$failures = New-Object System.Collections.Generic.List[string]

Write-Host "Verifying $($checksumEntries.Count) checksums..." -ForegroundColor Cyan

foreach ($entry in $checksumEntries) {
  $parts = ($entry -split '\s{2,}')
  if ($parts.Count -lt 2) {
    $failures.Add("Invalid checksum line: $entry")
    $failCount++
    continue
  }

  $expectedHash = $parts[0].Trim()
  $relativePath = $parts[1].Trim()
  $filePath = Join-Path $packageRoot $relativePath.Replace('/', '\')

  if (-not (Test-Path -LiteralPath $filePath)) {
    $failures.Add("File missing: $relativePath")
    $missingCount++
    continue
  }

  $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash

  if ($actualHash -eq $expectedHash) {
    $passCount++
  } else {
    $failures.Add("Checksum mismatch: $relativePath (expected: $expectedHash, actual: $actualHash)")
    $failCount++
  }
}

Write-Host ''
if ($failCount -gt 0 -or $missingCount -gt 0) {
  Write-Host "FAIL: Checksum verification failed." -ForegroundColor Red
  Write-Host "  Passed: $passCount"
  Write-Host "  Failed: $failCount"
  Write-Host "  Missing: $missingCount"
  foreach ($failure in $failures) {
    Write-Host "  FAIL: $failure" -ForegroundColor Red
  }
  exit 1
}

Write-Host "PASS: All $passCount checksums verified successfully." -ForegroundColor Green
