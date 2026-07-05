import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
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
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض المخزون.'));
    }

    final canAdjust = user.permissions.canCreateStockAdjustment;

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
                      Text('المخزون', style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'الأرصدة محسوبة من حركات المخزون فقط.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canAdjust)
                  FilledButton.icon(
                    onPressed: _controller.products.isEmpty
                        ? null
                        : () => _showMovementForm(context, user: user),
                    icon: const Icon(Icons.add_chart_rounded),
                    label: const Text('إضافة حركة'),
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
            else if (_controller.products.isEmpty)
              const PremiumCard(
                child: Text('لا توجد أصناف نشطة لعرض المخزون.'),
              )
            else
              ..._controller.products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InventoryProductCard(
                    product: product,
                    balanceKg: _controller.balanceForProduct(product.id),
                    movements: _controller.movementsForProduct(product.id),
                  ),
                ),
              ),
          ],
        );
      },
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
    }
  }
}

class _InventoryProductCard extends StatelessWidget {
  const _InventoryProductCard({
    required this.product,
    required this.balanceKg,
    required this.movements,
  });

  final Product product;
  final int balanceKg;
  final List<StockMovement> movements;

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
            const Text('لا توجد حركات لهذا الصنف بعد.')
          else
            ...movements.reversed.take(4).map(
                  (movement) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${movement.movementType.labelAr}: ${_formatQuantity(movement.quantityKg)}',
                    ),
                  ),
                ),
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
    return AlertDialog(
      title: const Text('إضافة حركة مخزون'),
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
                  setState(() {
                    _productId = value;
                    if (!_availableMovementTypes().contains(_movementType)) {
                      _movementType = _availableMovementTypes().first;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StockMovementType>(
              value: _movementType,
              decoration: const InputDecoration(labelText: 'نوع الحركة'),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الكمية'),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'سبب أو ملاحظة'),
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
          child: const Text('حفظ'),
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
      setState(() => _errorMessage = 'ادخل كمية صحيحة موجبة.');
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
