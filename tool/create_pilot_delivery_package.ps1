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
  "docs\PILOT-RELEASE-NOTES-AR.md",
  "docs\PILOT-FEEDBACK-FORM-AR.md",
  "docs\PHASE-26-FIRST-CUSTOMER-TRIAL-START-CHECKLIST-AR.md",
  "docs\CUSTOMER-TRIAL-DAILY-LOG-AR.md",
  "docs\PILOT-ISSUE-LOG.md",
  "docs\PHASE-24-PILOT-FIELD-TRIAL-RUNBOOK-AR.md",
  "docs\CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md",
  "docs\RELEASE-NOTES-AR.md",
  "docs\PHASE-22-PILOT-DELIVERY-CHECKLIST.md",
  "docs\PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md",
  "docs\PHASE-37A-ACCOUNTING-CONTINUITY-OPENING-BALANCES.md",
  "docs\PHASE-37B-CUSTOMER-OPENING-BALANCE.md"
)
foreach ($doc in $docs) {
  Copy-Item -LiteralPath (Join-Path $projectRoot $doc) -Destination $docsOutput -Force
}

$readme = @"
برنامج إدارة مخزن الحبوب - نسخة تجريبية محلية

الهدف من النسخة:
هذه نسخة مخصصة للتجربة العملية على جهاز ويندوز واحد. الهدف هو اختبار البيع والشراء والمخزون والتقارير والنسخ الاحتياطي قبل اعتماد أي تطوير إضافي.

طريقة التشغيل:
1. افتح مجلد Release.
2. شغل الملف grain_warehouse_erp_lite.exe.
3. انتظر حتى تظهر شاشة البرنامج.

أول خطوة:
إذا كانت هذه أول مرة تستخدم البرنامج، أنشئ حساب المالك من الشاشة الأولى.
إذا كان الحساب موجودا بالفعل، سجل الدخول بالبيانات المتفق عليها.

تنبيه مهم:
اعمل نسخة احتياطية بانتظام، خصوصا بعد إدخال بيانات مهمة أو قبل أي تجربة استرجاع.
الاسترجاع يتم فقط إلى نظام فارغ بعد فحص النسخة من شاشة المعاينة.

الوظائف المتوفرة حاليا:
- بيع نقدي.
- بيع آجل على عميل.
- تحصيل من العملاء وتحديث الرصيد.
- كشف حساب العميل.
- شراء من موردين مربوط بالمورد.
- حسابات الموردين: كشف حساب، تسجيل دفعة، رصيد افتتاحي.
- حسابات العملاء: رصيد افتتاحي (ديون سابقة).
- عرض رصيد المورد المستحق على بطاقة المورد.
- إضافة رصيد افتتاحي للمخزون (كجم / طن).
- إضافة رصيد افتتاحي لحسابات العملاء (ديون سابقة).
- التقارير اليومية تشمل مدفوعات الموردين وأرصدة الموردين المستحقة.
- لوحة الرئيسية تعرض مبيعات اليوم ورصيد النقدية مع شرح طريقة الحساب والمخزون.
- التقارير توضح الفرق بين صافي حركة المستندات ورصيد النقدية، وتفصل بين أرصدة العملاء والموردين.
- إدارة المخزون.
- نسخ احتياطي واسترجاع (متوافق مع النسخ القديمة).

ما زال غير متوفر حاليا:
- الدفعات المقدمة أو الرصيد السالب غير مدعوم - الرصيد لا يقل عن صفر.
- لا توجد مزامنة سحابية في هذه النسخة.

طريقة إبلاغ المطور بأي مشكلة:
- اكتب وصف المشكلة ببساطة.
- أرسل صورة إن أمكن.
- اذكر تاريخ العملية.
- اذكر اسم الصنف أو رقم/اسم الفاتورة إن وجد.
- اذكر الخطوات التي حدثت قبل ظهور المشكلة.
"@
Set-Content -LiteralPath (Join-Path $outputPath "README-AR.txt") -Value $readme -Encoding utf8

Write-Host "Pilot delivery folder created:" $outputPath
Write-Host "Do not commit delivery artifacts. The delivery/ folder should stay ignored by Git."
