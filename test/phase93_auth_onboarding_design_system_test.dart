import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';

import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/auth/first_owner_setup_screen.dart';
import 'package:grain_warehouse_erp_lite/features/auth/login_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 93 LoginScreen design-system migration', () {
    testWidgets('shows app name and submit button', (tester) async {
      await _pumpLogin(tester);

      expect(find.text('غلال'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.byKey(const Key('login-submit-button')), findsOneWidget);
    });

    testWidgets('phone and password fields are present', (tester) async {
      await _pumpLogin(tester);

      expect(find.byKey(const Key('login-phone-field')), findsOneWidget);
      expect(find.byKey(const Key('login-password-field')), findsOneWidget);
    });

    testWidgets('password is obscured by default', (tester) async {
      await _pumpLogin(tester);

      final password = tester.widget<TextField>(
        find.byKey(const Key('login-password-field')),
      );
      expect(password.obscureText, isTrue);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await _pumpLogin(tester);

      await tester.tap(find.byTooltip('إظهار كلمة المرور'));
      await tester.pump();
      var password = tester.widget<TextField>(
        find.byKey(const Key('login-password-field')),
      );
      expect(password.obscureText, isFalse);

      await tester.tap(find.byTooltip('إخفاء كلمة المرور'));
      await tester.pump();
      password = tester.widget<TextField>(
        find.byKey(const Key('login-password-field')),
      );
      expect(password.obscureText, isTrue);
    });

    testWidgets('submit disables button and calls signIn', (tester) async {
      final completer = Completer<void>();
      final auth = AuthController(
        repository: _DelayedAuthRepository(completer: completer),
      );
      addTearDown(auth.dispose);
      await auth.initialize();

      await tester.pumpWidget(_authHarness(auth, const LoginScreen()));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('login-phone-field')),
        '01000000000',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'owner123',
      );
      await tester.tap(find.byKey(const Key('login-submit-button')));
      await tester.pump();

      expect(find.text('جاري تسجيل الدخول...'), findsOneWidget);

      completer.complete();
      await tester.pump();
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('auth error displays correctly', (tester) async {
      final auth = AuthController(
        repository: LocalAuthRepository.demo(),
      );
      addTearDown(auth.dispose);
      await auth.initialize();
      await auth.signIn(phone: 'wrong', password: 'wrong');
      await tester.pump();

      await tester.pumpWidget(_authHarness(auth, const LoginScreen()));
      await tester.pump();

      expect(find.text('بيانات الدخول غير صحيحة.'), findsOneWidget);
    });

    testWidgets('no AppBar present', (tester) async {
      await _pumpLogin(tester);

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('uses PremiumCard', (tester) async {
      await _pumpLogin(tester);

      expect(find.byType(PremiumCard), findsOneWidget);
    });

    testWidgets('no back button on root login screen', (tester) async {
      await _pumpLogin(tester);

      expect(find.byTooltip('رجوع'), findsNothing);
    });

    testWidgets('no overflow on compact viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpLogin(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL directionality preserved', (tester) async {
      await _pumpLogin(tester);

      expect(
        Directionality.of(tester.element(find.text('غلال'))),
        TextDirection.rtl,
      );
    });

    testWidgets('icon has Semantics label for accessibility', (tester) async {
      await _pumpLogin(tester);

      final semantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'شعار غلال لإدارة مخازن الحبوب',
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('error message wrapped in Semantics with liveRegion',
        (tester) async {
      final auth = AuthController(
        repository: LocalAuthRepository.demo(),
      );
      addTearDown(auth.dispose);
      await auth.initialize();
      await auth.signIn(phone: 'wrong', password: 'wrong');
      await tester.pump();

      await tester.pumpWidget(_authHarness(auth, const LoginScreen()));
      await tester.pump();

      final errorText = find.text('بيانات الدخول غير صحيحة.');
      final directParentSemantics = find.ancestor(
        of: errorText,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      );
      expect(directParentSemantics, findsOneWidget);
    });
  });

  group('Phase 93 FirstOwnerSetupScreen design-system migration', () {
    testWidgets('shows setup title and submit button', (tester) async {
      await _pumpSetup(tester);

      expect(find.text('إعداد المالك الأول'), findsOneWidget);
      expect(find.text('إنشاء حساب المالك'), findsOneWidget);
      expect(find.byKey(const Key('setup-submit-button')), findsOneWidget);
    });

    testWidgets('required fields are present', (tester) async {
      await _pumpSetup(tester);

      expect(find.byKey(const Key('setup-name-field')), findsOneWidget);
      expect(find.byKey(const Key('setup-phone-field')), findsOneWidget);
      expect(find.byKey(const Key('setup-password-field')), findsOneWidget);
    });

    testWidgets('password is obscured by default', (tester) async {
      await _pumpSetup(tester);

      final password = tester.widget<TextField>(
        find.byKey(const Key('setup-password-field')),
      );
      expect(password.obscureText, isTrue);
    });

    testWidgets('password visibility toggle works', (tester) async {
      await _pumpSetup(tester);

      await tester.tap(find.byTooltip('إظهار كلمة المرور'));
      await tester.pump();
      var password = tester.widget<TextField>(
        find.byKey(const Key('setup-password-field')),
      );
      expect(password.obscureText, isFalse);

      await tester.tap(find.byTooltip('إخفاء كلمة المرور'));
      await tester.pump();
      password = tester.widget<TextField>(
        find.byKey(const Key('setup-password-field')),
      );
      expect(password.obscureText, isTrue);
    });

    testWidgets('submit disables button and calls createFirstOwner',
        (tester) async {
      final completer = Completer<void>();
      final auth = AuthController(
        repository: _DelayedAuthRepository(completer: completer),
      );
      addTearDown(auth.dispose);
      await auth.initialize();

      await tester.pumpWidget(
        _authHarness(auth, const FirstOwnerSetupScreen()),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('setup-name-field')),
        'مالك المخزن',
      );
      await tester.enterText(
        find.byKey(const Key('setup-phone-field')),
        '01000000000',
      );
      await tester.enterText(
        find.byKey(const Key('setup-password-field')),
        'owner123',
      );
      await tester.tap(find.byKey(const Key('setup-submit-button')));
      await tester.pump();

      expect(find.text('جاري الحفظ...'), findsOneWidget);

      completer.complete();
      await tester.pump();
      expect(find.text('إنشاء حساب المالك'), findsOneWidget);
    });

    testWidgets('empty fields show validation error', (tester) async {
      final auth = AuthController(
        repository: LocalAuthRepository.empty(),
      );
      addTearDown(auth.dispose);
      await auth.initialize();

      await tester.pumpWidget(
        _authHarness(auth, const FirstOwnerSetupScreen()),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('setup-submit-button')));
      await tester.pump();

      expect(
        find.text('ادخل اسم المالك ورقم الهاتف وكلمة المرور.'),
        findsOneWidget,
      );
    });

    testWidgets('short password shows validation error', (tester) async {
      final auth = AuthController(
        repository: LocalAuthRepository.empty(),
      );
      addTearDown(auth.dispose);
      await auth.initialize();

      await tester.pumpWidget(
        _authHarness(auth, const FirstOwnerSetupScreen()),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('setup-name-field')),
        'مالك',
      );
      await tester.enterText(
        find.byKey(const Key('setup-phone-field')),
        '01000000000',
      );
      await tester.enterText(
        find.byKey(const Key('setup-password-field')),
        '123',
      );
      await tester.tap(find.byKey(const Key('setup-submit-button')));
      await tester.pump();

      expect(
        find.text('كلمة المرور يجب ألا تقل عن 6 أحرف.'),
        findsOneWidget,
      );
    });

    testWidgets('successful setup transitions to signedIn', (tester) async {
      final auth = AuthController(
        repository: LocalAuthRepository.empty(),
      );
      addTearDown(auth.dispose);
      await auth.initialize();

      await tester.pumpWidget(
        _authHarness(auth, const FirstOwnerSetupScreen()),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('setup-name-field')),
        'مالك المخزن',
      );
      await tester.enterText(
        find.byKey(const Key('setup-phone-field')),
        '01000000000',
      );
      await tester.enterText(
        find.byKey(const Key('setup-password-field')),
        'owner123',
      );
      await tester.tap(find.byKey(const Key('setup-submit-button')));
      await tester.pumpAndSettle();

      expect(auth.state.status.name, 'signedIn');
    });

    testWidgets('no AppBar present', (tester) async {
      await _pumpSetup(tester);

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('uses PremiumCard', (tester) async {
      await _pumpSetup(tester);

      expect(find.byType(PremiumCard), findsOneWidget);
    });

    testWidgets('no back button on mandatory setup screen', (tester) async {
      await _pumpSetup(tester);

      expect(find.byTooltip('رجوع'), findsNothing);
    });

    testWidgets('no overflow on compact viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpSetup(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL directionality preserved', (tester) async {
      await _pumpSetup(tester);

      expect(
        Directionality.of(
          tester.element(find.text('إعداد المالك الأول')),
        ),
        TextDirection.rtl,
      );
    });

    testWidgets('icon has Semantics label for accessibility', (tester) async {
      await _pumpSetup(tester);

      final semantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'إعداد المالك الأول',
      );
      expect(semantics, findsOneWidget);
    });

    testWidgets('error message wrapped in Semantics with liveRegion',
        (tester) async {
      final auth = AuthController(
        repository: LocalAuthRepository.empty(),
      );
      addTearDown(auth.dispose);
      await auth.initialize();

      await tester.pumpWidget(
        _authHarness(auth, const FirstOwnerSetupScreen()),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('setup-submit-button')));
      await tester.pump();

      final errorText = find.text(
        'ادخل اسم المالك ورقم الهاتف وكلمة المرور.',
      );
      final liveRegionSemantics = find.ancestor(
        of: errorText,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      );
      expect(liveRegionSemantics, findsOneWidget);
    });

    testWidgets('no legacy AppColors.mutedText usage', (tester) async {
      await _pumpSetup(tester);

      final subtitle = find.text(
        'لا يوجد مالك مسجل لهذا المخزن. أنشئ حساب المالك للبدء.',
      );
      expect(subtitle, findsOneWidget);

      final widget = tester.widget<Text>(subtitle);
      final color = widget.style?.color;

      expect(color, isNotNull);

      final expectedColor = Theme.of(
        tester.element(subtitle),
      ).colorScheme.onSurfaceVariant;
      expect(color, expectedColor);
    });
  });
}

Future<void> _pumpLogin(WidgetTester tester) async {
  final auth = AuthController(repository: LocalAuthRepository.demo());
  addTearDown(auth.dispose);
  await auth.initialize();

  await tester.pumpWidget(_authHarness(auth, const LoginScreen()));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpSetup(WidgetTester tester) async {
  final auth = AuthController(repository: LocalAuthRepository.empty());
  addTearDown(auth.dispose);
  await auth.initialize();

  await tester.pumpWidget(_authHarness(auth, const FirstOwnerSetupScreen()));
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _authHarness(AuthController auth, Widget child) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, content) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: content ?? const SizedBox.shrink(),
        );
      },
      home: Scaffold(body: child),
    ),
  );
}

class _DelayedAuthRepository implements AuthRepository {
  _DelayedAuthRepository({required this.completer});

  final Completer<void> completer;
  final AuthRepository _inner = LocalAuthRepository.empty();

  @override
  Future<AppUser?> signIn({
    required String phone,
    required String password,
  }) async {
    await completer.future;
    return _inner.signIn(phone: phone, password: password);
  }

  @override
  Future<AppUser?> verifyCredentials({
    required String phone,
    required String password,
  }) async {
    await completer.future;
    return _inner.verifyCredentials(phone: phone, password: password);
  }

  @override
  Future<AppUser> createFirstOwner({
    required String name,
    required String phone,
    required String password,
  }) async {
    await completer.future;
    return _inner.createFirstOwner(
      name: name,
      phone: phone,
      password: password,
    );
  }

  @override
  Future<void> signOut() => _inner.signOut();

  @override
  Future<bool> hasOwner() => _inner.hasOwner();

  @override
  Future<AppUser?> currentUser() => _inner.currentUser();

  @override
  Future<AppUser?> getUserById(String id) => _inner.getUserById(id);
}
