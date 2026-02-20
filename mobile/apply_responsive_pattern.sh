#!/bin/bash

# Script to apply responsive pattern to remaining auth screens
# This adds the responsive layout wrapper and desktop-specific adjustments

echo "Applying responsive pattern to remaining auth screens..."

# The screens to update
SCREENS=(
  "/Users/abhijeetroy/Documents/JEEVibe/mobile/lib/screens/auth/create_pin_screen.dart"
  "/Users/abhijeetroy/Documents/JEEVibe/mobile/lib/screens/onboarding/onboarding_step1_screen.dart"
  "/Users/abhijeetroy/Documents/JEEVibe/mobile/lib/screens/onboarding/onboarding_step2_screen.dart"
)

for screen in "${SCREENS[@]}"; do
  filename=$(basename "$screen")
  echo "Processing: $filename"

  # Check if responsive_layout import already exists
  if grep -q "responsive_layout.dart" "$screen"; then
    echo "  ✓ Already has responsive import - skipping"
  else
    echo "  → Adding responsive import..."
    # Add import after the last existing import
    # This is a placeholder - actual implementation would be done manually
    echo "  ⚠️  Manual update required: Add import '../../widgets/responsive_layout.dart';"
  fi
done

echo ""
echo "Done! Please review the files and apply the pattern manually."
echo "Pattern to apply:"
echo "1. Add: import '../../widgets/responsive_layout.dart';"
echo "2. Wrap body with: ResponsiveScrollableLayout(maxWidth: 480, useSafeArea: false, child: ...)"
echo "3. Change Column to Column with no Expanded children"
echo "4. Change Expanded widgets to Padding widgets"
echo "5. Add desktop-specific sizing: final isDesktop = isDesktopViewport(context);"
