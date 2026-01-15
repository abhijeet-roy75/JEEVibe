# JEEVibe Flutter Web App - Build Plan

**Version:** 1.0
**Date:** January 2026
**Status:** Planning Complete

---

## Overview

Enable the existing Flutter mobile app to run in web browsers with feature parity (excluding offline functionality).

| Attribute | Value |
|-----------|-------|
| **Source** | Existing `/mobile` Flutter project |
| **Hosting** | Firebase Hosting |
| **Domain** | `app.jeevibe.com` or `jeevibe.com/app` |
| **Scope** | Full features minus offline mode |

---

## Scope Definition

### In Scope (Web Version)
- Phone OTP authentication
- Initial assessment
- Snap & Solve (image upload → AI solution)
- Daily quizzes
- Analytics dashboard
- Solution history
- Subscription management
- Priya Ma'am persona

### Out of Scope (Web Version)
- Offline mode / offline storage
- Downloaded solutions cache
- Background sync
- PWA install prompts (future consideration)

---

## Current State Analysis

### What Works Out of the Box
| Feature | Package | Web Support |
|---------|---------|-------------|
| Firebase Auth | `firebase_auth` | Yes |
| Firestore | `cloud_firestore` | Yes |
| HTTP calls | `http` | Yes |
| State management | `provider` | Yes |
| Math rendering | `flutter_math_fork` | Yes |
| Charts | `fl_chart` | Yes |
| Shared preferences | `shared_preferences` | Yes (localStorage) |
| Google Fonts | `google_fonts` | Yes |

### Needs Modification
| Feature | Current Package | Issue | Solution |
|---------|-----------------|-------|----------|
| Camera capture | `camera` | Not web-compatible | Use `image_picker` (already used) |
| Image cropping | `image_cropper` | Limited web support | Simplify or use web alternative |
| Local database | `isar` | No web support | Skip for web (online-only) |
| Secure storage | `flutter_secure_storage` | Web uses localStorage | Acceptable for PIN |
| Biometrics | `local_auth` | Not available on web | PIN-only on web |
| File paths | `path_provider` | Different on web | Use conditional logic |

### Already Compatible
The app already uses `image_picker` which has web support via `image_picker_for_web`. The `ImagePicker().pickImage()` calls will work on web, though the UX differs:
- Mobile: Opens camera or gallery
- Web: Opens browser file picker (can access camera on supported devices)

---

## Implementation Plan

### Phase 1: Project Configuration

#### 1.1 Enable Web Platform
```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter config --enable-web
flutter create --platforms=web .
```

#### 1.2 Add Firebase Web Config
Run FlutterFire CLI to add web configuration:
```bash
flutterfire configure
```

This will update `lib/firebase_options.dart` with web-specific settings.

#### 1.3 Update pubspec.yaml

No new dependencies required since we're skipping offline. May need to add:
```yaml
dependencies:
  # Only if needed for web-specific image handling
  universal_html: ^2.2.4
```

---

### Phase 2: Platform Abstraction

#### 2.1 Create Platform Detection Utility

**File:** `lib/utils/platform_utils.dart`
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb;

  /// Check if offline features should be available
  static bool get supportsOffline => !kIsWeb;
}
```

#### 2.2 Disable Offline Features for Web

**Files to modify:**
- `lib/main.dart` - Skip offline provider initialization on web
- `lib/providers/offline_provider.dart` - Return early if web
- `lib/screens/` - Hide offline indicators on web

**Pattern:**
```dart
if (PlatformUtils.supportsOffline) {
  // Initialize offline services
} else {
  // Skip offline initialization
}
```

---

### Phase 3: Image Handling

#### 3.1 Camera Screen Modifications

**File:** `lib/screens/camera_screen.dart`

Current implementation uses `ImagePicker` which already works on web. Modifications needed:

1. **Update UI for Web**
   - Show "Upload Image" button prominently (web doesn't have live camera preview)
   - Add drag-and-drop support (optional enhancement)
   - Adjust button text: "Take Photo" → "Select or Capture Image"

2. **Handle File Differences**
   - Mobile: Returns file path
   - Web: Returns blob URL or bytes
   - Use `XFile` consistently (already does)

**Code pattern:**
```dart
Widget build(BuildContext context) {
  if (kIsWeb) {
    return _buildWebCaptureUI();
  }
  return _buildMobileCaptureUI();
}
```

#### 3.2 Image Preview Modifications

**File:** `lib/screens/image_preview_screen.dart`

Current issue: Uses `dart:io.File` which doesn't exist on web.

**Solution:** Use `Uint8List` for cross-platform image display.

```dart
// Instead of File
final Uint8List imageBytes;

// Display using Image.memory()
Image.memory(imageBytes)
```

#### 3.3 Photo Review Screen

**File:** `lib/screens/photo_review_screen.dart`

Same modifications as image preview - use bytes instead of File.

#### 3.4 Image Cropper Handling

`image_cropper` has limited web support. Options:
1. **Simplify:** Skip cropping on web, rely on user to crop before upload
2. **Alternative:** Use a web-compatible cropper library
3. **Conditional:** Use cropper on mobile, skip on web

**Recommended:** Option 3 - Conditional cropping
```dart
if (!kIsWeb) {
  // Use image_cropper
  croppedFile = await ImageCropper().cropImage(...);
} else {
  // Skip cropping on web, use original
  croppedFile = originalFile;
}
```

---

### Phase 4: UI/UX Adaptations

#### 4.1 Responsive Layout System

**File:** `lib/widgets/responsive/responsive_builder.dart` (NEW)

```dart
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 768) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}
```

#### 4.2 Breakpoints

Use existing breakpoints from `lib/theme/app_colors.dart`:
```dart
static const double mobile = 480.0;
static const double tablet = 768.0;
static const double desktop = 1024.0;
static const double wide = 1280.0;
```

#### 4.3 Key Screens to Update

| Screen | Mobile Layout | Desktop Layout |
|--------|---------------|----------------|
| Home/Dashboard | Single column | Sidebar + main content |
| Camera | Full screen | Centered card (max-width 600px) |
| Solution | Single column | Two-column (question | solution) |
| Analytics | Scrolling cards | Grid dashboard |
| Daily Quiz | Full screen | Centered card (max-width 800px) |

#### 4.4 Web-Specific UX Enhancements

1. **Mouse hover states** - Add hover effects to buttons/cards
2. **Keyboard navigation** - Ensure tab navigation works
3. **Browser back button** - Handle with Navigator properly
4. **URL routing** - Consider deep links (future enhancement)
5. **Loading states** - Web may have more latency, show better loading UI

---

### Phase 5: Authentication Adjustments

#### 5.1 Phone OTP on Web

Firebase Phone Auth works on web but with considerations:
- reCAPTCHA verification is required on web
- May need to configure reCAPTCHA in Firebase Console

**File:** `lib/services/firebase/auth_service.dart`

No code changes needed - Firebase handles web automatically. Just ensure:
1. Web app is added to Firebase project
2. Authorized domains include your hosting domain

#### 5.2 PIN Storage on Web

`flutter_secure_storage` on web uses localStorage (not as secure as mobile Keychain/Keystore, but acceptable for PIN).

No changes needed - library handles platform differences.

---

### Phase 6: Skip Offline Services

#### 6.1 Files to Modify

**`lib/main.dart`**
```dart
void main() async {
  // ... existing init ...

  if (!kIsWeb) {
    // Only initialize offline services on mobile
    await DatabaseService.instance.initialize();
    await ConnectivityService.instance.initialize();
  }

  runApp(MyApp());
}
```

**`lib/providers/offline_provider.dart`**
```dart
class OfflineProvider extends ChangeNotifier {
  // On web, always report as "online"
  bool get isOnline => kIsWeb ? true : _connectivityService.isOnline;

  // Skip offline features on web
  bool get supportsOffline => !kIsWeb;
}
```

#### 6.2 UI Changes

Hide offline-related UI elements on web:
- "Available Offline" badges
- Download for offline buttons
- Offline mode indicators
- Sync status widgets

**Pattern:**
```dart
if (!kIsWeb) {
  // Show offline-related UI
}
```

---

### Phase 7: Build & Deploy

#### 7.1 Web Build Command

```bash
cd /Users/abhijeetroy/Documents/JEEVibe/mobile
flutter build web --release
```

Output will be in `mobile/build/web/`

#### 7.2 Web Renderer Choice

Flutter web has two renderers:
- **HTML:** Smaller size, better text rendering
- **CanvasKit:** Better graphics, larger download

**Recommendation:** Use HTML renderer for JEEVibe (text-heavy app)

```bash
flutter build web --web-renderer html --release
```

#### 7.3 Firebase Hosting Configuration

Update root `firebase.json` for multi-site hosting:

```json
{
  "hosting": [
    {
      "target": "website",
      "public": "website",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
    },
    {
      "target": "webapp",
      "public": "mobile/build/web",
      "ignore": ["firebase.json", "**/.*"],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    }
  ]
}
```

#### 7.4 Firebase Hosting Targets

```bash
firebase target:apply hosting website website
firebase target:apply hosting webapp webapp
```

#### 7.5 Deploy Commands

```bash
# Deploy marketing website
firebase deploy --only hosting:website

# Deploy Flutter web app
flutter build web --web-renderer html --release
firebase deploy --only hosting:webapp
```

---

## Files to Modify Summary

### Core Files
| File | Changes |
|------|---------|
| `lib/main.dart` | Skip offline init on web |
| `lib/firebase_options.dart` | Add web config (auto via flutterfire) |
| `pubspec.yaml` | Minimal changes |

### Platform Abstraction
| File | Changes |
|------|---------|
| `lib/utils/platform_utils.dart` | NEW - Platform detection |
| `lib/providers/offline_provider.dart` | Return online=true on web |

### Image Handling
| File | Changes |
|------|---------|
| `lib/screens/camera_screen.dart` | Web-specific UI |
| `lib/screens/image_preview_screen.dart` | Use bytes not File |
| `lib/screens/photo_review_screen.dart` | Use bytes not File |

### UI/Responsive
| File | Changes |
|------|---------|
| `lib/widgets/responsive/responsive_builder.dart` | NEW |
| `lib/screens/assessment_intro_screen.dart` | Add responsive layout |
| `lib/screens/solution_screen.dart` | Add responsive layout |
| `lib/screens/analytics_screen.dart` | Add responsive layout |

### Configuration
| File | Changes |
|------|---------|
| `firebase.json` | Add webapp hosting target |
| `web/index.html` | Customize title, meta tags |

---

## New Files to Create

| File | Purpose |
|------|---------|
| `lib/utils/platform_utils.dart` | Platform detection helpers |
| `lib/widgets/responsive/responsive_builder.dart` | Responsive layout widget |
| `lib/widgets/responsive/max_width_container.dart` | Content width limiter |

---

## Testing Checklist

### Functional Testing
- [ ] Phone OTP sign-in works
- [ ] Initial assessment completes
- [ ] Image upload works (Snap & Solve)
- [ ] Solution displays correctly (LaTeX rendering)
- [ ] Daily quiz functions properly
- [ ] Analytics charts render
- [ ] Subscription status shows correctly

### Browser Testing
- [ ] Chrome (primary)
- [ ] Firefox
- [ ] Safari
- [ ] Edge
- [ ] Mobile Chrome (Android)
- [ ] Mobile Safari (iOS)

### Responsive Testing
- [ ] Mobile viewport (375px)
- [ ] Tablet viewport (768px)
- [ ] Desktop viewport (1024px)
- [ ] Wide viewport (1440px)

### Performance Testing
- [ ] Initial load time < 3s
- [ ] Image upload responsive
- [ ] No memory leaks
- [ ] Smooth scrolling

---

## Deployment Checklist

- [ ] Firebase web config added
- [ ] Web build succeeds without errors
- [ ] HTML renderer produces acceptable output
- [ ] Firebase hosting configured for webapp
- [ ] Custom domain configured (if using subdomain)
- [ ] SSL certificate active
- [ ] Analytics tracking works on web

---

## Future Enhancements (Post-Launch)

1. **PWA Support** - Add service worker for app-like install
2. **Deep Linking** - URL-based navigation to specific screens
3. **Keyboard Shortcuts** - Power user features
4. **Drag & Drop** - Enhanced image upload UX
5. **Web Push Notifications** - Daily quiz reminders
6. **Offline Mode** - If demand exists, implement with IndexedDB
