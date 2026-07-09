import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';

class PdfSupplierStatementBuilder {
  PdfSupplierStatementBuilder._();

  static Future<Uint8List> build({
    required SupplierStatement statement,
    required String supplierName,
    required pw.Font arabicFont,
    required pw.Font arabicFontBold,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          final style = pw.TextStyle(font: arabicFont, fontSize: 10);
          final boldStyle = pw.TextStyle(font: arabicFontBold, fontSize: 10);
          final headerStyle = pw.TextStyle(font: arabicFontBold, fontSize: 18);

          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    '\u0643\u0634\u0641 \u062d\u0633\u0627\u0628 \u0645\u0648\u0631\u062f',
                    style: headerStyle,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '$supplierName \u2014 \u062c\u0645\u064a\u0639 \u0627\u0644\u062d\u0631\u0643\u0627\u062a \u0627\u0644\u0645\u062a\u0627\u062d\u0629',
                  style: boldStyle,
                ),
                pw.Text(
                  '\u0627\u0644\u062a\u0627\u0631\u064a\u062e: ${_formatDate(DateTime.now())}',
                  style: style,
                ),
                pw.SizedBox(height: 16),
                if (statement.lines.isEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        '\u0644\u0627 \u062a\u0648\u062c\u062f \u062d\u0631\u0643\u0627\u062a',
                        style: boldStyle,
                      ),
                    ),
                  )
                else
                  pw.TableHelper.fromTextArray(
                    headerStyle: boldStyle,
                    cellStyle: style,
                    border: pw.TableBorder.all(),
                    headerAlignment: pw.Alignment.center,
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.center,
                      3: pw.Alignment.center,
                      4: pw.Alignment.center,
                    },
                    headers: [
                      '\u0627\u0644\u062a\u0627\u0631\u064a\u062e',
                      '\u0627\u0644\u0628\u064a\u0627\u0646',
                      '\u0645\u062f\u064a\u0646',
                      '\u062f\u0627\u0626\u0646',
                      '\u0627\u0644\u0631\u0627\u062c\u0639',
                    ],
                    data: statement.lines.map((line) {
                      final entry = line.entry;
                      return [
                        _formatDate(entry.date),
                        entry.descriptionAr,
                        entry.debitAmountQirsh > 0
                            ? MoneyUtils.formatPiastersAsEgp(entry.debitAmountQirsh)
                            : '',
                        entry.creditAmountQirsh > 0
                            ? MoneyUtils.formatPiastersAsEgp(entry.creditAmountQirsh)
                            : '',
                        MoneyUtils.formatPiastersAsEgp(line.runningBalanceQirsh),
                      ];
                    }).toList(),
                  ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                  ),
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      '\u0627\u0644\u0631\u0635\u064a\u062f \u0627\u0644\u0646\u0647\u0627\u0626\u064a: ${MoneyUtils.formatPiastersAsEgp(statement.finalBalanceQirsh)}',
                      style: boldStyle,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
