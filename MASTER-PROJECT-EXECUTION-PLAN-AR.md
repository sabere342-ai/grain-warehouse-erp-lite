# الخطة التنفيذية الشاملة لمشروع «غلال»

> **نوع الوثيقة:** Master Execution Plan + Governance Rules + Remaining Backlog  
> **المصدر الحاكم:** مستودع `grain-warehouse-erp-lite` ووثائق Phase 70 وMaster Roadmap وDecision Register وRTM وDeveloper Handoff، مع سياق النقل المعتمد.  
> **قاعدة التعارض:** الكود والاختبارات وتاريخ Git الفعلي مقدَّمة على الملخصات؛ والقرار الأحدث الصريح للمالك مقدَّم على وثيقة قديمة متعارضة.

---

## 1. خط الأساس الحالي

### 1.1 Git baseline المؤكد

- **HEAD:** `4d8705b2cc76b757294a5ddaed44fd8adc83eaec`
- **Commit:** `Owner Wipe: snapshot coverage gate + transaction rollback safety`
- **Tag:** `owner-wipe-final-pass`
- **Branch:** `transaction-safe-restore-wipe`
- **السلسلة المتكاملة:** DC-U007 → CAN-005/006/007 → DC-U002 → DC-U008 → Owner Wipe
- **النتيجة المثبتة:** 862/862 اختبارات ناجحة، flutter analyze: 0 مشاكل، Windows Release Build: PASS
- **Phase 66:** لم تُنفذ، ولا يوجد لها Tag، ولا يجوز وصفها كمكتملة.
- **Phase 82:** غير معرفة في المستودع، ولا يجوز اختراعها.

### 1.2 حالة النطاقات المغلقة

تم التحقق من إغلاق جميع النطاقات التالية عبر سلسلة Git المتكاملة:

| النطاق | Commit | Tag | الحالة |
|--------|--------|-----|--------|
| DC-U007 | `af56ced` | `dc-u007-windows-release-build-verified` | مغلق ومتكامل |
| CAN-005/006/007 | `49878f7` | `can-005-006-007-financial-reversals-pass` | مغلق ومتكامل |
| DC-U002 Core | `839ff78` | `dc-u002-split-payments-pass` | Core مغلق ومتكامل |
| DC-U002 UI | — | — | غير منفذ |
| DC-U008 Core | `59d689f` | `dc-u008-overpayments-advances-refunds-pass` | Core مغلق ومتكامل |
| DC-U008 UI | — | — | غير منفذ |
| Owner Wipe | `4d8705b` | `owner-wipe-final-pass` | مغلق ومتكامل |

**لا يُعاد فتح أي نطاق مغلق إلا عند وجود regression مثبت بالاختبارات.**

---

## 2. الرؤية النهائية للمنتج

نظام عربي RTL لإدارة مخزن حبوب، يبدأ بمالك/منشأة واحدة، ويصل تدريجيًا إلى:

1. تطبيق Windows محلي كامل ومستقر للمبيعات والمشتريات والمخزون والعملاء والموردين والحسابات المالية.
2. خزنة وبنوك ومحافظ إلكترونية مرتبطة بجميع الحركات المالية.
3. دفتر مالي قابل للتدقيق، إغلاقات وتسويات وتقارير صحيحة.
4. نسخ احتياطي واستعادة ذرية ومتوافقة مع الإصدارات القديمة.
5. تشغيل حقيقي موثّق لدى المالك دون صفحات ناقصة أو أخطاء محاسبية.
6. Cloud backend آمن ومزامنة Offline-first بعد إثبات النموذج المحلي.
7. Multi-device ثم تطبيق موبايل بعد استقرار المزامنة والأمان.
8. Multi-tenant وSaaS/licensing لاحقًا فقط، وليس ضمن الأولوية الحالية.

---

## 3. القواعد الحاكمة غير القابلة للتفاوض

### 3.1 قواعد الواجهة والصفحات

1. لا حذف أو إخفاء أي صفحة موجودة كحل للهروب من إكمالها.
2. لا Placeholder ولا «قيد التنفيذ» ولا زر ظاهر بلا وظيفة.
3. كل صفحة موجودة في التنقل يجب أن تعمل ببيانات حقيقية ونهايات نجاح وفشل واضحة.
4. كل صفحة فرعية يجب أن تحتوي مسار رجوع واضحًا ومتوافقًا مع RTL.
5. لا تُضاف صفحة أو Navigation destination جديدة قبل اكتمالها وظيفيًا واختبارها.
6. الواجهة عربية RTL، والنصوص المالية واضحة وغير مضللة.
7. إعدادات الألوان والثيم يجب أن تكون عملية، محفوظة محليًا، وبمستوى تباين مناسب.
8. اسم المنشأة والشعار يجب أن يظهرا بصورة متسقة في التطبيق والفواتير والتقارير حيث تم اعتمادهما.
9. أيقونة Windows تُدار بأداة Build-time موثقة؛ لا يُوعد بتغيير Runtime غير ممكن تقنيًا.
10. لا تستخدم رسالة نجاح قبل اكتمال العملية الذرية كاملة.

### 3.2 قواعد المحاسبة

1. الأموال تُخزن كـ`int` بوحدة القرش فقط؛ ممنوع `double` للأموال والأسعار والأرصدة.
2. الأوزان والكميات تُخزن كـ`int` بوحدة الجرام فقط.
3. الرصيد مشتق من دفتر قيود قابل للتدقيق؛ لا يُخزن كقيمة مستقلة قابلة للتعديل.
4. لا تعديل مباشر للأرصدة.
5. لا حذف لمستندات مرحلة أو قيود مالية.
6. التصحيح والإلغاء يتمان بحركة عكسية مستقلة وموثقة.
7. المستند الأصلي يظل محفوظًا، ويرتبط بالحركة العكسية.
8. كل حركة مالية لها Source document وAudit واضحان.
9. لا استخدام لـ`abs()` أو Clamp لإخفاء الرصيد السالب.
10. لا اختلاق قيد موازنة لتسوية فرق فعلي؛ الفرق يُسجل كتسوية/مصالحة دون تغيير الدفتر إلا بقرار محاسبي مستقل.
11. التقارير تقرأ من المصدر الحاكم، ولا تحتفظ بإجماليات مستقلة قد تنحرف.
12. لا يغيّر إلغاء حركة مالية المخزون إلا إذا كانت العملية الأصلية نفسها مخزنية ويجب عكسها وفق عقدها.

### 3.3 الذرية والـIdempotency

1. العملية التجارية وقيود العميل/المورد والدفتر المالي والمخزون والـAudit والتاريخ وحدة ذرية واحدة.
2. عند فشل أي جزء: Rollback كامل، بلا سجل نجاح أو رصيد جزئي.
3. كل أمر مالي يملك `clientRequestId` أو Idempotency key مناسبًا.
4. تكرار نفس الطلب يعيد النتيجة نفسها أو يرفض بأمان، ولا ينشئ قيدًا ثانيًا.
5. تغيير بيانات الطلب مع نفس المفتاح يُرفض.
6. الموافقات الحساسة أحادية الاستخدام ومرتبطة بالعملية المحددة.
7. لا تعتمد الحماية على UI؛ التحقق النهائي داخل Domain/Repository/Service.

### 3.4 الصلاحيات والتدقيق

1. إخفاء زر لا يساوي صلاحية؛ يجب التحقق في طبقة التطبيق الأساسية.
2. هوية المالك الموافق يجب أن تأتي من Auth حقيقي، لا String أو Boolean يمرره caller.
3. يجب التحقق من وجود المستخدم ودوره ونشاط حسابه.
4. لا تُخزن كلمات مرور أو PIN أو Secrets في Audit أو Backup.
5. Audit يحتوي Metadata منظمة: requester، approver، account، amount، source، before/after، result، timestamp.
6. Audit النجاح يُكتب فقط مع نجاح العملية، وفي نفس الوحدة الذرية.

### 3.5 المخزون

1. كل تغيير مخزون ينتج Stock movement قابلًا للتدقيق.
2. لا تعديل مباشر للكمية النهائية دون حركة.
3. الإلغاء المخزني مشتق من الأصل، وليس من إدخال يدوي جديد.
4. لا تسمح عملية مالية فاشلة ببقاء زيادة أو نقص مخزون.
5. تكلفة وربح وتقارير المخزون لا تتغير من Feature مالية بلا عقد صريح.

### 3.6 النسخ الاحتياطي والاستعادة

1. Backup versioned ومتوافق مع جميع الإصدارات السابقة المدعومة.
2. الحقول الجديدة الغائبة في نسخة قديمة تستعيد Defaults آمنة، ولا تُختلق بيانات تاريخية.
3. جميع العلاقات والمراجع تُفحص قبل بدء الكتابة.
4. Restore غير صالح يفشل قبل الكتابة أو يعمل داخل Transaction مع Rollback كامل.
5. Wipe لا يبدأ إلا بعد Backup ناجح وتأكيد واضح، ويجب أن يصبح ذريًا.
6. لا تكسر Format قديمًا ولا تعيد استخدام Version بمعنى مختلف.
7. النسخ الاحتياطي يجب أن يشمل بيانات الحوكمة الدائمة اللازمة: سياسات الحسابات، الموافقات المستهلكة، الحركات العكسية، Metadata الإغلاق والتدقيق.

### 3.7 Git والحوكمة والإغلاق

لا تعتبر أي مرحلة أو نطاق مكتملًا إلا بعد نجاح جميع الآتي:

- إثبات Baseline وWorking tree نظيفة قبل البدء.
- Scope وOut-of-scope واضحان.
- Owner decisions والاعتماديات مثبتة من المستودع.
- Focused tests.
- Full tests.
- `flutter analyze --no-pub` بلا Issues.
- `flutter build windows --release` ناجح.
- `git diff --check` ناجح.
- مراجعة الملفات وعدم وجود Build outputs أو ZIP أو `.venv` أو ملفات عرضية.
- تحديث الوثائق الحاكمة بعد نجاح التنفيذ فقط.
- Commit مستقل واضح.
- Tag جديد لا يعيد استخدام أو تحريك Tag قديم.
- `git status --short` فارغ بعد الإغلاق.

قواعد إضافية:

- لا اختراع أرقام Phases.
- لا وصف Documentation-only بأنها Implementation.
- لا نقل Tag قديم إلى Commit جديد.
- لا تنسيق جماعي أو Refactor واسع خارج النطاق.
- لا حذف اختبارات لتخفيض الفشل.
- لا تعديل معادلات محاسبية بلا Acceptance tests.
- لا اعتماد ملخص محادثة على حساب دليل المستودع.

### 3.8 حماية المصدر والتسليم

1. مستودع التطوير خاص ويحتفظ بـ`.git` والتاريخ كاملًا.
2. حزمة العميل لا تحتوي `.git` أو `lib` أو `test` أو Scripts أو Secrets.
3. التسليم للعميل يحتوي Build وملفات التشغيل والوثائق اللازمة فقط.
4. لا تُرفع مفاتيح خدمة أو `.env` أو Credentials داخل Git أو ChatGPT.
5. أي حزمة نقل للمطور تُرفع فقط إلى مشروع/حساب خاص ومقصود.

---

## 4. ترتيب التنفيذ الإلزامي

## Track 0 — Governance Reconciliation — مكتمل ✓

### الهدف
إزالة الانحراف بين الوثائق والكود وتثبيت الحالة الحقيقية بعد Owner Wipe.

### الأعمال المنفذة

1. تحديث baseline إلى `4d8705b` (Owner Wipe final).
2. توثيق إغلاق DC-U007 عبر `af56ced`.
3. توثيق إغلاق CAN-005/006/007 عبر `49878f7`.
4. توثيق إغلاق DC-U002 Core عبر `839ff78`.
5. توثيق إغلاق DC-U008 Core عبر `59d689f`.
6. توثيق إغلاق Owner Wipe عبر `4d8705b`.
7. تحديث عدد الاختبارات إلى 862/862.
8. تحديث جميع الوثائق الحاكمة (Roadmap، Decision Register، RTM، Handoff).

### بوابة الخروج
جميع الحالات متسقة: Roadmap وDecision Register وRTM وHandoff تتفق على نفس الحالة.

---

## Track 1 — DC-U007 Negative-Balance Controls — مكتمل ✓

### الحالة
مغلق ومتكامل عبر Commit `af56ced` وتاغ `dc-u007-windows-release-build-verified`.

### ما تم تنفيذه
- نموذج `allowNegativeBalance` على FinancialAccount.
- تحقق من الرصيد على مسارات المصروفات والمدفوعات والتحويلات.
- موافقة المالك مع Audit trail.
- اختبارات Fault-injection.
- Backup/restore للبيانات الجديدة.

### لا يُعاد فتح هذا النطاق إلا عند وجود regression مثبت.

---

## Track 2 — إطار الذرية العام للمعاملات

قد يُنفذ داخل Track 1، لكن يجب أن يصبح قدرة مشتركة قبل باقي العمليات المالية.

### المطلوب

1. `UnitOfWork` أو Snapshot/rollback موحد للمستودعات المحلية.
2. Transaction boundary صريح لخدمات الأعمال.
3. Preflight validations قبل الكتابة.
4. Fault injection hooks للاختبارات.
5. Idempotency registry موحد.
6. Atomic audit/document history.
7. قابلية الترحيل لاحقًا إلى Database transaction/Server command.

### السبب
CAN-005/006 وSplit Payments وOverpayments والـCloud جميعها تعتمد على ذرية موثوقة.

---

## Track 3 — CAN-005 / CAN-006 / CAN-007 — مكتمل ✓

### الحالة
مغلق ومتكامل عبر Commit `49878f7` وتاغ `can-005-006-007-financial-reversals-pass`.

### ما تم تنفيذه

#### CAN-005 — Customer Collection Cancellation
- الإبقاء على التحصيل الأصلي.
- إنشاء Cancellation/Reversal مستقل.
- إعادة مديونية العميل.
- خفض الحساب المالي الأصلي.
- منع الإلغاء المكرر.
- Audit وDocument History وBackup وتقارير صحيحة.

#### CAN-006 — Supplier Payment Cancellation
- الإبقاء على الدفع الأصلي.
- إعادة مستحق المورد.
- زيادة الحساب المالي الأصلي.
- منع الإلغاء المكرر.
- Audit وDocument History وBackup وتقارير صحيحة.

#### CAN-007 — General Financial Account Reversal
- Reversal مشتق من القيد الأصلي.
- نفس المبلغ والحساب والمصدر.
- Link بين الأصل والعكس.
- Atomic rollback عند الفشل.

### لا يُعاد فتح هذا النطاق إلا عند وجود regression مثبت.

---

## Track 4 — DC-U002: Split Payments — Core مكتمل / UI مفتوح

### الحالة
Core مغلق ومتكامل عبر Commit `839ff78` وتاغ `dc-u002-split-payments-pass`.
End-User UI: غير منفذ — النطاق التالي بعد إغلاق الوثائق.

### ما تم تنفيذه (Core)
- نموذج `PaymentAllocation` مرتبط بالمستند.
- مجموع التخصيصات يساوي المبلغ المدفوع بالضبط.
- توزيع بين خزنة/بنك/محفظة وفق الحسابات النشطة.
- إنشاء قيد مستقل لكل Allocation.
- ذرية كاملة لكل التخصيصات.
- Cancellation يعكس كل Allocation إلى حسابه الأصلي.
- تقارير Payment Method وAccount statements لا تكرر الإجماليات.
- Backup versioning وتوافق الإصدارات القديمة.
- Idempotency وFault-injection tests.

### المتبقي (UI)
- مراجعة UI واضحة بالمجموع والمتبقي والتحقق الفوري.
- منع تجاوز الحد أو الحساب المعطل.
- لا خلط UI وPersistence في commit واحد.

---

## Track 5 — DC-U008: Overpayments, Credits, Advances & Refunds — Core مكتمل / UI مفتوح

### الحالة
Core مغلق ومتكامل عبر Commit `59d689f` وتاغ `dc-u008-overpayments-advances-refunds-pass`.
End-User UI: غير منفذ — النطاق الثاني بعد Split Payments UI.

### ما تم تنفيذه (Core)
- Customer credit/advance ledger entries.
- Supplier credit/advance entries.
- Owner approval authentic and operation-bound.
- Refund document مستقل بحركة تعويضية.
- DC-U007 عند Refund Outflow.
- Partial consumption للرصيد الدائن مع تاريخ واضح.
- منع الرصيد المزدوج أو Refund أكبر من المتاح.
- Backup، reports، statements، cancellation، audit، idempotency.
- تكامل صحيح مع Split Payments.

### المتبقي (UI)
- واجهة مستخدم عربية لعمليات الزائد/الاسترداد/العربون.
- لا خلط UI وPersistence في commit واحد.

---

## Track 6 — Backup/Restore/Wipe Transaction Safety

### المتطلبات غير المنفذة

- `BKP-008 — Transaction-safe restore`
- `BKP-009 — Transaction-safe wipe`

### المطلوب

1. Validate-all-first لكل النسخة.
2. Transaction/Unit of Work لاستعادة جميع المستودعات.
3. Rollback كامل عند فشل أي Category.
4. Integrity checks لكل العلاقات والمراجع والـIDs.
5. منع Duplicate IDs وعلاقات Cancellation/Approval التالفة.
6. Restore dry-run/preview يعرض الأخطاء قبل التنفيذ.
7. Wipe ذري بعد Backup ناجح.
8. Recovery test بفشل متعمد في كل مرحلة.
9. Hash/manifest للنسخة إن كان متوافقًا مع التصميم.
10. توثيق Upgrade path للإصدارات القديمة.

---

## Track 7 — Reporting Completeness

بعد استقرار القيود والإلغاءات والمدفوعات المقسمة والزائدة.

### تقارير ما زالت مطلوبة

1. Inflows report.
2. Outflows report.
3. Collections by account report.
4. Supplier payments by account report.
5. Expenses by account report.
6. Bank/wallet fee tracking and report — يحتاج Owner decision عن المعالجة المحاسبية.
7. `RPT-005` Dedicated collection report:
   - Filters.
   - Totals.
   - Per-customer breakdown.
8. `RPT-006` Settlement report:
   - تقدم سداد ديون العملاء والموردين.
   - الربط بالمستندات الأصلية.
9. `RPT-008` Reconciliation report:
   - أولًا مراجعة ما نفذته Phase 80.
   - لا تكرر شاشة/تقرير قائمًا.
10. Profit/financial statements المتقدمة لا تُنفذ دون تعريف محاسبي واضح؛ التطبيق الحالي Operational ERP وليس General Ledger مزدوج القيد كاملًا.

### قواعد التقارير

- Read-only من Ledger/source records.
- Date boundaries موحدة.
- لا Double counting للحركات العكسية أو Split allocations.
- PDF/CSV حسب صلاحيات العرض والتصدير.
- الأرصدة السالبة تظهر بصدق.

---

## Track 8 — Inventory & Document Output Completion

### المطلوب

1. `INV-005 — PDF stock adjustment/variance report`.
2. مراجعة جميع Printable views والتأكد من Back navigation وRTL.
3. إدراج اسم المنشأة والشعار حيث تنص العقود، مع اختبار واقعي للملف الناتج.
4. مراجعة Invoice logo drift بين الوثائق والكود.
5. اختبار أرقام الملفات الآمنة وعدم تسريب IDs داخل أسماء ملفات غير مناسبة.
6. لا كشف تكلفة/ربح في مستندات العميل غير المصرح بها.

---

## Track 9 — UI/UX Completeness Audit

### المطلوب

1. جرد جميع Routes والصفحات الظاهرة لكل Role.
2. كل صفحة لها:
   - Back action واضح إذا كانت فرعية.
   - Loading/empty/error states مفيدة.
   - Validation عربي واضح.
   - Permission handling في UI وDomain.
3. التأكد أن `PlaceholderFeatureScreen` غير مستخدم في Navigation فعلي.
4. عدم حذف الملف لمجرد اسمه؛ الحاكم هو الاستخدام الفعلي.
5. Theme/color controls:
   - Presets الحالية.
   - تباين النص والأزرار والجداول.
   - حفظ الاختيار.
   - إمكانية إضافة تحكم محدود إضافي دون كسر الهوية.
6. Branding verification:
   - اسم المنشأة.
   - Logo upload/remove.
   - Dashboard.
   - Sales/purchase invoices.
   - Statements/reports حيث مطلوب.
   - Windows icon build tool.
7. Keyboard/focus/scroll behavior على شاشات Windows الصغيرة.
8. منع Overflow في الاختبارات وأحجام النوافذ المختلفة.

---

## Track 10 — Local Production Hardening & Real Owner Trial

### ملاحظة Phase 66

Phase 66 لم تُنفذ تاريخيًا، ولا يجوز إضافة Tag لها بأثر رجعي.

### المطلوب

إنشاء نطاق حوكمي جديد غير مرقم أو رقم معتمد لاحقًا لـ**Controlled Owner Trial Execution**:

1. يوم عمل حقيقي كامل ببيانات تجريبية/مصرح بها.
2. مشتريات، مبيعات، تحصيلات، مدفوعات، مصروفات، تحويلات، إغلاق، Backup/restore.
3. تسجيل كل Incident بالأدلة.
4. عدم إصلاح أي Issue دون Reproduction وRoot cause.
5. Performance profiling على حجم بيانات واقعي.
6. Crash/error logging محلي آمن.
7. Backup drill واستعادة على جهاز منفصل.
8. Delivery smoke من Package العميل، لا من Source tree.
9. تدريب المالك ودليل تشغيل عربي.
10. قبول Owner رسمي قبل الانتقال للسحابة.

### بوابة إثبات النموذج المحلي

لا يبدأ Cloud Track إلا بعد:

- فترة تشغيل واقعي متفق عليها.
- عدم وجود Critical accounting/inventory bugs.
- Restore drill ناجح.
- تقرير أداء.
- Owner acceptance واضح.

---

## Track 11 — القرارات المفتوحة قبل التوسع

### قرارات Owner المطلوبة

1. `DC-U001` — نطاق الموبايل: قراءة فقط / تحصيلات ميدانية / كامل العمليات.
2. `DC-U003` — Multi-currency أم الاستمرار بعملة واحدة.
3. `DC-U004` — فروع/مخازن متعددة أم منشأة واحدة.
4. `DC-U005` — خزنة/درج واحد أم عدة Cash registers.
5. `DC-U006` — يجب أولًا حل تعارضه مع Phase 80 وتوثيق القرار المنفذ.
6. `DC-U009` و`DC-U012` — دمجهما كقرار واحد عن iOS.
7. `DC-U010` — Cloud provider. Supabase مرشح قوي ومذكور سابقًا، لكنه لا يصبح حاكمًا قبل اعتماد رسمي.
8. `DC-U011` — Licensing model مؤجل حتى بناء Cloud، وليس أولوية الآن.
9. سياسة Fees للبنوك والمحافظ والتحويلات.
10. Mixed source operations وتعريفها المحاسبي.
11. Branch numbering/document numbering عند اعتماد الفروع.

### قاعدة
لا يبدأ Track يعتمد على قرار مفتوح قبل تسجيل قرار المالك في Decision Register.

---

## Track 12 — Cloud Foundation

لا يبدأ قبل بوابة إثبات النموذج المحلي وقرار DC-U010.

### 12.1 Architecture & Security

1. Backend/API server أو Supabase architecture معتمدة.
2. PostgreSQL/Database schema دائم بدل in-memory-only.
3. Server-authoritative commands للعمليات المالية والمخزنية.
4. Auth server-side وجلسات آمنة.
5. Roles/permissions server-side.
6. Tenant/establishment isolation حتى لو بدأ بعميل واحد.
7. Row Level Security عند استخدام Supabase.
8. Audit append-only server-side.
9. Secrets management وعدم وضع Service keys في العميل.
10. File/logo object storage وسياسة الحجم والنوع والـhash.

### 12.2 Migration

1. Backup كامل قبل الترحيل.
2. Mapping من جميع Models المحلية إلى Schema الجديد.
3. Migration dry-run.
4. Row counts، ledger totals، stock totals، customer/supplier balances قبل وبعد.
5. Rollback plan.
6. Migration idempotent.
7. لا تغيير في المستندات التاريخية.

### 12.3 API Contracts

1. Commands ذرية لكل عملية أعمال.
2. Idempotency key إجباري.
3. Server timestamps.
4. Optimistic concurrency/version fields.
5. Error codes مستقرة وقابلة للترجمة.
6. Attachments/logo upload contracts.
7. Rate limiting وsession revocation.

### 12.4 Operations

1. Cloud backups وسياسة retention.
2. Monitoring وalerts.
3. Error tracking دون تسريب بيانات مالية حساسة.
4. Environment separation: dev/staging/prod.
5. Cost monitoring.
6. Disaster recovery drill.

---

## Track 13 — Offline-first Sync

### المطلوب

1. Durable local database؛ لا تعتمد المزامنة على in-memory repositories.
2. Offline command queue.
3. Per-command idempotency.
4. Retry/backoff.
5. Sync status ظاهر للمستخدم.
6. Partial failure handling.
7. Transaction groups.
8. Server-authoritative validation.
9. Clock-skew handling باستخدام server time.
10. Conflict detection/resolution.
11. Tombstones للحذف المنطقي عند الحاجة، دون حذف المستندات المالية.
12. Re-sync/recovery tools.
13. Sync audit.

### اختبارات حرجة

- Duplicate sale/collection/payment.
- Two devices selling last stock.
- Same debt collected/paid twice.
- Permission changed on another device.
- Queue loss/restart.
- Partial transaction sync.
- Conflict on same document.

---

## Track 14 — Multi-device

بعد Cloud + Offline Sync فقط.

### المطلوب

1. Device identity.
2. Device authorization/revocation.
3. Concurrent users and permission refresh.
4. Conflict-safe financial posting.
5. Unique document numbering strategy.
6. Per-device diagnostics.
7. Multi-device reconciliation tests.
8. Branch isolation فقط إذا اعتمد DC-U004.
9. Cash-register isolation فقط إذا اعتمد DC-U005.

---

## Track 15 — Mobile Application

بعد Multi-device foundation وقرارات DC-U001/DC-U009.

### خيارات النطاق

- Read-only owner dashboard.
- Field collections/payments.
- Full operations.

### الترتيب الموصى به لتقليل المخاطر

1. Read-only dashboard.
2. Owner monitoring and reports.
3. Field collections/payments مع GPS/attachments فقط إذا طلبت رسميًا.
4. Full sales/purchases لاحقًا بعد إثبات المزامنة.

### متطلبات

- Android first أو Android+iOS حسب القرار.
- Mobile auth.
- Secure local storage.
- Offline queue.
- Device revocation.
- Responsive Arabic RTL.
- Push notifications عند اعتمادها.
- لا منطق محاسبي مختلف عن Windows؛ نفس Server commands.

---

## Track 16 — SaaS / Multi-tenancy / Licensing — مؤجل

لا يبدأ الآن.

### عند اعتماده لاحقًا

1. Tenant provisioning.
2. Strict tenant isolation.
3. Subscription plans.
4. Licensing/device limits.
5. Billing and invoices.
6. Support/admin tools.
7. Usage limits.
8. Data export/deletion policies.
9. Legal/privacy/security requirements.

---

## 5. قائمة المطلوب غير المنفذ أو غير المغلق

### مغلق ✓ (لا يُعاد فتحه)

- ~~DC-U007 Negative-Balance Controls~~ ✓ Commit `af56ced`
- ~~CAN-005 Collection cancellation~~ ✓ Commit `49878f7`
- ~~CAN-006 Supplier payment cancellation~~ ✓ Commit `49878f7`
- ~~CAN-007 General financial reversal~~ ✓ Commit `49878f7`
- ~~DC-U002 Split Payments Core~~ ✓ Commit `839ff78`
- ~~DC-U008 Overpayments/Advances/Refunds Core~~ ✓ Commit `59d689f`
- ~~Owner Wipe & Transaction-safe Restore~~ ✓ Commit `4d8705b`

### النطاق التالي المعتمد

1. Split Payments End-User UI.
2. Advances/Overpayments/Refunds End-User UI.
3. Durable Persistence Architecture Decision (ADR).
4. Durable Persistence Implementation.

### الحظر التشغيلي

> لا تُستخدم بيانات مالية تشغيلية حقيقية قبل نجاح التخزين الدائم واختبارات crash recovery وBackup/Restore drill.

- لا تخلط UI وPersistence في commit واحد.
- لا تغيّر Domain APIs المغلقة بلا سبب مثبت.
- لا تعيد تصميم المحاسبة من الصفر.
- لا تحذف compatibility مع Backup الحالي.

### Financial operations — مفتوح

- Mixed source operations.
- Fee tracking/accounting.
- Daily cash closing (DC-U006 — يعتمد قرار المالك).

### Data safety

- Durable Persistence ADR.
- Durable Persistence Implementation.
- Transaction-safe restore (يحتاج persistent storage).
- Transaction-safe wipe (يحتاج persistent storage).

### Reports — مفتوح

- Inflows.
- Outflows.
- Collection by account.
- Supplier payment by account.
- Expense by account.
- Dedicated collection report.
- Settlement report.
- Reconciliation-report status reconciliation with Phase 80.

### Inventory/documents/UI

- PDF stock adjustment/variance report.
- Full page/back-navigation audit.
- Branding documentation/code reconciliation.
- Invoice logo verification across all required outputs.
- Windows icon build-flow verification.
- Additional theme/color usability verification.

### Operational readiness

- Controlled synthetic-data pilot.
- Real financial data pilot (محظور قبل durable persistence).
- Extended real-condition trial.
- Performance/edge-case hardening.
- Restore drill on separate machine.
- Final client-safe delivery refresh after all local changes.

### Cloud/mobile

- Durable local database.
- Backend/API.
- Cloud sync.
- User/device identity.
- Offline queue.
- Conflict resolution.
- Server-side validation.
- Multi-device.
- Mobile app.
- Tenant management.
- SaaS/licensing لاحقًا.

---

## 6. نموذج عمل كل نطاق مستقبلي

### قبل التنفيذ

1. `git status --short`
2. `git rev-parse HEAD`
3. `git tag --points-at HEAD`
4. قراءة Roadmap/Decision Register/RTM/Handoff والوثيقة السابقة.
5. Scope وOut-of-scope.
6. Dependency audit.
7. Owner decisions.
8. Posting path inventory.
9. Backup/report/UI impact.
10. Acceptance tests قبل الكود.

### أثناء التنفيذ

1. تغييرات صغيرة مترابطة.
2. Focused tests بعد كل مجموعة.
3. Fault injection للعمليات الذرية.
4. `flutter analyze --no-pub` دوريًا.
5. `git diff --check` دوريًا.
6. مراجعة `git diff --name-only` لمنع Scope creep.

### قبل الإغلاق

1. Code review ضد العقد المحاسبي.
2. Permission review.
3. Atomicity review.
4. Backup compatibility review.
5. Reports/inventory non-regression.
6. Focused tests.
7. Full suite.
8. Analyze.
9. Windows release build.
10. Diff check.
11. Documentation update.
12. Staging review.
13. Commit + Tag.
14. Clean tree.

---

## 7. الترتيب التنفيذي المختصر المعتمد

### مكتمل ✓

1. ~~**DC-U007 Negative-Balance Controls.**~~ ✓ Commit `af56ced`
2. ~~**CAN-005/CAN-006/CAN-007 cancellations and reversals.**~~ ✓ Commit `49878f7`
3. ~~**DC-U002 Split Payments Core.**~~ ✓ Commit `839ff78`
4. ~~**DC-U008 Overpayments/Advances/Refunds Core.**~~ ✓ Commit `59d689f`
5. ~~**Owner Wipe & Transaction-safe Restore.**~~ ✓ Commit `4d8705b`

### القادم (بعد إغلاق الوثائق)

6. **Split Payments End-User UI.**
7. **Advances/Overpayments/Refunds End-User UI.**
8. **Durable Persistence Architecture Decision (ADR).**
9. **Durable Persistence Implementation.**
10. **Remaining financial and settlement reports.**
11. **Stock-adjustment PDF + UI/branding/navigation audit.**
12. **Real Financial Data Pilot (محظور قبل durable persistence).**
13. **Local production hardening.**
14. **Resolve cloud/mobile owner decisions.**
15. **Cloud backend + durable DB + migration.**
16. **Offline-first sync.**
17. **Multi-device.**
18. **Mobile.**
19. **SaaS/licensing only later.**

أي تغيير في هذا الترتيب يحتاج دليل اعتماديات من Master Roadmap أو قرار مالك موثق، وليس مجرد رغبة في ترقيم مرحلة جديدة.

---

## 8. تعريف «المشروع مكتمل»

لا يعد مشروع «غلال» مكتملًا نهائيًا إلا عند تحقق الآتي:

- جميع الصفحات الحالية تعمل دون Placeholder أو إخفاء.
- كل الحركات المالية والمخزنية ذرية ومدققة وقابلة للعكس.
- ~~Split Payments وOverpayments والإلغاءات مكتملة (Core)~~ ✓ مكتمل.
- Split Payments UI وAdvances UI مكتملة.
- Durable persistence منفذة ومجربة.
- Backup/restore/wipe ذرية ومجربة على persistent storage.
- التقارير الأساسية والداعمة متسقة مع Ledger.
- التجربة الحقيقية للمالك مكتملة ومقبولة.
- حزمة Windows مستقرة وآمنة المصدر.
- Cloud sync وMulti-device والموبايل مكتملة إذا ظل هذا هو نطاق المنتج النهائي المعتمد.
- لا توجد قرارات Owner مفتوحة تؤثر في خصائص تم الإعلان عنها كجاهزة.
- جميع بوابات Git/QA/Build/Documentation مغلقة.

