import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/deletable_card.dart';
import '../../widgets/filled_input.dart';
import '../../widgets/primary_button.dart';

/// Screen 4 — Products.
///
/// Product cards (name, stock + unit, buy → sell price, stock/LOW badge);
/// green FAB opens the Add Product bottom sheet (name, unit, buy/sell price,
/// opening stock).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  static const route = '/products';

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  void _openAddProduct() {
    final store = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _AddProductSheet(
        onAdd: (name, unit, stock, buyPrice, sellPrice) async {
          await store.addProduct(
            name: name,
            unit: unit,
            stock: stock,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
          );
          if (!mounted) return;
          showAppToast(context, '✅ $name added');
        },
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    await AppScope.of(context).deleteProduct(product.id);
    if (!mounted) return;
    showAppToast(context, '✅ ${product.name} deleted');
  }

  void _openEditProduct(Product product) {
    final store = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _EditProductSheet(
        product: product,
        onSave: (name, unit, buyPrice, sellPrice, lowStockThreshold) async {
          await store.updateProduct(
            id: product.id,
            name: name,
            unit: unit,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            lowStockThreshold: lowStockThreshold,
          );
          if (!mounted) return;
          showAppToast(context, '✅ $name updated');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: store.watchProducts(),
                builder: (context, snapshot) {
                  final products = snapshot.data ?? const <Product>[];
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
                    itemCount: products.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppShape.cardGap),
                    itemBuilder: (_, index) => DeletableCard(
                      itemKey: products[index].id,
                      title: 'Delete ${products[index].name}?',
                      message: 'It will be removed from your products. '
                          'Past sales are not affected.',
                      onDelete: () => _deleteProduct(products[index]),
                      child: _ProductCard(
                        product: products[index],
                        menu: CardOverflowMenu(
                          title: 'Delete ${products[index].name}?',
                          message: 'It will be removed from your products. '
                              'Past sales are not affected.',
                          onDelete: () => _deleteProduct(products[index]),
                          onEdit: () => _openEditProduct(products[index]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _Fab(onTap: _openAddProduct),
      bottomNavigationBar: const AppTabBar(active: AppTab.products),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                navigator.pushReplacementNamed('/dashboard');
              }
            },
            child: const Icon(Icons.arrow_back,
                size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Text('Products', style: AppText.screenTitle),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, this.menu});

  final Product product;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style:
                      AppText.style(FontWeight.w700, 15, AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.stock} ${product.unit}',
                  style: AppText.style(
                      FontWeight.w600, 12, AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatNaira(product.buyPrice)} → '
                  '${formatNaira(product.sellPrice)}',
                  style: AppText.style(
                      FontWeight.w600, 12, AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      product.isLow ? AppColors.orangeTint : AppColors.mintTint,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  product.isLow ? 'LOW' : '${product.stock}',
                  style: AppText.style(
                    FontWeight.w800,
                    10,
                    product.isLow ? AppColors.accentOrange : AppColors.primary,
                  ),
                ),
              ),
              if (menu != null) ...[
                const SizedBox(height: 6),
                menu!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}


class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: Color(0x590B8F4E),
              offset: Offset(0, 8),
              blurRadius: 20,
            ),
          ],
        ),
        child: const Icon(Icons.add, size: 24, color: Colors.white),
      ),
    );
  }
}

typedef _AddProduct = Future<void> Function(
    String name, String unit, int stock, int buyPrice, int sellPrice);

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet({required this.onAdd});

  final _AddProduct onAdd;

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _name = TextEditingController();
  final _unit = TextEditingController();
  final _buyPrice = TextEditingController();
  final _sellPrice = TextEditingController();
  final _stock = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _buyPrice.dispose();
    _sellPrice.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final unit = _unit.text.trim();
    final buy = int.tryParse(_buyPrice.text.trim());
    final sell = int.tryParse(_sellPrice.text.trim());
    final stock = int.tryParse(_stock.text.trim());
    if (name.isEmpty ||
        unit.isEmpty ||
        buy == null ||
        sell == null ||
        stock == null) {
      showAppToast(context, '⚠ Fill in every field to add a product');
      return;
    }
    widget.onAdd(name, unit, stock, buy, sell);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Product', style: AppText.screenTitle),
          const SizedBox(height: 16),
          _label('PRODUCT NAME'),
          FilledInput(
            hint: 'Palm Oil (25L)',
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppShape.cardGap),
          _label('UNIT'),
          FilledInput(
            hint: 'bottles',
            controller: _unit,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppShape.cardGap),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('BUY PRICE (₦)'),
                    FilledInput(hint: '6800', controller: _buyPrice, digitsOnly: true, textInputAction: TextInputAction.next),
                  ],
                ),
              ),
              const SizedBox(width: AppShape.gridGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('SELL PRICE (₦)'),
                    FilledInput(hint: '9200', controller: _sellPrice, digitsOnly: true, textInputAction: TextInputAction.next),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppShape.cardGap),
          _label('OPENING STOCK'),
          FilledInput(hint: '42', controller: _stock, digitsOnly: true, textInputAction: TextInputAction.done),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Add Product', onPressed: _submit),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppText.fieldLabel),
      );

}

typedef _SaveProduct = Future<void> Function(
    String name, String unit, int buyPrice, int sellPrice,
    int lowStockThreshold);

/// Edit sheet for an existing product. Stock is deliberately absent — it
/// changes through sales; prices/name/unit/threshold change here. Edits
/// never touch past sales (their price/cost snapshots are frozen).
class _EditProductSheet extends StatefulWidget {
  const _EditProductSheet({required this.product, required this.onSave});

  final Product product;
  final _SaveProduct onSave;

  @override
  State<_EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<_EditProductSheet> {
  late final _name = TextEditingController(text: widget.product.name);
  late final _unit = TextEditingController(text: widget.product.unit);
  late final _buyPrice =
      TextEditingController(text: '${widget.product.buyPrice}');
  late final _sellPrice =
      TextEditingController(text: '${widget.product.sellPrice}');
  late final _threshold =
      TextEditingController(text: '${widget.product.lowStockThreshold}');

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _buyPrice.dispose();
    _sellPrice.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final unit = _unit.text.trim();
    final buy = int.tryParse(_buyPrice.text.trim());
    final sell = int.tryParse(_sellPrice.text.trim());
    final threshold = int.tryParse(_threshold.text.trim());
    if (name.isEmpty ||
        unit.isEmpty ||
        buy == null ||
        sell == null ||
        threshold == null) {
      showAppToast(context, '⚠ Fill in every field to save changes');
      return;
    }
    final navigator = Navigator.of(context);
    try {
      await widget.onSave(name, unit, buy, sell, threshold);
    } catch (_) {
      // Keep the sheet open so nothing typed is lost.
      if (mounted) {
        showAppToast(context, '⚠ Could not save changes — please try again');
      }
      return;
    }
    navigator.pop();
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppText.fieldLabel),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Product', style: AppText.screenTitle),
          const SizedBox(height: 4),
          Text(
            'Past sales keep their original prices.',
            style: AppText.style(FontWeight.w600, 12, AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _label('PRODUCT NAME'),
          FilledInput(
            hint: 'Palm Oil (25L)',
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppShape.cardGap),
          _label('UNIT'),
          FilledInput(
            hint: 'bottles',
            controller: _unit,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppShape.cardGap),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('BUY PRICE (₦)'),
                    FilledInput(
                        hint: '6800',
                        controller: _buyPrice,
                        digitsOnly: true,
                        textInputAction: TextInputAction.next),
                  ],
                ),
              ),
              const SizedBox(width: AppShape.gridGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('SELL PRICE (₦)'),
                    FilledInput(
                        hint: '9200',
                        controller: _sellPrice,
                        digitsOnly: true,
                        textInputAction: TextInputAction.next),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppShape.cardGap),
          _label('LOW-STOCK ALERT AT'),
          FilledInput(
              hint: '10',
              controller: _threshold,
              digitsOnly: true,
              textInputAction: TextInputAction.done),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Save Changes', onPressed: _submit),
        ],
      ),
    );
  }
}
