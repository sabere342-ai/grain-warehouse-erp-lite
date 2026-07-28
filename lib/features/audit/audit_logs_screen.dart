import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_controller.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key, this.controller});

  final AuditLogController? controller;

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  late final AuditLogController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AuditLogController(repository: AppRepositories.auditLogRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = AuthScope.of(context).state.user;
      if (user != null) {
        _controller.loadLogs(user);
      }
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;

    if (user == null || !user.permissions.canViewAuditLogs) {
      return const PremiumCard(child: Text('سجل التدقيق متاح للمالك فقط.'));
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ListView(
          children: [
            const GhalalPageHeader(
              title:
                  '\u0633\u062c\u0644 \u0627\u0644\u062a\u062f\u0642\u064a\u0642',
              subtitle:
                  '\u0639\u0631\u0636 \u0642\u0631\u0627\u0621\u0629 \u0641\u0642\u0637 \u0644\u0644\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u0627\u0644\u0645\u0647\u0645\u0629 \u0627\u0644\u0645\u0633\u062c\u0644\u0629 \u0645\u062d\u0644\u064a\u0627\u064b.',
              icon: Icons.fact_check_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_controller.errorMessage != null) ...[
              GhalalErrorState(
                message: _controller.errorMessage!,
                onRetry: () {
                  final user = AuthScope.of(context).state.user;
                  if (user != null) _controller.loadLogs(user);
                },
              ),
            ] else if (_controller.isLoading)
              const GhalalLoadingState()
            else if (_controller.entries.isEmpty)
              const GhalalEmptyState(
                title:
                    '\u0644\u0627 \u062a\u0648\u062c\u062f \u0623\u062d\u062f\u0627\u062b \u062a\u062f\u0642\u064a\u0642 \u0645\u0633\u062c\u0644\u0629 \u0628\u0639\u062f.',
              )
            else
              ..._controller.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _AuditLogCard(entry: entry),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.entry});

  final AuditLogReadModel entry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.descriptionAr,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text('الوقت: ${_formatDateTime(entry.timestamp)}'),
          if (entry.referenceId != null)
            Text('رقم المستند: ${entry.referenceId}'),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
