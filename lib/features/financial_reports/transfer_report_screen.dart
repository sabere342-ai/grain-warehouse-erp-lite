import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_csv_exporter.dart';
import 'package:grain_warehouse_erp_lite/features/exports/financial_report_pdf_builder.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class TransferReportScreen extends StatefulWidget {
  const TransferReportScreen({super.key});

  @override
  State<TransferReportScreen> createState() => _TransferReportScreenState();
}

class _TransferReportScreenState extends State<TransferReportScreen> {
  late final FinancialReportService _service;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _anyAccountId;
  String? _reversalFilter;
  TransferReport? _report;
  List<FinancialAccount> _accounts = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = FinancialReportService(
        repository: AppRepositories.financialAccountRepository);
    _loadAccounts();
    _applyFilters();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AppRepositories.financialAccountRepository
        .listAccounts(includeInactive: true);
    setState(() => _accounts = accounts);
  }

  Future<void> _applyFilters() async {
    setState(() => _loading = true);
    try {
      _report = await _service.transferReport(
        fromDate: _fromDate,
        toDate: _toDate,
        sourceAccountId: _sourceAccountId,
        destinationAccountId: _destinationAccountId,
        anyAccountId: _anyAccountId,
        reversalFilter: _reversalFilter,
      );
    } catch (e) {
      _report = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _resetFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _sourceAccountId = null;
      _destinationAccountId = null;
      _anyAccountId = null;
      _reversalFilter = null;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null || !user.permissions.canViewFinancialReports) {
      return const Scaffold(
        body: Center(child: Text('ليس لديك صلاحية عرض التقارير المالية.')),
      );
    }

    final rows = _report?.rows ?? [];

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GhalalPageHeader(
            title: 'تقرير التحويلات الداخلية',
            subtitle: 'سجل التحويلات بين الحسابات المالية خلال الفترة المحددة.',
            icon: Icons.swap_horiz_rounded,
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              if (user.permissions.canExportFinancialReports) ...[
                OutlinedButton.icon(
                  onPressed: _report != null ? _exportPdf : null,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _report != null ? _exportCsv : null,
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('CSV'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildFilters(textTheme),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const GhalalLoadingState(label: 'جاري تحميل التقرير...')
          else if (_report == null)
            GhalalErrorState(
              message: 'تعذر تحميل التقرير.',
              onRetry: _applyFilters,
            )
          else if (rows.isEmpty)
            const GhalalEmptyState(
              title: 'لا توجد تحويلات',
              message: 'لا توجد تحويلات داخلية في الفترة المحددة.',
              icon: Icons.swap_horiz_rounded,
            )
          else ...[
            _buildSummaryCard(textTheme),
            const SizedBox(height: AppSpacing.md),
            ...rows.map((row) => _buildTransferCard(row, textTheme)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters(TextTheme textTheme) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الفلاتر', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _fromDate != null
                        ? 'من: ${_formatDate(_fromDate!)}'
                        : 'من تاريخ',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: _pickToDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _toDate != null
                        ? 'إلى: ${_formatDate(_toDate!)}'
                        : 'إلى تاريخ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _anyAccountId,
            decoration: const InputDecoration(labelText: 'أي حساب'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('الكل'),
              ),
              for (final a in _accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(a.name),
                ),
            ],
            onChanged: (v) {
              setState(() => _anyAccountId = v);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _sourceAccountId,
                  decoration: const InputDecoration(labelText: 'الحساب المصدر'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('الكل'),
                    ),
                    for (final a in _accounts)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _sourceAccountId = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _destinationAccountId,
                  decoration: const InputDecoration(labelText: 'الحساب الوجهة'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('الكل'),
                    ),
                    for (final a in _accounts)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _destinationAccountId = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _reversalFilter,
            decoration: const InputDecoration(labelText: 'حالة التحويل'),
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text('الكل'),
              ),
              DropdownMenuItem(
                value: 'original',
                child: Text('أصلي فقط'),
              ),
              DropdownMenuItem(
                value: 'reversal',
                child: Text('تحويل عكس فقط'),
              ),
              DropdownMenuItem(
                value: 'reversed',
                child: Text('تم عكسه فقط'),
              ),
            ],
            onChanged: (v) {
              setState(() => _reversalFilter = v);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _applyFilters,
                child: const Text('تطبيق'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('إعادة تعيين'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(TextTheme textTheme) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الإجمالي', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryItem('إجمالي المبالغ',
                  MoneyUtils.formatPiastersAsEgp(_report!.totalAmountQirsh)),
              _summaryItem('عدد التحويلات', '${_report!.rows.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTransferCard(TransferReportRow row, TextTheme textTheme) {
    String statusLabel;
    Color statusColor;
    if (row.isReversal) {
      statusLabel = 'عكس تحويل';
      statusColor = Colors.orange[800]!;
    } else if (row.isReversed) {
      statusLabel = 'تم العكس';
      statusColor = Colors.red[800]!;
    } else {
      statusLabel = 'أصلي';
      statusColor = Colors.green[800]!;
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                row.displayNumber,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(row.effectiveDate),
                style:
                    textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'من: ${row.sourceAccountName}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'إلى: ${row.destinationAccountName}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              Text(
                MoneyUtils.formatPiastersAsEgp(row.amountQirsh),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (row.reference != null && row.reference!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'المرجع: ${row.reference}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
          ],
          if (row.note != null && row.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              row.note!,
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (row.isReversed && row.reversalDisplayNumber != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Colors.orange[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم العكس بتحويل رقم: ${row.reversalDisplayNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );
    if (selected != null) {
      setState(() => _fromDate = selected);
    }
  }

  Future<void> _pickToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ar'),
    );
    if (selected != null) {
      setState(() => _toDate = selected);
    }
  }

  Future<void> _exportPdf() async {
    if (_report == null) return;
    try {
      final identity =
          await AppRepositories.businessIdentityRepository.loadIdentity();
      Uint8List? logoBytes;
      if (identity.hasLogo && identity.logo != null) {
        // The export contract intentionally resolves this only after identity.
        final result =
            // ignore: use_build_context_synchronously
            await ApplicationScope.of(context).queries.businessLogo.execute(
                  LoadBusinessLogoQuery(
                    managedFileName: identity.logo!.managedFileName,
                  ),
                );

        logoBytes = result.value;
      }
      final file = await FinancialReportPdfBuilder.buildTransferReport(
        report: _report!,
        businessIdentity: identity,
        logoBytes: logoBytes,
      );
      await _showExportResult(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إنشاء ملف PDF.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_report == null) return;
    try {
      final file = await FinancialReportCsvExporter.exportTransferReport(
        report: _report!,
      );
      await _showExportResult(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إنشاء ملف CSV.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showExportResult(File file) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الملف بنجاح.\n${file.path}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
