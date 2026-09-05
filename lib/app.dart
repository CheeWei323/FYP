import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';

class TravelGuardApp extends StatelessWidget {
  const TravelGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelGuard MY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
        ),
      ),
      home: const OnboardingScreen(),
    );
  }
}