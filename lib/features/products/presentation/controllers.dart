import 'package:bizniz_tracker/features/products/domain/product.dart';
import 'package:bizniz_tracker/features/products/domain/repositories.dart';
import 'package:bizniz_tracker/core/failure.dart';
import 'package:bizniz_tracker/features/settings/services/activity_log_service.dart';

class ProductState {
  final bool loading;
  final List<ProductModel> products;
  final String? error;

  ProductState({this.loading = false, this.products = const [], this.error});

  ProductState copyWith({
    bool? loading,
    List<ProductModel>? products,
    String? error,
  }) {
    return ProductState(
      loading: loading ?? this.loading,
      products: products ?? this.products,
      error: error ?? this.error,
    );
  }
}

class ProductController {
  final ProductRepository repository;
  final ActivityLogService? activityLog;
  ProductState state = ProductState();

  ProductController({
    required this.repository,
    this.activityLog = const ActivityLogService(),
  });

  Future<void> loadProducts() async {
    state = ProductState(loading: true, products: state.products);
    final res = await repository.getAllProducts();
    res.fold(
      (Failure f) => state = state.copyWith(loading: false, error: f.message),
      (List<ProductModel> list) =>
          state = state.copyWith(loading: false, products: list),
    );
  }

  Future<void> addProduct(ProductModel product) async {
    final res = await repository.addProduct(product);
    await res.fold<Future<void>>(
      (f) async {
        state = state.copyWith(error: f.message);
      },
      (_) async {
        await loadProducts();
        final logger = activityLog;
        if (logger != null) {
          logger.recordInBackground(
            description: 'Added product: ${product.name}',
            category: 'Inventory',
          );
        }
      },
    );
  }

  Future<void> updateProduct(ProductModel product) async {
    final res = await repository.updateProduct(product);
    await res.fold<Future<void>>(
      (f) async {
        state = state.copyWith(error: f.message);
      },
      (_) async {
        await loadProducts();
        final logger = activityLog;
        if (logger != null) {
          logger.recordInBackground(
            description: 'Updated product: ${product.name}',
            category: 'Inventory',
          );
        }
      },
    );
  }

  Future<void> deleteProduct(String id) async {
    final res = await repository.deleteProduct(id);
    await res.fold<Future<void>>(
      (f) async {
        state = state.copyWith(error: f.message);
      },
      (_) async {
        await loadProducts();
        final logger = activityLog;
        if (logger != null) {
          logger.recordInBackground(
            description: 'Deleted product: $id',
            category: 'Inventory',
          );
        }
      },
    );
  }
}
