import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/jeevibe_theme.dart';
import 'providers/app_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Handle errors globally
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };
  
  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };
  
  runApp(const JEEVibeApp());
}

class JEEVibeApp extends StatelessWidget {
  const JEEVibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateProvider()..initialize(),
      child: MaterialApp(
        title: 'JEEVibe - Snap Your Question',
        debugShowCheckedModeBanner: false,
        theme: JVTheme.theme,
        home: const AppInitializer(),
      ),
    );
  }
}

/// Handles initial routing based on first launch
class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        if (!appState.isInitialized) {
          // Show loading screen while initializing
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: JVColors.primary,
              ),
            ),
          );
        }

        // Check if user has seen welcome screens
        if (!appState.hasSeenWelcome) {
          return WelcomeScreen(
            onComplete: () async {
              await appState.setWelcomeSeen();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            },
          );
        }

        return const HomeScreen();
      },
    );
  }
}

