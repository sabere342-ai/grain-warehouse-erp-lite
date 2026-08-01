import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_responsive_dialog.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class ProfitabilityReportScreen extends StatefulWidget {
  const ProfitabilityReportScreen({super.key});

  @override
  State<ProfitabilityReportScreen> createState() =>
      _ProfitabilityReportScreenState();
}

class _ProfitabilityReportScreenState extends State<ProfitabilityReportScreen> {
  ProfitabilityReport? _report;
  bool _loading = true;
  String? _error;
  DateTime? _activationDate;
  DateTime? _selectedStart;
  DateTime? _selectedEnd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_report == null && _loading) _load();
  }

  Future<void> _load() async {
    final user = AuthScope.of(context).state.user;
    if (user == null || !user.permissions.canViewFinancialReports) {
      setState(() {
        _loading = false;
        _error = 'ليس لديك صلاحية عرض التقارير المالية.';
      });
      return;
    }
    try {
      final activation =
          await AppRepositories.inventoryValuationRepository.getActivation();
      final activationDate = activation.activationDate;
      final start = _selectedStart ?? activationDate ?? DateTime(2000);
      final inclusiveEnd = _selectedEnd ?? DateTime.now();
      final report = await AppRepositories.profitabilityReportService.build(
        user: user,
        start: start,
        end: DateTime(
          inclusiveEnd.year,
          inclusiveEnd.month,
          inclusiveEnd.day + 1,
        ),
      );
      if (mounted) {
        setState(() {
          _activationDate = activationDate;
          _selectedStart ??= activationDate;
          _selectedEnd ??= inclusiveEnd;
          _report = report;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const GhalalPageHeader(
            title: 'الربحية التشغيلية',
            subtitle:
                'إيراد المبيعات ناقص تكلفة البضاعة المباعة والمصروفات التشغيلية فقط.',
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            PremiumCard(child: Text(_error!))
          else if (_report?.isAvailable != true)
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _report?.messageAr ??
                        ProfitabilityReport.unavailableBeforeActivationAr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا يعيد النظام تشغيل المشتريات القديمة ولا يخمّن تكلفة تاريخية. '
                    'ابدأ بعد جرد فعلي وتكلفة موثقة لكل صنف.',
                  ),
                  if (user != null && user.permissions.canAccessSettings) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _activate(user),
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('تفعيل الربحية من جرد فعلي'),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            _PeriodSelector(
              start: _selectedStart!,
              end: _selectedEnd!,
              onChooseStart: _chooseStart,
              onChooseEnd: _chooseEnd,
            ),
            const SizedBox(height: AppSpacing.md),
            _AvailableReport(report: _report!),
          ],
        ],
      ),
    );
  }

  Future<void> _activate(AppUser user) async {
    final products = await AppRepositories.productCatalogReadRepository
        .listProductCatalog(includeInactive: true);
    final balances =
        await AppRepositories.inventoryRepository.allProductBalancesKg();
    if (!mounted) return;
    final input = await showDialog<_ActivationInput>(
      context: context,
      builder: (_) => _ActivationDialog(
        products: products,
        balances: balances,
      ),
    );
    if (input == null) return;
    setState(() => _loading = true);
    try {
      await AppRepositories.profitabilityActivationService.activate(
        user: user,
        activationDate: input.activationDate,
        evidenceNote: input.evidenceNote,
        openings: input.openings,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _chooseStart() async {
    final activationDate = _activationDate;
    final currentStart = _selectedStart;
    final currentEnd = _selectedEnd;
    if (activationDate == null || currentStart == null || currentEnd == null) {
      return;
    }
    final value = await showDatePicker(
      context: context,
      initialDate: currentStart,
      firstDate: activationDate,
      lastDate: currentEnd,
    );
    if (value == null || !mounted) return;
    setState(() {
      _selectedStart = value;
      _loading = true;
    });
    await _load();
  }

  Future<void> _chooseEnd() async {
    final currentStart = _selectedStart;
    final currentEnd = _selectedEnd;
    if (currentStart == null || currentEnd == null) return;
    final today = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: currentEnd,
      firstDate: currentStart,
      lastDate: today,
    );
    if (value == null || !mounted) return;
    setState(() {
      _selectedEnd = value;
      _loading = true;
    });
    await _load();
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.start,
    required this.end,
    required this.onChooseStart,
    required this.onChooseEnd,
  });

  final DateTime start;
  final DateTime end;
  final VoidCallback onChooseStart;
  final VoidCallback onChooseEnd;

  @override
  Widget build(BuildContext context) => PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فترة التقرير',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onChooseStart,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text('من ${_formatDate(start)}'),
                ),
                OutlinedButton.icon(
                  onPressed: onChooseEnd,
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text('إلى ${_formatDate(end)}'),
                ),
              ],
            ),
          ],
        ),
      );

  static String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _AvailableReport extends StatelessWidget {
  const _AvailableReport({required this.report});
  final ProfitabilityReport report;

  @override
  Widget build(BuildContext context) {
    final values = <(String, int?)>[
      ('إيراد المبيعات', report.salesRevenueQirsh),
      ('منه محصل/نقدي', report.cashRevenueQirsh),
      ('منه آجل', report.creditRevenueQirsh),
      ('تكلفة البضاعة المباعة', report.costOfGoodsSoldQirsh),
      ('مجمل الربح', report.grossProfitQirsh),
      ('المصروفات التشغيلية', report.operatingExpensesQirsh),
      ('صافي الربح التشغيلي', report.netOperatingProfitQirsh),
    ];
    return Column(
      children: [
        if (report.activation.isSyntheticTestActivated)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumCard(
              key: const Key('synthetic-profitability-test-warning'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.science_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'بيانات اختبار اصطناعية فقط — ليست ربحية إنتاجية ولا يجوز اعتمادها كبيانات فعلية.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumCard(
              child: Row(
                children: [
                  Expanded(child: Text(value.$1)),
                  Text(
                    MoneyUtils.formatPiastersAsEgp(value.$2 ?? 0),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        PremiumCard(
          child: Text(
            report.cashWarning,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}

class _ActivationDialog extends StatefulWidget {
  const _ActivationDialog({required this.products, required this.balances});
  final List<ProductCatalogReadModel> products;
  final Map<String, int> balances;

  @override
  State<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<_ActivationDialog> {
  late DateTime _date = DateTime.now();
  final _evidenceNote = TextEditingController();
  final _quantity = <String, TextEditingController>{};
  final _cost = <String, TextEditingController>{};
  final _evidence = <String, TextEditingController>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final product in widget.products) {
      _quantity[product.id] = TextEditingController(
        text: '${widget.balances[product.id] ?? 0}',
      );
      _cost[product.id] = TextEditingController();
      _evidence[product.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _evidenceNote.dispose();
    for (final controller in [
      ..._quantity.values,
      ..._cost.values,
      ..._evidence.values
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GhalalResponsiveDialog(
        isDirty: true,
        title: const Text('تفعيل الربحية — قرار مالك غير قابل للتخمين'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text('تاريخ التفعيل: ${_formatDate(_date)}'),
                ),
                TextField(
                  controller: _evidenceNote,
                  decoration: const InputDecoration(
                    labelText: 'مرجع الجرد الفعلي واعتماد المالك *',
                  ),
                ),
                const SizedBox(height: 12),
                for (final product in widget.products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _quantity[product.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الكمية الفعلية كجم *',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _cost[product.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'التكلفة قرش/كجم *',
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _evidence[product.id],
                            decoration: const InputDecoration(
                              labelText: 'دليل التكلفة الموثوق *',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('اعتماد التفعيل'),
          ),
        ],
      );

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _date = value);
  }

  void _submit() {
    if (_evidenceNote.text.trim().isEmpty) {
      setState(() => _error = 'مرجع الجرد واعتماد المالك مطلوب.');
      return;
    }
    final openings = <OpeningValuationInput>[];
    for (final product in widget.products) {
      final quantity = int.tryParse(_quantity[product.id]!.text.trim());
      final cost = int.tryParse(_cost[product.id]!.text.trim());
      final evidence = _evidence[product.id]!.text.trim();
      if (quantity == null ||
          quantity < 0 ||
          (quantity > 0 && (cost == null || cost <= 0)) ||
          evidence.isEmpty) {
        setState(() => _error = 'أكمل الكمية والتكلفة والدليل لكل صنف.');
        return;
      }
      openings.add(OpeningValuationInput(
        productId: product.id,
        quantityKg: quantity,
        unitCostQirshPerKg: cost ?? 0,
        evidenceReference: evidence,
      ));
    }
    Navigator.of(context).pop(_ActivationInput(
      activationDate: _date,
      evidenceNote: _evidenceNote.text.trim(),
      openings: openings,
    ));
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _ActivationInput {
  const _ActivationInput({
    required this.activationDate,
    required this.evidenceNote,
    required this.openings,
  });
  final DateTime activationDate;
  final String evidenceNote;
  final List<OpeningValuationInput> openings;
}
