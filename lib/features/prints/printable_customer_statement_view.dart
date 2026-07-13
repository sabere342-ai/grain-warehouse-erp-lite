import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/whatsapp_assisted_share_service.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/whatsapp_message_templates.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_export_service.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_document_scaffold.dart';

class PrintableCustomerStatementView extends StatelessWidget {
  const PrintableCustomerStatementView({
    super.key,
    required this.statement,
    required this.customerName,
    this.customerPhone,
  });

  final CustomerStatement statement;
  final String customerName;
  final String? customerPhone;

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  String _entryDescription(CustomerAccountEntry entry) {
    switch (entry.type) {
      case CustomerAccountEntryType.creditSale:
        return 'فاتورة بيع آجل — ${entry.descriptionAr}';
      case CustomerAccountEntryType.cashSale:
        return 'فاتورة بيع نقدي — ${entry.descriptionAr}';
      case CustomerAccountEntryType.collection:
        return 'تحصيل من العميل — ${entry.descriptionAr}';
      case CustomerAccountEntryType.openingBalance:
        return entry.descriptionAr;
      case CustomerAccountEntryType.saleCancellation:
        return '\u0625\u0644\u063a\u0627\u0621 \u0628\u064a\u0639 \u2014 ${entry.descriptionAr}';
      case CustomerAccountEntryType.collectionCancellation:
        return 'عكس تحصيل — ${entry.descriptionAr}';
    }
  }

  String _amountDisplay(CustomerAccountEntry entry) {
    if (entry.debitAmountQirsh > 0) {
      return '${MoneyUtils.formatPiastersAsEgp(entry.debitAmountQirsh)} (مدين)';
    }
    if (entry.creditAmountQirsh > 0) {
      return '${MoneyUtils.formatPiastersAsEgp(entry.creditAmountQirsh)} (دائن)';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canWhatsApp =
        customerPhone != null && customerPhone!.trim().isNotEmpty;

    return PrintableDocumentScaffold(
      title: 'كشف حساب عميل',
      subtitle: '$customerName — جميع الحركات المتاحة',
      documentDate: _formatDate(now),
      onExportPdf: () => PdfExportService.exportCustomerStatement(
        context,
        statement: statement,
        customerName: customerName,
      ),
      onOpenWhatsApp: canWhatsApp
          ? () => WhatsAppAssistedShareService.openWhatsApp(
                phone: customerPhone!,
                message: WhatsAppMessageTemplates.customerStatement(
                  customerName: customerName,
                  date: _formatDate(now),
                ),
                context: context,
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTable(),
          const Divider(),
          _buildFinalBalance(),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(4),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(3),
      },
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            _TableHeader('البيان'),
            _TableHeader('المبلغ'),
            _TableHeader('الرصيد'),
          ],
        ),
        ...statement.lines.map(
          (line) => TableRow(
            children: [
              _TableCell(_entryDescription(line.entry)),
              _TableCell(_amountDisplay(line.entry)),
              _TableCell(
                MoneyUtils.formatPiastersAsEgp(line.runningBalanceQirsh),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinalBalance() {
    final isZero = statement.finalBalanceQirsh == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'الرصيد النهائي:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            isZero
                ? '0 ج.م — لا يوجد رصيد'
                : MoneyUtils.formatPiastersAsEgp(
                    statement.finalBalanceQirsh,
                  ),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isZero ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
