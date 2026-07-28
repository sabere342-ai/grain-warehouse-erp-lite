# Phase 104A — First Repository Boundary Pilot Discovery & Exact Scope Freeze

تاريخ التجميد: 2026-07-28
نوع المرحلة: Discovery + Scope Freeze فقط
حالة التنفيذ: لا يوجد كود Production أو Test منفذ في هذه المرحلة.

## 1. النتيجة

تم اختيار عملية **قراءة قائمة سجل التدقيق المعروضة في شاشة سجل التدقيق** بوصفها أول Pilot لفصل قراءة محلية خلف عقد Repository مخصص للقراءة.

اكتملت بوابات التحقق بنجاح، والنتيجة هي:

`Outcome A — FULL SUCCESS: FIRST REPOSITORY BOUNDARY PILOT FROZEN`

## 2. نقطة البداية والفرع

- نقطة البداية الإلزامية: `34999e9f8ca11dfb5225703b70925164a283be50`.
- تم إثبات أن `HEAD` كان يساوي نقطة البداية حرفيًا قبل إنشاء الفرع.
- الفرع: `codex/phase-104a-first-repository-boundary-pilot-discovery-scope-freeze`.
- بدأت الشجرة وIndex نظيفين.
- لم يكن هناك merge أو rebase أو cherry-pick أو revert قيد التنفيذ.
- أُنشئ الفرع من الالتزام المحدد مباشرة؛ لم يحدث merge أو rebase أو cherry-pick.

## 3. حدود Phase 104A

المسموح الوحيد هو إنشاء هذه الوثيقة. المرحلة لا تنشئ Repository في Dart، ولا Adapter، ولا تنقل مستهلكًا، ولا تغير Composition أو Dependency Injection أو Query أو Schema أو Migration أو Dependency أو Test.

النتيجة البنيوية المتوقعة:

- Production files modified: `0`.
- Test files modified: `0`.
- Dependency files modified: `0`.
- Schema files modified: `0`.
- Documentation files created: `1`.

## 4. القيود الحاكمة من Phase 103

القرارات التالية تحكم اختيار الـPilot والمراحل اللاحقة:

1. تبقى Windows مدعومة، ويبقى السلوك الحالي متطابقًا أثناء الفصل التدريجي.
2. تبقى SQLite هي مخزن Windows الانتقالي، ثم cache/offline store/outbox مستقبلًا؛ لا تُحذف ولا يتغير Schema 15 هنا.
3. يجب فصل Presentation وApplication وDomain وRepository contracts وLocal/Remote data sources وPlatform capabilities.
4. لا يجوز أن تستدعي Widgets Drift أو SQL أو HTTP أو Cloud SDK مباشرة.
5. يجب أن تكون العقود Platform-neutral وألا تستورد Flutter أو Drift أو SQLite أو HTTP أو APIs خاصة بنظام تشغيل.
6. لا Backend ولا Remote API ولا Cloud migration ولا بيانات إنتاج حقيقية في Phase 104.
7. لا يبدأ Outbox أو Sync أو UUID أو Organization/branch/warehouse migration في هذا الـPilot.
8. لا تتغير قواعد المخزون أو المحاسبة أو النسخ الاحتياطي أو الصلاحيات.
9. تبقى الربحية `profitabilityNotActivated`، ولا تُفعّل بأي صورة.
10. لا يُختار Write مالي أو مخزني أو Transaction متعدد الجداول كأول Pilot.

## 5. منهج اختيار الـPilot

تم فحص الكود الفعلي لمسارات Drift المباشرة، ثم قورنت ثلاث عمليات قراءة فقط. استُخدمت المعايير التالية بالترتيب:

1. عدم وجود أي Mutation أو أثر مالي/مخزني.
2. عدم الحاجة إلى Transaction أو Schema/Migration أو Backend.
3. مستهلك واجهة واحد أو نطاق مستهلكين صغير.
4. عقد مخرجات صغير يمكن جعله Platform-neutral.
5. سلوك ترتيب وNullability واضحان وقابلان لاختبارات parity.
6. وجود اختبارات حالية على Query وController وScreen.
7. إمكان فصل المستهلك المحدد دون نقل الاستعمالات الجانبية للـRepository القديم.

قياس البحث داخل `lib/` أعطى:

| العملية الحالية | مرات الظهور | ملفات Production | الملاحظة |
| --- | ---: | ---: | --- |
| `listLogs()` | 9 | 7 | أصغر سطح؛ مستهلك UI واحد، مع استعمالات جانبية يمكن إبقاؤها خارج الـPilot |
| `listCustomers()` | 16 | 12 | ممتدة إلى المبيعات وحسابات العملاء والتقارير والنسخ الاحتياطي |
| `listSuppliers()` | 19 | 15 | ممتدة إلى المشتريات وحسابات الموردين والتقارير والنسخ الاحتياطي |

`listProducts()` فُحص أيضًا كمرجع استبعادي وظهر 28 مرة في 23 ملفًا، ويمتد إلى المخزون والتقييم والربحية؛ لذلك لم يدخل قائمة المرشحين النهائية الثلاثة.

## 6. مقارنة المرشحين

### 6.1 المرشح الأول — عرض قائمة سجل التدقيق

- الغرض: تحميل كل أحداث التدقيق المحلية وعرضها للأدوار المصرح لها، الأحدث أولًا.
- نقطة الدخول: `AuditLogsScreen` من وجهة سجل التدقيق في `DashboardShell`.
- الملفات الأساسية: `dashboard_shell.dart`، `audit_logs_screen.dart`، `audit_log_controller.dart`، `audit_log_repository.dart`، `drift_audit_log_repository.dart`، `audit_log_entry.dart`، `app_repositories.dart`، `foundation_database.dart`.
- موضع Drift: `DriftAuditLogRepository.listLogs()` ينفذ `select(auditLogs)` ثم `get()`.
- المستهلك المحدد: شاشة واحدة عبر `AuditLogController`.
- الاستعمالات الجانبية لنفس `listLogs()`: export/restore/wipe، snapshot rollback، وفحص داخل negative-balance approval workflow. كلها خارج الـPilot.
- النوع: Read-only.
- Transaction: لا.
- ارتباط محاسبي/مخزني: لا يكتب أو يحسب أو يغير أي قيد أو مخزون؛ محتوى السجل قد يصف أحداثًا سابقة فقط.
- الاختبارات الحالية المباشرة: 10 اختبارات مرتبطة بالمسار في 3 ملفات؛ موضحة في القسم 10.
- مخاطر الفصل: المحافظة على الترتيب، تفسير `metadataJson` التالف، Nullability لـ`referenceId`، وعدم توسيع الـPilot إلى كتابة سجل التدقيق.
- القرار: **مقبول ومختار**؛ أصغر سطح قابل للعزل مع مستهلك UI واحد.

### 6.2 المرشح الثاني — قراءة قائمة العملاء

- الغرض: تحميل العملاء مع اختيار تضمين غير النشطين.
- نقطة الدخول المرجعية: `CustomersScreen` عبر `CustomerController.loadCustomers()`.
- الملفات الأساسية: customer screen/controller/repository/Drift adapter/table، إضافة إلى عدة خدمات.
- موضع Drift: `DriftCustomerRepository.listCustomers()` على جدول `customers` مع ترتيب `createdAt` ثم `id` وفلتر `isActive` اختياري.
- عدد الظهور/الملفات: 16 ظهورًا في 12 ملف Production.
- النوع: Read-only؛ بلا Transaction للقراءة نفسها.
- الارتباط: العملية نفسها مرجعية، لكن مستهلكيها يشملون sales controller وحسابات العملاء وتقارير مالية وbackup/restore.
- الاختبارات: Durable customer repository واختبارات controller/screen وعمليات استعادة.
- مخاطر الفصل: سطح مستهلكين أوسع واحتمال جرّ حسابات العملاء والمبيعات إلى النطاق.
- القرار: **مرفوض كأول Pilot**؛ صالح لاحقًا بعد نجاح حد أصغر.

### 6.3 المرشح الثالث — قراءة قائمة الموردين

- الغرض: تحميل الموردين مع اختيار تضمين غير النشطين.
- نقطة الدخول المرجعية: `SuppliersScreen` عبر `SupplierController.loadSuppliers()`.
- الملفات الأساسية: supplier screen/controller/repository/Drift adapter/table، إضافة إلى المشتريات والحسابات والتقارير.
- موضع Drift: `DriftSupplierRepository.listSuppliers()` على جدول `suppliers` مع ترتيب `createdAt` ثم `id` وفلتر `isActive` اختياري.
- عدد الظهور/الملفات: 19 ظهورًا في 15 ملف Production.
- النوع: Read-only؛ بلا Transaction للقراءة نفسها.
- الارتباط: العملية نفسها مرجعية، لكن المستهلكين يشملون purchase flows وsupplier payables وfinancial reports وbackup/restore.
- الاختبارات: Durable supplier repository واختبارات controller/screen والمشتريات.
- مخاطر الفصل: احتمال توسيع Pilot بسيط إلى مسارات شراء ودفع محظورة.
- القرار: **مرفوض كأول Pilot**؛ سطحه أكبر من سجل التدقيق.

## 7. الـPilot المختار وأسباب الاختيار

العملية المختارة هي:

> تحميل read model لقائمة سجل التدقيق التي تحتاجها `AuditLogsScreen` فقط، مرتبة تنازليًا حسب الوقت ثم المعرّف.

أسباب الاختيار:

- Read-only بالكامل ولا تنشئ Audit row جديدة.
- لا تعتمد على Transaction.
- لا تغير محاسبة أو مخزون أو صلاحية أو وثيقة أو رصيد.
- لا تحتاج idempotency أو offline conflict أو Backend.
- لا توجد input parameters أو pagination أو search semantics لتجميدها الآن.
- مستهلك الواجهة واحد، ويمكن إبقاء export/restore/wipe/workflow على العقد القديم.
- مخرجات الشاشة الفعلية صغيرة: المعرّف، الوقت، الوصف العربي، ومرجع اختياري.
- الترتيب وفساد metadata مغطّيان حاليًا باختبارات Drift.
- يمكن إنشاء عقد Query منفصل دون تعريض Drift types أو نقل كتابة سجل التدقيق.

## 8. التتبع الحالي الكامل

1. **Navigation consumer:** `lib/features/dashboard/dashboard_shell.dart:75` يضيف `AuditLogsScreen()` كوجهة في Shell.
2. **Screen:** `lib/features/audit/audit_logs_screen.dart:29` ينشئ `AuditLogController` باستخدام `AppRepositories.auditLogRepository` عند عدم حقن Controller للاختبار.
3. **Screen trigger:** بعد أول frame، تفحص الشاشة المستخدم ثم تستدعي `_controller.loadLogs(user)` في السطر 33 تقريبًا. زر Retry يعيد الاستدعاء نفسه.
4. **Permission/state:** `lib/core/audit/audit_log_controller.dart:18` يرفض المستخدم غير الصالح أو غير الحاصل على `canViewAuditLogs`، يضبط loading، ثم يستدعي `_repository.listLogs()` في السطر 27.
5. **Composition:** `lib/app/app_repositories.dart:46-49` يحتفظ بالمستودع العام، و`initializeProduction()` يربطه بـ`DriftAuditLogRepository(database)` في السطر 113.
6. **Database adapter:** `lib/core/audit/drift_audit_log_repository.dart:16` يبني Query على `_database.auditLogs`.
7. **Drift operation:** `select(auditLogs)`، ثم `ORDER BY timestamp DESC, id DESC`، ثم `query.get()`.
8. **Mapping:** كل `AuditLogRow` يتحول إلى `AuditLogEntry`; `metadataJson` يمر عبر `jsonDecode` ويجب أن يكون JSON object.
9. **Presentation:** تعرض الشاشة `descriptionAr` ووقتًا محولًا محليًا و`referenceId` عند وجوده. التنسيق المحلي للوقت يبقى مسؤولية الشاشة.
10. **Storage:** جدول `AuditLogs` في `foundation_database.dart:315` يحتوي `id`, `timestamp`, `actionType`, `descriptionAr`, `actorId`, `referenceId`, `metadataJson`، مع indexes للوقت/action/reference.

لا توجد Application service أو Domain service بين Controller والمستودع حاليًا. لا توجد كتابة أو Transaction في هذا المسار.

## 9. الملفات المرتبطة بالمسار

### ملفات المسار المختار

- `lib/features/dashboard/dashboard_shell.dart`
- `lib/features/audit/audit_logs_screen.dart`
- `lib/core/audit/audit_log_controller.dart`
- `lib/core/audit/audit_log_repository.dart`
- `lib/core/audit/drift_audit_log_repository.dart`
- `lib/core/audit/audit_log_entry.dart`
- `lib/app/app_repositories.dart`
- `lib/core/persistence/foundation_database.dart`

### ملفات الاختبارات المباشرة

- `test/phase8i_durable_audit_log_repository_test.dart`
- `test/phase31_functional_recovery_test.dart`
- `test/phase89_settings_utilities_design_system_test.dart`

### استعمالات جانبية مستبعدة صراحة

- `lib/core/backup/backup_export.dart`
- `lib/core/backup/backup_restore_service.dart`
- `lib/core/backup/business_data_wipe_service.dart`
- `lib/core/financial_accounts/negative_balance_approval_workflow_service.dart`
- `_DriftAuditSnapshot` داخل `drift_audit_log_repository.dart`

وجود هذه الاستعمالات هو سبب إنشاء عقد قراءة خاص بالشاشة بدل تغيير معنى `AuditLogRepository.listLogs()` الحالي لكل النظام.

## 10. الاختبارات الحالية التي تغطي المسار

اعتُبرت 10 اختبارات مرتبطة مباشرة بالـPilot:

- 7 اختبارات في `phase8i_durable_audit_log_repository_test.dart` تغطي القراءة الفارغة، إعادة الفتح، newest-first، round-trip للـmetadata، الفشل المغلق عند metadata تالفة، التسلسل/التوازي، rollback، wipe/restore، وmigration. بعض الاختبارات تجمع أكثر من سلوك في test واحد.
- اختبار واحد في `phase31_functional_recovery_test.dart` يغطي owner-only controller ونجاح/رفض `loadLogs()`.
- اختباران في مجموعة `AuditLogsScreen` داخل `phase89_settings_utilities_design_system_test.dart` يشغّلان مسار تحميل الشاشة ويثبتان header/empty state. اختبار الرفض للموظف يحمي الصلاحية لكنه لا يصل إلى Repository، لذلك لم يدخل العدد 10.

اختبارات backup والعمليات المالية التي تفحص audit rows تبقى regression evidence جانبية، وليست ضمن عقد الـPilot.

## 11. الوصول المباشر إلى Drift/SQLite

الوصول المباشر المحدد بدقة هو داخل `DriftAuditLogRepository.listLogs()`:

```text
FoundationDatabase
  -> select(AuditLogs)
  -> orderBy(timestamp DESC, id DESC)
  -> get()
  -> AuditLogRow
  -> jsonDecode(metadataJson)
  -> AuditLogEntry
```

- لا يوجد SQL خام في هذا المسار.
- لا يوجد `transaction()`.
- لا توجد كتابة أو sequence allocation.
- الـQuery يعيد كل الصفوف؛ لا pagination ولا filter.
- القائمة النهائية non-growable، والترتيب من Adapter لا من الشاشة.

## 12. العقد المستقبلي المجمد

العقد المقترح توثيقيًا، ولا يُنشأ في Phase 104A:

```dart
abstract interface class AuditLogReadRepository {
  Future<List<AuditLogReadModel>> listAuditLogs();
}
```

والـread model المجمد:

```dart
final class AuditLogReadModel {
  const AuditLogReadModel({
    required this.id,
    required this.timestamp,
    required this.descriptionAr,
    this.referenceId,
  });

  final String id;
  final DateTime timestamp;
  final String descriptionAr;
  final String? referenceId;
}
```

### دلالات العقد

- اسم Repository: `AuditLogReadRepository`.
- اسم العملية: `listAuditLogs`.
- Input parameters: لا يوجد.
- Return type: `Future<List<AuditLogReadModel>>`.
- Nullability: الـFuture والقائمة والعناصر والحقول `id/timestamp/descriptionAr` غير nullable؛ `referenceId` فقط nullable.
- عدم وجود بيانات: قائمة فارغة، وليس `null` وليس Exception.
- نوع النتيجة: Read model خاص بالمستهلك، وليس Drift row ولا نسخة من write entity الكامل.
- Async: نعم.
- الترتيب: `timestamp` تنازليًا، ثم `id` تنازليًا عند تساوي الوقت.
- Mutability: يعيد Adapter قائمة غير قابلة للتعديل من المستهلك.
- Filter/pagination: غير موجودين في العقد المجمد؛ إضافتهما تحتاج مرحلة لاحقة.

## 13. Error semantics

يجمد 104B vocabulary صغيرًا Platform-neutral داخل ملف العقد نفسه:

- `storageUnavailable`: تعذر إتمام القراءة من مصدر البيانات.
- `corruptData`: صف مخزن لا يمكن تحويله بأمان إلى read model.
- `unexpected`: فشل غير مصنف عند حد الـAdapter.

تظهر هذه القيم من خلال `AuditLogReadException` لا يحمل Drift exception أو SQL row أو مسار ملف. لا يسمح العقد بتسريب استثناءات Drift إلى المستهلك.

سلوك النظام الحالي:

- رفض الصلاحية يُعالج داخل `AuditLogController` برسالة owner-only وإرجاع `false`.
- خطأ القراءة/فشل `jsonDecode` لا يُلتقط حاليًا داخل Controller؛ ينتشر، وقد يبقى loading مضبوطًا.

حفاظًا على parity، لا يضيف 104B أو 104C رسالة UI أو retry policy. عند تحويل المستهلك في 104D يجب ألا تتغير النتيجة المرئية الناجحة، ويجب أن يبقى failure غير مكتوم؛ تحسين UX للفشل مرحلة مستقلة.

## 14. ملكية التحويل والترتيب والـcache

- تعريف `AuditLogReadModel` وerror vocabulary: طبقة العقد Platform-neutral.
- تحويل `AuditLogRow` وفحص/فك `metadataJson`: SQLite/Drift adapter في 104C.
- إسقاط الحقول غير المطلوبة (`actionType`, `actorId`, `metadata`) من read model: Adapter، وفق العقد المجمد.
- ترتيب النتائج: العقد يحدد المعنى، والAdapter يطبقه في Query؛ لا يعاد الترتيب في Controller أو Screen.
- فحص الصلاحية وحالة loading: Controller/Application edge، خارج Repository.
- تنسيق الوقت محليًا والعرض: Screen، خارج Repository.
- اختيار local مقابل remote أو cache policy مستقبلًا: Application/composition layer؛ ليس مسؤولية Widget أو العقد. لا Remote cache في 104B–104E.

## 15. قواعد Platform-neutrality

يحظر على ملف العقد وread model أن يستورد أو يكشف:

- `drift` أو أي generated table/data class.
- `FoundationDatabase`, `DatabaseConnection`, `QueryExecutor`.
- SQL rows أو companions أو expressions.
- `dart:io` أو file paths.
- Windows/Android/iOS APIs.
- Flutter widgets أو `ChangeNotifier`.
- HTTP أو provider/cloud SDKs.

يسمح فقط بأنواع Dart و`DateTime` و`List` و`String` وبأنواع الخطأ المعرفة في العقد.

## 16. مطابقة SQLite الحالية للسلوك

يجب أن يثبت Adapter 104C parity حرفيًا مع القراءة الحالية:

1. نفس مجموعة صفوف `audit_logs` كاملة.
2. نفس الترتيب `timestamp DESC, id DESC`.
3. نفس قيم `id`, `timestamp`, `descriptionAr`, `referenceId`.
4. قائمة فارغة عند عدم وجود صفوف.
5. بقاء `referenceId == null` دون تحويل إلى نص فارغ.
6. فشل مغلق عند صف تالف؛ يترجم إلى `corruptData` بدل تسريب `FormatException`.
7. عدم تنفيذ insert/update/delete/transaction/sequence.
8. عدم تغيير Schema أو indexes أو generated files.

## 17. ما يبقى خارج Repository الجديد

في المراحل التالية يبقى خارج العقد الجديد:

- فحص `AppUser` و`canViewAuditLogs`.
- `AuditLogController` وحالة loading/error/entries حتى Phase 104D.
- Screen widgets، local time formatting، navigation، empty/loading/denied views.
- `record(AuditLogDraft)` وكل كتابة Audit.
- restore، owner wipe، transaction snapshot، وbackup export.
- فحص negative-balance workflow لسجل موجود.
- Global `AppRepositories` cleanup العام.
- Remote API، server audit، organization scope، pagination، search، sync، outbox.

## 18. Scope freeze لـPhase 104B

### الملفات المسموح إنشاؤها/تعديلها فقط

1. `lib/core/audit/audit_log_read_repository.dart` — عقد القراءة والـread model وerror vocabulary فقط.
2. `test/phase104b_audit_log_read_repository_contract_test.dart` — اختبارات العقد والنموذج فقط.

لا يجوز أن يحتاج 104B ملفًا ثالثًا. إذا ظهر احتياج حقيقي، يتوقف 104B بنتيجة Safe Blocked بدل توسيع allowlist ضمنيًا.

### الملفات المحظور تعديلها في 104B

- كل ملف غير الملفين السابقين، وبالأخص:
- `lib/core/audit/audit_log_repository.dart`
- `lib/core/audit/drift_audit_log_repository.dart`
- `lib/core/audit/audit_log_controller.dart`
- `lib/features/audit/audit_logs_screen.dart`
- `lib/app/app_repositories.dart`
- `lib/core/persistence/foundation_database.dart`
- `lib/core/persistence/foundation_database.g.dart`
- كل ملفات backup والfinancial workflows.
- كل ملفات platform و`pubspec.yaml` و`pubspec.lock`.

### الاختبارات المطلوبة في 104B

- Compile-time use لعقد `AuditLogReadRepository` بواسطة Fake بلا imports بنيوية.
- بناء read model بقيم non-null وبـ`referenceId` null/non-null.
- عقد القائمة الفارغة وعدم استخدام null لغياب النتائج.
- ثبات error kinds الثلاثة وعدم وجود raw cause/vendor type في الواجهة العامة.
- توثيق/اختبار أن read model لا يحتوي `metadata`, `actorId`, أو Drift row.
- لا Drift parity test في 104B؛ مكانه 104C.

### ما لن ينفذه 104B

- لا Adapter.
- لا Query.
- لا تغيير مستهلك أو DI/Composition.
- لا تعديل للـdomain entity الحالي.
- لا Remote source ولا cache ولا backend.
- لا schema/migration/generated code.

## 19. تقسيم 104B–104E

### Phase 104B — Introduce the Frozen Repository Contract

ينشئ فقط العقد والـread model/error vocabulary واختبارات العقد وفق allowlist القسم 18. لا مستهلك ولا Adapter.

### Phase 104C — Add One SQLite/Drift Adapter with Parity Tests

ينشئ Adapter واحدًا مقترح الاسم `DriftAuditLogReadRepository` واختبار parity واحدًا. يقارن المخرجات المطلوبة بالعقد مع سلوك `DriftAuditLogRepository.listLogs()` الحالي، ويثبت empty/order/tie-break/null/corrupt-data/no-write. لا يغير المستهلك ولا العقد القديم ولا Schema.

### Phase 104D — Move One Consumer Through Minimal Composition

يحوّل `AuditLogsScreen` عبر `AuditLogController` فقط إلى `AuditLogReadRepository`، ويربط الـAdapter في أبسط Composition getter داخل `AppRepositories`. لا تُنقل backup أو wipe أو restore أو negative-balance workflow. لا تتغير شاشة أخرى.

### Phase 104E — Remove Legacy Access for This Path and Regress

يزيل فقط أي bridge/import/constructor fallback مؤقت يسمح لـ`AuditLogsScreen` أو `AuditLogController` بالرجوع إلى `AuditLogRepository.listLogs()`. لا يحذف `listLogs()` من العقد القديم لأنه ما زال يخدم الاستعمالات الجانبية. يشغل regression verification ويثبت أن المستهلك المختار لا يصل إلى العقد القديم أو Drift مباشرة.

لا توجد Phase 105 ضمن هذا النطاق.

## 20. المخاطر وRollback boundary

| الخطر | الحد الوقائي |
| --- | --- |
| توسيع القراءة إلى كتابة audit | العقد Query-only ولا يحتوي `record/restore/clear` |
| كسر ترتيب الشاشة | الترتيب جزء صريح من العقد واختبارات parity |
| تسريب metadata تالفة أو Drift exception | Adapter mapping و`corruptData` Platform-neutral |
| جر backup/approval workflow إلى الـPilot | الاستعمالات الجانبية مستبعدة وتبقى على العقد القديم |
| تغيير صلاحيات owner-only | الصلاحية خارج Repository ولا تتغير قبل 104D |
| تغيير Schema أو generated files | محظور صراحة في 104B–104E لهذا الـPilot |
| تغيير السلوك المرئي | parity يثبت القائمة والترتيب والحقول؛ لا UX جديد للفشل |

Rollback boundary لكل مرحلة هو ملفات allowlist الخاصة بها فقط. لا rollback لبيانات أو Schema لأن المراحل لا تجري Migration ولا Mutation. في 104D/104E يمكن إعادة توصيل المستهلك بالعقد القديم دون تحويل بيانات، مع بقاء Adapter الجديد غير مستخدم أو حذفه ضمن ملفات المرحلة فقط.

## 21. Non-goals

- لا تنفيذ Repository أو Adapter الآن.
- لا فصل كتابة سجل التدقيق.
- لا إعادة تصميم audit authorization أو server audit.
- لا pagination/search/filter.
- لا نقل backup/export/restore/wipe.
- لا تعديل financial approval workflows.
- لا Backend أو HTTP أو Remote API أو cloud provider.
- لا Outbox أو Sync أو UUID أو tenant scope.
- لا Schema أو Migration أو generated code.
- لا mobile redesign أو compileSdk.
- لا profitability activation ولا بيانات مالك أو إنتاج.

## 22. Owner decisions required

لا يوجد قرار مالك مطلوب لبدء 104B؛ العملية والعقد والـallowlist مجمدة بما يكفي. قرارات provider وserver audit retention وorganization scope وpagination تبقى مؤجلة لمراحلها ولا تعيق هذا الـPilot المحلي.

أي رغبة في توسيع read model ليشمل `metadata` أو `actorId/actionType` قبل 104C تحتاج Scope Freeze جديدًا؛ لا تُفترض ضمنيًا.

## 23. Acceptance criteria

تنجح Phase 104A فقط إذا:

- ثبت baseline والفرع ونظافة البداية.
- قورنت ثلاثة مرشحين من الكود الفعلي.
- اختير Pilot واحد فقط، Read-only وبلا Transaction أو أثر مالي/مخزني.
- وُثق call path الكامل وموضع Drift والmapping/errors/tests/side uses.
- جُمّد عقد Platform-neutral وScope 104B بملفين فقط.
- لم يتغير Production أو Test أو Dependency أو Schema.
- الملف الجديد الوحيد هو هذه الوثيقة قبل Commit.
- نجح `git diff --check` وAnalyzer وFull tests وFormatter check.
- أُنشئ Commit واحد بالرسالة المطلوبة، ثم أصبحت الشجرة نظيفة.
- لم يحدث Push أو Tag.

## 24. Evidence commands

أوامر الاكتشاف الأساسية:

```text
git status --short --branch
git rev-parse HEAD
git branch --show-current
rg -n "listLogs\(" lib test -g "*.dart"
rg -n "listCustomers\(" lib -g "*.dart"
rg -n "listSuppliers\(" lib -g "*.dart"
rg -n "listProducts\(" lib -g "*.dart"
rg -n "FoundationDatabase|\.select\(|customSelect|selectOnly" lib -g "*.dart" -g "!*.g.dart"
```

بوابات التحقق النهائية:

```text
git status --short
git diff --stat
git diff --check
flutter analyze --no-pub
flutter test --no-pub
<direct-dart-sdk> format --output=none --set-exit-if-changed <current Dart files>
git diff --name-only <baseline>..HEAD
git status --short --branch
```

## 25. حالة التحقق والبناء

| البوابة | النتيجة |
| --- | --- |
| `flutter analyze --no-pub` | Pass — `No issues found`، Exit 0، وزمن Analyzer المبلغ 260.2 ثانية |
| `flutter test --no-pub --reporter compact` | Pass — 1,910 اختبارات ناجحة، skip واحد قائم، `All tests passed`، Exit 0، 546.8 ثانية |
| Direct Dart formatter | Pass — 362 ملف Dart، 0 changed، Exit 0، 13.17 ثانية |
| `git diff --check` | Pass قبل staging؛ يعاد على staged diff قبل Commit |
| Scope check | Pass — المسار الوحيد المتغير هو مستند Phase 104A المصرح به |

ملاحظة التحقق: محاولة أولى شغّلت Analyzer وtests بالتوازي، فتزاحمت أوامر Flutter على startup lock وانتهت محاولة الاختبار بفشل واحد. لم تُستخدم تلك المحاولة كدليل نجاح. أُعيد Full suite منفردًا في حالة عمليات نظيفة ونجح كاملًا بالنتيجة المثبتة أعلاه.

Builds:

`Not performed — documentation-only atomic scope`

لا توجد Production أو Platform أو Dependency أو Schema changes تبرر Windows/Android/iOS builds.

## 26. الحالة التجارية

- لا Cloud migration.
- لا Backend.
- لا Remote API.
- لا بيانات إنتاج حقيقية.
- لا تفعيل ربحية.
- الحالة ما زالت `profitabilityNotActivated`.

## 27. المرحلة التالية الوحيدة المقترحة

عند Outcome A فقط:

**Phase 104B — Introduce the Frozen Repository Contract for the Selected Pilot**

لا يبدأ 104C معها، ولا يُنشأ Adapter أو ينقل مستهلك في 104B.

## 28. Final outcome classification

`Outcome A — FULL SUCCESS: FIRST REPOSITORY BOUNDARY PILOT FROZEN`

ثبتت بوابات الكود والاختبارات والتنسيق ونطاق الملفات. يكتمل الدليل التشغيلي للنتيجة بإنشاء Commit المرحلة الواحد والتحقق من نظافة الشجرة بعده؛ لا Push ولا Tag.
