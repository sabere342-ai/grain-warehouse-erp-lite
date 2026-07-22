import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';

class GhalalResponsiveDialog extends StatelessWidget {
  const GhalalResponsiveDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon,
    this.isDirty = false,
    this.isBusy = false,
    this.maxWidth = AppComponentSizes.dialogMaxWidth,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final Widget? icon;
  final bool isDirty;
  final bool isBusy;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    // WillPopScope intentionally guards user-initiated back/escape while still
    // allowing a successful submit to close the route programmatically.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (isBusy) return false;
        if (!isDirty) return true;
        return _confirmDiscard(context);
      },
      child: AlertDialog(
        icon: icon,
        title: title,
        scrollable: true,
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actionsOverflowAlignment: OverflowBarAlignment.end,
        actionsOverflowDirection: VerticalDirection.down,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? 0 : 420,
            maxWidth: maxWidth - (AppSpacing.lg * 2),
          ),
          child: content,
        ),
        actions: actions,
      ),
    );
  }

  static Future<void> requestClose(
    BuildContext context, {
    required bool isDirty,
  }) async {
    if (!isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await _confirmDiscard(context);
    if (discard && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  static Future<bool> _confirmDiscard(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: const Text('تجاهل التغييرات؟'),
        content: const Text(
          'لم تُحفظ البيانات التي أدخلتها. يمكنك الرجوع إلى النموذج أو تجاهلها والخروج.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('متابعة التعديل'),
          ),
          FilledButton.icon(
            key: const Key('confirm-discard-dialog-action'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('تجاهل والخروج'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
    return discard == true;
  }
}
