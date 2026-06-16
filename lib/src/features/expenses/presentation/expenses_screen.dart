import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/data/dashboard_providers.dart';
import '../data/expenses_providers.dart';
import '../domain/expense.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExpenseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Expense'),
      ),
      body: expenses.when(
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(expensesProvider.future),
          child: items.isEmpty
              ? const _EmptyExpenses()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final expense = items[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_categoryIcon(expense.category)),
                        ),
                        title: Text(
                          expense.title.isEmpty ? 'Expense' : expense.title,
                        ),
                        subtitle: Text(
                          '${expense.category} - ${_shortDate(expense.date)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _money(expense.amount),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            PopupMenuButton<_ExpenseAction>(
                              onSelected: (action) {
                                if (action == _ExpenseAction.edit) {
                                  _openExpenseDialog(
                                    context,
                                    ref,
                                    expense: expense,
                                  );
                                } else {
                                  _deleteExpense(context, ref, expense);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _ExpenseAction.edit,
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: _ExpenseAction.delete,
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemCount: items.length,
                ),
        ),
        error: (error, stackTrace) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(expensesProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _openExpenseDialog(
    BuildContext context,
    WidgetRef ref, {
    Expense? expense,
  }) async {
    final result = await showDialog<Expense>(
      context: context,
      builder: (context) => _ExpenseDialog(expense: expense),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(expensesRepositoryProvider);
      if (expense == null) {
        await repository.createExpense(result);
      } else {
        await repository.updateExpense(result);
      }
      ref.invalidate(expensesProvider);
      ref.invalidate(dashboardSummaryProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense could not be saved: $error')),
        );
      }
    }
  }

  Future<void> _deleteExpense(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'Remove ${expense.title.isEmpty ? 'this expense' : expense.title}?',
        ),
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
      await ref.read(expensesRepositoryProvider).deleteExpense(expense.id);
      ref.invalidate(expensesProvider);
      ref.invalidate(dashboardSummaryProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense could not be deleted: $error')),
        );
      }
    }
  }
}

enum _ExpenseAction { edit, delete }

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({this.expense});

  final Expense? expense;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late ExpenseCategory _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _titleController = TextEditingController(text: expense?.title ?? '');
    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    _notesController = TextEditingController(text: expense?.notes ?? '');
    _category = ExpenseCategory.values.firstWhere(
      (category) => category.label == expense?.category,
      orElse: () => ExpenseCategory.miscellaneous,
    );
    _date = expense?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? 'New expense' : 'Edit expense'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (NGN)'),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return amount == null || amount < 0
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final category in ExpenseCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _category = value ?? _category);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_shortDate(_date)),
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
              Expense(
                id: widget.expense?.id ?? '',
                title: _titleController.text.trim(),
                amount: double.parse(_amountController.text),
                category: _category.label,
                notes: _notesController.text.trim(),
                date: _date,
                createdAt: widget.expense?.createdAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (selected == null) {
      return;
    }
    setState(() => _date = selected);
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        Icon(Icons.receipt_long_outlined, size: 48),
        SizedBox(height: 12),
        Center(child: Text('No expenses yet')),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Unable to load expenses.', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'Transport' => Icons.directions_bus,
    'Fuel' => Icons.local_gas_station,
    'Rent' => Icons.home_work,
    'Salary' => Icons.badge,
    'Utilities' => Icons.bolt,
    _ => Icons.receipt_long,
  };
}

String _shortDate(DateTime? date) {
  if (date == null) {
    return 'No date';
  }
  return '${date.day}/${date.month}/${date.year}';
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs().toStringAsFixed(2);
  final parts = amount.split('.');
  final naira = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '$sign\u20A6$naira.${parts.last}';
}
