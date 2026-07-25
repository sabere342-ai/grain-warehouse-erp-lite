param(
  [Parameter(Mandatory=$true)]
  [string]$PackagePath
)

$ErrorActionPreference = 'Stop'

Write-Host '=== Phase 98 — Package Source-Safety Scanner ===' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path -LiteralPath $PackagePath -PathType Container)) {
  Write-Host "FAIL: Package path does not exist: $PackagePath" -ForegroundColor Red
  exit 1
}

$packageRoot = (Resolve-Path -LiteralPath $PackagePath).Path
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

# --- Prohibited directories (allowlist approach: these must NOT exist) ---
$prohibitedDirectories = @(
  '.git',
  '.dart_tool',
  '.idea',
  '.vscode',
  '.build-diagnostics',
  '.agents',
  '.diagnostics',
  'lib',
  'test',
  'android',
  'ios',
  'macos',
  'linux',
  'web',
  'windows',
  'tool',
  'tmp',
  '.venv'
)

# --- Prohibited file extensions ---
$prohibitedExtensions = @(
  '.dart',
  '.ps1',
  '.py',
  '.sh',
  '.bat',
  '.cmd',
  '.cmake',
  '.cc',
  '.cpp',
  '.h',
  '.lock',
  '.log',
  '.tmp',
  '.db',
  '.sqlite3',
  '.sqlite3-wal',
  '.sqlite3-shm',
  '.env',
  '.pem',
  '.key',
  '.p12',
  '.pfx',
  '.jks',
  '.keystore',
  '.iml',
  '.suo',
  '.user',
  '.sln',
  '.vcxproj',
  '.filters'
)

# --- Prohibited file names ---
$prohibitedFileNames = @(
  'pubspec.yaml',
  'pubspec.lock',
  'analysis_options.yaml',
  '.metadata',
  '.packages',
  'package_config.json',
  'flutter_01.log',
  'LICENSE',
  'README.md',
  'MASTER-PROJECT-EXECUTION-PLAN-AR.md'
)

# --- Prohibited filename patterns ---
$prohibitedNamePatterns = @(
  '*DEVELOPER*',
  '*INTERNAL*',
  '*HANDOFF-NOTES*',
  '*PHASE-*',
  '*BUILD-WEEK-*',
  '*COMPETITION-*',
  '*ADR-*',
  '*AI_ACTION*',
  '*GOVERNING*',
  '*ROADMAP*',
  '*REQUIREMENTS*',
  '*TRACEABILITY*'
)

# --- Expected required files (relative to package root) ---
$requiredFiles = @(
  'README-AR.txt',
  'Release/grain_warehouse_erp_lite.exe',
  'Release/flutter_windows.dll',
  'Release/data/icudtl.dat',
  'Release/data/flutter_assets',
  'release-manifest.json',
  'checksums.sha256',
  'file-listing.txt'
)

# --- Required directories ---
$requiredDirectories = @(
  'Release',
  'Release/data',
  'Release/data/flutter_assets',
  'docs'
)

# --- Developer path patterns ---
$developerPathPatterns = @(
  'C:\dev\',
  'C:\src\',
  'C:\Users\',
  '/home/',
  '/Users/',
  'C:\Program Files',
  'C:\Program Files (x86)'
)

Write-Host 'Scanning package...' -ForegroundColor Cyan
$allItems = Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue

foreach ($item in $allItems) {
  $relativePath = $item.FullName.Substring($packageRoot.Length).TrimStart('\', '/')

  # Check prohibited directories
  if ($item.PSIsContainer) {
    if ($prohibitedDirectories -contains $item.Name) {
      $failures.Add("Prohibited directory: $relativePath")
    }
    continue
  }

  # Check prohibited file extensions
  if ($prohibitedExtensions -contains $item.Extension.ToLowerInvariant()) {
    $failures.Add("Prohibited file extension ($($item.Extension)): $relativePath")
  }

  # Check prohibited file names
  if ($prohibitedFileNames -contains $item.Name) {
    $failures.Add("Prohibited file: $relativePath")
  }

  # Check prohibited name patterns
  foreach ($pattern in $prohibitedNamePatterns) {
    if ($item.Name -like $pattern) {
      $failures.Add("Prohibited file pattern ($pattern): $relativePath")
      break
    }
  }

  # Check for oversized files (>100MB is suspicious for a demo package)
  if ($item.Length -gt 100MB) {
    $warnings.Add("Oversized file ($([math]::Round($item.Length / 1MB, 0)) MB): $relativePath")
  }
}

# --- Check text files for developer path references ---
$textExtensions = @('.txt', '.json', '.md')
$allFiles = Get-ChildItem -LiteralPath $packageRoot -Recurse -File -ErrorAction SilentlyContinue
foreach ($file in $allFiles) {
  if ($textExtensions -contains $file.Extension.ToLowerInvariant()) {
    if ($file.Length -lt 1MB) {
      try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
          foreach ($pattern in $developerPathPatterns) {
            if ($content -match [regex]::Escape($pattern)) {
              $relativePath = $file.FullName.Substring($packageRoot.Length).TrimStart('\', '/')
              $failures.Add("Developer path reference ($pattern) in: $relativePath")
            }
          }
          # Check for com.example
          if ($content -match 'com\.example') {
            $relativePath = $file.FullName.Substring($packageRoot.Length).TrimStart('\', '/')
            $failures.Add("com.example reference in: $relativePath")
          }
        }
      } catch {
        # Skip files that can't be read
      }
    }
  }
}

# --- Verify required files ---
foreach ($required in $requiredFiles) {
  $requiredPath = Join-Path $packageRoot $required.Replace('/', '\')
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    $failures.Add("Missing required file: $required")
  }
}

# --- Verify required directories ---
foreach ($requiredDir in $requiredDirectories) {
  $requiredDirPath = Join-Path $packageRoot $requiredDir.Replace('/', '\')
  if (-not (Test-Path -LiteralPath $requiredDirPath -PathType Container)) {
    $failures.Add("Missing required directory: $requiredDir")
  }
}

# --- Verify executable exists in Release ---
$exePath = Join-Path $packageRoot 'Release\grain_warehouse_erp_lite.exe'
if (Test-Path -LiteralPath $exePath) {
  $exeVersion = (Get-Item -LiteralPath $exePath).VersionInfo
  Write-Host "Executable found: grain_warehouse_erp_lite.exe" -ForegroundColor Green
  Write-Host "  CompanyName: $($exeVersion.CompanyName)"
  Write-Host "  ProductName: $($exeVersion.ProductName)"
  Write-Host "  FileDescription: $($exeVersion.FileDescription)"
} else {
  $failures.Add("Main executable not found: Release\grain_warehouse_erp_lite.exe")
}

# --- Results ---
Write-Host ''
if ($failures.Count -gt 0) {
  Write-Host "FAIL: Package safety scan failed with $($failures.Count) issue(s)." -ForegroundColor Red
  foreach ($failure in $failures) {
    Write-Host "  FAIL: $failure" -ForegroundColor Red
  }
  if ($warnings.Count -gt 0) {
    Write-Host ''
    Write-Host "WARNINGS: $($warnings.Count)" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
      Write-Host "  WARN: $warning" -ForegroundColor Yellow
    }
  }
  exit 1
}

Write-Host 'PASS: Package safety scan passed.' -ForegroundColor Green
Write-Host "  Prohibited directories checked: $($prohibitedDirectories.Count)"
Write-Host "  Prohibited extensions checked: $($prohibitedExtensions.Count)"
Write-Host "  Prohibited file names checked: $($prohibitedFileNames.Count)"
Write-Host "  Required files verified: $($requiredFiles.Count)"
Write-Host "  Required directories verified: $($requiredDirectories.Count)"
if ($warnings.Count -gt 0) {
  Write-Host "  Warnings: $($warnings.Count)" -ForegroundColor Yellow
  foreach ($warning in $warnings) {
    Write-Host "    WARN: $warning" -ForegroundColor Yellow
  }
}
