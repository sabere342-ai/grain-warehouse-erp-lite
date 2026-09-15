import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_coordinator.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_product_catalog_query.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/cloud_hybrid_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';

class ProductController extends ChangeNotifier {
  ProductController({
    ProductCatalogReadRepository? productCatalogReadRepository,
    LoadProductCatalogQueryHandler? queryHandler,
    required ProductRepository repository,
    ProductCatalogSyncCoordinator? syncCoordinator,
  })  : assert(
          (productCatalogReadRepository == null) != (queryHandler == null),
          'Exactly one product catalog repository or query handler is required.',
        ),
        _queryHandler = queryHandler ??
            LoadProductCatalogQueryHandler(
              repository: productCatalogReadRepository!,
            ),
        _repository = repository,
        _syncCoordinator = syncCoordinator;

  final LoadProductCatalogQueryHandler _queryHandler;
  final ProductRepository _repository;
  final ProductCatalogSyncCoordinator? _syncCoordinator;
  List<ProductCatalogReadModel> _products = const [];
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSynchronizing = false;

  List<ProductCatalogReadModel> get products =>
      List<ProductCatalogReadModel>.unmodifiable(_products);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isSynchronizing => _isSynchronizing;

  Future<void> synchronize(AppUser user) async {
    final coordinator = _syncCoordinator;
    if (coordinator == null || _isSynchronizing) return;
    _isSynchronizing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await coordinator.synchronizeOnce();
      await loadProducts(user);
    } catch (error) {
      _errorMessage = _messageForError(error);
    } finally {
      _isSynchronizing = false;
      notifyListeners();
    }
  }

  Future<bool> adoptLegacyProduct({
    required AppUser user,
    required String productId,
  }) async {
    final repository = _repository;
    if (!_canManageProducts(user) ||
        repository is! CloudHybridProductRepository) {
      return false;
    }
    try {
      await repository.adoptLegacyProduct(productId);
      await loadProducts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> resolveConflict({
    required AppUser user,
    required String productId,
    required bool acceptServer,
  }) async {
    final coordinator = _syncCoordinator;
    if (!_canManageProducts(user) || coordinator == null) return false;
    try {
      final conflicts = await coordinator.listUnresolvedForProduct(productId);
      if (conflicts.isEmpty) {
        throw StateError('productCatalog.conflictMissing');
      }
      final conflict = conflicts.first;
      if (acceptServer) {
        await coordinator.acceptServer(
          localProductId: productId,
          conflictId: conflict.evidence.conflictId,
          expectedRecordVersion: conflict.recordVersion,
        );
      } else {
        await coordinator.resubmitLocal(
          localProductId: productId,
          conflictId: conflict.evidence.conflictId,
          expectedRecordVersion: conflict.recordVersion,
        );
      }
      await loadProducts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadProducts(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _queryHandler.execute(
      LoadProductCatalogQuery(
        includeInactive: user.permissions.canManageProducts,
      ),
    );
    _products = result.value;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createProduct({
    required AppUser user,
    required ProductDraft draft,
  }) async {
    if (!_canManageProducts(user)) {
      return false;
    }

    try {
      await _repository.createProduct(draft);
      await loadProducts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct({
    required AppUser user,
    required String productId,
    required ProductDraft draft,
  }) async {
    if (!_canManageProducts(user)) {
      return false;
    }

    try {
      await _repository.updateProduct(productId: productId, draft: draft);
      await loadProducts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setProductActive({
    required AppUser user,
    required String productId,
    required bool isActive,
  }) async {
    if (!_canManageProducts(user)) {
      return false;
    }

    try {
      await _repository.setProductActive(
        productId: productId,
        isActive: isActive,
      );
      await loadProducts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  bool _canManageProducts(AppUser user) {
    if (user.permissions.canManageProducts) {
      return true;
    }

    _errorMessage = 'لا يملك هذا المستخدم صلاحية إدارة الأصناف.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is ArgumentError) {
      return 'تحقق من بيانات الصنف المدخلة.';
    }
    if (error is StateError) {
      return 'يوجد صنف بنفس الاسم أو الكود.';
    }

    return 'تعذر حفظ بيانات الصنف.';
  }
}
