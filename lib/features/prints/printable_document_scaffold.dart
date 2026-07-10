import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
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

class _PrintableDocumentScaffoldState
    extends State<PrintableDocumentScaffold> {
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
    final displayName =
        BusinessIdentityScope.maybeOf(context)?.identity.displayName ??
            BusinessIdentity.defaultDisplayName;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.text,
                          ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.mutedText),
                      ),
                    ],
                    if (widget.documentDate != null ||
                        widget.documentNumber != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.documentDate != null)
                            Text(
                              '\u0627\u0644\u062A\u0627\u0631\u064A\u062E: ${widget.documentDate}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.text),
                            ),
                          if (widget.documentDate != null &&
                              widget.documentNumber != null)
                            const SizedBox(width: 24),
                          if (widget.documentNumber != null)
                            Text(
                              '\u0631\u0642\u0645 \u0627\u0644\u0645\u0633\u062A\u0646\u062F: ${widget.documentNumber}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.text),
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
                padding: const EdgeInsets.all(16),
                child: Text(
                  '\u064A\u0645\u0643\u0646 \u0645\u0631\u0627\u062C\u0639\u0629 \u0647\u0630\u0627 \u0627\u0644\u0645\u0633\u062A\u0646\u062F \u0645\u0646 \u0627\u0644\u0634\u0627\u0634\u0629 \u0623\u0648 \u062A\u0635\u0648\u064A\u0631\u0647/\u062D\u0641\u0638\u0647 \u062D\u0633\u0628 \u0627\u0644\u0645\u062A\u0627\u062D \u062D\u0627\u0644\u064A\u064B\u0627.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedText),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                child: Center(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (widget.onExportPdf != null)
                        OutlinedButton.icon(
                          onPressed: _isExporting ? null : _handleExport,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: const Text(
                              '\u062A\u0635\u062F\u064A\u0631 PDF'),
                        ),
                      if (widget.onOpenWhatsApp != null)
                        OutlinedButton.icon(
                          onPressed: _isSharing ? null : _handleWhatsApp,
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chat),
                          label: const Text('\u0641\u062A\u062D \u0648\u0627\u062A\u0633\u0627\u0628'),
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
      ),
    );
  }
}
