import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/product_model.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.read(dioProvider));
});

class ProductsRepository {
  final Dio _dio;

  ProductsRepository(this._dio);

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
      return (response.data as List)
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
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
      return (response.data as List)
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<CategoryModel>> getCategories(String teamId) async {
    try {
      final response = await _dio.get('/teams/$teamId/categories');
      return (response.data as List)
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
      final response = await _dio.post('/teams/$teamId/categories', data: data);
      return CategoryModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
