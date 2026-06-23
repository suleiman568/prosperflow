class Sale {
  const Sale({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.paymentStatus,
    required this.saleDate,
    required this.createdAt,
    this.syncStatus = 'synced',
  });

  final String id;
  final String customerId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String paymentStatus;
  final DateTime? saleDate;
  final DateTime? createdAt;
  final String syncStatus;

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'].toString(),
      customerId: (json['customer_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      quantity: _asInt(json['quantity']),
      unitPrice: _asDouble(json['unit_price']),
      totalAmount: _asDouble(json['total_amount']),
      paymentStatus: (json['payment_status'] ?? 'pending').toString(),
      saleDate: DateTime.tryParse((json['sale_date'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      syncStatus: (json['sync_status'] ?? 'synced').toString(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    final amount = totalAmount == 0 ? quantity * unitPrice : totalAmount;
    return {
      'customer_id': customerId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': amount,
      'payment_status': paymentStatus,
      'sale_date': saleDate?.toIso8601String(),
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
