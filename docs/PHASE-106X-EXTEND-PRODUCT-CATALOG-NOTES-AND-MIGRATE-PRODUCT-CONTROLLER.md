# Phase 106X — Extend Product Catalog Read Contract with Notes and Migrate ProductController

## 1. النتيجة التنفيذية

**Outcome A — FULL SUCCESS**

نُفذت التوسعة والترحيل الذريان المطلوبان فقط: أضيف `String? notes`
إلى `ProductCatalogReadModel`، ورُحّل `PRC-104 —
ProductController.loadProducts` من قراءة `ProductRepository.listProducts`
إلى `ProductCatalogReadRepository.listProductCatalog`. لم يُرحّل أي مستهلك
آخر، ولم يحدث أي تغيير في schema أو migrations أو generated Drift files.

## 2. نقطة البداية وحالة Git

| البند | القيمة |
| --- | --- |
| Starting HEAD | `b7d5086b4194b0dc2682b54ea5aa8fc79b314e1a` |
| Starting commit | `PHASE 106W: freeze next product read migration target` |
| حالة الشجرة قبل التنفيذ | نظيفة؛ لا staged أو unstaged أو untracked |
| فرع التنفيذ | `codex/phase-106x-extend-product-catalog-notes-migrate-product-controller` |
| الهدف المجمد | `PRC-104 — ProductController.loadProducts` |
| رسالة الالتزام المطلوبة | `PHASE 106X: extend product catalog notes and migrate product controller` |

## 3. المسار القديم والمسار الجديد

المسار القديم:

```text
ProductsScreen
→ ProductController.loadProducts
→ ProductRepository.listProducts
```

المسار الجديد:

```text
ProductsScreen
→ ProductController.loadProducts
→ ProductCatalogReadRepository.listProductCatalog
```

ظل تعبير الصلاحية حرفيًا ودلاليًا:

```dart
includeInactive: user.permissions.canManageProducts
```

وبذلك يرى المدير المنتجات النشطة وغير النشطة، بينما يرى غير المدير المنتجات
النشطة فقط. وظل ترتيب المستودع `createdAt ASC` ثم `id ASC` دون إعادة ترتيب في
المتحكم أو الشاشة.

## 4. عقد القراءة قبل التوسعة وبعدها

قبل Phase 106X كان النموذج يحمل الحقول الثمانية التالية:

```dart
String id
String name
String? code
GrainUnit unit
bool isActive
int? referenceCostPricePiastersPerKg
int? defaultSalePricePiastersPerKg
int? minimumSalePricePiastersPerKg
```

بعد Phase 106X يحمل الحقول نفسها دون تغيير، إضافة إلى الحقل التاسع الوحيد:

```dart
String? notes
```

لم يُضف أي حقل آخر، ولم يتغير اسم أو نوع أو nullable status لأي حقل سابق.
تظل الحقول المالية الثلاثة بالقروش لكل كيلوجرام، ويظل `id` من نوع `String`.

## 5. مصدر notes ودلالته

المصدر الفعلي هو عمود Drift الموجود مسبقًا:

```dart
Products.notes // TextColumn, nullable
```

يختار adapter العمود عبر `products.notes` ويربطه مباشرة هكذا:

```dart
notes: row.read(products.notes)
```

لذلك:

- تبقى قيمة قاعدة البيانات `null` كما هي `null`.
- يبقى النص الفارغ المخزن `''` نصًا فارغًا.
- تبقى المسافات والنصوص غير الفارغة كما هي.
- لا يوجد `.trim()` أو normalization أو fallback أو formatting.

لم يتغير `foundation_database.dart` أو `foundation_database.g.dart`، ولم تتغير
`schemaVersion`، ولم تُضف migration؛ العمود كان موجودًا أصلًا والمطلوب كشفه
فقط عبر read model.

## 6. تحليل ProductController والترحيل

قبل الترحيل كانت حالة المتحكم `List<Product>` وكان الاعتماد الواحد
`ProductRepository` مستخدمًا للقراءة والكتابة. أثبت فحص الشاشة أن العرض ونموذج
التحرير لا يحتاجان أكثر من حقول read model التسعة، وأن mutations تحتاج `id`
و`ProductDraft` فقط.

بعد الترحيل أصبحت الحالة:

```dart
List<ProductCatalogReadModel>
```

وفُصل الاعتمادان بأقل تغيير:

```dart
ProductCatalogReadRepository // loadProducts فقط
ProductRepository            // create/update/setActive فقط
```

ظل نجاح أي mutation يستدعي `loadProducts`، ولذلك يمر refresh عبر read contract
الجديد. لا يستخدم read repository في mutation، ولا يستخدم write repository
لقراءة القائمة، ولا توجد قراءة مزدوجة أو fallback أو `getProductById` أو N+1
أو تحويل إلى كائنات `Product` مصطنعة.

حافظ `loadProducts` على loading state والإشعارات ودلالة تمرير الأخطاء السابقة
دون silent catch أو retry. حافظت الشاشة على العرض، ملء حقول التحرير، الرسائل،
الصلاحيات، الأسعار، الملاحظات، والتفعيل/الإيقاف.

## 7. ملفات production المعدلة

- `lib/core/catalog/product_catalog_read_repository.dart`: إضافة الحقل التاسع
  `String? notes` فقط.
- `lib/core/catalog/drift_product_catalog_read_repository.dart`: اختيار
  `products.notes` وربطه مباشرة مع الحفاظ على filter والترتيب.
- `lib/core/catalog/product_controller.dart`: فصل read dependency عن write
  dependency وترحيل `loadProducts` وتغيير نوع حالة القائمة.
- `lib/features/products/products_screen.dart`: حقن مستودع القراءة وتغيير أنواع
  عناصر العرض/التحرير إلى `ProductCatalogReadModel` فقط.
- `lib/app/app_repositories.dart`: تمرير `notes` ميكانيكيًا في legacy local
  composition adapter؛ production composition ما زال يوفر
  `DriftProductCatalogReadRepository` الحقيقي.

لم تتغير أي ملفات persistence أو schema أو generated files أو dependencies.

## 8. ملفات الاختبارات المعدلة

### اختبارات العقد والـadapter المباشرة

- `test/phase105b_product_catalog_read_contract_test.dart`: يثبت النوع، النص
  verbatim، النص الفارغ، و`null`.
- `test/phase105c_local_drift_product_catalog_read_adapter_test.dart`: يثبت
  `notes` النصية و`null` والنص الفارغ، الفلترة، الأسعار، والترتيب الفعلي عبر
  SQLite/Drift adapter.
- `test/phase106j_product_catalog_read_model_reference_cost_test.dart`
- `test/phase106u_product_catalog_read_contract_expansion_test.dart`
- `test/support/product_catalog_read_repository_test_adapter.dart`

### اختبار Phase 106X وProductController

- `test/phase106x_product_controller_product_catalog_migration_freeze_test.dart`:
  تسعة اختبارات للسلوك، الصلاحيات، loading/error، الفصل بين القراءة والكتابة،
  refresh بعد mutations، بنية المصدر، عمود Drift، عدم تغير persistence، وعدم
  ترحيل مستهلك ثانٍ.
- `test/product_catalog_test.dart`: تحديث إنشاء المتحكم مع read test adapter مع
  بقاء اختبارات CRUD وواجهة المنتجات.
- `test/phase11_ux_test.dart`
- `test/phase21b_pricing_cost_minimum_ui_acceptance_test.dart`
- `test/phase21c_profit_stock_valuation_reports_test.dart`
- `test/phase21d_end_to_end_business_release_test.dart`

### fixtures وحراس المراحل السابقة

أضيف `notes: null` ميكانيكيًا إلى fixtures المباشرة في:

- `test/inventory_attention_service_test.dart`
- `test/phase105d_product_catalog_application_read_boundary_migration_test.dart`
- `test/phase105f_product_catalog_read_boundary_pilot_acceptance_freeze_test.dart`
- `test/phase106e_inventory_attention_product_catalog_read_migration_test.dart`
- `test/phase106g_genuine_runtime_dashboard_service_product_catalog_read_integration_test.dart`
- `test/phase106h_dashboard_service_product_catalog_read_migration_acceptance_freeze_test.dart`
- `test/phase106k_local_report_repository_daily_activity_product_read_migration_test.dart`
- `test/phase106u_sale_controller_product_catalog_read_migration_test.dart`

ورُقّيت حراس القوائم/الخط الزمني دون حذف assertions سابقة أو تغيير الأدلة
التاريخية، لتعكس الحقل التاسع والمستهلك العاشر فقط، في:

- `test/phase106p_purchase_controller_product_catalog_read_migration_test.dart`
- `test/phase106q_next_product_read_migration_target_discovery_freeze_test.dart`
- `test/phase106r_inventory_controller_product_catalog_read_migration_guard_test.dart`
- `test/phase106s_inventory_controller_product_catalog_runtime_integration_test.dart`
- `test/phase106t_next_product_read_migration_target_freeze_test.dart`
- `test/phase106u_sale_controller_product_catalog_read_migration_freeze_test.dart`
- `test/phase106v_sale_controller_product_catalog_runtime_integration_test.dart`
- `test/phase106w_next_product_read_migration_target_freeze_test.dart`

## 9. أدلة عدم توسيع النطاق

- البحث الحالي يجد عشرة ملفات production تستدعي `.listProductCatalog(`؛ الفرق
  عن baseline هو `lib/core/catalog/product_controller.dart` فقط.
- `ProductController.loadProducts` لا يحتوي `listProducts` أو fallback أو
  lookup إضافيًا.
- `ProductRepository` باقٍ داخل المتحكم لأعمال الكتابة الثلاثة فقط.
- `ProductCatalogReadRepository` لا يحتوي أي write method.
- `git diff <Starting HEAD> -- lib` يحتوي ملفات production الخمسة المسموح بها
  فقط.
- لا يوجد تعديل في `lib/core/persistence`.

## 10. نتائج التحقق

| التحقق | النتيجة |
| --- | --- |
| `flutter test test/phase106x_product_controller_product_catalog_migration_freeze_test.dart` | PASS — 9 passed |
| `flutter test test/product_catalog_test.dart` | PASS — 15 passed |
| Product Catalog contract/adapter targeted suite | PASS — 28 passed |
| Phase 106Q/106T/106V/106W guard suite | PASS — 56 passed |
| Updated Phase 106U freeze guard | PASS — 11 passed |
| Updated Phase 106P/106R/106S guard suite | PASS — 39 passed |
| related Phase 105B/105C/105F/106J/106O/106Q/106T/106V/106W/106X guards | PASS (also covered by full suite) |
| `flutter test` | PASS — 2226 passed, 1 skipped, 0 failed |
| `flutter analyze` | PASS — No issues found |
| `dart format --output=none --set-exit-if-changed .` | PASS — 403 files checked, 0 changed |
| `git diff --check` | PASS |

## 11. ملخص diff وحالة Git النهائية

قبل إضافة هذا التقرير كان tracked diff يتكون من 31 ملفًا، بإجمالي `318`
إضافة و`109` حذف، إضافة إلى اختبار Phase 106X الجديد. معظم عدد الملفات ناتج عن
إضافة constructor argument الإلزامي إلى fixtures، تحديث حقن المتحكم في خمسة
اختبارات، وترقية حراس الخط الزمني الدقيقة.

ستكون المرحلة التزامًا واحدًا فقط بعد baseline بالرسالة:

```text
PHASE 106X: extend product catalog notes and migrate product controller
```

يُسجل Final HEAD الكامل في handoff التنفيذي بعد إنشاء الالتزام، لأن الالتزام
لا يمكن أن يحتوي hash الخاص به. فحص ما بعد الالتزام يجب أن يثبت:

- commit count بعد baseline يساوي `1`.
- الشجرة النهائية نظيفة.
- لا Push.
- لا Tag.
- لا amend أو rebase أو merge commit.

## 12. حدود Phase 106Y المقترحة

لم تُنفذ Phase 106Y هنا. نطاقها المقترح هو إثبات runtime حقيقي للمسار:

```text
App composition
→ ProductController
→ ProductCatalogReadRepository
→ DriftProductCatalogReadRepository
→ Drift
→ SQLite in-memory products table
```

ويشمل إثبات الفلترة بصلاحية `canManageProducts`، وصول `notes` النصية وبقاء
`null`، القيم المالية، الترتيب، عدم استدعاء legacy `listProducts`، وبقاء
عمليات الكتابة خارج read repository. لا ينبغي لPhase 106Y ترحيل مستهلك جديد أو
توسيع العقد أو إعادة تصميم CRUD.

## 13. النتيجة النهائية

**Outcome A — FULL SUCCESS**

Phase 106X توسّع عقد القراءة بالحقل `String? notes` وترحّل
`ProductController.loadProducts` فقط، مع الحفاظ على دلالة الصلاحيات والترتيب
والأسعار وCRUD، ودون schema change أو runtime proof خاص بPhase 106Y.
