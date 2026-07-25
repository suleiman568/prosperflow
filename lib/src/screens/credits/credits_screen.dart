import 'package:flutter/material.dart';

import '../../data/app_scope.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../utils/haptics.dart';
import '../../utils/naira.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/pressable.dart';
import '../../widgets/header_back_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/error_state.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/sync_widgets.dart';

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
  /// Bumped by the error state's "Try again" to force a fresh subscription.
  int _retryTick = 0;

  Future<void> _markPaid(Credit credit) async {
    await AppScope.of(context).markCreditPaid(credit.saleId);
    if (!mounted) return;
    AppHaptics.success();
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
                key: ValueKey(_retryTick),
                stream: store.watchOwedCredits(),
                builder: (context, snapshot) {
                  final Widget body;
                  if (snapshot.hasError) {
                    body = RefreshableViewport(
                      child: ErrorState(
                        onRetry: () => setState(() => _retryTick++),
                      ),
                    );
                  } else if (snapshot.data == null) {
                    body = const _LoadingList();
                  } else if (snapshot.data!.isEmpty) {
                    body = const RefreshableViewport(child: _EmptyState());
                  } else {
                    final credits = snapshot.data!;
                    final total = credits.fold(0, (sum, c) => sum + c.amount);
                    body = ListView(
                      padding: AppShape.screenBody,
                      physics: const AlwaysScrollableScrollPhysics(),
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
                  }
                  return PullToSync(child: body);
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
          const Expanded(
            child: ScreenTitle(
              'Outstanding Credits',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder total banner + rows shown while the credit stream delivers
/// its first value, so the screen fades in instead of flashing blank.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppShape.screenBody,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AppCard.tinted(
          color: AppColors.orangeTint,
          borderColor: AppColors.orangeBorder,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 130, height: 12),
                  SizedBox(height: AppShape.gapSm),
                  Skeleton(width: 150, height: 24),
                ],
              ),
              Skeleton.circle(size: 24),
            ],
          ),
        ),
        for (var i = 0; i < 4; i++) ...[
          const SizedBox(height: AppShape.cardGap),
          const _SkeletonCreditCard(),
        ],
      ],
    );
  }
}

class _SkeletonCreditCard extends StatelessWidget {
  const _SkeletonCreditCard();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 96, color: AppColors.orangeTint),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 120, height: 14),
                        SizedBox(height: 6),
                        Skeleton(width: 150, height: 11),
                        SizedBox(height: 4),
                        Skeleton(width: 90, height: 11),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Skeleton(width: 70, height: 14),
                      SizedBox(height: 10),
                      Skeleton(width: 90, height: 26, radius: 12),
                    ],
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
