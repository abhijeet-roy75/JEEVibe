/// Active Weak Spots Card
/// Home screen dashboard widget showing top 3 active/improving weak spots.
/// Sort order: active → severity (high > medium > low) → score descending.
/// Empty state: "No Active Weak Spots 🎉"
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../screens/all_weak_spots_screen.dart';
import 'buttons/gradient_button.dart';

/// A single weak spot entry as returned by GET /api/weak-spots/:userId
class WeakSpotEntry {
  final String nodeId;
  final String nodeTitle;
  final String nodeState; // active | improving | stable
  final String severityLevel; // high | medium | low
  final double currentScore;
  final String? capsuleId;
  final String? chapterKey;

  WeakSpotEntry({
    required this.nodeId,
    required this.nodeTitle,
    required this.nodeState,
    required this.severityLevel,
    required this.currentScore,
    this.capsuleId,
    this.chapterKey,
  });

  factory WeakSpotEntry.fromJson(Map<String, dynamic> json) {
    return WeakSpotEntry(
      nodeId: json['nodeId']?.toString() ?? '',
      nodeTitle: json['nodeTitle']?.toString() ?? json['title']?.toString() ?? '',
      nodeState: json['nodeState']?.toString() ?? 'active',
      severityLevel: json['severityLevel']?.toString() ?? 'medium',
      currentScore: (json['currentScore'] ?? json['score'] ?? 0.0).toDouble(),
      capsuleId: json['capsuleId']?.toString(),
      chapterKey: json['chapterKey']?.toString(),
    );
  }

  String get stateLabel {
    switch (nodeState) {
      case 'improving':
        return 'Keep Practicing';
      case 'stable':
        return 'Recently Strengthened';
      case 'active':
      default:
        return 'Needs Strengthening';
    }
  }

  Color get stateColor {
    switch (nodeState) {
      case 'improving':
        return const Color(0xFFF59E0B); // amber
      case 'stable':
        return AppColors.successGreen;
      case 'active':
      default:
        return AppColors.errorRed;
    }
  }

  int get _severityOrder {
    switch (severityLevel) {
      case 'high':
        return 0;
      case 'medium':
        return 1;
      default:
        return 2;
    }
  }

  int get _stateOrder {
    switch (nodeState) {
      case 'active':
        return 0;
      case 'improving':
        return 1;
      default:
        return 2;
    }
  }

  static int compare(WeakSpotEntry a, WeakSpotEntry b) {
    final stateCmp = a._stateOrder.compareTo(b._stateOrder);
    if (stateCmp != 0) return stateCmp;
    final sevCmp = a._severityOrder.compareTo(b._severityOrder);
    if (sevCmp != 0) return sevCmp;
    return b.currentScore.compareTo(a.currentScore); // higher score = worse
  }
}

class ActiveWeakSpotsCard extends StatelessWidget {
  final List<WeakSpotEntry> weakSpots;
  final bool isLoading;
  final String? authToken;
  final String? userId;

  const ActiveWeakSpotsCard({
    super.key,
    required this.weakSpots,
    this.isLoading = false,
    this.authToken,
    this.userId,
  });

  List<WeakSpotEntry> get _activeItems {
    final items = weakSpots
        .where((w) => w.nodeState == 'active' || w.nodeState == 'improving')
        .toList()
      ..sort(WeakSpotEntry.compare);
    return items.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: gradient icon + title
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.ctaGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Weak Spots',
                        style: AppTextStyles.headerSmall.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isLoading && _activeItems.isNotEmpty)
                        Builder(builder: (context) {
                          final activeCount = _activeItems.where((w) => w.nodeState == 'active').length;
                          final improvingCount = _activeItems.where((w) => w.nodeState == 'improving').length;
                          final parts = <String>[];
                          if (activeCount > 0) parts.add('$activeCount to fix');
                          if (improvingCount > 0) parts.add('$improvingCount improving');
                          return Text(
                            parts.join(' · '),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: activeCount > 0 ? AppColors.errorRed : const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        })
                      else if (!isLoading)
                        Text(
                          'All caught up!',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isLoading)
              _buildLoading()
            else if (_activeItems.isEmpty)
              _buildEmpty()
            else ...[
              _buildList(context),
              const SizedBox(height: 16),
              GradientButton(
                text: 'View All Weak Spots',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AllWeakSpotsScreen(
                      weakSpots: weakSpots,
                      authToken: authToken,
                      userId: userId,
                    ),
                  ),
                ),
                size: GradientButtonSize.large,
                trailingIcon: Icons.arrow_forward,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Text(
      'Complete chapter practice to discover weak spots.',
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textMedium,
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: [
        ..._activeItems.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (i > 0) const Divider(height: 1),
              _buildRow(item),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildRow(WeakSpotEntry item) {
    final isImproving = item.nodeState == 'improving';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: item.stateColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nodeTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isImproving) ...[
                      Icon(
                        Icons.check_circle_outline,
                        size: 13,
                        color: item.stateColor,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      item.stateLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: item.stateColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
