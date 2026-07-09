import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_controller.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_purchase_invoice_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class SupplierPurchasesScreen extends StatefulWidget {
  const SupplierPurchasesScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  final String supplierId;
  final String supplierName;

  @override
  State<SupplierPurchasesScreen> createState() =>
      _SupplierPurchasesScreenState();
}

class _SupplierPurchasesScreenState extends State<SupplierPurchasesScreen> {
  late final PurchaseController _controller;
  final SupplierAccountRepository _accountRepo =
      AppRepositories.supplierAccountRepository;
  int _balanceQirsh = 0;
  bool _balanceLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = PurchaseController(
      purchaseRepository: AppRepositories.purchaseRepository,
      supplierRepository: AppRepositories.supplierRepository,
      productRepository: AppRepositories.productRepository,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.load(user);
        _loadBalance();
      }
    });
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _accountRepo.balanceForSupplier(widget.supplierId);
      if (!mounted) return;
      setState(() {
        _balanceQirsh = balance;
        _balanceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _balanceLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('مشتريات ${widget.supplierName}'),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final supplierIntakes = _controller.intakes
              .where((intake) => intake.supplierId == widget.supplierId)
              .toList(growable: false);

          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (supplierIntakes.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: PremiumCard(
                child: Text('لا توجد مشتريات مسجلة لهذا المورد بعد.'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_balanceLoading) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PremiumCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'الرصيد المستحق: ',
                            style: textTheme.titleMedium,
                          ),
                          Text(
                            MoneyUtils.formatPiastersAsEgp(_balanceQirsh),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: _balanceQirsh > 0
                                  ? AppColors.text
                                  : AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              ...supplierIntakes.reversed.map((intake) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PremiumCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _controller.productName(intake.productId),
                              style: textTheme.titleLarge,
                            ),
                          ),
                          if (intake.isCancelled)
                            Chip(
                              label: const Text('ملغي'),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('الكمية: ${intake.quantityKg} كجم'),
                      Text(
                        'السعر: ${MoneyUtils.formatPiastersAsEgp(intake.unitPricePiastersPerKg)} / كجم',
                      ),
                      Text(
                        'الإجمالي: ${MoneyUtils.formatPiastersAsEgp(intake.totalAmountPiasters)}',
                      ),
                      Text(
                        'التاريخ: ${_formatDate(intake.createdAt)}',
                      ),
                      if (intake.notes != null) ...[
                        const SizedBox(height: 4),
                        Text(intake.notes!),
                      ],
                      if (intake.cancellation != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'سبب الإلغاء: ${intake.cancellation!.cancellationReason}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    PrintablePurchaseInvoiceView(
                                  purchase: intake,
                                  supplierName: widget.supplierName,
                                  productName: _controller
                                      .productName(intake.productId),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.preview_rounded),
                          label:
                              const Text('معاينة الفاتورة'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
