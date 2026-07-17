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
    return _sanitize(
        '\u0641\u0627\u062a\u0648\u0631\u0629-\u0628\u064a\u0639-$safeId-${_datePart(date)}.pdf');
  }

  static String customerStatement(String customerName, DateTime date) {
    final safeName = customerName.replaceAll(_forbidden, '-');
    return _sanitize(
        '\u0643\u0634\u0641-\u062d\u0633\u0627\u0628-\u0639\u0645\u064a\u0644-$safeName-${_datePart(date)}.pdf');
  }

  static String dailyReport(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u064a\u0648\u0645\u064a-${_datePart(date)}.pdf');
  }

  static String purchaseInvoice(String purchaseId, DateTime date) {
    final safeId = purchaseId.replaceAll(_forbidden, '-');
    return _sanitize(
        '\u0641\u0627\u062a\u0648\u0631\u0629-\u0634\u0631\u0627\u0621-$safeId-${_datePart(date)}.pdf');
  }

  static String supplierStatement(String supplierName, DateTime date) {
    final safeName = supplierName.replaceAll(_forbidden, '-');
    return _sanitize(
        '\u0643\u0634\u0641-\u062d\u0633\u0627\u0628-\u0645\u0648\u0631\u062f-$safeName-${_datePart(date)}.pdf');
  }

  static String accountBalanceReport(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0623\u0631\u0635\u062f\u0629-${_datePart(date)}.pdf');
  }

  static String accountStatementReport(String accountName, DateTime date) {
    final safeName = accountName.replaceAll(_forbidden, '-');
    return _sanitize(
        '\u0643\u0634\u0641-\u062d\u0633\u0627\u0628-\u0645\u0627\u0644\u064a-$safeName-${_datePart(date)}.pdf');
  }

  static String paymentMethodReport(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0637\u0631\u0642-\u0627\u0644\u062f\u0641\u0639-${_datePart(date)}.pdf');
  }

  static String transferReport(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0627\u0644\u062a\u062d\u0648\u064a\u0644\u0627\u062a-${_datePart(date)}.pdf');
  }

  static String accountBalanceReportCsv(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0623\u0631\u0635\u062f\u0629-${_datePart(date)}.csv');
  }

  static String accountStatementReportCsv(String accountName, DateTime date) {
    final safeName = accountName.replaceAll(_forbidden, '-');
    return _sanitize(
        '\u0643\u0634\u0641-\u062d\u0633\u0627\u0628-\u0645\u0627\u0644\u064a-$safeName-${_datePart(date)}.csv');
  }

  static String paymentMethodReportCsv(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0637\u0631\u0642-\u0627\u0644\u062f\u0641\u0639-${_datePart(date)}.csv');
  }

  static String transferReportCsv(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0627\u0644\u062a\u062d\u0648\u064a\u0644\u0627\u062a-${_datePart(date)}.csv');
  }

  static String inflowsReport(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0627\u0644\u062a\u062f\u0641\u0642\u0627\u062a-\u0627\u0644\u062f\u0627\u062e\u0644\u0629-${_datePart(date)}.pdf');
  }

  static String inflowsReportCsv(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0627\u0644\u062a\u062f\u0641\u0642\u0627\u062a-\u0627\u0644\u062f\u0627\u062e\u0644\u0629-${_datePart(date)}.csv');
  }

  static String outflowsReport(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0627\u0644\u062a\u062f\u0641\u0642\u0627\u062a-\u0627\u0644\u062e\u0627\u0631\u062c\u0629-${_datePart(date)}.pdf');
  }

  static String outflowsReportCsv(DateTime date) {
    return _sanitize(
        '\u062a\u0642\u0631\u064a\u0631-\u0627\u0644\u062a\u062f\u0641\u0642\u0627\u062a-\u0627\u0644\u062e\u0627\u0631\u062c\u0629-${_datePart(date)}.csv');
  }

  static String customerCollectionsByAccountReport(DateTime date) {
    return _sanitize(
        '\u062a\u062d\u0635\u064a\u0644\u0627\u062a-\u0627\u0644\u0639\u0645\u0644\u0627\u0621-\u062d\u0633\u0628-\u0627\u0644\u062d\u0633\u0627\u0628-${_datePart(date)}.pdf');
  }

  static String customerCollectionsByAccountReportCsv(DateTime date) {
    return _sanitize(
        '\u062a\u062d\u0635\u064a\u0644\u0627\u062a-\u0627\u0644\u0639\u0645\u0644\u0627\u0621-\u062d\u0633\u0628-\u0627\u0644\u062d\u0633\u0627\u0628-${_datePart(date)}.csv');
  }

  static String supplierSettlementsByAccountReport(DateTime date) {
    return _sanitize(
        '\u062a\u0633\u0648\u064a\u0627\u062a-\u0627\u0644\u0645\u0648\u0631\u062f\u064a\u0646-\u062d\u0633\u0628-\u0627\u0644\u062d\u0633\u0627\u0628-${_datePart(date)}.pdf');
  }

  static String supplierSettlementsByAccountReportCsv(DateTime date) {
    return _sanitize(
        '\u062a\u0633\u0648\u064a\u0627\u062a-\u0627\u0644\u0645\u0648\u0631\u062f\u064a\u0646-\u062d\u0633\u0628-\u0627\u0644\u062d\u0633\u0627\u0628-${_datePart(date)}.csv');
  }

  static String advancesAndRefundsReport(DateTime date) {
    return _sanitize(
        '\u0627\u0644\u0633\u0644\u0641-\u0648\u0627\u0644\u0631\u062f\u0648\u062f-${_datePart(date)}.pdf');
  }

  static String advancesAndRefundsReportCsv(DateTime date) {
    return _sanitize(
        '\u0627\u0644\u0633\u0644\u0641-\u0648\u0627\u0644\u0631\u062f\u0648\u062f-${_datePart(date)}.csv');
  }

  static String expenseAnalysisReport(DateTime date) {
    return _sanitize(
        '\u062a\u062d\u0644\u064a\u0644-\u0627\u0644\u0645\u0635\u0631\u0648\u0641\u0627\u062a-${_datePart(date)}.pdf');
  }

  static String expenseAnalysisReportCsv(DateTime date) {
    return _sanitize(
        '\u062a\u062d\u0644\u064a\u0644-\u0627\u0644\u0645\u0635\u0631\u0648\u0641\u0627\u062a-${_datePart(date)}.csv');
  }
}
