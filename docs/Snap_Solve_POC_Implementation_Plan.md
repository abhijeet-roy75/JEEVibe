# Snap & Solve POC - Implementation Plan

**Version:** 1.0  
**Date:** November 2025  
**Platform:** iOS (Flutter)  
**Purpose:** Proof of Concept for Snap & Solve feature validation

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [File Structure](#file-structure)
4. [UI/UX Design Principles](#uiux-design-principles)
5. [Implementation Phases](#implementation-phases)
6. [Key Technical Decisions](#key-technical-decisions)
7. [Success Criteria](#success-criteria)
8. [Out of Scope](#out-of-scope)
9. [Next Steps After POC](#next-steps-after-poc)

---

## Overview

Build a minimal iOS Flutter app that demonstrates the core Snap & Solve flow: capture question photo → OCR + solution → display solution + 3 interactive follow-up questions with mini-quiz. This validates the AI-powered question-solving use case and interactive quiz experience for the India market (low bandwidth, lightweight UI).

### Key Objectives
- Validate OpenAI Vision API for JEE question OCR
- Test Priya Ma'am persona in solution generation
- Validate interactive quiz experience
- Test on real iOS device via TestFlight
- Optimize for low bandwidth scenarios

---

## Architecture

### Frontend (Flutter - iOS)

**Framework:** Flutter 3.x with iOS support  
**State Management:** Provider (lightweight, sufficient for POC)  
**Target iOS:** iOS 12+ (for camera support)

**Key Packages:**
```yaml
dependencies:
  camera: ^0.10.x              # Camera functionality
  image_picker: ^1.0.x         # Gallery selection fallback
  http: ^1.1.x                 # API calls to backend
  flutter_math_fork: ^0.7.x    # LaTeX rendering in solutions
  image: ^4.1.x                # Basic image compression
  shared_preferences: ^2.2.x    # Local state (snap count, quiz progress)
  provider: ^6.1.x             # State management
  intl: ^0.19.x                 # Future multi-language support (structure only)
```

### Backend (Node.js)

**Framework:** Express.js  
**Runtime:** Node.js 18+

**Key Dependencies:**
```json
{
  "express": "^4.18.x",
  "multer": "^1.4.x",
  "openai": "^4.x",
  "cors": "^2.8.x",
  "dotenv": "^16.x"
}
```

### API Flow

1. Flutter app captures/selects image
2. Basic compression (<5MB, JPEG quality 85%, max 2048x2048)
3. POST to Node.js backend `/api/solve` with multipart/form-data
4. Backend receives image in memory (process and discard, no storage)
5. Backend calls OpenAI Vision API (gpt-4o) with:
   - Image (base64 encoded)
   - Detailed Priya Ma'am system prompt (from AI API Prompt Templates doc)
   - Request: Extract question, solve step-by-step, identify topic/difficulty
6. Backend generates 3 follow-up questions using OpenAI text API:
   - Uses `SNAP_SOLVE_FOLLOWUP_PROMPT` template (from doc)
   - Progressive difficulty: Q1 similar, Q2 twist, Q3 advanced
   - Each question includes: question text, 4 options, correct answer, explanation
7. Return JSON: `{ solution, topic, difficulty, followUpQuestions: [3] }`
8. Flutter displays solution with LaTeX rendering
9. User can tap "Start Practice" → Interactive mini-quiz (F6.3)
10. Mini-quiz: 3 questions, 90s timer each, immediate feedback, completion summary

---

## File Structure

```
JEEVibe/
├── mobile/                          # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── camera_screen.dart
│   │   │   ├── solution_screen.dart
│   │   │   └── followup_quiz_screen.dart
│   │   ├── services/
│   │   │   └── api_service.dart
│   │   ├── models/
│   │   │   ├── solution_model.dart
│   │   │   └── question_model.dart
│   │   ├── widgets/
│   │   │   ├── latex_widget.dart
│   │   │   └── loading_indicator.dart
│   │   └── utils/
│   │       ├── image_compressor.dart
│   │       └── localization.dart    # Structure for future Hindi support
│   ├── pubspec.yaml
│   └── ios/                         # iOS configuration
│       ├── Runner/
│       │   └── Info.plist           # Camera permissions
│       └── Runner.xcodeproj
│
├── backend/                          # Node.js server
│   ├── src/
│   │   ├── index.js                 # Express server
│   │   ├── routes/
│   │   │   └── solve.js             # /api/solve endpoint
│   │   ├── services/
│   │   │   └── openai.js            # OpenAI API wrapper
│   │   └── prompts/
│   │       ├── priya_maam_base.js   # BASE_PROMPT_TEMPLATE
│   │       ├── snap_solve.js        # SNAP_SOLVE_FOLLOWUP_PROMPT
│   │       └── templates.js         # Subject-specific templates (reference)
│   ├── package.json
│   └── .env                         # API keys (gitignored)
│
└── docs/
    ├── JEEVibe MVP - Business Requirements Document.txt
    ├── AI API Prompt Templates for Snap Solve 3-Question Generation.txt
    ├── F6_ Snap & Solve - Comprehensive Test Cases.txt
    ├── Image Compression Chinese Edtech Style.txt
    └── Snap_Solve_POC_Implementation_Plan.md (this file)
```

---

## UI/UX Design Principles (India Market)

### Lightweight & Professional (Robinhood-style)

- **Minimal assets:** No heavy images, use vector icons
- **Simple color palette:**
  - Primary: `#4A90E2` (Blue - Trust, Learning)
  - Success: `#50C878` (Green - Success, Growth)
  - Accent: `#FF6B6B` (Red - Alerts)
  - Background: `#F8F9FA` (Light Gray)
  - Text: `#212529` (Dark Gray)
- **Typography:** Poppins (Google Fonts) - clean, readable
  - Headings: Poppins SemiBold 20-24px
  - Body: Poppins Regular 14-16px
- **Sparse animations:** Only essential transitions (no heavy animations)
- **Progressive loading:** Show skeleton screens, not blank states
- **Offline indicators:** Clear "No internet" messages

### Low Bandwidth Optimizations

- **Lazy loading:** Load images only when needed
- **Compressed assets:** All icons as SVG or minimal PNG
- **Efficient API calls:** Single request for solution + follow-ups
- **Cache responses:** Store last solution locally (SharedPreferences)
- **Error messages:** Clear, actionable (not technical jargon)
- **Image compression:** Aggressive (target <2MB before upload)

### Multi-Language Structure (Future)

- **i18n setup:** Use `intl` package, structure for Hindi
- **String externalization:** All UI text in localization files
- **RTL support:** Structure for future Hindi RTL (not in POC)
- **POC:** English only, but code structured for easy translation

---

## Implementation Phases

### Phase 1: Backend Setup (Node.js)

**Duration:** 2-3 days

1. Initialize Node.js project with Express
2. Set up `/api/solve` endpoint accepting multipart/form-data
3. Configure multer memory storage (no disk writes)
4. Integrate OpenAI SDK
5. Implement Priya Ma'am base prompt (from templates doc):
   - Import `BASE_PROMPT_TEMPLATE` from templates
   - Configure system prompt with Priya Ma'am persona
6. Implement solution generation using Vision API:
   - System prompt: `BASE_PROMPT_TEMPLATE` with Priya Ma'am persona
   - Request: Extract question, solve step-by-step, identify topic
   - Parse response: solution text, topic, difficulty
7. Implement 3 follow-up questions using `SNAP_SOLVE_FOLLOWUP_PROMPT`:
   - Progressive difficulty (similar → harder → advanced)
   - Each question in standard JSON format (from templates)
   - Include: question text, 4 options, correct answer, explanation
8. Return structured JSON response
9. Add error handling:
   - Timeouts (30s for Vision API)
   - API errors (rate limits, invalid responses)
   - Invalid images (size, format validation)

**Deliverables:**
- Working Express server
- `/api/solve` endpoint
- OpenAI integration with Priya Ma'am prompts
- Error handling

---

### Phase 2: Flutter App Setup

**Duration:** 1 day

1. Initialize Flutter project with iOS support:
   ```bash
   flutter create --org com.jeevibe mobile
   cd mobile
   ```
2. Configure iOS permissions in `ios/Runner/Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>We need camera access to capture questions</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>We need photo library access to select questions</string>
   ```
3. Set up project structure:
   - Create `screens/`, `services/`, `models/`, `widgets/`, `utils/` directories
4. Add required dependencies to `pubspec.yaml`
5. Set up Provider for state management
6. Create basic app theme:
   - Lightweight, professional colors
   - Poppins font
   - Minimal styling

**Deliverables:**
- Flutter project structure
- Dependencies installed
- Basic theme configured

---

### Phase 3: Camera & Image Handling

**Duration:** 2-3 days

1. Implement camera screen:
   - Camera viewfinder with grid overlay
   - Capture button (large, accessible, bottom-center)
   - Gallery icon (bottom-left)
   - Flash toggle (top-right, if available)
   - Back button (top-left)
2. Add gallery selection option:
   - Use `image_picker` package
   - Handle permission requests
3. Implement basic image compression utility:
   - Target <5MB
   - JPEG quality 85%
   - Max dimensions 2048x2048
   - Remove EXIF data
   - Function: `compressImage(File image) -> File`
4. Preview screen:
   - Show captured/selected image
   - [Retake] button (left)
   - [Use This Photo] button (right, prominent)
   - Loading indicator during upload

**Deliverables:**
- Working camera screen
- Gallery selection
- Image compression utility
- Preview screen

---

### Phase 4: API Integration

**Duration:** 2 days

1. Create API service (`services/api_service.dart`):
   - Base URL configuration
   - Image upload function
   - Error handling
2. Image upload to `/api/solve` endpoint:
   - Multipart/form-data request
   - Include compressed image
   - Handle progress (if possible)
3. Handle loading states:
   - "Priya Ma'am is solving this..." message
   - Progress indicator (circular or linear)
   - Disable buttons during processing
4. Error handling:
   - Network failures: "No internet. Check connection and retry."
   - API timeouts: "Taking longer than usual. Retry?"
   - Invalid images: "Couldn't recognize question. Try retaking photo."
   - Server errors: "Something went wrong. Please try again."
5. Parse JSON response:
   - Solution model
   - Follow-up questions model
   - Error responses

**Deliverables:**
- API service implementation
- Image upload working
- Error handling
- Response parsing

---

### Phase 5: Solution Display Screen

**Duration:** 3-4 days

1. Solution screen UI (lightweight, clean):
   - Recognized question text (LaTeX rendered)
   - Step-by-step solution (expandable steps)
   - Final answer highlighted (boxed or bold)
   - Priya Ma'am's tip section
   - Topic and difficulty metadata
2. LaTeX rendering:
   - Use `flutter_math_fork` for math formulas
   - Test with:
     - Fractions: `\frac{a}{b}`
     - Integrals: `\int`, `\sum`
     - Greek letters: `\alpha`, `\beta`, `\theta`
     - Square roots: `\sqrt{x}`
     - Subscripts/superscripts: `x_1`, `x^2`
3. Display 3 follow-up questions:
   - Question cards (minimal design)
   - Show question text, 4 options (not selectable yet)
   - "Start Practice" button (prominent, green)
4. Styling:
   - Professional, Robinhood-inspired (clean, minimal)
   - Proper spacing and typography
   - Smooth scrolling

**Deliverables:**
- Solution display screen
- LaTeX rendering working
- Follow-up questions displayed
- Professional UI

---

### Phase 6: Interactive Follow-Up Quiz (F6.3)

**Duration:** 3-4 days

1. Mini-quiz screen:
   - Question 1/3, 2/3, 3/3 progress indicator (top)
   - Timer: 90 seconds countdown per question (top-right)
   - Question text with LaTeX rendering
   - 4 options (A, B, C, D) - large touch targets (56px height)
   - [Submit Answer] button (disabled until selection)
2. Immediate feedback after each question:
   - **Correct:**
     - Green checkmark + "Correct! Well done."
     - Brief explanation
     - Priya Ma'am encouragement: "Great job! You're getting this!"
   - **Incorrect:**
     - Red X + "Not quite. Correct answer: [X]"
     - Explanation shown
     - Priya Ma'am encouragement: "This is tricky—let's see why..."
3. Navigation:
   - [Next Question] button after feedback
   - Can exit mid-quiz (confirmation dialog: "Exit practice? Progress won't be saved.")
4. Completion summary:
   - Score: "You got 2/3 correct!"
   - Priya Ma'am feedback: "You're getting better at [Topic]! 🎉"
   - [Done] button → Return to solution screen

**Deliverables:**
- Interactive mini-quiz
- Timer functionality
- Immediate feedback
- Completion summary

---

### Phase 7: iOS Build & TestFlight Deployment

**Duration:** 1-2 days

1. Configure iOS build settings:
   - Set bundle identifier (e.g., `com.jeevibe.snapsolve`)
   - Configure signing with Apple Developer account:
     - Open `ios/Runner.xcworkspace` in Xcode
     - Select Runner target → Signing & Capabilities
     - Select your team
     - Enable "Automatically manage signing"
   - Set minimum iOS version (iOS 12+ for camera support)
   - Configure Info.plist permissions (already done in Phase 2)
   - Add app icons and launch screen (basic for POC)
2. Build iOS app:
   - Run `flutter build ios --release`
   - Open in Xcode: `open ios/Runner.xcworkspace`
   - Product → Archive
   - Validate build (no errors/warnings)
3. TestFlight setup:
   - Create app record in App Store Connect (if new app):
     - Go to App Store Connect → My Apps → +
     - Enter app name: "JEEVibe Snap & Solve"
     - Bundle ID: `com.jeevibe.snapsolve`
     - Platform: iOS
   - Upload build to App Store Connect:
     - In Xcode: Window → Organizer → Archives
     - Select archive → Distribute App
     - Choose "App Store Connect"
     - Follow prompts to upload
   - Configure TestFlight:
     - Go to App Store Connect → TestFlight tab
     - Add internal testers (yourself)
     - Add external testers (optional, for beta testing)
     - Set up test information and notes
   - Submit for TestFlight beta review (usually 24-48 hours)
4. Distribute via TestFlight:
   - Install TestFlight app on iPhone
   - Accept invitation and install JEEVibe app
   - Test on real device with camera functionality
   - Verify all features work on physical device

**Deliverables:**
- iOS build configured
- App uploaded to App Store Connect
- TestFlight set up
- App installable on real device

---

### Phase 8: Testing & Polish

**Duration:** 2-3 days

1. Test on real iOS device via TestFlight:
   - Camera functionality (capture, gallery selection)
   - Image compression and upload
   - Solution display and LaTeX rendering
   - Interactive mini-quiz flow
2. Test with real JEE question photos:
   - Printed questions (textbook, PDF screenshots)
   - Handwritten neat questions
   - Various subjects (Math, Physics, Chemistry)
3. Validate OCR accuracy:
   - Target: >80% accuracy on printed text
   - Test with 10-15 sample questions
   - Note any OCR failures
4. Test solution quality:
   - Correctness (verify with manual solutions)
   - Priya Ma'am voice (warm, encouraging tone)
   - Step-by-step clarity
5. Test follow-up question progression:
   - Q1: Similar difficulty, same concept
   - Q2: Slight twist, harder
   - Q3: Advanced, combines concepts
6. Test mini-quiz flow:
   - All 3 questions work
   - Timer counts down correctly
   - Feedback appears immediately
   - Completion summary shows correct score
7. Performance testing:
   - Low bandwidth scenarios (3G simulation in Xcode)
   - Memory usage on real device (Xcode Instruments)
   - Battery consumption (monitor during testing)
8. UI/UX refinements:
   - Loading states (skeleton screens)
   - Error messages (clear, actionable)
   - Offline handling (graceful degradation)
   - Real device optimizations (touch targets, spacing)

**Deliverables:**
- Tested on real device
- OCR accuracy validated
- Solution quality verified
- Performance optimized
- UI/UX polished

---

## Key Technical Decisions

### OpenAI API Usage

- **Vision Model:** `gpt-4o` (best vision capabilities, cost-effective)
- **Text Model:** `gpt-4o` for follow-up questions (consistent quality)
- **System Prompts:** Use detailed templates from AI API Prompt Templates doc:
  - `BASE_PROMPT_TEMPLATE` for Priya Ma'am persona
  - `SNAP_SOLVE_FOLLOWUP_PROMPT` for 3 questions
- **Response Format:** JSON mode (structured output)
- **Temperature:** 0.7 for variety while maintaining consistency
- **Max Tokens:** 2000 for solution, 1500 per follow-up question

### Image Handling

- **Compression:** Basic (JPEG quality 85%, max 2048x2048, <5MB)
- **Format:** JPEG (better compression than PNG)
- **Processing:** Client-side only (no server-side optimization for POC)
- **Storage:** None (process and discard for POC)
- **Validation:** Check size and format before upload

### Error Handling

- **Network failures:** Clear message + retry button
- **OCR failures:** "Couldn't recognize question. Try retaking with better lighting."
- **API timeouts:** 30s timeout, show "Taking longer..." message
- **Invalid images:** Validate before upload (size, format)
- **Non-question images:** Detect and show appropriate message
- **Rate limits:** Queue requests, show "Too many requests. Please wait."

### Performance (Low Bandwidth)

- **Image compression:** Aggressive (target <2MB before upload)
- **API calls:** Single request (solution + follow-ups together)
- **Caching:** Store last solution locally (SharedPreferences)
- **Loading states:** Skeleton screens, not blank
- **Progressive rendering:** Show solution as it arrives
- **Retry logic:** Exponential backoff for failed requests

---

## Success Criteria for POC

- ✅ Can capture/select question image
- ✅ Image compressed and sent to backend (<5MB)
- ✅ OpenAI correctly extracts question text (OCR >80% accuracy)
- ✅ Solution generated in Priya Ma'am's voice (warm, encouraging)
- ✅ Solution includes step-by-step breakdown with LaTeX
- ✅ 3 relevant follow-up questions generated (progressive difficulty)
- ✅ LaTeX formulas render correctly in solution and questions
- ✅ Interactive mini-quiz works (3 questions, timer, feedback)
- ✅ UI is lightweight and professional (Robinhood-style)
- ✅ Works on iOS device (not just simulator)
- ✅ Handles low bandwidth gracefully (clear errors, retry)
- ✅ App installable via TestFlight

---

## Out of Scope for POC

- ❌ User authentication
- ❌ Firebase integration
- ❌ Image storage (process and discard)
- ❌ Progress tracking
- ❌ Daily snap limits
- ❌ Bookmark/share features
- ❌ Full Chinese-style compression pipeline (basic only)
- ❌ Multi-language support (structure only, English for POC)
- ❌ Offline mode (requires internet)
- ❌ Android support (iOS only for POC)
- ❌ Parental consent flow
- ❌ Analytics tracking

---

## Next Steps After POC Validation

If POC succeeds:

1. **Add full image compression pipeline:**
   - ML Kit for smart cropping
   - Aggressive compression (Chinese-style)
   - Server-side optimization with Sharp

2. **Add Firebase for data persistence:**
   - Firestore for user data
   - Cloud Storage for images (with 30-day auto-delete)
   - Cloud Functions for backend logic

3. **Implement authentication (F1):**
   - Phone number + OTP
   - Optional PIN setup
   - Biometric authentication

4. **Add snap history tracking:**
   - Store snap metadata
   - View history
   - Bookmark solutions

5. **Implement daily snap limits:**
   - 5 snaps/day for free tier
   - Unlimited for Pro tier
   - Counter and upgrade prompts

6. **Add Android support:**
   - Test on Android devices
   - Handle Android-specific permissions
   - Optimize for Android UI

7. **Add Hindi language support:**
   - Implement i18n
   - Translate UI strings
   - Test with Hindi questions

8. **Integrate with full MVP features:**
   - Dashboard
   - Progress tracking
   - Parental consent
   - Payment integration

---

## Estimated Timeline

**Total Duration:** 15-20 days

- Phase 1 (Backend): 2-3 days
- Phase 2 (Flutter Setup): 1 day
- Phase 3 (Camera): 2-3 days
- Phase 4 (API Integration): 2 days
- Phase 5 (Solution Display): 3-4 days
- Phase 6 (Interactive Quiz): 3-4 days
- Phase 7 (TestFlight): 1-2 days
- Phase 8 (Testing): 2-3 days

**Buffer:** 2-3 days for unexpected issues

---

## Risk Mitigation

1. **OpenAI API Issues:**
   - Have fallback error messages
   - Test with various question types
   - Monitor API response times

2. **Camera Permissions:**
   - Clear permission requests
   - Handle denial gracefully
   - Provide settings link

3. **Low Bandwidth:**
   - Aggressive compression
   - Clear loading states
   - Retry mechanisms

4. **LaTeX Rendering:**
   - Test with various math expressions
   - Have fallback for unsupported syntax
   - Validate rendering on device

5. **TestFlight Approval:**
   - Submit early (24-48 hour review)
   - Have backup plan (direct device install if needed)

---

## Notes

- This is a POC focused on validating core functionality
- Code should be structured for easy extension to full MVP
- Multi-language structure should be in place (even if not used)
- Performance optimizations are critical for India market
- TestFlight deployment is essential for real device testing

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Owner:** Development Team

