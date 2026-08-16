import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../sync/sync_engine.dart';
import '../theme/tokens.dart';
import '../utils/plural.dart';

/// Shown in place of an empty state while this device is still bringing the
/// trader's ledger down for the first time.
///
/// The two situations are indistinguishable from the database alone — a new
/// phone and a new trader both have nothing in it — and the messages they call
/// for are opposites. "No products yet" told to someone whose products are
/// still arriving invites them to type it all in again, which mints fresh ids
/// for stock they already own and leaves the ledger holding each product
/// twice once the restore lands.
class RestoringState extends StatelessWidget {
  const RestoringState({super.key, required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    // Offline is the more useful thing to say when both are true: nothing is
    // coming until the connection does, and a spinner would suggest otherwise.
    final offline = !state.online;
    final rows = state.restoredRows;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppShape.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (offline)
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.placeholder,
              )
            else
              const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.placeholder,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppShape.gapMd),
            Text(
              offline ? 'Waiting for a connection' : 'Restoring your data',
              style: AppText.emptyTitle,
            ),
            const SizedBox(height: 6),
            Text(
              offline
                  ? 'Your ledger is safe on the server. It comes back as '
                        'soon as you are online.'
                  : 'Everything you saved is coming back to this phone. '
                        'Nothing is missing — please give it a moment.',
              textAlign: TextAlign.center,
              style: AppText.style(
                FontWeight.w600,
                13,
                AppColors.textSecondary,
              ),
            ),
            // Only once something has actually landed. "0 items so far" reads
            // as a failure at the exact moment there is nothing wrong.
            if (!offline && rows > 0) ...[
              const SizedBox(height: AppShape.gapMd),
              Text(
                '${countNoun(rows, 'item')} so far',
                style: AppText.style(
                  FontWeight.w700,
                  12,
                  AppColors.placeholder,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders [empty] unless a first restore is still running, in which case it
/// says that instead.
///
/// Wraps every empty state that a restore could be responsible for, so the
/// screens do not each have to reason about sync.
class EmptyUnlessRestoring extends StatelessWidget {
  const EmptyUnlessRestoring({super.key, required this.empty});

  final Widget empty;

  @override
  Widget build(BuildContext context) {
    final sync = AppScope.syncOf(context);
    return StreamBuilder<SyncState>(
      stream: sync.watchState(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? sync.state;
        return state.restoring ? RestoringState(state: state) : empty;
      },
    );
  }
}
