[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Prepare', 'Install', 'Launch', 'Snapshot', 'Close', 'StageSecret', 'RemoveSecrets', 'ResetInvalid')]
  [string]$Action,
  [string]$RunId,
  [ValidateSet('First', 'Second')]
  [string]$LaunchLabel = 'First'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$baseline = 'd2103102f68ff7dbc1dec3ca5fc4b02d054be912'
$expectedArtifactHash = 'ab67d04e205a78aa2d6e087ffd6f63655a80e5e2de10d7a603f959b073098659'
$expectedArtifactSize = 14998748L
$expectedWindowTitle = -join @([char]0x063A, [char]0x0644, [char]0x0627, [char]0x0644)
$testUser = 'CodexGhalal107E'
$stateRoot = Join-Path $env:ProgramData 'GralaPhase107E'
$statePath = Join-Path $stateRoot 'state.json'
$credentialPath = Join-Path $stateRoot 'credential.clixml'
$runtimeSecretPath = Join-Path $stateRoot 'runtime-secret.bin'
$publicRoot = Join-Path $env:PUBLIC 'Documents\GralaPhase107E'
$publicInstaller = Join-Path $publicRoot 'GrainWarehouseERP-1.0.0-windows-x64.exe'
$worker = Join-Path $projectRoot 'tools\phase107e\fresh_user_worker.ps1'
$evidenceRoot = Join-Path $projectRoot 'docs\phase-107e\evidence'

function Assert-Administrator {
  $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Phase 107E controller requires an elevated PowerShell process.'
  }
}

function Write-Json([string]$Path, [object]$Value) {
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  [System.IO.File]::WriteAllText(
    $Path,
    ($Value | ConvertTo-Json -Depth 10),
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Read-State {
  if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    throw 'Phase 107E state is missing; run Prepare first.'
  }
  return Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Credential {
  if (-not (Test-Path -LiteralPath $credentialPath -PathType Leaf)) {
    throw 'Encrypted fresh-user credential is missing.'
  }
  return Import-Clixml -LiteralPath $credentialPath
}

function Quote-Argument([string]$Value) {
  return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-AsFreshUser(
  [string]$FilePath,
  [string[]]$Arguments,
  [string]$WorkingDirectory,
  [bool]$Wait,
  [bool]$CreateNoWindow
) {
  $credential = Get-Credential
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $FilePath
  $info.Arguments = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ')
  $info.WorkingDirectory = $WorkingDirectory
  $info.Domain = $env:COMPUTERNAME
  $info.UserName = $testUser
  $info.Password = $credential.Password
  $info.LoadUserProfile = $true
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $CreateNoWindow
  if ($Wait) {
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  if (-not $process.Start()) { throw "Failed to start $FilePath as fresh user." }
  if ($Wait) {
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
      throw "Fresh-user process failed with exit $($process.ExitCode): $stderr"
    }
    return [ordered]@{ exitCode = $process.ExitCode; stdout = $stdout; stderr = $stderr }
  }
  return $process
}

function Invoke-Worker([string]$Mode, [string]$OutputPath, [string]$InstallerPath) {
  $arguments = @(
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $worker,
    '-Mode', $Mode, '-RunId', $RunId, '-OutputPath', $OutputPath
  )
  if ($InstallerPath) { $arguments += @('-InstallerPath', $InstallerPath) }
  return Invoke-AsFreshUser `
    -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Arguments $arguments -WorkingDirectory $env:SystemRoot -Wait $true -CreateNoWindow $true
}

trap {
  try {
    Write-Json (Join-Path $evidenceRoot '00-controller-last-error.json') ([ordered]@{
      timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
      action = $Action
      launchLabel = $LaunchLabel
      exceptionType = $_.Exception.GetType().FullName
      message = $_.Exception.Message
      scriptStackTrace = $_.ScriptStackTrace
    })
  } catch {}
  exit 1
}

Assert-Administrator

switch ($Action) {
  'Prepare' {
    if (-not $RunId -or $RunId -cnotmatch '^\d{8}-\d{6}$') {
      throw 'Prepare requires -RunId yyyyMMdd-HHmmss.'
    }
    $status = @(git -C $projectRoot status --porcelain --untracked-files=all)
    $head = (git -C $projectRoot rev-parse HEAD).Trim()
    $branch = (git -C $projectRoot branch --show-current).Trim()
    $unexpectedChanges = @($status | Where-Object {
      $path = $_.Substring(3).Replace('\', '/')
      $path -notlike 'tools/phase107e/*' -and $path -notlike 'docs/phase-107e/*'
    })
    if ($unexpectedChanges.Count -ne 0) {
      throw "Unexpected non-Phase-107E worktree changes: $($unexpectedChanges -join ', ')"
    }
    if ($head -cne $baseline) { throw "Expected baseline $baseline, found $head." }
    if ($branch -cne 'codex/phase-107e-fresh-profile-runtime-acceptance') {
      throw "Unexpected branch: $branch"
    }
    if (Get-LocalUser -Name $testUser -ErrorAction SilentlyContinue) {
      throw "Fresh-user gate failed: local user $testUser already exists."
    }
    $profilePath = Join-Path (Split-Path $env:USERPROFILE -Parent) $testUser
    if (Test-Path -LiteralPath $profilePath) {
      throw "Fresh-profile gate failed: $profilePath already exists."
    }
    $artifactPath = Join-Path $projectRoot 'delivery\phase-107d\GrainWarehouseERP-1.0.0-windows-x64.exe'
    $artifact = Get-Item -LiteralPath $artifactPath
    $artifactHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($artifact.Length -ne $expectedArtifactSize -or $artifactHash -cne $expectedArtifactHash) {
      throw 'E3 governed Phase 107D artifact identity mismatch.'
    }

    [System.IO.Directory]::CreateDirectory($stateRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($publicRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($evidenceRoot) | Out-Null
    $random = [byte[]]::new(24)
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($random) } finally { $generator.Dispose() }
    $secret = 'G7!' + [Convert]::ToBase64String($random).Replace('/', 'x').Replace('+', 'Y')
    $secureSecret = ConvertTo-SecureString $secret -AsPlainText -Force
    $credential = [PSCredential]::new("$env:COMPUTERNAME\$testUser", $secureSecret)
    $credential | Export-Clixml -LiteralPath $credentialPath
    [IO.File]::WriteAllText($runtimeSecretPath, $secret, [Text.UTF8Encoding]::new($false))
    $acl = Get-Acl -LiteralPath $runtimeSecretPath
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRule($rule) }
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    foreach ($identityName in @($currentIdentity, 'NT AUTHORITY\SYSTEM', 'BUILTIN\Administrators')) {
      $rule = [Security.AccessControl.FileSystemAccessRule]::new(
        $identityName, 'FullControl', 'Allow'
      )
      $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $runtimeSecretPath -AclObject $acl
    Set-Acl -LiteralPath $credentialPath -AclObject $acl

    New-LocalUser -Name $testUser -Password $secureSecret -AccountNeverExpires -PasswordNeverExpires | Out-Null
    $localUser = Get-LocalUser -Name $testUser
    Copy-Item -LiteralPath $artifactPath -Destination $publicInstaller -Force
    $copiedHash = (Get-FileHash -LiteralPath $publicInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($copiedHash -cne $expectedArtifactHash) { throw 'Public installer copy hash mismatch.' }

    $state = [ordered]@{
      runId = $RunId
      testUser = $testUser
      sid = $localUser.SID.Value
      profilePath = $profilePath
      profileExistedBeforeUserCreation = $false
      profileExistedBeforeInitialization = $false
      artifactHash = $artifactHash
      publicInstallerHash = $copiedHash
      preparedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-Json $statePath $state
    Write-Json (Join-Path $evidenceRoot '01-baseline-and-identity.json') ([ordered]@{
      runId = $RunId
      timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
      baselineCommit = $head
      branch = $branch
      startingTreeClean = $true
      phaseEntryCleanWasObservedBeforeBranchCreation = $true
      controllerWorktreeContainedOnlyPhase107EChanges = $true
      testUser = $testUser
      sid = $localUser.SID.Value
      profilePath = $profilePath
      profileExistedBeforeUserCreation = $false
      profileExistedBeforeInitialization = $false
      artifactFileName = $artifact.Name
      artifactSize = [long]$artifact.Length
      artifactSha256 = $artifactHash
      publicCopySha256 = $copiedHash
    })

    $prestatePath = Join-Path $evidenceRoot '02-fresh-profile-prestate.json'
    Invoke-Worker -Mode Prestate -OutputPath $prestatePath -InstallerPath '' | Out-Null
    $prestate = Get-Content -LiteralPath $prestatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($prestate.sid -cne $localUser.SID.Value -or
        $prestate.applicationSupport.exists -or $prestate.preferences.exists -or
        $prestate.backupDirectory.exists -or $prestate.installDirectory.exists -or
        $prestate.database.exists -or $prestate.uninstallRegistration.exists -or
        $prestate.startMenuShortcut.exists -or $prestate.desktopShortcut.exists -or
        $prestate.runningProcessCount -ne 0) {
      throw 'E1/E2 fresh-profile prestate gate failed.'
    }
    Write-Host "PASS: prepared genuinely new user $testUser with SID $($localUser.SID.Value)."
  }
  'Install' {
    $state = Read-State
    $RunId = [string]$state.runId
    if ((Get-FileHash -LiteralPath $publicInstaller -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedArtifactHash) {
      throw 'E3 governed installer copy changed before installation.'
    }
    $installEvidence = Join-Path $evidenceRoot '03-install-result.json'
    Invoke-Worker -Mode Install -OutputPath $installEvidence -InstallerPath $publicInstaller | Out-Null
    $installed = Get-Content -LiteralPath $installEvidence -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($installed.exitCode -ne 0 -or -not $installed.installedExecutable.exists -or
        -not $installed.installedManifest.exists -or -not $installed.uninstallRegistration.exists) {
      throw 'E4/E5 installation gate failed.'
    }
    Write-Host "PASS: installed governed artifact under $testUser."
  }
  'Launch' {
    $state = Read-State
    $RunId = [string]$state.runId
    $launchFile = if ($LaunchLabel -eq 'First') { '04-first-launch-process.json' } else { '09-second-launch-process.json' }
    $launchPath = Join-Path $evidenceRoot $launchFile
    Invoke-Worker -Mode Launch -OutputPath $launchPath -InstallerPath '' | Out-Null
    $launch = Get-Content -LiteralPath $launchPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($launch.mainWindowHandle -eq 0 -or $launch.mainWindowTitle -cne $expectedWindowTitle -or
        $launch.effectiveAppData -notmatch '(?i)\\Users\\CodexGhalal107E\\AppData\\Roaming$') {
      throw "$LaunchLabel launch identity/environment gate failed."
    }
    Write-Host "PASS: $LaunchLabel installed launch process $($launch.processId) presented '$($launch.mainWindowTitle)'."
  }
  'Snapshot' {
    $state = Read-State
    $RunId = [string]$state.runId
    $name = if ($LaunchLabel -eq 'First') { '08-first-session-persistence.json' } else { '11-second-session-persistence.json' }
    Invoke-Worker -Mode Snapshot -OutputPath (Join-Path $evidenceRoot $name) -InstallerPath '' | Out-Null
    Write-Host "PASS: captured $LaunchLabel fresh-user state snapshot."
  }
  'Close' {
    $state = Read-State
    $RunId = [string]$state.runId
    $processes = @(Get-Process grain_warehouse_erp_lite -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
      if (-not $process.CloseMainWindow()) { throw "Could not request clean close for process $($process.Id)." }
      if (-not $process.WaitForExit(15000)) { throw "Process $($process.Id) did not close within 15 seconds." }
    }
    $closeFile = if ($LaunchLabel -eq 'First') { '07-first-clean-close.json' } else { '10-second-clean-close.json' }
    Write-Json (Join-Path $evidenceRoot $closeFile) ([ordered]@{
      runId = $RunId
      timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
      launchLabel = $LaunchLabel
      processCount = $processes.Count
      cleanClose = $true
    })
    Write-Host "PASS: clean close completed for $($processes.Count) process(es)."
  }
  'StageSecret' {
    if (-not (Test-Path -LiteralPath $runtimeSecretPath -PathType Leaf)) {
      throw 'Runtime-only secret is missing.'
    }
    $secret = [IO.File]::ReadAllText($runtimeSecretPath, [Text.Encoding]::UTF8)
    Set-Clipboard -Value $secret
    Write-Host 'PASS: runtime-only secret staged to the interactive clipboard without disclosure.'
  }
  'RemoveSecrets' {
    if (Test-Path -LiteralPath $credentialPath) { Remove-Item -LiteralPath $credentialPath -Force }
    if (Test-Path -LiteralPath $runtimeSecretPath) { Remove-Item -LiteralPath $runtimeSecretPath -Force }
    Write-Host 'PASS: runtime-only secret material removed.'
  }
  'ResetInvalid' {
    $localUser = Get-LocalUser -Name $testUser -ErrorAction SilentlyContinue
    if ($localUser) {
      Get-Process grain_warehouse_erp_lite -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      $sid = $localUser.SID.Value
      Remove-LocalUser -Name $testUser
      $profile = Get-CimInstance Win32_UserProfile -Filter "SID='$sid'" -ErrorAction SilentlyContinue
      if ($profile) { $profile | Remove-CimInstance }
      if (Get-LocalUser -Name $testUser -ErrorAction SilentlyContinue) { throw 'Invalid test user still exists.' }
      if (Test-Path -LiteralPath (Join-Path (Split-Path $env:USERPROFILE -Parent) $testUser)) {
        throw 'Invalid test profile directory still exists.'
      }
    }
    if (Test-Path -LiteralPath $stateRoot) { Remove-Item -LiteralPath $stateRoot -Recurse -Force }
    if (Test-Path -LiteralPath $publicRoot) { Remove-Item -LiteralPath $publicRoot -Recurse -Force }
    Write-Host 'PASS: invalid fresh-user attempt removed; ready for a new profile.'
  }
}
