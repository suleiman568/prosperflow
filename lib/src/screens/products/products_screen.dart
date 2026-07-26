import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../utils/haptics.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/discard_dialog.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/header_back_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/deletable_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/filled_input.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/sync_widgets.dart';

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
  /// Bumped to force a fresh subscription — by the error panel's "Try again"
  /// and by a pull-to-refresh made from that panel.
  int _retryTick = 0;

  void _retry() {
    if (mounted) setState(() => _retryTick++);
  }

  void _openAddProduct() {
    final store = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // enableDrag off so a drag-dismiss can't bypass the DiscardGuard.
      enableDrag: false,
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
          AppHaptics.success();
          showAppToast(context, '✅ $name added');
        },
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    await AppScope.of(context).deleteProduct(product.id);
    if (!mounted) return;
    AppHaptics.warning();
    showAppToast(context, '✅ ${product.name} deleted');
  }

  void _openEditProduct(Product product) {
    final store = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // enableDrag off so a drag-dismiss can't bypass the DiscardGuard.
      enableDrag: false,
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
          AppHaptics.success();
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
                key: ValueKey(_retryTick),
                stream: store.watchProducts(),
                builder: (context, snapshot) {
                  final Widget body;
                  VoidCallback? onRefresh;
                  if (snapshot.hasError) {
                    onRefresh = _retry;
                    body = RefreshableViewport(
                      child: ErrorState(onRetry: _retry),
                    );
                  } else if (!snapshot.hasData) {
                    body = const _LoadingList();
                  } else if (snapshot.data!.isEmpty) {
                    body = RefreshableViewport(
                      child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products yet',
                        message: 'Everything you sell lives here.',
                        actionLabel: 'Add product',
                        onAction: _openAddProduct,
                      ),
                    );
                  } else {
                    final products = snapshot.data!;
                    body = ListView.separated(
                      padding: AppShape.screenBodyFab,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: products.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppShape.cardGap),
                      itemBuilder: (_, index) => DeletableCard(
                        itemKey: products[index].id,
                        title: 'Delete ${products[index].name}?',
                        message:
                            'It will be removed from your products. '
                            'Past sales are not affected.',
                        onDelete: () => _deleteProduct(products[index]),
                        child: _ProductCard(
                          product: products[index],
                          menu: CardOverflowMenu(
                            title: 'Delete ${products[index].name}?',
                            message:
                                'It will be removed from your products. '
                                'Past sales are not affected.',
                            onDelete: () => _deleteProduct(products[index]),
                            onEdit: () => _openEditProduct(products[index]),
                          ),
                        ),
                      ),
                    );
                  }
                  return PullToSync(onRefresh: onRefresh, child: body);
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
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [const HeaderBackButton(), const ScreenTitle('Products')],
      ),
    );
  }
}

/// Placeholder cards shown while the product stream delivers its first value,
/// so the list fades in instead of flashing an empty screen.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppShape.screenBodyFab,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppShape.cardGap),
      itemBuilder: (_, _) => const _SkeletonProductCard(),
    );
  }
}

class _SkeletonProductCard extends StatelessWidget {
  const _SkeletonProductCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 150, height: 15),
                SizedBox(height: 10),
                Skeleton(width: 80, height: 12),
                SizedBox(height: 6),
                Skeleton(width: 120, height: 12),
              ],
            ),
          ),
          Skeleton(width: 40, height: 20, radius: 100),
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
                Text(product.name, style: AppText.cardTitle),
                const SizedBox(height: AppShape.gapXs),
                Text(
                  '${product.stock} ${product.unit}',
                  style: AppText.cardMeta,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatNaira(product.buyPrice)} → '
                  '${formatNaira(product.sellPrice)}',
                  style: AppText.cardMeta,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: product.isLow
                      ? AppColors.orangeTint
                      : AppColors.mintTint,
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
              if (menu != null) ...[const SizedBox(height: 6), menu!],
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
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Add product',
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ).copyWith(boxShadow: AppShape.glow(AppColors.primary)),
        child: const Icon(Icons.add, size: 24, color: Colors.white),
      ),
    );
  }
}

typedef _AddProduct =
    Future<void> Function(
      String name,
      String unit,
      int stock,
      int buyPrice,
      int sellPrice,
    );

/// Live below-cost / no-margin hint for the product forms. Returns null while
/// either price is still blank or unparseable, or when the sell price clears
/// the buy price. Surfaces a losing price the moment it's typed — at
/// product-definition time — rather than only warning later at sale time.
Widget? _marginWarning(String buyText, String sellText) {
  final buy = int.tryParse(buyText.trim());
  final sell = int.tryParse(sellText.trim());
  if (buy == null || sell == null) return null;
  final String message;
  final Color color;
  if (sell < buy) {
    message =
        '⚠ Below cost — you lose ${formatNaira(buy - sell)} on every sale';
    color = AppColors.accentRed;
  } else if (sell == buy) {
    message = '⚠ No profit — this price only covers your cost';
    color = AppColors.accentOrange;
  } else {
    return null;
  }
  return Padding(
    padding: const EdgeInsets.only(top: AppShape.gapSm),
    child: Text(message, style: AppText.style(FontWeight.w700, 12, color)),
  );
}

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

  // Normalized so whitespace-only input doesn't count as unsaved work.
  bool get _isDirty =>
      _name.text.trim().isNotEmpty ||
      _unit.text.trim().isNotEmpty ||
      _buyPrice.text.trim().isNotEmpty ||
      _sellPrice.text.trim().isNotEmpty ||
      _stock.text.trim().isNotEmpty;

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
    return DiscardGuard(
      isDirty: () => _isDirty,
      child: Padding(
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
            const SizedBox(height: AppShape.gapLg),
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
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
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
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ?_marginWarning(_buyPrice.text, _sellPrice.text),
            const SizedBox(height: AppShape.cardGap),
            _label('OPENING STOCK'),
            FilledInput(
              hint: '42',
              controller: _stock,
              digitsOnly: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 22),
            PrimaryButton(label: 'Add Product', onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppText.fieldLabel),
  );
}

typedef _SaveProduct =
    Future<void> Function(
      String name,
      String unit,
      int buyPrice,
      int sellPrice,
      int lowStockThreshold,
    );

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
  late final _buyPrice = TextEditingController(
    text: '${widget.product.buyPrice}',
  );
  late final _sellPrice = TextEditingController(
    text: '${widget.product.sellPrice}',
  );
  late final _threshold = TextEditingController(
    text: '${widget.product.lowStockThreshold}',
  );
  bool _saving = false;

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
    if (_saving) return;
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
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await widget.onSave(name, unit, buy, sell, threshold);
    } catch (_) {
      // Keep the sheet open so nothing typed is lost, and release the button.
      if (mounted) {
        setState(() => _saving = false);
        showAppToast(context, '⚠ Could not save changes — please try again');
      }
      return;
    }
    navigator.pop();
  }

  // Compare normalized values against the saved product, so re-typing the
  // same text with stray whitespace (a no-op on save) isn't "dirty".
  bool get _isDirty =>
      _name.text.trim() != widget.product.name ||
      _unit.text.trim() != widget.product.unit ||
      _buyPrice.text.trim() != '${widget.product.buyPrice}' ||
      _sellPrice.text.trim() != '${widget.product.sellPrice}' ||
      _threshold.text.trim() != '${widget.product.lowStockThreshold}';

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppText.fieldLabel),
  );

  @override
  Widget build(BuildContext context) {
    return DiscardGuard(
      isDirty: () => _isDirty,
      child: Padding(
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
            const SizedBox(height: AppShape.gapXs),
            Text(
              'Past sales keep their original prices.',
              style: AppText.cardMeta,
            ),
            const SizedBox(height: AppShape.gapLg),
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
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
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
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ?_marginWarning(_buyPrice.text, _sellPrice.text),
            const SizedBox(height: AppShape.cardGap),
            _label('LOW-STOCK ALERT AT'),
            FilledInput(
              hint: '10',
              controller: _threshold,
              digitsOnly: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Save Changes',
              busy: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
