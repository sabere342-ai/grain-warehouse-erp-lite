import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_controller.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key, this.controller});

  final PurchaseController? controller;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  late final PurchaseController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        PurchaseController(
          purchaseRepository: AppRepositories.purchaseRepository,
          supplierRepository: AppRepositories.supplierRepository,
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
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض المشتريات.'));
    }

    final canCreate = user.permissions.canCreatePurchaseIntake;
    final canCancel = user.permissions.canCancelInvoice;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final canOpenForm = _controller.suppliers.isNotEmpty &&
            _controller.products.isNotEmpty &&
            canCreate;

        return ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('استلامات الشراء', style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        canCreate
                            ? 'استلام الحبوب من الموردين وزيادة المخزون بحركة مرحلة. الإلغاء للمالك فقط.'
                            : 'عرض استلامات الشراء فقط. تسجيل الاستلام وإلغاء المستندات للمالك.',
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
                    onPressed: canOpenForm
                        ? () => _showPurchaseForm(context, user: user)
                        : null,
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('تسجيل استلام حبوب'),
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
            else if (_controller.intakes.isEmpty)
              const PremiumCard(
                child: Text(
                  'لا توجد استلامات شراء مسجلة بعد. ستظهر هنا مستندات استلام الحبوب من الموردين.',
                ),
              )
            else
                ..._controller.intakes.reversed.map(
                (intake) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PurchaseIntakeCard(
                    intake: intake,
                    supplierName: _controller.displaySupplierName(intake),
                    productName: _controller.productName(intake.productId),
                    canCancel: canCancel,
                    onCancel: intake.isCancelled
                        ? null
                        : () => _confirmCancelPurchase(context, user, intake),
                  ),
                ),
              ),
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

  Future<void> _showPurchaseForm(
    BuildContext context, {
    required user,
  }) async {
    final draft = await showDialog<PurchaseIntakeDraft>(
      context: context,
      builder: (context) => _PurchaseFormDialog(
        suppliers: _controller.suppliers.where((supplier) {
          return supplier.isActive;
        }).toList(growable: false),
        products: _controller.products.where((product) {
          return product.isActive;
        }).toList(growable: false),
        userId: user.id,
      ),
    );

    if (draft == null) {
      return;
    }

    await _controller.createPurchaseIntake(user: user, draft: draft);
  }

  Future<void> _confirmCancelPurchase(
    BuildContext context,
    user,
    PurchaseIntake intake,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إلغاء استلام الشراء'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تحذير مهم: سيتم إنشاء حركة مخزون عكسية لإلغاء أثر هذا الاستلام. لن يتم حذف المستند الأصلي أو الحركة الأصلية، وسيظهر الإلغاء في سجل المستندات للمالك.',
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

    await _controller.cancelPurchaseIntake(
      user: user,
      purchaseIntakeId: intake.id,
      cancellationReason: reason,
    );
  }
}

class _PurchaseIntakeCard extends StatelessWidget {
  const _PurchaseIntakeCard({
    required this.intake,
    required this.supplierName,
    required this.productName,
    required this.canCancel,
    this.onCancel,
  });

  final PurchaseIntake intake;
  final String supplierName;
  final String productName;
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
              if (intake.isCancelled)
                Chip(
                  label: const Text('ملغي'),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('المورد: $supplierName'),
              Text('الكمية: ${_formatQuantity(intake.quantityKg)}'),
              Text(
                'السعر: ${MoneyUtils.formatPiastersAsEgp(intake.unitPricePiastersPerKg)} / كجم',
                textDirection: TextDirection.rtl,
              ),
              Text(
                'الإجمالي: ${MoneyUtils.formatPiastersAsEgp(intake.totalAmountPiasters)}',
              ),
            ],
          ),
          if (intake.notes != null) ...[
            const SizedBox(height: 8),
            Text(intake.notes!),
          ],
          if (intake.cancellation != null) ...[
            const SizedBox(height: 8),
            Text('سبب الإلغاء: ${intake.cancellation!.cancellationReason}'),
          ],
          if (canCancel && !intake.isCancelled) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء مستند الاستلام'),
              ),
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

class _PurchaseFormDialog extends StatefulWidget {
  const _PurchaseFormDialog({
    required this.suppliers,
    required this.products,
    required this.userId,
  });

  final List<Supplier> suppliers;
  final List<Product> products;
  final String userId;

  @override
  State<_PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _PurchaseFormDialogState extends State<_PurchaseFormDialog> {
  late String _supplierId = widget.suppliers.first.id;
  late String _productId = widget.products.first.id;
  GrainUnit _inputUnit = GrainUnit.kilogram;
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل استلام حبوب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _supplierId,
              decoration: const InputDecoration(labelText: 'المورد'),
              items: [
                for (final supplier in widget.suppliers)
                  DropdownMenuItem(
                    value: supplier.id,
                    child: Text(supplier.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _supplierId = value);
                }
              },
            ),
            const SizedBox(height: 12),
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      helperText: 'اكتب الكمية حسب الوحدة المختارة.',
                    ),
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
              controller: _unitPriceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'سعر الشراء بالجنيه / كجم',
                helperText: 'اكتب سعر شراء الكيلو بالجنيه.',
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات اختيارية',
                helperText: 'مثال: رقم النقلة أو اسم السائق.',
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
          child: const Text('حفظ الاستلام'),
        ),
      ],
    );
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim());
    final unitPrice = _tryParsePrice(_unitPriceController.text);
    if (quantity == null || quantity <= 0) {
      setState(() =>
          _errorMessage = 'اكتب كمية الاستلام، ويجب أن تكون أكبر من صفر.');
      return;
    }
    if (unitPrice == null || unitPrice <= 0) {
      setState(() => _errorMessage = 'اكتب سعر الشراء بالجنيه بشكل صحيح.');
      return;
    }

    final quantityKg = _inputUnit == GrainUnit.ton
        ? GrainUnitConverter.tonsToKilograms(quantity)
        : quantity;

    final selectedSupplier = widget.suppliers.firstWhere(
      (s) => s.id == _supplierId,
    );

    Navigator.of(context).pop(
      PurchaseIntakeDraft(
        supplierId: _supplierId,
        supplierName: selectedSupplier.name,
        supplierPhone: selectedSupplier.phone,
        supplierAddress: selectedSupplier.address,
        productId: _productId,
        quantityKg: quantityKg,
        entryUnit: _inputUnit,
        unitPricePiastersPerKg: unitPrice,
        createdByUserId: widget.userId,
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
