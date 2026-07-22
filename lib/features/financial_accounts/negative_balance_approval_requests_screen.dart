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
          Row(
            children: [
              IconButton(
                key: const Key('approval-requests-back-button'),
                tooltip: 'رجوع',
                onPressed: Navigator.of(context).canPop()
                    ? () => Navigator.of(context).maybePop()
                    : null,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  'طلبات الموافقة',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'بحث بالمعرف أو العملية أو الحساب...',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<
                    NegativeBalanceApprovalRequestStatus?>(
                  value: _statusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    ...NegativeBalanceApprovalRequestStatus.values.map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.labelAr),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(user)),
        ],
      ),
    );
  }

  Widget _buildBody(AppUser user) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    final items = _visibleItems;
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد طلبات تطابق الفلتر الحالي.'));
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
                  Chip(label: Text(request.status.labelAr)),
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

  Future<void> _showDetails(NegativeBalanceApprovalRequest request) async {
    final transitions = await _requests.listTransitions(requestId: request.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل ${request.operationType.labelAr}'),
        content: SizedBox(
          width: 560,
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
