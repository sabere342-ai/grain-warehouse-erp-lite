import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/supplier_accounts/supplier_payment_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';

const _viewports = <String, Size>{
  'mobile 360x800': Size(360, 800),
  'mobile 390x844': Size(390, 844),
  'tablet 800x1024': Size(800, 1024),
  'small Windows 1024x640': Size(1024, 640),
  'desktop 1366x768': Size(1366, 768),
  'desktop 1600x900': Size(1600, 900),
};

void main() {
  group('Phase 84 responsive transaction dialog contract', () {
    for (final viewport in _viewports.entries) {
      testWidgets('${viewport.key} keeps fields and primary action reachable',
          (tester) async {
        _setViewport(tester, viewport.value);
        await tester.pumpWidget(
          _dialogApp(
            theme: AppTheme.lightFor(AppThemePreset.olive),
            textScaler: const TextScaler.linear(1.3),
          ),
        );

        await tester.tap(find.text('فتح معاملة'));
        await tester.pumpAndSettle();

        expect(find.byType(GhalalResponsiveDialog), findsOneWidget);
        expect(find.text('مراجعة معاملة مالية عالية الخطورة'), findsOneWidget);
        expect(find.text('الحساب المالي'), findsOneWidget);
        expect(find.text('طريقة الدفع'), findsOneWidget);
        expect(find.textContaining('المبلغ الإجمالي'), findsOneWidget);
        expect(find.byTooltip('حذف البند'), findsOneWidget);

        final primary = find.byKey(const Key('phase84-primary-action'));
        await tester.ensureVisible(primary);
        await tester.pump();
        expect(primary, findsOneWidget);
        expect(
          tester.getSize(primary).height,
          greaterThanOrEqualTo(AppComponentSizes.minimumTouchTarget),
        );
        final removeAction = find.ancestor(
          of: find.byTooltip('حذف البند'),
          matching: find.byType(IconButton),
        );
        expect(removeAction, findsOneWidget);
        expect(
          tester.getSize(removeAction).shortestSide,
          greaterThanOrEqualTo(AppComponentSizes.minimumTouchTarget),
        );

        final alert = tester.getSize(find.byType(AlertDialog));
        expect(alert.width, lessThanOrEqualTo(viewport.value.width));
        expect(alert.height, lessThanOrEqualTo(viewport.value.height));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('dirty cancel preserves data until discard is confirmed',
        (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkFor(AppThemePreset.blue),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: _DirtyDialogLauncher()),
          ),
        ),
      );

      await tester.tap(find.text('فتح نموذج'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('phase84-dirty-field')),
        'بيانات لم تحفظ',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('إلغاء'));
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('تجاهل التغييرات؟'), findsOneWidget);
      expect(find.text('بيانات لم تحفظ'), findsOneWidget);
      await tester.tap(find.text('متابعة التعديل'));
      await tester.pumpAndSettle();
      expect(find.text('بيانات لم تحفظ'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-discard-dialog-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('phase84-dirty-field')), findsNothing);
      expect(find.text('فتح نموذج'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shared transaction dialog renders in dark wheat theme',
        (tester) async {
      _setViewport(tester, const Size(1366, 768));
      await tester.pumpWidget(
        _dialogApp(theme: AppTheme.darkFor(AppThemePreset.wheat)),
      );
      await tester.tap(find.text('فتح معاملة'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(GhalalResponsiveDialog));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(Directionality.of(context), TextDirection.rtl);
      expect(find.text('تنفيذ المعاملة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 84 supplier payment responsive integration', () {
    for (final viewport in _viewports.entries) {
      testWidgets('${viewport.key} keeps the payment action and route visible',
          (tester) async {
        _setViewport(tester, viewport.value);
        await tester.pumpWidget(_supplierPaymentApp());
        await tester.tap(find.text('فتح سداد المورد'));
        await tester.pumpAndSettle();

        expect(find.byType(GhalalResponsiveDialog), findsOneWidget);
        expect(find.text('طريقة الدفع *'), findsOneWidget);
        expect(find.text('الحساب المالي *'), findsOneWidget);
        expect(find.textContaining('الرصيد المستحق:'), findsOneWidget);
        final submit = find.text('تسجيل الدفع');
        await tester.ensureVisible(submit);
        await tester.pump();
        expect(submit, findsOneWidget);
        expect(Directionality.of(tester.element(submit)), TextDirection.rtl);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Phase 84 expense form dialog responsive contract', () {
    for (final viewport in _viewports.entries) {
      testWidgets(
          '${viewport.key} keeps expense fields and save action reachable',
          (tester) async {
        _setViewport(tester, viewport.value);
        await tester.pumpWidget(_expenseFormApp());
        await tester.tap(find.text('فتح نموذج مصروف'));
        await tester.pumpAndSettle();

        expect(find.byType(GhalalResponsiveDialog), findsOneWidget);
        expect(find.text('إضافة مصروف'), findsOneWidget);
        expect(find.text('اسم المصروف *'), findsOneWidget);
        expect(find.text('المبلغ بالجنيه *'), findsOneWidget);
        expect(find.text('طريقة الدفع *'), findsOneWidget);
        expect(find.text('الحساب المالي *'), findsOneWidget);

        final save = find.text('حفظ المصروف');
        await tester.ensureVisible(save);
        await tester.pump();
        expect(save, findsOneWidget);

        final alert = tester.getSize(find.byType(AlertDialog));
        expect(alert.width, lessThanOrEqualTo(viewport.value.width));
        expect(alert.height, lessThanOrEqualTo(viewport.value.height));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Phase 84 purchase form responsive layout', () {
    for (final viewport in _viewports.entries) {
      testWidgets(
          '${viewport.key} purchase form shows quantity and unit correctly',
          (tester) async {
        _setViewport(tester, viewport.value);
        await tester.pumpWidget(_purchaseFormApp());
        await tester.tap(find.text('فتح نموذج شراء'));
        await tester.pumpAndSettle();

        expect(find.byType(GhalalResponsiveDialog), findsOneWidget);
        expect(find.text('تسجيل استلام حبوب'), findsOneWidget);
        expect(find.text('المورد'), findsOneWidget);
        expect(find.text('الصنف'), findsOneWidget);
        expect(find.text('الكمية'), findsOneWidget);
        expect(find.text('الوحدة'), findsOneWidget);
        expect(find.text('سعر الوحدة'), findsOneWidget);

        final save = find.text('حفظ الاستلام');
        await tester.ensureVisible(save);
        await tester.pump();
        expect(save, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Phase 84 full-page screen viewport coverage', () {
    testWidgets('sales screen empty state at narrow mobile 360x800',
        (tester) async {
      _setViewport(tester, const Size(360, 800));
      await tester.pumpWidget(_salesScreenEmptyApp());
      await tester.pumpAndSettle();

      expect(find.text('المبيعات'), findsOneWidget);
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.text('لا توجد فواتير بيع'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sales screen empty state at wide desktop 1600x900',
        (tester) async {
      _setViewport(tester, const Size(1600, 900));
      await tester.pumpWidget(_salesScreenEmptyApp());
      await tester.pumpAndSettle();

      expect(find.text('المبيعات'), findsOneWidget);
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expenses screen empty state at narrow mobile 360x800',
        (tester) async {
      _setViewport(tester, const Size(360, 800));
      await tester.pumpWidget(_expensesScreenEmptyApp());
      await tester.pumpAndSettle();

      expect(find.text('المصروفات'), findsOneWidget);
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.text('لا توجد مصروفات'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expenses screen empty state at wide desktop 1600x900',
        (tester) async {
      _setViewport(tester, const Size(1600, 900));
      await tester.pumpWidget(_expensesScreenEmptyApp());
      await tester.pumpAndSettle();

      expect(find.text('المصروفات'), findsOneWidget);
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('purchases screen empty state at small Windows 1024x640',
        (tester) async {
      _setViewport(tester, const Size(1024, 640));
      await tester.pumpWidget(_purchasesScreenEmptyApp());
      await tester.pumpAndSettle();

      expect(find.text('استلامات الشراء'), findsOneWidget);
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.text('لا توجد استلامات شراء'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('purchases screen empty state at tablet 800x1024',
        (tester) async {
      _setViewport(tester, const Size(800, 1024));
      await tester.pumpWidget(_purchasesScreenEmptyApp());
      await tester.pumpAndSettle();

      expect(find.text('استلامات الشراء'), findsOneWidget);
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('customer advances screen empty state at narrow 360x800',
        (tester) async {
      _setViewport(tester, const Size(360, 800));
      await tester.pumpWidget(_customerAdvancesScreenEmptyApp());
      await tester.pumpAndSettle();

      expect(find.text('إدارة سلف العميل'), findsOneWidget);
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.text('لا توجد سلف للعميل'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supplier advances screen empty state at wide 1600x900',
        (tester) async {
      _setViewport(tester, const Size(1600, 900));
      await tester.pumpWidget(_supplierAdvancesScreenEmptyApp());
      await tester.pumpAndSettle();

      expect(find.text('إدارة سلف المورد'), findsOneWidget);
      expect(find.byType(GhalalEmptyState), findsOneWidget);
      expect(find.text('لا توجد سلف للمورد'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 84 dirty-form double-submit protection', () {
    testWidgets('busy dialog disables cancel and submit buttons',
        (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightFor(AppThemePreset.blue),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: _BusyDialogLauncher()),
          ),
        ),
      );

      await tester.tap(find.text('فتح نموذج مشغول'));
      await tester.pumpAndSettle();

      expect(find.text('نموذج مشغول'), findsOneWidget);
      expect(find.byType(GhalalResponsiveDialog), findsOneWidget);

      final submit = find.text('تنفيذ');
      expect(submit, findsOneWidget);
      await tester.tap(submit);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      final cancel = find.text('إلغاء');
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('نموذج مشغول'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supplier payment dirty cancel shows discard confirmation',
        (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(_supplierPaymentApp());
      await tester.tap(find.text('فتح سداد المورد'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        '500',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('إلغاء'));
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('تجاهل التغييرات؟'), findsOneWidget);
      expect(find.byKey(const Key('confirm-discard-dialog-action')),
          findsOneWidget);

      await tester.tap(find.text('متابعة التعديل'));
      await tester.pumpAndSettle();
      expect(find.byType(GhalalResponsiveDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supplier payment clean cancel closes without confirmation',
        (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(_supplierPaymentApp());
      await tester.tap(find.text('فتح سداد المورد'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('إلغاء'));
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.byType(GhalalResponsiveDialog), findsNothing);
      expect(find.text('فتح سداد المورد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 84 loading empty error state coverage', () {
    testWidgets('GhalalLoadingState shows Arabic label', (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightFor(AppThemePreset.blue),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: GhalalLoadingState(label: 'جاري التحميل...'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('جاري التحميل...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GhalalErrorState retry button is reachable and tappable',
        (tester) async {
      _setViewport(tester, const Size(390, 844));
      var retryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightFor(AppThemePreset.blue),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: GhalalErrorState(
                message: 'حدث خطأ في تحميل البيانات',
                onRetry: () => retryPressed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('حدث خطأ في تحميل البيانات'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      final retryBtn = find.text('إعادة المحاولة');
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pump();
      expect(retryPressed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GhalalEmptyState shows icon title and message',
        (tester) async {
      _setViewport(tester, const Size(800, 1024));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightFor(AppThemePreset.olive),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: GhalalEmptyState(
                title: 'لا توجد بيانات',
                message: 'ستظهر البيانات هنا.',
                icon: Icons.inbox_outlined,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد بيانات'), findsOneWidget);
      expect(find.text('ستظهر البيانات هنا.'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _dialogApp({
  required ThemeData theme,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: theme,
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: media.copyWith(textScaler: textScaler),
          child: child!,
        ),
      );
    },
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => GhalalResponsiveDialog(
                  title: const Text('مراجعة معاملة مالية عالية الخطورة'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TextField(
                        decoration: InputDecoration(labelText: 'الحساب المالي'),
                      ),
                      const SizedBox(height: 12),
                      const TextField(
                        decoration: InputDecoration(labelText: 'طريقة الدفع'),
                      ),
                      const SizedBox(height: 12),
                      const Text('المبلغ الإجمالي: 12345.67 ج.م'),
                      IconButton(
                        tooltip: 'حذف البند',
                        onPressed: () {},
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('رجوع'),
                    ),
                    FilledButton(
                      key: const Key('phase84-primary-action'),
                      onPressed: () {},
                      child: const Text('تنفيذ المعاملة'),
                    ),
                  ],
                ),
              ),
              child: const Text('فتح معاملة'),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _supplierPaymentApp() {
  final account = FinancialAccount(
    id: 'treasury-1',
    name: 'الخزينة الرئيسية',
    type: FinancialAccountType.treasury,
    createdByUserId: 'owner-1',
    createdAt: DateTime(2026, 7, 22),
  );
  final supplier = Supplier(
    id: 'supplier-1',
    name: 'مورد اختبار بعبارة عربية طويلة',
    isActive: true,
    createdAt: DateTime(2026, 7, 22),
    updatedAt: DateTime(2026, 7, 22),
  );
  return MaterialApp(
    theme: AppTheme.lightFor(AppThemePreset.blue),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<SupplierPaymentResult>(
                context: context,
                barrierDismissible: false,
                builder: (_) => SupplierPaymentDialog(
                  supplier: supplier,
                  balanceQirsh: 250000,
                  userId: 'owner-1',
                  financialAccounts: [account],
                ),
              ),
              child: const Text('فتح سداد المورد'),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _expenseFormApp() {
  final accounts = [
    FinancialAccount(
      id: 'cash-1',
      name: 'الصندوق النقدي',
      type: FinancialAccountType.treasury,
      createdByUserId: 'owner-1',
      createdAt: DateTime(2026, 7, 22),
    ),
  ];
  return MaterialApp(
    theme: AppTheme.lightFor(AppThemePreset.olive),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _ExpenseFormHarness(accounts: accounts),
              ),
              child: const Text('فتح نموذج مصروف'),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ExpenseFormHarness extends StatefulWidget {
  const _ExpenseFormHarness({required this.accounts});
  final List<FinancialAccount> accounts;

  @override
  State<_ExpenseFormHarness> createState() => _ExpenseFormHarnessState();
}

class _ExpenseFormHarnessState extends State<_ExpenseFormHarness> {
  String? _selectedMethod;
  String? _selectedAccount;

  @override
  Widget build(BuildContext context) {
    return GhalalResponsiveDialog(
      title: const Text('إضافة مصروف'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TextField(
            decoration: InputDecoration(labelText: 'اسم المصروف *'),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(labelText: 'المبلغ بالجنيه *'),
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedMethod,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'طريقة الدفع *'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('نقداً')),
              DropdownMenuItem(value: 'transfer', child: Text('تحويل بنكي')),
            ],
            onChanged: (v) => setState(() => _selectedMethod = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedAccount,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الحساب المالي *'),
            items: widget.accounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedAccount = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('حفظ المصروف'),
        ),
      ],
    );
  }
}

Widget _purchaseFormApp() {
  return MaterialApp(
    theme: AppTheme.lightFor(AppThemePreset.blue),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => GhalalResponsiveDialog(
                  title: const Text('تسجيل استلام حبوب'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'المورد'),
                          items: const [],
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'الصنف'),
                          items: const [],
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 12),
                        const TextField(
                          decoration: InputDecoration(labelText: 'الكمية'),
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'الوحدة'),
                          items: const [
                            DropdownMenuItem(value: 'kg', child: Text('كجم')),
                            DropdownMenuItem(value: 'ton', child: Text('طن')),
                          ],
                          onChanged: (_) {},
                        ),
                        const SizedBox(height: 12),
                        const TextField(
                          decoration: InputDecoration(labelText: 'سعر الوحدة'),
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('حفظ الاستلام'),
                    ),
                  ],
                ),
              ),
              child: const Text('فتح نموذج شراء'),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _salesScreenEmptyApp() {
  return MaterialApp(
    theme: AppTheme.lightFor(AppThemePreset.blue),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            GhalalPageHeader(
              title: 'المبيعات',
              subtitle: 'كل فاتورة بيع تتطلب عميلاً مسجلاً.',
              icon: Icons.point_of_sale_rounded,
            ),
            Expanded(
              child: GhalalEmptyState(
                title: 'لا توجد فواتير بيع',
                message: 'ستظهر هنا فواتير البيع بعد تنفيذها.',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _expensesScreenEmptyApp() {
  return MaterialApp(
    theme: AppTheme.lightFor(AppThemePreset.blue),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            GhalalPageHeader(
              title: 'المصروفات',
              subtitle: 'تسجيل المصروفات النقدية فقط.',
              icon: Icons.receipt_long_rounded,
            ),
            Expanded(
              child: GhalalEmptyState(
                title: 'لا توجد مصروفات',
                message: 'ستظهر هنا المصروفات بعد تنفيذها.',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _purchasesScreenEmptyApp() {
  return MaterialApp(
    theme: AppTheme.lightFor(AppThemePreset.blue),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            GhalalPageHeader(
              title: 'استلامات الشراء',
              subtitle: 'استلام الحبوب من الموردين.',
              icon: Icons.shopping_bag_rounded,
            ),
            Expanded(
              child: GhalalEmptyState(
                title: 'لا توجد استلامات شراء',
                message: 'ستظهر هنا مستندات الاستلام.',
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _customerAdvancesScreenEmptyApp() {
  return MaterialApp(
    theme: AppTheme.lightFor(AppThemePreset.blue),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            GhalalPageHeader(
              title: 'إدارة سلف العميل',
              subtitle: 'يمكن تطبيق الرصيد المتاح على ذمة العميل.',
              icon: Icons.account_balance_wallet_rounded,
            ),
            Expanded(
              child: GhalalEmptyState(
                title: 'لا توجد سلف للعميل',
                message: 'لا توجد سلف متاحة أو سابقة لهذا العميل.',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _supplierAdvancesScreenEmptyApp() {
  return MaterialApp(
    theme: AppTheme.lightFor(AppThemePreset.blue),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            GhalalPageHeader(
              title: 'إدارة سلف المورد',
              subtitle: 'يمكن تطبيق الرصيد على ذمة المورد.',
              icon: Icons.account_balance_wallet_rounded,
            ),
            Expanded(
              child: GhalalEmptyState(
                title: 'لا توجد سلف للمورد',
                message: 'لا توجد سلف مسجلة لهذا المورد.',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DirtyDialogLauncher extends StatelessWidget {
  const _DirtyDialogLauncher();

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton(
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _DirtyDialog(),
          ),
          child: const Text('فتح نموذج'),
        ),
      );
}

class _DirtyDialog extends StatefulWidget {
  const _DirtyDialog();

  @override
  State<_DirtyDialog> createState() => _DirtyDialogState();
}

class _DirtyDialogState extends State<_DirtyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _controller.text.trim().isNotEmpty;
    return GhalalResponsiveDialog(
      title: const Text('نموذج معاملة'),
      isDirty: dirty,
      content: TextField(
        key: const Key('phase84-dirty-field'),
        controller: _controller,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => GhalalResponsiveDialog.requestClose(
            context,
            isDirty: dirty,
          ),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}

class _BusyDialogLauncher extends StatelessWidget {
  const _BusyDialogLauncher();

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton(
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _BusyDialog(),
          ),
          child: const Text('فتح نموذج مشغول'),
        ),
      );
}

class _BusyDialog extends StatefulWidget {
  const _BusyDialog();

  @override
  State<_BusyDialog> createState() => _BusyDialogState();
}

class _BusyDialogState extends State<_BusyDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return GhalalResponsiveDialog(
      title: const Text('نموذج مشغول'),
      isBusy: _busy,
      content: const Text('نموذج أثناء التنفيذ'),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => GhalalResponsiveDialog.requestClose(
                    context,
                    isDirty: false,
                  ),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () {
                  setState(() => _busy = true);
                  Future.delayed(const Duration(seconds: 5), () {
                    if (mounted) setState(() => _busy = false);
                  });
                },
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تنفيذ'),
        ),
      ],
    );
  }
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
