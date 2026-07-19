import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';

class PdfDailyReportBuilder {
  PdfDailyReportBuilder._();

  static Future<Uint8List> build({
    required DailyActivityReport report,
    required DateTime reportDate,
    required pw.Font arabicFont,
    required pw.Font arabicFontBold,
    BusinessIdentity businessIdentity = BusinessIdentity.empty,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          final style = pw.TextStyle(font: arabicFont, fontSize: 10);
          final boldStyle = pw.TextStyle(font: arabicFontBold, fontSize: 10);
          final headerStyle = pw.TextStyle(font: arabicFontBold, fontSize: 18);

          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Column(
                      children: [
                        if (logoBytes != null && logoBytes.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 8),
                            child: pw.Image(
                              pw.MemoryImage(logoBytes),
                              height: 50,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        pw.Text(
                          businessIdentity.displayName,
                          style: pw.TextStyle(
                            font: arabicFontBold,
                            fontSize: 13,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '\u0627\u0644\u062a\u0642\u0631\u064a\u0631 \u0627\u0644\u064a\u0648\u0645\u064a',
                          style: headerStyle,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '\u0627\u0644\u062a\u0627\u0631\u064a\u062e: ${_formatDate(reportDate)}',
                    style: boldStyle,
                  ),
                  pw.SizedBox(height: 16),
                  _buildSection(
                    '\u0642\u0633\u0645 \u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a',
                    [
                      _metricLine(
                          '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a',
                          MoneyUtils.formatPiastersAsEgp(
                              report.totalSalesAmountQirsh),
                          style,
                          boldStyle),
                      _metricLine(
                          '\u0645\u0628\u064a\u0639\u0627\u062a \u0646\u0642\u062f\u064a\u0629',
                          MoneyUtils.formatPiastersAsEgp(
                              report.cashSalesAmountQirsh),
                          style,
                          boldStyle),
                      _metricLine(
                          '\u0645\u0628\u064a\u0639\u0627\u062a \u0622\u062c\u0644\u0629',
                          MoneyUtils.formatPiastersAsEgp(
                              report.totalCreditSalesAmountQirsh),
                          style,
                          boldStyle),
                      _metricLine(
                          '\u0627\u0644\u0643\u0645\u064a\u0629 \u0627\u0644\u0645\u0628\u0627\u0639\u0629',
                          '${report.totalSoldKg} \u0643\u062c\u0645',
                          style,
                          boldStyle),
                      _metricLine(
                          '\u0639\u062f\u062f \u0641\u0648\u0627\u062a\u064a\u0631 \u0627\u0644\u0628\u064a\u0639',
                          '${report.saleCount}',
                          style,
                          boldStyle),
                    ],
                    arabicFontBold,
                  ),
                  pw.SizedBox(height: 8),
                  _buildSection(
                    '\u0642\u0633\u0645 \u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a',
                    [
                      _metricLine(
                          '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a',
                          MoneyUtils.formatPiastersAsEgp(
                              report.totalPurchaseAmountQirsh),
                          style,
                          boldStyle),
                      _metricLine(
                          '\u0627\u0644\u0643\u0645\u064a\u0629 \u0627\u0644\u0645\u0634\u062a\u0631\u0627\u0629',
                          '${report.totalPurchasedKg} \u0643\u062c\u0645',
                          style,
                          boldStyle),
                      _metricLine(
                          '\u0639\u062f\u062f \u0641\u0648\u0627\u062a\u064a\u0631 \u0627\u0644\u0634\u0631\u0627\u0621',
                          '${report.purchaseCount}',
                          style,
                          boldStyle),
                    ],
                    arabicFontBold,
                  ),
                  pw.SizedBox(height: 8),
                  _buildSection(
                    '\u0627\u0644\u062a\u062d\u0635\u064a\u0644 \u0648\u0627\u0644\u0645\u062f\u0641\u0648\u0639\u0627\u062a',
                    [
                      _metricLine(
                          '\u062a\u062d\u0635\u064a\u0644 \u0645\u0646 \u0627\u0644\u0639\u0645\u0644\u0627\u0621',
                          MoneyUtils.formatPiastersAsEgp(
                              report.totalCollectionsAmountQirsh),
                          style,
                          boldStyle),
                      _metricLine(
                          '\u0645\u062f\u0641\u0648\u0639\u0627\u062a \u0644\u0644\u0645\u0648\u0631\u062f\u064a\u0646',
                          MoneyUtils.formatPiastersAsEgp(
                              report.totalSupplierPaymentsQirsh),
                          style,
                          boldStyle),
                    ],
                    arabicFontBold,
                  ),
                  pw.SizedBox(height: 12),
                  _buildSection(
                    '\u0627\u0644\u0645\u0644\u062e\u0635',
                    [
                      _metricLine(
                          '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a',
                          MoneyUtils.formatPiastersAsEgp(
                              report.totalSalesAmountQirsh),
                          style,
                          boldStyle),
                      if (report.totalExpenseAmountQirsh > 0)
                        _metricLine(
                            '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0645\u0635\u0631\u0648\u0641\u0627\u062a',
                            MoneyUtils.formatPiastersAsEgp(
                                report.totalExpenseAmountQirsh),
                            style,
                            boldStyle),
                      if (report.totalOutstandingReceivablesQirsh > 0)
                        _metricLine(
                            '\u0627\u0644\u0645\u0633\u062a\u062d\u0642 \u0639\u0644\u0649 \u0627\u0644\u0639\u0645\u0644\u0627\u0621',
                            MoneyUtils.formatPiastersAsEgp(
                                report.totalOutstandingReceivablesQirsh),
                            style,
                            boldStyle),
                      if (report.totalOutstandingSupplierPayablesQirsh > 0)
                        _metricLine(
                            '\u0627\u0644\u0645\u0633\u062a\u062d\u0642 \u0644\u0644\u0645\u0648\u0631\u062f\u064a\u0646',
                            MoneyUtils.formatPiastersAsEgp(
                                report.totalOutstandingSupplierPayablesQirsh),
                            style,
                            boldStyle),
                    ],
                    arabicFontBold,
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSection(
    String title,
    List<pw.Widget> children,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  static pw.Widget _metricLine(
      String label, String value, pw.TextStyle style, pw.TextStyle boldStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: boldStyle),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
