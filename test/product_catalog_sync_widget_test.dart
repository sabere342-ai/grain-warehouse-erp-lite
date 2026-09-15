import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_contracts.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';

void main() {
  testWidgets('catalog renders truthful sync states and guards pending actions',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthController(repository: LocalAuthRepository.demo());
    await auth.initialize();
    await auth.signIn(phone: '01000000000', password: 'owner123');
    final controller = ProductController(
      productCatalogReadRepository: _ReadRepository(_models()),
      repository: LocalProductRepository(),
    );
    addTearDown(auth.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          home: ProductsScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('محلي - دون اتصال سحابي'), findsOneWidget);
    expect(find.text('بانتظار المزامنة'), findsOneWidget);
    expect(find.text('متزامن'), findsNWidgets(2));
    expect(find.text('سحابي - قديم'), findsOneWidget);
    expect(find.text('يتطلب مراجعة'), findsOneWidget);
    expect(find.text('متوقف'), findsOneWidget);
    expect(find.byKey(const Key('products_sync_button')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('product_edit_pending')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('product_toggle_attention')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('product_accept_server_attention')),
        findsOneWidget);
    expect(
        find.byKey(const Key('product_keep_local_attention')), findsOneWidget);
  });
}

final class _ReadRepository implements ProductCatalogReadRepository {
  const _ReadRepository(this.values);
  final List<ProductCatalogReadModel> values;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async =>
      values;
}

List<ProductCatalogReadModel> _models() {
  final now = DateTime(2026, 9, 12);
  ProductCatalogReadModel model(
    String id,
    ProductCloudDisposition disposition, {
    bool stale = false,
    bool active = true,
    String? pending,
  }) =>
      ProductCatalogReadModel(
        id: id,
        name: 'صنف $id',
        code: null,
        unit: GrainUnit.kilogram,
        isActive: active,
        referenceCostPricePiastersPerKg: null,
        defaultSalePricePiastersPerKg: null,
        minimumSalePricePiastersPerKg: null,
        notes: null,
        createdAt: now,
        updatedAt: now,
        cloudDisposition: disposition,
        remoteProductId:
            disposition == ProductCloudDisposition.localOnly ? null : id,
        acknowledgedEntityVersion:
            disposition == ProductCloudDisposition.localOnly ? null : 1,
        pendingOperationId: pending,
        lastSuccessfulPullAtUtc: stale ? now : null,
        isStale: stale,
      );

  return [
    model('local', ProductCloudDisposition.localOnly),
    model('pending', ProductCloudDisposition.pending, pending: 'op-pending'),
    model('ack', ProductCloudDisposition.acknowledged),
    model('stale', ProductCloudDisposition.acknowledged, stale: true),
    model('attention', ProductCloudDisposition.attentionRequired,
        pending: 'op-attention'),
    model('inactive', ProductCloudDisposition.acknowledged, active: false),
  ];
}
