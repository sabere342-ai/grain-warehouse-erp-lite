import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

int _counterFromId(String id) {
  final parts = id.split('-');
  return int.parse(parts.last);
}

void main() {
  group('LocalProductRepository snapshot restores counter on rollback', () {
    test('counter and list are both restored after failed transaction',
        () async {
      final repo = LocalProductRepository();
      final p1 = await repo.createProduct(
        const ProductDraft(name: 'P1', unit: GrainUnit.kilogram),
      );
      final p2 = await repo.createProduct(
        const ProductDraft(name: 'P2', unit: GrainUnit.kilogram),
      );

      final productsBefore = await repo.listProducts();
      expect(productsBefore, hasLength(2));
      expect(_counterFromId(p1.id), 1);
      expect(_counterFromId(p2.id), 2);

      final snapshot = repo.createTransactionSnapshot();
      snapshot.capture();

      final p3 = await repo.createProduct(
        const ProductDraft(name: 'P3', unit: GrainUnit.kilogram),
      );
      expect(_counterFromId(p3.id), 3);
      expect(await repo.listProducts(), hasLength(3));

      snapshot.rollback();

      final productsAfter = await repo.listProducts();
      expect(productsAfter, hasLength(2));

      final pNew = await repo.createProduct(
        const ProductDraft(name: 'P-new', unit: GrainUnit.kilogram),
      );
      expect(_counterFromId(pNew.id), 3);
      expect(await repo.listProducts(), hasLength(3));
    });
  });

  group('LocalCustomerRepository snapshot restores counter on rollback', () {
    test('counter and list are both restored after failed transaction',
        () async {
      final repo = LocalCustomerRepository();
      final c1 = await repo.createCustomer(const CustomerDraft(name: 'C1'));
      final c2 = await repo.createCustomer(const CustomerDraft(name: 'C2'));

      final customersBefore = await repo.listCustomers();
      expect(customersBefore, hasLength(2));
      expect(_counterFromId(c1.id), 1);
      expect(_counterFromId(c2.id), 2);

      final snapshot = repo.createTransactionSnapshot();
      snapshot.capture();

      final c3 = await repo.createCustomer(const CustomerDraft(name: 'C3'));
      expect(_counterFromId(c3.id), 3);
      expect(await repo.listCustomers(), hasLength(3));

      snapshot.rollback();

      final customersAfter = await repo.listCustomers();
      expect(customersAfter, hasLength(2));

      final cNew = await repo.createCustomer(
        const CustomerDraft(name: 'C-new'),
      );
      expect(_counterFromId(cNew.id), 3);
      expect(await repo.listCustomers(), hasLength(3));
    });
  });

  group('LocalSupplierRepository snapshot restores counter on rollback', () {
    test('counter and list are both restored after failed transaction',
        () async {
      final repo = LocalSupplierRepository();
      final s1 = await repo.createSupplier(
        const SupplierDraft(name: 'S1', phone: '01000000001'),
      );
      final s2 = await repo.createSupplier(
        const SupplierDraft(name: 'S2', phone: '01000000002'),
      );

      final suppliersBefore = await repo.listSuppliers();
      expect(suppliersBefore, hasLength(2));
      expect(_counterFromId(s1.id), 1);
      expect(_counterFromId(s2.id), 2);

      final snapshot = repo.createTransactionSnapshot();
      snapshot.capture();

      final s3 = await repo.createSupplier(
        const SupplierDraft(name: 'S3', phone: '01000000003'),
      );
      expect(_counterFromId(s3.id), 3);
      expect(await repo.listSuppliers(), hasLength(3));

      snapshot.rollback();

      final suppliersAfter = await repo.listSuppliers();
      expect(suppliersAfter, hasLength(2));

      final sNew = await repo.createSupplier(
        const SupplierDraft(name: 'S-new', phone: '01000000004'),
      );
      expect(_counterFromId(sNew.id), 3);
      expect(await repo.listSuppliers(), hasLength(3));
    });
  });

  group('Transaction rollback restores all three repos', () {
    test('product, customer, supplier snapshots restore after wipe', () async {
      final products = LocalProductRepository();
      final customers = LocalCustomerRepository();
      final suppliers = LocalSupplierRepository();

      await products.createProduct(
        const ProductDraft(name: 'wheat', unit: GrainUnit.kilogram),
      );
      await customers.createCustomer(const CustomerDraft(name: 'ahmed'));
      await suppliers.createSupplier(
        const SupplierDraft(name: 'farm', phone: '01011112222'),
      );

      final productSnap = products.createTransactionSnapshot();
      final customerSnap = customers.createTransactionSnapshot();
      final supplierSnap = suppliers.createTransactionSnapshot();

      productSnap.capture();
      customerSnap.capture();
      supplierSnap.capture();

      await products.clearForOwnerDataWipe();
      await customers.clearForOwnerDataWipe();
      await suppliers.clearForOwnerDataWipe();

      expect(await products.listProducts(), isEmpty);
      expect(await customers.listCustomers(), isEmpty);
      expect(await suppliers.listSuppliers(), isEmpty);

      productSnap.rollback();
      customerSnap.rollback();
      supplierSnap.rollback();

      expect(await products.listProducts(), hasLength(1));
      expect(await customers.listCustomers(), hasLength(1));
      expect(await suppliers.listSuppliers(), hasLength(1));

      final nextProduct = await products.createProduct(
        const ProductDraft(name: 'corn', unit: GrainUnit.kilogram),
      );
      final nextCustomer = await customers.createCustomer(
        const CustomerDraft(name: 'sara'),
      );
      final nextSupplier = await suppliers.createSupplier(
        const SupplierDraft(name: 'depot', phone: '01033334444'),
      );

      expect(_counterFromId(nextProduct.id), 2);
      expect(_counterFromId(nextCustomer.id), 2);
      expect(_counterFromId(nextSupplier.id), 2);
    });
  });
}
