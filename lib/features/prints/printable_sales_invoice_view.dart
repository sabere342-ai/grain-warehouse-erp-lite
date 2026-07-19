import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/whatsapp_assisted_share_service.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/whatsapp_message_templates.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_export_service.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_document_scaffold.dart';

class PrintableSalesInvoiceView extends StatelessWidget {
  const PrintableSalesInvoiceView({
    super.key,
    required this.sale,
    required this.customerName,
    required this.productNames,
    this.customerPhone,
  });

  final SaleRecord sale;
  final String customerName;
  final Map<String, String> productNames;
  final String? customerPhone;

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  String _paymentStatusLabel() {
    switch (sale.paymentMode) {
      case SalePaymentMode.cash:
        return '\u0646\u0642\u062f\u064a';
      case SalePaymentMode.credit:
        return '\u0622\u062c\u0644';
      case SalePaymentMode.partial:
        return '\u0645\u062f\u0641\u0648\u0639 \u062c\u0632\u0626\u064a\u064b\u0627';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = sale.items;
    final hasItems = items.isNotEmpty;

    final canWhatsApp =
        customerPhone != null && customerPhone!.trim().isNotEmpty;

    return PrintableDocumentScaffold(
      title: '\u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639',
      subtitle: customerName,
      documentDate: _formatDate(sale.createdAt),
      documentNumber: sale.id,
      onExportPdf: () => PdfExportService.exportSalesInvoice(
        context,
        sale: sale,
        customerName: customerName,
        productNames: productNames,
      ),
      onOpenWhatsApp: canWhatsApp
          ? () => WhatsAppAssistedShareService.openWhatsApp(
                phone: customerPhone!,
                message: WhatsAppMessageTemplates.salesInvoice(
                  customerName: customerName,
                  documentNumber: sale.id,
                  date: _formatDate(sale.createdAt),
                ),
                context: context,
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPaymentStatus(),
          if (sale.isCancelled) _buildCancellationStatus(),
          const Divider(),
          if (hasItems) _buildItemTable(),
          if (!hasItems) _buildSingleItem(),
          const Divider(),
          _buildTotalRow(),
          if (sale.isPartialPayment) _buildPartialPaymentInfo(),
          if (sale.notes != null && sale.notes!.trim().isNotEmpty)
            _buildNotes(),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          const Text(
            '\u062d\u0627\u0644\u0629 \u0627\u0644\u062f\u0641\u0639: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(_paymentStatusLabel()),
          const SizedBox(width: 16),
          const Text(
            'طريقة السداد: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(sale.paymentMethod?.labelAr ?? 'غير محددة'),
        ],
      ),
    );
  }

  Widget _buildCancellationStatus() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        '\u0645\u0644\u063a\u0627\u0629 \u2014 \u062a\u0645 \u0639\u0643\u0633 \u0627\u0644\u0623\u0631\u0635\u062f\u0629',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildItemTable() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
      },
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            _TableHeader('\u0627\u0644\u0635\u0646\u0641'),
            _TableHeader('\u0627\u0644\u0643\u0645\u064a\u0629'),
            _TableHeader(
                '\u0633\u0639\u0631 \u0627\u0644\u0648\u062d\u062f\u0629'),
            _TableHeader('\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a'),
          ],
        ),
        ...sale.items.map(
          (item) => TableRow(
            children: [
              _TableCell(productNames[item.productId] ??
                  '\u0645\u0646\u062a\u062c \u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641'),
              _TableCell('${item.quantityKg} \u0643\u062c\u0645'),
              _TableCell(
                MoneyUtils.formatPiastersAsEgp(item.salePriceQirshPerKg),
              ),
              _TableCell(
                MoneyUtils.formatPiastersAsEgp(item.lineTotalQirsh),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _infoRow(
            '\u0627\u0644\u0635\u0646\u0641',
            productNames[sale.productId] ??
                '\u0645\u0646\u062a\u062c \u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641',
          ),
          _infoRow('\u0627\u0644\u0643\u0645\u064a\u0629',
              '${sale.quantityKg} \u0643\u062c\u0645'),
          _infoRow(
            '\u0633\u0639\u0631 \u0627\u0644\u0648\u062d\u062f\u0629',
            MoneyUtils.formatPiastersAsEgp(sale.salePriceQirshPerKg),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            MoneyUtils.formatPiastersAsEgp(sale.totalQirsh),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPartialPaymentInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('\u0627\u0644\u0645\u062f\u0641\u0648\u0639:'),
              Text(
                MoneyUtils.formatPiastersAsEgp(sale.effectivePaidAmountQirsh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('\u0627\u0644\u0645\u062a\u0628\u0642\u064a:'),
              Text(
                MoneyUtils.formatPiastersAsEgp(sale.remainingAmountQirsh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\u0645\u0644\u0627\u062d\u0638\u0627\u062a:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(sale.notes!),
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
