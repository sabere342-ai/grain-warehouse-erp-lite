# خارطة ترحيل شاشات غلال بعد Phase 83

Phase 83 أغلقت الجرد والأساس والعينة المرجعية فقط. الترحيل التالي يجب أن يكون على موجات صغيرة، مع بوابات الانحدار الخاصة بكل مجال.

## ما رُحّل في Phase 83

- Login.
- Dashboard وApplication Shell.
- قائمة وتفاصيل طلبات الموافقة.
- الحسابات المالية الأساسية.
- قائمة الموردين والبحث.
- إعدادات المظهر.

## الموجات المؤجلة

### الموجة 1 — المعاملات عالية الخطورة

- Sales، Purchases، Expenses، Supplier/Customer payments وadvances.
- الهدف: form/dialog primitives، ترتيب الأفعال، تحذير unsaved changes، ودقة رسائل Pending/Executed.
- البوابات: payment routing، Phase 82 approvals، reversals، inventory، actor identity.

### الموجة 2 — المخزون والأطراف

- Products، Customers، Inventory، Stock take، adjustment history، statements.
- الهدف: search/filter موحد، responsive lists/tables، حالات no-data/no-results.
- البوابات: stock invariants، balances، document history.

### الموجة 3 — التقارير والإغلاق

- Financial reports hub وكل تقارير Phase 79، Daily report، Closing/Reconciliation.
- الهدف: filter bars وfinancial value/status primitives وجداول متجاوبة.
- البوابات: Phase 79 calculations، Phase 80 closing، exports/printing.

### الموجة 4 — الإعدادات والاسترجاع والتدقيق

- Business identity editor، Backup/Restore، data wipe، audit logs، help.
- الهدف: destructive confirmations، progress/error states، keyboard/focus.
- البوابات: Backup v1–v7، atomic restore، logo failure behavior.

### الموجة 5 — الطباعة والمعاينة

- فواتير البيع والشراء وكشوف العملاء والموردين والتقرير اليومي.
- الهدف: فصل layout الشاشة عن layout الطباعة واختبار العربية والخطوط وWindows/PDF.

## قواعد كل موجة

- لا Schema أو عقد مالي لأغراض بصرية.
- لا حذف لشاشة أو إخفاء وظيفة قائمة.
- لا تغيير لحسابات التقارير أو حالة الموافقات.
- كل موجة تبدأ من صفوف Gap Matrix ذات الصلة وتنتهي باختبارات viewport وRTL والمجال ثم full suite وWindows build.
- لا يوصف المشروع بأنه «أعيد تصميمه بالكامل» حتى تنتهي جميع الموجات وتُراجع الشاشات الفعلية مرة أخرى.
