import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
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

      final faRepo = _financialAccountRepository;
      if (faRepo != null &&
          financialAccountId != null &&
          financialAccountId.isNotEmpty &&
          (paymentMode == SalePaymentMode.cash ||
              paymentMode == SalePaymentMode.partial)) {
        final paidAmount = sale.effectivePaidAmountQirsh;
        if (paidAmount > 0) {
          await faRepo.createEntry(
            accountId: financialAccountId,
            direction: FinancialAccountEntryDirection.inflow,
            amountQirsh: paidAmount,
            sourceType: FinancialAccountEntrySource.salePayment,
            sourceDocumentId: sale.id,
            effectiveDate: sale.createdAt,
            createdByUserId: user.id,
            reference: 'دفعة مبيعات - فاتورة ${sale.id}',
            note: paymentMode == SalePaymentMode.partial
                ? 'دفع جزئي للفاتورة'
                : 'دفعة كاملة للفاتورة',
            paymentMethod: paymentMethod,
          );
        }
      }

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
  }) async {
    if (!_canCancelPostedDocument(user)) {
      return false;
    }

    try {
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

      final faRepo = _financialAccountRepository;
      if (faRepo != null &&
          cancelled.financialAccountId != null &&
          cancelled.financialAccountId!.isNotEmpty &&
          !cancelled.isCreditSale) {
        final paidAmount = cancelled.effectivePaidAmountQirsh;
        if (paidAmount > 0) {
          await faRepo.createEntry(
            accountId: cancelled.financialAccountId!,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: paidAmount,
            sourceType: FinancialAccountEntrySource.cancellationReversal,
            sourceDocumentId: cancelled.id,
            effectiveDate: DateTime.now(),
            createdByUserId: user.id,
            reversalOf: cancelled.id,
            reference: 'عكس إلغاء فاتورة ${cancelled.id}',
            note: 'إلغاء فاتورة مبيعات: $cancellationReason',
            paymentMethod: cancelled.paymentMethod,
            negativeBalanceApprovalId: negativeBalanceApprovalId,
          );
        }
      }

      await load(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
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
