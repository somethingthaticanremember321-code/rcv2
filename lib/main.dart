import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/database_service.dart';
import 'services/paywall_service.dart';
import 'theme/app_theme.dart';

/// Global helper to toggle language anywhere in the app
Future<void> toggleAppLanguage() async {
  final db = DatabaseService();
  final current = db.getHousehold();
  final newLang = current.preferredLanguage == 'ar' ? 'en' : 'ar';
  await db.setAppLanguage(newLang);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for both Arabic and English locales
  try {
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('en', null);
  } catch (e) {
    debugPrint('DateFormatting initialization fallback: $e');
  }

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

class AhlApp extends StatelessWidget {
  const AhlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return ValueListenableBuilder(
      valueListenable: db.householdListenable,
      builder: (context, box, child) {
        final hasSeenOnboarding = db.hasSeenOnboarding;
        final household = db.getHousehold();
        final lang = household.preferredLanguage;
        final isArabic = lang == 'ar';

        return MaterialApp(
          key: ValueKey('ahl_app_$lang'),
          title: isArabic ? 'أهل - ميزانية الأسرة والزكاة' : 'Ahl - Family Finance & Zakat',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          locale: Locale(lang),
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox(),
            );
          },
          home: hasSeenOnboarding
              ? MainNavigationScreen(
                  key: ValueKey('main_nav_$lang'),
                  onToggleLanguage: toggleAppLanguage,
                )
              : const OnboardingScreen(),
        );
      },
    );
  }
}
