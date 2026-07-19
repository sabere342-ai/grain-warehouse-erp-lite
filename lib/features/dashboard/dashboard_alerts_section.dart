// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/premium_card.dart';

class OwnerAlertData {
  final List<_CustomerBalanceAlert> customerAlerts;
  final List<_SupplierPayableAlert> supplierAlerts;
  final List<_LowStockAlert> stockAlerts;

  const OwnerAlertData({
    required this.customerAlerts,
    required this.supplierAlerts,
    required this.stockAlerts,
  });

  bool get hasAnyAlert =>
      customerAlerts.isNotEmpty ||
      supplierAlerts.isNotEmpty ||
      stockAlerts.isNotEmpty;

  factory OwnerAlertData.empty() => const OwnerAlertData(
        customerAlerts: [],
        supplierAlerts: [],
        stockAlerts: [],
      );

  static Future<OwnerAlertData> load({
    CustomerRepository? customerRepository,
    SupplierRepository? supplierRepository,
    CustomerAccountRepository? customerAccountRepository,
    SupplierAccountRepository? supplierAccountRepository,
    ProductRepository? productRepository,
    InventoryRepository? inventoryRepository,
    InventoryAttentionService? inventoryAttentionService,
  }) async {
    final customers =
        await (customerRepository ?? AppRepositories.customerRepository)
            .listCustomers();
    final customerBalances = await (customerAccountRepository ??
            AppRepositories.customerAccountRepository)
        .balancesByCustomerId();
    final customerAlerts = <_CustomerBalanceAlert>[];
    for (final c in customers) {
      final b = customerBalances[c.id] ?? 0;
      if (b > 0) {
        customerAlerts.add(_CustomerBalanceAlert(
          customerName: c.name,
          balanceQirsh: b,
        ));
      }
    }
    customerAlerts.sort((a, b) => b.balanceQirsh.compareTo(a.balanceQirsh));

    final suppliers =
        await (supplierRepository ?? AppRepositories.supplierRepository)
            .listSuppliers();
    final supplierBalances = await (supplierAccountRepository ??
            AppRepositories.supplierAccountRepository)
        .balancesBySupplierId();
    final supplierAlerts = <_SupplierPayableAlert>[];
    for (final s in suppliers) {
      final b = supplierBalances[s.id] ?? 0;
      if (b > 0) {
        supplierAlerts.add(_SupplierPayableAlert(
          supplierName: s.name,
          payableQirsh: b,
        ));
      }
    }
    supplierAlerts.sort((a, b) => b.payableQirsh.compareTo(a.payableQirsh));

    final attentionService = inventoryAttentionService ??
        InventoryAttentionService(
          productRepository:
              productRepository ?? AppRepositories.productRepository,
          inventoryRepository:
              inventoryRepository ?? AppRepositories.inventoryRepository,
        );
    final attention = await attentionService.loadAttention();
    final stockAlerts = <_LowStockAlert>[];
    for (final item in attention) {
      if (item.type == InventoryAttentionType.lowStock) {
        stockAlerts.add(_LowStockAlert(
          productName: item.productName,
          stockKg: item.quantityKg,
        ));
      }
    }

    return OwnerAlertData(
      customerAlerts: customerAlerts,
      supplierAlerts: supplierAlerts,
      stockAlerts: stockAlerts,
    );
  }
}

class _CustomerBalanceAlert {
  final String customerName;
  final int balanceQirsh;
  const _CustomerBalanceAlert({
    required this.customerName,
    required this.balanceQirsh,
  });
}

class _SupplierPayableAlert {
  final String supplierName;
  final int payableQirsh;
  const _SupplierPayableAlert({
    required this.supplierName,
    required this.payableQirsh,
  });
}

class _LowStockAlert {
  final String productName;
  final int stockKg;
  const _LowStockAlert({
    required this.productName,
    required this.stockKg,
  });
}

class OwnerAlertsSection extends StatelessWidget {
  const OwnerAlertsSection({super.key, required this.loadData});

  final Future<OwnerAlertData> loadData;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OwnerAlertData>(
      future: loadData,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data ?? OwnerAlertData.empty();
        return _OwnerAlertsContent(data: data);
      },
    );
  }
}

class _OwnerAlertsContent extends StatelessWidget {
  const _OwnerAlertsContent({required this.data});
  final OwnerAlertData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final items = <Widget>[];

    if (data.customerAlerts.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('أرصدة العملاء المستحقة',
            style: textTheme.titleSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
      ));
      for (final a in data.customerAlerts.take(5)) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Icon(Icons.person_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${a.customerName}: ${MoneyUtils.formatPiastersAsEgp(a.balanceQirsh)}',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ));
      }
      items.add(const SizedBox(height: 8));
    }

    if (data.supplierAlerts.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('أرصدة الموردين المستحقة',
            style: textTheme.titleSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
      ));
      for (final a in data.supplierAlerts.take(5)) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Icon(Icons.person_rounded, size: 16, color: colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${a.supplierName}: ${MoneyUtils.formatPiastersAsEgp(a.payableQirsh)}',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ));
      }
      items.add(const SizedBox(height: 8));
    }

    if (data.stockAlerts.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('مخزون منخفض',
            style: textTheme.titleSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
      ));
      for (final a in data.stockAlerts) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Icon(Icons.inventory_2_rounded,
                  size: 16, color: colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${a.productName}: ${a.stockKg} كجم',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ));
      }
      items.add(const SizedBox(height: 8));
    }

    if (!data.hasAnyAlert) {
      items.add(Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text('لا توجد تنبيهات.', style: textTheme.bodySmall),
        ],
      ));
      items.add(const SizedBox(height: 8));
    }

    items.add(const Divider(height: 12));
    items.add(Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.backup_rounded, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'تذكير: احفظ نسخة احتياطية قبل أي تعديل كبير على البيانات.',
            style: textTheme.bodySmall,
          ),
        ),
      ],
    ));
    items.add(const SizedBox(height: 6));
    items.add(Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: colorScheme.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'النظام في مرحلة تجربة. راجع دليل اليوم الأول للتشغيل.',
            style: textTheme.bodySmall,
          ),
        ),
      ],
    ));

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تنبيهات المالك',
            style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }
}
