[CmdletBinding()]
param(
  [string]$SourceCommit = 'f521a97946d73829fef19f4f0d30a6d07b9f8051',
  [string]$IsccPath = '',
  [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$installerSource = Join-Path $projectRoot 'installer\phase-107d\GrainWarehouseERP.iss'
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-RelativeSlashPath([string]$Root, [string]$Path) {
  return $Path.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
}

function Resolve-Iscc([string]$RequestedPath) {
  if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
    if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
      throw "ISCC.exe not found at requested path: $RequestedPath"
    }
    return (Resolve-Path -LiteralPath $RequestedPath).Path
  }

  $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($null -ne $command) { return $command.Source }

  $candidates = @(
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe'
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
  }
  throw 'ISCC.exe was not found. Install Inno Setup 6 or pass -IsccPath.'
}

$status = @(& git -C $projectRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Unable to read Git status.' }
if ($status.Count -ne 0) {
  throw "Packaging requires a clean committed state. Dirty entries: $($status -join '; ')"
}

$packagingToolCommit = (& git -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to read HEAD.' }
& git -C $projectRoot merge-base --is-ancestor $SourceCommit $packagingToolCommit
if ($LASTEXITCODE -ne 0) { throw "$SourceCommit is not an ancestor of HEAD." }

$changedPaths = @(& git -C $projectRoot diff --name-only "$SourceCommit..$packagingToolCommit")
$allowedPrefixes = @('installer/', 'scripts/', 'docs/phase-107d/')
$allowedLineageGuards = @(
  'test/phase106aj_migrate_drift_purchase_product_validation_reads_test.dart',
  'test/phase106ak_reaudit_freeze_next_product_read_migration_target_test.dart',
  'test/phase106al_negative_balance_approval_product_fingerprint_read_migration_test.dart',
  'test/phase106am_profitability_activation_product_read_migration_test.dart'
)
foreach ($changedPath in $changedPaths) {
  $normalizedPath = $changedPath.Replace('\', '/')
  $allowed = $false
  foreach ($prefix in $allowedPrefixes) {
    if ($normalizedPath.StartsWith($prefix, [StringComparison]::Ordinal)) {
      $allowed = $true
      break
    }
  }
  if ($allowedLineageGuards -ccontains $normalizedPath) { $allowed = $true }
  if (-not $allowed) { throw "Out-of-scope path differs from source baseline: $changedPath" }
}

if (-not (Test-Path -LiteralPath $releaseDir -PathType Container)) {
  throw "Windows release output not found: $releaseDir"
}
$requiredReleaseFiles = @(
  'grain_warehouse_erp_lite.exe',
  'flutter_windows.dll',
  'data\icudtl.dat',
  'data\flutter_assets'
)
foreach ($required in $requiredReleaseFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $releaseDir $required))) {
    throw "Required Windows runtime payload is missing: $required"
  }
}

$pubspec = Get-Content -LiteralPath $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*(\S+)')
if (-not $versionMatch.Success) { throw 'Unable to read version from pubspec.yaml.' }
$fullVersion = $versionMatch.Groups[1].Value
$version = $fullVersion.Split('+')[0]
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Unsupported installer version: $version" }

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path $projectRoot 'delivery\phase-107d'
}
[System.IO.Directory]::CreateDirectory($OutputRoot) | Out-Null
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path
$payloadDir = Join-Path $OutputRoot 'payload'
$manifestPath = Join-Path $OutputRoot 'release-manifest.json'
$metadataPath = Join-Path $OutputRoot 'release-metadata.json'
$artifactBaseName = "GrainWarehouseERP-$version-windows-x64"
$artifactPath = Join-Path $OutputRoot "$artifactBaseName.exe"

if (Test-Path -LiteralPath $payloadDir) {
  Remove-Item -LiteralPath $payloadDir -Recurse -Force
}
[System.IO.Directory]::CreateDirectory($payloadDir) | Out-Null
Copy-Item -Path (Join-Path $releaseDir '*') -Destination $payloadDir -Recurse -Force

$payloadFiles = @(Get-ChildItem -LiteralPath $payloadDir -Recurse -File)
$manifestFileEntries = foreach ($file in $payloadFiles) {
  [ordered]@{
    path = Get-RelativeSlashPath $payloadDir $file.FullName
    size = [long]$file.Length
    sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
}
$entriesByPath = @{}
foreach ($entry in $manifestFileEntries) {
  $entriesByPath[[string]$entry['path']] = $entry
}
[string[]]$sortedManifestPaths = @($entriesByPath.Keys)
[Array]::Sort($sortedManifestPaths, [StringComparer]::Ordinal)
$manifestFileEntries = @($sortedManifestPaths | ForEach-Object {
    $entriesByPath[$_]
  })
$totalBytes = [long](($manifestFileEntries | ForEach-Object {
      [long]$_['size']
    } | Measure-Object -Sum).Sum)

$manifest = [ordered]@{
  application = 'Grain Warehouse ERP Lite'
  version = $fullVersion
  platform = 'windows-x64'
  sourceCommit = $SourceCommit
  packageFormat = 'inno-setup-exe'
  fileCount = $manifestFileEntries.Count
  totalBytes = $totalBytes
  files = $manifestFileEntries
}
Write-Utf8NoBom $manifestPath (($manifest | ConvertTo-Json -Depth 8) + "`n")
$manifestSha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()

$resolvedIscc = Resolve-Iscc $IsccPath
if (Test-Path -LiteralPath $artifactPath) { Remove-Item -LiteralPath $artifactPath -Force }
& $resolvedIscc "/DMyAppSourceDir=$payloadDir" "/DMyManifestPath=$manifestPath" "/DMyOutputDir=$OutputRoot" "/DMyOutputBaseFilename=$artifactBaseName" "/DMyAppVersion=$version" $installerSource
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed with exit code $LASTEXITCODE." }
if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
  throw "Installer was not created: $artifactPath"
}

$artifact = Get-Item -LiteralPath $artifactPath
$artifactSha256 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
$metadata = [ordered]@{
  application = 'Grain Warehouse ERP Lite'
  platform = 'windows-x64'
  sourceCommit = $SourceCommit
  packagingToolCommit = $packagingToolCommit
  gitState = 'clean'
  packageFormat = 'inno-setup-exe'
  artifact = [ordered]@{
    path = $artifact.Name
    size = [long]$artifact.Length
    sha256 = $artifactSha256
  }
  manifest = [ordered]@{
    path = 'release-manifest.json'
    sha256 = $manifestSha256
  }
  payloadDirectory = 'payload'
  manifestExclusions = @(
    'release-manifest.json is installer metadata, not a runtime payload file.',
    'unins*.exe and unins*.dat are Inno Setup uninstall metadata.'
  )
}
Write-Utf8NoBom $metadataPath (($metadata | ConvertTo-Json -Depth 8) + "`n")

Write-Host 'PASS: governed Windows installer created.' -ForegroundColor Green
Write-Host "Artifact: $artifactPath"
Write-Host "Artifact size: $($artifact.Length)"
Write-Host "Artifact SHA-256: $artifactSha256"
Write-Host "Manifest: $manifestPath"
Write-Host "Manifest SHA-256: $manifestSha256"
Write-Host "Payload files: $($manifestFileEntries.Count)"
Write-Host "Payload bytes: $totalBytes"
