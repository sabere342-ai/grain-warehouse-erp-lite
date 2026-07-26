import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/features/opening_balances/opening_balance_amount_dialog.dart';
import 'package:grain_warehouse_erp_lite/features/supplier_accounts/supplier_statement_screen.dart';

void main() {
  group('Phase 101F customer opening-balance EGP input', () {
    testWidgets('converts جنيه input exactly and stores canonical qirsh',
        (tester) async {
      const cases = <String, int>{
        '1000': 100000,
        '1000.50': 100050,
        '0.25': 25,
        '1000.5': 100050,
      };

      for (final entry in cases.entries) {
        final amountQirsh = await _submitValidAmount(
          tester,
          party: OpeningBalanceParty.customer,
          input: entry.key,
        );
        expect(amountQirsh, entry.value, reason: 'input ${entry.key}');

        final customers = LocalCustomerRepository();
        final accounts = LocalCustomerAccountRepository(
          customerRepository: customers,
        );
        final customer = await customers.createCustomer(
          CustomerDraft(name: 'عميل ${entry.key}'),
        );
        await accounts.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: amountQirsh!,
          createdByUserId: 'owner-1',
        );

        expect(await accounts.balanceForCustomer(customer.id), entry.value);
        expect(
          MoneyUtils.formatPiastersAsEgp(entry.value),
          '${MoneyUtils.formatPiastersAsEgpNumber(entry.value)} ج.م',
        );
      }
    });

    testWidgets('rejects malformed, over-precision, zero, and overflow input',
        (tester) async {
      for (final input in [
        '1000.501',
        'not-money',
        '0',
        '-1',
        '999999999999999999999999999999999999999999.99',
      ]) {
        await _expectInvalidAmount(
          tester,
          party: OpeningBalanceParty.customer,
          input: input,
        );
      }
    });

    test('duplicate prevention remains enforced', () async {
      final customers = LocalCustomerRepository();
      final accounts = LocalCustomerAccountRepository(
        customerRepository: customers,
      );
      final customer = await customers.createCustomer(
        const CustomerDraft(name: 'عميل مكرر'),
      );

      await accounts.createOpeningBalanceEntry(
        customerId: customer.id,
        amountQirsh: 100050,
        createdByUserId: 'owner-1',
      );

      expect(
        accounts.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: 25,
          createdByUserId: 'owner-1',
        ),
        throwsStateError,
      );
    });
  });

  group('Phase 101F supplier opening-balance EGP input', () {
    testWidgets('converts جنيه input exactly and stores canonical qirsh',
        (tester) async {
      const cases = <String, int>{
        '1000': 100000,
        '1000.50': 100050,
        '0.25': 25,
        '1000.5': 100050,
      };

      for (final entry in cases.entries) {
        final amountQirsh = await _submitValidAmount(
          tester,
          party: OpeningBalanceParty.supplier,
          input: entry.key,
        );
        expect(amountQirsh, entry.value, reason: 'input ${entry.key}');

        final suppliers = LocalSupplierRepository();
        final accounts = LocalSupplierAccountRepository(
          supplierRepository: suppliers,
        );
        final supplier = await suppliers.createSupplier(
          SupplierDraft(name: 'مورد ${entry.key}'),
        );
        await accounts.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: amountQirsh!,
          createdByUserId: 'owner-1',
        );

        expect(await accounts.balanceForSupplier(supplier.id), entry.value);
        expect(
          MoneyUtils.formatPiastersAsEgp(entry.value),
          '${MoneyUtils.formatPiastersAsEgpNumber(entry.value)} ج.م',
        );
      }
    });

    testWidgets('rejects malformed, over-precision, zero, and overflow input',
        (tester) async {
      for (final input in [
        '1000.501',
        'not-money',
        '0',
        '-1',
        '999999999999999999999999999999999999999999.99',
      ]) {
        await _expectInvalidAmount(
          tester,
          party: OpeningBalanceParty.supplier,
          input: input,
        );
      }
    });

    test('duplicate prevention remains enforced', () async {
      final suppliers = LocalSupplierRepository();
      final accounts = LocalSupplierAccountRepository(
        supplierRepository: suppliers,
      );
      final supplier = await suppliers.createSupplier(
        const SupplierDraft(name: 'مورد مكرر'),
      );

      await accounts.createOpeningBalanceEntry(
        supplierId: supplier.id,
        amountQirsh: 100050,
        createdByUserId: 'owner-1',
      );

      expect(
        accounts.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 25,
          createdByUserId: 'owner-1',
        ),
        throwsStateError,
      );
    });

    testWidgets('supplier statement renders the exact EGP opening balance',
        (tester) async {
      final suppliers = LocalSupplierRepository();
      final accounts = LocalSupplierAccountRepository(
        supplierRepository: suppliers,
      );
      final supplier = await suppliers.createSupplier(
        const SupplierDraft(name: 'مورد كشف الحساب'),
      );
      await accounts.createOpeningBalanceEntry(
        supplierId: supplier.id,
        amountQirsh: 87525,
        createdByUserId: 'owner-1',
      );

      final previousRepository = AppRepositories.supplierAccountRepository;
      AppRepositories.supplierAccountRepository = accounts;
      addTearDown(() {
        AppRepositories.supplierAccountRepository = previousRepository;
      });

      final auth = AuthController(repository: LocalAuthRepository.demo());
      addTearDown(auth.dispose);
      await auth.initialize();
      await auth.signIn(phone: '01000000000', password: 'owner123');

      await tester.pumpWidget(
        AuthScope(
          controller: auth,
          child: MaterialApp(
            locale: const Locale('ar'),
            home: SupplierStatementScreen(supplier: supplier),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('875.25 ج.م'), findsNWidgets(3));
      expect(find.text('رصيد افتتاحي للمورد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<int?> _submitValidAmount(
  WidgetTester tester, {
  required OpeningBalanceParty party,
  required String input,
}) async {
  int? submittedAmount;
  await tester.pumpWidget(_dialogHarness(
    party: party,
    onSubmitted: (value) => submittedAmount = value,
  ));

  await tester.tap(find.byKey(const ValueKey('open-opening-balance-dialog')));
  await tester.pumpAndSettle();

  expect(
    find.text(
      party == OpeningBalanceParty.customer
          ? 'رصيد افتتاحي للعميل'
          : 'رصيد افتتاحي للمورد',
    ),
    findsOneWidget,
  );
  expect(find.text('الرصيد الافتتاحي (جنيه)'), findsOneWidget);
  expect(find.textContaining('بقروش'), findsNothing);
  expect(find.textContaining('بالقرش'), findsNothing);

  await tester.enterText(
    find.byKey(const ValueKey('opening-balance-egp-input')),
    input,
  );
  await tester.tap(find.text('حفظ الرصيد الافتتاحي'));
  await tester.pumpAndSettle();

  return submittedAmount;
}

Future<void> _expectInvalidAmount(
  WidgetTester tester, {
  required OpeningBalanceParty party,
  required String input,
}) async {
  int? submittedAmount;
  await tester.pumpWidget(_dialogHarness(
    party: party,
    onSubmitted: (value) => submittedAmount = value,
  ));

  await tester.tap(find.byKey(const ValueKey('open-opening-balance-dialog')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('opening-balance-egp-input')),
    input,
  );
  await tester.tap(find.text('حفظ الرصيد الافتتاحي'));
  await tester.pumpAndSettle();

  expect(submittedAmount, isNull, reason: 'input $input');
  expect(
    find.text(
      'أدخل مبلغًا صحيحًا بالجنيه أكبر من صفر وبحد أقصى خانتان عشريتان.',
    ),
    findsOneWidget,
  );

  Navigator.of(
    tester.element(find.byType(OpeningBalanceAmountDialog)),
  ).pop();
  await tester.pumpAndSettle();
}

Widget _dialogHarness({
  required OpeningBalanceParty party,
  required ValueChanged<int?> onSubmitted,
}) {
  return MaterialApp(
    locale: const Locale('ar'),
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          key: const ValueKey('open-opening-balance-dialog'),
          onPressed: () async {
            final value = await showDialog<int>(
              context: context,
              builder: (_) => OpeningBalanceAmountDialog(party: party),
            );
            onSubmitted(value);
          },
          child: const Text('فتح'),
        ),
      ),
    ),
  );
}
