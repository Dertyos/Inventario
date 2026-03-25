class ProductModel {
  final String id;
  final String sku;
  final String name;
  final String? barcode;
  final String? description;
  final String? imageUrl;
  final double price;
  final double? cost;
  final int stock;
  final int minStock;
  final bool trackLots;
  final bool isActive;
  final String? categoryId;
  final String? categoryName;
  final DateTime createdAt;

  const ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    this.barcode,
    this.description,
    this.imageUrl,
    required this.price,
    this.cost,
    this.stock = 0,
    this.minStock = 0,
    this.trackLots = false,
    this.isActive = true,
    this.categoryId,
    this.categoryName,
    required this.createdAt,
  });

  bool get isLowStock => stock <= minStock;
  double get margin => cost != null && cost! > 0 ? ((price - cost!) / cost!) * 100 : 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        sku: json['sku'] as String? ?? '',
        name: json['name'] as String,
        barcode: json['barcode'] as String?,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        price: JsonParse.toDouble(json['price']) ?? 0,
        cost: JsonParse.toDouble(json['cost']),
        stock: JsonParse.toInt(json['stock']) ?? 0,
        minStock: JsonParse.toInt(json['minStock']) ?? 0,
        trackLots: json['trackLots'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
        categoryId: json['categoryId'] as String? ?? json['category']?['id'] as String?,
        categoryName: json['category']?['name'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? color;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.color,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        color: json['color'] as String?,
      );
}

/// Safe JSON number parsing — handles both num and String from backend.
class JsonParse {
  JsonParse._();

  static double? toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
