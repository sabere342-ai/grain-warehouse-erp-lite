import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class DocumentHistoryScreen extends StatefulWidget {
  const DocumentHistoryScreen({super.key, this.controller});

  final DocumentHistoryController? controller;

  @override
  State<DocumentHistoryScreen> createState() => _DocumentHistoryScreenState();
}

class _DocumentHistoryScreenState extends State<DocumentHistoryScreen> {
  late final DocumentHistoryController _controller;
  late final bool _ownsController;
  final _searchController = TextEditingController();
  final _productController = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  DocumentHistoryType? _type;
  DocumentHistoryStatus? _status;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        DocumentHistoryController(
          repository: AppRepositories.documentHistoryRepository,
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
    _productController.dispose();
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
        child: Text('يجب تسجيل الدخول لعرض سجل المستندات.'),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView(
          children: [
            Text('سجل المستندات', style: textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'بحث ومراجعة مستندات الشراء والبيع المرحلة وحالة الإلغاء.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 16),
            _HistoryFilters(
              searchController: _searchController,
              productController: _productController,
              from: _from,
              to: _to,
              type: _type,
              status: _status,
              onFromChanged: (value) => setState(() => _from = value),
              onToChanged: (value) => setState(() => _to = value),
              onTypeChanged: (value) => setState(() => _type = value),
              onStatusChanged: (value) => setState(() => _status = value),
              onApply: () => _applyFilter(user),
              onClear: () => _clearFilter(user),
            ),
            const SizedBox(height: 16),
            if (_controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_controller.entries.isEmpty)
              const PremiumCard(
                child: Text('لا توجد مستندات مطابقة للفلاتر الحالية.'),
              )
            else
              ..._controller.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DocumentHistoryCard(
                    entry: entry,
                    showAudit: _controller.canViewOwnerAudit,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _applyFilter(user) async {
    await _controller.applyFilter(
      user: user,
      filter: DocumentHistoryFilter(
        from: _from == null ? null : _startOfDay(_from!),
        to: _to == null ? null : _endOfDay(_to!),
        type: _type,
        status: _status,
        query: _searchController.text,
        productName: _productController.text,
      ),
    );
  }

  Future<void> _clearFilter(user) async {
    setState(() {
      _from = null;
      _to = null;
      _type = null;
      _status = null;
      _searchController.clear();
      _productController.clear();
    });
    await _controller.applyFilter(
      user: user,
      filter: const DocumentHistoryFilter(),
    );
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999, 999);
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.searchController,
    required this.productController,
    required this.from,
    required this.to,
    required this.type,
    required this.status,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController searchController;
  final TextEditingController productController;
  final DateTime? from;
  final DateTime? to;
  final DocumentHistoryType? type;
  final DocumentHistoryStatus? status;
  final ValueChanged<DateTime?> onFromChanged;
  final ValueChanged<DateTime?> onToChanged;
  final ValueChanged<DocumentHistoryType?> onTypeChanged;
  final ValueChanged<DocumentHistoryStatus?> onStatusChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'بحث برقم أو معرف المستند',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: productController,
              decoration: const InputDecoration(
                labelText: 'اسم الصنف',
                prefixIcon: Icon(Icons.inventory_2_rounded),
              ),
            ),
          ),
          _DateButton(
            label: 'من',
            value: from,
            onChanged: onFromChanged,
          ),
          _DateButton(
            label: 'إلى',
            value: to,
            onChanged: onToChanged,
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<DocumentHistoryType?>(
              value: type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع المستند'),
              items: [
                const DropdownMenuItem(value: null, child: Text('الكل')),
                for (final value in DocumentHistoryType.values)
                  DropdownMenuItem(value: value, child: Text(value.labelAr)),
              ],
              onChanged: onTypeChanged,
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<DocumentHistoryStatus?>(
              value: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الحالة'),
              items: [
                const DropdownMenuItem(value: null, child: Text('الكل')),
                for (final value in DocumentHistoryStatus.values)
                  DropdownMenuItem(value: value, child: Text(value.labelAr)),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          FilledButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.filter_alt_rounded),
            label: const Text('تطبيق'),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
            label: const Text('مسح'),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        onChanged(picked);
      },
      icon: const Icon(Icons.calendar_month_rounded),
      label: Text('$label: ${value == null ? 'الكل' : _formatDate(value!)}'),
    );
  }
}

class _DocumentHistoryCard extends StatelessWidget {
  const _DocumentHistoryCard({
    required this.entry,
    required this.showAudit,
  });

  final DocumentHistoryEntry entry;
  final bool showAudit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      padding: const EdgeInsets.all(8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(entry.productName, style: textTheme.titleMedium),
        subtitle: Text('${entry.type.labelAr} - ${entry.id}'),
        trailing: Chip(
          label: Text(entry.status.labelAr),
          backgroundColor: entry.isCancelled
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.secondaryContainer,
        ),
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Text('الكمية: ${entry.quantityKg} كجم'),
              if (entry.unitPricePiastersPerKg != null)
                Text('السعر: ${entry.unitPricePiastersPerKg} قرش/كجم'),
              if (entry.totalPiasters != null)
                Text(
                  'الإجمالي: '
                  '${MoneyUtils.formatPiastersAsEgp(entry.totalPiasters!)}',
                ),
              Text('التاريخ: ${_formatDateTime(entry.createdAt)}'),
              Text(
                  'أنشأه: ${entry.createdByUserName ?? entry.createdByUserId}'),
            ],
          ),
          if (entry.notes != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(entry.notes!),
            ),
          ],
          const SizedBox(height: 10),
          _MovementLine(
              label: 'الحركة الأصلية', movement: entry.originalMovement),
          if (entry.reversalMovements.isNotEmpty)
            for (final movement in entry.reversalMovements)
              _MovementLine(label: 'حركة الإلغاء', movement: movement),
          if (showAudit && entry.cancellation != null) ...[
            const Divider(height: 22),
            _AuditDetails(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _MovementLine extends StatelessWidget {
  const _MovementLine({
    required this.label,
    required this.movement,
  });

  final String label;
  final StockMovement? movement;

  @override
  Widget build(BuildContext context) {
    final visibleMovement = movement;
    if (visibleMovement == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text('$label: غير متاح'),
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        '$label: ${visibleMovement.id} - '
        '${visibleMovement.movementType.labelAr} - '
        '${visibleMovement.quantityKg} كجم',
      ),
    );
  }
}

class _AuditDetails extends StatelessWidget {
  const _AuditDetails({required this.entry});

  final DocumentHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final cancellation = entry.cancellation!;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سبب الإلغاء: ${cancellation.cancellationReason}'),
          Text('وقت الإلغاء: ${_formatDateTime(cancellation.cancelledAt)}'),
          Text('ألغاه: ${cancellation.cancelledByUserId}'),
          Text('معرف المستند الأصلي: ${cancellation.originalDocumentId}'),
          Text(
            'حركات العكس: ${cancellation.reversalMovementIds.join(', ')}',
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_formatDate(local)} ${_twoDigits(local.hour)}:'
      '${_twoDigits(local.minute)}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
