class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.quantityInStock,
    required this.reorderLevel,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String sku;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final int quantityInStock;
  final int reorderLevel;
  final DateTime? createdAt;

  bool get isLowStock => quantityInStock <= reorderLevel;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      costPrice: _asDouble(json['cost_price']),
      sellingPrice: _asDouble(json['selling_price']),
      quantityInStock: _asInt(json['stock_quantity']),
      reorderLevel: _asInt(json['reorder_level']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'sku': sku,
      'category': category,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock_quantity': quantityInStock,
      'reorder_level': reorderLevel,
    };
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '0').toString()) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }
}
