import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/backup/business_data_wipe_service.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class DataWipeScreen extends StatefulWidget {
  const DataWipeScreen({super.key, this.service});

  final BusinessDataWipeService? service;

  @override
  State<DataWipeScreen> createState() => _DataWipeScreenState();
}

class _DataWipeScreenState extends State<DataWipeScreen> {
  final TextEditingController _confirmationController = TextEditingController();
  BusinessDataWipeResult? _result;
  bool _warningAccepted = false;
  bool _isWiping = false;

  BusinessDataWipeService get _service =>
      widget.service ?? AppRepositories.businessDataWipeService;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(_onConfirmationChanged);
  }

  @override
  void dispose() {
    _confirmationController
      ..removeListener(_onConfirmationChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    if (user?.permissions.canWipeBusinessData != true) {
      return const PremiumCard(
        child: Text(
          '\u0647\u0630\u0647 \u0627\u0644\u0623\u062f\u0627\u0629 \u0645\u062a\u0627\u062d\u0629 \u0644\u0644\u0645\u0627\u0644\u0643 \u0641\u0642\u0637.',
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final canSubmit = _confirmationController.text ==
            BusinessDataWipeService.confirmationPhrase &&
        !_isWiping;

    return ListView(
      children: [
        Text(
          '\u0625\u0639\u0627\u062f\u0629 \u062a\u0647\u064a\u0626\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0645\u062e\u0632\u0646',
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          '\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u062e\u0637\u064a\u0631\u0629 \u0644\u0644\u0645\u0627\u0644\u0643 \u0641\u0642\u0637',
          style: textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        const _DangerCopyCard(),
        const SizedBox(height: 16),
        if (!_warningAccepted)
          FilledButton.icon(
            onPressed: _showWarningDialog,
            icon: const Icon(Icons.warning_rounded),
            label: const Text('\u0645\u062a\u0627\u0628\u0639\u0629'),
          )
        else ...[
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u0627\u0643\u062a\u0628 \u0639\u0628\u0627\u0631\u0629 \u0627\u0644\u062a\u0623\u0643\u064a\u062f \u0643\u0645\u0627 \u0647\u064a \u0644\u0644\u0645\u062a\u0627\u0628\u0639\u0629.',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const SelectableText(
                  BusinessDataWipeService.confirmationPhrase,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmationController,
                  decoration: const InputDecoration(
                    labelText:
                        '\u0639\u0628\u0627\u0631\u0629 \u0627\u0644\u062a\u0623\u0643\u064a\u062f',
                    border: OutlineInputBorder(),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: canSubmit ? _wipeData : null,
                  icon: _isWiping
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_rounded),
                  label: const Text(
                    '\u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644 \u0628\u0639\u062f \u0627\u0644\u0646\u0633\u062e \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a',
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          _WipeResultCard(result: _result!),
        ],
      ],
    );
  }

  Future<void> _showWarningDialog() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '\u062a\u0623\u0643\u064a\u062f \u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644',
        ),
        content: const Text(
          '\u0633\u064a\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0623\u0648\u0644\u0627. \u0644\u0646 \u064a\u062a\u0645 \u0627\u0644\u0645\u0633\u062d \u0625\u0630\u0627 \u0641\u0634\u0644 \u0625\u0646\u0634\u0627\u0621 \u0623\u0648 \u062d\u0641\u0638 \u0627\u0644\u0646\u0633\u062e\u0629 \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629. \u0633\u064a\u062a\u0645 \u062d\u0630\u0641 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644\u060c \u0648\u0633\u064a\u0628\u0642\u0649 \u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u0643 \u0648\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062f\u062e\u0648\u0644 \u0643\u0645\u0627 \u0647\u064a.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\u0625\u0644\u063a\u0627\u0621'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('\u0645\u062a\u0627\u0628\u0639\u0629'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() => _warningAccepted = true);
    }
  }

  Future<void> _wipeData() async {
    final user = AuthScope.of(context).state.user;
    setState(() {
      _isWiping = true;
      _result = null;
    });

    final result = await _service.wipeBusinessData(
      user: user,
      confirmationText: _confirmationController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _isWiping = false;
    });
  }

  void _onConfirmationChanged() {
    setState(() {});
  }
}

class _DangerCopyCard extends StatelessWidget {
  const _DangerCopyCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('\u0625\u062c\u0631\u0627\u0621 \u062e\u0637\u064a\u0631'),
          SizedBox(height: 8),
          Text(
              '\u0647\u0630\u0627 \u0625\u062c\u0631\u0627\u0621 \u062e\u0637\u064a\u0631.'),
          SizedBox(height: 8),
          Text(
            '\u0633\u064a\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0623\u0648\u0644\u0627.',
          ),
          SizedBox(height: 8),
          Text(
            '\u0644\u0646 \u064a\u062a\u0645 \u0627\u0644\u0645\u0633\u062d \u0625\u0630\u0627 \u0641\u0634\u0644 \u0625\u0646\u0634\u0627\u0621 \u0623\u0648 \u062d\u0641\u0638 \u0627\u0644\u0646\u0633\u062e\u0629 \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629.',
          ),
          SizedBox(height: 8),
          Text(
            '\u0633\u064a\u062a\u0645 \u062d\u0630\u0641 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644 \u0645\u062b\u0644 \u0627\u0644\u0623\u0635\u0646\u0627\u0641 \u0648\u0627\u0644\u0645\u062e\u0632\u0648\u0646 \u0648\u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a \u0648\u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a \u0648\u0633\u062c\u0644 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a.',
          ),
          SizedBox(height: 8),
          Text(
            '\u0644\u0646 \u064a\u062a\u0645 \u062d\u0630\u0641 \u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u0643 \u0623\u0648 \u0628\u064a\u0627\u0646\u0627\u062a \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644.',
          ),
          SizedBox(height: 8),
          Text(
            '\u0644\u0627 \u064a\u0645\u0643\u0646 \u0627\u0644\u062a\u0631\u0627\u062c\u0639 \u0639\u0646 \u0647\u0630\u0627 \u0627\u0644\u0625\u062c\u0631\u0627\u0621 \u0645\u0646 \u062f\u0627\u062e\u0644 \u0627\u0644\u0646\u0638\u0627\u0645 \u0625\u0644\u0627 \u0628\u0627\u0633\u062a\u0631\u062c\u0627\u0639 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0635\u0627\u0644\u062d\u0629 \u0625\u0644\u0649 \u0646\u0638\u0627\u0645 \u0641\u0627\u0631\u063a.',
          ),
          SizedBox(height: 8),
          Text(
            '\u0627\u0633\u062a\u0631\u062c\u0627\u0639 \u0641\u0648\u0642 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062d\u0627\u0644\u064a\u0629 \u0645\u0627 \u0632\u0627\u0644 \u063a\u064a\u0631 \u0645\u062f\u0639\u0648\u0645.',
          ),
        ],
      ),
    );
  }
}

class _WipeResultCard extends StatelessWidget {
  const _WipeResultCard({required this.result});

  final BusinessDataWipeResult result;

  @override
  Widget build(BuildContext context) {
    final counts = result.wipedCounts;
    final save = result.backupSaveResult;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.message,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: result.success ? AppColors.olive : null,
                ),
          ),
          if (save != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
                '\u0627\u0633\u0645 \u0645\u0644\u0641 \u0627\u0644\u0646\u0633\u062e\u0629',
                save.fileName),
            _InfoRow(
                '\u0645\u062c\u0644\u062f \u0627\u0644\u0646\u0633\u062e\u0629',
                save.folderPath),
            _InfoRow(
                '\u0645\u0633\u0627\u0631 \u0627\u0644\u0646\u0633\u062e\u0629',
                save.filePath),
          ],
          if (counts != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
                '\u062a\u0645 \u0645\u0633\u062d \u0627\u0644\u0623\u0635\u0646\u0627\u0641',
                '${counts.products}'),
            _InfoRow(
                '\u062a\u0645 \u0645\u0633\u062d \u062d\u0631\u0643\u0627\u062a \u0627\u0644\u0645\u062e\u0632\u0648\u0646',
                '${counts.inventoryMovements}'),
            _InfoRow(
                '\u062a\u0645 \u0645\u0633\u062d \u0627\u0644\u0645\u0648\u0631\u062f\u064a\u0646',
                '${counts.suppliers}'),
            _InfoRow(
                '\u062a\u0645 \u0645\u0633\u062d \u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a',
                '${counts.purchases}'),
            _InfoRow(
                '\u062a\u0645 \u0645\u0633\u062d \u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a',
                '${counts.sales}'),
            _InfoRow(
                '\u062a\u0645 \u0645\u0633\u062d \u0633\u062c\u0644 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a',
                '${counts.documentHistory}'),
          ],
          for (final warning in result.warnings) ...[
            const SizedBox(height: 8),
            Text(warning),
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
