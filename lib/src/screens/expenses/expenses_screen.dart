import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/deletable_card.dart';
import '../../widgets/filled_input.dart';
import '../../widgets/primary_button.dart';

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
  void _openAddExpense() {
    final store = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
          showAppToast(context, '✅ Expense recorded');
        },
      ),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    await AppScope.of(context).deleteExpense(expense.id);
    if (!mounted) return;
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
                stream: store.watchExpenses(),
                builder: (context, snapshot) {
                  final expenses = snapshot.data ?? const <Expense>[];
                  final weekStart =
                      DateTime.now().subtract(const Duration(days: 7));
                  final weekTotal = expenses
                      .where((e) => e.spentOn.isAfter(weekStart))
                      .fold(0, (sum, e) => sum + e.amount);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
                    children: [
                      AppCard.tinted(
                        color: AppColors.redTint,
                        borderColor: AppColors.redBorder,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "THIS WEEK'S TOTAL",
                              style: AppText.style(
                                  FontWeight.w700, 12, AppColors.accentRed),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatNaira(weekTotal),
                              style: AppText.style(
                                  FontWeight.w900, 28, AppColors.accentRed),
                            ),
                          ],
                        ),
                      ),
                      for (final expense in expenses) ...[
                        const SizedBox(height: AppShape.cardGap),
                        DeletableCard(
                          itemKey: expense.id,
                          title: 'Delete ${expense.description}?',
                          message: 'The -${formatNaira(expense.amount)} '
                              'expense will leave your totals and reports.',
                          onDelete: () => _deleteExpense(expense),
                          child: _ExpenseCard(expense: expense),
                        ),
                      ],
                    ],
                  );
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
          Text('Expenses', style: AppText.screenTitle),
        ],
      ),
    );
  }
}

/// List card per the component inventory: white card with a 4px red left
/// border, leading 42px tinted icon circle, trailing red amount.
class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.cardRadius),
        boxShadow: AppShape.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 4, height: 70, color: AppColors.accentRed),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.redTint,
                    ),
                    child: Icon(
                      expenseCategoryIcon(expense.category),
                      size: 18,
                      color: AppColors.accentRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description,
                          style: AppText.style(
                              FontWeight.w700, 13, AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatWeekdayDayMonth(expense.spentOn),
                          style: AppText.style(
                              FontWeight.w600, 11, AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${formatNaira(expense.amount)}',
                    style:
                        AppText.style(FontWeight.w700, 13, AppColors.accentRed),
                  ),
                ],
              ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentRed,
          boxShadow: [
            BoxShadow(
              color: Color(0x59C62828),
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

typedef _AddExpense = Future<void> Function(
    String description, int amount, ExpenseCategory category, DateTime spentOn);

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet({required this.onAdd});

  final _AddExpense onAdd;

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.delivery;
  DateTime _date = DateTime.now();

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

  void _submit() {
    final description = _description.text.trim();
    final amount = int.tryParse(_amount.text.trim());
    if (description.isEmpty || amount == null) {
      showAppToast(context, '⚠ Enter a description and amount');
      return;
    }
    widget.onAdd(description, amount, _category, _date);
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
          Text('Add Expense', style: AppText.screenTitle),
          const SizedBox(height: 16),
          _label('DESCRIPTION'),
          FilledInput(
            hint: 'Delivery Cost',
            controller: _description,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppShape.cardGap),
          _label('AMOUNT (₦)'),
          FilledInput(
            hint: '8500',
            controller: _amount,
            digitsOnly: true,
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
                          ? AppColors.accentRed
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(AppShape.controlRadius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatWeekdayDayMonth(_date), style: AppText.input),
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Add Expense', onPressed: _submit),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppText.fieldLabel),
      );
}
