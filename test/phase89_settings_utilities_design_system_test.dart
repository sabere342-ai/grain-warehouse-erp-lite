import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_controller.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/audit/audit_logs_screen.dart';
import 'package:grain_warehouse_erp_lite/features/backup/backup_export_screen.dart';
import 'package:grain_warehouse_erp_lite/features/help/help_guide_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';

void main() {
  group('Phase 89 — Settings & Utilities Design System Migration', () {
    group('GhalalPageHeader', () {
      testWidgets('renders title and subtitle', (tester) async {
        await tester.pumpWidget(
          _harness(
            Scaffold(
              body: ListView(
                children: const [
                  GhalalPageHeader(
                    title: 'テスト',
                    subtitle: 'サブタイトル',
                    icon: Icons.settings_rounded,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('テスト'), findsOneWidget);
        expect(find.text('サブタイトル'), findsOneWidget);
        expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      });

      testWidgets('without onBack renders no back button', (tester) async {
        await tester.pumpWidget(
          _harness(
            Scaffold(
              body: ListView(
                children: const [
                  GhalalPageHeader(
                    title: 'بدون رجوع',
                    icon: Icons.help_outline_rounded,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('رجوع'), findsNothing);
      });

      testWidgets('with onBack renders back button with tooltip',
          (tester) async {
        await tester.pumpWidget(
          _harness(
            Scaffold(
              body: ListView(
                children: [
                  GhalalPageHeader(
                    title: 'مع رجوع',
                    icon: Icons.help_outline_rounded,
                    onBack: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('رجوع'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      });
    });
    group('BackupExportScreen', () {
      testWidgets('renders GhalalPageHeader with back button', (tester) async {
        final auth = await _signedInOwner();
        await tester.pumpWidget(
          _routeHarness(
            auth: auth,
            builder: (_) => const BackupExportScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BackupExportScreen), findsOneWidget);
        expect(find.text('النسخ الاحتياطي'), findsOneWidget);
        expect(find.byTooltip('رجوع'), findsOneWidget);
      });

      testWidgets('back button pops the route', (tester) async {
        final auth = await _signedInOwner();
        await tester.pumpWidget(
          _popRouteHarness(
            auth: auth,
            builder: (_) => const BackupExportScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('فتح'));
        await tester.pumpAndSettle();
        expect(find.byType(BackupExportScreen), findsOneWidget);

        await tester.tap(find.byTooltip('رجوع'));
        await tester.pumpAndSettle();

        expect(find.byType(BackupExportScreen), findsNothing);
      });
    });

    group('HelpGuideScreen', () {
      testWidgets('renders GhalalPageHeader with back button', (tester) async {
        await tester.pumpWidget(
          _routeHarness(
            builder: (_) => const HelpGuideScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HelpGuideScreen), findsOneWidget);
        expect(find.text('دليل الاستخدام'), findsOneWidget);
        expect(find.byTooltip('رجوع'), findsOneWidget);
      });

      testWidgets('back button pops the route', (tester) async {
        await tester.pumpWidget(
          _popRouteHarness(
            builder: (_) => const HelpGuideScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('فتح'));
        await tester.pumpAndSettle();
        expect(find.byType(HelpGuideScreen), findsOneWidget);

        await tester.tap(find.byTooltip('رجوع'));
        await tester.pumpAndSettle();

        expect(find.byType(HelpGuideScreen), findsNothing);
      });
      testWidgets('contains all guide sections', (tester) async {
        await tester.pumpWidget(
          _harness(const HelpGuideScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('دليل الاستخدام'), findsOneWidget);
        expect(find.text('أول مرة تستخدم النظام'), findsOneWidget);
        expect(find.text('خطوات العمل اليومية'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('شرح مبسط للشاشات'),
          300,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('شرح مبسط للشاشات'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('تنبيهات مهمة'),
          300,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('تنبيهات مهمة'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('للمالك فقط'),
          300,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('للمالك فقط'), findsOneWidget);
      });
    });

    group('AuditLogsScreen', () {
      testWidgets('shows GhalalPageHeader with no back button', (tester) async {
        final auth = await _signedInOwner();
        await tester.pumpWidget(
          _harness(
            AuthScope(
              controller: auth,
              child: const Scaffold(body: AuditLogsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('سجل التدقيق'), findsOneWidget);
        expect(find.byTooltip('رجوع'), findsNothing);
      });

      testWidgets('shows empty state when no logs exist', (tester) async {
        final auth = await _signedInOwner();
        final controller = AuditLogController(
          repository: LocalAuditLogRepository(),
        );

        await tester.pumpWidget(
          _harness(
            AuthScope(
              controller: auth,
              child: Scaffold(
                body: AuditLogsScreen(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('لا توجد أحداث تدقيق مسجلة بعد.'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('denied state for employee without audit permission',
          (tester) async {
        final employeeAuth = await _signedInEmployee();

        await tester.pumpWidget(
          _harness(
            AuthScope(
              controller: employeeAuth,
              child: const Scaffold(body: AuditLogsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('سجل التدقيق متاح للمالك فقط.'), findsOneWidget);

        employeeAuth.dispose();
      });
    });
  });
}

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar'),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: child,
  );
}

Widget _routeHarness({
  required Widget Function(BuildContext) builder,
  AuthController? auth,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar'),
    onGenerateRoute: (settings) {
      return MaterialPageRoute(
        builder: (context) {
          final content = builder(context);
          if (auth != null) {
            return AuthScope(controller: auth, child: content);
          }
          return content;
        },
      );
    },
  );
}

Widget _popRouteHarness({
  required Widget Function(BuildContext) builder,
  AuthController? auth,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar'),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () {
              final screen = builder(context);
              final wrapped = auth != null
                  ? AuthScope(controller: auth, child: screen)
                  : screen;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => wrapped),
              );
            },
            child: const Text('فتح'),
          ),
        ),
      ),
    ),
  );
}

Future<AuthController> _signedInOwner() async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: '01000000000', password: 'owner123');
  return controller;
}

Future<AuthController> _signedInEmployee() async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: '01100000000', password: 'employee123');
  return controller;
}
