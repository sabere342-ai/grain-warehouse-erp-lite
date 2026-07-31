import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';

const int _maxStockTakeQuantityKg = 9223372036854775807;
const String _stockTakeAdjustmentNote = 'تسوية جرد المخزون';

class StockTakeScreen extends StatefulWidget {
  const StockTakeScreen({super.key, this.controller});

  final InventoryController? controller;

  @override
  State<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends State<StockTakeScreen> {
  late final InventoryController _controller;
  late final bool _ownsController;
  final Map<String, TextEditingController> _actualControllers = {};
  final Map<String, TextEditingController> _surplusCostControllers = {};
  final Map<String, TextEditingController> _surplusEvidenceControllers = {};
  String? _errorMessage;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        InventoryController(
          inventoryRepository: AppRepositories.inventoryRepository,
          productCatalogReadRepository:
              AppRepositories.productCatalogReadRepository,
          inventoryValuationRepository:
              AppRepositories.inventoryValuationRepository,
          financialAccountRepository:
              AppRepositories.financialAccountRepository,
          auditLogRepository: AppRepositories.auditLogRepository,
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
    for (final c in _actualControllers.values) {
      c.dispose();
    }
    for (final c in _surplusCostControllers.values) {
      c.dispose();
    }
    for (final c in _surplusEvidenceControllers.values) {
      c.dispose();
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (user == null) {
      return const PremiumCard(child: Text('يجب تسجيل الدخول.'));
    }

    if (!user.permissions.canCreateStockAdjustment) {
      return const PremiumCard(
        child: Text('هذه الصفحة متاحة للمالك فقط.'),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            GhalalPageHeader(
              title: 'جرد المخزون',
              subtitle:
                  'أدخل الكمية الفعلية التي تم عدّها، وسيقوم النظام بحساب الفرق وتسجيل حركة تسوية فقط عند وجود فرق.',
              icon: Icons.balance_rounded,
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
              backButtonKey: const ValueKey('stock-take-back-button'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_controller.isLoading)
              const GhalalLoadingState(label: 'جاري تحميل بيانات المخزون...')
            else if (_controller.products.isEmpty)
              const GhalalEmptyState(
                title: 'لا توجد أصناف نشطة',
                message: 'أضف صنف حبوب أولاً لبدء الجرد.',
                icon: Icons.inventory_2_outlined,
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = AppSpacing.md;
                  final columns = constraints.maxWidth >= 980 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final product in _controller.products)
                        SizedBox(
                          width: width,
                          child: _buildProductRow(product, textTheme),
                        ),
                    ],
                  );
                },
              ),
              if (_controller.products.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: FilledButton.icon(
                    onPressed: _isApplying ? null : _applyStockTake,
                    icon: _isApplying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _isApplying ? 'جاري تطبيق التسوية...' : 'تطبيق التسوية',
                    ),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildProductRow(
      ProductCatalogReadModel product, TextTheme textTheme) {
    final productId = product.id;
    final balanceKg = _controller.balanceForProduct(productId);
    final actualController = _controllerFor(productId);
    final actualText = actualController.text.trim();
    final actualKg = int.tryParse(actualText);
    final variance = actualKg != null ? actualKg - balanceKg : 0;
    final hasVariance = actualKg != null && variance != 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد النظامي: $balanceKg كجم',
                        style: textTheme.bodyMedium,
                      ),
                      if (actualKg != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الفرق: ${variance > 0 ? '+' : ''}$variance كجم',
                          style: textTheme.bodyMedium?.copyWith(
                            color: hasVariance
                                ? (variance > 0
                                    ? AppColors.olive
                                    : Theme.of(context).colorScheme.error)
                                : AppColors.mutedText,
                            fontWeight: hasVariance
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: actualController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'العد الفعلي',
                      isDense: true,
                    ),
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (variance > 0 && _controller.isProfitabilityActivated) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _surplusCostControllerFor(productId),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'تكلفة الفائض بالقروش لكل كجم *',
                  helperText: 'قيمة صحيحة من فاتورة أو دليل موثوق',
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _surplusEvidenceControllerFor(productId),
                decoration: const InputDecoration(
                  labelText: 'مرجع دليل تكلفة الفائض *',
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextEditingController _controllerFor(String productId) {
    if (!_actualControllers.containsKey(productId)) {
      _actualControllers[productId] = TextEditingController();
    }
    return _actualControllers[productId]!;
  }

  TextEditingController _surplusCostControllerFor(String productId) =>
      _surplusCostControllers.putIfAbsent(
        productId,
        TextEditingController.new,
      );

  TextEditingController _surplusEvidenceControllerFor(String productId) =>
      _surplusEvidenceControllers.putIfAbsent(
        productId,
        TextEditingController.new,
      );

  Future<void> _applyStockTake() async {
    final user = AuthScope.of(context).state.user;
    if (user == null) return;

    final adjustments = <_StockTakeAdjustment>[];
    setState(() => _errorMessage = null);

    for (final product in _controller.products) {
      final productId = product.id;
      final text = _actualControllers[productId]?.text.trim() ?? '';
      if (text.isEmpty) {
        setState(() {
          _errorMessage = 'أدخل الكمية الفعلية لكل صنف قبل تطبيق تسوية الجرد.';
        });
        return;
      }

      final actualKg = int.tryParse(text);
      if (actualKg == null ||
          actualKg < 0 ||
          actualKg > _maxStockTakeQuantityKg) {
        setState(() {
          _errorMessage =
              'الكمية غير صحيحة لـ ${product.name}. أدخل رقماً صحيحاً غير سالب.';
        });
        return;
      }

      final balanceKg = _controller.balanceForProduct(productId);
      final variance = actualKg - balanceKg;
      if (variance == 0) continue;

      int? surplusCostQirshPerKg;
      String? surplusEvidenceReference;
      if (variance > 0 && _controller.isProfitabilityActivated) {
        surplusCostQirshPerKg = int.tryParse(
          _surplusCostControllers[productId]?.text.trim() ?? '',
        );
        surplusEvidenceReference =
            _surplusEvidenceControllers[productId]?.text.trim();
        if (surplusCostQirshPerKg == null ||
            surplusCostQirshPerKg <= 0 ||
            surplusEvidenceReference == null ||
            surplusEvidenceReference.isEmpty) {
          setState(() {
            _errorMessage =
                'أدخل تكلفة صحيحة ومرجع دليل موثوق لفائض ${product.name}.';
          });
          return;
        }
      }

      adjustments.add(_StockTakeAdjustment(
        product: product,
        productId: productId,
        balanceKg: balanceKg,
        actualKg: actualKg,
        variance: variance,
        surplusUnitCostQirshPerKg: surplusCostQirshPerKg,
        surplusEvidenceReference: surplusEvidenceReference,
      ));
    }

    if (adjustments.isEmpty) {
      setState(() {
        _errorMessage =
            'لا يوجد فرق للتسوية. أدخل العد الفعلي للأصناف المطلوب جردها.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _StockTakeConfirmationDialog(
        adjustments: adjustments,
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    setState(() => _isApplying = true);

    int successCount = 0;
    int failCount = 0;
    for (final adj in adjustments) {
      final quantityKg = adj.variance.abs();
      final success = adj.variance > 0
          ? await _controller.createManualIncrease(
              user: user,
              productId: adj.productId,
              quantityKg: quantityKg,
              note: _stockTakeAdjustmentNote,
              unitCostQirshPerKg: adj.surplusUnitCostQirshPerKg,
              evidenceReference: adj.surplusEvidenceReference,
              isStocktake: true,
            )
          : await _controller.createManualDecrease(
              user: user,
              productId: adj.productId,
              quantityKg: quantityKg,
              note: _stockTakeAdjustmentNote,
              isStocktake: true,
            );

      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    if (!mounted) return;

    setState(() {
      _isApplying = false;
      if (failCount == 0) {
        _errorMessage = null;
        for (final c in _actualControllers.values) {
          c.clear();
        }
        for (final c in _surplusCostControllers.values) {
          c.clear();
        }
        for (final c in _surplusEvidenceControllers.values) {
          c.clear();
        }
      }
    });

    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسوية $successCount صنف بنجاح.'),
          backgroundColor: AppColors.olive,
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'تم تسوية $successCount صنف بنجاح، فشل $failCount صنف.';
      });
    }
  }
}

class _StockTakeAdjustment {
  const _StockTakeAdjustment({
    required this.product,
    required this.productId,
    required this.balanceKg,
    required this.actualKg,
    required this.variance,
    this.surplusUnitCostQirshPerKg,
    this.surplusEvidenceReference,
  });

  final ProductCatalogReadModel product;
  final String productId;
  final int balanceKg;
  final int actualKg;
  final int variance;
  final int? surplusUnitCostQirshPerKg;
  final String? surplusEvidenceReference;
}

class _StockTakeConfirmationDialog extends StatelessWidget {
  const _StockTakeConfirmationDialog({required this.adjustments});

  final List<_StockTakeAdjustment> adjustments;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GhalalResponsiveDialog(
      title: const Text('تأكيد تسوية الجرد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سيتم إنشاء حركات المخزون التالية:',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final adj in adjustments) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    adj.variance > 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                    color: adj.variance > 0
                        ? AppColors.olive
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${adj.product.name}: '
                      'الرصيد ${adj.balanceKg} ← الفعلي ${adj.actualKg} كجم '
                      '(${adj.variance > 0 ? "زيادة" : "نقص"} ${adj.variance.abs()} كجم)',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'ملاحظة: يتم تسجيل زيادة يدوية أو نقص يدوي حسب فرق كل صنف، مع حفظ سبب "$_stockTakeAdjustmentNote".',
            style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('تأكيد التسوية'),
        ),
      ],
    );
  }
}
