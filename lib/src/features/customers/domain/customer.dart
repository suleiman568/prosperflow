class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String company;
  final DateTime? createdAt;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'company': company,
    };
  }
}
