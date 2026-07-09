import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_colors.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class PrintableDocumentScaffold extends StatelessWidget {
  const PrintableDocumentScaffold({
    super.key,
    required this.title,
    this.documentDate,
    this.documentNumber,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? documentDate;
  final String? documentNumber;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                    if (documentDate != null || documentNumber != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (documentDate != null)
                            Text(
                              'التاريخ: $documentDate',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.text,
                              ),
                            ),
                          if (documentDate != null && documentNumber != null)
                            const SizedBox(width: 24),
                          if (documentNumber != null)
                            Text(
                              'رقم المستند: $documentNumber',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.text,
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
                child: child,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'يمكن مراجعة هذا المستند من الشاشة أو تصويره/حفظه حسب المتاح حاليًا.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('رجوع'),
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
