import 'package:bizniz_tracker/features/products/domain/product.dart';

import '../../../../core/app_database.dart';
import 'product_local_datasource.dart';

class ProductLocalDataSourceImpl implements ProductLocalDataSource {
  final AppDatabase database;

  ProductLocalDataSourceImpl({required this.database});

  @override
  Future<ProductModel> addProduct(ProductModel product) async {
    await database.putProduct(product);
    return product;
  }

  @override
  Future<bool> deleteProduct(String id) async {
    await database.deleteProduct(id);
    return true;
  }

  @override
  Future<List<ProductModel>> getAllProducts() async {
    return database.getProducts();
  }

  @override
  Future<ProductModel?> getProductById(String id) async {
    return database.getProduct(id);
  }

  @override
  Future<ProductModel> updateProduct(ProductModel product) async {
    await database.putProduct(product);
    return product;
  }
}
