/// Active Weak Spots Card
/// Home screen dashboard widget showing top 3 active/improving weak spots.
/// Sort order: active → severity (high > medium > low) → score descending.
/// Empty state: "No Active Weak Spots 🎉"
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../screens/all_weak_spots_screen.dart';

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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: PlatformSizing.spacing(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(16)),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              PlatformSizing.spacing(16),
              PlatformSizing.spacing(14),
              PlatformSizing.spacing(16),
              PlatformSizing.spacing(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.psychology_outlined,
                  color: AppColors.primaryPurple,
                  size: PlatformSizing.iconSize(20),
                ),
                SizedBox(width: PlatformSizing.spacing(8)),
                Expanded(
                  child: Text(
                    isLoading
                        ? 'Active Weak Spots'
                        : 'Active Weak Spots${_activeItems.isNotEmpty ? ' (${_activeItems.length})' : ''}',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      fontSize: PlatformSizing.fontSize(15),
                    ),
                  ),
                ),
                if (!isLoading && _activeItems.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AllWeakSpotsScreen(
                          weakSpots: weakSpots,
                          authToken: authToken,
                          userId: userId,
                        ),
                      ),
                    ),
                    child: Text(
                      'View All →',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontSize: PlatformSizing.fontSize(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (isLoading)
            _buildLoading()
          else if (_activeItems.isEmpty)
            _buildEmpty()
          else
            _buildList(context),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: EdgeInsets.all(PlatformSizing.spacing(16)),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: EdgeInsets.all(PlatformSizing.spacing(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No Active Weak Spots 🎉',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
              fontSize: PlatformSizing.fontSize(14),
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(4)),
          Text(
            'Complete chapter practice to discover weak spots.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMedium,
              fontSize: PlatformSizing.fontSize(12),
            ),
          ),
        ],
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
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              _buildRow(item),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildRow(WeakSpotEntry item) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: PlatformSizing.spacing(16),
        vertical: PlatformSizing.spacing(12),
      ),
      child: Row(
        children: [
          Container(
            width: PlatformSizing.spacing(8),
            height: PlatformSizing.spacing(8),
            decoration: BoxDecoration(
              color: item.stateColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: PlatformSizing.spacing(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nodeTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    fontSize: PlatformSizing.fontSize(14),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: PlatformSizing.spacing(2)),
                Text(
                  item.stateLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: item.stateColor,
                    fontSize: PlatformSizing.fontSize(12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
