import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_search_field.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';

const String _stockTakeAdjustmentNote = 'تسوية جرد المخزون';

class StockAdjustmentReportScreen extends StatefulWidget {
  const StockAdjustmentReportScreen({super.key, this.controller});

  final InventoryController? controller;

  @override
  State<StockAdjustmentReportScreen> createState() =>
      _StockAdjustmentReportScreenState();
}

class _StockAdjustmentReportScreenState
    extends State<StockAdjustmentReportScreen> {
  late final InventoryController _controller;
  late final bool _ownsController;
  final _searchController = TextEditingController();
  _AdjustmentFilter _filter = _AdjustmentFilter.all;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        InventoryController(
          inventoryRepository: AppRepositories.inventoryRepository,
          productRepository: AppRepositories.productRepository,
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
    _searchController.dispose();
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
        child: Text('هذا التقرير متاح للمالك فقط.'),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final rows = _filteredRows();
        final totals = _AdjustmentTotals.fromRows(rows);

        return ListView(
          key: const Key('stock-adjustment-report-list'),
          children: [
            GhalalPageHeader(
              title: 'تقرير تسويات المخزون',
              subtitle:
                  'يعرض هذا التقرير حركات الزيادة والنقص اليدوية الناتجة عن تسويات المخزون، ولا يقوم بتعديل الكميات.',
              icon: Icons.fact_check_rounded,
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
              backButtonKey:
                  const ValueKey('stock-adjustment-report-back-button'),
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _controller.load(user),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تحديث'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _Filters(
              searchController: _searchController,
              filter: _filter,
              onSearchChanged: (_) => setState(() {}),
              onFilterChanged: (value) {
                if (value != null) {
                  setState(() => _filter = value);
                }
              },
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
              const GhalalLoadingState(label: 'جاري تحميل التقرير...')
            else ...[
              _TotalsCard(totals: totals),
              const SizedBox(height: 12),
              const PremiumCard(
                child: Text(
                  'أرصدة قبل/بعد الحركة غير متوفرة في بيانات الحركة الحالية، لذلك لا يعرضها التقرير حتى لا يخترع أرقاما تاريخية.',
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const GhalalEmptyState(
                  title: 'لا توجد تسويات مخزون مسجلة',
                  message: 'لم تُجرِ أي تسوية مخزون يدوية حتى الآن.',
                  icon: Icons.fact_check_outlined,
                )
              else
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AdjustmentCard(row: row),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  List<_AdjustmentRow> _filteredRows() {
    final productsById = {
      for (final product in _controller.products) product.id: product,
    };
    final query = _searchController.text.trim().toLowerCase();

    final rows = _controller.movements
        .where(_isManualAdjustment)
        .where((movement) => _matchesFilter(movement))
        .map(
          (movement) => _AdjustmentRow(
            movement: movement,
            productName:
                productsById[movement.productId]?.name ?? 'صنف غير معروف',
          ),
        )
        .where((row) {
      if (query.isEmpty) return true;
      return row.productName.toLowerCase().contains(query) ||
          row.note.toLowerCase().contains(query);
    }).toList(growable: false);

    return [...rows]..sort(
        (a, b) {
          final createdAt =
              b.movement.createdAt.compareTo(a.movement.createdAt);
          if (createdAt != 0) return createdAt;
          return b.movement.id.compareTo(a.movement.id);
        },
      );
  }

  bool _isManualAdjustment(StockMovement movement) {
    return !movement.isVoided &&
        (movement.movementType == StockMovementType.manualIncrease ||
            movement.movementType == StockMovementType.manualDecrease);
  }

  bool _matchesFilter(StockMovement movement) {
    switch (_filter) {
      case _AdjustmentFilter.all:
        return true;
      case _AdjustmentFilter.increase:
        return movement.movementType == StockMovementType.manualIncrease;
      case _AdjustmentFilter.decrease:
        return movement.movementType == StockMovementType.manualDecrease;
      case _AdjustmentFilter.stockTakeOnly:
        return movement.note?.trim() == _stockTakeAdjustmentNote;
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.filter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final _AdjustmentFilter filter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_AdjustmentFilter?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: GhalalSearchField(
            key: const Key('stock-adjustment-search-field'),
            controller: searchController,
            hintText: 'بحث بالصنف أو الملاحظة',
            onChanged: onSearchChanged,
          ),
        ),
        SizedBox(
          width: 340,
          child: DropdownButtonFormField<_AdjustmentFilter>(
            key: const Key('stock-adjustment-filter'),
            value: filter,
            decoration: const InputDecoration(labelText: 'نوع الحركة'),
            items: [
              for (final item in _AdjustmentFilter.values)
                DropdownMenuItem(
                  value: item,
                  child: Text(item.labelAr),
                ),
            ],
            onChanged: onFilterChanged,
          ),
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});

  final _AdjustmentTotals totals;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إجماليات التسويات',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _MetricLine('إجمالي الزيادة اليدوية', '${totals.increaseKg} كجم'),
          _MetricLine('إجمالي النقص اليدوي', '${totals.decreaseKg} كجم'),
          _MetricLine(
            'صافي التسوية',
            '${totals.netKg >= 0 ? '+' : ''}${totals.netKg} كجم',
          ),
        ],
      ),
    );
  }
}

class _AdjustmentCard extends StatelessWidget {
  const _AdjustmentCard({required this.row});

  final _AdjustmentRow row;

  @override
  Widget build(BuildContext context) {
    final movement = row.movement;
    final isIncrease =
        movement.movementType == StockMovementType.manualIncrease;

    return PremiumCard(
      key: ValueKey('stock-adjustment-card-${row.note}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncrease
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isIncrease
                    ? AppColors.olive
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.productName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${movement.quantityKg} كجم',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetricLine('التاريخ', _formatDateTime(movement.createdAt)),
          _MetricLine('نوع الحركة', movement.movementType.labelAr),
          _MetricLine('السبب / الملاحظة', row.note),
          Text(
            key: ValueKey('stock-adjustment-before-after-${row.note}'),
            'الرصيد قبل/بعد الحركة: غير متوفر في بيانات الحركة الحالية.',
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentRow {
  const _AdjustmentRow({
    required this.movement,
    required this.productName,
  });

  final StockMovement movement;
  final String productName;

  String get note => movement.note?.trim().isNotEmpty == true
      ? movement.note!.trim()
      : 'بدون ملاحظة';
}

class _AdjustmentTotals {
  const _AdjustmentTotals({
    required this.increaseKg,
    required this.decreaseKg,
  });

  factory _AdjustmentTotals.fromRows(List<_AdjustmentRow> rows) {
    var increaseKg = 0;
    var decreaseKg = 0;
    for (final row in rows) {
      switch (row.movement.movementType) {
        case StockMovementType.manualIncrease:
          increaseKg += row.movement.quantityKg;
        case StockMovementType.manualDecrease:
          decreaseKg += row.movement.quantityKg;
        case StockMovementType.openingBalance:
        case StockMovementType.purchaseIntake:
        case StockMovementType.sale:
        case StockMovementType.purchaseCancellation:
        case StockMovementType.saleCancellation:
          break;
      }
    }

    return _AdjustmentTotals(
      increaseKg: increaseKg,
      decreaseKg: decreaseKg,
    );
  }

  final int increaseKg;
  final int decreaseKg;

  int get netKg => increaseKg - decreaseKg;
}

enum _AdjustmentFilter {
  all('الكل'),
  increase('زيادة يدوية'),
  decrease('نقص يدوي'),
  stockTakeOnly('تسويات الجرد فقط');

  const _AdjustmentFilter(this.labelAr);

  final String labelAr;
}
