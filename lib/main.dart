import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/database_service.dart';
import 'services/paywall_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize Firebase if platform config is present
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase initialization optional during development/testing
  }

  // Initialize Database and TypeAdapters
  final dbService = DatabaseService();
  await dbService.init();

  // Initialize Paywall and RevenueCat configurations
  await PaywallService().init();

  runApp(const AhlApp());
}

class AhlApp extends StatefulWidget {
  const AhlApp({super.key});

  @override
  State<AhlApp> createState() => _AhlAppState();
}

class _AhlAppState extends State<AhlApp> {
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final hasSeenOnboarding = _db.hasSeenOnboarding;
    final household = _db.getHousehold();
    final isArabic = household.preferredLanguage == 'ar';

    return MaterialApp(
      title: 'أهل - ميزانية الأسرة',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: Locale(household.preferredLanguage),
      builder: (context, child) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox(),
        );
      },
      home: hasSeenOnboarding
          ? MainNavigationScreen(
              onToggleLanguage: () => setState(() {}),
            )
          : const OnboardingScreen(),
    );
  }
}
