# Phase 83 — UI/UX Comprehensive Audit & Design Foundation

## حالة الوثيقة

- المرحلة: **Phase 83 — Comprehensive UI/UX Audit, Design System & Application Shell Foundation**.
- حالة هذا المستند عند إنشائه: **اكتمل الجرد والـGap Matrix، ولم يبدأ تعديل production code**.
- نقطة البدء المثبتة: `e588adc4193f08ba5a47fc8f3ef80ffc9aaf53c9`.
- الفرع: `phase-83-ui-ux-design-foundation`.
- Phase 82: الـannotated tag `phase-82-durable-negative-balance-approval-verified` يفك إلى نقطة البدء نفسها.
- نطاق الإغلاق: Audit شامل + Design foundation + ترحيل العينة المرجعية فقط؛ لا يعني إعادة تصميم كل شاشة.

## منهج العد والجرد

- تمت مراجعة **51 نقطة دخول/انتقال**: 4 نقاط Bootstrap/Named، و16 وجهة Shell، و4 انتقالات Dashboard/Backup، و3 انتقالات عملاء، و5 موردين، و2 حسابات مالية، و2 مخزون، و3 مبيعات/مشتريات، وانتقال تقرير يومي، و11 تقريرًا ماليًا. التكرار هنا مقصود عندما تفتح الشاشة نفسها من سياقين مختلفين لاختبار عقد الرجوع.
- تمت مراجعة **48 سطحًا مرئيًا مميزًا**: 41 صنفًا باسم `Screen/Page`، و`AuthGate`، و`DashboardShell`، وخمس معاينات طباعة.
- تمت مراجعة **35 نقطة استدعاء Dialog** داخل 18 ملفًا، منها 21 Dialog widgets مسماة، إضافة إلى dialogs موضعية للتأكيد/الأسباب/إعادة التحقق.
- `PlaceholderFeatureScreen` ملف ميت غير مستورد ولا توجد له نقطة وصول. لا توجد صفحة «قيد التنفيذ» قابلة للوصول.
- `showModalBottomSheet`/Nested Navigator/GoRouter غير مستخدمة حاليًا.

## Route Inventory

| المجموعة | نقاط الدخول الفعلية | العدد | الملاحظة |
|---|---|---:|---|
| Bootstrap/Named | `AuthGate`، `/login`، `/first-owner-setup`، `/dashboard` | 4 | `AuthGate` هو `home` وليس ضمن map |
| Shell | الرئيسية، المبيعات، المشتريات، الأصناف، المخزون، الموردون، العملاء، الحسابات، الموافقات، التقارير المالية، المصروفات، التدقيق، التقرير اليومي، الجرد، التسويات، الإعدادات | 16 | صلاحيات الوجهات مفروضة في `_ShellDestination` |
| Dashboard/Backup | النسخ الاحتياطي، الدليل، فحص الاسترجاع، مسح البيانات | 4 | انتقالات Stack مباشرة |
| العملاء | كشف العميل، السلف، معاينة كشف العميل | 3 | كشف العميل private داخل الملف |
| الموردون | السلف، مشتريات المورد، كشف المورد، معاينة كشف المورد، معاينة فاتورة شراء | 5 | انتقالات Stack مباشرة |
| الحسابات | التحويل المالي، كشف الحساب المالي | 2 | للمالك وفق الواجهة الحالية |
| المخزون | الجرد، تقرير التسويات | 2 | متاحان أيضًا كوجهتي Shell |
| البيع والشراء | معاينة فاتورة بيع، سجل المستندات من البيع، سجل المستندات من الشراء | 3 | سياقان مستقلان للرجوع |
| التقرير اليومي | معاينة التقرير اليومي | 1 | من `ReportsScreen` |
| التقارير المالية | الأرصدة، الإغلاق، كشف الحساب، طرق الدفع، التحويلات، الداخل، الخارج، التحصيلات، تسويات الموردين، السلف والردود، تحليل المصروفات | 11 | كلها `MaterialPageRoute` من مركز التقارير |
| **الإجمالي** |  | **51** | تمت مراجعة نقطة المصدر والهدف وسلوك الرجوع |

## مفاتيح Screen Inventory

- الوصول: `نعم`، أو `صلاحية`، أو `ميت`.
- الرجوع: `Shell` يعني العودة للرئيسية من shell؛ `Stack` يعني pop للسياق السابق؛ `—` جذر أو dialog.
- المنصات: `جيد` أو `مخاطرة` بناءً على فحص constraints وأنماط layout؛ الإثبات النهائي للعينة المرحلة يكون باختبار widget على الأحجام المحددة.
- `F` تعني بيانات/أفعال مالية حساسة، و`L` تعني كثافة Widgets محلية مكررة.

## Comprehensive Screen Inventory

| # | Screen / file | Route أو الدخول | الوظيفة | الوصول | الرجوع | RTL | هاتف | Windows | Overflow | Dead/Placeholder | F | L | الخطورة | الترحيل |
|---:|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `auth/auth_gate.dart` | app `home` | توجيه حالة الدخول | نعم | — | نعم | جيد | جيد | منخفض | لا | لا | لا | Low | Phase 83 smoke |
| 2 | `auth/login_screen.dart` | `/login` | دخول محلي بالهاتف/كلمة المرور | نعم | جذر | نعم | مخاطرة scaling | جيد | متوسط | لا | لا | نعم | Medium | **Phase 83** |
| 3 | `auth/first_owner_setup_screen.dart` | `/first-owner-setup` | إنشاء المالك الأول | نعم | جذر | نعم | مخاطرة scaling | جيد | متوسط | لا | حساس | نعم | Medium | لاحق مشترك مع Login |
| 4 | `dashboard/dashboard_shell.dart` | `/dashboard` | Shell وصلاحيات وتنقل | نعم | Shell | نعم | **مخاطرة** | جيد | مرتفع | لا | F حسب الصفحة | نعم | **High** | **Phase 83** |
| 5 | `dashboard/dashboard_screen.dart` | Shell: الرئيسية | مؤشرات وإرشاد ونسخ احتياطي | صلاحية | Shell | نعم | مخاطرة grid | جيد | متوسط | لا | نعم | نعم | Medium | **Phase 83** |
| 6 | `products/products_screen.dart` | Shell: الأصناف | CRUD الأصناف | نعم | Shell | نعم | مخاطرة أفعال | جيد | متوسط | لا | مخزون | نعم | Medium | roadmap |
| 7 | `customers/customers_screen.dart` | Shell: العملاء | العملاء والتحصيل والكشوف | نعم | Shell | نعم | مخاطرة أفعال | جيد | متوسط | لا | نعم | نعم | High | roadmap بعد الموردين |
| 8 | `_CustomerStatementScreen` في ملف العملاء | عميل > كشف | كشف عميل | نعم | Stack | نعم | مخاطرة جدول | جيد | متوسط | لا | نعم | نعم | Medium | roadmap |
| 9 | `customers/customer_advance_actions_screen.dart` | عميل > سلف | تطبيق/رد/عكس سلفة | صلاحية | Stack | نعم | مخاطرة forms | جيد | متوسط | لا | نعم | نعم | High | roadmap مالي |
| 10 | `suppliers/suppliers_screen.dart` | Shell: الموردون | الموردون والسداد والكشوف | نعم | Shell | نعم | مخاطرة أفعال/لا بحث | جيد | متوسط | لا | نعم | نعم | High | **Phase 83** |
| 11 | `suppliers/supplier_advance_actions_screen.dart` | مورد > سلف | تطبيق/رد/عكس سلفة | صلاحية | Stack | نعم | مخاطرة forms | جيد | متوسط | لا | نعم | نعم | High | roadmap مالي |
| 12 | `supplier_accounts/supplier_statement_screen.dart` | مورد > كشف | كشف وسداد المورد | نعم | Stack | نعم | مخاطرة | جيد | متوسط | لا | نعم | نعم | High | roadmap مالي |
| 13 | `sales/sales_screen.dart` | Shell: المبيعات | إنشاء/إلغاء/معاينة بيع | صلاحية | Shell | نعم | مخاطرة form كبير | جيد | مرتفع | لا | نعم | نعم | High | roadmap معاملات |
| 14 | `purchases/purchases_screen.dart` | Shell: المشتريات | شراء آجل/مدفوع/إلغاء | صلاحية | Shell | نعم | مخاطرة form كبير | جيد | مرتفع | لا | نعم | نعم | High | roadmap معاملات |
| 15 | `purchases/supplier_purchases_screen.dart` | مورد > مشتريات | سجل مشتريات مورد | نعم | Stack | نعم | جيد نسبيًا | جيد | منخفض | لا | نعم | نعم | Medium | roadmap |
| 16 | `inventory/inventory_screen.dart` | Shell: المخزون | الرصيد والحركات | صلاحية | Shell | نعم | مخاطرة أفعال | جيد | متوسط | لا | نعم | نعم | High | roadmap مخزون |
| 17 | `inventory/stock_take_screen.dart` | Shell أو المخزون | الجرد والتسوية | صلاحية | Shell/Stack | نعم | مخاطرة form | جيد | متوسط | لا | نعم | نعم | High | roadmap مخزون |
| 18 | `inventory/stock_adjustment_report_screen.dart` | Shell أو المخزون | تقرير تسويات المخزون | صلاحية | Shell/Stack | نعم | جيد نسبيًا | جيد | منخفض | لا | نعم | نعم | Medium | roadmap تقارير |
| 19 | `expenses/expenses_screen.dart` | Shell: المصروفات | إنشاء وعرض المصروف | صلاحية | Shell | نعم | مخاطرة form | جيد | متوسط | لا | نعم | نعم | High | roadmap معاملات |
| 20 | `financial_accounts/financial_accounts_screen.dart` | Shell: الحسابات | أرصدة وإنشاء/تعطيل حساب | مالك | Shell | نعم | مخاطرة Row | جيد | مرتفع | لا | نعم | نعم | High | **Phase 83** |
| 21 | `financial_accounts/financial_account_statement_screen.dart` | حساب > كشف | حركات حساب مالي | مالك | Stack | نعم | مخاطرة سجل | جيد | متوسط | لا | نعم | نعم | High | roadmap مالي |
| 22 | `financial_accounts/financial_transfers_screen.dart` | الحسابات > تحويل | تحويل وعكس مالي | مالك | Stack | نعم | مخاطرة form | جيد | متوسط | لا | نعم | نعم | High | roadmap مالي |
| 23 | `financial_accounts/negative_balance_approval_requests_screen.dart` | Shell: الموافقات | قائمة/تفاصيل/حسم الطلبات | نعم، أفعال بصلاحية | Shell | نعم | **مخاطرة** | جيد | مرتفع | لا | نعم | نعم | **High** | **Phase 83** |
| 24 | `financial_reports/financial_reports_screen.dart` | Shell: تقارير مالية | مركز 11 تقريرًا | مالك | Shell | نعم | جيد | جيد | منخفض | لا | نعم | نعم | Medium | roadmap تقارير |
| 25 | `account_balance_report_screen.dart` | التقارير > الأرصدة | أرصدة الحسابات | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 26 | `financial_closing_screen.dart` | التقارير > الإغلاق | إغلاق/فتح وتسوية | مالك | Stack | نعم | مخاطرة form | جيد | متوسط | لا | نعم | نعم | High | roadmap مالي |
| 27 | `account_statement_report_screen.dart` | التقارير > كشف | كشف حساب بفلاتر | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 28 | `payment_method_report_screen.dart` | التقارير > طرق الدفع | تحليل طرق الدفع | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 29 | `transfer_report_screen.dart` | التقارير > التحويلات | سجل التحويل/العكس | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 30 | `inflows_report_screen.dart` | التقارير > الداخل | التدفقات الداخلة | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 31 | `outflows_report_screen.dart` | التقارير > الخارج | التدفقات الخارجة | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 32 | `customer_collections_report_screen.dart` | التقارير > التحصيلات | تحصيلات حسب الحساب | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 33 | `supplier_settlements_report_screen.dart` | التقارير > التسويات | سداد الموردين حسب الحساب | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 34 | `advances_and_refunds_report_screen.dart` | التقارير > السلف والردود | سلف وردود وعكس | مالك | Stack | نعم | مخاطرة كثافة | جيد | مرتفع | لا | نعم | نعم | High | roadmap تقارير |
| 35 | `expense_analysis_report_screen.dart` | التقارير > تحليل المصروف | تحليل حسب التصنيف | مالك | Stack | نعم | مخاطرة filters | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 36 | `reports/reports_screen.dart` | Shell: التقارير | التقرير اليومي | صلاحية | Shell | نعم | مخاطرة كثافة | جيد | متوسط | لا | نعم | نعم | Medium | roadmap تقارير |
| 37 | `documents/document_history_screen.dart` | البيع/الشراء > السجل | بحث وفلاتر المستندات | صلاحية | Stack | نعم | مخاطرة cards | جيد | متوسط | لا | نعم | نعم | Medium | roadmap قوائم |
| 38 | `backup/backup_export_screen.dart` | Dashboard > النسخ | تصدير/استيراد | مالك | Stack | نعم | جيد نسبيًا | جيد | منخفض | لا | تشغيلي | نعم | Medium | roadmap إعدادات |
| 39 | `backup/backup_restore_preview_screen.dart` | النسخ > فحص | تحقق واسترجاع ذري | مالك | Stack | نعم | مخاطرة نص طويل | جيد | متوسط | لا | شديد | نعم | High | roadmap إعدادات |
| 40 | `backup/data_wipe_screen.dart` | النسخ > مسح | مسح بيانات مؤكد | مالك | Stack | نعم | مخاطرة | جيد | متوسط | لا | شديد | نعم | High | roadmap إعدادات |
| 41 | `settings/settings_screen.dart` | Shell: الإعدادات | المظهر وهوية المنشأة | صلاحية | Shell | نعم | مخاطرة كثافة | جيد | متوسط | لا | لا | نعم | Medium | **Phase 83 appearance** |
| 42 | `audit/audit_logs_screen.dart` | Shell: التدقيق | عرض سجل التدقيق | صلاحية | Shell | نعم | جيد نسبيًا | جيد | منخفض | لا | نعم | نعم | Medium | roadmap |
| 43 | `help/help_guide_screen.dart` | Dashboard > الدليل | إرشاد تشغيلي | نعم | Stack | نعم | جيد | جيد | منخفض | لا | لا | لا | Low | tokens فقط |
| 44 | `prints/printable_sales_invoice_view.dart` | بيع > معاينة | فاتورة بيع | نعم | Stack | نعم | مخاطرة عرض ضيق | جيد/طباعة | متوسط | لا | نعم | نعم | Medium | roadmap print |
| 45 | `prints/printable_purchase_invoice_view.dart` | مشتريات مورد > معاينة | فاتورة شراء | نعم | Stack | نعم | مخاطرة عرض ضيق | جيد/طباعة | متوسط | لا | نعم | نعم | Medium | roadmap print |
| 46 | `prints/printable_customer_statement_view.dart` | عميل > معاينة | كشف عميل | نعم | Stack | نعم | مخاطرة جدول | جيد/طباعة | متوسط | لا | نعم | نعم | Medium | roadmap print |
| 47 | `prints/printable_supplier_statement_view.dart` | مورد > معاينة | كشف مورد | نعم | Stack | نعم | مخاطرة جدول | جيد/طباعة | متوسط | لا | نعم | نعم | Medium | roadmap print |
| 48 | `prints/printable_daily_report_view.dart` | تقرير يومي > معاينة | تقرير يومي | نعم | Stack | نعم | مخاطرة جدول | جيد/طباعة | متوسط | لا | نعم | نعم | Medium | roadmap print |

## Dialog Inventory

| المجال | Dialogs/نقاط الاستدعاء | الفجوة الحالية | الخطورة | القرار |
|---|---:|---|---|---|
| الأصناف/البيع/الشراء/المصروف | 8 | أحجام ومسافات وأزرار غير موحدة؛ forms الكبيرة عرضة للضيق | High | component contract ثم ترحيل لاحق، دون تغيير validation |
| العملاء/الموردون/السلف/السداد | 12 | تكرار confirmation/form layout وترتيب أفعال متفاوت | High | توحيد تدريجي؛ شاشة الموردين فقط في العينة |
| المخزون والجرد | 5 | confirmations جيدة وظيفيًا لكن غير موحدة بصريًا | Medium | roadmap مخزون |
| الحسابات والتحويلات | 3 | أفعال مالية حساسة تحتاج فصلًا دلاليًا | High | الحسابات الأساسية في Phase 83، التحويل لاحقًا |
| الموافقات | 4 | تفاصيل بعرض ثابت؛ re-auth بلا إظهار/إخفاء؛ الحالة Chip غير دلالية | High | **Phase 83** مع بقاء domain كما هو |
| الإغلاق/النسخ/المسح | 3 | رسائل خطرة صحيحة وظيفيًا لكن responsive/semantics غير موحد | High | roadmap إعدادات/تقارير |
| **الإجمالي** | **35** | 21 Widget مسمى والباقي dialogs موضعية |  | لا يوجد modal sheet حاليًا |

## UI Gap Matrix

| Screen | Current route | Current UX problem | Functional or cosmetic | Severity | Mobile impact | Windows impact | Accessibility impact | Financial-risk impact | Reusable component needed | Proposed remediation | Included in Phase 83? | Deferred phase | Evidence or test |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AuthGate | home | Loading نصي غير موحد | Cosmetic | Low | منخفض | منخفض | لا live-region | Loading state | State view | state primitive | smoke فقط | — | route build test |
| Login | `/login` | لا هوية «غلال» مختصرة، لا إظهار كلمة مرور أو Enter | Functional | Medium | scaling محتمل | keyboard ناقص | focus/submit | لا | Auth scaffold/button | هوية حقيقية + show/hide + submit | نعم | — | 360×800، scaling، Enter |
| First owner setup | `/first-owner-setup` | يكرر Login layout | Cosmetic | Medium | scaling | متوسط | focus | هوية actor | Auth scaffold | استخدام tokens لاحقًا | لا | migration wave 2 | route smoke |
| Dashboard shell | `/dashboard` | الهاتف يعرض 5 من 16 وجهة بلا Drawer | **Functional** | **High** | يمنع 11 وحدة | لا | discoverability | قد يمنع الوصول للموافقات | Adaptive shell | 5 primary + More/Drawer؛ Rail واسع | نعم | — | navigation tests |
| Dashboard | shell 0 | Grid ثنائي ثابت حتى الهاتف الضيق، تجميع ضعيف | Functional/cosmetic | Medium | overflow/scaling | cards متمددة | headings | مؤشرات حساسة | Metric/section/grid | مجموعات حقيقية وgrid responsive | نعم | — | 360/390/1366 tests |
| Products | shell | أفعال cards غير متدرجة وبلا بحث موحد | Cosmetic | Medium | كثافة | جيد | touch/focus | مخزون | ListCard/Search | roadmap | لا | wave 2 | inventory audit |
| Customers | shell | قائمة طويلة بلا search/filter موحد | Functional | High | العثور صعب | متوسط | search semantics | تحصيلات | Search/ListCard | بعد نموذج الموردين | لا | wave 2 | source audit |
| Customer statement | push | جدول/أرقام على عرض ضيق | Cosmetic | Medium | قص محتمل | جيد | reading order | نعم | Responsive table | cards mobile/table desktop | لا | reports wave | viewport test |
| Customer advances | push | form/actions كثيرة محلية | Functional | High | ضغط أفعال | جيد | destructive grouping | عالٍ | FormSection/Dialog | ترحيل مالي مستقل | لا | financial wave | Phase 82 regression |
| Suppliers | shell | لا بحث أو فصل no-data/no-result؛ أزرار كثيرة | Functional | High | العثور/overflow | كثافة | touch/focus | سداد | Search/ListCard/Amount | بحث محلي واضح وقائمة responsive | نعم | — | filter + 360 tests |
| Supplier advances | push | form/actions محلية | Functional | High | ضغط أفعال | جيد | destructive grouping | عالٍ | FormSection/Dialog | ترحيل مالي مستقل | لا | financial wave | regression |
| Supplier statement | push | كشف وسداد في سطح كثيف | Functional | High | قص محتمل | جيد | grouping | عالٍ | PageHeader/Amount | roadmap | لا | financial wave | regression |
| Sales | shell | dialog ضخم وكثافة fields/actions | Functional | High | overflow محتمل | جيد | focus/validation | عالٍ | Responsive form | ترحيل معاملات مستقل | لا | transaction wave | sales tests |
| Purchases | shell | dialog ضخم ومسار دفع حساس | Functional | High | overflow محتمل | جيد | focus/validation | عالٍ | Responsive form | لا تغيير routing؛ ترحيل لاحق | لا | transaction wave | Phase 82 paid purchase tests |
| Supplier purchases | push | list cards غير موحدة | Cosmetic | Medium | متوسط | جيد | labels | نعم | ListCard | roadmap | لا | list wave | route smoke |
| Inventory | shell | أفعال وحركات كثيرة دون section shell | Functional | High | كثافة | جيد | focus | مخزون | Section/ListCard | roadmap | لا | inventory wave | inventory tests |
| Stock take | shell/push | input list كثيف | Functional | High | touch/scaling | جيد | input labels | مخزون | FormSection | roadmap | لا | inventory wave | stock tests |
| Adjustment report | shell/push | search/filter محلي غير مشترك | Cosmetic | Medium | جيد نسبيًا | جيد | filter state | مخزون | Search/Filter | roadmap | لا | report wave | filter tests |
| Expenses | shell | form محلي وحالات خطأ غير موحدة | Functional | High | متوسط | جيد | validation | عالٍ | Form/Dialog/State | roadmap | لا | transaction wave | approval regression |
| Financial accounts | shell | header actions وaccount row قد يفيضان؛ ألوان ثابتة | Functional | High | مرتفع | متوسط | status not semantic | عالٍ | PageHeader/Badge/Amount | responsive cards + semantic states | نعم | — | narrow/scaling tests |
| Account statement | push | سجلات وألوان مباشرة | Cosmetic | Medium | متوسط | جيد | color-only | عالٍ | Amount/Status | roadmap | لا | report wave | statement tests |
| Transfers | push | form حساس داخل Scaffold مستقل | Functional | High | متوسط | جيد | confirmations | عالٍ | Form/Dialog | roadmap | لا | financial wave | transfer tests |
| Approval list/details | shell/dialog | back داخلي معطل داخل Shell، fixed 560 detail، long IDs، Chip عام | Functional | High | قص/ازدحام | متوسط | status/color/action | شديد | Header/Badge/State/Dialog | تفاصيل responsive وحالات دلالية وفصل الأفعال | نعم | — | all 5 statuses + 360 tests |
| Financial reports hub | shell | cards متكررة وألوان muted ثابتة | Cosmetic | Medium | قائمة طويلة | جيد | grouping | عالٍ | ActionCard/Grid | roadmap | لا | report wave | route tests |
| Account balances | push | filter/table patterns محلية | Cosmetic | Medium | متوسط | جيد | color-only | عالٍ | Filter/Amount | roadmap | لا | report wave | report regression |
| Closing | push | أفعال خطرة تحتاج hierarchy موحد | Functional | High | متوسط | جيد | destructive semantics | شديد | Confirmation/Form | roadmap | لا | financial wave | Phase 80 |
| Account report | push | filter/table محلي | Cosmetic | Medium | متوسط | جيد | color-only | عالٍ | Filter/Amount | roadmap | لا | report wave | report regression |
| Payment method report | push | 4 فلاتر بتخطيط محلي | Cosmetic | Medium | كثافة | جيد | filter state | عالٍ | FilterBar | roadmap | لا | report wave | report regression |
| Transfer report | push | filter/status بألوان مباشرة | Cosmetic | Medium | كثافة | جيد | color-only | عالٍ | Filter/Badge | roadmap | لا | report wave | report regression |
| Inflows | push | لون أخضر مباشر وfilters محلية | Cosmetic | Medium | متوسط | جيد | color-only | عالٍ | Amount/Filter | roadmap | لا | report wave | report regression |
| Outflows | push | لون أحمر مباشر وfilters محلية | Cosmetic | Medium | متوسط | جيد | color-only | عالٍ | Amount/Filter | roadmap | لا | report wave | report regression |
| Customer collections report | push | cards/filters كثيرة | Cosmetic | Medium | كثافة | جيد | color-only | عالٍ | Filter/ListCard | roadmap | لا | report wave | Phase 79 |
| Supplier settlements report | push | cards/filters كثيرة | Cosmetic | Medium | كثافة | جيد | color-only | عالٍ | Filter/ListCard | roadmap | لا | report wave | Phase 79 |
| Advances/refunds report | push | ملف كبير وكثافة أفعال/حالات | Functional | High | مرتفع | متوسط | state meaning | عالٍ | Filter/Badge | roadmap | لا | report wave | report regression |
| Expense analysis | push | filters/cards محلية | Cosmetic | Medium | متوسط | جيد | charts/text | عالٍ | Filter/Metric | roadmap | لا | report wave | Phase 79 |
| Daily report | shell | surface طويل وحالات محلية | Cosmetic | Medium | كثافة | جيد | headings | عالٍ | Section/State | roadmap | لا | report wave | report regression |
| Document history | push | يخلط no-data/no-result ورسائل cards كثيفة | Functional | Medium | متوسط | جيد | search status | عالٍ | Search/Empty/List | roadmap | لا | list wave | search tests |
| Backup export | push | state/buttons خاصة | Cosmetic | Medium | منخفض | جيد | progress | تشغيلي | State/Button | roadmap | لا | settings wave | backup v1-v7 |
| Restore preview | push | نص/summary طويل وتحذير حساس | Functional | High | متوسط | جيد | confirmation | شديد | Summary/Confirm | roadmap | لا | settings wave | atomic restore |
| Data wipe | push | destructive surface محلي | Functional | High | متوسط | جيد | destructive semantics | شديد | DestructiveButton/Confirm | roadmap | لا | settings wave | wipe tests |
| Settings/appearance | shell | preset يخلط Accent وBrightness؛ لا System/Light/Dark | Functional | Medium | متوسط | متوسط | selected state | لا | Appearance selector | فصل ThemeMode عن accent مع persistence | نعم | — | restart/theme switch tests |
| Audit logs | shell | list states محلية | Cosmetic | Medium | منخفض | جيد | reading order | تدقيق | State/ListCard | roadmap | لا | list wave | audit tests |
| Help | push | يستخدم layout قديم فقط | Cosmetic | Low | منخفض | جيد | headings | لا | PageScaffold | tokens لاحقًا | لا | wave 2 | route smoke |
| Sales preview | push | جدول ثابت نسبيًا | Cosmetic | Medium | متوسط | جيد | table semantics | عالٍ | Print layout | roadmap | لا | print wave | printable tests |
| Purchase preview | push | جدول ثابت نسبيًا | Cosmetic | Medium | متوسط | جيد | table semantics | عالٍ | Print layout | roadmap | لا | print wave | printable tests |
| Customer preview | push | جدول ثابت نسبيًا | Cosmetic | Medium | متوسط | جيد | table semantics | عالٍ | Print layout | roadmap | لا | print wave | printable tests |
| Supplier preview | push | جدول ثابت نسبيًا | Cosmetic | Medium | متوسط | جيد | table semantics | عالٍ | Print layout | roadmap | لا | print wave | printable tests |
| Daily preview | push | تقرير متعدد الأقسام | Cosmetic | Medium | متوسط | جيد | headings | عالٍ | Print layout | roadmap | لا | print wave | printable tests |
| Shared dialogs | 35 calls | قياسات وأفعال وحالات loading غير موحدة | Functional | High | overflow محتمل | متوسط | focus/semantics | عالٍ | Confirmation/FormSection | contract مركزي ثم migration تدريجي | جزئي | per owning wave | small viewport dialog tests |

## التصنيف الأولي

- Critical: **0 مثبتة** من الفحص الساكن. لا يوجد دليل حالي على تنفيذ مالي خاطئ سببه الواجهة أو صفحة فرعية بلا أي مسار رجوع.
- High: **18 مجموعة/سطحًا**؛ أهمها فقدان 11 وجهة على الهاتف، كثافة معاملات البيع/الشراء، تفاصيل الموافقة بعرض ثابت، وفصل الأفعال المالية الحساسة.
- Medium: **28 مجموعة/سطحًا**؛ أبرزها تكرار search/filter/state patterns، الألوان المباشرة، وضعف text scaling.
- Low: **2**؛ AuthGate ودليل الاستخدام.
- يوجد Risk وظيفي قديم خارج التجميل: إنشاء حساب مالي من UI يبني `createdByUserId: 'owner'` حرفيًا بدل Actor ID الحقيقي. يجب تصحيحه باختبار محدود إن ثبت أن repository لا يستبدله؛ لا يبرر تغيير عقد مالي.

## نطاق الشاشات المرجعية المعتمد

1. `LoginScreen`: يثبت الهوية والـkeyboard/loading/error behavior.
2. `DashboardShell` + `DashboardScreen`: يثبت التنقل المتجاوب، التجميع، والبطاقات.
3. `NegativeBalanceApprovalRequestsScreen` بما فيه details dialog: يثبت الحالات الخمس والأفعال الحساسة دون تغيير State machine.
4. `FinancialAccountsScreen`: الشاشة المالية الكثيفة المختارة؛ لا تعديل للأرصدة أو repository rules.
5. `SuppliersScreen`: قائمة البحث المختارة؛ البحث local على النتائج المحملة ولا يغير repository contract.
6. قسم Appearance في `SettingsScreen`: يثبت System/Light/Dark وaccent persistence.

## خطة التنفيذ بعد بوابة الجرد

1. تثبيت Design tokens وsemantic theme extension وTypography/spacing/radius/breakpoints.
2. فصل `ThemeMode` عن accent مع قراءة متوافقة للملف القديم؛ لا Schema أو Backup change.
3. بناء adaptive shell واحد: Bottom navigation للوجهات اليومية + More/Drawer للهاتف، وNavigationRail/Sidebar لـWindows.
4. بناء مكونات composition صغيرة: page header/scaffold، metrics، status badge، loading/empty/error، search، responsive grid، financial amount.
5. ترحيل العينة بالترتيب: Login، Dashboard، Approvals، Financial Accounts، Suppliers، Appearance.
6. إضافة اختبارات responsive/RTL/semantics/navigation/theme، ثم تشغيل انحدارات Phase 82 والبوابات الكاملة.

## حدود لا تتغير

- لا تعديل لمعادلات، Ledger، PaymentRoutingPolicy، Approval state machine، Backup v7، أو schema.
- لا نسخ لاسم/شعار/نص/بيانات نظام الأدوية المرجعي.
- لا Demo data، ولا free-form color picker، ولا font dependency جديدة.
- هوية المنشأة الحالية (`BusinessIdentity`) وشعارها تُعاد استخدامهما؛ fallback النصي في Phase 83 يصبح «غلال» مع وصف مخازن الحبوب.
- Launcher icon أصل build asset وليس إعدادًا ديناميكيًا؛ شعار المنشأة داخل التطبيق/الفواتير مستقل عنه.

## حالة الإنجاز التفصيلية

| البند | الحالة |
|---|---|
| Audit completed | نعم — 51 نقطة دخول/انتقال و48 سطحًا بصريًا فعليًا، مع 35 موضع dialog؛ ويظل التحقق النهائي ضمن gates |
| Gap Matrix completed | نعم |
| Design foundation completed | نعم — tokens وsemantic colors وtypography وbreakpoints وLight/Dark/System وaccent presets وadaptive shell |
| Screens migrated | نعم — Login وDashboard/Shell وApproval list/details وFinancial Accounts وSuppliers وAppearance فقط |
| Screens deferred | موثقة في الجدولين |
| Full visual overhaul | **غير منفذ وغير مدعى** |

## التنفيذ النهائي لنطاق Phase 83

### القرارات البصرية

- الهوية الافتراضية داخل التطبيق هي «غلال»، مع استمرار أولوية اسم المنشأة وشعارها المحفوظين في `BusinessIdentity`.
- تم فصل سطوع الواجهة (`System`/`Light`/`Dark`) عن لون الهوية، مع ثلاثة presets مختبرة: الأخضر، الأزرق، والدافئ.
- ألوان المخاطر والحالات المالية دلالية وثابتة المعنى عبر كل presets؛ لا يعتمد عرض الحالة على اللون وحده.
- يستخدم التطبيق خط Arial المتوفر عبر النظام لدعم العربية؛ لم تُضف ملفات خطوط أو dependencies.
- الهاتف يستخدم أربع وجهات يومية مع «المزيد» لفتح كل الوجهات المصرح بها، بينما يستخدم Windows شريطًا جانبيًا قابلًا للتمرير؛ كلاهما يغير السطح نفسه ولا ينشئ نظامي تنقل وظيفيين.
- عرض المحتوى الواسع محدود لمنع تمدد البطاقات، وتتحول الأفعال من صف إلى التفاف آمن عند ضيق المساحة.
- Launcher icon أصل build ثابت، ولا يتغير تلقائيًا مع شعار المنشأة. شعار المنشأة الديناميكي يظل خاصًا برأس التطبيق والمطبوعات وفق العقد الحالي.

### الملفات والمكونات المركزية

- `app_tokens.dart`: spacing، radius، durations، breakpoints، icon/component sizes، shadows، typography.
- `app_semantic_colors.dart`: ThemeExtension للحالات التشغيلية والمالية في الوضعين.
- `app_theme.dart` و`app_theme_mode.dart`: بناء Light/Dark وفصل ThemeMode عن accent.
- `theme_settings_repository.dart` و`theme_controller.dart`: تخزين إعدادات المظهر بإصدار محلي مع قراءة ملف preset القديم.
- `ghalal_page_header.dart`، `ghalal_state_view.dart`، `ghalal_status_badge.dart`، `ghalal_search_field.dart`، `ghalal_theme_selector.dart`: primitives مشتركة للعينة المرحلة.
- `responsive_layout.dart`: تصنيف compact/tablet/desktop/wide وعدد أعمدة مناسب للقيود.

### سلوك الـShell والرجوع

- جميع وجهات الـShell المسموح بها متاحة على الهاتف عبر Drawer «المزيد»، بعد أن كانت 11 وجهة غير ظاهرة.
- الشاشات الواسعة تعرض sidebar قابلًا للتمرير ومحتوى محدود العرض.
- العودة من سطح فرعي تعيد إلى Dashboard داخل الـShell نفسه ولا تدفع نسخة Dashboard جديدة.
- `Alt+Left` يتبع عقد الرجوع نفسه على Windows في نطاق الـShell.
- `PageBackButton` يقبل مفتاحًا على الزر الفعلي لتسهيل الاختبار دون تغيير سلوكه.

### الشاشات المرحلة

1. **Login:** هوية غلال، الحقول الحقيقية فقط، إظهار/إخفاء كلمة المرور، Enter، autofill، وتعطيل الإرسال أثناء التحميل.
2. **Dashboard/Shell:** تجميع مقروء، بطاقات metrics متجاوبة، تنقل كامل على الهاتف وWindows.
3. **Approval list/details:** بحث وفلاتر RTL، حالات no-data/no-results منفصلة، badges نصية/أيقونية للحالات الخمس، dialog محدود بقيود الشاشة، مع بقاء صلاحيات وأفعال Phase 82 كما هي.
4. **Financial Accounts:** رأس وأفعال متجاوبة، حالة نشط/متوقف دلالية، loading/empty/error مع Retry، وتصحيح تمرير Actor الحقيقي من الجلسة عند إنشاء الحساب بدل النص الثابت القديم.
5. **Suppliers:** بحث محلي بالاسم/الهاتف/العنوان، no-data/no-results، وأفعال تلتف على الهاتف.
6. **Settings/Appearance:** System/Light/Dark وثلاثة accents محفوظة محليًا.

### الحماية الوظيفية والأداء

- لم تتغير schema أو migrations أو Backup v7 أو ledger أو PaymentRoutingPolicy أو approval state machine أو معادلات التقارير.
- تصحيح Actor في نموذج إنشاء الحساب يمرر `user.id` الحقيقي إلى العقد الموجود ولا يوسع العقد المالي.
- كشف full-suite race قديمًا في Stale detection: إنشاء الكيان وتعديله داخل دقة التخزين نفسها كان قد يُبقي `updatedAt` مساويًا. أصبحت مراجعات المورد/الصنف تتقدم رتيبًا بما لا يقل عن ثانية في Local وDrift، وهي دقة تخزين Drift الحالية؛ لا تتغير بيانات الطلب أو state machine، لكن التغيير الجوهري لا يمكن أن يفلت من المقارنة الزمنية.
- لا توجد query داخل `build` في الشاشات المرحلة، ولا تعاد البيانات عند تبديل الثيم.
- القوائم الموجودة تحتفظ بنمط التحميل الحالي؛ لم تُضف صور كبيرة أو ظلال ثقيلة أو `IntrinsicHeight/IntrinsicWidth` متكررة.

### دليل الاختبار

- اختبارات Phase 83 الجديدة تغطي الثيمات الثلاثة في Light/Dark، persistence والتوافق القديم، semantic statuses، العربية، الهوية، shell للهاتف/tablet/Windows، الرجوع وAlt+Left، resize، Login، Suppliers، Financial Accounts، Approvals، وAppearance.
- اختبارات Phase 82 الحالية تغطي تفاصيل طلب موافقة حقيقي على viewport ضيق، إخفاء فعل الاعتماد عن غير المالك، الإلغاء، والرجوع.
- أضيفت Assertions حتمية على تقدم `updatedAt` بعد restore ذي timestamp مستقبلي لكل من Local وDrift supplier/product repositories، لمنع عودة سباق Stale.
- نتائج الأعداد النهائية وAnalyzer وWindows build وGit تسجل في قسم الإغلاق بعد تشغيل البوابات النهائية، ولا تعتمد هذه الوثيقة نتيجة قديمة.

## أدلة الإغلاق النهائية

- تنسيق الملفات المعدلة فقط: PASS.
- الحزمة المركزة النهائية (Phase 83 + Phase 82 + payment routing + reports + closing + backup/migration): **257/257 PASS**.
- الحزمة الكاملة: **1522 passed، 1 skipped مقصود، 0 failed**.
- `flutter analyze --no-pub`: **No issues found**.
- `flutter build windows --release --no-pub`: **PASS**؛ تم إنتاج `grain_warehouse_erp_lite.exe`. تحذيرا CMake deprecation وMSVCRT linker غير حاجزين ولم يغيرا النتيجة.
- Schema/Backup: لا تغيير؛ schema يظل v14 وBackup يظل v7.
- مراجعة Git وCommit وannotated tag ونظافة الشجرة تُسجل من الأوامر النهائية بعد إضافة هذه الأدلة، ولا تُفترض هنا.
