import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_mode.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';
import 'package:grain_warehouse_erp_lite/features/auth/login_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/financial_accounts_screen.dart';
import 'package:grain_warehouse_erp_lite/features/financial_accounts/negative_balance_approval_requests_screen.dart';
import 'package:grain_warehouse_erp_lite/features/suppliers/suppliers_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_theme_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 83 migrated reference screens', () {
    testWidgets('login is RTL-safe at 360px and supports password visibility',
        (tester) async {
      await _setViewport(tester, const Size(360, 800));
      final auth = AuthController(repository: LocalAuthRepository.demo());
      addTearDown(auth.dispose);
      await auth.initialize();

      await tester.pumpWidget(
        _authHarness(
          auth,
          const LoginScreen(),
          textScale: 1.3,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('غلال'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
      var password = tester.widget<TextField>(
        find.byKey(const Key('login-password-field')),
      );
      expect(password.obscureText, isTrue);

      await tester.tap(find.byTooltip('إظهار كلمة المرور'));
      await tester.pump();
      password = tester.widget<TextField>(
        find.byKey(const Key('login-password-field')),
      );
      expect(password.obscureText, isFalse);
      expect(Directionality.of(tester.element(find.text('غلال'))),
          TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supplier search distinguishes no results from no data',
        (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);
      final repository = LocalSupplierRepository();
      await repository.createSupplier(
        const SupplierDraft(
          name: 'مخزن الوادي',
          phone: '01012345678',
          address: 'المنيا',
        ),
      );
      await repository.createSupplier(
        const SupplierDraft(name: 'مورد القمح', address: 'أسيوط'),
      );
      final controller = SupplierController(repository: repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _authHarness(auth, SuppliersScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.text('مخزن الوادي'), findsOneWidget);
      expect(find.text('مورد القمح'), findsOneWidget);

      final field = find.descendant(
        of: find.byKey(const Key('suppliers-search-field')),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'غير موجود');
      await tester.pump();
      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
      expect(find.text('لا توجد بيانات موردين'), findsNothing);

      await tester.tap(find.byTooltip('مسح البحث'));
      await tester.pump();
      expect(find.text('مخزن الوادي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('financial account form records the real signed-in actor',
        (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);
      final repository = LocalFinancialAccountRepository();
      final controller = FinancialAccountController(repository: repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _authHarness(auth, FinancialAccountsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا توجد حسابات مالية'), findsOneWidget);

      await tester.tap(find.text('إضافة حساب'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'الخزينة الرئيسية');
      await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
      await tester.pumpAndSettle();

      final accounts = await repository.listAccounts(includeInactive: true);
      expect(accounts, hasLength(1));
      expect(accounts.single.name, 'الخزينة الرئيسية');
      expect(accounts.single.createdByUserId, auth.state.user!.id);
      expect(tester.takeException(), isNull);
    });

    testWidgets('approval queue has explicit loading and empty states on phone',
        (tester) async {
      await _setViewport(tester, const Size(360, 800));
      final authRepository = LocalAuthRepository.demo();
      final auth = AuthController(repository: authRepository);
      addTearDown(auth.dispose);
      await auth.initialize();
      await auth.signIn(phone: '01000000000', password: 'owner123');

      await tester.pumpWidget(
        _authHarness(
          auth,
          NegativeBalanceApprovalRequestsScreen(
            requestRepository: LocalNegativeBalanceApprovalRequestRepository(),
            financialAccountRepository: LocalFinancialAccountRepository(),
            authRepository: authRepository,
          ),
          textScale: 1.2,
        ),
      );
      expect(find.text('جاري تحميل طلبات الموافقة...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('لا توجد طلبات موافقة'), findsOneWidget);
      expect(find.textContaining('لم ينفذ العملية بعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('appearance settings expose System Light Dark and accents',
        (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final repository = _MemoryThemeSettingsRepository();
      final themeController = ThemeController(
        repository: repository,
      );
      addTearDown(themeController.dispose);
      await themeController.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GhalalThemeSelector(controller: themeController),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('theme-mode-system')), findsOneWidget);
      expect(find.byKey(const Key('theme-mode-light')), findsOneWidget);
      expect(find.byKey(const Key('theme-mode-dark')), findsOneWidget);
      expect(find.text('لمسة اللون'), findsOneWidget);

      await tester.tap(find.byKey(const Key('theme-mode-dark')));
      await tester.pump();
      expect(themeController.mode.name, 'dark');
      expect(repository.settings.mode, AppThemeMode.dark);
      expect(tester.takeException(), isNull);
    });
  });
}

class _MemoryThemeSettingsRepository implements ThemeSettingsRepository {
  AppThemeSettings settings = const AppThemeSettings(
    mode: AppThemeMode.system,
    preset: AppThemePreset.olive,
  );

  @override
  Future<AppThemeSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(AppThemeSettings value) async {
    settings = value;
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<AuthController> _signedInOwner() async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: '01000000000', password: 'owner123');
  return controller;
}

Widget _authHarness(
  AuthController auth,
  Widget child, {
  double textScale = 1,
}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, content) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: content ?? const SizedBox.shrink(),
          ),
        );
      },
      home: Scaffold(body: child),
    ),
  );
}
