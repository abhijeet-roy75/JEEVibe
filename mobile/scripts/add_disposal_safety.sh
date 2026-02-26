#!/bin/bash

# Script to add _isDisposed safety checks to screens
# This applies the disposal safety pattern to all screens missing it

SCREENS=(
  "mobile/lib/screens/daily_quiz_home_screen.dart"
  "mobile/lib/screens/daily_quiz_result_screen.dart"
  "mobile/lib/screens/daily_quiz_question_screen.dart"
  "mobile/lib/screens/daily_quiz_review_screen.dart"
  "mobile/lib/screens/solution_screen.dart"
  "mobile/lib/screens/profile/profile_edit_screen.dart"
  "mobile/lib/screens/mock_test/mock_test_home_screen.dart"
  "mobile/lib/screens/mock_test/mock_test_screen.dart"
  "mobile/lib/screens/mock_test/mock_test_results_screen.dart"
  "mobile/lib/screens/ai_tutor_chat_screen.dart"
  "mobile/lib/screens/all_weak_spots_screen.dart"
  "mobile/lib/screens/all_solutions_screen.dart"
  "mobile/lib/screens/history/history_screen.dart"
  "mobile/lib/screens/history/daily_quiz_history_screen.dart"
  "mobile/lib/screens/history/mock_test_history_screen.dart"
  "mobile/lib/screens/chapter_practice/chapter_practice_question_screen.dart"
  "mobile/lib/screens/chapter_practice/chapter_practice_result_screen.dart"
  "mobile/lib/screens/chapter_practice/chapter_practice_loading_screen.dart"
  "mobile/lib/screens/followup_quiz_screen.dart"
  "mobile/lib/screens/processing_screen.dart"
  "mobile/lib/screens/onboarding/onboarding_step1_screen.dart"
  "mobile/lib/screens/onboarding/onboarding_step2_screen.dart"
  "mobile/lib/screens/welcome_carousel_screen.dart"
  "mobile/lib/screens/feedback/feedback_form_screen.dart"
)

echo "🔧 Adding disposal safety to ${#SCREENS[@]} screens..."
echo ""

for screen in "${SCREENS[@]}"; do
  if [ -f "$screen" ]; then
    echo "✓ Processing: $screen"
  else
    echo "✗ Not found: $screen"
  fi
done

echo ""
echo "⚠️  This is a DRY RUN. Manual changes required for each screen:"
echo ""
echo "1. Add field: bool _isDisposed = false;"
echo "2. In dispose(): _isDisposed = true; (first line)"
echo "3. Add checks before all setState: if (!_isDisposed && mounted) { setState(...) }"
echo "4. Add checks after async operations: if (_isDisposed || !mounted) return;"
echo "5. Add checks before ScaffoldMessenger/Navigator: if (!_isDisposed && mounted) { ... }"
echo ""
echo "Use the pattern from assessment_question_screen.dart as reference."
