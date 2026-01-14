import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/daily_quiz_provider.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'providers/app_state_provider.dart';
import 'providers/offline_provider.dart';

// Screens
import 'screens/auth/welcome_screen.dart'; // The new Auth Wrapper
import 'screens/auth/pin_verification_screen.dart'; // PIN verification
import 'screens/assessment_intro_screen.dart'; // The new home dashboard
// Services
import 'services/firebase/pin_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize connectivity service for offline detection
  await ConnectivityService().initialize();

  // Initialize offline database and image cache
  await DatabaseService().initialize();
  await ImageCacheService().initialize();

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
  
  // Handle errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };
  
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    return true;
  };
  
  // Create services
  final storageService = StorageService();
  final snapCounterService = SnapCounterService(storageService);
  
  runApp(
    MultiProvider(
      providers: [
        // Firebase Auth (Now defined FIRST so others can depend on it)
        ChangeNotifierProvider(create: (_) => AuthService()),
        
        // App State (Snap limits, etc.) - Now depends on AuthService
        ChangeNotifierProxyProvider<AuthService, AppStateProvider>(
          create: (context) => AppStateProvider(
            storageService, 
            snapCounterService, 
            Provider.of<AuthService>(context, listen: false)
          )..initialize(),
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

        // Offline Mode Provider
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isLockScreenShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    final context = _navigatorKey.currentContext;
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
          
          _navigatorKey.currentState?.push(
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
      navigatorKey: _navigatorKey,
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

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    
    // 2. Check Auth & Profile
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (authService.isAuthenticated) {
      // Verify that user has a valid profile in Firestore
      // If no profile exists, sign out and redirect to welcome screen
      final firestoreService = Provider.of<FirestoreUserService>(context, listen: false);
      bool hasValidProfile = false;
      
      try {
        final profile = await firestoreService.getUserProfile(authService.currentUser!.uid);
        hasValidProfile = profile != null;
      } catch (e) {
        print('Error checking profile: $e');
        hasValidProfile = false;
      }
      
      if (!mounted) return;
      
      // If authenticated but no profile exists, sign out and show welcome screen
      // This handles cases where Firestore data was deleted but Auth session persists
      if (!hasValidProfile) {
        print('User authenticated but no profile found. Signing out...');
        await authService.signOut();
        final pinService = PinService();
        await pinService.clearPin(); // Clear any local PIN data too
        
        if (mounted) {
          setState(() {
            _targetScreen = const WelcomeScreen();
            _isLoading = false;
          });
        }
        return;
      }
      
      // User has valid profile - proceed with normal flow

      // Get auth token for API calls
      String? authToken;
      try {
        authToken = await authService.currentUser?.getIdToken();
        if (authToken != null) {
          print('');
          print('========== AUTH TOKEN FOR TESTING ==========');
          print(authToken);
          print('=============================================');
          print('');
        }
      } catch (e) {
        print('Error getting auth token: $e');
      }

      // Initialize OfflineProvider with user ID, auth token, and subscription status
      if (mounted) {
        final offlineProvider = Provider.of<OfflineProvider>(context, listen: false);

        // Fetch subscription status to determine offline capability (BUG-001 fix)
        bool offlineEnabled = false;
        if (authToken != null) {
          try {
            final subscriptionStatus = await SubscriptionService().fetchStatus(authToken);
            offlineEnabled = subscriptionStatus?.limits.offlineEnabled ?? false;
          } catch (e) {
            print('Error fetching subscription status: $e');
          }
        }

        await offlineProvider.initialize(
          authService.currentUser!.uid,
          offlineEnabled: offlineEnabled,
          authToken: authToken,
        );
      }

      if (!mounted) return;

      final pinService = PinService();
      final hasPin = await pinService.pinExists();
      
      if (!mounted) return;
      
      // Determine target screen (Assessment Intro is the new home)
      final targetScreen = const AssessmentIntroScreen();
      
      // If PIN exists, show PIN verification screen, otherwise go directly to home
      if (hasPin) {
        _targetScreen = PinVerificationScreen(
          targetScreen: targetScreen,
        );
      } else {
        _targetScreen = targetScreen;
      }
    } else {
      _targetScreen = const WelcomeScreen();
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
              // App Logo
              Image.asset(
                'assets/images/JEEVibeLogo.png',
                width: 120,
                height: 120,
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
