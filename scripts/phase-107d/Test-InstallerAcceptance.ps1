[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ReleaseRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ReleaseRoot = (Resolve-Path -LiteralPath $ReleaseRoot).Path
$metadata = Get-Content -LiteralPath (Join-Path $ReleaseRoot 'release-metadata.json') -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath (Join-Path $ReleaseRoot 'release-manifest.json') -Raw | ConvertFrom-Json
$installerPath = Join-Path $ReleaseRoot ([string]$metadata.artifact.path)
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) { throw 'Installer not found.' }

$acceptanceRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("phase107d-acceptance-" + [Guid]::NewGuid().ToString('N'))
$installDir = Join-Path $acceptanceRoot 'installed'
$profileDir = Join-Path $acceptanceRoot 'profile'
$appData = Join-Path $profileDir 'AppData\Roaming'
$localAppData = Join-Path $profileDir 'AppData\Local'
[System.IO.Directory]::CreateDirectory($appData) | Out-Null
[System.IO.Directory]::CreateDirectory($localAppData) | Out-Null

function Invoke-InstalledLaunch([string]$ExePath, [string]$Label) {
  $previousAppData = $env:APPDATA
  $previousLocalAppData = $env:LOCALAPPDATA
  $previousUserProfile = $env:USERPROFILE
  try {
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    $env:USERPROFILE = $profileDir
    $process = Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path $ExePath) -PassThru
    $deadline = (Get-Date).AddSeconds(40)
    do {
      Start-Sleep -Milliseconds 500
      $process.Refresh()
      if ($process.HasExited) { throw "$Label exited before presenting a window (exit $($process.ExitCode))." }
    } until ($process.MainWindowHandle -ne 0 -or (Get-Date) -ge $deadline)
    if ($process.MainWindowHandle -eq 0) { throw "$Label did not present a top-level window within 40 seconds." }
    Write-Host "PASS: $Label presented window '$($process.MainWindowTitle)'." -ForegroundColor Green
    Stop-Process -Id $process.Id -Force
    $process.WaitForExit()
  } finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    $env:USERPROFILE = $previousUserProfile
  }
}

try {
  $install = Start-Process -FilePath $installerPath -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=$installDir") -PassThru -Wait
  if ($install.ExitCode -ne 0) { throw "Installer failed with exit code $($install.ExitCode)." }
  $installedExe = Join-Path $installDir 'grain_warehouse_erp_lite.exe'
  if (-not (Test-Path -LiteralPath $installedExe -PathType Leaf)) { throw 'Installed executable is missing.' }
  if (-not (Test-Path -LiteralPath (Join-Path $installDir 'release-manifest.json') -PathType Leaf)) { throw 'Installed manifest is missing.' }
  foreach ($entry in @($manifest.files)) {
    $installedPath = Join-Path $installDir ([string]$entry.path).Replace('/', '\')
    if (-not (Test-Path -LiteralPath $installedPath -PathType Leaf)) {
      throw "Installed payload file is missing: $($entry.path)"
    }
    $file = Get-Item -LiteralPath $installedPath
    if ([long]$file.Length -ne [long]$entry.size) {
      throw "Installed payload size mismatch: $($entry.path)"
    }
    $hash = (Get-FileHash -LiteralPath $installedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -cne ([string]$entry.sha256).ToLowerInvariant()) {
      throw "Installed payload SHA-256 mismatch: $($entry.path)"
    }
  }
  $declaredPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($entry in @($manifest.files)) { [void]$declaredPaths.Add([string]$entry.path) }
  foreach ($file in @(Get-ChildItem -LiteralPath $installDir -Recurse -File)) {
    $relativePath = $file.FullName.Substring($installDir.Length).TrimStart('\', '/').Replace('\', '/')
    $isInstallerMetadata = $relativePath -ceq 'release-manifest.json' -or
      $relativePath -match '^unins\d+\.(?:exe|dat)$'
    if (-not $isInstallerMetadata -and -not $declaredPaths.Contains($relativePath)) {
      throw "Installed payload contains an undeclared extra file: $relativePath"
    }
  }
  Write-Host "PASS: installer completed; all $($manifest.fileCount) installed payload files match size and SHA-256." -ForegroundColor Green

  Invoke-InstalledLaunch $installedExe 'first installed launch'
  Invoke-InstalledLaunch $installedExe 'second installed launch'

  $sentinelDir = Join-Path $appData 'GrainWarehouseErpLite'
  [System.IO.Directory]::CreateDirectory($sentinelDir) | Out-Null
  $sentinelPath = Join-Path $sentinelDir 'phase107d-user-data-sentinel.txt'
  [System.IO.File]::WriteAllText($sentinelPath, 'preserve-user-data')

  $databaseFiles = @(Get-ChildItem -LiteralPath $profileDir -Recurse -Filter 'grain_warehouse_erp.sqlite3' -File -ErrorAction SilentlyContinue)
  if ($databaseFiles.Count -eq 0) { throw 'Installed launches did not create the expected SQLite database under the isolated profile.' }
  $userFilesBeforeUninstall = @{}
  foreach ($file in @(Get-ChildItem -LiteralPath $profileDir -Recurse -File)) {
    $userFilesBeforeUninstall[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  }

  $uninstaller = Get-ChildItem -LiteralPath $installDir -Filter 'unins*.exe' -File | Select-Object -First 1
  if ($null -eq $uninstaller) { throw 'Inno Setup uninstaller is missing.' }
  $uninstall = Start-Process -FilePath $uninstaller.FullName -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -PassThru -Wait
  if ($uninstall.ExitCode -ne 0) { throw "Uninstaller failed with exit code $($uninstall.ExitCode)." }
  if (Test-Path -LiteralPath $installedExe) { throw 'Uninstall left the application executable behind.' }
  foreach ($path in $userFilesBeforeUninstall.Keys) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Uninstall deleted user data: $path" }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($hash -cne $userFilesBeforeUninstall[$path]) { throw "Uninstall changed user data: $path" }
  }
  Write-Host "PASS: uninstall removed binaries and preserved $($userFilesBeforeUninstall.Count) user-data file(s) byte-for-byte." -ForegroundColor Green
  Write-Host 'User data policy checked under isolated profile/AppData and profile/Documents.'
} finally {
  Get-Process grain_warehouse_erp_lite -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $acceptanceRoot) { Remove-Item -LiteralPath $acceptanceRoot -Recurse -Force }
}
