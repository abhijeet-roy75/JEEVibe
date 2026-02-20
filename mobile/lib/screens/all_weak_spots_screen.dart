/// All Weak Spots Screen
/// Shows all weak spots grouped by state.
/// States: active ("Needs Strengthening"), improving ("Keep Practicing"), stable ("Recently Strengthened")
/// "Learn" action available for active nodes with a capsule.
import 'package:flutter/material.dart';
import '../widgets/active_weak_spots_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../widgets/app_header.dart';
import 'capsule_screen.dart';

class AllWeakSpotsScreen extends StatelessWidget {
  final List<WeakSpotEntry> weakSpots;
  final String? authToken;
  final String? userId;

  const AllWeakSpotsScreen({
    super.key,
    required this.weakSpots,
    this.authToken,
    this.userId,
  });

  Map<String, List<WeakSpotEntry>> get _grouped {
    final groups = <String, List<WeakSpotEntry>>{
      'active': [],
      'improving': [],
      'stable': [],
    };
    for (final ws in weakSpots) {
      final state = ws.nodeState;
      if (groups.containsKey(state)) {
        groups[state]!.add(ws);
      } else {
        groups['active']!.add(ws); // fallback
      }
    }
    // Sort each group by severity then score
    for (final key in groups.keys) {
      groups[key]!.sort(WeakSpotEntry.compare);
    }
    return groups;
  }

  String _groupTitle(String state) {
    switch (state) {
      case 'improving':
        return 'KEEP PRACTICING';
      case 'stable':
        return 'RECENTLY STRENGTHENED';
      case 'active':
      default:
        return 'NEEDS STRENGTHENING';
    }
  }

  Color _groupColor(String state) {
    switch (state) {
      case 'improving':
        return const Color(0xFFF59E0B);
      case 'stable':
        return AppColors.successGreen;
      case 'active':
      default:
        return AppColors.errorRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final orderedStates = ['active', 'improving', 'stable'];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          AppHeader(
            showGradient: true,
            gradient: AppColors.ctaGradient,
            topPadding: 16,
            bottomPadding: 20,
            leading: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.all(PlatformSizing.spacing(8)),
                constraints: const BoxConstraints(),
              ),
            ),
            title: Text(
              'My Weak Spots',
              style: AppTextStyles.headerSmall.copyWith(
                fontSize: PlatformSizing.fontSize(20),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
              child: weakSpots.isEmpty
                  ? _buildEmpty()
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        MediaQuery.of(context).viewPadding.bottom + 24,
                      ),
                      children: orderedStates
                          .where((s) => (grouped[s] ?? []).isNotEmpty)
                          .expand((state) => [
                                _buildGroupHeader(state, grouped[state]!.length),
                                SizedBox(height: PlatformSizing.spacing(8)),
                                ...grouped[state]!.map((ws) => _buildCard(context, ws, state)),
                                SizedBox(height: PlatformSizing.spacing(16)),
                              ])
                          .toList(),
                    ),
            ),
          ],
        ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 56,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No Weak Spots Yet',
              style: AppTextStyles.headerMedium.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete chapter practice to discover areas that need strengthening.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String state, int count) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _groupColor(state),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_groupTitle(state)} ($count)',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: PlatformSizing.fontSize(12),
            fontWeight: FontWeight.bold,
            color: AppColors.textMedium,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, WeakSpotEntry ws, String state) {
    final canResume =
        state == 'active' && ws.capsuleId != null && authToken != null && userId != null;

    return Container(
      margin: EdgeInsets.only(bottom: PlatformSizing.spacing(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: EdgeInsets.all(PlatformSizing.spacing(14)),
        child: Row(
          children: [
            Container(
              width: PlatformSizing.spacing(8),
              height: PlatformSizing.spacing(8),
              decoration: BoxDecoration(
                color: _groupColor(state),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: PlatformSizing.spacing(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ws.nodeTitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      fontSize: PlatformSizing.fontSize(14),
                    ),
                  ),
                  SizedBox(height: PlatformSizing.spacing(2)),
                  Row(
                    children: [
                      if (_chapterLabel(ws.chapterKey).isNotEmpty)
                        Text(
                          _chapterLabel(ws.chapterKey),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMedium,
                            fontSize: PlatformSizing.fontSize(12),
                          ),
                        ),
                      if (_chapterLabel(ws.chapterKey).isNotEmpty)
                        Text(
                          ' · ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textLight,
                            fontSize: PlatformSizing.fontSize(12),
                          ),
                        ),
                      Text(
                        _severityLabel(ws.severityLevel),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _severityColor(ws.severityLevel),
                          fontSize: PlatformSizing.fontSize(12),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canResume)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CapsuleScreen(
                      capsuleId: ws.capsuleId!,
                      nodeId: ws.nodeId,
                      nodeTitle: ws.nodeTitle,
                      authToken: authToken!,
                      userId: userId!,
                    ),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primaryPurple,
                  padding: EdgeInsets.symmetric(
                    horizontal: PlatformSizing.spacing(16),
                    vertical: PlatformSizing.spacing(10),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PlatformSizing.radius(20)),
                  ),
                  minimumSize: Size(PlatformSizing.spacing(64), PlatformSizing.spacing(36)),
                ),
                child: Text(
                  'Learn',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryPurple,
                    fontSize: PlatformSizing.fontSize(13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'high':
        return 'High Severity';
      case 'medium':
        return 'Medium Severity';
      case 'low':
      default:
        return 'Low Severity';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return AppColors.errorRed;
      case 'medium':
        return const Color(0xFFF59E0B); // amber/orange
      case 'low':
      default:
        return AppColors.successGreen;
    }
  }

  String _chapterLabel(String? chapterKey) {
    if (chapterKey == null) return '';
    // physics_electrostatics → Electrostatics
    final parts = chapterKey.split('_');
    if (parts.length > 1) {
      return parts.sublist(1).map(_capitalise).join(' ');
    }
    return _capitalise(chapterKey);
  }

  String _capitalise(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
