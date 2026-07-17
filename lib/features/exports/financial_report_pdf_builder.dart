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

  static Future<File> buildInflowsReport({
    required FlowReport report,
    String? accountLabel,
  }) async {
    return _buildFlowReport(
      report: report,
      title: 'تقرير التدفقات الداخلة',
      accountLabel: accountLabel,
      fileName: PdfFileNaming.inflowsReport(report.toDate),
    );
  }

  static Future<File> buildOutflowsReport({
    required FlowReport report,
    String? accountLabel,
  }) async {
    return _buildFlowReport(
      report: report,
      title: 'تقرير التدفقات الخارجة',
      accountLabel: accountLabel,
      fileName: PdfFileNaming.outflowsReport(report.toDate),
    );
  }

  static Future<File> _buildFlowReport({
    required FlowReport report,
    required String title,
    String? accountLabel,
    required String fileName,
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
                pw.Center(child: pw.Text(title, style: titleStyle)),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'من: ${_formatDate(report.fromDate)}  إلى: ${_formatDate(report.toDate)}',
                    style: boldCell,
                  ),
                ),
                if (accountLabel != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text('الحساب: $accountLabel', style: boldCell),
                  ),
                ],
                pw.SizedBox(height: 12),
                if (report.sourceBreakdown.isNotEmpty) ...[
                  pw.Text('التصنيف حسب المصدر', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: ['المصدر', 'الإجمالي'],
                    data: [
                      ...report.sourceBreakdown.entries.map((e) => [
                            e.key.labelAr,
                            MoneyUtils.formatPiastersAsEgp(e.value),
                          ]),
                      [
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(report.totalQirsh),
                      ],
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                    },
                  ),
                  pw.SizedBox(height: 16),
                ],
                if (report.entries.isNotEmpty) ...[
                  pw.Text('الحركات', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'التاريخ',
                      'الحساب',
                      'المصدر',
                      'المبلغ',
                      'ملاحظات',
                    ],
                    data: [
                      ...report.entries.map((e) => [
                            _formatDate(e.timestamp),
                            e.accountName,
                            e.source.labelAr,
                            MoneyUtils.formatPiastersAsEgp(e.amountQirsh),
                            e.description ?? '',
                          ]),
                      [
                        '',
                        '',
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(report.totalQirsh),
                        '',
                      ],
                    ],
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerLeft,
                      4: pw.Alignment.centerRight,
                    },
                    headerAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerLeft,
                      4: pw.Alignment.centerRight,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2),
                      1: const pw.FlexColumnWidth(1.8),
                      2: const pw.FlexColumnWidth(1.8),
                      3: const pw.FlexColumnWidth(1.5),
                      4: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final file = File('${dir.path}\\$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> buildCustomerCollectionsByAccountReport({
    required CustomerCollectionsByAccountReport report,
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
                  child:
                      pw.Text('تحصيلات العملاء حسب الحساب', style: titleStyle),
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
                    'إجمالي التحصيلات',
                    'إجمالي المرتجعات',
                    'صافي التحصيلات',
                  ],
                  data: [
                    [
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalGrossCollectionsQirsh),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalReversalsQirsh),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalNetCollectionsQirsh),
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                  },
                  headerAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                  },
                ),
                if (report.accountSummaries.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('التحصيلات حسب الحساب', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'الحساب',
                      'تحصيلات',
                      'مرتجعات',
                      'صافي',
                    ],
                    data: [
                      ...report.accountSummaries.map((a) => [
                            '${a.account.name} (${a.account.type.labelAr})',
                            MoneyUtils.formatPiastersAsEgp(
                                a.grossCollectionsQirsh),
                            MoneyUtils.formatPiastersAsEgp(a.reversalsQirsh),
                            MoneyUtils.formatPiastersAsEgp(
                                a.netCollectionsQirsh),
                          ]),
                      [
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalGrossCollectionsQirsh),
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalReversalsQirsh),
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalNetCollectionsQirsh),
                      ],
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
                if (report.customerSummaries.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('التحصيلات حسب العميل', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'العميل',
                      'تحصيلات',
                      'مرتجعات',
                      'صافي',
                    ],
                    data: [
                      ...report.customerSummaries.map((c) => [
                            c.customerName,
                            MoneyUtils.formatPiastersAsEgp(
                                c.grossCollectionsQirsh),
                            MoneyUtils.formatPiastersAsEgp(c.reversalsQirsh),
                            MoneyUtils.formatPiastersAsEgp(
                                c.netCollectionsQirsh),
                          ]),
                      [
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalGrossCollectionsQirsh),
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalReversalsQirsh),
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalNetCollectionsQirsh),
                      ],
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
                if (report.details.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('التفاصيل', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'التاريخ',
                      'العميل',
                      'الحساب',
                      'النوع',
                      'المبلغ',
                    ],
                    data: [
                      ...report.details.map((d) => [
                            _formatDate(d.timestamp),
                            d.customerName,
                            d.accountName,
                            d.sourceType.labelAr,
                            MoneyUtils.formatPiastersAsEgp(d.amountQirsh),
                          ]),
                      [
                        '',
                        '',
                        '',
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalGrossCollectionsQirsh -
                                report.totalReversalsQirsh),
                      ],
                    ],
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2),
                      1: const pw.FlexColumnWidth(1.8),
                      2: const pw.FlexColumnWidth(1.8),
                      3: const pw.FlexColumnWidth(1.5),
                      4: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final filename =
        PdfFileNaming.customerCollectionsByAccountReport(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> buildSupplierSettlementsByAccountReport({
    required SupplierSettlementsByAccountReport report,
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
                  child:
                      pw.Text('تسويات الموردين حسب الحساب', style: titleStyle),
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
                    'إجمالي التسويات',
                    'إجمالي الإلغاءات',
                    'صافي التسويات',
                  ],
                  data: [
                    [
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalGrossSettlementsQirsh),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalReversalsQirsh),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalNetSettlementsQirsh),
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                  },
                  headerAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                  },
                ),
                if (report.accountSummaries.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('التسويات حسب الحساب', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'الحساب',
                      'تسويات',
                      'إلغاءات',
                      'صافي',
                    ],
                    data: [
                      ...report.accountSummaries.map((a) => [
                            '${a.account.name} (${a.account.type.labelAr})',
                            MoneyUtils.formatPiastersAsEgp(
                                a.grossSettlementsQirsh),
                            MoneyUtils.formatPiastersAsEgp(a.reversalsQirsh),
                            MoneyUtils.formatPiastersAsEgp(
                                a.netSettlementsQirsh),
                          ]),
                      [
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalGrossSettlementsQirsh),
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalReversalsQirsh),
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalNetSettlementsQirsh),
                      ],
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
                if (report.supplierSummaries.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('التسويات حسب المورد', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'المورد',
                      'تسويات',
                      'إلغاءات',
                      'صافي',
                    ],
                    data: [
                      ...report.supplierSummaries.map((s) => [
                            s.supplierName,
                            MoneyUtils.formatPiastersAsEgp(
                                s.grossSettlementsQirsh),
                            MoneyUtils.formatPiastersAsEgp(s.reversalsQirsh),
                            MoneyUtils.formatPiastersAsEgp(
                                s.netSettlementsQirsh),
                          ]),
                      [
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalGrossSettlementsQirsh),
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalReversalsQirsh),
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalNetSettlementsQirsh),
                      ],
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
                if (report.details.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('التفاصيل', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'التاريخ',
                      'المورد',
                      'الحساب',
                      'النوع',
                      'المبلغ',
                    ],
                    data: [
                      ...report.details.map((d) => [
                            _formatDate(d.timestamp),
                            d.supplierName,
                            d.accountName,
                            d.sourceType.labelAr,
                            MoneyUtils.formatPiastersAsEgp(d.amountQirsh),
                          ]),
                      [
                        '',
                        '',
                        '',
                        'الإجمالي',
                        MoneyUtils.formatPiastersAsEgp(
                            report.totalGrossSettlementsQirsh -
                                report.totalReversalsQirsh),
                      ],
                    ],
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2),
                      1: const pw.FlexColumnWidth(1.8),
                      2: const pw.FlexColumnWidth(1.8),
                      3: const pw.FlexColumnWidth(1.5),
                      4: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final filename =
        PdfFileNaming.supplierSettlementsByAccountReport(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> buildAdvancesAndRefundsReport({
    required AdvancesAndRefundsReport report,
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
                  child: pw.Text('تقرير السلف والردود', style: titleStyle),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'من: ${_formatDate(report.fromDate)}  إلى: ${_formatDate(report.toDate)}',
                    style: boldCell,
                  ),
                ),
                pw.SizedBox(height: 12),
                // Customer summary
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  cellStyle: cellStyle,
                  headerStyle: headerStyle,
                  headerAlignment: pw.Alignment.center,
                  cellAlignment: pw.Alignment.center,
                  headerDirection: pw.TextDirection.rtl,
                  headers: [
                    'إجمالي رد سلف العملاء',
                    'إلغاءات العملاء',
                    'صافي رد سلف العملاء',
                  ],
                  data: [
                    [
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalCustomerGrossRefundOutflow),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalCustomerRefundReversals),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalCustomerNetRefundOutflow),
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                  },
                  headerAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                  },
                ),
                pw.SizedBox(height: 8),
                // Supplier summary
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  cellStyle: cellStyle,
                  headerStyle: headerStyle,
                  headerAlignment: pw.Alignment.center,
                  cellAlignment: pw.Alignment.center,
                  headerDirection: pw.TextDirection.rtl,
                  headers: [
                    'إجمالي ردود سلف الموردين',
                    'إلغاءات الموردين',
                    'صافي ردود سلف الموردين',
                  ],
                  data: [
                    [
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalSupplierGrossRefundInflow),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalSupplierRefundReversals),
                      MoneyUtils.formatPiastersAsEgp(
                          report.totalSupplierNetRefundInflow),
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                  },
                  headerAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                  },
                ),
                pw.SizedBox(height: 8),
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(text: 'صافي الأثر النقدي: ', style: boldCell),
                      pw.TextSpan(
                        text: MoneyUtils.formatPiastersAsEgp(
                            report.signedGrandCashEffect),
                        style: cellStyle,
                      ),
                    ],
                  ),
                ),
                // Account summaries
                if (report.accountSummaries.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('الملخص حسب الحساب المالي', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'الحساب',
                      'رد عملاء',
                      'إلغاء عملاء',
                      'صافي عملاء',
                      'رد موردين',
                      'إلغاء موردين',
                      'صافي موردين',
                      'صافي',
                    ],
                    data: [
                      ...report.accountSummaries.map((a) => [
                            '${a.account.name} (${a.account.type.labelAr})',
                            MoneyUtils.formatPiastersAsEgp(
                                a.customerGrossRefundOutflow),
                            MoneyUtils.formatPiastersAsEgp(
                                a.customerRefundReversals),
                            MoneyUtils.formatPiastersAsEgp(
                                a.customerNetRefundOutflow),
                            MoneyUtils.formatPiastersAsEgp(
                                a.supplierGrossRefundInflow),
                            MoneyUtils.formatPiastersAsEgp(
                                a.supplierRefundReversals),
                            MoneyUtils.formatPiastersAsEgp(
                                a.supplierNetRefundInflow),
                            MoneyUtils.formatPiastersAsEgp(
                                a.signedNetCashEffect),
                          ]),
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                      4: pw.Alignment.centerLeft,
                      5: pw.Alignment.centerLeft,
                      6: pw.Alignment.centerLeft,
                      7: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                      4: pw.Alignment.centerLeft,
                      5: pw.Alignment.centerLeft,
                      6: pw.Alignment.centerLeft,
                      7: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.3),
                      2: const pw.FlexColumnWidth(1.3),
                      3: const pw.FlexColumnWidth(1.3),
                      4: const pw.FlexColumnWidth(1.3),
                      5: const pw.FlexColumnWidth(1.3),
                      6: const pw.FlexColumnWidth(1.3),
                      7: const pw.FlexColumnWidth(1.3),
                    },
                  ),
                ],
                // Customer entity summaries
                if (report.customerSummaries.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('ملخص حسب العميل', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'العميل',
                      'إجمالي',
                      'إلغاءات',
                      'صافي',
                    ],
                    data: [
                      ...report.customerSummaries.map((c) => [
                            c.entityName,
                            MoneyUtils.formatPiastersAsEgp(c.grossAmount),
                            MoneyUtils.formatPiastersAsEgp(c.reversalAmount),
                            MoneyUtils.formatPiastersAsEgp(c.netAmount),
                          ]),
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
                // Supplier entity summaries
                if (report.supplierSummaries.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('ملخص حسب المورد', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'المورد',
                      'إجمالي',
                      'إلغاءات',
                      'صافي',
                    ],
                    data: [
                      ...report.supplierSummaries.map((s) => [
                            s.entityName,
                            MoneyUtils.formatPiastersAsEgp(s.grossAmount),
                            MoneyUtils.formatPiastersAsEgp(s.reversalAmount),
                            MoneyUtils.formatPiastersAsEgp(s.netAmount),
                          ]),
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
                // Details
                if (report.details.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('التفاصيل', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'التاريخ',
                      'الطرف',
                      'الاسم',
                      'الحساب',
                      'النوع',
                      'المبلغ',
                      'الأثر النقدي',
                    ],
                    data: [
                      ...report.details.map((d) => [
                            _formatDate(d.timestamp),
                            d.partyType.labelAr,
                            d.entityName,
                            d.accountName,
                            d.sourceType.labelAr,
                            MoneyUtils.formatPiastersAsEgp(d.amountQirsh),
                            MoneyUtils.formatPiastersAsEgp(d.signedCashEffect),
                          ]),
                    ],
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.center,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.centerRight,
                      5: pw.Alignment.centerLeft,
                      6: pw.Alignment.centerLeft,
                    },
                    headerAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.center,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.centerRight,
                      5: pw.Alignment.centerLeft,
                      6: pw.Alignment.centerLeft,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2),
                      1: const pw.FlexColumnWidth(0.8),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                      4: const pw.FlexColumnWidth(1.5),
                      5: const pw.FlexColumnWidth(1.3),
                      6: const pw.FlexColumnWidth(1.3),
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final filename = PdfFileNaming.advancesAndRefundsReport(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> buildExpenseAnalysisReport({
    required ExpenseAnalysisReport report,
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
                  child: pw.Text('تقرير تحليل المصروفات', style: titleStyle),
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
                    'الإجمالي',
                    'العدد',
                  ],
                  data: [
                    [
                      MoneyUtils.formatPiastersAsEgp(report.totalQirsh),
                      '${report.grandCount}',
                    ],
                  ],
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                  },
                  headerAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                  },
                ),
                if (report.rows.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('تحليل التصنيفات', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'التصنيف',
                      'الإجمالي',
                      'العدد',
                      'النسبة',
                    ],
                    data: [
                      ...report.rows.map((r) => [
                            r.category,
                            MoneyUtils.formatPiastersAsEgp(r.totalAmountQirsh),
                            '${r.count}',
                            '${r.percentageOfTotal.toStringAsFixed(1)}%',
                          ]),
                    ],
                    cellAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.center,
                      3: pw.Alignment.center,
                    },
                    headerAlignments: {
                      0: pw.Alignment.centerRight,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.center,
                      3: pw.Alignment.center,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1),
                    },
                  ),
                ],
                if (report.allDetails.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('تفاصيل المصروفات', style: boldCell),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    context: ctx,
                    cellStyle: cellStyle,
                    headerStyle: headerStyle,
                    headerAlignment: pw.Alignment.center,
                    cellAlignment: pw.Alignment.center,
                    headerDirection: pw.TextDirection.rtl,
                    headers: [
                      'التاريخ',
                      'التصنيف',
                      'المبلغ',
                      'وسيلة الدفع',
                      'الحساب',
                      'ملاحظات',
                    ],
                    data: [
                      ...report.allDetails.map((d) => [
                            _formatDate(d.date),
                            d.category,
                            MoneyUtils.formatPiastersAsEgp(d.amountQirsh),
                            d.paymentMethodLabel,
                            d.accountName,
                            d.notes ?? '',
                          ]),
                    ],
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.center,
                      4: pw.Alignment.centerRight,
                      5: pw.Alignment.centerRight,
                    },
                    headerAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.center,
                      4: pw.Alignment.centerRight,
                      5: pw.Alignment.centerRight,
                    },
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.3),
                      3: const pw.FlexColumnWidth(1.2),
                      4: const pw.FlexColumnWidth(1.5),
                      5: const pw.FlexColumnWidth(1.5),
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportDir();
    final filename = PdfFileNaming.expenseAnalysisReport(report.toDate);
    final file = File('${dir.path}\\$filename');
    await file.writeAsBytes(bytes);
    return file;
  }
}
