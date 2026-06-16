import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tasks_providers.dart';
import '../domain/task_item.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
      body: tasks.when(
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(tasksProvider.future),
          child: items.isEmpty
              ? const _EmptyTasks()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final task = items[index];
                    return Card(
                      child: CheckboxListTile(
                        value: task.isComplete,
                        onChanged: (_) => _toggleTask(context, ref, task),
                        title: Text(task.title.isEmpty ? 'Untitled task' : task.title),
                        subtitle: Text(
                          [
                            if (task.description.isNotEmpty) task.description,
                            if (task.isOverdue) 'Overdue',
                            task.status,
                          ].join(' | '),
                        ),
                        secondary: PopupMenuButton<_TaskAction>(
                          onSelected: (action) {
                            if (action == _TaskAction.edit) {
                              _openTaskDialog(context, ref, task: task);
                            } else {
                              _deleteTask(context, ref, task);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _TaskAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: _TaskAction.delete,
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemCount: items.length,
                ),
        ),
        error: (error, stackTrace) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(tasksProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _openTaskDialog(
    BuildContext context,
    WidgetRef ref, {
    TaskItem? task,
  }) async {
    final result = await showDialog<TaskItem>(
      context: context,
      builder: (context) => _TaskDialog(task: task),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(tasksRepositoryProvider);
      if (task == null) {
        await repository.createTask(result);
      } else {
        await repository.updateTask(result);
      }
      ref.invalidate(tasksProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task could not be saved: $error')),
        );
      }
    }
  }

  Future<void> _toggleTask(BuildContext context, WidgetRef ref, TaskItem task) async {
    final updated = TaskItem(
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.isComplete ? 'open' : 'done',
      dueDate: task.dueDate,
      createdAt: task.createdAt,
    );
    try {
      await ref.read(tasksRepositoryProvider).updateTask(updated);
      ref.invalidate(tasksProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task could not be updated: $error')),
        );
      }
    }
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref, TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Remove ${task.title.isEmpty ? 'this task' : task.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(tasksRepositoryProvider).deleteTask(task.id);
      ref.invalidate(tasksProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task could not be deleted: $error')),
        );
      }
    }
  }
}

enum _TaskAction { edit, delete }

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.task});

  final TaskItem? task;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _status;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');
    _status = task?.status ?? 'open';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'New task' : 'Edit task'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'done', child: Text('Done')),
                ],
                onChanged: (value) => setState(() => _status = value ?? _status),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              TaskItem(
                id: widget.task?.id ?? '',
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                status: _status,
                dueDate: widget.task?.dueDate,
                createdAt: widget.task?.createdAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        Icon(Icons.task_alt, size: 48),
        SizedBox(height: 12),
        Center(child: Text('No tasks yet')),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
