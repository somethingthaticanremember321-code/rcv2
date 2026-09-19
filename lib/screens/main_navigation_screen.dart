import 'package:flutter/material.dart';

import '../models/household.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'category_budgets_screen.dart';
import 'household_dashboard_screen.dart';
import 'household_split_screen.dart';
import 'quick_add_transaction_sheet.dart';
import 'zakat_tracker_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback? onToggleLanguage;

  const MainNavigationScreen({
    super.key,
    this.onToggleLanguage,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final DatabaseService _db = DatabaseService();
  int _currentIndex = 0;
  late Household _household;

  @override
  void initState() {
    super.initState();
    _household = _db.getHousehold();
  }

  void _reloadHousehold() {
    setState(() {
      _household = _db.getHousehold();
    });
    widget.onToggleLanguage?.call();
  }

  void _openQuickAdd() async {
    final added = await QuickAddTransactionSheet.show(
      context,
      household: _household,
    );
    if (added == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _household = _db.getHousehold();
    final isArabic = _household.preferredLanguage == 'ar';
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    final List<Widget> screens = [
      HouseholdDashboardScreen(
        onToggleLanguage: _reloadHousehold,
      ),
      const CategoryBudgetsScreen(),
      const HouseholdSplitScreen(),
      const ZakatTrackerScreen(),
    ];

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.creamBg,
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceCard,
            border: Border(
              top: BorderSide(color: AppTheme.surfaceBorder, width: 1),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: AppTheme.surfaceCard,
            elevation: 0,
            indicatorColor: AppTheme.primaryTealLight,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined, color: AppTheme.inkSecondary),
                selectedIcon: const Icon(Icons.dashboard_rounded, color: AppTheme.primaryTeal),
                label: isArabic ? 'الرئيسية' : 'Dashboard',
              ),
              NavigationDestination(
                icon: const Icon(Icons.pie_chart_outline_rounded, color: AppTheme.inkSecondary),
                selectedIcon: const Icon(Icons.pie_chart_rounded, color: AppTheme.primaryTeal),
                label: isArabic ? 'الميزانية' : 'Budget',
              ),
              NavigationDestination(
                icon: const Icon(Icons.people_outline_rounded, color: AppTheme.inkSecondary),
                selectedIcon: const Icon(Icons.people_rounded, color: AppTheme.primaryTeal),
                label: isArabic ? 'الأسرة' : 'Household',
              ),
              NavigationDestination(
                icon: const Icon(Icons.balance_outlined, color: AppTheme.inkSecondary),
                selectedIcon: const Icon(Icons.balance_rounded, color: AppTheme.accentGold),
                label: isArabic ? 'الزكاة' : 'Zakat',
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openQuickAdd,
          backgroundColor: AppTheme.primaryTeal,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          tooltip: isArabic ? 'إضافة عملية' : 'Add Transaction',
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}
