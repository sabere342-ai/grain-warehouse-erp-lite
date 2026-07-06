import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class BackupExportScreen extends StatefulWidget {
  const BackupExportScreen({super.key, this.service});

  final BackupExportService? service;

  @override
  State<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends State<BackupExportScreen> {
  BackupExportResult? _result;
  bool _isExporting = false;
  String? _errorMessage;

  BackupExportService get _service =>
      widget.service ?? AppRepositories.backupExportService;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.state.user;
    final canExport = user?.permissions.canExportBackups ?? false;

    if (!canExport) {
      return const PremiumCard(
        child: Text('النسخ الاحتياطي متاح للمالك فقط.'),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return ListView(
      children: [
        Text('النسخ الاحتياطي', style: textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'أنشئ نسخة احتياطية قبل أي تعديل كبير أو قبل نقل الجهاز.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        const _SafetyCopyCard(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isExporting ? null : _createBackup,
          icon: _isExporting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.backup_rounded),
          label: const Text('إنشاء نسخة احتياطية'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          _BackupResultCard(
            result: _result!,
            onCopy: _copyBackup,
          ),
        ],
      ],
    );
  }

  Future<void> _createBackup() async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.createBackup();
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'تعذر إنشاء النسخة الاحتياطية. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _copyBackup() async {
    final result = _result;
    if (result == null) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: result.jsonText));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ بيانات النسخة الاحتياطية. احفظها في ملف آمن.'),
      ),
    );
  }
}

class _SafetyCopyCard extends StatelessWidget {
  const _SafetyCopyCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('هذه المرحلة: التصدير فقط.'),
          SizedBox(height: 8),
          Text(
            'النسخة الاحتياطية تحفظ بيانات النظام الحالية في نص آمن يمكن حفظه خارج النظام.',
          ),
          SizedBox(height: 8),
          Text(
            'الاسترجاع غير متاح الآن لتجنب مسح البيانات بالخطأ.',
          ),
          SizedBox(height: 8),
          Text(
            'احتفظ بالنسخة في مكان آمن مثل فلاشة أو مساحة تخزين موثوقة.',
          ),
          SizedBox(height: 8),
          Text(
            'لا تشارك النسخة لأنها قد تحتوي على بيانات البيع والشراء والمخزون.',
          ),
        ],
      ),
    );
  }
}

class _BackupResultCard extends StatelessWidget {
  const _BackupResultCard({
    required this.result,
    required this.onCopy,
  });

  final BackupExportResult result;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final counts = result.counts;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تم إنشاء النسخة الاحتياطية بنجاح.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _InfoRow('تاريخ التصدير', result.generatedAt.toLocal().toString()),
          _InfoRow('عدد الأصناف', '${counts.products}'),
          _InfoRow('عدد حركات المخزون', '${counts.inventoryMovements}'),
          _InfoRow('عدد المشتريات', '${counts.purchases}'),
          _InfoRow('عدد المبيعات', '${counts.sales}'),
          _InfoRow('عدد سجلات المستندات', '${counts.documentHistory}'),
          _InfoRow('إصدار النسخة', '${result.backupVersion}'),
          _InfoRow('فحص النسخ البسيط', result.checksum),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('نسخ بيانات النسخة'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
