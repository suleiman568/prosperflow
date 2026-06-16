import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cashflow_providers.dart';
import '../domain/cashflow_entry.dart';

class CashflowScreen extends ConsumerWidget {
  const CashflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashflow = ref.watch(cashflowProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cashflow')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCashflowDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Entry'),
      ),
      body: cashflow.when(
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(cashflowProvider.future),
          child: items.isEmpty
              ? const _EmptyCashflow()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    final color = entry.isInflow
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            entry.isInflow
                                ? Icons.south_west
                                : Icons.north_east,
                          ),
                        ),
                        title: Text(
                          entry.description.isEmpty
                              ? 'Cashflow entry'
                              : entry.description,
                        ),
                        subtitle: Text(CashflowType.label(entry.type)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _money(entry.signedAmount),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            PopupMenuButton<_CashflowAction>(
                              onSelected: (action) {
                                if (action == _CashflowAction.edit) {
                                  _openCashflowDialog(
                                    context,
                                    ref,
                                    entry: entry,
                                  );
                                } else {
                                  _deleteCashflow(context, ref, entry);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _CashflowAction.edit,
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: _CashflowAction.delete,
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
          onRetry: () => ref.invalidate(cashflowProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _openCashflowDialog(
    BuildContext context,
    WidgetRef ref, {
    CashflowEntry? entry,
  }) async {
    final result = await showDialog<CashflowEntry>(
      context: context,
      builder: (context) => _CashflowDialog(entry: entry),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(cashflowRepositoryProvider);
      if (entry == null) {
        await repository.createCashflow(result);
      } else {
        await repository.updateCashflow(result);
      }
      ref.invalidate(cashflowProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cashflow could not be saved: $error')),
        );
      }
    }
  }

  Future<void> _deleteCashflow(
    BuildContext context,
    WidgetRef ref,
    CashflowEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete cashflow entry?'),
        content: Text(
          'Remove ${entry.description.isEmpty ? 'this entry' : entry.description}?',
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
      await ref.read(cashflowRepositoryProvider).deleteCashflow(entry.id);
      ref.invalidate(cashflowProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cashflow could not be deleted: $error')),
        );
      }
    }
  }
}

enum _CashflowAction { edit, delete }

class _CashflowDialog extends StatefulWidget {
  const _CashflowDialog({this.entry});

  final CashflowEntry? entry;

  @override
  State<_CashflowDialog> createState() => _CashflowDialogState();
}

class _CashflowDialogState extends State<_CashflowDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late String _type;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _descriptionController = TextEditingController(
      text: entry?.description ?? '',
    );
    _amountController = TextEditingController(
      text: entry == null ? '' : entry.amount.toStringAsFixed(2),
    );
    _type = CashflowType.normalize(entry?.type);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.entry == null ? 'New cashflow entry' : 'Edit cashflow entry',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₦)'),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return amount == null || amount < 0
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: CashflowType.income,
                    child: Text('Income'),
                  ),
                  DropdownMenuItem(
                    value: CashflowType.expense,
                    child: Text('Expense'),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _type = CashflowType.normalize(value ?? _type),
                ),
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
              CashflowEntry(
                id: widget.entry?.id ?? '',
                description: _descriptionController.text.trim(),
                amount: double.parse(_amountController.text),
                type: CashflowType.normalize(_type),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyCashflow extends StatelessWidget {
  const _EmptyCashflow();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        Icon(Icons.account_balance_wallet_outlined, size: 48),
        SizedBox(height: 12),
        Center(child: Text('No cashflow entries yet')),
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

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  return '$sign₦${value.abs().toStringAsFixed(2)}';
}
