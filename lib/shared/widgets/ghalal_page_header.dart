import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';

class GhalalPageHeader extends StatelessWidget {
  const GhalalPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.onBack,
    this.backButtonKey,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Key? backButtonKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton(
            key: backButtonKey,
            tooltip: 'رجوع',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        if (icon != null) ...[
          Semantics(
            excludeSemantics: true,
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (actions.isEmpty) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: actions,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: actions,
              ),
            ),
          ],
        );
      },
    );
  }
}
