import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';

class GhalalLoadingState extends StatelessWidget {
  const GhalalLoadingState({super.key, this.label = 'جاري التحميل...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class GhalalEmptyState extends StatelessWidget {
  const GhalalEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: theme.textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class GhalalErrorState extends StatelessWidget {
  const GhalalErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryButtonKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key? retryButtonKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GhalalEmptyState(
      title: 'تعذر تحميل البيانات',
      message: message,
      icon: Icons.error_outline_rounded,
      action: FilledButton.icon(
        key: retryButtonKey,
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('إعادة المحاولة'),
        style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
      ),
    );
  }
}
