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
  final String categoryId;
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
    required this.categoryId,
    this.categoryName,
    required this.createdAt,
  });

  bool get isLowStock => stock <= minStock;
  double get margin => cost != null && cost! > 0 ? ((price - cost!) / cost!) * 100 : 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        sku: json['sku'] as String,
        name: json['name'] as String,
        barcode: json['barcode'] as String?,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        price: (json['price'] as num).toDouble(),
        cost: (json['cost'] as num?)?.toDouble(),
        stock: json['stock'] as int? ?? 0,
        minStock: json['minStock'] as int? ?? 0,
        trackLots: json['trackLots'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
        categoryId: json['categoryId'] as String? ?? json['category']?['id'] as String? ?? '',
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
