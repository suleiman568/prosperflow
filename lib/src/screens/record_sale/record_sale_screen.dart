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

/// Screen 3 — Record Sale.
///
/// Product picker showing live stock count; qty stepper (min 1, max stock)
/// + unit price; green-gradient Total card that recomputes live; 2×2 payment
/// pills; credit selection shows the "customer name required" banner;
/// Walk-in/Delivery toggle (location field only for Delivery). Saving writes
/// the sale to the local store: stock decrements and, for credit sales, a
/// credit record opens.
class RecordSaleScreen extends StatefulWidget {
  const RecordSaleScreen({super.key});

  static const route = '/record-sale';

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen> {
  String? _productId;
  int _qty = 1;
  PaymentMethod _method = PaymentMethod.cash;
  Fulfilment _fulfilment = Fulfilment.walkIn;
  bool _saving = false;
  final _customerController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _customerController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _pickProduct(List<Product> products) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Choose product', style: AppText.screenTitle),
            ),
            for (final product in products)
              ListTile(
                onTap: () {
                  setState(() {
                    _productId = product.id;
                    _qty = _qty.clamp(1, product.stock.clamp(1, 1 << 31));
                  });
                  Navigator.of(sheetContext).pop();
                },
                title: Text(
                  product.name,
                  style: AppText.style(
                      FontWeight.w700, 14, AppColors.textPrimary),
                ),
                trailing: Text(
                  '${product.stock} in stock',
                  style: AppText.style(FontWeight.w600, 12, AppColors.primary),
                ),
                selected: product.id == _productId,
                selectedTileColor: AppColors.mintTint,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(Product product) async {
    if (_saving) return;
    if (_method == PaymentMethod.credit &&
        _customerController.text.trim().isEmpty) {
      showAppToast(context, '⚠ Customer name is required for credit sales');
      return;
    }
    if (product.stock < 1) {
      showAppToast(context, '⚠ ${product.name} is out of stock');
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final customer = _customerController.text.trim();
    final location = _locationController.text.trim();
    await AppScope.of(context).recordSale(
      productId: product.id,
      qty: _qty,
      method: _method,
      fulfilment: _fulfilment,
      customerName: customer.isEmpty ? null : customer,
      location: _fulfilment == Fulfilment.delivery && location.isNotEmpty
          ? location
          : null,
    );
    if (!mounted) return;
    showAppToast(context, '✅ Sale saved on this phone');
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/dashboard');
    }
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
                  final products = snapshot.data;
                  if (products == null || products.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final product = products.firstWhere(
                    (p) => p.id == _productId,
                    orElse: () => products.first,
                  );
                  final qty = _qty.clamp(1, product.stock.clamp(1, 1 << 31));
                  return _buildForm(products, product, qty);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppTabBar(),
    );
  }

  Widget _buildForm(List<Product> products, Product product, int qty) {
    final total = qty * product.sellPrice;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        const _FieldLabel('PRODUCT — TAP TO CHANGE'),
        GestureDetector(
          onTap: () => _pickProduct(products),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(AppShape.controlRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.style(
                        FontWeight.w700, 14, AppColors.textPrimary),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${product.stock} in stock',
                      style: AppText.style(
                          FontWeight.w600, 12, AppColors.primary),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        size: 18, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppShape.cardGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('QTY'),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius:
                          BorderRadius.circular(AppShape.controlRadius),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StepperButton(
                          icon: Icons.remove,
                          onTap:
                              qty > 1 ? () => setState(() => _qty = qty - 1) : null,
                        ),
                        Text(
                          '$qty',
                          style: AppText.style(
                              FontWeight.w700, 16, AppColors.textPrimary),
                        ),
                        _StepperButton(
                          icon: Icons.add,
                          onTap: qty < product.stock
                              ? () => setState(() => _qty = qty + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppShape.gridGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('PRICE/UNIT'),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius:
                          BorderRadius.circular(AppShape.controlRadius),
                    ),
                    child: Text(
                      formatNaira(product.sellPrice),
                      style: AppText.style(
                          FontWeight.w700, 16, AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppShape.cardGap),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppShape.cardRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL',
                    style: AppText.style(
                        FontWeight.w700, 11, Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 4),
                  Text(formatNaira(total), style: AppText.moneyHero),
                ],
              ),
              const Icon(Icons.account_balance_wallet_rounded,
                  size: 32, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: AppShape.cardGap),
        const _FieldLabel('PAYMENT METHOD'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 170 / 44,
          children: [
            for (final method in PaymentMethod.values)
              _PaymentPill(
                method: method,
                selected: _method == method,
                onTap: () => setState(() => _method = method),
              ),
          ],
        ),
        if (_method == PaymentMethod.credit) ...[
          const SizedBox(height: AppShape.cardGap),
          AppCard.tinted(
            color: AppColors.orangeTint,
            borderColor: AppColors.orangeBorder,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              '⚠ Customer name is required for credit sales',
              style: AppText.style(FontWeight.w700, 12, AppColors.accentOrange),
            ),
          ),
        ],
        const SizedBox(height: AppShape.cardGap),
        Row(
          children: [
            Expanded(
              child: _FulfilmentPill(
                icon: Icons.directions_walk_rounded,
                label: 'Walk-in',
                selected: _fulfilment == Fulfilment.walkIn,
                onTap: () => setState(() => _fulfilment = Fulfilment.walkIn),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FulfilmentPill(
                icon: Icons.directions_car_rounded,
                label: 'Delivery',
                selected: _fulfilment == Fulfilment.delivery,
                onTap: () => setState(() => _fulfilment = Fulfilment.delivery),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppShape.cardGap),
        const _FieldLabel('CUSTOMER NAME'),
        FilledInput(
          hint: 'Chioma Ojo',
          controller: _customerController,
          textInputAction: TextInputAction.next,
        ),
        if (_fulfilment == Fulfilment.delivery) ...[
          const SizedBox(height: AppShape.cardGap),
          const _FieldLabel('DELIVERY LOCATION'),
          FilledInput(
            hint: 'Lekki Phase 1',
            controller: _locationController,
            textInputAction: TextInputAction.done,
          ),
        ],
        const SizedBox(height: 22),
        PrimaryButton(label: 'Record Sale', onPressed: () => _submit(product)),
      ],
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
          Text('Record Sale', style: AppText.screenTitle),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: AppText.fieldLabel),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.placeholder : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _PaymentPill extends StatelessWidget {
  const _PaymentPill({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  static const _specs = {
    PaymentMethod.cash: (
      Icons.payments_rounded,
      'Cash',
      AppColors.primary,
      AppColors.mintTint
    ),
    PaymentMethod.transfer: (
      Icons.account_balance_rounded,
      'Transfer',
      AppColors.accentBlue,
      AppColors.blueTint
    ),
    PaymentMethod.pos: (
      Icons.credit_card_rounded,
      'POS',
      AppColors.accentPurple,
      AppColors.purpleTint
    ),
    PaymentMethod.credit: (
      Icons.schedule_rounded,
      'Credit',
      AppColors.accentOrange,
      AppColors.orangeBorder
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, tint) = _specs[method]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? color : tint, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.style(
                selected ? FontWeight.w700 : FontWeight.w600,
                13,
                selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FulfilmentPill extends StatelessWidget {
  const _FulfilmentPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.inputBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.style(
                FontWeight.w700,
                13,
                selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
