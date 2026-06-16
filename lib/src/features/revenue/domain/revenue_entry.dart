class RevenueEntry {
  const RevenueEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;
  final String status;
  final DateTime? date;
  final DateTime? createdAt;

  factory RevenueEntry.fromJson(Map<String, dynamic> json) {
    return RevenueEntry(
      id: json['id'].toString(),
      title: (json['title'] ?? json['description'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      status: (json['status'] ?? 'received').toString(),
      date: DateTime.tryParse((json['date'] ?? json['created_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'title': title,
      'amount': amount,
      'status': status,
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
