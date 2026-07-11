import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_file_naming.dart';

class FinancialReportPdfBuilder {
  FinancialReportPdfBuilder._();

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

  static Future<File> buildAccountBalanceReport({
    required AccountBalanceReport report,
  }) async {
    await initialize();
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(font: _arabicFontBold!, fontSize: 16);
    final headerStyle = pw.TextStyle(font: _arabicFontBold!, fontSize: 10);
    final cellStyle = pw.TextStyle(font: _arabicFont!, fontSize: 9);
    final boldCell = pw.TextStyle(font: _arabicFontBold!, fontSize: 9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text('تقرير أرصددة الحسابات المالية',
                      style: titleStyle),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'من: ${_formatDate(report.fromDate)}  إلى: ${_formatDate(report.toDate)}',
                    style: boldCell,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  cellStyle: cellStyle,
                  headerStyle: headerStyle,
                  headerAlignment: pw.Alignment.center,
                  cellAlignment: pw.Alignment.center,
                  headerDirection: pw.TextDirection.rtl,
                  headers: [
                    'الحساب',
                    'الرصيد الافتتاحي',
                    'الوارد',
                    'الصادر',
                    'الحركة الصافية',
                    'الرصيد الختامي',
                    'عدد القيود',
                  ],
                  data: [
                    ...report.rows.map((row) => [
                          '${row.account.name} (${row.account.type.labelAr})',
                          MoneyUtils.formatPiastersAsEgp(
                              row.openingBalanceQirsh),
                          MoneyUtils.formatPiastersAsEgp(row.totalInflowsQirsh),
                          MoneyUtils.formatPiastersAsEgp(
                              row.totalOutflowsQirsh),
                          MoneyUtils.formatPiastersAsEgp(row.netMovementQirsh),
                          MoneyUtils.formatPiastersAsEgp(
                              row.closingBalanceQirsh),
                          '${row.entryCount}',
                        ]),
                    [
                      'الإجمالي',
                      MoneyUtils.formatPiastersAsEgp(report.totalOpeningQirsh),
                      MoneyUtils.formatPiastersAsEgp(report.totalInflowsQirsh),
                      MoneyUtils.formatPiastersAsEgp(report.totalOutflowsQirsh),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalNetMovementQirsh),
                      MoneyUtils.formatPiastersAsEgp(report.totalClosingQirsh),
                      '',
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.centerRight,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerLeft,
                    6: pw.Alignment.center,
                  },
                  headerAlignments: {
                    0: pw.Alignment.centerRight,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerLeft,
                    6: pw.Alignment.center,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(1.8),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(1.8),
                    4: const pw.FlexColumnWidth(1.8),
                    5: const pw.FlexColumnWidth(1.8),
                    6: const pw.FlexColumnWidth(1),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final filename = PdfFileNaming.accountBalanceReport(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> buildAccountStatementReport({
    required AccountStatementReport report,
  }) async {
    await initialize();
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(font: _arabicFontBold!, fontSize: 16);
    final headerStyle = pw.TextStyle(font: _arabicFontBold!, fontSize: 10);
    final cellStyle = pw.TextStyle(font: _arabicFont!, fontSize: 9);
    final boldCell = pw.TextStyle(font: _arabicFontBold!, fontSize: 9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text('كشف حساب مالي', style: titleStyle),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'الحساب: ${report.account.name} (${report.account.type.labelAr})',
                    style: boldCell,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'من: ${_formatDate(report.fromDate)}  إلى: ${_formatDate(report.toDate)}',
                    style: boldCell,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(text: 'الرصيد الافتتاحي: ', style: boldCell),
                      pw.TextSpan(
                        text: MoneyUtils.formatPiastersAsEgp(
                            report.openingBalanceQirsh),
                        style: cellStyle,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  cellStyle: cellStyle,
                  headerStyle: headerStyle,
                  headerAlignment: pw.Alignment.center,
                  cellAlignment: pw.Alignment.center,
                  headerDirection: pw.TextDirection.rtl,
                  headers: [
                    'التاريخ',
                    'المصدر',
                    'النوع',
                    'المبلغ',
                    'المرجع',
                    'الرصيد الجاري',
                  ],
                  data: [
                    ...report.lines.map((line) => [
                          _formatDate(line.entry.effectiveDate),
                          line.entry.sourceType.labelAr,
                          line.entry.direction.labelAr,
                          MoneyUtils.formatPiastersAsEgp(
                              line.entry.amountQirsh),
                          line.entry.reference ?? '',
                          MoneyUtils.formatPiastersAsEgp(
                              line.runningBalanceQirsh),
                        ]),
                    [
                      '',
                      '',
                      'الرصيد الختامي',
                      MoneyUtils.formatPiastersAsEgp(
                          report.closingBalanceQirsh),
                      '',
                      '',
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerLeft,
                  },
                  headerAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(0.8),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(1.5),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final filename = PdfFileNaming.accountStatementReport(
      report.account.name,
      report.toDate,
    );
    final file = File('${dir.path}\\$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> buildPaymentMethodReport({
    required PaymentMethodReport report,
  }) async {
    await initialize();
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(font: _arabicFontBold!, fontSize: 16);
    final headerStyle = pw.TextStyle(font: _arabicFontBold!, fontSize: 10);
    final cellStyle = pw.TextStyle(font: _arabicFont!, fontSize: 9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text('تقرير طرق الدفع', style: titleStyle),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'من: ${_formatDate(report.fromDate)}  إلى: ${_formatDate(report.toDate)}',
                    style: headerStyle,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  cellStyle: cellStyle,
                  headerStyle: headerStyle,
                  headerAlignment: pw.Alignment.center,
                  cellAlignment: pw.Alignment.center,
                  headerDirection: pw.TextDirection.rtl,
                  headers: [
                    'طريقة الدفع',
                    'عدد العمليات',
                    'إجمالي الوارد',
                    'إجمالي الصادر',
                    'الحركة الصافية',
                  ],
                  data: [
                    ...report.rows.map((row) => [
                          row.displayName,
                          '${row.operationCount}',
                          MoneyUtils.formatPiastersAsEgp(row.totalInflowsQirsh),
                          MoneyUtils.formatPiastersAsEgp(
                              row.totalOutflowsQirsh),
                          MoneyUtils.formatPiastersAsEgp(row.netMovementQirsh),
                        ]),
                    [
                      'الإجمالي',
                      '',
                      MoneyUtils.formatPiastersAsEgp(report.totalInflowsQirsh),
                      MoneyUtils.formatPiastersAsEgp(report.totalOutflowsQirsh),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalNetMovementQirsh),
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.centerRight,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerLeft,
                  },
                  headerAlignments: {
                    0: pw.Alignment.centerRight,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(1.8),
                    4: const pw.FlexColumnWidth(1.8),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final filename = PdfFileNaming.paymentMethodReport(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> buildTransferReport({
    required TransferReport report,
  }) async {
    await initialize();
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(font: _arabicFontBold!, fontSize: 16);
    final headerStyle = pw.TextStyle(font: _arabicFontBold!, fontSize: 10);
    final cellStyle = pw.TextStyle(font: _arabicFont!, fontSize: 9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text('تقرير التحويلات', style: titleStyle),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'من: ${_formatDate(report.fromDate)}  إلى: ${_formatDate(report.toDate)}',
                    style: headerStyle,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  cellStyle: cellStyle,
                  headerStyle: headerStyle,
                  headerAlignment: pw.Alignment.center,
                  cellAlignment: pw.Alignment.center,
                  headerDirection: pw.TextDirection.rtl,
                  headers: [
                    'رقم التحويل',
                    'التاريخ',
                    'من حساب',
                    'إلى حساب',
                    'المبلغ',
                    'المرجع',
                    'ملاحظات',
                    'حالة',
                  ],
                  data: [
                    ...report.rows.map((row) => [
                          row.displayNumber,
                          _formatDate(row.effectiveDate),
                          row.sourceAccountName,
                          row.destinationAccountName,
                          MoneyUtils.formatPiastersAsEgp(row.amountQirsh),
                          row.reference ?? '',
                          row.note ?? '',
                          _transferStatusLabel(row),
                        ]),
                    [
                      '',
                      '',
                      '',
                      'الإجمالي',
                      MoneyUtils.formatPiastersAsEgp(report.totalAmountQirsh),
                      '',
                      '',
                      '',
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerRight,
                    6: pw.Alignment.centerRight,
                    7: pw.Alignment.center,
                  },
                  headerAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerLeft,
                    5: pw.Alignment.centerRight,
                    6: pw.Alignment.centerRight,
                    7: pw.Alignment.center,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(1.8),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(1.2),
                    6: const pw.FlexColumnWidth(1.2),
                    7: const pw.FlexColumnWidth(0.8),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final filename = PdfFileNaming.transferReport(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _transferStatusLabel(TransferReportRow row) {
    if (row.isReversal) return 'معكوس';
    if (row.isReversed) return 'تم عكسه';
    return 'نشط';
  }
}
