import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(dioProvider));
});

// --- Models ---

class AnalyticsSummary {
  final double todayRevenue;
  final int todayTransactions;
  final double yesterdayRevenue;
  final double weekRevenue;
  final int weekTransactions;
  final double monthRevenue;
  final int monthTransactions;
  final double changePercent;
  final double weekChangePercent;
  final double monthChangePercent;
  final List<double> last7DaysRevenue;
  final List<double> last30DaysRevenue;

  const AnalyticsSummary({
    required this.todayRevenue,
    required this.todayTransactions,
    required this.yesterdayRevenue,
    required this.weekRevenue,
    required this.weekTransactions,
    required this.monthRevenue,
    required this.monthTransactions,
    required this.changePercent,
    required this.weekChangePercent,
    required this.monthChangePercent,
    required this.last7DaysRevenue,
    required this.last30DaysRevenue,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>? ?? {};
    final yesterday = json['yesterday'] as Map<String, dynamic>? ?? {};
    final thisWeek = json['thisWeek'] as Map<String, dynamic>? ?? {};
    final last30 = json['last30Days'] as Map<String, dynamic>? ?? {};

    return AnalyticsSummary(
      todayRevenue: _toDouble(today['revenue'] ?? json['todayRevenue']),
      todayTransactions: _toInt(today['count'] ?? json['todayTransactions']),
      yesterdayRevenue: _toDouble(yesterday['revenue'] ?? json['yesterdayRevenue']),
      weekRevenue: _toDouble(thisWeek['revenue']),
      weekTransactions: _toInt(thisWeek['count']),
      monthRevenue: _toDouble(last30['revenue']),
      monthTransactions: _toInt(last30['count']),
      changePercent: _toDouble(json['percentChange']),
      weekChangePercent: _toDouble(json['weekPercentChange']),
      monthChangePercent: _toDouble(json['monthPercentChange']),
      last7DaysRevenue: (json['revenueHistory'] as List?)
              ?.map((e) => _toDouble(e))
              .toList() ??
          [],
      last30DaysRevenue: (json['monthlyRevenueHistory'] as List?)
              ?.map((e) => _toDouble(e))
              .toList() ??
          [],
    );
  }
}

class SalesAnalytics {
  final double totalRevenue;
  final int totalTransactions;
  final double previousPeriodRevenue;
  final List<DailyRevenue> dailyRevenue;
  final List<TopProduct> topProducts;
  final List<PaymentMethodBreakdown> paymentMethods;

  const SalesAnalytics({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.previousPeriodRevenue,
    required this.dailyRevenue,
    required this.topProducts,
    required this.paymentMethods,
  });

  double get changePercent {
    if (previousPeriodRevenue == 0) return 0;
    return ((totalRevenue - previousPeriodRevenue) / previousPeriodRevenue) *
        100;
  }

  factory SalesAnalytics.fromJson(Map<String, dynamic> json) {
    return SalesAnalytics(
      totalRevenue: _toDouble(json['totalRevenue']),
      totalTransactions: _toInt(json['totalTransactions']),
      previousPeriodRevenue: _toDouble(json['previousPeriodRevenue']),
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
  final int count;

  const PaymentMethodBreakdown({
    required this.method,
    required this.amount,
    required this.count,
  });

  factory PaymentMethodBreakdown.fromJson(Map<String, dynamic> json) {
    return PaymentMethodBreakdown(
      method: json['method'] as String? ?? '',
      amount: _toDouble(json['amount']),
      count: _toInt(json['count']),
    );
  }
}

class InventoryAnalytics {
  final int totalProducts;
  final int lowStockCount;
  final double totalValue;
  final int outOfStockCount;

  const InventoryAnalytics({
    required this.totalProducts,
    required this.lowStockCount,
    required this.totalValue,
    required this.outOfStockCount,
  });

  factory InventoryAnalytics.fromJson(Map<String, dynamic> json) {
    return InventoryAnalytics(
      totalProducts: _toInt(json['totalProducts']),
      lowStockCount: _toInt(json['lowStockCount']),
      totalValue: _toDouble(json['totalValue']),
      outOfStockCount: _toInt(json['outOfStockCount']),
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

// --- Repository ---

class ReportsRepository {
  final Dio _dio;

  ReportsRepository(this._dio);

  Future<AnalyticsSummary> getSummary(String teamId) async {
    try {
      final tzOffset = DateTime.now().timeZoneOffset.inMinutes;
      final response = await _dio.get(
        '/teams/$teamId/analytics/summary',
        queryParameters: {'tzOffset': tzOffset.toString()},
      );
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
