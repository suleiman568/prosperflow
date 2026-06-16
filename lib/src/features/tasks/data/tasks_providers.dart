import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task_item.dart';
import 'tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository();
});

final tasksProvider = FutureProvider<List<TaskItem>>((ref) {
  return ref.watch(tasksRepositoryProvider).fetchTasks();
});
