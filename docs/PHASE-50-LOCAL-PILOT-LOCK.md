# Phase 50 — Local Pilot Lock

## Phase purpose
Phase 50 locks the current local Windows pilot for the existing client. It documents what is ready for field use and what is intentionally excluded from this pilot.

This phase does not add cloud sync, mobile app support, SaaS features, automatic backend messaging, or multi-device live sync.

## Baseline
- Starting commit: 4d6c1ef
- Starting tag: phase-49c-post-feature-delivery-refresh
- Existing delivery package path: delivery/grain_warehouse_erp_lite_post_feature_delivery_20260709-212904/
- Production code changed in this phase: no
- Schema changed in this phase: no

## Locked local pilot scope
The local pilot includes:
- Product catalog
- Purchases
- Sales
- Customers
- Suppliers
- Customer balances
- Supplier balances
- Inventory quantities
- Inventory movement history
- Stock-taking workflow
- Stock adjustment variance report
- Document history
- Daily reports
- Existing PDF/export behavior
- Existing WhatsApp assisted sharing behavior
- Backup/restore with current safety restrictions

## Explicitly not promised in this pilot
The following are not part of Phase 50:
- No automatic cloud sync
- No Android/mobile app in this package
- No multi-device live sync
- No automatic WhatsApp sending
- No WhatsApp Business API
- No hidden backend messaging
- No automatic PDF attachment to WhatsApp
- No PDF/export for stock adjustment report yet
- No invented before/after stock balances for old stock movements
- No SaaS or multi-client dashboard in this phase

## Owner pilot checklist
- فتح البرنامج من نسخة التسليم
- إنشاء أو مراجعة الأصناف
- تسجيل مشتريات
- تسجيل مبيعات
- مراجعة المخزون وكميات الأصناف
- مراجعة حركة الصنف في المخزون
- تسجيل عميل ومراجعة رصيده
- تسجيل مورد ومراجعة رصيده
- تسجيل تحصيل من عميل
- تسجيل دفعة لمورد إن كانت متاحة
- مراجعة التقرير اليومي
- تجربة جرد المخزون
- مراجعة تقرير تسويات المخزون
- تجربة PDF/export للوظائف المدعومة فقط
- تجربة مشاركة واتساب المساعدة للوظائف المدعومة فقط
- عمل نسخة احتياطية
- التأكد أن الاستعادة لا تتم إلا حسب القيود الآمنة الحالية

## Stop conditions
أوقف التجربة وأبلغ المطور إذا حدث أي مما يلي:
- أصبحت كمية المخزون سالبة بشكل غير متوقع
- لم يطابق رصيد العميل المستندات المصدرية
- لم يطابق رصيد المورد المستندات المصدرية
- لم تطابق إجماليات التقرير اليومي المبيعات/المشتريات/المدفوعات/المصروفات المصدرية
- تاريخ حركة المخزون يتعارض مع كمية الصنف
- الإلغاء لا ينشئ سلوك عكسي صحيح
- النسخ الاحتياطي/الاستعادة تغيّر المخزون أو الأرصدة أو المستندات بشكل غير متوقع
- ظهرت صفحة مرئية غير واقعية أو فارغة أو مضللة أو غير وظيفية
- تضمّن أي حزمة عميل ملفات مصدر أو ملفات مطور داخلية

## Deferred items
- Cloud/mobile migration is planned later, not part of Phase 50.
- Rich stock adjustment PDF/export needs reliable before/after stock balances first.
- Multi-device sync needs a future sync contract and conflict rules first.
