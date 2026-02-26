/// Main Navigation Screen
/// Bottom navigation shell containing Home, History, Analytics, and Profile tabs
/// Desktop: Left sidebar navigation (NavigationRail)
/// Mobile: Bottom navigation bar

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_platform_sizing.dart';
import '../widgets/responsive_layout.dart';
import 'home_screen.dart';
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
        return const HomeScreen(isInBottomNav: true);
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
    // PERFORMANCE: Profile already loaded in AppInitializer - no need to reload
    // Profile will auto-refresh if user navigates to profile screen
  }

  void _onTabSelected(int index) {
    // Always refresh Home tab when tapped, even if already on it
    if (index == 0) {
      // Small delay to ensure widget is built
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          HomeScreen.refreshIfNeeded(context);
        }
      });
    }

    // Note: Analytics tab uses AutomaticKeepAliveClientMixin
    // State is kept alive automatically, no manual refresh needed

    // Only change tabs if switching to a different one
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
    final isDesktop = isDesktopViewport(context);

    return Scaffold(
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  /// Desktop layout with left sidebar navigation
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left sidebar navigation
        NavigationRail(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: AppColors.surface,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            child: Image.asset(
              'assets/images/JEEVibeLogo_240.png',
              width: 48,
              height: 48,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.ctaGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'JV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          destinations: [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined, color: _tabColors[0]),
              selectedIcon: Icon(Icons.home_rounded, color: _tabColors[0]),
              label: const Text('Home'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.history_outlined, color: _tabColors[1]),
              selectedIcon: Icon(Icons.history_rounded, color: _tabColors[1]),
              label: const Text('History'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.insights_outlined, color: _tabColors[2]),
              selectedIcon: Icon(Icons.insights_rounded, color: _tabColors[2]),
              label: const Text('Analytics'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person_outline_rounded, color: _tabColors[3]),
              selectedIcon: Icon(Icons.person_rounded, color: _tabColors[3]),
              label: const Text('Profile'),
            ),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        // Main content area - constrained to max width
        Expanded(
          child: IndexedStack(
            index: _currentIndex,
            children: List.generate(4, (index) {
              if (_visitedTabs.contains(index)) {
                return _buildScreen(index);
              }
              return const SizedBox.shrink();
            }),
          ),
        ),
      ],
    );
  }

  /// Mobile layout with bottom navigation bar
  Widget _buildMobileLayout() {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(4, (index) {
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
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,  // 12px iOS, 9.6px Android
            vertical: AppSpacing.sm,    // 8px iOS, 6.4px Android
          ),
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
      borderRadius: BorderRadius.circular(PlatformSizing.radius(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? AppSpacing.lg : AppSpacing.md,  // 16/12px iOS, 12.8/9.6px Android
          vertical: AppSpacing.sm,  // 8px iOS, 6.4px Android
        ),
        decoration: BoxDecoration(
          color: isSelected ? tabBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(PlatformSizing.radius(20)),  // 20px iOS, 16px Android
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? tabColor : AppColors.textSecondary,
              size: PlatformSizing.iconSize(22),  // 22px iOS, 19.36px Android
            ),
            // Show label only when selected
            if (isSelected) ...[
              SizedBox(width: AppSpacing.sm),  // 8px iOS, 6.4px Android
              Text(
                label,
                style: TextStyle(
                  color: tabColor,
                  fontSize: PlatformSizing.fontSize(13),  // 13px iOS, 11.44px Android
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
