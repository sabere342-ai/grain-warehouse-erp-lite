param(
  [string]$PackagePath
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
  $deliveryRoot = Join-Path $projectRoot "delivery"
  if (-not (Test-Path -LiteralPath $deliveryRoot)) {
    Write-Host "FAIL: delivery folder was not found." -ForegroundColor Red
    exit 1
  }

  $latest = Get-ChildItem -LiteralPath $deliveryRoot -Directory |
    Where-Object { $_.Name -like "grain_warehouse_erp_lite_pilot*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if ($null -eq $latest) {
    Write-Host "FAIL: no pilot delivery package was found." -ForegroundColor Red
    exit 1
  }

  $PackagePath = $latest.FullName
}

if (-not (Test-Path -LiteralPath $PackagePath -PathType Container)) {
  Write-Host "FAIL: package path does not exist: $PackagePath" -ForegroundColor Red
  exit 1
}

$packageRoot = (Resolve-Path -LiteralPath $PackagePath).Path
$blockedDirectoryNames = @(
  ".git",
  "lib",
  "test",
  "android",
  "ios",
  "macos",
  "linux",
  "web",
  "windows",
  ".dart_tool",
  ".idea",
  ".vscode"
)
$blockedFileNames = @(
  "pubspec.yaml",
  "pubspec.lock",
  "analysis_options.yaml"
)
$blockedExtensions = @(".log", ".tmp", ".dart")
$blockedScriptExtensions = @(".ps1")
$blockedDocNamePatterns = @("*DEVELOPER*", "*INTERNAL*", "*HANDOFF-NOTES*", "*PHASE-33-PILOT-SMOKE-RUN-HANDOFF.md")

$failures = New-Object System.Collections.Generic.List[string]
$items = Get-ChildItem -LiteralPath $packageRoot -Recurse -Force

foreach ($item in $items) {
  $relative = $item.FullName.Substring($packageRoot.Length).TrimStart("\", "/")
  if ($item.PSIsContainer) {
    if ($blockedDirectoryNames -contains $item.Name) {
      $failures.Add("Blocked directory: $relative")
    }
    continue
  }

  if ($blockedFileNames -contains $item.Name) {
    $failures.Add("Blocked file: $relative")
  }

  if ($blockedExtensions -contains $item.Extension.ToLowerInvariant()) {
    $failures.Add("Blocked file extension: $relative")
  }

  if ($blockedScriptExtensions -contains $item.Extension.ToLowerInvariant()) {
    $failures.Add("Blocked script file: $relative")
  }

  foreach ($pattern in $blockedDocNamePatterns) {
    if ($item.Name -like $pattern) {
      $failures.Add("Blocked internal/developer document: $relative")
    }
  }
}

$requiredFiles = @(
  "README-AR.txt",
  "Release\grain_warehouse_erp_lite.exe",
  "docs\PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md",
  "docs\CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md",
  "docs\OWNER-QUICK-START-AR.md"
)

foreach ($required in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $required))) {
    $failures.Add("Missing required handoff file: $required")
  }
}

if ($failures.Count -gt 0) {
  Write-Host "FAIL: pilot delivery package is not safe to hand off." -ForegroundColor Red
  foreach ($failure in $failures) {
    Write-Host " - $failure" -ForegroundColor Red
  }
  exit 1
}

Write-Host "PASS: pilot delivery package is safe to hand off." -ForegroundColor Green
Write-Host "Package:" $packageRoot
Write-Host "Checked blocked directories:" ($blockedDirectoryNames -join ", ")
Write-Host "Checked blocked files:" ($blockedFileNames -join ", ")
Write-Host "Checked blocked extensions:" (($blockedExtensions + $blockedScriptExtensions) -join ", ")
Write-Host "Required owner files are present."
