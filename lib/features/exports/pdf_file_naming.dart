class PdfFileNaming {
  PdfFileNaming._();

  static final RegExp _forbidden = RegExp(r'[\\/:*?"<>|]');

  static String _sanitize(String name) {
    return name.replaceAll(_forbidden, '_');
  }

  static String _datePart(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String salesInvoice(String saleId, DateTime date) {
    final safeId = saleId.replaceAll(_forbidden, '-');
    return _sanitize('\u0641\u0627\u062a\u0648\u0631\u0629-\u0628\u064a\u0639-$safeId-${_datePart(date)}.pdf');
  }

  static String customerStatement(String customerName, DateTime date) {
    final safeName = customerName.replaceAll(_forbidden, '-');
    return _sanitize('\u0643\u0634\u0641-\u062d\u0633\u0627\u0628-\u0639\u0645\u064a\u0644-$safeName-${_datePart(date)}.pdf');
  }

  static String dailyReport(DateTime date) {
    return _sanitize('\u062a\u0642\u0631\u064a\u0631-\u064a\u0648\u0645\u064a-${_datePart(date)}.pdf');
  }

  static String purchaseInvoice(String purchaseId, DateTime date) {
    final safeId = purchaseId.replaceAll(_forbidden, '-');
    return _sanitize('\u0641\u0627\u062a\u0648\u0631\u0629-\u0634\u0631\u0627\u0621-$safeId-${_datePart(date)}.pdf');
  }

  static String supplierStatement(String supplierName, DateTime date) {
    final safeName = supplierName.replaceAll(_forbidden, '-');
    return _sanitize('\u0643\u0634\u0641-\u062d\u0633\u0627\u0628-\u0645\u0648\u0631\u062f-$safeName-${_datePart(date)}.pdf');
  }
}
