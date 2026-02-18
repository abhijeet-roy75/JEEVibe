/// Capsule Screen
/// Displays the 90-second lesson for a weak spot node.
/// Renders coreMisconception ("The Problem"), structuralRule ("The Fix"),
/// illustrativeExample ("Example") using LaTeX-aware rendering.
/// On scroll-to-bottom, marks capsule as completed via events API.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:jeevibe_mobile/theme/app_platform_sizing.dart';
import '../widgets/latex_widget.dart';
import '../widgets/buttons/gradient_button.dart';
import 'weak_spot_retrieval_screen.dart';

class CapsuleScreen extends StatefulWidget {
  final String capsuleId;
  final String nodeId;
  final String nodeTitle;
  final String authToken;
  final String userId;

  const CapsuleScreen({
    super.key,
    required this.capsuleId,
    required this.nodeId,
    required this.nodeTitle,
    required this.authToken,
    required this.userId,
  });

  @override
  State<CapsuleScreen> createState() => _CapsuleScreenState();
}

class _CapsuleScreenState extends State<CapsuleScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _capsule;
  List<dynamic> _retrievalQuestions = [];
  bool _isDisposed = false;
  bool _completedLogged = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCapsule();
    _scrollController.addListener(_onScroll);

    // Log capsule_opened event
    _logEvent('capsule_opened');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_completedLogged) return;
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    // Consider "read" when within 100px of bottom
    if (current >= maxScroll - 100) {
      _completedLogged = true;
      _logEvent('capsule_completed');
    }
  }

  Future<void> _loadCapsule() async {
    try {
      final apiService = ApiService();
      final result = await apiService.getCapsule(widget.capsuleId, widget.authToken);
      if (!_isDisposed && mounted) {
        setState(() {
          _capsule = result['capsule'] as Map<String, dynamic>?;
          _retrievalQuestions = result['retrievalQuestions'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _logEvent(String eventType) {
    try {
      ApiService().logWeakSpotEvent(
        userId: widget.userId,
        nodeId: widget.nodeId,
        eventType: eventType,
        capsuleId: widget.capsuleId,
        authToken: widget.authToken,
      );
    } catch (_) {
      // Non-fatal
    }
  }

  void _skipForNow() {
    Navigator.of(context).pop();
  }

  void _continueToValidation() {
    if (!_isDisposed && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WeakSpotRetrievalScreen(
            nodeId: widget.nodeId,
            nodeTitle: widget.nodeTitle,
            capsuleId: widget.capsuleId,
            questions: _retrievalQuestions,
            authToken: widget.authToken,
            userId: widget.userId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 20, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fix This Weak Spot',
                      style: AppTextStyles.headerWhite.copyWith(
                        fontSize: PlatformSizing.fontSize(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: PlatformSizing.iconSize(14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '90s read',
                          style: AppTextStyles.bodyWhite.copyWith(
                            fontSize: PlatformSizing.fontSize(12),
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.errorRed, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load capsule',
              style: AppTextStyles.headerMedium.copyWith(color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadCapsule();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final capsule = _capsule;
    if (capsule == null) return const SizedBox.shrink();

    final coreMisconception = capsule['coreMisconception']?.toString() ?? '';
    final structuralRule = capsule['structuralRule']?.toString() ?? '';
    final illustrativeExample = capsule['illustrativeExample']?.toString() ?? '';

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node title chip
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: PlatformSizing.spacing(12),
              vertical: PlatformSizing.spacing(6),
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(PlatformSizing.radius(20)),
            ),
            child: Text(
              widget.nodeTitle,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: PlatformSizing.fontSize(13),
              ),
            ),
          ),
          SizedBox(height: PlatformSizing.spacing(20)),

          // The Problem
          if (coreMisconception.isNotEmpty) ...[
            _buildSectionHeader('The Problem', Icons.warning_amber_rounded, AppColors.errorRed),
            SizedBox(height: PlatformSizing.spacing(10)),
            _buildSectionCard(coreMisconception, AppColors.errorRed.withValues(alpha: 0.05)),
            SizedBox(height: PlatformSizing.spacing(20)),
          ],

          // The Fix
          if (structuralRule.isNotEmpty) ...[
            _buildSectionHeader('The Fix', Icons.check_circle_outline, AppColors.successGreen),
            SizedBox(height: PlatformSizing.spacing(10)),
            _buildSectionCard(structuralRule, AppColors.successGreen.withValues(alpha: 0.05)),
            SizedBox(height: PlatformSizing.spacing(20)),
          ],

          // Example
          if (illustrativeExample.isNotEmpty) ...[
            _buildSectionHeader('Example', Icons.science_outlined, AppColors.infoBlue),
            SizedBox(height: PlatformSizing.spacing(10)),
            _buildSectionCard(illustrativeExample, AppColors.infoBlue.withValues(alpha: 0.05)),
            SizedBox(height: PlatformSizing.spacing(24)),
          ],

          // Continue to Validation button
          GradientButton(
            text: 'Continue to Validation',
            onPressed: _retrievalQuestions.isEmpty ? null : _continueToValidation,
            size: GradientButtonSize.large,
          ),
          SizedBox(height: PlatformSizing.spacing(12)),

          // Skip for now
          Center(
            child: TextButton(
              onPressed: _skipForNow,
              child: Text(
                'Skip for Now',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMedium,
                  fontSize: PlatformSizing.fontSize(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: PlatformSizing.iconSize(18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: PlatformSizing.fontSize(16),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String content, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(PlatformSizing.spacing(16)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(PlatformSizing.radius(12)),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: LaTeXWidget(
        text: content,
        allowWrapping: true,
        textStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textDark,
          height: 1.6,
          fontSize: PlatformSizing.fontSize(14),
        ),
      ),
    );
  }
}
