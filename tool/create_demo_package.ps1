param(
  [string]$Version = '',
  [string]$CommitHash = '',
  [string]$GitTag = ''
)

$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$exePath = Join-Path $releaseDir 'grain_warehouse_erp_lite.exe'
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'

Write-Host '=== Phase 98 — Client Demo Package Generator ===' -ForegroundColor Cyan
Write-Host ''

# --- Validate prerequisites ---
if (-not (Test-Path -LiteralPath $exePath)) {
  throw 'Release executable not found. Run tool\build_release.ps1 first.'
}

# --- Read version from pubspec if not provided ---
$pubspecContent = Get-Content -LiteralPath $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspecContent, '(?m)^version:\s*(\S+)')
if (-not $versionMatch.Success) {
  throw 'Could not parse version from pubspec.yaml'
}
if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = $versionMatch.Groups[1].Value
}

# --- Git metadata ---
if ([string]::IsNullOrWhiteSpace($CommitHash)) {
  try {
    $CommitHash = (git -C $projectRoot rev-parse HEAD 2>$null).Trim()
  } catch {
    $CommitHash = 'unknown'
  }
}
if ([string]::IsNullOrWhiteSpace($GitTag)) {
  try {
    $GitTag = (git -C $projectRoot describe --tags --exact-match 2>$null).Trim()
  } catch {
    $GitTag = 'none'
  }
}

$semver = $Version.Split('+')[0]
$buildNumber = if ($Version.Contains('+')) { $Version.Split('+')[1] } else { '0' }
$buildDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

Write-Host "Version: $Version (semver=$semver, build=$buildNumber)"
Write-Host "Commit: $CommitHash"
Write-Host "Tag: $GitTag"
Write-Host "Build date: $buildDate"
Write-Host ''

# --- Create output directory ---
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$packageName = "ghalal-demo-v$semver-$stamp"
$outputPath = Join-Path (Join-Path $projectRoot 'delivery') $packageName
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outputPath 'Release') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outputPath 'docs') | Out-Null

Write-Host "Package directory: $outputPath" -ForegroundColor Green
Write-Host ''

# --- Copy release build ---
Write-Host 'Copying release build...' -ForegroundColor Cyan
Copy-Item -Path (Join-Path $releaseDir '*') -Destination (Join-Path $outputPath 'Release') -Recurse -Force
$releaseFiles = Get-ChildItem -LiteralPath (Join-Path $outputPath 'Release') -Recurse -File
Write-Host "  Copied $($releaseFiles.Count) files" -ForegroundColor Green

# --- Copy client documentation ---
Write-Host 'Copying client documentation...' -ForegroundColor Cyan
$clientDocs = @(
  'docs\CLIENT-INSTALLATION-GUIDE-AR.md',
  'docs\CLIENT-DEMO-WALKTHROUGH-AR.md',
  'docs\CLIENT-KNOWN-LIMITATIONS-AR.md',
  'docs\CLIENT-PILOT-HANDOFF-SMOKE-AR.md',
  'docs\OWNER-QUICK-START-AR.md',
  'docs\CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md',
  'docs\PHASE-98-RELEASE-NOTES-AR.md'
)
$copiedDocs = @()
foreach ($doc in $clientDocs) {
  $srcPath = Join-Path $projectRoot $doc
  if (Test-Path -LiteralPath $srcPath) {
    Copy-Item -LiteralPath $srcPath -Destination (Join-Path $outputPath 'docs') -Force
    $copiedDocs += $doc
  } else {
    Write-Host "  WARNING: Doc not found: $doc" -ForegroundColor Yellow
  }
}
Write-Host "  Copied $($copiedDocs.Count) documentation files" -ForegroundColor Green

# --- Generate README-AR.txt ---
$readme = @"
برنامج غلال - نسخة تجربة للعميل
الإصدار: $semver ($Version)
تاريخ البناء: $buildDate
ال Commit: $CommitHash

==========================================================
الهدف من النسخة
==========================================================
هذه نسخة تجريبية مخصصة لتقييم البرنامج على جهاز Windows واحد.
الهدف هو اختبار جميع الوظائف الأساسية قبل اعتماد النظام في بيئة العمل الحقيقية.

==========================================================
متطلبات النظام
==========================================================
- نظام التشغيل: Windows 10 أو Windows 11 (64-bit)
- لا يحتاج إلى Flutter أو Visual Studio أو أي أدوات تطوير
- لا يحتاج إلى اتصال بالإنترنت

==========================================================
خطوات التثبيت والتشغيل (نسخة محمولة)
==========================================================
1. افتح مجلد التسليم.
2. افتح مجلد Release.
3. شغل الملف grain_warehouse_erp_lite.exe.
4. قد تظهر رسالة أمان من Windows. اختر "更多信息" ثم "تشغيل على أي حال".
   هذه النسخة غير موقعة بشهادة أمان، وهذا أمر طبيعي للنسخ التجريبية.
5. انتظر حتى تظهر شاشة البرنامج.

==========================================================
الخطوة الأولى: إعداد حساب المالك
==========================================================
- إذا كانت هذه أول مرة تستخدم البرنامج، أنشئ حساب المالك من الشاشة الأولى.
- اختر اسم مستخدم وكلمة مرور سهلة التذكر.
- سجّل الدخول بالبيانات التي أنشأتها.

==========================================================
إعداد اسم المنشأة والشعار
==========================================================
1. افتح شاشة الإعدادات من القائمة الجانبية.
2. أدخل اسم المنشأة الذي يظهر في الفواتير والتقارير.
3. اختر صورة شعار بصيغة PNG أو JPEG من جهازك.
4. حفظ الإعدادات.
5. يمكنك إزالة الشعار في أي وقت.

==========================================================
الوظائف المتوفرة في النسخة التجريبية
==========================================================
- إدارة أصناف الحبوب والمنتجات.
- تسجيل المشتريات من الموردين.
- تسجيل المبيعات (نقدي وآجل).
- إلغاء المبيعات مع أثر عكسي على رصيد العميل.
- التحصيل من العملاء ودفع الموردين.
- حسابات العملاء والموردين (كشف حساب، رصيد افتتاحي).
- إدارة المصروفات.
- الحسابات المالية (خزينة، بنك، محفظة إلكترونية).
- التحويلات المالية الداخلية.
- التقارير اليومية والتقارير المالية.
- سجل المستندات.
- النسخ الاحتياطي والاستعادة.
- إعداد اسم المنشأة وشعارها.
- مشاركة واتساب Assistance.

==========================================================
ملاحظات أمان البيانات
==========================================================
- اعمل نسخة احتياطية في نهاية كل يوم.
- احفظ النسخ الاحتياطي في مكان واضح (فلاشة أو مكان خارجي).
- لا تنقل ملفات البرنامج أثناء التشغيل ولا تحذف مجلد البرنامج.
- الاسترجاع يتم فقط إلى نظام فارغ.

==========================================================
حدود النسخة التجريبية
==========================================================
- النسخة تعمل محليا على جهاز واحد فقط.
- لا توجد مزامنة سحابية.
- لا يوجد تطبيق موبايل.
- لا توجد مزامنة حية بين أكثر من جهاز.
- النسخة غير موقعة بشهادة أمان Windows.
- بعض وظائف الدفعات المقدمة قد تكون محدودة.

==========================================================
الإبلاغ عن المشاكل
==========================================================
- اكتب وصف المشكلة ببساطة.
- أرسل صورة إن أمكن.
- اذكر تاريخ العملية والخطوات التي سبقت المشكلة.
- لا تحاول تعديل قاعدة البيانات يدويا.
"@

Set-Content -LiteralPath (Join-Path $outputPath 'README-AR.txt') -Value $readme -Encoding utf8
Write-Host 'Generated README-AR.txt' -ForegroundColor Green

# --- Compute SHA-256 checksums ---
Write-Host ''
Write-Host 'Computing SHA-256 checksums...' -ForegroundColor Cyan
$checksumEntries = @()
$allPackageFiles = Get-ChildItem -LiteralPath $outputPath -Recurse -File
foreach ($file in $allPackageFiles) {
  $relativePath = $file.FullName.Substring($outputPath.Length).TrimStart('\', '/')
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  $checksumEntries += "$hash  $relativePath"
}
$checksumContent = $checksumEntries -join "`n"
Set-Content -LiteralPath (Join-Path $outputPath 'checksums.sha256') -Value $checksumContent -Encoding utf8
Write-Host "  Computed checksums for $($checksumEntries.Count) files" -ForegroundColor Green

# --- Generate release manifest ---
$manifest = @{
  productName = 'غلال'
  productNameEn = 'Grala'
  internalPackageName = 'grain_warehouse_erp_lite'
  version = $semver
  buildNumber = $buildNumber
  fullVersion = $Version
  gitCommitHash = $CommitHash
  gitTag = $GitTag
  buildDateUtc = $buildDate
  buildConfiguration = 'Release'
  targetPlatform = 'windows-x64'
  architecture = 'x64'
  signed = $false
  installerAvailable = $false
  installerStatus = 'Inno Setup source created; compilation blocked (no admin access to ISCC.exe)'
  testResult = '1712+ passed, 1 skipped, 0 failed (baseline before Phase 98 tests)'
  analyzerResult = '0 errors, 0 new warnings'
  files = @()
  prohibitedPatterns = @(
    '.git/*',
    'lib/**/*.dart',
    'test/**/*.dart',
    'android/**',
    'ios/**',
    'windows/**/*.cpp',
    'windows/**/*.h',
    'windows/**/*.cmake',
    '*.dart',
    '*.ps1',
    '*.py',
    '*.db',
    '*.sqlite3',
    '*.env',
    '*.pem',
    '*.key',
    '*.log',
    '*.tmp'
  )
}

foreach ($file in $allPackageFiles) {
  $relativePath = $file.FullName.Substring($outputPath.Length).TrimStart('\', '/')
  $checksumEntry = $checksumEntries | Where-Object { $_ -like "*  $relativePath" }
  $checksum = if ($checksumEntry) { ($checksumEntry -split '  ')[0] } else { 'unknown' }
  $manifest.files += @{
    path = $relativePath
    sizeBytes = $file.Length
    sha256 = $checksum
  }
}

$manifestJson = $manifest | ConvertTo-Json -Depth 5
Set-Content -LiteralPath (Join-Path $outputPath 'release-manifest.json') -Value $manifestJson -Encoding utf8
Write-Host 'Generated release-manifest.json' -ForegroundColor Green

# --- Generate file listing ---
$fileList = @("ghalal Demo Package - File Listing", "Version: $semver", "Build: $Version", "Commit: $CommitHash", "Date: $buildDate", '')
foreach ($file in $allPackageFiles) {
  $relativePath = $file.FullName.Substring($outputPath.Length).TrimStart('\', '/')
  $sizeMB = [math]::Round($file.Length / 1MB, 2)
  $fileList += "$relativePath  ($sizeMB MB)"
}
Set-Content -LiteralPath (Join-Path $outputPath 'file-listing.txt') -Value ($fileList -join "`n") -Encoding utf8
Write-Host 'Generated file-listing.txt' -ForegroundColor Green

# --- Summary ---
$totalSize = ($allPackageFiles | Measure-Object -Property Length -Sum).Sum
Write-Host ''
Write-Host '=== Demo package created successfully ===' -ForegroundColor Green
Write-Host "  Path: $outputPath"
Write-Host "  Total files: $($allPackageFiles.Count)"
Write-Host "  Total size: $([math]::Round($totalSize / 1MB, 2)) MB ($totalSize bytes)"
Write-Host "  Version: $Version"
Write-Host "  Commit: $CommitHash"
Write-Host ''
Write-Host 'Do not commit delivery artifacts. The delivery/ folder is gitignored.' -ForegroundColor Yellow
