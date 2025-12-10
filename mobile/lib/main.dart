import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Services
import 'services/storage_service.dart';
import 'services/snap_counter_service.dart';
import 'services/firebase/auth_service.dart';
import 'services/firebase/firestore_user_service.dart';
import 'providers/app_state_provider.dart';

// Screens
import 'screens/auth/welcome_screen.dart'; // The new Auth Wrapper
import 'screens/auth/pin_verification_screen.dart'; // PIN verification
import 'screens/home_screen.dart'; // The main dashboard
// Services
import 'services/firebase/pin_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
        // App State (Snap limits, etc.)
        ChangeNotifierProvider(create: (_) => AppStateProvider(storageService, snapCounterService)..initialize()),
        
        // Firebase Auth
        ChangeNotifierProvider(create: (_) => AuthService()),
        
        // Firestore User Data
        Provider(create: (_) => FirestoreUserService()),
      ],
      child: const JEEVibeApp(),
    ),
  );
}

class JEEVibeApp extends StatelessWidget {
  const JEEVibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    // 1. Simulate splash delay
    await Future.delayed(const Duration(seconds: 1));
    
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
      final pinService = PinService();
      final hasPin = await pinService.pinExists();
      
      if (!mounted) return;
      
      // Determine target screen (Home or Profile Setup)
      Widget targetScreen = const HomeScreen(); // Profile exists, so go to home
      
      // If PIN exists, show PIN verification screen, otherwise go directly to target
      if (hasPin) {
        _targetScreen = PinVerificationScreen(targetScreen: targetScreen);
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
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6200EE)),
        ),
      );
    }
    
    return _targetScreen ?? const WelcomeScreen();
  }
}
