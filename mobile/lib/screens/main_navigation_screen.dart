/// Main Navigation Screen
/// Bottom navigation shell containing Home, History, Analytics, and Profile tabs

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import 'assessment_intro_screen.dart';
import 'history/history_screen.dart';
import 'analytics_screen.dart';
import 'profile/profile_view_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  // Track which tabs have been visited (for lazy loading)
  late Set<int> _visitedTabs;

  // Screen builders for lazy loading - only called when tab is first visited
  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const AssessmentIntroScreen(isInBottomNav: true);
      case 1:
        return const HistoryScreen();
      case 2:
        return const AnalyticsScreen(isInBottomNav: true);
      case 3:
        return const ProfileViewScreen(isInBottomNav: true);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    // Only mark the initial tab as visited
    _visitedTabs = {_currentIndex};
    // Load user profile into centralized provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProfileProvider>().loadProfile();
    });
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        // Mark tab as visited when first selected
        _visitedTabs.add(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(4, (index) {
          // Only build visited tabs, use placeholder for unvisited
          if (_visitedTabs.contains(index)) {
            return _buildScreen(index);
          }
          return const SizedBox.shrink();
        }),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // Tab colors for colorful navigation
  static const List<Color> _tabColors = [
    AppColors.primary,           // Home - Purple
    Color(0xFFFF9800),           // History - Orange
    Color(0xFF2196F3),           // Analytics - Blue
    AppColors.secondary,         // Profile - Pink
  ];

  // Light background colors for selected state
  static const List<Color> _tabBackgroundColors = [
    AppColors.cardLightPurple,   // Home
    Color(0xFFFFF3E0),           // History - Light Orange
    Color(0xFFE3F2FD),           // Analytics - Light Blue
    AppColors.cardLightPink,     // Profile
  ];

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.history_outlined,
                activeIcon: Icons.history_rounded,
                label: 'History',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.insights_outlined,
                activeIcon: Icons.insights_rounded,
                label: 'Analytics',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final tabColor = _tabColors[index];
    final tabBgColor = _tabBackgroundColors[index];

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? tabBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? tabColor : AppColors.textSecondary,
              size: 22,
            ),
            // Show label only when selected
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: tabColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
