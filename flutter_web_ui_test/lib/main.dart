import 'package:flutter/material.dart';
import 'home_screen_test.dart';

void main() => runApp(const WebTestApp());

class WebTestApp extends StatelessWidget {
  const WebTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JEEVibe Web - Home Screen Test',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9333EA)),
      ),
      home: const HomeScreenTest(),
    );
  }
}
