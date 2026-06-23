import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/data/customers_providers.dart';
import '../../customers/domain/customer.dart';
import '../../../core/offline/offline_providers.dart';
import '../../products/data/products_providers.dart';
import '../../products/domain/product.dart';
import '../data/sales_providers.dart';
import '../domain/sale.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(salesProvider).value ?? const <Sale>[];
    final lookup = ref.watch(salesLookupProvider).value;
    final customers = lookup?.customers ?? const <Customer>[];
    final products = lookup?.products ?? const <Product>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSaleDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Sale'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesLookupProvider);
          ref.invalidate(salesProvider);
          await ref.read(salesProvider.future);
          await ref.read(salesLookupProvider.future);
        },
        child: sales.isEmpty
            ? const _EmptySales()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  final customerName = _customerName(
                    customers,
                    sale.customerId,
                  );
                  final productName = _productName(products, sale.productId);
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.point_of_sale),
                      ),
                      title: Text(productName),
                      subtitle: Text('$customerName - ${sale.quantity} sold'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_money(sale.totalAmount)),
                          PopupMenuButton<_SaleAction>(
                            onSelected: (action) {
                              if (action == _SaleAction.edit) {
                                _openSaleDialog(context, ref, sale: sale);
                              } else {
                                _deleteSale(context, ref, sale);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _SaleAction.edit,
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: _SaleAction.delete,
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
                itemCount: sales.length,
              ),
      ),
    );
  }

  Future<void> _openSaleDialog(
    BuildContext context,
    WidgetRef ref, {
    Sale? sale,
  }) async {
    final lookup = await _readLocalLookup(ref);
    final customers = lookup.customers;
    final products = lookup.products;
    final canCreateLocalSale = customers.isNotEmpty && products.isNotEmpty;
    if (!context.mounted) {
      return;
    }
    if (!canCreateLocalSale) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one customer and product first.'),
        ),
      );
      return;
    }

    debugPrint('SALES_FORM_OPEN');
    final result = await showDialog<Sale>(
      context: context,
      builder: (context) =>
          _SaleDialog(sale: sale, customers: customers, products: products),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      final repository = ref.read(salesRepositoryProvider);
      if (sale == null) {
        await repository.createSale(result);
      } else {
        await repository.updateSale(result);
      }
      await _refreshLocalSales(ref);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale could not be saved: $error')),
        );
      }
    }
  }

  Future<void> _deleteSale(
    BuildContext context,
    WidgetRef ref,
    Sale sale,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sale?'),
        content: const Text('Remove this sale and restore product stock?'),
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
      await ref.read(salesRepositoryProvider).deleteSale(sale);
      await _refreshLocalSales(ref);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale could not be deleted: $error')),
        );
      }
    }
  }

  Future<void> _refreshLocalSales(WidgetRef ref) async {
    final sales = await ref.read(salesRepositoryProvider).fetchLocalSales();
    debugPrint('SALES_LIST_REFRESHED_COUNT=${sales.length}');
    ref.read(salesLocalRefreshProvider.notifier).state++;
    ref.invalidate(salesProvider);
    ref.invalidate(salesLookupProvider);
    ref.invalidate(productsProvider);
    await ref.read(salesProvider.future);
  }

  Future<SalesLookupData> _readLocalLookup(WidgetRef ref) async {
    final localCustomers = await ref
        .read(customersRepositoryProvider)
        .fetchLocalCustomers();
    final localProducts = await ref
        .read(productsRepositoryProvider)
        .fetchLocalProducts();
    debugPrint('SALES_LOCAL_CUSTOMERS_COUNT=${localCustomers.length}');
    debugPrint('SALES_LOCAL_PRODUCTS_COUNT=${localProducts.length}');

    final isOnline = ref.read(isOnlineProvider).valueOrNull ?? false;
    if (!isOnline) {
      return SalesLookupData(
        customers: localCustomers,
        products: localProducts,
      );
    }

    final customers = await ref
        .read(customersProvider.future)
        .catchError((_) => localCustomers);
    final products = await ref
        .read(productsProvider.future)
        .catchError((_) => localProducts);
    debugPrint('Sales customersProvider count: ${customers.length}');
    debugPrint('Sales productsProvider count: ${products.length}');

    return SalesLookupData(customers: customers, products: products);
  }
}

enum _SaleAction { edit, delete }

class _SaleDialog extends StatefulWidget {
  const _SaleDialog({
    required this.customers,
    required this.products,
    this.sale,
  });

  final List<Customer> customers;
  final List<Product> products;
  final Sale? sale;

  @override
  State<_SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<_SaleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;
  late String _customerId;
  late String _productId;
  late String _paymentStatus;

  @override
  void initState() {
    super.initState();
    final sale = widget.sale;
    final selectedProduct = sale == null
        ? widget.products.first
        : widget.products.firstWhere(
            (product) => product.id == sale.productId,
            orElse: () => widget.products.first,
          );
    _customerId =
        widget.customers.any((customer) => customer.id == sale?.customerId)
        ? sale!.customerId
        : widget.customers.first.id;
    _productId = selectedProduct.id;
    _paymentStatus = sale?.paymentStatus ?? 'pending';
    _quantityController = TextEditingController(
      text: sale == null ? '1' : sale.quantity.toString(),
    )..addListener(() => setState(() {}));
    _unitPriceController = TextEditingController(
      text: sale == null
          ? selectedProduct.sellingPrice.toStringAsFixed(2)
          : sale.unitPrice.toStringAsFixed(2),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalAmount;

    return AlertDialog(
      title: Text(widget.sale == null ? 'New sale' : 'Edit sale'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: [
                  for (final customer in widget.customers)
                    DropdownMenuItem(
                      value: customer.id,
                      child: Text(
                        customer.name.isEmpty
                            ? 'Unnamed customer'
                            : customer.name,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _customerId = value ?? _customerId),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _productId,
                decoration: const InputDecoration(labelText: 'Product'),
                items: [
                  for (final product in widget.products)
                    DropdownMenuItem(
                      value: product.id,
                      child: Text(
                        product.name.isEmpty ? 'Unnamed product' : product.name,
                      ),
                    ),
                ],
                onChanged: (value) {
                  final nextProduct = widget.products.firstWhere(
                    (product) => product.id == value,
                    orElse: () => widget.products.first,
                  );
                  setState(() {
                    _productId = nextProduct.id;
                    _unitPriceController.text = nextProduct.sellingPrice
                        .toStringAsFixed(2);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (value) {
                  final quantity = int.tryParse(value ?? '');
                  return quantity == null || quantity <= 0
                      ? 'Enter a valid quantity'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Unit price (₦)'),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return amount == null || amount < 0
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment status'),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'partial', child: Text('Partial')),
                ],
                onChanged: (value) =>
                    setState(() => _paymentStatus = value ?? _paymentStatus),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Total: ${_money(total)}'),
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
            final quantity = int.parse(_quantityController.text);
            final unitPrice = double.parse(_unitPriceController.text);
            Navigator.of(context).pop(
              Sale(
                id: widget.sale?.id ?? '',
                customerId: _customerId,
                productId: _productId,
                quantity: quantity,
                unitPrice: unitPrice,
                totalAmount: quantity * unitPrice,
                paymentStatus: _paymentStatus,
                saleDate: widget.sale?.saleDate ?? DateTime.now(),
                createdAt: widget.sale?.createdAt,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  double get _totalAmount {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;
    return quantity * unitPrice;
  }
}

class _EmptySales extends StatelessWidget {
  const _EmptySales();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        Icon(Icons.point_of_sale_outlined, size: 48),
        SizedBox(height: 12),
        Center(child: Text('No sales yet')),
      ],
    );
  }
}

String _customerName(List<Customer> customers, String id) {
  for (final customer in customers) {
    if (customer.id == id) {
      return customer.name.isEmpty ? 'Unnamed customer' : customer.name;
    }
  }
  return 'Customer';
}

String _productName(List<Product> products, String id) {
  for (final product in products) {
    if (product.id == id) {
      return product.name.isEmpty ? 'Unnamed product' : product.name;
    }
  }
  return 'Product';
}

String _money(double value) => '₦${value.toStringAsFixed(2)}';
