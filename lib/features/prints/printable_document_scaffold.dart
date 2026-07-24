import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class PrintableDocumentScaffold extends StatefulWidget {
  const PrintableDocumentScaffold({
    super.key,
    required this.title,
    this.documentDate,
    this.documentNumber,
    this.subtitle,
    required this.child,
    this.onExportPdf,
    this.onOpenWhatsApp,
  });

  final String title;
  final String? documentDate;
  final String? documentNumber;
  final String? subtitle;
  final Widget child;
  final Future<void> Function()? onExportPdf;
  final Future<void> Function()? onOpenWhatsApp;

  @override
  State<PrintableDocumentScaffold> createState() =>
      _PrintableDocumentScaffoldState();
}

class _PrintableDocumentScaffoldState extends State<PrintableDocumentScaffold> {
  bool _isExporting = false;
  bool _isSharing = false;

  Future<void> _handleExport() async {
    if (_isExporting || widget.onExportPdf == null) return;
    setState(() => _isExporting = true);
    try {
      await widget.onExportPdf!();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleWhatsApp() async {
    if (_isSharing || widget.onOpenWhatsApp == null) return;
    setState(() => _isSharing = true);
    try {
      await widget.onOpenWhatsApp!();
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName =
        BusinessIdentityScope.maybeOf(context)?.identity.displayName ??
            BusinessIdentity.defaultDisplayName;
    final logo = BusinessIdentityScope.maybeOf(context)?.identity.logo;
    final hasLogo = logo != null && logo.isValid;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        color: colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  if (hasLogo)
                    _PrintableLogo(managedFileName: logo.managedFileName),
                  if (hasLogo) const SizedBox(height: AppSpacing.xs),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs + 2),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (widget.documentDate != null ||
                      widget.documentNumber != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Column(
                      children: [
                        if (widget.documentDate != null)
                          Text(
                            '\u0627\u0644\u062A\u0627\u0631\u064A\u062E: ${widget.documentDate}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        if (widget.documentDate != null &&
                            widget.documentNumber != null)
                          const SizedBox(height: AppSpacing.xxs),
                        if (widget.documentNumber != null)
                          Text(
                            '\u0631\u0642\u0645 \u0627\u0644\u0645\u0633\u062A\u0646\u062F: ${widget.documentNumber}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            PremiumCard(
              child: widget.child,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '\u064A\u0645\u0643\u0646 \u0645\u0631\u0627\u062C\u0639\u0629 \u0647\u0630\u0627 \u0627\u0644\u0645\u0633\u062A\u0646\u062F \u0645\u0646 \u0627\u0644\u0634\u0627\u0634\u0629 \u0623\u0648 \u062A\u0635\u0648\u064A\u0631\u0647/\u062D\u0641\u0638\u0647 \u062D\u0633\u0628 \u0627\u0644\u0645\u062A\u0627\u062D \u062D\u0627\u0644\u064A\u064B\u0627.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
              ),
              child: Center(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.onExportPdf != null)
                      OutlinedButton.icon(
                        onPressed: _isExporting ? null : _handleExport,
                        icon: _isExporting
                            ? const SizedBox(
                                width: AppIconSizes.sm,
                                height: AppIconSizes.sm,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: const Text('\u062A\u0635\u062F\u064A\u0631 PDF'),
                      ),
                    if (widget.onOpenWhatsApp != null)
                      OutlinedButton.icon(
                        onPressed: _isSharing ? null : _handleWhatsApp,
                        icon: _isSharing
                            ? const SizedBox(
                                width: AppIconSizes.sm,
                                height: AppIconSizes.sm,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chat),
                        label: const Text(
                            '\u0641\u062A\u062D \u0648\u0627\u062A\u0633\u0627\u0628'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('\u0631\u062C\u0648\u0639'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintableLogo extends StatelessWidget {
  const _PrintableLogo({required this.managedFileName});

  final String managedFileName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _loadBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 60, maxWidth: 200),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _loadBytes() async {
    if (managedFileName.isEmpty) return null;
    try {
      return await AppRepositories.businessIdentityRepository
          .loadLogoBytes(managedFileName);
    } catch (_) {
      return null;
    }
  }
}
