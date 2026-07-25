import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_purchase_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_sales_invoice_view.dart';

void main() {
  group('COMPETITION-05 document preview and PDF readiness', () {
    testWidgets('dark narrow invoice preview wraps metadata and preserves data',
        (tester) async {
      final controller = BusinessIdentityController(
        repository: _MemoryBusinessIdentityRepository(
          const BusinessIdentity(
            establishmentName:
                'منشأة غلال الوادي للتجارة والتوريدات الزراعية والحبوب',
          ),
        ),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final sale = SaleRecord(
        id: 'SALE-2026-VERY-LONG-DOCUMENT-NUMBER-000001',
        productId: 'p1',
        quantityKg: 1250,
        salePriceQirshPerKg: 987,
        totalQirsh: 1233750,
        createdByUserId: 'owner',
        createdAt: DateTime(2026, 7, 19, 10, 30),
        stockMovementId: 'sm-1',
        customerId: 'c1',
        paymentMethod: PaymentMethod.bankTransfer,
        notes:
            'ملاحظة محفوظة في المستند ولا يعاد احتسابها عند المعاينة أو التصدير.',
      );

      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BusinessIdentityScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.fromPreset(AppThemePreset.highContrast),
            themeMode: ThemeMode.dark,
            home: Scaffold(
              body: PrintableSalesInvoiceView(
                sale: sale,
                customerName: 'عميل باسم طويل لا ينبغي أن يخفي بيانات الفاتورة',
                productNames: const {
                  'p1':
                      'صنف حبوب باسم طويل لا ينبغي أن يسبب تجاوزاً في المعاينة',
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(controller.identity.displayName), findsOneWidget);
      expect(find.text('تحويل بنكي'), findsOneWidget);
      expect(find.textContaining('ملاحظة محفوظة'), findsOneWidget);
      expect(find.text('رجوع'), findsOneWidget);
      expect(find.text('تصدير PDF'), findsOneWidget);
    });

    testWidgets('purchase preview keeps a null payment method neutral',
        (tester) async {
      final purchase = PurchaseIntake(
        id: 'PURCHASE-05',
        supplierId: 's1',
        productId: 'p1',
        quantityKg: 1000,
        entryUnit: GrainUnit.ton,
        unitPricePiastersPerKg: 900,
        totalAmountPiasters: 900000,
        createdByUserId: 'owner',
        createdAt: DateTime(2026, 7, 19),
        stockMovementId: 'sm-2',
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

      expect(find.text('غير محددة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('all five existing printable PDFs use the shared identity contract',
        () {
      final builders = [
        'lib/features/exports/pdf_sales_invoice_builder.dart',
        'lib/features/exports/pdf_purchase_invoice_builder.dart',
        'lib/features/exports/pdf_customer_statement_builder.dart',
        'lib/features/exports/pdf_supplier_statement_builder.dart',
        'lib/features/exports/pdf_daily_report_builder.dart',
      ];

      for (final path in builders) {
        final source = File(path).readAsStringSync();
        expect(source, contains('BusinessIdentity'));
        expect(source, contains('pdf_branding_header.dart'));
      }
    });

    test(
        'export save path avoids silent overwrites and preview stays read-only',
        () {
      final source = File('lib/features/exports/pdf_export_service.dart')
          .readAsStringSync();
      final scaffold =
          File('lib/features/prints/printable_document_scaffold.dart')
              .readAsStringSync();

      expect(source, contains('while (await candidate.exists())'));
      expect(source, contains('await file.writeAsBytes(bytes)'));
      expect(source.indexOf('await file.writeAsBytes(bytes)'),
          greaterThan(source.indexOf('await _availableFile(dir, filename)')));
      expect(scaffold, isNot(contains('saveIdentity(')));
      expect(scaffold, isNot(contains('saveLogo(')));
      expect(scaffold, isNot(contains('deleteLogoFile(')));
    });
  });
}

class _MemoryBusinessIdentityRepository implements BusinessIdentityRepository {
  _MemoryBusinessIdentityRepository(this._identity);

  BusinessIdentity _identity;

  @override
  String get managedLogosDirectory => '';

  @override
  Future<void> deleteLogoFile(String managedFileName) async {}

  @override
  Future<BusinessIdentity> loadIdentity() async => _identity;

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async => null;

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    _identity = identity;
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async =>
      null;
}
