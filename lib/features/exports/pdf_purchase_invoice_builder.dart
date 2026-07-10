import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';

class PdfPurchaseInvoiceBuilder {
  PdfPurchaseInvoiceBuilder._();

  static Future<Uint8List> build({
    required PurchaseIntake purchase,
    required String supplierName,
    required String productName,
    required pw.Font arabicFont,
    required pw.Font arabicFontBold,
    BusinessIdentity businessIdentity = BusinessIdentity.empty,
    Uint8List? logoBytes,
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
                        '\u0641\u0627\u062a\u0648\u0631\u0629 \u0634\u0631\u0627\u0621',
                        style: headerStyle,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '\u0627\u0644\u0631\u0642\u0645: ${purchase.id}',
                      style: boldStyle,
                    ),
                    pw.Text(
                      '\u0627\u0644\u062a\u0627\u0631\u064a\u062e: ${_formatDate(purchase.createdAt)}',
                      style: style,
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '\u0627\u0644\u0645\u0648\u0631\u062f: $supplierName',
                  style: boldStyle,
                ),
                if (purchase.isCancelled) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.red),
                    ),
                    child: pw.Text(
                      '\u0645\u0644\u063a\u064a\u0629 \u2014 \u062a\u0645 \u0639\u0643\u0633 \u0627\u0644\u0623\u0631\u0635\u062f\u0629',
                      style: pw.TextStyle(
                        font: arabicFontBold,
                        fontSize: 10,
                        color: PdfColors.red,
                      ),
                    ),
                  ),
                ],
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headerStyle: boldStyle,
                  cellStyle: style,
                  border: pw.TableBorder.all(),
                  headerAlignment: pw.Alignment.center,
                  cellAlignments: {
                    0: pw.Alignment.centerRight,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                  },
                  headers: [
                    '\u0627\u0644\u0635\u0646\u0641',
                    '\u0627\u0644\u0643\u0645\u064a\u0629',
                    '\u0633\u0639\u0631 \u0627\u0644\u0643\u064a\u0644\u0648',
                    '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a',
                  ],
                  data: [
                    [
                      productName,
                      '${purchase.quantityKg} ${purchase.entryUnit.labelAr}',
                      MoneyUtils.formatPiastersAsEgp(purchase.unitPricePiastersPerKg),
                      MoneyUtils.formatPiastersAsEgp(purchase.totalAmountPiasters),
                    ],
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                  ),
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a: ${MoneyUtils.formatPiastersAsEgp(purchase.totalAmountPiasters)}',
                      style: boldStyle,
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Center(
                  child: pw.Text(
                    '\u0634\u0643\u0631\u064b\u0627 \u0644\u062a\u0639\u0627\u0648\u0646\u0643\u0645',
                    style: style,
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
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
