import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';

void main() {
  group('Phase 90 — Push-Route Screens Design System Migration', () {
    group('DocumentHistoryScreen', () {
      testWidgets('renders GhalalPageHeader with back button', (tester) async {
        final auth = await _signedInOwner();
        final controller = DocumentHistoryController(
          repository: _EmptyDocumentHistoryRepository(),
        );

        await tester.pumpWidget(
          _harness(
            auth: auth,
            child: DocumentHistoryScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DocumentHistoryScreen), findsOneWidget);
        expect(find.byType(GhalalPageHeader), findsOneWidget);
        expect(find.text('سجل المستندات'), findsOneWidget);
        expect(find.byTooltip('رجوع'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('back button pops the route', (tester) async {
        final auth = await _signedInOwner();
        final controller = DocumentHistoryController(
          repository: _EmptyDocumentHistoryRepository(),
        );

        await tester.pumpWidget(
          _popHarness(
            auth: auth,
            child: DocumentHistoryScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('فتح'));
        await tester.pumpAndSettle();
        expect(find.byType(DocumentHistoryScreen), findsOneWidget);

        await tester.tap(find.byTooltip('رجوع'));
        await tester.pumpAndSettle();

        expect(find.byType(DocumentHistoryScreen), findsNothing);

        controller.dispose();
      });

      testWidgets('uses GhalalEmptyState when no entries', (tester) async {
        final auth = await _signedInOwner();
        final controller = DocumentHistoryController(
          repository: _EmptyDocumentHistoryRepository(),
        );

        await tester.pumpWidget(
          _harness(
            auth: auth,
            child: DocumentHistoryScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GhalalEmptyState), findsOneWidget);
        expect(find.text('لا توجد نتائج'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('header subtitle changes by permission', (tester) async {
        final ownerAuth = await _signedInOwner();
        final controller = DocumentHistoryController(
          repository: _EmptyDocumentHistoryRepository(),
        );

        await tester.pumpWidget(
          _harness(
            auth: ownerAuth,
            child: DocumentHistoryScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'بحث ومراجعة مستندات الشراء والبيع وحالة الإلغاء وتفاصيل التدقيق.',
          ),
          findsOneWidget,
        );

        controller.dispose();
        ownerAuth.dispose();
      });
    });

    group('GhalalPageHeader shared patterns', () {
      testWidgets('all migrated screens use GhalalPageHeader as header',
          (tester) async {
        final auth = await _signedInOwner();
        final controller = DocumentHistoryController(
          repository: _EmptyDocumentHistoryRepository(),
        );

        await tester.pumpWidget(
          _harness(
            auth: auth,
            child: DocumentHistoryScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        final header = find.byType(GhalalPageHeader);
        expect(header, findsOneWidget);

        final headerWidget = tester.widget<GhalalPageHeader>(header);
        expect(headerWidget.onBack, isNotNull);
        expect(headerWidget.icon, isNotNull);

        controller.dispose();
      });

      testWidgets(
          'no raw AppBarBackButton or PageBackButton in DocumentHistoryScreen',
          (tester) async {
        final auth = await _signedInOwner();
        final controller = DocumentHistoryController(
          repository: _EmptyDocumentHistoryRepository(),
        );

        await tester.pumpWidget(
          _harness(
            auth: auth,
            child: DocumentHistoryScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('رجوع'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

        controller.dispose();
      });
    });
  });
}

Widget _harness({
  required Widget child,
  AuthController? auth,
}) {
  final wrapped =
      auth != null ? AuthScope(controller: auth, child: child) : child;
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar'),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(body: wrapped),
  );
}

Widget _popHarness({
  required Widget child,
  AuthController? auth,
}) {
  final wrapped =
      auth != null ? AuthScope(controller: auth, child: child) : child;
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar'),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(body: wrapped),
                ),
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

class _EmptyDocumentHistoryRepository implements DocumentHistoryRepository {
  @override
  Future<List<DocumentHistoryEntry>> listHistory({
    DocumentHistoryFilter filter = const DocumentHistoryFilter(),
  }) async =>
      [];

  @override
  Future<DocumentHistoryEntry?> entryById(String id) async => null;
}

final _owner = AppUser(
  id: 'owner-test',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
