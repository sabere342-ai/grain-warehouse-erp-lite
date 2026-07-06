# Pilot Issue Log Template

Use this log after receiving owner feedback. Classify each item before deciding whether to change the app.

Feature requests must not be mixed with pilot-blocking bugs. A feature request can be useful, but it should not delay fixing a real bug that affects sales, purchases, stock, backup, or daily reporting.

| ID | Date | Reported By | Area | Severity | Type | Description | Repro Steps | Expected | Actual | Evidence | Decision | Status | Linked Commit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P24-001 |  |  |  |  |  |  |  |  |  |  |  | New |  |

## Severity values

- Blocker: يمنع التجربة أو يسبب خطر واضح على البيع أو المخزون أو النسخ الاحتياطي.
- High: يؤثر على استخدام مهم، لكن يوجد حل مؤقت واضح.
- Medium: مشكلة مزعجة أو غير واضحة، لكنها لا توقف العمل اليومي.
- Low: ملاحظة صغيرة أو تحسين بسيط.

## Type values

- Bug: سلوك خطأ في البرنامج.
- Usability: خطوة صعبة أو غير واضحة للمستخدم.
- Documentation: يحتاج توضيح في الدليل أو ملاحظات التسليم.
- Data Entry Mistake: خطأ من المستخدم أو بيانات غير صحيحة.
- Feature Request: طلب ميزة جديدة أو تغيير خارج نطاق التجربة.

## Decision values

- Fix Now: يجب إصلاحها قبل استمرار أو توسيع التجربة.
- Fix Later: مهمة، لكن لا تمنع التجربة الحالية.
- Document Only: يكفي توضيحها في الدليل أو ملاحظات التسليم.
- Reject: ليست مشكلة صحيحة أو خارج نطاق المنتج.
- Convert to Future Phase: طلب ميزة أو تغيير كبير يتم نقله لمرحلة لاحقة.

## Status values

- New: تم تسجيلها ولم تتم مراجعتها بعد.
- Confirmed: تم التأكد من صحتها.
- In Progress: يتم العمل عليها.
- Fixed: تم إصلاحها في Commit محدد.
- Verified: تم التأكد من الإصلاح.
- Closed: تم إغلاقها بقرار واضح.

## Review reminder

- لا تغير منطق البيع أو الشراء أو التسعير أثناء جمع الملاحظات.
- لا تغير النسخ الاحتياطي أو الاستعادة بدون مرحلة مخصصة.
- افصل الأخطاء الحقيقية عن طلبات الميزات.
- اربط أي إصلاح لاحق برقم الملاحظة و Commit واضح.
