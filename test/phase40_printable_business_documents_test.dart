import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
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
  group('Phase 40 - Printable Business Documents Foundation', () {
    group('A. PrintableDocumentScaffold', () {
      testWidgets('renders title and child content', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
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
        expect(
          find.text('يمكن مراجعة هذا المستند من الشاشة أو تصويره/حفظه حسب المتاح حاليًا.'),
          findsOneWidget,
        );
      });

      testWidgets('shows document date and number when provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PrintableDocumentScaffold(
                title: 'فاتورة',
                documentDate: '2026/07/09',
                documentNumber: 'DOC-001',
                child: Text('محتوى'),
              ),
            ),
          ),
        );

        expect(find.text('التاريخ: 2026/07/09'), findsOneWidget);
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
    });

    group('B. PrintableSalesInvoiceView', () {
      testWidgets('renders cash sale invoice correctly', (tester) async {
        final sale = SaleRecord(
          id: 'SALE-001',
          productId: 'p1',
          quantityKg: 100,
          salePriceQirshPerKg: 700,
          totalQirsh: 70000,
          createdByUserId: 'owner',
          createdAt: DateTime(2026, 7, 9, 10, 30),
          stockMovementId: 'sm1',
          customerId: 'c1',
          notes: 'ملاحظات تجريبية',
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
        expect(find.text('نقدي'), findsOneWidget);
        expect(find.textContaining('الإجمالي'), findsWidgets);
        expect(find.textContaining('ملاحظات تجريبية'), findsOneWidget);
      });

      testWidgets('renders cancelled credit sale', (tester) async {
        final now = DateTime(2026, 7, 9, 12, 0);
        final sale = SaleRecord(
          id: 'SALE-002',
          productId: 'p1',
          quantityKg: 50,
          salePriceQirshPerKg: 800,
          totalQirsh: 40000,
          createdByUserId: 'owner',
          createdAt: now,
          stockMovementId: 'sm2',
          paymentMode: SalePaymentMode.credit,
          customerId: 'c1',
          cancellation: CancellationMetadata(
            cancelledByUserId: 'owner',
            cancelledAt: now,
            cancellationReason: 'خطأ في البيانات',
            originalDocumentId: 'SALE-002',
            reversalMovementIds: ['sm2-rev'],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableSalesInvoiceView(
                sale: sale,
                customerName: 'عميل آخر',
                productNames: const {'p1': 'قمح'},
              ),
            ),
          ),
        );

        expect(find.text('آجل'), findsOneWidget);
        expect(find.text('ملغاة — تم عكس الأرصدة'), findsOneWidget);
      });

      testWidgets('renders partial payment info', (tester) async {
        final sale = SaleRecord(
          id: 'SALE-003',
          productId: 'p1',
          quantityKg: 100,
          salePriceQirshPerKg: 1000,
          totalQirsh: 100000,
          createdByUserId: 'owner',
          createdAt: DateTime(2026, 7, 9, 14, 0),
          stockMovementId: 'sm3',
          paymentMode: SalePaymentMode.partial,
          paidAmountQirsh: 30000,
          customerId: 'c1',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableSalesInvoiceView(
                sale: sale,
                customerName: 'عميل جزئي',
                productNames: const {'p1': 'قمح'},
              ),
            ),
          ),
        );

        expect(find.text('مدفوع جزئيًا'), findsOneWidget);
        expect(find.textContaining('المدفوع'), findsWidgets);
        expect(find.textContaining('المتبقي'), findsWidgets);
      });

      testWidgets('renders multi-item sale', (tester) async {
        final sale = SaleRecord(
          id: 'SALE-004',
          productId: 'p1',
          quantityKg: 0,
          salePriceQirshPerKg: 0,
          totalQirsh: 130000,
          createdByUserId: 'owner',
          createdAt: DateTime(2026, 7, 9, 15, 0),
          stockMovementId: 'sm4',
          customerId: 'c1',
          items: const [
            SaleLineItem(
              productId: 'p1',
              quantityKg: 50,
              salePriceQirshPerKg: 700,
              lineTotalQirsh: 35000,
            ),
            SaleLineItem(
              productId: 'p2',
              quantityKg: 100,
              salePriceQirshPerKg: 950,
              lineTotalQirsh: 95000,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableSalesInvoiceView(
                sale: sale,
                customerName: 'عميل متعدد',
                productNames: const {'p1': 'قمح', 'p2': 'شعير'},
              ),
            ),
          ),
        );

        expect(find.text('فاتورة بيع'), findsOneWidget);
        expect(find.text('عميل متعدد'), findsOneWidget);
      });
    });

    group('C. PrintableCustomerStatementView', () {
      testWidgets('renders statement with entries', (tester) async {
        final now = DateTime(2026, 7, 9);
        final statement = CustomerStatement(
          customerId: 'c1',
          finalBalanceQirsh: 70000,
          lines: [
            CustomerStatementLine(
              entry: CustomerAccountEntry(
                id: 'e1',
                customerId: 'c1',
                date: DateTime(2026, 1, 1),
                type: CustomerAccountEntryType.openingBalance,
                debitAmountQirsh: 50000,
                creditAmountQirsh: 0,
                sourceDocumentType: 'manual',
                sourceDocumentId: 'OB-001',
                descriptionAr: 'رصيد افتتاحي',
                createdAt: now,
                createdByUserId: 'owner',
              ),
              runningBalanceQirsh: 50000,
            ),
            CustomerStatementLine(
              entry: CustomerAccountEntry(
                id: 'e2',
                customerId: 'c1',
                date: now,
                type: CustomerAccountEntryType.creditSale,
                debitAmountQirsh: 40000,
                creditAmountQirsh: 0,
                sourceDocumentType: 'sale',
                sourceDocumentId: 'SALE-001',
                descriptionAr: 'فاتورة بيع آجل',
                createdAt: now,
                createdByUserId: 'owner',
              ),
              runningBalanceQirsh: 90000,
            ),
            CustomerStatementLine(
              entry: CustomerAccountEntry(
                id: 'e3',
                customerId: 'c1',
                date: now,
                type: CustomerAccountEntryType.collection,
                debitAmountQirsh: 0,
                creditAmountQirsh: 20000,
                sourceDocumentType: 'collection',
                sourceDocumentId: 'COL-001',
                descriptionAr: 'تحصيل نقدي',
                createdAt: now,
                createdByUserId: 'owner',
              ),
              runningBalanceQirsh: 70000,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableCustomerStatementView(
                statement: statement,
                customerName: 'عميل تجريبي',
              ),
            ),
          ),
        );

        expect(find.text('كشف حساب عميل'), findsOneWidget);
        expect(find.text('عميل تجريبي'), findsOneWidget);
        expect(find.textContaining('الرصيد النهائي'), findsWidgets);
      });

      testWidgets('handles zero balance', (tester) async {
        final statement = const CustomerStatement(
          customerId: 'c1',
          finalBalanceQirsh: 0,
          lines: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableCustomerStatementView(
                statement: statement,
                customerName: 'عميل بدون رصيد',
              ),
            ),
          ),
        );

        expect(find.text('عميل بدون رصيد'), findsOneWidget);
        expect(find.textContaining('لا يوجد رصيد'), findsOneWidget);
      });
    });

    group('D. PrintableDailyReportView', () {
      testWidgets('renders daily report with sales and purchases', (tester) async {
        final date = DateTime(2026, 7, 9);
        final report = DailyActivityReport(
          start: date,
          end: date,
          totalPurchasedKg: 5000,
          totalSoldKg: 3000,
          totalPurchaseAmountQirsh: 20000,
          totalSalesAmountQirsh: 80000,
          totalCreditSalesAmountQirsh: 30000,
          totalExpenseAmountQirsh: 0,
          totalCollectionsAmountQirsh: 25000,
          totalOutstandingReceivablesQirsh: 5000,
          totalSupplierPaymentsQirsh: 0,
          totalOutstandingSupplierPayablesQirsh: 0,
          estimatedSalesCostQirsh: null,
          estimatedGrossProfitQirsh: null,
          estimatedStockValueQirsh: null,
          hasCompleteSalesCost: false,
          hasCompleteStockValuation: false,
          missingSalesCostProductNames: [],
          missingStockCostProductNames: [],
          purchaseCount: 1,
          saleCount: 3,
          stockMovementCount: 4,
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
        expect(find.text('قسم المبيعات'), findsOneWidget);
        expect(find.text('قسم المشتريات'), findsOneWidget);
        expect(find.text('الملخص'), findsOneWidget);
      });

      testWidgets('renders empty report gracefully', (tester) async {
        final date = DateTime(2026, 7, 9);
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

    group('E. PrintablePurchaseInvoiceView', () {
      testWidgets('renders purchase invoice correctly', (tester) async {
        final purchase = PurchaseIntake(
          id: 'PUR-001',
          supplierId: 's1',
          productId: 'p1',
          quantityKg: 500,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 600,
          totalAmountPiasters: 300000,
          createdByUserId: 'owner',
          createdAt: DateTime(2026, 7, 9, 9, 0),
          stockMovementId: 'sm5',
          notes: 'ملاحظات الشراء',
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
        expect(find.textContaining('كجم'), findsWidgets);
      });

      testWidgets('renders cancelled purchase invoice', (tester) async {
        final now = DateTime(2026, 7, 9, 10, 0);
        final purchase = PurchaseIntake(
          id: 'PUR-002',
          supplierId: 's1',
          productId: 'p1',
          quantityKg: 200,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 700,
          totalAmountPiasters: 140000,
          createdByUserId: 'owner',
          createdAt: now,
          stockMovementId: 'sm6',
          cancellation: CancellationMetadata(
            cancelledByUserId: 'owner',
            cancelledAt: now,
            cancellationReason: 'خطأ في الكمية',
            originalDocumentId: 'PUR-002',
            reversalMovementIds: ['sm6-rev'],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintablePurchaseInvoiceView(
                purchase: purchase,
                supplierName: 'مورد آخر',
                productName: 'شعير',
              ),
            ),
          ),
        );

        expect(find.text('ملغاة — تم عكس الأرصدة'), findsOneWidget);
      });
    });

    group('F. PrintableSupplierStatementView', () {
      testWidgets('renders supplier statement with entries', (tester) async {
        final now = DateTime(2026, 7, 9);
        final statement = SupplierStatement(
          supplierId: 's1',
          finalBalanceQirsh: 300000,
          lines: [
            SupplierStatementLine(
              entry: SupplierAccountEntry(
                id: 'e1',
                supplierId: 's1',
                date: DateTime(2026, 1, 1),
                type: SupplierAccountEntryType.openingBalance,
                debitAmountQirsh: 200000,
                creditAmountQirsh: 0,
                sourceDocumentType: 'manual',
                sourceDocumentId: 'OB-001',
                descriptionAr: 'رصيد افتتاحي',
                createdAt: now,
                createdByUserId: 'owner',
              ),
              runningBalanceQirsh: 200000,
            ),
            SupplierStatementLine(
              entry: SupplierAccountEntry(
                id: 'e2',
                supplierId: 's1',
                date: now,
                type: SupplierAccountEntryType.purchase,
                debitAmountQirsh: 150000,
                creditAmountQirsh: 0,
                sourceDocumentType: 'purchase',
                sourceDocumentId: 'PUR-001',
                descriptionAr: 'فاتورة شراء',
                createdAt: now,
                createdByUserId: 'owner',
              ),
              runningBalanceQirsh: 350000,
            ),
            SupplierStatementLine(
              entry: SupplierAccountEntry(
                id: 'e3',
                supplierId: 's1',
                date: now,
                type: SupplierAccountEntryType.payment,
                debitAmountQirsh: 0,
                creditAmountQirsh: 50000,
                sourceDocumentType: 'payment',
                sourceDocumentId: 'PAY-001',
                descriptionAr: 'دفعة للمورد',
                createdAt: now,
                createdByUserId: 'owner',
              ),
              runningBalanceQirsh: 300000,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableSupplierStatementView(
                statement: statement,
                supplierName: 'مورد تجريبي',
              ),
            ),
          ),
        );

        expect(find.text('كشف حساب مورد'), findsOneWidget);
        expect(find.text('مورد تجريبي'), findsOneWidget);
        expect(find.textContaining('الرصيد النهائي'), findsWidgets);
      });

      testWidgets('handles zero supplier balance', (tester) async {
        final statement = const SupplierStatement(
          supplierId: 's1',
          finalBalanceQirsh: 0,
          lines: [],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrintableSupplierStatementView(
                statement: statement,
                supplierName: 'مورد بدون رصيد',
              ),
            ),
          ),
        );

        expect(find.text('مورد بدون رصيد'), findsOneWidget);
        expect(find.textContaining('لا يوجد رصيد'), findsOneWidget);
      });
    });
  });
}
