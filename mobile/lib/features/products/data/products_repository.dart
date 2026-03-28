import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/pending_sales_service.dart';
import '../../../shared/models/product_model.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(
    ref.read(dioProvider),
    ref.read(pendingSalesServiceProvider),
  );
});

class ProductsRepository {
  final Dio _dio;
  final PendingSalesService _offline;

  ProductsRepository(this._dio, this._offline);

  Future<List<ProductModel>> getProducts(
    String teamId, {
    String? categoryId,
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (categoryId != null) params['categoryId'] = categoryId;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _dio.get(
        '/teams/$teamId/products',
        queryParameters: params,
      );
      final data = response.data;
      final rawList = data is List ? data : <dynamic>[];
      final products = rawList
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache for offline use (only full catalog, no filters)
      if (categoryId == null && (search == null || search.isEmpty)) {
        _offline.cacheProducts(
          teamId,
          rawList.cast<Map<String, dynamic>>(),
        );
      }

      return products;
    } on DioException catch (e) {
      // Offline fallback: return cached products
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        final cached = await _offline.getCachedProducts(teamId);
        if (cached != null) {
          return cached.map((e) => ProductModel.fromJson(e)).toList();
        }
      }
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProductModel> getProduct(String teamId, String productId) async {
    try {
      final response = await _dio.get('/teams/$teamId/products/$productId');
      return ProductModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProductModel> createProduct(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/teams/$teamId/products', data: data);
      return ProductModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        await _offline.savePendingOperation(
          teamId: teamId,
          type: 'create_product',
          endpoint: '/teams/$teamId/products',
          data: data,
        );
        throw ApiException(
            'Producto guardado localmente. Se creara cuando haya conexion.');
      }
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProductModel> updateProduct(
    String teamId,
    String productId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(
        '/teams/$teamId/products/$productId',
        data: data,
      );
      return ProductModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteProduct(String teamId, String productId) async {
    try {
      await _dio.delete('/teams/$teamId/products/$productId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<ProductModel>> getLowStock(String teamId) async {
    try {
      final response = await _dio.get('/teams/$teamId/products/low-stock');
      final data = response.data;
      final list = data is List ? data : <dynamic>[];
      return list
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<CategoryModel>> getCategories(String teamId) async {
    try {
      final response = await _dio.get('/teams/$teamId/categories');
      final data = response.data;
      final list = data is List ? data : <dynamic>[];
      return list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<CategoryModel> createCategory(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response =
          await _dio.post('/teams/$teamId/categories', data: data);
      return CategoryModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
