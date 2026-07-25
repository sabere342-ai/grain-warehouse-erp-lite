import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';

class PdfBrandingHeader {
  PdfBrandingHeader._();

  static List<pw.Widget> build({
    required BusinessIdentity businessIdentity,
    required pw.Font arabicFont,
    required pw.Font arabicFontBold,
    Uint8List? logoBytes,
    bool includeProfileDetails = false,
  }) {
    final details = <pw.Widget>[];
    if (includeProfileDetails) {
      final address = businessIdentity.trimmedAddress;
      final phone = businessIdentity.trimmedPhone;
      final taxNumber = businessIdentity.trimmedTaxNumber;
      if (address != null || phone != null || taxNumber != null) {
        details.add(pw.SizedBox(height: 2));
        if (address != null) {
          details.add(pw.Text(
            address,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: arabicFont, fontSize: 9),
          ));
        }
        final contactLine = <String>[];
        if (phone != null) contactLine.add('هاتف: $phone');
        if (taxNumber != null) contactLine.add('الرقم الضريبي: $taxNumber');
        if (contactLine.isNotEmpty) {
          details.add(pw.Text(
            contactLine.join(' — '),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: arabicFont, fontSize: 9),
          ));
        }
      }
    }
    return [
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
              style: pw.TextStyle(font: arabicFontBold, fontSize: 13),
            ),
            ...details,
            pw.SizedBox(height: 4),
          ],
        ),
      ),
    ];
  }
}
