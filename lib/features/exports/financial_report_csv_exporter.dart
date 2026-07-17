import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_file_naming.dart';

class FinancialReportCsvExporter {
  FinancialReportCsvExporter._();

  static Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}\\Exports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _bomCsv(List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    for (final row in rows) {
      buffer.write(row.map((cell) => _escapeCsvCell(cell)).join(','));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  static String _escapeCsvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _money(int piasters) {
    return MoneyUtils.formatPiastersAsEgpNumber(piasters);
  }

  static Future<File> exportAccountBalanceReport({
    required AccountBalanceReport report,
  }) async {
    final rows = <List<String>>[];
    rows.add([
      'الحساب',
      'الرصيد الافتتاحي',
      'الوارد',
      'الصادر',
      'الحركة الصافية',
      'الرصيد الختامي',
      'عدد القيود',
    ]);
    for (final row in report.rows) {
      rows.add([
        '${row.account.name} (${row.account.type.labelAr})',
        _money(row.openingBalanceQirsh),
        _money(row.totalInflowsQirsh),
        _money(row.totalOutflowsQirsh),
        _money(row.netMovementQirsh),
        _money(row.closingBalanceQirsh),
        '${row.entryCount}',
      ]);
    }
    rows.add([
      'الإجمالي',
      _money(report.totalOpeningQirsh),
      _money(report.totalInflowsQirsh),
      _money(report.totalOutflowsQirsh),
      _money(report.totalNetMovementQirsh),
      _money(report.totalClosingQirsh),
      '',
    ]);

    final csv = _bomCsv(rows);
    final dir = await _exportDir();
    final filename = PdfFileNaming.accountBalanceReportCsv(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsString(csv, encoding: utf8);
    return file;
  }

  static Future<File> exportAccountStatementReport({
    required AccountStatementReport report,
  }) async {
    final rows = <List<String>>[];
    rows.add([
      'التاريخ',
      'المصدر',
      'النوع',
      'المبلغ',
      'المرجع',
      'الرصيد الجاري',
    ]);
    for (final line in report.lines) {
      rows.add([
        _formatDate(line.entry.effectiveDate),
        line.entry.sourceType.labelAr,
        line.entry.direction.labelAr,
        _money(line.entry.amountQirsh),
        line.entry.reference ?? '',
        _money(line.runningBalanceQirsh),
      ]);
    }
    rows.add([
      '',
      '',
      'الرصيد الختامي',
      _money(report.closingBalanceQirsh),
      '',
      '',
    ]);

    final csv = _bomCsv(rows);
    final dir = await _exportDir();
    final filename = PdfFileNaming.accountStatementReportCsv(
      report.account.name,
      report.toDate,
    );
    final file = File('${dir.path}\\$filename');
    await file.writeAsString(csv, encoding: utf8);
    return file;
  }

  static Future<File> exportPaymentMethodReport({
    required PaymentMethodReport report,
  }) async {
    final rows = <List<String>>[];
    rows.add([
      'طريقة الدفع',
      'عدد العمليات',
      'إجمالي الوارد',
      'إجمالي الصادر',
      'الحركة الصافية',
    ]);
    for (final row in report.rows) {
      rows.add([
        row.displayName,
        '${row.operationCount}',
        _money(row.totalInflowsQirsh),
        _money(row.totalOutflowsQirsh),
        _money(row.netMovementQirsh),
      ]);
    }
    rows.add([
      'الإجمالي',
      '',
      _money(report.totalInflowsQirsh),
      _money(report.totalOutflowsQirsh),
      _money(report.totalNetMovementQirsh),
    ]);

    final csv = _bomCsv(rows);
    final dir = await _exportDir();
    final filename = PdfFileNaming.paymentMethodReportCsv(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsString(csv, encoding: utf8);
    return file;
  }

  static Future<File> exportTransferReport({
    required TransferReport report,
  }) async {
    final rows = <List<String>>[];
    rows.add([
      'رقم التحويل',
      'التاريخ',
      'من حساب',
      'إلى حساب',
      'المبلغ',
      'المرجع',
      'ملاحظات',
      'حالة',
    ]);
    for (final row in report.rows) {
      rows.add([
        row.displayNumber,
        _formatDate(row.effectiveDate),
        row.sourceAccountName,
        row.destinationAccountName,
        _money(row.amountQirsh),
        row.reference ?? '',
        row.note ?? '',
        _transferStatusLabel(row),
      ]);
    }
    rows.add([
      '',
      '',
      '',
      'الإجمالي',
      _money(report.totalAmountQirsh),
      '',
      '',
      '',
    ]);

    final csv = _bomCsv(rows);
    final dir = await _exportDir();
    final filename = PdfFileNaming.transferReportCsv(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsString(csv, encoding: utf8);
    return file;
  }

  static String _transferStatusLabel(TransferReportRow row) {
    if (row.isReversal) return 'معكوس';
    if (row.isReversed) return 'تم عكسه';
    return 'نشط';
  }

  static Future<File> exportInflowsReport({
    required FlowReport report,
  }) async {
    return _exportFlowReport(
      report: report,
      fileName: PdfFileNaming.inflowsReportCsv(report.toDate),
    );
  }

  static Future<File> exportOutflowsReport({
    required FlowReport report,
  }) async {
    return _exportFlowReport(
      report: report,
      fileName: PdfFileNaming.outflowsReportCsv(report.toDate),
    );
  }

  static Future<File> _exportFlowReport({
    required FlowReport report,
    required String fileName,
  }) async {
    final rows = <List<String>>[];
    rows.add([
      'التاريخ',
      'الحساب',
      'المصدر',
      'المبلغ',
      'مرجع',
      'ملاحظات',
    ]);
    for (final e in report.entries) {
      rows.add([
        _formatDate(e.timestamp),
        e.accountName,
        e.source.labelAr,
        _money(e.amountQirsh),
        e.referenceId ?? '',
        e.description ?? '',
      ]);
    }
    rows.add([
      '',
      '',
      'الإجمالي',
      _money(report.totalQirsh),
      '',
      '',
    ]);

    final csv = _bomCsv(rows);
    final dir = await _exportDir();
    final file = File('${dir.path}\\$fileName');
    await file.writeAsString(csv, encoding: utf8);
    return file;
  }
}
