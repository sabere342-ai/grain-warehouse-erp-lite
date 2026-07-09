import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/phone_number_normalizer.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/whatsapp_message_templates.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_customer_statement_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_daily_report_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_purchase_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_sales_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_supplier_statement_view.dart';

void main() {
  final now = DateTime(2026, 7, 9, 10, 30);

  group('Scenario A — Customer-bound sale to WhatsApp', () {
    testWidgets('sales invoice preview shows customer name, items, totals',
        (tester) async {
      final sale = SaleRecord(
        id: 'S-0001',
        productId: 'p1',
        quantityKg: 0,
        salePriceQirshPerKg: 0,
        totalQirsh: 950000,
        createdByUserId: 'owner',
        createdAt: now,
        stockMovementId: 'sm-1',
        customerId: 'c1',
        items: const [
          SaleLineItem(
            productId: 'p1', quantityKg: 300,
            salePriceQirshPerKg: 1000, lineTotalQirsh: 300000,
          ),
          SaleLineItem(
            productId: 'p2', quantityKg: 500,
            salePriceQirshPerKg: 1300, lineTotalQirsh: 650000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrintableSalesInvoiceView(
              sale: sale,
              customerName: 'أحمد',
              productNames: const {'p1': 'قمح', 'p2': 'شعير'},
              customerPhone: '01001234567',
            ),
          ),
        ),
      );

      expect(find.text('أحمد'), findsWidgets);
      expect(find.textContaining('قمح'), findsWidgets);
      expect(find.textContaining('شعير'), findsWidgets);
      expect(find.textContaining('كجم'), findsWidgets);
      expect(find.textContaining('تصدير PDF'), findsOneWidget);
      expect(find.textContaining('فتح واتساب'), findsOneWidget);
    });

    test('prepared message contains customer name, doc number, date, مرفق',
        () {
      final msg = WhatsAppMessageTemplates.salesInvoice(
        customerName: 'أحمد',
        documentNumber: 'S-0001',
        date: '2026/07/09',
      );
      expect(msg, contains('أحمد'));
      expect(msg, contains('S-0001'));
      expect(msg, contains('2026/07/09'));
      expect(msg, contains('مرفق'));
      expect(msg, isNot(contains('تم الإرسال')));
      expect(msg, isNot(contains('أرسلنا')));
    });

    testWidgets('فتح واتساب button is visible when valid customer phone exists',
        (tester) async {
      final sale = SaleRecord(
        id: 'S-0002', productId: 'p1', quantityKg: 500,
        salePriceQirshPerKg: 1000, totalQirsh: 500000,
        createdByUserId: 'owner', createdAt: now,
        stockMovementId: 'sm-2', customerId: 'c1',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintableSalesInvoiceView(
            sale: sale, customerName: 'عميل',
            productNames: const {'p1': 'قمح'},
            customerPhone: '01001234567',
          ),
        ),
      ));

      expect(find.text('فتح واتساب'), findsOneWidget);
    });
  });

  group('Scenario B — Customer without phone', () {
    testWidgets('sales invoice hides WhatsApp button when phone is null',
        (tester) async {
      final sale = SaleRecord(
        id: 'S-0003', productId: 'p1', quantityKg: 500,
        salePriceQirshPerKg: 1000, totalQirsh: 500000,
        createdByUserId: 'owner', createdAt: now,
        stockMovementId: 'sm-3', customerId: 'c1',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintableSalesInvoiceView(
            sale: sale, customerName: 'عميل',
            productNames: const {'p1': 'قمح'},
          ),
        ),
      ));

      expect(find.text('فتح واتساب'), findsNothing);
    });

    testWidgets('customer statement hides WhatsApp button when phone is null',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintableCustomerStatementView(
            statement: CustomerStatement(
              customerId: 'c1', finalBalanceQirsh: 0, lines: [],
            ),
            customerName: 'عميل',
          ),
        ),
      ));

      expect(find.text('فتح واتساب'), findsNothing);
    });

    test('PhoneNumberNormalizer returns null for invalid numbers', () {
      expect(PhoneNumberNormalizer.normalize(''), isNull);
      expect(PhoneNumberNormalizer.normalize('   '), isNull);
      expect(PhoneNumberNormalizer.normalize('02-23456789'), isNull);
      expect(PhoneNumberNormalizer.normalize('12345'), isNull);
      expect(PhoneNumberNormalizer.normalize(null), isNull);
    });
  });

  group('Scenario C — Supplier purchase to WhatsApp', () {
    testWidgets('purchase invoice shows فتح واتساب when valid supplier phone',
        (tester) async {
      final purchase = PurchaseIntake(
        id: 'P-0001', supplierId: 's1', productId: 'p1',
        quantityKg: 1000, entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 900, totalAmountPiasters: 900000,
        createdByUserId: 'owner', createdAt: now,
        stockMovementId: 'sm-p1',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintablePurchaseInvoiceView(
            purchase: purchase, supplierName: 'مورد',
            productName: 'قمح', supplierPhone: '01001234567',
          ),
        ),
      ));

      expect(find.text('فتح واتساب'), findsOneWidget);
    });

    testWidgets('purchase invoice hides WhatsApp when supplier phone is null',
        (tester) async {
      final purchase = PurchaseIntake(
        id: 'P-0002', supplierId: 's1', productId: 'p1',
        quantityKg: 1000, entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 900, totalAmountPiasters: 900000,
        createdByUserId: 'owner', createdAt: now,
        stockMovementId: 'sm-p2',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintablePurchaseInvoiceView(
            purchase: purchase, supplierName: 'مورد',
            productName: 'قمح',
          ),
        ),
      ));

      expect(find.text('فتح واتساب'), findsNothing);
    });

    test('supplier message contains supplier name, doc number, date, مرفق', () {
      final msg = WhatsAppMessageTemplates.purchaseInvoice(
        supplierName: 'شركة النور',
        documentNumber: 'P-0045',
        date: '2026/07/09',
      );
      expect(msg, contains('شركة النور'));
      expect(msg, contains('P-0045'));
      expect(msg, contains('مرفق'));
      expect(msg, isNot(contains('تم الإرسال')));
    });
  });

  group('Scenario D — Daily report', () {
    testWidgets('daily report shows PDF export but no WhatsApp',
        (tester) async {
      final report = DailyActivityReport(
        start: now, end: now,
        totalPurchasedKg: 1000, totalSoldKg: 500,
        totalPurchaseAmountQirsh: 100000, totalSalesAmountQirsh: 500000,
        totalCreditSalesAmountQirsh: 200000, totalExpenseAmountQirsh: 0,
        totalCollectionsAmountQirsh: 150000,
        totalOutstandingReceivablesQirsh: 100000,
        totalSupplierPaymentsQirsh: 50000,
        totalOutstandingSupplierPayablesQirsh: 40000,
        estimatedSalesCostQirsh: null, estimatedGrossProfitQirsh: null,
        estimatedStockValueQirsh: null,
        hasCompleteSalesCost: false, hasCompleteStockValuation: false,
        missingSalesCostProductNames: [],
        missingStockCostProductNames: [],
        purchaseCount: 2, saleCount: 5, stockMovementCount: 7,
        stockBalances: [], recentMovements: [],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintableDailyReportView(
            report: report, reportDate: now,
          ),
        ),
      ));

      expect(find.text('تصدير PDF'), findsOneWidget);
      expect(find.text('فتح واتساب'), findsNothing);
    });
  });

  group('Scenario E — Statements', () {
    testWidgets('customer statement shows subtitle و WhatsApp when phone',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintableCustomerStatementView(
            statement: CustomerStatement(
              customerId: 'c1', finalBalanceQirsh: 50000, lines: [],
            ),
            customerName: 'عميل تجريبي',
            customerPhone: '01001234567',
          ),
        ),
      ));

      expect(find.textContaining('جميع الحركات المتاحة'), findsOneWidget);
      expect(find.text('فتح واتساب'), findsOneWidget);
    });

    testWidgets('supplier statement shows subtitle و WhatsApp when phone',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintableSupplierStatementView(
            statement: SupplierStatement(
              supplierId: 's1', finalBalanceQirsh: 30000, lines: [],
            ),
            supplierName: 'مورد تجريبي',
            supplierPhone: '01001234567',
          ),
        ),
      ));

      expect(find.textContaining('جميع الحركات المتاحة'), findsOneWidget);
      expect(find.text('فتح واتساب'), findsOneWidget);
    });

    testWidgets('supplier statement hides WhatsApp when no phone',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrintableSupplierStatementView(
            statement: SupplierStatement(
              supplierId: 's1', finalBalanceQirsh: 0, lines: [],
            ),
            supplierName: 'مورد',
          ),
        ),
      ));

      expect(find.text('فتح واتساب'), findsNothing);
    });
  });

  group('Scenario F — Forbidden text audit across PDF and WhatsApp sources',
      () {
    final forbiddenPatterns = <String>[
      'تم الإرسال',
      'تم إرسال',
      'إرسال واتساب',
      'إرسال تلقائي',
      'WhatsApp API',
      'token',
      'قيد التنفيذ',
      'placeholder',
      'TODO',
    ];

    final sourceFiles = <String>[
      'lib/core/sharing/phone_number_normalizer.dart',
      'lib/core/sharing/whatsapp_message_templates.dart',
      'lib/core/sharing/whatsapp_assisted_share_service.dart',
      'lib/features/prints/printable_document_scaffold.dart',
      'lib/features/prints/printable_sales_invoice_view.dart',
      'lib/features/prints/printable_customer_statement_view.dart',
      'lib/features/prints/printable_purchase_invoice_view.dart',
      'lib/features/prints/printable_supplier_statement_view.dart',
      'lib/features/exports/pdf_export_service.dart',
      'lib/features/exports/pdf_file_naming.dart',
      'lib/features/exports/pdf_sales_invoice_builder.dart',
      'lib/features/exports/pdf_customer_statement_builder.dart',
      'lib/features/exports/pdf_daily_report_builder.dart',
      'lib/features/exports/pdf_purchase_invoice_builder.dart',
      'lib/features/exports/pdf_supplier_statement_builder.dart',
    ];

    for (final pattern in forbiddenPatterns) {
      test('no "$pattern" in any PDF/WhatsApp source file', () {
        for (final filePath in sourceFiles) {
          final content = File(filePath).readAsStringSync();
          expect(content, isNot(contains(pattern)),
              reason: '$filePath should not contain "$pattern"');
        }
      });
    }

    test('PDF SnackBar uses حفظ (save) not إرسال (send)', () {
      final content =
          File('lib/features/exports/pdf_export_service.dart')
              .readAsStringSync();
      expect(content, contains('\\u062a\\u0645 \\u062d\\u0641\\u0638'));
      expect(content, isNot(contains('\\u062a\\u0645 \\u0627\\u0644\\u0625\\u0631\\u0633\\u0627\\u0644')));
    });

    test('WhatsApp instruction says افتح and أرفق not تم الإرسال', () {
      final content =
          File('lib/core/sharing/whatsapp_assisted_share_service.dart')
              .readAsStringSync();
      expect(content, contains('\\u062A\\u0645 \\u0641\\u062A\\u062D'));
      expect(content, contains('\\u0623\\u0631\\u0641\\u0642'));
      expect(content, contains('\\u064A\\u062F\\u0648\\u064A\\u064B\\u0627'));
      expect(content, isNot(contains('\\u062A\\u0645 \\u0627\\u0644\\u0625\\u0631\\u0633\\u0627\\u0644')));
    });
  });

  group('Phase 42 & 43 integrity — existing tests not broken', () {
    test('PhoneNumberNormalizer still normalizes correctly', () {
      expect(PhoneNumberNormalizer.normalize('01001234567'),
          equals('201001234567'));
      expect(PhoneNumberNormalizer.normalize('+201001234567'),
          equals('201001234567'));
    });

    test('all 4 message templates still build', () {
      expect(
          WhatsAppMessageTemplates.salesInvoice(
              customerName: 'أ', documentNumber: '1', date: 'd'),
          isNotEmpty);
      expect(
          WhatsAppMessageTemplates.customerStatement(
              customerName: 'أ', date: 'd'),
          isNotEmpty);
      expect(
          WhatsAppMessageTemplates.purchaseInvoice(
              supplierName: 'أ', documentNumber: '1', date: 'd'),
          isNotEmpty);
      expect(
          WhatsAppMessageTemplates.supplierStatement(
              supplierName: 'أ', date: 'd'),
          isNotEmpty);
    });

    test('فتح واتساب button label exists in scaffold', () {
      final content =
          File('lib/features/prints/printable_document_scaffold.dart')
              .readAsStringSync();
      expect(content, contains('\\u0641\\u062A\\u062D \\u0648\\u0627\\u062A\\u0633\\u0627\\u0628'));
    });
  });
}
