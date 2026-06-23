import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sales/data/sales_providers.dart';
import '../data/customers_providers.dart';
import '../domain/customer.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCustomerDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Customer'),
      ),
      body: customers.when(
        data: (items) => RefreshIndicator(
          onRefresh: () async => _refreshLocalCustomers(ref),
          child: items.isEmpty
              ? const _EmptyCustomers()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final customer = items[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(
                          customer.name.isEmpty
                              ? 'Unnamed customer'
                              : customer.name,
                        ),
                        subtitle: Text(
                          [
                            if (customer.company.isNotEmpty) customer.company,
                            if (customer.email.isNotEmpty) customer.email,
                            if (customer.phone.isNotEmpty) customer.phone,
                          ].join(' | '),
                        ),
                        trailing: PopupMenuButton<_CustomerAction>(
                          onSelected: (action) {
                            if (action == _CustomerAction.edit) {
                              _openCustomerDialog(
                                context,
                                ref,
                                customer: customer,
                              );
                            } else {
                              _deleteCustomer(context, ref, customer);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _CustomerAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: _CustomerAction.delete,
                              child: Text('Delete'),
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
          onRetry: () => unawaited(_refreshLocalCustomers(ref)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _openCustomerDialog(
    BuildContext context,
    WidgetRef ref, {
    Customer? customer,
  }) async {
    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => _CustomerDialog(customer: customer),
    );
    if (result == null || !context.mounted) {
      return;
    }

    final repository = ref.read(customersRepositoryProvider);
    try {
      if (customer == null) {
        await repository.createCustomer(result);
      } else {
        await repository.updateCustomer(result);
      }
      await _refreshLocalCustomers(ref);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer could not be saved: $error')),
        );
      }
    }
  }

  Future<void> _deleteCustomer(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text(
          'Remove ${customer.name.isEmpty ? 'this customer' : customer.name}?',
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
      await ref.read(customersRepositoryProvider).deleteCustomer(customer.id);
      await _refreshLocalCustomers(ref);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer could not be deleted: $error')),
        );
      }
    }
  }
}

Future<void> _refreshLocalCustomers(WidgetRef ref) async {
  ref.read(customersLocalRefreshProvider.notifier).state++;
  await ref.read(customersRepositoryProvider).fetchLocalCustomers();
  ref.invalidate(salesLookupProvider);
}

enum _CustomerAction { edit, delete }

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog({this.customer});

  final Customer? customer;

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _companyController;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer?.name ?? '');
    _emailController = TextEditingController(text: customer?.email ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
    _companyController = TextEditingController(text: customer?.company ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'New customer' : 'Edit customer'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(labelText: 'Company'),
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
              Customer(
                id: widget.customer?.id ?? '',
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
                company: _companyController.text.trim(),
                createdAt: widget.customer?.createdAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        Icon(Icons.people_outline, size: 48),
        SizedBox(height: 12),
        Center(child: Text('No customers yet')),
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
