import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_semantic_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';

enum GhalalStatusTone {
  neutral,
  information,
  success,
  warning,
  error,
  cancelled,
  stale,
}

class GhalalStatusBadge extends StatelessWidget {
  const GhalalStatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final GhalalStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Semantics(
      label: 'الحالة: $label',
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withOpacity(0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSizes.sm, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _color(BuildContext context) {
    final semantic = AppSemanticColors.of(context);
    return switch (tone) {
      GhalalStatusTone.neutral =>
        Theme.of(context).colorScheme.onSurfaceVariant,
      GhalalStatusTone.information => semantic.information,
      GhalalStatusTone.success => semantic.executed,
      GhalalStatusTone.warning => semantic.pending,
      GhalalStatusTone.error => semantic.rejected,
      GhalalStatusTone.cancelled => semantic.cancelled,
      GhalalStatusTone.stale => semantic.stale,
    };
  }
}
