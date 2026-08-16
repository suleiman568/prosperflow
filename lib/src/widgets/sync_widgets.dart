import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../sync/sync_engine.dart';
import '../theme/tokens.dart';
import '../utils/dates.dart';
import '../utils/plural.dart';
import 'app_card.dart';
import 'app_toast.dart';

/// Gray strip under the app bar when offline (handoff §6):
/// "📴 Offline — sales save on your phone". Calm gray, never red.
class OfflinePill extends StatelessWidget {
  const OfflinePill({super.key, required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    if (state.online) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.offlineBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Text(
        '📴 Offline — sales save on your phone',
        textAlign: TextAlign.center,
        style: AppText.style(FontWeight.w600, 12, AppColors.offlineFg),
      ),
    );
  }
}

/// Dashboard sync status row: "✅ Backed up 2 min ago" (green tint) ↔
/// "🕓 3 sales waiting to sync" (gray tint). Tapping triggers manual sync.
class SyncStatusRow extends StatelessWidget {
  const SyncStatusRow({super.key, required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    // Green is reserved for "your work is safe on the server". A restore in
    // flight has not earned it yet, so it takes the calm gray too.
    final pendingOrOffline =
        !state.online || state.hasPending || state.restoring;
    final String text;
    if (state.restoring) {
      // Ahead of everything else: until the ledger is here, what is queued or
      // when it last backed up is not the question the trader is asking.
      if (!state.online) {
        text = '📴 Offline — your data comes back when you are';
      } else {
        final n = state.restoredRows;
        text = n > 0
            ? '⏳ Restoring your data — ${countNoun(n, 'item')} so far'
            : '⏳ Restoring your data…';
      }
    } else if (state.hasPending) {
      final n = state.pendingSales;
      text = n > 0
          ? '🕓 ${countNoun(n, 'sale')} waiting to sync'
          : '🕓 Changes waiting to sync';
    } else if (!state.online) {
      text = '📴 Offline — sales save on your phone';
    } else if (state.lastSyncAt != null) {
      text = '✅ Backed up ${formatAgo(state.lastSyncAt!)}';
    } else {
      text = '✅ Saved on this phone';
    }
    final fg = pendingOrOffline ? AppColors.offlineFg : AppColors.positive;

    return AppCard.tinted(
      color: pendingOrOffline ? AppColors.offlineBg : AppColors.positiveTint,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onTap: () => runManualSync(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: AppText.style(FontWeight.w700, 12, fg),
            ),
          ),
          Row(
            children: [
              Icon(Icons.sync_rounded, size: 13, color: fg),
              const SizedBox(width: 3),
              Text('sync', style: AppText.style(FontWeight.w600, 11, fg)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Wraps a scrollable in pull-to-refresh that runs a manual sync — the same
/// action (and toasts) as the header ↻ button, with the platform's standard
/// refresh spinner in the app's green.
///
/// A manual sync pushes pending local changes and then pulls down whatever
/// has changed elsewhere, so on a phone waiting to be restored this gesture is
/// also what fetches the ledger. The wording stays "sync/back up now" because
/// backing up is what a trader is usually reaching for.
class PullToSync extends StatelessWidget {
  const PullToSync({super.key, required this.child, this.onRefresh});

  final Widget child;

  /// Extra work to run alongside the manual sync. Used from the error panel
  /// to re-subscribe the failed stream (the same reset the "Try again" button
  /// does) — a pull there must recover the screen, not just back up pending
  /// changes.
  ///
  /// It runs *after* the sync, on purpose: [runManualSync] shows its
  /// completion toast via this [context], and a reset that re-keys the
  /// enclosing `StreamBuilder` would unmount that context first — dropping the
  /// toast. Syncing first keeps the context alive for the toast, then the
  /// reset recovers the view.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.textPrimary,
      onRefresh: () async {
        await runManualSync(context);
        onRefresh?.call();
      },
      child: child,
    );
  }
}

/// Makes non-scrolling content (an empty or error panel) fill the viewport so
/// it can still be pulled down to sync — [RefreshIndicator] needs a scrollable
/// child that can overscroll, which a bare centered panel isn't. Wrap this in
/// [PullToSync] to make those states refreshable, which is exactly when a user
/// most wants to retry a sync.
class RefreshableViewport extends StatelessWidget {
  const RefreshableViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

/// Manual sync with the design's toasts (handoff §6).
Future<void> runManualSync(BuildContext context) async {
  final engine = AppScope.syncOf(context);
  if (!engine.state.online) {
    showAppToast(context, '📴 No connection — will back up when online');
    return;
  }
  final result = await engine.syncNow();
  if (!context.mounted) return;
  if (result.failed) {
    showAppToast(context, '⚠ Backup didn\'t finish — will retry shortly');
  } else if (result.pushedSales > 0) {
    final n = result.pushedSales;
    showAppToast(context, '✅ ${countNoun(n, 'sale')} backed up');
  } else {
    showAppToast(context, '✅ Everything is backed up');
  }
}
