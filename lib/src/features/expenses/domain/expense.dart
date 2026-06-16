class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.notes,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;
  final String category;
  final String notes;
  final DateTime? date;
  final DateTime? createdAt;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'].toString(),
      title: (json['title'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      category: (json['category'] ?? ExpenseCategory.miscellaneous.label)
          .toString(),
      notes: (json['notes'] ?? '').toString(),
      date: DateTime.tryParse(
        (json['date'] ?? json['created_at'] ?? '').toString(),
      ),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'notes': notes,
      'date': date?.toIso8601String(),
    };
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '0').toString()) ?? 0;
  }
}

enum ExpenseCategory {
  transport('Transport'),
  fuel('Fuel'),
  rent('Rent'),
  salary('Salary'),
  utilities('Utilities'),
  miscellaneous('Miscellaneous');

  const ExpenseCategory(this.label);

  final String label;
}
