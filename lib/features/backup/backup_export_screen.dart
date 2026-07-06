import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/business_data_wipe_service.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/features/backup/backup_restore_preview_screen.dart';
import 'package:grain_warehouse_erp_lite/features/backup/data_wipe_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/page_back_button.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class BackupExportScreen extends StatefulWidget {
  const BackupExportScreen({
    super.key,
    this.service,
    this.fileWriter,
    this.wipeService,
  });

  final BackupExportService? service;
  final BackupFileWriter? fileWriter;
  final BusinessDataWipeService? wipeService;

  @override
  State<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends State<BackupExportScreen> {
  BackupExportResult? _result;
  BackupFileSaveResult? _saveResult;
  bool _isExporting = false;
  bool _isSaving = false;
  String? _errorMessage;

  BackupExportService get _service =>
      widget.service ?? AppRepositories.backupExportService;
  BackupFileWriter get _fileWriter =>
      widget.fileWriter ?? const LocalBackupFileWriter();

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
        const PageBackButton(),
        const SizedBox(height: 12),
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openRestorePreview,
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('فحص نسخة احتياطية'),
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
            saveResult: _saveResult,
            onCopy: _copyBackup,
            onSave: _saveBackup,
            isSaving: _isSaving,
          ),
        ],
        if (user?.permissions.canWipeBusinessData == true) ...[
          const SizedBox(height: 16),
          _DangerActionsCard(onOpenDataWipe: _openDataWipe),
        ],
      ],
    );
  }

  void _openRestorePreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BackupRestorePreviewScreen(),
      ),
    );
  }

  void _openDataWipe() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DataWipeScreen(service: widget.wipeService),
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _saveResult = null;
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
        _errorMessage =
            'تعذر إنشاء نسخة احتياطية آمنة. حاول مرة أخرى أو تواصل مع الدعم.';
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
    if (!_validateResultForUser(result)) {
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

  Future<void> _saveBackup() async {
    final result = _result;
    if (result == null || _isSaving) {
      return;
    }
    if (!_validateResultForUser(result)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final saveResult = await _fileWriter.save(
        fileName: result.fileName,
        jsonText: result.jsonText,
      );
      if (!mounted) {
        return;
      }
      setState(() => _saveResult = saveResult);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ النسخة الاحتياطية بنجاح.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'تعذر حفظ النسخة في ملف. يمكنك نسخ البيانات وحفظها يدويا.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool _validateResultForUser(BackupExportResult result) {
    try {
      BackupExportValidator.validateJsonText(result.jsonText);
      if (!BackupFileName.isSafeWindowsFileName(result.fileName)) {
        throw const BackupExportValidationException();
      }
      return true;
    } catch (_) {
      setState(() {
        _errorMessage =
            'تعذر إنشاء نسخة احتياطية آمنة. حاول مرة أخرى أو تواصل مع الدعم.';
      });
      return false;
    }
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
          Text('هذه النسخة للتصدير والحفظ فقط.'),
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
            'احتفظ بالنسخة في فلاشة أو مكان آمن خارج الجهاز إن أمكن.',
          ),
          SizedBox(height: 8),
          Text(
            'لا تشارك النسخة لأنها تحتوي على بيانات المخزون والمشتريات والمبيعات.',
          ),
        ],
      ),
    );
  }
}

class _DangerActionsCard extends StatelessWidget {
  const _DangerActionsCard({required this.onOpenDataWipe});

  final VoidCallback onOpenDataWipe;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u062e\u0637\u064a\u0631\u0629 \u0644\u0644\u0645\u0627\u0644\u0643 \u0641\u0642\u0637',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 8),
          const Text('\u0625\u062c\u0631\u0627\u0621 \u062e\u0637\u064a\u0631'),
          const SizedBox(height: 8),
          const Text(
            '\u0627\u0633\u062a\u062e\u062f\u0645 \u0647\u0630\u0627 \u0627\u0644\u0625\u062c\u0631\u0627\u0621 \u0641\u0642\u0637 \u0639\u0646\u062f \u0627\u0644\u062d\u0627\u062c\u0629 \u0644\u0628\u062f\u0621 \u0627\u0644\u0646\u0638\u0627\u0645 \u0645\u0646 \u062c\u062f\u064a\u062f \u0623\u0648 \u062d\u0630\u0641 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u062c\u0631\u0628\u0629. \u0633\u064a\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0623\u0648\u0644\u0627 \u0642\u0628\u0644 \u0623\u064a \u0645\u0633\u062d.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenDataWipe,
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text(
              '\u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644',
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupResultCard extends StatelessWidget {
  const _BackupResultCard({
    required this.result,
    required this.saveResult,
    required this.onCopy,
    required this.onSave,
    required this.isSaving,
  });

  final BackupExportResult result;
  final BackupFileSaveResult? saveResult;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final bool isSaving;

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
          _InfoRow('عدد الموردين', '${counts.suppliers}'),
          _InfoRow('عدد المشتريات', '${counts.purchases}'),
          _InfoRow('عدد المبيعات', '${counts.sales}'),
          _InfoRow('عدد سجلات المستندات', '${counts.documentHistory}'),
          _InfoRow('إصدار النسخة', '${result.backupVersion}'),
          _InfoRow('فحص النسخ البسيط', result.checksum),
          _InfoRow('اسم الملف', result.fileName),
          if (saveResult != null) ...[
            const SizedBox(height: 8),
            const Text('تم حفظ النسخة الاحتياطية بنجاح.'),
            const SizedBox(height: 6),
            _InfoRow('مكان الحفظ', saveResult!.folderPath),
            _InfoRow('مسار الملف', saveResult!.filePath),
            const SizedBox(height: 6),
            const Text(
              'احتفظ بهذا الملف في مكان آمن خارج الجهاز إن أمكن.',
            ),
            const SizedBox(height: 6),
            const Text('الاسترجاع غير متاح في هذه المرحلة.'),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ بيانات النسخة'),
              ),
              FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt_rounded),
                label: const Text('حفظ النسخة في ملف'),
              ),
            ],
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
