param(
  [string]$OutputRoot = "delivery\grain_warehouse_erp_lite_pilot"
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$releaseDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
$exePath = Join-Path $releaseDir "grain_warehouse_erp_lite.exe"

if (-not (Test-Path -LiteralPath $exePath)) {
  throw "Windows release executable was not found. Run: flutter.bat build windows --release"
}

$outputPath = Join-Path $projectRoot $OutputRoot
if (Test-Path -LiteralPath $outputPath) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $outputPath = Join-Path $projectRoot "delivery\grain_warehouse_erp_lite_pilot_$stamp"
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$releaseOutput = Join-Path $outputPath "Release"
$docsOutput = Join-Path $outputPath "docs"
New-Item -ItemType Directory -Force -Path $releaseOutput | Out-Null
New-Item -ItemType Directory -Force -Path $docsOutput | Out-Null

Copy-Item -Path (Join-Path $releaseDir "*") -Destination $releaseOutput -Recurse -Force
$docs = @(
  "docs\OWNER-QUICK-START-AR.md",
  "docs\RELEASE-NOTES-AR.md",
  "docs\PHASE-22-PILOT-DELIVERY-CHECKLIST.md"
)
foreach ($doc in $docs) {
  Copy-Item -LiteralPath (Join-Path $projectRoot $doc) -Destination $docsOutput -Force
}

Write-Host "Pilot delivery folder created:" $outputPath
Write-Host "Do not commit delivery artifacts. The delivery/ folder should stay ignored by Git."