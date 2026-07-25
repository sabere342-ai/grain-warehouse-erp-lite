import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_branding_header.dart';

class PdfSalesInvoiceBuilder {
  PdfSalesInvoiceBuilder._();

  static Future<Uint8List> build({
    required SaleRecord sale,
    required String customerName,
    required Map<String, String> productNames,
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
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Center(
                        child: pw.Column(
                          children: [
                            ...PdfBrandingHeader.build(
                              businessIdentity: businessIdentity,
                              arabicFont: arabicFont,
                              arabicFontBold: arabicFontBold,
                              logoBytes: logoBytes,
                              includeProfileDetails: true,
                            ),
                            pw.Text(
                              '\u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639',
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
                            '\u0627\u0644\u0631\u0642\u0645: ${sale.id}',
                            style: boldStyle,
                          ),
                          pw.Text(
                            '\u0627\u0644\u062a\u0627\u0631\u064a\u062e: ${_formatDate(sale.createdAt)}',
                            style: style,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '\u0627\u0644\u0639\u0645\u064a\u0644: $customerName',
                        style: boldStyle,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'حالة الدفع: ${sale.paymentMode.labelAr} — طريقة السداد: ${sale.paymentMethod?.labelAr ?? 'غير محددة'}',
                        style: style,
                      ),
                      if (sale.isCancelled) ...[
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.red),
                          ),
                          child: pw.Text(
                            '\u0645\u0644\u063a\u0627\u0629 \u2014 \u062a\u0645 \u0639\u0643\u0633 \u0627\u0644\u0623\u0631\u0635\u062f\u0629',
                            style: pw.TextStyle(
                              font: arabicFontBold,
                              fontSize: 10,
                              color: PdfColors.red,
                            ),
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 12),
                    ],
                  ),
                ),
                pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: _buildItemsTable(sale, productNames, style, boldStyle),
                ),
                pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(),
                        ),
                        child: pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(
                            '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a: ${MoneyUtils.formatPiastersAsEgp(sale.totalQirsh)}',
                            style: boldStyle,
                          ),
                        ),
                      ),
                      if (sale.paymentMode == SalePaymentMode.partial &&
                          sale.paidAmountQirsh != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(),
                          ),
                          child: pw.Align(
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Text(
                              '\u0627\u0644\u0645\u062f\u0641\u0648\u0639: ${MoneyUtils.formatPiastersAsEgp(sale.effectivePaidAmountQirsh)}',
                              style: style,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(),
                          ),
                          child: pw.Align(
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Text(
                              '\u0627\u0644\u0628\u0627\u0642\u064a: ${MoneyUtils.formatPiastersAsEgp(sale.remainingAmountQirsh)}',
                              style: style,
                            ),
                          ),
                        ),
                      ],
                      if (sale.notes != null &&
                          sale.notes!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 12),
                        pw.Text('ملاحظات: ${sale.notes}', style: style),
                      ],
                      pw.SizedBox(height: 24),
                      pw.Center(
                        child: pw.Text(
                          '\u0634\u0643\u0631\u064b\u0627 \u0644\u062a\u0639\u0627\u0648\u0646\u0643\u0645',
                          style: style,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildItemsTable(
    SaleRecord sale,
    Map<String, String> productNames,
    pw.TextStyle style,
    pw.TextStyle boldStyle,
  ) {
    final items = sale.isMultiItem
        ? sale.items
        : [
            SaleLineItem(
              productId: sale.productId,
              quantityKg: sale.quantityKg,
              salePriceQirshPerKg: sale.salePriceQirshPerKg,
              lineTotalQirsh: sale.totalQirsh,
            ),
          ];

    final headers = [
      '\u0627\u0644\u0635\u0646\u0641',
      '\u0627\u0644\u0643\u0645\u064a\u0629',
      '\u0633\u0639\u0631 \u0627\u0644\u0643\u064a\u0644\u0648',
      '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a',
    ];

    final rows = items.map((item) {
      return [
        productNames[item.productId] ??
            '\u0645\u0646\u062a\u062c \u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641',
        '${item.quantityKg} \u0643\u062c\u0645',
        MoneyUtils.formatPiastersAsEgp(item.salePriceQirshPerKg),
        MoneyUtils.formatPiastersAsEgp(item.lineTotalQirsh),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
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
      headers: headers,
      data: rows,
    );
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
