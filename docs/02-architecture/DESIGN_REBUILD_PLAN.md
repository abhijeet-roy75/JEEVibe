# Design Rebuild Plan - Pixel-Perfect Implementation

## Scope
Rebuild ALL screens to match the mockups in `/screens` folder exactly, following the design system in "Flutter Design Reference for JEEVibe Light-Theme.txt"

## Design System Components Created
✅ `mobile/lib/theme/app_colors.dart` - Complete color palette
✅ `mobile/lib/theme/app_text_styles.dart` - Typography system

## Screens to Rebuild (12 total)

### 1. Welcome Screens (2a, 2b, 2c) ⏳
**Mockups:** `2a Welcome Screen 1.png`, `2b Welcome Screen 2.png`, `2c Welcome Screen 3.png`

**Screen 2a - Snap Your Question:**
- Purple gradient background (#9333EA → #A855F7)
- Camera icon in white circle
- "JEEVibe" title
- "AI-Powered JEE Preparation" subtitle
- "Snap Your Question" main heading
- Description text
- "Quick Tips" section with checkmarks
- Progress dots (1 of 3)
- "Next" button (gradient)
- "Skip Introduction" link at bottom

**Screen 2b - AI Solves Instantly:**
- Pink gradient background (#EC4899 → #DB2777)
- Lightning/bolt icon in white circle
- "AI Solves Instantly" heading
- Description
- "Meet Priya Ma'am" card with avatar and message
- Progress dots (2 of 3)
- "Next" button
- "Skip Introduction" link

**Screen 2c - Practice & Master:**
- Amber/orange gradient (#F59E0B → #D97706)
- Lightning icon
- "Practice & Master" heading
- Description
- "What You Get (Free!)" section with checkmarks:
  - 5 Free Snaps Daily
  - Step-by-Step Solutions
  - Practice Questions
  - No Sign-Up Required
- Progress dots (3 of 3)
- "Next" button
- Bottom text: "No sign-up required • 5 free snaps daily"

### 2. Home Screen (3) ⏳
**Mockup:** `3 Home Screen.png`

**Layout:**
- Purple gradient header (#9333EA → #A855F7) with "Snap and Solve" title
- Overlapping white card (offset -32px):
  - Camera icon (purple tint)
  - "Snaps Today" with "Free daily limit"
  - Large "2/5" counter (purple)
  - Progress bar (purple fill, gray background)
  - "Resets in 8h 32m" • "3 remaining"
- Gradient CTA button: "Snap Your Question"
- "Recent Solutions" section with "View All" link:
  - Solution cards with icon, subject, time, question preview
  - Practice score chips (green)
  - Topic tags
- "Today's Progress" section:
  - 3 stats cards: Questions, Accuracy, Snaps Used
  - Icons with large numbers

### 3. Camera Screen (4) ⏳
**Mockup:** `4 Camera Interface Screen Redesigned.png`

**SIMPLIFIED DESIGN** (not live camera):
- Two large buttons:
  - "Capture" with camera icon
  - "Gallery" with gallery icon
- Snap counter visible
- Simple, clean interface

### 4. Photo Review Screen (6a) ⏳
**Mockup:** `6a Photo Review Screen.png`

**Layout:**
- Purple gradient header
- "Review Photo" title
- Checkmark icon
- "Looking Good!" message
- Subtitle: "Make sure the question is clear and readable"
- Dark tooltip: "Pinch to zoom, use tools below to adjust"
- Gray box showing "Question Text Area" with preview
- "Quality Check" card:
  - Blue checkmark icon
  - "Automatic analysis of your photo"
  - ✓ Text is readable - Good
  - ✓ Good lighting - Good
  - ✓ No blur detected - Good
- Priya Ma'am card: "Perfect! The question is clear..."
- Gradient "Use This Photo" button
- White "Retake Photo" button
- Small text: "You can always retake if the result isn't accurate"

### 5. OCR Failed Screen (6b) ⏳
**Mockup:** `6b OCR Recognition Failed.png`

**Layout:**
- Red gradient header (#DC2626 → #F87171)
- X close button
- "Recognition Failed" title
- Error icon (exclamation in circle)
- "Couldn't Read Question" heading
- "Let's try again with a clearer photo" subtitle
- "What Went Wrong?" white card:
  - Numbered list (red circles):
    1. Blurry or out of focus
    2. Poor lighting or shadows
    3. Question cut off or incomplete
    4. Handwriting too messy
- Priya Ma'am card: "Don't worry! This happens sometimes..."
- "Quick Tips for Next Try" list
- Gradient "Try Again with Camera" button
- White "Back to Dashboard" button

### 6. Processing Screen (8) ⏳
**Mockup:** `8 Processing and Loading.png`

**Layout:**
- Purple gradient header
- Sparkle icon
- "Hold Tight!" title
- "Priya Ma'am is working on your solution" subtitle
- Three dots loading animation
- White card with large "P" avatar (gradient circle)
- "Priya Ma'am is solving this..." heading
- Status box: "Thinking through the solution..." with spinner
- "This usually takes 5-10 seconds"
- Progress bar (100% shown)
- Checklist with checkmarks:
  - ✓ Reading your question...
  - ✓ Identifying the concept...
  - 3 Thinking through the solution... (active with dots)
  - 4 Writing step-by-step explanation... (gray)
- "Did you know?" info card
- Bottom gradient footer: "Almost there! Preparing your solution..."

### 7. Solution Screen (9) ⏳
**Mockup:** `9 Solution Screen.png`

**Layout:**
- Purple gradient header
- Checkmark icon
- "Question Recognized!"
- "Mechanics - Newton's Laws" subtitle
- Purple "HERE'S WHAT I SEE:" section with question text
- "JEE Main Level" badge
- "Report Issue" link
- "Step-by-Step Solution" section (expandable):
  - Numbered steps (1-4)
  - Each step expandable
- Green "FINAL ANSWER" box
- Pink Priya Ma'am card: "Pro tip: When dealing with friction..."
- "Practice Similar Questions" section:
  - Three colored boxes: Basic Q1, Intermediate Q2, Advanced Q3
  - Blue "Start Practice" button
- Gradient "Snap Another Question" button
- White "Back to Dashboard" button
- Bottom purple footer: "3/5 snaps remaining today"

### 8. Practice Questions (11) ⏳
**Mockup:** `11 Practice Questions.png`

**Layout:**
- Purple gradient header
- Back button
- "Practice Similar" with sparkle icon
- Timer badge: "90s"
- Progress circle: "1" in center
- "Question 1 of 3"
- "Basic Level" subtitle
- Overlapping white card:
  - Progress bar (3 segments, 1 filled pink)
  - "Question 1" • "Basic"
- Green chip: "Basic" • "Warming up with basics"
- Question card with purple "Q1" badge
- Question text
- 4 option cards (A, B, C, D) - white with borders
- Disabled "Submit Answer" button
- "Skip this question" link

### 9. Practice Results (13) ⏳
**Mockup:** `13 Practice Results Summary.png`

**Layout:**
- Purple gradient header
- Target icon
- "Good Effort!"
- "You completed all 3 practice questions"
- Three stat boxes:
  - 2/3 Questions Correct
  - 67% Accuracy (orange)
  - 4.5 Minutes
- "Topic Mastery" progress bar (72% with +15% indicator)
- Priya Ma'am card: "Great progress! You're solid on the basics..."
- "Question Breakdown" section:
  - Question 1: ✓ Basic Level, Your answer A, Review Solution link
  - Question 2: ✓ Intermediate, Your answer A
  - Question 3: ✗ Advanced, Your answer B → C (red), Review Solution
- White "Back to Dashboard" button
- Bottom gradient footer: "Keep going! You're getting there! 💪"

### 10. Review Questions (13b) ⏳
**Mockup:** `13b Review Questions screen.png`

**Layout:**
- Purple gradient header
- Back button
- "Question 2"
- "Time: 98s • From today's practice"
- "Intermediate" badge
- White background with sections:
  - "Question" section
  - Option A: Green background "Correct Answer" badge
  - Option B: Red background "Your Answer" badge
  - Options C, D: Gray
- Purple "Understanding the Concept" card:
  - Lightbulb icon
  - "What are Mitochondria?"
  - Detailed explanation text
  - "Primary Function" section
  - "Why Not the Other Options?" breakdown
  - Yellow "Key Takeaway" box
- Gradient "Next Question" button
- Purple outline "Back to Review List" button

### 11. Daily Limit Screen (14) ⏳
**Mockup:** `14 Daily Snaps Reached without PRO push.png`

**Layout:**
- Purple gradient header
- Checkmark icon
- "Amazing Work Today!"
- "You've completed all 5 snaps for today"
- White card:
  - Target icon "5/5 snaps completed"
  - "You've made excellent progress today!"
  - Stats grid:
    - Questions: 15
    - Accuracy: 80% (green background)
  - Yellow card: "Top Subject" - Physics
  - Green card: "Topics You Improved Today" with chips
- Blue card: Clock icon, "Your snaps reset in 8h 32m", "Tomorrow at 12:00 AM"
- Priya Ma'am card: "Fantastic dedication! You completed all 5 snaps..."
- Gradient "Back to Home" button
- Bottom gradient footer: "Day Complete! ⭐"

### 12. Home After 5 Snaps (15) ⏳
**Mockup:** `15 Home Screen - After all 5 Snaps.png`

**Layout:**
- Same as Home Screen #3 but:
  - 5/5 snaps counter (green fill)
  - "All complete! 🎉" message
  - "Snap Your Question" button DISABLED (gray with lock icon)
  - Green congratulations card at bottom:
    - Target icon
    - "Amazing Work Today!"
    - "You've completed all 5 snaps. Come back tomorrow for more learning!"

## Technical Requirements

### Colors
- Use `AppColors` class for all colors
- Exact hex values as specified
- Proper gradients

### Typography
- Use `AppTextStyles` class
- Inter font family (via Google Fonts)
- Exact font sizes and weights

### Spacing
- Use `AppSpacing` constants
- 24px screen padding
- Consistent gaps

### Components
- Rounded corners: 12-16px
- Shadows: elevation matching design
- Borders: exact colors

### Special Handling
- **Chemistry**: Unicode subscripts/superscripts (e.g., H₂O, CO₂)
- **Math**: LaTeX rendering (existing LaTeXWidget)

## Implementation Order
1. Welcome screens (2a, 2b, 2c)
2. Home screen (3)
3. Camera simplified (4)
4. Photo review (6a)
5. OCR failed (6b)
6. Processing (8)
7. Solution (9)
8. Practice questions (11)
9. Practice results (13)
10. Review questions (13b)
11. Daily limit (14)
12. Home after limit (15)

## Files to Completely Rebuild
- `mobile/lib/screens/welcome_screen.dart`
- `mobile/lib/screens/home_screen.dart`
- `mobile/lib/screens/camera_screen.dart`
- `mobile/lib/screens/photo_review_screen.dart`
- `mobile/lib/screens/ocr_failed_screen.dart`
- `mobile/lib/screens/processing_screen.dart` (new - extract from solution_screen)
- `mobile/lib/screens/solution_screen.dart`
- `mobile/lib/screens/followup_quiz_screen.dart`
- `mobile/lib/screens/practice_results_screen.dart`
- `mobile/lib/screens/review_questions_screen.dart`
- `mobile/lib/screens/daily_limit_screen.dart`

## Status
🔄 **READY TO START** - Awaiting confirmation to begin complete rebuild

