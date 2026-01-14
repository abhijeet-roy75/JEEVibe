// Offline Banner Widget
//
// Displays a persistent banner when the app is offline.
// Shows different messages based on tier (free users see "upgrade" message).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/offline_provider.dart';
import '../../models/offline/cached_solution.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class OfflineBanner extends StatelessWidget {
  final bool showUpgradeHint;

  const OfflineBanner({
    super.key,
    this.showUpgradeHint = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        // Only show when offline
        if (!offlineProvider.isInitialized || offlineProvider.isOnline) {
          return const SizedBox.shrink();
        }

        final hasOfflineAccess = offlineProvider.offlineEnabled;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: hasOfflineAccess
                ? AppColors.warningAmber.withValues(alpha: 0.9)
                : AppColors.textMedium.withValues(alpha: 0.9),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(
                  hasOfflineAccess ? Icons.cloud_off : Icons.wifi_off,
                  color: hasOfflineAccess ? Colors.white : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasOfflineAccess
                        ? "You're offline - viewing cached content"
                        : "You're offline - some features unavailable",
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (hasOfflineAccess && offlineProvider.hasPendingActions)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${offlineProvider.pendingActionsCount} pending',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact offline indicator for use in app bars
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        if (!offlineProvider.isInitialized || offlineProvider.isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warningAmber,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Offline',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Sync status indicator showing last sync time and pending count
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        if (!offlineProvider.isInitialized || !offlineProvider.offlineEnabled) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sync icon with state
              _buildSyncIcon(offlineProvider.syncState),
              const SizedBox(width: 8),
              // Status text
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getSyncStatusText(offlineProvider),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (offlineProvider.lastSyncTimeFormatted != null)
                    Text(
                      'Last sync: ${offlineProvider.lastSyncTimeFormatted}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncIcon(SyncState state) {
    switch (state) {
      case SyncState.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryPurple,
          ),
        );
      case SyncState.error:
        return const Icon(
          Icons.sync_problem,
          color: AppColors.errorRed,
          size: 16,
        );
      case SyncState.completed:
        return const Icon(
          Icons.cloud_done,
          color: AppColors.successGreen,
          size: 16,
        );
      case SyncState.idle:
        return const Icon(
          Icons.cloud_queue,
          color: AppColors.textMedium,
          size: 16,
        );
    }
  }

  String _getSyncStatusText(OfflineProvider provider) {
    switch (provider.syncState) {
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.error:
        return 'Sync failed';
      case SyncState.completed:
        return provider.hasPendingActions
            ? '${provider.pendingActionsCount} pending'
            : 'Up to date';
      case SyncState.idle:
        return provider.hasPendingActions
            ? '${provider.pendingActionsCount} pending'
            : 'Ready';
    }
  }
}

