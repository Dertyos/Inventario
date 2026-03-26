import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(dioProvider));
});

class ReportsRepository {
  final Dio _dio;

  ReportsRepository(this._dio);

  Future<AnalyticsSummary> getSummary(String teamId) async {
    try {
      final response = await _dio.get('/teams/$teamId/analytics/summary');
      return AnalyticsSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SalesAnalytics> getSalesAnalytics(
    String teamId, {
    String? period,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (period != null) queryParams['period'] = period;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _dio.get(
        '/teams/$teamId/analytics/sales',
        queryParameters: queryParams,
      );
      return SalesAnalytics.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<InventoryAnalytics> getInventoryAnalytics(String teamId) async {
    try {
      final response = await _dio.get('/teams/$teamId/analytics/inventory');
      return InventoryAnalytics.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<String> exportSalesCsv(
    String teamId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _dio.get(
        '/teams/$teamId/export/sales',
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.plain),
      );
      return response.data as String;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

// --- Models ---

class AnalyticsSummary {
  final double todayRevenue;
  final int todayTransactions;
  final double percentChangeVsYesterday;
  final List<double> last7DaysRevenue;

  const AnalyticsSummary({
    required this.todayRevenue,
    required this.todayTransactions,
    required this.percentChangeVsYesterday,
    required this.last7DaysRevenue,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      todayRevenue: _toDouble(json['todayRevenue']),
      todayTransactions: _toInt(json['todayTransactions']),
      percentChangeVsYesterday: _toDouble(json['percentChangeVsYesterday']),
      last7DaysRevenue: (json['last7DaysRevenue'] as List?)
              ?.map((e) => _toDouble(e))
              .toList() ??
          [],
    );
  }
}

class SalesAnalytics {
  final double totalRevenue;
  final int totalTransactions;
  final double percentChange;
  final List<DailyRevenue> dailyRevenue;
  final List<TopProduct> topProducts;
  final List<PaymentMethodBreakdown> paymentMethods;

  const SalesAnalytics({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.percentChange,
    required this.dailyRevenue,
    required this.topProducts,
    required this.paymentMethods,
  });

  factory SalesAnalytics.fromJson(Map<String, dynamic> json) {
    return SalesAnalytics(
      totalRevenue: _toDouble(json['totalRevenue']),
      totalTransactions: _toInt(json['totalTransactions']),
      percentChange: _toDouble(json['percentChange']),
      dailyRevenue: (json['dailyRevenue'] as List?)
              ?.map((e) => DailyRevenue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topProducts: (json['topProducts'] as List?)
              ?.map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      paymentMethods: (json['paymentMethods'] as List?)
              ?.map((e) =>
                  PaymentMethodBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DailyRevenue {
  final String date;
  final double revenue;

  const DailyRevenue({required this.date, required this.revenue});

  factory DailyRevenue.fromJson(Map<String, dynamic> json) {
    return DailyRevenue(
      date: json['date'] as String? ?? '',
      revenue: _toDouble(json['revenue']),
    );
  }
}

class TopProduct {
  final String name;
  final double revenue;
  final int quantity;

  const TopProduct({
    required this.name,
    required this.revenue,
    required this.quantity,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      name: json['name'] as String? ?? '',
      revenue: _toDouble(json['revenue']),
      quantity: _toInt(json['quantity']),
    );
  }
}

class PaymentMethodBreakdown {
  final String method;
  final double amount;
  final double percentage;

  const PaymentMethodBreakdown({
    required this.method,
    required this.amount,
    required this.percentage,
  });

  factory PaymentMethodBreakdown.fromJson(Map<String, dynamic> json) {
    return PaymentMethodBreakdown(
      method: json['method'] as String? ?? '',
      amount: _toDouble(json['amount']),
      percentage: _toDouble(json['percentage']),
    );
  }
}

class InventoryAnalytics {
  final int totalProducts;
  final int lowStockCount;
  final double totalValue;
  final List<CategoryBreakdown> categories;

  const InventoryAnalytics({
    required this.totalProducts,
    required this.lowStockCount,
    required this.totalValue,
    required this.categories,
  });

  factory InventoryAnalytics.fromJson(Map<String, dynamic> json) {
    return InventoryAnalytics(
      totalProducts: _toInt(json['totalProducts']),
      lowStockCount: _toInt(json['lowStockCount']),
      totalValue: _toDouble(json['totalValue']),
      categories: (json['categories'] as List?)
              ?.map(
                  (e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CategoryBreakdown {
  final String name;
  final int count;
  final double value;

  const CategoryBreakdown({
    required this.name,
    required this.count,
    required this.value,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      name: json['name'] as String? ?? '',
      count: _toInt(json['count']),
      value: _toDouble(json['value']),
    );
  }
}

// --- Helpers ---

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
