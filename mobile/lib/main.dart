import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'providers/daily_quiz_provider.dart';
import 'providers/ai_tutor_provider.dart';
import 'providers/chapter_practice_provider.dart';
import 'providers/mock_test_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Services
import 'services/storage_service.dart';
import 'services/snap_counter_service.dart';
import 'services/firebase/auth_service.dart';
import 'services/firebase/firestore_user_service.dart';
import 'services/subscription_service.dart';
import 'services/offline/connectivity_service.dart';
import 'services/offline/database_service.dart';
import 'services/offline/image_cache_service.dart';
import 'services/offline/sync_service.dart';
import 'services/api_service.dart';
import 'services/push_notification_service.dart';
import 'providers/app_state_provider.dart';
import 'providers/offline_provider.dart';
import 'providers/user_profile_provider.dart';
import 'models/user_profile.dart';
import 'models/subscription_models.dart';

// Screens
import 'screens/auth/welcome_screen.dart'; // The new Auth Wrapper
import 'screens/auth/pin_verification_screen.dart'; // PIN verification
import 'screens/assessment_intro_screen.dart'; // Home dashboard (used in bottom nav)
import 'screens/main_navigation_screen.dart'; // Main navigation with bottom nav
// Services
import 'services/firebase/pin_service.dart';

// Widgets
import 'widgets/trial_expired_dialog.dart';

// Global navigator key for navigation and in-app notifications
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

/// Initialize screenshot and screen recording prevention
/// This applies globally to the entire app
Future<void> _initializeScreenProtection() async {
  try {
    if (Platform.isAndroid) {
      // Android: Uses FLAG_SECURE to prevent screenshots and screen recording
      await ScreenProtector.protectDataLeakageOn();
    } else if (Platform.isIOS) {
      // iOS: Prevent screenshots (uses secure text field technique)
      await ScreenProtector.preventScreenshotOn();
      // Also blur content in app switcher
      await ScreenProtector.protectDataLeakageWithBlur();
    }

    debugPrint('Screen protection enabled');
  } catch (e) {
    debugPrint('Failed to enable screen protection: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Register background message handler for push notifications
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize connectivity service for offline detection
  // Use forceReinit: true to handle hot restart properly
  await ConnectivityService().initialize(forceReinit: true);

  // Initialize offline database and image cache
  await DatabaseService().initialize();
  await ImageCacheService().initialize();

  // Enable screenshot prevention (global - applies to entire app)
  await _initializeScreenProtection();

  // Suppress harmless SVG warnings and LaTeX debug messages
  // These are informational and don't affect functionality
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      final lowerMessage = message.toLowerCase();
      // Suppress SVG warnings (check for various patterns)
      // Suppress "unhandled element" warnings for SVG elements like style, metadata, etc.
      if (lowerMessage.contains('unhandled element')) {
        if (lowerMessage.contains('metadata') || 
            lowerMessage.contains('style') ||
            lowerMessage.contains('<style')) {
          return;
        }
      }
      // Suppress "Picture key" warnings related to SVG (can appear with or without "unhandled element")
      if (lowerMessage.contains('picture key')) {
        if (lowerMessage.contains('svg') || 
            lowerMessage.contains('loader') ||
            lowerMessage.contains('svg loader')) {
          return;
        }
      }
      // Suppress SVG loader messages
      if (lowerMessage.contains('svg loader')) {
        return;
      }
      // Suppress combined messages like "unhandled element <style/>; Picture key: Svg loader"
      if (lowerMessage.contains('unhandled element') && lowerMessage.contains('picture key')) {
        return;
      }
      // Suppress LaTeX debug messages
      if (lowerMessage.contains('[latex]') || lowerMessage.contains('latex')) {
        if (lowerMessage.contains('wrapping allowed') ||
            lowerMessage.contains('fallback') ||
            lowerMessage.contains('converted latex')) {
          return;
        }
      }
    }
    // Use original debugPrint for all other messages
    originalDebugPrint?.call(message, wrapWidth: wrapWidth);
  };
  
  // Note: print() cannot be overridden in Dart as it's a top-level function
  // SVG warnings from flutter_svg package will still appear but are harmless
  
  // Create services
  final storageService = StorageService();
  final snapCounterService = SnapCounterService(storageService);
  
  runApp(
    MultiProvider(
      providers: [
        // Firebase Auth (Now defined FIRST so others can depend on it)
        ChangeNotifierProvider(create: (_) => AuthService()),

        // Subscription Service (singleton - provides tier info and feature gating)
        ChangeNotifierProvider.value(value: SubscriptionService()),

        // User Profile (centralized state for user info across all screens)
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),

        // App State (Snap limits, etc.) - Now depends on AuthService
        // PERFORMANCE: Lazy initialization - initialize() called on first access, not at app startup
        ChangeNotifierProxyProvider<AuthService, AppStateProvider>(
          create: (context) => AppStateProvider(
            storageService,
            snapCounterService,
            Provider.of<AuthService>(context, listen: false)
          ), // Removed ..initialize() - will initialize lazily on first access
          update: (context, authService, previous) =>
            previous ?? AppStateProvider(storageService, snapCounterService, authService),
        ),
        
        // Firestore User Data
        Provider(create: (_) => FirestoreUserService()),
        
        // Daily Quiz State
        ChangeNotifierProxyProvider<AuthService, DailyQuizProvider>(
          create: (_) => DailyQuizProvider(AuthService()),
          update: (_, authService, previous) =>
            previous ?? DailyQuizProvider(authService),
        ),

        // AI Tutor (Priya Ma'am) State
        ChangeNotifierProxyProvider<AuthService, AiTutorProvider>(
          create: (_) => AiTutorProvider(AuthService()),
          update: (_, authService, previous) =>
            previous ?? AiTutorProvider(authService),
        ),

        // Chapter Practice State
        ChangeNotifierProvider(create: (_) => ChapterPracticeProvider()),

        // Offline Mode Provider
        ChangeNotifierProvider(create: (_) => OfflineProvider()),

        // Mock Test State
        ChangeNotifierProxyProvider<AuthService, MockTestProvider>(
          create: (_) => MockTestProvider(AuthService()),
          update: (_, authService, previous) =>
            previous ?? MockTestProvider(authService),
        ),
      ],
      child: const JEEVibeApp(),
    ),
  );
}

class JEEVibeApp extends StatefulWidget {
  const JEEVibeApp({super.key});

  @override
  State<JEEVibeApp> createState() => _JEEVibeAppState();
}

class _JEEVibeAppState extends State<JEEVibeApp> with WidgetsBindingObserver {
  bool _isLockScreenShown = false;
  bool _isSessionExpiredDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register session expiry callback for API service
    ApiService.onSessionExpired = _handleSessionExpired;
  }

  /// Handle session expiry by showing a dialog and forcing logout
  void _handleSessionExpired(String code, String message) {
    // Prevent showing multiple dialogs
    if (_isSessionExpiredDialogShown) return;
    _isSessionExpiredDialogShown = true;

    final context = globalNavigatorKey.currentContext;
    if (context == null) {
      _isSessionExpiredDialogShown = false;
      return;
    }

    // Show dialog after current frame to avoid build issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isSessionExpiredDialogShown = false;
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Session Expired'),
          content: Text(
            code == 'SESSION_EXPIRED'
                ? 'You have been logged in on another device. Please sign in again to continue using this device.'
                : message,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                _isSessionExpiredDialogShown = false;

                // Force logout
                try {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await authService.signOut();

                  // Clear PIN
                  final pinService = PinService();
                  await pinService.clearPin();
                } catch (e) {
                  debugPrint('Error during force logout: $e');
                }

                // Navigate to welcome screen
                globalNavigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              child: const Text('Sign In Again'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up session expiry callback to prevent memory leaks
    ApiService.onSessionExpired = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // _checkAndLockApp(); // DISABLED: As per user request, do not prompt for PIN on resume
    }
  }

  Future<void> _checkAndLockApp() async {
    // Only lock if not already showing lock screen
    if (_isLockScreenShown) return;

    final context = globalNavigatorKey.currentContext;
    if (context == null) return;

    // Access providers via context or instances if available
    // Note: Provider might not be available if widget tree isn't fully built
    // But since this is resume, it should be fine.
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated) {
        final pinService = PinService();
        final hasPin = await pinService.pinExists();
        
        if (hasPin && mounted) {
          // Show Lock Screen
          setState(() {
            _isLockScreenShown = true;
          });
          
          globalNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => PinVerificationScreen(
                isUnlockMode: true,
              ),
            ),
          ).then((_) {
             // Reset flag when lock screen is popped (unlocked)
             if (mounted) {
               setState(() {
                 _isLockScreenShown = false;
               });
             }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking lock status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'JEEVibe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EE),
          primary: const Color(0xFF6200EE),
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> with WidgetsBindingObserver {
  bool _isLoading = true;
  Widget? _targetScreen;
  bool _hasShownTrialExpiredDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLoginStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Trigger sync when app comes to foreground if user has offline access
    if (state == AppLifecycleState.resumed) {
      _triggerForegroundSync();
    }
  }

  /// Trigger sync when app comes to foreground
  Future<void> _triggerForegroundSync() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        return;
      }

      final userId = authService.currentUser?.uid;
      if (userId == null) return;

      // Update last active timestamp
      _updateLastActive(userId);

      final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);
      if (!offlineProvider.offlineEnabled || !offlineProvider.isOnline) {
        return;
      }

      final authToken = await authService.currentUser?.getIdToken();
      if (authToken != null) {
        _triggerBackgroundSync(
          offlineProvider,
          userId,
          authToken,
        );
      }
    } catch (e) {
      print('Error triggering foreground sync: $e');
    }
  }

  /// Update last active timestamp (non-blocking)
  void _updateLastActive(String userId) {
    // Fire and forget - don't block app startup/resume
    () async {
      try {
        final firestoreService = FirestoreUserService();
        await firestoreService.updateLastActive(userId);
      } catch (e) {
        print('Failed to update last active: $e');
        // Non-critical error, don't show to user
      }
    }();
  }

  /// Trigger background sync for offline solutions
  void _triggerBackgroundSync(
    OfflineProvider offlineProvider,
    String userId,
    String authToken,
  ) {
    // Only sync if online and initialized
    if (!offlineProvider.isOnline || !offlineProvider.isInitialized) {
      return;
    }

    // Trigger sync in background (async, don't wait)
    () async {
      try {
        // Get subscription status to determine solution limit
        final subscriptionStatus = await SubscriptionService().fetchStatus(authToken);
        if (subscriptionStatus == null) {
          return;
        }

        final maxSolutions = subscriptionStatus.limits.offlineSolutionsLimit;
        // -1 means unlimited, use a reasonable default for unlimited
        final limit = maxSolutions == -1 ? 200 : maxSolutions;

        // Trigger sync in background
        final syncService = SyncService();
        final result = await syncService.syncSolutions(
          userId: userId,
          authToken: authToken,
          maxSolutions: limit,
        );

        if (result.success) {
          print('Background sync completed: ${result.syncedCount} solutions synced');
        } else {
          print('Background sync failed: ${result.error}');
        }
      } catch (e) {
        print('Error starting background sync: $e');
      }
    }();
  }

  Future<void> _checkLoginStatus() async {
    // Check Auth & Profile
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    // Store currentUser in local variable to avoid race conditions
    final currentUser = authService.currentUser;
    if (currentUser == null) {
      // User not authenticated, proceed to welcome screen
      if (mounted) {
        setState(() {
          _targetScreen = const WelcomeScreen();
          _isLoading = false;
        });
      }
      return;
    }

    // PERFORMANCE OPTIMIZATION: Parallelize independent operations
    // Previously: profile check → token fetch → subscription status → offline init (sequential: 20-45s)
    // Now: profile + token (parallel) → subscription + offline init (parallel) (optimized: 10-15s)

    final firestoreService = Provider.of<FirestoreUserService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _targetScreen = const WelcomeScreen();
          _isLoading = false;
        });
      }
      return;
    }

    // Step 1: Parallelize profile fetch and token fetch (both independent)
    UserProfile? userProfile;
    String? authToken;

    try {
      final results = await Future.wait([
        firestoreService.getUserProfile(user.uid).catchError((e) {
          print('Error checking profile: $e');
          return null; // null = couldn't check
        }),
        user.getIdToken().catchError((e) {
          print('Error getting auth token: $e');
          return null;
        }),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Profile/token fetch timed out after 10 seconds');
          return [null, null]; // Return nulls on timeout
        },
      );

      userProfile = results[0] as UserProfile?;
      authToken = results[1] as String?;

      // Auth token obtained successfully (removed logging for security)
    } catch (e) {
      print('Error in parallel initialization: $e');
      userProfile = null;
    }

    if (!mounted) return;

    // Re-check authentication state after async operations
    if (authService.currentUser == null) {
      if (mounted) {
        setState(() {
          _targetScreen = const WelcomeScreen();
          _isLoading = false;
        });
      }
      return;
    }

    // Only sign out if we CONFIRMED profile doesn't exist (not on network error)
    if (userProfile == null) {
      // Could be network error or genuinely no profile
      // Don't sign out immediately - let user continue and handle later
      print('Warning: Could not load profile, continuing with limited data');
    }

    // Pre-populate UserProfileProvider with fetched profile to avoid duplicate fetch
    if (mounted && userProfile != null) {
      final profileProvider = Provider.of<UserProfileProvider>(context, listen: false);
      profileProvider.updateProfile(userProfile);
    }

    // Step 2: Parallelize subscription fetch, offline provider initialization, and push notification setup
    if (mounted && authToken != null) {
      final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);
      bool offlineEnabled = false;

      try {
        // Fetch subscription status and initialize offline provider in parallel
        final results = await Future.wait([
          SubscriptionService().fetchStatus(authToken, forceRefresh: true).catchError((e) {
            print('Error fetching subscription status: $e');
            return null;
          }),
          // Pre-initialize offline provider (will update offlineEnabled after subscription fetch)
          Future.value(null), // Placeholder, will init after we get offlineEnabled
        ]).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Subscription fetch timed out after 10 seconds');
            return [null, null]; // Return nulls on timeout
          },
        );

        final subscriptionStatus = results[0];
        offlineEnabled = subscriptionStatus?.limits.offlineEnabled ?? false;

        // Now initialize offline provider with correct offlineEnabled value
        await offlineProvider.initialize(
          user.uid,
          offlineEnabled: offlineEnabled,
          authToken: authToken,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Offline provider initialization timed out after 5 seconds');
          },
        );

        // Initialize push notifications (non-blocking)
        PushNotificationService().initialize(
          authToken,
          navigatorKey: globalNavigatorKey,
        ).catchError((e) {
          print('Error initializing push notifications: $e');
        });

        // Update last active timestamp (non-blocking)
        firestoreService.updateLastActive(user.uid).catchError((e) {
          print('Error updating last active: $e');
        });

        // Trigger automatic sync for Pro/Ultra users if online
        if (offlineEnabled && mounted) {
          try {
            // Sync in background (don't wait for it)
            _triggerBackgroundSync(
              offlineProvider,
              user.uid,
              authToken,
            );
          } catch (e) {
            print('Error triggering background sync: $e');
          }
        }
      } catch (e) {
        print('Error in subscription/offline initialization: $e');
      }
    }

    if (!mounted) return;

    final pinService = PinService();
    final hasPin = await pinService.pinExists();

    if (!mounted) return;

    // Determine target screen (MainNavigation with bottom nav is the new home)
    final targetScreen = const MainNavigationScreen();

    // If PIN exists, show PIN verification screen, otherwise go directly to home
    if (hasPin) {
      _targetScreen = PinVerificationScreen(
        targetScreen: targetScreen,
      );
    } else {
      _targetScreen = targetScreen;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Check if trial has expired and show dialog
      _checkAndShowTrialExpiredDialog();
    }
  }

  /// Check if trial expired and show dialog once
  Future<void> _checkAndShowTrialExpiredDialog() async {
    if (_hasShownTrialExpiredDialog) return;

    // Wait for widget tree to be built
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final subscriptionService = Provider.of<SubscriptionService>(context, listen: false);
    final status = subscriptionService.status;

    // Check if trial expired
    // When trial expires, user moves to free tier but trial data persists
    if (status != null &&
        status.subscription.tier == SubscriptionTier.free &&
        status.subscription.trial != null &&
        status.subscription.trial!.isExpired) {

      _hasShownTrialExpiredDialog = true;

      if (mounted) {
        TrialExpiredDialog.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo - using 240 version for better quality
              Image.asset(
                'assets/images/JEEVibeLogo_240.png',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if logo not found
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6200EE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'JEEVibe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: Color(0xFF6200EE)),
            ],
          ),
        ),
      );
    }
    
    return _targetScreen ?? const WelcomeScreen();
  }
}
