import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pressable.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Save Billable Hours',
      'description': 'Every hour spent on spreadsheets is an hour not billed. Let AI extract your receipt totals instantly.',
      'icon': 'timer',
    },
    {
      'title': 'Clean Financial Records',
      'description': 'Keep organized, categorized expense ledgers ready for Excel, Google Sheets, or your accountant.',
      'icon': 'table',
    },
    {
      'title': 'Private Photo Processing',
      'description': 'Receipt photos are scanned locally on your phone and never uploaded. Extracted text is sent over TLS 1.3 solely for structuring.',
      'icon': 'lock',
    },
  ];

  IconData _getIcon(String name) {
    switch (name) {
      case 'timer':
        return Icons.timer_outlined;
      case 'table':
        return Icons.table_chart_outlined;
      case 'lock':
        return Icons.shield_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  void _completeOnboarding() async {
    await DatabaseService().setHasSeenOnboarding(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainTabScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paperBg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.inkMuted, fontSize: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.pineLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.pineBorder, width: 1.5),
                          ),
                          child: Icon(
                            _getIcon(_pages[index]['icon']!),
                            size: 64,
                            color: AppTheme.pinePrimary,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          _pages[index]['title']!,
                          textAlign: TextAlign.center,
                          style: AppTheme.editorialHeading.copyWith(fontSize: 26),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _pages[index]['description']!,
                          textAlign: TextAlign.center,
                          style: AppTheme.body.copyWith(
                            fontSize: 15,
                            color: AppTheme.inkSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppTheme.pinePrimary
                              : AppTheme.surfaceBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Pressable(
                    onTap: () {
                      if (_currentPage == _pages.length - 1) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.pinePrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
