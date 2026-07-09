import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/app_toast.dart';
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
                    itemBuilder: (_, index) => _DeletableProductCard(
                      product: products[index],
                      onDelete: () => _deleteProduct(products[index]),
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
  const _ProductCard({required this.product});

  final Product product;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: product.isLow ? AppColors.orangeTint : AppColors.mintTint,
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
        ],
      ),
    );
  }
}


/// Swipe left to delete, with a confirmation dialog. Deletion is a soft
/// delete in the local store and syncs to Supabase like any other update.
class _DeletableProductCard extends StatelessWidget {
  const _DeletableProductCard({required this.product, required this.onDelete});

  final Product product;
  final Future<void> Function() onDelete;

  Future<bool?> _confirm(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.cardRadius),
        ),
        title: Text(
          'Delete ${product.name}?',
          style: AppText.style(FontWeight.w800, 17, AppColors.textPrimary),
        ),
        content: Text(
          'It will be removed from your products. '
          'Past sales are not affected.',
          style: AppText.style(FontWeight.w500, 13, AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style:
                  AppText.style(FontWeight.w700, 13, AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppShape.controlRadius),
              ),
            ),
            child: Text(
              'Delete',
              style: AppText.style(FontWeight.w700, 13, Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(product.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.accentRed,
          borderRadius: BorderRadius.circular(AppShape.cardRadius),
        ),
        child: const Icon(Icons.delete_rounded, size: 24, color: Colors.white),
      ),
      child: _ProductCard(product: product),
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
