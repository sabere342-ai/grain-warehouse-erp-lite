import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

/// Durable adapter that deliberately delegates domain validation and side
/// effects to the characterized in-memory implementation. Only storage and
/// serialization are different, which keeps Phase 8G behavior parity narrow.
class DriftSaleRepository implements DurableSaleRepository {
  DriftSaleRepository(
    this._database, {
    required ProductRepository productRepository,
    required InventoryRepository inventoryRepository,
  }) : _delegate = LocalSaleRepository(
          productRepository: productRepository,
          inventoryRepository: inventoryRepository,
        );

  final db.FoundationDatabase _database;
  final LocalSaleRepository _delegate;
  Future<void> _tail = Future<void>.value();
  bool _loaded = false;

  Future<T> _serialized<T>(Future<T> Function() action) async {
    final completion = Completer<void>();
    final previous = _tail;
    _tail = completion.future;
    await previous.catchError((_) {});
    try {
      return await action();
    } finally {
      completion.complete();
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final rows = await (_database.select(_database.sales)
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .get();
    if (rows.isNotEmpty) {
      await _delegate.restoreSalesIntoEmpty(rows.map(_toDomain).toList());
    }
    _loaded = true;
  }

  @override
  Future<SaleRecord> createSale(SaleDraft draft) => _serialized(() async {
        await _ensureLoaded();
        final snapshot = _delegate.createTransactionSnapshot();
        await snapshot.capture();
        try {
          return await _database.inTransaction(() async {
            final sale = await _delegate.createSale(draft);
            await _database.into(_database.sales).insert(_toCompanion(sale));
            return sale;
          });
        } catch (_) {
          await snapshot.rollback();
          rethrow;
        }
      });

  @override
  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) =>
      _serialized(() async {
        await _ensureLoaded();
        final snapshot = _delegate.createTransactionSnapshot();
        await snapshot.capture();
        try {
          return await _database.inTransaction(() async {
            final sale = await _delegate.cancelSale(
              saleId: saleId,
              cancelledByUserId: cancelledByUserId,
              cancellationReason: cancellationReason,
            );
            await (_database.update(_database.sales)
                  ..where((table) => table.id.equals(sale.id)))
                .write(_toCompanion(sale));
            return sale;
          });
        } catch (_) {
          await snapshot.rollback();
          rethrow;
        }
      });

  @override
  Future<List<SaleRecord>> listSales() => _serialized(() async {
        await _ensureLoaded();
        return _delegate.listSales();
      });

  @override
  Future<void> restoreSalesIntoEmpty(List<SaleRecord> sales) =>
      _serialized(() async {
        await _ensureLoaded();
        final snapshot = _delegate.createTransactionSnapshot();
        await snapshot.capture();
        try {
          await _database.inTransaction(() async {
            await _delegate.restoreSalesIntoEmpty(sales);
            for (final sale in sales) {
              await _database.into(_database.sales).insert(_toCompanion(sale));
            }
          });
        } catch (_) {
          await snapshot.rollback();
          rethrow;
        }
      });

  @override
  Future<void> clearForOwnerDataWipe() => _serialized(() async {
        await _ensureLoaded();
        await _database.inTransaction(() async {
          await _database.delete(_database.sales).go();
          await _delegate.clearForOwnerDataWipe();
        });
      });

  @override
  SnapshotHolder createTransactionSnapshot() => _DriftSaleSnapshot(this);

  db.SalesCompanion _toCompanion(SaleRecord sale) {
    final cancellation = sale.cancellation;
    return db.SalesCompanion.insert(
      id: sale.id,
      productId: sale.productId,
      quantityKg: sale.quantityKg,
      salePriceQirshPerKg: sale.salePriceQirshPerKg,
      totalQirsh: sale.totalQirsh,
      createdByUserId: sale.createdByUserId,
      createdAt: sale.createdAt,
      stockMovementId: sale.stockMovementId,
      paymentMode: sale.paymentMode.name,
      itemsJson: jsonEncode(sale.items
          .map((item) => {
                'productId': item.productId,
                'quantityKg': item.quantityKg,
                'salePriceQirshPerKg': item.salePriceQirshPerKg,
                'lineTotalQirsh': item.lineTotalQirsh,
              })
          .toList()),
      paymentAllocationsJson: jsonEncode(sale.paymentAllocations
          .map((allocation) => {
                'financialAccountId': allocation.financialAccountId,
                'amountQirsh': allocation.amountQirsh,
                'paymentMethod': allocation.paymentMethod.name,
              })
          .toList()),
      createdByUserName: Value(sale.createdByUserName),
      customerId: Value(sale.customerId),
      notes: Value(sale.notes),
      paidAmountQirsh: Value(sale.paidAmountQirsh),
      financialAccountId: Value(sale.financialAccountId),
      paymentMethod: Value(sale.paymentMethod?.name),
      operationRequestId: Value(sale.operationRequestId),
      cancelledAt: Value(cancellation?.cancelledAt),
      cancelledByUserId: Value(cancellation?.cancelledByUserId),
      cancellationReason: Value(cancellation?.cancellationReason),
      reversalMovementIdsJson: Value(cancellation == null
          ? null
          : jsonEncode(cancellation.reversalMovementIds)),
    );
  }

  SaleRecord _toDomain(db.Sale row) {
    final items = (jsonDecode(row.itemsJson) as List)
        .cast<Map<String, Object?>>()
        .map((item) => SaleLineItem(
              productId: item['productId']! as String,
              quantityKg: item['quantityKg']! as int,
              salePriceQirshPerKg: item['salePriceQirshPerKg']! as int,
              lineTotalQirsh: item['lineTotalQirsh']! as int,
            ))
        .toList(growable: false);
    final allocations = (jsonDecode(row.paymentAllocationsJson) as List)
        .cast<Map<String, Object?>>()
        .map((allocation) => SalePaymentAllocation(
              financialAccountId:
                  allocation['financialAccountId']! as String,
              amountQirsh: allocation['amountQirsh']! as int,
              paymentMethod: PaymentMethod.values
                  .byName(allocation['paymentMethod']! as String),
            ))
        .toList(growable: false);
    return SaleRecord(
      id: row.id,
      productId: row.productId,
      quantityKg: row.quantityKg,
      salePriceQirshPerKg: row.salePriceQirshPerKg,
      totalQirsh: row.totalQirsh,
      createdByUserId: row.createdByUserId,
      createdByUserName: row.createdByUserName,
      createdAt: row.createdAt,
      stockMovementId: row.stockMovementId,
      paymentMode: SalePaymentMode.values.byName(row.paymentMode),
      customerId: row.customerId,
      notes: row.notes,
      items: items,
      paidAmountQirsh: row.paidAmountQirsh,
      financialAccountId: row.financialAccountId,
      paymentMethod: row.paymentMethod == null
          ? null
          : PaymentMethod.values.byName(row.paymentMethod!),
      paymentAllocations: allocations,
      operationRequestId: row.operationRequestId,
      cancellation: row.cancelledAt == null
          ? null
          : CancellationMetadata(
              cancelledAt: row.cancelledAt!,
              cancelledByUserId: row.cancelledByUserId!,
              cancellationReason: row.cancellationReason!,
              originalDocumentId: row.id,
              reversalMovementIds:
                  (jsonDecode(row.reversalMovementIdsJson!) as List)
                      .cast<String>(),
            ),
    );
  }
}

class _DriftSaleSnapshot extends SnapshotHolder {
  _DriftSaleSnapshot(this._repository);

  final DriftSaleRepository _repository;
  List<SaleRecord>? _sales;

  @override
  Future<void> capture() async {
    _sales = await _repository.listSales();
  }

  @override
  Future<void> rollback() async {
    final sales = _sales;
    if (sales == null) return;
    await _repository.clearForOwnerDataWipe();
    await _repository.restoreSalesIntoEmpty(sales);
  }
}
