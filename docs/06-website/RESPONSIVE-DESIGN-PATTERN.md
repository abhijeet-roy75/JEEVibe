# Responsive Design Pattern for Web

**Date**: 2026-02-20
**Purpose**: Standardize responsive behavior across all screens for web/desktop

---

## Core Principles

1. **Full-Page Scrolling**: Entire page scrolls (including headers), not just content area
2. **Constrained Width**: Content limited to readable width on desktop (typically 480-1200px)
3. **Centered Layout**: Content centered horizontally on wide screens
4. **Mobile-First**: No changes to mobile behavior (full width, native scrolling)

---

## The Problem (Before)

### Issue 1: Partial Scrolling
```dart
// ❌ BAD: Only content area scrolls, header is fixed
Column(
  children: [
    Header(),  // Fixed at top
    Expanded(
      child: SingleChildScrollView(
        child: Content(),  // Only this scrolls
      ),
    ),
  ],
)
```

**Problems**:
- Header takes up valuable viewport space
- Confusing UX (users expect full page to scroll)
- Wastes vertical space on desktop

### Issue 2: Full-Width Content
```dart
// ❌ BAD: Content stretched across entire screen
Scaffold(
  body: Content(),  // Stretches to 1920px+ on desktop
)
```

**Problems**:
- Poor readability (lines too long)
- Unprofessional appearance
- Doesn't feel like a mobile app

---

## The Solution (After)

### Pattern 1: Scrollable Screens (Recommended)

Use `ResponsiveScrollableLayout` for screens where everything scrolls together:

```dart
import 'package:jeevibe_mobile/widgets/responsive_layout.dart';

Scaffold(
  backgroundColor: AppColors.backgroundWhite,
  body: ResponsiveScrollableLayout(
    maxWidth: 480, // Mobile app width
    child: Column(
      children: [
        // Header section
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: AppColors.ctaGradient),
          child: HeaderContent(),
        ),
        // Content section
        Padding(
          padding: EdgeInsets.all(24),
          child: BodyContent(),
        ),
        // Footer
        Footer(),
      ],
    ),
  ),
)
```

**Benefits**:
- ✅ Entire page scrolls naturally
- ✅ Constrained to 480px on desktop (centered)
- ✅ Full width on mobile
- ✅ Clean, simple code

### Pattern 2: Non-Scrollable Screens

Use `ResponsiveLayout` for screens with built-in scrolling (like ListView):

```dart
Scaffold(
  body: ResponsiveLayout(
    maxWidth: 600,
    child: ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => ItemCard(items[index]),
    ),
  ),
)
```

---

## Recommended Max Widths

| Screen Type | Max Width | Example |
|-------------|-----------|---------|
| **Auth Screens** | 480px | Welcome, Phone Entry, OTP |
| **Simple Forms** | 480px | Create PIN, Profile Edit |
| **Content Screens** | 600px | Quiz, Chapter Practice |
| **Dashboard** | 1200px | Home (2-column grid) |
| **Wide Content** | 800px | Analytics, Reports |

---

## Implementation Guide

### Step 1: Import the Widget

```dart
import 'package:jeevibe_mobile/widgets/responsive_layout.dart';
```

### Step 2: Choose Pattern

**Scrollable (most screens)**:
```dart
ResponsiveScrollableLayout(
  maxWidth: 480,
  child: YourContent(),
)
```

**Non-Scrollable (ListView, GridView, etc.)**:
```dart
ResponsiveLayout(
  maxWidth: 600,
  child: YourScrollableWidget(),
)
```

### Step 3: Adjust Header Size for Desktop

For screens with prominent headers, reduce padding on desktop:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isDesktop = constraints.maxWidth > 900;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 40), // Less padding on desktop
      child: Header(),
    );
  },
)
```

**Or use utility function**:
```dart
import 'package:jeevibe_mobile/widgets/responsive_layout.dart';

Container(
  padding: EdgeInsets.all(isDesktopViewport(context) ? 24 : 40),
  child: Header(),
)
```

---

## Migration Checklist

### Priority 1: Auth Flow (Week 1)
- [x] ✅ Welcome Screen - DONE
- [x] ✅ Phone Entry Screen - DONE
- [x] ✅ OTP Verification Screen - DONE
- [ ] Create PIN Screen
- [ ] Onboarding Screens (3 steps)

### Priority 2: Core Features (Week 2)
- [x] ✅ Home Screen (2-column grid for desktop) - DONE
- [ ] Daily Quiz Flow
- [ ] Chapter Practice
- [ ] Mock Test
- [ ] Snap & Solve

### Priority 3: Secondary Screens (Week 3)
- [ ] Profile screens
- [ ] History screens
- [ ] Analytics
- [ ] Settings

---

## Example: Welcome Screen (Complete)

**Before** (Column with Expanded):
```dart
Column(
  children: [
    Expanded(flex: 2, child: Header()),  // 40% height, fixed
    Expanded(flex: 3, child: ScrollableContent()),  // 60% height, scrolls
  ],
)
```

**After** (ResponsiveScrollableLayout):
```dart
ResponsiveScrollableLayout(
  maxWidth: 480,
  child: Column(
    children: [
      Container(
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 40 : 60,  // Smaller on desktop
        ),
        child: Header(),
      ),
      Padding(
        padding: EdgeInsets.all(24),
        child: Content(),
      ),
    ],
  ),
)
```

---

## Desktop-Specific Adjustments

### Smaller Headers
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isDesktop = constraints.maxWidth > 900;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 40 : 60,  // 33% less padding
      ),
      child: Column(
        children: [
          SizedBox(
            width: isDesktop ? 80 : 100,  // Smaller logo
            height: isDesktop ? 80 : 100,
            child: Logo(),
          ),
          SizedBox(height: isDesktop ? 16 : 20),  // Less spacing
          Text(
            'Welcome',
            style: TextStyle(
              fontSize: isDesktop ? 24 : 28,  // Smaller text
            ),
          ),
        ],
      ),
    );
  },
)
```

### 2-Column Grid Layouts (Home Screen)

```dart
ResponsiveScrollableLayout(
  maxWidth: 1200,  // Wider for 2 columns
  child: LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 900;

      return isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [Card1(), Card2(), Card3()],
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [Card4(), Card5()],
                  ),
                ),
              ],
            )
          : Column(
              children: [Card1(), Card2(), Card3(), Card4(), Card5()],
            );
    },
  ),
)
```

---

## Testing Checklist

For each migrated screen:

- [ ] **Desktop (>900px)**: Content constrained and centered
- [ ] **Mobile (<900px)**: Full width, no changes
- [ ] **Full-page scroll**: Entire page scrolls, not just content
- [ ] **Header size**: Proportional on desktop (not massive)
- [ ] **Readability**: Lines not too long, comfortable reading
- [ ] **No horizontal scroll**: Content fits within max width

---

## Performance Notes

- `LayoutBuilder` is lightweight (no performance impact)
- `ResponsiveLayout` widgets are stateless (efficient)
- Desktop constraints only apply when width > 900px
- Mobile performance unchanged (no overhead)

---

## References

- Widget: `mobile/lib/widgets/responsive_layout.dart`
- Example: `mobile/lib/screens/auth/welcome_screen.dart`
- Test project: `flutter_web_ui_test/lib/home_screen_test.dart`
- Flutter responsive guide: https://docs.flutter.dev/ui/layout/responsive
