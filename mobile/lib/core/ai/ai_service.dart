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
      if (e.response?.statusCode == 403) {
        throw ApiException(
          'No tienes permisos para usar el asistente IA.',
          statusCode: 403,
        );
      }
      throw ApiException.fromDioError(e);
    }
  }

  /// Envia texto en lenguaje natural y recibe un comando parseado.
  /// Soporta ventas, compras, productos, categorias, clientes, proveedores,
  /// inventario y miembros.
  Future<ParsedCommand> parseCommand(
    String teamId,
    String text,
  ) async {
    if (teamId.isEmpty) {
      throw ApiException('No hay equipo activo. Crea uno primero.');
    }
    if (text.trim().length < 3) {
      throw ApiException('El texto es muy corto. Describe lo que necesitas.');
    }
    try {
      final response = await _dio.post(
        '/teams/$teamId/ai/parse-command',
        data: {'text': text},
      );
      return ParsedCommand.fromJson(response.data);
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
      if (e.response?.statusCode == 403) {
        throw ApiException(
          'No tienes permisos para usar el asistente IA.',
          statusCode: 403,
        );
      }
      throw ApiException.fromDioError(e);
    }
  }
}

// ---------------------------------------------------------------------------
// Command action types
// ---------------------------------------------------------------------------

enum CommandAction {
  createSale,
  createPurchase,
  createProduct,
  createCategory,
  createCustomer,
  createSupplier,
  addStock,
  removeStock,
  inviteMember,
  navigateProducts,
  navigateSales,
  navigateInventory,
  navigateLowStock,
  navigateCustomers,
  navigateSuppliers,
  navigateCredits,
  navigateSettings,
  navigateDashboard,
  unsupported,
}

extension CommandActionX on CommandAction {
  bool get isNavigation => name.startsWith('navigate');
}

// ---------------------------------------------------------------------------
// ParsedCommand - top-level AI response for any action
// ---------------------------------------------------------------------------

class ParsedCommand {
  final CommandAction action;
  final TransactionData? transaction;
  final ProductData? product;
  final CategoryData? category;
  final CustomerData? customer;
  final SupplierData? supplier;
  final InventoryData? inventory;
  final MemberData? member;
  final String? unsupportedMessage;
  final String? navigateRoute;
  final String? navigateMessage;
  final String rawText;
  final double confidence;

  const ParsedCommand({
    required this.action,
    this.transaction,
    this.product,
    this.category,
    this.customer,
    this.supplier,
    this.inventory,
    this.member,
    this.unsupportedMessage,
    this.navigateRoute,
    this.navigateMessage,
    required this.rawText,
    required this.confidence,
  });

  factory ParsedCommand.fromJson(Map<String, dynamic> json) {
    final actionStr = json['action'] as String? ?? '';
    final action = _parseAction(actionStr);

    return ParsedCommand(
      action: action,
      transaction: json['transaction'] != null
          ? TransactionData.fromJson(json['transaction'] as Map<String, dynamic>)
          : null,
      product: json['product'] != null
          ? ProductData.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      category: json['category'] != null
          ? CategoryData.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      customer: json['customer'] != null
          ? CustomerData.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      supplier: json['supplier'] != null
          ? SupplierData.fromJson(json['supplier'] as Map<String, dynamic>)
          : null,
      inventory: json['inventory'] != null
          ? InventoryData.fromJson(json['inventory'] as Map<String, dynamic>)
          : null,
      member: json['member'] != null
          ? MemberData.fromJson(json['member'] as Map<String, dynamic>)
          : null,
      unsupportedMessage: json['unsupportedMessage'] as String?,
      navigateRoute: json['navigateRoute'] as String?,
      navigateMessage: json['navigateMessage'] as String?,
      rawText: json['rawText'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static CommandAction _parseAction(String value) {
    switch (value) {
      case 'create_sale':
        return CommandAction.createSale;
      case 'create_purchase':
        return CommandAction.createPurchase;
      case 'create_product':
        return CommandAction.createProduct;
      case 'create_category':
        return CommandAction.createCategory;
      case 'create_customer':
        return CommandAction.createCustomer;
      case 'create_supplier':
        return CommandAction.createSupplier;
      case 'add_stock':
        return CommandAction.addStock;
      case 'remove_stock':
        return CommandAction.removeStock;
      case 'invite_member':
        return CommandAction.inviteMember;
      case 'navigate_products':
        return CommandAction.navigateProducts;
      case 'navigate_sales':
        return CommandAction.navigateSales;
      case 'navigate_inventory':
        return CommandAction.navigateInventory;
      case 'navigate_low_stock':
        return CommandAction.navigateLowStock;
      case 'navigate_customers':
        return CommandAction.navigateCustomers;
      case 'navigate_suppliers':
        return CommandAction.navigateSuppliers;
      case 'navigate_credits':
        return CommandAction.navigateCredits;
      case 'navigate_settings':
        return CommandAction.navigateSettings;
      case 'navigate_dashboard':
        return CommandAction.navigateDashboard;
      case 'unsupported':
        return CommandAction.unsupported;
      default:
        return CommandAction.unsupported;
    }
  }
}

// ---------------------------------------------------------------------------
// Data models for each action type
// ---------------------------------------------------------------------------

class TransactionData {
  final TransactionType type;
  final List<ParsedItem> items;
  final String? customerOrSupplier;
  final double? totalAmount;
  final String? paymentMethod;

  const TransactionData({
    required this.type,
    required this.items,
    this.customerOrSupplier,
    this.totalAmount,
    this.paymentMethod,
  });

  factory TransactionData.fromJson(Map<String, dynamic> json) =>
      TransactionData(
        type: TransactionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => TransactionType.sale,
        ),
        items: (json['items'] as List<dynamic>?)
                ?.map((i) => ParsedItem.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
        customerOrSupplier: json['customerOrSupplier'] as String?,
        totalAmount: (json['totalAmount'] as num?)?.toDouble(),
        paymentMethod: json['paymentMethod'] as String?,
      );
}

class ProductData {
  final String name;
  final String? sku;
  final double price;
  final double? cost;
  final String? categoryName;
  final String? categoryId;
  final int? minStock;

  const ProductData({
    required this.name,
    this.sku,
    required this.price,
    this.cost,
    this.categoryName,
    this.categoryId,
    this.minStock,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) => ProductData(
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        cost: (json['cost'] as num?)?.toDouble(),
        categoryName: json['categoryName'] as String?,
        categoryId: json['categoryId'] as String?,
        minStock: json['minStock'] as int?,
      );
}

class CategoryData {
  final String name;
  final String? description;

  const CategoryData({
    required this.name,
    this.description,
  });

  factory CategoryData.fromJson(Map<String, dynamic> json) => CategoryData(
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
      );
}

class CustomerData {
  final String name;
  final String? phone;
  final String? email;
  final String? documentType;
  final String? documentNumber;
  final String? address;

  const CustomerData({
    required this.name,
    this.phone,
    this.email,
    this.documentType,
    this.documentNumber,
    this.address,
  });

  factory CustomerData.fromJson(Map<String, dynamic> json) => CustomerData(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        documentType: json['documentType'] as String?,
        documentNumber: json['documentNumber'] as String?,
        address: json['address'] as String?,
      );
}

class SupplierData {
  final String name;
  final String? nit;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;

  const SupplierData({
    required this.name,
    this.nit,
    this.contactName,
    this.phone,
    this.email,
    this.address,
  });

  factory SupplierData.fromJson(Map<String, dynamic> json) => SupplierData(
        name: json['name'] as String? ?? '',
        nit: json['nit'] as String?,
        contactName: json['contactName'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
      );
}

class InventoryData {
  final String productName;
  final String? productId;
  final int quantity;
  final String type; // 'in' or 'out'
  final String? reason;

  const InventoryData({
    required this.productName,
    this.productId,
    required this.quantity,
    required this.type,
    this.reason,
  });

  factory InventoryData.fromJson(Map<String, dynamic> json) => InventoryData(
        productName: json['productName'] as String? ?? '',
        productId: json['productId'] as String?,
        quantity: json['quantity'] as int? ?? 0,
        type: json['type'] as String? ?? 'in',
        reason: json['reason'] as String?,
      );
}

class MemberData {
  final String email;
  final String? role;

  const MemberData({
    required this.email,
    this.role,
  });

  factory MemberData.fromJson(Map<String, dynamic> json) => MemberData(
        email: json['email'] as String? ?? '',
        role: json['role'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Legacy models (backward compatibility)
// ---------------------------------------------------------------------------

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
