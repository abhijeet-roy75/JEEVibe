// Feedback Form Screen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/buttons/icon_button.dart';
import '../../widgets/app_header.dart';
import '../../services/feedback_service.dart';
import '../../services/firebase/auth_service.dart';

/// Maximum length for feedback description
const int _maxDescriptionLength = 1000;

/// Sanitize user input to prevent injection attacks
/// Removes potentially dangerous characters and patterns
String _sanitizeInput(String input) {
  if (input.isEmpty) return input;

  String sanitized = input;

  // Remove any HTML/script tags
  sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');

  // Remove common SQL injection patterns
  sanitized = sanitized.replaceAll(RegExp(r'''['";]--'''), '');
  sanitized = sanitized.replaceAll(RegExp(r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE)\b)', caseSensitive: false), '');

  // Remove null bytes and other control characters (except newlines)
  sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

  // Trim excessive whitespace
  sanitized = sanitized.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  sanitized = sanitized.replaceAll(RegExp(r' {3,}'), '  ');

  // Limit length
  if (sanitized.length > _maxDescriptionLength) {
    sanitized = sanitized.substring(0, _maxDescriptionLength);
  }

  return sanitized.trim();
}

class FeedbackFormScreen extends StatefulWidget {
  final String currentScreen;

  const FeedbackFormScreen({
    super.key,
    required this.currentScreen,
  });

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  int _selectedRating = 0;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Description is optional - no validation required

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final authToken = await authService.getIdToken();

      if (authToken == null) {
        throw Exception('Authentication required');
      }

      // Get recent activity (last 3 actions) - simplified for now
      // In a real implementation, you'd track user actions
      final recentActivity = <Map<String, dynamic>>[];

      await FeedbackService.submitFeedback(
        authToken: authToken,
        rating: _selectedRating,
        description: _sanitizeInput(_descriptionController.text),
        currentScreen: widget.currentScreen,
        recentActivity: recentActivity,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate back
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Standard gradient header
          AppHeader(
            leading: AppIconButton.back(
              onPressed: () => Navigator.pop(context),
              forGradientHeader: true,
            ),
            title: Text(
              'Share Feedback',
              style: AppTextStyles.headerWhite.copyWith(fontSize: 20),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Help us improve JEEVibe',
                style: AppTextStyles.bodyWhite.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            bottomPadding: 16,
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating Section
                  Text(
                    'How would you rate your experience?',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final rating = index + 1;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRating = rating;
                          });
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _selectedRating >= rating
                                ? AppColors.primary
                                : AppColors.borderLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.star,
                            color: _selectedRating >= rating
                                ? Colors.white
                                : AppColors.textTertiary,
                            size: 28,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  // Description Section
                  Text(
                    'Tell us more (optional)',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 6,
                    maxLength: _maxDescriptionLength,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]')),
                    ],
                    decoration: InputDecoration(
                      hintText: 'What did you like? What can we improve?',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderDefault),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderDefault),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Info text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardLightPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your feedback is automatically sent with context about your device and app version to help us debug issues faster.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Submit Button
                  GradientButton(
                    text: _isSubmitting ? 'Submitting...' : 'Submit Feedback',
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    size: GradientButtonSize.large,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
