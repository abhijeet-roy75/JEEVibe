/// JEEVibe Widget Library
/// Barrel file for easy importing of all reusable widgets
///
/// Usage:
/// ```dart
/// import 'package:jeevibe_mobile/widgets/widgets.dart';
/// ```
///
/// This gives you access to:
///
/// Buttons:
/// - GradientButton (primary CTA button)
/// - OutlinedButton (secondary button)
/// - AppTextButton (text-only button)
/// - AppIconButton (icon button with variants)
/// - AppFloatingButton (FAB)
///
/// Cards:
/// - AppCard (standard card with variants)
/// - PriyaCard (gradient card for tips)
/// - SectionCard (card with header)
///
/// Inputs:
/// - FormTextField (text input with variants)
///
/// Dialogs:
/// - AppDialog (modal dialogs)
/// - AppBottomSheet (bottom sheet dialogs)
///
/// Feedback:
/// - LoadingOverlay (loading state overlay)
/// - LoadingIndicator (simple loading indicator)
/// - LoadingScreen (full screen loading)
/// - LoadingDots (animated dots)
/// - ShimmerLoading (shimmer placeholder)
/// - SkeletonList (skeleton loading for lists)
/// - SkeletonCard (skeleton loading card)
/// - EmptyState (empty state display)
/// - ErrorState (error state display)
///
/// Existing Widgets:
/// - AppHeader
/// - PriyaAvatar
/// - LatexWidget
/// - ChemistryText
/// - SubjectIconWidget
/// - SafeSvgWidget

library widgets;

// Buttons
export 'buttons/gradient_button.dart';
export 'buttons/icon_button.dart';

// Cards
export 'cards/app_card.dart';

// Inputs
export 'inputs/form_text_field.dart';

// Dialogs
export 'dialogs/app_dialog.dart';

// Feedback
export 'feedback/loading_overlay.dart';

// Existing widgets
export 'app_header.dart';
export 'priya_avatar.dart';
export 'latex_widget.dart';
export 'chemistry_text.dart';
export 'subject_icon_widget.dart';
export 'safe_svg_widget.dart';
