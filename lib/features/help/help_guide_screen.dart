import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class HelpGuideScreen extends StatelessWidget {
  const HelpGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('دليل الاستخدام')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('طريقة تشغيل مخزن الغلال', style: textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'خطوات قصيرة تساعد المالك والموظف على تسجيل الوارد والمنصرف ومراجعة المستندات بأمان.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const _GuideSection(
            title: 'أول مرة تستخدم النظام',
            lines: [
              'أضف الأصناف الأساسية مثل القمح أو الذرة.',
              'راجع أسماء الأصناف ووحداتها حتى لا يتشتت الرصيد.',
              'أدخل رصيد افتتاحي أو حركة وارد عند الحاجة.',
              'سجّل المشتريات عند دخول بضاعة من المورد.',
              'سجّل المبيعات عند خروج بضاعة للعميل.',
              'راجع التقرير اليومي وسجل المستندات في نهاية اليوم.',
            ],
          ),
          const _GuideSection(
            title: 'خطوات العمل اليومية',
            lines: [
              'افتح النظام وتأكد من المستخدم الحالي.',
              'راجع الأصناف والأرصدة قبل التسجيل.',
              'سجّل مشتريات اليوم إن وجدت.',
              'سجّل مبيعات اليوم عند خروج البضاعة.',
              'راجع التقرير اليومي قبل نهاية اليوم.',
              'راجع سجل المستندات عند وجود إلغاء مستند أو حركة عكسية.',
            ],
          ),
          const _GuideSection(
            title: 'شرح مبسط للشاشات',
            lines: [
              'لوحة متابعة المخزن: تعرض تنبيهات وإرشادات سريعة.',
              'الأصناف: أسماء الحبوب ووحداتها وأسعارها الإرشادية.',
              'المخزون: أرصدة الأصناف وحركات الوارد والمنصرف.',
              'المشتريات: تسجيل استلام الحبوب من الموردين.',
              'المبيعات: تسجيل خروج الحبوب من المخزن.',
              'التقارير: مراجعة نشاط اليوم والكميات المسجلة.',
              'سجل المستندات: البحث عن مستندات الشراء والبيع وحالة الإلغاء.',
            ],
          ),
          const _GuideSection(
            title: 'تنبيهات مهمة',
            lines: [
              'لا تستخدم حركة مخزون يدوية إلا عند الجرد أو التصحيح.',
              'إلغاء المستند لا يحذف الأصل.',
              'الإلغاء ينشئ حركة عكسية للحفاظ على التاريخ.',
              'راجع التقرير اليومي قبل نهاية اليوم.',
              'لا تضف نفس الصنف بأكثر من اسم قريب حتى لا يتشتت الرصيد.',
            ],
          ),
          const _GuideSection(
            title: 'للمالك فقط',
            lines: [
              'تابع التقارير وسجل المستندات بانتظام.',
              'راجع الإلغاءات وأسبابها وحركاتها العكسية.',
              'تأكد أن الموظف يستخدم الشاشات المناسبة فقط.',
              'إدارة الصلاحيات والإعدادات تكون من شاشات المالك عند توفرها.',
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $line'),
              ),
          ],
        ),
      ),
    );
  }
}
