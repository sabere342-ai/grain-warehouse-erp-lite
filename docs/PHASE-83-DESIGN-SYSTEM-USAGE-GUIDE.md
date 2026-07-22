# دليل استخدام Design System — Phase 83

هذا الدليل يصف الأساس المشترك للعينة المرحلة. لا يعني أن جميع شاشات «غلال» رُحلت إلى التصميم النهائي.

## الثيم والألوان

- استخدم `Theme.of(context).colorScheme` للألوان العامة.
- استخدم `Theme.of(context).extension<AppSemanticColors>()!` للمعاني المالية والتشغيلية مثل pending وexecuted وrejected وincome وpayment.
- لا تربط اللون باسم الشاشة، ولا تعتمد على اللون وحده؛ أضف نصًا وأيقونة وSemantics.
- أضف accent جديدًا فقط بعد بناء Light/Dark واختبار التباين والحالات المالية. لا تستخدم color picker حرًا.

## المقاسات والنصوص

- استخدم `AppSpacing` و`AppRadius` و`AppComponentSizes` بدل أرقام جديدة متكررة.
- استخدم `Theme.of(context).textTheme`؛ أدوار النص المعرفة في `AppTypography` تشمل العناوين والنصوص والأرقام.
- لا توقف text scaling. اختبر على الأقل هاتف 360×800 مع scaling مرتفع معقول.

## الاستجابة والتنقل

- استخدم `ResponsiveLayout` و`LayoutBuilder` بناءً على قيود المكون، لا `MediaQuery.width` موزعًا في كل شاشة.
- المحتوى على Windows يجب ألا يتمدد بلا حد. الأفعال المتعددة تستخدم `Wrap` عند احتمال الضيق.
- وجهات المستوى الأول تُضاف إلى تعريف Shell الواحد؛ لا تنشئ قائمة هاتف وقائمة Windows بقواعد صلاحيات مختلفة.
- الصفحة المدفوعة عبر Navigator تستخدم `PageBackButton`. سطح داخل Shell يستخدم عقد رجوع Shell ولا يدفع Dashboard جديدة.

## المكونات المشتركة

- رأس الصفحة: `GhalalPageHeader`.
- البحث القابل للمسح: `GhalalSearchField`.
- loading/empty/error: مكونات `GhalalStateView`، مع Retry حقيقي لخطأ repository.
- الحالة: `GhalalStatusBadge` بنص وأيقونة ولون دلالي.
- اختيار المظهر: `GhalalThemeSelector`.

## قواعد الشاشات المالية

- لا تخف الحساب أو طريقة الدفع أو العجز أو حالة Pending.
- افصل الفعل الخطر بصريًا عن فعل العرض، وعطل الفعل أثناء التنفيذ لمنع الضغط المتكرر.
- لا تغير validation أو repository/domain contract لتسهيل التخطيط.
- رسالة النجاح تصف النتيجة الحقيقية: طلب Pending ليس عملية منفذة.

## نمط الترحيل

1. ثبّت route والصلاحيات والاختبارات المالية قبل التعديل.
2. استبدل الرأس والحالات والبحث بالمكونات المشتركة.
3. اجعل التخطيط constraint-driven، ثم اختبر الهاتف وWindows وRTL وtext scaling.
4. شغّل اختبارات المجال ذات الصلة للتأكد أن التغيير بصري فقط.
5. حدّث Gap Matrix وroadmap؛ لا تدّع ترحيل شاشة لم تتغير فعليًا.
