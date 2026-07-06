import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_controller.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.controller});

  final ProductController? controller;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ProductController(repository: AppRepositories.productRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.loadProducts(user);
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
    final canManage = user?.permissions.canManageProducts ?? false;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const PremiumCard(child: Text('يجب تسجيل الدخول لعرض الأصناف.'));
    }

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
                      Text('الأصناف', style: textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        canManage
                            ? 'إدارة أصناف الحبوب وأسعار البيع الإرشادية للكيلو.'
                            : 'عرض الأصناف النشطة فقط. إضافة وتعديل الأصناف للمالك فقط.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _showProductForm(context, user: user),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة صنف حبوب'),
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
                child: Text(
                  'لا توجد أصناف حبوب مسجلة بعد. أضف صنفا مثل قمح أو ذرة قبل تسجيل المخزون.',
                ),
              )
            else
              ..._controller.products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProductCard(
                    product: product,
                    canManage: canManage,
                    onEdit: () => _showProductForm(
                      context,
                      user: user,
                      product: product,
                    ),
                    onToggleActive: () => _controller.setProductActive(
                      user: user,
                      productId: product.id,
                      isActive: !product.isActive,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showProductForm(
    BuildContext context, {
    required user,
    Product? product,
  }) async {
    final draft = await showDialog<ProductDraft>(
      context: context,
      builder: (context) => _ProductFormDialog(product: product),
    );

    if (draft == null) {
      return;
    }

    if (product == null) {
      await _controller.createProduct(user: user, draft: draft);
    } else {
      await _controller.updateProduct(
        user: user,
        productId: product.id,
        draft: draft,
      );
    }
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canManage,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Product product;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

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
                child: Text(product.name, style: textTheme.titleLarge),
              ),
              _StatusChip(isActive: product.isActive),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoText('الوحدة', product.unit.labelAr),
              if (product.code != null) _InfoText('الكود', product.code!),
              _InfoText(
                'السعر الافتراضي',
                _formatOptionalPrice(product.defaultSalePricePiastersPerKg),
              ),
              _InfoText(
                'الحد الأدنى',
                _formatOptionalPrice(product.minimumSalePricePiastersPerKg),
              ),
              _InfoText(
                'سعر التكلفة',
                _formatOptionalPrice(product.referenceCostPricePiastersPerKg),
              ),
            ],
          ),
          if (product.notes != null) ...[
            const SizedBox(height: 8),
            Text(product.notes!),
          ],
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('تعديل'),
                ),
                OutlinedButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(
                    product.isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  label: Text(product.isActive ? 'إيقاف' : 'تفعيل'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatOptionalPrice(int? price) {
    if (price == null) {
      return 'غير محدد';
    }

    return '${MoneyUtils.formatPiastersAsEgp(price)} / كجم';
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(isActive ? 'نشط' : 'متوقف'),
      backgroundColor: isActive ? AppColors.surfaceAlt : AppColors.border,
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});

  final Product? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _defaultPriceController;
  late final TextEditingController _minimumPriceController;
  late final TextEditingController _referenceCostPriceController;
  late final TextEditingController _notesController;
  GrainUnit _unit = GrainUnit.kilogram;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _codeController = TextEditingController(text: product?.code ?? '');
    _defaultPriceController = TextEditingController(
      text: _priceText(product?.defaultSalePricePiastersPerKg),
    );
    _minimumPriceController = TextEditingController(
      text: _priceText(product?.minimumSalePricePiastersPerKg),
    );
    _referenceCostPriceController = TextEditingController(
      text: _priceText(product?.referenceCostPricePiastersPerKg),
    );
    _notesController = TextEditingController(text: product?.notes ?? '');
    _unit = product?.unit ?? GrainUnit.kilogram;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _defaultPriceController.dispose();
    _minimumPriceController.dispose();
    _referenceCostPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'إضافة صنف حبوب' : 'تعديل صنف حبوب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم الصنف',
                helperText: 'مثال: قمح محلي أو ذرة صفراء',
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'الكود اختياري'),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GrainUnit>(
              value: _unit,
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
                  setState(() => _unit = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _defaultPriceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'السعر الافتراضي بالجنيه / كجم اختياري',
                helperText: 'اتركه فارغا إذا لم يوجد سعر ثابت.',
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minimumPriceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'الحد الأدنى للبيع بالجنيه / كجم اختياري',
                helperText: 'يمنع حفظ البيع بسعر أقل من هذا الحد.',
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceCostPriceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'سعر التكلفة بالجنيه / كجم اختياري',
                helperText: 'تكلفة مرجعية للصنف وليست محرك تكلفة.',
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات اختيارية'),
              textDirection: TextDirection.rtl,
              maxLines: 2,
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

  void _submit() {
    final defaultPrice = _parseOptionalEgpPrice(_defaultPriceController.text);
    final minimumPrice = _parseOptionalEgpPrice(_minimumPriceController.text);
    final referenceCost =
        _parseOptionalEgpPrice(_referenceCostPriceController.text);

    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'اكتب اسم صنف الحبوب أولا.');
      return;
    }
    if (defaultPrice == -1 || minimumPrice == -1 || referenceCost == -1) {
      setState(
        () => _errorMessage =
            'اكتب السعر بالجنيه بالأرقام فقط، ويجب أن يكون أكبر من صفر.',
      );
      return;
    }
    if (defaultPrice != null &&
        minimumPrice != null &&
        minimumPrice > defaultPrice) {
      setState(
        () => _errorMessage =
            'الحد الأدنى للبيع لا يمكن أن يزيد عن السعر الافتراضي.',
      );
      return;
    }

    Navigator.of(context).pop(
      ProductDraft(
        name: _nameController.text,
        code: _codeController.text,
        unit: _unit,
        defaultSalePricePiastersPerKg: defaultPrice,
        minimumSalePricePiastersPerKg: minimumPrice,
        referenceCostPricePiastersPerKg: referenceCost,
        notes: _notesController.text,
      ),
    );
  }

  int? _parseOptionalEgpPrice(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      return MoneyUtils.parseEgpToPiasters(trimmed, allowZero: false);
    } on FormatException {
      return -1;
    } on ArgumentError {
      return -1;
    }
  }

  String _priceText(int? price) {
    return price == null ? '' : MoneyUtils.formatPiastersAsEgpNumber(price);
  }
}
