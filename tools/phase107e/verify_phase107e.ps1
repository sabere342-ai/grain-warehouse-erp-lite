[CmdletBinding()]
param(
  [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $EvidenceRoot) {
  $EvidenceRoot = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path 'docs\phase-107e\evidence'
}

function Require([bool]$Condition, [string]$Gate) {
  if (-not $Condition) { throw "FAIL: $Gate" }
  Write-Host "PASS: $Gate"
}

function Read-Evidence([string]$Name) {
  $path = Join-Path $EvidenceRoot $Name
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing evidence: $Name" }
  return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

$identity = Read-Evidence '01-baseline-and-identity.json'
$prestate = Read-Evidence '02-fresh-profile-prestate.json'
$install = Read-Evidence '03-install-result.json'
$first = Read-Evidence '04-first-launch-process.json'
$route = Read-Evidence '05-first-route-and-setup.json'
$smoke = Read-Evidence '06-main-runtime-smoke.json'
$firstClose = Read-Evidence '07-first-clean-close.json'
$persistence = Read-Evidence '08-first-session-persistence.json'
$second = Read-Evidence '09-second-launch-process.json'
$secondClose = Read-Evidence '10-second-clean-close.json'
$secondPersistence = Read-Evidence '11-second-session-persistence.json'

$runIds = @(@($identity, $prestate, $install, $first, $route, $smoke, $firstClose,
  $persistence, $second, $secondClose, $secondPersistence) | ForEach-Object { [string]$_.runId } | Select-Object -Unique)
Require ($runIds.Count -eq 1 -and $runIds[0] -match '^\d{8}-\d{6}$') 'E1 one canonical run id'
Require ($identity.baselineCommit -ceq 'd2103102f68ff7dbc1dec3ca5fc4b02d054be912' -and $identity.startingTreeClean) 'E2 governed clean baseline'
Require (-not $identity.profileExistedBeforeUserCreation -and -not $identity.profileExistedBeforeInitialization -and $prestate.sid -ceq $identity.sid) 'E3 genuinely new Windows profile and SID'
Require (-not $prestate.applicationSupport.exists -and -not $prestate.preferences.exists -and -not $prestate.backupDirectory.exists -and -not $prestate.database.exists) 'E4 no prior application data'
Require (-not $prestate.installDirectory.exists -and -not $prestate.uninstallRegistration.exists -and -not $prestate.startMenuShortcut.exists -and $prestate.runningProcessCount -eq 0) 'E5 no prior installation'
Require ($identity.artifactSize -eq 14998748 -and $identity.artifactSha256 -ceq 'ab67d04e205a78aa2d6e087ffd6f63655a80e5e2de10d7a603f959b073098659' -and $identity.publicCopySha256 -ceq $identity.artifactSha256) 'E6 exact frozen installer identity'
Require ($install.exitCode -eq 0 -and $install.installedExecutable.exists -and $install.installedManifest.exists -and $install.uninstallRegistration.exists) 'E7 installation and registered payload'
$expectedWindowTitle = -join @([char]0x063A, [char]0x0644, [char]0x0627, [char]0x0644)
Require (-not $first.immediateExit -and $first.mainWindowHandle -ne 0 -and $first.mainWindowTitle -ceq $expectedWindowTitle) 'E8 first process and visible window'
Require ($route.expectedRoute -ceq 'first-owner-setup' -and $route.actualRoute -ceq 'first-owner-setup' -and $route.visibleWindow -and $route.setupSucceeded -and $route.postSetupRoute -ceq 'dashboard') 'E9 canonical fresh route and owner bootstrap'
Require ($route.secretExposed -eq $false -and $route.ownerPhone -ceq '01070000107') 'E10 deterministic setup without secret exposure'
Require ($smoke.dashboard -and $smoke.products -and $smoke.inventory -and $smoke.sales -and $smoke.settings -and $smoke.noCrash) 'E11 basic installed runtime smoke'
Require ($firstClose.cleanClose -and $firstClose.processCount -ge 1) 'E12 first clean close'
Require ($persistence.database.exists -and $persistence.database.size -gt 0) 'E13 persisted SQLite state exists'
Require ($secondPersistence.installedPayloadVerification.passed -and $secondPersistence.installedPayloadVerification.declaredCount -eq 21) 'E13b all installed payload files match the governed manifest'
Require (-not $second.immediateExit -and $second.mainWindowHandle -ne 0 -and $second.mainWindowTitle -ceq $expectedWindowTitle) 'E14 second process and visible window'
Require ($route.secondLaunchRoute -ceq 'login' -and $route.secondLoginSucceeded -and $route.secondPostLoginRoute -ceq 'dashboard') 'E15 second-launch authentication and persistence'
Require ($secondClose.cleanClose -and $secondPersistence.database.exists -and $secondPersistence.database.sha256 -ceq $persistence.database.sha256) 'E16 clean second close and stable persisted data'
Require ($first.workingDirectory -notmatch '(?i)\\dev\\|grain-warehouse-erp-lite' -and -not $first.sourceCheckoutUsed -and $first.executablePath -match '(?i)\\AppData\\Local\\Programs\\GrainWarehouseERPLite\\') 'E17 no developer environment dependency'
Require ($persistence.database.path -match '(?i)\\Users\\CodexGhalal107E\\AppData\\Roaming\\Grala\\Grala\\grain_warehouse_erp\.sqlite3$') 'E18 correct user-scoped data path'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$textFiles = @(
  Get-ChildItem -LiteralPath (Split-Path $EvidenceRoot -Parent), (Join-Path $projectRoot 'tools\phase107e') -Recurse -File |
    Where-Object { $_.Extension -in @('.json', '.txt', '.md', '.ps1') }
)
$joined = ($textFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join "`n"
$leakPatterns = @(
  '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
  '(?i)(?:api[_-]?key|token|password|credential)\s*[:=]\s*["''][^"'']+["'']',
  '(?i)C:\\Users\\saber(?:\\|\b)',
  '(?i)C:\\dev\\'
)
foreach ($pattern in $leakPatterns) { Require ($joined -notmatch $pattern) "E19 leak scan: $pattern" }

$summary = @(
  'PHASE 107E FRESH-PROFILE RUNTIME ACCEPTANCE',
  "Run ID: $($runIds[0])",
  'E1-E19: PASS',
  'Outcome: Outcome A - FULL SUCCESS',
  'Risk decision: R1-004 CLOSED; R1-005 and R1-006 unchanged'
) -join [Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $EvidenceRoot 'VERIFICATION-SUMMARY.txt'), $summary, [Text.UTF8Encoding]::new($false))
Write-Host 'PASS: Phase 107E E1-E19 verification complete.'
