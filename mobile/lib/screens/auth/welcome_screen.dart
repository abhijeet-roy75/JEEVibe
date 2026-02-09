import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'phone_entry_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_platform_sizing.dart';
import '../../widgets/buttons/gradient_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Removed auto-navigation - user must click button to continue

  void _navigateToPhoneEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PhoneEntryScreen(),
      ),
    );
  }

  Future<void> _openTerms() async {
    final url = Uri.parse('https://jeevibe.web.app/terms');
    // Try external browser first, fall back to in-app if not available
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Column(
        children: [
            // Gradient Header Section - Full Width (reduced from flex: 2)
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppColors.ctaGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo in circle (matching profile pages style, larger for welcome screen)
                        Container(
                          width: PlatformSizing.iconSize(100), // 100→88px Android
                          height: PlatformSizing.iconSize(100), // 100→88px Android
                          margin: EdgeInsets.only(bottom: PlatformSizing.spacing(20)), // 20→16px Android
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: EdgeInsets.all(PlatformSizing.spacing(12)), // 12→9.6px Android
                              child: Image.asset(
                                'assets/images/JEEVibeLogo_240.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.ctaGradient,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'JV',
                                        style: AppTextStyles.headerLarge.copyWith(
                                          fontSize: PlatformSizing.fontSize(36), // 36→31.68px Android
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Welcome to JEEVibe',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headerLarge.copyWith(
                            fontSize: PlatformSizing.fontSize(28), // 28→24.64px Android
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'Your AI-powered path to JEE success',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // White Content Section
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: PlatformSizing.spacing(32), // 32→25.6px Android
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Abstract Graphic - Wavy line with dots
                    SizedBox(
                      height: PlatformSizing.spacing(120), // 120→96px Android
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          // Calculate positions as percentages of width
                          final dot1X = width * 0.15; // 15% from left
                          final dot2X = width * 0.50; // 50% (center)
                          final dot3X = width * 0.85; // 85% from left
                          
                          return CustomPaint(
                            painter: _WavePainter(
                              dot1X: dot1X,
                              dot2X: dot2X,
                              dot3X: dot3X,
                            ),
                            child: Stack(
                              children: [
                                // Purple dots - showing upward trajectory
                                // First dot - lowest position
                                Positioned(
                                  left: dot1X - PlatformSizing.spacing(6), // Center the dot
                                  top: PlatformSizing.spacing(100) - PlatformSizing.spacing(6), // At bottom
                                  child: Container(
                                    width: PlatformSizing.spacing(12), // 12→9.6px Android
                                    height: PlatformSizing.spacing(12), // 12→9.6px Android
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                // Second dot - middle position
                                Positioned(
                                  left: dot2X - PlatformSizing.spacing(6), // Center the dot
                                  top: PlatformSizing.spacing(20) - PlatformSizing.spacing(6), // Middle height
                                  child: Container(
                                    width: PlatformSizing.spacing(12), // 12→9.6px Android
                                    height: PlatformSizing.spacing(12), // 12→9.6px Android
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                // Third dot - highest position (with padding to avoid header cutoff)
                                Positioned(
                                  left: dot3X - PlatformSizing.spacing(6), // Center the dot
                                  top: PlatformSizing.spacing(15) - PlatformSizing.spacing(6), // Slightly below top
                                  child: Container(
                                    width: PlatformSizing.spacing(12), // 12→9.6px Android
                                    height: PlatformSizing.spacing(12), // 12→9.6px Android
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: PlatformSizing.spacing(32)), // 32→25.6px Android
                    // Feature List
                    _FeatureItem(
                      icon: Icons.auto_stories,
                      iconColor: Colors.blue,
                      title: 'Personalized Practice',
                    ),
                    SizedBox(height: AppSpacing.xl),
                    _FeatureItem(
                      icon: Icons.check_circle_outline,
                      iconColor: Colors.green,
                      title: 'Track Your Progress',
                    ),
                    SizedBox(height: AppSpacing.xl),
                    _FeatureItem(
                      icon: Icons.bolt,
                      iconColor: Colors.orange,
                      title: 'Achieve Your Goals',
                    ),
                    SizedBox(height: PlatformSizing.spacing(48)), // 48→38.4px Android
                    // Continue Button
                    GradientButton(
                      text: 'Continue with Phone Number',
                      onPressed: _navigateToPhoneEntry,
                      size: GradientButtonSize.large,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    // Legal text
                    Text(
                      'By continuing, you agree to our',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: _openTerms,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Terms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryPurple,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    // Bottom safe area padding to prevent Android nav bar covering content
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}

// Custom painter for the wavy line graphic
class _WavePainter extends CustomPainter {
  final double dot1X;
  final double dot2X;
  final double dot3X;

  _WavePainter({
    required this.dot1X,
    required this.dot2X,
    required this.dot3X,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Define dot positions - x positions are passed in, y positions are relative to height
    final dot1Y = size.height - 20.0; // At bottom (100% down, with some padding)
    final dot2Y = size.height * 0.20; // 20% from top
    final dot3Y = 15.0; // Slightly below top (y=15) to avoid header cutoff

    final paint = Paint()
      ..color = AppColors.primaryPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Start at first dot (lowest - at bottom)
    path.moveTo(dot1X, dot1Y);
    
    // Create a smooth, curved path through all three points
    // Use cubic bezier with control points positioned to create a smooth upward trajectory
    // Control point 1: positioned to create a curved path from first to second point
    final control1X = dot1X + (dot2X - dot1X) * 0.5; // 50% along the way horizontally
    final control1Y = dot1Y - (dot1Y - dot2Y) * 0.7; // Pull up more aggressively (70% of the way) for pronounced curve
    
    // Control point 2: positioned to create smooth curve from second to third point
    final control2X = dot2X + (dot3X - dot2X) * 0.5; // 50% along the way horizontally
    final control2Y = dot2Y - (dot2Y - dot3Y) * 0.6; // Continue upward curve (60% of the way)
    
    // Cubic bezier for smooth, curved path through all three points
    path.cubicTo(
      control1X, control1Y, // First control point
      control2X, control2Y, // Second control point
      dot3X, dot3Y, // End point (highest dot)
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.dot1X != dot1X || 
           oldDelegate.dot2X != dot2X || 
           oldDelegate.dot3X != dot3X;
  }
}

// Feature item widget
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppButtonSizes.iconButtonLg,
          height: AppButtonSizes.iconButtonLg,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: AppRadius.borderRadiusMd,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: AppIconSizes.lg,
          ),
        ),
        AppSpacing.gapHorizontalLg,
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
