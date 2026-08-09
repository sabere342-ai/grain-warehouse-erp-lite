[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Prestate', 'Install', 'Launch', 'Snapshot')]
  [string]$Mode,
  [Parameter(Mandatory = $true)]
  [string]$RunId,
  [Parameter(Mandatory = $true)]
  [string]$OutputPath,
  [string]$InstallerPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-FileRecord([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return [ordered]@{ path = $Path; exists = $false }
  }
  $file = Get-Item -LiteralPath $Path
  $record = [ordered]@{
    path = $Path
    exists = $true
    size = [long]$file.Length
    lastWriteUtc = $file.LastWriteTimeUtc.ToString('o')
  }
  try {
    $record.sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  } catch [System.IO.IOException] {
    $record.sha256 = $null
    $record.hashUnavailableWhileLocked = $true
  }
  return $record
}

function Get-DirectoryRecord([string]$Path) {
  $exists = Test-Path -LiteralPath $Path -PathType Container
  return [ordered]@{
    path = $Path
    exists = $exists
    fileCount = if ($exists) { @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction Stop).Count } else { 0 }
  }
}

function Get-UninstallRegistration {
  $keys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}_is1',
    'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}_is1'
  )
  foreach ($key in $keys) {
    if (Test-Path -LiteralPath $key) {
      $item = Get-ItemProperty -LiteralPath $key
      return [ordered]@{
        exists = $true
        key = $key
        displayName = [string]$item.DisplayName
        installLocation = [string]$item.InstallLocation
        uninstallString = [string]$item.UninstallString
      }
    }
  }
  return [ordered]@{ exists = $false; key = $null }
}

function Merge-Record([System.Collections.IDictionary]$Base, [System.Collections.IDictionary]$Extra) {
  $merged = [ordered]@{}
  foreach ($entry in $Base.GetEnumerator()) { $merged[$entry.Key] = $entry.Value }
  foreach ($entry in $Extra.GetEnumerator()) { $merged[$entry.Key] = $entry.Value }
  return $merged
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$profilePath = $env:USERPROFILE
$appSupport = Join-Path $env:APPDATA 'Grala\Grala'
$preferences = Join-Path $env:APPDATA 'GrainWarehouseErpLite'
$backupDirectory = Join-Path $profilePath 'Documents\grain-warehouse-erp-lite-backups'
$installDirectory = Join-Path $env:LOCALAPPDATA 'Programs\GrainWarehouseERPLite'
$installedExe = Join-Path $installDirectory 'grain_warehouse_erp_lite.exe'
$startMenuShortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Grain Warehouse ERP Lite\Grain Warehouse ERP Lite.lnk'
$desktopShortcut = Join-Path $profilePath 'Desktop\Grain Warehouse ERP Lite.lnk'
$database = Join-Path $appSupport 'grain_warehouse_erp.sqlite3'

$base = [ordered]@{
  runId = $RunId
  timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
  mode = $Mode
  user = $identity.Name
  sid = $identity.User.Value
  profilePath = $profilePath
  appData = $env:APPDATA
  localAppData = $env:LOCALAPPDATA
}

switch ($Mode) {
  'Prestate' {
    $result = Merge-Record $base ([ordered]@{
      applicationSupport = Get-DirectoryRecord $appSupport
      preferences = Get-DirectoryRecord $preferences
      backupDirectory = Get-DirectoryRecord $backupDirectory
      installDirectory = Get-DirectoryRecord $installDirectory
      database = Get-FileRecord $database
      startMenuShortcut = Get-FileRecord $startMenuShortcut
      desktopShortcut = Get-FileRecord $desktopShortcut
      uninstallRegistration = Get-UninstallRegistration
      runningProcessCount = @(Get-Process grain_warehouse_erp_lite -ErrorAction SilentlyContinue).Count
    })
  }
  'Install' {
    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
      throw 'Governed installer copy is missing.'
    }
    $hash = (Get-FileHash -LiteralPath $InstallerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -cne 'ab67d04e205a78aa2d6e087ffd6f63655a80e5e2de10d7a603f959b073098659') {
      throw 'E3 governed installer hash mismatch immediately before use.'
    }
    $startedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $process = Start-Process -FilePath $InstallerPath -ArgumentList @(
      '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-'
    ) -PassThru -Wait
    if ($process.ExitCode -ne 0) {
      throw "Installer exited with code $($process.ExitCode)."
    }
    $result = Merge-Record $base ([ordered]@{
      installer = Get-FileRecord $InstallerPath
      startedUtc = $startedUtc
      completedUtc = (Get-Date).ToUniversalTime().ToString('o')
      exitCode = [int]$process.ExitCode
      installDirectory = Get-DirectoryRecord $installDirectory
      installedExecutable = Get-FileRecord $installedExe
      installedManifest = Get-FileRecord (Join-Path $installDirectory 'release-manifest.json')
      startMenuShortcut = Get-FileRecord $startMenuShortcut
      desktopShortcut = Get-FileRecord $desktopShortcut
      uninstallRegistration = Get-UninstallRegistration
    })
  }
  'Launch' {
    if (-not (Test-Path -LiteralPath $installedExe -PathType Leaf)) {
      throw 'Installed executable is missing.'
    }
    $runtimeCwd = Join-Path $env:PUBLIC 'Documents\GralaPhase107E\runtime-cwd'
    [IO.Directory]::CreateDirectory($runtimeCwd) | Out-Null
    $process = Start-Process -FilePath $installedExe -WorkingDirectory $runtimeCwd -PassThru
    $deadline = (Get-Date).AddSeconds(45)
    do {
      Start-Sleep -Milliseconds 500
      $process.Refresh()
      if ($process.HasExited) { throw "Installed runtime exited immediately with code $($process.ExitCode)." }
    } until ($process.MainWindowHandle -ne 0 -or (Get-Date) -ge $deadline)
    if ($process.MainWindowHandle -eq 0) { throw 'Installed runtime did not expose a top-level window.' }
    $result = Merge-Record $base ([ordered]@{
      processId = $process.Id
      executablePath = $installedExe
      workingDirectory = $runtimeCwd
      mainWindowHandle = $process.MainWindowHandle.ToInt64()
      mainWindowTitle = $process.MainWindowTitle
      immediateExit = $false
      sourceCheckoutUsed = $false
      effectiveAppData = $env:APPDATA
      effectiveLocalAppData = $env:LOCALAPPDATA
    })
  }
  'Snapshot' {
    $profileDatabaseFiles = @(@($env:APPDATA, $env:LOCALAPPDATA) | ForEach-Object {
      Get-ChildItem -LiteralPath $_ -Recurse -File -Force -ErrorAction SilentlyContinue
    } | Where-Object {
      $_.Name -match '(?i)grain.*\.sqlite|\.sqlite3?(?:-(?:wal|shm))?$'
    } | ForEach-Object { Get-FileRecord $_.FullName })
    $installedManifestPath = Join-Path $installDirectory 'release-manifest.json'
    $payloadVerification = [ordered]@{ passed = $false; reason = 'installed manifest missing' }
    if (Test-Path -LiteralPath $installedManifestPath -PathType Leaf) {
      $manifest = Get-Content -LiteralPath $installedManifestPath -Raw | ConvertFrom-Json
      $mismatches = @()
      foreach ($entry in @($manifest.files)) {
        $payloadPath = Join-Path $installDirectory ([string]$entry.path).Replace('/', '\')
        if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
          $mismatches += "missing:$($entry.path)"
          continue
        }
        $payloadFile = Get-Item -LiteralPath $payloadPath
        $payloadHash = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($payloadFile.Length -ne [long]$entry.size -or $payloadHash -cne ([string]$entry.sha256).ToLowerInvariant()) {
          $mismatches += "identity:$($entry.path)"
        }
      }
      $declared = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
      foreach ($entry in @($manifest.files)) { [void]$declared.Add([string]$entry.path) }
      $extras = @(Get-ChildItem -LiteralPath $installDirectory -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($installDirectory.Length).TrimStart('\', '/').Replace('\', '/')
        if (-not $declared.Contains($relative) -and $relative -cne 'release-manifest.json' -and $relative -notmatch '^unins\d+\.(?:exe|dat)$') {
          $relative
        }
      })
      $payloadVerification = [ordered]@{
        passed = $mismatches.Count -eq 0 -and $extras.Count -eq 0
        declaredCount = @($manifest.files).Count
        matchedCount = @($manifest.files).Count - $mismatches.Count
        mismatchCount = $mismatches.Count
        undeclaredExtraCount = $extras.Count
        mismatches = $mismatches
        undeclaredExtras = $extras
      }
    }
    $result = Merge-Record $base ([ordered]@{
      applicationSupport = Get-DirectoryRecord $appSupport
      preferences = Get-DirectoryRecord $preferences
      backupDirectory = Get-DirectoryRecord $backupDirectory
      installDirectory = Get-DirectoryRecord $installDirectory
      database = Get-FileRecord $database
      databaseWal = Get-FileRecord "$database-wal"
      databaseShm = Get-FileRecord "$database-shm"
      profileDatabaseFiles = $profileDatabaseFiles
      installedExecutable = Get-FileRecord $installedExe
      installedPayloadVerification = $payloadVerification
      uninstallRegistration = Get-UninstallRegistration
      runningProcessCount = @(Get-Process grain_warehouse_erp_lite -ErrorAction SilentlyContinue).Count
    })
  }
}

$outputDirectory = Split-Path -Parent $OutputPath
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$json = $result | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))
