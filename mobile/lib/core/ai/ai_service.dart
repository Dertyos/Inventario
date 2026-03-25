import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Servicio de IA integrado en el core.
/// Se conecta al backend que a su vez llama a Claude API.
/// Todos los módulos pueden usarlo para insights, sugerencias, y análisis.
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(ref.read(dioProvider));
});

class AiService {
  final Dio _dio;

  AiService(this._dio);

  /// Analiza datos de inventario y retorna insights en lenguaje natural.
  /// Usado en: Dashboard para resumen inteligente del negocio.
  Future<AiInsight> getDashboardInsights(String teamId) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/ai/insights',
        data: {'context': 'dashboard'},
      );
      return AiInsight.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Sugiere precio óptimo basado en historial de ventas y competencia.
  /// Usado en: ProductFormScreen al crear/editar producto.
  Future<AiPriceSuggestion> suggestPrice(
    String teamId, {
    required String productName,
    required String categoryName,
    double? currentCost,
  }) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/ai/suggest-price',
        data: {
          'productName': productName,
          'categoryName': categoryName,
          'cost': currentCost,
        },
      );
      return AiPriceSuggestion.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Predice demanda de un producto para planificar compras.
  /// Usado en: Inventory / Products para recomendaciones de restock.
  Future<AiDemandForecast> forecastDemand(
    String teamId,
    String productId,
  ) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/ai/forecast-demand',
        data: {'productId': productId},
      );
      return AiDemandForecast.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Chat libre con contexto del negocio.
  /// Usado en: Pantalla de AI Assistant.
  Future<String> chat(
    String teamId,
    String message, {
    List<Map<String, String>>? history,
  }) async {
    try {
      final response = await _dio.post(
        '/teams/$teamId/ai/chat',
        data: {
          'message': message,
          'history': history ?? [],
        },
      );
      return response.data['reply'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

class AiInsight {
  final String summary;
  final List<String> recommendations;
  final Map<String, dynamic>? metrics;

  const AiInsight({
    required this.summary,
    required this.recommendations,
    this.metrics,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) => AiInsight(
        summary: json['summary'] as String? ?? '',
        recommendations: (json['recommendations'] as List<dynamic>?)
                ?.cast<String>() ??
            [],
        metrics: json['metrics'] as Map<String, dynamic>?,
      );
}

class AiPriceSuggestion {
  final double suggestedPrice;
  final double minPrice;
  final double maxPrice;
  final String reasoning;

  const AiPriceSuggestion({
    required this.suggestedPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.reasoning,
  });

  factory AiPriceSuggestion.fromJson(Map<String, dynamic> json) =>
      AiPriceSuggestion(
        suggestedPrice: (json['suggestedPrice'] as num).toDouble(),
        minPrice: (json['minPrice'] as num).toDouble(),
        maxPrice: (json['maxPrice'] as num).toDouble(),
        reasoning: json['reasoning'] as String? ?? '',
      );
}

class AiDemandForecast {
  final int predictedDemand;
  final int daysUntilStockout;
  final int suggestedReorderQuantity;
  final String confidence;
  final String reasoning;

  const AiDemandForecast({
    required this.predictedDemand,
    required this.daysUntilStockout,
    required this.suggestedReorderQuantity,
    required this.confidence,
    required this.reasoning,
  });

  factory AiDemandForecast.fromJson(Map<String, dynamic> json) =>
      AiDemandForecast(
        predictedDemand: json['predictedDemand'] as int? ?? 0,
        daysUntilStockout: json['daysUntilStockout'] as int? ?? 0,
        suggestedReorderQuantity:
            json['suggestedReorderQuantity'] as int? ?? 0,
        confidence: json['confidence'] as String? ?? 'medium',
        reasoning: json['reasoning'] as String? ?? '',
      );
}
