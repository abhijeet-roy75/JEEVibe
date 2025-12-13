import 'package:flutter/material.dart';
import 'phone_entry_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Column(
        children: [
            // Gradient Header Section - Full Width
            Expanded(
              flex: 2,
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
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
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
                                          fontSize: 36,
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
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            'Your AI-powered path to JEE success',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white.withOpacity(0.9),
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Abstract Graphic - Wavy line with dots
                    SizedBox(
                      height: 120,
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
                                  left: dot1X - 6, // Center the dot
                                  top: 100 - 6, // At bottom (y=100)
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                // Second dot - middle position
                                Positioned(
                                  left: dot2X - 6, // Center the dot
                                  top: 20 - 6, // Middle height (y=20)
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                // Third dot - highest position (with padding to avoid header cutoff)
                                Positioned(
                                  left: dot3X - 6, // Center the dot
                                  top: 15 - 6, // Slightly below top (y=15) to avoid header cutoff
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withOpacity(0.3),
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
                    const SizedBox(height: 32),
                    // Feature List
                    _FeatureItem(
                      icon: Icons.auto_stories,
                      iconColor: Colors.blue,
                      title: 'Personalized Practice',
                    ),
                    const SizedBox(height: 20),
                    _FeatureItem(
                      icon: Icons.check_circle_outline,
                      iconColor: Colors.green,
                      title: 'Track Your Progress',
                    ),
                    const SizedBox(height: 20),
                    _FeatureItem(
                      icon: Icons.bolt,
                      iconColor: Colors.orange,
                      title: 'Achieve Your Goals',
                    ),
                    const SizedBox(height: 48),
                    // Continue Button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppShadows.buttonShadow,
                        gradient: AppColors.ctaGradient,
                      ),
                      child: ElevatedButton(
                        onPressed: _navigateToPhoneEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Continue with Phone Number',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Legal text
                    Text(
                      'By continuing, you agree to our',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to terms and privacy
                      },
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
                    const SizedBox(height: 32),
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
