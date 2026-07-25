# دليل الأدلة — جلسة العرض التجريبي لبرنامج غلال

> المرحلة: 100 | الإصدار: 1.0.0+1 | هذا المستند يسرد جميع الأدلة المطلوبة والمتاحة لتوثيق جلسة العرض الفعلية.

---

## معلومات الجلسة

| الحقل | القيمة |
|-------|--------|
| تاريخ الجلسة | PENDING CLIENT SESSION |
| إصدار الحزمة | 1.0.0+1 |
| مسار الحزمة | `delivery/ghalal-demo-v1.0.0-20260725-201405` |

---

## الأدلة المطلوبة

| # | نوع الدليل | الوصف | الحالة | المرجع |
|---|-----------|-------|--------|--------|
| 1 | سجل الجلسة | سجل كامل لجميع خطوات الجلسة | PENDING CLIENT SESSION | CLIENT-DEMO-SESSION-RECORD-AR.md |
| 2 | قائمة القبول | قائمة تحقق موقّعة من العميل | PENDING CLIENT SESSION | CLIENT-DEMO-ACCEPTANCE-CHECKLIST-AR.md |
| 3 | سجل الملاحظات | جميع الملاحظات والأعطال | PENDING CLIENT SESSION | CLIENT-DEMO-FINDINGS-REGISTER-AR.md |
| 4 | صور الشاشة | صور للشاشات الرئيسية أثناء الجلسة | PENDING CLIENT SESSION | PENDING CLIENT SESSION |
| 5 | سجل المشاكل | أي مشاكل وقعت أثناء الجلسة | PENDING CLIENT SESSION | OWNER-TRIAL-INCIDENT-LOG-AR.md |
| 6 | Checksums الحزمة | التحقق من سلامة الحزمة المستخدمة | PASS | checksums.sha256 |
| 7 | دليل المشغّل | الدليل المستخدم أثناء الجلسة | EXISTS | CLIENT-DEMO-OPERATOR-RUNBOOK-AR.md |
| 8 | سيناريو العرض | السكريبت المستخدم أثناء الجلسة | EXISTS | CLIENT-DEMO-WALKTHROUGH-AR.md |
| 9 | قرار المالك | القرار النهائي من العميل | PENDING CLIENT SESSION | CLIENT-COMMERCIAL-READINESS-DECISION-AR.md |

---

## قواعد الأدلة

1. لا تعدّل الأدلة الأصلية بما يغيّر معناها.
2. لا تضف ملفات كبيرة إلى Git تلقائيًا.
3. لا تضف تسجيلات شاشة أو بيانات عميل حساسة للمستودع.
4. يمكن إضافة Manifest أو مسارات مرجعية أو Hashes بدل الملفات الكبيرة.
5. لا تدّع وجود توقيع إن لم يوجد.
6. لا تستخدم كلمة "موافق" إلا إذا كان هناك قول أو إجراء فعلي يدعمها.

---

## أدلة موجودة مسبقاً (الحزمة)

| # | الملف | الحالة | التحقق |
|---|-------|--------|--------|
| 1 | checksums.sha256 | موجود | 29/29 SHA-256 متطابق |
| 2 | release-manifest.json | موجود وصحيح | تم التحقق |
| 3 | file-listing.txt | موجود | تم التحقق |
| 4 | README-AR.txt | موجود | تم التحقق |
| 5 | docs/CLIENT-DEMO-WALKTHROUGH-AR.md | موجود في الحزمة | SHA-256 متطابق |
| 6 | docs/CLIENT-INSTALLATION-GUIDE-AR.md | موجود في الحزمة | SHA-256 متطابق |
| 7 | docs/CLIENT-KNOWN-LIMITATIONS-AR.md | موجود في الحزمة | SHA-256 متطابق |
| 8 | docs/CLIENT-PILOT-HANDOFF-SMOKE-AR.md | موجود في الحزمة | SHA-256 متطابق |
| 9 | docs/OWNER-QUICK-START-AR.md | موجود في الحزمة | SHA-256 متطابق |
| 10 | docs/CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md | موجود في الحزمة | SHA-256 متطابق |

---

## ملخص حالة الأدلة

| الفئة | العدد | الحالة |
|-------|-------|--------|
| الأدلة المطلوبة والمتوفرة | 2 | EXISTS |
| الأدلة المطلوبة والناقصة | 7 | PENDING CLIENT SESSION |
| الأدلة المتوفرة من الحزمة | 10 | PASS |
| **الإجمالي** | **19** | — |

---

*تم إنشاء هذا المستند في المرحلة 100 — دليل الأدلة.*
*حالة الأدلة: PENDING CLIENT SESSION*
