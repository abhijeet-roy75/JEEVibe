/// Feedback Floating Action Button with tooltip
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../services/session_tracking_service.dart';
import '../../screens/feedback/feedback_form_screen.dart';

class FeedbackFAB extends StatefulWidget {
  final String currentScreen;

  const FeedbackFAB({
    super.key,
    required this.currentScreen,
  });

  @override
  State<FeedbackFAB> createState() => _FeedbackFABState();
}

class _FeedbackFABState extends State<FeedbackFAB> {
  final SessionTrackingService _sessionService = SessionTrackingService();
  bool _showTooltip = false;
  bool _tooltipDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkTooltipVisibility();
  }

  Future<void> _checkTooltipVisibility() async {
    final shouldShow = await _sessionService.shouldShowTooltip();
    if (mounted && shouldShow && !_tooltipDismissed) {
      setState(() {
        _showTooltip = true;
      });
      
      // Auto-dismiss after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showTooltip = false;
          });
          _sessionService.markTooltipSeen();
        }
      });
    }
  }

  void _dismissTooltip() {
    setState(() {
      _showTooltip = false;
      _tooltipDismissed = true;
    });
    _sessionService.markTooltipSeen();
  }

  void _openFeedbackForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackFormScreen(
          currentScreen: widget.currentScreen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // FAB
        FloatingActionButton(
          onPressed: _openFeedbackForm,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.feedback),
        ),
        
        // Tooltip (only for first 3 sessions)
        if (_showTooltip)
          Positioned(
            right: 70,
            bottom: 0,
            child: GestureDetector(
              onTap: _dismissTooltip,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Share Feedback',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _dismissTooltip,
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
