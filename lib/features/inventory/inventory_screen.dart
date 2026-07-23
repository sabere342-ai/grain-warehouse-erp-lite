import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/stock_adjustment_report_screen.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/stock_take_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.controller});

  final InventoryController? controller;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final InventoryController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        InventoryController(
          inventoryRepository: AppRepositories.inventoryRepository,
          productRepository: AppRepositories.productRepository,
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

    if (user == null) {
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض المخزون.'));
    }

    final canAdjust = user.permissions.canCreateStockAdjustment;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView(
          children: [
            GhalalPageHeader(
              title: 'المخزون',
              subtitle: canAdjust
                  ? 'الأرصدة محسوبة من حركات المخزون فقط. أي تعديل يدوي يحتاج سبب واضح.'
                  : 'الأرصدة للعرض فقط. تعديل المخزون وإضافة الحركات للمالك فقط.',
              icon: Icons.warehouse_rounded,
              actions: [
                if (canAdjust) ...[
                  FilledButton.icon(
                    key: const Key('inventory_add_movement_button'),
                    onPressed: _controller.products.isEmpty
                        ? null
                        : () => _showMovementForm(context, user: user),
                    icon: const Icon(Icons.add_chart_rounded),
                    label: const Text('إضافة حركة مخزون'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('inventory_stock_take_button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StockTakeScreen(
                            controller: _controller,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.balance_rounded),
                    label: const Text('جرد المخزون'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('inventory_adjustment_report_button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: StockAdjustmentReportScreen(
                              controller: _controller,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fact_check_rounded),
                    label: const Text('تقرير التسويات'),
                  ),
                ],
              ],
            ),
            if (_controller.errorMessage != null &&
                _controller.products.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _controller.errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_controller.isLoading)
              const GhalalLoadingState(label: 'جاري تحميل المخزون...')
            else if (_controller.errorMessage != null &&
                _controller.products.isEmpty)
              GhalalErrorState(
                message: _controller.errorMessage!,
                onRetry: () => _controller.load(user),
              )
            else if (_controller.products.isEmpty)
              const GhalalEmptyState(
                title: 'لا توجد أصناف نشطة لعرض المخزون',
                message: 'أضف أو فعّل صنف حبوب أولا.',
                icon: Icons.warehouse_outlined,
              )
            else
              ..._controller.products.map(
                (product) {
                  final productId = product.id;
                  final hasOpening = _controller.hasOpeningBalance(productId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _InventoryProductCard(
                      product: product,
                      balanceKg: _controller.balanceForProduct(productId),
                      movements: _controller.movementsForProduct(productId),
                      canAdjust: canAdjust,
                      hasOpeningBalance: hasOpening,
                      onAddOpeningBalance: canAdjust && !hasOpening
                          ? () => _addOpeningBalance(
                                context,
                                user: user,
                                product: product,
                              )
                          : null,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _addOpeningBalance(
    BuildContext context, {
    required user,
    required Product product,
  }) async {
    final quantityKg = await showDialog<int>(
      context: context,
      builder: (context) => _OpeningBalanceDialog(product: product),
    );

    if (quantityKg == null) return;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GhalalResponsiveDialog(
        title: const Text('تأكيد الرصيد الافتتاحي'),
        content: Text(
          'تأكيد تسجيل رصيد افتتاحي لـ ${product.name} بكمية $quantityKg كجم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await _controller.createOpeningBalance(
      user: user,
      productId: product.id,
      quantityKg: quantityKg,
      note: null,
    );
  }

  Future<void> _showMovementForm(
    BuildContext context, {
    required user,
  }) async {
    final draft = await showDialog<_MovementFormResult>(
      context: context,
      builder: (context) => _MovementFormDialog(
        products: _controller.products,
        hasOpeningBalance: _controller.hasOpeningBalance,
      ),
    );

    if (draft == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final confirmed = await _confirmStockMovement(context, draft);
    if (!confirmed) {
      return;
    }

    switch (draft.movementType) {
      case StockMovementType.openingBalance:
        await _controller.createOpeningBalance(
          user: user,
          productId: draft.productId,
          quantityKg: draft.quantityKg,
          note: draft.note,
        );
      case StockMovementType.manualIncrease:
        await _controller.createManualIncrease(
          user: user,
          productId: draft.productId,
          quantityKg: draft.quantityKg,
          note: draft.note,
        );
      case StockMovementType.manualDecrease:
        await _controller.createManualDecrease(
          user: user,
          productId: draft.productId,
          quantityKg: draft.quantityKg,
          note: draft.note,
        );
      case StockMovementType.purchaseIntake:
        return;
      case StockMovementType.sale:
        return;
      case StockMovementType.purchaseCancellation:
        return;
      case StockMovementType.saleCancellation:
        return;
    }
  }

  Future<bool> _confirmStockMovement(
    BuildContext context,
    _MovementFormResult draft,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => GhalalResponsiveDialog(
            title: const Text('تأكيد حركة المخزون'),
            content: Text(
              'تنبيه: سيتم تسجيل ${draft.movementType.labelAr} بكمية '
              '${draft.quantityKg} كجم. هذه الحركة تؤثر على رصيد المخزون '
              'ولا يتم تعديلها بعد الحفظ.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('رجوع'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('تأكيد الحركة'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _InventoryProductCard extends StatelessWidget {
  const _InventoryProductCard({
    required this.product,
    required this.balanceKg,
    required this.movements,
    this.canAdjust = false,
    this.hasOpeningBalance = false,
    this.onAddOpeningBalance,
  });

  final Product product;
  final int balanceKg;
  final List<StockMovement> movements;
  final bool canAdjust;
  final bool hasOpeningBalance;
  final VoidCallback? onAddOpeningBalance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(product.name, style: textTheme.titleLarge)),
              Text(
                _formatQuantity(balanceKg),
                textDirection: TextDirection.ltr,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.olive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (movements.isEmpty)
            const Text(
              'لا توجد حركات مخزون لهذا الصنف بعد. ستظهر هنا أرصدة الافتتاح والشراء والبيع والإلغاء.',
            )
          else
            ...movements.reversed.take(4).map(
                  (movement) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${movement.movementType.labelAr}: ${_formatQuantity(movement.quantityKg)}',
                    ),
                  ),
                ),
          if (canAdjust && !hasOpeningBalance) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAddOpeningBalance,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('إضافة رصيد افتتاحي'),
            ),
          ],
        ],
      ),
    );
  }

  String _formatQuantity(int quantityKg) {
    if (quantityKg >= GrainUnitConverter.kilogramsPerTon &&
        quantityKg % GrainUnitConverter.kilogramsPerTon == 0) {
      return '$quantityKg كجم (${quantityKg ~/ GrainUnitConverter.kilogramsPerTon} طن)';
    }

    return '$quantityKg كجم';
  }
}

class _OpeningBalanceDialog extends StatefulWidget {
  const _OpeningBalanceDialog({required this.product});

  final Product product;

  @override
  State<_OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<_OpeningBalanceDialog> {
  GrainUnit _inputUnit = GrainUnit.kilogram;
  final _quantityController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GhalalResponsiveDialog(
      title: const Text('إضافة رصيد افتتاحي للمخزون'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('أدخل الكمية الافتتاحية لـ ${widget.product.name}.'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    helperText: 'اكتب الرقم حسب الوحدة المختارة.',
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<GrainUnit>(
                  value: _inputUnit,
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                  items: const [
                    DropdownMenuItem(
                      value: GrainUnit.kilogram,
                      child: Text('كجم'),
                    ),
                    DropdownMenuItem(
                      value: GrainUnit.ton,
                      child: Text('طن'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _inputUnit = value);
                    }
                  },
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => GhalalResponsiveDialog.requestClose(
            context,
            isDirty: _quantityController.text.isNotEmpty,
          ),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _errorMessage = 'اكتب كمية صحيحة أكبر من صفر.');
      return;
    }

    final quantityKg = _inputUnit == GrainUnit.ton
        ? GrainUnitConverter.tonsToKilograms(quantity)
        : quantity;

    Navigator.of(context).pop(quantityKg);
  }
}

class _MovementFormDialog extends StatefulWidget {
  const _MovementFormDialog({
    required this.products,
    required this.hasOpeningBalance,
  });

  final List<Product> products;
  final bool Function(String productId) hasOpeningBalance;

  @override
  State<_MovementFormDialog> createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends State<_MovementFormDialog> {
  late String _productId = widget.products.first.id;
  late StockMovementType _movementType = _availableMovementTypes().first;
  GrainUnit _inputUnit = GrainUnit.kilogram;
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GhalalResponsiveDialog(
      title: const Text('إضافة حركة مخزون'),
      content: Column(
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
                setState(() {
                  _productId = value;
                  if (!_availableMovementTypes().contains(_movementType)) {
                    _movementType = _availableMovementTypes().first;
                  }
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<StockMovementType>(
            value: _movementType,
            decoration: const InputDecoration(
              labelText: 'نوع الحركة',
              helperText: 'اخترها بدقة لأنها تؤثر على الرصيد.',
            ),
            items: [
              for (final type in _availableMovementTypes())
                DropdownMenuItem(
                  value: type,
                  child: Text(type.labelAr),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _movementType = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    helperText: 'اكتب الرقم حسب الوحدة المختارة.',
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<GrainUnit>(
                  value: _inputUnit,
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                  items: const [
                    DropdownMenuItem(
                      value: GrainUnit.kilogram,
                      child: Text('كجم'),
                    ),
                    DropdownMenuItem(
                      value: GrainUnit.ton,
                      child: Text('طن'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _inputUnit = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'سبب أو ملاحظة',
              helperText: 'مطلوب عمليا لتسهيل مراجعة المالك.',
            ),
            maxLines: 2,
            textDirection: TextDirection.rtl,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => GhalalResponsiveDialog.requestClose(
            context,
            isDirty: _quantityController.text.isNotEmpty ||
                _noteController.text.isNotEmpty,
          ),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('مراجعة الحركة'),
        ),
      ],
    );
  }

  List<StockMovementType> _availableMovementTypes() {
    final hasOpening = widget.hasOpeningBalance(_productId);
    return [
      if (!hasOpening) StockMovementType.openingBalance,
      StockMovementType.manualIncrease,
      StockMovementType.manualDecrease,
    ];
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _errorMessage = 'اكتب كمية صحيحة أكبر من صفر.');
      return;
    }

    final quantityKg = _inputUnit == GrainUnit.ton
        ? GrainUnitConverter.tonsToKilograms(quantity)
        : quantity;

    Navigator.of(context).pop(
      _MovementFormResult(
        productId: _productId,
        movementType: _movementType,
        quantityKg: quantityKg,
        note: _noteController.text,
      ),
    );
  }
}

class _MovementFormResult {
  const _MovementFormResult({
    required this.productId,
    required this.movementType,
    required this.quantityKg,
    this.note,
  });

  final String productId;
  final StockMovementType movementType;
  final int quantityKg;
  final String? note;
}
