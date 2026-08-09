import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/trial/trial_service.dart';
import '../../core/trial/trial_state.dart';

class TrialAppGate extends StatefulWidget {
  const TrialAppGate({
    super.key,
    required this.evaluation,
    required this.child,
    this.evaluator,
  });

  final TrialEvaluation evaluation;
  final Widget child;
  final TrialEvaluator? evaluator;

  @override
  State<TrialAppGate> createState() => _TrialAppGateState();
}

class _TrialAppGateState extends State<TrialAppGate> {
  static const _checkpointInterval = Duration(minutes: 1);

  late TrialEvaluation _evaluation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _evaluation = widget.evaluation;
    _scheduleCheckpoint();
  }

  @override
  void didUpdateWidget(TrialAppGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evaluation != widget.evaluation ||
        oldWidget.evaluator != widget.evaluator) {
      _evaluation = widget.evaluation;
      _timer?.cancel();
      _scheduleCheckpoint();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleCheckpoint() {
    final evaluator = widget.evaluator;
    if (evaluator == null || !_evaluation.allowsAccess) return;
    final untilExpiry = _evaluation.remaining;
    final delay =
        untilExpiry < _checkpointInterval ? untilExpiry : _checkpointInterval;
    _timer = Timer(delay, _refreshEvaluation);
  }

  Future<void> _refreshEvaluation() async {
    final evaluator = widget.evaluator;
    if (evaluator == null) return;
    final next = await evaluator.evaluate();
    if (!mounted) return;
    setState(() => _evaluation = next);
    _scheduleCheckpoint();
  }

  @override
  Widget build(BuildContext context) {
    if (!_evaluation.allowsAccess) {
      return _TrialBlockedApp(status: _evaluation.status);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            top: 8,
            left: 12,
            child: SafeArea(
              child: IgnorePointer(
                child: Material(
                  key: const Key('trial-status-banner'),
                  color: const Color(0xFFE8F0D5),
                  elevation: 2,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      _activeLabel(_evaluation.daysRemaining),
                      style: const TextStyle(
                        color: Color(0xFF33451F),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _activeLabel(int daysRemaining) {
    if (daysRemaining == 1) {
      return 'نسخة تجريبية — متبقي يوم واحد';
    }
    return 'نسخة تجريبية — متبقي $daysRemaining يومًا';
  }
}

class _TrialBlockedApp extends StatelessWidget {
  const _TrialBlockedApp({required this.status});

  final TrialAccessStatus status;

  @override
  Widget build(BuildContext context) {
    final expired = status == TrialAccessStatus.expired;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        key: const Key('trial-blocked-screen'),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        expired ? Icons.timer_off_outlined : Icons.lock_clock,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        expired
                            ? 'انتهت الفترة التجريبية'
                            : 'تعذر التحقق من صلاحية الفترة التجريبية',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        expired
                            ? 'انتهت مدة التجربة لهذا البرنامج. بياناتك محفوظة ولم يتم حذفها.'
                            : 'تم اكتشاف تغيير غير متوقع في تاريخ أو وقت الجهاز، أو تعذر التحقق من بيانات الفترة التجريبية.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'للاستمرار في استخدام النظام، برجاء التواصل مع مزود البرنامج للحصول على النسخة الكاملة.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
