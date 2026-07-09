import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/whatsapp_assisted_share_service.dart';
import 'package:grain_warehouse_erp_lite/core/sharing/whatsapp_message_templates.dart';
import 'package:grain_warehouse_erp_lite/features/exports/pdf_export_service.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_document_scaffold.dart';

class PrintablePurchaseInvoiceView extends StatelessWidget {
  const PrintablePurchaseInvoiceView({
    super.key,
    required this.purchase,
    required this.supplierName,
    required this.productName,
    this.supplierPhone,
  });

  final PurchaseIntake purchase;
  final String supplierName;
  final String productName;
  final String? supplierPhone;

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final canWhatsApp = supplierPhone != null && supplierPhone!.trim().isNotEmpty;

    return PrintableDocumentScaffold(
      title: '\u0641\u0627\u062a\u0648\u0631\u0629 \u0634\u0631\u0627\u0621',
      subtitle: supplierName,
      documentDate: _formatDate(purchase.createdAt),
      documentNumber: purchase.id,
      onExportPdf: () => PdfExportService.exportPurchaseInvoice(
        context,
        purchase: purchase,
        supplierName: supplierName,
        productName: productName,
      ),
      onOpenWhatsApp: canWhatsApp
          ? () => WhatsAppAssistedShareService.openWhatsApp(
                phone: supplierPhone!,
                message: WhatsAppMessageTemplates.purchaseInvoice(
                  supplierName: supplierName,
                  documentNumber: purchase.id,
                  date: _formatDate(purchase.createdAt),
                ),
                context: context,
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (purchase.isCancelled) _buildCancellationStatus(),
          const Divider(),
          _buildItemSection(),
          const Divider(),
          _buildTotalRow(),
          if (purchase.notes != null && purchase.notes!.trim().isNotEmpty)
            _buildNotes(),
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

  Widget _buildItemSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _infoRow(
            '\u0627\u0644\u0635\u0646\u0641',
            productName,
          ),
          _infoRow(
            '\u0627\u0644\u0643\u0645\u064a\u0629',
            '${purchase.quantityKg} ${purchase.entryUnit.labelAr}',
          ),
          _infoRow(
            '\u0633\u0639\u0631 \u0627\u0644\u0648\u062d\u062f\u0629',
            MoneyUtils.formatPiastersAsEgp(purchase.unitPricePiastersPerKg),
          ),
          _infoRow(
            '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a',
            MoneyUtils.formatPiastersAsEgp(purchase.totalAmountPiasters),
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
            MoneyUtils.formatPiastersAsEgp(purchase.totalAmountPiasters),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          Text(purchase.notes!),
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
          Text(value),
        ],
      ),
    );
  }
}
