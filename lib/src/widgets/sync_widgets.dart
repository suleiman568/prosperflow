import 'package:flutter/material.dart';

import '../data/app_scope.dart';
import '../sync/sync_engine.dart';
import '../theme/tokens.dart';
import '../utils/dates.dart';
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
    final pendingOrOffline = !state.online || state.hasPending;
    final String text;
    if (state.hasPending) {
      final n = state.pendingSales;
      text = n > 0
          ? '🕓 $n sale${n > 1 ? 's' : ''} waiting to sync'
          : '🕓 Changes waiting to sync';
    } else if (!state.online) {
      text = '📴 Offline — sales save on your phone';
    } else if (state.lastSyncAt != null) {
      text = '✅ Backed up ${formatAgo(state.lastSyncAt!)}';
    } else {
      text = '✅ Saved on this phone';
    }
    final fg = pendingOrOffline ? AppColors.offlineFg : AppColors.primary;

    return AppCard.tinted(
      color: pendingOrOffline ? AppColors.offlineBg : AppColors.mintTint,
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
    showAppToast(context, '✅ $n sale${n > 1 ? 's' : ''} backed up');
  } else {
    showAppToast(context, '✅ Everything is backed up');
  }
}
