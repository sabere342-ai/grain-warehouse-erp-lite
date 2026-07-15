import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/features/customers/customer_advance_actions_screen.dart';

void main() {
  group('Phase 4 customer advance summaries', () {
    test('derives every display status deterministically', () {
      final cases = <CustomerAdvanceSummary, String>{
        _summary(): 'متاحة',
        _summary(appliedQirsh: 50, remainingQirsh: 150): 'مستخدمة جزئيًا',
        _summary(appliedQirsh: 200, remainingQirsh: 0): 'مستهلكة',
        _summary(refundedQirsh: 200, remainingQirsh: 0): 'مردودة',
        _summary(reversed: true, remainingQirsh: 0): 'معكوسة',
      };

      for (final entry in cases.entries) {
        expect(entry.key.statusLabelAr, entry.value);
      }
    });

    test('only active advances with a positive remainder can act', () {
      expect(_summary().canAct, isTrue);
      expect(_summary(remainingQirsh: 0).canAct, isFalse);
      expect(_summary(reversed: true).canAct, isFalse);
    });

    test('customer advance financial statement labels are Arabic', () {
      expect(FinancialAccountEntrySource.customerAdvanceRefund.labelAr,
          'رد سلفة عميل');
      expect(
        FinancialAccountEntrySource.customerAdvanceRefundReversal.labelAr,
        'عكس رد سلفة عميل',
      );
    });
  });

  group('Phase 4 customer advance list UI', () {
    testWidgets('shows loading state', (tester) async {
      final gate = Completer<void>();
      final controller = _ProbeCustomerController(
        summaries: [_summary()],
        loadGate: gate,
      );

      await _pumpScreen(tester, controller: controller);

      expect(
          find.byKey(const Key('customer-advances-loading')), findsOneWidget);
      gate.complete();
    });

    testWidgets('shows empty state', (tester) async {
      final controller = _ProbeCustomerController(summaries: const []);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.byKey(const Key('customer-advances-empty')), findsOneWidget);
      expect(
          find.text('لا توجد سلف متاحة أو سابقة لهذا العميل.'), findsOneWidget);
    });

    testWidgets('shows safe error and retry reloads the list', (tester) async {
      final controller = _ProbeCustomerController(
        summaries: [_summary()],
        failLoading: true,
      );
      await _pumpScreen(tester, controller: controller, settle: true);
      expect(find.byKey(const Key('customer-advances-error')), findsOneWidget);
      expect(find.textContaining('تعذر تحميل سلف العميل'), findsOneWidget);

      controller.failLoading = false;
      await tester.tap(find.byKey(const Key('customer-advances-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer-advances-list')), findsOneWidget);
      expect(controller.loadCalls, 2);
    });

    testWidgets('shows values, source, date and status without internal ids',
        (tester) async {
      final summary = _summary(
        appliedQirsh: 50,
        refundedQirsh: 25,
        remainingQirsh: 125,
      );
      final controller = _ProbeCustomerController(summaries: [summary]);
      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.textContaining('القيمة الأصلية:'), findsOneWidget);
      expect(find.textContaining('المبلغ المطبق:'), findsOneWidget);
      expect(find.textContaining('المبلغ المردود:'), findsOneWidget);
      expect(find.textContaining('الرصيد المتاح:'), findsOneWidget);
      expect(find.text('مستخدمة جزئيًا'), findsOneWidget);
      expect(find.textContaining('المصدر: تحصيل عميل'), findsOneWidget);
      expect(find.textContaining('2026-07-15'), findsOneWidget);
      expect(find.textContaining(summary.advance.id), findsNothing);
      expect(find.textContaining(summary.advance.sourceCollectionId),
          findsNothing);
    });

    testWidgets('hides actions for exhausted and reversed advances',
        (tester) async {
      final controller = _ProbeCustomerController(
        summaries: [
          _summary(id: 'exhausted', remainingQirsh: 0, appliedQirsh: 200),
          _summary(id: 'reversed', reversed: true, remainingQirsh: 0),
        ],
      );
      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.text('تطبيق السلفة'), findsNothing);
      expect(find.text('رد السلفة'), findsNothing);
    });

    testWidgets('hides financial actions from an unauthorized user',
        (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpScreen(
        tester,
        controller: controller,
        user: _owner.copyWith(isActive: false),
        settle: true,
      );

      expect(find.text('تطبيق السلفة'), findsNothing);
      expect(find.text('رد السلفة'), findsNothing);
    });

    testWidgets('is RTL and scrollable on a compact desktop window',
        (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _ProbeCustomerController(
        summaries: List.generate(4, (index) => _summary(id: 'advance-$index')),
      );
      await _pumpScreen(tester, controller: controller, settle: true);

      expect(Directionality.of(tester.element(find.byType(Scaffold))),
          TextDirection.rtl);
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finishing load after disposal does not call setState',
        (tester) async {
      final gate = Completer<void>();
      final controller = _ProbeCustomerController(
        summaries: [_summary()],
        loadGate: gate,
      );
      await _pumpScreen(tester, controller: controller);
      await tester.pumpWidget(const SizedBox.shrink());

      gate.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 4 advance application UI', () {
    testWidgets('opens a clear application dialog', (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpScreen(tester, controller: controller, settle: true);

      await _openApplication(tester);

      expect(find.text('تطبيق السلفة - عميل الاختبار'), findsOneWidget);
      expect(find.textContaining('الرصيد المتاح:'), findsWidgets);
      expect(find.textContaining('سيخفض المبلغ ذمة العميل'), findsOneWidget);
    });

    testWidgets('rejects empty, zero, negative and malformed amounts',
        (tester) async {
      for (final value in ['', '0', '-1', 'abc']) {
        final controller = _ProbeCustomerController(summaries: [_summary()]);
        await _pumpScreen(tester, controller: controller, settle: true);
        await _openApplication(tester);
        if (value.isNotEmpty) {
          await tester.enterText(
              find.byKey(const Key('advance-application-amount')), value);
        }
        await tester.tap(find.byKey(const Key('advance-application-submit')));
        await tester.pump();

        expect(
            find.byKey(const Key('advance-application-error')), findsOneWidget,
            reason: value);
        expect(controller.applyCalls, 0, reason: value);
        await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('rejects amounts over the advance remainder', (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpScreen(tester, controller: controller, settle: true);
      await _openApplication(tester);
      await tester.enterText(
          find.byKey(const Key('advance-application-amount')), '2.01');
      await tester.tap(find.byKey(const Key('advance-application-submit')));
      await tester.pump();

      expect(
          find.text('المبلغ يتجاوز الرصيد المتاح من السلفة.'), findsOneWidget);
      expect(controller.applyCalls, 0);
    });

    testWidgets('rejects amounts over the current customer receivable',
        (tester) async {
      final controller = _ProbeCustomerController(
        summaries: [_summary()],
        receivableQirsh: 50,
      );
      await _pumpScreen(tester, controller: controller, settle: true);
      await _openApplication(tester);
      await tester.enterText(
          find.byKey(const Key('advance-application-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-application-submit')));
      await tester.pump();

      expect(find.text('المبلغ يتجاوز ذمة العميل الحالية.'), findsOneWidget);
      expect(controller.applyCalls, 0);
    });

    testWidgets('submits once, disables controls and survives a double tap',
        (tester) async {
      final gate = Completer<CustomerAdvanceActionResult>();
      final controller = _ProbeCustomerController(
        summaries: [_summary()],
        applyGate: gate,
      );
      await _pumpScreen(tester, controller: controller, settle: true);
      await _openApplication(tester);
      await tester.enterText(
          find.byKey(const Key('advance-application-amount')), '1.00');

      await tester.tap(find.byKey(const Key('advance-application-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('advance-application-submit')),
          warnIfMissed: false);
      await tester.pump();

      expect(controller.applyCalls, 1);
      expect(find.byKey(const Key('advance-application-progress')),
          findsOneWidget);
      expect(controller.applyRequestIds.single, isNotEmpty);
      gate.complete(const CustomerAdvanceActionResult.success());
      await tester.pumpAndSettle();
      expect(find.text('تم تطبيق السلفة بنجاح.'), findsOneWidget);
    });

    testWidgets('keeps the dialog open with a safe Arabic domain error',
        (tester) async {
      final controller = _ProbeCustomerController(
        summaries: [_summary()],
        applyResult: const CustomerAdvanceActionResult.failure(
          'تعذر تطبيق السلفة. راجع البيانات وحاول مرة أخرى.',
        ),
      );
      await _pumpScreen(tester, controller: controller, settle: true);
      await _openApplication(tester);
      await tester.enterText(
          find.byKey(const Key('advance-application-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-application-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('تعذر تطبيق السلفة'), findsOneWidget);
      expect(
          find.byKey(const Key('advance-application-submit')), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
    });
  });

  group('Phase 4 ordinary refund UI', () {
    testWidgets('opens refund dialog and requires account selection',
        (tester) async {
      final accountFixture = await _AccountFixture.create();
      final controller = _ProbeCustomerController(
        summaries: [_summary(accountId: accountFixture.account.id)],
      );
      await _pumpScreen(
        tester,
        controller: controller,
        accounts: accountFixture.repository,
        settle: true,
      );
      await _openRefund(tester,
          advanceId: controller.summaries.single.advance.id);

      expect(find.text('رد السلفة - عميل الاختبار'), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-refund-submit')));
      await tester.pump();

      expect(find.text('اختر الحساب المالي أولًا.'), findsOneWidget);
      expect(controller.refundCalls, 0);
    });

    testWidgets('rejects invalid and over-available refund amounts',
        (tester) async {
      for (final value in ['', '0', '-1', 'abc', '2.01']) {
        final accountFixture = await _AccountFixture.create();
        final controller = _ProbeCustomerController(
          summaries: [_summary(accountId: accountFixture.account.id)],
        );
        await _pumpScreen(
          tester,
          controller: controller,
          accounts: accountFixture.repository,
          settle: true,
        );
        await _openRefund(tester,
            advanceId: controller.summaries.single.advance.id);
        await _selectRefundAccount(tester, accountFixture.account.name);
        if (value.isNotEmpty) {
          await tester.enterText(
              find.byKey(const Key('advance-refund-amount')), value);
        }
        await tester.tap(find.byKey(const Key('advance-refund-submit')));
        await tester.pump();

        expect(find.byKey(const Key('advance-refund-error')), findsOneWidget,
            reason: value);
        expect(controller.refundCalls, 0, reason: value);
        await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('shows account balance and complete confirmation',
        (tester) async {
      final accountFixture = await _AccountFixture.create(balanceQirsh: 500);
      final controller = _ProbeCustomerController(
        summaries: [_summary(accountId: accountFixture.account.id)],
      );
      await _pumpScreen(
        tester,
        controller: controller,
        accounts: accountFixture.repository,
        settle: true,
      );
      await _openRefund(tester,
          advanceId: controller.summaries.single.advance.id);
      await _selectRefundAccount(tester, accountFixture.account.name);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');
      await tester.pump();

      expect(find.byKey(const Key('advance-refund-account-balance')),
          findsOneWidget);
      expect(find.textContaining('عميل الاختبار'), findsWidgets);
      expect(find.textContaining(accountFixture.account.name), findsWidgets);
      expect(
          find.byKey(const Key('advance-refund-confirmation')), findsOneWidget);
    });

    testWidgets('ordinary refund executes once without approval',
        (tester) async {
      final accountFixture = await _AccountFixture.create(balanceQirsh: 500);
      final controller = _ProbeCustomerController(
        summaries: [_summary(accountId: accountFixture.account.id)],
      );
      var approvalCalls = 0;
      Future<String?> approvalPrompt({
        required BuildContext context,
        required FinancialAccount account,
        required int currentBalanceQirsh,
        required int requestedAmountQirsh,
        required String operationDescription,
        required NegativeBalanceApprovalDraft approvalDraft,
      }) async {
        approvalCalls++;
        return 'unexpected';
      }

      await _pumpScreen(
        tester,
        controller: controller,
        accounts: accountFixture.repository,
        approvalPrompt: approvalPrompt,
        settle: true,
      );
      await _openRefund(tester,
          advanceId: controller.summaries.single.advance.id);
      await _selectRefundAccount(tester, accountFixture.account.name);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-refund-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.refundCalls, 1);
      expect(controller.refundApprovalIds.single, isNull);
      expect(approvalCalls, 0);
      expect(find.text('تم رد السلفة بنجاح.'), findsOneWidget);
    });

    testWidgets('refund disables controls and blocks double submission',
        (tester) async {
      final accountFixture = await _AccountFixture.create(balanceQirsh: 500);
      final gate = Completer<CustomerAdvanceActionResult>();
      final controller = _ProbeCustomerController(
        summaries: [_summary(accountId: accountFixture.account.id)],
        refundGate: gate,
      );
      await _pumpScreen(
        tester,
        controller: controller,
        accounts: accountFixture.repository,
        settle: true,
      );
      await _openRefund(tester,
          advanceId: controller.summaries.single.advance.id);
      await _selectRefundAccount(tester, accountFixture.account.name);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');

      await tester.tap(find.byKey(const Key('advance-refund-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('advance-refund-submit')),
          warnIfMissed: false);
      await tester.pump();

      expect(controller.refundCalls, 1);
      expect(find.byKey(const Key('advance-refund-progress')), findsOneWidget);
      gate.complete(const CustomerAdvanceActionResult.success());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 4 negative-balance refund approval UI', () {
    testWidgets('requests exact approval and retries the same logical request',
        (tester) async {
      final accountFixture = await _AccountFixture.create();
      final summary = _summary(accountId: accountFixture.account.id);
      final controller = _ProbeCustomerController(
        summaries: [summary],
        refundRequiresApproval: true,
      );
      NegativeBalanceApprovalDraft? capturedDraft;
      var promptCalls = 0;
      Future<String?> approvalPrompt({
        required BuildContext context,
        required FinancialAccount account,
        required int currentBalanceQirsh,
        required int requestedAmountQirsh,
        required String operationDescription,
        required NegativeBalanceApprovalDraft approvalDraft,
      }) async {
        promptCalls++;
        capturedDraft = approvalDraft;
        return 'approval-1';
      }

      await _pumpScreen(
        tester,
        controller: controller,
        accounts: accountFixture.repository,
        approvalPrompt: approvalPrompt,
        settle: true,
      );
      await _openRefund(tester, advanceId: summary.advance.id);
      await _selectRefundAccount(tester, accountFixture.account.name);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-refund-submit')));
      await tester.pumpAndSettle();

      expect(promptCalls, 1);
      expect(controller.refundCalls, 2);
      expect(controller.refundRequestIds.toSet(), hasLength(1));
      expect(controller.refundApprovalIds, [null, 'approval-1']);
      expect(capturedDraft!.requestedByUserId, _owner.id);
      expect(capturedDraft!.accountId, accountFixture.account.id);
      expect(capturedDraft!.amountQirsh, 100);
      expect(capturedDraft!.operationType,
          NegativeBalanceOperationType.customerAdvanceRefund);
      expect(capturedDraft!.sourceDocumentType, 'customerAdvanceRefund');
      expect(capturedDraft!.balanceBeforeQirsh, 0);
      expect(capturedDraft!.expectedBalanceAfterQirsh, -100);
      expect(capturedDraft!.authorizationContext!.customerId, _customer.id);
      expect(
          capturedDraft!.authorizationContext!.advanceId, summary.advance.id);
      expect(capturedDraft!.authorizationContext!.financialDirection,
          NegativeBalanceFinancialDirection.outflow);
    });

    testWidgets('cancelled approval does not execute the refund',
        (tester) async {
      final accountFixture = await _AccountFixture.create();
      final controller = _ProbeCustomerController(
        summaries: [_summary(accountId: accountFixture.account.id)],
        refundRequiresApproval: true,
      );
      Future<String?> cancelledPrompt({
        required BuildContext context,
        required FinancialAccount account,
        required int currentBalanceQirsh,
        required int requestedAmountQirsh,
        required String operationDescription,
        required NegativeBalanceApprovalDraft approvalDraft,
      }) async =>
          null;

      await _pumpScreen(
        tester,
        controller: controller,
        accounts: accountFixture.repository,
        approvalPrompt: cancelledPrompt,
        settle: true,
      );
      await _openRefund(tester,
          advanceId: controller.summaries.single.advance.id);
      await _selectRefundAccount(tester, accountFixture.account.name);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-refund-submit')));
      await tester.pumpAndSettle();

      expect(controller.refundCalls, 1);
      expect(find.text('تم إلغاء الاعتماد. لم يتم رد السلفة.'), findsOneWidget);
      expect(find.text('تم رد السلفة بنجاح.'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
      await tester.pumpAndSettle();
    });

    testWidgets('approval prompt failure is mapped to a safe Arabic message',
        (tester) async {
      final accountFixture = await _AccountFixture.create();
      final controller = _ProbeCustomerController(
        summaries: [_summary(accountId: accountFixture.account.id)],
        refundRequiresApproval: true,
      );
      Future<String?> failingPrompt({
        required BuildContext context,
        required FinancialAccount account,
        required int currentBalanceQirsh,
        required int requestedAmountQirsh,
        required String operationDescription,
        required NegativeBalanceApprovalDraft approvalDraft,
      }) =>
          Future<String?>.error(StateError('technical failure'));

      await _pumpScreen(
        tester,
        controller: controller,
        accounts: accountFixture.repository,
        approvalPrompt: failingPrompt,
        settle: true,
      );
      await _openRefund(tester,
          advanceId: controller.summaries.single.advance.id);
      await _selectRefundAccount(tester, accountFixture.account.name);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-refund-submit')));
      await tester.pumpAndSettle();

      expect(
          find.text('تعذر طلب اعتماد المالك. حاول مرة أخرى.'), findsOneWidget);
      expect(find.textContaining('technical'), findsNothing);
      expect(controller.refundCalls, 1);
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
      await tester.pumpAndSettle();
    });

    testWidgets('real Phase 4A approval is consumed exactly once in UI flow',
        (tester) async {
      final fixture = await _DomainFixture.create(drainAccount: true);
      NegativeBalanceApprovalDraft? capturedDraft;
      Future<String?> realApprovalPrompt({
        required BuildContext context,
        required FinancialAccount account,
        required int currentBalanceQirsh,
        required int requestedAmountQirsh,
        required String operationDescription,
        required NegativeBalanceApprovalDraft approvalDraft,
      }) async {
        capturedDraft = approvalDraft;
        return fixture.approvalService.requestApproval(
          draft: approvalDraft,
          ownerPhone: _owner.phone,
          ownerPassword: 'secret',
        );
      }

      await _pumpDomainScreen(
        tester,
        fixture,
        approvalPrompt: realApprovalPrompt,
      );
      await _openRefund(tester, advanceId: fixture.advance.id);
      await _selectRefundAccount(tester, fixture.account.name);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-refund-submit')));
      await tester.pumpAndSettle();

      final refunds = await fixture.ledger.listAdvanceRefunds();
      expect(refunds, hasLength(1));
      expect(refunds.single.amountQirsh, 100);
      expect(
          await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id), 100);
      final approvals = await fixture.approvalRepository.listAll();
      final approval = approvals.firstWhere(
        (value) =>
            value.operationType ==
            NegativeBalanceOperationType.customerAdvanceRefund,
      );
      expect(approval.status, NegativeBalanceApprovalStatus.consumed);
      expect(
          approval.authorizationContext!
              .matches(capturedDraft!.authorizationContext),
          isTrue);
      expect(
        await fixture.accounts.currentBalanceForAccount(fixture.account.id),
        -100,
      );
      expect(find.text('تم رد السلفة بنجاح.'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpDomainScreen(tester, fixture);
      expect(find.text('مستخدمة جزئيًا'), findsOneWidget);
      expect(find.textContaining('المبلغ المردود:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid owner credentials never execute a real refund',
        (tester) async {
      final accountFixture = await _AccountFixture.create();
      final controller = _ProbeCustomerController(
        summaries: [_summary(accountId: accountFixture.account.id)],
        refundRequiresApproval: true,
      );
      await _pumpScreen(
        tester,
        controller: controller,
        accounts: accountFixture.repository,
        settle: true,
      );
      await _openRefund(
        tester,
        advanceId: controller.summaries.single.advance.id,
      );
      await _selectRefundAccount(tester, accountFixture.account.name);
      await tester.enterText(
          find.byKey(const Key('advance-refund-amount')), '1.00');
      await tester.tap(find.byKey(const Key('advance-refund-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('موافقة المالك مطلوبة'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'رقم الهاتف'), '01000000000');
      await tester.enterText(
          find.widgetWithText(TextField, 'كلمة المرور'), 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'موافقة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('بيانات الدخول غير صحيحة.'), findsOneWidget);
      expect(controller.refundCalls, 1);
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.refundCalls, 1);
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
      await tester.pumpAndSettle();
    });
  });
}

final _owner = AppUser(
  id: 'owner-1',
  name: 'المالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _fixedDate,
  updatedAt: _fixedDate,
);

final _customer = Customer(
  id: 'customer-1',
  name: 'عميل الاختبار',
  isActive: true,
  createdAt: _fixedDate,
  updatedAt: _fixedDate,
);

final _fixedDate = DateTime.utc(2026, 7, 15);

CustomerAdvanceSummary _summary({
  String id = 'advance-visible',
  String accountId = 'account-1',
  int appliedQirsh = 0,
  int refundedQirsh = 0,
  int remainingQirsh = 200,
  bool reversed = false,
}) {
  return CustomerAdvanceSummary(
    advance: CustomerAdvance(
      id: id,
      customerId: _customer.id,
      sourceCollectionId: 'internal-collection-42',
      financialAccountId: accountId,
      amountQirsh: 200,
      createdAt: _fixedDate,
      createdByUserId: _owner.id,
      ownerApprovalId: 'internal-owner-approval',
      operationRequestId: 'internal-create-request',
      paymentMethod: PaymentMethod.cash,
      reversedAt: reversed ? _fixedDate : null,
      reversedByUserId: reversed ? _owner.id : null,
    ),
    appliedQirsh: appliedQirsh,
    refundedQirsh: refundedQirsh,
    remainingQirsh: remainingQirsh,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required CustomerController controller,
  FinancialAccountRepository? accounts,
  CustomerAdvanceApprovalPrompt? approvalPrompt,
  AppUser? user,
  Customer? customer,
  bool settle = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CustomerAdvanceActionsScreen(
        customer: customer ?? _customer,
        user: user ?? _owner,
        controller: controller,
        financialAccountRepository:
            accounts ?? LocalFinancialAccountRepository(),
        approvalPrompt: approvalPrompt,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _pumpDomainScreen(
  WidgetTester tester,
  _DomainFixture fixture, {
  CustomerAdvanceApprovalPrompt? approvalPrompt,
}) async {
  await _pumpScreen(
    tester,
    controller: fixture.controller,
    accounts: fixture.accounts,
    approvalPrompt: approvalPrompt,
    customer: fixture.customer,
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openApplication(
  WidgetTester tester, {
  String advanceId = 'advance-visible',
}) async {
  await tester.tap(find.byKey(Key('apply-advance-$advanceId')));
  await tester.pumpAndSettle();
}

Future<void> _openRefund(
  WidgetTester tester, {
  String advanceId = 'advance-visible',
}) async {
  await tester.tap(find.byKey(Key('refund-advance-$advanceId')));
  await tester.pumpAndSettle();
}

Future<void> _selectRefundAccount(
  WidgetTester tester,
  String accountName,
) async {
  await tester.tap(find.byKey(const Key('advance-refund-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(accountName).last);
  await tester.pumpAndSettle();
}

class _ProbeCustomerController extends CustomerController {
  _ProbeCustomerController({
    required List<CustomerAdvanceSummary> summaries,
    this.loadGate,
    this.failLoading = false,
    this.receivableQirsh = 10000,
    this.applyResult = const CustomerAdvanceActionResult.success(),
    this.applyGate,
    this.refundGate,
    this.refundRequiresApproval = false,
  })  : summaries = List<CustomerAdvanceSummary>.from(summaries),
        super(repository: LocalCustomerRepository());

  List<CustomerAdvanceSummary> summaries;
  final Completer<void>? loadGate;
  bool failLoading;
  final int receivableQirsh;
  final CustomerAdvanceActionResult applyResult;
  final Completer<CustomerAdvanceActionResult>? applyGate;
  final Completer<CustomerAdvanceActionResult>? refundGate;
  final bool refundRequiresApproval;
  int loadCalls = 0;
  int applyCalls = 0;
  int refundCalls = 0;
  final List<String> applyRequestIds = [];
  final List<String> refundRequestIds = [];
  final List<String?> refundApprovalIds = [];

  @override
  int balanceForCustomer(String customerId) => receivableQirsh;

  @override
  Future<List<CustomerAdvanceSummary>> advancesForCustomer(
    String customerId,
  ) async {
    loadCalls++;
    if (loadGate != null) await loadGate!.future;
    if (failLoading) throw StateError('technical load failure');
    return List<CustomerAdvanceSummary>.unmodifiable(summaries);
  }

  @override
  Future<CustomerAdvanceActionResult> applyCustomerAdvance({
    required AppUser user,
    required CustomerAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
  }) async {
    applyCalls++;
    applyRequestIds.add(operationRequestId);
    if (applyGate != null) return applyGate!.future;
    return applyResult;
  }

  @override
  Future<CustomerAdvanceActionResult> refundCustomerAdvance({
    required AppUser user,
    required CustomerAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
    required String financialAccountId,
    PaymentMethod? paymentMethod,
    String? negativeBalanceApprovalId,
  }) async {
    refundCalls++;
    refundRequestIds.add(operationRequestId);
    refundApprovalIds.add(negativeBalanceApprovalId);
    if (refundGate != null) return refundGate!.future;
    if (refundRequiresApproval && negativeBalanceApprovalId == null) {
      return const CustomerAdvanceActionResult.approvalRequired();
    }
    return const CustomerAdvanceActionResult.success();
  }
}

class _AccountFixture {
  const _AccountFixture({required this.repository, required this.account});

  final LocalFinancialAccountRepository repository;
  final FinancialAccount account;

  static Future<_AccountFixture> create({int balanceQirsh = 0}) async {
    final repository = LocalFinancialAccountRepository();
    final account = await repository.createAccount(
      FinancialAccountDraft(
        name: 'حساب السلفة',
        type: FinancialAccountType.treasury,
        allowNegativeBalance: true,
        createdByUserId: _owner.id,
      ),
    );
    if (balanceQirsh > 0) {
      await repository.setOpeningBalance(
        accountId: account.id,
        amountQirsh: balanceQirsh,
        effectiveDate: _fixedDate,
        createdByUserId: _owner.id,
      );
    }
    return _AccountFixture(repository: repository, account: account);
  }
}

class _DomainFixture {
  const _DomainFixture({
    required this.auth,
    required this.approvalRepository,
    required this.approvalService,
    required this.accounts,
    required this.customers,
    required this.ledger,
    required this.controller,
    required this.customer,
    required this.account,
    required this.advance,
  });

  final LocalAuthRepository auth;
  final LocalNegativeBalanceApprovalRepository approvalRepository;
  final NegativeBalanceApprovalService approvalService;
  final LocalFinancialAccountRepository accounts;
  final LocalCustomerRepository customers;
  final LocalCustomerAccountRepository ledger;
  final CustomerController controller;
  final Customer customer;
  final FinancialAccount account;
  final CustomerAdvance advance;

  static Future<_DomainFixture> create({bool drainAccount = false}) async {
    final audit = LocalAuditLogRepository();
    final auth = LocalAuthRepository(
      seedAccounts: [LocalAuthAccount(user: _owner, password: 'secret')],
    );
    final approvalRepository = LocalNegativeBalanceApprovalRepository();
    final approvalService = NegativeBalanceApprovalService(
      authRepository: auth,
      approvalRepository: approvalRepository,
      auditLogRepository: audit,
    );
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: audit,
      negativeBalanceApprovalService: approvalService,
    );
    final customers = LocalCustomerRepository(auditLogRepository: audit);
    final ledger = LocalCustomerAccountRepository(
      customerRepository: customers,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
      negativeBalanceApprovalService: approvalService,
    );
    final customer = await customers.createCustomer(
      const CustomerDraft(name: 'عميل الاختبار'),
    );
    final account = await accounts.createAccount(
      FinancialAccountDraft(
        name: 'حساب السلفة',
        type: FinancialAccountType.treasury,
        allowNegativeBalance: true,
        createdByUserId: _owner.id,
      ),
    );
    await ledger.createOpeningBalanceEntry(
      customerId: customer.id,
      amountQirsh: 100,
      createdByUserId: _owner.id,
    );
    const collectionRequestId = 'phase4-ui-seed-overpayment';
    final overpaymentApprovalId = await approvalService.requestApproval(
      draft: NegativeBalanceApprovalDraft(
        requestedByUserId: _owner.id,
        approvedByOwnerUserId: _owner.id,
        accountId: account.id,
        amountQirsh: 200,
        operationType: NegativeBalanceOperationType.customerOverpayment,
        sourceDocumentId: collectionRequestId,
        sourceDocumentType: 'customerOverpayment',
        balanceBeforeQirsh: 0,
        expectedBalanceAfterQirsh: 300,
        reason: 'إنشاء سلفة لاختبار الواجهة',
      ),
      ownerPhone: _owner.phone,
      ownerPassword: 'secret',
    );
    await ledger.createCollection(
      CustomerCollectionDraft(
        customerId: customer.id,
        date: _fixedDate,
        amountQirsh: 300,
        createdByUserId: _owner.id,
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
        operationRequestId: collectionRequestId,
        overpaymentApprovalId: overpaymentApprovalId,
      ),
    );
    final advance = (await ledger.listAdvances()).single;
    await ledger.createCreditSaleEntry(
      sale: SaleRecord(
        id: 'phase4-ui-credit-sale',
        productId: 'product-1',
        quantityKg: 1,
        salePriceQirshPerKg: 500,
        totalQirsh: 500,
        createdByUserId: _owner.id,
        createdAt: _fixedDate,
        stockMovementId: 'movement-1',
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      ),
      customerId: customer.id,
    );
    if (drainAccount) {
      await accounts.createEntry(
        accountId: account.id,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: 300,
        sourceType: FinancialAccountEntrySource.expense,
        sourceDocumentId: 'phase4-ui-drain-account',
        effectiveDate: _fixedDate,
        createdByUserId: _owner.id,
      );
    }
    final controller = CustomerController(
      repository: customers,
      accountRepository: ledger,
    );
    await controller.loadCustomers(_owner);
    return _DomainFixture(
      auth: auth,
      approvalRepository: approvalRepository,
      approvalService: approvalService,
      accounts: accounts,
      customers: customers,
      ledger: ledger,
      controller: controller,
      customer: customer,
      account: account,
      advance: advance,
    );
  }
}
