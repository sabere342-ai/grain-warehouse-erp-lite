import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_sales_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, this.controller});

  final SaleController? controller;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late final SaleController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        SaleController(
          saleRepository: AppRepositories.saleRepository,
          productRepository: AppRepositories.productRepository,
          inventoryRepository: AppRepositories.inventoryRepository,
          customerRepository: AppRepositories.customerRepository,
          customerAccountRepository: AppRepositories.customerAccountRepository,
          financialAccountRepository:
              AppRepositories.financialAccountRepository,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.load(user);
      }
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const PremiumCard(
          child: Text(
              '\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0644\u0639\u0631\u0636 \u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a.'));
    }

    final canCreate = user.permissions.canCreateSale;
    final canCancel = user.permissions.canCancelInvoice;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('\u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a',
                          style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        '\u0643\u0644 \u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639 \u062a\u062a\u0637\u0644\u0628 \u0639\u0645\u064a\u0644\u0627 \u0645\u0633\u062c\u0644\u0627\u060c \u0648\u062a\u062f\u0639\u0645 \u0623\u0643\u062b\u0631 \u0645\u0646 \u0635\u0646\u0641 \u0641\u064a \u0646\u0641\u0633 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openHistory(context),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text(
                      '\u0633\u062c\u0644 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a'),
                ),
                const SizedBox(width: 8),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: _controller.products.isEmpty ||
                            _controller.customers.isEmpty
                        ? null
                        : () => _showSaleForm(context, user: user),
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: const Text(
                        '\u062a\u0633\u062c\u064a\u0644 \u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639'),
                  ),
              ],
            ),
            if (_controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _controller.errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (canCreate) ...[
                _ProductSaleCards(
                  products: _controller.products,
                  stockByProductId: _controller.stockByProductId,
                  onSelect: (product) => _showSaleForm(
                    context,
                    user: user,
                    initialProductId: product.id,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_controller.sales.isEmpty)
                const PremiumCard(
                  child: Text(
                    '\u0644\u0627 \u062a\u0648\u062c\u062f \u0641\u0648\u0627\u062a\u064a\u0631 \u0628\u064a\u0639 \u0645\u0633\u062c\u0644\u0629 \u0628\u0639\u062f. \u0633\u062a\u0638\u0647\u0631 \u0647\u0646\u0627 \u0641\u0648\u0627\u062a\u064a\u0631 \u0627\u0644\u0628\u064a\u0639 \u0628\u0639\u062f \u0627\u0644\u062d\u0641\u0638.',
                  ),
                )
              else
                ..._controller.sales.reversed.map(
                  (sale) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SaleCard(
                      sale: sale,
                      productName: _controller.productName(sale.productId),
                      customerName: _controller.customerName(sale.customerId),
                      canCancel: canCancel,
                      onCancel: sale.isCancelled
                          ? null
                          : () => _confirmCancelSale(context, user, sale),
                      onPreview: () => _showSalePreview(context, sale),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  void _showSalePreview(BuildContext context, SaleRecord sale) {
    final productNames = <String, String>{
      for (final p in _controller.products) p.id: p.name,
    };
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrintableSalesInvoiceView(
          sale: sale,
          customerName: _controller.customerName(sale.customerId),
          productNames: productNames,
        ),
      ),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DocumentHistoryScreen(),
      ),
    );
  }

  Future<void> _showSaleForm(
    BuildContext context, {
    required user,
    String? initialProductId,
  }) async {
    final result = await showDialog<_SaleFormResult>(
      context: context,
      builder: (context) => _SaleFormDialog(
        products: _controller.products,
        customers: _controller.customers,
        financialAccounts: _controller.financialAccounts,
        initialProductId: initialProductId,
      ),
    );

    if (result == null) {
      return;
    }

    await _controller.createSale(
      user: user,
      productId: result.items.first.productId,
      quantityKg: result.items.first.quantityKg,
      salePriceQirshPerKg: result.items.first.salePriceQirshPerKg,
      notes: result.notes,
      paymentMode: result.paymentMode,
      customerId: result.customerId,
      items: result.items,
      paidAmountQirsh: result.paidAmountQirsh,
      paymentAllocations: result.paymentAllocations,
      operationRequestId: result.operationRequestId,
    );
  }

  Future<void> _confirmCancelSale(
    BuildContext context,
    user,
    SaleRecord sale,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
            '\u062a\u0623\u0643\u064a\u062f \u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u0628\u064a\u0639'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '\u062a\u062d\u0630\u064a\u0631 \u0645\u0647\u0645: \u0633\u064a\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u062d\u0631\u0643\u0627\u062a \u0645\u062e\u0632\u0648\u0646 \u0639\u0643\u0633\u064a\u0629 \u0644\u0625\u0644\u063a\u0627\u0621 \u0623\u062b\u0631 \u0647\u0630\u0627 \u0627\u0644\u0628\u064a\u0639. \u0644\u0646 \u064a\u062a\u0645 \u062d\u0630\u0641 \u0645\u0633\u062a\u0646\u062f \u0627\u0644\u0628\u064a\u0639 \u0627\u0644\u0623\u0635\u0644\u064a \u0623\u0648 \u0627\u0644\u062d\u0631\u0643\u0629 \u0627\u0644\u0623\u0635\u0644\u064a\u0629\u060c \u0648\u0633\u064a\u0638\u0647\u0631 \u0627\u0644\u0625\u0644\u063a\u0627\u0621 \u0641\u064a \u0633\u062c\u0644 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0644\u0644\u0645\u0627\u0644\u0643.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                  labelText:
                      '\u0633\u0628\u0628 \u0627\u0644\u0625\u0644\u063a\u0627\u0621'),
              maxLines: 2,
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('\u0631\u062c\u0648\u0639'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            child: const Text(
                '\u062a\u0623\u0643\u064a\u062f \u0627\u0644\u0625\u0644\u063a\u0627\u0621'),
          ),
        ],
      ),
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    await _controller.cancelSale(
      user: user,
      saleId: sale.id,
      cancellationReason: reason,
    );
  }
}

class _ProductSaleCards extends StatelessWidget {
  const _ProductSaleCards({
    required this.products,
    required this.stockByProductId,
    required this.onSelect,
  });

  final List<Product> products;
  final Map<String, int> stockByProductId;
  final ValueChanged<Product> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (products.isEmpty) {
      return const PremiumCard(
        child: Text(
            '\u0623\u0636\u0641 \u0635\u0646\u0641\u0627 \u0648\u0643\u0645\u064a\u0629 \u0645\u062e\u0632\u0648\u0646 \u0642\u0628\u0644 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0628\u064a\u0639.'),
      );
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '\u0627\u062e\u062a\u0631 \u0635\u0646\u0641 \u0627\u0644\u0628\u064a\u0639',
              style: textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '\u0627\u0636\u063a\u0637 \u0639\u0644\u0649 \u0628\u0637\u0627\u0642\u0629 \u0627\u0644\u0635\u0646\u0641 \u0644\u0641\u062a\u062d \u0646\u0645\u0648\u0630\u062c \u0627\u0644\u0628\u064a\u0639 \u0648\u0625\u0636\u0627\u0641\u0629 \u0623\u0635\u0646\u0627\u0641 \u0645\u062a\u0639\u062f\u062f\u0629 \u0641\u064a \u0646\u0641\u0633 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cardWidth = width >= 920
                  ? (width - 24) / 3
                  : width >= 620
                      ? (width - 12) / 2
                      : width;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final product in products)
                    SizedBox(
                      width: cardWidth.toDouble(),
                      child: _ProductSaleCard(
                        product: product,
                        stockKg: stockByProductId[product.id] ?? 0,
                        onSelect: () => onSelect(product),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProductSaleCard extends StatelessWidget {
  const _ProductSaleCard({
    required this.product,
    required this.stockKg,
    required this.onSelect,
  });

  final Product product;
  final int stockKg;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final defaultPrice = product.defaultSalePricePiastersPerKg;
    final minimumPrice = product.minimumSalePricePiastersPerKg;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(product.name, style: textTheme.titleLarge)),
                  const Icon(Icons.touch_app_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                  '\u0627\u0644\u0645\u062e\u0632\u0648\u0646 \u0627\u0644\u062d\u0627\u0644\u064a: $stockKg \u0643\u062c\u0645'),
              const SizedBox(height: 6),
              Text(
                defaultPrice == null
                    ? '\u0633\u0639\u0631 \u0627\u0644\u0628\u064a\u0639 \u0627\u0644\u0627\u0641\u062a\u0631\u0627\u0636\u064a: \u063a\u064a\u0631 \u0645\u062d\u062f\u062f'
                    : '\u0633\u0639\u0631 \u0627\u0644\u0628\u064a\u0639 \u0627\u0644\u0627\u0641\u062a\u0631\u0627\u0636\u064a: ${MoneyUtils.formatPiastersAsEgp(defaultPrice)} / \u0643\u062c\u0645',
              ),
              const SizedBox(height: 6),
              Text(
                minimumPrice == null
                    ? '\u0627\u0644\u062d\u062f \u0627\u0644\u0623\u062f\u0646\u0649 \u0644\u0644\u0628\u064a\u0639: \u063a\u064a\u0631 \u0645\u062d\u062f\u062f'
                    : '\u0627\u0644\u062d\u062f \u0627\u0644\u0623\u062f\u0646\u0649 \u0644\u0644\u0628\u064a\u0639: ${MoneyUtils.formatPiastersAsEgp(minimumPrice)} / \u0643\u062c\u0645',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: const Text(
                      '\u0628\u064a\u0639 \u0647\u0630\u0627 \u0627\u0644\u0635\u0646\u0641'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.productName,
    required this.customerName,
    required this.canCancel,
    this.onCancel,
    this.onPreview,
  });

  final SaleRecord sale;
  final String productName;
  final String customerName;
  final bool canCancel;
  final VoidCallback? onCancel;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sale.isMultiItem)
                      Text(
                        '\u0641\u0627\u062a\u0648\u0631\u0629 ${sale.items.length} \u0623\u0635\u0646\u0627\u0641',
                        style: textTheme.titleLarge,
                      )
                    else
                      Text(productName, style: textTheme.titleLarge),
                    if (customerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        customerName,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Chip(label: Text(sale.paymentMode.labelAr)),
              if (sale.isCancelled) ...[
                const SizedBox(width: 8),
                Chip(
                  label: const Text('\u0645\u0644\u063a\u064a'),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (sale.isMultiItem)
            ...sale.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '\u2022 $productName \u2014 $item.quantityKg \u0643\u062c\u0645 \u00d7 ${MoneyUtils.formatPiastersAsEgp(item.salePriceQirshPerKg)} = ${MoneyUtils.formatPiastersAsEgp(item.lineTotalQirsh)}',
                    style: textTheme.bodyMedium,
                  ),
                ))
          else ...[
            Text(
                '\u0627\u0644\u0643\u0645\u064a\u0629: ${sale.quantityKg} \u0643\u062c\u0645'),
            Text(
              '\u0627\u0644\u0633\u0639\u0631: ${MoneyUtils.formatPiastersAsEgp(sale.salePriceQirshPerKg)} / \u0643\u062c\u0645',
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a: ${MoneyUtils.formatPiastersAsEgp(sale.totalQirsh)}',
              ),
              Text(
                  '\u0627\u0644\u0648\u0642\u062a: ${_formatDateTime(sale.createdAt)}'),
              if (sale.isPartialPayment)
                Text(
                  '\u0627\u0644\u0645\u062f\u0641\u0648\u0639: ${MoneyUtils.formatPiastersAsEgp(sale.effectivePaidAmountQirsh)}',
                ),
              if (sale.isPartialPayment)
                Text(
                  '\u0627\u0644\u0645\u062a\u0628\u0642\u064a: ${MoneyUtils.formatPiastersAsEgp(sale.remainingAmountQirsh)}',
                ),
            ],
          ),
          if (sale.notes != null) ...[
            const SizedBox(height: 8),
            Text(sale.notes!),
          ],
          if (sale.cancellation != null) ...[
            const SizedBox(height: 8),
            Text(
                '\u0633\u0628\u0628 \u0627\u0644\u0625\u0644\u063a\u0627\u0621: ${sale.cancellation!.cancellationReason}'),
          ],
          if (onPreview != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.preview_rounded),
                label: const Text(
                    '\u0645\u0639\u0627\u064a\u0646\u0629 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629'),
              ),
            ),
          ],
          if (canCancel && !sale.isCancelled) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text(
                    '\u0625\u0644\u063a\u0627\u0621 \u0645\u0633\u062a\u0646\u062f \u0627\u0644\u0628\u064a\u0639'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final date =
        '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';

    return '$date $time';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _SaleFormDialog extends StatefulWidget {
  const _SaleFormDialog({
    required this.products,
    required this.customers,
    required this.financialAccounts,
    this.initialProductId,
  });

  final List<Product> products;
  final List<Customer> customers;
  final List<FinancialAccount> financialAccounts;
  final String? initialProductId;

  @override
  State<_SaleFormDialog> createState() => _SaleFormDialogState();
}

class _SaleFormDialogState extends State<_SaleFormDialog> {
  SalePaymentMode _paymentMode = SalePaymentMode.cash;
  String? _customerId;
  final _notesController = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;

  final List<_LineItemEntry> _lineItems = [];

  String? _paidAmountText;

  bool _useSplitPayments = true;
  final List<_AllocationEntry> _allocationEntries = [];

  @override
  void initState() {
    super.initState();
    final initialId = _initialProductId();
    _lineItems.add(_LineItemEntry(
      productId: initialId,
      products: widget.products,
    ));
    _allocationEntries.add(_AllocationEntry());
  }

  String _initialProductId() {
    final preferred = widget.initialProductId;
    if (preferred != null &&
        widget.products.any((product) => product.id == preferred)) {
      return preferred;
    }
    return widget.products.first.id;
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final item in _lineItems) {
      item.quantityController.dispose();
      item.priceController.dispose();
    }
    for (final entry in _allocationEntries) {
      entry.amountController.dispose();
    }
    super.dispose();
  }

  int? _computeTotal() {
    var total = 0;
    for (final item in _lineItems) {
      final qty = int.tryParse(item.quantityController.text.trim());
      final price = _tryParsePrice(item.priceController.text);
      if (qty == null || qty <= 0 || price == null || price <= 0) {
        return null;
      }
      total += qty * price;
    }
    return total > 0 ? total : null;
  }

  int? _computeAllocatedTotal() {
    if (!_useSplitPayments || _allocationEntries.isEmpty) return null;
    var total = 0;
    for (final entry in _allocationEntries) {
      final amount = _tryParseAmount(entry.amountController.text);
      if (amount == null) return null;
      total += amount;
    }
    return total;
  }

  int? _computeSplitRemaining() {
    final total = _computeTotal();
    if (total == null) return null;
    if (!_useSplitPayments) return null;
    final allocated = _computeAllocatedTotal();
    if (allocated == null) return null;
    final reference = _paymentMode == SalePaymentMode.partial
        ? (_parsePaidAmount() ?? 0)
        : total;
    return reference - allocated;
  }

  bool _isSplitBalanced() {
    final total = _computeTotal();
    if (total == null) return false;
    if (!_useSplitPayments) return true;
    final allocated = _computeAllocatedTotal();
    if (allocated == null) return false;
    final reference = _paymentMode == SalePaymentMode.partial
        ? (_parsePaidAmount() ?? 0)
        : total;
    return allocated == reference;
  }

  int? _parsePaidAmount() {
    if (_paymentMode != SalePaymentMode.partial) return null;
    try {
      return MoneyUtils.parseEgpToPiasters(
        _paidAmountText ?? '',
        allowZero: false,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _computeTotal();
    final hasValidItems = _lineItems.isNotEmpty &&
        _lineItems.every((item) {
          final qty = int.tryParse(item.quantityController.text.trim());
          final price = _tryParsePrice(item.priceController.text);
          return qty != null && qty > 0 && price != null && price > 0;
        });
    final customerSelected =
        _customerId != null && _customerId!.trim().isNotEmpty;
    final canUseSplit = _paymentMode != SalePaymentMode.credit &&
        widget.financialAccounts.isNotEmpty;
    final paymentRouteValid = _paymentMode == SalePaymentMode.credit ||
        (canUseSplit && _useSplitPayments && _isSplitBalanced());
    final canSubmit = customerSelected &&
        hasValidItems &&
        paymentRouteValid &&
        !_isSubmitting;

    return AlertDialog(
      title: const Text(
          '\u062a\u0633\u062c\u064a\u0644 \u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '\u0623\u0636\u0641 \u0627\u0644\u0623\u0635\u0646\u0627\u0641 \u0648\u0627\u062e\u062a\u0631 \u0627\u0644\u0639\u0645\u064a\u0644 \u0642\u0628\u0644 \u062d\u0641\u0638 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629.',
                style: TextStyle(fontSize: 12, color: AppColors.mutedText),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _customerId,
              decoration: const InputDecoration(
                labelText:
                    '\u0627\u062e\u062a\u0631 \u0627\u0644\u0639\u0645\u064a\u0644 *',
                helperText:
                    '\u0643\u0644 \u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639 \u062a\u062a\u0637\u0644\u0628 \u0639\u0645\u064a\u0644\u0627 \u0645\u0633\u062c\u0644\u0627.',
              ),
              items: [
                for (final customer in widget.customers)
                  DropdownMenuItem(
                    value: customer.id,
                    child: Text(customer.name),
                  ),
              ],
              onChanged: (value) => setState(() => _customerId = value),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '\u0623\u0635\u0646\u0627\u0641 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _lineItems.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _buildLineItem(i),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: widget.products.length > 1 ? _addLineItem : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text(
                    '\u0625\u0636\u0627\u0641\u0629 \u0635\u0646\u0641 \u0622\u062e\u0631'),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                total == null
                    ? '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a: -'
                    : '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a: ${MoneyUtils.formatPiastersAsEgp(total)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '\u0637\u0631\u064a\u0642\u0629 \u0627\u0644\u062f\u0641\u0639',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<SalePaymentMode>(
              segments: const [
                ButtonSegment(
                  value: SalePaymentMode.cash,
                  label: Text('\u0646\u0642\u062f\u064a'),
                  icon: Icon(Icons.payments_rounded),
                ),
                ButtonSegment(
                  value: SalePaymentMode.credit,
                  label: Text('\u0622\u062c\u0644'),
                  icon: Icon(Icons.person_pin_circle_rounded),
                ),
                ButtonSegment(
                  value: SalePaymentMode.partial,
                  label: Text('\u062f\u0641\u0639 \u062c\u0632\u0626\u064a'),
                  icon: Icon(Icons.money_rounded),
                ),
              ],
              selected: {_paymentMode},
              onSelectionChanged: (selection) {
                setState(() {
                  _paymentMode = selection.first;
                  if (_paymentMode == SalePaymentMode.cash) {
                    _paidAmountText = null;
                  }
                  if (_paymentMode == SalePaymentMode.credit) {
                    _useSplitPayments = false;
                  } else {
                    _useSplitPayments = true;
                    if (_allocationEntries.isEmpty) {
                      _allocationEntries.add(_AllocationEntry());
                    }
                  }
                });
              },
            ),
            if (_paymentMode == SalePaymentMode.partial) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText:
                      '\u0627\u0644\u0645\u0628\u0644\u063a \u0627\u0644\u0645\u062f\u0641\u0648\u0639 \u0628\u0627\u0644\u062c\u0646\u064a\u0647',
                  helperText:
                      '\u0623\u062f\u062e\u0644 \u0627\u0644\u0645\u0628\u0644\u063a \u0627\u0644\u0630\u064a \u062f\u0641\u0639\u0647 \u0627\u0644\u0639\u0645\u064a\u0644 \u0646\u0642\u062f\u0627\u060c \u0648\u0627\u0644\u0628\u0627\u0642\u064a \u0633\u064a\u0638\u0644 \u0639\u0644\u064a\u0647.',
                ),
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                onChanged: (value) => setState(() => _paidAmountText = value),
              ),
            ],
            if (_paymentMode == SalePaymentMode.credit && total != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '\u0633\u064a\u062a\u0645 \u0625\u0636\u0627\u0641\u0629 \u0642\u064a\u0645\u0629 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629 \u0639\u0644\u0649 \u0631\u0635\u064a\u062f \u0627\u0644\u0639\u0645\u064a\u0644: ${MoneyUtils.formatPiastersAsEgp(total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                ),
              ),
            ],
            if (_paymentMode == SalePaymentMode.cash && total != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '\u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629 \u0645\u062f\u0641\u0648\u0639\u0629 \u0646\u0642\u062f\u0627\u060c \u0648\u0633\u062a\u0638\u0647\u0631 \u0641\u064a \u0643\u0634\u0641 \u062d\u0633\u0627\u0628 \u0627\u0644\u0639\u0645\u064a\u0644 \u0643\u0641\u0627\u062a\u0648\u0631\u0629 \u0645\u0633\u062f\u062f\u0629.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                ),
              ),
            ],
            if (canUseSplit) ...[
              const SizedBox(height: 12),
              const Divider(),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '\u062a\u062e\u0635\u064a\u0635 \u0627\u0644\u0645\u062f\u0641\u0648\u0639\u0627\u062a',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '\u062a\u062d\u062f\u064a\u062f \u0627\u0644\u062d\u0633\u0627\u0628 \u0648\u0637\u0631\u064a\u0642\u0629 \u0627\u0644\u062f\u0641\u0639',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  '\u064a\u062c\u0628 \u0631\u0628\u0637 \u0643\u0644 \u0645\u0628\u0644\u063a \u0645\u062f\u0641\u0648\u0639 \u0628\u062d\u0633\u0627\u0628 \u0645\u0627\u0644\u064a \u0645\u062a\u0648\u0627\u0641\u0642.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                ),
                value: _useSplitPayments,
                onChanged: null,
              ),
              if (_useSplitPayments) ...[
                if (widget.financialAccounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '\u0644\u0627 \u062a\u0648\u062c\u062f \u062d\u0633\u0627\u0628\u0627\u062a \u0645\u0627\u0644\u064a\u0629 \u0645\u062a\u0648\u0641\u0642\u0629. \u062a\u0639\u0631\u0641 \u062d\u0633\u0627\u0628\u0627\u062a \u0645\u0627\u0644\u064a\u0629 \u0623\u0648\u0644\u0627\u064b.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  )
                else ...[
                  for (int i = 0; i < _allocationEntries.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _buildAllocationRow(i),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _allocationEntries.length < 5
                          ? () => setState(() {
                                _allocationEntries.add(_AllocationEntry());
                              })
                          : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text(
                          '\u0625\u0636\u0627\u0641\u0629 \u062a\u062e\u0635\u064a\u0635'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSplitSummary(),
                ],
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText:
                    '\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u062e\u062a\u064a\u0627\u0631\u064a\u0629',
                helperText:
                    '\u0645\u062b\u0627\u0644: \u0627\u0633\u0645 \u0627\u0644\u0633\u0627\u0626\u0642 \u0623\u0648 \u0631\u0642\u0645 \u0627\u0644\u0633\u064a\u0627\u0631\u0629.',
              ),
              maxLines: 2,
              textDirection: TextDirection.rtl,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('\u0625\u0644\u063a\u0627\u0621'),
        ),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '\u062d\u0641\u0638 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629'),
        ),
      ],
    );
  }

  Widget _buildAllocationRow(int index) {
    final entry = _allocationEntries[index];
    final activeAccounts = widget.financialAccounts
        .where((account) =>
            account.isActive &&
            PaymentRoutingPolicy.isCompatible(
              paymentMethod: entry.paymentMethod,
              accountType: account.type,
            ))
        .toList(growable: false);
    final usedAccountIds = <String>{
      for (int i = 0; i < _allocationEntries.length; i++)
        if (i != index) _allocationEntries[i].accountId ?? '',
    };
    final availableAccounts = activeAccounts
        .where((a) => !usedAccountIds.contains(a.id))
        .toList(growable: false);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    value: entry.accountId,
                    decoration: const InputDecoration(
                      labelText:
                          '\u0627\u0644\u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u064a',
                      isDense: true,
                    ),
                    items: [
                      for (final account in availableAccounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => entry.accountId = value);
                    },
                  ),
                ),
                if (_allocationEntries.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: Colors.red, size: 20),
                    onPressed: () => setState(() {
                      entry.amountController.dispose();
                      _allocationEntries.removeAt(index);
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText:
                          '\u0627\u0644\u0645\u0628\u0644\u063a (\u062c.\u0645)',
                      isDense: true,
                    ),
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<PaymentMethod>(
                    value: entry.paymentMethod,
                    decoration: const InputDecoration(
                      labelText: '\u0637\u0631\u064a\u0642\u0629',
                      isDense: true,
                    ),
                    items: PaymentRoutingPolicy.selectablePaymentMethods
                        .map((method) => DropdownMenuItem(
                              value: method,
                              child: Text(method.labelAr),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          entry.paymentMethod = value;
                          final accountId = entry.accountId;
                          if (accountId != null &&
                              !widget.financialAccounts.any((account) =>
                                  account.id == accountId &&
                                  PaymentRoutingPolicy.isCompatible(
                                    paymentMethod: value,
                                    accountType: account.type,
                                  ))) {
                            entry.accountId = null;
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () {
                  final remaining = _computeSplitRemaining();
                  if (remaining != null && remaining > 0) {
                    setState(() {
                      entry.amountController.text =
                          MoneyUtils.formatPiastersAsEgpNumber(remaining);
                    });
                  }
                },
                child: const Text(
                  '\u0627\u0633\u062a\u062e\u062f\u0627\u0645 \u0627\u0644\u0645\u062a\u0628\u0642\u064a',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitSummary() {
    final total = _computeTotal();
    final allocated = _computeAllocatedTotal();
    final remaining = _computeSplitRemaining();
    final balanced = _isSplitBalanced();
    final reference = _paymentMode == SalePaymentMode.partial
        ? (_parsePaidAmount() ?? 0)
        : (total ?? 0);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _summaryRow(
              '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629',
              total != null ? MoneyUtils.formatPiastersAsEgp(total) : '-',
            ),
            _summaryRow(
              '\u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u062a\u062e\u0635\u064a\u0635',
              allocated != null
                  ? MoneyUtils.formatPiastersAsEgp(allocated)
                  : '-',
            ),
            if (_paymentMode == SalePaymentMode.partial)
              _summaryRow(
                '\u0627\u0644\u0645\u0628\u0644\u063a \u0627\u0644\u0645\u062f\u0641\u0648\u0639',
                MoneyUtils.formatPiastersAsEgp(reference),
              ),
            _summaryRow(
              '\u0627\u0644\u0645\u062a\u0628\u0642\u064a',
              remaining != null
                  ? MoneyUtils.formatPiastersAsEgp(remaining)
                  : '-',
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                balanced
                    ? '\u2713 \u0645\u062a\u0648\u0627\u0641\u0642'
                    : '\u2717 \u063a\u064a\u0631 \u0645\u062a\u0648\u0627\u0641\u0642',
                style: TextStyle(
                  color: balanced ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildLineItem(int index) {
    final item = _lineItems[index];
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: item.productId,
                decoration: const InputDecoration(
                  labelText: '\u0627\u0644\u0635\u0646\u0641',
                  isDense: true,
                ),
                items: [
                  for (final product in widget.products)
                    DropdownMenuItem(
                      value: product.id,
                      child:
                          Text(product.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => item.productId = value);
                  }
                },
              ),
            ),
            if (_lineItems.length > 1) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.red),
                onPressed: () => setState(() {
                  item.quantityController.dispose();
                  item.priceController.dispose();
                  _lineItems.removeAt(index);
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: item.quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText:
                      '\u0627\u0644\u0643\u0645\u064a\u0629 (\u0643\u062c\u0645)',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                textDirection: TextDirection.ltr,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: item.priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText:
                      '\u0627\u0644\u0633\u0639\u0631 / \u0643\u062c\u0645',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            _lineTotalPreview(index),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  String _lineTotalPreview(int index) {
    final item = _lineItems[index];
    final qty = int.tryParse(item.quantityController.text.trim());
    final price = _tryParsePrice(item.priceController.text);
    if (qty == null || qty <= 0 || price == null || price <= 0) {
      return '\u0627\u0644\u0645\u062c\u0645\u0648\u0639: -';
    }
    return '\u0627\u0644\u0645\u062c\u0645\u0648\u0639: ${MoneyUtils.formatPiastersAsEgp(qty * price)}';
  }

  void _addLineItem() {
    final usedProductIds = _lineItems.map((item) => item.productId).toSet();
    final available =
        widget.products.where((p) => !usedProductIds.contains(p.id)).toList();
    if (available.isEmpty) return;

    setState(() {
      _lineItems.add(_LineItemEntry(
        productId: available.first.id,
        products: widget.products,
      ));
    });
  }

  void _submit() {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final customerId = _customerId;
    if (customerId == null || customerId.trim().isEmpty) {
      setState(() {
        _errorMessage =
            '\u0627\u062e\u062a\u0631 \u0627\u0644\u0639\u0645\u064a\u0644 \u0642\u0628\u0644 \u062d\u0641\u0638 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629.';
        _isSubmitting = false;
      });
      return;
    }

    if (_lineItems.isEmpty) {
      setState(() {
        _errorMessage =
            '\u0623\u0636\u0641 \u0635\u0646\u0641\u0627 \u0648\u0627\u062d\u062f\u0627 \u0639\u0644\u0649 \u0627\u0644\u0623\u0642\u0644 \u0644\u0644\u0641\u0627\u062a\u0648\u0631\u0629.';
        _isSubmitting = false;
      });
      return;
    }

    final items = <SaleLineItemDraft>[];
    for (final item in _lineItems) {
      final qty = int.tryParse(item.quantityController.text.trim());
      final price = _tryParsePrice(item.priceController.text);
      if (qty == null || qty <= 0) {
        setState(() {
          _errorMessage =
              '\u0627\u0643\u062a\u0628 \u0643\u0645\u064a\u0629 \u0627\u0644\u0628\u064a\u0639 \u0628\u0627\u0644\u0643\u064a\u0644\u0648\u060c \u0648\u064a\u062c\u0628 \u0623\u0646 \u062a\u0643\u0648\u0646 \u0623\u0643\u0628\u0631 \u0645\u0646 \u0635\u0641\u0631.';
          _isSubmitting = false;
        });
        return;
      }
      if (price == null || price <= 0) {
        setState(() {
          _errorMessage =
              '\u0627\u0643\u062a\u0628 \u0633\u0639\u0631 \u0627\u0644\u0628\u064a\u0639 \u0628\u0627\u0644\u062c\u0646\u064a\u0647 \u0628\u0634\u0643\u0644 \u0635\u062d\u064a\u062d.';
          _isSubmitting = false;
        });
        return;
      }
      items.add(SaleLineItemDraft(
        productId: item.productId,
        quantityKg: qty,
        salePriceQirshPerKg: price,
      ));
    }

    int? paidAmountQirsh;
    if (_paymentMode == SalePaymentMode.partial) {
      try {
        paidAmountQirsh = MoneyUtils.parseEgpToPiasters(
          _paidAmountText ?? '',
          allowZero: false,
        );
      } on Object {
        setState(() {
          _errorMessage =
              '\u0627\u0643\u062a\u0628 \u0627\u0644\u0645\u0628\u0644\u063a \u0627\u0644\u0645\u062f\u0641\u0648\u0639 \u0628\u0634\u0643\u0644 \u0635\u062d\u064a\u062d.';
          _isSubmitting = false;
        });
        return;
      }
      final total = _computeTotal();
      if (total != null && paidAmountQirsh > total) {
        setState(() {
          _errorMessage =
              '\u0627\u0644\u0645\u0628\u0644\u063a \u0627\u0644\u0645\u062f\u0641\u0648\u0639 \u0644\u0627 \u064a\u0645\u0643\u0646 \u0623\u0646 \u064a\u0643\u0648\u0646 \u0623\u0643\u0628\u0631 \u0645\u0646 \u0625\u062c\u0645\u0627\u0644\u064a \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629.';
          _isSubmitting = false;
        });
        return;
      }
      if (paidAmountQirsh <= 0) {
        setState(() {
          _errorMessage =
              '\u0627\u0644\u0645\u0628\u0644\u063a \u0627\u0644\u0645\u062f\u0641\u0648\u0639 \u064a\u062c\u0628 \u0623\u0646 \u064a\u0643\u0648\u0646 \u0623\u0643\u0628\u0631 \u0645\u0646 \u0635\u0641\u0631.';
          _isSubmitting = false;
        });
        return;
      }
    }

    final saleTotal = _computeTotal() ?? 0;
    List<SalePaymentAllocation> paymentAllocations = const [];
    String? operationRequestId;

    if (_useSplitPayments) {
      final allocations = <SalePaymentAllocation>[];
      final usedAccountIds = <String>{};

      for (int i = 0; i < _allocationEntries.length; i++) {
        final entry = _allocationEntries[i];
        final amount = _tryParseAmount(entry.amountController.text);
        if (amount == null || amount <= 0) {
          setState(() {
            _errorMessage =
                '\u0645\u0628\u0644\u063a \u0627\u0644\u062a\u062e\u0635\u064a\u0635 ${i + 1} \u063a\u064a\u0631 \u0635\u062d\u064a\u062d. \u0623\u062f\u062e\u0644 \u0645\u0628\u0644\u063a\u0627\u064b \u0635\u062d\u064a\u062d\u0627\u064b.';
            _isSubmitting = false;
          });
          return;
        }
        final accountId = entry.accountId;
        if (accountId == null || accountId.trim().isEmpty) {
          setState(() {
            _errorMessage =
                '\u0627\u062e\u062a\u0631 \u0627\u0644\u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u064a \u0644\u0644\u062a\u062e\u0635\u064a\u0635 ${i + 1}.';
            _isSubmitting = false;
          });
          return;
        }
        if (!usedAccountIds.add(accountId)) {
          setState(() {
            _errorMessage =
                '\u0627\u0644\u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u064a \u0645\u0633\u062a\u062e\u062f\u0645 \u0623\u0643\u062b\u0631 \u0645\u0646 \u0645\u0631\u0629.';
            _isSubmitting = false;
          });
          return;
        }
        allocations.add(SalePaymentAllocation(
          financialAccountId: accountId,
          amountQirsh: amount,
          paymentMethod: entry.paymentMethod,
        ));
      }

      final reference = _paymentMode == SalePaymentMode.partial
          ? (paidAmountQirsh ?? 0)
          : saleTotal;
      final allocatedTotal =
          allocations.fold<int>(0, (sum, a) => sum + a.amountQirsh);
      if (allocatedTotal != reference) {
        setState(() {
          _errorMessage =
              '\u0645\u062c\u0645\u0648\u0639 \u0627\u0644\u062a\u062e\u0635\u064a\u0635\u0627\u062a ($allocatedTotal) \u063a\u064a\u0631 \u0645\u0637\u0627\u0628\u0642 \u0644\u0644\u0645\u0628\u0644\u063a \u0627\u0644\u0645\u062d\u062f\u062f ($reference).';
          _isSubmitting = false;
        });
        return;
      }

      paymentAllocations = allocations;
      operationRequestId = 'sale-ui-${DateTime.now().microsecondsSinceEpoch}';
    }

    Navigator.of(context).pop(
      _SaleFormResult(
        customerId: customerId,
        paymentMode: _paymentMode,
        items: items,
        notes: _notesController.text,
        paidAmountQirsh: paidAmountQirsh,
        paymentAllocations: paymentAllocations,
        operationRequestId: operationRequestId,
      ),
    );
  }

  int? _tryParsePrice(String value) {
    try {
      return MoneyUtils.parseEgpToPiasters(value, allowZero: false);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  int? _tryParseAmount(String value) {
    try {
      return MoneyUtils.parseEgpToPiasters(value, allowZero: false);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}

class _AllocationEntry {
  _AllocationEntry() : amountController = TextEditingController();

  String? accountId;
  PaymentMethod paymentMethod = PaymentMethod.cash;
  final TextEditingController amountController;
}

class _LineItemEntry {
  _LineItemEntry({
    required this.productId,
    required List<Product> products,
  })  : quantityController = TextEditingController(),
        priceController = TextEditingController();

  String productId;
  final TextEditingController quantityController;
  final TextEditingController priceController;
}

class _SaleFormResult {
  const _SaleFormResult({
    required this.customerId,
    required this.paymentMode,
    required this.items,
    this.notes,
    this.paidAmountQirsh,
    this.paymentAllocations = const [],
    this.operationRequestId,
  });

  final String customerId;
  final SalePaymentMode paymentMode;
  final List<SaleLineItemDraft> items;
  final String? notes;
  final int? paidAmountQirsh;
  final List<SalePaymentAllocation> paymentAllocations;
  final String? operationRequestId;
}
