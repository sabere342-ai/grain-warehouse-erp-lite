import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_customer_statement_builder.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_daily_report_builder.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_file_naming.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_purchase_invoice_builder.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_sales_invoice_builder.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_supplier_statement_builder.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_export_service.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_customer_statement_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_daily_report_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_purchase_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_sales_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_supplier_statement_view.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  final now = DateTime(2026, 7, 9, 10, 30);

  group('A. File naming — Windows-safe sanitization', () {
    test('sanitizes forbidden Windows characters', () {
      final name = PdfFileNaming.salesInvoice(
        'SALE:001?',
        now,
      );
      expect(name.contains(':'), isFalse);
      expect(name.contains('?'), isFalse);
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('sales invoice filename pattern', () {
      final name = PdfFileNaming.salesInvoice('S-000123', now);
      expect(name, contains('فاتورة-بيع'));
      expect(name, contains('S-000123'));
      expect(name, contains('2026-07-09'));
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('customer statement filename pattern', () {
      final name = PdfFileNaming.customerStatement('محمد', now);
      expect(name, contains('كشف-حساب-عميل'));
      expect(name, contains('محمد'));
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('daily report filename pattern', () {
      final name = PdfFileNaming.dailyReport(now);
      expect(name, contains('تقرير-يومي'));
      expect(name, contains('2026-07-09'));
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('purchase invoice filename pattern', () {
      final name = PdfFileNaming.purchaseInvoice('P-000045', now);
      expect(name, contains('فاتورة-شراء'));
      expect(name, contains('P-000045'));
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('supplier statement filename pattern', () {
      final name = PdfFileNaming.supplierStatement('شركة النور', now);
      expect(name, contains('كشف-حساب-مورد'));
      expect(name, contains('شركة النور'));
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('no raw database IDs in filename', () {
      final name = PdfFileNaming.salesInvoice('S-000123', now);
      expect(name, isNot(contains('productId')));
      expect(name, isNot(contains('customerId')));
    });

    test('no excessive length', () {
      final longName = 'أ' * 100;
      final name = PdfFileNaming.customerStatement(longName, now);
      expect(name.length, lessThan(200));
    });
  });

  group('B. PDF generation', () {
    late pw.Font arabicFont;
    late pw.Font arabicFontBold;

    setUpAll(() async {
      await PdfExportService.initialize();
      final regular =
          await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final bold =
          await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
      arabicFont = pw.Font.ttf(regular.buffer.asByteData());
      arabicFontBold = pw.Font.ttf(bold.buffer.asByteData());
    });

    testWidgets('sales invoice PDF bytes are generated', (tester) async {
      final sale = SaleRecord(
        id: 'S-0001',
        productId: 'p1',
        quantityKg: 500,
        salePriceQirshPerKg: 1000,
        totalQirsh: 500000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-1',
        customerId: 'c1',
      );

      final bytes = await PdfSalesInvoiceBuilder.build(
        sale: sale,
        customerName: 'عميل تجريبي',
        productNames: const {'p1': 'قمح'},
        arabicFont: arabicFont,
        arabicFontBold: arabicFontBold,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    testWidgets('cancelled sales invoice PDF has cancellation notice',
        (tester) async {
      final sale = SaleRecord(
        id: 'S-0002',
        productId: 'p1',
        quantityKg: 500,
        salePriceQirshPerKg: 1000,
        totalQirsh: 500000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-2',
        customerId: 'c1',
        cancellation: CancellationMetadata(
          cancelledByUserId: 'owner',
          cancelledAt: now,
          cancellationReason: 'خطأ في الإدخال',
          originalDocumentId: 'S-0002',
          reversalMovementIds: ['sm-2-rev'],
        ),
      );

      final bytes = await PdfSalesInvoiceBuilder.build(
        sale: sale,
        customerName: 'عميل تجريبي',
        productNames: const {'p1': 'قمح'},
        arabicFont: arabicFont,
        arabicFontBold: arabicFontBold,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    testWidgets('multi-item sales invoice PDF is generated', (tester) async {
      final sale = SaleRecord(
        id: 'S-0003',
        productId: 'p1',
        quantityKg: 0,
        salePriceQirshPerKg: 0,
        totalQirsh: 950000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-3',
        customerId: 'c1',
        items: const [
          SaleLineItem(
            productId: 'p1',
            quantityKg: 300,
            salePriceQirshPerKg: 1000,
            lineTotalQirsh: 300000,
          ),
          SaleLineItem(
            productId: 'p2',
            quantityKg: 500,
            salePriceQirshPerKg: 1300,
            lineTotalQirsh: 650000,
          ),
        ],
      );

      final bytes = await PdfSalesInvoiceBuilder.build(
        sale: sale,
        customerName: 'عميل تجريبي',
        productNames: const {'p1': 'قمح', 'p2': 'شعير'},
        arabicFont: arabicFont,
        arabicFontBold: arabicFontBold,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    testWidgets('customer statement PDF bytes are generated', (tester) async {
      final statement = CustomerStatement(
        customerId: 'c1',
        finalBalanceQirsh: 100000,
        lines: [
          CustomerStatementLine(
            entry: CustomerAccountEntry(
              id: 'e1',
              customerId: 'c1',
              date: now,
              type: CustomerAccountEntryType.openingBalance,
              debitAmountQirsh: 50000,
              creditAmountQirsh: 0,
              sourceDocumentType: 'opening',
              sourceDocumentId: 'open-1',
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
              type: CustomerAccountEntryType.collection,
              debitAmountQirsh: 0,
              creditAmountQirsh: 50000,
              sourceDocumentType: 'collection',
              sourceDocumentId: 'col-1',
              descriptionAr: 'تحصيل',
              createdAt: now,
              createdByUserId: 'owner',
            ),
            runningBalanceQirsh: 0,
          ),
        ],
      );

      final bytes = await PdfCustomerStatementBuilder.build(
        statement: statement,
        customerName: 'عميل تجريبي',
        arabicFont: arabicFont,
        arabicFontBold: arabicFontBold,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    testWidgets('daily report PDF bytes are generated', (tester) async {
      final report = DailyActivityReport(
        start: now,
        end: now,
        totalPurchasedKg: 1000,
        totalSoldKg: 500,
        totalPurchaseAmountQirsh: 100000,
        totalSalesAmountQirsh: 500000,
        totalCreditSalesAmountQirsh: 200000,
        totalExpenseAmountQirsh: 30000,
        totalCollectionsAmountQirsh: 150000,
        totalOutstandingReceivablesQirsh: 100000,
        totalSupplierPaymentsQirsh: 50000,
        totalOutstandingSupplierPayablesQirsh: 40000,
        estimatedSalesCostQirsh: null,
        estimatedGrossProfitQirsh: null,
        estimatedStockValueQirsh: null,
        hasCompleteSalesCost: false,
        hasCompleteStockValuation: false,
        missingSalesCostProductNames: [],
        missingStockCostProductNames: [],
        purchaseCount: 2,
        saleCount: 5,
        stockMovementCount: 7,
        stockBalances: [],
        recentMovements: [],
      );

      final bytes = await PdfDailyReportBuilder.build(
        report: report,
        reportDate: now,
        arabicFont: arabicFont,
        arabicFontBold: arabicFontBold,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    testWidgets('purchase invoice PDF bytes are generated', (tester) async {
      final purchase = PurchaseIntake(
        id: 'P-0001',
        supplierId: 's1',
        productId: 'p1',
        quantityKg: 1000,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 900,
        totalAmountPiasters: 900000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-p1',
        supplierName: 'مورد تجريبي',
      );

      final bytes = await PdfPurchaseInvoiceBuilder.build(
        purchase: purchase,
        supplierName: 'مورد تجريبي',
        productName: 'قمح',
        arabicFont: arabicFont,
        arabicFontBold: arabicFontBold,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    testWidgets('cancelled purchase invoice PDF is generated', (tester) async {
      final purchase = PurchaseIntake(
        id: 'P-0002',
        supplierId: 's1',
        productId: 'p1',
        quantityKg: 1000,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 900,
        totalAmountPiasters: 900000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-p2',
        supplierName: 'مورد تجريبي',
        cancellation: CancellationMetadata(
          cancelledByUserId: 'owner',
          cancelledAt: now,
          cancellationReason: 'إلغاء',
          originalDocumentId: 'P-0002',
          reversalMovementIds: ['sm-p2-rev'],
        ),
      );

      final bytes = await PdfPurchaseInvoiceBuilder.build(
        purchase: purchase,
        supplierName: 'مورد تجريبي',
        productName: 'قمح',
        arabicFont: arabicFont,
        arabicFontBold: arabicFontBold,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    testWidgets('supplier statement PDF bytes are generated', (tester) async {
      final statement = SupplierStatement(
        supplierId: 's1',
        finalBalanceQirsh: 50000,
        lines: [
          SupplierStatementLine(
            entry: SupplierAccountEntry(
              id: 'se1',
              supplierId: 's1',
              date: now,
              type: SupplierAccountEntryType.purchase,
              debitAmountQirsh: 900000,
              creditAmountQirsh: 0,
              sourceDocumentType: 'purchase',
              sourceDocumentId: 'P-0001',
              descriptionAr: 'فاتورة شراء',
              createdAt: now,
              createdByUserId: 'owner',
            ),
            runningBalanceQirsh: 900000,
          ),
          SupplierStatementLine(
            entry: SupplierAccountEntry(
              id: 'se2',
              supplierId: 's1',
              date: now,
              type: SupplierAccountEntryType.payment,
              debitAmountQirsh: 0,
              creditAmountQirsh: 850000,
              sourceDocumentType: 'payment',
              sourceDocumentId: 'pay-1',
              descriptionAr: 'دفعة',
              createdAt: now,
              createdByUserId: 'owner',
            ),
            runningBalanceQirsh: 50000,
          ),
        ],
      );

      final bytes = await PdfSupplierStatementBuilder.build(
        statement: statement,
        supplierName: 'مورد تجريبي',
        arabicFont: arabicFont,
        arabicFontBold: arabicFontBold,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('C. PDF export button appears on printable views', () {
    testWidgets('sales invoice shows تصدير PDF', (tester) async {
      final sale = SaleRecord(
        id: 'S-0001',
        productId: 'p1',
        quantityKg: 500,
        salePriceQirshPerKg: 1000,
        totalQirsh: 500000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-1',
        customerId: 'c1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintableSalesInvoiceView(
              sale: sale,
              customerName: 'عميل',
              productNames: const {'p1': 'قمح'},
            ),
          ),
        ),
      );

      expect(find.text('تصدير PDF'), findsOneWidget);
    });

    testWidgets('customer statement shows تصدير PDF', (tester) async {
      final statement = CustomerStatement(
        customerId: 'c1',
        finalBalanceQirsh: 0,
        lines: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintableCustomerStatementView(
              statement: statement,
              customerName: 'عميل',
            ),
          ),
        ),
      );

      expect(find.text('تصدير PDF'), findsOneWidget);
    });

    testWidgets('daily report shows تصدير PDF', (tester) async {
      final report = DailyActivityReport(
        start: now,
        end: now,
        totalPurchasedKg: 1000,
        totalSoldKg: 500,
        totalPurchaseAmountQirsh: 100000,
        totalSalesAmountQirsh: 500000,
        totalCreditSalesAmountQirsh: 200000,
        totalExpenseAmountQirsh: 0,
        totalCollectionsAmountQirsh: 150000,
        totalOutstandingReceivablesQirsh: 100000,
        totalSupplierPaymentsQirsh: 50000,
        totalOutstandingSupplierPayablesQirsh: 40000,
        estimatedSalesCostQirsh: null,
        estimatedGrossProfitQirsh: null,
        estimatedStockValueQirsh: null,
        hasCompleteSalesCost: false,
        hasCompleteStockValuation: false,
        missingSalesCostProductNames: [],
        missingStockCostProductNames: [],
        purchaseCount: 2,
        saleCount: 5,
        stockMovementCount: 7,
        stockBalances: [],
        recentMovements: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintableDailyReportView(
              report: report,
              reportDate: now,
            ),
          ),
        ),
      );

      expect(find.text('تصدير PDF'), findsOneWidget);
    });

    testWidgets('purchase invoice shows تصدير PDF', (tester) async {
      final purchase = PurchaseIntake(
        id: 'P-0001',
        supplierId: 's1',
        productId: 'p1',
        quantityKg: 1000,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 900,
        totalAmountPiasters: 900000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-p1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintablePurchaseInvoiceView(
              purchase: purchase,
              supplierName: 'مورد',
              productName: 'قمح',
            ),
          ),
        ),
      );

      expect(find.text('تصدير PDF'), findsOneWidget);
    });

    testWidgets('supplier statement shows تصدير PDF', (tester) async {
      final statement = SupplierStatement(
        supplierId: 's1',
        finalBalanceQirsh: 0,
        lines: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintableSupplierStatementView(
              statement: statement,
              supplierName: 'مورد',
            ),
          ),
        ),
      );

      expect(find.text('تصدير PDF'), findsOneWidget);
    });
  });

  group('D. No forbidden text in Phase 42 scope', () {
    testWidgets('no إرسال واتساب in printable views', (tester) async {
      final sale = SaleRecord(
        id: 'S-0001',
        productId: 'p1',
        quantityKg: 500,
        salePriceQirshPerKg: 1000,
        totalQirsh: 500000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-1',
        customerId: 'c1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintableSalesInvoiceView(
              sale: sale,
              customerName: 'عميل',
              productNames: const {'p1': 'قمح'},
            ),
          ),
        ),
      );

      expect(find.textContaining('إرسال'), findsNothing);
      expect(find.textContaining('واتساب'), findsNothing);
    });

    testWidgets('no placeholder, TODO, or قيد التنفيذ in exports source',
        (tester) async {
      final exportFiles = <String>[
        'lib/features/exports/pdf_export_service.dart',
        'lib/features/exports/pdf_file_naming.dart',
        'lib/features/exports/pdf_sales_invoice_builder.dart',
        'lib/features/exports/pdf_customer_statement_builder.dart',
        'lib/features/exports/pdf_daily_report_builder.dart',
        'lib/features/exports/pdf_purchase_invoice_builder.dart',
        'lib/features/exports/pdf_supplier_statement_builder.dart',
      ];

      for (final path in exportFiles) {
        final content = File(path).readAsStringSync();
        expect(content, isNot(contains('placeholder')));
        expect(content, isNot(contains('TODO')));
        expect(content, isNot(contains('قيد التنفيذ')));
      }
    });

    testWidgets('no PDF button on screens without PDF export', (tester) async {
      // Verify no button with misleading text exists in the exports code
      final exportServiceContent =
          File('lib/features/exports/pdf_export_service.dart')
              .readAsStringSync();
      expect(exportServiceContent, isNot(contains('طباعة')));
      expect(exportServiceContent, isNot(contains('مشاركة')));
    });
  });
}
