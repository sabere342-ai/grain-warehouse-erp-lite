import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class BackupRestorePreviewScreen extends StatefulWidget {
  const BackupRestorePreviewScreen(
      {super.key, this.service, this.restoreService});

  final BackupRestorePreviewService? service;
  final BackupRestoreService? restoreService;

  @override
  State<BackupRestorePreviewScreen> createState() =>
      _BackupRestorePreviewScreenState();
}

class _BackupRestorePreviewScreenState
    extends State<BackupRestorePreviewScreen> {
  final TextEditingController _controller = TextEditingController();
  BackupRestorePreviewResult? _result;
  BackupRestoreResult? _restoreResult;
  bool _isRestoring = false;

  BackupRestorePreviewService get _service =>
      widget.service ?? const BackupRestorePreviewService();
  BackupRestoreService get _restoreService =>
      widget.restoreService ?? AppRepositories.backupRestoreService;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    if (user?.permissions.canExportBackups != true) {
      return const PremiumCard(
        child: Text('هذه الأداة متاحة للمالك فقط.'),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return ListView(
      children: [
        Text('فحص نسخة احتياطية', style: textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'يمكنك فحص نسخة احتياطية ومعرفة محتواها قبل أن ندعم الاسترجاع الفعلي في مرحلة لاحقة.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        const PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هذه الشاشة للفحص والمعاينة فقط.'),
              SizedBox(height: 8),
              Text(
                'لن يتم استرجاع أو تعديل أو حذف أي بيانات من النظام الحالي.',
              ),
              SizedBox(height: 8),
              Text(
                'تأكد أنك تستخدم نسخة صادرة من هذا النظام ولا تشارك النسخة مع أي شخص غير موثوق.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          minLines: 8,
          maxLines: 14,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'الصق بيانات النسخة الاحتياطية هنا',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _previewBackup,
              icon: const Icon(Icons.fact_check_rounded),
              label: const Text('فحص النسخة'),
            ),
            OutlinedButton.icon(
              onPressed: _clearText,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('مسح النص'),
            ),
          ],
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          _PreviewResultCard(result: _result!),
        ],
        if (_result?.isValid == true) ...[
          const SizedBox(height: 16),
          _RestoreToEmptyCard(
            isRestoring: _isRestoring,
            restoreResult: _restoreResult,
            onRestore: _confirmAndRestore,
          ),
        ],
      ],
    );
  }

  void _previewBackup() {
    setState(() {
      _result = _service.preview(_controller.text);
      _restoreResult = null;
    });
  }

  void _clearText() {
    _controller.clear();
    setState(() {
      _result = null;
      _restoreResult = null;
    });
  }

  Future<void> _confirmAndRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد استرجاع النسخة'),
        content: const Text(
          'سيتم استرجاع بيانات النسخة الاحتياطية إلى النظام الحالي بشرط أن يكون فارغا. لن يتم تنفيذ العملية إذا وُجدت أي بيانات حالية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد الاسترجاع'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isRestoring = true);
    final user = AuthScope.of(context).state.user;
    final result = await _restoreService.restoreToEmpty(
      user: user,
      jsonText: _controller.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _restoreResult = result;
      _isRestoring = false;
    });
  }
}

class _RestoreToEmptyCard extends StatelessWidget {
  const _RestoreToEmptyCard({
    required this.isRestoring,
    required this.restoreResult,
    required this.onRestore,
  });

  final bool isRestoring;
  final BackupRestoreResult? restoreResult;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'استرجاع النسخة إلى نظام فارغ',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'الاسترجاع الفعلي متاح فقط إذا كان النظام الحالي فارغا تماما.',
          ),
          const SizedBox(height: 6),
          const Text(
            'لن يتم استبدال أو دمج أو مسح أي بيانات موجودة.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isRestoring ? null : onRestore,
            icon: isRestoring
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_rounded),
            label: const Text('استرجاع إلى نظام فارغ'),
          ),
          if (restoreResult != null) ...[
            const SizedBox(height: 12),
            Text(
              restoreResult!.message,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (restoreResult!.success && restoreResult!.counts != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                  'تم استرجاع الأصناف', '${restoreResult!.counts!.products}'),
              _InfoRow(
                'تم استرجاع حركات المخزون',
                '${restoreResult!.counts!.inventoryMovements}',
              ),
              _InfoRow(
                  'تم استرجاع الموردين', '${restoreResult!.counts!.suppliers}'),
              _InfoRow('تم استرجاع المشتريات',
                  '${restoreResult!.counts!.purchases}'),
              _InfoRow(
                  'تم استرجاع المبيعات', '${restoreResult!.counts!.sales}'),
              _InfoRow(
                'تم استرجاع سجل المستندات',
                '${restoreResult!.counts!.documentHistory}',
              ),
              for (final warning in restoreResult!.warnings) ...[
                const SizedBox(height: 6),
                Text(warning),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _PreviewResultCard extends StatelessWidget {
  const _PreviewResultCard({required this.result});

  final BackupRestorePreviewResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.isValid) {
      return PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعذر فحص النسخة الاحتياطية.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(result.message),
          ],
        ),
      );
    }

    final summary = result.summary!;
    final counts = summary.counts;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.message,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _InfoRow(
              'تاريخ إنشاء النسخة', summary.generatedAt.toLocal().toString()),
          _InfoRow('إصدار النسخة', '${summary.backupVersion}'),
          if (summary.fileName != null)
            _InfoRow('اسم الملف', summary.fileName!),
          if (summary.checksum != null)
            _InfoRow('فحص النسخ البسيط', summary.checksum!),
          _InfoRow('الأصناف', '${counts.products}'),
          _InfoRow('حركات المخزون', '${counts.inventoryMovements}'),
          _InfoRow('الموردين', '${counts.suppliers}'),
          _InfoRow('المشتريات', '${counts.purchases}'),
          _InfoRow('المبيعات', '${counts.sales}'),
          _InfoRow('سجل المستندات', '${counts.documentHistory}'),
          const SizedBox(height: 12),
          for (final warning in result.warnings) ...[
            Text(warning),
            const SizedBox(height: 6),
          ],
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
