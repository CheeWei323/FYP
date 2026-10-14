import 'package:flutter/material.dart';

import 'navigation/app_route_observer.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

class TravelGuardApp extends StatelessWidget {
  const TravelGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelGuard MY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorObservers: [appRouteObserver],
      home: const OnboardingScreen(),
    );
  }
}
