import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

class SaleController extends ChangeNotifier {
  SaleController({
    required SaleRepository saleRepository,
    required ProductRepository productRepository,
    required InventoryRepository inventoryRepository,
    CustomerRepository? customerRepository,
    CustomerAccountRepository? customerAccountRepository,
    FinancialAccountRepository? financialAccountRepository,
  })  : _saleRepository = saleRepository,
        _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _customerRepository = customerRepository,
        _customerAccountRepository = customerAccountRepository,
        _financialAccountRepository = financialAccountRepository;

  final SaleRepository _saleRepository;
  final ProductRepository _productRepository;
  final InventoryRepository _inventoryRepository;
  final CustomerRepository? _customerRepository;
  final CustomerAccountRepository? _customerAccountRepository;
  final FinancialAccountRepository? _financialAccountRepository;

  List<SaleRecord> _sales = const [];
  List<Product> _products = const [];
  List<Customer> _customers = const [];
  Map<String, int> _stockByProductId = const {};
  String? _errorMessage;
  bool _isLoading = false;

  List<SaleRecord> get sales => List<SaleRecord>.unmodifiable(_sales);
  List<Product> get products => List<Product>.unmodifiable(_products);
  List<Customer> get customers => List<Customer>.unmodifiable(_customers);
  Map<String, int> get stockByProductId =>
      Map<String, int>.unmodifiable(_stockByProductId);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  int stockForProduct(String productId) => _stockByProductId[productId] ?? 0;

  Future<void> load(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _sales = await _saleRepository.listSales();
    _products = await _productRepository.listProducts(includeInactive: false);
    _stockByProductId = await _inventoryRepository.allProductBalancesKg(
      activeProductsOnly: true,
    );
    _customers = await _customerRepository?.listCustomers(
          includeInactive: false,
        ) ??
        const [];

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createSale({
    required AppUser user,
    required String productId,
    required int quantityKg,
    required int salePriceQirshPerKg,
    String? notes,
    SalePaymentMode paymentMode = SalePaymentMode.cash,
    String? customerId,
    List<SaleLineItemDraft> items = const [],
    int? paidAmountQirsh,
    String? financialAccountId,
    PaymentMethod? paymentMethod,
    List<SalePaymentAllocation> paymentAllocations = const [],
    String? operationRequestId,
  }) async {
    if (!_canCreateSale(user)) {
      return false;
    }

    try {
      final selectedCustomer = await _findActiveCustomer(customerId);

      final saleItems = items.isNotEmpty
          ? items
          : [
              SaleLineItemDraft(
                productId: productId,
                quantityKg: quantityKg,
                salePriceQirshPerKg: salePriceQirshPerKg,
              ),
            ];

      if (paymentAllocations.isNotEmpty &&
          _financialAccountRepository == null) {
        throw StateError(
            'Split payments require the financial accounts repository.');
      }

      await _runWithinAtomicBoundary(
        // Existing one-account callers may use older adapters that do not
        // expose snapshots. New allocation-based requests fail closed unless
        // every participant can join the same rollback boundary.
        requireAtomic: paymentAllocations.isNotEmpty,
        operation: () async {
          final sale = await _saleRepository.createSale(
            SaleDraft(
              productId: productId,
              quantityKg: quantityKg,
              salePriceQirshPerKg: salePriceQirshPerKg,
              createdByUserId: user.id,
              paymentMode: paymentMode,
              customerId: selectedCustomer.id,
              createdByUserName: user.name,
              notes: notes,
              items: saleItems,
              paidAmountQirsh: paidAmountQirsh,
              financialAccountId: financialAccountId,
              paymentMethod: paymentMethod,
              paymentAllocations: paymentAllocations,
              operationRequestId: operationRequestId,
            ),
          );

          final accountRepo = _customerAccountRepository;
          if (accountRepo != null) {
            if (paymentMode == SalePaymentMode.cash ||
                paymentMode == SalePaymentMode.partial) {
              await accountRepo.createCashSaleEntry(
                sale: sale,
                customerId: selectedCustomer.id,
              );
            } else if (paymentMode == SalePaymentMode.credit) {
              await accountRepo.createCreditSaleEntry(
                sale: sale,
                customerId: selectedCustomer.id,
              );
            }
          }

          await _postSalePaymentAllocations(sale: sale, user: user);
        },
      );

      await load(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelSale({
    required AppUser user,
    required String saleId,
    required String cancellationReason,
    String? negativeBalanceApprovalId,
    Map<String, String> negativeBalanceApprovalIdsByAccount = const {},
  }) async {
    if (!_canCancelPostedDocument(user)) {
      return false;
    }

    try {
      var requiresAtomicSplitReversal = false;
      for (final sale in await _saleRepository.listSales()) {
        if (sale.id == saleId) {
          requiresAtomicSplitReversal = sale.paymentAllocations.length > 1;
          break;
        }
      }
      await _runWithinAtomicBoundary(
        requireAtomic: requiresAtomicSplitReversal,
        operation: () async {
          SaleRecord? existing;
          for (final sale in await _saleRepository.listSales()) {
            if (sale.id == saleId) {
              existing = sale;
              break;
            }
          }
          if (existing == null) {
            throw StateError('Sale was not found.');
          }
          if (existing.isCancelled) {
            throw StateError('Sale was already cancelled.');
          }
          final cancelled = await _saleRepository.cancelSale(
            saleId: saleId,
            cancelledByUserId: user.id,
            cancellationReason: cancellationReason,
          );
          final accountRepo = _customerAccountRepository;
          if (accountRepo != null && cancelled.customerId != null) {
            await accountRepo.reverseSaleEntry(
              cancelledSale: cancelled,
              cancelledByUserId: user.id,
              cancellationReason: cancellationReason,
            );
          }
          await _reverseSalePaymentAllocations(
            cancelledSale: cancelled,
            user: user,
            cancellationReason: cancellationReason,
            legacyNegativeBalanceApprovalId: negativeBalanceApprovalId,
            negativeBalanceApprovalIdsByAccount:
                negativeBalanceApprovalIdsByAccount,
          );
        },
      );

      await load(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> _runWithinAtomicBoundary({
    required bool requireAtomic,
    required Future<void> Function() operation,
  }) async {
    final participants = <Object>[
      _saleRepository,
      _inventoryRepository,
      if (_customerAccountRepository case final repository?) repository,
      if (_financialAccountRepository case final repository?) repository,
    ];
    if (participants.any((value) => value is! TransactionSnapshotProvider)) {
      if (requireAtomic) {
        throw StateError(
          'Sale payment participants do not support atomic transactions.',
        );
      }
      await operation();
      return;
    }
    late final List<SnapshotHolder> snapshots;
    try {
      snapshots = participants
          .cast<TransactionSnapshotProvider>()
          .map((participant) => participant.createTransactionSnapshot())
          .toList(growable: false);
    } on StateError {
      if (requireAtomic) rethrow;
      await operation();
      return;
    }
    await RepositoryTransaction.execute(snapshots, operation);
  }

  Future<void> _postSalePaymentAllocations({
    required SaleRecord sale,
    required AppUser user,
  }) async {
    final allocations = _paymentAllocationsFor(sale);
    if (allocations.isEmpty) return;
    final repository = _financialAccountRepository;
    if (repository == null) {
      throw StateError('Financial accounts are required for sale payments.');
    }
    for (final allocation in allocations) {
      final account =
          await repository.accountById(allocation.financialAccountId);
      if (!account.isActive) {
        throw StateError('Inactive financial account cannot receive payment.');
      }
      await repository.createEntry(
        accountId: allocation.financialAccountId,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: allocation.amountQirsh,
        sourceType: FinancialAccountEntrySource.salePayment,
        sourceDocumentId: sale.id,
        effectiveDate: sale.createdAt,
        createdByUserId: user.id,
        reference: 'دفعة مبيعات - فاتورة ${sale.id}',
        note: sale.isPartialPayment
            ? 'جزء من دفع فاتورة مبيعات'
            : 'دفع فاتورة مبيعات',
        paymentMethod: allocation.paymentMethod,
      );
    }
  }

  Future<void> _reverseSalePaymentAllocations({
    required SaleRecord cancelledSale,
    required AppUser user,
    required String cancellationReason,
    required String? legacyNegativeBalanceApprovalId,
    required Map<String, String> negativeBalanceApprovalIdsByAccount,
  }) async {
    final allocations = _paymentAllocationsFor(cancelledSale);
    if (allocations.isEmpty) return;
    final repository = _financialAccountRepository;
    if (repository == null) {
      throw StateError(
          'Financial accounts are required to reverse sale payments.');
    }
    final now = DateTime.now();
    for (final allocation in allocations) {
      final statement = await repository.statementForAccount(
        allocation.financialAccountId,
      );
      final originals = statement.lines
          .map((line) => line.entry)
          .where(
            (entry) =>
                entry.sourceType == FinancialAccountEntrySource.salePayment &&
                entry.sourceDocumentId == cancelledSale.id &&
                entry.amountQirsh == allocation.amountQirsh &&
                entry.paymentMethod == allocation.paymentMethod &&
                entry.reversalOf == null,
          )
          .toList(growable: false);
      if (originals.length != 1) {
        throw StateError(
            'Original financial entry for sale payment was not found.');
      }
      await repository.createEntry(
        accountId: allocation.financialAccountId,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: allocation.amountQirsh,
        sourceType: FinancialAccountEntrySource.cancellationReversal,
        sourceDocumentId: cancelledSale.id,
        effectiveDate: now,
        createdByUserId: user.id,
        reversalOf: originals.single.id,
        reference: 'عكس إلغاء فاتورة ${cancelledSale.id}',
        note: 'إلغاء فاتورة مبيعات: $cancellationReason',
        paymentMethod: allocation.paymentMethod,
        negativeBalanceApprovalId: negativeBalanceApprovalIdsByAccount[
                allocation.financialAccountId] ??
            legacyNegativeBalanceApprovalId,
      );
    }
  }

  List<SalePaymentAllocation> _paymentAllocationsFor(SaleRecord sale) {
    if (sale.paymentAllocations.isNotEmpty) {
      return sale.paymentAllocations;
    }
    final accountId = sale.financialAccountId?.trim();
    if (accountId == null || accountId.isEmpty || sale.isCreditSale) {
      return const [];
    }
    final amount = sale.effectivePaidAmountQirsh;
    if (amount <= 0) return const [];
    return [
      SalePaymentAllocation(
        financialAccountId: accountId,
        amountQirsh: amount,
        paymentMethod: sale.paymentMethod ?? PaymentMethod.cash,
      ),
    ];
  }

  Future<Customer> _findActiveCustomer(String? customerId) async {
    final id = customerId?.trim();
    if (id == null || id.isEmpty) {
      throw ArgumentError.value(customerId, 'customerId',
          '\u0627\u062e\u062a\u0631 \u0627\u0644\u0639\u0645\u064a\u0644 \u0642\u0628\u0644 \u062d\u0641\u0638 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629.');
    }
    final customers = await _customerRepository!.listCustomers(
      includeInactive: true,
    );
    for (final customer in customers) {
      if (customer.id == id) {
        if (!customer.isActive) {
          throw StateError(
              '\u0627\u0644\u0639\u0645\u064a\u0644 \u063a\u064a\u0631 \u0646\u0634\u0637 \u0648\u0644\u0627 \u064a\u0645\u0643\u0646 \u0627\u0644\u0628\u064a\u0639 \u0644\u0647.');
        }
        return customer;
      }
    }
    throw StateError(
        '\u0627\u0644\u0639\u0645\u064a\u0644 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f.');
  }

  String productName(String productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product.name;
      }
    }

    return '\u0635\u0646\u0641 \u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641';
  }

  String customerName(String? customerId) {
    if (customerId == null) {
      return '';
    }
    for (final customer in _customers) {
      if (customer.id == customerId) {
        return customer.name;
      }
    }
    return '\u0639\u0645\u064a\u0644 \u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641';
  }

  bool _canCreateSale(AppUser user) {
    if (!user.canProceed) {
      _errorMessage =
          '\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0628\u0645\u0633\u062a\u062e\u062f\u0645 \u0635\u0627\u0644\u062d.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canCreateSale) {
      return true;
    }

    _errorMessage =
        '\u0644\u0627 \u064a\u0645\u0644\u0643 \u0647\u0630\u0627 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 \u0635\u0644\u0627\u062d\u064a\u0629 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0628\u064a\u0639.';
    notifyListeners();
    return false;
  }

  bool _canCancelPostedDocument(AppUser user) {
    if (!user.canProceed) {
      _errorMessage =
          '\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0628\u0645\u0633\u062a\u062e\u062f\u0645 \u0635\u0627\u0644\u062d.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canCancelInvoice) {
      return true;
    }

    _errorMessage =
        '\u0644\u0627 \u064a\u0645\u0644\u0643 \u0647\u0630\u0627 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 \u0635\u0644\u0627\u062d\u064a\u0629 \u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u0645\u0631\u062d\u0644\u0629.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is MinimumSalePriceViolation) {
      return '\u0633\u0639\u0631 \u0627\u0644\u0628\u064a\u0639 \u0623\u0642\u0644 \u0645\u0646 \u0627\u0644\u062d\u062f \u0627\u0644\u0623\u062f\u0646\u0649 \u0627\u0644\u0645\u062d\u062f\u062f \u0644\u0644\u0635\u0646\u0641.';
    }
    if (error is ArgumentError) {
      return '\u062a\u062d\u0642\u0642 \u0645\u0646 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0628\u064a\u0639\u060c \u0648\u0627\u0644\u0628\u064a\u0639 \u064a\u062a\u0637\u0644\u0628 \u0639\u0645\u064a\u0644\u0627 \u0646\u0634\u0637\u0627.';
    }
    if (error is StateError) {
      return '\u0644\u0627 \u064a\u0645\u0643\u0646 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0628\u064a\u0639 \u0644\u0647\u0630\u0647 \u0627\u0644\u0643\u0645\u064a\u0629 \u0623\u0648 \u0627\u0644\u0635\u0646\u0641 \u0623\u0648 \u0627\u0644\u0639\u0645\u064a\u0644.';
    }

    return '\u062a\u0639\u0630\u0631 \u062d\u0641\u0638 \u0627\u0644\u0628\u064a\u0639.';
  }
}
