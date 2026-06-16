import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/task_item.dart';

class TasksRepository {
  TasksRepository({SupabaseClient? client}) : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<TaskItem>> fetchTasks() async {
    final rows = await _client.from('tasks').select().order('created_at');
    return rows.map(TaskItem.fromJson).toList();
  }

  Future<TaskItem> createTask(TaskItem task) async {
    final row = await _client
        .from('tasks')
        .insert({
          ...task.toInsertJson(),
          'user_id': _client.auth.currentUser!.id,
        })
        .select()
        .single();
    return TaskItem.fromJson(row);
  }

  Future<TaskItem> updateTask(TaskItem task) async {
    final row = await _client
        .from('tasks')
        .update(task.toInsertJson())
        .eq('id', task.id)
        .select()
        .single();
    return TaskItem.fromJson(row);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }
}
