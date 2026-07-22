import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_workflow_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_search_field.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_status_badge.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class NegativeBalanceApprovalRequestsScreen extends StatefulWidget {
  const NegativeBalanceApprovalRequestsScreen({
    super.key,
    this.workflowService,
    this.requestRepository,
    this.financialAccountRepository,
    this.authRepository,
  });

  final NegativeBalanceApprovalWorkflowService? workflowService;
  final NegativeBalanceApprovalRequestRepository? requestRepository;
  final FinancialAccountRepository? financialAccountRepository;
  final AuthRepository? authRepository;

  @override
  State<NegativeBalanceApprovalRequestsScreen> createState() =>
      _NegativeBalanceApprovalRequestsScreenState();
}

class _NegativeBalanceApprovalRequestsScreenState
    extends State<NegativeBalanceApprovalRequestsScreen> {
  late final NegativeBalanceApprovalWorkflowService _workflow;
  late final NegativeBalanceApprovalRequestRepository _requests;
  late final FinancialAccountRepository _accounts;
  late final AuthRepository _auth;

  List<NegativeBalanceApprovalRequest> _items = const [];
  Map<String, String> _accountNames = const {};
  Map<String, String> _actorNames = const {};
  NegativeBalanceApprovalRequestStatus? _statusFilter =
      NegativeBalanceApprovalRequestStatus.pending;
  final _searchController = TextEditingController();
  String _query = '';
  String? _busyRequestId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _workflow = widget.workflowService ??
        AppRepositories.negativeBalanceApprovalWorkflowService;
    _requests = widget.requestRepository ??
        AppRepositories.negativeBalanceApprovalRequestRepository;
    _accounts = widget.financialAccountRepository ??
        AppRepositories.financialAccountRepository;
    _auth = widget.authRepository ?? AppRepositories.authRepository;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _requests.listAll();
      final accountNames = <String, String>{};
      final actorNames = <String, String>{};
      for (final item in items) {
        if (!accountNames.containsKey(item.financialAccountId)) {
          try {
            accountNames[item.financialAccountId] =
                (await _accounts.accountById(item.financialAccountId)).name;
          } on Object {
            accountNames[item.financialAccountId] = 'حساب غير متاح';
          }
        }
        for (final actorId in [item.requesterActorId, item.resolverActorId]) {
          if (actorId == null || actorNames.containsKey(actorId)) continue;
          actorNames[actorId] =
              (await _auth.getUserById(actorId))?.name ?? actorId;
        }
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _accountNames = accountNames;
        _actorNames = actorNames;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل طلبات الموافقة: $error';
      });
    }
  }

  List<NegativeBalanceApprovalRequest> get _visibleItems {
    final query = _query.trim().toLowerCase();
    return _items.where((item) {
      if (_statusFilter != null && item.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      final haystack = [
        item.id,
        item.operationType.labelAr,
        _accountNames[item.financialAccountId] ?? '',
        _actorNames[item.requesterActorId] ?? item.requesterActorId,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    if (user == null) {
      return const Center(child: Text('يجب تسجيل الدخول لعرض الطلبات.'));
    }
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GhalalPageHeader(
            title: 'طلبات الموافقة',
            subtitle:
                'الطلب المعلّق لم ينفذ العملية بعد؛ الاعتماد الصحيح ينفذها فورًا.',
            icon: Icons.approval_rounded,
            onBack: Navigator.of(context).canPop()
                ? () => Navigator.of(context).maybePop()
                : null,
            backButtonKey: const Key('approval-requests-back-button'),
            actions: [
              IconButton(
                tooltip: 'تحديث الطلبات',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFilters(),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildBody(user)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final search = GhalalSearchField(
      controller: _searchController,
      hintText: 'بحث بالمعرف أو العملية أو الحساب...',
      onChanged: (value) => setState(() => _query = value),
    );
    final status =
        DropdownButtonFormField<NegativeBalanceApprovalRequestStatus?>(
      value: _statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'الحالة'),
      items: [
        const DropdownMenuItem(value: null, child: Text('كل الحالات')),
        ...NegativeBalanceApprovalRequestStatus.values.map(
          (value) => DropdownMenuItem(
            value: value,
            child: Text(value.labelAr),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _statusFilter = value),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              search,
              const SizedBox(height: AppSpacing.sm),
              status,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 230, child: status),
          ],
        );
      },
    );
  }

  Widget _buildBody(AppUser user) {
    if (_loading) {
      return const GhalalLoadingState(label: 'جاري تحميل طلبات الموافقة...');
    }
    if (_error != null) {
      return GhalalErrorState(message: _error!, onRetry: _load);
    }
    final items = _visibleItems;
    if (items.isEmpty) {
      if (_items.isEmpty) {
        return const GhalalEmptyState(
          title: 'لا توجد طلبات موافقة',
          message: 'ستظهر هنا الطلبات التي تحتاج اعتمادًا قبل التنفيذ.',
          icon: Icons.approval_outlined,
        );
      }
      return const GhalalEmptyState(
        title: 'لا توجد نتائج مطابقة',
        message: 'غيّر البحث أو الحالة لعرض طلبات أخرى.',
        icon: Icons.search_off_rounded,
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _requestCard(items[index], user),
    );
  }

  Widget _requestCard(
    NegativeBalanceApprovalRequest request,
    AppUser user,
  ) {
    final isBusy = _busyRequestId == request.id;
    final isOwner = user.role == UserRole.owner;
    final isRequester = user.id == request.requesterActorId;
    return PremiumCard(
      child: InkWell(
        onTap: () => _showDetails(request),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.operationType.labelAr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _approvalStatusBadge(request.status),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('الطلب: ${request.id}'),
                  Text(
                      'مقدم الطلب: ${_actorNames[request.requesterActorId] ?? request.requesterActorId}'),
                  Text(
                      'الحساب: ${_accountNames[request.financialAccountId] ?? request.financialAccountId}'),
                  Text('الطريقة: ${request.paymentMethod.labelAr}'),
                  Text(
                      'المبلغ: ${MoneyUtils.formatPiastersAsEgp(request.amountQirsh)}'),
                  Text(
                      'الرصيد: ${MoneyUtils.formatPiastersAsEgp(request.balanceAtRequestQirsh)}'),
                  Text(
                      'العجز: ${MoneyUtils.formatPiastersAsEgp(request.deficitAtRequestQirsh)}'),
                  Text('الوقت: ${_formatDateTime(request.requestedAt)}'),
                ],
              ),
              if (request.resolutionReason != null) ...[
                const SizedBox(height: 8),
                Text('سبب الحسم: ${request.resolutionReason}'),
              ],
              if (request.status ==
                  NegativeBalanceApprovalRequestStatus.pending) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isOwner)
                      FilledButton.icon(
                        onPressed:
                            isBusy ? null : () => _approve(request, user),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('اعتماد وتنفيذ فورًا'),
                      ),
                    if (isOwner)
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : () => _reject(request, user),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('رفض'),
                      ),
                    if (isRequester)
                      TextButton.icon(
                        onPressed: isBusy ? null : () => _cancel(request, user),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('إلغاء الطلب'),
                      ),
                    if (isBusy)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _approvalStatusBadge(
    NegativeBalanceApprovalRequestStatus status,
  ) {
    return switch (status) {
      NegativeBalanceApprovalRequestStatus.pending => GhalalStatusBadge(
          label: status.labelAr,
          icon: Icons.schedule_rounded,
          tone: GhalalStatusTone.warning,
        ),
      NegativeBalanceApprovalRequestStatus.executed => GhalalStatusBadge(
          label: status.labelAr,
          icon: Icons.check_circle_rounded,
          tone: GhalalStatusTone.success,
        ),
      NegativeBalanceApprovalRequestStatus.rejected => GhalalStatusBadge(
          label: status.labelAr,
          icon: Icons.block_rounded,
          tone: GhalalStatusTone.error,
        ),
      NegativeBalanceApprovalRequestStatus.cancelled => GhalalStatusBadge(
          label: status.labelAr,
          icon: Icons.cancel_outlined,
          tone: GhalalStatusTone.cancelled,
        ),
      NegativeBalanceApprovalRequestStatus.stale => GhalalStatusBadge(
          label: status.labelAr,
          icon: Icons.history_toggle_off_rounded,
          tone: GhalalStatusTone.stale,
        ),
    };
  }

  Future<void> _showDetails(NegativeBalanceApprovalRequest request) async {
    final transitions = await _requests.listTransitions(requestId: request.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل ${request.operationType.labelAr}'),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppComponentSizes.dialogMaxWidth,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الحالة: ${request.status.labelAr}'),
                Text('المعرف: ${request.id}'),
                Text('مفتاح Idempotency: ${request.idempotencyKey}'),
                Text('المصدر/المسودة: ${request.sourceDocumentId}'),
                Text(
                    'الحساب: ${_accountNames[request.financialAccountId] ?? request.financialAccountId}'),
                Text(
                    'المبلغ: ${MoneyUtils.formatPiastersAsEgp(request.amountQirsh)}'),
                Text(
                    'العجز وقت الطلب: ${MoneyUtils.formatPiastersAsEgp(request.deficitAtRequestQirsh)}'),
                Text('السبب: ${request.reason}'),
                const SizedBox(height: 12),
                const Text('سجل الحالات:'),
                for (final transition in transitions)
                  Text(
                    '• ${transition.toStatus.labelAr} — ${_actorNames[transition.actorId] ?? transition.actorId} — ${_formatDateTime(transition.occurredAt)} — ${transition.reason}',
                  ),
                if (request.status ==
                    NegativeBalanceApprovalRequestStatus.pending) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'العملية لم تُنفذ بعد. الاعتماد الصحيح سينفذها فورًا داخل معاملة ذرية واحدة.',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(
    NegativeBalanceApprovalRequest request,
    AppUser user,
  ) async {
    var enteredPassword = '';
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة إثبات صلاحية المالك'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الاعتماد سينفذ العملية فورًا. أدخل كلمة مرور حساب المالك الحالي للمتابعة.',
            ),
            const SizedBox(height: 12),
            Text('هاتف المالك: ${user.phone}'),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              onChanged: (value) => enteredPassword = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(enteredPassword),
            child: const Text('اعتماد وتنفيذ'),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty) return;
    await _runRequestAction(request.id, () async {
      final resolved = await _workflow.approveAndExecute(
        requestId: request.id,
        approverActorId: user.id,
        ownerPhone: user.phone,
        ownerPassword: password,
      );
      if (resolved.status == NegativeBalanceApprovalRequestStatus.stale) {
        throw StateError(resolved.resolutionReason ?? 'أصبح الطلب غير صالح.');
      }
      return resolved;
    });
  }

  Future<void> _reject(
    NegativeBalanceApprovalRequest request,
    AppUser user,
  ) async {
    final reason = await _askReason('سبب رفض الطلب');
    if (reason == null) return;
    await _runRequestAction(
      request.id,
      () =>
          _workflow.reject(requestId: request.id, actor: user, reason: reason),
    );
  }

  Future<void> _cancel(
    NegativeBalanceApprovalRequest request,
    AppUser user,
  ) async {
    final reason = await _askReason('سبب إلغاء الطلب');
    if (reason == null) return;
    await _runRequestAction(
      request.id,
      () =>
          _workflow.cancel(requestId: request.id, actor: user, reason: reason),
    );
  }

  Future<String?> _askReason(String title) async {
    var enteredReason = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'السبب مطلوب'),
          onChanged: (value) => enteredReason = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(enteredReason.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _runRequestAction(
    String requestId,
    Future<Object?> Function() action,
  ) async {
    if (_busyRequestId != null) return;
    setState(() => _busyRequestId = requestId);
    try {
      await action();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حسم الطلب: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
