import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';

class FinancialClosingScreen extends StatefulWidget {
  const FinancialClosingScreen({super.key});
  @override
  State<FinancialClosingScreen> createState() => _FinancialClosingScreenState();
}

class _FinancialClosingScreenState extends State<FinancialClosingScreen> {
  final _repo = AppRepositories.financialAccountRepository;
  final _actual = <String, TextEditingController>{};
  bool _busy = false;
  FinancialClosingKind _kind = FinancialClosingKind.daily;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();

  @override
  void dispose() {
    for (final c in _actual.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).state.user;
    if (user == null || user.role.name != 'owner') {
      return const Scaffold(
          body: Center(child: Text('هذه العملية متاحة للمالك فقط.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الإغلاق المالي والتسوية')),
      body: FutureBuilder<(List<FinancialAccount>, List<FinancialClosing>)>(
        future: _load(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
                child: Text('تعذر تحميل بيانات الإغلاق المالي.'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (accounts, closings) = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text(
                'تُسجّل التسوية الرصيد الفعلي وتقارنه بالرصيد الدفتري. لا تنشئ فروقًا أو تعدّل أي حركة مالية.'),
            const SizedBox(height: 12),
            SegmentedButton<FinancialClosingKind>(
                segments: const [
                  ButtonSegment(
                      value: FinancialClosingKind.daily,
                      label: Text('إغلاق يومي')),
                  ButtonSegment(
                      value: FinancialClosingKind.period,
                      label: Text('إغلاق فترة'))
                ],
                selected: {
                  _kind
                },
                onSelectionChanged: (v) => setState(() {
                      _kind = v.first;
                      if (_kind == FinancialClosingKind.daily) _from = _to;
                    })),
            const SizedBox(height: 12),
            Wrap(spacing: 12, children: [
              TextButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.date_range),
                  label: Text('من: ${_date(_from)}')),
              TextButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.event),
                  label: Text('إلى: ${_date(_to)}'))
            ]),
            for (final account in accounts)
              TextField(
                  controller: _actual.putIfAbsent(
                      account.id, TextEditingController.new),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'الرصيد الفعلي — ${account.name} (قرش)')),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _busy || accounts.isEmpty
                    ? null
                    : () => _approve(user, accounts),
                icon: const Icon(Icons.lock),
                label: Text(
                    _busy ? 'جارٍ الاعتماد...' : 'مراجعة واعتماد الإغلاق')),
            const Divider(height: 32),
            Text('سجل التسويات', style: Theme.of(context).textTheme.titleLarge),
            if (closings.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد تسويات مسجلة بعد.')),
            for (final closing in closings)
              Card(
                  child: ListTile(
                      title: Text(
                          '${closing.kind == FinancialClosingKind.daily ? 'يومي' : 'فترة'}: ${_date(closing.fromDate)} — ${_date(closing.toDate)}'),
                      subtitle: Text(
                          'فرق التسوية: ${closing.totalDifferenceQirsh} قرش\nالحالة: ${closing.isOpen ? 'أعيد فتحه' : 'معتمد ومغلق'}${closing.reopenReason == null ? '' : '\nسبب إعادة الفتح: ${closing.reopenReason}'}'),
                      isThreeLine: true,
                      trailing: closing.isOpen
                          ? null
                          : IconButton(
                              tooltip: 'إعادة فتح',
                              icon: const Icon(Icons.lock_open),
                              onPressed: () => _reopen(user, closing))))
          ]);
        },
      ),
    );
  }

  Future<(List<FinancialAccount>, List<FinancialClosing>)> _load() async =>
      (await _repo.listAccounts(), await _repo.listClosings());
  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: from ? _from : _to,
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        if (from) {
          _from = picked;
        } else {
          _to = picked;
        }
        if (_kind == FinancialClosingKind.daily) {
          _from = _to;
        }
      });
    }
  }

  Future<void> _approve(user, List<FinancialAccount> accounts) async {
    final values = <String, int>{};
    for (final account in accounts) {
      final value = int.tryParse(_actual[account.id]?.text.trim() ?? '');
      if (value == null) {
        _message('أدخل الرصيد الفعلي لكل حساب.');
        return;
      }
      values[account.id] = value;
    }
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    title: const Text('تأكيد الإغلاق المالي'),
                    content: const Text(
                        'سيُقفل النطاق المحدد أمام الحركات المؤرخة داخله، مع حفظ الفروق كما هي دون قيود موازنة.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('رجوع')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('اعتماد'))
                    ])) ??
        false;
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await _repo.createClosing(
          user: user,
          draft: FinancialClosingDraft(
              kind: _kind,
              fromDate: _from,
              toDate: _to,
              actualBalancesQirsh: values));
      _message('تم اعتماد الإغلاق المالي وحفظ التسوية.');
    } catch (_) {
      _message('تعذر اعتماد الإغلاق. راجع الفترة والأرصدة والحالة الحالية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopen(user, FinancialClosing closing) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('إعادة فتح الفترة'),
                content: TextField(
                    controller: c,
                    decoration: const InputDecoration(labelText: 'سبب إلزامي')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, c.text),
                      child: const Text('إعادة فتح'))
                ]));
    if (reason == null) return;
    try {
      await _repo.reopenClosing(
          user: user, closingId: closing.id, reason: reason);
      setState(() {});
    } catch (_) {
      _message('تعذر إعادة الفتح. يجب إدخال سبب صالح.');
    }
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
