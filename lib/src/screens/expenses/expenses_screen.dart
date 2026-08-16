import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../utils/haptics.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/money_text.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/header_back_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/deletable_card.dart';
import '../../widgets/discard_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/filled_input.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/restoring_state.dart';
import '../../widgets/sync_widgets.dart';

/// Screen 5 — Expenses.
///
/// Red weekly summary banner; expense list cards with a 4px red left border;
/// red FAB opens the Add Expense bottom sheet (description, amount, category,
/// date).
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  static const route = '/expenses';

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  /// Bumped to force a fresh subscription — by the error panel's "Try again"
  /// and by a pull-to-refresh made from that panel.
  int _retryTick = 0;

  void _retry() {
    if (mounted) setState(() => _retryTick++);
  }

  void _openAddExpense() {
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
      builder: (sheetContext) => _AddExpenseSheet(
        onAdd: (description, amount, category, spentOn) async {
          await store.addExpense(
            description: description,
            amount: amount,
            category: category,
            spentOn: spentOn,
          );
          if (!mounted) return;
          AppHaptics.success();
          showAppToast(context, '✅ Expense recorded');
        },
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    await AppScope.of(context).deleteExpense(expense.id);
    if (!mounted) return;
    AppHaptics.warning();
    showAppToast(context, '\u2705 ${expense.description} deleted');
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
              child: StreamBuilder<List<Expense>>(
                key: ValueKey(_retryTick),
                stream: store.watchExpenses(),
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
                      child: EmptyUnlessRestoring(
                        empty: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No expenses yet',
                          message:
                              'Track costs like transport, rent and '
                              'stock here\nso your profit stays honest.',
                          actionLabel: 'Add expense',
                          onAction: _openAddExpense,
                        ),
                      ),
                    );
                  } else {
                    final expenses = snapshot.data!;
                    final weekStart = DateTime.now().subtract(
                      const Duration(days: 7),
                    );
                    final weekTotal = expenses
                        .where((e) => e.spentOn.isAfter(weekStart))
                        .fold(0, (sum, e) => sum + e.amount);
                    body = ListView(
                      padding: AppShape.screenBodyFab,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        AppCard.tinted(
                          color: AppColors.negativeTint,
                          borderColor: AppColors.negativeBorder,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "THIS WEEK'S TOTAL",
                                style: AppText.style(
                                  FontWeight.w700,
                                  12,
                                  AppColors.negative,
                                ),
                              ),
                              const SizedBox(height: AppShape.gapXs),
                              MoneyText(
                                weekTotal,
                                style: AppText.style(
                                  FontWeight.w900,
                                  28,
                                  AppColors.negative,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final expense in expenses) ...[
                          const SizedBox(height: AppShape.cardGap),
                          DeletableCard(
                            itemKey: expense.id,
                            title: 'Delete ${expense.description}?',
                            message:
                                'The -${formatNaira(expense.amount)} '
                                'expense will leave your totals and reports.',
                            onDelete: () => _deleteExpense(expense),
                            child: _ExpenseCard(
                              expense: expense,
                              menu: CardOverflowMenu(
                                title: 'Delete ${expense.description}?',
                                message:
                                    'The -${formatNaira(expense.amount)} '
                                    'expense will leave your totals and '
                                    'reports.',
                                onDelete: () => _deleteExpense(expense),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                  return PullToSync(onRefresh: onRefresh, child: body);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _Fab(onTap: _openAddExpense),
      bottomNavigationBar: const AppTabBar(),
    );
  }
}

IconData expenseCategoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.delivery => Icons.local_shipping_rounded,
  ExpenseCategory.stock => Icons.shopping_cart_rounded,
  ExpenseCategory.rent => Icons.storefront_rounded,
  ExpenseCategory.transport => Icons.bolt_rounded,
  ExpenseCategory.other => Icons.receipt_long_rounded,
};

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
        children: [
          const HeaderBackButton(),
          const Expanded(
            child: ScreenTitle('Expenses', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Placeholder total banner + rows shown while the expense stream delivers
/// its first value, so the screen fades in instead of flashing blank.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppShape.screenBodyFab,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AppCard.tinted(
          color: AppColors.negativeTint,
          borderColor: AppColors.negativeBorder,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 120, height: 12),
              SizedBox(height: AppShape.gapSm),
              Skeleton(width: 160, height: 28),
            ],
          ),
        ),
        for (var i = 0; i < 5; i++) ...[
          const SizedBox(height: AppShape.cardGap),
          const _SkeletonExpenseCard(),
        ],
      ],
    );
  }
}

class _SkeletonExpenseCard extends StatelessWidget {
  const _SkeletonExpenseCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.cardRadius),
        boxShadow: AppShape.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: const Row(
        children: [
          Skeleton.circle(size: 42),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 140, height: 13),
                SizedBox(height: 6),
                Skeleton(width: 90, height: 11),
              ],
            ),
          ),
          SizedBox(width: 12),
          Skeleton(width: 60, height: 13),
        ],
      ),
    );
  }
}

/// List card per the component inventory: white card with a 4px red left
/// border, leading 42px tinted icon circle, trailing red amount.
class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, this.menu});

  final Expense expense;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.cardRadius),
        boxShadow: AppShape.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      // The 4px red edge is a Positioned stripe that stretches to the card's
      // height for free (Stack sizes to the padded content) — no extra
      // IntrinsicHeight layout pass per row.
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: SizedBox(
              width: 4,
              child: ColoredBox(color: AppColors.negative),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.negativeTint,
                  ),
                  child: Icon(
                    expenseCategoryIcon(expense.category),
                    size: 18,
                    color: AppColors.negative,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.description, style: AppText.listTitle),
                      const SizedBox(height: 2),
                      Text(
                        formatWeekdayDayMonth(expense.spentOn),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                Text(
                  '-${formatNaira(expense.amount)}',
                  style: AppText.style(FontWeight.w700, 13, AppColors.negative),
                ),
                if (menu != null) ...[const SizedBox(width: 2), menu!],
              ],
            ),
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
      semanticLabel: 'Add expense',
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.negative,
        ).copyWith(boxShadow: AppShape.glow(AppColors.negative)),
        child: const Icon(Icons.add, size: 24, color: Colors.white),
      ),
    );
  }
}

typedef _AddExpense =
    Future<void> Function(
      String description,
      int amount,
      ExpenseCategory category,
      DateTime spentOn,
    );

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({required this.onAdd});

  final _AddExpense onAdd;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  static const _initialCategory = ExpenseCategory.delivery;
  ExpenseCategory _category = _initialCategory;
  final DateTime _initialDate = DateTime.now();
  late DateTime _date = _initialDate;

  static const _categoryLabels = {
    ExpenseCategory.delivery: 'Delivery',
    ExpenseCategory.stock: 'Stock',
    ExpenseCategory.rent: 'Rent',
    ExpenseCategory.transport: 'Transport',
    ExpenseCategory.other: 'Other',
  };

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Dirty when any editable field departs from its initial value — the text
  /// fields (normalized, so whitespace-only isn't "dirty"), the category, or
  /// the date (compared by calendar day, so re-picking today is a no-op).
  bool get _isDirty =>
      _description.text.trim().isNotEmpty ||
      _amount.text.trim().isNotEmpty ||
      _category != _initialCategory ||
      !_isSameDay(_date, _initialDate);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _submit() {
    final description = _description.text.trim();
    final amount = parseAmount(_amount.text);
    if (description.isEmpty || amount == null) {
      showAppToast(context, '⚠ Enter a description and amount');
      return;
    }
    widget.onAdd(description, amount, _category, _date);
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
            Text('Add Expense', style: AppText.screenTitle),
            const SizedBox(height: AppShape.gapLg),
            _label('DESCRIPTION'),
            FilledInput(
              hint: 'Delivery Cost',
              controller: _description,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppShape.cardGap),
            _label('AMOUNT (₦)'),
            FilledInput(
              hint: '8,500',
              controller: _amount,
              groupThousands: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppShape.cardGap),
            _label('CATEGORY'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in ExpenseCategory.values)
                  GestureDetector(
                    onTap: () => setState(() => _category = category),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _category == category
                            ? AppColors.negative
                            : AppColors.inputBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            expenseCategoryIcon(category),
                            size: 14,
                            color: _category == category
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _categoryLabels[category]!,
                            style: AppText.style(
                              FontWeight.w700,
                              12,
                              _category == category
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppShape.cardGap),
            _label('DATE'),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(AppShape.controlRadius),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatWeekdayDayMonth(_date), style: AppText.input),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            PrimaryButton(label: 'Add Expense', onPressed: _submit),
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
