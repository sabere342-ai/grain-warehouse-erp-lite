import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/phone_number_normalizer.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/whatsapp_message_templates.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_customer_statement_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_daily_report_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_purchase_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_sales_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_supplier_statement_view.dart';

void main() {
  final now = DateTime(2026, 7, 9, 10, 30);

  group('A. Phone number normalization', () {
    test('normalizes 010xxxxxxxx (11 digits) to 2010xxxxxxxx', () {
      final result = PhoneNumberNormalizer.normalize('01001234567');
      expect(result, equals('201001234567'));
    });

    test('normalizes +2010xxxxxxxx (13 digits)', () {
      final result = PhoneNumberNormalizer.normalize('+201001234567');
      expect(result, equals('201001234567'));
    });

    test('normalizes 002010xxxxxxxx (14 digits)', () {
      final result = PhoneNumberNormalizer.normalize('00201001234567');
      expect(result, equals('201001234567'));
    });

    test('normalizes 2010xxxxxxxx (12 digits) as-is', () {
      final result = PhoneNumberNormalizer.normalize('201001234567');
      expect(result, equals('201001234567'));
    });

    test('normalizes 011, 012, 015 prefixes', () {
      expect(PhoneNumberNormalizer.normalize('01112345678'),
          equals('201112345678'));
      expect(PhoneNumberNormalizer.normalize('01212345678'),
          equals('201212345678'));
      expect(PhoneNumberNormalizer.normalize('01512345678'),
          equals('201512345678'));
    });

    test('returns null for empty string', () {
      expect(PhoneNumberNormalizer.normalize(''), isNull);
    });

    test('returns null for null input', () {
      expect(PhoneNumberNormalizer.normalize(null), isNull);
    });

    test('returns null for whitespace-only', () {
      expect(PhoneNumberNormalizer.normalize('   '), isNull);
    });

    test('returns null for non-mobile Egyptian number (landline)', () {
      expect(PhoneNumberNormalizer.normalize('0223456789'), isNull);
    });

    test('returns null for too-short number', () {
      expect(PhoneNumberNormalizer.normalize('010123'), isNull);
    });

    test('normalizes number with spaces and dashes', () {
      final result = PhoneNumberNormalizer.normalize('010 1234 5678');
      expect(result, equals('201012345678'));
    });

    test('normalizes number with parentheses', () {
      final result = PhoneNumberNormalizer.normalize('+(20) 1001234567');
      expect(result, equals('201001234567'));
    });
  });

  group('B. WhatsApp message templates', () {
    test('sales invoice message contains customer name and document number',
        () {
      final msg = WhatsAppMessageTemplates.salesInvoice(
        customerName: 'أحمد',
        documentNumber: 'S-0001',
        date: '2026/07/09',
      );
      expect(msg, contains('أحمد'));
      expect(msg, contains('S-0001'));
      expect(msg, contains('2026/07/09'));
      expect(msg, contains('فاتورة'));
      expect(msg, contains('مرفق'));
    });

    test('customer statement message contains customer name and date', () {
      final msg = WhatsAppMessageTemplates.customerStatement(
        customerName: 'محمد',
        date: '2026/07/09',
      );
      expect(msg, contains('محمد'));
      expect(msg, contains('2026/07/09'));
      expect(msg, contains('كشف'));
      expect(msg, contains('مرفق'));
    });

    test('purchase invoice message contains supplier name and document number',
        () {
      final msg = WhatsAppMessageTemplates.purchaseInvoice(
        supplierName: 'شركة النور',
        documentNumber: 'P-0045',
        date: '2026/07/09',
      );
      expect(msg, contains('شركة النور'));
      expect(msg, contains('P-0045'));
      expect(msg, contains('2026/07/09'));
      expect(msg, contains('فاتورة'));
      expect(msg, contains('مرفق'));
    });

    test('supplier statement message contains supplier name and date', () {
      final msg = WhatsAppMessageTemplates.supplierStatement(
        supplierName: 'المورد السريع',
        date: '2026/07/09',
      );
      expect(msg, contains('المورد السريع'));
      expect(msg, contains('2026/07/09'));
      expect(msg, contains('كشف'));
      expect(msg, contains('مرفق'));
    });

    test('all messages reference PDF attachment (مرفق) not auto-send', () {
      final sales = WhatsAppMessageTemplates.salesInvoice(
          customerName: 'أ', documentNumber: '1', date: 'd');
      final customer = WhatsAppMessageTemplates.customerStatement(
          customerName: 'أ', date: 'd');
      final purchase = WhatsAppMessageTemplates.purchaseInvoice(
          supplierName: 'أ', documentNumber: '1', date: 'd');
      final supplier = WhatsAppMessageTemplates.supplierStatement(
          supplierName: 'أ', date: 'd');

      for (final msg in [sales, customer, purchase, supplier]) {
        expect(msg, contains('مرفق'));
        expect(msg, isNot(contains('تم الإرسال')));
        expect(msg, isNot(contains('أرسلنا')));
      }
    });
  });

  group('C. WhatsApp button visibility on printable views', () {
    testWidgets('sales invoice shows فتح واتساب when phone provided',
        (tester) async {
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
              customerPhone: '01001234567',
            ),
          ),
        ),
      );

      expect(find.text('فتح واتساب'), findsOneWidget);
    });

    testWidgets('sales invoice hides فتح واتساب when phone is null',
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

      expect(find.text('فتح واتساب'), findsNothing);
    });

    testWidgets('customer statement shows فتح واتساب when phone provided',
        (tester) async {
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
              customerName: 'عميل',
              customerPhone: '01001234567',
            ),
          ),
        ),
      );

      expect(find.text('فتح واتساب'), findsOneWidget);
    });

    testWidgets('customer statement hides فتح واتساب when phone is null',
        (tester) async {
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
              customerName: 'عميل',
            ),
          ),
        ),
      );

      expect(find.text('فتح واتساب'), findsNothing);
    });

    testWidgets('purchase invoice shows فتح واتساب when phone provided',
        (tester) async {
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
              supplierPhone: '01001234567',
            ),
          ),
        ),
      );

      expect(find.text('فتح واتساب'), findsOneWidget);
    });

    testWidgets('purchase invoice hides فتح واتساب when phone is null',
        (tester) async {
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

      expect(find.text('فتح واتساب'), findsNothing);
    });

    testWidgets('supplier statement shows فتح واتساب when phone provided',
        (tester) async {
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
              supplierName: 'مورد',
              supplierPhone: '01001234567',
            ),
          ),
        ),
      );

      expect(find.text('فتح واتساب'), findsOneWidget);
    });

    testWidgets('supplier statement hides فتح واتساب when phone is null',
        (tester) async {
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
              supplierName: 'مورد',
            ),
          ),
        ),
      );

      expect(find.text('فتح واتساب'), findsNothing);
    });

    testWidgets('daily report does NOT show فتح واتساب', (tester) async {
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

      expect(find.text('فتح واتساب'), findsNothing);
    });
  });

  group('D. Forbidden text audit in WhatsApp sharing source', () {
    test('no auto-send claims in WhatsApp sharing source files', () {
      final sourceFiles = <String>[
        'lib/core/sharing/phone_number_normalizer.dart',
        'lib/core/sharing/whatsapp_message_templates.dart',
        'lib/core/sharing/whatsapp_assisted_share_service.dart',
        'lib/features/prints/printable_document_scaffold.dart',
        'lib/features/prints/printable_sales_invoice_view.dart',
        'lib/features/prints/printable_customer_statement_view.dart',
        'lib/features/prints/printable_purchase_invoice_view.dart',
        'lib/features/prints/printable_supplier_statement_view.dart',
      ];

      for (final path in sourceFiles) {
        final content = File(path).readAsStringSync();
        expect(content, isNot(contains('placeholder')));
        expect(content, isNot(contains('TODO')));
        expect(content, isNot(contains('قيد التنفيذ')));
        expect(content, isNot(contains('تم الإرسال')));
        expect(content, isNot(contains('أرسلنا')));
        expect(content, isNot(contains('تم التحميل')));
      }
    });

    test('فتح واتساب button label exists in scaffold source', () {
      final scaffoldContent =
          File('lib/features/prints/printable_document_scaffold.dart')
              .readAsStringSync();
      expect(
          scaffoldContent,
          contains(
              '\\u0641\\u062A\\u062D \\u0648\\u0627\\u062A\\u0633\\u0627\\u0628'));
    });
  });
}
