import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Servicio de IA para procesar transacciones por voz/texto en lenguaje natural.
/// El backend usa Claude API para parsear el texto a una transaccion estructurada.
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(ref.read(dioProvider));
});

class AiService {
  final Dio _dio;

  AiService(this._dio);

  /// Envia texto en lenguaje natural y recibe una transaccion parseada.
  /// Ejemplo: "Venta de 5 tornillos a Pedro por 25mil"
  /// Retorna los datos estructurados para que el usuario confirme.
  Future<ParsedTransaction> parseTransaction(
    String teamId,
    String naturalText,
  ) async {
    if (teamId.isEmpty) {
      throw ApiException('No hay equipo activo. Crea uno primero.');
    }
    if (naturalText.trim().length < 3) {
      throw ApiException('El texto es muy corto. Describe la transaccion.');
    }
    try {
      final response = await _dio.post(
        '/teams/$teamId/ai/parse-transaction',
        data: {'text': naturalText},
      );
      return ParsedTransaction.fromJson(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw ApiException(
          'No se pudo conectar al servidor. Verifica la URL en Configuracion > Servidor.',
        );
      }
      if (e.response?.statusCode == 503) {
        throw ApiException(
          'IA no disponible. Verifica que ANTHROPIC_API_KEY este configurada en el backend.',
        );
      }
      throw ApiException.fromDioError(e);
    }
  }
}

/// Transaccion parseada desde lenguaje natural.
class ParsedTransaction {
  final TransactionType type;
  final List<ParsedItem> items;
  final String? customerOrSupplier;
  final double? totalAmount;
  final String? notes;
  final String rawText;
  final double confidence;

  const ParsedTransaction({
    required this.type,
    required this.items,
    this.customerOrSupplier,
    this.totalAmount,
    this.notes,
    required this.rawText,
    required this.confidence,
  });

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) =>
      ParsedTransaction(
        type: TransactionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => TransactionType.sale,
        ),
        items: (json['items'] as List<dynamic>?)
                ?.map((i) =>
                    ParsedItem.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
        customerOrSupplier: json['customerOrSupplier'] as String?,
        totalAmount: (json['totalAmount'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        rawText: json['rawText'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

enum TransactionType { sale, purchase }

class ParsedItem {
  final String name;
  final int quantity;
  final double? unitPrice;
  final String? matchedProductId;

  const ParsedItem({
    required this.name,
    required this.quantity,
    this.unitPrice,
    this.matchedProductId,
  });

  factory ParsedItem.fromJson(Map<String, dynamic> json) => ParsedItem(
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble(),
        matchedProductId: json['matchedProductId'] as String?,
      );
}
