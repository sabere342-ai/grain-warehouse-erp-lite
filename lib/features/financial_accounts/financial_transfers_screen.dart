import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/post_internal_transfer_command.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_state_view.dart';
import 'package:uuid/uuid.dart';

class FinancialTransfersScreen extends StatefulWidget {
  const FinancialTransfersScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<FinancialTransfersScreen> createState() =>
      _FinancialTransfersScreenState();
}

class _FinancialTransfersScreenState extends State<FinancialTransfersScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late final FinancialAccountController _controller;
  List<FinancialAccount> _accounts = const [];
  List<FinancialTransfer> _transfers = const [];
  String? _sourceId;
  String? _destinationId;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _submitting = false;
  bool _restoredAttempt = false;
  String? _postingLifecycle;
  String? _postingStatusMessage;
  ApplicationCommandRequest<PostInternalTransferCommand>? _retryRequest;

  @override
  void initState() {
    super.initState();
    _controller = FinancialAccountController(
        repository: AppRepositories.financialAccountRepository);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restoredAttempt) {
      _restoredAttempt = true;
      _restoreIncompleteCloudAttempt();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _controller.loadAccounts(widget.user);
    final accounts =
        await AppRepositories.financialAccountRepository.listAccounts();
    final transfers =
        await AppRepositories.financialAccountRepository.listTransfers();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _transfers = transfers.reversed.toList();
        _loading = false;
      });
    }
  }

  FinancialAccount? _account(String? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.role != UserRole.owner) {
      return Scaffold(
          body: ListView(
        children: [
          GhalalPageHeader(
            title: 'التحويلات المالية',
            icon: Icons.swap_horiz_rounded,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const Center(child: Text('التحويلات المالية متاحة للمالك فقط.')),
        ],
      ));
    }
    return Scaffold(
      body: _loading
          ? const GhalalLoadingState(label: 'جاري تحميل التحويلات...')
          : ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
              GhalalPageHeader(
                title: 'التحويلات المالية',
                subtitle: 'إدارة التحويلات بين الحسابات المالية.',
                icon: Icons.swap_horiz_rounded,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Text('تحويل جديد', style: Theme.of(context).textTheme.titleLarge),
              if (_postingStatusMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _postingStatusMessage!,
                  key: Key(
                    'internal-transfer-posting-${_postingLifecycle ?? 'queued'}',
                  ),
                  style: TextStyle(
                    color: _postingLifecycle == 'confirmed'
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _accountPicker('الحساب المصدر', _sourceId,
                  (v) => setState(() => _sourceId = v)),
              const SizedBox(height: AppSpacing.sm),
              _accountPicker('الحساب الوجهة', _destinationId,
                  (v) => setState(() => _destinationId = v)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'المبلغ بالقرش')),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                  title: const Text('تاريخ التحويل'),
                  subtitle: Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate),
              TextField(
                  controller: _note,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظة (اختيارية)')),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                  onPressed: _submitting ? null : _review,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('مراجعة التحويل')),
              const Divider(height: AppSpacing.xl),
              Text('سجل التحويلات',
                  style: Theme.of(context).textTheme.titleLarge),
              if (_transfers.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: Text('لا توجد تحويلات مسجلة.')),
              ..._transfers.map(_transferTile),
            ]),
    );
  }

  Widget _accountPicker(
          String label, String? value, ValueChanged<String?> change) =>
      DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: _accounts
              .map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                      '${a.name} — ${MoneyUtils.formatPiastersAsEgp(_balance(a.id))}')))
              .toList(),
          onChanged: change);
  int _balance(String id) => _controller.balances
      .where((b) => b.account.id == id)
      .fold(0, (_, b) => b.currentBalanceQirsh);
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Widget _transferTile(FinancialTransfer transfer) {
    final source =
        _account(transfer.sourceAccountId)?.name ?? transfer.sourceAccountId;
    final destination = _account(transfer.destinationAccountId)?.name ??
        transfer.destinationAccountId;
    return Card(
        child: ListTile(
            title: Text('${transfer.displayNumber}: $source ← $destination'),
            subtitle: Text(
                '${MoneyUtils.formatPiastersAsEgp(transfer.amountQirsh)} · ${transfer.effectiveDate.toLocal().toIso8601String().substring(0, 10)}${transfer.isReversal ? ' · عكس' : transfer.isReversed ? ' · تم عكسه' : ''}'),
            trailing:
                !_isCloudMode && !transfer.isReversal && !transfer.isReversed
                    ? TextButton(
                        onPressed: () => _reverse(transfer),
                        child: const Text('عكس'))
                    : null));
  }

  Future<void> _review() async {
    final source = _account(_sourceId);
    final destination = _account(_destinationId);
    final value = int.tryParse(_amount.text.trim());
    if (source == null ||
        destination == null ||
        value == null ||
        value <= 0 ||
        source.id == destination.id) {
      _message('أكمل الحسابين المختلفين والمبلغ الموجب.');
      return;
    }
    final approved = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('مراجعة قبل التنفيذ'),
                content: Text(
                    'من: ${source.name}\nإلى: ${destination.name}\nالمبلغ: ${MoneyUtils.formatPiastersAsEgp(value)}\nالتاريخ: ${_date.toLocal().toIso8601String().substring(0, 10)}\nالملاحظة: ${_note.text.trim().isEmpty ? '—' : _note.text.trim()}\nرصيد المصدر الحالي: ${MoneyUtils.formatPiastersAsEgp(_balance(source.id))}\nرصيد الوجهة الحالي: ${MoneyUtils.formatPiastersAsEgp(_balance(destination.id))}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('تأكيد نهائي'))
                ]));
    if (approved != true) {
      return;
    }
    if (_isCloudMode) {
      await _postCloudTransfer(source, destination, value);
      return;
    }
    final now = DateTime.now().microsecondsSinceEpoch;
    final transfer = await _controller.createTransfer(
        user: widget.user,
        draft: FinancialTransferDraft(
            clientRequestId: 'transfer-$now',
            transferReference: 'TR-$now',
            sourceAccountId: source.id,
            destinationAccountId: destination.id,
            amountQirsh: value,
            effectiveDate: _date,
            createdByUserId: widget.user.id,
            note: _note.text));
    if (transfer == null) {
      _message(_controller.errorMessage ?? 'تعذر إنشاء التحويل.');
    } else {
      _amount.clear();
      _note.clear();
      await _load();
    }
  }

  Future<void> _reverse(FinancialTransfer transfer) async {
    if (_isCloudMode) {
      _message('عكس التحويلات السحابية غير متاح حتى اعتماد أمر عكس خادمي.');
      return;
    }
    final reason = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('عكس التحويل'),
                content: TextField(
                    controller: reason,
                    decoration:
                        const InputDecoration(labelText: 'سبب العكس (إلزامي)')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, reason.text),
                      child: const Text('تأكيد العكس'))
                ]));
    reason.dispose();
    if (result == null) {
      return;
    }
    final reversed = await _controller.reverseTransfer(
        user: widget.user, transferId: transfer.id, reason: result);
    if (reversed == null) {
      _message(_controller.errorMessage ?? 'تعذر عكس التحويل.');
    } else {
      await _load();
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool get _isCloudMode =>
      ApplicationScope.of(context).dependencies.runtime.sessionContextProvider
          is! LocalSessionContextProvider;

  Future<void> _postCloudTransfer(
    FinancialAccount source,
    FinancialAccount destination,
    int amountQirsh,
  ) async {
    final application = ApplicationScope.of(context);
    final runtime = application.dependencies.runtime;
    final session = runtime.sessionContextProvider.current;
    final business = runtime.businessContextProvider.current;
    if (session == null ||
        !session.isVerifiedRemote ||
        business == null ||
        !business.isVerifiedMembership ||
        business.role != 'owner') {
      _showPostingMessage(
        lifecycle: 'rejected',
        message: 'يلزم اتصال سحابي وعضوية مالك موثقة لتنفيذ التحويل.',
      );
      return;
    }
    final resolver =
        application.dependencies.repositories.financialAccountCloudLinkResolver;
    final sourceLink = await resolver.readyLinkForLocalAccount(
      localAccountId: source.id,
      businessId: business.businessId,
    );
    final destinationLink = await resolver.readyLinkForLocalAccount(
      localAccountId: destination.id,
      businessId: business.businessId,
    );
    if (sourceLink == null ||
        destinationLink == null ||
        sourceLink.serverAccountUuid == destinationLink.serverAccountUuid) {
      _showPostingMessage(
        lifecycle: 'rejected',
        message: 'يجب تحديث وتسوية الحسابين سحابياً قبل التحويل.',
      );
      return;
    }
    final command = PostInternalTransferCommand(
      commandId: const Uuid().v7(),
      businessId: business.businessId,
      sourceFinancialAccountId: sourceLink.serverAccountUuid,
      destinationFinancialAccountId: destinationLink.serverAccountUuid,
      amountQirsh: amountQirsh,
      effectiveBusinessDate: _date.toIso8601String().substring(0, 10),
      transferReference: const Uuid().v7(),
      note: _note.text,
    );
    final request = ApplicationCommandRequest<PostInternalTransferCommand>(
      command: command,
      businessContext: business,
      idempotencyKey: command.commandId,
    );
    _retryRequest = request;
    setState(() {
      _submitting = true;
      _postingLifecycle = 'queued';
      _postingStatusMessage = 'تم حفظ محاولة التحويل محلياً دون أي أثر مالي.';
    });
    try {
      await _submitCloudTransfer(request);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitCloudTransfer(
    ApplicationCommandRequest<PostInternalTransferCommand> request,
  ) async {
    if (mounted) {
      setState(() {
        _postingLifecycle = 'sending';
        _postingStatusMessage = 'جارٍ إرسال التحويل إلى الخادم المالي...';
      });
    }
    final result = await ApplicationScope.of(context)
        .commands
        .postInternalTransfer
        .execute(request);
    if (!mounted) return;
    if (result is PostInternalTransferSuccess) {
      if (result.projectionPending) {
        _showPostingMessage(
          lifecycle: 'confirmedProjectionPending',
          message:
              'تم اعتماد التحويل، وتعذر تحديث النسخة المحلية. أعد المحاولة لإصلاح العرض فقط.',
          retry: true,
        );
      } else {
        _retryRequest = null;
        _amount.clear();
        _note.clear();
        _showPostingMessage(
          lifecycle: 'confirmed',
          message: result.replayed
              ? 'تم تأكيد التحويل السابق دون تكرار الحركة المالية.'
              : 'تم اعتماد التحويل وتحديث الحسابين محلياً.',
        );
        await _load();
      }
      return;
    }
    final failure = result as PostInternalTransferFailure;
    final uncertain = failure.retryable;
    _showPostingMessage(
      lifecycle: uncertain ? 'unknownOutcome' : 'rejected',
      message: _messageForFailure(failure.code),
      retry: uncertain,
    );
    if (!uncertain) _retryRequest = null;
  }

  Future<void> _retryLastCloudTransfer() async {
    final request = _retryRequest;
    if (request == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _submitCloudTransfer(request);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _restoreIncompleteCloudAttempt() async {
    if (!_isCloudMode) return;
    final application = ApplicationScope.of(context);
    final business =
        application.dependencies.runtime.businessContextProvider.current;
    if (business == null ||
        !business.isVerifiedMembership ||
        business.role != 'owner') {
      return;
    }
    final attempts = await application
        .commands.postInternalTransfer.attemptStore
        .loadIncompleteForBusiness(business.businessId);
    if (attempts.isEmpty || !mounted) return;
    final payload = (jsonDecode(attempts.first.canonicalPayloadJson)
            as Map<String, dynamic>)
        .cast<String, Object?>();
    try {
      final command = PostInternalTransferCommand(
        commandId: payload['commandId']! as String,
        schemaVersion: payload['schemaVersion']! as int,
        businessId: payload['businessId']! as String,
        sourceFinancialAccountId:
            payload['sourceFinancialAccountId']! as String,
        destinationFinancialAccountId:
            payload['destinationFinancialAccountId']! as String,
        amountQirsh: payload['amountQirsh']! as int,
        effectiveBusinessDate: payload['effectiveBusinessDate']! as String,
        transferReference: payload['transferReference']! as String,
        note: payload['note'] as String?,
      );
      _retryRequest = ApplicationCommandRequest<PostInternalTransferCommand>(
        command: command,
        businessContext: business,
        idempotencyKey: command.commandId,
      );
      setState(() {
        _postingLifecycle = attempts.first.state.name;
        _postingStatusMessage =
            'توجد محاولة تحويل غير مكتملة. أعد المحاولة بنفس مفتاح الأمر.';
      });
    } on Object {
      setState(() {
        _postingLifecycle = 'unknownOutcome';
        _postingStatusMessage = 'تعذر قراءة محاولة التحويل المحفوظة بأمان.';
      });
    }
  }

  void _showPostingMessage({
    required String lifecycle,
    required String message,
    bool retry = false,
  }) {
    if (!mounted) return;
    setState(() {
      _postingLifecycle = lifecycle;
      _postingStatusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: retry
            ? SnackBarAction(
                label: 'إعادة المحاولة',
                onPressed: _retryLastCloudTransfer,
              )
            : null,
      ),
    );
  }

  String _messageForFailure(String code) => switch (code) {
        'validation.invalidField' ||
        'validation.sameAccount' =>
          'تحقق من حسابي التحويل والمبلغ والتاريخ والمرجع.',
        'unauthenticated.sessionRequired' =>
          'انتهت الجلسة السحابية. سجّل الدخول ثم أعد المحاولة.',
        'unauthorized.internalTransferDenied' ||
        'wrongBusinessContext' =>
          'لا تملك صلاحية تنفيذ هذا التحويل في المنشأة الحالية.',
        'sourceAccount.notFoundOrInactive' =>
          'الحساب المصدر غير نشط أو غير جاهز سحابياً.',
        'destinationAccount.notFoundOrInactive' =>
          'الحساب الوجهة غير نشط أو غير جاهز سحابياً.',
        'period.closed' => 'تاريخ التحويل داخل فترة مالية مغلقة.',
        'balance.insufficient' => 'رصيد الحساب المصدر غير كافٍ.',
        'transferReference.conflict' => 'مرجع التحويل مستخدم بالفعل.',
        'idempotencyConflict' =>
          'تعارض مفتاح إعادة المحاولة مع بيانات تحويل مختلفة.',
        'serverUnavailable' ||
        'transactionFailure' ||
        'unexpectedServerError' =>
          'نتيجة التحويل غير مؤكدة. أعد المحاولة بنفس الأمر عند استقرار الاتصال.',
        'projectionFailure' =>
          'تم الاعتماد خادمياً وتحتاج النسخة المحلية إلى إصلاح.',
        _ => 'تعذر تنفيذ التحويل المالي.',
      };
}
