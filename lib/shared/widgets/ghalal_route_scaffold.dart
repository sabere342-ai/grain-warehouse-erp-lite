import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';

/// Theme-aware surface for screens that are pushed as standalone routes.
///
/// A route child without a [Scaffold] is transparent. On Windows that can
/// expose the Navigator's black canvas between otherwise themed cards.
class GhalalRouteScaffold extends StatelessWidget {
  const GhalalRouteScaffold({
    super.key,
    required this.child,
    this.scaffoldKey,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final Key? scaffoldKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
