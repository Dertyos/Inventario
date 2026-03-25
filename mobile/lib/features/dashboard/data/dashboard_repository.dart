import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/models/sale_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.read(dioProvider));
});

class DashboardRepository {
  final Dio _dio;

  DashboardRepository(this._dio);

  Future<DashboardData> getDashboardData(String teamId) async {
    try {
      final results = await Future.wait([
        _dio.get('/teams/$teamId/products'),
        _dio.get('/teams/$teamId/products/low-stock'),
        _dio.get('/teams/$teamId/sales'),
        _dio.get('/teams/$teamId/categories'),
      ]);

      final allProducts = (results[0].data as List)
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final lowStock = (results[1].data as List)
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final sales = (results[2].data as List)
          .map((e) => SaleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final categoryCount = (results[3].data as List).length;

      final todaySales = sales.where((s) {
        final now = DateTime.now();
        return s.createdAt.year == now.year &&
            s.createdAt.month == now.month &&
            s.createdAt.day == now.day &&
            !s.isCancelled;
      }).toList();

      final todayRevenue =
          todaySales.fold<double>(0, (sum, s) => sum + s.totalAmount);

      return DashboardData(
        totalProducts: allProducts.length,
        totalCategories: categoryCount,
        lowStockProducts: lowStock,
        todaySalesCount: todaySales.length,
        todayRevenue: todayRevenue,
        recentSales: sales.take(5).toList(),
        totalSales: sales.where((s) => !s.isCancelled).length,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

class DashboardData {
  final int totalProducts;
  final int totalCategories;
  final List<ProductModel> lowStockProducts;
  final int todaySalesCount;
  final double todayRevenue;
  final List<SaleModel> recentSales;
  final int totalSales;

  const DashboardData({
    required this.totalProducts,
    required this.totalCategories,
    required this.lowStockProducts,
    required this.todaySalesCount,
    required this.todayRevenue,
    required this.recentSales,
    required this.totalSales,
  });
}
