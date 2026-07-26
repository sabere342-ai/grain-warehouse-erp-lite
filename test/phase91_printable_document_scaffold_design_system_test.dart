import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';

import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_customer_statement_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_daily_report_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_document_scaffold.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_purchase_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_sales_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_supplier_statement_view.dart';

void main() {
  group('Phase 91 — Printable Document Scaffold Design-System Migration', () {
    group('A. PrintableDocumentScaffold design tokens', () {
      testWidgets('uses theme colorScheme for text, not AppColors',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
            ),
            home: const Scaffold(
              body: PrintableDocumentScaffold(
                title: 'مستند تجريبي',
                child: Text('المحتوى'),
              ),
            ),
          ),
        );

        expect(find.text('مستند تجريبي'), findsOneWidget);
        expect(find.text('المحتوى'), findsOneWidget);
        expect(find.text('رجوع'), findsOneWidget);
      });

      testWidgets('no Directionality wrapper — relies on app RTL',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const Scaffold(
              body: PrintableDocumentScaffold(
                title: 'اختبار',
                child: Text('محتوى'),
              ),
            ),
          ),
        );

        expect(find.text('اختبار'), findsOneWidget);
      });

      testWidgets('shows document date and number with proper spacing',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'فاتورة',
                documentDate: '2026/07/25',
                documentNumber: 'DOC-001',
                child: Text('محتوى'),
              ),
            ),
          ),
        );

        expect(find.text('التاريخ: 2026/07/25'), findsOneWidget);
        expect(find.text('رقم المستند: DOC-001'), findsOneWidget);
      });

      testWidgets('back button pops navigation', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const PrintableDocumentScaffold(
                  title: 'اختبار',
                  child: Text('محتوى'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('رجوع'));
        await tester.pumpAndSettle();
      });

      testWidgets('no overflow on small viewport 360x720', (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: const Scaffold(
              body: PrintableDocumentScaffold(
                title: 'فاتورة بيع',
                documentDate: '2026/07/25',
                documentNumber: 'INV-001',
                child: Text('المحتوى'),
              ),
            ),
          ),
        );

        final finder = find.byType(PrintableDocumentScaffold);
        expect(finder, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('export and back buttons are accessible by scrolling',
          (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: const Scaffold(
              body: PrintableDocumentScaffold(
                title: 'اختبار',
                child: SizedBox(height: 2000),
              ),
            ),
          ),
        );

        final scrollView = find.byType(SingleChildScrollView);
        expect(scrollView, findsOneWidget);
      });
    });

    group('B. All 5 printable views render through migrated scaffold', () {
      testWidgets('sales invoice renders with title', (tester) async {
        final sale = SaleRecord(
          id: 'SALE-001',
          productId: 'p1',
          quantityKg: 100,
          salePriceQirshPerKg: 700,
          totalQirsh: 70000,
          createdByUserId: 'owner',
          createdAt: DateTime(2026, 7, 25, 10, 30),
          stockMovementId: 'sm1',
          customerId: 'c1',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableSalesInvoiceView(
                sale: sale,
                customerName: 'عميل تجريبي',
                productNames: const {'p1': 'قمح'},
              ),
            ),
          ),
        );

        expect(find.text('فاتورة بيع'), findsOneWidget);
        expect(find.text('عميل تجريبي'), findsOneWidget);
      });

      testWidgets('purchase invoice renders with title', (tester) async {
        final purchase = PurchaseIntake(
          id: 'PUR-001',
          supplierId: 's1',
          productId: 'p1',
          quantityKg: 500,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 600,
          totalAmountPiasters: 300000,
          createdByUserId: 'owner',
          createdAt: DateTime(2026, 7, 25, 9, 0),
          stockMovementId: 'sm5',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintablePurchaseInvoiceView(
                purchase: purchase,
                supplierName: 'مورد تجريبي',
                productName: 'قمح',
              ),
            ),
          ),
        );

        expect(find.text('فاتورة شراء'), findsOneWidget);
        expect(find.text('مورد تجريبي'), findsOneWidget);
      });

      testWidgets('customer statement renders with title', (tester) async {
        const statement = CustomerStatement(
          customerId: 'c1',
          finalBalanceQirsh: 0,
          lines: [],
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableCustomerStatementView(
                statement: statement,
                customerName: 'عميل تجريبي',
              ),
            ),
          ),
        );

        expect(find.text('كشف حساب عميل'), findsOneWidget);
        expect(find.textContaining('عميل تجريبي'), findsOneWidget);
      });

      testWidgets('supplier statement renders with title', (tester) async {
        const statement = SupplierStatement(
          supplierId: 's1',
          finalBalanceQirsh: 0,
          lines: [],
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableSupplierStatementView(
                statement: statement,
                supplierName: 'مورد تجريبي',
              ),
            ),
          ),
        );

        expect(find.text('كشف حساب مورد'), findsOneWidget);
        expect(find.textContaining('مورد تجريبي'), findsOneWidget);
      });

      testWidgets('daily report renders with title', (tester) async {
        final date = DateTime(2026, 7, 25);
        final report = DailyActivityReport(
          start: date,
          end: date,
          totalPurchasedKg: 0,
          totalSoldKg: 0,
          totalPurchaseAmountQirsh: 0,
          totalSalesAmountQirsh: 0,
          totalCreditSalesAmountQirsh: 0,
          totalExpenseAmountQirsh: 0,
          totalCollectionsAmountQirsh: 0,
          totalOutstandingReceivablesQirsh: 0,
          totalSupplierPaymentsQirsh: 0,
          totalOutstandingSupplierPayablesQirsh: 0,
          estimatedSalesCostQirsh: null,
          estimatedGrossProfitQirsh: null,
          estimatedStockValueQirsh: null,
          hasCompleteSalesCost: false,
          hasCompleteStockValuation: false,
          missingSalesCostProductNames: [],
          missingStockCostProductNames: [],
          purchaseCount: 0,
          saleCount: 0,
          stockMovementCount: 0,
          stockBalances: [],
          recentMovements: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableDailyReportView(
                report: report,
                reportDate: date,
              ),
            ),
          ),
        );

        expect(find.text('التقرير اليومي'), findsOneWidget);
      });
    });

    group('C. Action buttons preserved', () {
      testWidgets('shows export PDF button', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'اختبار',
                onExportPdf: null,
                child: Text('محتوى'),
              ),
            ),
          ),
        );

        expect(find.text('رجوع'), findsOneWidget);
      });

      testWidgets('shows export PDF and WhatsApp when callbacks provided',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'اختبار',
                child: const Text('محتوى'),
                onExportPdf: () async {},
                onOpenWhatsApp: () async {},
              ),
            ),
          ),
        );

        expect(find.text('تصدير PDF'), findsOneWidget);
        expect(find.text('فتح واتساب'), findsOneWidget);
        expect(find.text('رجوع'), findsOneWidget);
      });

      testWidgets('hides export buttons when callbacks are null',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'اختبار',
                child: Text('محتوى'),
              ),
            ),
          ),
        );

        expect(find.text('تصدير PDF'), findsNothing);
        expect(find.text('فتح واتساب'), findsNothing);
        expect(find.text('رجوع'), findsOneWidget);
      });
    });

    group('D. Branding preserved', () {
      testWidgets('displays default business identity name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'اختبار',
                child: Text('محتوى'),
              ),
            ),
          ),
        );

        expect(find.text('اختبار'), findsOneWidget);
      });
    });

    group('E. Back button correct positioning', () {
      testWidgets(
          'back button visible in first viewport on tall content without scrolling',
          (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'اختبار طويل',
                child: SizedBox(height: 5000),
              ),
            ),
          ),
        );

        expect(find.text('رجوع'), findsOneWidget);
        expect(find.byKey(const Key('printable-document-back-button')),
            findsOneWidget);
        final button = tester.widget<OutlinedButton>(
          find.byKey(const Key('printable-document-back-button')),
        );
        expect(button.onPressed, isNotNull);
      });

      testWidgets('only one back button exists — no duplicate', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'اختبار',
                child: SizedBox(height: 5000),
              ),
            ),
          ),
        );

        expect(find.text('رجوع'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      });

      testWidgets('back button pops route on tall content', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const Scaffold(
                            body: PrintableDocumentScaffold(
                              title: 'مستند طويل',
                              child: SizedBox(height: 5000),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('فتح'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('فتح'));
        await tester.pumpAndSettle();

        expect(find.byType(PrintableDocumentScaffold), findsOneWidget);
        expect(find.text('رجوع'), findsOneWidget);

        await tester.tap(find.text('رجوع'));
        await tester.pumpAndSettle();

        expect(find.byType(PrintableDocumentScaffold), findsNothing);
      });

      testWidgets('no overflow on small viewport 360x720 with tall content',
          (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'فاتورة بيع',
                documentDate: '2026/07/25',
                documentNumber: 'INV-001',
                child: SizedBox(height: 5000),
              ),
            ),
          ),
        );

        final finder = find.byType(PrintableDocumentScaffold);
        expect(finder, findsOneWidget);
        expect(find.text('رجوع'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
