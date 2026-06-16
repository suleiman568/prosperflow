class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime? dueDate;
  final DateTime? createdAt;

  bool get isComplete => status == 'done' || status == 'completed';

  bool get isOverdue {
    if (dueDate == null || isComplete) {
      return false;
    }
    final today = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final current = DateTime(today.year, today.month, today.day);
    return due.isBefore(current);
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'].toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString(),
      dueDate: DateTime.tryParse((json['due_date'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'due_date': dueDate?.toIso8601String(),
    };
  }
}
