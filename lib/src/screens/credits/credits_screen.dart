import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/pressable.dart';
import '../../widgets/header_back_button.dart';
import '../../widgets/app_toast.dart';

/// Screen 7 — Outstanding Credits.
///
/// Orange total banner; per-customer cards (name, product × qty, sale date,
/// orange amount, green "Mark as Paid" button that removes the card); empty
/// state "All credits collected!" once nothing is owed.
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  static const route = '/credits';

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  Future<void> _markPaid(Credit credit) async {
    await AppScope.of(context).markCreditPaid(credit.saleId);
    if (!mounted) return;
    showAppToast(
      context,
      '✅ ${formatNaira(credit.amount)} collected from ${credit.customerName}',
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
              child: StreamBuilder<List<Credit>>(
                stream: store.watchOwedCredits(),
                builder: (context, snapshot) {
                  final credits = snapshot.data;
                  if (credits == null) return const SizedBox.shrink();
                  if (credits.isEmpty) return const _EmptyState();
                  final total = credits.fold(0, (sum, c) => sum + c.amount);
                  return ListView(
                    padding: AppShape.screenBody,
                    children: [
                      AppCard.tinted(
                        color: AppColors.orangeTint,
                        borderColor: AppColors.orangeBorder,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL OUTSTANDING',
                                  style: AppText.style(
                                    FontWeight.w700,
                                    12,
                                    AppColors.accentOrange,
                                  ),
                                ),
                                const SizedBox(height: AppShape.gapXs),
                                Text(
                                  formatNaira(total),
                                  style: AppText.style(
                                    FontWeight.w900,
                                    24,
                                    AppColors.accentOrange,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.schedule_rounded,
                              size: 24,
                              color: AppColors.accentOrange,
                            ),
                          ],
                        ),
                      ),
                      for (final credit in credits) ...[
                        const SizedBox(height: AppShape.cardGap),
                        _CreditCard(
                          credit: credit,
                          onMarkPaid: () => _markPaid(credit),
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
      bottomNavigationBar: const AppTabBar(active: AppTab.credits),
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
        children: [
          const HeaderBackButton(),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Outstanding Credits',
                style: AppText.screenTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.credit, required this.onMarkPaid});

  final Credit credit;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.cardRadius),
        boxShadow: AppShape.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.accentOrange),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            credit.customerName,
                            style: AppText.style(
                              FontWeight.w700,
                              14,
                              AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(credit.product, style: AppText.caption),
                          const SizedBox(height: 2),
                          Text(
                            'Sold: ${formatDayMonthYear(credit.soldAt)}',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatNaira(credit.amount),
                          style: AppText.style(
                            FontWeight.w800,
                            14,
                            AppColors.accentOrange,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Pressable(
                          onTap: onMarkPaid,
                          semanticLabel: 'Mark as paid',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                AppShape.controlRadius,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Mark as Paid',
                                  style: AppText.style(
                                    FontWeight.w700,
                                    11,
                                    Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mintTint,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'All credits collected!',
            style: AppText.style(FontWeight.w700, 16, AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'No customers owe you money.',
            style: AppText.style(FontWeight.w600, 13, AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
