import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/revenue_providers.dart';
import '../domain/revenue_entry.dart';

class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenue = ref.watch(revenueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Revenue')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRevenueDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Revenue'),
      ),
      body: revenue.when(
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(revenueProvider.future),
          child: items.isEmpty
              ? const _EmptyRevenue()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.payments)),
                        title: Text(entry.title.isEmpty ? 'Revenue entry' : entry.title),
                        subtitle: Text(entry.status),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_money(entry.amount)),
                            PopupMenuButton<_RevenueAction>(
                              onSelected: (action) {
                                if (action == _RevenueAction.edit) {
                                  _openRevenueDialog(context, ref, entry: entry);
                                } else {
                                  _deleteRevenue(context, ref, entry);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _RevenueAction.edit,
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: _RevenueAction.delete,
                                  child: Text('Delete'),
                                ),
                              ],
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
          onRetry: () => ref.invalidate(revenueProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _openRevenueDialog(
    BuildContext context,
    WidgetRef ref, {
    RevenueEntry? entry,
  }) async {
    final result = await showDialog<RevenueEntry>(
      context: context,
      builder: (context) => _RevenueDialog(entry: entry),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(revenueRepositoryProvider);
      if (entry == null) {
        await repository.createRevenue(result);
      } else {
        await repository.updateRevenue(result);
      }
      ref.invalidate(revenueProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revenue could not be saved: $error')),
        );
      }
    }
  }

  Future<void> _deleteRevenue(
    BuildContext context,
    WidgetRef ref,
    RevenueEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete revenue?'),
        content: Text('Remove ${entry.title.isEmpty ? 'this entry' : entry.title}?'),
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
      await ref.read(revenueRepositoryProvider).deleteRevenue(entry.id);
      ref.invalidate(revenueProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revenue could not be deleted: $error')),
        );
      }
    }
  }
}

enum _RevenueAction { edit, delete }

class _RevenueDialog extends StatefulWidget {
  const _RevenueDialog({this.entry});

  final RevenueEntry? entry;

  @override
  State<_RevenueDialog> createState() => _RevenueDialogState();
}

class _RevenueDialogState extends State<_RevenueDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _status;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _amountController = TextEditingController(
      text: entry == null ? '' : entry.amount.toStringAsFixed(2),
    );
    _status = entry?.status ?? 'received';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'New revenue' : 'Edit revenue'),
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
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₦)'),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return amount == null || amount < 0 ? 'Enter a valid amount' : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'received', child: Text('Received')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
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
              RevenueEntry(
                id: widget.entry?.id ?? '',
                title: _titleController.text.trim(),
                amount: double.parse(_amountController.text),
                status: _status,
                date: widget.entry?.date ?? DateTime.now(),
                createdAt: widget.entry?.createdAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyRevenue extends StatelessWidget {
  const _EmptyRevenue();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        Icon(Icons.payments_outlined, size: 48),
        SizedBox(height: 12),
        Center(child: Text('No revenue entries yet')),
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

String _money(double value) => '₦${value.toStringAsFixed(2)}';
