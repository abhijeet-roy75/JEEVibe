# JEEVibe Authentication & Database Implementation - Task Breakdown

## Overview
This task list covers the complete implementation of authentication, profile setup, and Firebase database integration for JEEVibe.

---

## Phase 1: Firebase Project Setup
- [ ] Create Firebase project in Firebase Console
- [ ] Enable Firebase Authentication
  - [ ] Enable Phone authentication provider
  - [ ] Configure authorized domains
  - [ ] Set up reCAPTCHA for web testing
- [ ] Create Cloud Firestore database
  - [ ] Choose region (asia-south1 for India)
  - [ ] Start in test mode initially
- [ ] Set up Firebase Storage (for future snap images)
- [ ] Download and add configuration files
  - [ ] `google-services.json` for Android
  - [ ] `GoogleService-Info.plist` for iOS
- [ ] Enable Firebase Analytics (optional)

---

## Phase 2: Flutter Firebase Integration
- [ ] Add Firebase dependencies to `pubspec.yaml`
  - [ ] `firebase_core`
  - [ ] `firebase_auth`
  - [ ] `cloud_firestore`
  - [ ] `firebase_storage`
  - [ ] `firebase_analytics` (optional)
- [ ] Initialize Firebase in `main.dart`
- [ ] Configure iOS
  - [ ] Update `ios/Runner/Info.plist`
  - [ ] Add URL schemes
  - [ ] Update minimum iOS version to 12.0
- [ ] Configure Android
  - [ ] Update `android/build.gradle`
  - [ ] Update `android/app/build.gradle`
  - [ ] Add multidex support
  - [ ] Update minimum SDK to 21
- [ ] Test Firebase initialization
  - [ ] Run on iOS simulator
  - [ ] Run on Android emulator

---

## Phase 3: Firebase Services Layer
- [ ] Create `lib/services/firebase/` directory
- [ ] Implement `auth_service.dart`
  - [ ] Phone number verification
  - [ ] OTP verification
  - [ ] Sign in with credential
  - [ ] Sign out
  - [ ] Get current user
  - [ ] Auth state listener
- [ ] Implement `firestore_service.dart`
  - [ ] User CRUD operations
  - [ ] User stats operations
  - [ ] Snap history operations
  - [ ] Practice history operations
  - [ ] Question bank queries
  - [ ] Lookup values queries
- [ ] Implement `pin_service.dart`
  - [ ] Hash PIN (using crypto package)
  - [ ] Verify PIN
  - [ ] Store PIN in Firestore
  - [ ] Local PIN caching (encrypted)
- [ ] Create Firebase models in `lib/models/firebase/`
  - [ ] `user_model.dart`
  - [ ] `user_stats_model.dart`
  - [ ] `snap_history_model.dart`
  - [ ] `practice_history_model.dart`
  - [ ] `question_model.dart`

---

## Phase 4: Authentication Screens
### 4.1: Welcome Splash Screen
- [ ] Create `lib/screens/auth/welcome_splash_screen.dart`
- [ ] Design UI matching `1. WelcomeSplash.png`
  - [ ] JEEVibe logo
  - [ ] Tagline/value proposition
  - [ ] "Get Started" button
  - [ ] Auto-dismiss timer (2 seconds)
- [ ] Navigation logic
  - [ ] Check if user is authenticated
  - [ ] Navigate to appropriate screen

### 4.2: Phone Number Entry Screen
- [ ] Create `lib/screens/auth/phone_entry_screen.dart`
- [ ] Design UI matching `2. AuthFlow - Phone Number Entry.png`
  - [ ] Country code selector widget
  - [ ] Phone number input field
  - [ ] Input validation
  - [ ] "Send OTP" button
  - [ ] Terms & Privacy links
- [ ] Implement phone validation
  - [ ] Format validation (10 digits for India)
  - [ ] Country code validation
- [ ] Integrate Firebase Phone Auth
  - [ ] Call `verifyPhoneNumber()`
  - [ ] Handle callbacks
  - [ ] Error handling
  - [ ] Loading states

### 4.3: OTP Verification Screen
- [ ] Create `lib/screens/auth/otp_verification_screen.dart`
- [ ] Design UI matching `3. AuthFlow - OTP Verification.png`
  - [ ] 6 individual OTP input boxes
  - [ ] Auto-focus next box
  - [ ] Countdown timer (60 seconds)
  - [ ] Resend OTP button
  - [ ] Edit phone number link
- [ ] Implement OTP functionality
  - [ ] Auto-read OTP from SMS
  - [ ] Manual OTP entry
  - [ ] Auto-submit on 6 digits
  - [ ] Resend OTP logic
  - [ ] Timer countdown
- [ ] Integrate Firebase OTP verification
  - [ ] Sign in with credential
  - [ ] Handle success/failure
  - [ ] Navigate to PIN creation

### 4.4: Create PIN Screen
- [ ] Create `lib/screens/auth/create_pin_screen.dart`
- [ ] Design UI matching `4. AuthFlow - Create Your Pin.png`
  - [ ] PIN input display (4 dots)
  - [ ] Numeric keypad (0-9)
  - [ ] Biometric toggle
  - [ ] Confirm PIN step
- [ ] Implement PIN logic
  - [ ] PIN entry state management
  - [ ] PIN confirmation
  - [ ] PIN strength validation
  - [ ] Hash PIN before storing
- [ ] Store PIN in Firestore
  - [ ] Create user document
  - [ ] Store hashed PIN
- [ ] Optional: Biometric setup
  - [ ] Check device support
  - [ ] Enable biometric auth

### 4.5: Profile Setup - Basics Screen
- [ ] Create `lib/screens/auth/profile_basics_screen.dart`
- [ ] Design UI matching `5. Student Profile Setup - Basics.png`
  - [ ] Form layout
  - [ ] Progress indicator (Step 1 of 2)
  - [ ] All input fields
  - [ ] Dropdown widgets
  - [ ] "Continue" button
- [ ] Implement form fields
  - [ ] First Name input
  - [ ] Last Name input
  - [ ] Email input (optional)
  - [ ] Date of Birth picker
  - [ ] Gender dropdown
  - [ ] Current Class dropdown
  - [ ] Target Exam dropdown
  - [ ] Target Year dropdown (see `5a.png`)
- [ ] Form validation
  - [ ] Required field validation
  - [ ] Email format validation
  - [ ] Age validation
- [ ] Fetch lookup values from Firestore
  - [ ] Load dropdown options
  - [ ] Cache locally
- [ ] Save to Firestore (partial save)
  - [ ] Update user document
  - [ ] Navigate to advanced screen

### 4.6: Profile Setup - Advanced Screen
- [ ] Create `lib/screens/auth/profile_advanced_screen.dart`
- [ ] Design UI matching `6. Student Profile Setup - Advanced.png`
  - [ ] Form layout
  - [ ] Progress indicator (Step 2 of 2)
  - [ ] All input fields
  - [ ] Multi-select chips
  - [ ] "Complete Profile" button
  - [ ] "Back" button
- [ ] Implement form fields
  - [ ] School Name input
  - [ ] City input (with autocomplete)
  - [ ] State dropdown
  - [ ] Coaching Institute dropdown (see `6a.png`)
  - [ ] Coaching Branch input (conditional)
  - [ ] Study Mode dropdown
  - [ ] Preferred Language dropdown
  - [ ] Weak Subjects multi-select
  - [ ] Strong Subjects multi-select
- [ ] Form validation
  - [ ] Required field validation
  - [ ] Conditional field logic
- [ ] Save to Firestore (complete profile)
  - [ ] Update user document
  - [ ] Set `profileCompleted: true`
  - [ ] Create initial userStats document
- [ ] Success handling
  - [ ] Show success animation
  - [ ] Navigate to Home Screen

---

## Phase 5: PIN Lock & Session Management
- [ ] Create `lib/screens/auth/pin_lock_screen.dart`
- [ ] Design PIN entry UI
  - [ ] 4-dot display
  - [ ] Numeric keypad
  - [ ] Biometric button (if enabled)
  - [ ] "Forgot PIN?" link
- [ ] Implement PIN verification
  - [ ] Compare with stored hash
  - [ ] Limit attempts (5 max)
  - [ ] Lockout after max attempts
- [ ] Implement biometric auth
  - [ ] Use `local_auth` package
  - [ ] Fallback to PIN
- [ ] Session management
  - [ ] App lifecycle listener
  - [ ] Show PIN lock on background
  - [ ] Auto-lock after timeout
- [ ] Create auth state provider
  - [ ] Track authentication state
  - [ ] Track PIN lock state
  - [ ] Provide auth methods

---

## Phase 6: Database Migration
- [ ] Create migration utility
  - [ ] `lib/services/migration_service.dart`
- [ ] Implement migration functions
  - [ ] Migrate snap history
  - [ ] Migrate recent solutions
  - [ ] Migrate user stats
  - [ ] Migrate snap counter
- [ ] Create migration UI
  - [ ] Show migration progress
  - [ ] Handle errors
  - [ ] Confirm completion
- [ ] Test migration
  - [ ] Test with existing local data
  - [ ] Verify data in Firestore
  - [ ] Test rollback if needed
- [ ] Update existing services
  - [ ] Modify `StorageService` to use Firestore
  - [ ] Update `SnapCounterService` to use Firestore
  - [ ] Update `AppStateProvider` to use Firestore

---

## Phase 7: Question Bank Setup
- [ ] Create Firestore upload script
  - [ ] `scripts/upload_question_bank.js` (Node.js)
  - [ ] Parse JSON files
  - [ ] Batch upload to Firestore
  - [ ] Handle errors and retries
- [ ] Upload lookup values
  - [ ] Create lookup values JSON
  - [ ] Upload to `lookupValues` collection
- [ ] Upload question bank
  - [ ] Parse `QB- Physics-laws-of-motion.json`
  - [ ] Upload to `questionBank/Physics/questions`
  - [ ] Create indexes
  - [ ] Verify upload
- [ ] Create question bank service
  - [ ] `lib/services/question_bank_service.dart`
  - [ ] Fetch questions by filters
  - [ ] Cache questions locally
  - [ ] Update usage stats
- [ ] Test question fetching
  - [ ] Query by subject
  - [ ] Query by chapter
  - [ ] Query by difficulty
  - [ ] Query by tags

---

## Phase 8: Firestore Security Rules
- [ ] Write security rules
  - [ ] User data rules
  - [ ] User stats rules
  - [ ] Snap history rules
  - [ ] Practice history rules
  - [ ] Question bank rules (read-only)
  - [ ] Lookup values rules (public read)
- [ ] Deploy security rules
  - [ ] Test in Firebase Console
  - [ ] Deploy to production
- [ ] Test security
  - [ ] Test unauthorized access
  - [ ] Test user data isolation
  - [ ] Test read-only collections

---

## Phase 9: Update Existing Features
- [ ] Update Home Screen
  - [ ] Show user profile info
  - [ ] Fetch data from Firestore
  - [ ] Real-time stats updates
- [ ] Update Camera/Snap Flow
  - [ ] Save snaps to Firestore
  - [ ] Update snap counter in Firestore
  - [ ] Sync with daily limit
- [ ] Update Solution Screen
  - [ ] Save solutions to Firestore
  - [ ] Update recent solutions
- [ ] Update Quiz Flow
  - [ ] Save practice history to Firestore
  - [ ] Update user stats
  - [ ] Update question usage stats
- [ ] Update All Solutions Screen
  - [ ] Fetch from Firestore
  - [ ] Implement pagination
  - [ ] Real-time updates

---

## Phase 10: Testing & Validation
### 10.1: Unit Tests
- [ ] Test auth service
- [ ] Test Firestore service
- [ ] Test PIN service
- [ ] Test migration service
- [ ] Test question bank service

### 10.2: Integration Tests
- [ ] Test complete auth flow
- [ ] Test profile setup flow
- [ ] Test PIN lock flow
- [ ] Test data migration
- [ ] Test question bank queries

### 10.3: Manual Testing
- [ ] Test on iOS device (India number)
- [ ] Test on iOS device (US number)
- [ ] Test on Android device (India number)
- [ ] Test on Android device (US number)
- [ ] Test offline mode
- [ ] Test network errors
- [ ] Test edge cases

### 10.4: Performance Testing
- [ ] Test app startup time
- [ ] Test Firestore query performance
- [ ] Test image upload performance
- [ ] Test with large datasets
- [ ] Monitor Firebase usage

---

## Phase 11: Documentation & Deployment
- [ ] Update README with Firebase setup
- [ ] Document environment variables
- [ ] Document Firebase configuration
- [ ] Create deployment guide
- [ ] Update privacy policy
- [ ] Update terms of service
- [ ] Prepare for TestFlight/Play Store

---

## Dependencies to Add

```yaml
# pubspec.yaml additions
dependencies:
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_storage: ^11.6.0
  firebase_analytics: ^10.8.0
  
  # Authentication
  local_auth: ^2.1.8
  crypto: ^3.0.3
  
  # UI
  pin_code_fields: ^8.0.1
  country_code_picker: ^3.0.0
  
  # Utilities
  intl_phone_number_input: ^0.7.4
```

---

## Estimated Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Firebase Setup | 1 day | None |
| Phase 2: Flutter Integration | 1 day | Phase 1 |
| Phase 3: Services Layer | 2 days | Phase 2 |
| Phase 4: Auth Screens | 4 days | Phase 3 |
| Phase 5: PIN Lock | 1 day | Phase 4 |
| Phase 6: Migration | 2 days | Phase 3 |
| Phase 7: Question Bank | 2 days | Phase 2 |
| Phase 8: Security Rules | 1 day | Phase 7 |
| Phase 9: Update Features | 2 days | Phase 6 |
| Phase 10: Testing | 3 days | Phase 9 |
| Phase 11: Documentation | 1 day | Phase 10 |

**Total Estimated Time**: ~20 days (3-4 weeks)

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| OTP delivery issues in India | High | Use Firebase (proven in India), test extensively |
| Firebase costs exceed budget | Medium | Monitor usage, implement caching, use free tier wisely |
| Data migration failures | High | Implement rollback, keep local backup, test thoroughly |
| Security vulnerabilities | High | Follow Firebase best practices, implement security rules |
| Performance issues | Medium | Implement pagination, caching, optimize queries |

---

## Success Criteria

- [ ] Users can register with phone number (India & US)
- [ ] OTP verification works reliably
- [ ] PIN lock functions correctly
- [ ] Profile setup is intuitive and complete
- [ ] All existing local data migrated successfully
- [ ] Question bank accessible and performant
- [ ] Security rules prevent unauthorized access
- [ ] App works offline (with cached data)
- [ ] No regression in existing features
- [ ] Firebase costs within free tier limits
