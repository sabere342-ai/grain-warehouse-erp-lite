import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';
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
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض المبيعات.'));
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
                      Text('المبيعات', style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'سجل بيع نقدي أو بيع آجل على عميل بنفس قواعد السعر والمخزون.',
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
                  label: const Text('سجل المستندات'),
                ),
                const SizedBox(width: 8),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: _controller.products.isEmpty
                        ? null
                        : () => _showSaleForm(context, user: user),
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: const Text('تسجيل بيع حبوب'),
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
                    'لا توجد مبيعات حبوب مسجلة بعد. ستظهر هنا فواتير البيع بعد الحفظ.',
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
                    ),
                  ),
                ),
            ],
          ],
        );
      },
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
        initialProductId: initialProductId,
      ),
    );

    if (result == null) {
      return;
    }

    await _controller.createSale(
      user: user,
      productId: result.productId,
      quantityKg: result.quantityKg,
      salePriceQirshPerKg: result.salePriceQirshPerKg,
      notes: result.notes,
      paymentMode: result.paymentMode,
      customerId: result.customerId,
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
        title: const Text('تأكيد إلغاء البيع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم إنشاء حركة مخزون عكسية لإلغاء أثر هذا البيع. لن يتم حذف مستند البيع الأصلي.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'سبب الإلغاء'),
              maxLines: 2,
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            child: const Text('تأكيد الإلغاء'),
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
        child: Text('أضف صنفا وكمية مخزون قبل تسجيل البيع.'),
      );
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اختر صنف البيع', style: textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'اضغط على بطاقة الصنف لفتح نموذج البيع بنفس قواعد السعر والمخزون الحالية.',
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
              Text('المخزون الحالي: $stockKg كجم'),
              const SizedBox(height: 6),
              Text(
                defaultPrice == null
                    ? 'سعر البيع الافتراضي: غير محدد'
                    : 'سعر البيع الافتراضي: ${MoneyUtils.formatPiastersAsEgp(defaultPrice)} / كجم',
              ),
              const SizedBox(height: 6),
              Text(
                minimumPrice == null
                    ? 'الحد الأدنى للبيع: غير محدد'
                    : 'الحد الأدنى للبيع: ${MoneyUtils.formatPiastersAsEgp(minimumPrice)} / كجم',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: const Text('بيع هذا الصنف'),
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
  });

  final SaleRecord sale;
  final String productName;
  final String customerName;
  final bool canCancel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(productName, style: textTheme.titleLarge)),
              Chip(label: Text(sale.paymentMode.labelAr)),
              if (sale.isCancelled) ...[
                const SizedBox(width: 8),
                Chip(
                  label: const Text('ملغي'),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('الكمية: ${sale.quantityKg} كجم'),
              Text(
                'السعر: ${MoneyUtils.formatPiastersAsEgp(sale.salePriceQirshPerKg)} / كجم',
              ),
              Text(
                'الإجمالي: ${MoneyUtils.formatPiastersAsEgp(sale.totalQirsh)}',
              ),
              Text('الوقت: ${_formatDateTime(sale.createdAt)}'),
              if (sale.isCreditSale) Text('العميل: $customerName'),
            ],
          ),
          if (sale.notes != null) ...[
            const SizedBox(height: 8),
            Text(sale.notes!),
          ],
          if (sale.cancellation != null) ...[
            const SizedBox(height: 8),
            Text('سبب الإلغاء: ${sale.cancellation!.cancellationReason}'),
          ],
          if (canCancel && !sale.isCancelled) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء مستند البيع'),
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
    this.initialProductId,
  });

  final List<Product> products;
  final List<Customer> customers;
  final String? initialProductId;

  @override
  State<_SaleFormDialog> createState() => _SaleFormDialogState();
}

class _SaleFormDialogState extends State<_SaleFormDialog> {
  late String _productId = _initialProductId();
  SalePaymentMode _paymentMode = SalePaymentMode.cash;
  String? _customerId;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _errorMessage;

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
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = int.tryParse(_quantityController.text.trim());
    final price = _tryParsePrice(_priceController.text);
    final total = quantity != null && quantity > 0 && price != null && price > 0
        ? quantity * price
        : null;
    final isCredit = _paymentMode == SalePaymentMode.credit;

    return AlertDialog(
      title: const Text('تسجيل بيع حبوب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _productId,
              decoration: const InputDecoration(labelText: 'الصنف'),
              items: [
                for (final product in widget.products)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text(product.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _productId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الكمية بالكجم',
                helperText: 'اكتب كمية الحبوب الخارجة من المخزن.',
              ),
              onChanged: (_) => setState(() {}),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'سعر البيع بالجنيه / كجم',
                helperText: 'اكتب سعر الكيلو بالجنيه ويمكن استخدام القروش.',
              ),
              onChanged: (_) => setState(() {}),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                total == null
                    ? 'الإجمالي: -'
                    : 'الإجمالي: ${MoneyUtils.formatPiastersAsEgp(total)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'طريقة الدفع',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<SalePaymentMode>(
              segments: const [
                ButtonSegment(
                  value: SalePaymentMode.cash,
                  label: Text('نقدي'),
                  icon: Icon(Icons.payments_rounded),
                ),
                ButtonSegment(
                  value: SalePaymentMode.credit,
                  label: Text('آجل على عميل'),
                  icon: Icon(Icons.person_pin_circle_rounded),
                ),
              ],
              selected: {_paymentMode},
              onSelectionChanged: (selection) {
                setState(() {
                  _paymentMode = selection.first;
                  if (_paymentMode == SalePaymentMode.cash) {
                    _customerId = null;
                  }
                });
              },
            ),
            if (isCredit) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _customerId,
                decoration: const InputDecoration(labelText: 'اختر العميل'),
                items: [
                  for (final customer in widget.customers)
                    DropdownMenuItem(
                      value: customer.id,
                      child: Text(customer.name),
                    ),
                ],
                onChanged: (value) => setState(() => _customerId = value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  total == null
                      ? 'سيتم إضافة مبلغ الفاتورة على رصيد العميل بعد إدخال الكمية والسعر.'
                      : 'سيتم إضافة مبلغ الفاتورة على رصيد العميل: ${MoneyUtils.formatPiastersAsEgp(total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات اختيارية',
                helperText: 'مثال: اسم السائق أو رقم السيارة.',
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('حفظ البيع'),
        ),
      ],
    );
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim());
    final price = _tryParsePrice(_priceController.text);
    if (quantity == null || quantity <= 0) {
      setState(() =>
          _errorMessage = 'اكتب كمية البيع بالكيلو، ويجب أن تكون أكبر من صفر.');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _errorMessage = 'اكتب سعر البيع بالجنيه بشكل صحيح.');
      return;
    }
    if (_paymentMode == SalePaymentMode.credit &&
        (_customerId == null || _customerId!.trim().isEmpty)) {
      setState(() => _errorMessage = 'البيع الآجل يحتاج اختيار عميل نشط.');
      return;
    }

    Navigator.of(context).pop(
      _SaleFormResult(
        productId: _productId,
        quantityKg: quantity,
        salePriceQirshPerKg: price,
        paymentMode: _paymentMode,
        customerId: _customerId,
        notes: _notesController.text,
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
}

class _SaleFormResult {
  const _SaleFormResult({
    required this.productId,
    required this.quantityKg,
    required this.salePriceQirshPerKg,
    required this.paymentMode,
    this.customerId,
    this.notes,
  });

  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
  final SalePaymentMode paymentMode;
  final String? customerId;
  final String? notes;
}
