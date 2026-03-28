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
          message = 'No se pudo conectar. Verifica tu conexión a internet.';
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
        return 'Datos incorrectos. Revisa la información e intenta de nuevo.';
      case 401:
        return 'Tu sesión expiró. Inicia sesión de nuevo.';
      case 403:
        return 'No tienes permiso para realizar esta acción.';
      case 404:
        return 'No se encontró el recurso solicitado.';
      case 409:
        return 'Ya existe un registro con estos datos.';
      case 422:
        return 'Los datos enviados no son válidos.';
      case 429:
        return 'Demasiadas solicitudes. Espera un momento.';
      case 405:
        return 'Operación no permitida.';
      case 408:
        return 'La solicitud tardó demasiado. Intenta de nuevo.';
      case 413:
        return 'Los datos enviados son demasiado grandes.';
      case 500:
        return 'Error del servidor. Intenta más tarde.';
      case 502:
        return 'El servidor no está disponible. Intenta en unos segundos.';
      case 503:
        return 'El servidor está en mantenimiento. Intenta en unos minutos.';
      case 504:
        return 'El servidor tardó demasiado en responder. Intenta más tarde.';
      default:
        return 'Error inesperado (código $status). Intenta de nuevo.';
    }
  }

  @override
  String toString() => message;
}
