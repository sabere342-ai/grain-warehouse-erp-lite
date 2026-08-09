[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ReleaseRoot,
  [string]$ExpectedSourceCommit = 'f521a97946d73829fef19f4f0d30a6d07b9f8051'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Fail([string]$Message) {
  Write-Host "FAIL: $Message" -ForegroundColor Red
  exit 1
}

function Resolve-SafeChild([string]$Root, [string]$RelativePath) {
  if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
    Fail "Unsafe relative path: $RelativePath"
  }
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
  $childFull = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath.Replace('/', '\')))
  if (-not $childFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
    Fail "Path escapes release root: $RelativePath"
  }
  return $childFull
}

if (-not (Test-Path -LiteralPath $ReleaseRoot -PathType Container)) { Fail 'D1 release root does not exist.' }
$ReleaseRoot = (Resolve-Path -LiteralPath $ReleaseRoot).Path
$metadataPath = Join-Path $ReleaseRoot 'release-metadata.json'
$manifestPath = Join-Path $ReleaseRoot 'release-manifest.json'
if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) { Fail 'D1 release metadata does not exist.' }
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { Fail 'D3 manifest does not exist.' }

try {
  $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
} catch { Fail "Release JSON is invalid: $($_.Exception.Message)" }

$artifactPath = Resolve-SafeChild $ReleaseRoot ([string]$metadata.artifact.path)
if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) { Fail 'D1 artifact does not exist.' }
$artifact = Get-Item -LiteralPath $artifactPath
$artifactHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($artifactHash -cne ([string]$metadata.artifact.sha256).ToLowerInvariant()) { Fail 'D2 artifact SHA-256 mismatch.' }
if ([long]$artifact.Length -ne [long]$metadata.artifact.size) { Fail 'D2 artifact size mismatch.' }

$manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($manifestHash -cne ([string]$metadata.manifest.sha256).ToLowerInvariant()) { Fail 'D3 manifest SHA-256 mismatch.' }
if ([string]$manifest.sourceCommit -cne $ExpectedSourceCommit) { Fail 'D4 manifest sourceCommit mismatch.' }
if ([string]$metadata.sourceCommit -cne $ExpectedSourceCommit) { Fail 'D4 metadata sourceCommit mismatch.' }
if ([string]$metadata.gitState -cne 'clean') { Fail 'D10 package was not declared from a clean Git state.' }

$payloadDir = Resolve-SafeChild $ReleaseRoot ([string]$metadata.payloadDirectory)
if (-not (Test-Path -LiteralPath $payloadDir -PathType Container)) { Fail 'D5 payload directory does not exist.' }
$entries = @($manifest.files)
if ([int]$manifest.fileCount -ne $entries.Count) { Fail 'Manifest fileCount mismatch.' }
$paths = @($entries | ForEach-Object { [string]$_.path })
[string[]]$sortedPaths = @($paths)
[Array]::Sort($sortedPaths, [StringComparer]::Ordinal)
if (($paths -join "`n") -cne ($sortedPaths -join "`n")) { Fail 'Manifest paths are not lexical ascending.' }
$uniquePaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($path in $paths) {
  if (-not $uniquePaths.Add($path)) { Fail "Manifest contains a duplicate path: $path" }
}

$computedTotal = [long]0
foreach ($entry in $entries) {
  $relativePath = [string]$entry.path
  if ($relativePath.Contains('\')) { Fail "Manifest path is not slash-normalized: $relativePath" }
  $payloadPath = Resolve-SafeChild $payloadDir $relativePath
  if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) { Fail "D5 payload file missing: $relativePath" }
  $file = Get-Item -LiteralPath $payloadPath
  if ([long]$file.Length -ne [long]$entry.size) { Fail "D6 payload size mismatch: $relativePath" }
  $hash = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($hash -cne ([string]$entry.sha256).ToLowerInvariant()) { Fail "D7 payload SHA-256 mismatch: $relativePath" }
  if ([string]$entry.sha256 -cnotmatch '^[0-9a-f]{64}$') { Fail "Manifest hash format is invalid: $relativePath" }
  $computedTotal += [long]$file.Length
}
if ($computedTotal -ne [long]$manifest.totalBytes) { Fail 'Manifest totalBytes mismatch.' }

[string[]]$actualPaths = @(Get-ChildItem -LiteralPath $payloadDir -Recurse -File | ForEach-Object {
  $_.FullName.Substring($payloadDir.Length).TrimStart('\', '/').Replace('\', '/')
})
[Array]::Sort($actualPaths, [StringComparer]::Ordinal)
if (($actualPaths -join "`n") -cne ($paths -join "`n")) { Fail 'D8 payload has missing or undeclared extra files.' }

$text = (Get-Content -LiteralPath $manifestPath -Raw) + "`n" + (Get-Content -LiteralPath $metadataPath -Raw)
$leakPatterns = @(
  '(?i)[A-Z]:\\(?:dev|src|temp|tmp|users)\\',
  '(?i)(?:api[_-]?key|password|token|private[_-]?key|credential)\s*[:=]\s*["''][^"'']+["'']',
  '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
)
foreach ($pattern in $leakPatterns) {
  if ($text -match $pattern) { Fail "D9 textual path/secret leakage pattern detected: $pattern" }
}

Write-Host 'PASS: D1-D10 governed package integrity verification passed.' -ForegroundColor Green
Write-Host "Artifact SHA-256: $artifactHash"
Write-Host "Manifest SHA-256: $manifestHash"
Write-Host "Payload files: $($entries.Count)"
Write-Host "Payload bytes: $computedTotal"
