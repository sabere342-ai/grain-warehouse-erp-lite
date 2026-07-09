import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_document_scaffold.dart';

class PrintableSupplierStatementView extends StatelessWidget {
  const PrintableSupplierStatementView({
    super.key,
    required this.statement,
    required this.supplierName,
  });

  final SupplierStatement statement;
  final String supplierName;

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  String _entryDescription(SupplierAccountEntry entry) {
    if (entry.descriptionAr.trim().isNotEmpty) {
      return '${entry.type.labelAr} — ${entry.descriptionAr}';
    }
    return entry.type.labelAr;
  }

  String _amountDisplay(SupplierAccountEntry entry) {
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
    return PrintableDocumentScaffold(
      title: 'كشف حساب مورد',
      subtitle: supplierName,
      documentDate: _formatDate(DateTime.now()),
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
