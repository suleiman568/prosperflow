import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/products_providers.dart';
import '../domain/product.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Product'),
      ),
      body: products.when(
        data: (items) => RefreshIndicator(
          onRefresh: () async => _refreshLocalProducts(ref),
          child: items.isEmpty
              ? const _EmptyProducts()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final product = items[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            product.isLowStock
                                ? Icons.inventory_2_outlined
                                : Icons.inventory_2,
                          ),
                        ),
                        title: Text(
                          product.name.isEmpty
                              ? 'Unnamed product'
                              : product.name,
                        ),
                        subtitle: Text(
                          [
                            if (product.sku.isNotEmpty) product.sku,
                            if (product.category.isNotEmpty) product.category,
                            '${product.quantityInStock} in stock',
                          ].join(' - '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_money(product.sellingPrice)),
                            PopupMenuButton<_ProductAction>(
                              onSelected: (action) {
                                if (action == _ProductAction.edit) {
                                  _openProductDialog(
                                    context,
                                    ref,
                                    product: product,
                                  );
                                } else {
                                  _deleteProduct(context, ref, product);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _ProductAction.edit,
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: _ProductAction.delete,
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
          onRetry: () => unawaited(_refreshLocalProducts(ref)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _openProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
  }) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (context) => _ProductDialog(product: product),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(productsRepositoryProvider);
      if (product == null) {
        await repository.createProduct(result);
      } else {
        await repository.updateProduct(result);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product could not be saved: $error')),
        );
      }
      return;
    }

    try {
      await _refreshLocalProducts(ref);
    } catch (_) {
      // Product save already succeeded locally; sync/refresh failures stay silent.
    }
  }

  Future<void> _deleteProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final repository = ref.read(productsRepositoryProvider);
    final hasSales = await repository.hasSalesForProduct(product.id);
    if (!context.mounted) {
      return;
    }
    if (hasSales) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Product cannot be deleted'),
          content: Text(
            '${product.name.isEmpty ? 'This product' : product.name} has sales records. Delete the related sales first, or keep the product for sales history.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Remove ${product.name.isEmpty ? 'this product' : product.name}?',
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
      await repository.deleteProduct(product.id);
      await _refreshLocalProducts(ref);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product could not be deleted: $error')),
        );
      }
    }
  }
}

Future<void> _refreshLocalProducts(WidgetRef ref) async {
  ref.read(productsLocalRefreshProvider.notifier).state++;
  await ref.read(productsRepositoryProvider).fetchLocalProducts();
}

enum _ProductAction { edit, delete }

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});

  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _categoryController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _reorderController;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _categoryController = TextEditingController(text: product?.category ?? '');
    _costPriceController = TextEditingController(
      text: product == null ? '' : product.costPrice.toStringAsFixed(2),
    );
    _sellingPriceController = TextEditingController(
      text: product == null ? '' : product.sellingPrice.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: product == null ? '' : product.quantityInStock.toString(),
    );
    _reorderController = TextEditingController(
      text: product == null ? '' : product.reorderLevel.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'New product' : 'Edit product'),
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
                controller: _skuController,
                decoration: const InputDecoration(labelText: 'SKU'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cost price (₦)'),
                validator: _numberValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sellingPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Selling price (₦)',
                ),
                validator: _numberValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity in stock',
                ),
                validator: _integerValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reorderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reorder level'),
                validator: _integerValidator,
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
              Product(
                id: widget.product?.id ?? '',
                name: _nameController.text.trim(),
                sku: _skuController.text.trim(),
                category: _categoryController.text.trim(),
                costPrice: double.parse(_costPriceController.text),
                sellingPrice: double.parse(_sellingPriceController.text),
                quantityInStock: int.parse(_quantityController.text),
                reorderLevel: int.parse(_reorderController.text),
                createdAt: widget.product?.createdAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String? _numberValidator(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number < 0 ? 'Enter a valid amount' : null;
  }

  String? _integerValidator(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? 'Enter a valid quantity' : null;
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        Icon(Icons.inventory_2_outlined, size: 48),
        SizedBox(height: 12),
        Center(child: Text('No products yet')),
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
