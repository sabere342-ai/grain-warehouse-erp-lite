$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$exePath = Join-Path $releaseDir 'grain_warehouse_erp_lite.exe'
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'

Write-Host '=== Phase 98 — Deterministic Windows Release Build ===' -ForegroundColor Cyan
Write-Host ''

# --- Step 1: Read version from pubspec.yaml ---
if (-not (Test-Path -LiteralPath $pubspecPath)) {
  throw "pubspec.yaml not found at $pubspecPath"
}
$pubspecContent = Get-Content -LiteralPath $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspecContent, '(?m)^version:\s*(\S+)')
if (-not $versionMatch.Success) {
  throw 'Could not parse version from pubspec.yaml'
}
$version = $versionMatch.Groups[1].Value
Write-Host "Version: $version" -ForegroundColor Green

$semver = $version.Split('+')[0]
$buildNumber = if ($version.Contains('+')) { $version.Split('+')[1] } else { '0' }
Write-Host "Semver: $semver  Build: $buildNumber" -ForegroundColor Green
Write-Host ''

# --- Step 2: Read product name from pubspec ---
$nameMatch = [regex]::Match($pubspecContent, '(?m)^name:\s*(\S+)')
if (-not $nameMatch.Success) {
  throw 'Could not parse name from pubspec.yaml'
}
$packageName = $nameMatch.Groups[1].Value
Write-Host "Package name: $packageName" -ForegroundColor Green
Write-Host ''

# --- Step 3: Git metadata ---
$commitHash = 'unknown'
$gitTag = 'none'
try {
  $commitHash = (git -C $projectRoot rev-parse HEAD 2>$null).Trim()
  Write-Host "Git commit: $commitHash" -ForegroundColor Green
} catch {
  Write-Host 'WARNING: Could not read git commit hash' -ForegroundColor Yellow
}
try {
  $gitTag = (git -C $projectRoot describe --tags --exact-match 2>$null).Trim()
  Write-Host "Git tag: $gitTag" -ForegroundColor Green
} catch {
  $gitTag = 'none'
  Write-Host 'Git tag: none (not at a tag)' -ForegroundColor Yellow
}
Write-Host ''

# --- Step 4: Clean stale build output (selective) ---
$buildDir = Join-Path $projectRoot 'build\windows'
if (Test-Path -LiteralPath $releaseDir) {
  Write-Host 'Cleaning stale release output...' -ForegroundColor Yellow
  Remove-Item -LiteralPath $releaseDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Step 5: Run flutter build ---
Write-Host 'Running: flutter build windows --release' -ForegroundColor Cyan
$buildStart = Get-Date
flutter.bat build windows --release 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
  throw "flutter build windows --release failed with exit code $LASTEXITCODE"
}
$buildDuration = (Get-Date) - $buildStart
Write-Host "Build completed in $($buildDuration.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Green
Write-Host ''

# --- Step 6: Verify executable exists ---
if (-not (Test-Path -LiteralPath $exePath)) {
  throw "Release executable not found at: $exePath"
}
$exeSize = (Get-Item -LiteralPath $exePath).Length
Write-Host "Executable: $exePath" -ForegroundColor Green
Write-Host "Executable size: $([math]::Round($exeSize / 1MB, 2)) MB ($exeSize bytes)" -ForegroundColor Green
Write-Host ''

# --- Step 7: Verify required DLLs ---
$requiredDlls = @(
  'flutter_windows.dll'
)
$missingFiles = @()
foreach ($dll in $requiredDlls) {
  $dllPath = Join-Path $releaseDir $dll
  if (-not (Test-Path -LiteralPath $dllPath)) {
    $missingFiles += $dll
  }
}
if ($missingFiles.Count -gt 0) {
  throw "Missing required DLLs: $($missingFiles -join ', ')"
}
Write-Host 'Required DLLs verified.' -ForegroundColor Green

# --- Step 8: Verify flutter_assets directory ---
$flutterAssetsDir = Join-Path $releaseDir 'flutter_assets'
if (-not (Test-Path -LiteralPath $flutterAssetsDir -PathType Container)) {
  throw "flutter_assets directory not found at: $flutterAssetsDir"
}
Write-Host "flutter_assets directory: exists" -ForegroundColor Green

# --- Step 9: Verify data directory with icudtl.dat ---
$dataDir = Join-Path $releaseDir 'data'
$icuDatPath = Join-Path $dataDir 'icudtl.dat'
if (-not (Test-Path -LiteralPath $dataDir -PathType Container)) {
  throw "data directory not found at: $dataDir"
}
if (-not (Test-Path -LiteralPath $icuDatPath)) {
  throw "icudtl.dat not found at: $icuDatPath"
}
Write-Host "data/icudtl.dat: exists" -ForegroundColor Green

# --- Step 10: Verify app.so (AOT) ---
$aotPath = Join-Path $dataDir 'app.so'
if (-not (Test-Path -LiteralPath $aotPath)) {
  Write-Host 'WARNING: app.so (AOT library) not found in data/' -ForegroundColor Yellow
} else {
  Write-Host "data/app.so: exists" -ForegroundColor Green
}

# --- Step 11: List all files in release directory ---
Write-Host ''
Write-Host 'Release directory contents:' -ForegroundColor Cyan
$allFiles = Get-ChildItem -LiteralPath $releaseDir -Recurse -File
$totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
Write-Host "  Total files: $($allFiles.Count)" -ForegroundColor Green
Write-Host "  Total size: $([math]::Round($totalSize / 1MB, 2)) MB ($totalSize bytes)" -ForegroundColor Green

# --- Step 12: Verify executable metadata ---
$versionInfo = (Get-Item -LiteralPath $exePath).VersionInfo
Write-Host ''
Write-Host 'Executable version info:' -ForegroundColor Cyan
Write-Host "  CompanyName:     $($versionInfo.CompanyName)"
Write-Host "  FileDescription: $($versionInfo.FileDescription)"
Write-Host "  FileVersion:     $($versionInfo.FileVersion)"
Write-Host "  ProductName:     $($versionInfo.ProductName)"
Write-Host "  ProductVersion:  $($versionInfo.ProductVersion)"

Write-Host ''
Write-Host '=== Release build verified successfully ===' -ForegroundColor Green
Write-Host "Executable: $exePath"
