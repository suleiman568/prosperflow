class CashflowEntry {
  const CashflowEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
  });

  final String id;
  final String description;
  final double amount;
  final String type;

  bool get isInflow => type == CashflowType.income;

  double get signedAmount => isInflow ? amount : -amount;

  factory CashflowEntry.fromJson(Map<String, dynamic> json) {
    return CashflowEntry(
      id: json['id'].toString(),
      description: (json['description'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      type: CashflowType.normalize(json['type']),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'description': description,
      'amount': amount,
      'type': CashflowType.normalize(type),
    };
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '0').toString()) ?? 0;
  }
}

class CashflowType {
  const CashflowType._();

  static const income = 'income';
  static const expense = 'expense';

  static String normalize(dynamic value) {
    return switch ((value ?? '').toString().toLowerCase()) {
      income || 'inflow' => income,
      expense || 'outflow' => expense,
      _ => expense,
    };
  }

  static String label(String value) {
    return normalize(value) == income ? 'Income' : 'Expense';
  }
}
