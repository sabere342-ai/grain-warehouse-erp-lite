param(
  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$releaseDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
$exePath = Join-Path $releaseDir "grain_warehouse_erp_lite.exe"

if (-not (Test-Path -LiteralPath $exePath)) {
  throw "Windows release executable was not found. Run: flutter.bat build windows --release"
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = "delivery\grain_warehouse_erp_lite_branded_delivery_$stamp"
}

$outputPath = Join-Path $projectRoot $OutputRoot
if (Test-Path -LiteralPath $outputPath) {
  $outputPath = Join-Path $projectRoot "delivery\grain_warehouse_erp_lite_branded_delivery_$stamp"
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
  "docs\PHASE-37B-CUSTOMER-OPENING-BALANCE.md",
  "docs\PHASE-37C-REPORTS-TRUTHFULNESS-DAILY-CASH.md",
  "docs\PHASE-59-SALE-CANCELLATION-CUSTOMER-LEDGER-SYMMETRY.md",
  "docs\PHASE-60-FINAL-PRODUCTION-CANDIDATE-PACKAGING.md",
  "docs\PHASE-64-OWNER-DASHBOARD-ALERTS.md",
  "docs\PHASE-65-PILOT-DELIVERY-REFRESH-AFTER-OWNER-DASHBOARD-ALERTS.md",
  "docs\PHASE-67-NAVIGATION-THEME-BRANDING.md",
  "docs\PHASE-68-BUSINESS-LOGO-INVOICE-WINDOWS-ICON-BRANDING.md",
  "docs\PHASE-68A-WINDOWS-ICON-TOOL-VERIFICATION-FIXES.md",
  "docs\PHASE-69-FINAL-BRANDED-DELIVERY-PACKAGE-REFRESH.md"
)
foreach ($doc in $docs) {
  Copy-Item -LiteralPath (Join-Path $projectRoot $doc) -Destination $docsOutput -Force
}

$readme = @"
برنامج إدارة مخزن الحبوب - نسخة ماركة مسجلة

الهدف من النسخة:
هذه نسخة مخصصة للتجربة العملية على جهاز ويندوز واحد. الهدف هو اختبار البيع والشراء والمخزون والتقارير والنسخ الاحتياطي قبل اعتماد أي تطوير إضافي.

طريقة التشغيل:
1. افتح مجلد Release.
2. شغل الملف grain_warehouse_erp_lite.exe.
3. انتظر حتى تظهر شاشة البرنامج.

أول خطوة:
إذا كانت هذه أول مرة تستخدم البرنامج، أنشئ حساب المالك من الشاشة الأولى.
إذا كان الحساب موجودا بالفعل، سجل الدخول بالبيانات المتفق عليها.

اسم المنشأة والشعار:
- يمكنك إعداد اسم المنشأة وشعارها من شاشة الإعدادات.
- الشعار يظهر في أعلى الشاشة الرئيسية وفي الفواتير المطبوعة.
- يُقبل شعار بصيغة PNG أو JPEG فقط.
- يمكنك إزالة الشعار في أي وقت من شاشة الإعدادات.

نسخ احتياطي واسترجاع:
- اعمل نسخة احتياطية في نهاية كل يوم، واحفظها في مكان واضح. يفضل نسخها على فلاشة أو مكان خارجي.
- النسخ الاحتياطي من الإصدار الثالث يحتوي على بيانات المنشأة والشعار بشكل اختياري.
- يمكنك استرجاع نسخ احتياطية من الإصدارات القديمة (1 و 2 و 3).
- الاسترجاع يتم فقط إلى نظام فارغ بعد فحص النسخة من شاشة المعاينة.

تنبيه المحاسبة والمخزون:
- رصيد المخزون يعتمد على حركات المخزون المسجلة.
- رصيد العميل يعتمد على قيود حساب العميل.
- رصيد المورد يعتمد على قيود حساب المورد.
- التقارير للقراءة والمراجعة ولا تعدل البيانات الأصلية.
- الجرد وتسويات المخزون لا تغير أرصدة العملاء أو الموردين.
- إلغاء البيع يعكس أثر رصيد العميل تلقائيا ولا يحذف الحركة القديمة.

الوظائف المتوفرة حاليا:
- بيع نقدي.
- بيع آجل على عميل.
- إلغاء بيع مع أثر عكسي على رصيد العميل.
- تحصيل من العملاء وتحديث الرصيد.
- كشف حساب العميل.
- شراء من موردين مربوط بالمورد.
- حسابات الموردين: كشف حساب، تسجيل دفعة، رصيد افتتاحي.
- حسابات العملاء: رصيد افتتاحي (ديون سابقة).
- عرض رصيد المورد المستحق على بطاقة المورد.
- إضافة رصيد افتتاحي للمخزون (كجم / طن).
- إضافة رصيد افتتاحي لحسابات العملاء (ديون سابقة).
- لوحة الرئيسية تعرض: مبيعات اليوم (نقدي/آجل)، نقد داخل اليوم، المستحق على العملاء، المستحق للموردين، رصيد النقدية التراكمي، المخزون.
- التقارير اليومية تشمل قسم "حركة النقد اليوم" مع تفصيل النقد الداخل (مبيعات نقدية + تحصيلات) والنقد الخارج (مدفوعات موردين + مصروفات) وصافي حركة النقد.
- التقارير توضح الفرق بين صافي حركة المستندات ورصيد النقدية، وتفصل بين أرصدة العملاء والموردين.
- إدارة المخزون.
- نسخ احتياطي واسترجاع (متوافق مع النسخ القديمة).
- إعداد اسم المنشأة وشعارها (PNG/JPEG).

ما زال غير متوفر حاليا:
- الدفعات المقدمة أو الرصيد السالب غير مدعوم - الرصيد لا يقل عن صفر.
- لا توجد مزامنة سحابية في هذه النسخة.
- لا يوجد تطبيق موبايل في هذه النسخة.
- لا توجد مزامنة حية بين أكثر من جهاز في هذه النسخة.
- لا تستخدم نفس البيانات على أكثر من جهاز كأنها مزامنة مباشرة.
- جاهزية الانتقال السحابي موثقة للمستقبل فقط، ولم يتم تفعيل السحابة.

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
