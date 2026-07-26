# Phase 101H — Video-Derived Visual Consistency, Dark-Surface & UI Presentation Remediation

## الهدف والنتيجة

مراجعة تسجيل المالك كاملًا، إثبات عيوب العرض القابلة لإعادة الإنتاج، وإصلاح السبب المشترك بأقل تغيير آمن دون مساس بالمحاسبة أو البيانات. النتيجة: **OUTCOME A — FULL SUCCESS** ضمن النطاق البصري للمرحلة.

نجاح هذه المرحلة لا يمثل قبول عميل ولا يعلن الجاهزية التجارية. تظل Phase 101G والحالة التجارية: `BLOCKED — GENUINE CLIENT SESSION REQUIRED`.

## Baseline وPreflight

| البند | الدليل |
|---|---|
| المستودع | `C:\dev\multi-pos\grain-warehouse-erp-lite` |
| Starting branch | `codex/phase-101g-post-101f-genuine-client-reverification` |
| Starting HEAD | `765af4268930ba3188772e05e1b679a9e3515cd9` |
| Phase 101F baseline | `ec92dbfb268aaa8aa067191ae5b3f1a26b0f30fa` |
| علاقة التاريخ | Phase 101G مبنية فوق Phase 101F؛ ancestry check نجح |
| Working tree قبل العمل | نظيفة؛ لا staged ولا unstaged ولا untracked |
| Origin | `https://github.com/sabere342-ai/grain-warehouse-erp-lite.git` |
| Divergence/force | لا توجد حالة تتطلب force؛ لم يستخدم amend أو rebase أو reset |
| Final branch | `codex/phase-101h-video-derived-visual-consistency-dark-surface-remediation` |

## بيانات الفيديو ومنهج المراجعة

| البند | القيمة |
|---|---|
| المصدر | `Screen Recording 2026-07-26 215606.mp4` |
| المدة | `238.87s` |
| SHA-256 | `584FD7356C475D1EAEBE70136A25A1DB8F0A559126F97B82094EE2E7E8C1409F` |
| التصنيف | `SUPPLEMENTARY OWNER VISUAL EVIDENCE` |
| الفيديو | H.264، `1920x1020`، نحو `30 fps` |
| الصوت | موجود لكنه صامت فعليًا؛ `mean/max -91.0 dB` |

رُوجع التسجيل كاملًا زمنيًا مع عينات كل ثانية وcontact sheets وإطارات إضافية حول الانتقالات، ثم طُوبقت الشاشات مع الكود ومضيفات `MaterialPageRoute` والثيم والمكونات المشتركة. لم تُضف اللقطات أو الفيديو إلى Git، ولم يُعامل التسجيل كدليل قبول عميل.

## سجل التوقيت وجرد الشاشات الظاهرة

| أول ظهور | الشاشة/المسار | Theme | فحص السطح والبطاقات والحقول والأزرار والحوارات | التباين وRTL | القرار |
|---|---|---|---|---|---|
| `00:00` | لوحة التحكم | Light | سطح وبطاقات متناسقة | مقروء وRTL صحيح | Pass |
| `00:04` | النسخ الاحتياطي | Light | خلفية سوداء بين header والبطاقات والأزرار | عنوان داكن فوق الأسود وحدود ضعيفة | Needs remediation — F-005 |
| `00:07` | المساعدة | Light | سطح فاتح وبطاقات مشتركة | مقروء | Pass |
| `00:12` | المبيعات وحوار إنشاء بيع | Light | الشاشة والحوار متناسقان؛ modal overlay متوقع | الأزرار وRTL واضحان | Pass |
| `00:21` | المشتريات | Light | سطح وبطاقات متناسقة | مقروء | Pass |
| `00:26` | سجل المستندات | Light | خلفية وفجوات سوداء حول مرشحات وبطاقات فاتحة | العنوان والوصف شبه غير مقروءين | Needs remediation — F-005 |
| `00:28` | المنتجات | Light | سطح وحقول وأزرار متناسقة | RTL صحيح | Pass |
| `00:31` | المخزون وحوار الجرد | Light | الحوار فاتح والتعتيم خلفه مقصود | لا overflow ظاهر | Pass |
| `00:35` | تقرير تسوية المخزون | Light | سطح التقرير متناسق | مقروء | Pass |
| `00:38` | الموردون | Light | قائمة وبطاقات وأفعال متناسقة | RTL صحيح | Pass |
| `00:43` | العملاء | Light | قائمة وبطاقات متناسقة | RTL صحيح | Pass |
| `00:47` | كشف حساب العميل | Light | الجدول والمبالغ والبطاقات متناسقة | `ج.م` مقروء | Pass |
| `00:52` | معاينة/طباعة المستند | Light | المعاينة والحوارات متناسقة | العربية مقروءة | Pass |
| `00:56` | تعديل العميل | Light | الحقول والأزرار متناسقة | RTL صحيح | Pass |
| `01:01` | الحسابات المالية وطلبات الموافقة | Light | بطاقات وحالات واضحة | لا سطح داكن غير مقصود | Pass |
| `01:07` | مركز التقارير المالية وتقاريره | Light | الأسطح والجداول متناسقة | المبالغ والتسميات مقروءة | Pass |
| `02:13` | المصروفات وسجل التدقيق | Light | البطاقات والقوائم متناسقة | RTL صحيح | Pass |
| `02:19` | التقرير اليومي | Light | سطح تقرير متناسق | مقروء | Pass |
| `02:26` | حركة/تقرير المخزون | Light | جدول وفلاتر متناسقة | لا قص ظاهر | Pass |
| `02:43` | الإعدادات | Light | أقسام ومفاتيح تحكم متناسقة | مقروء | Pass |
| `02:59` | دفعة مورد وحوارات التأكيد/الموافقة | Light | dialogs فاتحة ومتناسقة؛ overlay متوقع | الحساب وطريقة الدفع والأزرار واضحة | Pass |
| `03:15` | سلفة مورد/استرداد سلفة | Light | حقول وحوارات متناسقة | `124.75` استرداد سلفة بالجنيه | Pass |
| `03:35`–`03:58` | المورد/العميل والكشوف الختامية | Light | الأسطح والبطاقات متناسقة | RTL والمبالغ مقروءة | Pass |

لا يعرض الفيديو Dark Theme مختارًا؛ لذلك لم تُنسب إليه عيوب داكنة لم تظهر فيه. التحقق الداكن اللاحق كشف F-006 بصورة مستقلة أثناء بوابة Phase 101H.

## Findings والأسباب الجذرية

| ID | التصنيف | الدليل | السبب الجذري | النتيجة |
|---|---|---|---|---|
| F-005 — Unexpected Dark Route Surfaces and Theme Inconsistency | `VISUAL-HIGH` | `00:04`–`00:06` النسخ الاحتياطي و`00:26`–`00:27` سجل المستندات في Light | جذرا المسارين كانا `ListView` شفافًا بلا `Scaffold`/Material surface، فظهر canvas الأسود للـNavigator على Windows. الاختبارات القديمة أخفت السبب بتغليف الشاشة في Scaffold. | **RESOLVED** |
| F-006 — Weak Dark-Theme Accent Contrast | `VISUAL-HIGH` | التحقق الأصلي بعد F-005 أظهر نصوص الأزرار الأساسية والثانوية داكنة فوق لون العلامة الداكن | استبدل الثيم `primary` بـ`preset.seed` الداكن مع إبقاء `onPrimary` الداكن المولّد لدرجة أخرى، واستُخدم seed نفسه لبقية accent controls. | **RESOLVED** |

لم تُنشأ finding للأشكال أو الحوارات لأن الفيديو لم يثبت عيبًا آخر قابلًا لإعادة الإنتاج. تعتيم الخلفية خلف dialog سلوك modal متوقع وليس سطحًا أسود خاطئًا.

## المعالجة وسبب توسيع النطاق

أُضيف `GhalalRouteScaffold` كسطح semantic مشترك يستخدم `ThemeData.scaffoldBackgroundColor` و`SafeArea` وpadding من design tokens. استُخدم في الفرعين الطبيعي وفرع رفض الصلاحية لكل من شاشة النسخ الاحتياطي وسجل المستندات. هذا يعالج السبب المشترك بدل ترقيع لونين محليين.

أصبحت ألوان accent في Dark Theme مشتقة من درجات `ColorScheme.fromSeed` الملائمة للسطح الداكن مع الحفاظ على preset الداكن المخصص. وُحد استخدامها في Filled/Outlined/Text buttons، focus، input focus، والتنقل لأن السبب نفسه كان يؤثر على كل هذه العناصر. لم تتغير الحوارات أو قواعدها أو عملياتها، ولم تُضف ألوان hard-coded للشاشتين.

## الملفات المعدلة

### Production

- `lib/core/theme/app_theme.dart`
- `lib/features/backup/backup_export_screen.dart`
- `lib/features/documents/document_history_screen.dart`
- `lib/shared/widgets/ghalal_route_scaffold.dart`

### Tests

- `test/phase101h_route_surface_presentation_test.dart`

### Documentation

- هذا التقرير.
- `docs/CLIENT-DEMO-FINDINGS-REGISTER-AR.md`

لم تتغير dependencies أو generated files أو repositories أو schema أو backup format.

## Before/After

| الحالة | Before | After |
|---|---|---|
| Backup — Light | canvas أسود، header داكن شبه مخفي، وبطاقات فاتحة عائمة | سطح فاتح متصل؛ header والبطاقات والأزرار مقروءة |
| Document history — Light | خلفية وفجوات سوداء بين المرشحات والحالة الفارغة | سطح semantic فاتح متصل ومتناسق |
| Shared accent — Dark | زر أخضر داكن ونص/أيقونة داكنان منخفضا التباين | primary داكن adaptive فاتح مع `onPrimary` مناسب، وحدود ونصوص accent مقروءة |

## التحقق المرئي اليدوي

بُني وشُغّل Windows native harness مؤقت يستخدم Widgetات الإنتاج و`AppTheme` الفعليين، RTL عربيًا، مصادقة demo، ومستودع سجل فارغ. لم يفتح قاعدة المستخدم ولم يغيّر بياناته. أُزيل المشغّل المؤقت قبل الالتزام، وحُفظت أربع لقطات `1938x1038` خارج المستودع فقط.

| البوابة | النتيجة |
|---|---|
| Light — Backup | PASS؛ سطح متصل، header والأزرار والبطاقات واضحة، لا شريط أسود |
| Light — Document history | PASS؛ سطح وفلاتر وحالة فارغة متناسقة، لا overflow |
| Dark — Backup | PASS؛ السطح الداكن مقصود ومتصل، والأزرار مقروءة |
| Dark — Document history | PASS؛ الفلاتر والحالة الفارغة والأزرار مقروءة |
| RTL | PASS؛ زر `arrow_forward_rounded` في جهة RTL الصحيحة وترتيب الأيقونة والنص سليم |
| Hover/focus/disabled | accent adaptive وحالات Material مشتركة؛ اختبارات الثيم والتنقل نجحت ولم تختف الحدود في التشغيل |
| Financial dialogs | ظهرت في الفيديو Light بلا عيب مؤكد؛ اختبارات الدفع والسلف والاسترداد والموافقات نجحت بعد تعديل الثيم. لم يتغير بناء dialogs أو منطقها |
| Data safety | بيانات وهمية فقط؛ لم يُضغط تصدير/مسح ولم تُنفذ عملية مالية |

## RTL وTheme واختبارات العرض

اختبار Phase 101H يغطي سطحي الشاشتين في Light/Dark، مطابقة `Scaffold.backgroundColor` للثيم وعدم كونه أسود في Light، اتجاه RTL وزر الرجوع وعدم وجود exception/overflow، ونسبة تباين لا تقل عن `4.5:1` بين primary/onPrimary وبين primary/سطح Scaffold في Dark لكل presets.

## Monetary regression وPhase 101F

- لم يتغير parsing أو التحويل الداخلي أو التخزين أو التنسيق المالي.
- نجح `phase101f_opening_balance_egp_input_test.dart` بجميع سيناريوهات العميل والمورد والدقة ومنع التكرار.
- نجحت اختبارات دفعات المورد والسلف والاستردادات والزيادة المسددة.
- `124.75` في الفيديو تظل **استرداد سلفة مورد: 124 جنيهًا و75 قرشًا** وليست رصيدًا افتتاحيًا.
- لا floating point جديد ولا تعديل لاتجاه قيد أو رصيد أو مخزون.

## بوابات التحقق التقني النهائية

| البوابة | Exit | النتيجة |
|---|---:|---|
| `dart format` للملفات المعدلة | `0` | PASS؛ استُخدم Dart SDK المباشر عند تأخر wrapper lock |
| `git diff --check` | `0` | PASS |
| فحص diff يدوي | — | PASS؛ UI/theme/tests/docs فقط |
| Phase 101H focused test | `0` | 7/7 PASS |
| Theme/RTL/supplier/payment/advance/Phase 101F pack | `0` | 80/80 PASS |
| `flutter analyze --no-pub` | `0` | `No issues found` |
| `flutter test --no-pub` | `0` | 1844 PASS وskip واحد ثابت |
| `flutter build windows --release --no-pub` | `0` | PASS؛ Windows EXE أُنشئ |
| Native Windows launch — Light/Dark | `0` | PASS؛ أربع حالات وفحص بصري مباشر |

تحذير CMake الخاص بالتوافق وتحذيرات PDB في debug harness معلومات بيئية غير حاجبة؛ release build نجح.

## Findings المغلقة والمتبقية

- F-005: `RESOLVED — PHASE 101H`.
- F-006: `RESOLVED — PHASE 101H`.
- Visual HIGH/BLOCKER ضمن النطاق: `0` مفتوحة.
- F-003: تبقى `RESOLVED` بلا تغيير.
- F-004: تبقى `RESOLVED — TECHNICALLY VERIFIED; CLIENT REVERIFICATION PENDING` بلا تغيير.

## Git وقرار الجاهزية

| البند | الحالة |
|---|---|
| Commit | commit واحد: `Phase 101H: remediate video-derived visual inconsistencies` |
| Local annotated tag | `phase-101h-video-derived-visual-consistency-dark-surface-remediation` عند Outcome A |
| Push | لم يتم؛ غير مفوض |
| Client video/screenshots/data | غير مضمنة في Git ولم تُعدّل |
| Final working tree | يجب أن تكون نظيفة بعد commit/tag؛ يُثبت ذلك في تقرير التسليم |

**VIDEO-DERIVED VISUAL DECISION: ALL CONFIRMED VIDEO-DERIVED VISUAL DEFECTS RESOLVED**

**CLIENT ACCEPTANCE: NOT ACHIEVED — GENUINE CLIENT SESSION STILL REQUIRED**

**COMMERCIAL READINESS: BLOCKED — GENUINE CLIENT SESSION REQUIRED**

الخطوة التالية المصرح بها: جلسة عميل حقيقية جديدة باستخدام Windows Release مبنية من commit Phase 101H النهائي، ثم استكمال Phase 101G أو continuation موثق لتنفيذ A–H وإصدار قرار تجاري صريح.
