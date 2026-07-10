import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
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

class PdfExportService {
  PdfExportService._();

  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    final regular = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    _arabicFont = pw.Font.ttf(regular.buffer.asByteData());
    _arabicFontBold = pw.Font.ttf(bold.buffer.asByteData());
    _initialized = true;
  }

  static Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}\\Exports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<bool> exportSalesInvoice(
    BuildContext context, {
    required SaleRecord sale,
    required String customerName,
    required Map<String, String> productNames,
  }) async {
    try {
      await initialize();
      final bytes = await PdfSalesInvoiceBuilder.build(
        sale: sale,
        customerName: customerName,
        productNames: productNames,
        arabicFont: _arabicFont!,
        arabicFontBold: _arabicFontBold!,
        businessIdentity:
            await AppRepositories.businessIdentityRepository.loadIdentity(),
      );
      final filename = PdfFileNaming.salesInvoice(sale.id, sale.createdAt);
      if (!context.mounted) return false;
      return _saveAndNotify(context, bytes, filename);
    } catch (e) {
      if (!context.mounted) return false;
      _showError(context);
      return false;
    }
  }

  static Future<bool> exportCustomerStatement(
    BuildContext context, {
    required CustomerStatement statement,
    required String customerName,
  }) async {
    try {
      await initialize();
      final bytes = await PdfCustomerStatementBuilder.build(
        statement: statement,
        customerName: customerName,
        arabicFont: _arabicFont!,
        arabicFontBold: _arabicFontBold!,
      );
      final filename =
          PdfFileNaming.customerStatement(customerName, DateTime.now());
      if (!context.mounted) return false;
      return _saveAndNotify(context, bytes, filename);
    } catch (e) {
      if (!context.mounted) return false;
      _showError(context);
      return false;
    }
  }

  static Future<bool> exportDailyReport(
    BuildContext context, {
    required DailyActivityReport report,
    required DateTime reportDate,
  }) async {
    try {
      await initialize();
      final bytes = await PdfDailyReportBuilder.build(
        report: report,
        reportDate: reportDate,
        arabicFont: _arabicFont!,
        arabicFontBold: _arabicFontBold!,
      );
      final filename = PdfFileNaming.dailyReport(reportDate);
      if (!context.mounted) return false;
      return _saveAndNotify(context, bytes, filename);
    } catch (e) {
      if (!context.mounted) return false;
      _showError(context);
      return false;
    }
  }

  static Future<bool> exportPurchaseInvoice(
    BuildContext context, {
    required PurchaseIntake purchase,
    required String supplierName,
    required String productName,
  }) async {
    try {
      await initialize();
      final bytes = await PdfPurchaseInvoiceBuilder.build(
        purchase: purchase,
        supplierName: supplierName,
        productName: productName,
        arabicFont: _arabicFont!,
        arabicFontBold: _arabicFontBold!,
        businessIdentity:
            await AppRepositories.businessIdentityRepository.loadIdentity(),
      );
      final filename =
          PdfFileNaming.purchaseInvoice(purchase.id, purchase.createdAt);
      if (!context.mounted) return false;
      return _saveAndNotify(context, bytes, filename);
    } catch (e) {
      if (!context.mounted) return false;
      _showError(context);
      return false;
    }
  }

  static Future<bool> exportSupplierStatement(
    BuildContext context, {
    required SupplierStatement statement,
    required String supplierName,
  }) async {
    try {
      await initialize();
      final bytes = await PdfSupplierStatementBuilder.build(
        statement: statement,
        supplierName: supplierName,
        arabicFont: _arabicFont!,
        arabicFontBold: _arabicFontBold!,
      );
      final filename =
          PdfFileNaming.supplierStatement(supplierName, DateTime.now());
      if (!context.mounted) return false;
      return _saveAndNotify(context, bytes, filename);
    } catch (e) {
      if (!context.mounted) return false;
      _showError(context);
      return false;
    }
  }

  static Future<bool> _saveAndNotify(
    BuildContext context,
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final dir = await _exportDir();
      final file = File('${dir.path}\\$filename');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
      if (context.mounted) {
        _showSuccess(context, file.path);
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        _showError(context);
      }
      return false;
    }
  }

  static void _showSuccess(BuildContext context, String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '\u062a\u0645 \u062d\u0641\u0638 \u0645\u0644\u0641 PDF \u0628\u0646\u062c\u0627\u062d.\n$path',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '\u062a\u0639\u0630\u0631 \u062d\u0641\u0638 \u0645\u0644\u0641 PDF. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649 \u0623\u0648 \u0627\u062e\u062a\u0631 \u0645\u0643\u0627\u0646\u064b\u0622 \u0622\u062e\u0631.',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }
}
