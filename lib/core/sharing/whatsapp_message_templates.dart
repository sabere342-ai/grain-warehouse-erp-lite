class WhatsAppMessageTemplates {
  WhatsAppMessageTemplates._();

  /// Sales invoice message for customer WhatsApp sharing.
  static String salesInvoice({
    required String customerName,
    required String documentNumber,
    required String date,
  }) {
    return '\u0645\u0631\u062D\u0628\u064B\u0627 $customerName\u060C '
        '\u0645\u0631\u0641\u0642 \u0641\u0627\u062A\u0648\u0631\u0629 \u0627\u0644\u0628\u064A\u0639 '
        '\u0631\u0642\u0645 $documentNumber \u0628\u062A\u0627\u0631\u064A\u062E $date '
        '\u0645\u0646 \u0646\u0638\u0627\u0645 \u063A\u0644\u0627\u0644. '
        '\u0628\u0631\u062C\u0627\u0621 \u0645\u0631\u0627\u062C\u0639\u0629 \u0645\u0644\u0641 PDF '
        '\u0627\u0644\u0645\u0631\u0641\u0642.';
  }

  /// Customer statement message for customer WhatsApp sharing.
  static String customerStatement({
    required String customerName,
    required String date,
  }) {
    return '\u0645\u0631\u062D\u0628\u064B\u0627 $customerName\u060C '
        '\u0645\u0631\u0641\u0642 \u0643\u0634\u0641 \u0627\u0644\u062D\u0633\u0627\u0628 '
        '\u0628\u062A\u0627\u0631\u064A\u062E $date '
        '\u0645\u0646 \u0646\u0638\u0627\u0645 \u063A\u0644\u0627\u0644. '
        '\u0628\u0631\u062C\u0627\u0621 \u0645\u0631\u0627\u062C\u0639\u0629 \u0645\u0644\u0641 PDF '
        '\u0627\u0644\u0645\u0631\u0641\u0642.';
  }

  /// Purchase invoice message for supplier WhatsApp sharing.
  static String purchaseInvoice({
    required String supplierName,
    required String documentNumber,
    required String date,
  }) {
    return '\u0645\u0631\u062D\u0628\u064B\u0627 $supplierName\u060C '
        '\u0645\u0631\u0641\u0642 \u0641\u0627\u062A\u0648\u0631\u0629 \u0627\u0644\u0634\u0631\u0627\u0621 '
        '\u0631\u0642\u0645 $documentNumber \u0628\u062A\u0627\u0631\u064A\u062E $date '
        '\u0645\u0646 \u0646\u0638\u0627\u0645 \u063A\u0644\u0627\u0644. '
        '\u0628\u0631\u062C\u0627\u0621 \u0645\u0631\u0627\u062C\u0639\u0629 \u0645\u0644\u0641 PDF '
        '\u0627\u0644\u0645\u0631\u0641\u0642.';
  }

  /// Supplier statement message for supplier WhatsApp sharing.
  static String supplierStatement({
    required String supplierName,
    required String date,
  }) {
    return '\u0645\u0631\u062D\u0628\u064B\u0627 $supplierName\u060C '
        '\u0645\u0631\u0641\u0642 \u0643\u0634\u0641 \u062D\u0633\u0627\u0628 \u0627\u0644\u0645\u0648\u0631\u062F '
        '\u0628\u062A\u0627\u0631\u064A\u062E $date '
        '\u0645\u0646 \u0646\u0638\u0627\u0645 \u063A\u0644\u0627\u0644. '
        '\u0628\u0631\u062C\u0627\u0621 \u0645\u0631\u0627\u062C\u0639\u0629 \u0645\u0644\u0641 PDF '
        '\u0627\u0644\u0645\u0631\u0641\u0642.';
  }
}
