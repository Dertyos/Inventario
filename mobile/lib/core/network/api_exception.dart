import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  factory ApiException.fromDioError(DioException error) {
    final data = error.response?.data;
    String message;

    if (data is Map && data.containsKey('message')) {
      final msg = data['message'];
      message = msg is List ? msg.join(', ') : msg.toString();
    } else {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Tiempo de conexión agotado. Intenta de nuevo.';
        case DioExceptionType.connectionError:
          message = 'Sin conexión a internet.';
        case DioExceptionType.badResponse:
          message = _messageForStatus(error.response?.statusCode);
        default:
          message = 'Error inesperado. Intenta de nuevo.';
      }
    }

    return ApiException(message, statusCode: error.response?.statusCode);
  }

  static String _messageForStatus(int? status) {
    switch (status) {
      case 400:
        return 'Datos inválidos.';
      case 401:
        return 'Sesión expirada. Inicia sesión de nuevo.';
      case 403:
        return 'No tienes permisos para esta acción.';
      case 404:
        return 'Recurso no encontrado.';
      case 409:
        return 'Conflicto: el recurso ya existe.';
      case 422:
        return 'Datos no procesables.';
      case 500:
        return 'Error del servidor. Intenta más tarde.';
      default:
        return 'Error inesperado ($status).';
    }
  }

  @override
  String toString() => message;
}
