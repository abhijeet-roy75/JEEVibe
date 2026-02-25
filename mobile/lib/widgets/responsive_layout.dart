import 'package:flutter/material.dart';

/// Responsive layout wrapper for web/desktop
///
/// Provides consistent responsive behavior across all screens:
/// - Constrains content width on desktop (>1200px)
/// - Centers content horizontally
/// - Maintains full width on mobile/tablet
/// - Handles safe area
///
/// Usage:
/// ```dart
/// Scaffold(
///   body: ResponsiveLayout(
///     maxWidth: 480, // Optional, defaults to 480
///     child: YourContent(),
///   ),
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool useSafeArea;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth = 480, // Default mobile app width
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1200;

        Widget content = Center(
          child: Container(
            constraints: isDesktop && maxWidth != null
                ? BoxConstraints(maxWidth: maxWidth!)
                : null,
            child: child,
          ),
        );

        if (useSafeArea) {
          content = SafeArea(child: content);
        }

        return content;
      },
    );
  }
}

/// Responsive scrollable layout wrapper
///
/// Same as ResponsiveLayout but wraps content in SingleChildScrollView
/// for full-page scrolling. Use this for screens with non-scrollable content
/// that should scroll as a whole page.
///
/// Usage:
/// ```dart
/// Scaffold(
///   body: ResponsiveScrollableLayout(
///     maxWidth: 480,
///     child: Column(
///       children: [
///         Header(),
///         Content(),
///         Footer(),
///       ],
///     ),
///   ),
/// )
/// ```
class ResponsiveScrollableLayout extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool useSafeArea;
  final EdgeInsetsGeometry? padding;

  const ResponsiveScrollableLayout({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.useSafeArea = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1200;

        Widget content = Center(
          child: Container(
            constraints: isDesktop && maxWidth != null
                ? BoxConstraints(maxWidth: maxWidth!)
                : null,
            child: child,
          ),
        );

        if (useSafeArea) {
          content = SafeArea(child: content);
        }

        content = SingleChildScrollView(
          padding: padding,
          child: content,
        );

        return content;
      },
    );
  }
}

/// Utility to check if current viewport is desktop
///
/// Breakpoint set at 1200px to avoid tablet layout issues.
/// - Mobile: < 600px (phones)
/// - Tablet: 600px - 1200px (tablets in portrait/landscape)
/// - Desktop: > 1200px (laptops, desktops, large monitors)
bool isDesktopViewport(BuildContext context) {
  return MediaQuery.of(context).size.width > 1200;
}
