from pathlib import Path
import shutil
import datetime
import os

project_root = Path(__file__).resolve().parent.parent
release_dir = project_root / "build" / "windows" / "x64" / "runner" / "Release"
exe_path = release_dir / "grain_warehouse_erp_lite.exe"
if not exe_path.exists():
    raise SystemExit("Release EXE not found")

stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
package_name = f"grain_warehouse_erp_lite_post_feature_delivery_{stamp}"
output_path = project_root / "delivery" / package_name
output_path.mkdir(parents=True, exist_ok=True)
(release_out := output_path / "Release").mkdir(parents=True, exist_ok=True)
(docs_out := output_path / "docs").mkdir(parents=True, exist_ok=True)

for item in release_dir.iterdir():
    if item.is_file():
        shutil.copy2(item, release_out / item.name)
    elif item.is_dir():
        shutil.copytree(item, release_out / item.name, dirs_exist_ok=True)

for rel in [
    "docs/OWNER-QUICK-START-AR.md",
    "docs/PILOT-RELEASE-NOTES-AR.md",
    "docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md",
    "docs/CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md",
    "docs/CLIENT-PILOT-FEEDBACK-FORM-AR.md",
    "docs/CLIENT-PILOT-ISSUE-LOG-AR.md",
]:
    src = project_root / rel
    if src.exists():
        shutil.copy2(src, docs_out / src.name)

readme = """برنامج إدارة مخزن الحبوب - نسخة محدثة بعد مراحل 49A و49B

الهدف من النسخة:
هذه نسخة محلية مخصصة للتسليم للعملاء بعد استكمال جرد المخزون وتقرير تسويات المخزون. النسخة تركز على تشغيل البرنامج على جهاز ويندوز واحد مع الوثائق العربية الواضحة.

طريقة التشغيل:
1. افتح مجلد Release.
2. شغل الملف grain_warehouse_erp_lite.exe.
3. انتظر حتى تظهر شاشة البرنامج.

الوظائف المتوفرة حاليا:
- إدارة أصناف الحبوب والمنتجات الأساسية.
- تسجيل المشتريات والمبيعات.
- عرض المخزون وحركاته.
- جرد المخزون: إدخال الكمية الفعلية وحساب الفرق باستخدام حركات تسوية المخزون عند وجود فرق.
- تقرير تسويات المخزون: مراجعة الزيادات والنقص اليدوي الناتج عن تسويات المخزون بشكل قراءة فقط.
- معاينة المستندات والتقارير الأساسية.
- نسخة احتياطية واستعادة على نظام فارغ فقط.

ملاحظات مهمة:
- تقرير تسويات المخزون للقراءة فقط ولا يعدّل الكميات أو أرصدة العملاء أو الموردين.
- لا يوجد تصدير PDF لتقرير التسويات في هذه النسخة لأن بيانات الحركة الحالية لا تخزن أرصدة قبل/بعد الحركة بشكل موثوق.
- مشاركة واتساب تبقى مساعدة فقط حيث كانت متاحة سابقا، ولا يتم الإرسال التلقائي.

طريقة الإبلاغ عن أي مشكلة:
- اكتب وصف المشكلة ببساطة.
- أرسل صورة إن أمكن.
- اذكر التاريخ والخطوات التي سبقت المشكلة.
"""
(output_path / "README-AR.txt").write_text(readme, encoding="utf-8")
print(output_path)
